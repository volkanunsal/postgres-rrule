BEGIN;

SELECT plan(19);

SET search_path TO _rrule, public;

-- Test RRULE to JSONB conversion
SELECT is(
    (_rrule.rrule_to_jsonb('(DAILY,1,10,,,,,,,,,,,MO)'::RRULE)->>'freq')::text,
    'DAILY',
    'Basic RRULE freq converts to JSONB correctly'
);

SELECT is(
    (_rrule.rrule_to_jsonb('(DAILY,1,10,,,,,,,,,,,MO)'::RRULE)->>'count')::int,
    10,
    'Basic RRULE count converts to JSONB correctly'
);

SELECT is(
    _rrule.rrule_to_jsonb('(MONTHLY,2,5,,,,,,,"{1,15}",,,,MO)'::RRULE) ? 'bymonthday',
    true,
    'RRULE with bymonthday includes it in JSONB'
);

-- Test JSONB to RRULE conversion
SELECT is(
    _rrule.jsonb_to_rrule('{"freq": "DAILY", "count": 10}'::jsonb),
    '(DAILY,1,10,,,,,,,,,,,MO)',
    'JSONB with freq and count converts correctly'
);

SELECT is(
    _rrule.jsonb_to_rrule('{"freq": "WEEKLY", "interval": 2, "byday": ["MO", "FR"]}'::jsonb),
    '(WEEKLY,2,,,,,,,,\"{MO,FR}\",,,,MO)',
    'JSONB with byday converts correctly'
);

-- Test NULL handling
SELECT is(
    _rrule.jsonb_to_rrule('null'::jsonb),
    NULL,
    'NULL JSONB returns NULL'
);

-- Test RRULESET to JSONB conversion
SELECT is(
    (_rrule.rruleset_to_jsonb(
        _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": {"freq": "DAILY", "count": 10}}'::jsonb)
    )->'dtstart')::text,
    '"1997-09-02T09:00:00"',
    'RRULESET dtstart converts to JSONB correctly'
);

SELECT is(
    (_rrule.rruleset_to_jsonb(
        _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": {"freq": "DAILY", "count": 10}}'::jsonb)
    )->'rrule'->'freq')::text,
    '"DAILY"',
    'RRULESET rrule.freq converts to JSONB correctly'
);

-- Test JSONB to RRULESET conversion
SELECT is(
    (_rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": {"freq": "MONTHLY"}}'::jsonb))."dtstart",
    '1997-09-02T09:00:00'::timestamp,
    'JSONB dtstart converts to RRULESET correctly'
);

-- Test DTSTART validation
PREPARE missing_dtstart AS SELECT _rrule.jsonb_to_rruleset('{"rrule": {"freq": "DAILY"}}'::jsonb);
SELECT throws_like(
    'missing_dtstart',
    'DTSTART cannot be null.',
    'RRULESET without DTSTART should raise exception'
);

-- Test DTEND validation
PREPARE invalid_dtend AS SELECT _rrule.jsonb_to_rruleset(
    '{"dtstart": "1997-09-02T09:00:00", "dtend": "1997-09-01T09:00:00", "rrule": {"freq": "DAILY"}}'::jsonb
);
SELECT throws_like(
    'invalid_dtend',
    'DTEND must be greater than or equal to DTSTART.',
    'DTEND before DTSTART should raise exception'
);

-- Test valid DTEND
SELECT is(
    (_rrule.jsonb_to_rruleset(
        '{"dtstart": "1997-09-02T09:00:00", "dtend": "1997-09-03T09:00:00", "rrule": {"freq": "DAILY"}}'::jsonb
    ))."dtend",
    '1997-09-03T09:00:00'::timestamp,
    'Valid DTEND converts correctly'
);

-- Test RRULESET array conversions
SELECT is(
    array_length(_rrule.jsonb_to_rruleset_array(
        '[{"dtstart": "1997-09-02T09:00:00", "rrule": {"freq": "DAILY"}}, {"dtstart": "1998-01-01T09:00:00", "rrule": {"freq": "WEEKLY"}}]'::jsonb
    ), 1),
    2,
    'JSONB array converts to RRULESET array with correct length'
);

SELECT is(
    jsonb_array_length(_rrule.rruleset_array_to_jsonb(
        _rrule.jsonb_to_rruleset_array('[{"dtstart": "1997-09-02T09:00:00", "rrule": {"freq": "DAILY"}}]'::jsonb)
    )),
    1,
    'RRULESET array converts back to JSONB array with correct length'
);

-- Test round-trip conversions
SELECT is(
    _rrule.jsonb_to_rrule(_rrule.rrule_to_jsonb('(DAILY,1,10,,,,,,,,,,,MO)'::RRULE)),
    '(DAILY,1,10,,,,,,,,,,,MO)'::RRULE,
    'RRULE -> JSONB -> RRULE round-trip preserves data'
);

-- Test complex RRULE with multiple BY* parameters
SELECT is(
    (_rrule.rrule_to_jsonb(
        '(YEARLY,1,,,,,,,"{1,15}","{1,-1}","{1,12}",,MO)'::RRULE
    ) ? 'bymonthday'),
    true,
    'Complex RRULE with multiple BY* parameters converts correctly'
);

SELECT is(
    (_rrule.rrule_to_jsonb(
        '(YEARLY,1,,,,,,,"{1,15}","{1,-1}","{1,12}",,MO)'::RRULE
    ) ? 'byyearday'),
    true,
    'Complex RRULE includes byyearday in JSONB'
);

SELECT is(
    (_rrule.rrule_to_jsonb(
        '(YEARLY,1,,,,,,,"{1,15}","{1,-1}","{1,12}",,MO)'::RRULE
    ) ? 'bymonth'),
    true,
    'Complex RRULE includes bymonth in JSONB'
);

-- Test default values
SELECT is(
    _rrule.jsonb_to_rrule('{"freq": "DAILY"}'::jsonb),
    '(DAILY,1,,,,,,,,,,,,MO)',
    'JSONB without interval/wkst uses defaults (interval=1, wkst=MO)'
);

SELECT * FROM finish();

ROLLBACK;
