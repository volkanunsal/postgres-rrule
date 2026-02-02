# Release Process Guide

This document provides a quick reference for maintainers on how to create and publish releases for postgres-rrule.

## Prerequisites

- Clean working directory (no uncommitted changes)
- All tests passing
- On the branch you want to release from (usually `master`)
- Git remote configured

## Quick Release Workflow

```bash
# 1. Ensure everything is up to date
git pull origin master
make all  # Build and test

# 2. Create a release (choose one)
make release-patch  # 0.0.X - Bug fixes
make release-minor  # 0.X.0 - New features (backward compatible)
make release-major  # X.0.0 - Breaking changes

# 3. Review the changes
git show HEAD        # Review commit
cat CHANGELOG.md     # Review changelog

# 4. Push the release
make push-release    # Prompts for confirmation

# 5. (Optional) Announce the release
# - Update release notes on GitHub
# - Notify users/contributors
```

## Detailed Steps

### 1. Pre-Release Checks

```bash
# Check current version
make show-version

# Ensure clean working directory
git status

# Run all tests
make all
```

### 2. Preview Release (Optional)

```bash
# See what would happen without making changes
make release-dry-run
```

This shows:
- What the new version will be
- How VERSION file will be updated
- What changelog entry will be generated
- What git operations will be performed

### 3. Create Release

Choose the appropriate release type based on [Semantic Versioning](https://semver.org/):

- **Patch** (0.0.X): Bug fixes, documentation updates, internal changes
- **Minor** (0.X.0): New features that are backward compatible
- **Major** (X.0.0): Breaking changes to the API

```bash
make release-patch
# OR
make release-minor
# OR
make release-major
```

This will:
1. ✓ Bump version in VERSION file
2. ✓ Generate changelog from git commits
3. ✓ Compile extension with version header
4. ✓ Create git commit
5. ✓ Create git tag (v{version})

### 4. Review Changes

Before pushing, carefully review:

```bash
# Review the release commit
git show HEAD

# Check the changelog entry
cat CHANGELOG.md | head -50

# Verify the version
cat VERSION

# Check the compiled SQL header
head postgres-rrule.sql
```

### 5. Push Release

```bash
make push-release
```

This will:
1. Show a summary of what will be pushed
2. Ask for confirmation (type `yes` to proceed)
3. Push commits to remote
4. Push tag to remote
5. Optionally create GitHub release (if `gh` CLI is available)

### 6. Post-Release

After pushing:

1. **Verify on GitHub/GitLab**: Check that the tag appears
2. **GitHub Release** (if not created automatically):
   - Go to Releases → Draft a new release
   - Select the tag
   - Copy changelog content
   - Publish release
3. **Announce**: Consider announcing in project channels

## Troubleshooting

### Uncommitted Changes Error

```
✗ You have uncommitted changes. Please commit or stash them first.
```

**Solution**: Commit or stash your changes before releasing.

```bash
git status
git add .
git commit -m "chore: prepare for release"
```

### Tag Already Exists

```
✗ Tag v0.1.0 already exists
```

**Solution**: This release has already been created. To re-create:

```bash
# Delete local tag
git tag -d v0.1.0

# Delete remote tag (if pushed)
git push origin :refs/tags/v0.1.0

# Run release again
make release-patch
```

### Need to Undo Release (Before Push)

If you created a release but haven't pushed yet:

```bash
# Reset to previous commit and remove tag
git reset --hard HEAD~1
git tag -d v{version}
```

## Conventional Commits

The changelog is automatically generated from commit messages. Follow this format:

```
<type>(<scope>): <description>

<type> = feat | fix | docs | test | refactor | perf | chore
```

### Examples

```bash
# Features
git commit -m "feat: add support for BYWEEKNO parameter"
git commit -m "feat(parser): improve error messages for invalid rules"

# Bug Fixes
git commit -m "fix: handle leap seconds correctly"
git commit -m "fix(occurrences): prevent infinite loop in edge case"

# Documentation
git commit -m "docs: update installation instructions"

# Tests
git commit -m "test: add coverage for BYSETPOS"

# Refactoring
git commit -m "refactor: simplify occurrence generation logic"

# Performance
git commit -m "perf: optimize date range queries"

# Chores
git commit -m "chore: update dependencies"
git commit -m "ci: add GitHub Actions workflow"
```

## Release Checklist

Before creating a release, ensure:

- [ ] All intended changes are committed
- [ ] Tests are passing (`make all`)
- [ ] Documentation is updated
- [ ] Breaking changes are documented
- [ ] Commit messages follow conventional commits format
- [ ] Working directory is clean

After creating a release:

- [ ] Reviewed changelog entry
- [ ] Reviewed version number
- [ ] Pushed release to remote
- [ ] Verified tag appears on GitHub/GitLab
- [ ] Created/updated GitHub release
- [ ] Announced release (if significant)

## Questions?

If you encounter issues with the release process, please:

1. Check this guide
2. Review the scripts in `scripts/`
3. Open an issue on GitHub
