-- scheduled_tasks — user/third-party scheduled tasks. Filters out the OS noise
-- under \Microsoft\ (Windows itself ships thousands).
SELECT name, action, path, enabled, state, hidden, last_run_time, next_run_time, last_run_message, last_run_code
FROM scheduled_tasks
WHERE path NOT LIKE '\Microsoft\%'
ORDER BY path, name COLLATE NOCASE;
