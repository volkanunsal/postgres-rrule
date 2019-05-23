BEGIN;

SELECT plan(6);

SET search_path TO _rrule, public;

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

SELECT is(
  _rrule.is_finite(
    _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "dtend": "1997-09-03T09:00:00", "rrule": {"freq": "DAILY"}}'::jsonb)
  ),
  false,
  'Recurrence is not finite.'
);

SELECT is(
  _rrule.is_finite(
    _rrule.jsonb_to_rruleset_array('[{"dtstart": "1997-09-02T09:00:00", "dtend": "1997-09-03T09:00:00", "rrule": {"freq": "DAILY"}}]'::jsonb)
  ),
  false,
  'Recurrence array is not finite.'
);

SELECT * FROM finish();

ROLLBACK;