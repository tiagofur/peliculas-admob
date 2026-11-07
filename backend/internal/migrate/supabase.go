// Package migrate copies users and libraries from the old Supabase database
// into our schema.
//
// It is safe to run many times: an early copy, then a final one at cutover.
//   - User IDs are kept, so nothing that refers to a user changes.
//   - Supabase bcrypt password hashes are copied as is: same passwords work.
//   - Apple/Google identities keep their provider subject, so the same
//     Apple/Google account lands on the same user.
//   - Library rows are upserted with last-write-wins on updated_at, so a
//     re-run never overwrites newer changes made on the new backend, and rows
//     deleted in Supabase become tombstones.
//
// The old schema drifted over time (is_deleted here, deleted_at there, renamed
// tables), so every query is built from the columns that actually exist.
package migrate

import (
	"context"
	"fmt"
	"log/slog"
	"math"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Step counts what happened to one kind of data.
type Step struct {
	Name    string
	Read    int
	Written int
	Skipped int
	Notes   []string
}

type Report struct {
	DryRun bool
	Steps  []*Step
}

func (r Report) String() string {
	var b strings.Builder
	if r.DryRun {
		b.WriteString("DRY RUN: nothing was saved\n")
	}
	fmt.Fprintf(&b, "%-16s %8s %8s %8s\n", "step", "read", "written", "skipped")
	for _, s := range r.Steps {
		fmt.Fprintf(&b, "%-16s %8d %8d %8d\n", s.Name, s.Read, s.Written, s.Skipped)
		for _, n := range s.Notes {
			fmt.Fprintf(&b, "    - %s\n", n)
		}
	}
	return b.String()
}

type Migrator struct {
	Src    *pgxpool.Pool // Supabase (read only)
	Dst    *pgxpool.Pool // our database
	DryRun bool          // do everything in a transaction, then roll back
	Log    *slog.Logger

	users map[string]bool // user IDs present in the destination
}

// Run copies everything inside one destination transaction.
func (m *Migrator) Run(ctx context.Context) (Report, error) {
	rep := Report{DryRun: m.DryRun}
	tx, err := m.Dst.Begin(ctx)
	if err != nil {
		return rep, err
	}
	defer tx.Rollback(ctx)

	steps := []func(context.Context, pgx.Tx) (*Step, error){
		m.migrateUsers, m.migrateIdentities, m.migrateProfiles,
		m.loadUsers,
		m.libraryStep("favorites", "favorite", []string{"user_favorites"}, "added_at"),
		m.libraryStep("watchlist", "watchlist", []string{"user_watchlist"}, "added_at"),
		m.libraryStep("watched", "watched", []string{"user_watched", "user_watched_movies", "watched_movies"}, "watched_at"),
		m.migrateLists, m.migrateListItems, m.migrateRatings,
	}
	for _, step := range steps {
		s, err := step(ctx, tx)
		if err != nil {
			return rep, err
		}
		if s != nil {
			rep.Steps = append(rep.Steps, s)
			m.log().Info("migrate", "step", s.Name, "read", s.Read, "written", s.Written, "skipped", s.Skipped)
		}
	}
	if m.DryRun {
		return rep, nil
	}
	return rep, tx.Commit(ctx)
}

// ---- schema introspection ----

func (m *Migrator) columns(ctx context.Context, schema, table string) (map[string]bool, error) {
	rows, err := m.Src.Query(ctx, `SELECT column_name FROM information_schema.columns
		WHERE table_schema = $1 AND table_name = $2`, schema, table)
	if err != nil {
		return nil, err
	}
	names, err := pgx.CollectRows(rows, pgx.RowTo[string])
	if err != nil {
		return nil, err
	}
	cols := map[string]bool{}
	for _, n := range names {
		cols[n] = true
	}
	return cols, nil
}

// firstTable returns the first table that exists and its columns.
func (m *Migrator) firstTable(ctx context.Context, names ...string) (string, map[string]bool, error) {
	for _, n := range names {
		cols, err := m.columns(ctx, "public", n)
		if err != nil {
			return "", nil, err
		}
		if len(cols) > 0 {
			return n, cols, nil
		}
	}
	return "", nil, nil
}

// coalesce builds COALESCE(a, b, ..., fallback) from the columns that exist.
func coalesce(cols map[string]bool, fallback string, candidates ...string) string {
	var parts []string
	for _, c := range candidates {
		if cols[c] {
			parts = append(parts, c)
		}
	}
	parts = append(parts, fallback)
	return "COALESCE(" + strings.Join(parts, ", ") + ")"
}

func deletedExpr(cols map[string]bool) string {
	switch {
	case cols["is_deleted"] && cols["deleted_at"]:
		return "(is_deleted OR deleted_at IS NOT NULL)"
	case cols["is_deleted"]:
		return "is_deleted"
	case cols["deleted_at"]:
		return "(deleted_at IS NOT NULL)"
	default:
		return "false"
	}
}

func col(cols map[string]bool, name, fallback string) string {
	if cols[name] {
		return name
	}
	return fallback
}

// ---- users ----

func (m *Migrator) migrateUsers(ctx context.Context, tx pgx.Tx) (*Step, error) {
	s := &Step{Name: "users"}
	cols, err := m.columns(ctx, "auth", "users")
	if err != nil {
		return nil, err
	}
	where := []string{"true"}
	if cols["deleted_at"] {
		where = append(where, "deleted_at IS NULL")
	}
	if cols["is_anonymous"] {
		where = append(where, "NOT is_anonymous")
	}
	rows, err := m.Src.Query(ctx, `SELECT id::text, lower(email), `+col(cols, "email_confirmed_at", "NULL::timestamptz")+` IS NOT NULL,
			COALESCE(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', ''),
			COALESCE(raw_user_meta_data->>'avatar_url', raw_user_meta_data->>'picture', ''),
			COALESCE(created_at, now())
		FROM auth.users WHERE `+strings.Join(where, " AND "))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	type user struct {
		id           string
		email        *string
		verified     bool
		name, avatar string
		created      time.Time
	}
	var users []user
	for rows.Next() {
		var u user
		if err := rows.Scan(&u.id, &u.email, &u.verified, &u.name, &u.avatar, &u.created); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	for _, u := range users {
		s.Read++
		if u.email != nil && *u.email == "" {
			u.email = nil
		}
		// ON CONFLICT DO NOTHING also covers an email that already signed up
		// on the new backend with another ID: that account is left alone.
		tag, err := tx.Exec(ctx, `INSERT INTO users (id, email, email_verified, display_name, avatar_url, created_at)
			VALUES ($1, $2, $3, left($4, 80), left($5, 500), $6) ON CONFLICT DO NOTHING`,
			u.id, u.email, u.verified, u.name, u.avatar, u.created)
		if err != nil {
			return nil, fmt.Errorf("user %s: %w", u.id, err)
		}
		if tag.RowsAffected() == 1 {
			s.Written++
			continue
		}
		var sameID bool
		if err := tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM users WHERE id = $1)`, u.id).Scan(&sameID); err != nil {
			return nil, err
		}
		if !sameID {
			s.Skipped++
			s.Notes = append(s.Notes, fmt.Sprintf("user %s: email already used by another account on the new backend", u.id))
		}
	}
	return s, nil
}

func (m *Migrator) migrateIdentities(ctx context.Context, tx pgx.Tx) (*Step, error) {
	s := &Step{Name: "identities"}

	// Email + password come from auth.users.
	rows, err := m.Src.Query(ctx, `SELECT id::text, lower(email), encrypted_password FROM auth.users
		WHERE email IS NOT NULL AND email <> '' AND encrypted_password IS NOT NULL AND encrypted_password <> ''`)
	if err != nil {
		return nil, err
	}
	type pw struct{ id, email, hash string }
	passwords, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (pw, error) {
		var p pw
		return p, r.Scan(&p.id, &p.email, &p.hash)
	})
	if err != nil {
		return nil, err
	}
	for _, p := range passwords {
		s.Read++
		if !strings.HasPrefix(p.hash, "$2") {
			s.Skipped++
			s.Notes = append(s.Notes, fmt.Sprintf("user %s: password hash is not bcrypt", p.id))
			continue
		}
		tag, err := tx.Exec(ctx, `INSERT INTO identities (user_id, provider, subject, email, password_hash)
			SELECT $1, 'email', $2, $2, $3 WHERE EXISTS (SELECT 1 FROM users WHERE id = $1)
			ON CONFLICT DO NOTHING`, p.id, p.email, p.hash)
		if err != nil {
			return nil, err
		}
		s.Written += int(tag.RowsAffected())
	}

	// Apple and Google from auth.identities.
	cols, err := m.columns(ctx, "auth", "identities")
	if err != nil {
		return nil, err
	}
	if len(cols) == 0 {
		return s, nil
	}
	subject := "identity_data->>'sub'"
	if cols["provider_id"] {
		subject = "COALESCE(provider_id, identity_data->>'sub')"
	}
	rows, err = m.Src.Query(ctx, `SELECT user_id::text, provider, `+subject+`, COALESCE(lower(identity_data->>'email'), '')
		FROM auth.identities WHERE provider IN ('apple', 'google')`)
	if err != nil {
		return nil, err
	}
	type idn struct{ user, provider, subject, email string }
	ids, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (idn, error) {
		var i idn
		var sub *string
		err := r.Scan(&i.user, &i.provider, &sub, &i.email)
		if sub != nil {
			i.subject = *sub
		}
		return i, err
	})
	if err != nil {
		return nil, err
	}
	for _, i := range ids {
		s.Read++
		if i.subject == "" {
			s.Skipped++
			continue
		}
		tag, err := tx.Exec(ctx, `INSERT INTO identities (user_id, provider, subject, email)
			SELECT $1, $2, $3, NULLIF($4, '') WHERE EXISTS (SELECT 1 FROM users WHERE id = $1)
			ON CONFLICT DO NOTHING`, i.user, i.provider, i.subject, i.email)
		if err != nil {
			return nil, err
		}
		s.Written += int(tag.RowsAffected())
	}
	return s, nil
}

// migrateProfiles fills display name and avatar from the profile table, only
// where the user has none yet.
func (m *Migrator) migrateProfiles(ctx context.Context, tx pgx.Tx) (*Step, error) {
	table, cols, err := m.firstTable(ctx, "user_profiles", "profiles")
	if err != nil || table == "" {
		return nil, err
	}
	s := &Step{Name: "profiles"}
	key := col(cols, "user_id", "id")
	name := coalesce(cols, "''", "display_name", "full_name", "username")
	avatar := coalesce(cols, "''", "avatar_url")
	rows, err := m.Src.Query(ctx, fmt.Sprintf(`SELECT %s::text, %s, %s FROM public.%s WHERE %s IS NOT NULL`,
		key, name, avatar, table, key))
	if err != nil {
		return nil, err
	}
	type prof struct{ id, name, avatar string }
	profs, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (prof, error) {
		var p prof
		return p, r.Scan(&p.id, &p.name, &p.avatar)
	})
	if err != nil {
		return nil, err
	}
	for _, p := range profs {
		s.Read++
		tag, err := tx.Exec(ctx, `UPDATE users SET
				display_name = CASE WHEN display_name = '' THEN left($2, 80) ELSE display_name END,
				avatar_url = CASE WHEN avatar_url = '' THEN left($3, 500) ELSE avatar_url END
			WHERE id::text = $1 AND (display_name = '' AND $2 <> '' OR avatar_url = '' AND $3 <> '')`,
			p.id, strings.TrimSpace(p.name), p.avatar)
		if err != nil {
			return nil, err
		}
		s.Written += int(tag.RowsAffected())
	}
	return s, nil
}

func (m *Migrator) loadUsers(ctx context.Context, tx pgx.Tx) (*Step, error) {
	rows, err := tx.Query(ctx, `SELECT id::text FROM users`)
	if err != nil {
		return nil, err
	}
	ids, err := pgx.CollectRows(rows, pgx.RowTo[string])
	if err != nil {
		return nil, err
	}
	m.users = make(map[string]bool, len(ids))
	for _, id := range ids {
		m.users[id] = true
	}
	return nil, nil
}

// ---- library ----

type movieRow struct {
	userID, title, poster, year string
	tmdbID                      int
	updated                     time.Time
	deleted                     bool
}

func (m *Migrator) libraryStep(name, kind string, tables []string, addedCol string) func(context.Context, pgx.Tx) (*Step, error) {
	return func(ctx context.Context, tx pgx.Tx) (*Step, error) {
		table, cols, err := m.firstTable(ctx, tables...)
		if err != nil || table == "" {
			return nil, err
		}
		s := &Step{Name: name}
		rows, err := m.Src.Query(ctx, fmt.Sprintf(`SELECT user_id::text, movie_id, COALESCE(movie_title, ''),
				COALESCE(movie_poster_path, ''), COALESCE(to_char(%s, 'YYYY'), ''), %s, %s
			FROM public.%s WHERE user_id IS NOT NULL AND movie_id > 0`,
			col(cols, "movie_release_date", "NULL::date"),
			coalesce(cols, "now()", "last_modified_at", "updated_at", addedCol, "created_at"),
			deletedExpr(cols), table))
		if err != nil {
			return nil, err
		}
		movies, err := collectMovies(rows)
		if err != nil {
			return nil, err
		}
		for _, r := range movies {
			s.Read++
			if !m.users[r.userID] {
				s.Skipped++
				continue
			}
			tag, err := tx.Exec(ctx, `
				INSERT INTO library_items (user_id, kind, media_type, tmdb_id, title, poster_path, year, updated_at, deleted_at)
				VALUES ($1, $2, 'movie', $3, left($4, 300), left($5, 200), $6, $7, CASE WHEN $8 THEN $7::timestamptz END)
				ON CONFLICT (user_id, kind, media_type, tmdb_id) DO UPDATE SET
					title = EXCLUDED.title, poster_path = EXCLUDED.poster_path, year = EXCLUDED.year,
					updated_at = EXCLUDED.updated_at, deleted_at = EXCLUDED.deleted_at, txid = pg_current_xact_id()
				WHERE library_items.updated_at < EXCLUDED.updated_at`,
				r.userID, kind, r.tmdbID, r.title, r.poster, r.year, r.updated, r.deleted)
			if err != nil {
				return nil, fmt.Errorf("%s: %w", name, err)
			}
			s.Written += int(tag.RowsAffected())
		}
		return s, nil
	}
}

func collectMovies(rows pgx.Rows) ([]movieRow, error) {
	return pgx.CollectRows(rows, func(r pgx.CollectableRow) (movieRow, error) {
		var m movieRow
		return m, r.Scan(&m.userID, &m.tmdbID, &m.title, &m.poster, &m.year, &m.updated, &m.deleted)
	})
}

func (m *Migrator) migrateLists(ctx context.Context, tx pgx.Tx) (*Step, error) {
	table, cols, err := m.firstTable(ctx, "user_lists")
	if err != nil || table == "" {
		return nil, err
	}
	s := &Step{Name: "lists"}
	rows, err := m.Src.Query(ctx, fmt.Sprintf(`SELECT id::text, user_id::text, COALESCE(name, ''), COALESCE(description, ''),
			(row_number() OVER (PARTITION BY user_id ORDER BY %s, id) - 1)::int, %s, %s
		FROM public.user_lists WHERE user_id IS NOT NULL`,
		coalesce(cols, "now()", "created_at"), coalesce(cols, "now()", "last_modified_at", "updated_at", "created_at"), deletedExpr(cols)))
	if err != nil {
		return nil, err
	}
	type list struct {
		id, userID, name, desc string
		pos                    int
		updated                time.Time
		deleted                bool
	}
	lists, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (list, error) {
		var l list
		return l, r.Scan(&l.id, &l.userID, &l.name, &l.desc, &l.pos, &l.updated, &l.deleted)
	})
	if err != nil {
		return nil, err
	}
	for _, l := range lists {
		s.Read++
		if !m.users[l.userID] {
			s.Skipped++
			continue
		}
		tag, err := tx.Exec(ctx, `
			INSERT INTO lists (id, user_id, name, description, position, updated_at, deleted_at)
			VALUES ($1, $2, left($3, 100), left($4, 500), $5, $6, CASE WHEN $7 THEN $6::timestamptz END)
			ON CONFLICT (id) DO UPDATE SET
				name = EXCLUDED.name, description = EXCLUDED.description, position = EXCLUDED.position,
				updated_at = EXCLUDED.updated_at, deleted_at = EXCLUDED.deleted_at, txid = pg_current_xact_id()
			WHERE lists.user_id = EXCLUDED.user_id AND lists.updated_at < EXCLUDED.updated_at`,
			l.id, l.userID, l.name, l.desc, l.pos, l.updated, l.deleted)
		if err != nil {
			return nil, fmt.Errorf("list %s: %w", l.id, err)
		}
		s.Written += int(tag.RowsAffected())
	}
	return s, nil
}

func (m *Migrator) migrateListItems(ctx context.Context, tx pgx.Tx) (*Step, error) {
	table, cols, err := m.firstTable(ctx, "user_list_items")
	if err != nil || table == "" {
		return nil, err
	}
	s := &Step{Name: "list_items"}
	// The owner always comes from the list, never from the item row.
	rows, err := m.Src.Query(ctx, fmt.Sprintf(`SELECT i.list_id::text, l.user_id::text, i.movie_id, COALESCE(i.movie_title, ''),
			COALESCE(i.movie_poster_path, ''), COALESCE(to_char(%s, 'YYYY'), ''), %s, %s, %s
		FROM public.user_list_items i JOIN public.user_lists l ON l.id = i.list_id
		WHERE i.movie_id > 0 AND l.user_id IS NOT NULL`,
		prefixed(cols, "i.", col(cols, "movie_release_date", "NULL::date")),
		prefixed(cols, "i.", col(cols, "position", "0")),
		prefixedCoalesce(cols, "i.", "now()", "last_modified_at", "updated_at", "added_at", "created_at"),
		prefixedDeleted(cols, "i.")))
	if err != nil {
		return nil, err
	}
	type item struct {
		listID, userID, title, poster, year string
		tmdbID, pos                         int
		updated                             time.Time
		deleted                             bool
	}
	items, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (item, error) {
		var it item
		return it, r.Scan(&it.listID, &it.userID, &it.tmdbID, &it.title, &it.poster, &it.year, &it.pos, &it.updated, &it.deleted)
	})
	if err != nil {
		return nil, err
	}
	for _, it := range items {
		s.Read++
		var listExists bool
		if err := tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM lists WHERE id = $1 AND user_id = $2)`, it.listID, it.userID).Scan(&listExists); err != nil {
			return nil, err
		}
		if !listExists {
			s.Skipped++
			continue
		}
		tag, err := tx.Exec(ctx, `
			INSERT INTO list_items (list_id, user_id, media_type, tmdb_id, title, poster_path, year, position, updated_at, deleted_at)
			VALUES ($1, $2, 'movie', $3, left($4, 300), left($5, 200), $6, GREATEST($7, 0), $8, CASE WHEN $9 THEN $8::timestamptz END)
			ON CONFLICT (list_id, media_type, tmdb_id) DO UPDATE SET
				title = EXCLUDED.title, poster_path = EXCLUDED.poster_path, year = EXCLUDED.year, position = EXCLUDED.position,
				updated_at = EXCLUDED.updated_at, deleted_at = EXCLUDED.deleted_at, txid = pg_current_xact_id()
			WHERE list_items.updated_at < EXCLUDED.updated_at`,
			it.listID, it.userID, it.tmdbID, it.title, it.poster, it.year, it.pos, it.updated, it.deleted)
		if err != nil {
			return nil, fmt.Errorf("list item %s/%d: %w", it.listID, it.tmdbID, err)
		}
		s.Written += int(tag.RowsAffected())
	}
	return s, nil
}

func (m *Migrator) migrateRatings(ctx context.Context, tx pgx.Tx) (*Step, error) {
	table, cols, err := m.firstTable(ctx, "user_movie_ratings")
	if err != nil || table == "" {
		return nil, err
	}
	s := &Step{Name: "ratings"}
	rows, err := m.Src.Query(ctx, fmt.Sprintf(`SELECT user_id::text, movie_id, COALESCE(rating, 0)::float8, %s,
			COALESCE(movie_title, ''), COALESCE(movie_poster_path, ''), %s, %s
		FROM public.user_movie_ratings WHERE user_id IS NOT NULL AND movie_id > 0`,
		coalesce(cols, "''", "review"),
		coalesce(cols, "now()", "last_modified_at", "updated_at", "rated_at", "created_at"), deletedExpr(cols)))
	if err != nil {
		return nil, err
	}
	type rating struct {
		userID, review, title, poster string
		tmdbID                        int
		score                         float64
		updated                       time.Time
		deleted                       bool
	}
	ratings, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (rating, error) {
		var x rating
		return x, r.Scan(&x.userID, &x.tmdbID, &x.score, &x.review, &x.title, &x.poster, &x.updated, &x.deleted)
	})
	if err != nil {
		return nil, err
	}
	for _, r := range ratings {
		s.Read++
		if !m.users[r.userID] {
			s.Skipped++
			continue
		}
		score := math.Round(r.score*2) / 2 // to the nearest 0.5
		if r.deleted {
			score = 0
		} else if score < 1 || score > 10 {
			s.Skipped++
			s.Notes = append(s.Notes, fmt.Sprintf("rating %s/%d: score %.1f out of range", r.userID, r.tmdbID, r.score))
			continue
		}
		tag, err := tx.Exec(ctx, `
			INSERT INTO ratings (user_id, media_type, tmdb_id, score, review, title, poster_path, updated_at, deleted_at)
			VALUES ($1, 'movie', $2, $3, left($4, 5000), left($5, 300), left($6, 200), $7, CASE WHEN $8 THEN $7::timestamptz END)
			ON CONFLICT (user_id, media_type, tmdb_id) DO UPDATE SET
				score = EXCLUDED.score, review = EXCLUDED.review, title = EXCLUDED.title, poster_path = EXCLUDED.poster_path,
				updated_at = EXCLUDED.updated_at, deleted_at = EXCLUDED.deleted_at, txid = pg_current_xact_id()
			WHERE ratings.updated_at < EXCLUDED.updated_at`,
			r.userID, r.tmdbID, score, r.review, r.title, r.poster, r.updated, r.deleted)
		if err != nil {
			return nil, fmt.Errorf("rating %s/%d: %w", r.userID, r.tmdbID, err)
		}
		s.Written += int(tag.RowsAffected())
	}
	return s, nil
}

// prefixed qualifies a bare column name with a table alias; literals pass through.
func prefixed(cols map[string]bool, prefix, expr string) string {
	if cols[expr] {
		return prefix + expr
	}
	return expr
}

func prefixedCoalesce(cols map[string]bool, prefix, fallback string, candidates ...string) string {
	var parts []string
	for _, c := range candidates {
		if cols[c] {
			parts = append(parts, prefix+c)
		}
	}
	return "COALESCE(" + strings.Join(append(parts, fallback), ", ") + ")"
}

func prefixedDeleted(cols map[string]bool, prefix string) string {
	switch {
	case cols["is_deleted"] && cols["deleted_at"]:
		return "(" + prefix + "is_deleted OR " + prefix + "deleted_at IS NOT NULL)"
	case cols["is_deleted"]:
		return prefix + "is_deleted"
	case cols["deleted_at"]:
		return "(" + prefix + "deleted_at IS NOT NULL)"
	default:
		return "false"
	}
}

func (m *Migrator) log() *slog.Logger {
	if m.Log != nil {
		return m.Log
	}
	return slog.Default()
}
