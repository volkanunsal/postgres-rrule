-- Specialized occurrence generator for MONTHLY frequency with ordinal BYDAY
-- This function generates occurrences by finding the nth weekday of each month,
-- rather than adding fixed intervals (which doesn't work for ordinal BYDAY)
CREATE OR REPLACE FUNCTION _rrule.occurrences_monthly_byday(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
)
RETURNS SETOF TIMESTAMP AS $$
DECLARE
  current_month TIMESTAMP;
  end_date TIMESTAMP;
  month_count INTEGER := 0;
  occurrence_count INTEGER := 0;
  max_occurrences INTEGER;
  byday_val TEXT;
  occurrence TIMESTAMP;
BEGIN
  -- Calculate end date
  IF "rrule"."until" IS NOT NULL THEN
    end_date := "rrule"."until";
  ELSIF "rrule"."count" IS NOT NULL THEN
    -- For COUNT, we need to generate enough months to get COUNT occurrences
    -- Estimate: COUNT * interval months should be sufficient
    end_date := "dtstart" + (_rrule.build_interval("rrule"."interval", "rrule"."freq") * "rrule"."count" * 2);
    max_occurrences := "rrule"."count";
  ELSE
    -- Infinite recurrence
    end_date := '9999-12-31 23:59:59'::TIMESTAMP;
  END IF;

  -- Start at the beginning of dtstart's month
  current_month := date_trunc('month', "dtstart");

  -- Iterate through months
  WHILE current_month <= end_date LOOP
    -- For each BYDAY value, generate occurrences in this month
    FOREACH byday_val IN ARRAY "rrule"."byday"
    LOOP
      -- Generate occurrence for this byday value in this month
      FOR occurrence IN
        SELECT _rrule.ordinal_byday_in_month(current_month, byday_val)
      LOOP
        -- Apply time component from dtstart
        occurrence := occurrence
          + (EXTRACT(HOUR FROM "dtstart") || ' hours')::INTERVAL
          + (EXTRACT(MINUTE FROM "dtstart") || ' minutes')::INTERVAL
          + (EXTRACT(SECOND FROM "dtstart") || ' seconds')::INTERVAL;

        -- Only include occurrences >= dtstart
        IF occurrence >= "dtstart" THEN
          -- Check against UNTIL
          IF "rrule"."until" IS NOT NULL AND occurrence > "rrule"."until" THEN
            RETURN;
          END IF;

          RETURN NEXT occurrence;
          occurrence_count := occurrence_count + 1;

          -- Check against COUNT
          IF max_occurrences IS NOT NULL AND occurrence_count >= max_occurrences THEN
            RETURN;
          END IF;
        END IF;
      END LOOP;
    END LOOP;

    -- Move to next month (apply interval)
    month_count := month_count + 1;
    current_month := date_trunc('month', "dtstart") + (_rrule.build_interval("rrule"."interval", 'MONTHLY') * month_count);
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
