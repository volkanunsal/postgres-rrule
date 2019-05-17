BEGIN;

SELECT plan(2);

SET search_path TO public, _rrule;


SELECT is(
  '{"freq": "WEEKLY", "count": 4}'::text::jsonb::_rrule.RRULE::jsonb,
  $$
    {"freq": "WEEKLY", "wkst": "MO", "count": 4, "interval": 1}
  $$,
  'when RRULE is cast to jsonb.'
);

SELECT is(
  '{"freq": "WEEKLY", "count": 4}'::text::jsonb::_rrule.RRULE,
  $$
    (WEEKLY,1,4,,,,,,,,,,,MO)
  $$,
  'when jsonb is cast to RRULE.'
);

SELECT * FROM finish();

ROLLBACK;