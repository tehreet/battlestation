-- certificates (LocalMachine\Root) — trusted root certificate authorities.
-- Summary fields only — no public key blobs in the baseline.
SELECT subject, issuer, not_valid_before, not_valid_after, sha1, key_usage, ca, self_signed, path
FROM certificates
WHERE path LIKE '%LocalMachine\Root%'
ORDER BY subject COLLATE NOCASE;
