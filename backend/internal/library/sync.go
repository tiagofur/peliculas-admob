// Package library stores each user's favorites, watchlist, watched titles,
// custom lists, ratings and watched episodes, and syncs them across devices.
//
// Protocol:
//   - Push: the device sends a batch of changes, each with its own updated_at.
//     Last write wins per row; deletions are tombstones.
//   - Pull: the device sends the cursor it got last time and receives every
//     row written since. Rows may repeat across pulls; applying them is idempotent.
//
// The cursor is a Postgres transaction id (xid8). A pull returns rows whose
// txid >= cursor and hands back the snapshot xmin as the next cursor, so a
// transaction that was still running during the pull is never skipped.
package library

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const MaxOps = 500

// PageSize must stay well above the rows one transaction can write
// (MaxOps, or one list's items when the list is deleted), or paging stalls.
// A var only so tests can shrink it.
var PageSize = 5000

const (
	// How far in the future a device clock may be before we clamp it.
	clockSkew = 5 * time.Minute
)

var ErrBadCursor = errors.New("library: invalid cursor")

type Service struct {
	DB  *pgxpool.Pool
	Now func() time.Time
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// ---- entities (same shape for push data and pull rows) ----

type LibraryItem struct {
	Kind       string    `json:"kind"` // favorite | watchlist | watched
	MediaType  string    `json:"media_type"`
	TMDBID     int       `json:"tmdb_id"`
	Title      string    `json:"title"`
	PosterPath string    `json:"poster_path"`
	Year       string    `json:"year"`
	UpdatedAt  time.Time `json:"updated_at"`
	Deleted    bool      `json:"deleted"`
}

type List struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Position    int       `json:"position"`
	UpdatedAt   time.Time `json:"updated_at"`
	Deleted     bool      `json:"deleted"`
}

type ListItem struct {
	ListID     string    `json:"list_id"`
	MediaType  string    `json:"media_type"`
	TMDBID     int       `json:"tmdb_id"`
	Title      string    `json:"title"`
	PosterPath string    `json:"poster_path"`
	Year       string    `json:"year"`
	Position   int       `json:"position"`
	UpdatedAt  time.Time `json:"updated_at"`
	Deleted    bool      `json:"deleted"`
}

type Rating struct {
	MediaType  string    `json:"media_type"`
	TMDBID     int       `json:"tmdb_id"`
	Score      int       `json:"score"` // 1..10
	Review     string    `json:"review"`
	Title      string    `json:"title"`
	PosterPath string    `json:"poster_path"`
	UpdatedAt  time.Time `json:"updated_at"`
	Deleted    bool      `json:"deleted"`
}

type Episode struct {
	TVID      int       `json:"tv_id"`
	Season    int       `json:"season"`
	Episode   int       `json:"episode"`
	WatchedAt time.Time `json:"watched_at"`
	UpdatedAt time.Time `json:"updated_at"`
	Deleted   bool      `json:"deleted"`
}

// ---- push ----

// Op is one change from a device.
type Op struct {
	Entity string          `json:"entity"` // library | list | list_item | rating | episode
	Data   json.RawMessage `json:"data"`
}

type OpResult struct {
	Index  int    `json:"index"`
	Status string `json:"status"` // applied | stale | invalid
	Error  string `json:"error,omitempty"`
}

type invalidError string

func (e invalidError) Error() string { return string(e) }

func invalid(format string, a ...any) error { return invalidError(fmt.Sprintf(format, a...)) }

// Push applies ops in order inside one transaction. Invalid ops are reported
// and skipped; database errors fail the whole batch.
func (s *Service) Push(ctx context.Context, userID string, ops []Op) ([]OpResult, error) {
	if len(ops) > MaxOps {
		return nil, invalid("too many ops: max %d", MaxOps)
	}
	tx, err := s.DB.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	results := make([]OpResult, len(ops))
	for i, op := range ops {
		applied, err := s.apply(ctx, tx, userID, op)
		var inv invalidError
		switch {
		case errors.As(err, &inv):
			results[i] = OpResult{Index: i, Status: "invalid", Error: inv.Error()}
		case err != nil:
			return nil, fmt.Errorf("op %d: %w", i, err)
		case applied:
			results[i] = OpResult{Index: i, Status: "applied"}
		default:
			results[i] = OpResult{Index: i, Status: "stale"}
		}
	}
	return results, tx.Commit(ctx)
}

func (s *Service) apply(ctx context.Context, tx pgx.Tx, userID string, op Op) (bool, error) {
	switch op.Entity {
	case "library":
		var v LibraryItem
		if err := decode(op.Data, &v); err != nil {
			return false, err
		}
		return s.applyLibrary(ctx, tx, userID, v)
	case "list":
		var v List
		if err := decode(op.Data, &v); err != nil {
			return false, err
		}
		return s.applyList(ctx, tx, userID, v)
	case "list_item":
		var v ListItem
		if err := decode(op.Data, &v); err != nil {
			return false, err
		}
		return s.applyListItem(ctx, tx, userID, v)
	case "rating":
		var v Rating
		if err := decode(op.Data, &v); err != nil {
			return false, err
		}
		return s.applyRating(ctx, tx, userID, v)
	case "episode":
		var v Episode
		if err := decode(op.Data, &v); err != nil {
			return false, err
		}
		return s.applyEpisode(ctx, tx, userID, v)
	default:
		return false, invalid("unknown entity %q", op.Entity)
	}
}

func decode(raw json.RawMessage, dst any) error {
	if err := json.Unmarshal(raw, dst); err != nil {
		return invalid("bad data: %v", err)
	}
	return nil
}

// stamp clamps future clocks and returns updated_at and the tombstone time.
func (s *Service) stamp(updated time.Time, deleted bool) (time.Time, *time.Time) {
	now := s.now()
	if updated.IsZero() || updated.After(now.Add(clockSkew)) {
		updated = now
	}
	if deleted {
		return updated, &updated
	}
	return updated, nil
}

func (s *Service) applyLibrary(ctx context.Context, tx pgx.Tx, userID string, v LibraryItem) (bool, error) {
	if v.Kind != "favorite" && v.Kind != "watchlist" && v.Kind != "watched" {
		return false, invalid("kind must be favorite, watchlist or watched")
	}
	if err := checkMedia(v.MediaType, v.TMDBID); err != nil {
		return false, err
	}
	if err := checkSnapshot(v.Title, v.PosterPath, v.Year); err != nil {
		return false, err
	}
	upd, del := s.stamp(v.UpdatedAt, v.Deleted)
	tag, err := tx.Exec(ctx, `
		INSERT INTO library_items (user_id, kind, media_type, tmdb_id, title, poster_path, year, updated_at, deleted_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (user_id, kind, media_type, tmdb_id) DO UPDATE SET
			title = CASE WHEN EXCLUDED.title <> '' THEN EXCLUDED.title ELSE library_items.title END,
			poster_path = CASE WHEN EXCLUDED.poster_path <> '' THEN EXCLUDED.poster_path ELSE library_items.poster_path END,
			year = CASE WHEN EXCLUDED.year <> '' THEN EXCLUDED.year ELSE library_items.year END,
			updated_at = EXCLUDED.updated_at, deleted_at = EXCLUDED.deleted_at, txid = pg_current_xact_id()
		WHERE library_items.updated_at < EXCLUDED.updated_at`,
		userID, v.Kind, v.MediaType, v.TMDBID, v.Title, v.PosterPath, v.Year, upd, del)
	return tag.RowsAffected() > 0, err
}

func (s *Service) applyList(ctx context.Context, tx pgx.Tx, userID string, v List) (bool, error) {
	if !isUUID(v.ID) {
		return false, invalid("list id must be a UUID")
	}
	if v.Position < 0 || v.Position > math.MaxInt32 {
		return false, invalid("position out of range")
	}
	if !v.Deleted && strings.TrimSpace(v.Name) == "" {
		return false, invalid("list name is required")
	}
	if err := checkText(v.Name, 100, "name"); err != nil {
		return false, err
	}
	if err := checkText(v.Description, 500, "description"); err != nil {
		return false, err
	}
	upd, del := s.stamp(v.UpdatedAt, v.Deleted)
	// The user_id check stops a device from overwriting someone else's list by ID.
	var owner string
	err := tx.QueryRow(ctx, `
		INSERT INTO lists (id, user_id, name, description, position, updated_at, deleted_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (id) DO UPDATE SET
			name = EXCLUDED.name, description = EXCLUDED.description, position = EXCLUDED.position,
			updated_at = EXCLUDED.updated_at, deleted_at = EXCLUDED.deleted_at, txid = pg_current_xact_id()
		WHERE lists.user_id = EXCLUDED.user_id AND lists.updated_at < EXCLUDED.updated_at
		RETURNING user_id`,
		v.ID, userID, strings.TrimSpace(v.Name), v.Description, v.Position, upd, del).Scan(&owner)
	if errors.Is(err, pgx.ErrNoRows) {
		if err := s.checkListOwner(ctx, tx, userID, v.ID); err != nil {
			return false, err
		}
		return false, nil // stale
	}
	if err != nil {
		return false, err
	}
	if del != nil { // deleting a list deletes its items too
		_, err = tx.Exec(ctx, `UPDATE list_items SET deleted_at = $2, updated_at = $2, txid = pg_current_xact_id()
			WHERE list_id = $1 AND deleted_at IS NULL AND updated_at < $2`, v.ID, upd)
	}
	return true, err
}

func (s *Service) checkListOwner(ctx context.Context, tx pgx.Tx, userID, listID string) error {
	var owner string
	err := tx.QueryRow(ctx, `SELECT user_id FROM lists WHERE id = $1`, listID).Scan(&owner)
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && owner != userID) {
		return invalid("unknown list")
	}
	return err
}

func (s *Service) applyListItem(ctx context.Context, tx pgx.Tx, userID string, v ListItem) (bool, error) {
	if !isUUID(v.ListID) {
		return false, invalid("list_id must be a UUID")
	}
	if err := checkMedia(v.MediaType, v.TMDBID); err != nil {
		return false, err
	}
	if err := checkSnapshot(v.Title, v.PosterPath, v.Year); err != nil {
		return false, err
	}
	if v.Position < 0 || v.Position > math.MaxInt32 {
		return false, invalid("position out of range")
	}
	if err := s.checkListOwner(ctx, tx, userID, v.ListID); err != nil {
		return false, err
	}
	upd, del := s.stamp(v.UpdatedAt, v.Deleted)
	tag, err := tx.Exec(ctx, `
		INSERT INTO list_items (list_id, user_id, media_type, tmdb_id, title, poster_path, year, position, updated_at, deleted_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		ON CONFLICT (list_id, media_type, tmdb_id) DO UPDATE SET
			title = CASE WHEN EXCLUDED.title <> '' THEN EXCLUDED.title ELSE list_items.title END,
			poster_path = CASE WHEN EXCLUDED.poster_path <> '' THEN EXCLUDED.poster_path ELSE list_items.poster_path END,
			year = CASE WHEN EXCLUDED.year <> '' THEN EXCLUDED.year ELSE list_items.year END,
			position = EXCLUDED.position,
			updated_at = EXCLUDED.updated_at, deleted_at = EXCLUDED.deleted_at, txid = pg_current_xact_id()
		WHERE list_items.updated_at < EXCLUDED.updated_at`,
		v.ListID, userID, v.MediaType, v.TMDBID, v.Title, v.PosterPath, v.Year, v.Position, upd, del)
	return tag.RowsAffected() > 0, err
}

func (s *Service) applyRating(ctx context.Context, tx pgx.Tx, userID string, v Rating) (bool, error) {
	if err := checkMedia(v.MediaType, v.TMDBID); err != nil {
		return false, err
	}
	if !v.Deleted && (v.Score < 1 || v.Score > 10) {
		return false, invalid("score must be 1..10")
	}
	if v.Deleted {
		v.Score = 0
	}
	if err := checkText(v.Review, 5000, "review"); err != nil {
		return false, err
	}
	if err := checkSnapshot(v.Title, v.PosterPath, ""); err != nil {
		return false, err
	}
	upd, del := s.stamp(v.UpdatedAt, v.Deleted)
	tag, err := tx.Exec(ctx, `
		INSERT INTO ratings (user_id, media_type, tmdb_id, score, review, title, poster_path, updated_at, deleted_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (user_id, media_type, tmdb_id) DO UPDATE SET
			score = EXCLUDED.score, review = EXCLUDED.review,
			title = CASE WHEN EXCLUDED.title <> '' THEN EXCLUDED.title ELSE ratings.title END,
			poster_path = CASE WHEN EXCLUDED.poster_path <> '' THEN EXCLUDED.poster_path ELSE ratings.poster_path END,
			updated_at = EXCLUDED.updated_at, deleted_at = EXCLUDED.deleted_at, txid = pg_current_xact_id()
		WHERE ratings.updated_at < EXCLUDED.updated_at`,
		userID, v.MediaType, v.TMDBID, v.Score, v.Review, v.Title, v.PosterPath, upd, del)
	return tag.RowsAffected() > 0, err
}

func (s *Service) applyEpisode(ctx context.Context, tx pgx.Tx, userID string, v Episode) (bool, error) {
	if v.TVID <= 0 || v.Season < 0 || v.Season > 1000 || v.Episode < 1 || v.Episode > 10000 {
		return false, invalid("bad tv_id/season/episode")
	}
	upd, del := s.stamp(v.UpdatedAt, v.Deleted)
	if v.WatchedAt.IsZero() || v.WatchedAt.After(upd) {
		v.WatchedAt = upd
	}
	tag, err := tx.Exec(ctx, `
		INSERT INTO watched_episodes (user_id, tv_id, season, episode, watched_at, updated_at, deleted_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (user_id, tv_id, season, episode) DO UPDATE SET
			watched_at = EXCLUDED.watched_at,
			updated_at = EXCLUDED.updated_at, deleted_at = EXCLUDED.deleted_at, txid = pg_current_xact_id()
		WHERE watched_episodes.updated_at < EXCLUDED.updated_at`,
		userID, v.TVID, v.Season, v.Episode, v.WatchedAt, upd, del)
	return tag.RowsAffected() > 0, err
}

// ---- pull ----

type Changes struct {
	Cursor    string        `json:"cursor"`
	HasMore   bool          `json:"has_more"`
	Library   []LibraryItem `json:"library"`
	Lists     []List        `json:"lists"`
	ListItems []ListItem    `json:"list_items"`
	Ratings   []Rating      `json:"ratings"`
	Episodes  []Episode     `json:"episodes"`
}

// Pull returns every row written since cursor ("" or "0" = everything).
func (s *Service) Pull(ctx context.Context, userID, cursor string) (Changes, error) {
	since := uint64(0)
	if cursor != "" {
		var err error
		if since, err = strconv.ParseUint(cursor, 10, 64); err != nil {
			return Changes{}, ErrBadCursor
		}
	}
	tx, err := s.DB.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.RepeatableRead, AccessMode: pgx.ReadOnly})
	if err != nil {
		return Changes{}, err
	}
	defer tx.Rollback(ctx)

	var xminText string
	if err := tx.QueryRow(ctx, `SELECT pg_snapshot_xmin(pg_current_snapshot())::text`).Scan(&xminText); err != nil {
		return Changes{}, err
	}
	next, _ := strconv.ParseUint(xminText, 10, 64)

	c := Changes{Library: []LibraryItem{}, Lists: []List{}, ListItems: []ListItem{}, Ratings: []Rating{}, Episodes: []Episode{}}
	// page reads one table. Every query selects txid::text as its last column;
	// fields gives the destinations for the other columns of a fresh row and
	// keep stores the row once scanned.
	page := func(sql string, fields func() []any, keep func()) error {
		rows, err := tx.Query(ctx, sql+` AND txid >= $2::text::xid8 ORDER BY txid LIMIT $3`,
			userID, strconv.FormatUint(since, 10), PageSize+1)
		if err != nil {
			return err
		}
		defer rows.Close()
		var n int
		var last uint64
		for rows.Next() {
			if n++; n > PageSize {
				// More than one page: resume from the last txid sent.
				c.HasMore = true
				next = min(next, last)
				break
			}
			var txid string
			if err := rows.Scan(append(fields(), &txid)...); err != nil {
				return err
			}
			if last, err = strconv.ParseUint(txid, 10, 64); err != nil {
				return err
			}
			keep()
		}
		return rows.Err()
	}

	var li LibraryItem
	var l List
	var it ListItem
	var r Rating
	var e Episode
	err = errors.Join(
		page(`SELECT kind, media_type, tmdb_id, title, poster_path, year, updated_at, deleted_at IS NOT NULL, txid::text
			FROM library_items WHERE user_id = $1`,
			func() []any {
				li = LibraryItem{}
				return []any{&li.Kind, &li.MediaType, &li.TMDBID, &li.Title, &li.PosterPath, &li.Year, &li.UpdatedAt, &li.Deleted}
			},
			func() { c.Library = append(c.Library, li) }),
		page(`SELECT id::text, name, description, position, updated_at, deleted_at IS NOT NULL, txid::text
			FROM lists WHERE user_id = $1`,
			func() []any {
				l = List{}
				return []any{&l.ID, &l.Name, &l.Description, &l.Position, &l.UpdatedAt, &l.Deleted}
			},
			func() { c.Lists = append(c.Lists, l) }),
		page(`SELECT list_id::text, media_type, tmdb_id, title, poster_path, year, position, updated_at, deleted_at IS NOT NULL, txid::text
			FROM list_items WHERE user_id = $1`,
			func() []any {
				it = ListItem{}
				return []any{&it.ListID, &it.MediaType, &it.TMDBID, &it.Title, &it.PosterPath, &it.Year, &it.Position, &it.UpdatedAt, &it.Deleted}
			},
			func() { c.ListItems = append(c.ListItems, it) }),
		page(`SELECT media_type, tmdb_id, score, review, title, poster_path, updated_at, deleted_at IS NOT NULL, txid::text
			FROM ratings WHERE user_id = $1`,
			func() []any {
				r = Rating{}
				return []any{&r.MediaType, &r.TMDBID, &r.Score, &r.Review, &r.Title, &r.PosterPath, &r.UpdatedAt, &r.Deleted}
			},
			func() { c.Ratings = append(c.Ratings, r) }),
		page(`SELECT tv_id, season, episode, watched_at, updated_at, deleted_at IS NOT NULL, txid::text
			FROM watched_episodes WHERE user_id = $1`,
			func() []any {
				e = Episode{}
				return []any{&e.TVID, &e.Season, &e.Episode, &e.WatchedAt, &e.UpdatedAt, &e.Deleted}
			},
			func() { c.Episodes = append(c.Episodes, e) }),
	)
	if err != nil {
		return Changes{}, err
	}
	c.Cursor = strconv.FormatUint(next, 10)
	return c, nil
}

// ---- validation ----

func checkMedia(mediaType string, tmdbID int) error {
	if mediaType != "movie" && mediaType != "tv" {
		return invalid("media_type must be movie or tv")
	}
	if tmdbID <= 0 || tmdbID > math.MaxInt32 {
		return invalid("tmdb_id out of range")
	}
	return nil
}

func checkSnapshot(title, poster, year string) error {
	return errors.Join(checkText(title, 300, "title"), checkText(poster, 200, "poster_path"), checkText(year, 10, "year"))
}

func checkText(v string, max int, field string) error {
	if !utf8.ValidString(v) || utf8.RuneCountInString(v) > max || strings.ContainsRune(v, 0) {
		return invalid("%s is invalid or longer than %d", field, max)
	}
	return nil
}

func isUUID(s string) bool {
	if len(s) != 36 {
		return false
	}
	for i, ch := range s {
		switch {
		case i == 8 || i == 13 || i == 18 || i == 23:
			if ch != '-' {
				return false
			}
		case !strings.ContainsRune("0123456789abcdefABCDEF", ch):
			return false
		}
	}
	return true
}
