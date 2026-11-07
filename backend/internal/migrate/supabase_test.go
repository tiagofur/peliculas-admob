package migrate

import (
	"context"
	"os"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"

	"github.com/tiagofur/peliculas-admob/backend/internal/db"
)

// A trimmed copy of the old Supabase schema, with the same drift as production:
// is_deleted on some tables, deleted_at on others, the renamed watched table.
const supabaseSchema = `
DROP SCHEMA IF EXISTS auth CASCADE;
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
CREATE SCHEMA auth;
CREATE TABLE auth.users (
	id uuid PRIMARY KEY, email text, encrypted_password text, email_confirmed_at timestamptz,
	raw_user_meta_data jsonb DEFAULT '{}', created_at timestamptz DEFAULT now(),
	deleted_at timestamptz, is_anonymous boolean DEFAULT false);
CREATE TABLE auth.identities (
	id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid, provider text, provider_id text, identity_data jsonb);
CREATE TABLE public.user_profiles (
	id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid, full_name varchar(100), display_name varchar(150), avatar_url text);
CREATE TABLE public.user_favorites (
	id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid, movie_id int, movie_title varchar(255),
	movie_poster_path text, movie_release_date date, added_at timestamptz DEFAULT now(), updated_at timestamptz,
	is_deleted boolean NOT NULL DEFAULT false);
CREATE TABLE public.user_watchlist (
	id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid, movie_id int, movie_title varchar(255),
	movie_poster_path text, movie_release_date date, priority varchar(10) DEFAULT 'normal',
	added_at timestamptz DEFAULT now(), updated_at timestamptz, deleted_at timestamptz);
CREATE TABLE public.user_watched (
	id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid, movie_id int, movie_title varchar(255),
	movie_poster_path text, movie_release_date date, watched_at timestamptz DEFAULT now(), updated_at timestamptz,
	is_deleted boolean NOT NULL DEFAULT false);
CREATE TABLE public.user_lists (
	id uuid PRIMARY KEY, user_id uuid, name varchar(100), description text, is_default boolean DEFAULT false,
	created_at timestamptz DEFAULT now(), updated_at timestamptz, is_deleted boolean NOT NULL DEFAULT false);
CREATE TABLE public.user_list_items (
	id uuid PRIMARY KEY DEFAULT gen_random_uuid(), list_id uuid, movie_id int, movie_title varchar(255),
	movie_poster_path text, movie_release_date date, position int DEFAULT 0, added_at timestamptz DEFAULT now(), updated_at timestamptz);
CREATE TABLE public.user_movie_ratings (
	id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, movie_id int NOT NULL, rating decimal(3,1),
	review text, movie_title varchar(500), movie_poster_path text, last_modified_at timestamptz DEFAULT now(),
	is_deleted boolean NOT NULL DEFAULT false);
`

const (
	ana     = "11111111-1111-1111-1111-111111111111" // email + password
	bruno   = "22222222-2222-2222-2222-222222222222" // Google
	carla   = "33333333-3333-3333-3333-333333333333" // Apple, sub only in identity_data
	anon    = "44444444-4444-4444-4444-444444444444" // anonymous: skipped
	gone    = "55555555-5555-5555-5555-555555555555" // deleted: skipped
	listAna = "aaaaaaaa-0000-0000-0000-000000000001"
	listOld = "aaaaaaaa-0000-0000-0000-000000000002" // belongs to a skipped user
)

func seed(t *testing.T, ctx context.Context, src *pgxpool.Pool, hash string) {
	t.Helper()
	sql := `
	INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_user_meta_data, is_anonymous, deleted_at) VALUES
		('` + ana + `', 'Ana@Example.com', $1, now(), '{"full_name":"Ana López"}', false, NULL),
		('` + bruno + `', 'bruno@gmail.com', '', now(), '{"name":"Bruno","avatar_url":"https://x/b.jpg"}', false, NULL),
		('` + carla + `', 'relay@privaterelay.appleid.com', NULL, now(), '{}', false, NULL),
		('` + anon + `', NULL, NULL, NULL, '{}', true, NULL),
		('` + gone + `', 'gone@example.com', $1, now(), '{}', false, now());
	INSERT INTO auth.identities (user_id, provider, provider_id, identity_data) VALUES
		('` + bruno + `', 'google', '1098765', '{"sub":"1098765","email":"bruno@gmail.com"}'),
		('` + carla + `', 'apple', NULL, '{"sub":"001234.abcd","email":"relay@privaterelay.appleid.com"}'),
		('` + ana + `', 'email', '` + ana + `', '{"sub":"` + ana + `"}');
	INSERT INTO public.user_profiles (user_id, full_name, display_name, avatar_url) VALUES
		('` + carla + `', 'Carla', NULL, 'https://x/c.jpg'),
		('` + ana + `', 'Otra', 'Otra', NULL);
	INSERT INTO public.user_favorites (user_id, movie_id, movie_title, movie_poster_path, movie_release_date, updated_at, is_deleted) VALUES
		('` + ana + `', 550, 'El club de la pelea', '/fc.jpg', '1999-10-15', '2025-09-01', false),
		('` + ana + `', 13, 'Forrest Gump', '/fg.jpg', '1994-07-06', '2025-09-02', true),
		('` + anon + `', 1, 'x', NULL, NULL, now(), false);
	INSERT INTO public.user_watchlist (user_id, movie_id, movie_title, updated_at, deleted_at) VALUES
		('` + bruno + `', 27205, 'El origen', '2025-09-03', NULL),
		('` + bruno + `', 603, 'Matrix', '2025-09-04', '2025-09-05');
	INSERT INTO public.user_watched (user_id, movie_id, movie_title, movie_release_date) VALUES
		('` + ana + `', 680, 'Pulp Fiction', '1994-09-10');
	INSERT INTO public.user_lists (id, user_id, name, description, created_at, updated_at) VALUES
		('` + listAna + `', '` + ana + `', 'Terror', 'Para octubre', '2025-01-01', '2025-09-01'),
		('` + listOld + `', '` + gone + `', 'Vieja', NULL, '2025-01-01', '2025-09-01');
	INSERT INTO public.user_list_items (list_id, movie_id, movie_title, position, updated_at) VALUES
		('` + listAna + `', 694, 'El resplandor', 3, '2025-09-01'),
		('` + listOld + `', 1, 'x', 0, '2025-09-01');
	INSERT INTO public.user_movie_ratings (user_id, movie_id, rating, review, movie_title, last_modified_at, is_deleted) VALUES
		('` + ana + `', 550, 7.5, 'Muy buena', 'El club de la pelea', '2025-09-01', false),
		('` + ana + `', 680, 8.3, NULL, 'Pulp Fiction', '2025-09-01', false),
		('` + bruno + `', 603, 6.0, NULL, 'Matrix', '2025-09-01', true);`
	// Several statements cannot take parameters; a bcrypt hash has no quotes.
	if _, err := src.Exec(ctx, strings.ReplaceAll(sql, "$1", "'"+hash+"'")); err != nil {
		t.Fatal(err)
	}
}

func setup(t *testing.T) (*Migrator, context.Context) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	ctx := context.Background()
	admin, err := pgx.Connect(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	var exists bool
	admin.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'supabase_test')`).Scan(&exists)
	if !exists {
		if _, err := admin.Exec(ctx, `CREATE DATABASE supabase_test`); err != nil {
			t.Fatal(err)
		}
	}
	admin.Close(ctx)

	cfg, _ := pgxpool.ParseConfig(url)
	cfg.ConnConfig.Database = "supabase_test"
	src, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(src.Close)
	if _, err := src.Exec(ctx, supabaseSchema); err != nil {
		t.Fatal(err)
	}
	// GoTrue stores bcrypt cost 10 with the $2a$ prefix.
	h, _ := bcrypt.GenerateFromPassword([]byte("supabase-pass"), 10)
	seed(t, ctx, src, "$2a$"+string(h[4:]))

	dst, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(dst.Close)
	if err := db.Migrate(ctx, dst); err != nil {
		t.Fatal(err)
	}
	if _, err := dst.Exec(ctx, `TRUNCATE users, entitlements CASCADE`); err != nil {
		t.Fatal(err)
	}
	return &Migrator{Src: src, Dst: dst}, ctx
}

func step(rep Report, name string) Step {
	for _, s := range rep.Steps {
		if s.Name == name {
			return *s
		}
	}
	return Step{}
}

func count(t *testing.T, m *Migrator, sql string, args ...any) int {
	t.Helper()
	var n int
	if err := m.Dst.QueryRow(context.Background(), sql, args...).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

func TestMigrateEverything(t *testing.T) {
	m, ctx := setup(t)
	rep, err := m.Run(ctx)
	if err != nil {
		t.Fatal(err)
	}
	t.Log("\n" + rep.String())

	// Users: anonymous and deleted ones stay behind; IDs are kept.
	if n := count(t, m, `SELECT count(*) FROM users`); n != 3 {
		t.Fatalf("users: %d", n)
	}
	var email, name, avatar string
	var verified bool
	m.Dst.QueryRow(ctx, `SELECT email, email_verified, display_name, avatar_url FROM users WHERE id = $1`, ana).Scan(&email, &verified, &name, &avatar)
	if email != "ana@example.com" || !verified || name != "Ana López" {
		t.Fatalf("ana: %s %v %q", email, verified, name)
	}
	m.Dst.QueryRow(ctx, `SELECT display_name, avatar_url FROM users WHERE id = $1`, carla).Scan(&name, &avatar)
	if name != "Carla" || avatar != "https://x/c.jpg" {
		t.Fatalf("profile fill: %q %q", name, avatar)
	}

	// Same password keeps working.
	var hash string
	m.Dst.QueryRow(ctx, `SELECT password_hash FROM identities WHERE provider = 'email' AND subject = 'ana@example.com'`).Scan(&hash)
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte("supabase-pass")) != nil {
		t.Fatal("Supabase password should still work")
	}
	// Same Apple/Google account → same user.
	if count(t, m, `SELECT count(*) FROM identities WHERE provider = 'google' AND subject = '1098765' AND user_id = $1`, bruno) != 1 ||
		count(t, m, `SELECT count(*) FROM identities WHERE provider = 'apple' AND subject = '001234.abcd' AND user_id = $1`, carla) != 1 {
		t.Fatal("social identities")
	}
	if count(t, m, `SELECT count(*) FROM identities WHERE user_id = $1 AND provider = 'email'`, bruno) != 0 {
		t.Fatal("empty password must not create an email identity")
	}

	// Library, with deletions as tombstones.
	if n := count(t, m, `SELECT count(*) FROM library_items WHERE deleted_at IS NULL`); n != 3 {
		t.Fatalf("live library items: %d", n)
	}
	if n := count(t, m, `SELECT count(*) FROM library_items WHERE deleted_at IS NOT NULL`); n != 2 {
		t.Fatalf("tombstones: %d", n)
	}
	var year, title string
	m.Dst.QueryRow(ctx, `SELECT year, title FROM library_items WHERE user_id = $1 AND kind = 'favorite' AND tmdb_id = 550`, ana).Scan(&year, &title)
	if year != "1999" || title != "El club de la pelea" {
		t.Fatalf("snapshot: %q %q", year, title)
	}
	if count(t, m, `SELECT count(*) FROM library_items WHERE kind = 'watched' AND tmdb_id = 680`) != 1 {
		t.Fatal("renamed watched table not read")
	}

	// Lists keep their ID; items of skipped users are dropped.
	if count(t, m, `SELECT count(*) FROM lists WHERE id = $1 AND name = 'Terror'`, listAna) != 1 ||
		count(t, m, `SELECT count(*) FROM lists`) != 1 {
		t.Fatal("lists")
	}
	if count(t, m, `SELECT count(*) FROM list_items WHERE list_id = $1 AND tmdb_id = 694 AND position = 3`, listAna) != 1 {
		t.Fatal("list items")
	}
	if s := step(rep, "list_items"); s.Skipped != 1 {
		t.Fatalf("list item of a skipped user: %+v", s)
	}

	// Ratings keep half points; others round to the nearest 0.5.
	var score float64
	m.Dst.QueryRow(ctx, `SELECT score FROM ratings WHERE user_id = $1 AND tmdb_id = 550`, ana).Scan(&score)
	if score != 7.5 {
		t.Fatalf("7.5 → %v", score)
	}
	m.Dst.QueryRow(ctx, `SELECT score FROM ratings WHERE user_id = $1 AND tmdb_id = 680`, ana).Scan(&score)
	if score != 8.5 {
		t.Fatalf("8.3 → %v", score)
	}
	if count(t, m, `SELECT count(*) FROM ratings WHERE user_id = $1 AND deleted_at IS NOT NULL AND score = 0`, bruno) != 1 {
		t.Fatal("deleted rating → tombstone")
	}
}

func TestRerunIsSafe(t *testing.T) {
	m, ctx := setup(t)
	if _, err := m.Run(ctx); err != nil {
		t.Fatal(err)
	}
	before := count(t, m, `SELECT (SELECT count(*) FROM users) + (SELECT count(*) FROM identities) + (SELECT count(*) FROM library_items)
		+ (SELECT count(*) FROM lists) + (SELECT count(*) FROM list_items) + (SELECT count(*) FROM ratings)`)

	// A change made on the new backend after the first copy...
	m.Dst.Exec(ctx, `UPDATE library_items SET deleted_at = now(), updated_at = now() WHERE user_id = $1 AND tmdb_id = 550`, ana)
	// ...and a newer change still made in Supabase before cutover.
	m.Src.Exec(ctx, `UPDATE user_watchlist SET deleted_at = now(), updated_at = now() WHERE movie_id = 27205`)

	rep, err := m.Run(ctx)
	if err != nil {
		t.Fatal(err)
	}
	after := count(t, m, `SELECT (SELECT count(*) FROM users) + (SELECT count(*) FROM identities) + (SELECT count(*) FROM library_items)
		+ (SELECT count(*) FROM lists) + (SELECT count(*) FROM list_items) + (SELECT count(*) FROM ratings)`)
	if after != before {
		t.Fatalf("re-run created rows: %d → %d", before, after)
	}
	if count(t, m, `SELECT count(*) FROM library_items WHERE user_id = $1 AND tmdb_id = 550 AND deleted_at IS NOT NULL`, ana) != 1 {
		t.Fatal("re-run overwrote a newer change from the new backend")
	}
	if count(t, m, `SELECT count(*) FROM library_items WHERE tmdb_id = 27205 AND deleted_at IS NOT NULL`) != 1 {
		t.Fatal("newer Supabase change not copied")
	}
	if s := step(rep, "users"); s.Written != 0 {
		t.Fatalf("users re-written: %+v", s)
	}
}

func TestEmailAlreadyOnNewBackend(t *testing.T) {
	m, ctx := setup(t)
	m.Dst.Exec(ctx, `INSERT INTO users (email) VALUES ('ana@example.com')`)
	rep, err := m.Run(ctx)
	if err != nil {
		t.Fatal(err)
	}
	s := step(rep, "users")
	if s.Skipped != 1 || len(s.Notes) != 1 || !strings.Contains(s.Notes[0], ana) {
		t.Fatalf("conflict should be reported: %+v", s)
	}
	if count(t, m, `SELECT count(*) FROM library_items WHERE user_id = $1`, ana) != 0 {
		t.Fatal("library of a skipped user must not be copied")
	}
}

func TestDryRunSavesNothing(t *testing.T) {
	m, ctx := setup(t)
	m.DryRun = true
	rep, err := m.Run(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if step(rep, "users").Written != 3 || !strings.HasPrefix(rep.String(), "DRY RUN") {
		t.Fatalf("report: %s", rep)
	}
	if n := count(t, m, `SELECT count(*) FROM users`); n != 0 {
		t.Fatalf("dry run saved %d users", n)
	}
}
