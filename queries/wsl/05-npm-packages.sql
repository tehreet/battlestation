-- npm_packages — globally-installed Node packages. May be empty if nothing
-- global is installed; the supplemental npm-globals.txt is the human-readable
-- companion.
SELECT * FROM npm_packages ORDER BY name COLLATE NOCASE;
