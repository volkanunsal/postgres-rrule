CREATE OR REPLACE FUNCTION _rrule.until("rrule" _rrule.RRULE, "dtstart" TIMESTAMP)
RETURNS TIMESTAMP AS $$
  SELECT min("until")
  FROM (
    SELECT "rrule"."until"
    UNION
    SELECT "dtstart" + _rrule.build_interval("rrule"."interval", "rrule"."freq") * COALESCE("rrule"."count", 1000, CASE WHEN "rrule"."until" IS NOT NULL THEN NULL ELSE 1 END) AS "until"
  ) "until" GROUP BY ();

$$ LANGUAGE SQL IMMUTABLE STRICT;
COMMENT ON FUNCTION _rrule.until(_rrule.RRULE, TIMESTAMP) IS 'The calculated "until"" timestamp for the given rrule+dtstart';

