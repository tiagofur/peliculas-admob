package storekit

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"encoding/base64"
	"encoding/json"
	"errors"
	"math/big"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tiagofur/peliculas-admob/backend/internal/db"
)

// ---- fake Apple PKI ----

type pki struct {
	root, inter, leaf *x509.Certificate
	leafKey           *ecdsa.PrivateKey
}

func newCert(t *testing.T, cn string, parent *x509.Certificate, parentKey *ecdsa.PrivateKey, isCA bool, ext *asn1.ObjectIdentifier) (*x509.Certificate, *ecdsa.PrivateKey) {
	t.Helper()
	key, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	tmpl := &x509.Certificate{
		SerialNumber: big.NewInt(time.Now().UnixNano()), Subject: pkix.Name{CommonName: cn},
		NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(24 * time.Hour),
		IsCA: isCA, BasicConstraintsValid: true,
		KeyUsage: x509.KeyUsageDigitalSignature | x509.KeyUsageCertSign,
	}
	if ext != nil {
		tmpl.ExtraExtensions = []pkix.Extension{{Id: *ext, Value: []byte{0x05, 0x00}}}
	}
	if parent == nil {
		parent, parentKey = tmpl, key
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, parent, &key.PublicKey, parentKey)
	if err != nil {
		t.Fatal(err)
	}
	c, _ := x509.ParseCertificate(der)
	return c, key
}

func newPKI(t *testing.T, leafOID asn1.ObjectIdentifier) pki {
	root, rootKey := newCert(t, "Test Root", nil, nil, true, nil)
	inter, interKey := newCert(t, "Test WWDR", root, rootKey, true, &oidIntermediate)
	leaf, leafKey := newCert(t, "Test StoreKit", inter, interKey, false, &leafOID)
	return pki{root, inter, leaf, leafKey}
}

func (p pki) sign(t *testing.T, payload any) string {
	t.Helper()
	b, _ := json.Marshal(payload)
	var claims jwt.MapClaims
	json.Unmarshal(b, &claims)
	tok := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	tok.Header["x5c"] = []string{
		base64.StdEncoding.EncodeToString(p.leaf.Raw),
		base64.StdEncoding.EncodeToString(p.inter.Raw),
		base64.StdEncoding.EncodeToString(p.root.Raw),
	}
	s, err := tok.SignedString(p.leafKey)
	if err != nil {
		t.Fatal(err)
	}
	return s
}

// ---- verifier ----

func TestAppleRootIsPinned(t *testing.T) {
	if _, err := NewAppleVerifier(); err != nil {
		t.Fatal(err)
	}
}

func TestVerifier(t *testing.T) {
	p := newPKI(t, oidLeaf)
	v := NewVerifier(p.root)
	var out map[string]any
	if err := v.Decode(p.sign(t, map[string]any{"productId": "pro"}), &out); err != nil || out["productId"] != "pro" {
		t.Fatalf("valid: %v %v", out, err)
	}

	stranger := newPKI(t, oidLeaf)
	if err := v.Decode(stranger.sign(t, map[string]any{}), &out); !errors.Is(err, ErrInvalidSignature) {
		t.Errorf("untrusted root: %v", err)
	}
	if err := v.Decode(newPKI(t, asn1.ObjectIdentifier{1, 2, 3}).sign(t, map[string]any{}), &out); !errors.Is(err, ErrInvalidSignature) {
		t.Errorf("leaf without Apple OID: %v", err)
	}
	parts := strings.Split(p.sign(t, map[string]any{"productId": "pro"}), ".")
	parts[1] = base64.RawURLEncoding.EncodeToString([]byte(`{"productId":"free-pro"}`))
	if err := v.Decode(strings.Join(parts, "."), &out); !errors.Is(err, ErrInvalidSignature) {
		t.Errorf("tampered payload: %v", err)
	}
	v.Now = func() time.Time { return time.Now().Add(48 * time.Hour) }
	if err := v.Decode(p.sign(t, map[string]any{}), &out); !errors.Is(err, ErrInvalidSignature) {
		t.Errorf("expired certificate: %v", err)
	}
	if err := (&Verifier{}).Decode("garbage", &out); !errors.Is(err, ErrInvalidSignature) {
		t.Errorf("garbage: %v", err)
	}
}

// ---- service (needs TEST_DATABASE_URL) ----

const bundle = "com.peliculas.app"

func testService(t *testing.T) (*Service, pki, string, string) {
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
	p := newPKI(t, oidLeaf)
	return &Service{DB: pool, Verifier: NewVerifier(p.root), BundleID: bundle,
		ProductIDs: []string{"pro.monthly", "pro.yearly", "pro.lifetime"}}, p, a, b
}

var now = time.Now()

func sub(orig string, expires time.Time, signed time.Time) Transaction {
	return Transaction{TransactionID: orig + "-" + signed.Format("150405.000"), OriginalTransactionID: orig, BundleID: bundle,
		ProductID: "pro.monthly", Type: "Auto-Renewable Subscription", Environment: "Sandbox",
		PurchaseDate: now.Add(-24 * time.Hour).UnixMilli(), ExpiresDate: expires.UnixMilli(), SignedDate: signed.UnixMilli()}
}

func notify(p pki, t *testing.T, tx Transaction, renewal *RenewalInfo) string {
	data := map[string]any{"bundleId": bundle, "environment": "Sandbox", "signedTransactionInfo": p.sign(t, tx)}
	if renewal != nil {
		data["signedRenewalInfo"] = p.sign(t, renewal)
	}
	return p.sign(t, map[string]any{"notificationType": "DID_RENEW", "notificationUUID": "u", "signedDate": tx.SignedDate, "data": data})
}

func TestClaimSubscription(t *testing.T) {
	s, p, a, b := testService(t)
	ctx := context.Background()
	st, err := s.Claim(ctx, a, p.sign(t, sub("1000", now.Add(30*24*time.Hour), now)))
	if err != nil || !st.Pro || st.ProductID != "pro.monthly" || st.ExpiresAt == nil {
		t.Fatalf("claim: %+v %v", st, err)
	}
	if _, err := s.Claim(ctx, b, p.sign(t, sub("1000", now.Add(30*24*time.Hour), now))); !errors.Is(err, ErrOtherAccount) {
		t.Fatalf("second account: %v", err)
	}
	if st, _ := s.Status(ctx, b); st.Pro {
		t.Fatal("other account must not get Pro")
	}

	wrong := sub("2000", now.Add(time.Hour), now)
	wrong.BundleID = "com.other.app"
	if _, err := s.Claim(ctx, a, p.sign(t, wrong)); !errors.Is(err, ErrWrongApp) {
		t.Fatalf("wrong app: %v", err)
	}
	coins := sub("3000", now.Add(time.Hour), now)
	coins.ProductID = "coins.100"
	if _, err := s.Claim(ctx, a, p.sign(t, coins)); !errors.Is(err, ErrUnknownProduct) {
		t.Fatalf("unknown product: %v", err)
	}
}

func TestLifetimeAndExpired(t *testing.T) {
	s, p, a, _ := testService(t)
	ctx := context.Background()
	expired := sub("4000", now.Add(-time.Hour), now)
	if st, _ := s.Claim(ctx, a, p.sign(t, expired)); st.Pro {
		t.Fatal("expired subscription is not Pro")
	}
	life := Transaction{OriginalTransactionID: "5000", BundleID: bundle, ProductID: "pro.lifetime", Type: "Non-Consumable",
		Environment: "Production", PurchaseDate: now.UnixMilli(), SignedDate: now.UnixMilli()}
	st, err := s.Claim(ctx, a, p.sign(t, life))
	if err != nil || !st.Pro || st.ExpiresAt != nil || st.ProductID != "pro.lifetime" {
		t.Fatalf("lifetime: %+v %v", st, err)
	}
}

func TestNotificationsBeforeAndAfterClaim(t *testing.T) {
	s, p, a, _ := testService(t)
	ctx := context.Background()

	// Apple tells us first; nobody owns it yet.
	if err := s.HandleNotification(ctx, notify(p, t, sub("6000", now.Add(time.Hour), now), nil)); err != nil {
		t.Fatal(err)
	}
	if st, _ := s.Status(ctx, a); st.Pro {
		t.Fatal("unclaimed purchase must not grant Pro")
	}
	if st, err := s.Claim(ctx, a, p.sign(t, sub("6000", now.Add(time.Hour), now))); err != nil || !st.Pro {
		t.Fatalf("claim after notification: %+v %v", st, err)
	}

	// appAccountToken (our user ID, any case) binds without the app.
	tok := sub("7000", now.Add(time.Hour), now)
	tok.AppAccountToken = strings.ToUpper(a)
	if err := s.HandleNotification(ctx, notify(p, t, tok, nil)); err != nil {
		t.Fatal(err)
	}
	var owner string
	s.DB.QueryRow(ctx, `SELECT user_id::text FROM entitlements WHERE original_transaction_id = '7000'`).Scan(&owner)
	if owner != a {
		t.Fatalf("appAccountToken binding: %q", owner)
	}
}

func TestRefundAndOrdering(t *testing.T) {
	s, p, a, _ := testService(t)
	ctx := context.Background()
	s.Claim(ctx, a, p.sign(t, sub("8000", now.Add(time.Hour), now)))

	refund := sub("8000", now.Add(time.Hour), now.Add(time.Minute))
	refund.RevocationDate = now.Add(time.Minute).UnixMilli()
	if err := s.HandleNotification(ctx, notify(p, t, refund, nil)); err != nil {
		t.Fatal(err)
	}
	if st, _ := s.Status(ctx, a); st.Pro {
		t.Fatal("refunded purchase must remove Pro")
	}
	// An older message arriving late must not undo the refund.
	late := sub("8000", now.Add(48*time.Hour), now.Add(-time.Minute))
	if err := s.HandleNotification(ctx, notify(p, t, late, nil)); err != nil {
		t.Fatal(err)
	}
	if st, _ := s.Status(ctx, a); st.Pro {
		t.Fatal("out-of-order message reverted the refund")
	}
}

func TestGracePeriod(t *testing.T) {
	s, p, a, _ := testService(t)
	ctx := context.Background()
	lapsed := sub("9000", now.Add(-time.Hour), now)
	renewal := &RenewalInfo{OriginalTransactionID: "9000", AutoRenewStatus: 1,
		GracePeriodExpiresDate: now.Add(3 * 24 * time.Hour).UnixMilli(), SignedDate: now.UnixMilli()}
	if err := s.HandleNotification(ctx, notify(p, t, lapsed, renewal)); err != nil {
		t.Fatal(err)
	}
	st, err := s.Claim(ctx, a, p.sign(t, lapsed))
	if err != nil || !st.Pro || !st.InGrace || st.AutoRenew == nil || !*st.AutoRenew {
		t.Fatalf("grace: %+v %v", st, err)
	}
}

func TestNotificationForOtherAppIsRejected(t *testing.T) {
	s, p, _, _ := testService(t)
	payload := p.sign(t, map[string]any{"notificationType": "TEST", "data": map[string]any{"bundleId": "com.other"}})
	if err := s.HandleNotification(context.Background(), payload); !errors.Is(err, ErrWrongApp) {
		t.Fatalf("got %v", err)
	}
	test := p.sign(t, map[string]any{"notificationType": "TEST", "data": map[string]any{"bundleId": bundle}})
	if err := s.HandleNotification(context.Background(), test); err != nil {
		t.Fatalf("TEST notification: %v", err)
	}
}

func TestAccountDeletionRemovesEntitlements(t *testing.T) {
	s, p, a, _ := testService(t)
	ctx := context.Background()
	s.Claim(ctx, a, p.sign(t, sub("9100", now.Add(time.Hour), now)))
	s.DB.Exec(ctx, `DELETE FROM users WHERE id = $1`, a)
	var n int
	s.DB.QueryRow(ctx, `SELECT count(*) FROM entitlements`).Scan(&n)
	if n != 0 {
		t.Fatalf("entitlements left: %d", n)
	}
}
