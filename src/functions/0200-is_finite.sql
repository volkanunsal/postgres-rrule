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
  -- All non-finite rrule objects have a counterpart in exrules that
  -- matches interval/frequency (or is a multiple of same).
  WITH non_finite AS (
    SELECT "rrule"
    FROM unnest("rruleset"."rrule") "rrule"
    WHERE NOT _rrule.is_finite("rrule")
  )
  SELECT FALSE;
$$ LANGUAGE SQL STRICT IMMUTABLE;



