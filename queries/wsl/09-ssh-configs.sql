-- ssh_configs — parsed ssh client/server config files (NOT keys). Useful for
-- spotting Host blocks, ProxyCommand entries, and option drift.
SELECT * FROM ssh_configs ORDER BY ssh_config_file, block;
