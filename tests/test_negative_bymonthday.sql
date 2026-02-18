-- Tests for negative BYMONTHDAY values (RFC 5545)
-- Negative values count from the end of the month:
--   -1 = last day, -2 = second-to-last day, etc.

BEGIN;

SELECT plan(6);

SET search_path TO _rrule, public;

-- Test 1: MONTHLY;BYMONTHDAY=-1;COUNT=3 starting Jan 2024
-- Should produce last day of Jan (31), Feb (29, leap year), Mar (31)
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;COUNT=3'),
    '2024-01-01T00:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2024-01-31T00:00:00'::TIMESTAMP),
    ('2024-02-29T00:00:00'::TIMESTAMP),
    ('2024-03-31T00:00:00'::TIMESTAMP)
  $$,
  'BYMONTHDAY=-1 returns last day of each month (Jan, Feb leap, Mar)'
);

-- Test 2: MONTHLY;BYMONTHDAY=-1;COUNT=12 starting Jan 2024
-- Should produce last day of each month for a full year
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;COUNT=12'),
    '2024-01-01T00:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2024-01-31T00:00:00'::TIMESTAMP),
    ('2024-02-29T00:00:00'::TIMESTAMP),
    ('2024-03-31T00:00:00'::TIMESTAMP),
    ('2024-04-30T00:00:00'::TIMESTAMP),
    ('2024-05-31T00:00:00'::TIMESTAMP),
    ('2024-06-30T00:00:00'::TIMESTAMP),
    ('2024-07-31T00:00:00'::TIMESTAMP),
    ('2024-08-31T00:00:00'::TIMESTAMP),
    ('2024-09-30T00:00:00'::TIMESTAMP),
    ('2024-10-31T00:00:00'::TIMESTAMP),
    ('2024-11-30T00:00:00'::TIMESTAMP),
    ('2024-12-31T00:00:00'::TIMESTAMP)
  $$,
  'BYMONTHDAY=-1 returns last day of each month for 12 months'
);

-- Test 3: MONTHLY;BYMONTHDAY=-2;COUNT=3 starting Jan 2024
-- Should produce second-to-last day of Jan (30), Feb (28), Mar (30)
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=-2;COUNT=3'),
    '2024-01-01T00:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2024-01-30T00:00:00'::TIMESTAMP),
    ('2024-02-28T00:00:00'::TIMESTAMP),
    ('2024-03-30T00:00:00'::TIMESTAMP)
  $$,
  'BYMONTHDAY=-2 returns second-to-last day of each month'
);

-- Test 4: MONTHLY;BYMONTHDAY=15,-1;COUNT=4 starting Jan 2024
-- Should produce 15th AND last day of month (interleaved, sorted)
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=15,-1;COUNT=4'),
    '2024-01-01T00:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2024-01-15T00:00:00'::TIMESTAMP),
    ('2024-01-31T00:00:00'::TIMESTAMP),
    ('2024-02-15T00:00:00'::TIMESTAMP),
    ('2024-02-29T00:00:00'::TIMESTAMP)
  $$,
  'BYMONTHDAY=15,-1 returns 15th and last day of month combined'
);

-- Test 5: YEARLY;BYMONTHDAY=-1;BYMONTH=2;COUNT=4 starting 2023
-- Should produce last day of February for 4 years (including leap year)
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.rrule('RRULE:FREQ=YEARLY;BYMONTHDAY=-1;BYMONTH=2;COUNT=4'),
    '2023-01-01T00:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2023-02-28T00:00:00'::TIMESTAMP),
    ('2024-02-29T00:00:00'::TIMESTAMP),
    ('2025-02-28T00:00:00'::TIMESTAMP),
    ('2026-02-28T00:00:00'::TIMESTAMP)
  $$,
  'YEARLY BYMONTHDAY=-1 BYMONTH=2 handles leap years correctly'
);

-- Test 6: JSONB path with negative BYMONTHDAY
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.jsonb_to_rrule('{"freq": "MONTHLY", "bymonthday": [-1], "count": 3}'::jsonb),
    '2024-01-01T00:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2024-01-31T00:00:00'::TIMESTAMP),
    ('2024-02-29T00:00:00'::TIMESTAMP),
    ('2024-03-31T00:00:00'::TIMESTAMP)
  $$,
  'JSONB with negative BYMONTHDAY returns last day of each month'
);

SELECT * FROM finish();

ROLLBACK;
