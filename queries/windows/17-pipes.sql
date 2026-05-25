-- pipes — named pipes currently published. Interesting forensic surface;
-- changes here are worth a second look.
SELECT pid, name, instances, max_instances, flags
FROM pipes
ORDER BY name COLLATE NOCASE;
