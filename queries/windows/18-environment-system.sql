-- environment (system-wide, redacted) — machine-scope env vars from the
-- Session Manager registry key. Values matching token/key/secret/password/auth
-- patterns are replaced with <REDACTED>. Source of truth, not per-process.
SELECT
    name,
    CASE
        WHEN UPPER(name) LIKE '%TOKEN%'
          OR UPPER(name) LIKE '%KEY%'
          OR UPPER(name) LIKE '%SECRET%'
          OR UPPER(name) LIKE '%PASSWORD%'
          OR UPPER(name) LIKE '%PASSWD%'
          OR UPPER(name) LIKE '%PWD%'
          OR UPPER(name) LIKE '%AUTH%'
          OR UPPER(name) LIKE '%CREDENTIAL%'
          OR UPPER(name) LIKE '%API%'
        THEN '<REDACTED>'
        ELSE data
    END AS value,
    type
FROM registry
WHERE key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
ORDER BY name COLLATE NOCASE;
