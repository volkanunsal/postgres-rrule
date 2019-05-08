CREATE OR REPLACE FUNCTION _rrule.jsonb_to_rruleset_array("input" jsonb)
RETURNS _rrule.RRULESET[] AS $$
DECLARE
  item jsonb;
  out _rrule.RRULESET[] := '{}'::_rrule.RRULESET[];
BEGIN
  FOR item IN SELECT * FROM jsonb_array_elements("input")
  LOOP
    out := (SELECT out || _rrule.jsonb_to_rruleset(item));
  END LOOP;

  RETURN out;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
