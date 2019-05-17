CREATE OR REPLACE FUNCTION _rrule.rruleset_has_after_timestamp(_rrule.RRULESET, TIMESTAMP)
RETURNS BOOLEAN AS $$
  SELECT count(*) > 0 FROM _rrule.after($1, $2) LIMIT 1;
$$ LANGUAGE SQL IMMUTABLE STRICT;
