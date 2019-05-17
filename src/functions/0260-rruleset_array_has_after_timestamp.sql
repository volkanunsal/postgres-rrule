CREATE OR REPLACE FUNCTION _rrule.rruleset_array_has_after_timestamp(_rrule.RRULESET[], TIMESTAMP)
RETURNS BOOLEAN AS $$
DECLARE
  item _rrule.RRULESET;
BEGIN
  FOREACH item IN ARRAY $1
  LOOP
    IF (SELECT count(*) > 0 FROM _rrule.after(item, $2) LIMIT 1) THEN
      RETURN true;
    END IF;
  END LOOP;

  RETURN false;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
