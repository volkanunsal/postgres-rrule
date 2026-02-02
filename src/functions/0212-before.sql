-- Returns all occurrences that occur before a given timestamp.
--
-- Parameters:
--   rrule   - The recurrence rule defining the pattern
--   dtstart - The starting timestamp from which to generate occurrences
--   when    - The cutoff timestamp (occurrences must be before or equal to this)
--
-- Returns: Set of timestamps that occur before or at the "when" timestamp
CREATE OR REPLACE FUNCTION _rrule.before(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP,
  "when" TIMESTAMP
)
RETURNS SETOF TIMESTAMP AS $$
  SELECT *
  FROM _rrule.occurrences("rrule", "dtstart", tsrange(NULL, "when", '[]'));
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Returns all occurrences (parsed from text) that occur before a given timestamp.
--
-- Parameters:
--   rrule   - RRULE string (e.g., "RRULE:FREQ=DAILY;COUNT=10")
--   dtstart - The starting timestamp
--   when    - The cutoff timestamp
--
-- Returns: Set of timestamps that occur before or at the "when" timestamp
CREATE OR REPLACE FUNCTION _rrule.before("rrule" TEXT, "dtstart" TIMESTAMP, "when" TIMESTAMP)
RETURNS SETOF TIMESTAMP AS $$
  SELECT _rrule.before(_rrule.rrule("rrule"), "dtstart", "when");
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Returns all occurrences from a ruleset that occur before a given timestamp.
--
-- Parameters:
--   rruleset - The ruleset containing RRULE, DTSTART, RDATE, EXDATE
--   when     - The cutoff timestamp
--
-- Returns: Set of timestamps that occur before or at the "when" timestamp
CREATE OR REPLACE FUNCTION _rrule.before("rruleset" _rrule.RRULESET, "when" TIMESTAMP)
RETURNS SETOF TIMESTAMP AS $$
  SELECT *
  FROM _rrule.occurrences("rruleset", tsrange(NULL, "when", '[]'));
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Returns all occurrences from multiple rulesets that occur before a given timestamp.
--
-- Parameters:
--   rruleset_array - Array of rulesets to combine
--   when           - The cutoff timestamp
--
-- Returns: Combined set of timestamps from all rulesets that occur before or at "when"
CREATE OR REPLACE FUNCTION _rrule.before("rruleset_array" _rrule.RRULESET[], "when" TIMESTAMP)
RETURNS SETOF TIMESTAMP AS $$
  SELECT *
  FROM _rrule.occurrences("rruleset_array", tsrange(NULL, "when", '[]'));
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

