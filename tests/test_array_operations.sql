BEGIN;

SELECT plan(15);

SET search_path TO _rrule, public;

-- Test rruleset_array_contains_timestamp (optimized with set-based operations)
SELECT is(
    _rrule.rruleset_array_contains_timestamp(
        ARRAY[
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": [{"freq": "DAILY", "count": 5}]}'::jsonb),
            _rrule.jsonb_to_rruleset('{"dtstart": "1998-01-01T09:00:00", "rrule": [{"freq": "WEEKLY", "count": 3}]}'::jsonb)
        ],
        '1997-09-03T09:00:00'::timestamp
    ),
    true,
    'Array contains timestamp that matches first rruleset'
);

SELECT is(
    _rrule.rruleset_array_contains_timestamp(
        ARRAY[
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": [{"freq": "DAILY", "count": 5}]}'::jsonb),
            _rrule.jsonb_to_rruleset('{"dtstart": "1998-01-01T09:00:00", "rrule": [{"freq": "WEEKLY", "count": 3}]}'::jsonb)
        ],
        '1998-01-08T09:00:00'::timestamp
    ),
    true,
    'Array contains timestamp that matches second rruleset'
);

SELECT is(
    _rrule.rruleset_array_contains_timestamp(
        ARRAY[
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": [{"freq": "DAILY", "count": 5}]}'::jsonb)
        ],
        '1997-10-01T09:00:00'::timestamp
    ),
    false,
    'Array does not contain timestamp outside all rulesets'
);

-- Test rruleset_array_has_after_timestamp (optimized with set-based operations)
SELECT is(
    _rrule.rruleset_array_has_after_timestamp(
        ARRAY[
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": [{"freq": "DAILY", "count": 10}]}'::jsonb)
        ],
        '1997-09-01T09:00:00'::timestamp
    ),
    true,
    'Array has occurrences after timestamp'
);

SELECT is(
    _rrule.rruleset_array_has_after_timestamp(
        ARRAY[
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": [{"freq": "DAILY", "count": 3}]}'::jsonb)
        ],
        '1997-09-10T09:00:00'::timestamp
    ),
    false,
    'Array has no occurrences after late timestamp'
);

-- Test rruleset_array_has_before_timestamp (optimized with set-based operations)
SELECT is(
    _rrule.rruleset_array_has_before_timestamp(
        ARRAY[
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": [{"freq": "DAILY", "count": 10}]}'::jsonb)
        ],
        '1997-09-10T09:00:00'::timestamp
    ),
    true,
    'Array has occurrences before timestamp'
);

SELECT is(
    _rrule.rruleset_array_has_before_timestamp(
        ARRAY[
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": [{"freq": "DAILY", "count": 3}]}'::jsonb)
        ],
        '1997-09-01T09:00:00'::timestamp
    ),
    false,
    'Array has no occurrences before early timestamp'
);

-- Test is_finite with array (optimized with set-based operations)
SELECT is(
    _rrule.is_finite(
        ARRAY[
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": [{"freq": "DAILY", "count": 10}]}'::jsonb),
            _rrule.jsonb_to_rruleset('{"dtstart": "1998-01-01T09:00:00", "rrule": [{"freq": "WEEKLY"}]}'::jsonb)
        ]
    ),
    true,
    'Array with one finite rruleset returns true'
);

SELECT is(
    _rrule.is_finite(
        ARRAY[
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": [{"freq": "DAILY"}]}'::jsonb),
            _rrule.jsonb_to_rruleset('{"dtstart": "1998-01-01T09:00:00", "rrule": [{"freq": "WEEKLY"}]}'::jsonb)
        ]
    ),
    false,
    'Array with all infinite rulesets returns false'
);

-- Test multiple rulesets in array
SELECT is(
    _rrule.rruleset_array_contains_timestamp(
        ARRAY[
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": [{"freq": "DAILY", "count": 2}]}'::jsonb),
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-05T09:00:00", "rrule": [{"freq": "DAILY", "count": 2}]}'::jsonb),
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-10T09:00:00", "rrule": [{"freq": "DAILY", "count": 2}]}'::jsonb)
        ],
        '1997-09-11T09:00:00'::timestamp
    ),
    true,
    'Large array with timestamp in third rruleset works'
);

-- Test empty array edge case
SELECT is(
    _rrule.is_finite('{}'::_rrule.RRULESET[]),
    false,
    'Empty rruleset array returns false for is_finite'
);

SELECT is(
    _rrule.rruleset_array_contains_timestamp(
        '{}'::_rrule.RRULESET[],
        '1997-09-02T09:00:00'::timestamp
    ),
    false,
    'Empty array does not contain any timestamp'
);

-- Test single element array
SELECT is(
    _rrule.is_finite(
        ARRAY[_rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": [{"freq": "DAILY", "count": 5}]}'::jsonb)]
    ),
    true,
    'Single element array with finite rruleset returns true'
);

-- Test jsonb_to_rruleset_array and rruleset_array_to_jsonb (optimized functions)
SELECT is(
    jsonb_array_length(
        _rrule.rruleset_array_to_jsonb(
            _rrule.jsonb_to_rruleset_array(
                '[{"dtstart": "1997-09-02T09:00:00", "rrule": [{"freq": "DAILY"}]}, {"dtstart": "1998-01-01T09:00:00", "rrule": [{"freq": "WEEKLY"}]}]'::jsonb
            )
        )
    ),
    2,
    'Round-trip conversion preserves array length'
);

-- Test array operations with mixed finite/infinite rulesets
SELECT is(
    _rrule.rruleset_array_has_after_timestamp(
        ARRAY[
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-02T09:00:00", "rrule": [{"freq": "DAILY", "count": 5}]}'::jsonb),
            _rrule.jsonb_to_rruleset('{"dtstart": "1997-09-10T09:00:00", "rrule": [{"freq": "DAILY", "count": 5}]}'::jsonb)
        ],
        '1997-09-03T09:00:00'::timestamp
    ),
    true,
    'Array with multiple finite rulesets has occurrences after timestamp'
);

SELECT * FROM finish();

ROLLBACK;
