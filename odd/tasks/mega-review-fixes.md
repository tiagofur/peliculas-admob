# Mega Review — Fix Phase: Cluster A (sync destructive writes)

Objective: eliminate data-loss bugs in sync/caching (audit Rank 1). Each fix: RED test first, minimal fix, GREEN, no regressions. Branch: current. Delivery: ask-on-risk. Runner: `flutter test <focused>`, `dart analyze`, full suite at close.

## Specs

- S1: "F1 simple_favorites_sync.dart:116 (:95 fallback, :126-136 isFavorite no movie_id filter) — remove-one deletes all"
- S2: "F2 cache_service.dart:68-71 clear() on shared prefs, :85-112 clearExpired removes non-envelope keys incl. sync queue"
- S3: "F3 favorite_movies_hive_datasource.dart:131-134 clear-all-as-expired, :174 add() vs :46 put dupes, :164 deleteAt first-only (same pattern GeneralMoviesHiveDatasource:97-99)"
- S4: "F8 trigger_free_watchlist_sync.dart:114-120 version=1 reset, unified_sync_base.dart:230-236 DELETE+INSERT reset, trigger_free_favorites_sync.dart:29-42 / trigger_free_watchlist_sync.dart:55-69 upsert w/o onConflict (vs correct :91-95), :112-127 hard-DELETE vs is_deleted reads"
- S5: "F11 migrations/20250101_clean_reset_user_lists.sql:16 TRUNCATE user_lists CASCADE, custom_lists_hive_datasource.dart:68-91 clear-then-readd swallowed, fallback-box orphaning (watched_movies_hive_datasource.dart:43-54, isar_datasource.dart:53-58), dual rating boxes diverge"

## Tasks

- [ ] T1 (S1-S5): verify every claim against current code — route: delegated explorer — status: in_progress — evidence: pending
- [ ] T2 (S1): fix favorites remove-one + isFavorite filter — route: inline — status: pending — evidence: pending
- [ ] T3 (S2): scope cache_service clear/clearExpired — route: inline — status: pending — evidence: pending
- [ ] T4 (S3): fix Hive datasource mutations — route: inline — status: pending — evidence: pending
- [ ] T5 (S4): fix trigger_free version/upsert/delete — route: inline — status: pending — evidence: pending
- [x] T6 (S5): migration + custom_lists + orphaning + ratings — route: inline — status: completed — evidence: TRUNCATE left untouched (applied one-shot history; forward-fix = unique index already in file); custom_lists cacheLists rewritten merge-first (contract test green); watched+isar fallback forks replaced by deleteBoxFromDisk+reopen repair with serialized init (red/green repair test); dual ratings boxes DEFERRED (different entities, needs own design part)
- [x] T7 (S1-S5): full verification — route: inline — status: completed — evidence: 19 new focused tests green (3 simple_favorites RED→GREEN, 4 cache_service, 4 hive favs incl. legacy sweep, 5 trigger_free onConflict/is_deleted/version, 1 watched repair RED→GREEN, 1 custom_lists merge, 1 slideshow); analyze 0 errors; full suite +287/-65 (same 65 pre-existing, +19 new green, zero regressions)
- L3 (2026-11-05): T2-T6 fixes applied with red/green tests where observable; _fallbackSave version + hard-DELETE-vs-tombstone documented as evaluated-not-changed (Cluster D territory); removeFavoriteById indexWhere+deleteAt judged CORRECT (same-order delete) but replaced by key-based delete + legacy sweep anyway.

## Log

- L1 (2026-11-05): user: "empezamos, haremos todo asi que elige como prefiereras" — elected order: audit rank order, starting Rank 1 (data loss).
- L2 (2026-11-05): audit claims above are UNVERIFIED subagent output (read-only, no reproduction); T1 must confirm/refute each with path:line evidence before any fix.
