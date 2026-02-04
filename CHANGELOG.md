## [2.1.0] - 2026-02-04
### ✨ Features

- Add release manager and notes writer agents for automated release process (5e05d1b)
- Add comprehensive timezone support for recurring events (5b4719d)
- **(tests)**: Add tests for explicit INTERVAL=1 with ordinal BYDAY and text round-trip normalization (31a9dc0)
- Update RRULE and EXRULE parsing to support array format in new schema (c632c1b)


## [2.0.0] - 2026-02-02
### ✨ Features

-  (0144aa1)


## [1.0.0] - 2026-02-02
### ✨ Features

-  (3926f63)


## [0.1.1] - 2026-02-02
### ✨ Features

-  (1a10952)
-  (7af73e1)
-  (d2c3fd9)
-  (5034bc0)
-  (d005bc8)
-  (bb09ad4)
-  (68bc10a)
-  (7c48ddd)
-  (d6a2f88)
-  (8f786dc)
-  (309c925)
-  (7456711)
-  (578b65f)
-  (f2820f1)
-  (1d82bc8)
-  (dc25c26)
-  (5f06df1)
-  (9d849d5)
-  (b19a4b6)
-  (20a3b0b)
-  (5ef9e1f)
-  (27eec2d)

### 🐛 Bug Fixes

-  (f9c7f01)
-  (6cc3a4a)
-  (9ba7f04)
-  (8b647d1)
-  (a02ce78)
-  (c3d7380)

### Other Changes

-  (b90ca62)
-  (bd3f875)
-  (c60eb61)
-  (18fcf74)
-  (8de2881)
-  (5e92d77)
-  (1728fc3)
-  (66ef498)
-  (e65c53b)
-  (e63aabf)
-  (6cd6266)
-  (e6d51b1)
-  (3232195)
-  (693757b)
-  (5a2f20a)
-  (77dbe70)
-  (692747b)
-  (9335816)
-  (db67835)
-  (a438710)
-  (fb73219)
-  (d865fda)
-  (c3cbd4d)
-  (bb5315d)
-  (2140091)
-  (0205894)
-  (fab571e)
-  (52d862e)
-  (2017a66)
-  (662593d)
-  (4dd26fd)
-  (83f0ddb)
-  (a7fb319)
-  (9db858a)
-  (c83825a)
-  (869d178)
-  (ff6d34b)
-  (abab778)
-  (8372597)
-  (15abfae)
-  (8133858)
-  (77401dd)
-  (7391921)
-  (498cd2a)
-  (9770bb0)
-  (3570a6a)
-  (bc04608)
-  (ea0e34b)
-  (eab5da0)


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
