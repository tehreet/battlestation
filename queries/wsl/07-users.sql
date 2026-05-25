-- users — Linux users from /etc/passwd. Skipping the description column when
-- it contains GECOS-style PII would be reasonable but we keep it for fidelity;
-- the file lives under .gitignore-protected paths only if you opt in.
SELECT uid, gid, username, description, directory, shell
FROM users
ORDER BY uid;
