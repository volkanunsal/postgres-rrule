-- Check if an array of RRULEs has at least one finite recurrence
CREATE OR REPLACE FUNCTION _rrule.is_finite("rrule_array" _rrule.RRULE[])
RETURNS BOOLEAN AS $$
  SELECT COALESCE(bool_or(_rrule.is_finite(r)), false)
  FROM unnest("rrule_array") AS r;
$$ LANGUAGE SQL STRICT IMMUTABLE PARALLEL SAFE;
