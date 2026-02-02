-- Helper function to extract the ordinal from a BYDAY value
-- Examples: "1TU" → 1, "2MO" → 2, "-1FR" → -1, "MO" → NULL
CREATE OR REPLACE FUNCTION _rrule.extract_byday_ordinal(byday_value TEXT)
RETURNS INTEGER AS $$
  SELECT CASE
    WHEN byday_value ~ '^[+-]?\d+[A-Z]{2}$' THEN
      substring(byday_value from '^([+-]?\d+)[A-Z]{2}$')::INTEGER
    ELSE NULL
  END;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;


-- Helper function to extract the day from a BYDAY value
-- Examples: "1TU" → "TU", "2MO" → "MO", "-1FR" → "FR", "MO" → "MO"
CREATE OR REPLACE FUNCTION _rrule.extract_byday_day(byday_value TEXT)
RETURNS _rrule.DAY AS $$
  SELECT substring(byday_value from '([A-Z]{2})$')::_rrule.DAY;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;


-- Helper function to check if a timestamp matches an ordinal BYDAY value within a month
-- For example, is '2026-02-03' the 1st Tuesday of February 2026?
CREATE OR REPLACE FUNCTION _rrule.matches_ordinal_byday_in_month(
  ts TIMESTAMP,
  byday_value TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  ordinal INTEGER;
  day_of_week _rrule.DAY;
  month_start TIMESTAMP;
  month_end TIMESTAMP;
  occurrence_count INTEGER;
  occurrence_position INTEGER;
BEGIN
  -- Extract ordinal and day from byday_value
  ordinal := _rrule.extract_byday_ordinal(byday_value);
  day_of_week := _rrule.extract_byday_day(byday_value);

  -- If no ordinal, just check if the day matches
  IF ordinal IS NULL THEN
    RETURN ts::_rrule.DAY = day_of_week;
  END IF;

  -- Check if timestamp is on the correct day of week
  IF ts::_rrule.DAY != day_of_week THEN
    RETURN false;
  END IF;

  -- Get month boundaries
  month_start := date_trunc('month', ts);
  month_end := month_start + INTERVAL '1 month' - INTERVAL '1 second';

  -- Count total occurrences of this day in the month
  SELECT count(*)::INTEGER INTO occurrence_count
  FROM generate_series(month_start, month_end, INTERVAL '1 day') d
  WHERE d::_rrule.DAY = day_of_week;

  -- Find position of current timestamp
  SELECT count(*)::INTEGER INTO occurrence_position
  FROM generate_series(month_start, ts, INTERVAL '1 day') d
  WHERE d::_rrule.DAY = day_of_week;

  -- Check if position matches ordinal
  IF ordinal > 0 THEN
    RETURN occurrence_position = ordinal;
  ELSE
    -- Negative ordinal counts from end
    RETURN occurrence_position = (occurrence_count + ordinal + 1);
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;


-- Helper function to check if a timestamp matches an ordinal BYDAY value within a year
-- Used for YEARLY frequency rules
CREATE OR REPLACE FUNCTION _rrule.matches_ordinal_byday_in_year(
  ts TIMESTAMP,
  byday_value TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  ordinal INTEGER;
  day_of_week _rrule.DAY;
  year_start TIMESTAMP;
  year_end TIMESTAMP;
  occurrence_count INTEGER;
  occurrence_position INTEGER;
BEGIN
  -- Extract ordinal and day from byday_value
  ordinal := _rrule.extract_byday_ordinal(byday_value);
  day_of_week := _rrule.extract_byday_day(byday_value);

  -- If no ordinal, just check if the day matches
  IF ordinal IS NULL THEN
    RETURN ts::_rrule.DAY = day_of_week;
  END IF;

  -- Check if timestamp is on the correct day of week
  IF ts::_rrule.DAY != day_of_week THEN
    RETURN false;
  END IF;

  -- Get year boundaries
  year_start := date_trunc('year', ts);
  year_end := year_start + INTERVAL '1 year' - INTERVAL '1 second';

  -- Count total occurrences of this day in the year
  SELECT count(*)::INTEGER INTO occurrence_count
  FROM generate_series(year_start, year_end, INTERVAL '1 day') d
  WHERE d::_rrule.DAY = day_of_week;

  -- Find position of current timestamp
  SELECT count(*)::INTEGER INTO occurrence_position
  FROM generate_series(year_start, ts, INTERVAL '1 day') d
  WHERE d::_rrule.DAY = day_of_week;

  -- Check if position matches ordinal
  IF ordinal > 0 THEN
    RETURN occurrence_position = ordinal;
  ELSE
    -- Negative ordinal counts from end
    RETURN occurrence_position = (occurrence_count + ordinal + 1);
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;


-- Helper function to generate all timestamps matching an ordinal BYDAY within a month
-- For example, all 1st Tuesdays: returns the 1st Tuesday of the given month
CREATE OR REPLACE FUNCTION _rrule.ordinal_byday_in_month(
  month_start TIMESTAMP,
  byday_value TEXT
)
RETURNS SETOF TIMESTAMP AS $$
DECLARE
  ordinal INTEGER;
  day_of_week _rrule.DAY;
  month_end TIMESTAMP;
  all_occurrences TIMESTAMP[];
  target_index INTEGER;
BEGIN
  -- Extract ordinal and day from byday_value
  ordinal := _rrule.extract_byday_ordinal(byday_value);
  day_of_week := _rrule.extract_byday_day(byday_value);

  month_end := month_start + INTERVAL '1 month' - INTERVAL '1 second';

  -- If no ordinal, return all occurrences of that weekday in the month
  IF ordinal IS NULL THEN
    RETURN QUERY
    SELECT d
    FROM generate_series(month_start, month_end, INTERVAL '1 day') d
    WHERE d::_rrule.DAY = day_of_week;
    RETURN;
  END IF;

  -- Collect all occurrences of this day in the month
  SELECT array_agg(d ORDER BY d) INTO all_occurrences
  FROM generate_series(month_start, month_end, INTERVAL '1 day') d
  WHERE d::_rrule.DAY = day_of_week;

  -- Calculate target index (1-based)
  IF ordinal > 0 THEN
    target_index := ordinal;
  ELSE
    target_index := array_length(all_occurrences, 1) + ordinal + 1;
  END IF;

  -- Return the nth occurrence if it exists
  IF target_index >= 1 AND target_index <= array_length(all_occurrences, 1) THEN
    RETURN NEXT all_occurrences[target_index];
  END IF;

  RETURN;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
