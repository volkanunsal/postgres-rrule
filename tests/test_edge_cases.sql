BEGIN;

SELECT plan(18);

SET search_path TO _rrule, public;

-- Test COUNT boundary values
SELECT is(
    rrule('RRULE:FREQ=DAILY;COUNT=1'),
    '(DAILY,1,1,,,,,,,,,,,MO)',
    'COUNT=1 (minimum valid value) works'
);

SELECT is(
    rrule('RRULE:FREQ=DAILY;COUNT=999999'),
    '(DAILY,1,999999,,,,,,,,,,,MO)',
    'Large COUNT value works'
);

-- Test INTERVAL boundary values
SELECT is(
    rrule('RRULE:FREQ=DAILY;INTERVAL=1'),
    '(DAILY,1,,,,,,,,,,,MO)',
    'INTERVAL=1 (minimum valid value) works'
);

SELECT is(
    rrule('RRULE:FREQ=DAILY;INTERVAL=100'),
    '(DAILY,100,,,,,,,,,,,MO)',
    'Large INTERVAL value works'
);

PREPARE zero_interval AS SELECT rrule('RRULE:FREQ=DAILY;INTERVAL=0');
SELECT throws_like(
    'zero_interval',
    'INTERVAL must be a non-zero integer.',
    'INTERVAL=0 raises exception'
);

-- Test timestamp edge cases
SELECT ok(
    (SELECT count(*) FROM _rrule.occurrences(
        '(DAILY,1,1,,,,,,,,,,,MO)'::RRULE,
        '1970-01-01T00:00:00'::timestamp
    )) = 1,
    'Unix epoch timestamp works as dtstart'
);

SELECT ok(
    (SELECT count(*) FROM _rrule.occurrences(
        '(DAILY,1,1,,,,,,,,,,,MO)'::RRULE,
        '2038-01-19T03:14:07'::timestamp
    )) = 1,
    'Near 32-bit time_t limit works'
);

SELECT ok(
    (SELECT count(*) FROM _rrule.occurrences(
        '(DAILY,1,1,,,,,,,,,,,MO)'::RRULE,
        '1900-01-01T00:00:00'::timestamp
    )) = 1,
    'Historical timestamp (1900) works'
);

SELECT ok(
    (SELECT count(*) FROM _rrule.occurrences(
        '(DAILY,1,1,,,,,,,,,,,MO)'::RRULE,
        '2100-12-31T23:59:59'::timestamp
    )) = 1,
    'Far future timestamp (2100) works'
);

-- Test leap year handling
SELECT ok(
    (SELECT occurrence::date FROM _rrule.occurrences(
        '(YEARLY,1,1,,,,,,,,,,,MO)'::RRULE,
        '2000-02-29T00:00:00'::timestamp
    ) LIMIT 1) = '2000-02-29'::date,
    'Leap year day (Feb 29) works'
);

-- Test time component edge cases
SELECT ok(
    (SELECT extract(hour from occurrence) FROM _rrule.occurrences(
        '(DAILY,1,1,,,,,,,,,,,MO)'::RRULE,
        '2000-01-01T00:00:00'::timestamp
    )) = 0,
    'Midnight (00:00:00) time works'
);

SELECT ok(
    (SELECT extract(hour from occurrence) FROM _rrule.occurrences(
        '(DAILY,1,1,,,,,,,,,,,MO)'::RRULE,
        '2000-01-01T23:59:59'::timestamp
    )) = 23,
    'End of day (23:59:59) time works'
);

-- Test BYMONTHDAY edge cases
SELECT is(
    rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=-1'),
    '(MONTHLY,1,,,,,,,{-1},,,,,MO)',
    'BYMONTHDAY=-1 (last day of month) works'
);

SELECT is(
    rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=31'),
    '(MONTHLY,1,,,,,,,{31},,,,,MO)',
    'BYMONTHDAY=31 (max day value) works'
);

-- Test BYHOUR edge cases
SELECT ok(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.jsonb_to_rrule('{"freq": "DAILY", "count": 1, "byhour": [0]}'::jsonb),
        '2000-01-01T00:00:00'::timestamp
    )) > 0,
    'BYHOUR=0 (midnight) works'
);

SELECT ok(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.jsonb_to_rrule('{"freq": "DAILY", "count": 1, "byhour": [23]}'::jsonb),
        '2000-01-01T00:00:00'::timestamp
    )) > 0,
    'BYHOUR=23 (last hour) works'
);

-- Test DTEND equals DTSTART (zero duration)
SELECT ok(
    _rrule.jsonb_to_rruleset(
        '{"dtstart": "1997-09-02T09:00:00", "dtend": "1997-09-02T09:00:00", "rrule": {"freq": "DAILY"}}'::jsonb
    ) IS NOT NULL,
    'DTEND equals DTSTART (zero duration) is valid'
);

-- Test very short UNTIL duration
SELECT ok(
    (SELECT count(*) FROM _rrule.occurrences(
        '(DAILY,1,,"1997-09-02T09:00:01",,,,,,,,,MO)'::RRULE,
        '1997-09-02T09:00:00'::timestamp
    )) = 1,
    'UNTIL just 1 second after DTSTART works'
);

SELECT * FROM finish();

ROLLBACK;
