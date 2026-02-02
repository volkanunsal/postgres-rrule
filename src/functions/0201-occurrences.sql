-- Generates all occurrences for a recurrence rule.
--
-- Parameters:
--   rrule   - The recurrence rule defining the pattern (frequency, interval, BY* constraints)
--   dtstart - The starting timestamp from which to generate occurrences
--
-- Returns: Set of timestamps representing each occurrence
CREATE OR REPLACE FUNCTION _rrule.occurrences(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
)
RETURNS SETOF TIMESTAMP AS $$
  WITH "starts" AS (
    SELECT "start"
    FROM _rrule.all_starts($1, $2) "start"
  ),
  "params" AS (
    SELECT
      "until",
      "interval"
    FROM _rrule.until($1, $2) "until"
    FULL OUTER JOIN _rrule.build_interval($1) "interval" ON (true)
  ),
  "generated" AS (
    SELECT generate_series("start", "until", "interval") "occurrence"
    FROM "params"
    FULL OUTER JOIN "starts" ON (true)
  ),
  "ordered" AS (
    SELECT DISTINCT "occurrence"
    FROM "generated"
    WHERE "occurrence" >= "dtstart"
    ORDER BY "occurrence"
  ),
  "tagged" AS (
    SELECT
      row_number() OVER (),
      "occurrence"
    FROM "ordered"
  )
  SELECT "occurrence"
  FROM "tagged"
  WHERE "row_number" <= "rrule"."count"
  OR "rrule"."count" IS NULL
  ORDER BY "occurrence";
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Generates occurrences for a recurrence rule within a specific time range.
--
-- Parameters:
--   rrule   - The recurrence rule defining the pattern
--   dtstart - The starting timestamp from which to generate occurrences
--   between - Time range (tsrange) to filter occurrences (e.g., '[2026-01-01, 2026-02-01)')
--
-- Returns: Set of timestamps within the specified range
CREATE OR REPLACE FUNCTION _rrule.occurrences("rrule" _rrule.RRULE, "dtstart" TIMESTAMP, "between" TSRANGE)
RETURNS SETOF TIMESTAMP AS $$
  SELECT "occurrence"
  FROM _rrule.occurrences("rrule", "dtstart") "occurrence"
  WHERE "occurrence" <@ "between";
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Generates occurrences for a recurrence rule (parsed from text) within a time range.
--
-- Parameters:
--   rrule   - RRULE string (e.g., "RRULE:FREQ=DAILY;COUNT=10")
--   dtstart - The starting timestamp from which to generate occurrences
--   between - Time range (tsrange) to filter occurrences
--
-- Returns: Set of timestamps within the specified range
CREATE OR REPLACE FUNCTION _rrule.occurrences("rrule" TEXT, "dtstart" TIMESTAMP, "between" TSRANGE)
RETURNS SETOF TIMESTAMP AS $$
  SELECT "occurrence"
  FROM _rrule.occurrences(_rrule.rrule("rrule"), "dtstart") "occurrence"
  WHERE "occurrence" <@ "between";
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Generates occurrences for a ruleset within a time range, including RDATE and excluding EXDATE.
--
-- Parameters:
--   rruleset - The ruleset containing RRULE[], DTSTART, DTEND, RDATE, EXDATE, EXRULE[]
--   tsrange  - Time range to filter occurrences (e.g., '[2026-01-01, 2026-02-01)')
--
-- Returns: Set of timestamps within the range, with RDATE included and EXDATE/EXRULE excluded
-- Note: Multiple RRULEs are combined (UNION), multiple EXRULEs are combined (UNION)
CREATE OR REPLACE FUNCTION _rrule.occurrences(
  "rruleset" _rrule.RRULESET,
  "tsrange" TSRANGE
)
RETURNS SETOF TIMESTAMP AS $$
  SELECT "occurrence" FROM (
    -- Generate occurrences from all RRULEs
    SELECT _rrule.occurrences(r, $1."dtstart", $2) AS "occurrence"
    FROM unnest($1."rrule") AS r
    UNION
    -- Add RDATE occurrences
    SELECT d AS "occurrence" FROM unnest($1."rdate") AS d
  ) AS rdates("occurrence")
  EXCEPT
  SELECT "occurrence" FROM (
    -- Generate exclusions from all EXRULEs
    SELECT _rrule.occurrences(e, $1."dtstart", $2) AS "occurrence"
    FROM unnest($1."exrule") AS e
    UNION
    -- Add EXDATE exclusions
    SELECT d AS "occurrence" FROM unnest($1."exdate") AS d
  ) AS exdates("occurrence")
  ORDER BY "occurrence";
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Generates all occurrences for a ruleset (unbounded time range).
--
-- Note: DTEND in RFC 5545 defines the duration of each individual occurrence,
-- NOT the end of the recurrence series. Use UNTIL or COUNT in the RRULE to limit occurrences.
--
-- Parameters:
--   rruleset - The ruleset containing RRULE[], DTSTART, DTEND, RDATE, EXDATE, EXRULE[]
--
-- Returns: Set of all timestamps with RDATE included and EXDATE/EXRULE excluded
CREATE OR REPLACE FUNCTION _rrule.occurrences("rruleset" _rrule.RRULESET)
RETURNS SETOF TIMESTAMP AS $$
  SELECT _rrule.occurrences("rruleset", '(,)'::TSRANGE);
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Generates all occurrences from multiple rulesets within a time range.
-- Rewritten to eliminate dynamic SQL for better security and maintainability.
--
-- Parameters:
--   rruleset_array - Array of rulesets to combine
--   tsrange        - Time range to filter occurrences
--
-- Returns: Combined set of timestamps from all rulesets, sorted chronologically
CREATE OR REPLACE FUNCTION _rrule.occurrences(
  "rruleset_array" _rrule.RRULESET[],
  "tsrange" TSRANGE
)
RETURNS SETOF TIMESTAMP AS $$
  SELECT DISTINCT occurrence
  FROM unnest("rruleset_array") AS rruleset,
       LATERAL _rrule.occurrences(rruleset, "tsrange") AS occurrence
  ORDER BY occurrence;
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;