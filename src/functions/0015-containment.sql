-- rrule containment.
-- intervals must be compatible.
-- wkst must match
-- all other fields must have $2's value(s) in $1.
CREATE OR REPLACE FUNCTION _rrule.contains(_rrule.RRULE, _rrule.RRULE)
RETURNS BOOLEAN AS $$
  WITH intervals AS (
    SELECT
      _rrule.build_interval($1) AS interval1,
      _rrule.build_interval($2) AS interval2
  )
  SELECT _rrule.interval_contains(interval1, interval2)
    AND COALESCE($1."wkst" = $2."wkst", true)
  FROM intervals;
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION _rrule.contained_by(_rrule.RRULE, _rrule.RRULE)
RETURNS BOOLEAN AS $$
  SELECT _rrule.contains($2, $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
