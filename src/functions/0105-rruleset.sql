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
