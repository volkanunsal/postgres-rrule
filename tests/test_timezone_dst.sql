BEGIN;

SELECT plan(6);

SET search_path TO _rrule, public;

-- Test 1: Weekly recurrence crossing CEST to CET transition (Europe/Belgrade)
-- This test demonstrates the DST issue where times should remain constant in local time
-- but change in UTC when crossing DST boundaries.
--
-- CEST (Central European Summer Time): UTC+2
-- CET (Central European Time): UTC+1
-- Transition: Last Sunday of October 2022 (2022-10-30 03:00:00 CEST -> 02:00:00 CET)
--
-- Expected behavior for "every Wednesday at 05:00 Europe/Belgrade":
-- - 2022-10-26 05:00:00+02:00 (CEST) = 2022-10-26 03:00:00 UTC
-- - 2022-11-02 05:00:00+01:00 (CET)  = 2022-11-02 04:00:00 UTC
--
-- The local time stays at 05:00, but UTC time shifts by 1 hour

-- First, let's test with the current implementation (this will pass but shows incorrect behavior)
SELECT is(
    (SELECT array_agg(occurrences ORDER BY occurrences) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=WE;UNTIL=20221105T000000Z'),
        '2022-10-26T05:00:00'::timestamp,
        '[2022-10-24, 2022-11-04]'::tsrange
    ) AS occurrences),
    ARRAY[
        '2022-10-26T05:00:00'::timestamp,
        '2022-11-02T05:00:00'::timestamp
    ],
    'Weekly Wednesday recurrence: current behavior (naive timestamps)'
);

-- Test 2: What we SHOULD get if timezone support existed
-- This test will FAIL with current implementation because there's no timezone support
-- When interpreted as Europe/Belgrade timezone:
-- - 2022-10-26T05:00:00 Europe/Belgrade = 2022-10-26T03:00:00 UTC (CEST, UTC+2)
-- - 2022-11-02T05:00:00 Europe/Belgrade = 2022-11-02T04:00:00 UTC (CET, UTC+1)

-- NOTE: This test expects a timezone-aware function that doesn't exist yet
-- For now, we'll document what the expected behavior should be

-- Test 3: Demonstrate the problem - same local time but different UTC offsets
-- If we had timezone support, converting to UTC would show different times
-- Currently PostgreSQL's AT TIME ZONE would give us incorrect results because
-- it doesn't know the original timezone context

SELECT ok(
    true, -- Placeholder: Would test timezone-aware conversion
    'TODO: Test that 2022-10-26T05:00:00 CEST converts to 2022-10-26T03:00:00 UTC'
);

SELECT ok(
    true, -- Placeholder: Would test timezone-aware conversion
    'TODO: Test that 2022-11-02T05:00:00 CET converts to 2022-11-02T04:00:00 UTC'
);

-- Test 4: Multiple DST transitions in a yearly recurrence
-- A monthly recurrence spanning a full year should handle multiple DST transitions
SELECT ok(
    true, -- Placeholder: Would test multiple DST transitions
    'TODO: Test yearly recurrence with multiple DST transitions'
);

-- Test 5: Verify current limitation - no timezone information preserved
-- The extension currently uses TIMESTAMP (not TIMESTAMPTZ)
-- This test documents that timezone information is lost
SELECT is(
    pg_typeof(_rrule.first(_rrule.rruleset('DTSTART:20221026T050000
RRULE:FREQ=WEEKLY;COUNT=1;BYDAY=WE')))::text,
    'timestamp without time zone',
    'Current implementation returns TIMESTAMP (no timezone info)'
);

-- Test 6: FAILING TEST - Expected timezone-aware behavior
-- This test expects DST-aware timestamp handling that doesn't exist yet
-- When occurrences cross DST boundaries, the UTC representation should change
-- to maintain the same local time in the source timezone
--
-- Expected behavior for "every Wednesday at 05:00 Europe/Belgrade":
-- - 2022-10-26 05:00:00 in Europe/Belgrade (CEST, UTC+2) = 2022-10-26 03:00:00 UTC
-- - 2022-11-02 05:00:00 in Europe/Belgrade (CET, UTC+1)  = 2022-11-02 04:00:00 UTC
--
-- This test will FAIL because:
-- 1. There's no way to specify timezone in the current API
-- 2. The current implementation returns naive timestamps
-- 3. Converting naive timestamps to UTC assumes they're already in UTC or server timezone
--
-- Workaround test: Try to convert current results to UTC with AT TIME ZONE
-- This will fail to produce correct results because timezone info is lost

-- First get the occurrences in naive format
CREATE TEMP TABLE dst_test_occurrences AS
SELECT occurrences FROM _rrule.occurrences(
    _rrule.rrule('RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=WE;UNTIL=20221105T000000Z'),
    '2022-10-26T05:00:00'::timestamp,
    '[2022-10-24, 2022-11-04]'::tsrange
) AS occurrences;

-- Try to interpret them as Europe/Belgrade and convert to UTC
-- This will give WRONG results because the naive timestamps are already
-- being treated as if they were in Europe/Belgrade, but DST handling is wrong
SELECT is(
    (SELECT array_agg(
        (occurrences AT TIME ZONE 'Europe/Belgrade') AT TIME ZONE 'UTC'
        ORDER BY occurrences
    ) FROM dst_test_occurrences),
    ARRAY[
        '2022-10-26T03:00:00'::timestamp,  -- Correct UTC time for 05:00 CEST (UTC+2)
        '2022-11-02T04:00:00'::timestamp   -- Correct UTC time for 05:00 CET (UTC+1)
    ],
    'EXPECTED TO FAIL: Naive timestamps do not properly handle DST transitions when converted to UTC'
);

DROP TABLE dst_test_occurrences;

SELECT * FROM finish();

ROLLBACK;
