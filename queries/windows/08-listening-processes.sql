-- listening processes — joins processes with process_open_sockets filtered to
-- LISTEN-equivalent sockets (no remote peer). Gives a "what's bound to what
-- port" view that's stable across captures (process names, not PIDs).
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
