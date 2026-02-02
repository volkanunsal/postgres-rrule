-- Check if an array of RRULESETs has at least one finite occurrence
CREATE OR REPLACE FUNCTION _rrule.is_finite("rruleset_array" _rrule.RRULESET[])
RETURNS BOOLEAN AS $$
  SELECT COALESCE(bool_or(_rrule.is_finite(r)), false)
  FROM unnest("rruleset_array") AS r;
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;
