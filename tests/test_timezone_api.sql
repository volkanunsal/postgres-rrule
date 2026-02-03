BEGIN;

SELECT plan(2);

SET search_path TO _rrule, public;

-- Tests for timezone-aware recurrence rule API

-- Test 1: Parse RRULESET with TZID parameter (RFC 5545 format)
-- RFC 5545 allows: DTSTART;TZID=Europe/Belgrade:20221026T050000
-- Verify the parser extracts and stores the timezone
SELECT is(
    (_rrule.rruleset('DTSTART;TZID=Europe/Belgrade:20221026T050000
RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=WE;COUNT=2')).tzid,
    'Europe/Belgrade',
    'Parser extracts TZID parameter from DTSTART'
);

-- Test 2: Occurrences with timezone parameter returning TIMESTAMPTZ
-- Verify the function exists and is executable
SELECT function_privs_are(
    '_rrule',
    'occurrences_tz',
    ARRAY['_rrule.rrule', 'timestamp without time zone', 'text'],
    'postgres',
    ARRAY['EXECUTE'],
    'occurrences_tz(rrule, timestamp, tzid text) function exists'
);

SELECT * FROM finish();

ROLLBACK;
