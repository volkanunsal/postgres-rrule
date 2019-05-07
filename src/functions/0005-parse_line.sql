CREATE OR REPLACE FUNCTION _rrule.parse_line (input TEXT, marker TEXT)
RETURNS SETOF TEXT AS $$
  -- Clear spaces at the front of the lines
  WITH A4 as (SELECT regexp_replace(input, '^\s*',  '', 'ng') "r"),
  -- Clear all lines except the ones starting with marker
  A5 as (SELECT regexp_replace(A4."r", '^(?!' || marker || ').*?$',  '', 'ng') "r" FROM A4),
  -- Replace carriage returns with blank space.
  A10 as (SELECT regexp_replace(A5."r", E'[\\n\\r]+',  '', 'g') "r" FROM A5),
  -- Remove marker prefix.
  A15 as (SELECT regexp_replace(A10."r", marker || ':(.*)$', '\1') "r" FROM A10),
  -- Trim
  A17 as (SELECT trim(A15."r") "r" FROM A15),
  -- Split each key-value pair into a row in a table
  A20 as (SELECT regexp_split_to_table(A17."r", ';') "r" FROM A17)
  -- Split each key value pair into an array, e.g. {'FREQ', 'DAILY'}
  SELECT "r" AS "y"
  FROM A20
  WHERE "r" != '';
$$ LANGUAGE SQL IMMUTABLE STRICT;
