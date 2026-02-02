#!/usr/bin/env bash
# Generate CHANGELOG.md from git commit history
# Uses conventional commit format

set -e

CHANGELOG_FILE="CHANGELOG.md"
NEW_VERSION=$1
PREVIOUS_TAG=$2

if [ -z "$NEW_VERSION" ]; then
    echo "Usage: $0 <new_version> [previous_tag]"
    exit 1
fi

# Determine the commit range
if [ -z "$PREVIOUS_TAG" ]; then
    # No previous tag, get all commits
    COMMIT_RANGE=""
else
    COMMIT_RANGE="${PREVIOUS_TAG}..HEAD"
fi

# Get the date
RELEASE_DATE=$(date +%Y-%m-%d)

# Function to strip emojis from commit message
strip_emoji() {
    # Remove common emoji patterns and extra spaces
    echo "$1" | sed -E 's/[[:space:]]*[🎉🚀✨🐛🔒📝🧪📚🔍⛰️🆕💡🎨♻️⚡🔧📦👷‍♂️🔨🎯💄🍱🚑💥🏗️🌐📄🔀🗃️🚚📌➕➖⬆️⬇️📍🔖🚨✅🔇🔊💬🗑️🥚🙈💾🧑‍💻☸️📈➖✏️💩⏪🔢🏷️🌱🚩🥅💫🗂️🔊🔇👔🩹🧐⚗️🧱🧵🦺]/g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//'
}

# Function to extract conventional commit type and scope
parse_commit() {
    local commit_msg=$1
    local type=""
    local scope=""
    local message=""

    # Match conventional commit format: type(scope): message or type: message
    if [[ "$commit_msg" =~ ^([a-z]+)(\([^)]+\))?: ]]; then
        type="${BASH_REMATCH[1]}"
        scope="${BASH_REMATCH[2]}"
        message="${commit_msg#*: }"
        message=$(strip_emoji "$message")
    else
        type="other"
        message=$(strip_emoji "$commit_msg")
    fi

    echo "${type}|${scope}|${message}"
}

# Arrays to store commits by type
declare -a features=()
declare -a fixes=()
declare -a docs=()
declare -a tests=()
declare -a refactor=()
declare -a perf=()
declare -a chore=()
declare -a other=()

# Read commits
while IFS= read -r line; do
    if [ -n "$line" ]; then
        commit_hash=$(echo "$line" | cut -d'|' -f1)
        commit_msg=$(echo "$line" | cut -d'|' -f2-)

        parsed=$(parse_commit "$commit_msg")
        type=$(echo "$parsed" | cut -d'|' -f1)
        scope=$(echo "$parsed" | cut -d'|' -f2)
        message=$(echo "$parsed" | cut -d'|' -f3)

        # Format the commit line
        if [ -n "$scope" ]; then
            commit_line="- **${scope}**: ${message} (${commit_hash})"
        else
            commit_line="- ${message} (${commit_hash})"
        fi

        case "$type" in
            feat|feature)
                features+=("$commit_line")
                ;;
            fix)
                fixes+=("$commit_line")
                ;;
            docs|doc)
                docs+=("$commit_line")
                ;;
            test|tests)
                tests+=("$commit_line")
                ;;
            refactor)
                refactor+=("$commit_line")
                ;;
            perf|performance)
                perf+=("$commit_line")
                ;;
            chore|build|ci)
                chore+=("$commit_line")
                ;;
            *)
                other+=("$commit_line")
                ;;
        esac
    fi
done < <(git log --format="%h|%s" $COMMIT_RANGE)

# Generate new changelog entry
NEW_ENTRY=$(cat <<EOF
## [$NEW_VERSION] - $RELEASE_DATE

EOF
)

# Add sections if they have content
if [ ${#features[@]} -gt 0 ]; then
    NEW_ENTRY+=$'\n### ✨ Features\n\n'
    for item in "${features[@]}"; do
        NEW_ENTRY+="${item}"$'\n'
    done
fi

if [ ${#fixes[@]} -gt 0 ]; then
    NEW_ENTRY+=$'\n### 🐛 Bug Fixes\n\n'
    for item in "${fixes[@]}"; do
        NEW_ENTRY+="${item}"$'\n'
    done
fi

if [ ${#perf[@]} -gt 0 ]; then
    NEW_ENTRY+=$'\n### ⚡ Performance Improvements\n\n'
    for item in "${perf[@]}"; do
        NEW_ENTRY+="${item}"$'\n'
    done
fi

if [ ${#refactor[@]} -gt 0 ]; then
    NEW_ENTRY+=$'\n### ♻️ Code Refactoring\n\n'
    for item in "${refactor[@]}"; do
        NEW_ENTRY+="${item}"$'\n'
    done
fi

if [ ${#docs[@]} -gt 0 ]; then
    NEW_ENTRY+=$'\n### 📝 Documentation\n\n'
    for item in "${docs[@]}"; do
        NEW_ENTRY+="${item}"$'\n'
    done
fi

if [ ${#tests[@]} -gt 0 ]; then
    NEW_ENTRY+=$'\n### 🧪 Tests\n\n'
    for item in "${tests[@]}"; do
        NEW_ENTRY+="${item}"$'\n'
    done
fi

if [ ${#chore[@]} -gt 0 ]; then
    NEW_ENTRY+=$'\n### 🔧 Chores\n\n'
    for item in "${chore[@]}"; do
        NEW_ENTRY+="${item}"$'\n'
    done
fi

if [ ${#other[@]} -gt 0 ]; then
    NEW_ENTRY+=$'\n### Other Changes\n\n'
    for item in "${other[@]}"; do
        NEW_ENTRY+="${item}"$'\n'
    done
fi

# Create or update CHANGELOG.md
if [ -f "$CHANGELOG_FILE" ]; then
    # Prepend new entry to existing changelog
    {
        echo "$NEW_ENTRY"
        echo ""
        cat "$CHANGELOG_FILE"
    } > "${CHANGELOG_FILE}.tmp"
    mv "${CHANGELOG_FILE}.tmp" "$CHANGELOG_FILE"
else
    # Create new changelog
    {
        echo "# Changelog"
        echo ""
        echo "All notable changes to this project will be documented in this file."
        echo ""
        echo "The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),"
        echo "and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)."
        echo ""
        echo "$NEW_ENTRY"
    } > "$CHANGELOG_FILE"
fi

echo "✓ Generated changelog entry for version $NEW_VERSION"
