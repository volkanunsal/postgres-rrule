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
BEGIN
  SELECT
    "dtstart"::TIMESTAMP,
    "dtend"::TIMESTAMP,
    _rrule.jsonb_to_rrule("rrule") "rrule",
    _rrule.jsonb_to_rrule("exrule") "exrule",
    "rdate"::TIMESTAMP[],
    "exdate"::TIMESTAMP[]
  INTO result
  FROM jsonb_to_record("input") as x(
    "dtstart" text,
    "dtend" text,
    "rrule" jsonb,
    "exrule" jsonb,
    "rdate" text[],
    "exdate" text[]
  );

  -- Validate rruleset
  IF result."dtstart" IS NULL THEN
    RAISE EXCEPTION 'DTSTART cannot be null.';
  END IF;

  IF result."dtend" IS NOT NULL AND result."dtend" < result."dtstart" THEN
    RAISE EXCEPTION 'DTEND must be greater than or equal to DTSTART.';
  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
