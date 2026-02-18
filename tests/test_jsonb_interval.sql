-- Regression tests for GitHub Issue #29:
-- INTERVAL is ignored for WEEKLY frequency with BYDAY when parsed via JSONB path
--
-- The bug: When using JSONB input like {"freq": "WEEKLY", "interval": 2, "byday": ["TH"]},
-- the extension returned EVERY Thursday instead of every OTHER Thursday.
-- These tests ensure the JSONB path produces the same results as the TEXT path.

BEGIN;

SELECT plan(8);

SET search_path TO _rrule, public;

-- Test 1: JSONB RRULESET with INTERVAL=2, FREQ=WEEKLY, BYDAY=TH
-- This is the exact scenario from the GitHub issue report
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.jsonb_to_rruleset('{
      "dtstart": "2024-11-14T17:30:00",
      "dtend": "2024-11-14T19:00:00",
      "rrule": {
        "freq": "WEEKLY",
        "wkst": "MO",
        "byday": ["TH"],
        "until": "2025-01-23T08:07:28",
        "interval": 2
      },
      "exdate": ["2024-12-26T17:30:00"]
    }'::jsonb)
  ) $$,
  $$ VALUES
    ('2024-11-14T17:30:00'::TIMESTAMP),
    ('2024-11-28T17:30:00'),
    ('2024-12-12T17:30:00'),
    ('2025-01-09T17:30:00')
  $$,
  'Issue #29: JSONB biweekly Thursday with exdate produces correct biweekly results'
);

-- Test 2: JSONB RRULESET with INTERVAL=2, FREQ=WEEKLY, BYDAY=TH (no exdates)
-- Same as above but without exdate to verify interval alone works
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.jsonb_to_rruleset('{
      "dtstart": "2024-11-14T17:30:00",
      "dtend": "2024-11-14T19:00:00",
      "rrule": {
        "freq": "WEEKLY",
        "wkst": "MO",
        "byday": ["TH"],
        "until": "2025-01-23T08:07:28",
        "interval": 2
      }
    }'::jsonb)
  ) $$,
  $$ VALUES
    ('2024-11-14T17:30:00'::TIMESTAMP),
    ('2024-11-28T17:30:00'),
    ('2024-12-12T17:30:00'),
    ('2024-12-26T17:30:00'),
    ('2025-01-09T17:30:00')
  $$,
  'Issue #29: JSONB biweekly Thursday without exdate produces correct biweekly results'
);

-- Test 3: JSONB RRULESET with INTERVAL=2, FREQ=WEEKLY, BYDAY=TH,SA (multiple days)
-- Biweekly with two days per week should produce 2 occurrences per cycle
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.jsonb_to_rruleset('{
      "dtstart": "1997-09-02T09:00:00",
      "rrule": {
        "freq": "WEEKLY",
        "byday": ["TH", "SA"],
        "count": 4,
        "interval": 2
      }
    }'::jsonb)
  ) $$,
  $$ VALUES
    ('1997-09-04T09:00:00'::TIMESTAMP),
    ('1997-09-06T09:00:00'),
    ('1997-09-18T09:00:00'),
    ('1997-09-20T09:00:00')
  $$,
  'Issue #29: JSONB biweekly with multiple BYDAY values matches TEXT path behavior'
);

-- Test 4: JSONB RRULESET with null fields matching user input exactly
-- Ensures null JSON values do not interfere with interval parsing
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.jsonb_to_rruleset('{
      "dtstart": "2024-11-14T17:30:00",
      "dtend": "2024-11-14T19:00:00",
      "rrule": {
        "freq": "WEEKLY",
        "wkst": "MO",
        "byday": ["TH"],
        "count": null,
        "until": "2025-01-23T08:07:28",
        "interval": 2,
        "byhour": null,
        "bymonth": null,
        "byminute": null,
        "bysecond": null,
        "bysetpos": null,
        "byweekno": null,
        "byyearday": null,
        "bymonthday": null
      },
      "exdate": ["2024-12-26T17:30:00"]
    }'::jsonb)
  ) $$,
  $$ VALUES
    ('2024-11-14T17:30:00'::TIMESTAMP),
    ('2024-11-28T17:30:00'),
    ('2024-12-12T17:30:00'),
    ('2025-01-09T17:30:00')
  $$,
  'Issue #29: JSONB with explicit null fields does not ignore INTERVAL'
);

-- Test 5: JSONB path matches TEXT path for INTERVAL=2 WEEKLY BYDAY=TH
-- Direct comparison of JSONB vs TEXT parsing paths
SELECT results_eq(
  $$ SELECT * FROM _rrule.occurrences(
    _rrule.jsonb_to_rruleset('{
      "dtstart": "1997-09-02T09:00:00",
      "rrule": {
        "freq": "WEEKLY",
        "byday": ["TH"],
        "count": 3,
        "interval": 2
      }
    }'::jsonb)
  ) $$,
  $$ SELECT * FROM occurrences(
    'RRULE:FREQ=WEEKLY;COUNT=3;BYDAY=TH;INTERVAL=2'::TEXT,
    '1997-09-02T09:00:00'::TIMESTAMP
  ) $$,
  'Issue #29: JSONB and TEXT paths produce identical results for biweekly BYDAY'
);

-- Test 6: TEXT path regression - ensure existing INTERVAL=2 WEEKLY test still works
SELECT results_eq(
  $$ SELECT * FROM occurrences(
    'RRULE:FREQ=WEEKLY;COUNT=3;BYDAY=TH;INTERVAL=2'::TEXT,
    '1997-09-02T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('1997-09-04T09:00:00'::TIMESTAMP),
    ('1997-09-18T09:00:00'),
    ('1997-10-02T09:00:00')
  $$,
  'Regression: TEXT path biweekly Thursday still works correctly'
);

-- Test 7: JSONB RRULE INTERVAL=2 is correctly parsed (unit test)
SELECT is(
  (_rrule.jsonb_to_rrule('{
    "freq": "WEEKLY",
    "byday": ["TH"],
    "count": 3,
    "interval": 2
  }'::jsonb))."interval",
  2,
  'Issue #29: JSONB parsing preserves INTERVAL=2'
);

-- Test 8: JSONB RRULE INTERVAL=2 with null fields is correctly parsed
SELECT is(
  (_rrule.jsonb_to_rrule('{
    "freq": "WEEKLY",
    "byday": ["TH"],
    "count": null,
    "until": "2025-01-23T08:07:28",
    "interval": 2,
    "byhour": null,
    "bymonth": null,
    "byminute": null,
    "bysecond": null,
    "bysetpos": null,
    "byweekno": null,
    "byyearday": null,
    "bymonthday": null,
    "wkst": "MO"
  }'::jsonb))."interval",
  2,
  'Issue #29: JSONB parsing preserves INTERVAL=2 even with explicit null fields'
);

SELECT * FROM finish();

ROLLBACK;
