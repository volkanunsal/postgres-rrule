CREATE OR REPLACE FUNCTION _rrule.build_interval("interval" INTEGER, "freq" _rrule.FREQ)
RETURNS INTERVAL AS $$
DECLARE
  result INTERVAL;
BEGIN
  -- Validate interval to prevent overflow (PostgreSQL supports intervals up to ~178M years)
  -- For practical RRULE usage, limit to 1 million to prevent arithmetic issues
  IF "interval" < 1 OR "interval" > 1000000 THEN
    RAISE EXCEPTION 'INTERVAL value % is out of valid range (1 to 1,000,000).', "interval";
  END IF;

  -- Transform ical time interval enums into Postgres intervals, e.g.
  -- "WEEKLY" becomes "WEEKS".
  result := ("interval" || ' ' || regexp_replace(regexp_replace("freq"::TEXT, 'LY', 'S'), 'IS', 'YS'))::INTERVAL;

  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;


CREATE OR REPLACE FUNCTION _rrule.build_interval(_rrule.RRULE)
RETURNS INTERVAL AS $$
  SELECT _rrule.build_interval(COALESCE($1."interval", 1), $1."freq");
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
