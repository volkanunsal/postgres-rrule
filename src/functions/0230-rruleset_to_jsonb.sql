CREATE OR REPLACE FUNCTION _rrule.rruleset_to_jsonb("input" _rrule.RRULESET)
RETURNS jsonb AS $$
DECLARE
  rrule jsonb;
  exrule jsonb;
BEGIN
  SELECT _rrule.rrule_to_jsonb("input"."rrule")
  INTO rrule;

  SELECT _rrule.rrule_to_jsonb("input"."exrule")
  INTO exrule;

  RETURN jsonb_strip_nulls(jsonb_build_object(
    'dtstart', "input"."dtstart",
    'dtend', "input"."dtend",
    'rrule', rrule,
    'exrule', exrule,
    'rdate', "input"."rdate",
    'exdate', "input"."exdate"
  ));
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
