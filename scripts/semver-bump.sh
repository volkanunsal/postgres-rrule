#!/usr/bin/env bash
# Simple semantic version bumper
# Usage: semver-bump.sh <version> <bump_type>
# bump_type: major, minor, patch

set -e

VERSION=$1
BUMP_TYPE=$2

if [ -z "$VERSION" ] || [ -z "$BUMP_TYPE" ]; then
    echo "Usage: $0 <version> <bump_type>"
    echo "bump_type: major, minor, patch"
    exit 1
fi

# Parse version
if [[ ! "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-.*)?$ ]]; then
    echo "Error: Invalid version format. Expected: MAJOR.MINOR.PATCH"
    exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"
PRERELEASE="${BASH_REMATCH[4]}"

case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo "Error: Invalid bump type. Use: major, minor, patch"
        exit 1
        ;;
esac

echo "${MAJOR}.${MINOR}.${PATCH}"
