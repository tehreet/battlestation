-- physical_disk_performance — current snapshot of physical disk perf counters.
-- Only the identifying + cumulative columns; live IO rates aren't useful in a baseline.
SELECT name, avg_disk_bytes_per_read, avg_disk_bytes_per_write
FROM physical_disk_performance;
