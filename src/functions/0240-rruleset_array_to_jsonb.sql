CREATE OR REPLACE FUNCTION _rrule.rruleset_array_to_jsonb("input" _rrule.RRULESET[])
RETURNS jsonb AS $$
DECLARE
  item _rrule.RRULESET;
  out jsonb := '[]'::jsonb;
BEGIN
  FOREACH item IN ARRAY "input" LOOP
    out := (SELECT out || _rrule.rruleset_to_jsonb(item));
  END LOOP;

  RETURN out;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
