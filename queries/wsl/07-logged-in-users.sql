-- logged_in_users — sessions in utmp (will usually include the WSL shell)
SELECT * FROM logged_in_users ORDER BY user, host;
