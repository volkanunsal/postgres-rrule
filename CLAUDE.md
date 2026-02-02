# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

postgres-rrule is a PostgreSQL extension for working with recurring dates. It parses RRULE (recurrence rule) specifications from the iCalendar standard and generates occurrences of recurring events.

**Key limitation**: This extension does not support endlessly repeating events. All RRULEs must include either `UNTIL` or `COUNT` parameters.

## Build System

The project uses a Makefile-based build system that compiles individual SQL files into a single `postgres-rrule.sql` file.

### Common Commands

Build and install the extension:
```bash
make all
```

This runs `make compile` (which builds postgres-rrule.sql) followed by `make execute` (which installs it into the database).

Individual build steps:
```bash
make compile    # Build postgres-rrule.sql from source files
make execute    # Install the extension into the database
make clean      # Drop the _rrule schema from the database
```

### Testing

Tests use pgTAP and require `pg_prove`:
```bash
make all test
```

Run tests only (assumes extension is already installed):
```bash
make test
```

Install pgTAP extension (one-time setup):
```bash
make pgtap
```

### Database Connection

The Makefile uses these default connection parameters:
- Host: localhost
- Port: 5432
- User: postgres
- Password: unsafe

Override these when running make commands:
```bash
make test PGHOST=myhost PGPORT=5433 PGUSER=myuser
```

## Architecture

### Schema Organization

All types, functions, and operators are created in the `_rrule` schema. Users must add `_rrule` to their search path:
```sql
SET search_path TO public, _rrule;
```

### Core Data Types

1. **RRULE** (table-based composite type in src/types/types.sql:19-36)
   - Represents a single recurrence rule with frequency, interval, count, until, and various BY* parameters
   - Uses table constraints to enforce RFC 5545 validity rules
   - Enum types: `FREQ` (YEARLY, MONTHLY, WEEKLY, DAILY) and `DAY` (MO, TU, WE, etc.)

2. **RRULESET** (table-based composite type in src/types/types.sql:39-46)
   - Combines an RRULE with dtstart, dtend, exrule, rdate, and exdate
   - Represents a complete recurrence specification

3. **exploded_interval** (type in src/types/types.sql:49-53)
   - Internal helper type for interval calculations with separate months, days, and seconds

### Source File Organization

The build system concatenates SQL files in this order:

1. **src/schema.sql** - Creates the `_rrule` schema
2. **src/types/** - Type definitions (FREQ, DAY, RRULE, RRULESET)
3. **src/functions/** - Functions numbered 0001-0270 (processed alphabetically)
4. **src/operators/** - Operator definitions (@>, <@, =, <>, etc.)
5. **src/casts/** - Type casting functions (TEXT <-> RRULE, JSONB <-> RRULESET)

Function files are numbered to ensure proper dependency ordering during compilation:
- 0001-0090: Helper functions and utilities
- 0100-0105: Core RRULE and RRULESET parsing functions
- 0200-0214: Query functions (is_finite, occurrences, first, last, before, after, contains_timestamp)
- 0215-0240: JSONB conversion functions
- 0250-0270: RRULESET array operators

### Key Functions

**Parsing:**
- `rrule(TEXT)` (src/functions/0100-rrule.sql) - Parse RRULE string to RRULE type
- `rruleset(TEXT)` (src/functions/0105-rruleset.sql) - Parse multiline RRULESET format with DTSTART, RRULE, EXDATE, RDATE
- `jsonb_to_rrule(JSONB)`, `jsonb_to_rruleset(JSONB)` - Parse from JSON format

**Querying:**
- `occurrences(RRULE, TIMESTAMP, INTEGER)` - Generate N occurrences starting from timestamp
- `first(RRULESET)`, `last(RRULESET)` - Get first/last occurrence
- `is_finite(RRULE)` - Check if rule has COUNT or UNTIL

**Operators:**
- `RRULESET @> TIMESTAMP` - Check if timestamp is contained in the ruleset
- `RRULESET[] @> TIMESTAMP` - Check if timestamp is in any ruleset in array
- Similar operators work with JSONB representations

### Validation

RRULE validation happens in `_rrule.validate_rrule()` (src/functions/0090-validate_rrule.sql), which enforces:
- FREQ is required
- BYWEEKNO only valid with FREQ=YEARLY
- BYYEARDAY only valid with FREQ=YEARLY
- BYMONTHDAY not valid with FREQ=WEEKLY
- BYDAY not valid with FREQ=DAILY
- BYSETPOS requires at least one other BY* parameter
- UNTIL and COUNT are mutually exclusive
- INTERVAL must be positive

### Testing Structure

Tests in `tests/` directory follow pgTAP conventions:
- Each test file begins with `BEGIN;` and `SELECT plan(N);`
- Tests use `is()`, `throws_like()`, and other pgTAP assertions
- Each test file ends with `SELECT * FROM finish();` and `ROLLBACK;`
- Tests set `search_path TO _rrule, public;` to access extension functions

## Development Workflow

1. Modify source files in src/types/, src/functions/, src/operators/, or src/casts/
2. Run `make compile` to rebuild postgres-rrule.sql
3. Run `make execute` to install into database (drops and recreates _rrule schema)
4. Run `make test` to verify changes
5. Or use `make all test` to do all steps at once

When adding new functions, use appropriate numbering (0001-0270) to maintain dependency order.
