-- Additional function documentation for public API functions
-- This supplements existing COMMENT statements in individual function files

-- =============================================================================
-- Core API Functions
-- =============================================================================

-- is_finite overloads
COMMENT ON FUNCTION _rrule.is_finite(_rrule.RRULE)
IS 'Returns true if the recurrence rule has a defined end via COUNT or UNTIL.';

COMMENT ON FUNCTION _rrule.is_finite(TEXT)
IS 'Returns true if the recurrence rule (parsed from text) has a defined end via COUNT or UNTIL.';

COMMENT ON FUNCTION _rrule.is_finite(_rrule.RRULESET)
IS 'Returns true if the ruleset has a defined end via COUNT or UNTIL.';

COMMENT ON FUNCTION _rrule.is_finite(_rrule.RRULESET[])
IS 'Returns true if any ruleset in the array has a defined end via COUNT or UNTIL.';

-- first/last overloads
COMMENT ON FUNCTION _rrule.first(_rrule.RRULE, TIMESTAMP)
IS 'Returns the first occurrence of a recurrence rule starting from the given timestamp.';

COMMENT ON FUNCTION _rrule.first(TEXT, TIMESTAMP)
IS 'Returns the first occurrence of a recurrence rule (parsed from text) starting from the given timestamp.';

COMMENT ON FUNCTION _rrule.first(_rrule.RRULESET)
IS 'Returns the first occurrence of a ruleset.';

COMMENT ON FUNCTION _rrule.first(_rrule.RRULESET[])
IS 'Returns the first occurrence from an array of rulesets.';

COMMENT ON FUNCTION _rrule.last(_rrule.RRULE, TIMESTAMP)
IS 'Returns the last occurrence of a recurrence rule. Requires the rule to have COUNT or UNTIL.';

COMMENT ON FUNCTION _rrule.last(TEXT, TIMESTAMP)
IS 'Returns the last occurrence of a recurrence rule (parsed from text). Requires the rule to have COUNT or UNTIL.';

COMMENT ON FUNCTION _rrule.last(_rrule.RRULESET)
IS 'Returns the last occurrence of a ruleset. Requires the ruleset to be finite.';

COMMENT ON FUNCTION _rrule.last(_rrule.RRULESET[])
IS 'Returns the last occurrence from an array of rulesets. Returns NULL if any ruleset is infinite.';

-- before/after overloads
COMMENT ON FUNCTION _rrule.before(_rrule.RRULE, TIMESTAMP, TIMESTAMP)
IS 'Returns all occurrences of a recurrence rule that occur before a given timestamp.';

COMMENT ON FUNCTION _rrule.before(TEXT, TIMESTAMP, TIMESTAMP)
IS 'Returns all occurrences of a recurrence rule (parsed from text) that occur before a given timestamp.';

COMMENT ON FUNCTION _rrule.before(_rrule.RRULESET, TIMESTAMP)
IS 'Returns all occurrences of a ruleset that occur before a given timestamp.';

COMMENT ON FUNCTION _rrule.before(_rrule.RRULESET[], TIMESTAMP)
IS 'Returns all occurrences from an array of rulesets that occur before a given timestamp.';

COMMENT ON FUNCTION _rrule.after(_rrule.RRULE, TIMESTAMP, TIMESTAMP)
IS 'Returns all occurrences of a recurrence rule that occur after a given timestamp.';

COMMENT ON FUNCTION _rrule.after(TEXT, TIMESTAMP, TIMESTAMP)
IS 'Returns all occurrences of a recurrence rule (parsed from text) that occur after a given timestamp.';

COMMENT ON FUNCTION _rrule.after(_rrule.RRULESET, TIMESTAMP)
IS 'Returns all occurrences of a ruleset that occur after a given timestamp.';

COMMENT ON FUNCTION _rrule.after(_rrule.RRULESET[], TIMESTAMP)
IS 'Returns all occurrences from an array of rulesets that occur after a given timestamp.';

-- occurrences overloads
COMMENT ON FUNCTION _rrule.occurrences(_rrule.RRULE, TIMESTAMP)
IS 'Generates all occurrences for a recurrence rule starting from the given timestamp.';

COMMENT ON FUNCTION _rrule.occurrences(_rrule.RRULE, TIMESTAMP, TSRANGE)
IS 'Generates occurrences for a recurrence rule within a specific time range.';

COMMENT ON FUNCTION _rrule.occurrences(TEXT, TIMESTAMP, TSRANGE)
IS 'Generates occurrences for a recurrence rule (parsed from text) within a specific time range.';

COMMENT ON FUNCTION _rrule.occurrences(_rrule.RRULESET, TSRANGE)
IS 'Generates occurrences for a ruleset within a time range, including RDATE and excluding EXDATE.';

COMMENT ON FUNCTION _rrule.occurrences(_rrule.RRULESET)
IS 'Generates all occurrences for a ruleset, including RDATE and excluding EXDATE.';

COMMENT ON FUNCTION _rrule.occurrences(_rrule.RRULESET[], TSRANGE)
IS 'Generates all occurrences from multiple rulesets within a time range.';

-- Containment functions
COMMENT ON FUNCTION _rrule.contains_timestamp(_rrule.RRULESET, TIMESTAMP)
IS 'Returns true if the given timestamp occurs within the ruleset. Matches by date, ignoring time.';

COMMENT ON FUNCTION _rrule.rruleset_array_contains_timestamp(_rrule.RRULESET[], TIMESTAMP)
IS 'Returns true if the given timestamp occurs within any ruleset in the array.';

COMMENT ON FUNCTION _rrule.rruleset_has_after_timestamp(_rrule.RRULESET, TIMESTAMP)
IS 'Returns true if the ruleset has any occurrences after the given timestamp.';

COMMENT ON FUNCTION _rrule.rruleset_has_before_timestamp(_rrule.RRULESET, TIMESTAMP)
IS 'Returns true if the ruleset has any occurrences before the given timestamp.';

COMMENT ON FUNCTION _rrule.rruleset_array_has_after_timestamp(_rrule.RRULESET[], TIMESTAMP)
IS 'Returns true if any ruleset in the array has occurrences after the given timestamp.';

COMMENT ON FUNCTION _rrule.rruleset_array_has_before_timestamp(_rrule.RRULESET[], TIMESTAMP)
IS 'Returns true if any ruleset in the array has occurrences before the given timestamp.';

-- Parsing and conversion functions
COMMENT ON FUNCTION _rrule.rrule(TEXT)
IS 'Parses an RRULE string (e.g., "RRULE:FREQ=DAILY;COUNT=10") into an RRULE type. Validates according to RFC 5545.';

COMMENT ON FUNCTION _rrule.rruleset(TEXT)
IS 'Parses a multiline RRULESET string (with DTSTART, RRULE, EXDATE, RDATE) into an RRULESET type.';

COMMENT ON FUNCTION _rrule.jsonb_to_rrule(JSONB)
IS 'Converts a JSONB object to an RRULE type. Validates according to RFC 5545.';

COMMENT ON FUNCTION _rrule.jsonb_to_rruleset(JSONB)
IS 'Converts a JSONB object to an RRULESET type. Validates DTSTART and DTEND.';

COMMENT ON FUNCTION _rrule.jsonb_to_rruleset_array(JSONB)
IS 'Converts a JSONB array to an array of RRULESET types.';

COMMENT ON FUNCTION _rrule.rrule_to_jsonb(_rrule.RRULE)
IS 'Converts an RRULE type to a JSONB object, stripping null values.';

COMMENT ON FUNCTION _rrule.rruleset_to_jsonb(_rrule.RRULESET)
IS 'Converts an RRULESET type to a JSONB object, stripping null values.';

COMMENT ON FUNCTION _rrule.rruleset_array_to_jsonb(_rrule.RRULESET[])
IS 'Converts an array of RRULESET types to a JSONB array.';

COMMENT ON FUNCTION _rrule.text(_rrule.RRULE)
IS 'Converts an RRULE type back to an RRULE string (e.g., "RRULE:FREQ=DAILY;COUNT=10").';

-- Comparison functions
COMMENT ON FUNCTION _rrule.contains(_rrule.RRULE, _rrule.RRULE)
IS 'Returns true if all occurrences generated by the second rule would also be generated by the first rule.';

COMMENT ON FUNCTION _rrule.contained_by(_rrule.RRULE, _rrule.RRULE)
IS 'Returns true if the first rule is contained by the second rule (inverse of contains).';
