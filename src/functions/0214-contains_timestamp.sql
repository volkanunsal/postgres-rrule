CREATE OR REPLACE FUNCTION _rrule.contains_timestamp(_rrule.rruleset, TIMESTAMP)
RETURNS BOOLEAN AS $$
DECLARE
  isEmpty boolean;
BEGIN
  SELECT COUNT(*) > 0
  INTO isEmpty
  FROM _rrule.after($1, $2 - INTERVAL '1 month') "ts"
  WHERE "ts"::date = $2::date;

  RETURN isEmpty;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
