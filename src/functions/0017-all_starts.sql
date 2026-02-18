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
-- 3. Filter candidates to ensure they satisfy ALL applicable BY* constraints
-- 4. Return distinct timestamps sorted chronologically
--
-- The function uses UNION to combine three potential sources of timestamps:
-- - Cartesian product of all BY* time parameters
-- - Day-of-week matches within a week window (for byday)
-- - Month-day matches within a 2-month window (for bymonthday)
-- - Month matches within a year window (for bymonth)
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
  timestamp_combinations as (
    SELECT
      make_timestamp(
        "year"."year",
        COALESCE("bymonth", month),
        COALESCE(
          -- Resolve negative BYMONTHDAY values to actual day numbers for the target month
          CASE WHEN "bymonthday" IS NOT NULL THEN
            _rrule.resolve_bymonthday(
              "bymonthday",
              make_timestamp("year"."year", COALESCE("bymonth", month), 1, 0, 0, 0)
            )
          ELSE NULL END,
          day
        ),
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
    WHERE "bymonthday" IS NULL
      OR _rrule.resolve_bymonthday(
           "bymonthday",
           make_timestamp("year"."year", COALESCE("bymonth", month), 1, 0, 0, 0)
         ) IS NOT NULL
  ),
  candidate_timestamps as (
    SELECT DISTINCT "ts"
    FROM timestamp_combinations
    UNION
    -- For WEEKLY/DAILY with BYDAY (no ordinals meaningful here)
    SELECT "ts" FROM (
      SELECT "ts"
      FROM generate_series("dtstart", dtstart + INTERVAL '6 days', INTERVAL '1 day') "ts"
      CROSS JOIN unnest("rrule"."byday") as byday_val
      WHERE "rrule"."byday" IS NOT NULL
        AND "rrule"."freq" IN ('DAILY', 'WEEKLY')
        AND "ts"::_rrule.DAY = _rrule.extract_byday_day(byday_val)
    ) as "ts"
    UNION
    -- For MONTHLY with BYDAY (supports ordinals)
    SELECT "ts" FROM (
      SELECT _rrule.ordinal_byday_in_month(
        date_trunc('month', "dtstart"),
        byday_val
      ) as "ts"
      FROM unnest("rrule"."byday") as byday_val
      WHERE "rrule"."byday" IS NOT NULL
        AND "rrule"."freq" = 'MONTHLY'
    ) as "ts"
    UNION
    -- For YEARLY with BYDAY (supports ordinals, generates across year)
    SELECT "ts" FROM (
      SELECT "ts"
      FROM generate_series("dtstart", "dtstart" + INTERVAL '1 year', INTERVAL '1 day') "ts"
      CROSS JOIN unnest("rrule"."byday") as byday_val
      WHERE "rrule"."byday" IS NOT NULL
        AND "rrule"."freq" = 'YEARLY'
        AND "ts"::_rrule.DAY = _rrule.extract_byday_day(byday_val)
    ) as "ts"
    UNION
    SELECT "ts" FROM (
      SELECT "ts"
      FROM generate_series("dtstart", "dtstart" + INTERVAL '2 months', INTERVAL '1 day') "ts"
      WHERE "rrule"."bymonthday" IS NOT NULL
        AND EXTRACT(DAY FROM "ts") = ANY(
          SELECT _rrule.resolve_bymonthday(bmd, "ts")
          FROM unnest("rrule"."bymonthday") AS bmd
          WHERE _rrule.resolve_bymonthday(bmd, "ts") IS NOT NULL
        )
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
    "rrule"."bymonthday" IS NULL OR EXTRACT(DAY FROM "ts") = ANY(
      SELECT _rrule.resolve_bymonthday(bmd, "ts")
      FROM unnest("rrule"."bymonthday") AS bmd
      WHERE _rrule.resolve_bymonthday(bmd, "ts") IS NOT NULL
    )
  )
  ORDER BY "ts";

END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE PARALLEL SAFE;
