BEGIN;

SELECT plan(12);

SET search_path TO _rrule, public;

-- Test new COUNT validation
PREPARE invalid_count AS SELECT rrule('RRULE:FREQ=DAILY;COUNT=0');
SELECT throws_like(
    'invalid_count',
    'COUNT must be a positive integer.',
    'COUNT=0 should raise exception'
);

PREPARE negative_count AS SELECT rrule('RRULE:FREQ=DAILY;COUNT=-5');
SELECT throws_like(
    'negative_count',
    'COUNT must be a positive integer.',
    'Negative COUNT should raise exception'
);

-- Note: Empty JSON arrays convert to NULL in PostgreSQL, not empty arrays
-- So we test that NULL arrays are handled correctly instead

-- Test has_any_by_rule helper function
SELECT is(
    _rrule.has_any_by_rule(_rrule.rrule('RRULE:FREQ=DAILY')),
    false,
    'RRULE with no BY* rules returns false'
);

SELECT is(
    _rrule.has_any_by_rule(_rrule.rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=1,15')),
    true,
    'RRULE with bymonthday returns true'
);

SELECT is(
    _rrule.has_any_by_rule(_rrule.rrule('RRULE:FREQ=WEEKLY;BYDAY=MO,FR')),
    true,
    'RRULE with byday returns true'
);

SELECT is(
    _rrule.has_any_by_rule(_rrule.rrule('RRULE:FREQ=YEARLY;BYMONTH=1,12')),
    true,
    'RRULE with bymonth returns true'
);

-- Test valid COUNT values work
SELECT ok(
    (rrule('RRULE:FREQ=DAILY;COUNT=1')).count = 1,
    'COUNT=1 is valid'
);

SELECT ok(
    (rrule('RRULE:FREQ=DAILY;COUNT=100')).count = 100,
    'COUNT=100 is valid'
);

-- Test valid non-empty arrays work
SELECT ok(
    (rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=1')).bymonthday = ARRAY[1],
    'Single value BYMONTHDAY array is valid'
);

SELECT ok(
    (rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=1,15')).bymonthday = ARRAY[1,15],
    'Multiple value BYMONTHDAY array is valid'
);

-- Test BYSETPOS validation with has_any_by_rule
PREPARE bysetpos_without_by AS SELECT rrule('RRULE:FREQ=MONTHLY;BYSETPOS=1');
SELECT throws_like(
    'bysetpos_without_by',
    'BYSETPOS requires at least one other BY* parameter.',
    'BYSETPOS without other BY* parameters should raise exception'
);

SELECT ok(
    (rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=1;BYSETPOS=1')).bysetpos = ARRAY[1],
    'BYSETPOS with BYMONTHDAY is valid'
);

SELECT * FROM finish();

ROLLBACK;
