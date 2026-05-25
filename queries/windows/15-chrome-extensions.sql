-- chrome_extensions — extensions installed in Chromium-based browsers (Chrome,
-- Edge, Brave, Chromium, Opera, Yandex). One row per (profile, extension).
SELECT browser_type, uid, profile, name, identifier, version, description, locale, update_url, author, persistent, permissions, optional_permissions, path
FROM chrome_extensions
ORDER BY browser_type, profile, name COLLATE NOCASE;
