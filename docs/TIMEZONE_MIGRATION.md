# Migrating to Timezone Support

This guide helps you migrate existing postgres-rrule implementations to use the new timezone support features.

## Overview

The timezone support is **fully backward compatible**. Your existing code will continue to work without any changes. However, to take advantage of timezone-aware DST handling, you'll need to update your code to use the new `occurrences_tz()` functions.

## Migration Strategies

Choose the strategy that best fits your needs:

### Strategy 1: No Changes Required (Backward Compatible)

If your application doesn't need timezone awareness, **no changes are required**.

```sql
-- Your existing code continues to work
SELECT * FROM _rrule.occurrences(
  _rrule.rruleset('DTSTART:20220101T090000
  RRULE:FREQ=DAILY;COUNT=10')
);
-- Still returns naive TIMESTAMP values
```

**When to use:**
- All events are in a single timezone
- You handle timezone conversion in your application layer
- Events don't cross DST boundaries
- You're using UTC for everything

### Strategy 2: Gradual Migration (Recommended)

Migrate to timezone support incrementally, starting with new features.

**Phase 1: New events use timezone support**

```sql
-- Old events (keep as-is)
SELECT * FROM _rrule.occurrences(old_rruleset);

-- New events (use timezone)
SELECT * FROM _rrule.occurrences_tz(
  new_rruleset  -- Created with TZID
);
```

**Phase 2: Add timezone column to existing data**

```sql
-- Add timezone column
ALTER TABLE events ADD COLUMN event_timezone TEXT;

-- Set timezone for existing events
UPDATE events SET event_timezone = 'America/New_York'
WHERE location = 'NYC Office';

UPDATE events SET event_timezone = 'Europe/London'
WHERE location = 'London Office';

UPDATE events SET event_timezone = 'UTC'
WHERE event_timezone IS NULL;  -- Default to UTC
```

**Phase 3: Update queries to use timezone**

```sql
-- Old query
SELECT _rrule.occurrences(recurrence) FROM events;

-- New query
SELECT _rrule.occurrences_tz(
  (recurrence."rrule")[1],
  recurrence."dtstart",
  COALESCE(event_timezone, 'UTC')
) FROM events;
```

### Strategy 3: Full Migration

Migrate all events to use timezone support at once.

**Best for:**
- Small datasets
- New projects
- Systems with planned downtime
- Applications with consistent timezone requirements

See [Full Migration Example](#full-migration-example) below.

## Step-by-Step Migration

### Step 1: Audit Your Current Usage

Identify where you're using postgres-rrule:

```sql
-- Find tables with RRULESET columns
SELECT
  schemaname,
  tablename,
  attname as column_name
FROM pg_attribute
JOIN pg_class ON pg_attribute.attrelid = pg_class.oid
JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
JOIN pg_type ON pg_attribute.atttypid = pg_type.oid
WHERE pg_type.typname = 'rruleset'
  AND schemaname NOT IN ('pg_catalog', 'information_schema');

-- Check for functions using occurrences()
SELECT
  routine_schema,
  routine_name,
  routine_definition
FROM information_schema.routines
WHERE routine_definition ILIKE '%occurrences(%'
  AND routine_schema NOT IN ('pg_catalog', 'information_schema', '_rrule');
```

### Step 2: Determine Timezone Requirements

For each table/usage, determine the timezone:

```sql
-- Example: Add timezone based on location
ALTER TABLE events ADD COLUMN event_timezone TEXT;

-- Map locations to timezones
UPDATE events SET event_timezone = CASE
  WHEN location IN ('New York', 'NYC', 'Boston') THEN 'America/New_York'
  WHEN location IN ('San Francisco', 'LA', 'Seattle') THEN 'America/Los_Angeles'
  WHEN location IN ('London', 'UK') THEN 'Europe/London'
  WHEN location IN ('Paris', 'Berlin') THEN 'Europe/Paris'
  WHEN location IN ('Tokyo', 'Japan') THEN 'Asia/Tokyo'
  ELSE 'UTC'  -- Default fallback
END;

-- Validate all events have timezones
SELECT location, event_timezone, count(*)
FROM events
GROUP BY location, event_timezone
ORDER BY location;
```

### Step 3: Create Migration Functions

Create helper functions to ease the transition:

```sql
-- Helper: Get timezone-aware occurrences with fallback
CREATE OR REPLACE FUNCTION get_event_occurrences(
  event_recurrence _rrule.RRULESET,
  event_timezone TEXT,
  range_start TIMESTAMP DEFAULT NULL,
  range_end TIMESTAMP DEFAULT NULL
)
RETURNS SETOF TIMESTAMPTZ AS $$
BEGIN
  -- Use timezone if available, fallback to UTC
  RETURN QUERY
  SELECT _rrule.occurrences_tz(
    (event_recurrence."rrule")[1],
    event_recurrence."dtstart",
    COALESCE(event_timezone, 'UTC'),
    CASE
      WHEN range_start IS NOT NULL AND range_end IS NOT NULL
      THEN tsrange(range_start, range_end, '[]')
      ELSE NULL
    END
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- Usage
SELECT get_event_occurrences(
  recurrence,
  event_timezone,
  '2022-01-01'::timestamp,
  '2022-12-31'::timestamp
) FROM events;
```

### Step 4: Update Application Code

#### Before (naive timestamps):

```sql
-- Application code before migration
SELECT
  event_id,
  event_name,
  _rrule.occurrences(recurrence) as occurrence
FROM events
WHERE event_category = 'meetings';
```

#### After (timezone-aware):

```sql
-- Application code after migration
SELECT
  event_id,
  event_name,
  _rrule.occurrences_tz(
    (recurrence."rrule")[1],
    recurrence."dtstart",
    event_timezone
  ) as occurrence_utc,
  _rrule.occurrences_tz(
    (recurrence."rrule")[1],
    recurrence."dtstart",
    event_timezone
  ) AT TIME ZONE event_timezone as occurrence_local
FROM events
WHERE event_category = 'meetings';
```

### Step 5: Update Views

If you have views using occurrences():

```sql
-- Drop old view
DROP VIEW IF EXISTS upcoming_events;

-- Create new timezone-aware view
CREATE VIEW upcoming_events AS
SELECT
  e.event_id,
  e.event_name,
  e.event_timezone,
  o.occurrence_time
FROM events e
CROSS JOIN LATERAL (
  SELECT _rrule.occurrences_tz(
    (e.recurrence."rrule")[1],
    e.recurrence."dtstart",
    e.event_timezone
  ) as occurrence_time
) o
WHERE o.occurrence_time >= NOW()
  AND o.occurrence_time <= NOW() + INTERVAL '30 days'
ORDER BY o.occurrence_time;
```

### Step 6: Test Thoroughly

```sql
-- Test 1: Verify timezone conversions
WITH test_data AS (
  SELECT
    'Test Event' as name,
    _rrule.rruleset('DTSTART;TZID=America/New_York:20220313T090000
    RRULE:FREQ=WEEKLY;BYDAY=SU;COUNT=4') as recurrence
)
SELECT
  name,
  occurrence,
  occurrence AT TIME ZONE 'America/New_York' as ny_time,
  occurrence AT TIME ZONE 'UTC' as utc_time
FROM test_data
CROSS JOIN LATERAL (
  SELECT _rrule.occurrences_tz(recurrence) as occurrence
) o;

-- Test 2: Verify DST transitions
-- Should show UTC time changing but local time staying constant
```

### Step 7: Monitor and Rollback Plan

```sql
-- Create comparison query to verify results
CREATE TEMP TABLE migration_comparison AS
SELECT
  event_id,
  -- Old method
  _rrule.occurrences(recurrence) as old_occurrence,
  -- New method (converted to naive for comparison)
  (_rrule.occurrences_tz(
    (recurrence."rrule")[1],
    recurrence."dtstart",
    'UTC'  -- Compare using UTC
  ))::timestamp as new_occurrence_as_utc
FROM events
WHERE event_timezone = 'UTC';  -- Only compare UTC events

-- Check for differences
SELECT *
FROM migration_comparison
WHERE old_occurrence != new_occurrence_as_utc;
-- Should return no rows if migration is correct
```

## Full Migration Example

Here's a complete example migrating a calendar application:

### Initial Schema

```sql
CREATE TABLE calendar_events (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  event_title TEXT NOT NULL,
  event_location TEXT,
  recurrence _rrule.RRULESET NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Sample data
INSERT INTO calendar_events (user_id, event_title, event_location, recurrence)
VALUES (
  1,
  'Weekly Team Meeting',
  'New York Office',
  _rrule.rruleset('DTSTART:20220103T100000
  RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=52')
);
```

### Step 1: Add Timezone Column

```sql
ALTER TABLE calendar_events ADD COLUMN event_timezone TEXT;

-- Set timezone based on location
UPDATE calendar_events SET event_timezone =
  CASE
    WHEN event_location ILIKE '%new york%' THEN 'America/New_York'
    WHEN event_location ILIKE '%london%' THEN 'Europe/London'
    WHEN event_location ILIKE '%tokyo%' THEN 'Asia/Tokyo'
    ELSE 'UTC'
  END;

-- Make timezone required for new events
ALTER TABLE calendar_events
ALTER COLUMN event_timezone SET NOT NULL;

ALTER TABLE calendar_events
ALTER COLUMN event_timezone SET DEFAULT 'UTC';
```

### Step 2: Create Occurrence View

```sql
CREATE OR REPLACE VIEW event_occurrences AS
SELECT
  e.id as event_id,
  e.user_id,
  e.event_title,
  e.event_timezone,
  o.occurrence_utc,
  o.occurrence_utc AT TIME ZONE e.event_timezone as occurrence_local
FROM calendar_events e
CROSS JOIN LATERAL (
  SELECT _rrule.occurrences_tz(
    (e.recurrence."rrule")[1],
    e.recurrence."dtstart",
    e.event_timezone
  ) as occurrence_utc
) o;

-- Query upcoming events
SELECT
  event_title,
  occurrence_local,
  event_timezone
FROM event_occurrences
WHERE occurrence_utc >= NOW()
  AND occurrence_utc < NOW() + INTERVAL '7 days'
ORDER BY occurrence_utc;
```

### Step 3: Update Insert Function

```sql
-- Old insert function
CREATE OR REPLACE FUNCTION create_event_old(
  p_user_id INTEGER,
  p_title TEXT,
  p_dtstart TIMESTAMP,
  p_rrule_text TEXT
) RETURNS INTEGER AS $$
DECLARE
  new_event_id INTEGER;
BEGIN
  INSERT INTO calendar_events (user_id, event_title, recurrence)
  VALUES (
    p_user_id,
    p_title,
    _rrule.rruleset('DTSTART:' || to_char(p_dtstart, 'YYYYMMDD"T"HH24MISS') || E'\n' || p_rrule_text)
  )
  RETURNING id INTO new_event_id;

  RETURN new_event_id;
END;
$$ LANGUAGE plpgsql;

-- New insert function with timezone
CREATE OR REPLACE FUNCTION create_event(
  p_user_id INTEGER,
  p_title TEXT,
  p_location TEXT,
  p_dtstart TIMESTAMP,
  p_timezone TEXT,
  p_rrule_text TEXT
) RETURNS INTEGER AS $$
DECLARE
  new_event_id INTEGER;
  rruleset_text TEXT;
BEGIN
  -- Build RRULESET with TZID
  rruleset_text := 'DTSTART;TZID=' || p_timezone || ':' ||
                   to_char(p_dtstart, 'YYYYMMDD"T"HH24MISS') || E'\n' ||
                   p_rrule_text;

  INSERT INTO calendar_events (
    user_id,
    event_title,
    event_location,
    event_timezone,
    recurrence
  )
  VALUES (
    p_user_id,
    p_title,
    p_location,
    p_timezone,
    _rrule.rruleset(rruleset_text)
  )
  RETURNING id INTO new_event_id;

  RETURN new_event_id;
END;
$$ LANGUAGE plpgsql;

-- Usage
SELECT create_event(
  1,
  'Daily Standup',
  'SF Office',
  '2022-01-03T09:00:00'::timestamp,
  'America/Los_Angeles',
  'RRULE:FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR;COUNT=250'
);
```

### Step 4: Verify Migration

```sql
-- Check all events have timezones
SELECT
  count(*) as total_events,
  count(event_timezone) as events_with_timezone,
  count(*) - count(event_timezone) as events_missing_timezone
FROM calendar_events;

-- Sample occurrences from each timezone
SELECT
  event_timezone,
  count(DISTINCT event_id) as event_count,
  min(occurrence_utc) as first_occurrence,
  max(occurrence_utc) as last_occurrence
FROM (
  SELECT
    e.id as event_id,
    e.event_timezone,
    _rrule.occurrences_tz(
      (e.recurrence."rrule")[1],
      e.recurrence."dtstart",
      e.event_timezone
    ) as occurrence_utc
  FROM calendar_events e
  LIMIT 1000
) occurrences
GROUP BY event_timezone
ORDER BY event_timezone;
```

## Common Pitfalls

### Pitfall 1: Mixing Naive and Timezone-Aware Timestamps

❌ **Wrong:**
```sql
-- Comparing naive TIMESTAMP with TIMESTAMPTZ
SELECT * FROM events
WHERE _rrule.occurrences(recurrence) > NOW();
-- NOW() returns TIMESTAMPTZ, occurrences() returns TIMESTAMP
```

✓ **Correct:**
```sql
-- Use consistent types
SELECT * FROM events
WHERE _rrule.occurrences_tz(
  (recurrence."rrule")[1],
  recurrence."dtstart",
  event_timezone
) > NOW();
-- Both are TIMESTAMPTZ
```

### Pitfall 2: Forgetting to Set Timezone

❌ **Wrong:**
```sql
-- Creating RRULESET without timezone when needed
INSERT INTO events (recurrence) VALUES (
  _rrule.rruleset('DTSTART:20220101T090000
  RRULE:FREQ=DAILY;COUNT=10')
);
-- tzid is NULL, occurrences_tz() will fail
```

✓ **Correct:**
```sql
INSERT INTO events (recurrence, event_timezone) VALUES (
  _rrule.rruleset('DTSTART;TZID=America/New_York:20220101T090000
  RRULE:FREQ=DAILY;COUNT=10'),
  'America/New_York'
);
-- tzid is set, occurrences_tz() works
```

### Pitfall 3: Assuming UTC Without Declaring It

❌ **Wrong:**
```sql
-- Assuming everything is UTC without being explicit
SELECT _rrule.occurrences_tz(recurrence) FROM events;
-- If tzid is NULL, this will error
```

✓ **Correct:**
```sql
-- Be explicit about UTC
SELECT _rrule.occurrences_tz(
  (recurrence."rrule")[1],
  recurrence."dtstart",
  COALESCE(event_timezone, 'UTC')
) FROM events;
```

## Rollback Plan

If you need to rollback:

```sql
-- 1. Drop timezone column
ALTER TABLE events DROP COLUMN IF EXISTS event_timezone;

-- 2. Revert views to use old functions
CREATE OR REPLACE VIEW upcoming_events AS
SELECT
  event_id,
  event_name,
  _rrule.occurrences(recurrence) as occurrence
FROM events
WHERE _rrule.occurrences(recurrence) >= NOW()::timestamp;

-- 3. Update application queries to use occurrences() instead of occurrences_tz()
```

The extension itself doesn't need to be downgraded - the old functions remain available.

## Support and Resources

- [Full Timezone Documentation](TIMEZONE_SUPPORT.md)
- [Quick Reference](TIMEZONE_QUICK_REFERENCE.md)
- [PostgreSQL Timezone Documentation](https://www.postgresql.org/docs/current/datatype-datetime.html#DATATYPE-TIMEZONES)
- [RFC 5545 iCalendar Specification](https://tools.ietf.org/html/rfc5545)
