-- environment (current user, redacted) — user-scope env vars from HKCU.
-- Same redaction list as 18-environment-system.sql.
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
WHERE key = 'HKEY_CURRENT_USER\Environment'
ORDER BY name COLLATE NOCASE;
