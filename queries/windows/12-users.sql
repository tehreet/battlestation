-- users — local user accounts. Selected columns only: skip the raw SID-bound
-- last_logon and password hint fields that don't matter for a baseline.
SELECT uid, gid, username, description, directory, shell, type
FROM users
ORDER BY username COLLATE NOCASE;
