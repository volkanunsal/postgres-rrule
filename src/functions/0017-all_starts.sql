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
