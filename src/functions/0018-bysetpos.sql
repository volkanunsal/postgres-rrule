CREATE OR REPLACE FUNCTION _rrule.bysetpos("rrule" _rrule.RRULE)
RETURNS INTEGER[] AS $$
    SELECT "rrule"."bysetpos";

$$ LANGUAGE SQL IMMUTABLE STRICT;
COMMENT ON FUNCTION _rrule.bysetpos(_rrule.RRULE) IS 'The calculated "bysetpos"" int[] for the given rrule';