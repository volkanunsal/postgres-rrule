CREATE OR REPLACE FUNCTION _rrule.contains_timestamp(_rrule.RRULESET, TIMESTAMP)
RETURNS BOOLEAN AS $$
DECLARE
  inSet boolean;
BEGIN
  SELECT COUNT(*) > 0
  INTO inSet
  FROM _rrule.after($1, $2 - INTERVAL '1 month') "ts"
  WHERE "ts"::date = $2::date;

  RETURN inSet;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
