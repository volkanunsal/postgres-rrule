

CREATE OR REPLACE FUNCTION _rrule.last("rrule" _rrule.RRULE, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$
  SELECT occurrence
  FROM _rrule.occurrences("rrule", "dtstart") occurrence
  ORDER BY occurrence DESC LIMIT 1;
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.last("rrule" TEXT, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$
  SELECT _rrule.last(_rrule.rrule("rrule"), "dtstart");
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.last("rruleset" _rrule.RRULESET)
RETURNS TIMESTAMP AS $$
  SELECT occurrence
  FROM _rrule.occurrences("rruleset") occurrence
  ORDER BY occurrence DESC LIMIT 1;
$$ LANGUAGE SQL STRICT IMMUTABLE;

-- TODO: Ensure to check whether the range is finite. If not, we should return null
-- or something meaningful.
CREATE OR REPLACE FUNCTION _rrule.last("rruleset_array" _rrule.RRULESET[])
RETURNS SETOF TIMESTAMP AS $$
BEGIN
  IF (SELECT _rrule.is_finite("rruleset_array")) THEN
    RETURN QUERY SELECT occurrence
    FROM _rrule.occurrences("rruleset_array", '(,)'::TSRANGE) occurrence
    ORDER BY occurrence DESC LIMIT 1;
  ELSE
    RETURN QUERY SELECT NULL::TIMESTAMP;
  END IF;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

