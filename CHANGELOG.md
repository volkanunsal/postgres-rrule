# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### ✨ Features

- Add support for ordinal BYDAY in recurrence rules (1TU, 2MO, -1FR)
- Add support for multiple RRULEs and EXRULEs in RRULESET
- Add automated release management with changelog generation

### 🐛 Bug Fixes

- Format UNTIL date in RFC 5545 format (YYYYMMDDTHHMMSSZ)
- Correct alias for distinct occurrences in RDATE test case

### 📝 Documentation

- Add comprehensive release management documentation
- Update README with new features and examples

### 🧪 Tests

- Add comprehensive tests for ordinal BYDAY functionality (17 tests)
- Add tests for multi-RRULE functionality (10 tests)

---

_This changelog is automatically generated from git commit history using conventional commits._
