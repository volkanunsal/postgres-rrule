-- Converts a JSONB object to an RRULESET type. Validates DTSTART and DTEND.
--
-- Parameters:
--   input - JSONB object with rruleset fields (dtstart, dtend, rrule, exrule, rdate, exdate)
--           Example single rule: '{"dtstart": "2026-01-01T09:00:00", "rrule": {"freq": "DAILY", "count": 10}}'
--           Example multi-rule: '{"dtstart": "2026-01-01T09:00:00", "rrule": [{"freq": "WEEKLY", "byday": ["MO"]}, {"freq": "DAILY", "interval": 3}]}'
--
-- Returns: RRULESET type with validated timestamps and rules
-- Note: Supports both single rule (object) and multiple rules (array) for backwards compatibility
CREATE OR REPLACE FUNCTION _rrule.jsonb_to_rruleset("input" jsonb)
RETURNS _rrule.RRULESET AS $$
DECLARE
  result _rrule.RRULESET;
  dtstart_text text;
  dtend_text text;
  rdate_text text[];
  exdate_text text[];
  rrule_json jsonb;
  exrule_json jsonb;
BEGIN
  -- Extract text values first for better error messages
  SELECT
    "dtstart",
    "dtend",
    "rrule",
    "exrule",
    "rdate",
    "exdate"
  INTO dtstart_text, dtend_text, rrule_json, exrule_json, rdate_text, exdate_text
  FROM jsonb_to_record("input") as x(
    "dtstart" text,
    "dtend" text,
    "rrule" jsonb,
    "exrule" jsonb,
    "rdate" text[],
    "exdate" text[]
  );

  -- Parse RRULE (support both single object and array for backwards compatibility)
  IF rrule_json IS NOT NULL THEN
    IF jsonb_typeof(rrule_json) = 'array' THEN
      -- Handle array of rules
      result."rrule" := ARRAY(
        SELECT _rrule.jsonb_to_rrule(rrule_elem)
        FROM jsonb_array_elements(rrule_json) AS rrule_elem
      );
    ELSE
      -- Handle single rule (backwards compatibility)
      result."rrule" := ARRAY[_rrule.jsonb_to_rrule(rrule_json)];
    END IF;
  END IF;

  -- Parse EXRULE (support both single object and array)
  IF exrule_json IS NOT NULL THEN
    IF jsonb_typeof(exrule_json) = 'array' THEN
      -- Handle array of rules
      result."exrule" := ARRAY(
        SELECT _rrule.jsonb_to_rrule(exrule_elem)
        FROM jsonb_array_elements(exrule_json) AS exrule_elem
      );
    ELSE
      -- Handle single rule (backwards compatibility)
      result."exrule" := ARRAY[_rrule.jsonb_to_rrule(exrule_json)];
    END IF;
  END IF;

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
