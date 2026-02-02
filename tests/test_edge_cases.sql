BEGIN;

SELECT plan(18);

SET search_path TO _rrule, public;

-- Test COUNT boundary values
SELECT ok(
    (rrule('RRULE:FREQ=DAILY;COUNT=1')).count = 1,
    'COUNT=1 (minimum valid value) works'
);

SELECT ok(
    (rrule('RRULE:FREQ=DAILY;COUNT=999999')).count = 999999,
    'Large COUNT value works'
);

-- Test INTERVAL boundary values
SELECT ok(
    (rrule('RRULE:FREQ=DAILY;INTERVAL=1')).interval = 1,
    'INTERVAL=1 (minimum valid value) works'
);

SELECT ok(
    (rrule('RRULE:FREQ=DAILY;INTERVAL=100')).interval = 100,
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
        _rrule.rrule('RRULE:FREQ=DAILY;COUNT=1'),
        '1970-01-01T00:00:00'::timestamp
    )) = 1,
    'Unix epoch timestamp works as dtstart'
);

SELECT ok(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=DAILY;COUNT=1'),
        '2038-01-19T03:14:07'::timestamp
    )) = 1,
    'Near 32-bit time_t limit works'
);

SELECT ok(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=DAILY;COUNT=1'),
        '1900-01-01T00:00:00'::timestamp
    )) = 1,
    'Historical timestamp (1900) works'
);

SELECT ok(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=DAILY;COUNT=1'),
        '2100-12-31T23:59:59'::timestamp
    )) = 1,
    'Far future timestamp (2100) works'
);

-- Test leap year handling
SELECT ok(
    (SELECT occurrence::date FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=YEARLY;COUNT=1'),
        '2000-02-29T00:00:00'::timestamp
    ) AS occurrence LIMIT 1) = '2000-02-29'::date,
    'Leap year day (Feb 29) works'
);

-- Test time component edge cases
SELECT ok(
    (SELECT extract(hour from occurrence) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=DAILY;COUNT=1'),
        '2000-01-01T00:00:00'::timestamp
    ) AS occurrence) = 0,
    'Midnight (00:00:00) time works'
);

SELECT ok(
    (SELECT extract(hour from occurrence) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=DAILY;COUNT=1'),
        '2000-01-01T23:59:59'::timestamp
    ) AS occurrence) = 23,
    'End of day (23:59:59) time works'
);

-- Test BYMONTHDAY edge cases
SELECT ok(
    (rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=-1')).bymonthday = ARRAY[-1],
    'BYMONTHDAY=-1 (last day of month) works'
);

SELECT ok(
    (rrule('RRULE:FREQ=MONTHLY;BYMONTHDAY=31')).bymonthday = ARRAY[31],
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
    (_rrule.jsonb_to_rruleset(
        '{"dtstart": "1997-09-02T09:00:00", "dtend": "1997-09-02T09:00:00", "rrule": {"freq": "DAILY"}}'::jsonb
    )).dtstart IS NOT NULL,
    'DTEND equals DTSTART (zero duration) is valid'
);

-- Test very short UNTIL duration
SELECT ok(
    (SELECT count(*) FROM _rrule.occurrences(
        _rrule.rrule('RRULE:FREQ=DAILY;UNTIL=19970902T090001'),
        '1997-09-02T09:00:00'::timestamp
    )) = 1,
    'UNTIL just 1 second after DTSTART works'
);

SELECT * FROM finish();

ROLLBACK;
