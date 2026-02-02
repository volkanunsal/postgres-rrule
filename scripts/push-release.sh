#!/usr/bin/env bash
# Push release commit and tags to remote repository
# Includes confirmation prompt for safety

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

cd "$PROJECT_ROOT"

# Check if git is available
if ! command -v git &> /dev/null; then
    print_error "git is not installed or not in PATH"
    exit 1
fi

# Get current version
if [ ! -f "VERSION" ]; then
    print_error "VERSION file not found"
    exit 1
fi

VERSION=$(cat VERSION | tr -d '[:space:]')
TAG="v$VERSION"

# Check if the tag exists locally
if ! git rev-parse "$TAG" >/dev/null 2>&1; then
    print_error "Tag $TAG does not exist locally"
    print_info "Please create a release first using:"
    print_info "  make release-patch  (for 0.0.X releases)"
    print_info "  make release-minor  (for 0.X.0 releases)"
    print_info "  make release-major  (for X.0.0 releases)"
    exit 1
fi

# Check if tag already exists on remote
REMOTE=$(git remote | head -n1)
if [ -z "$REMOTE" ]; then
    print_error "No git remote configured"
    exit 1
fi

print_info "Remote: $REMOTE"

# Check if tag exists on remote
if git ls-remote --tags "$REMOTE" | grep -q "refs/tags/$TAG"; then
    print_warning "Tag $TAG already exists on remote $REMOTE"
    print_info "This release has already been pushed."
    print_info "If you want to re-push, delete the remote tag first:"
    print_info "  git push $REMOTE :refs/tags/$TAG"
    exit 0  # Exit 0 for idempotency
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Show what will be pushed
echo ""
print_info "Release Summary:"
echo "  Version: $VERSION"
echo "  Tag: $TAG"
echo "  Branch: $CURRENT_BRANCH"
echo "  Remote: $REMOTE"
echo ""

# Show recent commits
print_info "Recent commits to be pushed:"
git log --oneline -5
echo ""

# Show the tag details
print_info "Tag details:"
git show "$TAG" --no-patch
echo ""

# Confirmation prompt
print_warning "This will push the release commit and tag to $REMOTE"
read -p "Are you sure you want to continue? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_info "Push cancelled"
    exit 0
fi

# Push the commits
print_info "Pushing commits to $REMOTE $CURRENT_BRANCH..."
git push "$REMOTE" "$CURRENT_BRANCH"
print_success "Pushed commits"

# Push the tag
print_info "Pushing tag $TAG to $REMOTE..."
git push "$REMOTE" "$TAG"
print_success "Pushed tag"

echo ""
print_success "Release $VERSION published successfully!"
echo ""
print_info "Next steps:"
print_info "  1. View the release on GitHub/GitLab"
print_info "  2. Create release notes on the platform (if applicable)"
print_info "  3. Announce the release"
echo ""

# Optionally create GitHub release if gh CLI is available
if command -v gh &> /dev/null; then
    echo ""
    read -p "Create GitHub release? (yes/no): " -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Creating GitHub release..."

        # Extract release notes from CHANGELOG.md
        RELEASE_NOTES=$(awk "/## \[$VERSION\]/,/## \[/" CHANGELOG.md | sed '$d' | tail -n +2)

        if [ -n "$RELEASE_NOTES" ]; then
            gh release create "$TAG" \
                --title "Release $VERSION" \
                --notes "$RELEASE_NOTES"
            print_success "GitHub release created"
        else
            print_warning "Could not extract release notes from CHANGELOG.md"
            gh release create "$TAG" --title "Release $VERSION" --generate-notes
            print_success "GitHub release created with auto-generated notes"
        fi
    fi
else
    print_info "Tip: Install 'gh' CLI to create GitHub releases automatically"
fi
