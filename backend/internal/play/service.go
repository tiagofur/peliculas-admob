package play

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tiagofur/peliculas-admob/backend/internal/storekit"
)

var (
	ErrWrongApp       = errors.New("play: purchase is for another app")
	ErrUnknownProduct = errors.New("play: product does not grant Pro")
	ErrPending        = errors.New("play: purchase is pending payment")
	ErrBadRequest     = errors.New("play: purchase_token and product_id are required")
	// ErrOtherAccount is the same error StoreKit uses, so the API answers
	// purchase_owned_by_other_account for both stores.
	ErrOtherAccount = storekit.ErrOtherAccount
)

// keyPrefix marks Play rows in entitlements.original_transaction_id.
const keyPrefix = "gp:"

type kind int

const (
	kindNone kind = iota
	kindSubscription
	kindOneTime
)

type Service struct {
	DB          *pgxpool.Pool
	API         Store
	PackageName string
	// ProductIDs unlock Pro. Those in OneTimeIDs are one-time products
	// (lifetime); the rest are subscriptions.
	ProductIDs []string
	OneTimeIDs []string
	Log        *slog.Logger
	Now        func() time.Time
}

// OneTimeDefaults picks the lifetime products from a product list, so
// peliculas_pro_lifetime is one-time without extra config.
func OneTimeDefaults(ids []string) []string {
	var out []string
	for _, id := range ids {
		if strings.Contains(id, "lifetime") {
			out = append(out, id)
		}
	}
	return out
}

func (s *Service) kindOf(productID string) kind {
	switch {
	case !slices.Contains(s.ProductIDs, productID):
		return kindNone
	case slices.Contains(s.OneTimeIDs, productID):
		return kindOneTime
	default:
		return kindSubscription
	}
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// ClaimRequest is what the app sends after a purchase or a restore.
type ClaimRequest struct {
	PurchaseToken string `json:"purchase_token"`
	ProductID     string `json:"product_id"`
	PackageName   string `json:"package_name"` // optional, defaults to ours
}

// record is one Play purchase as we store it.
type record struct {
	token       string
	productID   string
	environment string
	purchasedAt time.Time
	expiresAt   *time.Time // nil = lifetime
	graceUntil  *time.Time
	revokedAt   *time.Time
	autoRenew   *bool
	linkedToken string
	needsAck    bool
	accountID   string // obfuscatedExternalAccountId, if the app set it
}

// Claim verifies a purchase token with Google, binds it to the user and
// acknowledges it. It returns the user's Pro status.
func (s *Service) Claim(ctx context.Context, userID string, in ClaimRequest) (storekit.Status, error) {
	in.PurchaseToken = strings.TrimSpace(in.PurchaseToken)
	in.ProductID = strings.TrimSpace(in.ProductID)
	if in.PurchaseToken == "" || in.ProductID == "" || len(in.PurchaseToken) > 4096 {
		return storekit.Status{}, ErrBadRequest
	}
	if in.PackageName != "" && in.PackageName != s.PackageName {
		return storekit.Status{}, ErrWrongApp
	}
	k := s.kindOf(in.ProductID)
	if k == kindNone {
		return storekit.Status{}, ErrUnknownProduct
	}
	rec, err := s.fetch(ctx, k, in.ProductID, in.PurchaseToken)
	if err != nil {
		return storekit.Status{}, err
	}
	if err := s.save(ctx, &userID, rec); err != nil {
		return storekit.Status{}, err
	}
	s.acknowledge(ctx, k, rec)
	return s.Status(ctx, userID)
}

// Status is the user's Pro status across both stores.
func (s *Service) Status(ctx context.Context, userID string) (storekit.Status, error) {
	return storekit.UserStatus(ctx, s.DB, userID, s.now())
}

func (s *Service) fetch(ctx context.Context, k kind, productID, token string) (record, error) {
	if k == kindOneTime {
		p, err := s.API.Product(ctx, s.PackageName, productID, token)
		if err != nil {
			return record{}, err
		}
		return fromProduct(p, productID, token, s.now())
	}
	sub, err := s.API.Subscription(ctx, s.PackageName, token)
	if err != nil {
		return record{}, err
	}
	return fromSubscription(sub, s.ProductIDs, productID, token, s.now())
}

// fromSubscription maps a subscriptionsv2 purchase to an entitlement. want is
// the product the app named; empty means "whichever of ours it is" (RTDN).
func fromSubscription(sub *SubscriptionPurchase, products []string, want, token string, now time.Time) (record, error) {
	var item *LineItem
	for i := range sub.LineItems {
		li := &sub.LineItems[i]
		if (want == "" || li.ProductID == want) && slices.Contains(products, li.ProductID) {
			item = li
			break
		}
	}
	if item == nil {
		return record{}, ErrUnknownProduct
	}
	state := sub.SubscriptionState
	if state == "SUBSCRIPTION_STATE_PENDING" || state == "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED" {
		return record{}, ErrPending
	}
	r := record{
		token: token, productID: item.ProductID, environment: "Production",
		purchasedAt: now, linkedToken: sub.LinkedPurchaseToken,
	}
	if sub.TestPurchase != nil {
		r.environment = "Sandbox"
	}
	if t, err := time.Parse(time.RFC3339Nano, sub.StartTime); err == nil {
		r.purchasedAt = t.UTC()
	}
	if sub.ExternalAccountIdentifiers != nil {
		r.accountID = sub.ExternalAccountIdentifiers.ObfuscatedExternalAccountID
	}
	if item.AutoRenewingPlan != nil {
		ar := item.AutoRenewingPlan.AutoRenewEnabled
		r.autoRenew = &ar
	}
	expiry, err := time.Parse(time.RFC3339Nano, item.ExpiryTime)
	if err != nil {
		expiry = now
	}
	expiry = expiry.UTC()
	ended := minTime(expiry, now)
	switch state {
	case "SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_CANCELED":
		// CANCELED = auto-renew off; Pro lasts until expiryTime.
		r.expiresAt = &expiry
	case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD":
		// The payment failed; Google keeps access until expiryTime.
		r.expiresAt, r.graceUntil = &ended, &expiry
	default: // ON_HOLD, PAUSED, EXPIRED: no access
		r.expiresAt = &ended
	}
	r.needsAck = sub.AcknowledgementState == "ACKNOWLEDGEMENT_STATE_PENDING" &&
		(state == "SUBSCRIPTION_STATE_ACTIVE" || state == "SUBSCRIPTION_STATE_IN_GRACE_PERIOD")
	return r, nil
}

// fromProduct maps a one-time purchase (lifetime) to an entitlement.
func fromProduct(p *ProductPurchase, productID, token string, now time.Time) (record, error) {
	r := record{token: token, productID: productID, environment: "Production", purchasedAt: now,
		accountID: p.ObfuscatedExternalAccountID}
	if p.PurchaseType != nil && *p.PurchaseType == 0 {
		r.environment = "Sandbox"
	}
	if ms, err := strconv.ParseInt(p.PurchaseTimeMillis, 10, 64); err == nil && ms > 0 {
		r.purchasedAt = time.UnixMilli(ms).UTC()
	}
	switch p.PurchaseState {
	case 0:
		r.needsAck = p.AcknowledgementState == 0
	case 1: // canceled or refunded
		r.revokedAt = &now
	default:
		return record{}, ErrPending
	}
	return r, nil
}

func minTime(a, b time.Time) time.Time {
	if a.Before(b) {
		return a
	}
	return b
}

// save upserts the purchase. Each save writes the state Google just gave us,
// so it overwrites what we had. The first account to claim a purchase keeps
// it; an upgrade (linkedPurchaseToken) inherits the old purchase's owner.
func (s *Service) save(ctx context.Context, userID *string, r record) error {
	tx, err := s.DB.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	if userID == nil && r.linkedToken != "" {
		var owner *string
		err := tx.QueryRow(ctx, `SELECT user_id::text FROM entitlements WHERE original_transaction_id = $1`,
			keyPrefix+r.linkedToken).Scan(&owner)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		userID = owner
	}
	if userID == nil && r.accountID != "" {
		var exists bool
		if err := tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM users WHERE id::text = $1)`,
			strings.ToLower(r.accountID)).Scan(&exists); err != nil {
			return err
		}
		if exists {
			id := strings.ToLower(r.accountID)
			userID = &id
		}
	}

	key := keyPrefix + r.token
	var owner *string
	err = tx.QueryRow(ctx, `SELECT user_id::text FROM entitlements WHERE original_transaction_id = $1 FOR UPDATE`,
		key).Scan(&owner)
	switch {
	case errors.Is(err, pgx.ErrNoRows):
		_, err = tx.Exec(ctx, `INSERT INTO entitlements (original_transaction_id, user_id, product_id, environment,
				ownership, purchased_at, expires_at, grace_until, revoked_at, auto_renew, last_signed_at, store)
			VALUES ($1, $2, $3, $4, 'PURCHASED', $5, $6, $7, $8, $9, $10, 'play')`,
			key, userID, r.productID, r.environment, r.purchasedAt, r.expiresAt, r.graceUntil, r.revokedAt,
			r.autoRenew, s.now())
	case err != nil:
		return err
	case owner != nil && userID != nil && *owner != *userID:
		return ErrOtherAccount
	default:
		_, err = tx.Exec(ctx, `UPDATE entitlements SET
				user_id = COALESCE(user_id, $2), product_id = $3, environment = $4,
				expires_at = $5, grace_until = $6, revoked_at = COALESCE(revoked_at, $7), auto_renew = $8,
				last_signed_at = $9, updated_at = now()
			WHERE original_transaction_id = $1`,
			key, userID, r.productID, r.environment, r.expiresAt, r.graceUntil, r.revokedAt, r.autoRenew, s.now())
	}
	if err != nil {
		return err
	}
	if r.linkedToken != "" {
		// The old purchase was replaced (upgrade, downgrade or resubscribe).
		if _, err := tx.Exec(ctx, `UPDATE entitlements SET expires_at = LEAST(expires_at, $2), updated_at = now()
			WHERE original_transaction_id = $1 AND expires_at IS NOT NULL`, keyPrefix+r.linkedToken, s.now()); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

// acknowledge tells Google we granted the purchase; unacknowledged purchases
// are refunded after three days. A failure is retried on the next claim or
// notification.
func (s *Service) acknowledge(ctx context.Context, k kind, r record) {
	if !r.needsAck {
		return
	}
	var err error
	if k == kindOneTime {
		err = s.API.AcknowledgeProduct(ctx, s.PackageName, r.productID, r.token)
	} else {
		err = s.API.AcknowledgeSubscription(ctx, s.PackageName, r.productID, r.token)
	}
	if err != nil {
		s.log().Warn("play: acknowledge failed", "product", r.productID, "err", err)
	}
}

// ---- Real-time Developer Notifications ----

// DeveloperNotification is the RTDN payload inside the Pub/Sub message.
type DeveloperNotification struct {
	Version                  string `json:"version"`
	PackageName              string `json:"packageName"`
	EventTimeMillis          string `json:"eventTimeMillis"`
	SubscriptionNotification *struct {
		NotificationType int    `json:"notificationType"`
		PurchaseToken    string `json:"purchaseToken"`
		SubscriptionID   string `json:"subscriptionId"`
	} `json:"subscriptionNotification"`
	OneTimeProductNotification *struct {
		NotificationType int    `json:"notificationType"`
		PurchaseToken    string `json:"purchaseToken"`
		SKU              string `json:"sku"`
	} `json:"oneTimeProductNotification"`
	VoidedPurchaseNotification *struct {
		PurchaseToken string `json:"purchaseToken"`
		OrderID       string `json:"orderId"`
		ProductType   int    `json:"productType"` // 1 subscription, 2 one-time
		RefundType    int    `json:"refundType"`
	} `json:"voidedPurchaseNotification"`
	TestNotification *struct {
		Version string `json:"version"`
	} `json:"testNotification"`
}

// HandleNotification processes one RTDN. We never trust the payload's state:
// we read the purchase from Google again and store that. Pub/Sub retries on
// errors, so only transient failures return one.
func (s *Service) HandleNotification(ctx context.Context, data []byte) error {
	var n DeveloperNotification
	if err := json.Unmarshal(data, &n); err != nil {
		s.log().Warn("play rtdn: bad payload", "err", err)
		return nil // retrying will not fix it
	}
	if n.PackageName != s.PackageName {
		s.log().Warn("play rtdn: other package", "package", n.PackageName)
		return nil
	}
	var err error
	switch {
	case n.TestNotification != nil:
		s.log().Info("play rtdn: test notification")
		return nil
	case n.SubscriptionNotification != nil:
		sn := n.SubscriptionNotification
		s.log().Info("play rtdn", "subscription_type", sn.NotificationType, "product", sn.SubscriptionID)
		err = s.refresh(ctx, kindSubscription, "", sn.PurchaseToken)
	case n.OneTimeProductNotification != nil:
		on := n.OneTimeProductNotification
		s.log().Info("play rtdn", "one_time_type", on.NotificationType, "product", on.SKU)
		if s.kindOf(on.SKU) != kindOneTime {
			return nil
		}
		err = s.refresh(ctx, kindOneTime, on.SKU, on.PurchaseToken)
	case n.VoidedPurchaseNotification != nil:
		v := n.VoidedPurchaseNotification
		s.log().Info("play rtdn: voided purchase", "product_type", v.ProductType, "refund_type", v.RefundType)
		err = s.void(ctx, v.PurchaseToken)
	}
	switch {
	case errors.Is(err, ErrUnknownProduct), errors.Is(err, ErrPending), errors.Is(err, ErrInvalidPurchase):
		return nil // not ours, not paid yet, or unknown to Google: nothing to store
	case errors.Is(err, ErrOtherAccount):
		return nil // keep the existing owner
	}
	return err
}

// refresh re-reads a purchase from Google and stores it. productID may be
// empty for subscriptions (the line item tells us).
func (s *Service) refresh(ctx context.Context, k kind, productID, token string) error {
	if token == "" {
		return nil
	}
	var rec record
	var err error
	if k == kindOneTime {
		rec, err = s.fetch(ctx, k, productID, token)
	} else {
		var sub *SubscriptionPurchase
		sub, err = s.API.Subscription(ctx, s.PackageName, token)
		if err == nil {
			rec, err = fromSubscription(sub, s.ProductIDs, "", token, s.now())
		}
	}
	if err != nil {
		return err
	}
	if err := s.save(ctx, nil, rec); err != nil {
		return err
	}
	s.acknowledge(ctx, k, rec)
	return nil
}

// void revokes a refunded or charged-back purchase we already track.
func (s *Service) void(ctx context.Context, token string) error {
	if token == "" {
		return nil
	}
	_, err := s.DB.Exec(ctx, `UPDATE entitlements SET revoked_at = COALESCE(revoked_at, $2), updated_at = now()
		WHERE original_transaction_id = $1`, keyPrefix+token, s.now())
	if err != nil {
		return fmt.Errorf("play: void: %w", err)
	}
	return nil
}

func (s *Service) log() *slog.Logger {
	if s.Log != nil {
		return s.Log
	}
	return slog.Default()
}
