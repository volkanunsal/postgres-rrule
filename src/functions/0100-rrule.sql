CREATE OR REPLACE FUNCTION _rrule.rrule (TEXT)
RETURNS _rrule.RRULE AS $$

WITH "split_into_tokens" AS (
    SELECT
        "y"[1] AS "key",
        "y"[2] AS "val"
    FROM (
        SELECT regexp_split_to_array("r", '=') AS "y"
        FROM regexp_split_to_table(
            regexp_replace($1::text, '^RRULE:', ''),
            ';'
        ) "r"
    ) "x"
),
candidate_rrule AS (
    SELECT
        (SELECT "val"::_rrule.FREQ FROM "split_into_tokens" WHERE "key" = 'FREQ') AS "freq",
        (SELECT "val"::INTEGER FROM "split_into_tokens" WHERE "key" = 'INTERVAL') AS "interval",
        (SELECT "val"::INTEGER FROM "split_into_tokens" WHERE "key" = 'COUNT') AS "count",
        (SELECT "val"::TIMESTAMP FROM "split_into_tokens" WHERE "key" = 'UNTIL') AS "until",
        (SELECT _rrule.integer_array("val") FROM "split_into_tokens" WHERE "key" = 'BYSECOND') AS "bysecond",
        (SELECT _rrule.integer_array("val") FROM "split_into_tokens" WHERE "key" = 'BYMINUTE') AS "byminute",
        (SELECT _rrule.integer_array("val") FROM "split_into_tokens" WHERE "key" = 'BYHOUR') AS "byhour",
        (SELECT _rrule.day_array("val") FROM "split_into_tokens" WHERE "key" = 'BYDAY') AS "byday",
        (SELECT _rrule.integer_array("val") FROM "split_into_tokens" WHERE "key" = 'BYMONTHDAY') AS "bymonthday",
        (SELECT _rrule.integer_array("val") FROM "split_into_tokens" WHERE "key" = 'BYYEARDAY') AS "byyearday",
        (SELECT _rrule.integer_array("val") FROM "split_into_tokens" WHERE "key" = 'BYWEEKNO') AS "byweekno",
        (SELECT _rrule.integer_array("val") FROM "split_into_tokens" WHERE "key" = 'BYMONTH') AS "bymonth",
        (SELECT _rrule.integer_array("val") FROM "split_into_tokens" WHERE "key" = 'BYSETPOS') AS "bysetpos",
        (SELECT "val"::_rrule.DAY FROM "split_into_tokens" WHERE "key" = 'WKST') AS "wkst"
)
SELECT
    "freq",
    -- Default value for INTERVAL
    COALESCE("interval", 1) AS "interval",
    "count",
    "until",
    "bysecond",
    "byminute",
    "byhour",
    "byday",
    "bymonthday",
    "byyearday",
    "byweekno",
    "bymonth",
    "bysetpos",
    -- DEFAULT value for wkst
    COALESCE("wkst", 'MO') AS "wkst"
FROM candidate_rrule
-- FREQ is required
WHERE "freq" IS NOT NULL
-- FREQ=YEARLY required if BYWEEKNO is provided
AND ("freq" = 'YEARLY' OR "byweekno" IS NULL)
-- Limits on FREQ if byyearday is selected
AND ("freq" IN ('YEARLY') OR "byyearday" IS NULL)
-- FREQ=WEEKLY is invalid when BYMONTHDAY is set
AND ("freq" <> 'WEEKLY' OR "bymonthday" IS NULL)
-- FREQ=DAILY is invalid when BYDAY is set
AND ("freq" <> 'DAILY' OR "byday" IS NULL)
-- BY[something-else] is required if BYSETPOS is set.
AND (
    "bysetpos" IS NULL OR (
        "bymonth" IS NOT NULL OR
        "byweekno" IS NOT NULL OR
        "byyearday" IS NOT NULL OR
        "bymonthday" IS NOT NULL OR
        "byday" IS NOT NULL OR
        "byhour" IS NOT NULL OR
        "byminute" IS NOT NULL OR
        "bysecond" IS NOT NULL
    )
)
-- Either UNTIL or COUNT may appear in a 'recur', but
-- UNTIL and COUNT MUST NOT occur in the same 'recur'.
AND ("count" IS NULL OR "until" IS NULL)
AND ("interval" IS NULL OR "interval" > 0);

$$ LANGUAGE SQL IMMUTABLE STRICT;

