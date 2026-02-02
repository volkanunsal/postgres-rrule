# Docker Setup Summary

This document summarizes the Docker development environment that has been added to the postgres-rrule repository.

## What Was Added

### 1. Dockerfile

**Location**: `../Dockerfile`

A multi-layer Docker image based on `postgres:16` that includes:

- PostgreSQL 16 server
- pgTAP extension (built from source)
- TAP::Parser::SourceHandler::pgTAP (Perl module for pg_prove)
- Build dependencies (gcc, make, git, cpanminus)

**Key Features**:

- Uses official `postgres:16` as base (fast to pull, well-maintained)
- Installs pgTAP from GitHub source (latest version)
- Sets up working directory at `/workspace`
- Pre-configures database credentials

### 2. Enhanced Makefile

**Location**: `../Makefile`

**BREAKING CHANGE**: Docker is now the default! All main targets use Docker.

**Main Commands (Docker - Default)**:

- `make all` - Build and test in one command (most common)
- `make test` - Run complete test suite in clean container
- `make build` - Build the postgres-rrule image
- `make pull` - Pull the postgres:16 base image
- `make help` - Show all available commands

**Development Commands**:

- `make start` - Start detached container for interactive use
- `make stop` - Stop and remove container
- `make shell` - Open bash shell in running container
- `make psql` - Open psql session in running container
- `make logs` - View container logs (follows output)

**Maintenance Commands**:

- `make clean` - Remove image and prune Docker resources
- `make rebuild` - Complete clean rebuild from scratch

**Local PostgreSQL Commands (Optional)**:

- `make local-all` - Compile and install locally
- `make local-test` - Run tests on local PostgreSQL
- `make local-execute` - Install into local PostgreSQL
- `make local-clean` - Drop \_rrule schema locally
- `make local-pgtap` - Install pgTAP locally

**Backward Compatibility**: Old `docker-*` commands still work but show deprecation warnings.

### 3. Docker Ignore File

**Location**: `../.dockerignore`

Optimizes Docker build context by excluding:

- Git metadata
- IDE configuration files
- OS-specific files
- Documentation (except CLAUDE.md)

### 4. Documentation

**DOCKER.md** - Comprehensive guide covering:

- Detailed usage patterns
- Troubleshooting common issues
- CI/CD integration examples
- Performance optimization tips
- Advanced usage scenarios
- Makefile reference table

**README.md** - Updated with:

- New "Docker Development Environment" section
- Quick start examples
- Docker target reference
- Container configuration details
- Comparison with local development

**CLAUDE.md** - Updated with:

- Docker workflow documentation
- Quick reference for future AI assistants
- Docker configuration details

## Quick Start Guide

**Note:** Docker is now the default! All main commands use Docker without the `docker-` prefix.

### First Time Setup

```bash
# Build the Docker image and run tests (5-10 minutes first time)
make all
```

### Daily Development Workflow

```bash
# After making code changes, run tests
make test

# For debugging, use interactive mode
make start
make psql
# ... test queries ...
make stop
```

### Weekly Maintenance

```bash
# Clean up Docker resources periodically
make clean

# Rebuild from scratch if needed
make rebuild
```

### Using Local PostgreSQL (Optional)

```bash
# If you prefer local PostgreSQL instead of Docker
make local-all        # Compile and install
make local-test       # Run tests
make local-clean      # Clean up
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ Host Machine                                        │
│                                                     │
│  ┌─────────────────────────────────────────────┐  │
│  │ Repository Files (./postgres-rrule)         │  │
│  │ - src/*.sql                                 │  │
│  │ - tests/*.sql                               │  │
│  │ - Makefile, Dockerfile                      │  │
│  └─────────────┬───────────────────────────────┘  │
│                │ Volume Mount                      │
│                ▼                                   │
│  ┌─────────────────────────────────────────────┐  │
│  │ Docker Container: postgres-rrule-test       │  │
│  │                                             │  │
│  │  ┌──────────────────────────────────────┐  │  │
│  │  │ /workspace (mounted from host)       │  │  │
│  │  │ - Full repository access             │  │  │
│  │  │ - Compile and test here              │  │  │
│  │  └──────────────────────────────────────┘  │  │
│  │                                             │  │
│  │  ┌──────────────────────────────────────┐  │  │
│  │  │ PostgreSQL 16                        │  │  │
│  │  │ - Port 5432 (→ Host 5433)           │  │  │
│  │  │ - pgTAP extension installed          │  │  │
│  │  │ - User: postgres / Pass: unsafe      │  │  │
│  │  └──────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Configuration

### Default Settings

| Setting        | Value               | Override Method                          |
| -------------- | ------------------- | ---------------------------------------- |
| Base Image     | postgres:16         | Edit `DOCKER_BASE_IMAGE` in Makefile     |
| Image Name     | postgres-rrule      | Edit `DOCKER_IMAGE_NAME` in Makefile     |
| Container Name | postgres-rrule-test | Edit `DOCKER_CONTAINER_NAME` in Makefile |
| Host Port      | 5433                | Edit `DOCKER_DB_PORT` in Makefile        |
| Container Port | 5432                | Fixed (PostgreSQL default)               |
| DB User        | postgres            | Edit `PGUSER` in Makefile                |
| DB Password    | unsafe              | Edit `PGPASSWORD` in Makefile            |
| Working Dir    | /workspace          | Edit in Dockerfile                       |

### Customizing the Environment

To add custom tools or configurations:

1. Edit `Dockerfile` to add installations:

   ```dockerfile
   RUN apt-get install -y your-tool
   ```

2. Rebuild the image:
   ```bash
   make rebuild
   ```

## Comparison: Docker vs Local Development

### When to Use Docker

✅ **Best for:**

- Running tests before commits
- CI/CD pipelines
- Ensuring consistent behavior across team
- Isolating from local PostgreSQL installation
- Quick setup on new machines

### When to Use Local

✅ **Best for:**

- Active development with frequent iterations
- Debugging with local tools
- Production-like testing with existing data
- Performance-critical benchmarking

## Troubleshooting Quick Reference

### "Cannot connect to Docker daemon"

```bash
# Start Docker Desktop or Docker daemon
open -a Docker  # macOS
systemctl start docker  # Linux
```

### "Port 5433 already in use"

```bash
# Find what's using the port
lsof -i :5433

# Change port in Makefile
# Edit: DOCKER_DB_PORT = 5434
```

### "Container name already exists"

```bash
make stop   # Force remove
make start  # Start fresh
```

### "Tests failing in Docker but not locally"

```bash
# Check container logs
make logs

# Run tests with verbose output
make start
docker exec postgres-rrule-test pg_prove -v tests/test_*.sql
```

### "Docker build is slow"

```bash
# First time is slow (10 min), subsequent builds are cached
# To speed up:
make pull  # Pull base image first (caches it)

# If really slow, check Docker has enough resources
# Docker Desktop → Settings → Resources → Memory: 4GB+
```

## Testing the Setup

Verify everything works:

```bash
# 1. Check Docker is running
docker --version
docker ps

# 2. Build and test (one command!)
make all

# Expected output:
# Pulling base PostgreSQL image...
# Building Docker image postgres-rrule...
# Starting PostgreSQL container...
# PostgreSQL is ready!
# Compiling extension inside container...
# Installing extension inside container...
# Installing pgTAP extension...
# Running tests inside container...
# tests/test_*.sql .. ok
# All tests successful.
```

Or step by step:

```bash
# Pull base image (verify network access)
make pull

# Build image (verify Dockerfile is correct)
make build

# Run tests (verify complete workflow)
make test
```

## Integration with CI/CD

### GitHub Actions

Add to `.github/workflows/test.yml`:

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Docker tests
        run: make docker-all
```

### GitLab CI

Add to `.gitlab-ci.yml`:

```yaml
test:
  image: docker:latest
  services:
    - docker:dind
  script:
    - make docker-all
```

## Performance Notes

### Build Times

- **First build**: 5-10 minutes (downloads base image, compiles pgTAP)
- **Cached builds**: 30-60 seconds (uses Docker layer cache)
- **Test run**: 5-15 seconds (depends on test count)

### Optimization Tips

1. **Use `docker-all` for regular testing** - Fastest for common case
2. **Don't run `docker-clean` unnecessarily** - Preserves cache
3. **Keep container running during debugging** - Use `docker-start` once
4. **Allocate enough memory to Docker** - 4GB+ recommended

## Files Created

Summary of all new files:

```
postgres-rrule/
├── Dockerfile                    # Docker image definition
├── .dockerignore                 # Build context optimization
├── DOCKER.md                     # Comprehensive Docker guide
├── DOCKER_SETUP_SUMMARY.md       # This file
├── Makefile (modified)           # Added Docker targets
├── README.md (modified)          # Added Docker section
└── CLAUDE.md (modified)          # Added Docker workflow
```

## Next Steps

1. **Start Docker** if not already running
2. **Run `make all`** to verify setup works
3. **Read DOCKER.md** for detailed usage patterns
4. **Integrate into your workflow** - use `make test` before commits

## Support

For Docker-specific issues:

- See [DOCKER.md](DOCKER.md) for detailed troubleshooting
- Check Docker logs: `make logs`
- Rebuild from scratch: `make rebuild`

For general issues:

- See main [README.md](../README.md)
- Check test output in container: `make start && make shell`

## Summary

You now have a complete Docker development environment that:

- ✅ Provides consistent testing across all machines
- ✅ Includes all dependencies (PostgreSQL 16, pgTAP, pg_prove)
- ✅ Offers both quick testing and interactive debugging
- ✅ Is ready for CI/CD integration
- ✅ Is well-documented with examples
- ✅ **Docker is now the default** - simpler commands!

**Get started now:**

```bash
make all
```
