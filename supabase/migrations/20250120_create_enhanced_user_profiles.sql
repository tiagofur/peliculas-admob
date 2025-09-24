-- Migration: Enhanced User Profiles System
-- Date: 2025-01-20
-- Description: Create comprehensive user profile system with statistics, preferences, and achievements

-- =======================
-- EXPAND USER_PROFILES TABLE
-- =======================

-- Add new columns to existing user_profiles table
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS display_name VARCHAR(100),
ADD COLUMN IF NOT EXISTS email VARCHAR(255),
ADD COLUMN IF NOT EXISTS banner_url TEXT,
ADD COLUMN IF NOT EXISTS last_active_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS custom_fields JSONB DEFAULT '{}';

-- Rename full_name to display_name if it exists
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_profiles' AND column_name='full_name') THEN
        -- Copy data from full_name to display_name
        UPDATE user_profiles SET display_name = full_name WHERE display_name IS NULL;
        -- Drop the old column
        ALTER TABLE user_profiles DROP COLUMN full_name;
    END IF;
END $$;

-- Update display_name to NOT NULL with default
ALTER TABLE user_profiles ALTER COLUMN display_name SET DEFAULT 'Usuario Anónimo';
UPDATE user_profiles SET display_name = 'Usuario Anónimo' WHERE display_name IS NULL;
ALTER TABLE user_profiles ALTER COLUMN display_name SET NOT NULL;

-- Rename created_at to joined_date for clarity
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_profiles' AND column_name='joined_date') THEN
        ALTER TABLE user_profiles RENAME COLUMN created_at TO joined_date;
    END IF;
END $$;

-- =======================
-- CREATE USER_STATISTICS TABLE
-- =======================

CREATE TABLE IF NOT EXISTS user_statistics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    total_movies_watched INTEGER DEFAULT 0 CHECK (total_movies_watched >= 0),
    total_movies_rated INTEGER DEFAULT 0 CHECK (total_movies_rated >= 0),
    average_rating DECIMAL(3,2) DEFAULT 0.0 CHECK (average_rating >= 0.0 AND average_rating <= 10.0),
    total_watch_time_minutes INTEGER DEFAULT 0 CHECK (total_watch_time_minutes >= 0),
    genre_preferences JSONB DEFAULT '{}',
    year_preferences JSONB DEFAULT '{}',
    country_preferences JSONB DEFAULT '{}',
    annual_stats JSONB DEFAULT '{}',
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for user_statistics
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_statistics_user_id ON user_statistics(user_id);
CREATE INDEX IF NOT EXISTS idx_user_statistics_last_updated ON user_statistics(last_updated DESC);
CREATE INDEX IF NOT EXISTS idx_user_statistics_movies_watched ON user_statistics(total_movies_watched DESC);

-- =======================
-- CREATE USER_PREFERENCES TABLE
-- =======================

CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    genre_weights JSONB DEFAULT '{}',
    favorite_actors TEXT[] DEFAULT '{}',
    favorite_directors TEXT[] DEFAULT '{}',
    favorite_studios TEXT[] DEFAULT '{}',
    preferred_languages TEXT[] DEFAULT '{es,en}',
    max_content_rating VARCHAR(10) DEFAULT 'r',
    min_release_year INTEGER DEFAULT 1970 CHECK (min_release_year >= 1900),
    max_release_year INTEGER DEFAULT EXTRACT(YEAR FROM NOW()) + 2,
    min_runtime INTEGER DEFAULT 60 CHECK (min_runtime >= 0),
    max_runtime INTEGER DEFAULT 300 CHECK (max_runtime >= min_runtime),
    min_rating DECIMAL(3,2) DEFAULT 0.0 CHECK (min_rating >= 0.0 AND min_rating <= 10.0),
    include_adult_content BOOLEAN DEFAULT FALSE,
    prefer_subtitles BOOLEAN DEFAULT FALSE,
    prefer_dubbing BOOLEAN DEFAULT TRUE,
    notifications JSONB DEFAULT '{"enablePushNotifications": true, "notifyNewRecommendations": true, "notifyFriendsActivity": false, "notifyNewReleases": true, "notifyWatchlistUpdates": true, "notifyAchievements": true, "emailDigest": false, "digestFrequency": "weekly"}',
    privacy JSONB DEFAULT '{"profileVisibility": "public", "showRatingsPublic": true, "showWatchlistPublic": true, "showFavoritesPublic": true, "showStatsPublic": true, "allowFriendRequests": true, "shareActivityOnSocial": false, "analyticsOptOut": false}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for user_preferences
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_preferences_user_id ON user_preferences(user_id);

-- =======================
-- CREATE USER_ACHIEVEMENTS TABLE
-- =======================

CREATE TABLE IF NOT EXISTS user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    achievement_id VARCHAR(100) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    icon_path VARCHAR(500),
    category VARCHAR(50) DEFAULT 'watching',
    progress INTEGER DEFAULT 0 CHECK (progress >= 0),
    target INTEGER DEFAULT 1 CHECK (target > 0),
    is_unlocked BOOLEAN DEFAULT FALSE,
    unlocked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for user_achievements
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement_id ON user_achievements(achievement_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_achievements_user_achievement ON user_achievements(user_id, achievement_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_category ON user_achievements(category);
CREATE INDEX IF NOT EXISTS idx_user_achievements_unlocked ON user_achievements(is_unlocked, unlocked_at DESC);

-- =======================
-- ROW LEVEL SECURITY (RLS)
-- =======================

-- Enable RLS on all new tables
ALTER TABLE user_statistics ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

-- =======================
-- RLS POLICIES - USER_STATISTICS
-- =======================

-- Users can view their own statistics
CREATE POLICY "Users can view their own statistics" ON user_statistics
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own statistics
CREATE POLICY "Users can insert their own statistics" ON user_statistics
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own statistics
CREATE POLICY "Users can update their own statistics" ON user_statistics
    FOR UPDATE USING (auth.uid() = user_id);

-- =======================
-- RLS POLICIES - USER_PREFERENCES
-- =======================

-- Users can view their own preferences
CREATE POLICY "Users can view their own preferences" ON user_preferences
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own preferences
CREATE POLICY "Users can insert their own preferences" ON user_preferences
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own preferences
CREATE POLICY "Users can update their own preferences" ON user_preferences
    FOR UPDATE USING (auth.uid() = user_id);

-- =======================
-- RLS POLICIES - USER_ACHIEVEMENTS
-- =======================

-- Users can view their own achievements
CREATE POLICY "Users can view their own achievements" ON user_achievements
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own achievements
CREATE POLICY "Users can insert their own achievements" ON user_achievements
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own achievements
CREATE POLICY "Users can update their own achievements" ON user_achievements
    FOR UPDATE USING (auth.uid() = user_id);

-- Public view for achievements (if privacy settings allow)
CREATE POLICY "Public can view public achievements" ON user_achievements
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_preferences up
            WHERE up.user_id = user_achievements.user_id
            AND (up.privacy->>'showStatsPublic')::boolean = true
        )
    );

-- =======================
-- UPDATED TRIGGERS AND FUNCTIONS
-- =======================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_statistics_updated_at
    BEFORE UPDATE ON user_statistics
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_preferences_updated_at
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_achievements_updated_at
    BEFORE UPDATE ON user_achievements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =======================
-- ENHANCED USER CREATION FUNCTION
-- =======================

-- Drop existing function and recreate with enhanced functionality
DROP FUNCTION IF EXISTS public.handle_new_user();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Create user profile
    INSERT INTO public.user_profiles (user_id, display_name, email, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'full_name', 'Usuario Anónimo'),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
    );
    
    -- Create user statistics
    INSERT INTO public.user_statistics (user_id)
    VALUES (NEW.id);
    
    -- Create user preferences with defaults
    INSERT INTO public.user_preferences (user_id)
    VALUES (NEW.id);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =======================
-- UTILITY FUNCTIONS
-- =======================

-- Function to get complete user profile with all related data
CREATE OR REPLACE FUNCTION get_enhanced_user_profile(profile_user_id UUID)
RETURNS TABLE (
    profile_data JSONB,
    statistics_data JSONB,
    preferences_data JSONB,
    achievements_data JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        to_jsonb(up.*) as profile_data,
        to_jsonb(us.*) as statistics_data,
        to_jsonb(upr.*) as preferences_data,
        COALESCE(
            (SELECT jsonb_agg(to_jsonb(ua.*)) 
             FROM user_achievements ua 
             WHERE ua.user_id = profile_user_id),
            '[]'::jsonb
        ) as achievements_data
    FROM user_profiles up
    LEFT JOIN user_statistics us ON up.user_id = us.user_id
    LEFT JOIN user_preferences upr ON up.user_id = upr.user_id
    WHERE up.user_id = profile_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user statistics efficiently
CREATE OR REPLACE FUNCTION update_user_statistics(
    profile_user_id UUID,
    movies_watched_delta INTEGER DEFAULT 0,
    movies_rated_delta INTEGER DEFAULT 0,
    new_average_rating DECIMAL(3,2) DEFAULT NULL,
    watch_time_delta INTEGER DEFAULT 0,
    genre_data JSONB DEFAULT NULL,
    year_data JSONB DEFAULT NULL,
    country_data JSONB DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO user_statistics (user_id, total_movies_watched, total_movies_rated, average_rating, total_watch_time_minutes, genre_preferences, year_preferences, country_preferences)
    VALUES (profile_user_id, movies_watched_delta, movies_rated_delta, COALESCE(new_average_rating, 0.0), watch_time_delta, COALESCE(genre_data, '{}'), COALESCE(year_data, '{}'), COALESCE(country_data, '{}'))
    ON CONFLICT (user_id) DO UPDATE SET
        total_movies_watched = user_statistics.total_movies_watched + movies_watched_delta,
        total_movies_rated = user_statistics.total_movies_rated + movies_rated_delta,
        average_rating = COALESCE(new_average_rating, user_statistics.average_rating),
        total_watch_time_minutes = user_statistics.total_watch_time_minutes + watch_time_delta,
        genre_preferences = COALESCE(genre_data, user_statistics.genre_preferences),
        year_preferences = COALESCE(year_data, user_statistics.year_preferences),
        country_preferences = COALESCE(country_data, user_statistics.country_preferences),
        last_updated = NOW(),
        updated_at = NOW();
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =======================
-- GRANT PERMISSIONS
-- =======================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE ON user_statistics TO authenticated;
GRANT SELECT, INSERT, UPDATE ON user_preferences TO authenticated;
GRANT SELECT, INSERT, UPDATE ON user_achievements TO authenticated;

-- Grant limited SELECT permissions to anon for public profiles
GRANT SELECT ON user_statistics TO anon;
GRANT SELECT ON user_preferences TO anon;
GRANT SELECT ON user_achievements TO anon;

-- Grant usage on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO anon;

-- =======================
-- INITIAL DATA MIGRATION
-- =======================

-- Migrate existing user_stats data to new user_statistics table
INSERT INTO user_statistics (user_id, total_movies_watched, last_updated)
SELECT 
    user_id, 
    movies_watched,
    COALESCE(last_activity, NOW())
FROM user_stats
ON CONFLICT (user_id) DO NOTHING;

-- Create default preferences for existing users who don't have them
INSERT INTO user_preferences (user_id)
SELECT DISTINCT user_id 
FROM user_profiles up
WHERE NOT EXISTS (
    SELECT 1 FROM user_preferences upr 
    WHERE upr.user_id = up.user_id
);

-- Create default statistics for existing users who don't have them
INSERT INTO user_statistics (user_id)
SELECT DISTINCT user_id 
FROM user_profiles up
WHERE NOT EXISTS (
    SELECT 1 FROM user_statistics us 
    WHERE us.user_id = up.user_id
);

-- Log successful migration
DO $$ 
BEGIN
    RAISE NOTICE 'Enhanced User Profiles migration completed successfully';
END $$;