-- registry — autorun-relevant keys (Run/RunOnce + Image File Execution Options).
-- These are the classic persistence locations; surface anything that lives there.
SELECT key, name, type, data, mtime
FROM registry
WHERE key LIKE 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run%'
   OR key LIKE 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce%'
   OR key LIKE 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run%'
   OR key LIKE 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce%'
   OR key LIKE 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options%'
ORDER BY key, name;
