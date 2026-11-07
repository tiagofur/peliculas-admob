package push

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"strconv"
	"time"

	"github.com/tiagofur/peliculas-admob/backend/internal/tmdb"
)

// Shows reads TMDB through our cache (tmdb.Proxy).
type Shows interface {
	Get(ctx context.Context, path string, q url.Values) (tmdb.Result, error)
}

// EpisodeJob tells users when a new episode of a show they follow airs.
//
// A user follows a show if it is in their library (any list) or they have
// watched one of its episodes. Each run, for every followed show, it reads
// last_episode_to_air from TMDB (cached) and alerts each follower once, from
// AlertHour in their own timezone on the air date, or the next day if missed.
// Episodes the user already marked as watched are skipped.
type EpisodeJob struct {
	Push      *Service
	Shows     Shows
	ProOnly   bool // alerts are a Pro feature
	AlertHour int  // local hour from which "aired today" alerts go out
	Now       func() time.Time
}

type airedEpisode struct {
	AirDate string `json:"air_date"`
	Season  int    `json:"season_number"`
	Episode int    `json:"episode_number"`
	Name    string `json:"name"`
}

type showInfo struct {
	Name string        `json:"name"`
	Last *airedEpisode `json:"last_episode_to_air"`
}

const jobLock = 727275

// Run does one pass and returns how many users were alerted. Only one API
// instance runs it at a time.
func (j *EpisodeJob) Run(ctx context.Context) (int, error) {
	if j.Push.Sender == nil {
		return 0, ErrNotConfigured
	}
	conn, err := j.Push.DB.Acquire(ctx)
	if err != nil {
		return 0, err
	}
	defer conn.Release()
	var locked bool
	if err := conn.QueryRow(ctx, `SELECT pg_try_advisory_lock($1)`, jobLock).Scan(&locked); err != nil || !locked {
		return 0, err
	}
	defer conn.Exec(context.WithoutCancel(ctx), `SELECT pg_advisory_unlock($1)`, jobLock)

	rows, err := conn.Query(ctx, `
		WITH active AS (
			SELECT DISTINCT ON (user_id) user_id, timezone FROM devices
			WHERE disabled_at IS NULL ORDER BY user_id, updated_at DESC
		), eligible AS (
			SELECT a.user_id, a.timezone FROM active a
			WHERE NOT $1 OR EXISTS (
				SELECT 1 FROM entitlements e WHERE e.user_id = a.user_id AND e.revoked_at IS NULL
				AND (e.expires_at IS NULL OR GREATEST(e.expires_at, COALESCE(e.grace_until, e.expires_at)) > now()))
		), follows AS (
			SELECT user_id, tmdb_id AS tv_id FROM library_items WHERE media_type = 'tv' AND deleted_at IS NULL
			UNION
			SELECT user_id, tv_id FROM watched_episodes WHERE deleted_at IS NULL
		)
		SELECT f.user_id::text, e.timezone, f.tv_id FROM follows f JOIN eligible e USING (user_id)`, j.ProOnly)
	if err != nil {
		return 0, err
	}
	type follow struct {
		userID, tz string
		tvID       int
	}
	var follows []follow
	for rows.Next() {
		var f follow
		if err := rows.Scan(&f.userID, &f.tz, &f.tvID); err != nil {
			rows.Close()
			return 0, err
		}
		follows = append(follows, f)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return 0, err
	}

	shows := map[string]*showInfo{} // key: tvID/lang
	show := func(tvID int, lang string) *showInfo {
		key := strconv.Itoa(tvID) + "/" + lang
		if s, ok := shows[key]; ok {
			return s
		}
		var info *showInfo
		res, err := j.Shows.Get(ctx, "/tv/"+strconv.Itoa(tvID), url.Values{"language": {tmdbLanguage(lang)}})
		if err == nil && res.Status == http.StatusOK {
			var s showInfo
			if json.Unmarshal(res.Body, &s) == nil {
				info = &s
			}
		} else if err != nil {
			j.Push.log().Warn("episode job: tmdb", "tv", tvID, "err", err)
		}
		shows[key] = info
		return info
	}

	now := j.now()
	alerted := 0
	for _, f := range follows {
		info := show(f.tvID, "es")
		if info == nil || info.Last == nil || !j.due(info.Last.AirDate, f.tz, now) {
			continue
		}
		ep := *info.Last
		ok, err := j.alertOnce(ctx, f.userID, f.tvID, ep, func(l string) Alert {
			named := show(f.tvID, l)
			title, epName := info.Name, ep.Name
			if named != nil {
				title = named.Name
				if named.Last != nil && named.Last.Season == ep.Season && named.Last.Episode == ep.Episode {
					epName = named.Last.Name
				}
			}
			body := fmt.Sprintf(text[l].episode, ep.Season, ep.Episode)
			if epName != "" {
				body = fmt.Sprintf(text[l].episodeNamed, ep.Season, ep.Episode, epName)
			}
			return Alert{
				Title: title, Body: body,
				ThreadID:   fmt.Sprintf("tv-%d", f.tvID),
				CollapseID: fmt.Sprintf("tv-%d-s%de%d", f.tvID, ep.Season, ep.Episode),
				Data: map[string]any{"tv_id": f.tvID, "season": ep.Season, "episode": ep.Episode,
					"url": fmt.Sprintf("peliculas://serie/%d", f.tvID)},
			}
		})
		if err != nil {
			return alerted, err
		}
		if ok {
			alerted++
		}
	}
	return alerted, nil
}

// due: aired today (local) and it is past AlertHour, or aired yesterday.
func (j *EpisodeJob) due(airDate, tz string, now time.Time) bool {
	loc, err := time.LoadLocation(tz)
	if err != nil {
		loc = time.UTC
	}
	aired, err := time.ParseInLocation("2006-01-02", airDate, loc)
	if err != nil {
		return false
	}
	local := now.In(loc)
	today := time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, loc)
	// Round: days around a DST change are 23 or 25 hours long.
	switch days := int(math.Round(today.Sub(aired).Hours() / 24)); days {
	case 0:
		return local.Hour() >= j.AlertHour
	case 1:
		return true
	default:
		return false
	}
}

// alertOnce records the alert first so concurrent or repeated runs never
// double-send, and drops the record if no device accepted it so the next run
// retries.
func (j *EpisodeJob) alertOnce(ctx context.Context, userID string, tvID int, ep airedEpisode, build func(string) Alert) (bool, error) {
	db := j.Push.DB
	var watched bool
	if err := db.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM watched_episodes WHERE user_id = $1 AND tv_id = $2
		AND season = $3 AND episode = $4 AND deleted_at IS NULL)`, userID, tvID, ep.Season, ep.Episode).Scan(&watched); err != nil {
		return false, err
	}
	if watched {
		return false, nil
	}
	tag, err := db.Exec(ctx, `INSERT INTO episode_alerts (user_id, tv_id, season, episode) VALUES ($1, $2, $3, $4)
		ON CONFLICT DO NOTHING`, userID, tvID, ep.Season, ep.Episode)
	if err != nil || tag.RowsAffected() == 0 {
		return false, err
	}
	devices, err := j.Push.devicesOf(ctx, userID)
	if err != nil {
		return false, err
	}
	if j.Push.deliver(ctx, devices, build) > 0 {
		return true, nil
	}
	_, err = db.Exec(ctx, `DELETE FROM episode_alerts WHERE user_id = $1 AND tv_id = $2 AND season = $3 AND episode = $4`,
		userID, tvID, ep.Season, ep.Episode)
	return false, err
}

// Loop runs the job every interval until ctx ends.
func (j *EpisodeJob) Loop(ctx context.Context, every time.Duration) {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		n, err := j.Run(ctx)
		if err != nil {
			j.Push.log().Error("episode job", "err", err)
		} else if n > 0 {
			j.Push.log().Info("episode job", "alerted", n)
		}
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
	}
}

func (j *EpisodeJob) now() time.Time {
	if j.Now != nil {
		return j.Now()
	}
	return time.Now()
}
