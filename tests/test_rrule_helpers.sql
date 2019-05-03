BEGIN;

SELECT plan(7);

SET search_path TO _rrule, public;

SELECT is(
  _rrule.until(
    '(YEARLY,1,,"1997-12-24 00:00:00",,,,,,,,,,MO)'::RRULE,
    '1901-01-01 00:00:00'::TIMESTAMP
  ),
  '1997-12-24 00:00:00'::TIMESTAMP,
  'Explicit until is calculated until.'
);

SELECT is(
  _rrule.until(
    '(YEARLY,1,200,"1997-12-24 00:00:00",,,,,,,,,,MO)'::RRULE,
    '1901-01-01 00:00:00'::TIMESTAMP
  ),
  '1997-12-24 00:00:00'::TIMESTAMP,
  'Explicit until is calculated until if count > occurrences to until.'
);

SELECT is(
  _rrule.until(
    '(YEARLY,1,,,,,,,,,,,,MO)'::RRULE,
    '1901-01-01 00:00:00'::TIMESTAMP
  ),
  NULL::TIMESTAMP,
  'No until or count.'
);

SELECT is(
  _rrule.until(
    '(YEARLY,1,5,"1997-12-24 00:00:00",,,,,,,,,,MO)'::RRULE,
    '1990-01-01 00:00:00'::TIMESTAMP
  ),
  '1995-01-01 00:00:00'::TIMESTAMP,
  'Count limits until target.'
);


SELECT cmp_ok(
  '(YEARLY,1,5,"1997-12-24 00:00:00",,,,,,,,,,MO)'::RRULE,
  '@>',
  '(YEARLY,1,5,"1997-12-24 00:00:00",,,,,,,,,,MO)'::RRULE,
  'RRULE contains itself'
);

SELECT cmp_ok(
  '(YEARLY,1,5,"1997-12-24 00:00:00",,,,,,,,,,MO)'::RRULE,
  '@>',
  '(YEARLY,1,5,"1997-12-24 00:00:00",,,,,,,,,,MO)'::RRULE,
  'RRULE contained by itself'
);

SELECT cmp_ok(
  '(DAILY,1,,,,,,,,,,,,)'::RRULE,
  '@>',
  '(DAILY,2,,,,,,,,,,,,)'::RRULE,
  'Every day contains every second day'
);

SELECT * FROM finish();

ROLLBACK;