-- All of the function(rrule, ...) forms also accept a text argument, which will
-- be parsed using the RFC-compliant parser.

CREATE OR REPLACE FUNCTION _rrule.is_finite("rrule" _rrule.RRULE)
RETURNS BOOLEAN AS $$
  SELECT "rrule"."count" IS NOT NULL OR "rrule"."until" IS NOT NULL;
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.is_finite("rrule" TEXT)
RETURNS BOOLEAN AS $$
  SELECT _rrule.is_finite(_rrule.rrule("rrule"));
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.is_finite("rruleset" _rrule.RRULESET)
RETURNS BOOLEAN AS $$
  SELECT _rrule.is_finite("rruleset"."rrule")
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION _rrule.is_finite("rruleset_array" _rrule.RRULESET[])
RETURNS BOOLEAN AS $$
DECLARE
  item _rrule.RRULESET;
BEGIN
  FOREACH item IN ARRAY "rruleset_array" LOOP
    IF (SELECT _rrule.is_finite(item)) THEN
      RETURN true;
    END IF;
  END LOOP;
  RETURN false;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;


