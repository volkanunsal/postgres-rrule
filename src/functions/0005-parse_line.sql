CREATE OR REPLACE FUNCTION _rrule.parse_line (input TEXT, marker TEXT)
RETURNS SETOF TEXT AS $$
  -- Clear all lines except the ones starting with marker
  WITH A5 as (SELECT regexp_replace(input, '^(?!' || marker || ').*?$',  '', 'ng') "r"),
  -- Replace carriage returns with blank space.
  A10 as (SELECT regexp_replace(A5."r", E'[\\n\\r]+',  '', 'g') "r" FROM A5),
  -- Remove marker prefix.
  A15 as (SELECT regexp_replace(A10."r", marker || '.*:', '') "r" FROM A10),
  -- Split each key-value pair into a row in a table
  A20 as (SELECT regexp_split_to_table(A15."r", ';') "r" FROM A15)
  -- Split each key value pair into an array, e.g. {'FREQ', 'DAILY'}
  SELECT "r" AS "y" FROM A20
$$ LANGUAGE SQL IMMUTABLE STRICT;
