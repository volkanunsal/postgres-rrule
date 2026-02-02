DROP SCHEMA IF EXISTS _rrule CASCADE;

DROP CAST IF EXISTS (_rrule.RRULE AS TEXT);
DROP CAST IF EXISTS (TEXT AS _rrule.RRULE);

CREATE SCHEMA _rrule;

COMMENT ON SCHEMA _rrule IS
'PostgreSQL implementation of RFC 5545 recurrence rules (RRULE).

This schema provides types and functions for working with iCalendar recurrence rules,
allowing complex recurring event patterns to be stored and queried efficiently.

Main types:
- RRULE: Single recurrence rule with frequency, interval, and BY* constraints
- RRULESET: Collection of rules with DTSTART, DTEND, RDATE, and EXDATE
- FREQ: Enumeration of recurrence frequencies (YEARLY, MONTHLY, WEEKLY, DAILY)
- DAY: Enumeration of weekdays (MO, TU, WE, TH, FR, SA, SU)

Key functions:
- rrule(TEXT): Parse RRULE string into RRULE type
- occurrences(): Generate timestamps for recurring events
- is_finite(): Check if recurrence has a defined end
- first(), last(), before(), after(): Query occurrence boundaries
- contains_timestamp(): Check if timestamp matches recurrence pattern
- jsonb_to_rrule(), rrule_to_jsonb(): Convert between RRULE and JSONB

For more information, see: https://datatracker.ietf.org/doc/html/rfc5545#section-3.3.10
';

