DROP SCHEMA IF EXISTS "rrule" CASCADE;


CREATE OR REPLACE FUNCTION enum_index_of(anyenum)
RETURNS INTEGER AS $$

    SELECT row_number FROM (
        SELECT (row_number() OVER ())::INTEGER, "value"
        FROM unnest(enum_range($1)) "value"
    ) x
    WHERE "value" = $1;

$$ LANGUAGE SQL IMMUTABLE STRICT;

COMMENT ON FUNCTION enum_index_of(anyenum) IS 'Given an ENUM value, return it''s index.';


CREATE SCHEMA "rrule";



CREATE TYPE "rrule"."freq" AS ENUM (
  'YEARLY', 'MONTHLY', 'WEEKLY', 'DAILY', 'HOURLY', 'MINUTELY', 'SECONDLY'
);



CREATE TYPE "rrule"."day" AS ENUM (
  'MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'
);



-- We need to be able to have complicated check constraints, which cannot happen
-- on a COMPOSITE TYPE, so we need to use a TABLE TYPE instead.
CREATE TABLE "rrule"."rrule" (
  "freq" "rrule"."freq" NOT NULL,
  "interval" INTEGER DEFAULT 1 NOT NULL,
  "count" INTEGER,
  "until" TIMESTAMP,
  "bysecond" INTEGER[] CHECK (0 <= ALL("bysecond") AND 60 > ALL("bysecond")),
  "byminute" INTEGER[] CHECK (0 <= ALL("byminute") AND 60 > ALL("byminute")),
  "byhour" INTEGER[] CHECK (0 <= ALL("byhour") AND 24 > ALL("byhour")),
  "byday" "rrule"."day"[],
  "bymonthday" INTEGER[] CHECK (31 >= ALL("bymonthday") AND 0 <> ALL("bymonthday") AND -31 <= ALL("bymonthday")),
  "byyearday" INTEGER[] CHECK (366 >= ALL("byyearday") AND 0 <> ALL("byyearday") AND -366 <= ALL("byyearday")),
  "byweekno" INTEGER[] CHECK (53 >= ALL("byweekno") AND 0 <> ALL("byweekno") AND -53 <= ALL("byweekno")),
  "bymonth" INTEGER[] CHECK (0 < ALL("bymonth") AND 12 >= ALL("bymonth")),
  "bysetpos" INTEGER[] CHECK(366 >= ALL("bysetpos") AND 0 <> ALL("bysetpos") AND -366 <= ALL("bysetpos")),
  "wkst" "rrule"."day",

  CONSTRAINT freq_yearly_if_byweekno CHECK("freq" = 'YEARLY' OR "byweekno" IS NULL)
);



CREATE OR REPLACE FUNCTION "rrule"."integer_array" (text)
RETURNS integer[] AS $$

  SELECT ('{' || $1 || '}')::integer[];

$$ LANGUAGE SQL IMMUTABLE STRICT;

COMMENT ON FUNCTION "rrule"."integer_array" (text) IS 'Coerce a text string into an array of integers';



CREATE OR REPLACE FUNCTION "rrule"."day_array" (text)
RETURNS "rrule"."day"[] AS $$

  SELECT ('{' || $1 || '}')::"rrule"."day"[];

$$ LANGUAGE SQL IMMUTABLE STRICT;

COMMENT ON FUNCTION "rrule"."integer_array" (text) IS 'Coerce a text string into an array of "rrule"."day"';


CREATE FUNCTION "rrule"."ends" ("rrule"."rrule")
RETURNS BOOLEAN AS $$

  SELECT $1."count" IS NOT NULL OR $1."until" IS NOT NULL;

$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE OR REPLACE FUNCTION "rrule"."parse_rrule" (text)
RETURNS "rrule"."rrule" AS $$

WITH "split_into_tokens" AS (
    SELECT
        "y"[1] AS "key",
        "y"[2] AS "val"
    FROM (
        SELECT regexp_split_to_array("r", '=') AS "y"
        FROM regexp_split_to_table(
            regexp_replace($1, '^RRULE:', ''),
            ';'
        ) "r"
    ) "x"
),
candidate_rrule AS (
    SELECT
        (SELECT "val"::"rrule"."freq" FROM "split_into_tokens" WHERE "key" = 'FREQ') AS "freq",
        (SELECT "val"::integer FROM "split_into_tokens" WHERE "key" = 'INTERVAL') AS "interval",
        (SELECT "val"::integer FROM "split_into_tokens" WHERE "key" = 'COUNT') AS "count",
        (SELECT "val"::timestamp FROM "split_into_tokens" WHERE "key" = 'UNTIL') AS "until",
        (SELECT "rrule"."integer_array"("val") FROM "split_into_tokens" WHERE "key" = 'BYSECOND') AS "bysecond",
        (SELECT "rrule"."integer_array"("val") FROM "split_into_tokens" WHERE "key" = 'BYMINUTE') AS "byminute",
        (SELECT "rrule"."integer_array"("val") FROM "split_into_tokens" WHERE "key" = 'BYHOUR') AS "byhour",
        (SELECT "rrule"."day_array"("val") FROM "split_into_tokens" WHERE "key" = 'BYDAY') AS "byday",
        (SELECT "rrule"."integer_array"("val") FROM "split_into_tokens" WHERE "key" = 'BYMONTHDAY') AS "bymonthday",
        (SELECT "rrule"."integer_array"("val") FROM "split_into_tokens" WHERE "key" = 'BYYEARDAY') AS "byyearday",
        (SELECT "rrule"."integer_array"("val") FROM "split_into_tokens" WHERE "key" = 'BYWEEKNO') AS "byweekno",
        (SELECT "rrule"."integer_array"("val") FROM "split_into_tokens" WHERE "key" = 'BYMONTH') AS "bymonth",
        (SELECT "rrule"."integer_array"("val") FROM "split_into_tokens" WHERE "key" = 'BYSETPOS') AS "bysetpos",
        (SELECT "val"::"rrule"."day" FROM "split_into_tokens" WHERE "key" = 'WKST') AS "wkst"
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
AND ("freq" IN ('YEARLY', 'HOURLY', 'MINUTELY', 'SECONDLY') OR "byyearday" IS NULL)
-- FREQ=WEEKLY is invalid when BYMONTHDAY is set
AND ("freq" <> 'WEEKLY' OR "bymonthday" IS NULL)
-- BY<something-else> is required if BYSETPOS is set.
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
);

$$ LANGUAGE SQL IMMUTABLE STRICT;



CREATE TABLE "rrule"."rruleset" (
  "rruleset_id" SERIAL PRIMARY KEY,
  "dtstart" TIMESTAMP NOT NULL,
  "rrule" "rrule"."rrule"[],
  "exrule" "rrule"."rrule"[],
  "rdate" TIMESTAMP[],
  "exdate" TIMESTAMP[]
);


CREATE FUNCTION "rrule"."until" (
  "rrule" "rrule"."rrule",
  "dtstart" TIMESTAMP
) RETURNS TIMESTAMP AS $$

  WITH "expanded" AS (
    SELECT
      (("rrule")."interval" || ' ' || regexp_replace(regexp_replace(("rrule")."freq"::text, 'LY', 'S'), 'IS', 'YS'))::interval,
      ("rrule")."count",
      ("rrule")."until"
  )
  SELECT COALESCE(
    "until",
    "dtstart" + "interval" * "count"
  ) FROM "expanded";

$$ LANGUAGE SQL IMMUTABLE STRICT;

-- occurrences_between(rrule(set), dtstart, start, finish)
-- All occurrences of the rrule(set)+dtstart, between the start and finish.
-- This function is always guaranteed to return a finite number of occurrences.

CREATE FUNCTION "rrule"."occurrences_between" (
    "rrule" "rrule"."rrule",
    "dtstart" timestamp,
    "start" timestamp,
    "finish" timestamp
)
RETURNS SETOF TIMESTAMP AS $$

WITH "expanded" AS (
    SELECT
    (("rrule")."interval" || ' ' || regexp_replace(regexp_replace(("rrule")."freq"::text, 'LY', 'S'), 'IS', 'YS'))::interval,
    ("rrule")."count",
    ("rrule")."until"
),
"rrule_until" AS (
  SELECT
    "interval",
    "count",
    COALESCE("until", "dtstart" + "interval" * "count", "finish") AS "until"
  FROM "expanded"
  WHERE "dtstart" <= "finish"
),
"all_dtstarts" AS (
    SELECT
        make_timestamp(
            EXTRACT(YEAR FROM "dtstart")::integer,
            COALESCE("split"."bymonth", EXTRACT(MONTH FROM "dtstart")::integer),
            COALESCE("split"."bymonthday", EXTRACT(DAY FROM "dtstart")::integer),
            COALESCE("split"."byhour", EXTRACT(HOUR FROM "dtstart")::integer),
            COALESCE("split"."byminute", EXTRACT(MINUTE FROM "dtstart")::integer),
            COALESCE("split"."bysecond", EXTRACT(SECOND FROM "dtstart"))
        ) AS "this_start"
    FROM unnest(
        ("rrule")."bymonth",
        ("rrule")."bymonthday",
        ("rrule")."byhour",
        ("rrule")."byminute",
        ("rrule")."bysecond"
    ) AS "split" (
        "bymonth",
        "bymonthday",
        "byhour",
        "byminute",
        "bysecond"
    )
),
"generated" AS (
    SELECT
        "count",
        generate_series(COALESCE("this_start", "dtstart"), "until", "interval") AS "ts"
    FROM "rrule_until" FULL OUTER JOIN "all_dtstarts" ON (true)
),
"ordered" AS (
    SELECT
        "count",
        "ts"
    FROM "generated"
    WHERE "ts" >= "dtstart"
    ORDER BY "ts"
),
"tagged" AS (
    SELECT
        row_number() OVER (),
        "count",
        "ts"
    FROM "ordered"
)

SELECT "ts"
FROM "tagged"
WHERE "row_number" <= "count" OR "count" IS NULL
ORDER BY "ts";

$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE FUNCTION "rrule"."occurrences_between" (TEXT, TIMESTAMP, TIMESTAMP, TIMESTAMP)
RETURNS SETOF TIMESTAMP AS '
SELECT "rrule"."occurrences_between"("rrule"."parse_rrule"($1), $2, $3, $4);
' LANGUAGE SQL IMMUTABLE STRICT;


CREATE FUNCTION "rrule"."occurrences_between" (
    "rruleset" "rrule"."rruleset",
    "start" timestamp,
    "finish" timestamp
)
RETURNS SETOF timestamp AS $$

WITH "rrules" AS (
  SELECT "rruleset"."dtstart", unnest("rruleset"."rrule") AS "rrule"
), "rdates" AS (
  SELECT
    "rrule"."occurrences_between"("rrule", "dtstart", "start", "finish") AS "occurrence"
  FROM "rrules"

  UNION

  SELECT unnest("rruleset"."rdate") AS "occurrence"
),
"exrules" AS (
  SELECT "rruleset"."dtstart", unnest("rruleset"."exrule") AS "exrule"
),
"exdates" AS (
  SELECT "rrule"."occurrences_between"("exrule", "dtstart", "start", "finish") AS "occurrence"
  FROM "exrules"

  UNION

  SELECT unnest("rruleset"."exdate") AS "occurence"
)

SELECT "occurrence" FROM "rdates"

EXCEPT

SELECT "occurrence" FROM "exdates";

$$ LANGUAGE SQL IMMUTABLE STRICT;



CREATE FUNCTION "rrule"."first_occurrence" (
  "rrule" "rrule"."rrule",
  "dtstart" TIMESTAMP
) RETURNS TIMESTAMP AS $$
  SELECT *
  FROM "rrule"."occurrences_between"($1, $2, $2, $2 + INTERVAL '1 second')
  LIMIT 1;
$$ LANGUAGE SQL IMMUTABLE STRICT;


-- occurrences_before(rrule[set], dtstart, finish)

CREATE FUNCTION "rrule"."occurrences_before" (
  "rrule" "rrule"."rrule",
  "dtstart" timestamp,
  "finish" timestamp
) RETURNS SETOF TIMESTAMP AS $$
  SELECT "rrule"."occurrences_between"($1, $2, $2, $3);
$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE FUNCTION "rrule"."occurrences_before" (TEXT, TIMESTAMP, TIMESTAMP)
RETURNS SETOF TIMESTAMP AS $$
  SELECT "rrule"."occurrences_before"("rrule"."parse_rrule"($1), $2, $3)
$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE FUNCTION "rrule"."occurrences_before" ("rrule"."rruleset", TIMESTAMP)
RETURNS SETOF TIMESTAMP AS $$
  SELECT "rrule"."occurrences_between"($1, $1."dtstart", $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE FUNCTION "rrule"."occurrences_after" (
  "rrule" "rrule"."rrule",
  "dtstart" TIMESTAMP,
  "start" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
  -- Can only execute if we know we will return.
  SELECT *
  FROM "rrule"."occurrences_between"(
    "rrule",
    "dtstart",
    "start",
    "rrule"."until"("rrule", "dtstart")
  );

$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE FUNCTION "rrule"."occurences_after" (TEXT, TIMESTAMP, TIMESTAMP)
RETURNS SETOF TIMESTAMP AS $$
  SELECT * FROM "rrule"."occurrences_after"(
    "rrule"."parse_rrule"($1), $2, $3
  );
$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE FUNCTION "rrule"."last_occurrence" (
  "rrule" "rrule"."rrule",
  "dtstart" TIMESTAMP
) RETURNS TIMESTAMP AS $$

  SELECT * FROM "rrule"."occurrences_before"($1, $2, "rrule"."until"($1, $2)) "ts"
  ORDER BY "ts" DESC LIMIT 1;

$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE FUNCTION "rrule"."occurrences" ("rrule"."rrule", TIMESTAMP)
RETURNS SETOF TIMESTAMP AS $$
  SELECT * FROM "rrule"."occurrences_after"($1, $2, $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE FUNCTION "rrule"."occurrences" (TEXT, TIMESTAMP)
RETURNS SETOF TIMESTAMP AS $$
  SELECT * FROM "rrule"."occurrences_after"("rrule"."parse_rrule"($1), $2, $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;