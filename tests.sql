BEGIN;


SELECT plan(19);

SET search_path TO public, rrule;

SELECT is(
    parse_rrule('RRULE:FREQ=MONTHLY;COUNT=10;BYMONTHDAY=2,15'),
    '(MONTHLY,1,10,,,,,,"{2,15}",,,,,MO)',
    'On the 2nd and 15th of the month for 10 occcurrences'
);


SELECT is(
    parse_rrule('RRULE:FREQ=MONTHLY;COUNT=10;BYMONTHDAY=2'),
    '(MONTHLY,1,10,,,,,,{2},,,,,MO)',
    'On the 2nd of the month for 10 occcurrences'
);

SELECT results_eq(
    'SELECT * FROM occurrences(
        ''RRULE:FREQ=MONTHLY;COUNT=10;BYMONTHDAY=2'',
        ''2015-01-01''::TIMESTAMP
    )',
    'VALUES
        (''2015-01-02 00:00:00''::TIMESTAMP),
        (''2015-02-02 00:00:00''),
        (''2015-03-02 00:00:00''),
        (''2015-04-02 00:00:00''),
        (''2015-05-02 00:00:00''),
        (''2015-06-02 00:00:00''),
        (''2015-07-02 00:00:00''),
        (''2015-08-02 00:00:00''),
        (''2015-09-02 00:00:00''),
        (''2015-10-02 00:00:00'')
    ',
    'Monthly, on the second day of each month'
);

SELECT is(
    parse_rrule('RRULE:FREQ=DAILY;UNTIL=19971224T000000'),
    '(DAILY,1,,"1997-12-24 00:00:00",,,,,,,,,,MO)',
    'Daily, until Xmas eve 1997'
);


PREPARE daily_until_xmas_eve AS
SELECT * FROM occurrences(
        'RRULE:FREQ=DAILY;UNTIL=19971224T000000',
        '19970902T090000'::TIMESTAMP
);

SELECT results_eq(
    'daily_until_xmas_eve',
    'SELECT * FROM generate_series(
        ''19970902T090000''::TIMESTAMP,
        ''19971224T000000''::TIMESTAMP,
        INTERVAL ''1 day''
    )',
    'Daily, until Xmas Eve 1997'
);


SELECT is(
    parse_rrule(''),
    NULL,
    'Empty string parses as NULL'
);

SELECT is(
    parse_rrule('RRULE:FREQ=MONTHLY;BYWEEKNO=1'),
    NULL,
    'BYWEEKNO is only valid with FREQ=YEARLY'
);

SELECT is(
    parse_rrule('RRULE:FREQ=DAILY;BYYEARDAY=22'),
    NULL,
    'BYYEARDAY is only valid with FREQ in (YEARLY, SECONDLY, MINUTELY, HOURLY)'
);

SELECT is(
    parse_rrule('RRULE:FREQ=DAILY;BYSETPOS=1'),
    NULL,
    'BYSETPOS requires at least one other BY*'
);

SELECT is(
    parse_rrule('RRULE:FREQ=DAILY;BYSETPOS=1;BYMONTH=1'),
    '(DAILY,1,,,,,,,,,,{1},{1},MO)',
    'BYSETPOS requires at least one other BY*'
);

SELECT is(
    parse_rrule('RRULE:FREQ=WEEKLY;BYMONTHDAY=1'),
    NULL,
    'BYMONTHDAY is not valid with FREQ=WEEKLY'
);

SELECT results_eq(
    'SELECT * FROM occurrences(
        ''RRULE:FREQ=YEARLY;INTERVAL=2;COUNT=5'',
        ''19970105T083000''::TIMESTAMP
    )',
    'VALUES
        (''1997-01-05T08:30:00''::TIMESTAMP),
        (''1999-01-05T08:30:00''),
        (''2001-01-05T08:30:00''),
        (''2003-01-05T08:30:00''),
        (''2005-01-05T08:30:00'')
    ',
    'Every two years, on January 5th, for five repeats'
);


SELECT results_eq(
    'SELECT * FROM occurrences(
        ''RRULE:FREQ=YEARLY;INTERVAL=2;COUNT=5;BYMONTH=1'',
        ''19970105T083000''::TIMESTAMP
    )',
    'VALUES
        (''1997-01-05T08:30:00''::TIMESTAMP),
        (''1999-01-05T08:30:00''),
        (''2001-01-05T08:30:00''),
        (''2003-01-05T08:30:00''),
        (''2005-01-05T08:30:00'')
    ',
    'Every two years, on January 5th, for five repeats'
);

SELECT results_eq(
    'SELECT * FROM occurrences(
        ''RRULE:FREQ=YEARLY;INTERVAL=2;COUNT=5;BYMONTH=1;BYMONTHDAY=5,6,7'',
        ''19970105T083000''::TIMESTAMP
    )',
    'VALUES
        (''1997-01-05T08:30:00''::TIMESTAMP),
        (''1997-01-06T08:30:00''::TIMESTAMP),
        (''1997-01-07T08:30:00''::TIMESTAMP),
        (''1999-01-05T08:30:00''::TIMESTAMP),
        (''1999-01-06T08:30:00''::TIMESTAMP)
    ',
    'Every two years, on January 5th,6th,7th, for five repeats'
);

SELECT results_eq(
    'SELECT * FROM occurrences(
        ''RRULE:FREQ=YEARLY;INTERVAL=2;COUNT=10;BYMONTH=1;BYDAY=SU'',
        ''19970105T083000''::TIMESTAMP
    )',
    'VALUES
        (''1997-01-05T08:30:00''::TIMESTAMP),
        (''1997-01-12T08:30:00''),
        (''1997-01-19T08:30:00''),
        (''1997-01-26T08:30:00''),
        (''1999-01-03T08:30:00''),
        (''1999-01-10T08:30:00''),
        (''1999-01-17T08:30:00''),
        (''1999-01-24T08:30:00''),
        (''1999-01-31T08:30:00''),
        (''2001-01-07T08:30:00'')

    ',
    'Every sunday, every two years, on January 1st, for five repeats'
);

-- Tests poached from dateutil.
-- https://github.com/dateutil/dateutil/blob/master/dateutil/test/test.py

SELECT results_eq(
  'SELECT * FROM occurrences(
    ''RRULE:FREQ=YEARLY;COUNT=3'',
    ''1997-09-02T09:00:00''::TIMESTAMP
  )',
  'VALUES
    (''1997-09-02T09:00:00''::TIMESTAMP),
    (''1998-09-02T09:00:00''),
    (''1999-09-02T09:00:00'')
  ',
  'Yearly for three years'
);

SELECT results_eq(
  'SELECT * FROM occurrences(
    ''RRULE:FREQ=YEARLY;COUNT=3;INTERVAL=2'',
    ''1997-09-02T09:00:00''::TIMESTAMP
  )',
  'VALUES
    (''1997-09-02T09:00:00''::TIMESTAMP),
    (''1999-09-02T09:00:00''),
    (''2001-09-02T09:00:00'')
  ',
  'Every second year for three repeats'
);


SELECT results_eq(
  'SELECT * FROM occurrences(
    ''RRULE:FREQ=YEARLY;COUNT=3;INTERVAL=100'',
    ''1997-09-02T09:00:00''::TIMESTAMP
  )',
  'VALUES
    (''1997-09-02T09:00:00''::TIMESTAMP),
    (''2097-09-02T09:00:00''),
    (''2197-09-02T09:00:00'')
  ',
  'Every hundredth year for three repeats'
);

SELECT results_eq(
  'SELECT * FROM occurrences(
    ''RRULE:FREQ=YEARLY;COUNT=3;BYMONTH=1,3'',
    ''1997-09-02T09:00:00''::TIMESTAMP
  )',
  'VALUES
    (''1998-01-02T09:00:00''::TIMESTAMP),
    (''1998-03-02T09:00:00''),
    (''1999-01-02T09:00:00'')
  ',
  'Yearly by month'
);

SELECT results_eq(
  'SELECT * FROM occurrences(
    ''RRULE:FREQ=YEARLY;COUNT=3;BYMONTHDAY=1,3'',
    ''1997-09-02T09:00:00''::TIMESTAMP
  )',
  'VALUES
    (''1997-09-03T09:00:00''::TIMESTAMP),
    (''1997-10-01T09:00:00''),
    (''1997-10-03T09:00:00'')
  ',
  'Yearly by monthday'
);

-- Up to https://github.com/dateutil/dateutil/blob/master/dateutil/test/test.py#L305

SELECT * FROM finish();

ROLLBACK;