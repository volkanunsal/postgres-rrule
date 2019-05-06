CREATE OR REPLACE FUNCTION _rrule.contains_timestamp(_rrule.rruleset, TIMESTAMP)
RETURNS BOOLEAN AS $$
DECLARE
  isEmpty boolean;
BEGIN
  SELECT COUNT(*) > 0
  INTO isEmpty
  FROM _rrule.after($1, $2);
  RETURN isEmpty;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
