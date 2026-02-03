-- Generates timezone-aware occurrence timestamps for an RRULE.
-- This function properly handles daylight saving time transitions and timezone-aware UNTIL comparisons.
--
-- Parameters:
--   rrule - The recurrence rule
--   dtstart - Starting timestamp (interpreted in tzid timezone)
--   tzid - Timezone identifier (e.g., 'Europe/Belgrade', 'America/New_York')
--
-- Returns: Set of TIMESTAMPTZ values (in UTC) representing occurrences
--
-- Example:
--   SELECT * FROM _rrule.occurrences_tz(
--     _rrule.rrule('RRULE:FREQ=WEEKLY;BYDAY=WE;COUNT=3'),
--     '2022-10-26T05:00:00'::timestamp,
--     'Europe/Belgrade'
--   );
CREATE OR REPLACE FUNCTION _rrule.occurrences_tz(
    rrule _rrule.RRULE,
    dtstart TIMESTAMP,
    tzid TEXT
)
RETURNS SETOF TIMESTAMPTZ AS $$
DECLARE
  rrule_no_until _rrule.RRULE;
  until_tz TIMESTAMPTZ;
  occurrence_tz TIMESTAMPTZ;
BEGIN
  -- If there's an UNTIL, we need to handle it in a timezone-aware manner
  IF rrule."until" IS NOT NULL THEN
    -- Get timezone-aware UNTIL (always UTC per RFC 5545)
    until_tz := _rrule.until_with_timezone(rrule, tzid);

    -- Create a copy of rrule without UNTIL to avoid double-filtering
    rrule_no_until := rrule;
    rrule_no_until."until" := NULL;

    -- Generate occurrences and filter with timezone-aware UNTIL
    FOR occurrence_tz IN
      SELECT (occurrence AT TIME ZONE tzid)
      FROM _rrule.occurrences(rrule_no_until, dtstart) AS occurrence
    LOOP
      -- Apply timezone-aware UNTIL filter
      IF occurrence_tz < until_tz THEN
        RETURN NEXT occurrence_tz;
      END IF;
    END LOOP;
  ELSE
    -- No UNTIL, just convert occurrences to TIMESTAMPTZ
    RETURN QUERY
    SELECT (occurrence AT TIME ZONE tzid)
    FROM _rrule.occurrences(rrule, dtstart) AS occurrence;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION _rrule.occurrences_tz(_rrule.RRULE, TIMESTAMP, TEXT) IS
'Generates timezone-aware occurrences. Returns TIMESTAMPTZ values in UTC that account for DST transitions and handle UNTIL in a timezone-aware manner.';


-- Overload: occurrences_tz with tsrange filter
CREATE OR REPLACE FUNCTION _rrule.occurrences_tz(
    rrule _rrule.RRULE,
    dtstart TIMESTAMP,
    tzid TEXT,
    tsrange TSRANGE
)
RETURNS SETOF TIMESTAMPTZ AS $$
DECLARE
  rrule_no_until _rrule.RRULE;
  until_tz TIMESTAMPTZ;
  occurrence_tz TIMESTAMPTZ;
BEGIN
  -- If there's an UNTIL, handle it in a timezone-aware manner
  IF rrule."until" IS NOT NULL THEN
    until_tz := _rrule.until_with_timezone(rrule, tzid);
    rrule_no_until := rrule;
    rrule_no_until."until" := NULL;

    FOR occurrence_tz IN
      SELECT (occurrence AT TIME ZONE tzid)
      FROM _rrule.occurrences(rrule_no_until, dtstart, tsrange) AS occurrence
    LOOP
      IF occurrence_tz < until_tz THEN
        RETURN NEXT occurrence_tz;
      END IF;
    END LOOP;
  ELSE
    RETURN QUERY
    SELECT (occurrence AT TIME ZONE tzid)
    FROM _rrule.occurrences(rrule, dtstart, tsrange) AS occurrence;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;


-- Overload: occurrences_tz with RRULESET
-- Uses the tzid stored in the RRULESET
CREATE OR REPLACE FUNCTION _rrule.occurrences_tz(
    rruleset _rrule.RRULESET
)
RETURNS SETOF TIMESTAMPTZ AS $$
BEGIN
  IF rruleset."tzid" IS NULL THEN
    RAISE EXCEPTION 'RRULESET must have tzid field set for timezone-aware occurrences. Use occurrences() for naive timestamps.';
  END IF;

  RETURN QUERY
  SELECT occurrence_tz
  FROM _rrule.occurrences_tz((rruleset."rrule")[1], rruleset."dtstart", rruleset."tzid") AS occurrence_tz;
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;


-- Overload: occurrences_tz with RRULESET and tsrange
CREATE OR REPLACE FUNCTION _rrule.occurrences_tz(
    rruleset _rrule.RRULESET,
    tsrange TSRANGE
)
RETURNS SETOF TIMESTAMPTZ AS $$
BEGIN
  IF rruleset."tzid" IS NULL THEN
    RAISE EXCEPTION 'RRULESET must have tzid field set for timezone-aware occurrences. Use occurrences() for naive timestamps.';
  END IF;

  RETURN QUERY
  SELECT occurrence_tz
  FROM _rrule.occurrences_tz((rruleset."rrule")[1], rruleset."dtstart", rruleset."tzid", tsrange) AS occurrence_tz;
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;
