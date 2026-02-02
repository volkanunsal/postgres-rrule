BEGIN;

SELECT plan(13);

SET search_path TO _rrule, public;

SELECT is(
    rrule('RRULE:FREQ=MONTHLY;COUNT=10;BYMONTHDAY=2,15'),
    '(MONTHLY,1,10,,,,,,"{2,15}",,,,,MO)',
    'On the 2nd and 15th of the month for 10 occcurrences'
);


SELECT is(
    rrule('RRULE:FREQ=MONTHLY;COUNT=10;BYMONTHDAY=2'),
    '(MONTHLY,1,10,,,,,,{2},,,,,MO)',
    'On the 2nd of the month for 10 occcurrences'
);


SELECT is(
    rrule('RRULE:FREQ=DAILY;UNTIL=19971224T000000'),
    '(DAILY,1,,"1997-12-24 00:00:00",,,,,,,,,,MO)',
    'Daily, until Xmas eve 1997'
);

PREPARE my_thrower AS SELECT rrule('');
SELECT throws_like(
    'my_thrower',
    'FREQ cannot be null.',
    'Empty string raises exception.'
);

PREPARE my_thrower2 AS SELECT rrule('RRULE:FREQ=MONTHLY;BYWEEKNO=1');
SELECT throws_like(
    'my_thrower2',
    'FREQ must be YEARLY if BYWEEKNO is provided.',
    'BYWEEKNO is only valid with FREQ=YEARLY'
);

PREPARE my_thrower3 AS SELECT rrule('RRULE:FREQ=DAILY;BYYEARDAY=22');
SELECT throws_like(
    'my_thrower3',
    'BYYEARDAY is only valid when FREQ is YEARLY.',
    'BYYEARDAY is only valid when FREQ is YEARLY.'
);

PREPARE my_thrower4 AS SELECT rrule('RRULE:FREQ=WEEKLY;BYMONTHDAY=1');
SELECT throws_like(
    'my_thrower4',
    'BYMONTHDAY is not valid when FREQ is WEEKLY.',
    'BYMONTHDAY is not valid when FREQ is WEEKLY.'
);

PREPARE my_thrower5 AS SELECT rrule('RRULE:FREQ=DAILY;BYSETPOS=1');
SELECT throws_like(
    'my_thrower5',
    'BYSETPOS requires at least one other BY* parameter.',
    'BYSETPOS requires at least one other BY* parameter.'
);

PREPARE my_thrower6 AS SELECT rrule('RRULE:FREQ=DAILY;BYDAY=TU');
SELECT throws_like(
    'my_thrower6',
    'BYDAY is not valid when FREQ is DAILY.',
    'BYDAY is not valid when FREQ is DAILY.'
);

PREPARE my_thrower7 AS SELECT rrule('RRULE:FREQ=DAILY;UNTIL=19971224T000000;COUNT=3');
SELECT throws_like(
    'my_thrower7',
    'UNTIL and COUNT must not occur in the same recurrence.',
    'UNTIL and COUNT must not occur in the same recurrence.'
);

PREPARE my_thrower8 AS SELECT rrule('RRULE:FREQ=DAILY;INTERVAL=-1');
SELECT throws_like(
    'my_thrower8',
    'INTERVAL must be a non-zero integer.',
    'INTERVAL must be a non-zero integer.'
);

-- Test EXRULE parsing
SELECT is(
    (rruleset('DTSTART:20230724T100000
RRULE:FREQ=WEEKLY;BYDAY=MO,WE
EXRULE:FREQ=WEEKLY;BYDAY=MO,WE'))."exrule",
    '(WEEKLY,1,,,,,,"{MO,WE}",,,,,,MO)',
    'EXRULE is parsed correctly'
);

SELECT is(
    (rruleset('DTSTART:20230724T100000
RRULE:FREQ=DAILY;COUNT=10
EXRULE:FREQ=WEEKLY;BYDAY=FR'))."exrule",
    '(WEEKLY,1,,,,,,{FR},,,,,,MO)',
    'EXRULE with different FREQ than RRULE is parsed correctly'
);


SELECT * FROM finish();

ROLLBACK;