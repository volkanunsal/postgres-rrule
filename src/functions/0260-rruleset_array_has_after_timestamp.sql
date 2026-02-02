CREATE OR REPLACE FUNCTION _rrule.rruleset_array_has_after_timestamp(_rrule.RRULESET[], TIMESTAMP)
RETURNS BOOLEAN AS $$
  SELECT EXISTS(
    SELECT 1
    FROM unnest($1) AS item
    WHERE EXISTS(SELECT 1 FROM _rrule.after(item, $2) LIMIT 1)
  );
$$ LANGUAGE SQL IMMUTABLE STRICT;
