#!/usr/bin/env bash
# Prepare a new release
# This script is idempotent and can be run multiple times

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_error() { echo -e "${RED}✗ $1${NC}" >&2; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Parse arguments
BUMP_TYPE=$1
DRY_RUN=${2:-false}

if [ "$DRY_RUN" = "--dry-run" ] || [ "$DRY_RUN" = "-n" ]; then
    DRY_RUN=true
else
    DRY_RUN=false
fi

# Validate bump type
if [ -z "$BUMP_TYPE" ]; then
    print_error "Usage: $0 <major|minor|patch> [--dry-run]"
    exit 1
fi

if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
    print_error "Invalid bump type. Use: major, minor, or patch"
    exit 1
fi

cd "$PROJECT_ROOT"

print_info "Starting release preparation (bump: $BUMP_TYPE)"
if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN MODE - No changes will be made"
fi

# Check if git is available
if ! command -v git &> /dev/null; then
    print_error "git is not installed or not in PATH"
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not in a git repository"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    print_error "You have uncommitted changes. Please commit or stash them first."
    git status --short
    exit 1
fi

# Check if we're on a branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
print_info "Current branch: $CURRENT_BRANCH"

# Read current version
if [ ! -f "VERSION" ]; then
    print_error "VERSION file not found"
    exit 1
fi

CURRENT_VERSION=$(cat VERSION | tr -d '[:space:]')
print_info "Current version: $CURRENT_VERSION"

# Calculate new version
NEW_VERSION=$("$SCRIPT_DIR/semver-bump.sh" "$CURRENT_VERSION" "$BUMP_TYPE")
print_info "New version: $NEW_VERSION"

# Get the previous tag (if any)
PREVIOUS_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -z "$PREVIOUS_TAG" ]; then
    print_info "No previous tags found - this will be the first release"
else
    print_info "Previous tag: $PREVIOUS_TAG"
fi

# Check if tag already exists
if git rev-parse "v$NEW_VERSION" >/dev/null 2>&1; then
    print_error "Tag v$NEW_VERSION already exists"
    print_info "This release has already been created. If you want to re-release:"
    print_info "  1. Delete the tag: git tag -d v$NEW_VERSION"
    print_info "  2. Delete the remote tag: git push origin :refs/tags/v$NEW_VERSION"
    print_info "  3. Run this command again"
    exit 0  # Exit 0 for idempotency
fi

if [ "$DRY_RUN" = true ]; then
    print_info "Would update VERSION file to $NEW_VERSION"
    print_info "Would generate changelog entry"
    print_info "Would update compiled SQL header"
    print_info "Would create git commit"
    print_info "Would create git tag v$NEW_VERSION"
    print_success "Dry run completed successfully"
    exit 0
fi

# Update VERSION file
echo "$NEW_VERSION" > VERSION
print_success "Updated VERSION file"

# Generate changelog
"$SCRIPT_DIR/generate-changelog.sh" "$NEW_VERSION" "$PREVIOUS_TAG"
print_success "Generated changelog entry"

# Compile the extension with version info
print_info "Compiling extension..."
make compile > /dev/null 2>&1

# Add version comment to compiled SQL
if [ -f "postgres-rrule.sql" ]; then
    {
        echo "-- postgres-rrule v$NEW_VERSION"
        echo "-- Generated on $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo ""
        cat postgres-rrule.sql
    } > postgres-rrule.sql.tmp
    mv postgres-rrule.sql.tmp postgres-rrule.sql
    print_success "Added version header to postgres-rrule.sql"
fi

# Stage changes
git add VERSION CHANGELOG.md postgres-rrule.sql
print_success "Staged release files"

# Create commit
COMMIT_MSG="chore(release): bump version to $NEW_VERSION"
git commit -m "$COMMIT_MSG" --no-verify
print_success "Created release commit"

# Create tag
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"
print_success "Created git tag v$NEW_VERSION"

echo ""
print_success "Release v$NEW_VERSION prepared successfully!"
echo ""
print_info "Next steps:"
print_info "  1. Review the changes: git show HEAD"
print_info "  2. Review the changelog: cat CHANGELOG.md"
print_info "  3. Push the release: make push-release"
echo ""
print_warning "To undo this release (before pushing):"
print_warning "  git reset --hard HEAD~1"
print_warning "  git tag -d v$NEW_VERSION"
