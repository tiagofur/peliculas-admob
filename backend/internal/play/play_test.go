package play

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"slices"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tiagofur/peliculas-admob/backend/internal/db"
)

const pkg = "mx.creapolis.peliculas.android"

var (
	products = []string{"peliculas_pro_monthly", "peliculas_pro_yearly", "peliculas_pro_lifetime"}
	now      = time.Date(2026, 11, 8, 12, 0, 0, 0, time.UTC)
)

func rfc(t time.Time) string { return t.Format(time.RFC3339Nano) }

func sub(state, product string, expiry time.Time, autoRenew bool) *SubscriptionPurchase {
	s := &SubscriptionPurchase{
		SubscriptionState: state, AcknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
		StartTime: rfc(now.Add(-time.Hour)), LatestOrderID: "GPA.1",
		LineItems: []LineItem{{ProductID: product, ExpiryTime: rfc(expiry)}},
	}
	s.LineItems[0].AutoRenewingPlan = &struct {
		AutoRenewEnabled bool `json:"autoRenewEnabled"`
	}{autoRenew}
	return s
}

// ---- product mapping ----

func TestProductKinds(t *testing.T) {
	s := &Service{ProductIDs: products, OneTimeIDs: OneTimeDefaults(products)}
	cases := map[string]kind{
		"peliculas_pro_monthly":  kindSubscription,
		"peliculas_pro_yearly":   kindSubscription,
		"peliculas_pro_lifetime": kindOneTime,
		"coins_100":              kindNone,
		"":                       kindNone,
	}
	for id, want := range cases {
		if got := s.kindOf(id); got != want {
			t.Errorf("%q: got %d want %d", id, got, want)
		}
	}
	if got := OneTimeDefaults(products); !slices.Equal(got, []string{"peliculas_pro_lifetime"}) {
		t.Errorf("one-time defaults: %v", got)
	}
}

func TestFromSubscription(t *testing.T) {
	month := now.Add(30 * 24 * time.Hour)
	past := now.Add(-24 * time.Hour)
	type want struct {
		err       error
		expires   time.Time
		grace     *time.Time
		autoRenew bool
	}
	cases := []struct {
		name string
		sub  *SubscriptionPurchase
		want want
	}{
		{"active", sub("SUBSCRIPTION_STATE_ACTIVE", "peliculas_pro_monthly", month, true), want{expires: month, autoRenew: true}},
		{"canceled keeps access until expiry", sub("SUBSCRIPTION_STATE_CANCELED", "peliculas_pro_yearly", month, false), want{expires: month}},
		{"grace period", sub("SUBSCRIPTION_STATE_IN_GRACE_PERIOD", "peliculas_pro_monthly", month, true), want{expires: now, grace: &month, autoRenew: true}},
		{"on hold", sub("SUBSCRIPTION_STATE_ON_HOLD", "peliculas_pro_monthly", past, true), want{expires: past, autoRenew: true}},
		{"paused", sub("SUBSCRIPTION_STATE_PAUSED", "peliculas_pro_monthly", month, true), want{expires: now, autoRenew: true}},
		{"expired", sub("SUBSCRIPTION_STATE_EXPIRED", "peliculas_pro_monthly", past, false), want{expires: past}},
		{"pending", sub("SUBSCRIPTION_STATE_PENDING", "peliculas_pro_monthly", month, true), want{err: ErrPending}},
		{"other product", sub("SUBSCRIPTION_STATE_ACTIVE", "coins_sub", month, true), want{err: ErrUnknownProduct}},
	}
	for _, c := range cases {
		r, err := fromSubscription(c.sub, products, "", "tok", now)
		if !errors.Is(err, c.want.err) {
			t.Errorf("%s: err %v", c.name, err)
			continue
		}
		if err != nil {
			continue
		}
		if r.expiresAt == nil || !r.expiresAt.Equal(c.want.expires) {
			t.Errorf("%s: expires %v want %v", c.name, r.expiresAt, c.want.expires)
		}
		if (r.graceUntil == nil) != (c.want.grace == nil) || (r.graceUntil != nil && !r.graceUntil.Equal(*c.want.grace)) {
			t.Errorf("%s: grace %v", c.name, r.graceUntil)
		}
		if r.autoRenew == nil || *r.autoRenew != c.want.autoRenew {
			t.Errorf("%s: auto renew %v", c.name, r.autoRenew)
		}
		if r.environment != "Production" || !r.purchasedAt.Equal(now.Add(-time.Hour)) {
			t.Errorf("%s: %s %v", c.name, r.environment, r.purchasedAt)
		}
	}

	// The app names a product the purchase is not for.
	if _, err := fromSubscription(sub("SUBSCRIPTION_STATE_ACTIVE", "peliculas_pro_monthly", month, true),
		products, "peliculas_pro_yearly", "tok", now); !errors.Is(err, ErrUnknownProduct) {
		t.Errorf("mismatched product: %v", err)
	}
	// License testers' purchases are Sandbox; new purchases need an ack.
	s := sub("SUBSCRIPTION_STATE_ACTIVE", "peliculas_pro_monthly", month, true)
	s.TestPurchase = &struct{}{}
	s.AcknowledgementState = "ACKNOWLEDGEMENT_STATE_PENDING"
	r, _ := fromSubscription(s, products, "peliculas_pro_monthly", "tok", now)
	if r.environment != "Sandbox" || !r.needsAck {
		t.Errorf("test purchase: %+v", r)
	}
	s.SubscriptionState = "SUBSCRIPTION_STATE_EXPIRED"
	if r, _ := fromSubscription(s, products, "", "tok", now); r.needsAck {
		t.Error("expired purchases are not acknowledged")
	}
}

func TestFromProduct(t *testing.T) {
	zero := 0
	p := &ProductPurchase{PurchaseTimeMillis: "1762560000000", PurchaseState: 0, AcknowledgementState: 0, PurchaseType: &zero}
	r, err := fromProduct(p, "peliculas_pro_lifetime", "tok", now)
	if err != nil || r.expiresAt != nil || r.revokedAt != nil || !r.needsAck || r.environment != "Sandbox" ||
		r.purchasedAt.UnixMilli() != 1762560000000 {
		t.Fatalf("lifetime: %+v %v", r, err)
	}
	p.PurchaseType, p.AcknowledgementState = nil, 1
	if r, _ := fromProduct(p, "peliculas_pro_lifetime", "tok", now); r.environment != "Production" || r.needsAck {
		t.Fatalf("acked production: %+v", r)
	}
	p.PurchaseState = 1
	if r, _ := fromProduct(p, "peliculas_pro_lifetime", "tok", now); r.revokedAt == nil {
		t.Fatal("canceled purchase must be revoked")
	}
	p.PurchaseState = 2
	if _, err := fromProduct(p, "peliculas_pro_lifetime", "tok", now); !errors.Is(err, ErrPending) {
		t.Fatalf("pending: %v", err)
	}
}

// ---- Developer API client ----

type fakeAuth struct{ n, invalidated int }

func (f *fakeAuth) Token(context.Context) (string, error) { f.n++; return "at", nil }
func (f *fakeAuth) Invalidate()                           { f.invalidated++ }

func TestAPIClient(t *testing.T) {
	var reqs []string
	reject := 1
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		reqs = append(reqs, r.Method+" "+r.URL.EscapedPath())
		if r.Header.Get("Authorization") != "Bearer at" {
			w.WriteHeader(403)
			return
		}
		if reject > 0 {
			reject--
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		switch r.URL.Path {
		case "/androidpublisher/v3/applications/" + pkg + "/purchases/subscriptionsv2/tokens/tok-1":
			io.WriteString(w, `{"subscriptionState":"SUBSCRIPTION_STATE_ACTIVE","lineItems":[{"productId":"peliculas_pro_monthly","expiryTime":"2026-12-08T12:00:00.123Z"}]}`)
		case "/androidpublisher/v3/applications/" + pkg + "/purchases/products/peliculas_pro_lifetime/tokens/tok-2":
			io.WriteString(w, `{"purchaseState":0,"acknowledgementState":0,"purchaseTimeMillis":"1"}`)
		case "/androidpublisher/v3/applications/" + pkg + "/purchases/subscriptions/peliculas_pro_monthly/tokens/tok-1:acknowledge",
			"/androidpublisher/v3/applications/" + pkg + "/purchases/products/peliculas_pro_lifetime/tokens/tok-2:acknowledge":
			if r.Method != http.MethodPost {
				w.WriteHeader(405)
			}
		default:
			w.WriteHeader(http.StatusBadRequest)
			io.WriteString(w, `{"error":{"code":400,"message":"Invalid Value"}}`)
		}
	}))
	defer srv.Close()
	auth := &fakeAuth{}
	api := NewAPI(auth)
	api.BaseURL, api.HTTP = srv.URL, srv.Client()
	ctx := context.Background()

	s, err := api.Subscription(ctx, pkg, "tok-1")
	if err != nil || s.SubscriptionState != "SUBSCRIPTION_STATE_ACTIVE" || s.LineItems[0].ProductID != "peliculas_pro_monthly" {
		t.Fatalf("subscription: %+v %v", s, err)
	}
	if auth.invalidated != 1 || len(reqs) != 2 {
		t.Fatalf("401 should refresh the token once: %v", reqs)
	}
	p, err := api.Product(ctx, pkg, "peliculas_pro_lifetime", "tok-2")
	if err != nil || p.PurchaseState != 0 {
		t.Fatalf("product: %+v %v", p, err)
	}
	if err := api.AcknowledgeSubscription(ctx, pkg, "peliculas_pro_monthly", "tok-1"); err != nil {
		t.Fatal(err)
	}
	if err := api.AcknowledgeProduct(ctx, pkg, "peliculas_pro_lifetime", "tok-2"); err != nil {
		t.Fatal(err)
	}
	if _, err := api.Subscription(ctx, pkg, "made-up"); !errors.Is(err, ErrInvalidPurchase) {
		t.Fatalf("unknown token: %v", err)
	}
	// Tokens are path-escaped, never spliced raw into the URL.
	api.Subscription(ctx, pkg, "a/../b")
	if last := reqs[len(reqs)-1]; last != "GET /androidpublisher/v3/applications/"+pkg+"/purchases/subscriptionsv2/tokens/a%2F..%2Fb" {
		t.Fatalf("escaping: %s", last)
	}
}

// ---- database tests ----

type fakeStore struct {
	mu    sync.Mutex
	subs  map[string]*SubscriptionPurchase
	prods map[string]*ProductPurchase
	acks  []string
}

func (f *fakeStore) Subscription(_ context.Context, p, token string) (*SubscriptionPurchase, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if s, ok := f.subs[token]; ok && p == pkg {
		c := *s
		return &c, nil
	}
	return nil, ErrInvalidPurchase
}

func (f *fakeStore) Product(_ context.Context, p, productID, token string) (*ProductPurchase, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if s, ok := f.prods[productID+"/"+token]; ok && p == pkg {
		c := *s
		return &c, nil
	}
	return nil, ErrInvalidPurchase
}

func (f *fakeStore) AcknowledgeSubscription(_ context.Context, _, productID, token string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.acks = append(f.acks, productID+"/"+token)
	if s, ok := f.subs[token]; ok {
		s.AcknowledgementState = "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"
	}
	return nil
}

func (f *fakeStore) AcknowledgeProduct(_ context.Context, _, productID, token string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.acks = append(f.acks, productID+"/"+token)
	if p, ok := f.prods[productID+"/"+token]; ok {
		p.AcknowledgementState = 1
	}
	return nil
}

func (f *fakeStore) setSub(token string, s *SubscriptionPurchase) {
	f.mu.Lock()
	f.subs[token] = s
	f.mu.Unlock()
}

func testService(t *testing.T) (*Service, *fakeStore, string, string) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)
	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `TRUNCATE users, entitlements CASCADE`); err != nil {
		t.Fatal(err)
	}
	var a, b string
	pool.QueryRow(ctx, `INSERT INTO users (email) VALUES ('a@x.com') RETURNING id`).Scan(&a)
	pool.QueryRow(ctx, `INSERT INTO users (email) VALUES ('b@x.com') RETURNING id`).Scan(&b)
	store := &fakeStore{subs: map[string]*SubscriptionPurchase{}, prods: map[string]*ProductPurchase{}}
	s := &Service{DB: pool, API: store, PackageName: pkg, ProductIDs: products,
		OneTimeIDs: OneTimeDefaults(products), Now: func() time.Time { return now }}
	return s, store, a, b
}

func rtdn(t *testing.T, payload map[string]any) []byte {
	payload["version"], payload["packageName"] = "1.0", pkg
	b, err := json.Marshal(payload)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func TestClaimSubscription(t *testing.T) {
	s, store, a, b := testService(t)
	ctx := context.Background()
	month := now.Add(30 * 24 * time.Hour)
	fresh := sub("SUBSCRIPTION_STATE_ACTIVE", "peliculas_pro_monthly", month, true)
	fresh.AcknowledgementState = "ACKNOWLEDGEMENT_STATE_PENDING"
	store.setSub("tok-1", fresh)

	st, err := s.Claim(ctx, a, ClaimRequest{PurchaseToken: "tok-1", ProductID: "peliculas_pro_monthly"})
	if err != nil || !st.Pro || st.ProductID != "peliculas_pro_monthly" || st.Store != "play" ||
		st.ExpiresAt == nil || !st.ExpiresAt.Equal(month) || st.AutoRenew == nil || !*st.AutoRenew {
		t.Fatalf("claim: %+v %v", st, err)
	}
	if !slices.Equal(store.acks, []string{"peliculas_pro_monthly/tok-1"}) {
		t.Fatalf("acks: %v", store.acks)
	}
	// Claiming again (restore) works and does not acknowledge twice.
	if st, err := s.Claim(ctx, a, ClaimRequest{PurchaseToken: "tok-1", ProductID: "peliculas_pro_monthly", PackageName: pkg}); err != nil || !st.Pro {
		t.Fatalf("re-claim: %+v %v", st, err)
	}
	if len(store.acks) != 1 {
		t.Fatalf("acked twice: %v", store.acks)
	}
	// Another account cannot take it.
	if _, err := s.Claim(ctx, b, ClaimRequest{PurchaseToken: "tok-1", ProductID: "peliculas_pro_monthly"}); !errors.Is(err, ErrOtherAccount) {
		t.Fatalf("other account: %v", err)
	}
	if st, _ := s.Status(ctx, b); st.Pro {
		t.Fatal("other account must not get Pro")
	}

	bad := []struct {
		in   ClaimRequest
		want error
	}{
		{ClaimRequest{PurchaseToken: "tok-1", ProductID: "peliculas_pro_monthly", PackageName: "com.other"}, ErrWrongApp},
		{ClaimRequest{PurchaseToken: "tok-1", ProductID: "coins_100"}, ErrUnknownProduct},
		{ClaimRequest{PurchaseToken: "", ProductID: "peliculas_pro_monthly"}, ErrBadRequest},
		{ClaimRequest{PurchaseToken: "forged", ProductID: "peliculas_pro_monthly"}, ErrInvalidPurchase},
		{ClaimRequest{PurchaseToken: "tok-1", ProductID: "peliculas_pro_yearly"}, ErrUnknownProduct}, // token is for monthly
	}
	for i, c := range bad {
		if _, err := s.Claim(ctx, a, c.in); !errors.Is(err, c.want) {
			t.Errorf("bad %d: %v want %v", i, err, c.want)
		}
	}
	store.setSub("tok-pending", sub("SUBSCRIPTION_STATE_PENDING", "peliculas_pro_monthly", month, true))
	if _, err := s.Claim(ctx, b, ClaimRequest{PurchaseToken: "tok-pending", ProductID: "peliculas_pro_monthly"}); !errors.Is(err, ErrPending) {
		t.Fatalf("pending: %v", err)
	}
}

func TestClaimLifetime(t *testing.T) {
	s, store, a, _ := testService(t)
	ctx := context.Background()
	store.prods["peliculas_pro_lifetime/tok-L"] = &ProductPurchase{PurchaseTimeMillis: "1762560000000"}
	st, err := s.Claim(ctx, a, ClaimRequest{PurchaseToken: "tok-L", ProductID: "peliculas_pro_lifetime"})
	if err != nil || !st.Pro || st.ExpiresAt != nil || st.ProductID != "peliculas_pro_lifetime" {
		t.Fatalf("lifetime: %+v %v", st, err)
	}
	if !slices.Equal(store.acks, []string{"peliculas_pro_lifetime/tok-L"}) {
		t.Fatalf("acks: %v", store.acks)
	}
	// Refund: Google voids it and the RTDN revokes Pro.
	if err := s.HandleNotification(ctx, rtdn(t, map[string]any{"voidedPurchaseNotification": map[string]any{
		"purchaseToken": "tok-L", "orderId": "GPA.1", "productType": 2, "refundType": 1}})); err != nil {
		t.Fatal(err)
	}
	if st, _ := s.Status(ctx, a); st.Pro {
		t.Fatal("refunded lifetime must not be Pro")
	}
}

func TestNotificationsKeepSubscriptionInStep(t *testing.T) {
	s, store, a, b := testService(t)
	ctx := context.Background()
	month := now.Add(30 * 24 * time.Hour)
	note := func(token string, typ int) []byte {
		return rtdn(t, map[string]any{"subscriptionNotification": map[string]any{
			"version": "1.0", "notificationType": typ, "purchaseToken": token, "subscriptionId": "peliculas_pro_monthly"}})
	}

	// SUBSCRIPTION_PURCHASED arrives before the app claims: stored unowned and acknowledged.
	fresh := sub("SUBSCRIPTION_STATE_ACTIVE", "peliculas_pro_monthly", month, true)
	fresh.AcknowledgementState = "ACKNOWLEDGEMENT_STATE_PENDING"
	store.setSub("tok-1", fresh)
	if err := s.HandleNotification(ctx, note("tok-1", 4)); err != nil {
		t.Fatal(err)
	}
	if len(store.acks) != 1 {
		t.Fatalf("RTDN should acknowledge: %v", store.acks)
	}
	if st, _ := s.Status(ctx, a); st.Pro {
		t.Fatal("nobody owns it yet")
	}
	if st, err := s.Claim(ctx, a, ClaimRequest{PurchaseToken: "tok-1", ProductID: "peliculas_pro_monthly"}); err != nil || !st.Pro {
		t.Fatalf("claim after RTDN: %+v %v", st, err)
	}

	// Renewal moves the expiry forward.
	twoMonths := month.Add(30 * 24 * time.Hour)
	store.setSub("tok-1", sub("SUBSCRIPTION_STATE_ACTIVE", "peliculas_pro_monthly", twoMonths, true))
	s.HandleNotification(ctx, note("tok-1", 2))
	if st, _ := s.Status(ctx, a); !st.ExpiresAt.Equal(twoMonths) {
		t.Fatalf("renewal: %+v", st)
	}

	// Cancel: still Pro until expiry, auto-renew off.
	store.setSub("tok-1", sub("SUBSCRIPTION_STATE_CANCELED", "peliculas_pro_monthly", twoMonths, false))
	s.HandleNotification(ctx, note("tok-1", 3))
	if st, _ := s.Status(ctx, a); !st.Pro || *st.AutoRenew {
		t.Fatalf("canceled: %+v", st)
	}

	// Grace period, then on hold.
	store.setSub("tok-1", sub("SUBSCRIPTION_STATE_IN_GRACE_PERIOD", "peliculas_pro_monthly", now.Add(3*24*time.Hour), true))
	s.HandleNotification(ctx, note("tok-1", 6))
	if st, _ := s.Status(ctx, a); !st.Pro || !st.InGrace {
		t.Fatalf("grace: %+v", st)
	}
	store.setSub("tok-1", sub("SUBSCRIPTION_STATE_ON_HOLD", "peliculas_pro_monthly", now.Add(-time.Minute), true))
	s.HandleNotification(ctx, note("tok-1", 5))
	if st, _ := s.Status(ctx, a); st.Pro {
		t.Fatalf("on hold: %+v", st)
	}

	// Upgrade to yearly: new token linked to the old one inherits the owner.
	yearly := sub("SUBSCRIPTION_STATE_ACTIVE", "peliculas_pro_yearly", now.Add(365*24*time.Hour), true)
	yearly.LinkedPurchaseToken = "tok-1"
	store.setSub("tok-2", yearly)
	if err := s.HandleNotification(ctx, note("tok-2", 4)); err != nil {
		t.Fatal(err)
	}
	if st, _ := s.Status(ctx, a); !st.Pro || st.ProductID != "peliculas_pro_yearly" {
		t.Fatalf("upgrade: %+v", st)
	}

	// Revoked (refund with revocation): Google reports it expired now.
	store.setSub("tok-2", sub("SUBSCRIPTION_STATE_EXPIRED", "peliculas_pro_yearly", now.Add(-time.Second), false))
	s.HandleNotification(ctx, note("tok-2", 12))
	if st, _ := s.Status(ctx, a); st.Pro {
		t.Fatalf("revoked: %+v", st)
	}
	if st, _ := s.Status(ctx, b); st.Pro {
		t.Fatal("b never had Pro")
	}

	// Things to ignore without asking Pub/Sub to retry.
	ignored := [][]byte{
		rtdn(t, map[string]any{"testNotification": map[string]any{"version": "1.0"}}),
		note("unknown-token", 4),
		[]byte(`{not json`),
		[]byte(`{"packageName":"com.other.app","subscriptionNotification":{"purchaseToken":"tok-1"}}`),
		rtdn(t, map[string]any{"oneTimeProductNotification": map[string]any{"notificationType": 1, "purchaseToken": "x", "sku": "coins_100"}}),
	}
	for i, n := range ignored {
		if err := s.HandleNotification(ctx, n); err != nil {
			t.Errorf("ignored %d: %v", i, err)
		}
	}
}
