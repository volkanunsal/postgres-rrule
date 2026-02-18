-- Resolves a BYMONTHDAY value (positive or negative) to the actual day number
-- for a given month.
--
-- RFC 5545 allows negative BYMONTHDAY values where:
--   -1 = last day of month
--   -2 = second-to-last day of month
--   etc.
--
-- Parameters:
--   bymonthday_value  - The BYMONTHDAY value (positive 1-31 or negative -31 to -1)
--   month_timestamp   - A timestamp within the target month (used to determine days in month)
--
-- Returns: The actual day number (1-31), or NULL if the resolved day is out of range
--          for the given month (e.g., BYMONTHDAY=31 in a 30-day month).
CREATE OR REPLACE FUNCTION _rrule.resolve_bymonthday(
  bymonthday_value INTEGER,
  month_timestamp TIMESTAMP
)
RETURNS INTEGER AS $$
DECLARE
  days_in_month INTEGER;
  resolved_day INTEGER;
BEGIN
  -- Calculate the number of days in the month containing month_timestamp
  days_in_month := EXTRACT(DAY FROM (
    date_trunc('month', month_timestamp) + INTERVAL '1 month' - INTERVAL '1 day'
  ))::INTEGER;

  IF bymonthday_value < 0 THEN
    -- Negative value: count from end of month
    -- -1 = last day (days_in_month), -2 = second-to-last (days_in_month - 1), etc.
    resolved_day := days_in_month + 1 + bymonthday_value;
    -- If resolved day is less than 1, the value is out of range for this month
    IF resolved_day < 1 THEN
      RETURN NULL;
    END IF;
  ELSE
    -- Positive value: use as-is, but return NULL if greater than days in month
    resolved_day := bymonthday_value;
    IF resolved_day > days_in_month THEN
      RETURN NULL;
    END IF;
  END IF;

  RETURN resolved_day;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
