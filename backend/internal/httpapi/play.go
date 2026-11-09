package httpapi

import (
	"crypto/subtle"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/tiagofur/peliculas-admob/backend/internal/auth"
	"github.com/tiagofur/peliculas-admob/backend/internal/play"
)

// RTDNAuth checks that a Play notification really comes from our Pub/Sub
// push subscription. Either check (or both) may be set; none = accept all,
// which is still safe because we re-read every purchase from Google.
type RTDNAuth struct {
	Token string         // shared secret, sent as ?token= on the push URL
	OIDC  *auth.Verifier // verifies the push's Authorization: Bearer <OIDC token>
	Email string         // service account the push subscription signs as
}

func (s *Server) playRoutes(mux *http.ServeMux) {
	mux.Handle("POST /v1/play/transactions", s.requireAuth(s.claimPlay))
	mux.HandleFunc("POST /v1/play/notifications", s.playNotification)
}

func (s *Server) claimPlay(w http.ResponseWriter, r *http.Request) {
	if s.Play == nil {
		writeError(w, http.StatusServiceUnavailable, "play_disabled")
		return
	}
	var in play.ClaimRequest
	if !s.decode(w, r, &in) {
		return
	}
	st, err := s.Play.Claim(r.Context(), UserID(r.Context()), in)
	switch {
	case errors.Is(err, play.ErrBadRequest):
		writeError(w, http.StatusBadRequest, "invalid_request")
	case errors.Is(err, play.ErrWrongApp):
		writeError(w, http.StatusBadRequest, "wrong_app")
	case errors.Is(err, play.ErrUnknownProduct):
		writeError(w, http.StatusBadRequest, "unknown_product")
	case errors.Is(err, play.ErrInvalidPurchase):
		writeError(w, http.StatusBadRequest, "invalid_purchase")
	case errors.Is(err, play.ErrPending):
		writeError(w, http.StatusConflict, "purchase_pending")
	case errors.Is(err, play.ErrOtherAccount):
		writeError(w, http.StatusConflict, "purchase_owned_by_other_account")
	default:
		s.respond(w, http.StatusOK, st, err)
	}
}

// playNotification is the Pub/Sub push endpoint for Play RTDN.
func (s *Server) playNotification(w http.ResponseWriter, r *http.Request) {
	if s.Play == nil {
		writeError(w, http.StatusServiceUnavailable, "play_disabled")
		return
	}
	if !s.rtdnAuthorized(r) {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var in struct {
		Message struct {
			Data      []byte `json:"data"` // base64 in JSON
			MessageID string `json:"messageId"`
		} `json:"message"`
		Subscription string `json:"subscription"`
	}
	r.Body = http.MaxBytesReader(w, r.Body, 256<<10)
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	if err := s.Play.HandleNotification(r.Context(), in.Message.Data); err != nil {
		s.Log.Warn("play rtdn failed", "message", in.Message.MessageID, "err", err)
		writeError(w, http.StatusInternalServerError, "internal") // Pub/Sub will retry
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) rtdnAuthorized(r *http.Request) bool {
	a := s.RTDNAuth
	if a.Token != "" && subtle.ConstantTimeCompare([]byte(r.URL.Query().Get("token")), []byte(a.Token)) != 1 {
		return false
	}
	if a.OIDC != nil {
		bearer, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok {
			return false
		}
		claims, err := a.OIDC.Verify(r.Context(), bearer)
		if err != nil {
			s.Log.Warn("play rtdn: bad OIDC token", "err", err)
			return false
		}
		if a.Email != "" && (!claims.EmailVerified || !strings.EqualFold(claims.Email, a.Email)) {
			return false
		}
	}
	return true
}
