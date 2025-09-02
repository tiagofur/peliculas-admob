-- =============================================
-- SECURITY HARDENING MIGRATION
-- =============================================
-- This migration implements comprehensive security hardening
-- for RLS policies and security measures

-- =============================================
-- 1. CREATE AUDIT LOG TABLE
-- =============================================

CREATE TABLE security_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id TEXT,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS for audit log
ALTER TABLE security_audit_log ENABLE ROW LEVEL SECURITY;

-- Only admins can view audit logs (for now, restrict to authenticated users)
CREATE POLICY "Authenticated users can view audit logs" ON security_audit_log
    FOR SELECT USING (auth.role() = 'authenticated');

-- =============================================
-- 2. IMPROVE USER_PROFILES POLICIES
-- =============================================

-- Drop the overly broad policy
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;

-- Create specific, granular policies
CREATE POLICY "Users can view their own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own profile" ON user_profiles
    FOR INSERT WITH CHECK (
        auth.uid() = user_id 
        AND char_length(full_name) >= 2 
        AND char_length(full_name) <= 100
    );

CREATE POLICY "Users can update their own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (
        auth.uid() = user_id 
        AND char_length(full_name) >= 2 
        AND char_length(full_name) <= 100
    );

CREATE POLICY "Users can delete their own profile" ON user_profiles
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================
-- 3. IMPROVE USER_STATS POLICIES
-- =============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own stats" ON user_stats;
DROP POLICY IF EXISTS "Users can update their own stats" ON user_stats;

-- Create specific policies
CREATE POLICY "Users can view their own stats" ON user_stats
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own stats" ON user_stats
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (
        auth.uid() = user_id 
        AND movies_watched >= 0 
        AND favorites_count >= 0 
        AND lists_count >= 0
    );

-- Stats are created automatically via trigger, no manual insert
CREATE POLICY "System can insert user stats" ON user_stats
    FOR INSERT WITH CHECK (true);

-- =============================================
-- 4. IMPROVE USER_FAVORITES POLICIES
-- =============================================

-- Drop overly broad policy
DROP POLICY IF EXISTS "Users can manage their own favorites" ON user_favorites;

-- Create specific policies
CREATE POLICY "Users can view their own favorites" ON user_favorites
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can add to favorites" ON user_favorites
    FOR INSERT WITH CHECK (
        auth.uid() = user_id 
        AND movie_id > 0
        AND char_length(movie_title) > 0
    );

CREATE POLICY "Users can update their favorites" ON user_favorites
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove from favorites" ON user_favorites
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================
-- 5. IMPROVE USER_WATCHED_MOVIES POLICIES
-- =============================================

-- Drop overly broad policy
DROP POLICY IF EXISTS "Users can manage their own watched movies" ON user_watched_movies;

-- Create specific policies
CREATE POLICY "Users can view their watched movies" ON user_watched_movies
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can mark movies as watched" ON user_watched_movies
    FOR INSERT WITH CHECK (
        auth.uid() = user_id 
        AND movie_id > 0
        AND char_length(movie_title) > 0
    );

CREATE POLICY "Users can update watched movies" ON user_watched_movies
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove watched movies" ON user_watched_movies
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================
-- 6. IMPROVE USER_LISTS POLICIES
-- =============================================

-- Drop overly broad policy
DROP POLICY IF EXISTS "Users can manage their own lists" ON user_lists;

-- Create specific policies
CREATE POLICY "Users can view their own lists" ON user_lists
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Public lists are viewable by anyone" ON user_lists
    FOR SELECT USING (is_public = true);

CREATE POLICY "Users can create lists" ON user_lists
    FOR INSERT WITH CHECK (
        auth.uid() = user_id 
        AND char_length(name) >= 1 
        AND char_length(name) <= 100
        AND (description IS NULL OR char_length(description) <= 500)
    );

CREATE POLICY "Users can update their own lists" ON user_lists
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (
        auth.uid() = user_id 
        AND char_length(name) >= 1 
        AND char_length(name) <= 100
        AND (description IS NULL OR char_length(description) <= 500)
    );

CREATE POLICY "Users can delete their own lists" ON user_lists
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================
-- 7. IMPROVE USER_LIST_ITEMS POLICIES
-- =============================================

-- Drop overly broad policy
DROP POLICY IF EXISTS "Users can manage items in their own lists" ON user_list_items;

-- Create specific policies
CREATE POLICY "Users can view items in their own lists" ON user_list_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_lists 
            WHERE user_lists.id = user_list_items.list_id 
            AND user_lists.user_id = auth.uid()
        )
    );

CREATE POLICY "Public list items are viewable" ON user_list_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_lists 
            WHERE user_lists.id = user_list_items.list_id 
            AND user_lists.is_public = true
        )
    );

CREATE POLICY "Users can add items to their lists" ON user_list_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_lists 
            WHERE user_lists.id = user_list_items.list_id 
            AND user_lists.user_id = auth.uid()
        )
        AND movie_id > 0
        AND char_length(movie_title) > 0
    );

CREATE POLICY "Users can update items in their lists" ON user_list_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_lists 
            WHERE user_lists.id = user_list_items.list_id 
            AND user_lists.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_lists 
            WHERE user_lists.id = user_list_items.list_id 
            AND user_lists.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete items from their lists" ON user_list_items
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM user_lists 
            WHERE user_lists.id = user_list_items.list_id 
            AND user_lists.user_id = auth.uid()
        )
    );

-- =============================================
-- 8. IMPROVE USER_WATCHLIST POLICIES
-- =============================================

-- Drop overly broad policy
DROP POLICY IF EXISTS "Users can manage their own watchlist" ON user_watchlist;

-- Create specific policies
CREATE POLICY "Users can view their watchlist" ON user_watchlist
    FOR SELECT USING (auth.uid() = user_id AND deleted_at IS NULL);

CREATE POLICY "Users can add to watchlist" ON user_watchlist
    FOR INSERT WITH CHECK (
        auth.uid() = user_id 
        AND movie_id > 0
        AND char_length(movie_title) > 0
        AND priority IN ('alta', 'normal', 'baja')
    );

CREATE POLICY "Users can update their watchlist" ON user_watchlist
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (
        auth.uid() = user_id 
        AND priority IN ('alta', 'normal', 'baja')
    );

CREATE POLICY "Users can remove from watchlist" ON user_watchlist
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================
-- 9. IMPROVE USER_MOVIE_RATINGS POLICIES
-- =============================================

-- Drop overly broad policy
DROP POLICY IF EXISTS "Users can manage their own movie ratings" ON user_movie_ratings;

-- Create specific policies
CREATE POLICY "Users can view their movie ratings" ON user_movie_ratings
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create movie ratings" ON user_movie_ratings
    FOR INSERT WITH CHECK (
        auth.uid() = user_id 
        AND movie_id > 0
        AND char_length(movie_title) > 0
        AND rating >= 1 
        AND rating <= 5
        AND (personal_note IS NULL OR char_length(personal_note) <= 500)
    );

CREATE POLICY "Users can update their movie ratings" ON user_movie_ratings
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (
        auth.uid() = user_id 
        AND rating >= 1 
        AND rating <= 5
        AND (personal_note IS NULL OR char_length(personal_note) <= 500)
    );

CREATE POLICY "Users can delete their movie ratings" ON user_movie_ratings
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================
-- 10. IMPROVE STORAGE POLICIES
-- =============================================

-- Drop existing avatar policies
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;

-- Create more restrictive avatar policies
CREATE POLICY "Users can upload their own avatar" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'avatars' 
        AND auth.uid()::text = (storage.foldername(name))[1]
        AND lower(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp')
        AND octet_length(name) <= 100
    );

CREATE POLICY "Users can update their own avatar" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'avatars' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    )
    WITH CHECK (
        bucket_id = 'avatars' 
        AND auth.uid()::text = (storage.foldername(name))[1]
        AND lower(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp')
    );

CREATE POLICY "Users can delete their own avatar" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'avatars' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Anyone can view avatars" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');

-- =============================================
-- 11. REVOKE EXCESSIVE PERMISSIONS
-- =============================================

-- Remove excessive anon permissions (keep only necessary SELECT for public data)
REVOKE ALL ON user_profiles FROM anon;
REVOKE ALL ON user_stats FROM anon;

-- Only allow viewing public lists for anon users
REVOKE ALL ON user_favorites FROM anon;
REVOKE ALL ON user_watched_movies FROM anon;
REVOKE ALL ON user_watchlist FROM anon;
REVOKE ALL ON user_movie_ratings FROM anon;

-- Keep SELECT for public lists only
GRANT SELECT ON user_lists TO anon;
GRANT SELECT ON user_list_items TO anon;

-- =============================================
-- 12. CREATE AUDIT TRIGGER FUNCTION
-- =============================================

CREATE OR REPLACE FUNCTION audit_table_changes()
RETURNS TRIGGER AS $$
BEGIN
    -- Only log for authenticated users
    IF auth.uid() IS NOT NULL THEN
        INSERT INTO security_audit_log (
            user_id,
            action,
            table_name,
            record_id,
            old_values,
            new_values,
            timestamp
        ) VALUES (
            auth.uid(),
            TG_OP,
            TG_TABLE_NAME,
            CASE 
                WHEN TG_OP = 'DELETE' THEN OLD.id::text
                ELSE NEW.id::text
            END,
            CASE WHEN TG_OP != 'INSERT' THEN row_to_json(OLD) ELSE NULL END,
            CASE WHEN TG_OP != 'DELETE' THEN row_to_json(NEW) ELSE NULL END,
            NOW()
        );
    END IF;
    
    RETURN CASE 
        WHEN TG_OP = 'DELETE' THEN OLD 
        ELSE NEW 
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 13. CREATE AUDIT TRIGGERS FOR SENSITIVE TABLES
-- =============================================

-- User profile changes
CREATE TRIGGER audit_user_profiles_changes
    AFTER INSERT OR UPDATE OR DELETE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION audit_table_changes();

-- List changes (creation, deletion)
CREATE TRIGGER audit_user_lists_changes
    AFTER INSERT OR DELETE ON user_lists
    FOR EACH ROW EXECUTE FUNCTION audit_table_changes();

-- =============================================
-- 14. CREATE RATE LIMITING FUNCTION
-- =============================================

CREATE OR REPLACE FUNCTION check_rate_limit(
    operation_type TEXT,
    time_window INTERVAL DEFAULT '1 hour'::interval,
    max_operations INTEGER DEFAULT 100
)
RETURNS BOOLEAN AS $$
DECLARE
    operation_count INTEGER;
BEGIN
    -- Count operations in time window
    SELECT COUNT(*)
    INTO operation_count
    FROM security_audit_log
    WHERE user_id = auth.uid()
    AND action = operation_type
    AND timestamp > NOW() - time_window;
    
    RETURN operation_count < max_operations;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 15. ADD COMMENTS FOR DOCUMENTATION
-- =============================================

COMMENT ON TABLE security_audit_log IS 'Audit trail for security-sensitive operations';
COMMENT ON FUNCTION audit_table_changes() IS 'Trigger function to log all table changes for auditing';
COMMENT ON FUNCTION check_rate_limit(TEXT, INTERVAL, INTEGER) IS 'Function to check if user has exceeded rate limits for specific operations';