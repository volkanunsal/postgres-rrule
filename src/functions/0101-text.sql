
CREATE OR REPLACE FUNCTION _rrule.text(_rrule.RRULE)
RETURNS TEXT AS $$
  SELECT regexp_replace(
    'RRULE:'
    || COALESCE('FREQ=' || $1."freq" || ';', '')
    || CASE WHEN $1."interval" = 1 THEN '' ELSE COALESCE('INTERVAL=' || $1."interval" || ';', '') END
    || COALESCE('COUNT=' || $1."count" || ';', '')
    || COALESCE('UNTIL=' || TO_CHAR($1."until", 'YYYYMMDD"T"HH24MISS"Z"') || ';', '')
    || COALESCE('BYSECOND=' || _rrule.array_join($1."bysecond", ',') || ';', '')
    || COALESCE('BYMINUTE=' || _rrule.array_join($1."byminute", ',') || ';', '')
    || COALESCE('BYHOUR=' || _rrule.array_join($1."byhour", ',') || ';', '')
    || COALESCE('BYDAY=' || _rrule.array_join($1."byday", ',') || ';', '')
    || COALESCE('BYMONTHDAY=' || _rrule.array_join($1."bymonthday", ',') || ';', '')
    || COALESCE('BYYEARDAY=' || _rrule.array_join($1."byyearday", ',') || ';', '')
    || COALESCE('BYWEEKNO=' || _rrule.array_join($1."byweekno", ',') || ';', '')
    || COALESCE('BYMONTH=' || _rrule.array_join($1."bymonth", ',') || ';', '')
    || COALESCE('BYSETPOS=' || _rrule.array_join($1."bysetpos", ',') || ';', '')
    || CASE WHEN $1."wkst" = 'MO' THEN '' ELSE COALESCE('WKST=' || $1."wkst" || ';', '') END
  , ';$', '');
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION _rrule.text("input" _rrule.RRULESET)
RETURNS TEXT AS $$
DECLARE
  rrule TEXT;
  exrule TEXT;
  l_rdate TEXT[];
  l_exdate TEXT[];
BEGIN
  SELECT _rrule.text("input"."rrule")
  INTO rrule;

  SELECT _rrule.text("input"."exrule")
  INTO exrule;
  
  SELECT array_agg(TO_CHAR(rdate, 'YYYYMMDD"T"HH24MISS"Z"')) FROM UNNEST("input"."rdate") as rdate INTO l_rdate;
  SELECT array_agg(TO_CHAR(exdate, 'YYYYMMDD"T"HH24MISS"Z"')) FROM UNNEST("input"."exdate") as exdate INTO l_exdate;

  RETURN
    COALESCE('DTSTART:' || TO_CHAR("input"."dtstart", 'YYYYMMDD"T"HH24MISS"Z"') || E'\n', '')
    || COALESCE('DTEND:' || CASE WHEN "input"."dtend" IS NOT NULL THEN TO_CHAR("input"."dtend", 'YYYYMMDD"T"HH24MISS"Z"') ELSE NULL END || E'\n', '')
    || COALESCE(rrule || E'\n', '')
    || COALESCE(exrule || E'\n', '')
    || COALESCE('RDATE:' || _rrule.array_join(l_rdate, ',') || E'\n', '')
    || COALESCE('EXDATE:' || _rrule.array_join(l_exdate, ',') || E'\n', '');
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION _rrule.text("input" _rrule.RRULESET, tzid TEXT)
RETURNS TEXT AS $$
DECLARE
  rrule TEXT;
  exrule TEXT;
  l_rdate TEXT[];
  l_exdate TEXT[];

  l_occurrence TIMESTAMPTZ;
  l_interval INTERVAL;
BEGIN
  SELECT _rrule.text("input"."rrule")
  INTO rrule;
  
  SELECT timezone('UTC', "input"."dtstart") INTO l_occurrence;
  SELECT (l_occurrence AT TIME ZONE tzid) - (l_occurrence AT TIME ZONE 'UTC') INTO l_interval;

  SELECT _rrule.text("input"."exrule")
  INTO exrule;
  
  SELECT array_agg(TO_CHAR( rdate, 'YYYYMMDD"T"HH24MISS')) FROM UNNEST("input"."rdate") as rdate INTO l_rdate;
  SELECT array_agg(TO_CHAR( exdate, 'YYYYMMDD"T"HH24MISS')) FROM UNNEST("input"."exdate") as exdate INTO l_exdate;

  RETURN
    COALESCE('DTSTART;TZID=' || tzid || ':' || TO_CHAR( "input"."dtstart", 'YYYYMMDD"T"HH24MISS') || E'\n', '')
    || COALESCE('DTEND:' || CASE WHEN "input"."dtend" IS NOT NULL THEN TO_CHAR("input"."dtend", 'YYYYMMDD"T"HH24MISS') ELSE NULL END || E'\n', '')
    || COALESCE(rrule || E'\n', '')
    || COALESCE(exrule || E'\n', '')
    || COALESCE('RDATE:' || _rrule.array_join(l_rdate, ',') || E'\n', '')
    || COALESCE('EXDATE:' || _rrule.array_join(l_exdate, ',') || E'\n', '');
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;