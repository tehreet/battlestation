-- deb_packages — every installed dpkg-managed package. Large; the trimmed
-- "intentionally installed" view is captured separately as apt-manual.txt.
SELECT name, version, source, size, arch, revision, status, maintainer, section, priority
FROM deb_packages
ORDER BY name COLLATE NOCASE;
