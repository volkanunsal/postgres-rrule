DROP SCHEMA IF EXISTS _rrule CASCADE;

DROP CAST IF EXISTS (_rrule.RRULE AS TEXT);
DROP CAST IF EXISTS (TEXT AS _rrule.RRULE);

CREATE SCHEMA _rrule;

CREATE TYPE _rrule.FREQ AS ENUM (
  'YEARLY',
  'MONTHLY',
  'WEEKLY',
  'DAILY',
  'HOURLY',
  'MINUTELY',
  'SECONDLY'
);


CREATE TYPE _rrule.DAY AS ENUM (
  'MO',
  'TU',
  'WE',
  'TH',
  'FR',
  'SA',
  'SU'
);


CREATE TABLE _rrule.RRULE (
  "freq" _rrule.FREQ NOT NULL,
  "interval" INTEGER DEFAULT 1 NOT NULL CHECK(0 < "interval"),
  "count" INTEGER,
  "until" TIMESTAMP,
  "bysecond" INTEGER[] CHECK (0 <= ALL("bysecond") AND 60 > ALL("bysecond")),
  "byminute" INTEGER[] CHECK (0 <= ALL("byminute") AND 60 > ALL("byminute")),
  "byhour" INTEGER[] CHECK (0 <= ALL("byhour") AND 24 > ALL("byhour")),
  "byday" _rrule.DAY[],
  "bymonthday" INTEGER[] CHECK (31 >= ALL("bymonthday") AND 0 <> ALL("bymonthday") AND -31 <= ALL("bymonthday")),
  "byyearday" INTEGER[] CHECK (366 >= ALL("byyearday") AND 0 <> ALL("byyearday") AND -366 <= ALL("byyearday")),
  "byweekno" INTEGER[] CHECK (53 >= ALL("byweekno") AND 0 <> ALL("byweekno") AND -53 <= ALL("byweekno")),
  "bymonth" INTEGER[] CHECK (0 < ALL("bymonth") AND 12 >= ALL("bymonth")),
  "bysetpos" INTEGER[] CHECK(366 >= ALL("bysetpos") AND 0 <> ALL("bysetpos") AND -366 <= ALL("bysetpos")),
  "wkst" _rrule.DAY,

  -- Why?
  CONSTRAINT freq_yearly_if_byweekno CHECK("freq" = 'YEARLY' OR "byweekno" IS NULL)
);


CREATE TABLE _rrule.rruleset (
  "dtstart" TIMESTAMP NOT NULL,
  "rrule" _rrule.RRULE[],
  "exrule" _rrule.RRULE[],
  "rdate" TIMESTAMP[],
  "exdate" TIMESTAMP[]
);


CREATE TYPE _rrule.exploded_interval AS (
  "months" INTEGER,
  "days" INTEGER,
  "seconds" INTEGER
);

CREATE OR REPLACE FUNCTION _rrule.explode_interval(INTERVAL)
RETURNS _rrule.EXPLODED_INTERVAL AS $$
  SELECT
    (
      EXTRACT(YEAR FROM $1) * 12 + EXTRACT(MONTH FROM $1),
      EXTRACT(DAY FROM $1),
      EXTRACT(HOUR FROM $1) * 3600 + EXTRACT(MINUTE FROM $1) * 60 + EXTRACT(SECOND FROM $1)
    )::_rrule.EXPLODED_INTERVAL;

$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE OR REPLACE FUNCTION _rrule.factor(INTEGER, INTEGER)
RETURNS INTEGER AS $$
  SELECT
    CASE
      WHEN ($1 = 0 AND $2 = 0) THEN NULL
      WHEN ($1 = 0 OR $2 = 0) THEN 0
      WHEN ($1 % $2 <> 0) THEN 0
      ELSE $1 / $2
    END;

$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE OR REPLACE FUNCTION _rrule.interval_contains(INTERVAL, INTERVAL)
RETURNS BOOLEAN AS $$
  -- Any fields that have 0 must have zero in each.

  WITH factors AS (
    SELECT
      _rrule.factor(a.months, b.months) AS months,
      _rrule.factor(a.days, b.days) AS days,
      _rrule.factor(a.seconds, b.seconds) AS seconds
    FROM _rrule.explode_interval($2) a, _rrule.explode_interval($1) b
  )
  SELECT
    COALESCE(months <> 0, TRUE)
      AND
    COALESCE(days <> 0, TRUE)
      AND
    COALESCE(seconds <> 0, TRUE)
      AND
    COALESCE(months = days, TRUE)
      AND
    COALESCE(months = seconds, TRUE)
  FROM factors;

$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION _rrule.enum_index_of(anyenum)
RETURNS INTEGER AS $$
    SELECT row_number FROM (
        SELECT (row_number() OVER ())::INTEGER, "value"
        FROM unnest(enum_range($1)) "value"
    ) x
    WHERE "value" = $1;
$$ LANGUAGE SQL IMMUTABLE STRICT;
COMMENT ON FUNCTION _rrule.enum_index_of(anyenum) IS 'Given an ENUM value, return it''s index.';

CREATE OR REPLACE FUNCTION _rrule.integer_array (TEXT)
RETURNS integer[] AS $$
  SELECT ('{' || $1 || '}')::integer[];
$$ LANGUAGE SQL IMMUTABLE STRICT;
COMMENT ON FUNCTION _rrule.integer_array (text) IS 'Coerce a text string into an array of integers';



CREATE OR REPLACE FUNCTION _rrule.day_array (TEXT)
RETURNS _rrule.DAY[] AS $$
  SELECT ('{' || $1 || '}')::_rrule.DAY[];
$$ LANGUAGE SQL IMMUTABLE STRICT;
COMMENT ON FUNCTION _rrule.day_array (text) IS 'Coerce a text string into an array of "rrule"."day"';



CREATE OR REPLACE FUNCTION _rrule.array_join(ANYARRAY, "delimiter" TEXT)
RETURNS TEXT AS $$
  SELECT string_agg(x::text, "delimiter")
  FROM unnest($1) x;
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION _rrule.explode(_rrule.RRULE)
RETURNS SETOF _rrule.RRULE AS 'SELECT $1' LANGUAGE SQL IMMUTABLE STRICT;
COMMENT ON FUNCTION _rrule.explode (_rrule.RRULE) IS 'Helper function to allow SELECT * FROM explode(rrule)';

CREATE OR REPLACE FUNCTION _rrule.compare_equal(_rrule.RRULE, _rrule.RRULE)
RETURNS BOOLEAN AS $$
  SELECT count(*) = 1 FROM (
    SELECT * FROM _rrule.explode($1) UNION SELECT * FROM _rrule.explode($2)
  ) AS x;
$$ LANGUAGE SQL IMMUTABLE STRICT;



CREATE OR REPLACE FUNCTION _rrule.compare_not_equal(_rrule.RRULE, _rrule.RRULE)
RETURNS BOOLEAN AS $$
  SELECT count(*) = 2 FROM (
    SELECT * FROM _rrule.explode($1) UNION SELECT * FROM _rrule.explode($2)
  ) AS x;
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION _rrule.build_interval("interval" INTEGER, "freq" _rrule.FREQ)
RETURNS INTERVAL AS $$
  -- Transform ical time interval enums into Postgres intervals, e.g.
  -- "WEEKLY" becomes "WEEKS".
  SELECT ("interval" || ' ' || regexp_replace(regexp_replace("freq"::TEXT, 'LY', 'S'), 'IS', 'YS'))::INTERVAL;
$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE OR REPLACE FUNCTION _rrule.build_interval(_rrule.RRULE)
RETURNS INTERVAL AS $$
  SELECT _rrule.build_interval($1."interval", $1."freq");
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- rrule containment.
-- intervals must be compatible.
-- wkst must match
-- all other fields must have $2's value(s) in $1.
CREATE OR REPLACE FUNCTION _rrule.contains(_rrule.RRULE, _rrule.RRULE)
RETURNS BOOLEAN AS $$
  SELECT _rrule.interval_contains(
    _rrule.build_interval($1),
    _rrule.build_interval($2)
  ) AND $1."wkst" = $2."wkst";
$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE OR REPLACE FUNCTION _rrule.contained_by(_rrule.RRULE, _rrule.RRULE)
RETURNS BOOLEAN AS $$
  SELECT _rrule.contains($2, $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE OR REPLACE FUNCTION _rrule.until("rrule" _rrule.RRULE, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$

  SELECT min("until")
  FROM (
    SELECT "rrule"."until"
    UNION
    SELECT "dtstart" + _rrule.build_interval("rrule"."interval", "rrule"."freq") * "rrule"."count" AS "until"
  ) "until" GROUP BY ();

$$ LANGUAGE SQL IMMUTABLE STRICT;
COMMENT ON FUNCTION _rrule.until(_rrule.RRULE, TIMESTAMP) IS 'The calculated "until"" timestamp for the given rrule+dtstart';

-- STARTS
--
-- Given a start time, returns a set of all possible start values for a recurrence rule.
-- For example, a YEARLY rule that repeats on first and third month have 2 start values.

-- TODO: If we have a bymonthday, but no bymonth, we need to expand to all months.
-- TODO: If we have a byday, we need to expand to all days of the weeks.


CREATE OR REPLACE FUNCTION _rrule.all_starts(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
BEGIN
  RETURN QUERY WITH
  "year" as (SELECT EXTRACT(YEAR FROM "dtstart")::integer AS "year"),
  A10 as (
    SELECT
      make_timestamp(
        "year"."year",
        COALESCE("bymonth", EXTRACT(MONTH FROM "dtstart")::integer),
        COALESCE("bymonthday", EXTRACT(DAY FROM "dtstart")::integer),
        COALESCE("byhour", EXTRACT(HOUR FROM "dtstart")::integer),
        COALESCE("byminute", EXTRACT(MINUTE FROM "dtstart")::integer),
        COALESCE("bysecond", EXTRACT(SECOND FROM "dtstart"))
      ) as "ts"
    FROM "year"
    LEFT OUTER JOIN unnest(("rrule")."bymonth") AS "bymonth" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."bymonthday") as "bymonthday" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."byhour") AS "byhour" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."byminute") AS "byminute" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."bysecond") AS "bysecond" ON (true)
  )
  SELECT "ts" FROM A10;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

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
AND ("freq" IN ('YEARLY', 'HOURLY', 'MINUTELY', 'SECONDLY') OR "byyearday" IS NULL)
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

CREATE OR REPLACE FUNCTION _rrule.text(_rrule.RRULE)
RETURNS TEXT AS $$
  SELECT regexp_replace(
    'RRULE:'
    || COALESCE('FREQ=' || $1."freq" || ';', '')
    || CASE WHEN $1."interval" = 1 THEN '' ELSE COALESCE('INTERVAL=' || $1."interval" || ';', '') END
    || COALESCE('COUNT=' || $1."count" || ';', '')
    || COALESCE('UNTIL=' || $1."until" || ';', '')
    || COALESCE('BYSECOND=' || _rrule.array_join($1."bysecond", ',') || ';', '')
    || COALESCE('BYMINUTE=' || _rrule.array_join($1."byminute", ',') || ';', '')
    || COALESCE('BYHOUR=' || _rrule.array_join($1."byhour", ',') || ';', '')
    || COALESCE('BYDAY=' || _rrule.array_join($1."byday", ',') || ';', '')
    || COALESCE('BYMONTHDAY=' || _rrule.array_join($1."bymonthday", ',') || ';', '')
    || COALESCE('BYYEARDAY=' || _rrule.array_join($1."byyearday", ',') || ';', '')
    || COALESCE('BYWEEKNO=' || _rrule.array_join($1."byweekno", ',') || ';', '')
    || COALESCE('BYMONTH=' || _rrule.array_join($1."bymonth", ',') || ';', '')
    || COALESCE('BYSETPOS=' || _rrule.array_join($1."bysetpos", ',') || ';', '')
    || CASE WHEN $1."wkst" = 'MO' THEN '' ELSE COALESCE('WKST=' || $1."wkst" || ';', '') END
  , ';$', '');
$$ LANGUAGE SQL IMMUTABLE STRICT;
-- All of the function(rrule, ...) forms also accept a text argument, which will
-- be parsed using the RFC-compliant parser.

CREATE OR REPLACE FUNCTION _rrule.is_finite("rrule" _rrule.RRULE)
RETURNS BOOLEAN AS $$
  SELECT "rrule"."count" IS NOT NULL OR "rrule"."until" IS NOT NULL;
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.is_finite("rrule" TEXT)
RETURNS BOOLEAN AS $$
  SELECT _rrule.is_finite(_rrule.rrule("rrule"));
$$ LANGUAGE SQL STRICT IMMUTABLE;



CREATE OR REPLACE FUNCTION _rrule.is_finite("rruleset" _rrule.RRULESET)
RETURNS BOOLEAN AS $$
  -- All non-finite rrule objects have a counterpart in exrules that
  -- matches interval/frequency (or is a multiple of same).
  WITH non_finite AS (
    SELECT "rrule"
    FROM unnest("rruleset"."rrule") "rrule"
    WHERE NOT _rrule.is_finite("rrule")
  )
  SELECT FALSE;
$$ LANGUAGE SQL STRICT IMMUTABLE;



CREATE OR REPLACE FUNCTION _rrule.occurrences(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
)
RETURNS SETOF TIMESTAMP AS $$
  WITH "starts" AS (
    SELECT "start"
    FROM _rrule.all_starts($1, $2) "start"
  ),
  "params" AS (
    SELECT
      "until",
      "interval"
    FROM _rrule.until($1, $2) "until"
    FULL OUTER JOIN _rrule.build_interval($1) "interval" ON (true)
  ),
  "generated" AS (
    SELECT generate_series("start", COALESCE("until"), "interval") "occurrence"
    FROM "params" FULL OUTER JOIN "starts" ON (true)
  ),
  "ordered" AS (
    SELECT "occurrence"
    FROM "generated"
    WHERE "occurrence" >= "dtstart"
    ORDER BY "occurrence"
  ),
  "tagged" AS (
    SELECT
      row_number() OVER (),
      "occurrence"
    FROM "ordered"
  )
  SELECT "occurrence"
  FROM "tagged"
  WHERE "row_number" <= ("rrule")."count"
  OR ("rrule")."count" IS NULL
  ORDER BY "occurrence";
$$ LANGUAGE SQL STRICT IMMUTABLE;


CREATE OR REPLACE FUNCTION _rrule.occurrences("rrule" _rrule.RRULE, "dtstart" TIMESTAMP, "between" TSRANGE)
RETURNS SETOF TIMESTAMP AS $$
  SELECT "occurrence"
  FROM _rrule.occurrences("rrule", "dtstart") "occurrence"
  WHERE "occurrence" <@ "between";
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.occurrences("rrule" TEXT, "dtstart" TIMESTAMP, "between" TSRANGE)
RETURNS SETOF TIMESTAMP AS $$
  SELECT "occurrence"
  FROM _rrule.occurrences(_rrule.rrule("rrule"), "dtstart") "occurrence"
  WHERE "occurrence" <@ "between";
$$ LANGUAGE SQL STRICT IMMUTABLE;



CREATE OR REPLACE FUNCTION _rrule.occurrences(
  "rruleset" _rrule.RRULESET,
  "tsrange" TSRANGE
)
RETURNS SETOF TIMESTAMP AS $$

  WITH "rrules" AS (
    SELECT "rruleset"."dtstart", unnest("rruleset"."rrule") AS "rrule"
  ),
  "rdates" AS (
    SELECT _rrule.occurrences("rrule", "dtstart", "tsrange") AS "occurrence" FROM "rrules"
    UNION
    SELECT unnest("rruleset"."rdate") AS "occurrence"
  ),
  "exrules" AS (
    SELECT "rruleset"."dtstart", unnest("rruleset"."exrule") AS "exrule"
  ),
  "exdates" AS (
    SELECT _rrule.occurrences("exrule", "dtstart", "tsrange") AS "occurrence" FROM "exrules"
    UNION
    SELECT unnest("rruleset"."exdate") AS "occurrence"
  )

  SELECT "occurrence" FROM "rdates"
  EXCEPT
  SELECT "occurrence" FROM "exdates";

$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.occurrences("rruleset" _rrule.RRULESET)
RETURNS SETOF TIMESTAMP AS $$
  SELECT _rrule.occurrences("rruleset", '(,)'::TSRANGE);
$$ LANGUAGE SQL STRICT IMMUTABLE;








CREATE OR REPLACE FUNCTION _rrule.first("rrule" _rrule.RRULE, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$

  SELECT "ts"
  FROM _rrule.all_starts("rrule", "dtstart") "ts"
  ORDER BY "ts"
  LIMIT 1;

$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.first("rrule" TEXT, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$
  SELECT _rrule.first(_rrule.rrule("rrule"), "dtstart");
$$ LANGUAGE SQL STRICT IMMUTABLE;


-- HACK: support multiple rules.
CREATE OR REPLACE FUNCTION _rrule.first("rruleset" _rrule.RRULE)
RETURNS TIMESTAMP AS $$
  SELECT now()::TIMESTAMP;
$$ LANGUAGE SQL STRICT IMMUTABLE;



CREATE OR REPLACE FUNCTION _rrule.last("rrule" _rrule.RRULE, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$
  SELECT occurrence
  FROM _rrule.occurrences("rrule", "dtstart") occurrence
  ORDER BY occurrence DESC LIMIT 1;
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.last("rrule" TEXT, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$
  SELECT _rrule.last(_rrule.rrule("rrule"), "dtstart");
$$ LANGUAGE SQL STRICT IMMUTABLE;



CREATE OR REPLACE FUNCTION _rrule.last("rruleset" _rrule.RRULESET)
RETURNS TIMESTAMP AS $$
  SELECT occurrence
  FROM _rrule.occurrences("rruleset") occurrence
  ORDER BY occurrence DESC LIMIT 1;
$$ LANGUAGE SQL STRICT IMMUTABLE;


CREATE OR REPLACE FUNCTION _rrule.before(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP,
  "when" TIMESTAMP
)
RETURNS SETOF TIMESTAMP AS $$
  SELECT *
  FROM _rrule.occurrences("rrule", "dtstart", tsrange(NULL, "when", '[]'));
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.before("rrule" TEXT, "dtstart" TIMESTAMP, "when" TIMESTAMP)
RETURNS SETOF TIMESTAMP AS $$
  SELECT _rrule.before(_rrule.rrule("rrule"), "dtstart", "when");
$$ LANGUAGE SQL STRICT IMMUTABLE;



CREATE OR REPLACE FUNCTION _rrule.before("rruleset" _rrule.RRULESET, "when" TIMESTAMP)
RETURNS SETOF TIMESTAMP AS $$
  SELECT *
  FROM _rrule.occurrences("rruleset", tsrange(NULL, "when", '[]'));
$$ LANGUAGE SQL STRICT IMMUTABLE;


CREATE OR REPLACE FUNCTION _rrule.after(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP,
  "when" TIMESTAMP
)
RETURNS SETOF TIMESTAMP AS $$
  SELECT *
  FROM _rrule.occurrences("rrule", "dtstart", tsrange("when", NULL));
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.after(
  "rrule" TEXT,
  "dtstart" TIMESTAMP,
  "when" TIMESTAMP
)
RETURNS SETOF TIMESTAMP AS $$
  SELECT _rrule.after(_rrule.rrule("rrule"), "dtstart", "when");
$$ LANGUAGE SQL STRICT IMMUTABLE;



CREATE OR REPLACE FUNCTION _rrule.after("rruleset" _rrule.RRULESET, "when" TIMESTAMP)
RETURNS SETOF TIMESTAMP AS $$
  SELECT *
  FROM _rrule.occurrences("rruleset", tsrange("when", NULL));
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OPERATOR = (
  LEFTARG = _rrule.RRULE,
  RIGHTARG = _rrule.RRULE,
  PROCEDURE = _rrule.compare_equal,
  NEGATOR = <>,
  COMMUTATOR = =
);

CREATE OPERATOR <> (
  LEFTARG = _rrule.RRULE,
  RIGHTARG = _rrule.RRULE,
  PROCEDURE = _rrule.compare_not_equal,
  NEGATOR = =,
  COMMUTATOR = <>
);

CREATE OPERATOR @> (
  LEFTARG = _rrule.RRULE,
  RIGHTARG = _rrule.RRULE,
  PROCEDURE = _rrule.contains,
  COMMUTATOR = <@
);

CREATE OPERATOR <@ (
  LEFTARG = _rrule.RRULE,
  RIGHTARG = _rrule.RRULE,
  PROCEDURE = _rrule.contained_by,
  COMMUTATOR = @>
);

CREATE CAST (TEXT AS _rrule.RRULE)
  WITH FUNCTION _rrule.rrule(TEXT)
  AS IMPLICIT;
