BEGIN;

SELECT plan(5);

SET search_path TO public, _rrule;

SELECT is(
  contains_timestamp(
    '
    DTSTART:19970902T090000
    RRULE:FREQ=WEEKLY;UNTIL=19980902T090000
    '::TEXT::RRULESET,
    '19980602T090000'::timestamp
  ),
  true,
  'when timestamp is contained by ruleset.'
);

SELECT is(
  '
  DTSTART:19970902T090000
  RRULE:FREQ=WEEKLY;UNTIL=19980902T090000
  '::TEXT::RRULESET
  @>
  '19980602T090000'::timestamp,
  true,
  'when timestamp is NOT contained by ruleset (@> operator).'
);

SELECT is(
  contains_timestamp(
    '
    DTSTART:19970902T090000
    RRULE:FREQ=WEEKLY;UNTIL=19980902T090000
    '::TEXT::RRULESET,
    '19980603T090000'::timestamp
  ),
  false,
  'when timestamp is NOT contained by ruleset.'
);

SELECT is(
    '
    DTSTART:19970902T090000
    RRULE:FREQ=WEEKLY;UNTIL=19980902T090000
    '::TEXT::RRULESET
    @> '19980603T090000'::timestamp,
  false,
  'when timestamp is NOT contained by ruleset (@> operator).'
);

SELECT is(
    _rrule.jsonb_to_rruleset_array('[{"dtend": "1997-09-03T09:00:00", "rrule": {"freq": "WEEKLY", "wkst": "MO", "count": 4, "interval": 1}, "exrule": {}, "dtstart": "1997-09-02T09:00:00"}]'::jsonb)
    @> '1997-09-02T09:00:00'::text::timestamp,
  true,
  'when timestamp is contained by ruleset array (@> operator).'
);

SELECT * FROM finish();

ROLLBACK;