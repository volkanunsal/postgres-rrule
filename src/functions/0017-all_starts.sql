-- STARTS
--
-- Given a start time, returns a set of all possible start values for a recurrence rule.
-- For example, a YEARLY rule that repeats on first and third month have 2 start values.

-- NOTE:
-- If we have a bymonthday, but no bymonth, that means we need to expand to all months.

/*
  YEARLY rules
*/
CREATE OR REPLACE FUNCTION _rrule.all_starts_YEARLY(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
  WITH A0 as (
    SELECT
      make_timestamp(
        -- "bymonth" signals the months to apply the recurrence to. If any of the months
        -- in this array is greater than the current month, increment "year" by one because
        -- the next occurrence of the month cannot happen in the this year.
        CASE WHEN "bymonth" > EXTRACT(MONTH FROM "dtstart")::integer OR "bymonth" IS NULL THEN "year"."year" ELSE "year"."year" + 1 END,
        COALESCE("bymonth", EXTRACT(MONTH FROM "dtstart")::integer),
        COALESCE("bymonthday", EXTRACT(DAY FROM "dtstart")::integer),
        COALESCE("byhour", EXTRACT(HOUR FROM "dtstart")::integer),
        COALESCE("byminute", EXTRACT(MINUTE FROM "dtstart")::integer),
        COALESCE("bysecond", EXTRACT(SECOND FROM "dtstart"))
      ) as "ts"
    FROM (SELECT EXTRACT(YEAR FROM "dtstart")::integer AS "year") AS "year"
    LEFT OUTER JOIN unnest(("rrule")."bymonth") AS "bymonth" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."bymonthday") AS "bymonthday" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."byhour") AS "byhour" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."byminute") AS "byminute" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."bysecond") AS "bysecond" ON (true)

    -- LEFT OUTER JOIN generate_series(1, ("rrule")."count", 1) AS "count" ON (true)
  )
  SELECT "ts" FROM A0 WHERE "ts" >= "dtstart";
$$ LANGUAGE SQL STRICT IMMUTABLE;


/*
  MONTHLY rules
*/
CREATE OR REPLACE FUNCTION _rrule.all_starts_MONTHLY(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
  SELECT _rrule.all_starts_YEARLY("rrule", "dtstart");
$$ LANGUAGE SQL STRICT IMMUTABLE;

/*
  WEEKLY rules
*/

CREATE OR REPLACE FUNCTION _rrule.all_starts_WEEKLY(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
  SELECT _rrule.all_starts_YEARLY("rrule", "dtstart");
$$ LANGUAGE SQL STRICT IMMUTABLE;


/*
  DAILY rules
*/
CREATE OR REPLACE FUNCTION _rrule.all_starts_DAILY(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
  SELECT _rrule.all_starts_YEARLY("rrule", "dtstart");
$$ LANGUAGE SQL STRICT IMMUTABLE;

/*
  HOURLY rules
*/

CREATE OR REPLACE FUNCTION _rrule.all_starts_HOURLY(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
  SELECT _rrule.all_starts_YEARLY("rrule", "dtstart");
$$ LANGUAGE SQL STRICT IMMUTABLE;


/*
  MINUTELY rules
*/

CREATE OR REPLACE FUNCTION _rrule.all_starts_MINUTELY(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
  SELECT _rrule.all_starts_YEARLY("rrule", "dtstart");
$$ LANGUAGE SQL STRICT IMMUTABLE;

/*
  SECONDLY rules
*/

CREATE OR REPLACE FUNCTION _rrule.all_starts_SECONDLY(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
  SELECT _rrule.all_starts_YEARLY("rrule", "dtstart");
$$ LANGUAGE SQL STRICT IMMUTABLE;


CREATE OR REPLACE FUNCTION _rrule.all_starts(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
) RETURNS SETOF TIMESTAMP AS $$
BEGIN
  RETURN QUERY EXECUTE format(
    'SELECT * FROM _rrule.all_starts_%s($1, $2) ORDER BY 1',
    "rrule".FREQ
  ) USING "rrule", "dtstart";
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;


