-- Converts an RRULE's UNTIL field to a timezone-aware timestamp.
-- Per RFC 5545 recommendation, UNTIL is always stored and interpreted as UTC.
--
-- Parameters:
--   rrule - The RRULE containing until field
--   tzid - Timezone identifier (unused, kept for API compatibility)
--
-- Returns: TIMESTAMPTZ in UTC, or NULL if UNTIL is not set
--
-- Note: UNTIL is always interpreted as UTC per RFC 5545 recommendation.
-- The tzid parameter is kept for backward compatibility but not used.
CREATE OR REPLACE FUNCTION _rrule.until_with_timezone(
    rrule _rrule.RRULE,
    tzid TEXT
)
RETURNS TIMESTAMPTZ AS $$
BEGIN
  -- No UNTIL specified
  IF rrule."until" IS NULL THEN
    RETURN NULL;
  END IF;

  -- UNTIL is always stored as UTC (RFC 5545 recommendation)
  RETURN (rrule."until" AT TIME ZONE 'UTC');
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;
