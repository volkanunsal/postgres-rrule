CREATE OR REPLACE FUNCTION _rrule.rruleset (TEXT)
RETURNS _rrule.RRULESET AS $$
  WITH "start" AS (
      SELECT * FROM regexp_split_to_table(
        regexp_replace(
          regexp_replace(
            $1::text,
            'RRULE:.*',
            ''
          ),
          'DTSTART.*:',
          ''
        ),
        ';'
      ) "date"
  ),
  candidate_rruleset AS (
      SELECT
        (SELECT "date"::timestamp FROM "start" LIMIT 1) AS "dtstart"
  )
  SELECT
    "dtstart",
    ARRAY[_rrule.rrule($1)] "rrule",
    ARRAY[]::_rrule.RRULE[] "exrule",
    NULL::TIMESTAMP[] "rdate",
    NULL::TIMESTAMP[] "exdate",
    NULL::TEXT "timezone"
  FROM candidate_rruleset
$$ LANGUAGE SQL IMMUTABLE STRICT;

