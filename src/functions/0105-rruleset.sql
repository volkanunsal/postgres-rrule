CREATE OR REPLACE FUNCTION _rrule.rruleset (TEXT)
RETURNS _rrule.RRULESET AS $$
  WITH "dtstart-line" AS (SELECT _rrule.parse_line($1::text, 'DTSTART') as "x"),
  "dtend-line" AS (SELECT _rrule.parse_line($1::text, 'DTEND') as "x"),
  "exrule-line" AS (SELECT _rrule.parse_line($1::text, 'EXRULE') as "x"),
  "rdate-line" AS (SELECT _rrule.parse_line($1::text, 'RDATE') as "x"),
  "exdate-line" AS (SELECT _rrule.parse_line($1::text, 'EXDATE') as "x")
  SELECT
    (SELECT "x"::timestamp FROM "dtstart-line" LIMIT 1) AS "dtstart",
    (SELECT "x"::timestamp FROM "dtend-line" LIMIT 1) AS "dtend",
    (SELECT _rrule.rrule($1::text) "rrule") as "rrule",
    (SELECT _rrule.rrule("x"::text) "rrule" FROM "exrule-line") as "exrule",
    (SELECT (regexp_split_to_array("x"::text, ','))::TIMESTAMP[] from "rdate-line" AS "rdate"),
    (SELECT (regexp_split_to_array("x"::text, ','))::TIMESTAMP[] from "exdate-line" AS "exdate");
$$ LANGUAGE SQL IMMUTABLE STRICT;
