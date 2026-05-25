-- programs (games only) — companion to 05-programs.sql; captures entries that
-- look like Steam/Epic/Battle.net/Riot game installs based on install_location.
-- Game launchers (the Steam client itself, etc.) are NOT here — they're in
-- 05-programs.sql.
SELECT name, version, install_location, install_source, publisher
FROM programs
WHERE install_location LIKE '%\steamapps\%'
   OR install_location LIKE '%\Epic Games\%'
   OR install_location LIKE '%\Battle.net\Games\%'
   OR install_location LIKE '%\Riot Games\%'
ORDER BY name COLLATE NOCASE;
