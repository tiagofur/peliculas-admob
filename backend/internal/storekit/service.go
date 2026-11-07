package storekit

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrWrongApp       = errors.New("storekit: transaction is for another app")
	ErrUnknownProduct = errors.New("storekit: product does not grant Pro")
	ErrOtherAccount   = errors.New("storekit: purchase belongs to another account")
)

// Transaction is the JWSTransactionDecodedPayload fields we use. Dates are
// milliseconds since 1970.
type Transaction struct {
	TransactionID         string `json:"transactionId"`
	OriginalTransactionID string `json:"originalTransactionId"`
	BundleID              string `json:"bundleId"`
	ProductID             string `json:"productId"`
	Type                  string `json:"type"`
	AppAccountToken       string `json:"appAccountToken"`
	PurchaseDate          int64  `json:"purchaseDate"`
	ExpiresDate           int64  `json:"expiresDate"`
	RevocationDate        int64  `json:"revocationDate"`
	SignedDate            int64  `json:"signedDate"`
	Environment           string `json:"environment"`
	InAppOwnershipType    string `json:"inAppOwnershipType"`
}

// RenewalInfo is the JWSRenewalInfoDecodedPayload fields we use.
type RenewalInfo struct {
	OriginalTransactionID  string `json:"originalTransactionId"`
	AutoRenewStatus        int    `json:"autoRenewStatus"`
	GracePeriodExpiresDate int64  `json:"gracePeriodExpiresDate"`
	SignedDate             int64  `json:"signedDate"`
}

type notification struct {
	NotificationType string `json:"notificationType"`
	Subtype          string `json:"subtype"`
	NotificationUUID string `json:"notificationUUID"`
	SignedDate       int64  `json:"signedDate"`
	Data             struct {
		BundleID              string `json:"bundleId"`
		Environment           string `json:"environment"`
		SignedTransactionInfo string `json:"signedTransactionInfo"`
		SignedRenewalInfo     string `json:"signedRenewalInfo"`
	} `json:"data"`
}

type Service struct {
	DB         *pgxpool.Pool
	Verifier   *Verifier
	BundleID   string
	ProductIDs []string // products that unlock Pro
	Log        *slog.Logger
	Now        func() time.Time
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// Claim records a transaction the app sends right after a purchase or a
// restore, and binds it to the signed-in user.
func (s *Service) Claim(ctx context.Context, userID, signedTransaction string) (Status, error) {
	var t Transaction
	if err := s.Verifier.Decode(signedTransaction, &t); err != nil {
		return Status{}, err
	}
	if err := s.check(t); err != nil {
		return Status{}, err
	}
	if err := s.save(ctx, &userID, t, nil); err != nil {
		return Status{}, err
	}
	return s.Status(ctx, userID)
}

// HandleNotification processes an App Store Server Notification V2. Apple
// retries on non-2xx, so only bad signatures or foreign apps return errors.
func (s *Service) HandleNotification(ctx context.Context, signedPayload string) error {
	var n notification
	if err := s.Verifier.Decode(signedPayload, &n); err != nil {
		return err
	}
	if n.Data.BundleID != s.BundleID {
		return ErrWrongApp
	}
	s.log().Info("storekit notification", "type", n.NotificationType, "subtype", n.Subtype, "env", n.Data.Environment)
	if n.Data.SignedTransactionInfo == "" { // e.g. TEST
		return nil
	}
	var t Transaction
	if err := s.Verifier.Decode(n.Data.SignedTransactionInfo, &t); err != nil {
		return err
	}
	if err := s.check(t); errors.Is(err, ErrUnknownProduct) {
		return nil // not ours to track (e.g. a future consumable)
	} else if err != nil {
		return err
	}
	var renewal *RenewalInfo
	if n.Data.SignedRenewalInfo != "" {
		var r RenewalInfo
		if err := s.Verifier.Decode(n.Data.SignedRenewalInfo, &r); err != nil {
			return err
		}
		renewal = &r
	}
	// Bind to the account the app set as appAccountToken (our user ID), if any.
	var userID *string
	if token := strings.ToLower(t.AppAccountToken); token != "" {
		var exists bool
		if err := s.DB.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM users WHERE id::text = $1)`, token).Scan(&exists); err != nil {
			return err
		}
		if exists {
			userID = &token
		}
	}
	err := s.save(ctx, userID, t, renewal)
	if errors.Is(err, ErrOtherAccount) {
		return nil // keep the existing owner; Apple must not retry
	}
	return err
}

func (s *Service) check(t Transaction) error {
	if t.BundleID != s.BundleID {
		return ErrWrongApp
	}
	if !slices.Contains(s.ProductIDs, t.ProductID) {
		return ErrUnknownProduct
	}
	if t.OriginalTransactionID == "" || t.PurchaseDate == 0 || t.SignedDate == 0 {
		return fmt.Errorf("%w: incomplete transaction", ErrInvalidSignature)
	}
	return nil
}

// save upserts the purchase chain. Apple may deliver messages out of order,
// so an older signedDate never overwrites a newer one. The first account to
// claim a purchase keeps it.
func (s *Service) save(ctx context.Context, userID *string, t Transaction, r *RenewalInfo) error {
	var grace *time.Time
	var autoRenew *bool
	if r != nil {
		grace = ms(r.GracePeriodExpiresDate)
		ar := r.AutoRenewStatus == 1
		autoRenew = &ar
	}
	ownership := t.InAppOwnershipType
	if ownership == "" {
		ownership = "PURCHASED"
	}
	tx, err := s.DB.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var owner *string
	err = tx.QueryRow(ctx, `SELECT user_id::text FROM entitlements WHERE original_transaction_id = $1 FOR UPDATE`,
		t.OriginalTransactionID).Scan(&owner)
	switch {
	case errors.Is(err, pgx.ErrNoRows):
		_, err = tx.Exec(ctx, `INSERT INTO entitlements (original_transaction_id, user_id, product_id, environment,
				ownership, purchased_at, expires_at, grace_until, revoked_at, auto_renew, last_signed_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
			t.OriginalTransactionID, userID, t.ProductID, t.Environment, ownership, ms(t.PurchaseDate),
			ms(t.ExpiresDate), grace, ms(t.RevocationDate), autoRenew, ms(t.SignedDate))
		if err != nil {
			return err
		}
		return tx.Commit(ctx)
	case err != nil:
		return err
	}
	if owner != nil && userID != nil && *owner != *userID {
		return ErrOtherAccount
	}
	_, err = tx.Exec(ctx, `UPDATE entitlements SET
			user_id = COALESCE(user_id, $2),
			product_id = CASE WHEN $11 >= last_signed_at THEN $3 ELSE product_id END,
			environment = $4, ownership = $5,
			expires_at = CASE WHEN $11 >= last_signed_at THEN $6 ELSE expires_at END,
			revoked_at = CASE WHEN $11 >= last_signed_at THEN $7 ELSE revoked_at END,
			grace_until = CASE WHEN $10 THEN $8 ELSE grace_until END,
			auto_renew = CASE WHEN $10 THEN $9 ELSE auto_renew END,
			last_signed_at = GREATEST(last_signed_at, $11),
			updated_at = now()
		WHERE original_transaction_id = $1`,
		t.OriginalTransactionID, userID, t.ProductID, t.Environment, ownership,
		ms(t.ExpiresDate), ms(t.RevocationDate), grace, autoRenew, r != nil, ms(t.SignedDate))
	if err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// Status is what the app needs to unlock Pro features.
type Status struct {
	Pro         bool       `json:"pro"`
	ProductID   string     `json:"product_id,omitempty"`
	ExpiresAt   *time.Time `json:"expires_at"` // null with pro=true means lifetime
	AutoRenew   *bool      `json:"auto_renew,omitempty"`
	InGrace     bool       `json:"in_grace_period"`
	Environment string     `json:"environment,omitempty"`
}

// Status picks the best active entitlement: lifetime first, then the one that
// lasts longest.
func (s *Service) Status(ctx context.Context, userID string) (Status, error) {
	rows, err := s.DB.Query(ctx, `SELECT product_id, environment, expires_at, grace_until, auto_renew
		FROM entitlements WHERE user_id = $1 AND revoked_at IS NULL`, userID)
	if err != nil {
		return Status{}, err
	}
	defer rows.Close()
	now := s.now()
	best := Status{}
	var bestEnd time.Time
	for rows.Next() {
		var st Status
		var expires, grace *time.Time
		if err := rows.Scan(&st.ProductID, &st.Environment, &expires, &grace, &st.AutoRenew); err != nil {
			return Status{}, err
		}
		if expires == nil { // lifetime wins outright
			st.Pro = true
			return st, rows.Err()
		}
		end := *expires
		if grace != nil && grace.After(end) {
			end = *grace
		}
		if !now.Before(end) || !end.After(bestEnd) {
			continue
		}
		st.Pro, st.ExpiresAt, st.InGrace = true, expires, !now.Before(*expires)
		best, bestEnd = st, end
	}
	return best, rows.Err()
}

func ms(v int64) *time.Time {
	if v == 0 {
		return nil
	}
	t := time.UnixMilli(v).UTC()
	return &t
}

func (s *Service) log() *slog.Logger {
	if s.Log != nil {
		return s.Log
	}
	return slog.Default()
}
