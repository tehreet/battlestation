-- authorized_keys (SUMMARY ONLY) — count + algorithm + comment per key.
-- The actual `key` column (raw key material) is deliberately NOT selected.
-- This lets us track "how many keys, of what type, with what label" without
-- ever putting key material into the repo.
SELECT uid, algorithm, comment, key_file
FROM authorized_keys
ORDER BY uid, key_file, algorithm;
