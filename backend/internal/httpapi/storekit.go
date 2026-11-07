package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/tiagofur/peliculas-admob/backend/internal/storekit"
)

func (s *Server) storekitRoutes(mux *http.ServeMux) {
	mux.Handle("POST /v1/storekit/transactions", s.requireAuth(s.claimTransaction))
	mux.HandleFunc("POST /v1/storekit/notifications", s.storekitNotification)
	mux.Handle("GET /v1/me/entitlements", s.requireAuth(s.entitlements))
}

func (s *Server) storekitReady(w http.ResponseWriter) bool {
	if s.StoreKit == nil {
		writeError(w, http.StatusServiceUnavailable, "storekit_disabled")
		return false
	}
	return true
}

func (s *Server) claimTransaction(w http.ResponseWriter, r *http.Request) {
	if !s.storekitReady(w) {
		return
	}
	var in struct {
		SignedTransaction string `json:"signed_transaction"`
	}
	if !s.decode(w, r, &in) {
		return
	}
	st, err := s.StoreKit.Claim(r.Context(), UserID(r.Context()), in.SignedTransaction)
	if s.storekitError(w, err) {
		return
	}
	s.respond(w, http.StatusOK, st, err)
}

// storekitNotification is Apple's webhook (App Store Server Notifications V2).
func (s *Server) storekitNotification(w http.ResponseWriter, r *http.Request) {
	if !s.storekitReady(w) {
		return
	}
	var in struct {
		SignedPayload string `json:"signedPayload"`
	}
	r.Body = http.MaxBytesReader(w, r.Body, 256<<10)
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	err := s.StoreKit.HandleNotification(r.Context(), in.SignedPayload)
	if err != nil {
		s.Log.Warn("storekit notification rejected", "err", err)
	}
	if s.storekitError(w, err) {
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal") // Apple will retry
		return
	}
	w.WriteHeader(http.StatusOK)
}

func (s *Server) entitlements(w http.ResponseWriter, r *http.Request) {
	if !s.storekitReady(w) {
		return
	}
	st, err := s.StoreKit.Status(r.Context(), UserID(r.Context()))
	s.respond(w, http.StatusOK, st, err)
}

// storekitError writes known StoreKit errors and reports whether it did.
func (s *Server) storekitError(w http.ResponseWriter, err error) bool {
	switch {
	case errors.Is(err, storekit.ErrInvalidSignature):
		writeError(w, http.StatusBadRequest, "invalid_signature")
	case errors.Is(err, storekit.ErrWrongApp):
		writeError(w, http.StatusBadRequest, "wrong_app")
	case errors.Is(err, storekit.ErrUnknownProduct):
		writeError(w, http.StatusBadRequest, "unknown_product")
	case errors.Is(err, storekit.ErrOtherAccount):
		writeError(w, http.StatusConflict, "purchase_owned_by_other_account")
	default:
		return false
	}
	return true
}
