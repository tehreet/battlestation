-- drivers — loaded device drivers. Large output kept in its own file so the
-- diff is digestible and the rest of the baseline isn't drowned in driver
-- churn from Windows Update.
SELECT * FROM drivers ORDER BY device_name COLLATE NOCASE, driver_key;
