TESTS 		= $(find tests -name test_\*.sql)
PGHOST		= localhost
PGPORT		= 5432
PGPASSWORD	= unsafe
PGUSER		= postgres

clean:
	psql -c "DROP SCHEMA IF EXISTS _rrule CASCADE" -h ${PGHOST} -p ${PGPORT} -U ${PGUSER}

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
	pg_prove -h ${PGHOST} -p ${PGPORT} -U ${PGUSER} tests/test_*.sql

rm_rules:
	rm -f postgres-rrule.sql

compile: rm_rules schema types functions operators casts

execute:
	psql -X -f postgres-rrule.sql -h ${PGHOST} -p ${PGPORT} -U ${PGUSER}

dev: execute

pgtap: 
	psql -c "CREATE EXTENSION pgtap;" -h ${PGHOST} -p ${PGPORT} -U ${PGUSER}

all: compile execute
