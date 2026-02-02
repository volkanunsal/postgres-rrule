CREATE OR REPLACE FUNCTION _rrule.jsonb_to_rruleset_array("input" jsonb)
RETURNS _rrule.RRULESET[] AS $$
  SELECT COALESCE(array_agg(_rrule.jsonb_to_rruleset(item)), '{}'::_rrule.RRULESET[])
  FROM jsonb_array_elements("input") AS item;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
