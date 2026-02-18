-- Specialized occurrence generator for rules with negative BYMONTHDAY values.
--
-- PostgreSQL's generate_series with monthly intervals uses iterative addition
-- (prev + step), which causes day drift: Jan 31 + 1 month = Feb 28/29,
-- then Feb 28/29 + 1 month = Mar 28/29 (wrong, should be Mar 31 for BYMONTHDAY=-1).
--
-- This function resolves BYMONTHDAY values per-month to produce correct results.
-- It handles both positive and negative BYMONTHDAY values, MONTHLY and YEARLY frequencies,
-- and respects BYMONTH, UNTIL, COUNT, and INTERVAL parameters.
CREATE OR REPLACE FUNCTION _rrule.occurrences_bymonthday(
  "rrule" _rrule.RRULE,
  "dtstart" TIMESTAMP
)
RETURNS SETOF TIMESTAMP AS $$
DECLARE
  current_period TIMESTAMP;
  end_date TIMESTAMP;
  period_count INTEGER := 0;
  occurrence_count INTEGER := 0;
  max_occurrences INTEGER;
  resolved_day INTEGER;
  occurrence TIMESTAMP;
  step_interval INTERVAL;
  bymonthday_val INTEGER;
  target_month TIMESTAMP;
  bymonth_val INTEGER;
BEGIN
  -- Calculate end date
  IF "rrule"."until" IS NOT NULL THEN
    end_date := "rrule"."until";
  ELSIF "rrule"."count" IS NOT NULL THEN
    max_occurrences := "rrule"."count";
    -- Generous upper bound for iteration
    IF "rrule"."freq" = 'YEARLY' THEN
      end_date := "dtstart" + (COALESCE("rrule"."interval", 1) * max_occurrences * 2 || ' years')::INTERVAL;
    ELSE
      end_date := "dtstart" + (COALESCE("rrule"."interval", 1) * max_occurrences * 2 || ' months')::INTERVAL;
    END IF;
  ELSE
    end_date := '9999-12-31 23:59:59'::TIMESTAMP;
  END IF;

  -- Build step interval for advancing periods
  step_interval := _rrule.build_interval("rrule");

  -- Start at the beginning of dtstart's period
  IF "rrule"."freq" = 'YEARLY' THEN
    current_period := date_trunc('year', "dtstart");
  ELSE
    current_period := date_trunc('month', "dtstart");
  END IF;

  WHILE current_period <= end_date LOOP
    -- For YEARLY with BYMONTH, iterate through each target month
    IF "rrule"."freq" = 'YEARLY' AND "rrule"."bymonth" IS NOT NULL THEN
      FOREACH bymonth_val IN ARRAY "rrule"."bymonth"
      LOOP
        target_month := make_timestamp(
          EXTRACT(YEAR FROM current_period)::INTEGER, bymonth_val, 1, 0, 0, 0
        );
        FOREACH bymonthday_val IN ARRAY "rrule"."bymonthday"
        LOOP
          resolved_day := _rrule.resolve_bymonthday(bymonthday_val, target_month);
          IF resolved_day IS NOT NULL THEN
            occurrence := make_timestamp(
              EXTRACT(YEAR FROM current_period)::INTEGER,
              bymonth_val,
              resolved_day,
              EXTRACT(HOUR FROM "dtstart")::INTEGER,
              EXTRACT(MINUTE FROM "dtstart")::INTEGER,
              EXTRACT(SECOND FROM "dtstart")
            );
            IF occurrence >= "dtstart" THEN
              IF "rrule"."until" IS NOT NULL AND occurrence > "rrule"."until" THEN
                RETURN;
              END IF;
              RETURN NEXT occurrence;
              occurrence_count := occurrence_count + 1;
              IF max_occurrences IS NOT NULL AND occurrence_count >= max_occurrences THEN
                RETURN;
              END IF;
            END IF;
          END IF;
        END LOOP;
      END LOOP;
    ELSIF "rrule"."freq" = 'YEARLY' THEN
      -- YEARLY without BYMONTH: use dtstart's month
      target_month := make_timestamp(
        EXTRACT(YEAR FROM current_period)::INTEGER,
        EXTRACT(MONTH FROM "dtstart")::INTEGER,
        1, 0, 0, 0
      );
      FOREACH bymonthday_val IN ARRAY "rrule"."bymonthday"
      LOOP
        resolved_day := _rrule.resolve_bymonthday(bymonthday_val, target_month);
        IF resolved_day IS NOT NULL THEN
          occurrence := make_timestamp(
            EXTRACT(YEAR FROM current_period)::INTEGER,
            EXTRACT(MONTH FROM "dtstart")::INTEGER,
            resolved_day,
            EXTRACT(HOUR FROM "dtstart")::INTEGER,
            EXTRACT(MINUTE FROM "dtstart")::INTEGER,
            EXTRACT(SECOND FROM "dtstart")
          );
          IF occurrence >= "dtstart" THEN
            IF "rrule"."until" IS NOT NULL AND occurrence > "rrule"."until" THEN
              RETURN;
            END IF;
            RETURN NEXT occurrence;
            occurrence_count := occurrence_count + 1;
            IF max_occurrences IS NOT NULL AND occurrence_count >= max_occurrences THEN
              RETURN;
            END IF;
          END IF;
        END IF;
      END LOOP;
    ELSE
      -- MONTHLY: resolve each BYMONTHDAY for this month
      FOREACH bymonthday_val IN ARRAY "rrule"."bymonthday"
      LOOP
        resolved_day := _rrule.resolve_bymonthday(bymonthday_val, current_period);
        IF resolved_day IS NOT NULL THEN
          -- Check BYMONTH filter if present
          IF "rrule"."bymonth" IS NOT NULL
             AND NOT (EXTRACT(MONTH FROM current_period)::INTEGER = ANY("rrule"."bymonth")) THEN
            CONTINUE;
          END IF;

          occurrence := make_timestamp(
            EXTRACT(YEAR FROM current_period)::INTEGER,
            EXTRACT(MONTH FROM current_period)::INTEGER,
            resolved_day,
            EXTRACT(HOUR FROM "dtstart")::INTEGER,
            EXTRACT(MINUTE FROM "dtstart")::INTEGER,
            EXTRACT(SECOND FROM "dtstart")
          );
          IF occurrence >= "dtstart" THEN
            IF "rrule"."until" IS NOT NULL AND occurrence > "rrule"."until" THEN
              RETURN;
            END IF;
            RETURN NEXT occurrence;
            occurrence_count := occurrence_count + 1;
            IF max_occurrences IS NOT NULL AND occurrence_count >= max_occurrences THEN
              RETURN;
            END IF;
          END IF;
        END IF;
      END LOOP;
    END IF;

    -- Advance to next period using multiplicative approach to avoid drift
    period_count := period_count + 1;
    IF "rrule"."freq" = 'YEARLY' THEN
      current_period := date_trunc('year', "dtstart") + (COALESCE("rrule"."interval", 1) * period_count || ' years')::INTERVAL;
    ELSE
      current_period := date_trunc('month', "dtstart") + (_rrule.build_interval(COALESCE("rrule"."interval", 1), 'MONTHLY') * period_count);
    END IF;
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
