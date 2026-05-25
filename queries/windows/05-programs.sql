-- programs (non-games) — installed software, excluding entries that look like
-- Steam, Epic, Battle.net, or Riot games. Game launchers themselves stay here
-- (they're real software); only the per-game install entries are filtered out.
-- The companion 05-games.sql captures the inverse set.
SELECT name, version, install_location, install_source, publisher, uninstall_string, identifying_number
FROM programs
WHERE (install_location IS NULL OR (
        install_location NOT LIKE '%\steamapps\%'
    AND install_location NOT LIKE '%\Epic Games\%'
    AND install_location NOT LIKE '%\Battle.net\Games\%'
    AND install_location NOT LIKE '%\Riot Games\%'
))
ORDER BY name COLLATE NOCASE;
