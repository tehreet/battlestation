-- certificates (LocalMachine\My) — machine personal cert store. Same
-- summary-only column set as the trusted-root capture.
SELECT subject, issuer, not_valid_before, not_valid_after, sha1, key_usage, ca, self_signed, path
FROM certificates
WHERE path LIKE '%LocalMachine\My%'
ORDER BY subject COLLATE NOCASE;
