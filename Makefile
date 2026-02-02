TESTS 		= $(find tests -name test_\*.sql)
PGHOST		= localhost
PGPORT		= 5432
PGPASSWORD	= unsafe
PGUSER		= postgres

# Docker configuration
DOCKER_IMAGE_NAME	= postgres-rrule
DOCKER_CONTAINER_NAME	= postgres-rrule-test
DOCKER_DB_PORT		= 5433
DOCKER_BASE_IMAGE	= postgres:16

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "postgres-rrule Makefile Commands"
	@echo "================================="
	@echo ""
	@echo "🐳 Docker Commands (Default):"
	@echo "  make all              - Build Docker image and run tests"
	@echo "  make build            - Build Docker image with dependencies"
	@echo "  make test             - Run tests in Docker container"
	@echo "  make clean            - Stop container and remove Docker resources"
	@echo "  make rebuild          - Clean rebuild from scratch"
	@echo "  make start            - Start PostgreSQL container (detached)"
	@echo "  make stop             - Stop and remove container"
	@echo "  make shell            - Open bash shell in running container"
	@echo "  make psql             - Open psql session in running container"
	@echo "  make logs             - View container logs"
	@echo ""
	@echo "📝 Build Commands (No Database Required):"
	@echo "  make compile          - Compile SQL source files into postgres-rrule.sql"
	@echo ""
	@echo "💻 Local PostgreSQL Commands (Optional):"
	@echo "  make local-all        - Compile and install extension locally"
	@echo "  make local-execute    - Install extension into local PostgreSQL"
	@echo "  make local-test       - Run tests on local PostgreSQL"
	@echo "  make local-clean      - Drop _rrule schema from local database"
	@echo "  make local-pgtap      - Install pgTAP extension locally"
	@echo ""
	@echo "Docker Configuration:"
	@echo "  Image: $(DOCKER_IMAGE_NAME)"
	@echo "  Container: $(DOCKER_CONTAINER_NAME)"
	@echo "  Port: $(DOCKER_DB_PORT) -> 5432"
	@echo "  Base: $(DOCKER_BASE_IMAGE)"
	@echo ""
	@echo "💡 Quick Start: make all"
	@echo ""

# ============================================================================
# Compilation Targets (No Database Required)
# ============================================================================

.PHONY: rm_rules schema types functions operators casts compile

rm_rules:
	rm -f postgres-rrule.sql

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

compile: rm_rules schema types functions operators casts

# ============================================================================
# Docker Targets (Default)
# ============================================================================

.PHONY: all build test clean rebuild start stop shell psql logs pull

# Main targets use Docker by default
all: build test

build: pull
	@echo "Building Docker image $(DOCKER_IMAGE_NAME)..."
	docker build -t $(DOCKER_IMAGE_NAME) .

pull:
	@echo "Pulling base PostgreSQL image..."
	docker pull $(DOCKER_BASE_IMAGE)

start:
	@echo "Starting PostgreSQL container..."
	@docker rm -f $(DOCKER_CONTAINER_NAME) 2>/dev/null || true
	docker run -d \
		--name $(DOCKER_CONTAINER_NAME) \
		-e POSTGRES_USER=$(PGUSER) \
		-e POSTGRES_PASSWORD=$(PGPASSWORD) \
		-e POSTGRES_DB=postgres \
		-p $(DOCKER_DB_PORT):5432 \
		-v $(PWD):/workspace \
		$(DOCKER_IMAGE_NAME)
	@echo "Waiting for PostgreSQL to be ready..."
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		docker exec $(DOCKER_CONTAINER_NAME) pg_isready -U $(PGUSER) >/dev/null 2>&1 && break || sleep 2; \
	done
	@echo "PostgreSQL is ready!"

stop:
	@echo "Stopping Docker container..."
	@docker stop $(DOCKER_CONTAINER_NAME) 2>/dev/null || true
	@docker rm $(DOCKER_CONTAINER_NAME) 2>/dev/null || true

test: start
	@echo "Compiling extension inside container..."
	docker exec $(DOCKER_CONTAINER_NAME) sh -c "cd /workspace && make compile"
	@echo "Installing extension inside container..."
	docker exec $(DOCKER_CONTAINER_NAME) sh -c "cd /workspace && psql -X -f postgres-rrule.sql -U $(PGUSER)"
	@echo "Installing pgTAP extension..."
	docker exec $(DOCKER_CONTAINER_NAME) psql -U $(PGUSER) -c "CREATE EXTENSION IF NOT EXISTS pgtap;"
	@echo "Running tests inside container..."
	docker exec $(DOCKER_CONTAINER_NAME) sh -c "cd /workspace && pg_prove -U $(PGUSER) tests/test_*.sql"
	@$(MAKE) stop

shell:
	@echo "Opening shell in container (container must be running)..."
	@docker exec -it $(DOCKER_CONTAINER_NAME) /bin/bash || \
		(echo "Container not running. Start it with: make start" && exit 1)

psql:
	@echo "Opening psql in container (container must be running)..."
	@docker exec -it $(DOCKER_CONTAINER_NAME) psql -U $(PGUSER) || \
		(echo "Container not running. Start it with: make start" && exit 1)

logs:
	@docker logs -f $(DOCKER_CONTAINER_NAME) || \
		(echo "Container not running. Start it with: make start" && exit 1)

clean: stop
	@echo "Removing Docker image..."
	@docker rmi $(DOCKER_IMAGE_NAME) 2>/dev/null || true
	@echo "Pruning Docker resources..."
	@docker system prune -f
	@echo "Docker cleanup complete!"

rebuild: clean all

# ============================================================================
# Local PostgreSQL Targets (Optional)
# ============================================================================

.PHONY: local-all local-execute local-test local-clean local-pgtap local-dev

local-clean:
	@echo "Dropping _rrule schema from local PostgreSQL..."
	psql -c "DROP SCHEMA IF EXISTS _rrule CASCADE" -h ${PGHOST} -p ${PGPORT} -U ${PGUSER}

local-execute:
	@echo "Installing extension into local PostgreSQL..."
	psql -X -f postgres-rrule.sql -h ${PGHOST} -p ${PGPORT} -U ${PGUSER}

local-test:
	@echo "Running tests on local PostgreSQL..."
	pg_prove -h ${PGHOST} -p ${PGPORT} -U ${PGUSER} tests/test_*.sql

local-pgtap:
	@echo "Installing pgTAP extension in local PostgreSQL..."
	psql -c "CREATE EXTENSION pgtap;" -h ${PGHOST} -p ${PGPORT} -U ${PGUSER}

local-all: compile local-execute

local-dev: local-execute

# ============================================================================
# Compatibility Aliases (Deprecated - use main targets instead)
# ============================================================================

.PHONY: docker-pull docker-build docker-start docker-stop docker-test docker-shell docker-psql docker-logs docker-clean docker-all docker-rebuild

docker-pull: pull
	@echo "⚠️  Note: 'docker-pull' is deprecated. Use 'make pull' instead."

docker-build: build
	@echo "⚠️  Note: 'docker-build' is deprecated. Use 'make build' instead."

docker-start: start
	@echo "⚠️  Note: 'docker-start' is deprecated. Use 'make start' instead."

docker-stop: stop
	@echo "⚠️  Note: 'docker-stop' is deprecated. Use 'make stop' instead."

docker-test: test
	@echo "⚠️  Note: 'docker-test' is deprecated. Use 'make test' instead."

docker-shell: shell
	@echo "⚠️  Note: 'docker-shell' is deprecated. Use 'make shell' instead."

docker-psql: psql
	@echo "⚠️  Note: 'docker-psql' is deprecated. Use 'make psql' instead."

docker-logs: logs
	@echo "⚠️  Note: 'docker-logs' is deprecated. Use 'make logs' instead."

docker-clean: clean
	@echo "⚠️  Note: 'docker-clean' is deprecated. Use 'make clean' instead."

docker-all: all
	@echo "⚠️  Note: 'docker-all' is deprecated. Use 'make all' instead."

docker-rebuild: rebuild
	@echo "⚠️  Note: 'docker-rebuild' is deprecated. Use 'make rebuild' instead."

# Deprecated local aliases
.PHONY: execute dev pgtap

execute: local-execute
	@echo "⚠️  Note: 'execute' is deprecated. Use 'make local-execute' for local PostgreSQL."

dev: local-dev
	@echo "⚠️  Note: 'dev' is deprecated. Use 'make local-dev' for local PostgreSQL."

pgtap: local-pgtap
	@echo "⚠️  Note: 'pgtap' is deprecated. Use 'make local-pgtap' for local PostgreSQL."
