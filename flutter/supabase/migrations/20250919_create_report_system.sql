-- Migration: Create report system for movie ratings and reviews
-- Date: 2025-09-19
-- Description: Creates tables for user reports on inappropriate content

-- =============================================
-- TABLE: user_rating_reports
-- =============================================
CREATE TABLE IF NOT EXISTS public.user_rating_reports (
    -- Primary identifiers
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rating_id UUID NOT NULL REFERENCES public.user_movie_ratings(id) ON DELETE CASCADE,
    reporter_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reported_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
    
    -- Report data
    reason VARCHAR(100) NOT NULL,
    additional_details TEXT,
    report_category VARCHAR(50) NOT NULL DEFAULT 'inappropriate_content',
    
    -- Status tracking
    status VARCHAR(20) DEFAULT 'pending' NOT NULL 
        CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed')),
    
    -- Admin handling
    reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    admin_notes TEXT,
    resolution VARCHAR(50) CHECK (resolution IN ('no_action', 'content_removed', 'user_warned', 'user_suspended')),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    
    -- Constraints
    CONSTRAINT unique_user_rating_report UNIQUE (rating_id, reporter_user_id)
);

-- =============================================
-- INDEXES
-- =============================================
CREATE INDEX IF NOT EXISTS idx_rating_reports_rating_id ON public.user_rating_reports(rating_id);
CREATE INDEX IF NOT EXISTS idx_rating_reports_reporter ON public.user_rating_reports(reporter_user_id);
CREATE INDEX IF NOT EXISTS idx_rating_reports_reported ON public.user_rating_reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_rating_reports_status ON public.user_rating_reports(status);
CREATE INDEX IF NOT EXISTS idx_rating_reports_created_at ON public.user_rating_reports(created_at);
CREATE INDEX IF NOT EXISTS idx_rating_reports_category ON public.user_rating_reports(report_category);

-- =============================================
-- TRIGGERS
-- =============================================
CREATE OR REPLACE FUNCTION update_rating_reports_modified_time()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_update_rating_reports_modified_time
    BEFORE UPDATE ON public.user_rating_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_rating_reports_modified_time();

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================
ALTER TABLE public.user_rating_reports ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own submitted reports
CREATE POLICY user_rating_reports_select_policy ON public.user_rating_reports
    FOR SELECT
    USING (
        auth.uid() = reporter_user_id OR 
        auth.uid() = reported_user_id OR
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND auth.users.raw_app_meta_data->>'role' = 'admin'
        )
    );

-- Policy: Authenticated users can submit reports
CREATE POLICY user_rating_reports_insert_policy ON public.user_rating_reports
    FOR INSERT
    WITH CHECK (
        auth.uid() = reporter_user_id AND
        reporter_user_id != reported_user_id
    );

-- Policy: Only admins can update reports (change status, add notes)
CREATE POLICY user_rating_reports_update_policy ON public.user_rating_reports
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND auth.users.raw_app_meta_data->>'role' = 'admin'
        )
    );

-- =============================================
-- PERMISSIONS
-- =============================================
GRANT ALL ON public.user_rating_reports TO authenticated;
GRANT ALL ON public.user_rating_reports TO service_role;

-- =============================================
-- FUNCTIONS
-- =============================================

-- Function to submit a report
CREATE OR REPLACE FUNCTION submit_rating_report(
    p_rating_id UUID,
    p_reason VARCHAR,
    p_additional_details TEXT DEFAULT NULL,
    p_category VARCHAR DEFAULT 'inappropriate_content'
)
RETURNS UUID AS $$
DECLARE
    v_reporter_id UUID;
    v_reported_user_id UUID;
    v_report_id UUID;
BEGIN
    -- Get the current user
    v_reporter_id := auth.uid();
    
    IF v_reporter_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to submit reports';
    END IF;
    
    -- Get the user who created the rating
    SELECT user_id INTO v_reported_user_id 
    FROM public.user_movie_ratings 
    WHERE id = p_rating_id;
    
    IF v_reported_user_id IS NULL THEN
        RAISE EXCEPTION 'Rating not found';
    END IF;
    
    IF v_reported_user_id = v_reporter_id THEN
        RAISE EXCEPTION 'Users cannot report their own content';
    END IF;
    
    -- Insert the report
    INSERT INTO public.user_rating_reports (
        rating_id,
        reporter_user_id,
        reported_user_id,
        reason,
        additional_details,
        report_category
    )
    VALUES (
        p_rating_id,
        v_reporter_id,
        v_reported_user_id,
        p_reason,
        p_additional_details,
        p_category
    )
    RETURNING id INTO v_report_id;
    
    RETURN v_report_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get report statistics
CREATE OR REPLACE FUNCTION get_report_statistics()
RETURNS JSON AS $$
DECLARE
    stats JSON;
BEGIN
    -- Check if user is admin
    IF NOT EXISTS (
        SELECT 1 FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND auth.users.raw_app_meta_data->>'role' = 'admin'
    ) THEN
        RAISE EXCEPTION 'Only admins can view report statistics';
    END IF;
    
    SELECT json_build_object(
        'total_reports', COUNT(*),
        'pending_reports', COUNT(*) FILTER (WHERE status = 'pending'),
        'reviewing_reports', COUNT(*) FILTER (WHERE status = 'reviewing'),
        'resolved_reports', COUNT(*) FILTER (WHERE status = 'resolved'),
        'dismissed_reports', COUNT(*) FILTER (WHERE status = 'dismissed'),
        'reports_by_category', json_build_object(
            'inappropriate_content', COUNT(*) FILTER (WHERE report_category = 'inappropriate_content'),
            'spam', COUNT(*) FILTER (WHERE report_category = 'spam'),
            'harassment', COUNT(*) FILTER (WHERE report_category = 'harassment'),
            'other', COUNT(*) FILTER (WHERE report_category = 'other')
        ),
        'recent_reports_count', COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days')
    )
    INTO stats
    FROM public.user_rating_reports;
    
    RETURN stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION submit_rating_report(UUID, VARCHAR, TEXT, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION get_report_statistics() TO authenticated;

-- =============================================
-- COMMENTS
-- =============================================
COMMENT ON TABLE public.user_rating_reports IS 'Stores user reports for inappropriate movie ratings and reviews';
COMMENT ON COLUMN public.user_rating_reports.reason IS 'Primary reason for the report (predefined options)';
COMMENT ON COLUMN public.user_rating_reports.report_category IS 'Category classification for the report';
COMMENT ON COLUMN public.user_rating_reports.status IS 'Current status of the report in the moderation workflow';
COMMENT ON FUNCTION submit_rating_report(UUID, VARCHAR, TEXT, VARCHAR) IS 'Submits a new report for a rating/review';
COMMENT ON FUNCTION get_report_statistics() IS 'Returns comprehensive statistics for admin dashboard';