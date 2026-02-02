CREATE OR REPLACE FUNCTION _rrule.validate_rrule (result _rrule.RRULE)
RETURNS void AS $$
BEGIN
  -- FREQ is required
  IF result."freq" IS NULL THEN
    RAISE EXCEPTION 'FREQ cannot be null.';
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
  IF result."bysetpos" IS NOT NULL AND NOT _rrule.has_any_by_rule(result) THEN
    RAISE EXCEPTION 'BYSETPOS requires at least one other BY* parameter.';
  END IF;

  IF result."freq" = 'DAILY' AND result."byday" IS NOT NULL THEN
    RAISE EXCEPTION 'BYDAY is not valid when FREQ is DAILY.';
  END IF;

  IF result."until" IS NOT NULL AND result."count" IS NOT NULL THEN
    RAISE EXCEPTION 'UNTIL and COUNT must not occur in the same recurrence.';
  END IF;

  IF result."interval" IS NOT NULL THEN
    IF (NOT result."interval" > 0) THEN
      RAISE EXCEPTION 'INTERVAL must be a non-zero integer.';
    END IF;
  END IF;

  -- COUNT must be positive
  IF result."count" IS NOT NULL THEN
    IF (NOT result."count" > 0) THEN
      RAISE EXCEPTION 'COUNT must be a positive integer.';
    END IF;
  END IF;

  -- BY* arrays should not be empty
  IF result."bymonth" IS NOT NULL AND array_length(result."bymonth", 1) = 0 THEN
    RAISE EXCEPTION 'BYMONTH cannot be an empty array.';
  END IF;

  IF result."byweekno" IS NOT NULL AND array_length(result."byweekno", 1) = 0 THEN
    RAISE EXCEPTION 'BYWEEKNO cannot be an empty array.';
  END IF;

  IF result."byyearday" IS NOT NULL AND array_length(result."byyearday", 1) = 0 THEN
    RAISE EXCEPTION 'BYYEARDAY cannot be an empty array.';
  END IF;

  IF result."bymonthday" IS NOT NULL AND array_length(result."bymonthday", 1) = 0 THEN
    RAISE EXCEPTION 'BYMONTHDAY cannot be an empty array.';
  END IF;

  IF result."byday" IS NOT NULL AND array_length(result."byday", 1) = 0 THEN
    RAISE EXCEPTION 'BYDAY cannot be an empty array.';
  END IF;

  IF result."byhour" IS NOT NULL AND array_length(result."byhour", 1) = 0 THEN
    RAISE EXCEPTION 'BYHOUR cannot be an empty array.';
  END IF;

  IF result."byminute" IS NOT NULL AND array_length(result."byminute", 1) = 0 THEN
    RAISE EXCEPTION 'BYMINUTE cannot be an empty array.';
  END IF;

  IF result."bysecond" IS NOT NULL AND array_length(result."bysecond", 1) = 0 THEN
    RAISE EXCEPTION 'BYSECOND cannot be an empty array.';
  END IF;

  IF result."bysetpos" IS NOT NULL AND array_length(result."bysetpos", 1) = 0 THEN
    RAISE EXCEPTION 'BYSETPOS cannot be an empty array.';
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;