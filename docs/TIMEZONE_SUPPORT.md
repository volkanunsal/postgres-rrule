# Timezone Support

The postgres-rrule extension provides comprehensive timezone support for handling recurring events across daylight saving time (DST) transitions. This feature ensures that events maintain their local time even when DST rules change.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [How It Works](#how-it-works)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Migration Guide](#migration-guide)
- [RFC 5545 Compliance](#rfc-5545-compliance)
- [Troubleshooting](#troubleshooting)

## Overview

### The Problem

Without timezone support, recurring events crossing DST boundaries can report incorrect times:

```sql
-- Event: "Every Wednesday at 5:00 AM Europe/Belgrade"
-- DST transition: 2022-10-30 (CEST → CET, UTC+2 → UTC+1)

-- Without timezone support (naive timestamps):
-- Oct 26: 05:00 (ambiguous - what timezone?)
-- Nov 02: 05:00 (ambiguous - what timezone?)

-- With timezone support (timezone-aware):
-- Oct 26: 05:00 CEST (UTC+2) = 03:00 UTC
-- Nov 02: 05:00 CET (UTC+1) = 04:00 UTC
```

The local time stays at 05:00, but the UTC representation correctly adjusts for the DST transition.

### The Solution

The extension provides:

1. **Timezone storage**: Store timezone identifiers (TZID) with recurrence rulesets
2. **Timezone-aware functions**: New `occurrences_tz()` functions that return `TIMESTAMPTZ` values
3. **RFC 5545 compliance**: Support for `DTSTART;TZID=...` format
4. **DST handling**: Automatic adjustment of UTC times across DST transitions
5. **Backward compatibility**: Existing functions unchanged

## Quick Start

### Using TZID in Text Format

```sql
-- Parse RRULESET with timezone
SELECT _rrule.rruleset('DTSTART;TZID=Europe/Belgrade:20221026T050000
RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=WE;COUNT=3');
```

### Using TZID in JSON Format

```sql
-- Parse RRULESET from JSON with timezone
SELECT _rrule.jsonb_to_rruleset('{
  "dtstart": "2022-10-26T05:00:00",
  "tzid": "Europe/Belgrade",
  "rrule": [{
    "freq": "WEEKLY",
    "byday": ["WE"],
    "count": 3
  }]
}'::jsonb);
```

### Generating Timezone-Aware Occurrences

```sql
-- Generate occurrences with timezone awareness
SELECT * FROM _rrule.occurrences_tz(
  _rrule.rrule('RRULE:FREQ=WEEKLY;BYDAY=WE;COUNT=3'),
  '2022-10-26T05:00:00'::timestamp,
  'Europe/Belgrade'
);

-- Returns TIMESTAMPTZ values:
-- 2022-10-26 03:00:00+00 (05:00 CEST = UTC+2)
-- 2022-11-02 04:00:00+00 (05:00 CET = UTC+1)
-- 2022-11-09 04:00:00+00 (05:00 CET = UTC+1)
```

## How It Works

### 1. Timezone Storage

The `RRULESET` type includes an optional `tzid` field:

```sql
CREATE TABLE _rrule.RRULESET (
  "dtstart" TIMESTAMP NOT NULL,
  "dtend" TIMESTAMP,
  "tzid" TEXT DEFAULT NULL,  -- Timezone identifier (e.g., 'Europe/Belgrade')
  "rrule" _rrule.RRULE[],
  "exrule" _rrule.RRULE[],
  "rdate" TIMESTAMP[],
  "exdate" TIMESTAMP[]
);
```

- `tzid` accepts any PostgreSQL timezone name (see `pg_timezone_names`)
- Examples: `'Europe/Belgrade'`, `'America/New_York'`, `'Asia/Tokyo'`
- `NULL` means naive timestamps (backward compatible)

### 2. UNTIL Handling

Per RFC 5545 recommendation, `UNTIL` values are always stored and interpreted as UTC:

```sql
-- UNTIL with Z suffix (explicitly UTC)
SELECT _rrule.rrule('RRULE:FREQ=DAILY;UNTIL=20221105T000000Z');
-- Stores: 2022-11-05 00:00:00 UTC

-- UNTIL without Z (still treated as UTC for consistency)
SELECT _rrule.rrule('RRULE:FREQ=DAILY;UNTIL=20221105T000000');
-- Stores: 2022-11-05 00:00:00 UTC
```

When using `occurrences_tz()`, UNTIL is compared in UTC against timezone-adjusted occurrence times.

### 3. DST Transition Handling

The `occurrences_tz()` function:

1. Generates occurrences in naive local time
2. Converts each occurrence to the specified timezone using `AT TIME ZONE`
3. Returns `TIMESTAMPTZ` values in UTC

PostgreSQL's timezone database handles DST transitions automatically:

```sql
-- Oct 26, 2022: CEST (UTC+2)
SELECT '2022-10-26T05:00:00'::timestamp AT TIME ZONE 'Europe/Belgrade';
-- Returns: 2022-10-26 03:00:00+00

-- Nov 02, 2022: CET (UTC+1) after DST transition
SELECT '2022-11-02T05:00:00'::timestamp AT TIME ZONE 'Europe/Belgrade';
-- Returns: 2022-11-02 04:00:00+00
```

## API Reference

### New Functions

#### `occurrences_tz(rrule, dtstart, tzid)`

Generates timezone-aware occurrences for an RRULE.

**Parameters:**
- `rrule`: `_rrule.RRULE` - The recurrence rule
- `dtstart`: `TIMESTAMP` - Starting timestamp (interpreted in tzid timezone)
- `tzid`: `TEXT` - Timezone identifier (e.g., 'Europe/Belgrade')

**Returns:** `SETOF TIMESTAMPTZ` - Occurrences in UTC with timezone information

**Example:**
```sql
SELECT * FROM _rrule.occurrences_tz(
  _rrule.rrule('RRULE:FREQ=DAILY;COUNT=3'),
  '2022-10-26T09:00:00'::timestamp,
  'America/New_York'
);
```

#### `occurrences_tz(rrule, dtstart, tzid, tsrange)`

Timezone-aware occurrences with date range filter.

**Parameters:**
- `rrule`: `_rrule.RRULE` - The recurrence rule
- `dtstart`: `TIMESTAMP` - Starting timestamp
- `tzid`: `TEXT` - Timezone identifier
- `tsrange`: `TSRANGE` - Date range to filter occurrences

**Returns:** `SETOF TIMESTAMPTZ`

**Example:**
```sql
SELECT * FROM _rrule.occurrences_tz(
  _rrule.rrule('RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=10'),
  '2022-01-01T09:00:00'::timestamp,
  'Europe/London',
  '[2022-01-01, 2022-02-01]'::tsrange
);
```

#### `occurrences_tz(rruleset)`

Generates occurrences using the timezone stored in the RRULESET.

**Parameters:**
- `rruleset`: `_rrule.RRULESET` - Ruleset with tzid field set

**Returns:** `SETOF TIMESTAMPTZ`

**Example:**
```sql
SELECT * FROM _rrule.occurrences_tz(
  _rrule.rruleset('DTSTART;TZID=Asia/Tokyo:20220101T090000
  RRULE:FREQ=DAILY;COUNT=5')
);
```

**Note:** Raises error if `tzid` is NULL. Use `occurrences()` for naive timestamps.

#### `occurrences_tz(rruleset, tsrange)`

Timezone-aware occurrences from RRULESET with date range filter.

**Parameters:**
- `rruleset`: `_rrule.RRULESET` - Ruleset with tzid
- `tsrange`: `TSRANGE` - Date range filter

**Returns:** `SETOF TIMESTAMPTZ`

#### `until_with_timezone(rrule, tzid)`

Helper function that converts RRULE's UNTIL to timezone-aware timestamp.

**Parameters:**
- `rrule`: `_rrule.RRULE` - The recurrence rule
- `tzid`: `TEXT` - Timezone identifier (kept for API compatibility, UNTIL always treated as UTC)

**Returns:** `TIMESTAMPTZ` - UNTIL as UTC timestamp, or NULL if no UNTIL

**Note:** Per RFC 5545, UNTIL is always interpreted as UTC.

### Existing Functions (Unchanged)

All existing functions continue to work with naive timestamps:

- `occurrences(rrule, dtstart)` - Returns `SETOF TIMESTAMP`
- `occurrences(rruleset)` - Returns `SETOF TIMESTAMP`
- `first(rruleset)` - Returns `TIMESTAMP`
- `last(rruleset)` - Returns `TIMESTAMP`

These functions ignore the `tzid` field if present, maintaining full backward compatibility.

## Examples

### Example 1: Weekly Meeting Across DST

```sql
-- Setup: Weekly team meeting every Monday at 9:00 AM New York time
SELECT * FROM _rrule.occurrences_tz(
  _rrule.rrule('RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=10'),
  '2022-03-01T09:00:00'::timestamp,  -- Start date
  'America/New_York'
) ORDER BY occurrences_tz;

-- DST transition on March 13, 2022 (EST → EDT)
-- Times automatically adjust:
-- Before DST: 09:00 EST (UTC-5) = 14:00 UTC
-- After DST:  09:00 EDT (UTC-4) = 13:00 UTC
```

### Example 2: Daily Standup in Multiple Timezones

```sql
-- Create a table for team events
CREATE TABLE team_events (
  event_id SERIAL PRIMARY KEY,
  event_name TEXT,
  recurrence _rrule.RRULESET
);

-- Add daily standup for European team
INSERT INTO team_events (event_name, recurrence)
VALUES (
  'European Team Standup',
  _rrule.jsonb_to_rruleset('{
    "dtstart": "2022-01-01T10:00:00",
    "tzid": "Europe/Amsterdam",
    "rrule": [{"freq": "DAILY", "byday": ["MO","TU","WE","TH","FR"]}]
  }'::jsonb)
);

-- Get next 5 occurrences in UTC
SELECT
  event_name,
  _rrule.occurrences_tz(recurrence) as occurrence_utc
FROM team_events
WHERE event_name = 'European Team Standup'
LIMIT 5;

-- Convert to local timezone for display
SELECT
  event_name,
  _rrule.occurrences_tz(recurrence) AT TIME ZONE 'America/Los_Angeles' as occurrence_la
FROM team_events
WHERE event_name = 'European Team Standup'
LIMIT 5;
```

### Example 3: Holiday Schedule with Exclusions

```sql
-- Monthly meeting on first Monday, excluding holidays
WITH ruleset AS (
  SELECT _rrule.jsonb_to_rruleset('{
    "dtstart": "2022-01-03T14:00:00",
    "tzid": "America/Chicago",
    "rrule": [{
      "freq": "MONTHLY",
      "byday": ["1MO"],
      "count": 12
    }],
    "exdate": [
      "2022-05-02T14:00:00",
      "2022-09-05T14:00:00"
    ]
  }'::jsonb) as rs
)
SELECT _rrule.occurrences_tz(rs)
FROM ruleset;
```

### Example 4: Finding Next Occurrence After Now

```sql
-- Get next team meeting after current time
WITH tz_occurrences AS (
  SELECT _rrule.occurrences_tz(
    _rrule.rruleset('DTSTART;TZID=Europe/Paris:20220101T150000
    RRULE:FREQ=WEEKLY;BYDAY=TU,TH;COUNT=50')
  ) as occurrence
)
SELECT occurrence
FROM tz_occurrences
WHERE occurrence > NOW()
ORDER BY occurrence
LIMIT 1;
```

### Example 5: Converting Between Timezones

```sql
-- Event in Tokyo time, display in multiple timezones
WITH tokyo_events AS (
  SELECT _rrule.occurrences_tz(
    _rrule.rrule('RRULE:FREQ=WEEKLY;BYDAY=WE;COUNT=4'),
    '2022-01-05T10:00:00'::timestamp,
    'Asia/Tokyo'
  ) as utc_time
)
SELECT
  utc_time as utc,
  utc_time AT TIME ZONE 'Asia/Tokyo' as tokyo,
  utc_time AT TIME ZONE 'Europe/London' as london,
  utc_time AT TIME ZONE 'America/New_York' as new_york
FROM tokyo_events;
```

## Migration Guide

### Migrating Existing Code

If you have existing code using naive timestamps, you can gradually adopt timezone support:

#### Option 1: Keep Existing Code Unchanged

No changes needed. Existing `occurrences()` functions continue to work:

```sql
-- Old code (still works)
SELECT * FROM _rrule.occurrences(
  _rrule.rruleset('DTSTART:20220101T090000
  RRULE:FREQ=DAILY;COUNT=5')
);
-- Returns naive TIMESTAMP values
```

#### Option 2: Add Timezone Support to New Events

For new events, use the timezone-aware API:

```sql
-- New code with timezone support
SELECT * FROM _rrule.occurrences_tz(
  _rrule.rruleset('DTSTART;TZID=Europe/Berlin:20220101T090000
  RRULE:FREQ=DAILY;COUNT=5')
);
-- Returns TIMESTAMPTZ values
```

#### Option 3: Migrate Existing Data

Add timezone information to existing rulesets:

```sql
-- Add tzid column to your events table
ALTER TABLE events ADD COLUMN event_timezone TEXT DEFAULT 'UTC';

-- Update with appropriate timezones
UPDATE events SET event_timezone = 'America/New_York' WHERE location = 'NYC Office';
UPDATE events SET event_timezone = 'Europe/London' WHERE location = 'London Office';

-- Use timezone in queries
SELECT
  event_name,
  _rrule.occurrences_tz(
    (event_rruleset."rrule")[1],
    event_rruleset."dtstart",
    event_timezone
  ) as next_occurrence
FROM events;
```

### Testing Your Migration

```sql
-- Test that old and new APIs produce consistent results for UTC
-- (naive timestamps treated as UTC should match timezone-aware UTC)
WITH naive_results AS (
  SELECT occurrences FROM _rrule.occurrences(
    _rrule.rrule('RRULE:FREQ=DAILY;COUNT=5'),
    '2022-01-01T09:00:00'::timestamp
  ) as occurrences
),
tz_results AS (
  SELECT occurrences_tz::timestamp as occurrences FROM _rrule.occurrences_tz(
    _rrule.rrule('RRULE:FREQ=DAILY;COUNT=5'),
    '2022-01-01T09:00:00'::timestamp,
    'UTC'
  ) as occurrences_tz
)
SELECT * FROM naive_results
EXCEPT
SELECT * FROM tz_results;
-- Should return no rows (results are identical)
```

## RFC 5545 Compliance

### TZID Parameter Support

The extension supports the RFC 5545 TZID parameter format:

```
DTSTART;TZID=America/New_York:19970902T090000
```

This is parsed to extract both the timezone identifier and the local timestamp.

### UNTIL in UTC

Per RFC 5545 section 3.3.10:

> "If specified as a date-time value, then it MUST be specified in UTC."

The extension follows this recommendation:
- UNTIL values with 'Z' suffix are treated as UTC
- UNTIL values without 'Z' are also treated as UTC (normalized)
- Text output always includes 'Z' suffix on UNTIL

### Timezone Database

PostgreSQL uses the IANA timezone database, which is regularly updated to reflect:
- DST rule changes
- Historical timezone transitions
- New timezone definitions

Update PostgreSQL to get the latest timezone rules:
```bash
# Check current timezone data version
SELECT * FROM pg_timezone_names LIMIT 1;

# Update PostgreSQL to get latest timezone data
# (method depends on your PostgreSQL installation)
```

## Troubleshooting

### Invalid Timezone Error

**Error:**
```
ERROR: time zone "Invalid/Zone" not recognized
```

**Solution:**
Use a valid PostgreSQL timezone name. List available timezones:
```sql
SELECT name FROM pg_timezone_names ORDER BY name;
```

Common timezone names:
- US: `'America/New_York'`, `'America/Chicago'`, `'America/Los_Angeles'`
- Europe: `'Europe/London'`, `'Europe/Paris'`, `'Europe/Berlin'`
- Asia: `'Asia/Tokyo'`, `'Asia/Shanghai'`, `'Asia/Dubai'`

### RRULESET Requires tzid Error

**Error:**
```
ERROR: RRULESET must have tzid field set for timezone-aware occurrences
```

**Solution:**
Either:
1. Add tzid to your RRULESET:
   ```sql
   SELECT _rrule.jsonb_to_rruleset(
     jsonb_set(your_json, '{tzid}', '"America/New_York"')
   );
   ```

2. Use the overload that accepts tzid parameter:
   ```sql
   SELECT _rrule.occurrences_tz(
     (rruleset."rrule")[1],
     rruleset."dtstart",
     'America/New_York'
   );
   ```

3. Use naive `occurrences()` instead:
   ```sql
   SELECT _rrule.occurrences(rruleset);
   ```

### Unexpected Occurrence Times

**Issue:** Occurrences appear at wrong times

**Check:**
1. Verify timezone is correct:
   ```sql
   SELECT (your_rruleset).tzid;
   ```

2. Test timezone conversion manually:
   ```sql
   SELECT '2022-03-13T09:00:00'::timestamp AT TIME ZONE 'America/New_York';
   ```

3. Check for DST transitions:
   ```sql
   -- Find DST transitions in a year
   SELECT
     ts,
     ts AT TIME ZONE 'America/New_York' as ny_time,
     EXTRACT(TIMEZONE FROM (ts AT TIME ZONE 'America/New_York')) as offset_hours
   FROM generate_series(
     '2022-01-01'::timestamp,
     '2022-12-31'::timestamp,
     '1 day'::interval
   ) as ts
   WHERE EXTRACT(TIMEZONE FROM (ts AT TIME ZONE 'America/New_York')) !=
         LEAD(EXTRACT(TIMEZONE FROM (ts AT TIME ZONE 'America/New_York')))
         OVER (ORDER BY ts);
   ```

### Performance Considerations

For large recurrence sets:

1. Use date range filters to limit occurrences:
   ```sql
   SELECT _rrule.occurrences_tz(
     rrule, dtstart, tzid,
     '[2022-01-01, 2022-12-31]'::tsrange
   );
   ```

2. Use COUNT to limit occurrences:
   ```sql
   SELECT _rrule.occurrences_tz(
     _rrule.rrule('RRULE:FREQ=DAILY;COUNT=100'),  -- Limit to 100
     dtstart, tzid
   );
   ```

3. Add indexes on occurrence results if storing in tables:
   ```sql
   CREATE INDEX idx_event_occurrences ON event_occurrences
   USING btree (occurrence_time);
   ```

## See Also

- [PostgreSQL Timezone Documentation](https://www.postgresql.org/docs/current/datatype-datetime.html#DATATYPE-TIMEZONES)
- [RFC 5545: iCalendar Specification](https://tools.ietf.org/html/rfc5545)
- [IANA Time Zone Database](https://www.iana.org/time-zones)
