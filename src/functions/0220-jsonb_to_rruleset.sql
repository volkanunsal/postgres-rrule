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
