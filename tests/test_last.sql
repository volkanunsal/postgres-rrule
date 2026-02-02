BEGIN;

SELECT plan(3);

SET search_path TO public, _rrule;

SELECT is(
  _rrule.last(
    _rrule.jsonb_to_rruleset_array('[{"dtstart": "1997-09-02T09:00:00", "dtend": "1997-09-03T09:00:00", "rrule": [{"freq": "WEEKLY", "wkst": "MO", "count": 4, "interval": 1}]}]'::jsonb)
  ),
  '1997-09-23 09:00:00'::TIMESTAMP,
  'when argument is rruleset array.'
);

SELECT is(
  _rrule.last(
    _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "dtend": "1997-09-03T09:00:00", "rrule": [{"freq": "WEEKLY", "wkst": "MO", "count": 4, "interval": 1}]}'::jsonb)
  ),
  '1997-09-23 09:00:00'::TIMESTAMP,
  'when argument is rruleset.'
);

SELECT is(
  _rrule.last(
    _rrule.jsonb_to_rruleset_array('[{"dtstart": "1997-09-02T09:00:00", "dtend": "1997-09-03T09:00:00", "rrule": [{"freq": "WEEKLY"}]}]'::jsonb)
  ),
  NULL::TIMESTAMP,
  'when recurrence is not infinite.'
);


SELECT * FROM finish();