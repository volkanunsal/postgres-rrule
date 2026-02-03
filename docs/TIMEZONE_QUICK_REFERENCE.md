# Timezone Support - Quick Reference

## Basic Usage

### Generate Timezone-Aware Occurrences

```sql
-- Basic usage
SELECT * FROM _rrule.occurrences_tz(
  _rrule.rrule('RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=4'),
  '2022-01-03T09:00:00'::timestamp,
  'America/New_York'
);

-- With date range filter
SELECT * FROM _rrule.occurrences_tz(
  _rrule.rrule('RRULE:FREQ=DAILY;COUNT=30'),
  '2022-01-01T14:00:00'::timestamp,
  'Europe/London',
  '[2022-01-01, 2022-01-15]'::tsrange
);

-- From RRULESET with stored tzid
SELECT * FROM _rrule.occurrences_tz(
  _rrule.rruleset('DTSTART;TZID=Asia/Tokyo:20220101T090000
  RRULE:FREQ=WEEKLY;BYDAY=TU,TH;COUNT=10')
);
```

## Parsing with Timezone

### Text Format (RFC 5545)

```sql
-- DTSTART with TZID parameter
SELECT _rrule.rruleset('DTSTART;TZID=Europe/Paris:20220101T150000
RRULE:FREQ=MONTHLY;BYMONTHDAY=1;COUNT=12');

-- Extract tzid
SELECT (_rrule.rruleset('DTSTART;TZID=Europe/Paris:20220101T150000
RRULE:FREQ=DAILY;COUNT=5')).tzid;
-- Returns: 'Europe/Paris'
```

### JSON Format

```sql
-- JSONB with tzid field
SELECT _rrule.jsonb_to_rruleset('{
  "dtstart": "2022-01-01T09:00:00",
  "tzid": "America/Chicago",
  "rrule": [{
    "freq": "WEEKLY",
    "byday": ["MO", "WE", "FR"],
    "count": 20
  }]
}'::jsonb);

-- Convert back to JSON (includes tzid)
SELECT _rrule.rruleset_to_jsonb(your_rruleset);
```

## Common Patterns

### Next Occurrence After Now

```sql
WITH tz_occurrences AS (
  SELECT _rrule.occurrences_tz(
    _rrule.rrule('RRULE:FREQ=DAILY;COUNT=365'),
    '2022-01-01T10:00:00'::timestamp,
    'America/Los_Angeles'
  ) as occurrence
)
SELECT occurrence
FROM tz_occurrences
WHERE occurrence > NOW()
ORDER BY occurrence
LIMIT 1;
```

### Display in Multiple Timezones

```sql
WITH utc_times AS (
  SELECT _rrule.occurrences_tz(
    _rrule.rrule('RRULE:FREQ=WEEKLY;BYDAY=TU;COUNT=4'),
    '2022-01-04T14:00:00'::timestamp,
    'UTC'
  ) as utc
)
SELECT
  utc,
  utc AT TIME ZONE 'America/New_York' as new_york,
  utc AT TIME ZONE 'Europe/London' as london,
  utc AT TIME ZONE 'Asia/Tokyo' as tokyo
FROM utc_times;
```

### Working Hours in Local Timezone

```sql
-- Daily standup at 9:00 AM local time, Monday-Friday
SELECT * FROM _rrule.occurrences_tz(
  _rrule.jsonb_to_rruleset('{
    "dtstart": "2022-01-03T09:00:00",
    "tzid": "America/Denver",
    "rrule": [{
      "freq": "DAILY",
      "byday": ["MO","TU","WE","TH","FR"],
      "count": 50
    }]
  }'::jsonb)
) LIMIT 10;
```

### Events Table with Timezone

```sql
-- Create table
CREATE TABLE events (
  id SERIAL PRIMARY KEY,
  name TEXT,
  recurrence _rrule.RRULESET,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert with timezone
INSERT INTO events (name, recurrence) VALUES (
  'Weekly Team Meeting',
  _rrule.jsonb_to_rruleset('{
    "dtstart": "2022-01-10T10:00:00",
    "tzid": "America/New_York",
    "rrule": [{"freq": "WEEKLY", "byday": ["MO"], "count": 52}]
  }'::jsonb)
);

-- Query next 5 occurrences
SELECT
  name,
  _rrule.occurrences_tz(recurrence) as occurrence_utc,
  _rrule.occurrences_tz(recurrence) AT TIME ZONE (recurrence).tzid as occurrence_local
FROM events
WHERE name = 'Weekly Team Meeting'
LIMIT 5;
```

## DST Examples

### Spring Forward (March, US)

```sql
-- Event at 9:00 AM EST/EDT crossing spring DST
SELECT * FROM _rrule.occurrences_tz(
  _rrule.rrule('RRULE:FREQ=WEEKLY;BYDAY=SU;COUNT=4'),
  '2022-03-06T09:00:00'::timestamp,
  'America/New_York'
);

-- Results show UTC time shift:
-- 2022-03-06 14:00:00+00 (09:00 EST, UTC-5)
-- 2022-03-13 13:00:00+00 (09:00 EDT, UTC-4) ← DST starts
-- 2022-03-20 13:00:00+00 (09:00 EDT, UTC-4)
-- 2022-03-27 13:00:00+00 (09:00 EDT, UTC-4)
```

### Fall Back (October/November, Europe)

```sql
-- Event at 5:00 AM crossing fall DST in Europe
SELECT * FROM _rrule.occurrences_tz(
  _rrule.rrule('RRULE:FREQ=WEEKLY;BYDAY=WE;COUNT=3'),
  '2022-10-26T05:00:00'::timestamp,
  'Europe/Belgrade'
);

-- Results show UTC time shift:
-- 2022-10-26 03:00:00+00 (05:00 CEST, UTC+2)
-- 2022-11-02 04:00:00+00 (05:00 CET, UTC+1) ← DST ends
-- 2022-11-09 04:00:00+00 (05:00 CET, UTC+1)
```

## Timezone Names

### Common Timezones

```sql
-- US
'America/New_York'      -- EST/EDT
'America/Chicago'       -- CST/CDT
'America/Denver'        -- MST/MDT
'America/Los_Angeles'   -- PST/PDT

-- Europe
'Europe/London'         -- GMT/BST
'Europe/Paris'          -- CET/CEST
'Europe/Berlin'         -- CET/CEST
'Europe/Moscow'         -- MSK

-- Asia
'Asia/Tokyo'            -- JST
'Asia/Shanghai'         -- CST
'Asia/Dubai'            -- GST
'Asia/Kolkata'          -- IST

-- Australia
'Australia/Sydney'      -- AEDT/AEST
'Australia/Melbourne'   -- AEDT/AEST
```

### List All Available Timezones

```sql
-- Get all timezone names
SELECT name FROM pg_timezone_names
WHERE name LIKE 'America/%' OR name LIKE 'Europe/%'
ORDER BY name;

-- Count timezones by region
SELECT
  split_part(name, '/', 1) as region,
  count(*) as count
FROM pg_timezone_names
WHERE name ~ '^[A-Z]'
GROUP BY region
ORDER BY count DESC;
```

## UNTIL Handling

```sql
-- UNTIL is always treated as UTC (RFC 5545 compliant)

-- With Z suffix (explicitly UTC)
SELECT _rrule.rrule('RRULE:FREQ=DAILY;UNTIL=20221231T235959Z');

-- Without Z (still treated as UTC)
SELECT _rrule.rrule('RRULE:FREQ=DAILY;UNTIL=20221231T235959');

-- Text output always includes Z
SELECT _rrule.text(_rrule.rrule('RRULE:FREQ=DAILY;UNTIL=20221231T235959'));
-- Returns: 'RRULE:FREQ=DAILY;UNTIL=20221231T235959Z'
```

## Backward Compatibility

```sql
-- Old functions still work (naive timestamps)
SELECT * FROM _rrule.occurrences(
  _rrule.rruleset('DTSTART:20220101T090000
  RRULE:FREQ=DAILY;COUNT=5')
);
-- Returns: TIMESTAMP (no timezone)

-- New functions for timezone support
SELECT * FROM _rrule.occurrences_tz(
  _rrule.rruleset('DTSTART;TZID=UTC:20220101T090000
  RRULE:FREQ=DAILY;COUNT=5')
);
-- Returns: TIMESTAMPTZ (with timezone)
```

## Error Handling

### Invalid Timezone

```sql
-- ❌ Will error
SELECT _rrule.occurrences_tz(
  _rrule.rrule('RRULE:FREQ=DAILY;COUNT=1'),
  '2022-01-01T09:00:00'::timestamp,
  'Invalid/Timezone'
);
-- ERROR: time zone "Invalid/Timezone" not recognized

-- ✓ Use valid timezone
SELECT _rrule.occurrences_tz(
  _rrule.rrule('RRULE:FREQ=DAILY;COUNT=1'),
  '2022-01-01T09:00:00'::timestamp,
  'America/New_York'
);
```

### Missing TZID in RRULESET

```sql
-- ❌ Will error if tzid is NULL
SELECT _rrule.occurrences_tz(
  _rrule.rruleset('DTSTART:20220101T090000
  RRULE:FREQ=DAILY;COUNT=1')
);
-- ERROR: RRULESET must have tzid field set

-- ✓ Provide tzid explicitly
SELECT _rrule.occurrences_tz(
  (my_rruleset."rrule")[1],
  my_rruleset."dtstart",
  'America/New_York'
);

-- ✓ Or use naive occurrences()
SELECT _rrule.occurrences(my_rruleset);
```

## Performance Tips

```sql
-- Use COUNT to limit occurrences
SELECT _rrule.occurrences_tz(
  _rrule.rrule('RRULE:FREQ=DAILY;COUNT=30'),  -- Limit to 30
  dtstart, tzid
) LIMIT 30;

-- Use date range filters
SELECT _rrule.occurrences_tz(
  rrule, dtstart, tzid,
  '[2022-01-01, 2022-12-31]'::tsrange
);

-- Index occurrence results if storing
CREATE INDEX idx_occurrence ON my_occurrences_table
USING btree (occurrence_time);
```

## See Full Documentation

For comprehensive documentation, see:
- [docs/TIMEZONE_SUPPORT.md](TIMEZONE_SUPPORT.md) - Complete guide
- [README.md](../README.md) - Main project README
- [RFC 5545](https://tools.ietf.org/html/rfc5545) - iCalendar specification
