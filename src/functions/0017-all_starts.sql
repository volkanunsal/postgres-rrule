-- Computes all possible starting timestamps for a recurrence rule within its first cycle.
--
-- This function determines the "seed" timestamps from which occurrences are generated.
-- For example, a YEARLY rule with BYMONTH=[1,3] has 2 start values (January 1 and March 1).
--
-- Algorithm:
-- 1. Extract time components from dtstart (hour, minute, second, day, month)
-- 2. Generate candidate timestamps by combining:
--    a. BY* parameters (bymonth, bymonthday, byhour, byminute, bysecond)
--    b. Day-of-week constraints (byday) matched within date ranges
-- 3. Apply BYHOUR/BYMINUTE/BYSECOND to all candidate dates (including BYDAY-generated ones)
-- 4. Filter candidates to ensure they satisfy ALL applicable BY* constraints
-- 5. Return distinct timestamps sorted chronologically
--
-- The function uses UNION to combine candidate date sources, then applies time
-- components (BYHOUR/BYMINUTE/BYSECOND) uniformly via a cross-join to ensure
-- that BYDAY-generated dates also receive the correct time values.
--
-- Performance optimization: NULL checks prevent unnecessary generate_series calls
-- when the corresponding BY* parameter is not specified.

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
  -- Generate all candidate time values from BYHOUR/BYMINUTE/BYSECOND (or dtstart defaults)
  "time_values" AS (
    SELECT
      COALESCE("byhour", hour) AS "h",
      COALESCE("byminute", minute) AS "m",
      COALESCE("bysecond", second) AS "s"
    FROM (SELECT 1) AS _dummy
    LEFT OUTER JOIN unnest(("rrule")."byhour") AS "byhour" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."byminute") AS "byminute" ON (true)
    LEFT OUTER JOIN unnest(("rrule")."bysecond") AS "bysecond" ON (true)
  ),
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
  -- Collect candidate dates from BYDAY branches, then apply time values
  byday_dates AS (
    -- For WEEKLY/DAILY with BYDAY (no ordinals meaningful here)
    SELECT date_trunc('day', "ts") AS "d"
    FROM generate_series("dtstart", "dtstart" + INTERVAL '6 days', INTERVAL '1 day') "ts"
    CROSS JOIN unnest("rrule"."byday") as byday_val
    WHERE "rrule"."byday" IS NOT NULL
      AND "rrule"."freq" IN ('DAILY', 'WEEKLY')
      AND "ts"::_rrule.DAY = _rrule.extract_byday_day(byday_val)
    UNION
    -- For MONTHLY with BYDAY (supports ordinals)
    SELECT date_trunc('day', _rrule.ordinal_byday_in_month(
      date_trunc('month', "dtstart"),
      byday_val
    )) AS "d"
    FROM unnest("rrule"."byday") as byday_val
    WHERE "rrule"."byday" IS NOT NULL
      AND "rrule"."freq" = 'MONTHLY'
    UNION
    -- For YEARLY with BYDAY (supports ordinals, generates across year)
    SELECT date_trunc('day', "ts") AS "d"
    FROM generate_series("dtstart", "dtstart" + INTERVAL '1 year', INTERVAL '1 day') "ts"
    CROSS JOIN unnest("rrule"."byday") as byday_val
    WHERE "rrule"."byday" IS NOT NULL
      AND "rrule"."freq" = 'YEARLY'
      AND "ts"::_rrule.DAY = _rrule.extract_byday_day(byday_val)
  ),
  -- Apply BYHOUR/BYMINUTE/BYSECOND time values to BYDAY-generated dates
  byday_timestamps AS (
    SELECT ("d" + make_interval(hours := "h", mins := "m", secs := "s")) AS "ts"
    FROM byday_dates
    CROSS JOIN time_values
  ),
  candidate_timestamps as (
    SELECT DISTINCT "ts"
    FROM timestamp_combinations
    UNION
    SELECT DISTINCT "ts"
    FROM byday_timestamps
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
    "rrule"."byday" IS NULL
    OR (
      -- For MONTHLY, check ordinal match within month
      "rrule"."freq" = 'MONTHLY'
      AND EXISTS (
        SELECT 1 FROM unnest("rrule"."byday") byday_val
        WHERE _rrule.matches_ordinal_byday_in_month("ts", byday_val)
      )
    )
    OR (
      -- For YEARLY, check ordinal match within year
      "rrule"."freq" = 'YEARLY'
      AND EXISTS (
        SELECT 1 FROM unnest("rrule"."byday") byday_val
        WHERE _rrule.matches_ordinal_byday_in_year("ts", byday_val)
      )
    )
    OR (
      -- For WEEKLY/DAILY, just match the day (ordinals not meaningful)
      "rrule"."freq" IN ('WEEKLY', 'DAILY')
      AND "ts"::_rrule.DAY = ANY(
        SELECT _rrule.extract_byday_day(byday_val)
        FROM unnest("rrule"."byday") byday_val
      )
    )
  )
  AND (
    "rrule"."bymonth" IS NULL OR EXTRACT(MONTH FROM "ts") = ANY("rrule"."bymonth")
  )
  AND (
    "rrule"."bymonthday" IS NULL OR EXTRACT(DAY FROM "ts") = ANY("rrule"."bymonthday")
  )
  AND (
    "rrule"."byhour" IS NULL OR EXTRACT(HOUR FROM "ts")::integer = ANY("rrule"."byhour")
  )
  AND (
    "rrule"."byminute" IS NULL OR EXTRACT(MINUTE FROM "ts")::integer = ANY("rrule"."byminute")
  )
  AND (
    "rrule"."bysecond" IS NULL OR EXTRACT(SECOND FROM "ts")::integer = ANY("rrule"."bysecond")
  )
  ORDER BY "ts";

END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE PARALLEL SAFE;
