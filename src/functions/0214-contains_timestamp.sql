-- Returns true if the given timestamp occurs within the ruleset. Matches by date only, ignoring time.
--
-- Parameters:
--   rruleset - The ruleset containing RRULE, DTSTART, RDATE, EXDATE
--   timestamp - The timestamp to check (only the date portion is compared)
--
-- Returns: True if the date of the timestamp matches any occurrence date in the ruleset
CREATE OR REPLACE FUNCTION _rrule.contains_timestamp(_rrule.RRULESET, TIMESTAMP)
RETURNS BOOLEAN AS $$
DECLARE
  inSet boolean;
BEGIN
  -- Checks if the timestamp's date matches any occurrence date.
  -- Searches occurrences starting 1 month before the target date to ensure we capture it.
  SELECT COUNT(*) > 0
  INTO inSet
  FROM _rrule.after($1, $2 - INTERVAL '1 month') "ts"
  WHERE "ts"::date = $2::date;

  RETURN inSet;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
