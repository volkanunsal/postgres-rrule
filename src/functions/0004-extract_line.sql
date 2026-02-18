-- Extracts a line value from multiline input without splitting on semicolons.
-- Similar to parse_line but returns the complete value as a single string.
--
-- Parameters:
--   input - Multiline text input
--   marker - Line prefix to search for (e.g., 'EXRULE', 'RRULE')
--
-- Returns: The value after the marker prefix, or NULL if not found
CREATE OR REPLACE FUNCTION _rrule.extract_line (input TEXT, marker TEXT)
RETURNS TEXT AS $$
  -- Clear spaces at the front of the lines
  WITH trimmed_input as (SELECT regexp_replace(input, '^[ \t]*',  '', 'ng') "r"),
  -- Clear all lines except the ones starting with marker
  filtered_lines as (SELECT regexp_replace(trimmed_input."r", '^(?!' || marker || ').*?$',  '', 'ng') "r" FROM trimmed_input),
  -- Replace carriage returns with blank space.
  normalized_text as (SELECT regexp_replace(filtered_lines."r", E'[\\n\\r]+',  '', 'g') "r" FROM filtered_lines),
  -- Remove marker prefix.
  marker_removed as (SELECT regexp_replace(normalized_text."r", marker || ':(.*)$', '\1') "r" FROM normalized_text),
  -- Trim
  trimmed_result as (SELECT trim(marker_removed."r") "r" FROM marker_removed)
  SELECT "r"
  FROM trimmed_result
  WHERE "r" != '';
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;
