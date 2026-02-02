CREATE OR REPLACE FUNCTION _rrule.integer_array (TEXT)
RETURNS integer[] AS $$
  SELECT ('{' || $1 || '}')::integer[];
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
COMMENT ON FUNCTION _rrule.integer_array (text) IS 'Coerce a text string into an array of integers';



CREATE OR REPLACE FUNCTION _rrule.day_array (TEXT)
RETURNS TEXT[] AS $$
DECLARE
  result TEXT[];
  day_value TEXT;
BEGIN
  -- Split by comma and validate each day value
  FOREACH day_value IN ARRAY string_to_array($1, ',')
  LOOP
    -- Validate format: optional +/- and digits, followed by exactly 2 uppercase letters
    IF day_value !~ '^[+-]?\d*[A-Z]{2}$' THEN
      RAISE EXCEPTION 'Invalid BYDAY value: "%". Expected format: [+/-][ordinal]DAY (e.g., MO, 1TU, -1FR)', day_value;
    END IF;
    result := array_append(result, day_value);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
COMMENT ON FUNCTION _rrule.day_array (text) IS 'Parse BYDAY values with optional ordinal prefixes (e.g., MO, 1TU, 2MO, -1FR) into TEXT array';



CREATE OR REPLACE FUNCTION _rrule.array_join(ANYARRAY, "delimiter" TEXT)
RETURNS TEXT AS $$
  SELECT string_agg(x::text, "delimiter")
  FROM unnest($1) x;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

