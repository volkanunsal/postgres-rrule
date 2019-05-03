TESTS = $(find tests -name test_\*.sql)

clean:
	psql -c "DROP SCHEMA IF EXISTS _rrule CASCADE"

schema:
	psql -X -f src/schema.sql

types:
	find src/types -name \*.sql | sort | xargs -L 1 psql -X -f

functions:
	find src/functions -name \*.sql| sort | xargs -L 1 psql -X -f

operators:
	find src/operators -name \*.sql | sort | xargs -L 1 psql -X -f

casts:
	find src/casts -name \*.sql | sort | xargs -L 1 psql -X -f

test:
	psql -c "CREATE EXTENSION IF NOT EXISTS pgtap;" && pg_prove tests/test_*.sql

all: schema types functions operators casts