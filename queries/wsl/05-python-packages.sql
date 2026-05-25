-- python_packages — pip-installed Python packages osquery can locate. Often
-- partial since pipx/venv installs aren't always discovered. See pipx-list.txt
-- for the curated pipx view.
SELECT * FROM python_packages ORDER BY name COLLATE NOCASE;
