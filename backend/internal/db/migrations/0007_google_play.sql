-- Google Play purchases share the entitlements table with the App Store.
-- Play rows use 'gp:' + purchase token as original_transaction_id.
ALTER TABLE entitlements ADD COLUMN store text NOT NULL DEFAULT 'app_store'
    CHECK (store IN ('app_store', 'play'));

-- Android devices register FCM tokens (not hex, case-sensitive).
ALTER TABLE devices DROP CONSTRAINT devices_platform_check;
ALTER TABLE devices ADD CONSTRAINT devices_platform_check
    CHECK (platform IN ('ios', 'tvos', 'android'));
