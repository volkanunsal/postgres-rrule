CREATE OPERATOR = (
  LEFTARG = _rrule.RRULE,
  RIGHTARG = _rrule.RRULE,
  PROCEDURE = _rrule.compare_equal,
  NEGATOR = <>,
  COMMUTATOR = =
);

CREATE OPERATOR <> (
  LEFTARG = _rrule.RRULE,
  RIGHTARG = _rrule.RRULE,
  PROCEDURE = _rrule.compare_not_equal,
  NEGATOR = =,
  COMMUTATOR = <>
);

CREATE OPERATOR @> (
  LEFTARG = _rrule.RRULE,
  RIGHTARG = _rrule.RRULE,
  PROCEDURE = _rrule.contains,
  COMMUTATOR = <@
);

CREATE OPERATOR <@ (
  LEFTARG = _rrule.RRULE,
  RIGHTARG = _rrule.RRULE,
  PROCEDURE = _rrule.contained_by,
  COMMUTATOR = @>
);

CREATE OPERATOR @> (
  LEFTARG = _rrule.RRULESET,
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.contains_timestamp
);

CREATE OPERATOR @> (
  LEFTARG = _rrule.RRULESET[],
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_array_contains_timestamp
);


CREATE OPERATOR > (
  LEFTARG = _rrule.RRULESET[],
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_array_has_after_timestamp
);

CREATE OPERATOR < (
  LEFTARG = _rrule.RRULESET[],
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_array_has_before_timestamp
);

CREATE OPERATOR > (
  LEFTARG = _rrule.RRULESET,
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_has_after_timestamp
);

CREATE OPERATOR < (
  LEFTARG = _rrule.RRULESET,
  RIGHTARG = TIMESTAMP,
  PROCEDURE = _rrule.rruleset_has_before_timestamp
);

