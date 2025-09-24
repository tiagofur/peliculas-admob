-- Migration: Create user_movie_ratings table for rating and review system
-- Date: 2025-09-08
-- Description: Creates a comprehensive table for user movie ratings and reviews with sync capabilities

-- Create user_movie_ratings table
CREATE TABLE IF NOT EXISTS public.user_movie_ratings (
    -- Primary identifiers
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    movie_id INTEGER NOT NULL,
    
    -- Rating and review data
    rating DECIMAL(3,1) CHECK (rating >= 1.0 AND rating <= 10.0) NOT NULL,
    review TEXT,
    
    -- Movie metadata (denormalized for performance and offline capability)
    movie_title VARCHAR(500) NOT NULL,
    movie_poster_path TEXT,
    movie_backdrop_path TEXT,
    movie_overview TEXT,
    movie_release_date DATE,
    movie_vote_average DECIMAL(3,1),
    
    -- Sync system fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    last_modified_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    sync_version INTEGER DEFAULT 1 NOT NULL,
    device_id VARCHAR(255),
    is_deleted BOOLEAN DEFAULT FALSE NOT NULL,
    
    -- Additional metadata
    rated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    is_public BOOLEAN DEFAULT FALSE NOT NULL,
    tags TEXT[] DEFAULT '{}',
    
    -- Constraints
    CONSTRAINT unique_user_movie_rating UNIQUE (user_id, movie_id, is_deleted) 
        DEFERRABLE INITIALLY DEFERRED
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_user_id ON public.user_movie_ratings(user_id);
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_movie_id ON public.user_movie_ratings(movie_id);
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_rating ON public.user_movie_ratings(rating);
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_created_at ON public.user_movie_ratings(created_at);
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_rated_at ON public.user_movie_ratings(rated_at);
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_sync_version ON public.user_movie_ratings(sync_version);
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_last_modified ON public.user_movie_ratings(last_modified_at);
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_device_id ON public.user_movie_ratings(device_id) WHERE device_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_not_deleted ON public.user_movie_ratings(user_id, movie_id) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_public ON public.user_movie_ratings(movie_id, rating) WHERE is_public = TRUE AND is_deleted = FALSE;

-- Create composite index for sync operations
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_sync ON public.user_movie_ratings(user_id, last_modified_at, sync_version) WHERE is_deleted = FALSE;

-- Create trigger to update last_modified_at
CREATE OR REPLACE FUNCTION update_user_movie_ratings_modified_time()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified_at = TIMEZONE('utc', NOW());
    NEW.sync_version = OLD.sync_version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_update_user_movie_ratings_modified_time
    BEFORE UPDATE ON public.user_movie_ratings
    FOR EACH ROW
    EXECUTE FUNCTION update_user_movie_ratings_modified_time();

-- Row Level Security (RLS) policies
ALTER TABLE public.user_movie_ratings ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own ratings
CREATE POLICY user_movie_ratings_select_policy ON public.user_movie_ratings
    FOR SELECT
    USING (
        auth.uid() = user_id OR 
        (is_public = TRUE AND is_deleted = FALSE)
    );

-- Policy: Users can only insert their own ratings
CREATE POLICY user_movie_ratings_insert_policy ON public.user_movie_ratings
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only update their own ratings
CREATE POLICY user_movie_ratings_update_policy ON public.user_movie_ratings
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only delete their own ratings
CREATE POLICY user_movie_ratings_delete_policy ON public.user_movie_ratings
    FOR DELETE
    USING (auth.uid() = user_id);

-- Enable realtime for the table
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE public.user_movie_ratings;

-- Grant necessary permissions
GRANT ALL ON public.user_movie_ratings TO authenticated;
GRANT ALL ON public.user_movie_ratings TO service_role;

-- Create function to get user rating statistics
CREATE OR REPLACE FUNCTION get_user_rating_stats(target_user_id UUID)
RETURNS JSON AS $$
DECLARE
    stats JSON;
BEGIN
    SELECT json_build_object(
        'total_ratings', COUNT(*),
        'average_rating', ROUND(AVG(rating), 2),
        'highest_rating', MAX(rating),
        'lowest_rating', MIN(rating),
        'ratings_with_review', COUNT(*) FILTER (WHERE review IS NOT NULL AND LENGTH(review) > 0),
        'public_ratings', COUNT(*) FILTER (WHERE is_public = TRUE),
        'recent_ratings_count', COUNT(*) FILTER (WHERE rated_at >= NOW() - INTERVAL '30 days')
    )
    INTO stats
    FROM public.user_movie_ratings
    WHERE user_id = target_user_id
    AND is_deleted = FALSE;
    
    RETURN stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get movie rating summary
CREATE OR REPLACE FUNCTION get_movie_rating_summary(target_movie_id INTEGER)
RETURNS JSON AS $$
DECLARE
    summary JSON;
BEGIN
    SELECT json_build_object(
        'movie_id', target_movie_id,
        'total_ratings', COUNT(*),
        'average_rating', ROUND(AVG(rating), 2),
        'rating_distribution', json_build_object(
            '1-2', COUNT(*) FILTER (WHERE rating >= 1.0 AND rating < 3.0),
            '3-4', COUNT(*) FILTER (WHERE rating >= 3.0 AND rating < 5.0),
            '5-6', COUNT(*) FILTER (WHERE rating >= 5.0 AND rating < 7.0),
            '7-8', COUNT(*) FILTER (WHERE rating >= 7.0 AND rating < 9.0),
            '9-10', COUNT(*) FILTER (WHERE rating >= 9.0 AND rating <= 10.0)
        ),
        'recent_reviews', (
            SELECT json_agg(
                json_build_object(
                    'rating', rating,
                    'review', SUBSTRING(review, 1, 200),
                    'rated_at', rated_at,
                    'user_id', CASE WHEN is_public THEN user_id ELSE NULL END
                )
            )
            FROM public.user_movie_ratings
            WHERE movie_id = target_movie_id
            AND is_deleted = FALSE
            AND is_public = TRUE
            AND review IS NOT NULL
            AND LENGTH(review) > 0
            ORDER BY rated_at DESC
            LIMIT 5
        )
    )
    INTO summary
    FROM public.user_movie_ratings
    WHERE movie_id = target_movie_id
    AND is_deleted = FALSE
    AND is_public = TRUE;
    
    RETURN summary;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION get_user_rating_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_movie_rating_summary(INTEGER) TO authenticated;

-- Insert sample data for testing (optional - can be removed in production)
-- INSERT INTO public.user_movie_ratings (user_id, movie_id, rating, review, movie_title, rated_at)
-- VALUES 
--     ('00000000-0000-0000-0000-000000000000', 123456, 8.5, 'Great movie with excellent cinematography!', 'Sample Movie', NOW()),
--     ('00000000-0000-0000-0000-000000000000', 789012, 7.0, 'Good storyline but could be better.', 'Another Movie', NOW())
-- ON CONFLICT DO NOTHING;

-- Add comments for documentation
COMMENT ON TABLE public.user_movie_ratings IS 'Stores user movie ratings and reviews with real-time sync support';
COMMENT ON COLUMN public.user_movie_ratings.rating IS 'User rating from 1.0 to 10.0';
COMMENT ON COLUMN public.user_movie_ratings.review IS 'Optional user review text';
COMMENT ON COLUMN public.user_movie_ratings.is_public IS 'Whether this rating/review is visible to other users';
COMMENT ON COLUMN public.user_movie_ratings.sync_version IS 'Version number for conflict resolution';
COMMENT ON COLUMN public.user_movie_ratings.tags IS 'Array of tags for categorizing reviews';
COMMENT ON FUNCTION get_user_rating_stats(UUID) IS 'Returns comprehensive statistics for a users ratings';
COMMENT ON FUNCTION get_movie_rating_summary(INTEGER) IS 'Returns rating summary and recent reviews for a movie';