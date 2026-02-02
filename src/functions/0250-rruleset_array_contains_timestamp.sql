CREATE OR REPLACE FUNCTION _rrule.rruleset_array_contains_timestamp(_rrule.RRULESET[], TIMESTAMP)
RETURNS BOOLEAN AS $$
  SELECT COALESCE(bool_or(_rrule.contains_timestamp(item, $2)), false)
  FROM unnest($1) AS item;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
