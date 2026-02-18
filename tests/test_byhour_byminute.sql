-- Tests for BYHOUR and BYMINUTE support (GitHub Issue #8)
-- Verifies that BYHOUR/BYMINUTE values in RRULE and RRULESET produce
-- occurrences at the specified hours/minutes, not just the DTSTART time.

BEGIN;

SELECT plan(9);

SET search_path TO _rrule, public;

-- Test 1: RRULE with BYHOUR=[9,17], FREQ=DAILY, COUNT=4
-- Should produce 2 days x 2 hours = 4 occurrences at 09:00 and 17:00
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.rrule('RRULE:FREQ=DAILY;COUNT=4;BYHOUR=9,17'),
    '2024-01-01T00:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2024-01-01T09:00:00'::TIMESTAMP),
    ('2024-01-01T17:00:00'::TIMESTAMP),
    ('2024-01-02T09:00:00'::TIMESTAMP),
    ('2024-01-02T17:00:00'::TIMESTAMP)
  $$,
  'RRULE with BYHOUR=[9,17] FREQ=DAILY COUNT=4 produces occurrences at both hours'
);

-- Test 2: RRULE with BYMINUTE=[0,30], FREQ=DAILY, COUNT=4
-- Should produce occurrences at :00 and :30 of the dtstart hour
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.rrule('RRULE:FREQ=DAILY;COUNT=4;BYMINUTE=0,30'),
    '2024-01-01T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2024-01-01T09:00:00'::TIMESTAMP),
    ('2024-01-01T09:30:00'::TIMESTAMP),
    ('2024-01-02T09:00:00'::TIMESTAMP),
    ('2024-01-02T09:30:00'::TIMESTAMP)
  $$,
  'RRULE with BYMINUTE=[0,30] FREQ=DAILY COUNT=4 produces occurrences at both minutes'
);

-- Test 3: RRULE with BYHOUR=[9,17] and BYMINUTE=[0,30], COUNT=8
-- Cartesian product: 2 hours x 2 minutes x 1 day = 4 per day, COUNT=8 = 2 days
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.rrule('RRULE:FREQ=DAILY;COUNT=8;BYHOUR=9,17;BYMINUTE=0,30'),
    '2024-01-01T00:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2024-01-01T09:00:00'::TIMESTAMP),
    ('2024-01-01T09:30:00'::TIMESTAMP),
    ('2024-01-01T17:00:00'::TIMESTAMP),
    ('2024-01-01T17:30:00'::TIMESTAMP),
    ('2024-01-02T09:00:00'::TIMESTAMP),
    ('2024-01-02T09:30:00'::TIMESTAMP),
    ('2024-01-02T17:00:00'::TIMESTAMP),
    ('2024-01-02T17:30:00'::TIMESTAMP)
  $$,
  'RRULE with BYHOUR=[9,17] and BYMINUTE=[0,30] produces Cartesian product'
);

-- Test 4: RRULESET (text parsing path) with BYHOUR=[9,17]
-- Verifies that BYHOUR is preserved through text->RRULESET->occurrences path
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.rruleset(
      E'DTSTART:20240101T000000\nRRULE:FREQ=DAILY;COUNT=4;BYHOUR=9,17'
    )
  ) $$,
  $$ VALUES
    ('2024-01-01T09:00:00'::TIMESTAMP),
    ('2024-01-01T17:00:00'::TIMESTAMP),
    ('2024-01-02T09:00:00'::TIMESTAMP),
    ('2024-01-02T17:00:00'::TIMESTAMP)
  $$,
  'RRULESET (text path) with BYHOUR=[9,17] produces correct times'
);

-- Test 5: RRULESET (JSONB parsing path) with byhour: [9,17]
-- Verifies that BYHOUR is preserved through JSONB->RRULESET->occurrences path
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.jsonb_to_rruleset(
      '{"dtstart": "2024-01-01T00:00:00", "rrule": {"freq": "DAILY", "count": 4, "byhour": [9, 17]}}'::jsonb
    )
  ) $$,
  $$ VALUES
    ('2024-01-01T09:00:00'::TIMESTAMP),
    ('2024-01-01T17:00:00'::TIMESTAMP),
    ('2024-01-02T09:00:00'::TIMESTAMP),
    ('2024-01-02T17:00:00'::TIMESTAMP)
  $$,
  'RRULESET (JSONB path) with byhour=[9,17] produces correct times'
);

-- Test 6: BYHOUR with non-midnight DTSTART
-- BYHOUR should override the DTSTART hour, not be relative to it
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.rrule('RRULE:FREQ=DAILY;COUNT=4;BYHOUR=9,17'),
    '2024-01-01T12:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2024-01-01T17:00:00'::TIMESTAMP),
    ('2024-01-02T09:00:00'::TIMESTAMP),
    ('2024-01-02T17:00:00'::TIMESTAMP),
    ('2024-01-03T09:00:00'::TIMESTAMP)
  $$,
  'BYHOUR overrides DTSTART hour (dtstart at 12:00, BYHOUR=9,17)'
);

-- Test 7: BYMINUTE with non-zero minute DTSTART
-- BYMINUTE should override the DTSTART minute
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.rrule('RRULE:FREQ=DAILY;COUNT=4;BYMINUTE=15,45'),
    '2024-01-01T09:30:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2024-01-01T09:45:00'::TIMESTAMP),
    ('2024-01-02T09:15:00'::TIMESTAMP),
    ('2024-01-02T09:45:00'::TIMESTAMP),
    ('2024-01-03T09:15:00'::TIMESTAMP)
  $$,
  'BYMINUTE overrides DTSTART minute (dtstart at :30, BYMINUTE=15,45)'
);

-- Test 8: BYHOUR with WEEKLY frequency and BYDAY
-- Ensures BYHOUR works correctly when combined with BYDAY
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.rrule('RRULE:FREQ=WEEKLY;COUNT=4;BYDAY=MO,WE;BYHOUR=9,17'),
    '2024-01-01T00:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2024-01-01T09:00:00'::TIMESTAMP),
    ('2024-01-01T17:00:00'::TIMESTAMP),
    ('2024-01-03T09:00:00'::TIMESTAMP),
    ('2024-01-03T17:00:00'::TIMESTAMP)
  $$,
  'BYHOUR with WEEKLY BYDAY produces correct times on correct days'
);

-- Test 9: all_starts with BYHOUR verifies seed generation
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    _rrule.rrule('RRULE:FREQ=DAILY;COUNT=4;BYHOUR=9,17'),
    '2024-01-01T00:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2024-01-01T09:00:00'::TIMESTAMP),
    ('2024-01-01T17:00:00'::TIMESTAMP)
  $$,
  'all_starts with BYHOUR=[9,17] produces two seed timestamps'
);

SELECT * FROM finish();

ROLLBACK;
