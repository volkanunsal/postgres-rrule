-- For example, a YEARLY rule that repeats on first and third month have 2 start values.

CREATE OR REPLACE FUNCTION _rrule.all_starts(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
DECLARE
  year int := EXTRACT(YEAR FROM "dtstart")::integer;
  year_end timestamp := make_timestamp(year, 12, 31, 23, 59, 59);
BEGIN

  RETURN QUERY WITH
  "year" as (SELECT EXTRACT(YEAR FROM "dtstart")::integer AS "year"),
  A11 as (
    SELECT "ts" FROM (
      SELECT "ts"
      FROM generate_series("dtstart", year_end, INTERVAL '1 day') "ts"
      WHERE (
        "ts"::_rrule.DAY = ANY("rrule"."byday")
      )
      AND "ts" < ("dtstart" + INTERVAL '7 days')
    ) as "ts"
    
  )
  SELECT DISTINCT "ts"
  FROM A11
  ORDER BY "ts";

END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;
