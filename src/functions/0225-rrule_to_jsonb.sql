CREATE OR REPLACE FUNCTION _rrule.rrule_to_jsonb("input" _rrule.RRULE)
RETURNS jsonb AS $$
BEGIN
  RETURN jsonb_strip_nulls(jsonb_build_object(
    'freq', "input"."freq",
    'interval', "input"."interval",
    'count', "input"."count",
    'until', "input"."until",
    'bysecond', "input"."bysecond",
    'byminute', "input"."byminute",
    'byhour', "input"."byhour",
    'byday', "input"."byday",
    'bymonthday', "input"."bymonthday",
    'byyearday', "input"."byyearday",
    'byweekno', "input"."byweekno",
    'bymonth', "input"."bymonth",
    'bysetpos', "input"."bysetpos",
    'wkst', "input"."wkst"
  ));
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
