BEGIN;

SELECT plan(4);

SET search_path TO _rrule, public;

-- Test 1: Document that 'Z' suffix in UNTIL is stripped and normalized
-- Per RFC 5545, UNTIL is always stored as UTC
SELECT is(
    (_rrule.rrule('RRULE:FREQ=DAILY;UNTIL=20221105T000000Z'))."until",
    '2022-11-05T00:00:00'::timestamp,
    'UNTIL with Z suffix: Z is stripped and timestamp is stored as UTC'
);

-- Test 2: Demonstrate that naive occurrences() still uses naive comparison
-- Event at 05:00 local (CEST = UTC+2, so 03:00 UTC)
-- UNTIL at 04:00 UTC
-- Naive comparison: 05:00 local > 04:00 local → EXCLUDED (wrong!)
-- Correct UTC comparison: 03:00 UTC < 04:00 UTC → INCLUDED
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=WEEKLY;BYDAY=WE;UNTIL=20221026T040000Z'),
        '2022-10-26T05:00:00'::timestamp,
        '[2022-10-24, 2022-10-27]'::tsrange
    )),
    0::bigint,
    'Old occurrences() with naive comparison: event at 05:00 local excluded when UNTIL is 04:00 (incorrect for UTC UNTIL)'
);

-- Test 3: Verify timezone-aware occurrences_tz() handles UNTIL correctly
-- Same scenario but with timezone-aware function
-- Event at 05:00 CEST (03:00 UTC) with UNTIL at 04:00 UTC
-- Correct: 03:00 UTC < 04:00 UTC → INCLUDED
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences_tz(
        _rrule.rrule('RRULE:FREQ=WEEKLY;BYDAY=WE;UNTIL=20221026T040000Z'),
        '2022-10-26T05:00:00'::timestamp,
        'Europe/Belgrade',
        '[2022-10-24, 2022-10-27]'::tsrange
    )),
    1::bigint,
    'New occurrences_tz() with UTC comparison: event at 05:00 CEST (03:00 UTC) included when UNTIL is 04:00 UTC (correct)'
);

-- Test 4: Verify UNTIL is always treated as UTC (RFC 5545 recommendation)
-- UNTIL: 2022-10-26T06:00:00 (treated as UTC = 06:00 UTC)
-- Event: 2022-10-26T05:00:00 CEST (UTC+2) = 2022-10-26T03:00:00 UTC
-- Comparison: 03:00 UTC < 06:00 UTC → INCLUDED
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences_tz(
        _rrule.rrule('RRULE:FREQ=WEEKLY;BYDAY=WE;UNTIL=20221026T060000'),
        '2022-10-26T05:00:00'::timestamp,
        'Europe/Belgrade',
        '[2022-10-24, 2022-10-27]'::tsrange
    )),
    1::bigint,
    'UNTIL is always interpreted as UTC per RFC 5545: event at 03:00 UTC < UNTIL at 06:00 UTC'
);

SELECT * FROM finish();

ROLLBACK;
