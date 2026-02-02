BEGIN;

SELECT plan(16);

SET search_path TO _rrule, public;

-- Test before() function with RRULE
SELECT is(
    (SELECT count(*) FROM _rrule.before(
        '(DAILY,1,10,,,,,,,,,,,MO)'::RRULE,
        '1997-09-02T09:00:00'::timestamp,
        '1997-09-05T09:00:00'::timestamp
    )),
    3::bigint,
    'before() returns correct count for RRULE (3 occurrences before cutoff)'
);

SELECT is(
    (SELECT count(*) FROM _rrule.before(
        '(DAILY,1,10,,,,,,,,,,,MO)'::RRULE,
        '1997-09-02T09:00:00'::timestamp,
        '1997-09-02T08:59:59'::timestamp
    )),
    0::bigint,
    'before() with cutoff before dtstart returns 0'
);

SELECT is(
    (SELECT count(*) FROM _rrule.before(
        '(DAILY,1,10,,,,,,,,,,,MO)'::RRULE,
        '1997-09-02T09:00:00'::timestamp,
        '1997-09-02T09:00:00'::timestamp
    )),
    0::bigint,
    'before() with cutoff equal to dtstart returns 0'
);

-- Test after() function with RRULE
SELECT is(
    (SELECT count(*) FROM _rrule.after(
        '(DAILY,1,10,,,,,,,,,,,MO)'::RRULE,
        '1997-09-02T09:00:00'::timestamp,
        '1997-09-02T09:00:00'::timestamp
    )),
    9::bigint,
    'after() returns occurrences after dtstart (9 remaining from 10 total)'
);

SELECT is(
    (SELECT count(*) FROM _rrule.after(
        '(DAILY,1,10,,,,,,,,,,,MO)'::RRULE,
        '1997-09-02T09:00:00'::timestamp,
        '1997-09-05T09:00:00'::timestamp
    )),
    6::bigint,
    'after() with mid-range cutoff returns correct count'
);

SELECT is(
    (SELECT count(*) FROM _rrule.after(
        '(DAILY,1,3,,,,,,,,,,,MO)'::RRULE,
        '1997-09-02T09:00:00'::timestamp,
        '1997-09-10T09:00:00'::timestamp
    )),
    0::bigint,
    'after() with cutoff after all occurrences returns 0'
);

-- Test rruleset_has_before_timestamp
SELECT is(
    _rrule.rruleset_has_before_timestamp(
        _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": {"freq": "DAILY", "count": 10}}'::jsonb),
        '1997-09-05T09:00:00'::timestamp
    ),
    true,
    'rruleset_has_before_timestamp returns true when occurrences exist before timestamp'
);

SELECT is(
    _rrule.rruleset_has_before_timestamp(
        _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": {"freq": "DAILY", "count": 10}}'::jsonb),
        '1997-09-01T09:00:00'::timestamp
    ),
    false,
    'rruleset_has_before_timestamp returns false when no occurrences before timestamp'
);

-- Test rruleset_has_after_timestamp
SELECT is(
    _rrule.rruleset_has_after_timestamp(
        _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": {"freq": "DAILY", "count": 10}}'::jsonb),
        '1997-09-05T09:00:00'::timestamp
    ),
    true,
    'rruleset_has_after_timestamp returns true when occurrences exist after timestamp'
);

SELECT is(
    _rrule.rruleset_has_after_timestamp(
        _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": {"freq": "DAILY", "count": 3}}'::jsonb),
        '1997-09-10T09:00:00'::timestamp
    ),
    false,
    'rruleset_has_after_timestamp returns false when no occurrences after timestamp'
);

-- Test before() with RRULESET
SELECT is(
    (SELECT count(*) FROM _rrule.before(
        _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": {"freq": "DAILY", "count": 10}}'::jsonb),
        '1997-09-05T09:00:00'::timestamp
    )),
    3::bigint,
    'before() with RRULESET returns correct count'
);

-- Test after() with RRULESET
SELECT is(
    (SELECT count(*) FROM _rrule.after(
        _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": {"freq": "DAILY", "count": 10}}'::jsonb),
        '1997-09-05T09:00:00'::timestamp
    )),
    6::bigint,
    'after() with RRULESET returns correct count'
);

-- Test before() with RRULESET array
SELECT is(
    (SELECT count(*) FROM _rrule.before(
        ARRAY[
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": {"freq": "DAILY", "count": 3}}'::jsonb),
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-10T09:00:00", "rrule": {"freq": "DAILY", "count": 3}}'::jsonb)
        ],
        '1997-09-11T09:00:00'::timestamp
    )),
    4::bigint,
    'before() with RRULESET array combines occurrences from multiple rulesets'
);

-- Test after() with RRULESET array
SELECT is(
    (SELECT count(*) FROM _rrule.after(
        ARRAY[
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": {"freq": "DAILY", "count": 3}}'::jsonb),
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-10T09:00:00", "rrule": {"freq": "DAILY", "count": 3}}'::jsonb)
        ],
        '1997-09-03T09:00:00'::timestamp
    )),
    4::bigint,
    'after() with RRULESET array combines occurrences from multiple rulesets'
);

-- Test with infinite recurrence
SELECT ok(
    (SELECT count(*) FROM _rrule.after(
        '(DAILY,1,,,,,,,,,,,MO)'::RRULE,
        '1997-09-02T09:00:00'::timestamp,
        '1997-09-02T09:00:00'::timestamp
    ) LIMIT 100) = 100,
    'after() with infinite recurrence can return limited results'
);

SELECT ok(
    (SELECT count(*) FROM _rrule.before(
        '(DAILY,1,,"1997-09-10T09:00:00",,,,,,,,,MO)'::RRULE,
        '1997-09-02T09:00:00'::timestamp,
        '1997-09-10T09:00:00'::timestamp
    )) = 8,
    'before() with UNTIL works correctly'
);

SELECT * FROM finish();

ROLLBACK;
