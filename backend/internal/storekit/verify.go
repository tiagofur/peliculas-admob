// Package storekit verifies StoreKit 2 transactions and App Store Server
// Notifications V2, and turns them into Pro entitlements.
package storekit

import (
	"crypto/ecdsa"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"strings"
	"time"

	_ "embed" // Apple root certificate

	"github.com/golang-jwt/jwt/v5"
)

//go:embed AppleRootCA-G3.cer
var appleRootDER []byte

// Pinned so a swapped file in the repo cannot change who we trust.
const appleRootSHA256 = "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179"

var (
	// Apple marks the certificates that may sign App Store data with these OIDs.
	oidLeaf         = asn1.ObjectIdentifier{1, 2, 840, 113635, 100, 6, 11, 1}
	oidIntermediate = asn1.ObjectIdentifier{1, 2, 840, 113635, 100, 6, 2, 1}

	ErrInvalidSignature = errors.New("storekit: invalid signature")
)

// Verifier checks Apple's JWS: an ES256 signature by a leaf certificate that
// chains to the trusted root through Apple's intermediate.
type Verifier struct {
	roots *x509.CertPool
	Now   func() time.Time
}

func NewAppleVerifier() (*Verifier, error) {
	sum := sha256.Sum256(appleRootDER)
	if hex.EncodeToString(sum[:]) != appleRootSHA256 {
		return nil, errors.New("storekit: embedded Apple root certificate does not match pinned fingerprint")
	}
	root, err := x509.ParseCertificate(appleRootDER)
	if err != nil {
		return nil, err
	}
	return NewVerifier(root), nil
}

// NewVerifier trusts the given root; tests pass their own.
func NewVerifier(root *x509.Certificate) *Verifier {
	pool := x509.NewCertPool()
	pool.AddCert(root)
	return &Verifier{roots: pool, Now: time.Now}
}

// Decode verifies signed and unmarshals its payload into dst.
func (v *Verifier) Decode(signed string, dst any) error {
	header, _, ok := strings.Cut(signed, ".")
	if !ok {
		return ErrInvalidSignature
	}
	raw, err := base64.RawURLEncoding.DecodeString(header)
	if err != nil {
		return ErrInvalidSignature
	}
	var h struct {
		Alg string   `json:"alg"`
		X5C []string `json:"x5c"`
	}
	if json.Unmarshal(raw, &h) != nil || h.Alg != "ES256" || len(h.X5C) < 2 {
		return ErrInvalidSignature
	}
	certs := make([]*x509.Certificate, len(h.X5C))
	for i, c := range h.X5C {
		der, err := base64.StdEncoding.DecodeString(c)
		if err != nil {
			return ErrInvalidSignature
		}
		if certs[i], err = x509.ParseCertificate(der); err != nil {
			return ErrInvalidSignature
		}
	}
	leaf, intermediate := certs[0], certs[1]
	if !hasExt(leaf, oidLeaf) || !hasExt(intermediate, oidIntermediate) {
		return fmt.Errorf("%w: missing Apple certificate markers", ErrInvalidSignature)
	}
	inter := x509.NewCertPool()
	inter.AddCert(intermediate)
	if _, err := leaf.Verify(x509.VerifyOptions{
		Roots: v.roots, Intermediates: inter, CurrentTime: v.Now(),
		KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageAny},
	}); err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidSignature, err)
	}
	pub, ok := leaf.PublicKey.(*ecdsa.PublicKey)
	if !ok {
		return ErrInvalidSignature
	}
	// The payload is checked by our own types, not by registered JWT claims.
	tok, err := jwt.NewParser(jwt.WithValidMethods([]string{"ES256"}), jwt.WithoutClaimsValidation()).
		Parse(signed, func(*jwt.Token) (any, error) { return pub, nil })
	if err != nil || !tok.Valid {
		return fmt.Errorf("%w: %v", ErrInvalidSignature, err)
	}
	body, err := base64.RawURLEncoding.DecodeString(strings.Split(signed, ".")[1])
	if err != nil {
		return ErrInvalidSignature
	}
	return json.Unmarshal(body, dst)
}

func hasExt(c *x509.Certificate, oid asn1.ObjectIdentifier) bool {
	return slices.ContainsFunc(c.Extensions, func(e pkix.Extension) bool { return e.Id.Equal(oid) })
}
