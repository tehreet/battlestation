-- processes (top 50 by RSS) — snapshot of the heaviest processes at capture
-- time. PIDs are volatile so don't use this for diff stability — it's a
-- "what was running" reference, not a tracked baseline.
SELECT pid, name, path, cmdline, parent, resident_size, total_size, user_time, system_time
FROM processes
ORDER BY resident_size DESC
LIMIT 50;
