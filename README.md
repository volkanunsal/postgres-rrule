# postgres-rrule

> **MAINTENANCE MODE**: This repository is in maintenance mode. Bug reports and pull requests are welcome, but active development is paused.

A PostgreSQL extension for working with recurring dates and events using the iCalendar RRULE specification (RFC 5545).

**Key Features:**
- Parse RRULE strings and JSONB into native PostgreSQL types
- Query whether a timestamp occurs within a recurrence rule
- Generate occurrence sequences from recurrence rules
- Support for EXDATE, RDATE, and EXRULE for complex recurrence patterns
- Built-in operators for containment checking
- **Timezone support with automatic DST handling** - Properly handle recurring events across daylight saving time transitions

**Important Limitation:** This extension requires all recurrence rules to include either `UNTIL` (end date) or `COUNT` (number of occurrences). Infinite recurrence rules are not supported.

## Table of Contents

- [Installation](#installation)
- [Docker Development Environment](#docker-development-environment)
- [Quick Start](#quick-start)
- [Timezone Support](#timezone-support)
- [How It Works](#how-it-works)
- [Examples](#examples)
- [API Reference](#api-reference)
- [Testing](#testing)
- [Release Management](#release-management)
- [License](#license)

## Installation

### Recommended: Docker (Easiest)

The recommended way to use and test postgres-rrule is with Docker:

```bash
# Build and run tests (includes Docker, PostgreSQL, pgTAP)
make all
```

This provides a complete, isolated environment with all dependencies pre-installed. See [Docker Development Environment](#docker-development-environment) for details.

### Alternative: Local PostgreSQL

If you prefer to use your local PostgreSQL installation:

#### Prerequisites

- PostgreSQL 9.4 or later
- psql command-line tool
- pgTAP extension (for testing)
- pg_prove (for testing)

#### Install from Compiled SQL

Use the pre-compiled `postgres-rrule.sql` file:

```bash
psql -X -f postgres-rrule.sql -d your_database
```

#### Build and Install from Source

```bash
make compile          # Build postgres-rrule.sql
make local-execute    # Install into local PostgreSQL
```

#### Configure Search Path

After installation, add the `_rrule` schema to your search path:

**Per-session:**
```sql
SET search_path TO public, _rrule;
```

**Permanently for a database:**
```sql
ALTER DATABASE your_database SET search_path TO public, _rrule;
```

**Permanently for a user:**
```sql
ALTER ROLE your_user SET search_path TO public, _rrule;
```

## Docker Development Environment

A Docker-based development environment is provided for consistent testing across different machines. This is the recommended approach for development and testing.

**📚 See [DOCKER.md](DOCKER.md) for comprehensive Docker documentation, troubleshooting, and advanced usage patterns.**

### Prerequisites

- Docker installed on your system
- Docker daemon running

### Quick Docker Usage

Build and test in one command:

```bash
make all
```

This will:
1. Pull the PostgreSQL base image (postgres:16)
2. Build the development Docker image with all dependencies
3. Start a PostgreSQL container
4. Compile and install the extension
5. Run all tests
6. Clean up the container

### Docker Makefile Targets

**Main Commands:**
```bash
make all              # Build and test (recommended)
make test             # Run all tests in a clean container
make build            # Build the Docker image with pgTAP installed
make pull             # Pull the base PostgreSQL image (fast)
```

**Development:**
```bash
make start            # Start a PostgreSQL container (detached)
make stop             # Stop and remove the container
make shell            # Open a bash shell inside the container
make psql             # Open a psql session inside the container
make logs             # View container logs
```

**Cleanup:**
```bash
make clean            # Remove container, image, and prune Docker resources
make rebuild          # Clean and rebuild everything from scratch
```

**Note**: Old `docker-*` commands still work but show deprecation warnings. Use the shorter versions above.

### Docker Container Details

- **Container name**: `postgres-rrule-test`
- **Image name**: `postgres-rrule`
- **Base image**: `postgres:16`
- **Exposed port**: `5433` (mapped to container's 5432)
- **Database user**: `postgres`
- **Database password**: `unsafe`
- **Working directory**: `/workspace` (mounted from current directory)

### Example Docker Workflow

```bash
# First time setup and test
make all

# After making code changes
make test

# For debugging, start container and explore
make start
make psql
# ... run queries ...
# ... test manually ...
make stop

# Clean up when done
make clean
```

### Advantages of Docker Environment

- **Consistent dependencies**: pgTAP and all required tools pre-installed
- **Isolated testing**: No interference with local PostgreSQL installation
- **Clean slate**: Each test run starts with a fresh database
- **Cross-platform**: Works identically on Linux, macOS, and Windows
- **CI/CD ready**: Easy to integrate into automated pipelines

## Quick Start

Check if a date is part of a recurring series:

```sql
-- Every Tuesday until September 2, 1998
SELECT '
  DTSTART:19970902T090000
  RRULE:FREQ=WEEKLY;UNTIL=19980902T090000;BYDAY=TU
'::TEXT::RRULESET @> '1997-09-09 09:00:00'::TIMESTAMP;
-- Returns: true

-- Check if a date is NOT in the series
SELECT '
  DTSTART:19970902T090000
  RRULE:FREQ=WEEKLY;UNTIL=19980902T090000;BYDAY=TU
'::TEXT::RRULESET @> '1997-09-10 09:00:00'::TIMESTAMP;
-- Returns: false (Sept 10, 1997 is Wednesday)
```

Generate all occurrences:

```sql
SELECT * FROM occurrences(
  'DTSTART:20260101T100000
   RRULE:FREQ=DAILY;COUNT=5'::TEXT::RRULESET
);
-- Returns:
-- 2026-01-01 10:00:00
-- 2026-01-02 10:00:00
-- 2026-01-03 10:00:00
-- 2026-01-04 10:00:00
-- 2026-01-05 10:00:00
```

## Timezone Support

The extension provides comprehensive timezone support for handling recurring events across daylight saving time (DST) transitions. Events maintain their local time even when DST rules change.

### Quick Example

```sql
-- Generate timezone-aware occurrences
-- Event: "Every Wednesday at 5:00 AM Europe/Belgrade"
SELECT * FROM _rrule.occurrences_tz(
  _rrule.rrule('RRULE:FREQ=WEEKLY;BYDAY=WE;COUNT=3'),
  '2022-10-26T05:00:00'::timestamp,
  'Europe/Belgrade'
);

-- Returns TIMESTAMPTZ values (in UTC):
-- 2022-10-26 03:00:00+00  (05:00 CEST, UTC+2)
-- 2022-11-02 04:00:00+00  (05:00 CET, UTC+1) ← DST transition handled!
-- 2022-11-09 04:00:00+00  (05:00 CET, UTC+1)
```

Notice how the UTC time shifts from 03:00 to 04:00 after the DST transition on October 30, 2022, while the local time stays at 05:00.

### Storing Timezone Information

Use RFC 5545 TZID format or JSON:

```sql
-- Text format with TZID
SELECT _rrule.rruleset('DTSTART;TZID=America/New_York:20220101T090000
RRULE:FREQ=DAILY;COUNT=5');

-- JSON format with tzid
SELECT _rrule.jsonb_to_rruleset('{
  "dtstart": "2022-01-01T09:00:00",
  "tzid": "America/New_York",
  "rrule": [{"freq": "DAILY", "count": 5}]
}'::jsonb);
```

### New Functions

- `occurrences_tz(rrule, dtstart, tzid)` - Timezone-aware occurrences
- `occurrences_tz(rruleset)` - Uses tzid from RRULESET
- Returns `TIMESTAMPTZ` values with proper DST handling

### Documentation

See [docs/TIMEZONE_SUPPORT.md](docs/TIMEZONE_SUPPORT.md) for comprehensive documentation including:
- Detailed API reference
- DST handling examples
- Migration guide for existing code
- RFC 5545 compliance details
- Troubleshooting tips

## How It Works

postgres-rrule creates a dedicated `_rrule` schema containing:

- **Custom types**: `RRULE` and `RRULESET` composite types that represent recurrence rules
- **Type constraints**: Table constraints that enforce RFC 5545 validity rules
- **Functions**: Parse RRULE strings, generate occurrences, and query recurrence rules
- **Operators**: Intuitive operators like `@>` (contains) for checking date membership
- **Casts**: Automatic conversion between TEXT, JSONB, and native types

The `RRULE` type is implemented as a table structure, allowing PostgreSQL's constraint system to validate recurrence rules at parse time.

## Examples

### Parsing RRULE Strings

Parse a recurrence rule into the native `RRULESET` type:

```sql
SELECT '
  DTSTART:19970902T090000
  RRULE:FREQ=WEEKLY;UNTIL=19980902T090000
'::TEXT::RRULESET;

-- Returns the parsed RRULESET structure
-- ("1997-09-02 09:00:00",,"(WEEKLY,1,,""1998-09-02 09:00:00"",,,,,,,,,,MO)",,,)
```

### Checking Date Membership

Check if a specific timestamp occurs within a recurrence rule:

```sql
SELECT '
  DTSTART:19970902T090000
  RRULE:FREQ=WEEKLY;UNTIL=19980902T090000
'::TEXT::RRULESET @> '1997-09-02T09:00:00'::TIMESTAMP;
-- Returns: true
```

### Working with JSONB

The extension supports JSONB format for easier integration with applications:

```sql
SELECT '{
  "dtstart": "1997-09-02T09:00:00",
  "dtend": "1997-09-03T09:00:00",
  "rrule": {
    "freq": "WEEKLY",
    "wkst": "MO",
    "count": 4,
    "interval": 1
  }
}'::JSONB::RRULESET @> '1997-09-02T09:00:00'::TIMESTAMP;
-- Returns: true
```

### Common Recurrence Patterns

**Daily for 10 occurrences:**
```sql
SELECT * FROM occurrences(
  'DTSTART:20260201T090000
   RRULE:FREQ=DAILY;COUNT=10'::TEXT::RRULESET
) LIMIT 5;
```

**Every other week on Tuesday and Thursday:**
```sql
SELECT '
  DTSTART:20260201T090000
  RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH;COUNT=8
'::TEXT::RRULESET;
```

**Monthly on the 1st and 15th:**
```sql
SELECT * FROM occurrences(
  'DTSTART:20260201T090000
   RRULE:FREQ=MONTHLY;BYMONTHDAY=1,15;COUNT=12'::TEXT::RRULESET
);
```

**Every weekday (Monday-Friday):**
```sql
SELECT '
  DTSTART:20260201T090000
  RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;UNTIL=20261231T090000
'::TEXT::RRULESET;
```

### Using EXDATE and RDATE

Exclude specific dates or add extra dates to a recurrence:

```sql
-- Every day except Christmas and New Year's
SELECT '
  DTSTART:20260101T090000
  RRULE:FREQ=DAILY;UNTIL=20260131T090000
  EXDATE:20260101T090000,20260125T090000
'::TEXT::RRULESET @> '2026-01-25T09:00:00'::TIMESTAMP;
-- Returns: false (excluded)

-- Add specific dates outside the normal pattern
SELECT '
  DTSTART:20260101T090000
  RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=4
  RDATE:20260115T090000
'::TEXT::RRULESET;
```

### Querying with Arrays

Check if a timestamp matches any rule in an array of rulesets:

```sql
SELECT ARRAY[
  'DTSTART:20260101T090000
   RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=4'::TEXT::RRULESET,
  'DTSTART:20260101T100000
   RRULE:FREQ=WEEKLY;BYDAY=WE;COUNT=4'::TEXT::RRULESET
] @> '2026-01-07T10:00:00'::TIMESTAMP;
-- Returns: true (matches Wednesday rule)
```

## API Reference

### Types

**`RRULE`**: Composite type representing a single recurrence rule with fields:
- `freq`: Frequency (YEARLY, MONTHLY, WEEKLY, DAILY)
- `interval`: Interval between occurrences (default: 1)
- `count`: Maximum number of occurrences
- `until`: End date for recurrence
- `byday`, `bymonthday`, `byyearday`, `byweekno`, `bymonth`, `bysetpos`: Recurrence constraints
- `wkst`: Week start day (default: MO)

**`RRULESET`**: Composite type containing:
- `dtstart`: Start timestamp (required)
- `dtend`: End timestamp
- `rrule`: The recurrence rule
- `exrule`: Exclusion recurrence rule
- `rdate`: Array of additional timestamps to include
- `exdate`: Array of timestamps to exclude

### Operators

#### `RRULE` Operators

| Operator | Left Type | Right Type | Description | Example |
|----------|-----------|------------|-------------|---------|
| `=` | `RRULE` | `RRULE` | Equal (all parameters match) | `rule1 = rule2` |
| `<>` | `RRULE` | `RRULE` | Not equal | `rule1 <> rule2` |
| `@>` | `RRULE` | `RRULE` | Contains (all occurrences of right would be generated by left) | `rule1 @> rule2` |
| `<@` | `RRULE` | `RRULE` | Contained by | `rule1 <@ rule2` |

#### `RRULESET` Operators

| Operator | Left Type | Right Type | Description | Example |
|----------|-----------|------------|-------------|---------|
| `@>` | `RRULESET` | `TIMESTAMP` | Contains timestamp | `ruleset @> '2026-01-15'::TIMESTAMP` |
| `@>` | `RRULESET[]` | `TIMESTAMP` | Any ruleset in array contains timestamp | `ARRAY[ruleset1, ruleset2] @> ts` |
| `@>` | `JSONB` (as RRULESET) | `TIMESTAMP` | JSONB ruleset contains timestamp | `'{"dtstart": ...}'::JSONB @> ts` |

### Functions

#### Occurrence Generation

**`occurrences(rruleset RRULESET) → SETOF TIMESTAMP`**
Generate all occurrences from a ruleset.

```sql
SELECT * FROM occurrences(
  'DTSTART:20260101T100000
   RRULE:FREQ=DAILY;COUNT=3'::RRULESET
);
```

**`occurrences(rruleset RRULESET, tsrange TSRANGE) → SETOF TIMESTAMP`**
Generate occurrences within a specific time range.

```sql
SELECT * FROM occurrences(
  'DTSTART:20260101T100000
   RRULE:FREQ=DAILY;COUNT=100'::RRULESET,
  '[2026-01-15, 2026-01-20]'::TSRANGE
);
```

**`occurrences(rrule RRULE, dtstart TIMESTAMP) → SETOF TIMESTAMP`**
Generate occurrences from a bare RRULE with explicit start date.

**`occurrences(rruleset_array RRULESET[], tsrange TSRANGE) → SETOF TIMESTAMP`**
Generate occurrences from multiple rulesets.

#### Query Functions

**`first(rruleset RRULESET) → TIMESTAMP`**
Get the first occurrence.

```sql
SELECT first('DTSTART:20260201T090000
              RRULE:FREQ=DAILY;COUNT=10'::RRULESET);
-- Returns: 2026-02-01 09:00:00
```

**`last(rruleset RRULESET) → TIMESTAMP`**
Get the last occurrence (requires finite ruleset).

```sql
SELECT last('DTSTART:20260201T090000
             RRULE:FREQ=DAILY;COUNT=10'::RRULESET);
-- Returns: 2026-02-10 09:00:00
```

**`is_finite(rruleset RRULESET) → BOOLEAN`**
Check if a ruleset has a defined end (COUNT or UNTIL).

```sql
SELECT is_finite('DTSTART:20260101T090000
                  RRULE:FREQ=DAILY;COUNT=5'::RRULESET);
-- Returns: true
```

**`after(rruleset RRULESET, timestamp TIMESTAMP) → TIMESTAMP`**
Get the first occurrence after a given timestamp.

**`before(rruleset RRULESET, timestamp TIMESTAMP) → TIMESTAMP`**
Get the last occurrence before a given timestamp.

#### Conversion Functions

**`rrule(text TEXT) → RRULE`**
Parse RRULE string to RRULE type.

**`rruleset(text TEXT) → RRULESET`**
Parse RRULESET string to RRULESET type.

**`jsonb_to_rrule(input JSONB) → RRULE`**
Convert JSONB to RRULE.

**`jsonb_to_rruleset(input JSONB) → RRULESET`**
Convert JSONB to RRULESET.

**`rrule_to_jsonb(rrule RRULE) → JSONB`**
Convert RRULE to JSONB.

**`rruleset_to_jsonb(rruleset RRULESET) → JSONB`**
Convert RRULESET to JSONB.

### Supported RRULE Properties

- `FREQ`: YEARLY, MONTHLY, WEEKLY, DAILY (required)
- `INTERVAL`: Positive integer (default: 1)
- `COUNT`: Number of occurrences (mutually exclusive with UNTIL)
- `UNTIL`: End timestamp (mutually exclusive with COUNT)
- `BYDAY`: Day of week (MO, TU, WE, TH, FR, SA, SU)
- `BYMONTHDAY`: Day of month (1-31, -31 to -1)
- `BYMONTH`: Month (1-12)
- `BYYEARDAY`: Day of year (1-366, -366 to -1)
- `BYWEEKNO`: Week of year (1-53, -53 to -1, only with FREQ=YEARLY)
- `BYSETPOS`: Occurrence positions within the recurrence set
- `WKST`: Week start day (default: MO)

## Testing

The test suite uses [pgTAP](https://pgtap.org/) for PostgreSQL unit testing.

### Recommended: Docker Testing

The easiest way to run tests is using Docker (see [Docker Development Environment](#docker-development-environment)):

```bash
make all    # Build and test
# or
make test   # Just run tests (if already built)
```

This provides a consistent, isolated testing environment with all dependencies pre-installed.

### Local Testing

If you prefer to run tests locally without Docker:

#### Install Test Dependencies

Install pgTAP from CPAN:

```bash
sudo cpan TAP::Parser::SourceHandler::pgTAP
```

Install the pgTAP PostgreSQL extension in your test database:

```bash
make pgtap
# Or manually:
psql -c "CREATE EXTENSION pgtap;" -d your_test_database
```

### Running Tests

Run all tests:

```bash
make compile
make local-execute
make local-test
```

Or combined:

```bash
make local-all && make local-test
```

Run tests on a specific database:

```bash
make local-test PGHOST=localhost PGPORT=5432 PGUSER=testuser
```

### Test Structure

Tests are organized in `tests/` directory:
- `test_parser.sql` - RRULE string parsing
- `test_occurrences.sql` - Occurrence generation
- `test_contains_timestamp.sql` - Containment operators
- `test_first.sql`, `test_last.sql` - First/last occurrence queries
- `test_is_finite.sql` - Finite ruleset detection
- Additional test files for specific features

## Troubleshooting

### Schema Not Found

If you get errors about missing functions or types:

```sql
-- Make sure the _rrule schema is in your search path
SET search_path TO public, _rrule;

-- Or use fully qualified names
SELECT _rrule.occurrences('...'::_rrule.RRULESET);
```

### Infinite Recurrence Error

If you see errors about infinite recurrence:

```sql
-- ❌ This will fail (no COUNT or UNTIL)
SELECT occurrences('DTSTART:20260101T090000
                    RRULE:FREQ=DAILY'::RRULESET);

-- ✅ Add COUNT or UNTIL
SELECT occurrences('DTSTART:20260101T090000
                    RRULE:FREQ=DAILY;COUNT=10'::RRULESET);
```

### Invalid RRULE Parameters

Common validation errors:

```sql
-- BYWEEKNO only works with FREQ=YEARLY
-- ❌ SELECT rrule('RRULE:FREQ=MONTHLY;BYWEEKNO=1');
-- ✅ SELECT rrule('RRULE:FREQ=YEARLY;BYWEEKNO=1;COUNT=5');

-- UNTIL and COUNT are mutually exclusive
-- ❌ SELECT rrule('RRULE:FREQ=DAILY;UNTIL=20260201T090000;COUNT=5');
-- ✅ SELECT rrule('RRULE:FREQ=DAILY;UNTIL=20260201T090000');

-- INTERVAL must be positive
-- ❌ SELECT rrule('RRULE:FREQ=DAILY;INTERVAL=0;COUNT=5');
-- ✅ SELECT rrule('RRULE:FREQ=DAILY;INTERVAL=1;COUNT=5');
```

### Reinstalling the Extension

**Docker (recommended):**
```bash
make rebuild  # Clean rebuild in Docker
```

**Local PostgreSQL:**
```bash
make local-clean  # Drop the _rrule schema
make local-all    # Recompile and reinstall
```

## Additional Resources

- [RFC 5545 - iCalendar Specification](https://tools.ietf.org/html/rfc5545)
- [iCalendar RRULE Tool](https://icalendar.org/rrule-tool.html) - Test and visualize RRULE patterns
- [pgTAP Documentation](https://pgtap.org/) - PostgreSQL testing framework

## Prior Art

This extension is based on prior work by [Matthew Schinckel](https://bitbucket.org/schinckel/postgres-rrule). The original implementation provided the foundation for parsing and validating RRULE specifications in PostgreSQL.

## Contributing

This repository is in maintenance mode, but bug reports and pull requests are welcome:

1. Fork the repository
2. Create a feature branch
3. Make your changes and add tests
4. Run `make all test` to verify
5. Submit a pull request

## Release Management

This project uses automated release management with semantic versioning and changelog generation.

### Creating a Release

Release creation is automated through Makefile targets. The release process:

1. Updates the VERSION file
2. Generates changelog entries from git commit history
3. Compiles the extension with version header
4. Creates a git commit and tag
5. Provides commands to push the release

**Available release types:**

```bash
# Patch release (0.0.X) - for bug fixes
make release-patch

# Minor release (0.X.0) - for new features (backward compatible)
make release-minor

# Major release (X.0.0) - for breaking changes
make release-major
```

**Preview changes without committing:**

```bash
make release-dry-run
```

**View current version:**

```bash
make show-version
```

### Publishing a Release

After creating a release, review the changes and push to the remote repository:

```bash
# Review the release commit
git show HEAD

# Review the changelog
cat CHANGELOG.md

# Push the release (with confirmation prompt)
make push-release
```

The `push-release` target will:
- Show a summary of what will be pushed
- Ask for confirmation
- Push the commit and tag to the remote
- Optionally create a GitHub release (if `gh` CLI is installed)

### Release Process Details

The release automation follows these principles:

- **Idempotent**: Safe to run multiple times - if a release already exists, it will exit gracefully
- **Conventional Commits**: Changelog is generated from commit messages following the [Conventional Commits](https://www.conventionalcommits.org/) format
- **Semantic Versioning**: Versions follow [semver](https://semver.org/) (MAJOR.MINOR.PATCH)
- **Safety Checks**: Verifies clean working directory and no uncommitted changes

**Commit Message Format:**

```
<type>(<scope>): <description>

Examples:
feat: add support for ordinal BYDAY
fix: correct timestamp parsing in edge cases
docs: update installation instructions
```

Common types: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `chore`

### Undoing a Release (Before Pushing)

If you need to undo a release before pushing:

```bash
# Reset to previous commit and remove tag
git reset --hard HEAD~1
git tag -d v<version>
```

### Changelog

All release notes are maintained in [CHANGELOG.md](CHANGELOG.md), which is automatically generated and updated with each release.

## License

The MIT License (MIT)

Copyright (c) 2015 Matthew Schinckel
Copyright (c) 2019 Volkan Unsal

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
