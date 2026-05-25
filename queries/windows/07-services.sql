-- services — Windows services that are not explicitly disabled. Boot/system/
-- auto/manual all stay; only DISABLED is filtered out (those are intentional
-- off-state and add noise to diffs).
SELECT name, display_name, status, start_type, path, service_type, user_account, description
FROM services
WHERE start_type != 'DISABLED'
ORDER BY name COLLATE NOCASE;
