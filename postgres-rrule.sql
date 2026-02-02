DROP SCHEMA IF EXISTS _rrule CASCADE;

DROP CAST IF EXISTS (_rrule.RRULE AS TEXT);
DROP CAST IF EXISTS (TEXT AS _rrule.RRULE);

CREATE SCHEMA _rrule;

COMMENT ON SCHEMA _rrule IS
'PostgreSQL implementation of RFC 5545 recurrence rules (RRULE).

This schema provides types and functions for working with iCalendar recurrence rules,
allowing complex recurring event patterns to be stored and queried efficiently.

Main types:
- RRULE: Single recurrence rule with frequency, interval, and BY* constraints
- RRULESET: Collection of rules with DTSTART, DTEND, RDATE, and EXDATE
- FREQ: Enumeration of recurrence frequencies (YEARLY, MONTHLY, WEEKLY, DAILY)
- DAY: Enumeration of weekdays (MO, TU, WE, TH, FR, SA, SU)

Key functions:
- rrule(TEXT): Parse RRULE string into RRULE type
- occurrences(): Generate timestamps for recurring events
- is_finite(): Check if recurrence has a defined end
- first(), last(), before(), after(): Query occurrence boundaries
- contains_timestamp(): Check if timestamp matches recurrence pattern
- jsonb_to_rrule(), rrule_to_jsonb(): Convert between RRULE and JSONB

For more information, see: https://datatracker.ietf.org/doc/html/rfc5545#section-3.3.10
';

CREATE TYPE _rrule.FREQ AS ENUM (
  'YEARLY',
  'MONTHLY',
  'WEEKLY',
  'DAILY'
);

CREATE TYPE _rrule.DAY AS ENUM (
  'MO',
  'TU',
  'WE',
  'TH',
  'FR',
  'SA',
  'SU'
);


CREATE TABLE _rrule.RRULE (
  "freq" _rrule.FREQ NOT NULL,
  "interval" INTEGER DEFAULT 1 NOT NULL CHECK(0 < "interval"),
  "count" INTEGER,  -- Number of occurrences to generate (RFC 5545: positive integer)
  "until" TIMESTAMP,  -- End date for recurrence (RFC 5545: cannot coexist with COUNT)

  -- Time component constraints (RFC 5545 section 3.3.10)
  "bysecond" INTEGER[] CHECK (0 <= ALL("bysecond") AND 60 > ALL("bysecond")),  -- 0-59 (60 for leap second)
  "byminute" INTEGER[] CHECK (0 <= ALL("byminute") AND 60 > ALL("byminute")),  -- 0-59
  "byhour" INTEGER[] CHECK (0 <= ALL("byhour") AND 24 > ALL("byhour")),        -- 0-23
  "byday" _rrule.DAY[],  -- MO, TU, WE, TH, FR, SA, SU (optionally prefixed with ordinal)

  -- Date component constraints (RFC 5545 section 3.3.10)
  "bymonthday" INTEGER[] CHECK (31 >= ALL("bymonthday") AND 0 <> ALL("bymonthday") AND -31 <= ALL("bymonthday")),  -- 1-31 or -31 to -1 (negative counts from end)
  "byyearday" INTEGER[] CHECK (366 >= ALL("byyearday") AND 0 <> ALL("byyearday") AND -366 <= ALL("byyearday")),    -- 1-366 or -366 to -1 (leap year aware)
  "byweekno" INTEGER[] CHECK (53 >= ALL("byweekno") AND 0 <> ALL("byweekno") AND -53 <= ALL("byweekno")),          -- 1-53 or -53 to -1 (ISO week numbers)
  "bymonth" INTEGER[] CHECK (0 < ALL("bymonth") AND 12 >= ALL("bymonth")),     -- 1-12 (January through December)
  "bysetpos" INTEGER[] CHECK(366 >= ALL("bysetpos") AND 0 <> ALL("bysetpos") AND -366 <= ALL("bysetpos")),         -- Position in occurrence set

  "wkst" _rrule.DAY,  -- Week start day (RFC 5545 default: MO)

  -- RFC 5545: BYWEEKNO is only valid for YEARLY frequency
  CONSTRAINT freq_yearly_if_byweekno CHECK("freq" = 'YEARLY' OR "byweekno" IS NULL)
);


CREATE TABLE _rrule.RRULESET (
  "dtstart" TIMESTAMP NOT NULL,
  "dtend" TIMESTAMP,
  "rrule" _rrule.RRULE,
  "exrule" _rrule.RRULE,
  "rdate" TIMESTAMP[],
  "exdate" TIMESTAMP[]
);


CREATE TYPE _rrule.exploded_interval AS (
  "months" INTEGER,
  "days" INTEGER,
  "seconds" INTEGER
);CREATE OR REPLACE FUNCTION _rrule.explode_interval(INTERVAL)
RETURNS _rrule.EXPLODED_INTERVAL AS $$
  SELECT
    (
      EXTRACT(YEAR FROM $1) * 12 + EXTRACT(MONTH FROM $1),
      EXTRACT(DAY FROM $1),
      EXTRACT(HOUR FROM $1) * 3600 + EXTRACT(MINUTE FROM $1) * 60 + EXTRACT(SECOND FROM $1)
    )::_rrule.EXPLODED_INTERVAL;

$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;


CREATE OR REPLACE FUNCTION _rrule.factor(INTEGER, INTEGER)
RETURNS INTEGER AS $$
  SELECT
    CASE
      WHEN ($1 = 0 AND $2 = 0) THEN NULL
      WHEN ($1 = 0 OR $2 = 0) THEN 0
      WHEN ($1 % $2 <> 0) THEN 0
      ELSE $1 / $2
    END;

$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;


CREATE OR REPLACE FUNCTION _rrule.interval_contains(INTERVAL, INTERVAL)
RETURNS BOOLEAN AS $$
  -- Any fields that have 0 must have zero in each.

  WITH factors AS (
    SELECT
      _rrule.factor(a.months, b.months) AS months,
      _rrule.factor(a.days, b.days) AS days,
      _rrule.factor(a.seconds, b.seconds) AS seconds
    FROM _rrule.explode_interval($2) a, _rrule.explode_interval($1) b
  )
  SELECT
    COALESCE(months <> 0, TRUE)
      AND
    COALESCE(days <> 0, TRUE)
      AND
    COALESCE(seconds <> 0, TRUE)
      AND
    COALESCE(months = days, TRUE)
      AND
    COALESCE(months = seconds, TRUE)
  FROM factors;

$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;CREATE OR REPLACE FUNCTION _rrule.parse_line (input TEXT, marker TEXT)
RETURNS SETOF TEXT AS $$
  -- Clear spaces at the front of the lines
  WITH trimmed_input as (SELECT regexp_replace(input, '^\s*',  '', 'ng') "r"),
  -- Clear all lines except the ones starting with marker
  filtered_lines as (SELECT regexp_replace(trimmed_input."r", '^(?!' || marker || ').*?$',  '', 'ng') "r" FROM trimmed_input),
  -- Replace carriage returns with blank space.
  normalized_text as (SELECT regexp_replace(filtered_lines."r", E'[\\n\\r]+',  '', 'g') "r" FROM filtered_lines),
  -- Remove marker prefix.
  marker_removed as (SELECT regexp_replace(normalized_text."r", marker || ':(.*)$', '\1') "r" FROM normalized_text),
  -- Trim
  trimmed_result as (SELECT trim(marker_removed."r") "r" FROM marker_removed),
  -- Split each key-value pair into a row in a table
  split_pairs as (SELECT regexp_split_to_table(trimmed_result."r", ';') "r" FROM trimmed_result)
  -- Split each key value pair into an array, e.g. {'FREQ', 'DAILY'}
  SELECT "r" AS "y"
  FROM split_pairs
  WHERE "r" != '';
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _rrule.timestamp_to_day("ts" TIMESTAMP) RETURNS _rrule.DAY AS $$
  SELECT CAST(CASE to_char("ts", 'DY')
    WHEN 'MON' THEN 'MO'
    WHEN 'TUE' THEN 'TU'
    WHEN 'WED' THEN 'WE'
    WHEN 'THU' THEN 'TH'
    WHEN 'FRI' THEN 'FR'
    WHEN 'SAT' THEN 'SA'
    WHEN 'SUN' THEN 'SU'
  END as _rrule.DAY);
$$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;

CREATE CAST (TIMESTAMP AS _rrule.DAY)
  WITH FUNCTION _rrule.timestamp_to_day(TIMESTAMP)
  AS IMPLICIT;CREATE OR REPLACE FUNCTION _rrule.enum_index_of(anyenum)
RETURNS INTEGER AS $$
    SELECT row_number FROM (
        SELECT (row_number() OVER ())::INTEGER, "value"
        FROM unnest(enum_range($1)) "value"
    ) x
    WHERE "value" = $1;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
COMMENT ON FUNCTION _rrule.enum_index_of(anyenum) IS 'Given an ENUM value, return it''s index.';
CREATE OR REPLACE FUNCTION _rrule.integer_array (TEXT)
RETURNS integer[] AS $$
  SELECT ('{' || $1 || '}')::integer[];
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
COMMENT ON FUNCTION _rrule.integer_array (text) IS 'Coerce a text string into an array of integers';



CREATE OR REPLACE FUNCTION _rrule.day_array (TEXT)
RETURNS _rrule.DAY[] AS $$
  SELECT ('{' || $1 || '}')::_rrule.DAY[];
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
COMMENT ON FUNCTION _rrule.day_array (text) IS 'Coerce a text string into an array of "rrule"."day"';



CREATE OR REPLACE FUNCTION _rrule.array_join(ANYARRAY, "delimiter" TEXT)
RETURNS TEXT AS $$
  SELECT string_agg(x::text, "delimiter")
  FROM unnest($1) x;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

CREATE OR REPLACE FUNCTION _rrule.explode(_rrule.RRULE)
RETURNS SETOF _rrule.RRULE AS 'SELECT $1' LANGUAGE SQL IMMUTABLE STRICT;
COMMENT ON FUNCTION _rrule.explode (_rrule.RRULE) IS 'Helper function to allow SELECT * FROM explode(rrule)';
CREATE OR REPLACE FUNCTION _rrule.compare_equal(_rrule.RRULE, _rrule.RRULE)
RETURNS BOOLEAN AS $$
  SELECT count(*) = 1 FROM (
    SELECT * FROM _rrule.explode($1) UNION SELECT * FROM _rrule.explode($2)
  ) AS x;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;



CREATE OR REPLACE FUNCTION _rrule.compare_not_equal(_rrule.RRULE, _rrule.RRULE)
RETURNS BOOLEAN AS $$
  SELECT count(*) = 2 FROM (
    SELECT * FROM _rrule.explode($1) UNION SELECT * FROM _rrule.explode($2)
  ) AS x;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _rrule.build_interval("interval" INTEGER, "freq" _rrule.FREQ)
RETURNS INTERVAL AS $$
DECLARE
  result INTERVAL;
BEGIN
  -- Validate interval to prevent overflow (PostgreSQL supports intervals up to ~178M years)
  -- For practical RRULE usage, limit to 1 million to prevent arithmetic issues
  IF "interval" < 1 OR "interval" > 1000000 THEN
    RAISE EXCEPTION 'INTERVAL value % is out of valid range (1 to 1,000,000).', "interval";
  END IF;

  -- Transform ical time interval enums into Postgres intervals, e.g.
  -- "WEEKLY" becomes "WEEKS".
  result := ("interval" || ' ' || regexp_replace(regexp_replace("freq"::TEXT, 'LY', 'S'), 'IS', 'YS'))::INTERVAL;

  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;


CREATE OR REPLACE FUNCTION _rrule.build_interval(_rrule.RRULE)
RETURNS INTERVAL AS $$
  SELECT _rrule.build_interval(COALESCE($1."interval", 1), $1."freq");
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
-- rrule containment.
-- intervals must be compatible.
-- wkst must match
-- all other fields must have $2's value(s) in $1.
CREATE OR REPLACE FUNCTION _rrule.contains(_rrule.RRULE, _rrule.RRULE)
RETURNS BOOLEAN AS $$
  WITH intervals AS (
    SELECT
      _rrule.build_interval($1) AS interval1,
      _rrule.build_interval($2) AS interval2
  )
  SELECT _rrule.interval_contains(interval1, interval2)
    AND COALESCE($1."wkst" = $2."wkst", true)
  FROM intervals;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

CREATE OR REPLACE FUNCTION _rrule.contained_by(_rrule.RRULE, _rrule.RRULE)
RETURNS BOOLEAN AS $$
  SELECT _rrule.contains($2, $1);
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _rrule.until("rrule" _rrule.RRULE, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$
  SELECT min("until")
  FROM (
    SELECT "rrule"."until"
    UNION
    SELECT "dtstart" + _rrule.build_interval("rrule"."interval", "rrule"."freq") * COALESCE("rrule"."count", CASE WHEN "rrule"."until" IS NOT NULL THEN NULL ELSE 1 END) AS "until"
  ) "until" GROUP BY ();

$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
COMMENT ON FUNCTION _rrule.until(_rrule.RRULE, TIMESTAMP) IS 'The calculated "until"" timestamp for the given rrule+dtstart';

-- Computes all possible starting timestamps for a recurrence rule within its first cycle.
--
-- This function determines the "seed" timestamps from which occurrences are generated.
-- For example, a YEARLY rule with BYMONTH=[1,3] has 2 start values (January 1 and March 1).
--
-- Algorithm:
-- 1. Extract time components from dtstart (hour, minute, second, day, month)
-- 2. Generate candidate timestamps by combining:
--    a. BY* parameters (bymonth, bymonthday, byhour, byminute, bysecond)
--    b. Day-of-week constraints (byday) matched within date ranges
-- 3. Filter candidates to ensure they satisfy ALL applicable BY* constraints
-- 4. Return distinct timestamps sorted chronologically
--
-- The function uses UNION to combine three potential sources of timestamps:
-- - Cartesian product of all BY* time parameters
-- - Day-of-week matches within a week window (for byday)
-- - Month-day matches within a 2-month window (for bymonthday)
-- - Month matches within a year window (for bymonth)
--
-- Performance optimization: NULL checks prevent unnecessary generate_series calls
-- when the corresponding BY* parameter is not specified.

CREATE OR REPLACE FUNCTION _rrule.all_starts(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
DECLARE
  months int[];
  hour int := EXTRACT(HOUR FROM "dtstart")::integer;
  minute int := EXTRACT(MINUTE FROM "dtstart")::integer;
  second double precision := EXTRACT(SECOND FROM "dtstart");
  day int := EXTRACT(DAY FROM "dtstart")::integer;
  month int := EXTRACT(MONTH FROM "dtstart")::integer;
  interv INTERVAL := _rrule.build_interval("rrule");
BEGIN
  RETURN QUERY WITH
  "year" as (SELECT EXTRACT(YEAR FROM "dtstart")::integer AS "year"),
  timestamp_combinations as (
    SELECT
      make_timestamp(
        "year"."year",
        COALESCE("bymonth", month),
        COALESCE("bymonthday", day),
        COALESCE("byhour", hour),
        COALESCE("byminute", minute),
        COALESCE("bysecond", second)
      ) as "ts"
    FROM "year"
    LEFT OUTER JOIN unnest(("rrule")."bymonth") AS "bymonth" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."bymonthday") as "bymonthday" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."byhour") AS "byhour" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."byminute") AS "byminute" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."bysecond") AS "bysecond" ON (true)
  ),
  candidate_timestamps as (
    SELECT DISTINCT "ts"
    FROM timestamp_combinations
    UNION
    SELECT "ts" FROM (
      SELECT "ts"
      FROM generate_series("dtstart", dtstart + INTERVAL '6 days', INTERVAL '1 day') "ts"
      WHERE "rrule"."byday" IS NOT NULL
        AND "ts"::_rrule.DAY = ANY("rrule"."byday")
    ) as "ts"
    UNION
    SELECT "ts" FROM (
      SELECT "ts"
      FROM generate_series("dtstart", "dtstart" + INTERVAL '2 months', INTERVAL '1 day') "ts"
      WHERE "rrule"."bymonthday" IS NOT NULL
        AND EXTRACT(DAY FROM "ts") = ANY("rrule"."bymonthday")
        AND "ts" <= ("dtstart" + INTERVAL '2 months')
    ) as "ts"
    UNION
    SELECT "ts" FROM (
      SELECT "ts"
      FROM generate_series("dtstart", "dtstart" + INTERVAL '1 year', INTERVAL '1 month') "ts"
      WHERE "rrule"."bymonth" IS NOT NULL
        AND EXTRACT(MONTH FROM "ts") = ANY("rrule"."bymonth")
    ) as "ts"
  )
  SELECT DISTINCT "ts"
  FROM candidate_timestamps
  WHERE (
    "rrule"."byday" IS NULL OR "ts"::_rrule.DAY = ANY("rrule"."byday")
  )
  AND (
    "rrule"."bymonth" IS NULL OR EXTRACT(MONTH FROM "ts") = ANY("rrule"."bymonth")
  )
  AND (
    "rrule"."bymonthday" IS NULL OR EXTRACT(DAY FROM "ts") = ANY("rrule"."bymonthday")
  )
  ORDER BY "ts";

END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE PARALLEL SAFE;
-- Helper function to check if an RRULE has any BY* parameters set.
-- Used for BYSETPOS validation which requires at least one other BY* parameter.
CREATE OR REPLACE FUNCTION _rrule.has_any_by_rule(r _rrule.RRULE)
RETURNS BOOLEAN AS $$
  SELECT (
    r."bymonth" IS NOT NULL OR
    r."byweekno" IS NOT NULL OR
    r."byyearday" IS NOT NULL OR
    r."bymonthday" IS NOT NULL OR
    r."byday" IS NOT NULL OR
    r."byhour" IS NOT NULL OR
    r."byminute" IS NOT NULL OR
    r."bysecond" IS NOT NULL
  );
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _rrule.validate_rrule (result _rrule.RRULE)
RETURNS void AS $$
BEGIN
  -- FREQ is required
  IF result."freq" IS NULL THEN
    RAISE EXCEPTION 'FREQ cannot be null.';
  END IF;

  -- FREQ=YEARLY required if BYWEEKNO is provided
  IF result."byweekno" IS NOT NULL AND result."freq" != 'YEARLY' THEN
    RAISE EXCEPTION 'FREQ must be YEARLY if BYWEEKNO is provided.';
  END IF;

  -- Limits on FREQ if byyearday is selected
  IF (result."freq" <> 'YEARLY' AND result."byyearday" IS NOT NULL) THEN
    RAISE EXCEPTION 'BYYEARDAY is only valid when FREQ is YEARLY.';
  END IF;

  IF (result."freq" = 'WEEKLY' AND result."bymonthday" IS NOT NULL) THEN
    RAISE EXCEPTION 'BYMONTHDAY is not valid when FREQ is WEEKLY.';
  END IF;

  -- BY[something-else] is required if BYSETPOS is set.
  IF result."bysetpos" IS NOT NULL AND NOT _rrule.has_any_by_rule(result) THEN
    RAISE EXCEPTION 'BYSETPOS requires at least one other BY* parameter.';
  END IF;

  IF result."freq" = 'DAILY' AND result."byday" IS NOT NULL THEN
    RAISE EXCEPTION 'BYDAY is not valid when FREQ is DAILY.';
  END IF;

  IF result."until" IS NOT NULL AND result."count" IS NOT NULL THEN
    RAISE EXCEPTION 'UNTIL and COUNT must not occur in the same recurrence.';
  END IF;

  IF result."interval" IS NOT NULL THEN
    IF (NOT result."interval" > 0) THEN
      RAISE EXCEPTION 'INTERVAL must be a non-zero integer.';
    END IF;
  END IF;

  -- COUNT must be positive
  IF result."count" IS NOT NULL THEN
    IF (NOT result."count" > 0) THEN
      RAISE EXCEPTION 'COUNT must be a positive integer.';
    END IF;
  END IF;

  -- BY* arrays should not be empty
  IF result."bymonth" IS NOT NULL AND array_length(result."bymonth", 1) = 0 THEN
    RAISE EXCEPTION 'BYMONTH cannot be an empty array.';
  END IF;

  IF result."byweekno" IS NOT NULL AND array_length(result."byweekno", 1) = 0 THEN
    RAISE EXCEPTION 'BYWEEKNO cannot be an empty array.';
  END IF;

  IF result."byyearday" IS NOT NULL AND array_length(result."byyearday", 1) = 0 THEN
    RAISE EXCEPTION 'BYYEARDAY cannot be an empty array.';
  END IF;

  IF result."bymonthday" IS NOT NULL AND array_length(result."bymonthday", 1) = 0 THEN
    RAISE EXCEPTION 'BYMONTHDAY cannot be an empty array.';
  END IF;

  IF result."byday" IS NOT NULL AND array_length(result."byday", 1) = 0 THEN
    RAISE EXCEPTION 'BYDAY cannot be an empty array.';
  END IF;

  IF result."byhour" IS NOT NULL AND array_length(result."byhour", 1) = 0 THEN
    RAISE EXCEPTION 'BYHOUR cannot be an empty array.';
  END IF;

  IF result."byminute" IS NOT NULL AND array_length(result."byminute", 1) = 0 THEN
    RAISE EXCEPTION 'BYMINUTE cannot be an empty array.';
  END IF;

  IF result."bysecond" IS NOT NULL AND array_length(result."bysecond", 1) = 0 THEN
    RAISE EXCEPTION 'BYSECOND cannot be an empty array.';
  END IF;

  IF result."bysetpos" IS NOT NULL AND array_length(result."bysetpos", 1) = 0 THEN
    RAISE EXCEPTION 'BYSETPOS cannot be an empty array.';
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;-- Parses an RRULE string into an RRULE type. Validates according to RFC 5545.
--
-- Parameters:
--   text - RRULE string with format "RRULE:FREQ=DAILY;COUNT=10;..."
--          Example: "RRULE:FREQ=WEEKLY;BYDAY=MO,FR;COUNT=10"
--
-- Returns: RRULE type with parsed and validated fields
CREATE OR REPLACE FUNCTION _rrule.rrule (TEXT)
RETURNS _rrule.RRULE AS $$
DECLARE
  result _rrule.RRULE;
  v_until_text text;
BEGIN
  WITH "tokens" AS (
    WITH parsed_line as (SELECT _rrule.parse_line($1::text, 'RRULE') "r"),
    -- Split each key value pair into an array, e.g. {'FREQ', 'DAILY'}
    key_value_pairs as (SELECT regexp_split_to_array("r", '=') AS "y" FROM parsed_line)
    SELECT "y"[1] AS "key", "y"[2] AS "val" FROM key_value_pairs
  ),
  candidate AS (
    SELECT
      (SELECT "val"::_rrule.FREQ FROM "tokens" WHERE "key" = 'FREQ') AS "freq",
      (SELECT "val"::INTEGER FROM "tokens" WHERE "key" = 'INTERVAL') AS "interval",
      (SELECT "val"::INTEGER FROM "tokens" WHERE "key" = 'COUNT') AS "count",
      (SELECT "val" FROM "tokens" WHERE "key" = 'UNTIL') AS "until_val",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYSECOND') AS "bysecond",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYMINUTE') AS "byminute",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYHOUR') AS "byhour",
      (SELECT _rrule.day_array("val") FROM "tokens" WHERE "key" = 'BYDAY') AS "byday",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYMONTHDAY') AS "bymonthday",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYYEARDAY') AS "byyearday",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYWEEKNO') AS "byweekno",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYMONTH') AS "bymonth",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYSETPOS') AS "bysetpos",
      (SELECT "val"::_rrule.DAY FROM "tokens" WHERE "key" = 'WKST') AS "wkst"
  )
  SELECT
    "freq",
    -- Default value for INTERVAL
    COALESCE("interval", 1) AS "interval",
    "count",
    "until_val",
    "bysecond",
    "byminute",
    "byhour",
    "byday",
    "bymonthday",
    "byyearday",
    "byweekno",
    "bymonth",
    "bysetpos",
    -- DEFAULT value for wkst
    COALESCE("wkst", 'MO') AS "wkst"
  INTO result."freq", result."interval", result."count", v_until_text,
       result."bysecond", result."byminute", result."byhour", result."byday",
       result."bymonthday", result."byyearday", result."byweekno", result."bymonth",
       result."bysetpos", result."wkst"
  FROM candidate;

  -- Parse UNTIL with better error handling
  IF v_until_text IS NOT NULL THEN
    BEGIN
      result."until" := v_until_text::TIMESTAMP;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Invalid UNTIL timestamp format: "%". Expected format: YYYYMMDDTHHMMSS', v_until_text;
    END;
  END IF;

  PERFORM _rrule.validate_rrule(result);

  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;


CREATE OR REPLACE FUNCTION _rrule.text(_rrule.RRULE)
RETURNS TEXT AS $$
  SELECT regexp_replace(
    'RRULE:'
    || COALESCE('FREQ=' || $1."freq" || ';', '')
    || CASE WHEN $1."interval" = 1 THEN '' ELSE COALESCE('INTERVAL=' || $1."interval" || ';', '') END
    || COALESCE('COUNT=' || $1."count" || ';', '')
    || COALESCE('UNTIL=' || $1."until" || ';', '')
    || COALESCE('BYSECOND=' || _rrule.array_join($1."bysecond", ',') || ';', '')
    || COALESCE('BYMINUTE=' || _rrule.array_join($1."byminute", ',') || ';', '')
    || COALESCE('BYHOUR=' || _rrule.array_join($1."byhour", ',') || ';', '')
    || COALESCE('BYDAY=' || _rrule.array_join($1."byday", ',') || ';', '')
    || COALESCE('BYMONTHDAY=' || _rrule.array_join($1."bymonthday", ',') || ';', '')
    || COALESCE('BYYEARDAY=' || _rrule.array_join($1."byyearday", ',') || ';', '')
    || COALESCE('BYWEEKNO=' || _rrule.array_join($1."byweekno", ',') || ';', '')
    || COALESCE('BYMONTH=' || _rrule.array_join($1."bymonth", ',') || ';', '')
    || COALESCE('BYSETPOS=' || _rrule.array_join($1."bysetpos", ',') || ';', '')
    || CASE WHEN $1."wkst" = 'MO' THEN '' ELSE COALESCE('WKST=' || $1."wkst" || ';', '') END
  , ';$', '');
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
-- Parses a multiline RRULESET string into an RRULESET type.
-- Includes validation for better error messages on invalid timestamp formats.
--
-- Parameters:
--   text - Multiline string with DTSTART, RRULE, EXRULE, RDATE, EXDATE lines
--          Example: 'DTSTART:19970902T090000
--                    RRULE:FREQ=DAILY;COUNT=10'
--
-- Returns: RRULESET type with parsed DTSTART, RRULE, and optional DTEND, EXRULE, RDATE, EXDATE
CREATE OR REPLACE FUNCTION _rrule.rruleset (TEXT)
RETURNS _rrule.RRULESET AS $$
DECLARE
  result _rrule.RRULESET;
  dtstart_text text;
  dtend_text text;
  rdate_text text;
  exdate_text text;
BEGIN
  -- Extract line values
  dtstart_text := _rrule.parse_line($1, 'DTSTART');
  dtend_text := _rrule.parse_line($1, 'DTEND');
  rdate_text := _rrule.parse_line($1, 'RDATE');
  exdate_text := _rrule.parse_line($1, 'EXDATE');

  -- Parse DTSTART with error handling
  IF dtstart_text IS NOT NULL THEN
    BEGIN
      result."dtstart" := dtstart_text::TIMESTAMP;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Invalid DTSTART format: "%". Expected format: DTSTART:YYYYMMDDTHHMMSS', dtstart_text;
    END;
  END IF;

  -- Parse DTEND with error handling
  IF dtend_text IS NOT NULL THEN
    BEGIN
      result."dtend" := dtend_text::TIMESTAMP;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Invalid DTEND format: "%". Expected format: DTEND:YYYYMMDDTHHMMSS', dtend_text;
    END;
  END IF;

  -- Parse RRULE and EXRULE
  result."rrule" := _rrule.rrule($1);

  IF _rrule.parse_line($1, 'EXRULE') IS NOT NULL THEN
    result."exrule" := _rrule.rrule(_rrule.parse_line($1, 'EXRULE'));
  END IF;

  -- Parse RDATE array with error handling
  IF rdate_text IS NOT NULL THEN
    BEGIN
      result."rdate" := (regexp_split_to_array(rdate_text, ','))::TIMESTAMP[];
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Invalid RDATE format: "%". Expected comma-separated timestamps.', rdate_text;
    END;
  END IF;

  -- Parse EXDATE array with error handling
  IF exdate_text IS NOT NULL THEN
    BEGIN
      result."exdate" := (regexp_split_to_array(exdate_text, ','))::TIMESTAMP[];
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Invalid EXDATE format: "%". Expected comma-separated timestamps.', exdate_text;
    END;
  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
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
--   rruleset - The ruleset containing RRULE and optional EXRULE
--
-- Returns: True if the RRULE has COUNT or UNTIL set
CREATE OR REPLACE FUNCTION _rrule.is_finite("rruleset" _rrule.RRULESET)
RETURNS BOOLEAN AS $$
  SELECT _rrule.is_finite("rruleset"."rrule")
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
--   rruleset - The ruleset containing RRULE, DTSTART, DTEND, RDATE, EXDATE, EXRULE
--   tsrange  - Time range to filter occurrences (e.g., '[2026-01-01, 2026-02-01)')
--
-- Returns: Set of timestamps within the range, with RDATE included and EXDATE/EXRULE excluded
CREATE OR REPLACE FUNCTION _rrule.occurrences(
  "rruleset" _rrule.RRULESET,
  "tsrange" TSRANGE
)
RETURNS SETOF TIMESTAMP AS $$
  WITH "rrules" AS (
    SELECT
      "rruleset"."dtstart",
      "rruleset"."dtend",
      "rruleset"."rrule"
  ),
  "rdates" AS (
    SELECT _rrule.occurrences("rrule", "dtstart", "tsrange") AS "occurrence"
    FROM "rrules"
    UNION
    SELECT unnest("rruleset"."rdate") AS "occurrence"
  ),
  "exrules" AS (
    SELECT
      "rruleset"."dtstart",
      "rruleset"."dtend",
      "rruleset"."exrule"
  ),
  "exdates" AS (
    SELECT _rrule.occurrences("exrule", "dtstart", "tsrange") AS "occurrence"
    FROM "exrules"
    UNION
    SELECT unnest("rruleset"."exdate") AS "occurrence"
  )
  SELECT "occurrence" FROM "rdates"
  EXCEPT
  SELECT "occurrence" FROM "exdates"
  ORDER BY "occurrence";
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Generates all occurrences for a ruleset (unbounded time range).
--
-- Parameters:
--   rruleset - The ruleset containing RRULE, DTSTART, DTEND, RDATE, EXDATE, EXRULE
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
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;-- Returns the first occurrence of a recurrence rule.
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



-- Returns all occurrences that occur after a given timestamp.
--
-- Parameters:
--   rrule   - The recurrence rule defining the pattern
--   dtstart - The starting timestamp from which to generate occurrences
--   when    - The cutoff timestamp (occurrences must be after this)
--
-- Returns: Set of timestamps that occur after the "when" timestamp
CREATE OR REPLACE FUNCTION _rrule.after(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP,
  "when" TIMESTAMP
)
RETURNS SETOF TIMESTAMP AS $$
  SELECT *
  FROM _rrule.occurrences("rrule", "dtstart", tsrange("when", NULL));
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Returns all occurrences (parsed from text) that occur after a given timestamp.
--
-- Parameters:
--   rrule   - RRULE string (e.g., "RRULE:FREQ=DAILY;COUNT=10")
--   dtstart - The starting timestamp
--   when    - The cutoff timestamp
--
-- Returns: Set of timestamps that occur after the "when" timestamp
CREATE OR REPLACE FUNCTION _rrule.after(
  "rrule" TEXT,
  "dtstart" TIMESTAMP,
  "when" TIMESTAMP
)
RETURNS SETOF TIMESTAMP AS $$
  SELECT _rrule.after(_rrule.rrule("rrule"), "dtstart", "when");
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Returns all occurrences from a ruleset that occur after a given timestamp.
--
-- Parameters:
--   rruleset - The ruleset containing RRULE, DTSTART, RDATE, EXDATE
--   when     - The cutoff timestamp
--
-- Returns: Set of timestamps that occur after the "when" timestamp
CREATE OR REPLACE FUNCTION _rrule.after("rruleset" _rrule.RRULESET, "when" TIMESTAMP)
RETURNS SETOF TIMESTAMP AS $$
  SELECT *
  FROM _rrule.occurrences("rruleset", tsrange("when", NULL));
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

-- Returns all occurrences from multiple rulesets that occur after a given timestamp.
--
-- Parameters:
--   rruleset_array - Array of rulesets to combine
--   when           - The cutoff timestamp
--
-- Returns: Combined set of timestamps from all rulesets that occur after "when"
CREATE OR REPLACE FUNCTION _rrule.after("rruleset_array" _rrule.RRULESET[], "when" TIMESTAMP)
RETURNS SETOF TIMESTAMP AS $$
  SELECT *
  FROM _rrule.occurrences("rruleset_array", tsrange("when", NULL));
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;

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
-- Converts a JSONB object to an RRULE type. Validates according to RFC 5545.
--
-- Parameters:
--   input - JSONB object with RRULE fields (freq, interval, count, until, by* arrays, wkst)
--           Example: '{"freq": "DAILY", "count": 10, "interval": 1}'
--
-- Returns: RRULE type with defaults applied (interval=1, wkst='MO')
CREATE OR REPLACE FUNCTION _rrule.jsonb_to_rrule("input" jsonb)
RETURNS _rrule.RRULE AS $$
DECLARE
  result _rrule.RRULE;
BEGIN
  IF (SELECT count(*) = 0 FROM jsonb_object_keys("input") WHERE "input"::TEXT <> 'null') THEN
    RETURN NULL;
  END IF;

  SELECT
    "freq",
    -- Default value for INTERVAL
    COALESCE("interval", 1) AS "interval",
    "count",
    "until",
    "bysecond",
    "byminute",
    "byhour",
    "byday",
    "bymonthday",
    "byyearday",
    "byweekno",
    "bymonth",
    "bysetpos",
    -- DEFAULT value for wkst
    COALESCE("wkst", 'MO') AS "wkst"
  INTO result
  FROM jsonb_to_record("input") as x(
    "freq" _rrule.FREQ,
    "interval" integer,
    "count" INTEGER,
    "until" text,
    "bysecond" integer[],
    "byminute" integer[],
    "byhour" integer[],
    "byday" text[],
    "bymonthday" integer[],
    "byyearday" integer[],
    "byweekno" integer[],
    "bymonth" integer[],
    "bysetpos" integer[],
    "wkst" _rrule.DAY
  );

  PERFORM _rrule.validate_rrule(result);

  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
-- Converts a JSONB object to an RRULESET type. Validates DTSTART and DTEND.
--
-- Parameters:
--   input - JSONB object with rruleset fields (dtstart, dtend, rrule, exrule, rdate, exdate)
--           Example: '{"dtstart": "2026-01-01T09:00:00", "rrule": {"freq": "DAILY", "count": 10}}'
--
-- Returns: RRULESET type with validated timestamps and rules
CREATE OR REPLACE FUNCTION _rrule.jsonb_to_rruleset("input" jsonb)
RETURNS _rrule.RRULESET AS $$
DECLARE
  result _rrule.RRULESET;
  dtstart_text text;
  dtend_text text;
  rdate_text text[];
  exdate_text text[];
BEGIN
  -- Extract text values first for better error messages
  SELECT
    "dtstart",
    "dtend",
    _rrule.jsonb_to_rrule("rrule") "rrule",
    _rrule.jsonb_to_rrule("exrule") "exrule",
    "rdate",
    "exdate"
  INTO dtstart_text, dtend_text, result."rrule", result."exrule", rdate_text, exdate_text
  FROM jsonb_to_record("input") as x(
    "dtstart" text,
    "dtend" text,
    "rrule" jsonb,
    "exrule" jsonb,
    "rdate" text[],
    "exdate" text[]
  );

  -- Validate DTSTART presence
  IF dtstart_text IS NULL THEN
    RAISE EXCEPTION 'DTSTART cannot be null.';
  END IF;

  -- Parse timestamps with better error messages
  BEGIN
    result."dtstart" := dtstart_text::TIMESTAMP;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Invalid DTSTART timestamp format: "%". Expected ISO 8601 format (e.g., "2026-01-01T09:00:00").', dtstart_text;
  END;

  IF dtend_text IS NOT NULL THEN
    BEGIN
      result."dtend" := dtend_text::TIMESTAMP;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Invalid DTEND timestamp format: "%". Expected ISO 8601 format (e.g., "2026-12-31T17:00:00").', dtend_text;
    END;

    IF result."dtend" < result."dtstart" THEN
      RAISE EXCEPTION 'DTEND must be greater than or equal to DTSTART.';
    END IF;
  END IF;

  -- Parse RDATE array with better error messages
  IF rdate_text IS NOT NULL THEN
    BEGIN
      result."rdate" := rdate_text::TIMESTAMP[];
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Invalid RDATE timestamp format. Expected array of ISO 8601 timestamps.';
    END;
  END IF;

  -- Parse EXDATE array with better error messages
  IF exdate_text IS NOT NULL THEN
    BEGIN
      result."exdate" := exdate_text::TIMESTAMP[];
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Invalid EXDATE timestamp format. Expected array of ISO 8601 timestamps.';
    END;
  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _rrule.jsonb_to_rruleset_array("input" jsonb)
RETURNS _rrule.RRULESET[] AS $$
  SELECT COALESCE(array_agg(_rrule.jsonb_to_rruleset(item)), '{}'::_rrule.RRULESET[])
  FROM jsonb_array_elements("input") AS item;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _rrule.rrule_to_jsonb("input" _rrule.RRULE)
RETURNS jsonb AS $$
BEGIN
  RETURN jsonb_strip_nulls(jsonb_build_object(
    'freq', "input"."freq",
    'interval', "input"."interval",
    'count', "input"."count",
    'until', "input"."until",
    'bysecond', "input"."bysecond",
    'byminute', "input"."byminute",
    'byhour', "input"."byhour",
    'byday', "input"."byday",
    'bymonthday', "input"."bymonthday",
    'byyearday', "input"."byyearday",
    'byweekno', "input"."byweekno",
    'bymonth', "input"."bymonth",
    'bysetpos', "input"."bysetpos",
    'wkst', "input"."wkst"
  ));
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _rrule.rruleset_to_jsonb("input" _rrule.RRULESET)
RETURNS jsonb AS $$
DECLARE
  rrule jsonb;
  exrule jsonb;
BEGIN
  SELECT _rrule.rrule_to_jsonb("input"."rrule")
  INTO rrule;

  SELECT _rrule.rrule_to_jsonb("input"."exrule")
  INTO exrule;

  RETURN jsonb_strip_nulls(jsonb_build_object(
    'dtstart', "input"."dtstart",
    'dtend', "input"."dtend",
    'rrule', rrule,
    'exrule', exrule,
    'rdate', "input"."rdate",
    'exdate', "input"."exdate"
  ));
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _rrule.rruleset_array_to_jsonb("input" _rrule.RRULESET[])
RETURNS jsonb AS $$
  SELECT COALESCE(jsonb_agg(_rrule.rruleset_to_jsonb(item)), '[]'::jsonb)
  FROM unnest("input") AS item;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _rrule.rruleset_array_contains_timestamp(_rrule.RRULESET[], TIMESTAMP)
RETURNS BOOLEAN AS $$
  SELECT COALESCE(bool_or(_rrule.contains_timestamp(item, $2)), false)
  FROM unnest($1) AS item;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _rrule.rruleset_has_after_timestamp(_rrule.RRULESET, TIMESTAMP)
RETURNS BOOLEAN AS $$
  SELECT count(*) > 0 FROM _rrule.after($1, $2) LIMIT 1;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _rrule.rruleset_has_before_timestamp(_rrule.RRULESET, TIMESTAMP)
RETURNS BOOLEAN AS $$
  SELECT count(*) > 0 FROM _rrule.before($1, $2) LIMIT 1;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _rrule.rruleset_array_has_after_timestamp(_rrule.RRULESET[], TIMESTAMP)
RETURNS BOOLEAN AS $$
  SELECT EXISTS(
    SELECT 1
    FROM unnest($1) AS item
    WHERE EXISTS(SELECT 1 FROM _rrule.after(item, $2) LIMIT 1)
  );
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _rrule.rruleset_array_has_before_timestamp(_rrule.RRULESET[], TIMESTAMP)
RETURNS BOOLEAN AS $$
  SELECT EXISTS(
    SELECT 1
    FROM unnest($1) AS item
    WHERE EXISTS(SELECT 1 FROM _rrule.before(item, $2) LIMIT 1)
  );
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
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
IS 'Generates all occurrences for a recurrence rule starting from the given timestamp.

Example usage:
  -- Generate first 5 daily occurrences starting Sep 2, 1997
  SELECT occurrence FROM _rrule.occurrences(
    _rrule.rrule(''RRULE:FREQ=DAILY;COUNT=5''),
    ''1997-09-02T09:00:00''::timestamp
  );

  -- Generate weekly Monday meetings for 10 weeks
  SELECT occurrence FROM _rrule.occurrences(
    _rrule.rrule(''RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=10''),
    ''2026-01-05T10:00:00''::timestamp
  );
';

COMMENT ON FUNCTION _rrule.occurrences(_rrule.RRULE, TIMESTAMP, TSRANGE)
IS 'Generates occurrences for a recurrence rule within a specific time range.

Example usage:
  -- Get all daily occurrences in September 1997
  SELECT occurrence FROM _rrule.occurrences(
    _rrule.rrule(''RRULE:FREQ=DAILY''),
    ''1997-09-02T09:00:00''::timestamp,
    ''[1997-09-01, 1997-10-01)''::tsrange
  );
';

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
IS 'Returns true if the given timestamp occurs within the ruleset. Matches by date, ignoring time.

Example usage:
  -- Check if a date is a scheduled occurrence
  SELECT _rrule.contains_timestamp(
    _rrule.jsonb_to_rruleset(''{"dtstart": "2026-01-01T09:00:00", "rrule": {"freq": "WEEKLY", "byday": ["MO", "WE", "FR"]}}''::jsonb),
    ''2026-01-03T14:30:00''::timestamp  -- Returns true (Friday)
  );
';

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
IS 'Parses an RRULE string (e.g., "RRULE:FREQ=DAILY;COUNT=10") into an RRULE type. Validates according to RFC 5545.

Example usage:
  SELECT _rrule.rrule(''RRULE:FREQ=DAILY;COUNT=10'');
  SELECT _rrule.rrule(''RRULE:FREQ=WEEKLY;BYDAY=MO,FR;UNTIL=20251231T235959'');
  SELECT _rrule.rrule(''RRULE:FREQ=MONTHLY;BYMONTHDAY=1,15;COUNT=24'');
';

COMMENT ON FUNCTION _rrule.rruleset(TEXT)
IS 'Parses a multiline RRULESET string (with DTSTART, RRULE, EXDATE, RDATE) into an RRULESET type.

Example usage:
  SELECT _rrule.rruleset(''DTSTART:19970902T090000
RRULE:FREQ=DAILY;COUNT=10'');
';

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
CREATE OPERATOR = (
  LEFTARG = _rrule.RRULE,
  RIGHTARG = _rrule.RRULE,
  PROCEDURE = _rrule.compare_equal,
  NEGATOR = <>,
  COMMUTATOR = =
);

CREATE OPERATOR <> (
  LEFTARG = _rrule.RRULE,
  RIGHTARG = _rrule.RRULE,
  PROCEDURE = _rrule.compare_not_equal,
  NEGATOR = =,
  COMMUTATOR = <>
);

CREATE OPERATOR @> (
  LEFTARG = _rrule.RRULE,
  RIGHTARG = _rrule.RRULE,
  PROCEDURE = _rrule.contains,
  COMMUTATOR = <@
);

CREATE OPERATOR <@ (
  LEFTARG = _rrule.RRULE,
  RIGHTARG = _rrule.RRULE,
  PROCEDURE = _rrule.contained_by,
  COMMUTATOR = @>
);

CREATE OPERATOR @> (
  LEFTARG = _rrule.RRULESET,
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.contains_timestamp
);

CREATE OPERATOR @> (
  LEFTARG = _rrule.RRULESET[],
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_array_contains_timestamp
);


CREATE OPERATOR > (
  LEFTARG = _rrule.RRULESET[],
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_array_has_after_timestamp
);

CREATE OPERATOR < (
  LEFTARG = _rrule.RRULESET[],
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_array_has_before_timestamp
);

CREATE OPERATOR > (
  LEFTARG = _rrule.RRULESET,
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_has_after_timestamp
);

CREATE OPERATOR < (
  LEFTARG = _rrule.RRULESET,
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_has_before_timestamp
);

CREATE CAST (TEXT AS _rrule.RRULE)
  WITH FUNCTION _rrule.rrule(TEXT)
  AS IMPLICIT;


CREATE CAST (TEXT AS _rrule.RRULESET)
  WITH FUNCTION _rrule.rruleset(TEXT)
  AS IMPLICIT;


CREATE CAST (jsonb AS _rrule.RRULE)
  WITH FUNCTION _rrule.jsonb_to_rrule(jsonb)
  AS IMPLICIT;
  
CREATE CAST (jsonb AS _rrule.RRULESET)
  WITH FUNCTION _rrule.jsonb_to_rruleset(jsonb)
  AS IMPLICIT;

CREATE CAST (_rrule.RRULE AS jsonb)
  WITH FUNCTION _rrule.rrule_to_jsonb(_rrule.RRULE)
  AS IMPLICIT;

