CREATE OR REPLACE FUNCTION _rrule.rruleset_array_to_jsonb("input" _rrule.RRULESET[])
RETURNS jsonb AS $$
  SELECT COALESCE(jsonb_agg(_rrule.rruleset_to_jsonb(item)), '[]'::jsonb)
  FROM unnest("input") AS item;
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
