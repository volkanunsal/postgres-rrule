CREATE CAST (TEXT AS _rrule.RRULE)
  WITH FUNCTION _rrule.rrule(TEXT)
  AS IMPLICIT;


CREATE CAST (TEXT AS _rrule.RRULESET)
  WITH FUNCTION _rrule.rruleset(TEXT)
  AS IMPLICIT;



CREATE CAST (jsonb AS _rrule.RRULE)
  WITH FUNCTION _rrule.jsonb_to_rrule(jsonb)
  AS IMPLICIT;


CREATE CAST (_rrule.RRULE AS jsonb)
  WITH FUNCTION _rrule.rrule_to_jsonb(_rrule.RRULE)
  AS IMPLICIT;


-- CREATE CAST (jsonb AS _rrule.RRULESET)
--   WITH FUNCTION _rrule.jsonb_to_rruleset(jsonb)
--   AS IMPLICIT;

-- CREATE CAST (_rrule.RRULESET AS jsonb)
--   WITH FUNCTION _rrule.rruleset_to_jsonb(_rrule.RRULESET)
--   AS IMPLICIT;


-- CREATE CAST (jsonb AS _rrule.RRULESET[])
--   WITH FUNCTION _rrule.jsonb_to_rruleset_array(jsonb)
--   AS IMPLICIT;


-- CREATE CAST (_rrule.RRULESET[] AS jsonb)
--   WITH FUNCTION _rrule.rruleset_array_to_jsonb(_rrule.RRULESET[])
--   AS IMPLICIT;

