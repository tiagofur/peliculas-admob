package library

import (
	"context"
	"encoding/json"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tiagofur/peliculas-admob/backend/internal/db"
)

func testService(t *testing.T) (*Service, string, string) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)
	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `TRUNCATE users CASCADE`); err != nil {
		t.Fatal(err)
	}
	var a, b string
	pool.QueryRow(ctx, `INSERT INTO users (email) VALUES ('a@x.com') RETURNING id`).Scan(&a)
	pool.QueryRow(ctx, `INSERT INTO users (email) VALUES ('b@x.com') RETURNING id`).Scan(&b)
	return &Service{DB: pool}, a, b
}

var t0 = time.Date(2026, 11, 7, 12, 0, 0, 0, time.UTC)

func op(entity string, v any) Op {
	b, _ := json.Marshal(v)
	return Op{Entity: entity, Data: b}
}

func push(t *testing.T, s *Service, user string, ops ...Op) []string {
	t.Helper()
	res, err := s.Push(context.Background(), user, ops)
	if err != nil {
		t.Fatal(err)
	}
	out := make([]string, len(res))
	for i, r := range res {
		out[i] = r.Status
	}
	return out
}

func pull(t *testing.T, s *Service, user, cursor string) Changes {
	t.Helper()
	c, err := s.Pull(context.Background(), user, cursor)
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func fav(id int, at time.Time) LibraryItem {
	return LibraryItem{Kind: "favorite", MediaType: "movie", TMDBID: id, Title: "Fight Club", PosterPath: "/p.jpg", Year: "1999", UpdatedAt: at}
}

func TestPushPullAndCursor(t *testing.T) {
	s, a, _ := testService(t)
	if got := push(t, s, a, op("library", fav(550, t0)), op("library", fav(551, t0))); got[0] != "applied" || got[1] != "applied" {
		t.Fatalf("push: %v", got)
	}
	c := pull(t, s, a, "")
	if len(c.Library) != 2 || c.Library[0].Title != "Fight Club" || c.HasMore {
		t.Fatalf("first pull: %+v", c)
	}
	if again := pull(t, s, a, c.Cursor); len(again.Library) != 0 {
		t.Fatalf("nothing new expected, got %d", len(again.Library))
	}
	push(t, s, a, op("library", fav(552, t0)))
	if next := pull(t, s, a, c.Cursor); len(next.Library) != 1 || next.Library[0].TMDBID != 552 {
		t.Fatalf("incremental pull: %+v", next.Library)
	}
}

func TestLastWriteWins(t *testing.T) {
	s, a, _ := testService(t)
	push(t, s, a, op("library", fav(1, t0)))

	older := fav(1, t0.Add(-time.Minute))
	older.Deleted = true
	if got := push(t, s, a, op("library", older)); got[0] != "stale" {
		t.Fatalf("older delete should lose: %v", got)
	}
	newer := fav(1, t0.Add(time.Minute))
	newer.Deleted = true
	if got := push(t, s, a, op("library", newer)); got[0] != "applied" {
		t.Fatalf("newer delete should win: %v", got)
	}
	c := pull(t, s, a, "")
	if len(c.Library) != 1 || !c.Library[0].Deleted {
		t.Fatalf("tombstone expected: %+v", c.Library)
	}
	// Re-adding later brings it back, keeping the snapshot.
	back := LibraryItem{Kind: "favorite", MediaType: "movie", TMDBID: 1, UpdatedAt: t0.Add(2 * time.Minute)}
	push(t, s, a, op("library", back))
	c = pull(t, s, a, "")
	if c.Library[0].Deleted || c.Library[0].Title != "Fight Club" {
		t.Fatalf("restored item: %+v", c.Library[0])
	}
}

func TestFutureClockIsClamped(t *testing.T) {
	s, a, _ := testService(t)
	now := time.Now()
	s.Now = func() time.Time { return now }
	push(t, s, a, op("library", fav(9, now.Add(24*time.Hour))))
	c := pull(t, s, a, "")
	if !c.Library[0].UpdatedAt.Equal(now.Truncate(time.Microsecond)) {
		t.Fatalf("future time should be clamped to now: %v", c.Library[0].UpdatedAt)
	}
	// A device with a normal clock can still overwrite it later.
	later := fav(9, now.Add(time.Second))
	later.Deleted = true
	if got := push(t, s, a, op("library", later)); got[0] != "applied" {
		t.Fatalf("got %v", got)
	}
}

func TestInvalidOpsAreSkipped(t *testing.T) {
	s, a, _ := testService(t)
	got := push(t, s, a,
		op("library", LibraryItem{Kind: "loved", MediaType: "movie", TMDBID: 1}),
		op("library", LibraryItem{Kind: "watchlist", MediaType: "book", TMDBID: 1}),
		op("library", LibraryItem{Kind: "watchlist", MediaType: "movie", TMDBID: 1 << 40}),
		op("rating", Rating{MediaType: "movie", TMDBID: 1, Score: 11}),
		op("episode", Episode{TVID: 1, Season: 1, Episode: 0}),
		op("nope", nil),
		Op{Entity: "library", Data: json.RawMessage(`"not an object"`)},
		op("library", fav(2, t0)),
	)
	want := []string{"invalid", "invalid", "invalid", "invalid", "invalid", "invalid", "invalid", "applied"}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("op %d: got %s want %s (%v)", i, got[i], want[i], got)
		}
	}
}

func TestListsAndOwnership(t *testing.T) {
	s, a, b := testService(t)
	listID := "8f14e45f-ceea-467a-9a3c-1b2c3d4e5f60"
	list := List{ID: listID, Name: "Terror", UpdatedAt: t0}
	item := ListItem{ListID: listID, MediaType: "movie", TMDBID: 694, Title: "The Shining", UpdatedAt: t0}
	if got := push(t, s, a, op("list", list), op("list_item", item)); got[0] != "applied" || got[1] != "applied" {
		t.Fatalf("create: %v", got)
	}

	// Another user can neither add to nor take over the list.
	hijack := List{ID: listID, Name: "mine now", UpdatedAt: t0.Add(time.Hour)}
	intruder := ListItem{ListID: listID, MediaType: "movie", TMDBID: 1, UpdatedAt: t0.Add(time.Hour)}
	if got := push(t, s, b, op("list", hijack), op("list_item", intruder)); got[0] != "invalid" || got[1] != "invalid" {
		t.Fatalf("other user: %v", got)
	}
	if c := pull(t, s, b, ""); len(c.Lists)+len(c.ListItems) != 0 {
		t.Fatalf("other user must see nothing: %+v", c)
	}

	// Deleting the list deletes its items for every device.
	del := List{ID: listID, UpdatedAt: t0.Add(time.Minute), Deleted: true}
	if got := push(t, s, a, op("list", del)); got[0] != "applied" {
		t.Fatalf("delete: %v", got)
	}
	c := pull(t, s, a, "")
	if len(c.Lists) != 1 || !c.Lists[0].Deleted || c.Lists[0].Name != "Terror" && c.Lists[0].Name != "" {
		t.Fatalf("list tombstone: %+v", c.Lists)
	}
	if len(c.ListItems) != 1 || !c.ListItems[0].Deleted {
		t.Fatalf("item tombstone: %+v", c.ListItems)
	}
	if got := push(t, s, a, op("list_item", ListItem{ListID: "8f14e45f-0000-0000-0000-000000000000", MediaType: "tv", TMDBID: 1})); got[0] != "invalid" {
		t.Fatalf("unknown list: %v", got)
	}
}

func TestRatingsAndEpisodes(t *testing.T) {
	s, a, _ := testService(t)
	got := push(t, s, a,
		op("rating", Rating{MediaType: "tv", TMDBID: 1399, Score: 9, Review: "Épica", UpdatedAt: t0}),
		op("episode", Episode{TVID: 1399, Season: 1, Episode: 1, UpdatedAt: t0}),
		op("episode", Episode{TVID: 1399, Season: 1, Episode: 2, WatchedAt: t0.Add(-time.Hour), UpdatedAt: t0}),
	)
	if got[0] != "applied" || got[1] != "applied" || got[2] != "applied" {
		t.Fatalf("push: %v", got)
	}
	c := pull(t, s, a, "")
	if len(c.Ratings) != 1 || c.Ratings[0].Score != 9 || c.Ratings[0].Review != "Épica" {
		t.Fatalf("ratings: %+v", c.Ratings)
	}
	if len(c.Episodes) != 2 || !c.Episodes[0].WatchedAt.Equal(t0) && !c.Episodes[1].WatchedAt.Equal(t0) {
		t.Fatalf("episodes: %+v", c.Episodes)
	}
	unrate := Rating{MediaType: "tv", TMDBID: 1399, UpdatedAt: t0.Add(time.Minute), Deleted: true}
	if got := push(t, s, a, op("rating", unrate)); got[0] != "applied" {
		t.Fatalf("delete rating: %v", got)
	}
}

func TestInFlightWriteIsNotSkipped(t *testing.T) {
	s, a, _ := testService(t)
	ctx := context.Background()

	// A write that is still running while another device pulls...
	tx, err := s.DB.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := tx.Exec(ctx, `INSERT INTO library_items (user_id, kind, media_type, tmdb_id, updated_at)
		VALUES ($1, 'watchlist', 'movie', 42, now())`, a); err != nil {
		t.Fatal(err)
	}
	push(t, s, a, op("library", fav(7, t0))) // a later transaction commits first
	c := pull(t, s, a, "")
	if len(c.Library) != 1 {
		t.Fatalf("only the committed row is visible: %+v", c.Library)
	}
	if err := tx.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	// ...must still reach the device on its next pull.
	next := pull(t, s, a, c.Cursor)
	found := false
	for _, it := range next.Library {
		found = found || it.TMDBID == 42
	}
	if !found {
		t.Fatalf("in-flight row was skipped: %+v", next.Library)
	}
}

func TestPaging(t *testing.T) {
	s, a, _ := testService(t)
	old := PageSize
	PageSize = 2
	t.Cleanup(func() { PageSize = old })

	for i := 1; i <= 5; i++ { // one transaction each, so txids differ
		push(t, s, a, op("library", fav(i, t0)))
	}
	seen := map[int]bool{}
	cursor := ""
	for range 10 {
		c := pull(t, s, a, cursor)
		for _, it := range c.Library {
			seen[it.TMDBID] = true
		}
		cursor = c.Cursor
		if !c.HasMore {
			break
		}
	}
	if len(seen) != 5 {
		t.Fatalf("paging lost rows: %v", seen)
	}
}

func TestBadCursor(t *testing.T) {
	s, a, _ := testService(t)
	if _, err := s.Pull(context.Background(), a, "abc"); err != ErrBadCursor {
		t.Fatalf("got %v", err)
	}
}

func TestTooManyOps(t *testing.T) {
	s, a, _ := testService(t)
	ops := make([]Op, MaxOps+1)
	if _, err := s.Push(context.Background(), a, ops); err == nil {
		t.Fatal("expected error")
	}
}

func TestAccountDeletionRemovesLibrary(t *testing.T) {
	s, a, _ := testService(t)
	push(t, s, a, op("library", fav(1, t0)), op("list", List{ID: "11111111-1111-1111-1111-111111111111", Name: "x", UpdatedAt: t0}))
	if _, err := s.DB.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, a); err != nil {
		t.Fatal(err)
	}
	var n int
	s.DB.QueryRow(context.Background(), `SELECT (SELECT count(*) FROM library_items) + (SELECT count(*) FROM lists)`).Scan(&n)
	if n != 0 {
		t.Fatalf("rows left after delete: %d", n)
	}
}
