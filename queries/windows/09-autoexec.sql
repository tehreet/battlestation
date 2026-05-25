-- autoexec — meta-table merging startup_items, services, scheduled_tasks
-- into a unified autorun view
SELECT * FROM autoexec ORDER BY source, name COLLATE NOCASE;
