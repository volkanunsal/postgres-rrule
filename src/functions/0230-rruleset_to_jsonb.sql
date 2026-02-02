CREATE OR REPLACE FUNCTION _rrule.rruleset_to_jsonb("input" _rrule.RRULESET)
RETURNS jsonb AS $$
DECLARE
  rrule_array jsonb;
  exrule_array jsonb;
BEGIN
  -- Convert RRULE array to JSONB array
  IF "input"."rrule" IS NOT NULL AND array_length("input"."rrule", 1) > 0 THEN
    SELECT jsonb_agg(_rrule.rrule_to_jsonb(r))
    INTO rrule_array
    FROM unnest("input"."rrule") AS r;
  END IF;

  -- Convert EXRULE array to JSONB array
  IF "input"."exrule" IS NOT NULL AND array_length("input"."exrule", 1) > 0 THEN
    SELECT jsonb_agg(_rrule.rrule_to_jsonb(e))
    INTO exrule_array
    FROM unnest("input"."exrule") AS e;
  END IF;

  RETURN jsonb_strip_nulls(jsonb_build_object(
    'dtstart', "input"."dtstart",
    'dtend', "input"."dtend",
    'rrule', rrule_array,
    'exrule', exrule_array,
    'rdate', "input"."rdate",
    'exdate', "input"."exdate"
  ));
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
