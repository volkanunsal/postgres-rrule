BEGIN;

SELECT plan(8);

SET search_path TO _rrule, public;

-- Test 1: RRULESET with space-indented lines (exact scenario from issue #25)
SELECT is(
    (rruleset('
    DTSTART:19970902T090000
    RRULE:FREQ=WEEKLY;UNTIL=19980902T090000
    '))."dtstart"::TEXT,
    '1997-09-02 09:00:00',
    'RRULESET with space-indented lines parses DTSTART correctly'
);

-- Test 2: Verify the RRULE is also parsed correctly from indented input
SELECT is(
    ((rruleset('
    DTSTART:19970902T090000
    RRULE:FREQ=WEEKLY;UNTIL=19980902T090000
    '))."rrule")[1]."freq"::TEXT,
    'WEEKLY',
    'RRULESET with space-indented lines parses RRULE FREQ correctly'
);

-- Test 3: RRULESET with tab-indented lines
SELECT is(
    (rruleset(E'\tDTSTART:19970902T090000\n\tRRULE:FREQ=DAILY;COUNT=10\n'))."dtstart"::TEXT,
    '1997-09-02 09:00:00',
    'RRULESET with tab-indented lines parses DTSTART correctly'
);

-- Test 4: Verify RRULE from tab-indented input
SELECT is(
    ((rruleset(E'\tDTSTART:19970902T090000\n\tRRULE:FREQ=DAILY;COUNT=10\n'))."rrule")[1]."freq"::TEXT,
    'DAILY',
    'RRULESET with tab-indented lines parses RRULE FREQ correctly'
);

-- Test 5: RRULESET with mixed whitespace (spaces and tabs)
SELECT is(
    (rruleset(E'  \tDTSTART:19970902T090000\n \t RRULE:FREQ=MONTHLY;COUNT=5\n'))."dtstart"::TEXT,
    '1997-09-02 09:00:00',
    'RRULESET with mixed spaces and tabs parses DTSTART correctly'
);

-- Test 6: Verify RRULE from mixed whitespace input
SELECT is(
    ((rruleset(E'  \tDTSTART:19970902T090000\n \t RRULE:FREQ=MONTHLY;COUNT=5\n'))."rrule")[1]."freq"::TEXT,
    'MONTHLY',
    'RRULESET with mixed spaces and tabs parses RRULE FREQ correctly'
);

-- Test 7: Regression test - RRULESET without any indentation still works
SELECT is(
    (rruleset('DTSTART:19970902T090000
RRULE:FREQ=WEEKLY;UNTIL=19980902T090000'))."dtstart"::TEXT,
    '1997-09-02 09:00:00',
    'RRULESET without indentation still parses DTSTART correctly (regression)'
);

-- Test 8: Regression test - RRULE without indentation still works
SELECT is(
    ((rruleset('DTSTART:19970902T090000
RRULE:FREQ=WEEKLY;UNTIL=19980902T090000'))."rrule")[1]."freq"::TEXT,
    'WEEKLY',
    'RRULESET without indentation still parses RRULE FREQ correctly (regression)'
);

SELECT * FROM finish();

ROLLBACK;
