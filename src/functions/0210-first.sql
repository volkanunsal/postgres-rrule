
CREATE OR REPLACE FUNCTION _rrule.first("rrule" _rrule.RRULE, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$

  SELECT "ts"
  FROM _rrule.all_starts("rrule", "dtstart") "ts"
  ORDER BY "ts"
  LIMIT 1;

$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.first("rrule" TEXT, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$
  SELECT _rrule.first(_rrule.rrule("rrule"), "dtstart");
$$ LANGUAGE SQL STRICT IMMUTABLE;



CREATE OR REPLACE FUNCTION _rrule.first("rruleset" _rrule.RRULE)
RETURNS TIMESTAMP AS $$
  SELECT now()::TIMESTAMP;
$$ LANGUAGE SQL STRICT IMMUTABLE;

