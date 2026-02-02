-- Parses an RRULE string into an RRULE type. Validates according to RFC 5545.
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

