-- All of the function(rrule, ...) forms also accept a text argument, which will
-- be parsed using the RFC-compliant parser.

-- Returns true if the recurrence rule has a defined end (COUNT or UNTIL).
--
-- Parameters:
--   rrule - The recurrence rule to check
--
-- Returns: True if the rule has COUNT or UNTIL set, false if it recurs infinitely
CREATE OR REPLACE FUNCTION _rrule.is_finite("rrule" _rrule.RRULE)
RETURNS BOOLEAN AS $$
  SELECT "rrule"."count" IS NOT NULL OR "rrule"."until" IS NOT NULL;
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Returns true if the recurrence rule (parsed from text) has a defined end.
--
-- Parameters:
--   rrule - RRULE string (e.g., "RRULE:FREQ=DAILY;COUNT=10")
--
-- Returns: True if the rule has COUNT or UNTIL set
CREATE OR REPLACE FUNCTION _rrule.is_finite("rrule" TEXT)
RETURNS BOOLEAN AS $$
  SELECT _rrule.is_finite(_rrule.rrule("rrule"));
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Returns true if the ruleset has a defined end.
--
-- Parameters:
--   rruleset - The ruleset containing RRULE[] and optional EXRULE[]
--
-- Returns: True if ALL RRULEs have COUNT or UNTIL set (infinite if any RRULE is infinite)
CREATE OR REPLACE FUNCTION _rrule.is_finite("rruleset" _rrule.RRULESET)
RETURNS BOOLEAN AS $$
  SELECT COALESCE(bool_and(_rrule.is_finite(r)), true)
  FROM unnest("rruleset"."rrule") AS r;
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Returns true if any ruleset in the array has a defined end.
--
-- Parameters:
--   rruleset_array - Array of rulesets to check
--
-- Returns: True if at least one ruleset has COUNT or UNTIL set
CREATE OR REPLACE FUNCTION _rrule.is_finite("rruleset_array" _rrule.RRULESET[])
RETURNS BOOLEAN AS $$
  SELECT COALESCE(bool_or(_rrule.is_finite(item)), false)
  FROM unnest("rruleset_array") AS item;
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;


