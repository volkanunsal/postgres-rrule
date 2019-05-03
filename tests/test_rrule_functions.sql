BEGIN;



SELECT plan(8);

SET search_path TO _rrule, public;

SELECT ok(
  _rrule.compare_equal(
    '(DAILY,1,,"1997-12-24 00:00:00",,,,,,,,,,MO)',
    '(DAILY,1,,"1997-12-24 00:00:00",,,,,,,,,,MO)'
  ),
  'Identical rrule objects compare as equal.'
);

SELECT is(
  _rrule.compare_equal(
    '(DAILY,1,,"1997-12-24 00:00:00",,,,,,,,,,MO)',
    '(DAILY,1,,"1997-12-24 00:00:00",,,,,,,,,,TU)'
  ),
  false,
  'Differences in rrule objects compare as not equal'
);


SELECT cmp_ok(
  '(DAILY,1,,"1997-12-24 00:00:00",,,,,,,,,,MO)'::RRULE,
  '=',
  '(DAILY,1,,"1997-12-24 00:00:00",,,,,,,,,,MO)'::RRULE,
  'Identical rrule objects compare as equal.'
);

SELECT cmp_ok(
  '(DAILY,1,,"1997-12-24 00:00:00",,,,,,,,,,MO)'::RRULE,
  '<>',
  '(DAILY,2,,"1997-12-24 00:00:00",,,,,,,,,,MO)'::RRULE,
  'Different rrule objects compare as not equal.'
);


SELECT is(
  _rrule.is_finite('(DAILY,1,,"1997-12-24 00:00:00",,,,,,,,,,MO)'::RRULE),
  true,
  'Has until timestamp: finite'
);

SELECT is(
  _rrule.is_finite('(DAILY,1,10,,,,,,,,,,,)'::RRULE),
  true,
  'Has count: finite'
);

SELECT is(
  _rrule.is_finite('(DAILY,1,,"1997-12-24 00:00:00",,,,,,,,,,MO)'::RRULE),
  true,
  'Has count AND until timestamp: finite'
);

SELECT is(
  _rrule.is_finite('(DAILY,1,,,,,,,,,,,,)'::RRULE),
  false,
  'No count or until: non-finite'
);

SELECT * FROM finish();

ROLLBACK;