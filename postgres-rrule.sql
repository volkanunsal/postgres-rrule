DROP SCHEMA IF EXISTS _rrule CASCADE;

DROP CAST IF EXISTS (_rrule.RRULE AS TEXT);
DROP CAST IF EXISTS (TEXT AS _rrule.RRULE);

CREATE SCHEMA _rrule;

CREATE TYPE _rrule.FREQ AS ENUM (
  'YEARLY',
  'MONTHLY',
  'WEEKLY',
  'DAILY'
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

  CONSTRAINT freq_yearly_if_byweekno CHECK("freq" = 'YEARLY' OR "byweekno" IS NULL)
);


CREATE TABLE _rrule.RRULESET (
  "dtstart" TIMESTAMP NOT NULL,
  "dtend" TIMESTAMP,
  "rrule" _rrule.RRULE,
  "exrule" _rrule.RRULE,
  "rdate" TIMESTAMP[],
  "exdate" TIMESTAMP[]
);


CREATE TYPE _rrule.exploded_interval AS (
  "months" INTEGER,
  "days" INTEGER,
  "seconds" INTEGER
);CREATE OR REPLACE FUNCTION _rrule.explode_interval(INTERVAL)
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

$$ LANGUAGE SQL IMMUTABLE STRICT;CREATE OR REPLACE FUNCTION _rrule.parse_line (input TEXT, marker TEXT)
RETURNS SETOF TEXT AS $$
  -- Clear spaces at the front of the lines
  WITH A4 as (SELECT regexp_replace(input, '^\s*',  '', 'ng') "r"),
  -- Clear all lines except the ones starting with marker
  A5 as (SELECT regexp_replace(A4."r", '^(?!' || marker || ').*?$',  '', 'ng') "r" FROM A4),
  -- Replace carriage returns with blank space.
  A10 as (SELECT regexp_replace(A5."r", E'[\\n\\r]+',  '', 'g') "r" FROM A5),
  -- Remove marker prefix.
  A15 as (SELECT regexp_replace(A10."r", marker || ':(.*)$', '\1') "r" FROM A10),
  -- Trim
  A17 as (SELECT trim(A15."r") "r" FROM A15),
  -- Split each key-value pair into a row in a table
  A20 as (SELECT regexp_split_to_table(A17."r", ';') "r" FROM A17)
  -- Split each key value pair into an array, e.g. {'FREQ', 'DAILY'}
  SELECT "r" AS "y"
  FROM A20
  WHERE "r" != '';
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _rrule.timestamp_to_day("ts" TIMESTAMP) RETURNS _rrule.DAY AS $$
  SELECT CAST(CASE to_char("ts", 'DY')
    WHEN 'MON' THEN 'MO'
    WHEN 'TUE' THEN 'TU'
    WHEN 'WED' THEN 'WE'
    WHEN 'THU' THEN 'TH'
    WHEN 'FRI' THEN 'FR'
    WHEN 'SAT' THEN 'SA'
    WHEN 'SUN' THEN 'SU'
  END as _rrule.DAY);
$$ LANGUAGE SQL IMMUTABLE;

CREATE CAST (TIMESTAMP AS _rrule.DAY)
  WITH FUNCTION _rrule.timestamp_to_day(TIMESTAMP)
  AS IMPLICIT;CREATE OR REPLACE FUNCTION _rrule.enum_index_of(anyenum)
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
  SELECT _rrule.build_interval(COALESCE($1."interval", 1), $1."freq");
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
  ) AND COALESCE($1."wkst" = $2."wkst", true);
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
    SELECT "dtstart" + _rrule.build_interval("rrule"."interval", "rrule"."freq") * COALESCE("rrule"."count", CASE WHEN "rrule"."until" IS NOT NULL THEN NULL ELSE 1 END) AS "until"
  ) "until" GROUP BY ();

$$ LANGUAGE SQL IMMUTABLE STRICT;
COMMENT ON FUNCTION _rrule.until(_rrule.RRULE, TIMESTAMP) IS 'The calculated "until"" timestamp for the given rrule+dtstart';

-- For example, a YEARLY rule that repeats on first and third month have 2 start values.

CREATE OR REPLACE FUNCTION _rrule.all_starts(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
DECLARE
  months int[];
  hour int := EXTRACT(HOUR FROM "dtstart")::integer;
  minute int := EXTRACT(MINUTE FROM "dtstart")::integer;
  second double precision := EXTRACT(SECOND FROM "dtstart");
  day int := EXTRACT(DAY FROM "dtstart")::integer;
  month int := EXTRACT(MONTH FROM "dtstart")::integer;
  year int := EXTRACT(YEAR FROM "dtstart")::integer;
  year_start timestamp := make_timestamp(year, 1, 1, hour, minute, second);
  year_end timestamp := make_timestamp(year, 12, 31, hour, minute, second);
  interv INTERVAL := _rrule.build_interval("rrule");
BEGIN
  RETURN QUERY WITH
  "year" as (SELECT EXTRACT(YEAR FROM "dtstart")::integer AS "year"),
  A10 as (
    SELECT
      make_timestamp(
        "year"."year",
        COALESCE("bymonth", month),
        COALESCE("bymonthday", day),
        COALESCE("byhour", hour),
        COALESCE("byminute", minute),
        COALESCE("bysecond", second)
      ) as "ts"
    FROM "year"
    LEFT OUTER JOIN unnest(("rrule")."bymonth") AS "bymonth" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."bymonthday") as "bymonthday" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."byhour") AS "byhour" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."byminute") AS "byminute" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."bysecond") AS "bysecond" ON (true)
  ),
  A11 as (
    SELECT DISTINCT "ts"
    FROM A10
    UNION
    SELECT "ts" FROM (
      SELECT "ts"
      FROM generate_series("dtstart", year_end, INTERVAL '1 day') "ts"
      WHERE (
        "ts"::_rrule.DAY = ANY("rrule"."byday")
      )
      AND "ts" <= ("dtstart" + INTERVAL '7 days')
    ) as "ts"
    UNION
    SELECT "ts" FROM (
      SELECT "ts"
      FROM generate_series("dtstart", year_end, INTERVAL '1 day') "ts"
      WHERE (
        EXTRACT(DAY FROM "ts") = ANY("rrule"."bymonthday")
      )
      AND "ts" <= ("dtstart" + INTERVAL '2 months')
    ) as "ts"
    UNION
    SELECT "ts" FROM (
      SELECT "ts"
      FROM generate_series("dtstart", "dtstart" + INTERVAL '1 year', INTERVAL '1 month') "ts"
      WHERE (
        EXTRACT(MONTH FROM "ts") = ANY("rrule"."bymonth")
      )
    ) as "ts"
  )
  SELECT DISTINCT "ts"
  FROM A11
  WHERE (
    "rrule"."byday" IS NULL OR "ts"::_rrule.DAY = ANY("rrule"."byday")
  )
  AND (
    "rrule"."bymonth" IS NULL OR EXTRACT(MONTH FROM "ts") = ANY("rrule"."bymonth")
  )
  AND (
    "rrule"."bymonthday" IS NULL OR EXTRACT(DAY FROM "ts") = ANY("rrule"."bymonthday")
  )
  ORDER BY "ts";

END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;
CREATE OR REPLACE FUNCTION _rrule.validate_rrule (result _rrule.RRULE)
RETURNS void AS $$
BEGIN
  -- FREQ is required
  IF result."freq" IS NULL THEN
    RAISE EXCEPTION 'FREQ cannot be null';
  END IF;

  -- FREQ=YEARLY required if BYWEEKNO is provided
  IF result."byweekno" IS NOT NULL AND result."freq" != 'YEARLY' THEN
    RAISE EXCEPTION 'FREQ must be YEARLY if BYWEEKNO is provided.';
  END IF;

  -- Limits on FREQ if byyearday is selected
  IF (result."freq" <> 'YEARLY' AND result."byyearday" IS NOT NULL) THEN
    RAISE EXCEPTION 'BYYEARDAY is only valid when FREQ is YEARLY.';
  END IF;

  IF (result."freq" = 'WEEKLY' AND result."bymonthday" IS NOT NULL) THEN
    RAISE EXCEPTION 'BYMONTHDAY is not valid when FREQ is WEEKLY.';
  END IF;

  -- BY[something-else] is required if BYSETPOS is set.
  IF (result."bysetpos" IS NOT NULL AND result."bymonth" IS NULL AND result."byweekno" IS NULL AND result."byyearday" IS NULL AND result."bymonthday" IS NULL AND result."byday" IS NULL AND result."byhour" IS NULL AND result."byminute" IS NULL AND result."bysecond" IS NULL) THEN
    RAISE EXCEPTION 'BYSETPOS requires at least one other BY*';
  END IF;

  IF result."freq" = 'DAILY' AND result."byday" IS NOT NULL THEN
    RAISE EXCEPTION 'BYDAY is not valid when FREQ is DAILY.';
  END IF;

  IF result."until" IS NOT NULL AND result."count" IS NOT NULL THEN
    RAISE EXCEPTION 'UNTIL and COUNT MUST NOT occur in the same recurrence.';
  END IF;

  IF result."interval" IS NOT NULL THEN
    IF (NOT result."interval" > 0) THEN
      RAISE EXCEPTION 'INTERVAL must be a non-zero integer.';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;CREATE OR REPLACE FUNCTION _rrule.rrule (TEXT)
RETURNS _rrule.RRULE AS $$
DECLARE
  result _rrule.RRULE;
BEGIN
  WITH "tokens" AS (
    WITH A20 as (SELECT _rrule.parse_line($1::text, 'RRULE') "r"),
    -- Split each key value pair into an array, e.g. {'FREQ', 'DAILY'}
    A30 as (SELECT regexp_split_to_array("r", '=') AS "y" FROM A20)
    SELECT "y"[1] AS "key", "y"[2] AS "val" FROM A30
  ),
  candidate AS (
    SELECT
      (SELECT "val"::_rrule.FREQ FROM "tokens" WHERE "key" = 'FREQ') AS "freq",
      (SELECT "val"::INTEGER FROM "tokens" WHERE "key" = 'INTERVAL') AS "interval",
      (SELECT "val"::INTEGER FROM "tokens" WHERE "key" = 'COUNT') AS "count",
      (SELECT "val"::TIMESTAMP FROM "tokens" WHERE "key" = 'UNTIL') AS "until",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYSECOND') AS "bysecond",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYMINUTE') AS "byminute",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYHOUR') AS "byhour",
      (SELECT _rrule.day_array("val") FROM "tokens" WHERE "key" = 'BYDAY') AS "byday",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYMONTHDAY') AS "bymonthday",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYYEARDAY') AS "byyearday",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYWEEKNO') AS "byweekno",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYMONTH') AS "bymonth",
      (SELECT _rrule.integer_array("val") FROM "tokens" WHERE "key" = 'BYSETPOS') AS "bysetpos",
      (SELECT "val"::_rrule.DAY FROM "tokens" WHERE "key" = 'WKST') AS "wkst"
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
  INTO result
  FROM candidate;

  PERFORM _rrule.validate_rrule(result);

  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;


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
CREATE OR REPLACE FUNCTION _rrule.rruleset (TEXT)
RETURNS _rrule.RRULESET AS $$
  WITH "dtstart-line" AS (SELECT _rrule.parse_line($1::text, 'DTSTART') as "x"),
  "dtend-line" AS (SELECT _rrule.parse_line($1::text, 'DTEND') as "x"),
  "exrule-line" AS (SELECT _rrule.parse_line($1::text, 'EXRULE') as "x"),
  "rdate-line" AS (SELECT _rrule.parse_line($1::text, 'RDATE') as "x"),
  "exdate-line" AS (SELECT _rrule.parse_line($1::text, 'EXDATE') as "x")
  SELECT
    (SELECT "x"::timestamp FROM "dtstart-line" LIMIT 1) AS "dtstart",
    (SELECT "x"::timestamp FROM "dtend-line" LIMIT 1) AS "dtend",
    (SELECT _rrule.rrule($1::text) "rrule") as "rrule",
    (SELECT _rrule.rrule("x"::text) "rrule" FROM "exrule-line") as "exrule",
    (SELECT (regexp_split_to_array("x"::text, ','))::TIMESTAMP[] from "rdate-line" AS "rdate"),
    (SELECT (regexp_split_to_array("x"::text, ','))::TIMESTAMP[] from "exdate-line" AS "exdate");
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
  SELECT _rrule.is_finite("rruleset"."rrule"::text::_rrule.RRULE);
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
    SELECT generate_series("start", "until", "interval") "occurrence"
    FROM "params"
    FULL OUTER JOIN "starts" ON (true)
  ),
  "ordered" AS (
    SELECT DISTINCT "occurrence"
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
  WHERE "row_number" <= "rrule"."count"
  OR "rrule"."count" IS NULL
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
    SELECT
      "rruleset"."dtstart",
      "rruleset"."dtend",
      "rruleset"."rrule"
  ),
  "rdates" AS (
    SELECT _rrule.occurrences("rrule", "dtstart", "tsrange") AS "occurrence"
    FROM "rrules"
    UNION
    SELECT unnest("rruleset"."rdate") AS "occurrence"
  ),
  "exrules" AS (
    SELECT
      "rruleset"."dtstart",
      "rruleset"."dtend",
      "rruleset"."exrule"
  ),
  "exdates" AS (
    SELECT _rrule.occurrences("exrule", "dtstart", "tsrange") AS "occurrence"
    FROM "exrules"
    UNION
    SELECT unnest("rruleset"."exdate") AS "occurrence"
  )
  SELECT "occurrence" FROM "rdates"
  EXCEPT
  SELECT "occurrence" FROM "exdates"
  ORDER BY "occurrence";
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.occurrences("rruleset" _rrule.RRULESET)
RETURNS SETOF TIMESTAMP AS $$
  SELECT _rrule.occurrences("rruleset", '(,)'::TSRANGE);
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.occurrences(
  "rruleset_array" _rrule.RRULESET[],
  "tsrange" TSRANGE
)
RETURNS SETOF TIMESTAMP AS $$
DECLARE
  i int;
  lim int;
  q text := '';
BEGIN
  lim := array_length("rruleset_array", 1);

  -- TODO: test
  IF lim IS NULL THEN
    q := 'VALUES (NULL::TIMESTAMP) LIMIT 0;';
  ELSE
    FOR i IN 1..lim
    LOOP
      q := q || $q$SELECT _rrule.occurrences('$q$ || "rruleset_array"[i] ||$q$'::_rrule.RRULESET, '$q$ || "tsrange" ||$q$'::TSRANGE)$q$;
      IF i != lim THEN
        q := q || ' UNION ';
      END IF;
    END LOOP;
    q := q || ' ORDER BY occurrences ASC';
  END IF;

  RETURN QUERY EXECUTE q;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;CREATE OR REPLACE FUNCTION _rrule.first("rrule" _rrule.RRULE, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$
BEGIN
  RETURN (SELECT "ts"
  FROM _rrule.all_starts("rrule", "dtstart") "ts"
  WHERE "ts" >= "dtstart"
  ORDER BY "ts" ASC
  LIMIT 1);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.first("rrule" TEXT, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$
  SELECT _rrule.first(_rrule.rrule("rrule"), "dtstart");
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.first("rruleset" _rrule.RRULESET)
RETURNS TIMESTAMP AS $$
  SELECT occurrence
  FROM _rrule.occurrences("rruleset") occurrence
  ORDER BY occurrence DESC LIMIT 1;
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

CREATE OR REPLACE FUNCTION _rrule.contains_timestamp(_rrule.RRULESET, TIMESTAMP)
RETURNS BOOLEAN AS $$
DECLARE
  inSet boolean;
BEGIN
  -- TODO: Not sure what how this is finding a timestamp that is contained
  -- by the rruleset.
  SELECT COUNT(*) > 0
  INTO inSet
  FROM _rrule.after($1, $2 - INTERVAL '1 month') "ts"
  WHERE "ts"::date = $2::date;

  RETURN inSet;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _rrule.jsonb_to_rrule("input" jsonb)
RETURNS _rrule.RRULE AS $$
DECLARE
  result _rrule.RRULE;
BEGIN
  IF (SELECT count(*) = 0 FROM jsonb_object_keys("input") WHERE "input"::TEXT <> 'null') THEN
    RETURN NULL;
  END IF;

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
  INTO result
  FROM jsonb_to_record("input") as x(
    "freq" _rrule.FREQ,
    "interval" integer,
    "count" INTEGER,
    "until" text,
    "bysecond" integer[],
    "byminute" integer[],
    "byhour" integer[],
    "byday" text[],
    "bymonthday" integer[],
    "byyearday" integer[],
    "byweekno" integer[],
    "bymonth" integer[],
    "bysetpos" integer[],
    "wkst" _rrule.DAY
  );

  PERFORM _rrule.validate_rrule(result);

  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _rrule.jsonb_to_rruleset("input" jsonb)
RETURNS _rrule.RRULESET AS $$
DECLARE
  result _rrule.RRULESET;
BEGIN
  SELECT
    "dtstart"::TIMESTAMP,
    "dtend"::TIMESTAMP,
    _rrule.jsonb_to_rrule("rrule") "rrule",
    _rrule.jsonb_to_rrule("exrule") "exrule",
    "rdate"::TIMESTAMP[],
    "exdate"::TIMESTAMP[]
  INTO result
  FROM jsonb_to_record("input") as x(
    "dtstart" text,
    "dtend" text,
    "rrule" jsonb,
    "exrule" jsonb,
    "rdate" text[],
    "exdate" text[]
  );

  -- TODO: validate rruleset

  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _rrule.jsonb_to_rruleset_array("input" jsonb)
RETURNS _rrule.RRULESET[] AS $$
DECLARE
  item jsonb;
  out _rrule.RRULESET[] := '{}'::_rrule.RRULESET[];
BEGIN
  FOR item IN SELECT * FROM jsonb_array_elements("input")
  LOOP
    out := (SELECT out || _rrule.jsonb_to_rruleset(item));
  END LOOP;

  RETURN out;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _rrule.rrule_to_jsonb("input" _rrule.RRULE)
RETURNS jsonb AS $$
BEGIN
  RETURN jsonb_strip_nulls(jsonb_build_object(
    'freq', "input"."freq",
    'interval', "input"."interval",
    'count', "input"."count",
    'until', "input"."until",
    'bysecond', "input"."bysecond",
    'byminute', "input"."byminute",
    'byhour', "input"."byhour",
    'byday', "input"."byday",
    'bymonthday', "input"."bymonthday",
    'byyearday', "input"."byyearday",
    'byweekno', "input"."byweekno",
    'bymonth', "input"."bymonth",
    'bysetpos', "input"."bysetpos",
    'wkst', "input"."wkst"
  ));
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _rrule.rruleset_to_jsonb("input" _rrule.RRULESET)
RETURNS jsonb AS $$
DECLARE
  rrule jsonb;
  exrule jsonb;
BEGIN
  SELECT _rrule.rrule_to_jsonb("input"."rrule")
  INTO rrule;

  SELECT _rrule.rrule_to_jsonb("input"."exrule")
  INTO exrule;

  RETURN jsonb_strip_nulls(jsonb_build_object(
    'dtstart', "input"."dtstart",
    'dtend', "input"."dtend",
    'rrule', rrule,
    'exrule', exrule,
    'rdate', "input"."rdate",
    'exdate', "input"."exdate"
  ));
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _rrule.rruleset_array_to_jsonb("input" _rrule.RRULESET[])
RETURNS jsonb AS $$
DECLARE
  item _rrule.RRULESET;
  out jsonb := '[]'::jsonb;
BEGIN
  FOREACH item IN ARRAY "input" LOOP
    out := (SELECT out || _rrule.rruleset_to_jsonb(item));
  END LOOP;

  RETURN out;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _rrule.rruleset_array_contains_timestamp(_rrule.RRULESET[], TIMESTAMP)
RETURNS BOOLEAN AS $$
DECLARE
  item _rrule.RRULESET;
BEGIN
  FOREACH item IN ARRAY $1
  LOOP
    IF (SELECT _rrule.contains_timestamp(item, $2)) THEN
      RETURN true;
    END IF;
  END LOOP;

  RETURN false;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _rrule.rruleset_has_after_timestamp(_rrule.RRULESET, TIMESTAMP)
RETURNS BOOLEAN AS $$
  SELECT count(*) > 0 FROM _rrule.after($1, $2) LIMIT 1;
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _rrule.rruleset_has_before_timestamp(_rrule.RRULESET, TIMESTAMP)
RETURNS BOOLEAN AS $$
  SELECT count(*) > 0 FROM _rrule.before($1, $2) LIMIT 1;
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _rrule.rruleset_array_has_after_timestamp(_rrule.RRULESET[], TIMESTAMP)
RETURNS BOOLEAN AS $$
DECLARE
  item _rrule.RRULESET;
BEGIN
  FOREACH item IN ARRAY $1
  LOOP
    IF (SELECT count(*) > 0 FROM _rrule.after(item, $2) LIMIT 1) THEN
      RETURN true;
    END IF;
  END LOOP;

  RETURN false;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _rrule.rruleset_array_has_before_timestamp(_rrule.RRULESET[], TIMESTAMP)
RETURNS BOOLEAN AS $$
DECLARE
  item _rrule.RRULESET;
BEGIN
  FOREACH item IN ARRAY $1
  LOOP
    IF (SELECT count(*) > 0 FROM _rrule.before(item, $2) LIMIT 1) THEN
      RETURN true;
    END IF;
  END LOOP;

  RETURN false;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
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

CREATE OPERATOR @> (
  LEFTARG = _rrule.RRULESET,
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.contains_timestamp
);

CREATE OPERATOR @> (
  LEFTARG = _rrule.RRULESET[],
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_array_contains_timestamp
);


CREATE OPERATOR > (
  LEFTARG = _rrule.RRULESET[],
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_array_has_after_timestamp
);

CREATE OPERATOR < (
  LEFTARG = _rrule.RRULESET[],
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_array_has_before_timestamp
);

CREATE OPERATOR > (
  LEFTARG = _rrule.RRULESET,
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_has_after_timestamp
);

CREATE OPERATOR < (
  LEFTARG = _rrule.RRULESET,
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_has_before_timestamp
);

CREATE CAST (TEXT AS _rrule.RRULE)
  WITH FUNCTION _rrule.rrule(TEXT)
  AS IMPLICIT;


CREATE CAST (TEXT AS _rrule.RRULESET)
  WITH FUNCTION _rrule.rruleset(TEXT)
  AS IMPLICIT;


CREATE CAST (jsonb AS _rrule.RRULE)
  WITH FUNCTION _rrule.jsonb_to_rrule(jsonb)
  AS IMPLICIT;


CREATE CAST (_rrule.RRULE AS jsonb)
  WITH FUNCTION _rrule.rrule_to_jsonb(_rrule.RRULE)
  AS IMPLICIT;
