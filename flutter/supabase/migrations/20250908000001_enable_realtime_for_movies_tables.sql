-- Enable real-time replication for the movies app tables
-- This migration enables real-time for user_favorites, user_watchlist, and user_watched_movies

-- Enable real-time for user_favorites table
-- First remove if already exists to avoid errors
DO $$ 
BEGIN 
    BEGIN
        ALTER PUBLICATION supabase_realtime DROP TABLE user_favorites;
    EXCEPTION 
        WHEN others THEN 
            NULL; -- Table wasn't in publication, which is fine
    END;
END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE user_favorites;
ALTER TABLE user_favorites REPLICA IDENTITY FULL;

-- Enable real-time for user_watchlist table
DO $$ 
BEGIN 
    BEGIN
        ALTER PUBLICATION supabase_realtime DROP TABLE user_watchlist;
    EXCEPTION 
        WHEN others THEN 
            NULL; -- Table wasn't in publication, which is fine
    END;
END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE user_watchlist;
ALTER TABLE user_watchlist REPLICA IDENTITY FULL;

-- Enable real-time for user_watched_movies table
DO $$ 
BEGIN 
    BEGIN
        ALTER PUBLICATION supabase_realtime DROP TABLE user_watched_movies;
    EXCEPTION 
        WHEN others THEN 
            NULL; -- Table wasn't in publication, which is fine
    END;
END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE user_watched_movies;
ALTER TABLE user_watched_movies REPLICA IDENTITY FULL;