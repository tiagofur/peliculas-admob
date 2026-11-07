package httpapi

import (
	"errors"
	"net/http"

	"github.com/tiagofur/peliculas-admob/backend/internal/push"
)

func (s *Server) pushRoutes(mux *http.ServeMux) {
	mux.Handle("POST /v1/devices", s.requireAuth(s.registerDevice))
	mux.Handle("DELETE /v1/devices/{token}", s.requireAuth(s.unregisterDevice))
	mux.Handle("POST /v1/devices/test", s.requireAuth(s.testPush))
}

func (s *Server) registerDevice(w http.ResponseWriter, r *http.Request) {
	var d push.Device
	if !s.decode(w, r, &d) {
		return
	}
	err := s.Push.Register(r.Context(), UserID(r.Context()), d)
	if errors.Is(err, push.ErrBadDevice) {
		writeError(w, http.StatusBadRequest, "invalid_device")
		return
	}
	if err != nil {
		s.respond(w, 0, nil, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) unregisterDevice(w http.ResponseWriter, r *http.Request) {
	if err := s.Push.Unregister(r.Context(), UserID(r.Context()), r.PathValue("token")); err != nil {
		s.respond(w, 0, nil, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) testPush(w http.ResponseWriter, r *http.Request) {
	n, err := s.Push.SendTest(r.Context(), UserID(r.Context()))
	if errors.Is(err, push.ErrNotConfigured) {
		writeError(w, http.StatusServiceUnavailable, "push_not_configured")
		return
	}
	s.respond(w, http.StatusOK, map[string]int{"sent": n}, err)
}
