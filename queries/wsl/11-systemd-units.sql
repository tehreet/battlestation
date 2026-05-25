-- systemd_units — installed systemd units. Platform-conditional: requires
-- systemd to be enabled in /etc/wsl.conf (boot.systemd=true). The capture
-- script catches the error and writes [] if unavailable.
SELECT id, description, load_state, active_state, sub_state, fragment_path, unit_file_state
FROM systemd_units
ORDER BY id;
