-- Tests poached from dateutil
-- https://github.com/dateutil/dateutil/blob/master/dateutil/test/test_rrule.py

BEGIN;

SELECT plan(7);

SET search_path TO public, _rrule;

SELECT results_eq(
  $$ SELECT * FROM occurrences(
    'RRULE:FREQ=YEARLY;COUNT=3'::TEXT,
    '1997-09-02T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('1997-09-02T09:00:00'::TIMESTAMP),
    ('1998-09-02T09:00:00'),
    ('1999-09-02T09:00:00')
  $$,
  'testYearly'
);

SELECT results_eq(
  $$ SELECT * FROM occurrences(
    'RRULE:FREQ=YEARLY;COUNT=3;INTERVAL=2'::TEXT,
    '1997-09-02T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('1997-09-02T09:00:00'::TIMESTAMP),
    ('1999-09-02T09:00:00'),
    ('2001-09-02T09:00:00')
  $$,
  'testYearlyInterval'
);


SELECT results_eq(
  $$ SELECT * FROM occurrences(
    'RRULE:FREQ=YEARLY;COUNT=3;INTERVAL=100'::TEXT,
    '1997-09-02T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('1997-09-02T09:00:00'::TIMESTAMP),
    ('2097-09-02T09:00:00'),
    ('2197-09-02T09:00:00')
  $$,
  'testYearlyIntervalLarge'
);

SELECT results_eq(
  $$ SELECT * FROM occurrences(
    'RRULE:FREQ=YEARLY;COUNT=3;BYMONTH=1,3'::TEXT,
    '1997-09-02T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('1998-01-02T09:00:00'::TIMESTAMP),
    ('1998-03-02T09:00:00'),
    ('1999-01-02T09:00:00')
  $$,
  'testYearlyByMonth'
);


-- FIXME: need to modify all_starts to make it aware of COUNT.
SELECT results_eq(
  $$ SELECT * FROM occurrences(
    'RRULE:FREQ=YEARLY;COUNT=3;BYMONTHDAY=1,3'::TEXT,
    '1997-09-02T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('1997-09-03T09:00:00'::TIMESTAMP),
    ('1997-10-01T09:00:00'),
    ('1997-10-03T09:00:00')
  $$,
  'testYearlyByMonthDay'
);

SELECT results_eq(
  $$ SELECT * FROM occurrences(
    'RRULE:FREQ=YEARLY;COUNT=3;BYMONTH=1,3;BYMONTHDAY=5,7'::TEXT,
    '1997-09-02T09:00:00'::TIMESTAMP
  )$$,
  $$ VALUES
    ('1998-01-05T09:00:00'::TIMESTAMP),
    ('1998-01-07T09:00:00'),
    ('1998-03-05T09:00:00')
  $$,
  'testYearlyByMonthAndMonthDay'
);

-- FIXME: need to modify all_starts to make it aware of COUNT.
SELECT results_eq(
  $$ SELECT * FROM occurrences(
    'RRULE:FREQ=YEARLY;COUNT=3;BYWEEKDAY=TU,TH'::TEXT,
    '1997-03-02T09:00:00'::TIMESTAMP
  )$$,
  $$ VALUES
    ('1997-09-02T09:00:00'::TIMESTAMP),
    ('1997-09-04T09:00:00'),
    ('1997-09-09T09:00:00')
  $$,
  'testYearlyByWeekDay'
);

SELECT * FROM finish();

ROLLBACK;