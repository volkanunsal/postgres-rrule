TESTS 		:= $(find tests -name test_\*.sql)
PGHOST		:= localhost
PGPASSWORD	:= unsafe
PGUSER		:= postgres

clean:
	psql -c "DROP SCHEMA IF EXISTS _rrule CASCADE"

schema:
	cat src/schema.sql >> postgres-rrule.sql

types:
	find src/types -name \*.sql | sort | xargs -I % cat % >> postgres-rrule.sql

functions:
	find src/functions -name \*.sql| sort | xargs -I % cat % >> postgres-rrule.sql

operators:
	find src/operators -name \*.sql | sort | xargs -I % cat % >> postgres-rrule.sql

casts:
	find src/casts -name \*.sql | sort | xargs -I % cat % >> postgres-rrule.sql

test:
	pg_prove tests/test_*.sql

rm_rules:
	rm -f postgres-rrule.sql

compile: rm_rules schema types functions operators casts

execute:
	psql -X -f postgres-rrule.sql

dev: execute

all: compile execute
