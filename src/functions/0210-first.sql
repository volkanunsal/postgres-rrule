-- Returns the first occurrence of a recurrence rule.
--
-- Parameters:
--   rrule   - The recurrence rule defining the pattern
--   dtstart - The starting timestamp from which to find the first occurrence
--
-- Returns: The first timestamp that satisfies the recurrence rule
CREATE OR REPLACE FUNCTION _rrule.first("rrule" _rrule.RRULE, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$
BEGIN
  RETURN (SELECT "ts"
  FROM _rrule.all_starts("rrule", "dtstart") "ts"
  WHERE "ts" >= "dtstart"
  ORDER BY "ts" ASC
  LIMIT 1);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE PARALLEL SAFE;

-- Returns the first occurrence of a recurrence rule (parsed from text).
--
-- Parameters:
--   rrule   - RRULE string (e.g., "RRULE:FREQ=DAILY;COUNT=10")
--   dtstart - The starting timestamp
--
-- Returns: The first timestamp that satisfies the recurrence rule
CREATE OR REPLACE FUNCTION _rrule.first("rrule" TEXT, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$
  SELECT _rrule.first(_rrule.rrule("rrule"), "dtstart");
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Returns the first occurrence of a ruleset.
--
-- Parameters:
--   rruleset - The ruleset containing RRULE, DTSTART, RDATE, EXDATE
--
-- Returns: The earliest timestamp from the ruleset (including RDATE, excluding EXDATE)
CREATE OR REPLACE FUNCTION _rrule.first("rruleset" _rrule.RRULESET)
RETURNS TIMESTAMP AS $$
  SELECT occurrence
  FROM _rrule.occurrences("rruleset") occurrence
  ORDER BY occurrence ASC LIMIT 1;
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Returns the first occurrence from multiple rulesets.
--
-- Parameters:
--   rruleset_array - Array of rulesets to combine
--
-- Returns: The earliest timestamp across all rulesets
CREATE OR REPLACE FUNCTION _rrule.first("rruleset_array" _rrule.RRULESET[])
RETURNS TIMESTAMP AS $$
  SELECT occurrence
  FROM _rrule.occurrences("rruleset_array", '(,)'::TSRANGE) occurrence
  ORDER BY occurrence ASC LIMIT 1;
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;
