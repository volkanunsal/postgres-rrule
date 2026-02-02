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
    _rrule.has_any_by_rule('(DAILY,1,,,,,,,,,,,,MO)'::RRULE),
    false,
    'RRULE with no BY* rules returns false'
);

SELECT is(
    _rrule.has_any_by_rule('(MONTHLY,1,,,,,,,"{1,15}",,,,,MO)'::RRULE),
    true,
    'RRULE with bymonthday returns true'
);

SELECT is(
    _rrule.has_any_by_rule('(WEEKLY,1,,,,,,"{MO,FR}",,,,,MO)'::RRULE),
    true,
    'RRULE with byday returns true'
);

SELECT is(
    _rrule.has_any_by_rule('(YEARLY,1,,,,,,,,,"{1,12}",,MO)'::RRULE),
    true,
    'RRULE with bymonth returns true'
);

-- Test valid COUNT values work
SELECT is(
    rrule('RRULE:FREQ=DAILY;COUNT=1'),
    '(DAILY,1,1,,,,,,,,,,,,MO)',
    'COUNT=1 is valid'
);

SELECT is(
    rrule('RRULE:FREQ=DAILY;COUNT=100'),
    '(DAILY,1,100,,,,,,,,,,,,MO)',
    'COUNT=100 is valid'
);

-- Test valid non-empty arrays work
SELECT is(
    rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=1'),
    '(MONTHLY,1,,,,,,,{1},,,,,MO)',
    'Single value BYMONTHDAY array is valid'
);

SELECT is(
    rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=1,15'),
    '(MONTHLY,1,,,,,,\"{1,15}\",,,,,MO)',
    'Multiple value BYMONTHDAY array is valid'
);

-- Test BYSETPOS validation with has_any_by_rule
PREPARE bysetpos_without_by AS SELECT rrule('RRULE:FREQ=MONTHLY;BYSETPOS=1');
SELECT throws_like(
    'bysetpos_without_by',
    'BYSETPOS requires at least one other BY* parameter.',
    'BYSETPOS without other BY* parameters should raise exception'
);

SELECT is(
    rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=1;BYSETPOS=1'),
    '(MONTHLY,1,,,,,,,{1},,,,{1},MO)',
    'BYSETPOS with BYMONTHDAY is valid'
);

SELECT * FROM finish();

ROLLBACK;
