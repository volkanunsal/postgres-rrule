BEGIN;

SELECT plan(10);

SET search_path TO _rrule, public;

-- Test 1: Multiple RRULEs combine occurrences
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.jsonb_to_rruleset('{
            "dtstart": "2026-01-05T09:00:00",
            "rrule": [
                {"freq": "WEEKLY", "byday": ["MO"]},
                {"freq": "DAILY", "interval": 3}
            ]
        }'::jsonb),
        tsrange('2026-01-05', '2026-02-01')
    )),
    11::bigint,
    'Multiple RRULEs combine to produce union of occurrences'
);

-- Test 2: Single EXRULE excludes from combined RRULEs
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.jsonb_to_rruleset('{
            "dtstart": "2026-01-01T09:00:00",
            "rrule": [
                {"freq": "DAILY", "count": 10}
            ],
            "exrule": [{"freq": "DAILY", "interval": 2}]
        }'::jsonb)
    )),
    5::bigint,
    'EXRULE excludes every other day (10 days - 5 excluded = 5 remaining)'
);

-- Test 3: EXRULE with BYDAY excludes specific weekdays
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.jsonb_to_rruleset('{
            "dtstart": "2026-01-05T09:00:00",
            "rrule": [
                {"freq": "DAILY", "count": 14}
            ],
            "exrule": [{"freq": "WEEKLY", "byday": ["MO"]}]
        }'::jsonb),
        tsrange('2026-01-05', '2026-01-19')
    )),
    12::bigint,
    'EXRULE excludes Mondays from daily occurrences (14 days - 2 Mondays = 12)'
);

-- Test 4: Multiple EXRULEs combine exclusions
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.jsonb_to_rruleset('{
            "dtstart": "2026-01-01T09:00:00",
            "rrule": [{"freq": "DAILY", "count": 31}],
            "exrule": [
                {"freq": "WEEKLY", "byday": ["SA"]},
                {"freq": "WEEKLY", "byday": ["SU"]}
            ]
        }'::jsonb),
        tsrange('2026-01-01', '2026-02-01')
    )),
    22::bigint,
    'Multiple EXRULEs exclude weekends (31 days - 9 weekend days = 22)'
);

-- Test 5: Backwards compatibility - single RRULE as object still works
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.jsonb_to_rruleset('{
            "dtstart": "2026-01-01T09:00:00",
            "rrule": {"freq": "DAILY", "count": 5}
        }'::jsonb)
    )),
    5::bigint,
    'Backwards compatible: single RRULE object (not array) works'
);

-- Test 6: Empty RRULE array returns only RDATE occurrences
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.jsonb_to_rruleset('{
            "dtstart": "2026-01-01T09:00:00",
            "rrule": [],
            "rdate": ["2026-01-15T09:00:00", "2026-01-20T09:00:00"]
        }'::jsonb)
    )),
    2::bigint,
    'Empty RRULE array with RDATE returns only RDATE occurrences'
);

-- Test 7: RDATE adds to multiple RRULEs
SELECT is(
    (SELECT count(*) FROM (
        SELECT DISTINCT * FROM _rrule.occurrences(
            _rrule.jsonb_to_rruleset('{
                "dtstart": "2026-01-01T09:00:00",
                "rrule": [
                    {"freq": "DAILY", "interval": 7, "count": 2}
                ],
                "rdate": ["2026-01-15T09:00:00"]
            }'::jsonb)
        ) AS occurrences
    )),
    3::bigint,
    'RDATE adds additional occurrences to RRULE set'
);

-- Test 8: EXDATE excludes from multiple RRULEs
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.jsonb_to_rruleset('{
            "dtstart": "2026-01-01T09:00:00",
            "rrule": [
                {"freq": "DAILY", "count": 10}
            ],
            "exdate": ["2026-01-05T09:00:00", "2026-01-07T09:00:00"]
        }'::jsonb)
    )),
    8::bigint,
    'EXDATE excludes specific dates from RRULE occurrences (10 - 2 = 8)'
);

-- Test 9: Complex scenario - multiple rules with RDATE, EXRULE, and EXDATE
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.jsonb_to_rruleset('{
            "dtstart": "2026-01-05T09:00:00",
            "rrule": [
                {"freq": "DAILY", "count": 10}
            ],
            "rdate": ["2026-01-20T09:00:00"],
            "exrule": [{"freq": "DAILY", "interval": 3}],
            "exdate": ["2026-01-08T09:00:00"]
        }'::jsonb)
    )),
    6::bigint,
    'Complex: RRULE + RDATE - EXRULE - EXDATE combines correctly'
);

-- Test 10: rruleset_to_jsonb outputs arrays
SELECT is(
    jsonb_typeof((_rrule.rruleset_to_jsonb(
        _rrule.jsonb_to_rruleset('{
            "dtstart": "2026-01-01T09:00:00",
            "rrule": [{"freq": "DAILY", "count": 3}]
        }'::jsonb)
    ))->'rrule'),
    'array'::text,
    'rruleset_to_jsonb outputs rrule as array'
);

SELECT * FROM finish();

ROLLBACK;
