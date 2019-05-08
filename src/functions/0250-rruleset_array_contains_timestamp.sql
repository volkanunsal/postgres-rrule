CREATE OR REPLACE FUNCTION _rrule.rruleset_array_contains_timestamp(_rrule.RRULESET[], TIMESTAMP)
RETURNS BOOLEAN AS $$
DECLARE
  item _rrule.RRULESET;
BEGIN
  FOREACH item IN ARRAY $1
  LOOP
    IF (SELECT _rrule.contains_timestamp(item, $2)) THEN
      RETURN true;
    END IF;
  END LOOP;

  RETURN false;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
