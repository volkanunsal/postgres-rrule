BEGIN;

SELECT plan(8);

SET search_path TO public, _rrule;

-- 'Only one start with no modifiers.'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=YEARLY'::TEXT::RRULE,
    '19970105T083000'::TIMESTAMP
  )$$,
  'VALUES (''1997-01-05T08:30:00''::TIMESTAMP)',
  'Only one start with no modifiers.'
);

-- 'BYMONTHDAY expands number of starts.'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=YEARLY;COUNT=3;BYMONTHDAY=1,3'::TEXT,
    '1997-09-01T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('1997-09-01T09:00:00'::TIMESTAMP),
    ('1997-09-03T09:00:00'::TIMESTAMP)
  $$,
  'BYMONTHDAY expands number of starts.'
);

-- 'Monthly BYMONTH with one value -> one start.'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=MONTHLY;BYMONTH=2'::TEXT::RRULE,
    '1997-01-01T00:00:00'::TIMESTAMP
  )$$,
  $$ VALUES ('1997-02-01T00:00:00'::TIMESTAMP)$$,
  'Monthly BYMONTH with one value -> one start.'
);

-- 'WEEKLY COUNT=1.'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=WEEKLY;COUNT=1'::TEXT::RRULE,
    '1997-01-01T00:00:00'::TIMESTAMP
  )$$,
  $$ VALUES ('1997-01-01T00:00:00'::TIMESTAMP)$$,
  'WEEKLY COUNT=1.'
);

-- 'DAILY COUNT=1.'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=DAILY;COUNT=1'::TEXT::RRULE,
    '1997-01-01T00:00:00'::TIMESTAMP
  )$$,
  $$ VALUES ('1997-01-01T00:00:00'::TIMESTAMP)$$,
  'DAILY COUNT=1.'
);

-- 'HOURLY COUNT=1.'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=HOURLY;COUNT=1'::TEXT::RRULE,
    '1997-01-01T00:00:00'::TIMESTAMP
  )$$,
  $$ VALUES ('1997-01-01T00:00:00'::TIMESTAMP)$$,
  'HOURLY COUNT=1.'
);

-- 'MINUTELY COUNT=1.'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=MINUTELY;COUNT=1'::TEXT::RRULE,
    '1997-01-01T00:00:00'::TIMESTAMP
  )$$,
  $$ VALUES ('1997-01-01T00:00:00'::TIMESTAMP)$$,
  'MINUTELY COUNT=1.'
);

-- 'SECONDLY COUNT=1.'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=SECONDLY;COUNT=1'::TEXT::RRULE,
    '1997-01-01T00:00:00'::TIMESTAMP
  )$$,
  $$ VALUES ('1997-01-01T00:00:00'::TIMESTAMP)$$,
  'SECONDLY COUNT=1.'
);

SELECT * FROM finish();


ROLLBACK;