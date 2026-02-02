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
  interv INTERVAL := _rrule.build_interval("rrule");
BEGIN
  RETURN QUERY WITH
  "year" as (SELECT EXTRACT(YEAR FROM "dtstart")::integer AS "year"),
  timestamp_combinations as (
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
  candidate_timestamps as (
    SELECT DISTINCT "ts"
    FROM timestamp_combinations
    UNION
    SELECT "ts" FROM (
      SELECT "ts"
      FROM generate_series("dtstart", dtstart + INTERVAL '6 days', INTERVAL '1 day') "ts"
      WHERE "rrule"."byday" IS NOT NULL
        AND "ts"::_rrule.DAY = ANY("rrule"."byday")
    ) as "ts"
    UNION
    SELECT "ts" FROM (
      SELECT "ts"
      FROM generate_series("dtstart", "dtstart" + INTERVAL '2 months', INTERVAL '1 day') "ts"
      WHERE "rrule"."bymonthday" IS NOT NULL
        AND EXTRACT(DAY FROM "ts") = ANY("rrule"."bymonthday")
        AND "ts" <= ("dtstart" + INTERVAL '2 months')
    ) as "ts"
    UNION
    SELECT "ts" FROM (
      SELECT "ts"
      FROM generate_series("dtstart", "dtstart" + INTERVAL '1 year', INTERVAL '1 month') "ts"
      WHERE "rrule"."bymonth" IS NOT NULL
        AND EXTRACT(MONTH FROM "ts") = ANY("rrule"."bymonth")
    ) as "ts"
  )
  SELECT DISTINCT "ts"
  FROM candidate_timestamps
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
