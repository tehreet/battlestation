-- processes (top 50 by RSS) — same caveat as Windows side: PIDs are volatile,
-- this is a snapshot not a stable baseline. Useful for "what was running."
SELECT pid, name, path, cmdline, parent, uid, gid, resident_size, total_size, start_time
FROM processes
ORDER BY resident_size DESC
LIMIT 50;
