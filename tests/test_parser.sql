BEGIN;



SELECT plan(9);

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

SELECT is(
    rrule(''),
    NULL,
    'Empty string parses as NULL'
);

SELECT is(
    rrule('RRULE:FREQ=MONTHLY;BYWEEKNO=1'),
    NULL,
    'BYWEEKNO is only valid with FREQ=YEARLY'
);

SELECT is(
    rrule('RRULE:FREQ=DAILY;BYYEARDAY=22'),
    NULL,
    'BYYEARDAY is only valid with FREQ in (YEARLY, SECONDLY, MINUTELY, HOURLY)'
);

SELECT is(
    rrule('RRULE:FREQ=DAILY;BYSETPOS=1'),
    NULL,
    'BYSETPOS requires at least one other BY*'
);

SELECT is(
    rrule('RRULE:FREQ=DAILY;BYSETPOS=1;BYMONTH=1'),
    '(DAILY,1,,,,,,,,,,{1},{1},MO)',
    'BYSETPOS requires at least one other BY*'
);

SELECT is(
    rrule('RRULE:FREQ=WEEKLY;BYMONTHDAY=1'),
    NULL,
    'BYMONTHDAY is not valid with FREQ=WEEKLY'
);

SELECT * FROM finish();

ROLLBACK;