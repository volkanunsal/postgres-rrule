-- Tests poached from dateutil
-- https://github.com/dateutil/dateutil/blob/master/dateutil/test/test_rrule.py

BEGIN;

SELECT plan(7);

SET search_path TO public, _rrule;

SELECT results_eq(
  $$ SELECT * FROM occurrences(
    'RRULE:FREQ=WEEKLY;COUNT=3'::TEXT,
    '1997-09-02T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('1997-09-02T09:00:00'::TIMESTAMP),
    ('1997-09-09T09:00:00'),
    ('1997-09-016T09:00:00')
  $$,
  'testWeekly'
);

SELECT results_eq(
  $$ SELECT * FROM occurrences(
    'RRULE:FREQ=MONTHLY;COUNT=3;INTERVAL=2'::TEXT,
    '1997-09-02T09:00:00'::TIMESTAMP
  ) $$,
  $$ VALUES
    ('1997-09-02T09:00:00'::TIMESTAMP),
    ('1997-11-02T09:00:00'),
    ('1998-01-02T09:00:00')
  $$,
  'testMonthlyInterval'
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


SELECT results_eq(
  $$ SELECT * FROM occurrences(
    'RRULE:FREQ=WEEKLY;COUNT=3;BYDAY=TU,TH'::TEXT,
    '2019-05-06T09:00:00'::TIMESTAMP
  )$$,
  $$ VALUES
    ('2019-05-07T09:00:00'::TIMESTAMP),
    ('2019-05-09T09:00:00'),
    ('2019-05-14T09:00:00')
  $$,
  'testWeeklyByWeekDay'
);

-- SELECT results_eq(
--   $$ SELECT * FROM _rrule.occurrences(_rrule.jsonb_to_rruleset_array('[{"dtend": "1997-09-03T09:00:00", "rrule": {"freq": "WEEKLY", "wkst": "MO", "count": 4, "interval": 1}, "exrule": {}, "dtstart": "1997-09-02T09:00:00"},{"dtend": "1998-09-03T09:00:00", "rrule": {"freq": "MONTHLY", "wkst": "MO", "count": 12, "interval": 1}, "exrule": {}, "dtstart": "1997-09-02T09:00:00"}]'::jsonb), '(,)'::TSRANGE) LIMIT 10;
--   )$$,
--   $$ VALUES
--       ('1997-09-02 09:00:00'),
--       ('1997-09-09 09:00:00'),
--       ('1997-09-16 09:00:00'),
--       ('1997-09-23 09:00:00'),
--       ('1997-10-02 09:00:00'),
--       ('1997-11-02 09:00:00'),
--       ('1997-12-02 09:00:00'),
--       ('1998-01-02 09:00:00'),
--       ('1998-02-02 09:00:00'),
--       ('1998-03-02 09:00:00')
--   $$,
--   'testRulesetArray'
-- );

SELECT * FROM finish();

ROLLBACK;