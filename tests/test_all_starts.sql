BEGIN;

SELECT plan(10);

SET search_path TO public, _rrule;

-- 'Only one start with no modifiers.'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=YEARLY'::TEXT::RRULE,
    '19970105T083000'::TIMESTAMP
  )$$,
  $$ VALUES
    ('1997-01-05T08:30:00'::TIMESTAMP)
  $$,
  'Only one start with no modifiers.'
);

-- 'BYMONTHDAY expands number of starts.'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=YEARLY;BYMONTHDAY=1,3'::TEXT,
    '1997-09-01T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('1997-09-01T09:00:00'::TIMESTAMP),
    ('1997-09-03T09:00:00'::TIMESTAMP),
    ('1997-10-01T09:00:00'::TIMESTAMP),
    ('1997-10-03T09:00:00'::TIMESTAMP),
    ('1997-11-01T09:00:00'::TIMESTAMP)
  $$,
  'BYMONTHDAY expands number of starts.'
);

-- 'BYDAY works.'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=WEEKLY;BYDAY=WE;COUNT=2'::TEXT,
    '2019-05-08T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2019-05-08T09:00:00'::TIMESTAMP)
  $$,
  'BYDAY works.'
);

-- 'BYDAY works for Sunday.'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=WEEKLY;BYDAY=SU;COUNT=2'::TEXT,
    '1997-06-02T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('1997-06-08T09:00:00'::TIMESTAMP)
  $$,
  'BYDAY works for last day in week.'
);

-- 'BYDAY works for multiple days'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=WEEKLY;BYDAY=MO,WE,SU;COUNT=2'::TEXT,
    '1997-06-02T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('1997-06-02T09:00:00'::TIMESTAMP),
    ('1997-06-04T09:00:00'),
    ('1997-06-08T09:00:00')
  $$,
  'BYDAY works for multiple days.'
);

-- 'BYDAY works when start is on BYDAY'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=WEEKLY;BYDAY=TU;COUNT=2'::TEXT,
    '2023-07-04T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2023-07-04T09:00:00'::TIMESTAMP)
  $$,
  'BYDAY works when start is on that week day.'
);

-- 'BYDAY works when start is in previous year'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=WEEKLY;BYDAY=TH;COUNT=2'::TEXT,
    '2023-12-29T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('2024-01-04T09:00:00'::TIMESTAMP)
  $$,
  'BYDAY works when start is in previous year.'
);

-- 'Monthly BYMONTH with one value -> one start.'
SELECT results_eq(
  $$ SELECT _rrule.all_starts(
    'RRULE:FREQ=MONTHLY;BYMONTH=2'::TEXT::RRULE,
    '1997-01-01T00:00:00'::TIMESTAMP
  )$$,
  $$ VALUES
    ('1997-02-01T00:00:00'::TIMESTAMP)
  $$,
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

SELECT * FROM finish();


ROLLBACK;