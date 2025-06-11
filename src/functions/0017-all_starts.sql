-- For example, a YEARLY rule that repeats on first and third month have 2 start values.

CREATE OR REPLACE FUNCTION _rrule.all_starts(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
BEGIN
  IF ("rrule"."bysetpos" IS NULL) 
  THEN 
    RETURN QUERY SELECT * FROM _rrule.all_starts_standard($1,$2);
  ELSE
    RETURN QUERY SELECT * FROM _rrule.all_starts_bysetpos($1,$2);
  END IF;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;


CREATE OR REPLACE FUNCTION _rrule.all_starts_standard(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
DECLARE
  year int := EXTRACT(YEAR FROM _rrule.until($1, $2))::integer;
  year_end timestamp := make_timestamp(year, 12, 31, 23, 59, 59);
BEGIN
  RETURN QUERY WITH
  A11 as (
    SELECT "ts" FROM (
      SELECT "ts"
      FROM generate_series("dtstart" - interval '6 days', year_end, INTERVAL '1 day') "ts"
      WHERE (
        "ts"::_rrule.DAY = ANY("rrule"."byday")
      )
      AND (
        extract(isodow from "dtstart") > extract(isodow from "ts") AND "ts" BETWEEN "dtstart" - interval '6 days' AND "dtstart" 
        OR
        extract(isodow from "dtstart") <= extract(isodow from "ts") AND "ts" BETWEEN "dtstart" AND "dtstart" + interval '6 days'
      )
    ) as "ts"
  )
  SELECT DISTINCT "ts"
  FROM A11
  ORDER BY "ts";
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;


CREATE OR REPLACE FUNCTION _rrule.all_starts_bysetpos(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
DECLARE
  year int := EXTRACT(YEAR FROM "dtstart")::integer;
  month int := EXTRACT(MONTH FROM "dtstart")::integer;
  year_end timestamp := make_timestamp(EXTRACT(YEAR FROM _rrule.until($1, $2))::integer, 12, 31, 23, 59, 59);
  first_of_month timestamp := make_timestamp(year, month, 1, 0, 0,0);
BEGIN
  RETURN QUERY 
	WITH begin_months AS (
	SELECT "bm"
      FROM generate_series(first_of_month, year_end, INTERVAL '1 month') "bm"
    ),
    first_days AS (SELECT generate_series("bm", "bm"+interval '6 days', INTERVAL '1 day') "fd"
	FROM begin_months)
	SELECT "fd" 
	FROM first_days
	WHERE (
        "fd"::_rrule.DAY = ANY("rrule"."byday")
      );
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;