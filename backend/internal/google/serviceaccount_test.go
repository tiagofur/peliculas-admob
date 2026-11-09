package google

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func keyJSON(t *testing.T, key *rsa.PrivateKey, tokenURI string) string {
	t.Helper()
	der, _ := x509.MarshalPKCS8PrivateKey(key)
	p := string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}))
	b, _ := json.Marshal(map[string]string{
		"type": "service_account", "project_id": "peliculas-app", "private_key_id": "kid1",
		"private_key": p, "client_email": "play@peliculas-app.iam.gserviceaccount.com", "token_uri": tokenURI,
	})
	return string(b)
}

func TestServiceAccountToken(t *testing.T) {
	key, _ := rsa.GenerateKey(rand.Reader, 2048)
	var calls atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		r.ParseForm()
		if r.Form.Get("grant_type") != "urn:ietf:params:oauth:grant-type:jwt-bearer" {
			http.Error(w, "grant", 400)
			return
		}
		tok, err := jwt.Parse(r.Form.Get("assertion"), func(*jwt.Token) (any, error) { return &key.PublicKey, nil },
			jwt.WithValidMethods([]string{"RS256"}))
		if err != nil {
			http.Error(w, err.Error(), 400)
			return
		}
		c := tok.Claims.(jwt.MapClaims)
		if c["iss"] != "play@peliculas-app.iam.gserviceaccount.com" || c["scope"] != "a b" ||
			c["aud"] != "http://"+r.Host+"/token" || tok.Header["kid"] != "kid1" {
			http.Error(w, fmt.Sprint(c), 400)
			return
		}
		fmt.Fprintf(w, `{"access_token":"at-%d","expires_in":3600,"token_type":"Bearer"}`, calls.Load())
	}))
	defer srv.Close()

	sa, err := ParseServiceAccount(keyJSON(t, key, srv.URL+"/token"), "a", "b")
	if err != nil {
		t.Fatal(err)
	}
	if sa.ProjectID != "peliculas-app" {
		t.Fatalf("project: %q", sa.ProjectID)
	}
	now := time.Now()
	sa.Now = func() time.Time { return now }
	ctx := context.Background()
	if tok, err := sa.Token(ctx); err != nil || tok != "at-1" {
		t.Fatalf("first: %q %v", tok, err)
	}
	if tok, _ := sa.Token(ctx); tok != "at-1" || calls.Load() != 1 {
		t.Fatal("token should be cached")
	}
	now = now.Add(59 * time.Minute) // within the 2-minute safety margin
	if tok, _ := sa.Token(ctx); tok != "at-2" {
		t.Fatalf("expired token reused: %q", tok)
	}
	sa.Invalidate()
	if tok, _ := sa.Token(ctx); tok != "at-3" {
		t.Fatalf("invalidate: %q", tok)
	}
}

func TestParseServiceAccount(t *testing.T) {
	key, _ := rsa.GenerateKey(rand.Reader, 2048)
	if sa, err := ParseServiceAccount("  "); sa != nil || err != nil {
		t.Fatal("empty config should disable, not fail")
	}
	// A path to the JSON file works too.
	path := filepath.Join(t.TempDir(), "sa.json")
	os.WriteFile(path, []byte(keyJSON(t, key, "")), 0o600)
	sa, err := ParseServiceAccount(path)
	if err != nil || sa.TokenURL != defaultTokenURL {
		t.Fatalf("file: %v %+v", err, sa)
	}
	for _, bad := range []string{
		`{"type":"authorized_user","client_email":"x","private_key":"y"}`,
		`{"type":"service_account","client_email":"x"}`,
		`{"type":"service_account","client_email":"x","private_key":"not a key"}`,
		`{not json`,
		"/does/not/exist.json",
	} {
		if _, err := ParseServiceAccount(bad); err == nil {
			t.Errorf("accepted %q", bad)
		}
	}
}
