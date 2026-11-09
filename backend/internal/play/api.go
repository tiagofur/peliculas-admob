// Package play verifies Google Play purchases and keeps Pro entitlements in
// step with Real-time Developer Notifications (RTDN).
package play

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// Scope is the OAuth scope the service account needs.
const Scope = "https://www.googleapis.com/auth/androidpublisher"

// ErrInvalidPurchase means Google does not know the purchase token.
var ErrInvalidPurchase = errors.New("play: purchase token not found")

// SubscriptionPurchase is the purchases.subscriptionsv2 resource (fields we use).
type SubscriptionPurchase struct {
	SubscriptionState    string     `json:"subscriptionState"`
	AcknowledgementState string     `json:"acknowledgementState"`
	LinkedPurchaseToken  string     `json:"linkedPurchaseToken"`
	StartTime            string     `json:"startTime"`
	LatestOrderID        string     `json:"latestOrderId"`
	TestPurchase         *struct{}  `json:"testPurchase"`
	LineItems            []LineItem `json:"lineItems"`

	ExternalAccountIdentifiers *struct {
		ObfuscatedExternalAccountID string `json:"obfuscatedExternalAccountId"`
	} `json:"externalAccountIdentifiers"`
}

type LineItem struct {
	ProductID        string `json:"productId"`
	ExpiryTime       string `json:"expiryTime"`
	AutoRenewingPlan *struct {
		AutoRenewEnabled bool `json:"autoRenewEnabled"`
	} `json:"autoRenewingPlan"`
}

// ProductPurchase is the purchases.products resource (one-time products).
type ProductPurchase struct {
	PurchaseTimeMillis          string `json:"purchaseTimeMillis"`
	PurchaseState               int    `json:"purchaseState"`        // 0 purchased, 1 canceled, 2 pending
	AcknowledgementState        int    `json:"acknowledgementState"` // 0 pending, 1 acknowledged
	PurchaseType                *int   `json:"purchaseType"`         // 0 = test (license tester)
	OrderID                     string `json:"orderId"`
	ObfuscatedExternalAccountID string `json:"obfuscatedExternalAccountId"`
}

// Store is what the service needs from Google (tests use a fake).
type Store interface {
	Subscription(ctx context.Context, pkg, token string) (*SubscriptionPurchase, error)
	Product(ctx context.Context, pkg, productID, token string) (*ProductPurchase, error)
	AcknowledgeSubscription(ctx context.Context, pkg, productID, token string) error
	AcknowledgeProduct(ctx context.Context, pkg, productID, token string) error
}

// TokenSource gives OAuth access tokens (google.ServiceAccount).
type TokenSource interface {
	Token(ctx context.Context) (string, error)
	Invalidate()
}

// API talks to the Google Play Developer API over plain HTTP.
type API struct {
	Auth    TokenSource
	BaseURL string // https://androidpublisher.googleapis.com; tests use a fake
	HTTP    *http.Client
}

func NewAPI(auth TokenSource) *API {
	return &API{Auth: auth, BaseURL: "https://androidpublisher.googleapis.com",
		HTTP: &http.Client{Timeout: 15 * time.Second}}
}

func (a *API) path(pkg string, parts ...string) string {
	p := a.BaseURL + "/androidpublisher/v3/applications/" + url.PathEscape(pkg) + "/purchases"
	for _, s := range parts {
		p += "/" + url.PathEscape(s)
	}
	return p
}

func (a *API) Subscription(ctx context.Context, pkg, token string) (*SubscriptionPurchase, error) {
	var out SubscriptionPurchase
	return &out, a.do(ctx, http.MethodGet, a.path(pkg, "subscriptionsv2", "tokens", token), &out)
}

func (a *API) Product(ctx context.Context, pkg, productID, token string) (*ProductPurchase, error) {
	var out ProductPurchase
	return &out, a.do(ctx, http.MethodGet, a.path(pkg, "products", productID, "tokens", token), &out)
}

func (a *API) AcknowledgeSubscription(ctx context.Context, pkg, productID, token string) error {
	return a.do(ctx, http.MethodPost, a.path(pkg, "subscriptions", productID, "tokens", token)+":acknowledge", nil)
}

func (a *API) AcknowledgeProduct(ctx context.Context, pkg, productID, token string) error {
	return a.do(ctx, http.MethodPost, a.path(pkg, "products", productID, "tokens", token)+":acknowledge", nil)
}

func (a *API) do(ctx context.Context, method, u string, out any) error {
	for attempt := 0; ; attempt++ {
		bearer, err := a.Auth.Token(ctx)
		if err != nil {
			return err
		}
		var body io.Reader
		if method == http.MethodPost {
			body = bytes.NewReader([]byte("{}"))
		}
		req, err := http.NewRequestWithContext(ctx, method, u, body)
		if err != nil {
			return err
		}
		req.Header.Set("Authorization", "Bearer "+bearer)
		if body != nil {
			req.Header.Set("Content-Type", "application/json")
		}
		resp, err := a.HTTP.Do(req)
		if err != nil {
			return fmt.Errorf("play: %w", err)
		}
		raw, _ := io.ReadAll(io.LimitReader(resp.Body, 256<<10))
		resp.Body.Close()
		switch {
		case resp.StatusCode == http.StatusUnauthorized && attempt == 0:
			a.Auth.Invalidate()
			continue
		case resp.StatusCode == http.StatusOK:
			if out == nil {
				return nil
			}
			if err := json.Unmarshal(raw, out); err != nil {
				return fmt.Errorf("play: decode: %w", err)
			}
			return nil
		case resp.StatusCode == http.StatusBadRequest || resp.StatusCode == http.StatusNotFound ||
			resp.StatusCode == http.StatusGone:
			// Google answers 400 "Invalid Value" for tokens it never issued
			// and 410 for purchases too old to look up.
			return fmt.Errorf("%w (%d)", ErrInvalidPurchase, resp.StatusCode)
		default:
			return fmt.Errorf("play: %s %s", resp.Status, strings.TrimSpace(string(raw)))
		}
	}
}
