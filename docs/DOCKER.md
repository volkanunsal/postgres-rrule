# Docker Development Guide

This document provides detailed information about using Docker for postgres-rrule development and testing.

**Note:** Docker is now the default for all main commands. The `docker-` prefix is optional and will show deprecation warnings.

## Quick Start

```bash
# One-command setup and test
make all
```

## Overview

The Docker environment provides:

- PostgreSQL 16 with pgTAP extension pre-installed
- All build dependencies (make, perl, cpan modules)
- Isolated, reproducible testing environment
- Consistent behavior across Linux, macOS, and Windows

## Architecture

### Docker Image: `postgres-rrule`

Built from `postgres:16` official image with:

- PostgreSQL 16 server
- pgTAP extension (from source)
- TAP::Parser::SourceHandler::pgTAP (Perl module for pg_prove)
- Build tools (gcc, make, git)

### Docker Container: `postgres-rrule-test`

Runtime configuration:

- **Port mapping**: Host `5433` → Container `5432`
- **Volume mount**: `$(PWD)` → `/workspace`
- **Database**: postgres
- **User**: postgres
- **Password**: unsafe
- **Working directory**: `/workspace`

## Usage Patterns

### Pattern 1: Quick Test Run

For quick verification after making changes:

```bash
make test
```

This will:

1. Start a fresh container
2. Compile the extension
3. Install it
4. Run all tests
5. Stop and remove the container

### Pattern 2: Interactive Development

For debugging or manual testing:

```bash
# Start container
make start

# Open psql to test queries
make psql
postgres=# SET search_path TO public, _rrule;
postgres=# SELECT '...'::RRULESET;

# Or open a shell for exploration
make shell
root@container:/workspace# pg_prove tests/test_parser.sql

# View logs if needed
make logs

# Stop when done
make stop
```

### Pattern 3: Full Clean Build

For ensuring a completely fresh environment:

```bash
make rebuild
```

This performs:

1. `clean` - Remove all existing images/containers
2. `build` - Build fresh image from scratch
3. `test` - Run full test suite

## Troubleshooting

### Container Already Running

If you see "container name already in use":

```bash
make stop   # Force stop and remove
make start  # Start fresh
```

### Port Already in Use

If port 5433 is already in use, edit the Makefile:

```makefile
DOCKER_DB_PORT = 5434  # Or another available port
```

### Build Failures

If the Docker build fails:

```bash
# Check Docker is running
docker ps

# Clean and retry
make clean
make build

# View build output
docker build -t postgres-rrule .
```

### Test Failures

To debug test failures:

```bash
# Run tests with verbose output
make start
docker exec postgres-rrule-test sh -c "cd /workspace && pg_prove -v tests/test_*.sql"

# Or run a specific test
docker exec postgres-rrule-test sh -c "cd /workspace && pg_prove tests/test_parser.sql"

# Check PostgreSQL logs
make logs
```

### Permission Issues

If you encounter permission issues with mounted volumes:

```bash
# On Linux, ensure files are readable
chmod -R 755 .

# Or run container with your user ID
docker run -u $(id -u):$(id -g) ...
```

## Advanced Usage

### Running Specific Tests

```bash
make start

# Run single test file
docker exec postgres-rrule-test pg_prove -U postgres /workspace/tests/test_parser.sql

# Run with verbose output
docker exec postgres-rrule-test pg_prove -v -U postgres /workspace/tests/test_*.sql
```

### Connecting from Host

While the container is running, you can connect from your host machine:

```bash
psql -h localhost -p 5433 -U postgres -d postgres
# Password: unsafe
```

### Customizing the Environment

Edit `Dockerfile` to add additional tools or modify configuration:

```dockerfile
# Add debugging tools
RUN apt-get install -y vim less

# Install additional Perl modules
RUN cpanm Some::Module

# Set custom PostgreSQL configs
RUN echo "log_statement = 'all'" >> /etc/postgresql/postgresql.conf
```

Then rebuild:

```bash
make rebuild
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests in Docker
        run: make all
```

### GitLab CI Example

```yaml
test:
  image: docker:latest
  services:
    - docker:dind
  script:
    - make all
```

## Performance Optimization

### Speeding Up Builds

1. **Use Docker cache**: Don't run `make clean` unless necessary
2. **Pull base image first**: `make pull` caches the base image
3. **Multi-stage builds**: For production, consider multi-stage Dockerfile

### Reducing Image Size

For a smaller production image, use multi-stage build in Dockerfile:

```dockerfile
# Build stage
FROM postgres:16 AS builder
RUN apt-get update && apt-get install -y ...
RUN git clone ... && make install

# Runtime stage
FROM postgres:16
COPY --from=builder /usr/share/postgresql/16/extension /usr/share/postgresql/16/extension
```

## Makefile Reference

All Docker-related targets in the Makefile:

| Target    | Description                | Dependencies      |
| --------- | -------------------------- | ----------------- |
| `all`     | Build and test (default)   | build, test       |
| `build`   | Build development image    | pull              |
| `pull`    | Pull base PostgreSQL image | None              |
| `test`    | Run full test suite        | start             |
| `start`   | Start detached container   | None              |
| `stop`    | Stop and remove container  | None              |
| `shell`   | Open bash in container     | Container running |
| `psql`    | Open psql in container     | Container running |
| `logs`    | View container logs        | Container running |
| `clean`   | Remove image and prune     | stop              |
| `rebuild` | Clean and rebuild          | clean, all        |
| `compile` | Compile SQL files          | None              |

**Local PostgreSQL targets:**
| Target | Description |
|--------|-------------|
| `local-all` | Compile and install locally |
| `local-execute` | Install into local PostgreSQL |
| `local-test` | Run tests on local PostgreSQL |
| `local-clean` | Drop \_rrule schema locally |
| `local-pgtap` | Install pgTAP locally |

**Note:** Old `docker-*` prefixed commands still work but show deprecation warnings.

## Best Practices

1. **Use `make all` for regular testing** - It's fast and ensures clean state
2. **Use `make start` + `make psql` for debugging** - Interactive exploration
3. **Run `make clean` periodically** - Free up disk space
4. **Don't edit inside container** - Changes won't persist; edit on host
5. **Use `.dockerignore`** - Keep build context small and fast
6. **Default is Docker** - No need for `docker-` prefix anymore

## Comparison: Docker vs Local

| Aspect       | Docker                | Local               |
| ------------ | --------------------- | ------------------- |
| Setup time   | 5-10 min (first time) | 15-30 min           |
| Consistency  | Identical everywhere  | Varies by system    |
| Isolation    | Complete              | Shared with system  |
| Speed        | Slightly slower       | Faster              |
| CI/CD        | Excellent             | Harder to reproduce |
| Dependencies | Self-contained        | Manual install      |

## Further Reading

- [PostgreSQL Docker Official Image](https://hub.docker.com/_/postgres)
- [pgTAP Documentation](https://pgtap.org/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
