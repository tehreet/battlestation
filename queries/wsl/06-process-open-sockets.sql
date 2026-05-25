-- listening processes inside WSL — process_open_sockets joined to processes,
-- filtered to LISTEN-equivalent sockets. Stable on process name (not PID).
SELECT
    p.name        AS process_name,
    p.path        AS process_path,
    pos.family    AS family,
    pos.protocol  AS protocol,
    pos.local_address,
    pos.local_port
FROM processes p
JOIN process_open_sockets pos ON p.pid = pos.pid
WHERE (pos.remote_port = 0 OR pos.remote_address = '' OR pos.remote_address = '0.0.0.0' OR pos.remote_address = '::')
  AND pos.local_port > 0
ORDER BY pos.local_port, p.name COLLATE NOCASE;
