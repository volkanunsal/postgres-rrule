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
