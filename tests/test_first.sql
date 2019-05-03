BEGIN;

SELECT plan(6);

SET search_path TO public, _rrule;

SELECT is(
  _rrule.first(
    'RRULE:FREQ=YEARLY'::TEXT::RRULE,
    '19970105T083000'::TIMESTAMP
  ),
  '1997-01-05T08:30:00'::TIMESTAMP,
  '"dtstart" is first instance is simplest case'
);

SELECT is(
  _rrule.first(
    'RRULE:FREQ=MONTHLY;BYMONTH=2'::TEXT::RRULE,
    '1997-01-01T00:00:00'::TIMESTAMP
  ),
  '1997-02-01T00:00:00'::TIMESTAMP,
  '"BYMONTH" overrides first instance month.'
);

SELECT is(
  _rrule.first(
    'RRULE:FREQ=MONTHLY;BYMONTH=1'::TEXT::RRULE,
    '1997-02-01T00:00:00'::TIMESTAMP
  ),
  '1998-01-01T00:00:00'::TIMESTAMP,
  'It''s possible that the first instance will be in the following year.'
);

SELECT is(
  _rrule.first(
    'RRULE:FREQ=DAILY;BYMONTH=1,2,3;BYMONTHDAY=7,8,9'::TEXT::RRULE,
    '1997-02-14T00:00:00'::TIMESTAMP
  ),
  '1997-03-07T00:00:00'::TIMESTAMP,
  'Multiple BYMONTH and BYDAY rules work together.'
);

SELECT is(
  _rrule.first(
    'RRULE:FREQ=WEEKLY'::TEXT::RRULE,
    '1997-02-14T00:00:00'::TIMESTAMP
  ),
  '1997-02-14T00:00:00'::TIMESTAMP,
  'Simple case: WEEKLY.'
);

SELECT is(
  _rrule.first(
    'RRULE:FREQ=DAILY'::TEXT::RRULE,
    '1997-02-14T00:00:00'::TIMESTAMP
  ),
  '1997-02-14T00:00:00'::TIMESTAMP,
  'Simple case: DAILY.'
);


SELECT * FROM finish();