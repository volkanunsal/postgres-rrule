BEGIN;

SELECT plan(17);

SET search_path TO _rrule, public;

-- Test 1: First Tuesday of each month
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=MONTHLY;COUNT=3;BYDAY=1TU'),
        '2026-01-01T09:00:00'::timestamp
    )),
    3::bigint,
    'First Tuesday: generates 3 occurrences'
);

-- Verify they are all Tuesdays
SELECT ok(
    (SELECT bool_and(to_char(occurrences, 'DY') = 'TUE') FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=MONTHLY;COUNT=3;BYDAY=1TU'),
        '2026-01-01T09:00:00'::timestamp
    ) AS occurrences),
    'First Tuesday: all occurrences are Tuesdays'
);

-- Test 2: Last Friday of each month
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=MONTHLY;COUNT=3;BYDAY=-1FR'),
        '2026-01-01T09:00:00'::timestamp
    )),
    3::bigint,
    'Last Friday: generates 3 occurrences'
);

SELECT ok(
    (SELECT bool_and(to_char(occurrences, 'DY') = 'FRI') FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=MONTHLY;COUNT=3;BYDAY=-1FR'),
        '2026-01-01T09:00:00'::timestamp
    ) AS occurrences),
    'Last Friday: all occurrences are Fridays'
);

-- Test 3: Second Monday of each month
SELECT is(
    (SELECT array_agg(occurrences ORDER BY occurrences) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=MONTHLY;COUNT=3;BYDAY=2MO'),
        '2026-01-01T09:00:00'::timestamp
    ) AS occurrences),
    ARRAY[
        '2026-01-12T09:00:00'::timestamp,
        '2026-02-09T09:00:00'::timestamp,
        '2026-03-09T09:00:00'::timestamp
    ],
    'Second Monday: correct dates for first 3 months of 2026'
);

-- Test 4: Multiple ordinal BYDAY values
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=MONTHLY;COUNT=6;BYDAY=1MO,3FR'),
        '2026-01-01T09:00:00'::timestamp
    )),
    6::bigint,
    'Multiple ordinal BYDAY: first Monday and third Friday'
);

-- Test 5: Ordinal BYDAY with interval > 1
SELECT is(
    (SELECT array_agg(occurrences ORDER BY occurrences) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=MONTHLY;COUNT=3;INTERVAL=2;BYDAY=1TU'),
        '2026-01-01T09:00:00'::timestamp
    ) AS occurrences),
    ARRAY[
        '2026-01-06T09:00:00'::timestamp,
        '2026-03-03T09:00:00'::timestamp,
        '2026-05-05T09:00:00'::timestamp
    ],
    'Ordinal BYDAY with INTERVAL=2: first Tuesday every 2 months'
);

-- Test 6: Ordinal BYDAY with UNTIL
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=MONTHLY;UNTIL=20260301T090000Z;BYDAY=1WE'),
        '2026-01-01T09:00:00'::timestamp
    )),
    2::bigint,
    'Ordinal BYDAY with UNTIL: stops at correct date'
);

-- Test 7: Third Wednesday
SELECT ok(
    (SELECT bool_and(to_char(occurrences, 'DY') = 'WED') FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=MONTHLY;COUNT=3;BYDAY=3WE'),
        '2026-01-01T09:00:00'::timestamp
    ) AS occurrences),
    'Third Wednesday: all occurrences are Wednesdays'
);

-- Test 8: Second-to-last Thursday
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=MONTHLY;COUNT=3;BYDAY=-2TH'),
        '2026-01-01T09:00:00'::timestamp
    )),
    3::bigint,
    'Second-to-last Thursday: generates 3 occurrences'
);

-- Test 9: Text round-trip with ordinal BYDAY
SELECT is(
    _rrule.text(_rrule.rrule('RRULE:FREQ=MONTHLY;COUNT=3;BYDAY=1TU')),
    'RRULE:FREQ=MONTHLY;COUNT=3;BYDAY=1TU',
    'Text round-trip: ordinal BYDAY preserved'
);

-- Test 10: Text round-trip with negative ordinal
SELECT is(
    _rrule.text(_rrule.rrule('RRULE:FREQ=MONTHLY;COUNT=3;BYDAY=-1FR')),
    'RRULE:FREQ=MONTHLY;COUNT=3;BYDAY=-1FR',
    'Text round-trip: negative ordinal BYDAY preserved'
);

-- Test 11: Text round-trip with multiple ordinal BYDAY
SELECT is(
    _rrule.text(_rrule.rrule('RRULE:FREQ=MONTHLY;COUNT=3;BYDAY=1MO,2TU,-1FR')),
    'RRULE:FREQ=MONTHLY;COUNT=3;BYDAY=1MO,2TU,-1FR',
    'Text round-trip: multiple ordinal BYDAY preserved'
);

-- Test 12: JSONB conversion with ordinal BYDAY
SELECT is(
    ((_rrule.jsonb_to_rruleset('{"dtstart": "2026-01-01T09:00:00", "rrule": [{"freq": "MONTHLY", "count": 3, "byday": ["1TU"]}]}'::jsonb))."rrule")[1].byday,
    ARRAY['1TU']::TEXT[],
    'JSONB parsing: ordinal BYDAY parsed correctly'
);

-- Test 13: Ordinal BYDAY in RRULESET
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.jsonb_to_rruleset('{"dtstart": "2026-01-01T09:00:00", "rrule": [{"freq": "MONTHLY", "count": 3, "byday": ["1TU"]}]}'::jsonb)
    )),
    3::bigint,
    'RRULESET with ordinal BYDAY: generates correct count'
);

-- Test 14: Ordinal BYDAY starting mid-month
SELECT is(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=MONTHLY;COUNT=3;BYDAY=1TU'),
        '2026-01-15T09:00:00'::timestamp
    )),
    3::bigint,
    'Ordinal BYDAY with mid-month start: generates 3 occurrences (skips January)'
);

-- Test 15: Time component preserved with ordinal BYDAY
SELECT is(
    (SELECT EXTRACT(HOUR FROM occurrences)::INTEGER FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=MONTHLY;COUNT=1;BYDAY=1TU'),
        '2026-01-01T14:30:45'::timestamp
    ) AS occurrences LIMIT 1),
    14,
    'Ordinal BYDAY: time component from dtstart preserved'
);

SELECT * FROM finish();

ROLLBACK;
