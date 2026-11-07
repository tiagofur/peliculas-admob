package push

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrBadDevice = errors.New("push: invalid device")

// Sender is what the service needs from APNs (tests use a fake).
type Sender interface {
	Send(ctx context.Context, environment, deviceToken string, al Alert) error
}

type Service struct {
	DB     *pgxpool.Pool
	Sender Sender // nil when APNs is not configured
	Log    *slog.Logger
}

type Device struct {
	Token       string `json:"token"`
	Platform    string `json:"platform"`    // ios | tvos
	Environment string `json:"environment"` // sandbox | production
	Locale      string `json:"locale"`
	Timezone    string `json:"timezone"` // IANA, e.g. America/Mexico_City
	AppVersion  string `json:"app_version"`
}

func (d *Device) normalize() error {
	d.Token = strings.ToLower(strings.TrimSpace(d.Token))
	if len(d.Token) < 32 || len(d.Token) > 200 || strings.Trim(d.Token, "0123456789abcdef") != "" {
		return fmt.Errorf("%w: token must be hex", ErrBadDevice)
	}
	if d.Platform == "" {
		d.Platform = "ios"
	}
	if d.Platform != "ios" && d.Platform != "tvos" {
		return fmt.Errorf("%w: platform", ErrBadDevice)
	}
	if d.Environment != "sandbox" && d.Environment != "production" {
		return fmt.Errorf("%w: environment must be sandbox or production", ErrBadDevice)
	}
	if d.Timezone == "" {
		d.Timezone = "UTC"
	}
	if _, err := time.LoadLocation(d.Timezone); err != nil || len(d.Timezone) > 64 {
		return fmt.Errorf("%w: timezone", ErrBadDevice)
	}
	if len(d.Locale) > 16 || len(d.AppVersion) > 32 {
		return fmt.Errorf("%w: locale/app_version too long", ErrBadDevice)
	}
	return nil
}

// Register stores or moves a device token to this user and re-enables it.
func (s *Service) Register(ctx context.Context, userID string, d Device) error {
	if err := d.normalize(); err != nil {
		return err
	}
	_, err := s.DB.Exec(ctx, `
		INSERT INTO devices (token, user_id, platform, environment, locale, timezone, app_version)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (token) DO UPDATE SET
			user_id = EXCLUDED.user_id, platform = EXCLUDED.platform, environment = EXCLUDED.environment,
			locale = EXCLUDED.locale, timezone = EXCLUDED.timezone, app_version = EXCLUDED.app_version,
			updated_at = now(), disabled_at = NULL`,
		d.Token, userID, d.Platform, d.Environment, d.Locale, d.Timezone, d.AppVersion)
	return err
}

// Unregister removes a token (on logout or when the user turns alerts off).
func (s *Service) Unregister(ctx context.Context, userID, token string) error {
	_, err := s.DB.Exec(ctx, `DELETE FROM devices WHERE token = $1 AND user_id = $2`, strings.ToLower(token), userID)
	return err
}

type target struct {
	token, environment, locale string
}

func (s *Service) devicesOf(ctx context.Context, userID string) ([]target, error) {
	rows, err := s.DB.Query(ctx, `SELECT token, environment, locale FROM devices
		WHERE user_id = $1 AND disabled_at IS NULL`, userID)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, func(r pgx.CollectableRow) (target, error) {
		var t target
		return t, r.Scan(&t.token, &t.environment, &t.locale)
	})
}

// deliver sends to every device and returns how many accepted it. Dead
// tokens are disabled so we stop trying.
func (s *Service) deliver(ctx context.Context, devices []target, build func(lang string) Alert) int {
	sent := 0
	for _, d := range devices {
		err := s.Sender.Send(ctx, d.environment, d.token, build(lang(d.locale)))
		switch {
		case err == nil:
			sent++
		case errors.Is(err, ErrUnregistered):
			s.log().Info("push: disabling dead token", "err", err)
			if _, err := s.DB.Exec(ctx, `UPDATE devices SET disabled_at = now() WHERE token = $1`, d.token); err != nil {
				s.log().Warn("push: disable token", "err", err)
			}
		default:
			s.log().Warn("push: send failed", "err", err)
		}
	}
	return sent
}

// SendTest sends a confirmation alert to all the user's devices.
func (s *Service) SendTest(ctx context.Context, userID string) (int, error) {
	if s.Sender == nil {
		return 0, ErrNotConfigured
	}
	devices, err := s.devicesOf(ctx, userID)
	if err != nil {
		return 0, err
	}
	return s.deliver(ctx, devices, func(l string) Alert {
		return Alert{Title: text[l].testTitle, Body: text[l].testBody}
	}), nil
}

func (s *Service) log() *slog.Logger {
	if s.Log != nil {
		return s.Log
	}
	return slog.Default()
}

// ---- copy (es / en / pt) ----

type strs struct {
	testTitle, testBody string
	episode             string // %d season, %d episode
	episodeNamed        string // %d season, %d episode, %s name
}

var text = map[string]strs{
	"es": {"Películas", "¡Listo! Te avisaremos cuando salgan episodios nuevos.",
		"Nuevo episodio: T%d·E%d", "Nuevo episodio: T%d·E%d «%s»"},
	"en": {"Películas", "All set! We'll let you know when new episodes come out.",
		"New episode: S%dE%d", "New episode: S%dE%d “%s”"},
	"pt": {"Películas", "Tudo pronto! Vamos avisar quando saírem episódios novos.",
		"Novo episódio: T%d·E%d", "Novo episódio: T%d·E%d «%s»"},
}

// lang maps a device locale (es-MX, pt_BR, en) to one of our copy languages.
func lang(locale string) string {
	l := strings.ToLower(locale)
	for _, k := range []string{"es", "pt", "en"} {
		if strings.HasPrefix(l, k) {
			return k
		}
	}
	return "es"
}

// tmdbLanguage is the TMDB language we ask for show names.
func tmdbLanguage(l string) string {
	switch l {
	case "en":
		return "en-US"
	case "pt":
		return "pt-BR"
	default:
		return "es-MX"
	}
}
