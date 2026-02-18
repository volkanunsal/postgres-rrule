CREATE OR REPLACE FUNCTION _rrule.parse_line (input TEXT, marker TEXT)
RETURNS SETOF TEXT AS $$
  -- Clear spaces at the front of the lines
  WITH trimmed_input as (SELECT regexp_replace(input, '^[ \t]*',  '', 'ng') "r"),
  -- Clear all lines except the ones starting with marker
  filtered_lines as (SELECT regexp_replace(trimmed_input."r", '^(?!' || marker || ').*?$',  '', 'ng') "r" FROM trimmed_input),
  -- Replace carriage returns with blank space.
  normalized_text as (SELECT regexp_replace(filtered_lines."r", E'[\\n\\r]+',  '', 'g') "r" FROM filtered_lines),
  -- Remove marker prefix.
  marker_removed as (SELECT regexp_replace(normalized_text."r", marker || ':(.*)$', '\1') "r" FROM normalized_text),
  -- Trim
  trimmed_result as (SELECT trim(marker_removed."r") "r" FROM marker_removed),
  -- Split each key-value pair into a row in a table
  split_pairs as (SELECT regexp_split_to_table(trimmed_result."r", ';') "r" FROM trimmed_result)
  -- Split each key value pair into an array, e.g. {'FREQ', 'DAILY'}
  SELECT "r" AS "y"
  FROM split_pairs
  WHERE "r" != '';
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
