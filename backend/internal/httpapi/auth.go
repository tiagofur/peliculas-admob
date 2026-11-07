package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/tiagofur/peliculas-admob/backend/internal/auth"
)

type ctxKey int

const userIDKey ctxKey = 0

// UserID returns the signed-in user set by requireAuth.
func UserID(ctx context.Context) string {
	id, _ := ctx.Value(userIDKey).(string)
	return id
}

func (s *Server) authRoutes(mux *http.ServeMux) {
	// bcrypt is slow on purpose; a tighter per-IP limit keeps it from being a DoS lever.
	lim := newIPLimiter(1, 10)
	limited := func(h http.HandlerFunc) http.Handler { return lim.middleware(s.clientIP, h) }

	mux.Handle("POST /v1/auth/email/signup", limited(s.signup))
	mux.Handle("POST /v1/auth/email/login", limited(s.login))
	mux.Handle("POST /v1/auth/apple", limited(s.social(true)))
	mux.Handle("POST /v1/auth/google", limited(s.social(false)))
	mux.Handle("POST /v1/auth/refresh", limited(s.refresh))
	mux.Handle("POST /v1/auth/logout", limited(s.logout))
	mux.Handle("GET /v1/me", s.requireAuth(s.getMe))
	mux.Handle("PATCH /v1/me", s.requireAuth(s.patchMe))
	mux.Handle("DELETE /v1/me", s.requireAuth(s.deleteMe))
}

func (s *Server) requireAuth(next http.HandlerFunc) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if s.Auth == nil {
			writeError(w, http.StatusServiceUnavailable, "auth_disabled")
			return
		}
		token, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok {
			writeError(w, http.StatusUnauthorized, "missing_token")
			return
		}
		userID, err := s.Auth.Tokens.Parse(token)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "invalid_token")
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), userIDKey, userID)))
	})
}

type credentials struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	Name     string `json:"name"`
	Device   string `json:"device"`
}

func (s *Server) signup(w http.ResponseWriter, r *http.Request) {
	var in credentials
	if !s.decode(w, r, &in) {
		return
	}
	sess, err := s.Auth.SignupEmail(r.Context(), in.Email, in.Password, in.Name, in.Device)
	s.respond(w, http.StatusCreated, sess, err)
}

func (s *Server) login(w http.ResponseWriter, r *http.Request) {
	var in credentials
	if !s.decode(w, r, &in) {
		return
	}
	sess, err := s.Auth.LoginEmail(r.Context(), in.Email, in.Password, in.Device)
	s.respond(w, http.StatusOK, sess, err)
}

func (s *Server) social(apple bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var in struct {
			IDToken           string `json:"id_token"`
			Nonce             string `json:"nonce"`
			AuthorizationCode string `json:"authorization_code"`
			Name              string `json:"name"`
			Device            string `json:"device"`
		}
		if !s.decode(w, r, &in) {
			return
		}
		si := auth.SocialInput{IDToken: in.IDToken, Nonce: in.Nonce, AuthorizationCode: in.AuthorizationCode, Name: in.Name, Device: in.Device}
		var sess auth.Session
		var err error
		if apple {
			sess, err = s.Auth.SignInApple(r.Context(), si)
		} else {
			sess, err = s.Auth.SignInGoogle(r.Context(), si)
		}
		s.respond(w, http.StatusOK, sess, err)
	}
}

type refreshBody struct {
	RefreshToken string `json:"refresh_token"`
}

func (s *Server) refresh(w http.ResponseWriter, r *http.Request) {
	var in refreshBody
	if !s.decode(w, r, &in) {
		return
	}
	sess, err := s.Auth.Refresh(r.Context(), in.RefreshToken)
	s.respond(w, http.StatusOK, sess, err)
}

func (s *Server) logout(w http.ResponseWriter, r *http.Request) {
	var in refreshBody
	if !s.decode(w, r, &in) {
		return
	}
	if err := s.Auth.Logout(r.Context(), in.RefreshToken); err != nil {
		s.respond(w, 0, nil, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) getMe(w http.ResponseWriter, r *http.Request) {
	u, err := s.Auth.Me(r.Context(), UserID(r.Context()))
	s.respond(w, http.StatusOK, u, err)
}

func (s *Server) patchMe(w http.ResponseWriter, r *http.Request) {
	var p auth.Patch
	if !s.decode(w, r, &p) {
		return
	}
	u, err := s.Auth.UpdateMe(r.Context(), UserID(r.Context()), p)
	s.respond(w, http.StatusOK, u, err)
}

func (s *Server) deleteMe(w http.ResponseWriter, r *http.Request) {
	if err := s.Auth.DeleteAccount(r.Context(), UserID(r.Context())); err != nil {
		s.respond(w, 0, nil, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// decode reads a small JSON body; on failure it writes the error and returns false.
func (s *Server) decode(w http.ResponseWriter, r *http.Request, dst any) bool {
	if s.Auth == nil {
		writeError(w, http.StatusServiceUnavailable, "auth_disabled")
		return false
	}
	r.Body = http.MaxBytesReader(w, r.Body, 64<<10)
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return false
	}
	return true
}

var authErrors = []struct {
	err    error
	status int
	code   string
}{
	{auth.ErrBadEmail, http.StatusBadRequest, "invalid_email"},
	{auth.ErrWeakPassword, http.StatusBadRequest, "weak_password"},
	{auth.ErrBadInput, http.StatusBadRequest, "invalid_input"},
	{auth.ErrEmailTaken, http.StatusConflict, "email_taken"},
	{auth.ErrBadCredentials, http.StatusUnauthorized, "invalid_credentials"},
	{auth.ErrInvalidToken, http.StatusUnauthorized, "invalid_token"},
	{auth.ErrNonce, http.StatusUnauthorized, "invalid_nonce"},
	{auth.ErrNotFound, http.StatusNotFound, "not_found"},
	{auth.ErrNotConfigured, http.StatusServiceUnavailable, "provider_not_configured"},
}

func (s *Server) respond(w http.ResponseWriter, status int, body any, err error) {
	if err != nil {
		for _, e := range authErrors {
			if errors.Is(err, e.err) {
				writeError(w, e.status, e.code)
				return
			}
		}
		s.Log.Error("auth", "err", err)
		writeError(w, http.StatusInternalServerError, "internal")
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(body)
}
