-- Helper function to check if an RRULE has any BY* parameters set.
-- Used for BYSETPOS validation which requires at least one other BY* parameter.
CREATE OR REPLACE FUNCTION _rrule.has_any_by_rule(r _rrule.RRULE)
RETURNS BOOLEAN AS $$
  SELECT (
    r."bymonth" IS NOT NULL OR
    r."byweekno" IS NOT NULL OR
    r."byyearday" IS NOT NULL OR
    r."bymonthday" IS NOT NULL OR
    r."byday" IS NOT NULL OR
    r."byhour" IS NOT NULL OR
    r."byminute" IS NOT NULL OR
    r."bysecond" IS NOT NULL
  );
$$ LANGUAGE SQL IMMUTABLE STRICT;
