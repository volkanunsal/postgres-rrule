

-- Returns the last occurrence of a recurrence rule. Requires the rule to be finite (COUNT or UNTIL).
--
-- Parameters:
--   rrule   - The recurrence rule defining the pattern
--   dtstart - The starting timestamp
--
-- Returns: The last timestamp that satisfies the recurrence rule, or NULL if infinite
CREATE OR REPLACE FUNCTION _rrule.last("rrule" _rrule.RRULE, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$
  SELECT occurrence
  FROM _rrule.occurrences("rrule", "dtstart") occurrence
  ORDER BY occurrence DESC LIMIT 1;
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Returns the last occurrence of a recurrence rule (parsed from text).
--
-- Parameters:
--   rrule   - RRULE string (e.g., "RRULE:FREQ=DAILY;COUNT=10")
--   dtstart - The starting timestamp
--
-- Returns: The last timestamp that satisfies the recurrence rule, or NULL if infinite
CREATE OR REPLACE FUNCTION _rrule.last("rrule" TEXT, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$
  SELECT _rrule.last(_rrule.rrule("rrule"), "dtstart");
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Returns the last occurrence of a ruleset. Requires the ruleset to be finite.
--
-- Parameters:
--   rruleset - The ruleset containing RRULE, DTSTART, RDATE, EXDATE
--
-- Returns: The latest timestamp from the ruleset, or NULL if infinite
CREATE OR REPLACE FUNCTION _rrule.last("rruleset" _rrule.RRULESET)
RETURNS TIMESTAMP AS $$
  SELECT occurrence
  FROM _rrule.occurrences("rruleset") occurrence
  ORDER BY occurrence DESC LIMIT 1;
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Returns the last occurrence from multiple rulesets.
--
-- Parameters:
--   rruleset_array - Array of rulesets to combine
--
-- Returns: The latest timestamp across all rulesets, or NULL if any ruleset is infinite
CREATE OR REPLACE FUNCTION _rrule.last("rruleset_array" _rrule.RRULESET[])
RETURNS SETOF TIMESTAMP AS $$
BEGIN
  IF (SELECT _rrule.is_finite("rruleset_array")) THEN
    RETURN QUERY SELECT occurrence
    FROM _rrule.occurrences("rruleset_array", '(,)'::TSRANGE) occurrence
    ORDER BY occurrence DESC LIMIT 1;
  ELSE
    RETURN QUERY SELECT NULL::TIMESTAMP;
  END IF;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE PARALLEL SAFE;

