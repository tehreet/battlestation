-- ie_extensions — Internet Explorer / legacy Edge extensions. Likely empty on
-- modern Windows but kept so unexpected entries become visible in diffs.
SELECT * FROM ie_extensions ORDER BY name COLLATE NOCASE;
