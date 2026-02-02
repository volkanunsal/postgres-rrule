BEGIN;

SELECT plan(13);

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
  '9999-12-31 23:59:59'::TIMESTAMP,
  'No until or count returns far-future date for infinite recurrence.'
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

SELECT is(
  _rrule.jsonb_to_rruleset_array('[{"dtstart": "19970902T090000", "dtend": "19970903T090000", "rrule": [{"freq": "WEEKLY", "count": 4}]}]'::text::jsonb) > '19990904T090000'::timestamp,
  false,
  '> operator works with rruleset_array - returns false'
);

SELECT is(
  _rrule.jsonb_to_rruleset_array('[{"dtstart": "19970902T090000", "dtend": "19970903T090000", "rrule": [{"freq": "WEEKLY", "count": 4}]}]'::text::jsonb) > '19900902T090000'::timestamp,
  true,
  '> operator works with rruleset_array - returns true'
);

SELECT is(
  _rrule.jsonb_to_rruleset('{"dtstart": "19970902T090000", "dtend": "19970903T090000", "rrule": [{"freq": "WEEKLY", "count": 4}]}'::text::jsonb) > '19990904T090000'::timestamp,
  false,
  '> operator works with rruleset - returns false'
);

SELECT is(
  _rrule.jsonb_to_rruleset('{"dtstart": "19970902T090000", "dtend": "19970903T090000", "rrule": [{"freq": "WEEKLY", "count": 4}]}'::text::jsonb) > '19900902T090000'::timestamp,
  true,
  '> operator works with rruleset - returns true'
);

SELECT is(
  _rrule.jsonb_to_rruleset('{"dtstart": "19970902T090000", "dtend": "19970903T090000", "rrule": [{"freq": "WEEKLY", "count": 4}]}'::text::jsonb) < '19970904T090000'::timestamp,
  true,
  '< operator works with rruleset - returns true'
);

SELECT is(
  _rrule.jsonb_to_rruleset('{"dtstart": "19970902T090000", "dtend": "19970903T090000", "rrule": [{"freq": "WEEKLY", "count": 4}]}'::text::jsonb) < '19900902T090000'::timestamp,
  false,
  '< operator works with rruleset - returns false'
);


SELECT * FROM finish();

ROLLBACK;