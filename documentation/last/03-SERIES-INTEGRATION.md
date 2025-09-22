# 📺 Series Integration Plan

## Overview

Adding TV Series support alongside Movies while maintaining clean UI/UX.

## UI/UX Strategy

### Navigation Approach

```
Option A: Toggle Switch (Recommended)
┌──────────────────────────────┐
│ [Movies] <-> [Series]   🔍   │
├──────────────────────────────┤
│                              │
│     Content Area            │
│                              │
└──────────────────────────────┘

Option B: Tab Bar
┌──────────────────────────────┐
│  Movies  |  Series  |  Both  │
├──────────────────────────────┤
│                              │
└──────────────────────────────┘
```

### Data Model Design

```dart
// Shared base class
abstract class MediaItem {
  final int id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String overview;
  final double voteAverage;
  final DateTime? releaseDate;
  final MediaType type;
}

enum MediaType { movie, series }

class Movie extends MediaItem {
  final int runtime;
  final String? tagline;
  // Movie-specific fields
}

class Series extends MediaItem {
  final int numberOfSeasons;
  final int numberOfEpisodes;
  final List<Season> seasons;
  final String? status; // Returning, Ended, Canceled
  final DateTime? firstAirDate;
  final DateTime? lastAirDate;
  // Series-specific fields
}

class Season {
  final int seasonNumber;
  final int episodeCount;
  final String? name;
  final String? overview;
  final DateTime? airDate;
}

class Episode {
  final int episodeNumber;
  final int seasonNumber;
  final String name;
  final String? overview;
  final DateTime? airDate;
  final int? runtime;
}
```

### Database Schema

```sql
-- Series table
CREATE TABLE series (
  id INTEGER PRIMARY KEY,
  trakt_id INTEGER UNIQUE,
  tmdb_id INTEGER,
  imdb_id VARCHAR(20),
  title VARCHAR(255) NOT NULL,
  overview TEXT,
  poster_path VARCHAR(255),
  backdrop_path VARCHAR(255),
  first_air_date DATE,
  last_air_date DATE,
  status VARCHAR(50),
  number_of_seasons INTEGER,
  number_of_episodes INTEGER,
  vote_average DECIMAL(3,1),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- User series tracking
CREATE TABLE user_series (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  series_id INTEGER,
  status VARCHAR(50), -- watching, completed, on_hold, dropped
  current_season INTEGER DEFAULT 1,
  current_episode INTEGER DEFAULT 1,
  rating INTEGER,
  notes TEXT,
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Episodes watched
CREATE TABLE user_episodes_watched (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  series_id INTEGER,
  season_number INTEGER,
  episode_number INTEGER,
  watched_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, series_id, season_number, episode_number)
);
```

### UI Components Needed

1. **SeriesCard** - Similar to MovieCard but with season/episode info
2. **SeasonSelector** - Dropdown or horizontal scroll for seasons
3. **EpisodeList** - List of episodes with watched status
4. **SeriesProgressBar** - Visual progress of watched episodes
5. **NextEpisodeWidget** - Quick access to next unwatched episode

### API Integration (Trakt)

```dart
class TraktSeriesService {
  // Get trending series
  Future<List<Series>> getTrending({int page = 1});

  // Get series details
  Future<Series> getDetails(String traktId);

  // Get season details
  Future<Season> getSeason(String traktId, int seasonNumber);

  // Get episode details
  Future<Episode> getEpisode(
    String traktId,
    int seasonNumber,
    int episodeNumber
  );

  // Mark episode as watched
  Future<void> markEpisodeWatched(
    String traktId,
    int seasonNumber,
    int episodeNumber
  );

  // Get watching progress
  Future<SeriesProgress> getProgress(String traktId);
}
```

### Implementation Phases

#### Phase 1: Basic Series Support (2 weeks)

- [ ] Add Series data models
- [ ] Implement Trakt series API
- [ ] Create basic SeriesCard widget
- [ ] Add series to search results
- [ ] Toggle between movies/series

#### Phase 2: Series Details (1 week)

- [ ] Series details page
- [ ] Season/episode listings
- [ ] Basic tracking (watching/completed)
- [ ] Add to favorites/lists

#### Phase 3: Progress Tracking (1 week)

- [ ] Mark episodes as watched
- [ ] Track watching progress
- [ ] Continue watching section
- [ ] Episode notifications

#### Phase 4: Advanced Features (2 weeks)

- [ ] Calendar view for air dates
- [ ] Seasonal anime tracking
- [ ] Binge tracking statistics
- [ ] Series-specific recommendations

### UI Mockups

```
Series Card:
┌─────────────┐
│   [Image]   │
│             │
├─────────────┤
│ Series Name │
│ S2 E5 ▓▓▓░░│ <- Progress bar
│ ⭐ 8.5  2021│
└─────────────┘

Series Details:
┌──────────────────────┐
│     [Backdrop]       │
├──────────────────────┤
│ Title         ⭐ 8.5 │
│ 5 Seasons • Ongoing  │
├──────────────────────┤
│ [S1][S2][S3][S4][S5] │ <- Season selector
├──────────────────────┤
│ Episodes:            │
│ □ E01 - Pilot        │
│ ✓ E02 - Chapter 2    │
│ ✓ E03 - Chapter 3    │
│ □ E04 - Chapter 4    │
└──────────────────────┘
```

### Challenges & Solutions

1. **Data Volume**: Series have many more entities (seasons, episodes)

   - Solution: Lazy load episodes, cache aggressively

2. **Complex State**: Tracking per-episode watched status

   - Solution: Efficient local storage, batch sync operations

3. **UI Complexity**: More information to display

   - Solution: Progressive disclosure, smart defaults

4. **API Limits**: More API calls needed for series data
   - Solution: Implement smart caching, batch requests

### Testing Strategy

- Unit tests for Series models and services
- Widget tests for new UI components
- Integration tests for series flows
- Performance tests for large series (100+ episodes)
