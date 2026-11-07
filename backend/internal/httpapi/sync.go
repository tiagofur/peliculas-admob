package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/tiagofur/peliculas-admob/backend/internal/library"
)

func (s *Server) syncRoutes(mux *http.ServeMux) {
	mux.Handle("GET /v1/sync", s.requireAuth(s.pull))
	mux.Handle("POST /v1/sync", s.requireAuth(s.push))
}

func (s *Server) pull(w http.ResponseWriter, r *http.Request) {
	c, err := s.Library.Pull(r.Context(), UserID(r.Context()), r.URL.Query().Get("cursor"))
	if errors.Is(err, library.ErrBadCursor) {
		writeError(w, http.StatusBadRequest, "invalid_cursor")
		return
	}
	s.respond(w, http.StatusOK, c, err)
}

func (s *Server) push(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Ops []library.Op `json:"ops"`
	}
	r.Body = http.MaxBytesReader(w, r.Body, 2<<20)
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	if len(in.Ops) > library.MaxOps {
		writeError(w, http.StatusRequestEntityTooLarge, "too_many_ops")
		return
	}
	results, err := s.Library.Push(r.Context(), UserID(r.Context()), in.Ops)
	s.respond(w, http.StatusOK, map[string]any{"results": results}, err)
}
