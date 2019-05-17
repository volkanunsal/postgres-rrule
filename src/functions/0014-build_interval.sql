CREATE OR REPLACE FUNCTION _rrule.build_interval("interval" INTEGER, "freq" _rrule.FREQ)
RETURNS INTERVAL AS $$
  -- Transform ical time interval enums into Postgres intervals, e.g.
  -- "WEEKLY" becomes "WEEKS".
  SELECT ("interval" || ' ' || regexp_replace(regexp_replace("freq"::TEXT, 'LY', 'S'), 'IS', 'YS'))::INTERVAL;
$$ LANGUAGE SQL IMMUTABLE STRICT;


CREATE OR REPLACE FUNCTION _rrule.build_interval(_rrule.RRULE)
RETURNS INTERVAL AS $$
  SELECT _rrule.build_interval(COALESCE($1."interval", 1), $1."freq");
$$ LANGUAGE SQL IMMUTABLE STRICT;
