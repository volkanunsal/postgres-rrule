BEGIN;

SELECT plan(13);

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
  _rrule.rruleset_array_to_jsonb(ARRAY[_rrule.jsonb_to_rruleset('{"dtstart": "19970902T090000", "dtend": "19970903T090000", "rrule": {"freq": "WEEKLY", "count": 4}}'::text::jsonb)]::_rrule.RRULESET[]),
  $$[{"dtend": "1997-09-03T09:00:00", "rrule": {"freq": "WEEKLY", "wkst": "MO", "count": 4, "interval": 1}, "dtstart": "1997-09-02T09:00:00"}]$$::jsonb,
  'rruleset_array_to_jsonb outputs correct result'
);

SELECT is(
  _rrule.jsonb_to_rruleset_array('[{"dtend": "1997-09-03T09:00:00", "rrule": {"freq": "WEEKLY", "wkst": "MO", "count": 4, "interval": 1}, "dtstart": "1997-09-02T09:00:00"}]'::jsonb),
  $${"(\"1997-09-02 09:00:00\",\"1997-09-03 09:00:00\",\"(WEEKLY,1,4,,,,,,,,,,,MO)\",,,)"}$$::_rrule.RRULESET[],
  'jsonb_to_rruleset_array outputs correct result'
);

SELECT is(
  _rrule.jsonb_to_rruleset('{"dtstart": "19970902T090000", "dtend": "19970903T090000", "rrule": {"freq": "WEEKLY", "count": 4}}'::text::jsonb),
  $$
    ("1997-09-02 09:00:00","1997-09-03 09:00:00","(WEEKLY,1,4,,,,,,,,,,,MO)",,,)
  $$,
  'jsonb_to_rruleset outputs correct result'
);

SELECT is(
  _rrule.rruleset_has_before_timestamp(_rrule.jsonb_to_rruleset('{"dtstart": "19970902T090000", "dtend": "19970903T090000", "rrule": {"freq": "WEEKLY", "count": 4}}'::text::jsonb), '19970904T090000'::timestamp),
  true,
  'rruleset_has_before_timestamp returns true'
);

SELECT is(
  _rrule.rruleset_has_before_timestamp(_rrule.jsonb_to_rruleset('{"dtstart": "19970902T090000", "dtend": "19970903T090000", "rrule": {"freq": "WEEKLY", "count": 4}}'::text::jsonb), '19900902T090000'::timestamp),
  false,
  'rruleset_has_before_timestamp returns false'
);

SELECT is(
  _rrule.rruleset_has_after_timestamp(_rrule.jsonb_to_rruleset('{"dtstart": "19970902T090000", "dtend": "19970903T090000", "rrule": {"freq": "WEEKLY", "count": 4}}'::text::jsonb), '19900902T090000'::timestamp),
  true,
  'rruleset_has_after_timestamp returns true'
);

SELECT is(
  _rrule.rruleset_has_after_timestamp(_rrule.jsonb_to_rruleset('{"dtstart": "19970902T090000", "dtend": "19970903T090000", "rrule": {"freq": "WEEKLY", "count": 4}}'::text::jsonb), '19990904T090000'::timestamp),
  false,
  'rruleset_has_after_timestamp returns false'
);

SELECT is(
  _rrule.rruleset_array_has_after_timestamp(_rrule.jsonb_to_rruleset_array('[{"dtstart": "19970902T090000", "dtend": "19970903T090000", "rrule": {"freq": "WEEKLY", "count": 4}}]'::text::jsonb), '19900902T090000'::timestamp),
  true,
  'rruleset_array_has_after_timestamp returns true'
);

SELECT is(
  _rrule.rruleset_array_has_after_timestamp(_rrule.jsonb_to_rruleset_array('[{"dtstart": "19970902T090000", "dtend": "19970903T090000", "rrule": {"freq": "WEEKLY", "count": 4}}]'::text::jsonb), '19990904T090000'::timestamp),
  false,
  'rruleset_has_after_timestamp returns false'
);

SELECT * FROM finish();

ROLLBACK;