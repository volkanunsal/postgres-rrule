TESTS = $(find tests -name test_\*.sql)

clean:
	psql -c "DROP SCHEMA IF EXISTS _rrule CASCADE"

schema:
	cat src/schema.sql >> postgres-rrule.sql

types:
	cat src/types/*.sql >> postgres-rrule.sql

funcs:
	cat src/functions/*.sql >> postgres-rrule.sql

operators:
	cat src/operators/*.sql >> postgres-rrule.sql

casts:
	cat src/casts/*.sql >> postgres-rrule.sql

test:
	psql -c "CREATE EXTENSION IF NOT EXISTS pgtap;" && pg_prove tests/test_*.sql

rm_rules:
	rm -f postgres-rrule.sql

compile: rm_rules schema types funcs operators casts

functions: rm_rules funcs execute

execute:
	psql -U postgres -d synbird -X -f postgres-rrule.sql

dev: execute

all: compile execute


