CREATE TYPE _rrule.FREQ AS ENUM (
  'YEARLY',
  'MONTHLY',
  'WEEKLY',
  'DAILY'
);

CREATE TYPE _rrule.DAY AS ENUM (
  'MO',
  'TU',
  'WE',
  'TH',
  'FR',
  'SA',
  'SU'
);


CREATE TABLE _rrule.RRULE (
  "freq" _rrule.FREQ NOT NULL,
  "interval" INTEGER DEFAULT 1 NOT NULL CHECK(0 < "interval"),
  "count" INTEGER,  -- Number of occurrences to generate (RFC 5545: positive integer)
  "until" TIMESTAMP,  -- End date for recurrence (RFC 5545: cannot coexist with COUNT)

  -- Time component constraints (RFC 5545 section 3.3.10)
  "bysecond" INTEGER[] CHECK (0 <= ALL("bysecond") AND 60 > ALL("bysecond")),  -- 0-59 (60 for leap second)
  "byminute" INTEGER[] CHECK (0 <= ALL("byminute") AND 60 > ALL("byminute")),  -- 0-59
  "byhour" INTEGER[] CHECK (0 <= ALL("byhour") AND 24 > ALL("byhour")),        -- 0-23
  "byday" _rrule.DAY[],  -- MO, TU, WE, TH, FR, SA, SU (optionally prefixed with ordinal)

  -- Date component constraints (RFC 5545 section 3.3.10)
  "bymonthday" INTEGER[] CHECK (31 >= ALL("bymonthday") AND 0 <> ALL("bymonthday") AND -31 <= ALL("bymonthday")),  -- 1-31 or -31 to -1 (negative counts from end)
  "byyearday" INTEGER[] CHECK (366 >= ALL("byyearday") AND 0 <> ALL("byyearday") AND -366 <= ALL("byyearday")),    -- 1-366 or -366 to -1 (leap year aware)
  "byweekno" INTEGER[] CHECK (53 >= ALL("byweekno") AND 0 <> ALL("byweekno") AND -53 <= ALL("byweekno")),          -- 1-53 or -53 to -1 (ISO week numbers)
  "bymonth" INTEGER[] CHECK (0 < ALL("bymonth") AND 12 >= ALL("bymonth")),     -- 1-12 (January through December)
  "bysetpos" INTEGER[] CHECK(366 >= ALL("bysetpos") AND 0 <> ALL("bysetpos") AND -366 <= ALL("bysetpos")),         -- Position in occurrence set

  "wkst" _rrule.DAY,  -- Week start day (RFC 5545 default: MO)

  -- RFC 5545: BYWEEKNO is only valid for YEARLY frequency
  CONSTRAINT freq_yearly_if_byweekno CHECK("freq" = 'YEARLY' OR "byweekno" IS NULL)
);


CREATE TABLE _rrule.RRULESET (
  "dtstart" TIMESTAMP NOT NULL,
  "dtend" TIMESTAMP,
  "rrule" _rrule.RRULE,
  "exrule" _rrule.RRULE,
  "rdate" TIMESTAMP[],
  "exdate" TIMESTAMP[]
);


CREATE TYPE _rrule.exploded_interval AS (
  "months" INTEGER,
  "days" INTEGER,
  "seconds" INTEGER
);