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
  "count" INTEGER,
  "until" TIMESTAMP,
  "bysecond" INTEGER[] CHECK (0 <= ALL("bysecond") AND 60 > ALL("bysecond")),
  "byminute" INTEGER[] CHECK (0 <= ALL("byminute") AND 60 > ALL("byminute")),
  "byhour" INTEGER[] CHECK (0 <= ALL("byhour") AND 24 > ALL("byhour")),
  "byday" _rrule.DAY[],
  "bymonthday" INTEGER[] CHECK (31 >= ALL("bymonthday") AND 0 <> ALL("bymonthday") AND -31 <= ALL("bymonthday")),
  "byyearday" INTEGER[] CHECK (366 >= ALL("byyearday") AND 0 <> ALL("byyearday") AND -366 <= ALL("byyearday")),
  "byweekno" INTEGER[] CHECK (53 >= ALL("byweekno") AND 0 <> ALL("byweekno") AND -53 <= ALL("byweekno")),
  "bymonth" INTEGER[] CHECK (0 < ALL("bymonth") AND 12 >= ALL("bymonth")),
  "bysetpos" INTEGER[] CHECK(366 >= ALL("bysetpos") AND 0 <> ALL("bysetpos") AND -366 <= ALL("bysetpos")),
  "wkst" _rrule.DAY,

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