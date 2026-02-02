# Code Quality Improvements Checklist

This checklist identifies low-hanging fruit for improving code craftsmanship in `postgres-rrule.sql`.

## 🎯 Priority: High

### Code Style & Consistency

- [ ] **Standardize identifier quoting** - Line 26-42, throughout
  - Current: Mixed use of quoted ("freq") and unquoted identifiers
  - Issue: Inconsistent style makes code harder to read
  - Recommendation: Choose one style and apply consistently (prefer unquoted for simple identifiers)
  - Impact: Low effort, high consistency improvement

- [ ] **Remove TODO comments from production code** - Lines 646, 683, 810
  - Current: `-- TODO: Ensure to check whether the range is finite`
  - Issue: TODOs should not exist in compiled production SQL
  - Recommendation: Either implement the TODO or create GitHub issues and remove comments
  - Impact: Medium effort, improves code professionalism
  - Locations:
    - Line 646: `-- TODO: Ensure to check whether the range is finite`
    - Line 683: `-- TODO: test`
    - Line 810: `-- TODO: validate rruleset`

- [ ] **Standardize CTE naming conventions** - Lines 246-292
  - Current: Mix of descriptive names ("year") and cryptic names (A10, A11, A20, A30)
  - Issue: A10/A11 naming is not self-documenting
  - Recommendation: Use descriptive CTE names consistently
  - Example: `A10` → `timestamp_combinations`, `A11` → `distinct_timestamps`
  - Impact: Low effort, significantly improves readability

- [ ] **Add missing semicolons after type definitions** - Line 60
  - Current: Type definition runs directly into next function without clear separation
  - Issue: Poor visual separation between declarations
  - Recommendation: Add blank lines and ensure proper statement termination
  - Impact: Very low effort, improves readability

- [ ] **Standardize string literal quoting** - Throughout
  - Current: Mix of single quotes with escaped quotes
  - Issue: Inconsistent escape patterns
  - Recommendation: Use dollar-quoting for complex strings
  - Example: Replace `'(,)'::TSRANGE` patterns with more readable alternatives
  - Impact: Low effort, improves maintainability

## 🚀 Priority: Medium

### Performance Optimizations

- [ ] **Replace FOREACH loops with set-based operations** - Lines 463-469, 890-898, 821-826
  - Current: Iterative FOREACH loops for array operations
  - Issue: Row-by-row processing is slower than set operations
  - Recommendation: Use `unnest()` with aggregation functions
  - Example:
    ```sql
    -- Instead of FOREACH loop in is_finite()
    SELECT bool_or(_rrule.is_finite(item))
    FROM unnest("rruleset_array") AS item;
    ```
  - Impact: Medium effort, significant performance improvement for large arrays
  - Locations:
    - Lines 458-470: `is_finite()` for rruleset arrays
    - Lines 821-827: `jsonb_to_rruleset_array()`
    - Lines 878-883: `rruleset_array_to_jsonb()`
    - Lines 887-898: `rruleset_array_contains_timestamp()`

- [ ] **Optimize array concatenation in loops** - Lines 823, 879
  - Current: `out := (SELECT out || item)` in loops
  - Issue: Array concatenation in loops creates many intermediate arrays
  - Recommendation: Use `array_agg()` with set operations
  - Impact: Medium effort, improves performance for large arrays

- [ ] **Add indexes for table-based types** - Lines 26-43
  - Current: No indexes defined on RRULE or RRULESET tables
  - Issue: Could slow down queries on these composite types
  - Recommendation: Consider indexes on frequently queried fields (freq, dtstart)
  - Impact: Low effort, potential query performance improvement
  - Note: May not be applicable for table-based types; evaluate if needed

- [ ] **Optimize `generate_series` usage** - Lines 270-291
  - Current: Multiple `generate_series` calls with UNION
  - Issue: Each generate_series scans a date range independently
  - Recommendation: Combine into single generate_series where possible
  - Impact: Medium effort, reduces redundant date generation

- [ ] **Cache interval calculations** - Lines 200, 243
  - Current: `build_interval()` called multiple times for same rrule
  - Issue: Recalculating same interval repeatedly
  - Recommendation: Calculate once and reuse in CTEs
  - Impact: Low effort, small performance improvement

### Code Quality & Maintainability

- [ ] **Extract complex validation logic** - Lines 331-332
  - Current: Single-line validation with 9 NULL checks
  - Issue: Hard to read and maintain
  - Recommendation: Extract to helper function or split into multiple conditions
  - Example:
    ```sql
    CREATE FUNCTION _rrule.has_any_by_rule(r _rrule.RRULE) RETURNS BOOLEAN AS $$
      SELECT (r."bymonth" IS NOT NULL OR r."byweekno" IS NOT NULL OR ...);
    $$ LANGUAGE SQL IMMUTABLE STRICT;
    ```
  - Impact: Medium effort, significantly improves readability

- [ ] **Standardize error messages** - Lines 313, 318, 323, etc.
  - Current: Inconsistent punctuation and formatting in RAISE EXCEPTION
  - Issue: Some end with period, some don't; inconsistent capitalization
  - Recommendation: Standardize format (e.g., "Error: Description of problem")
  - Impact: Low effort, improves user experience

- [ ] **Add input validation for public functions** - Throughout
  - Current: Relies on STRICT and database constraints
  - Issue: Limited custom error messages for invalid input
  - Recommendation: Add explicit validation with helpful error messages
  - Impact: Medium effort, better error messages for users

- [ ] **Extract magic strings to constants** - Lines 228, 406-422
  - Current: Hardcoded strings like 'MO', 'RRULE:', format strings
  - Issue: Duplicated strings, harder to maintain
  - Recommendation: Use variables or constants where PostgreSQL supports them
  - Impact: Low effort, reduces duplication

- [ ] **Improve function naming consistency** - Throughout
  - Current: Mix of verb_noun (contains_timestamp) and noun_verb patterns
  - Issue: Inconsistent naming makes API harder to learn
  - Recommendation: Standardize on verb_noun pattern
  - Impact: Breaking change - document in migration guide if changed

## 📚 Priority: Low

### Documentation Improvements

- [ ] **Add function-level documentation** - Throughout
  - Current: Only one function has COMMENT (line 228)
  - Issue: No documentation for most functions
  - Recommendation: Add `COMMENT ON FUNCTION` for all public functions
  - Example:
    ```sql
    COMMENT ON FUNCTION _rrule.is_finite(_rrule.RRULE)
    IS 'Returns true if the recurrence rule has a defined end via COUNT or UNTIL';
    ```
  - Impact: Low effort, significantly improves discoverability
  - Priority functions:
    - `is_finite()`, `occurrences()`, `first()`, `last()`, `before()`, `after()`
    - `contains_timestamp()`, `jsonb_to_rrule()`, `jsonb_to_rruleset()`

- [ ] **Document function parameters** - Throughout
  - Current: No parameter documentation
  - Issue: Users must infer parameter meaning from code
  - Recommendation: Add comments above functions describing parameters
  - Impact: Low effort, improves API usability

- [ ] **Add usage examples in comments** - Key functions
  - Current: No examples in the SQL file
  - Issue: Users must refer to external documentation
  - Recommendation: Add simple usage examples in function comments
  - Impact: Low effort, improves developer experience

- [ ] **Document complex algorithms** - Lines 232-306
  - Current: `all_starts()` function has complex logic with no explanation
  - Issue: Hard to understand what the algorithm does
  - Recommendation: Add multi-line comment explaining the algorithm
  - Impact: Low effort, significantly helps future maintainers

- [ ] **Add schema-level documentation** - Line 6
  - Current: Just `CREATE SCHEMA _rrule;`
  - Issue: No explanation of what the schema contains
  - Recommendation: Add `COMMENT ON SCHEMA` with overview
  - Impact: Very low effort, helps users understand structure

### Refactoring Opportunities

- [ ] **Extract repeated null-checking patterns** - Throughout
  - Current: `COALESCE(condition, true)` pattern repeated many times
  - Issue: Duplicated code
  - Recommendation: Consider helper function for optional checks
  - Impact: Medium effort, reduces duplication

- [ ] **Split large functions** - Lines 232-306 (all_starts), 340-401 (rrule parser)
  - Current: Functions over 50 lines with multiple responsibilities
  - Issue: Hard to test and understand
  - Recommendation: Break into smaller, focused functions
  - Impact: High effort, improves testability

- [ ] **Consolidate duplicate validation patterns** - Lines 607-624
  - Current: Similar function signatures for TEXT and typed overloads
  - Issue: Boilerplate code for each overload
  - Recommendation: Good as-is (necessary for polymorphism), but document pattern
  - Impact: Low priority - this is acceptable PostgreSQL pattern

- [ ] **Extract common CTE patterns** - Multiple functions
  - Current: Similar CTE structures in multiple functions
  - Issue: Duplicated query logic
  - Recommendation: Create reusable helper functions for common patterns
  - Impact: Medium effort, reduces duplication

### Testing Improvements

- [ ] **Add assertions for function contracts** - Throughout
  - Current: Relies on STRICT for NULL handling
  - Issue: No explicit precondition checks
  - Recommendation: Add explicit checks with helpful error messages
  - Impact: Medium effort, better error messages

- [ ] **Add boundary condition comments** - Validation functions
  - Current: Check expressions without explanation
  - Issue: Not clear why boundaries are set (e.g., why 60 for seconds)
  - Recommendation: Add comments explaining RFC 5545 constraints
  - Impact: Very low effort, helps maintainers understand validation rules

## 🔒 Security & Best Practices

### SQL Injection & Safety

- [ ] **Review dynamic SQL patterns** - Line 114 (if any remain in compiled version)
  - Current: Check for any dynamic SQL construction
  - Issue: Potential SQL injection if not properly quoted
  - Recommendation: Ensure all dynamic SQL uses proper quoting
  - Impact: Critical if found, but likely already safe with STRICT functions

- [ ] **Validate TIMESTAMP parsing** - Lines 432-437
  - Current: Direct cast to TIMESTAMP without validation
  - Issue: Could raise unhelpful errors for invalid formats
  - Recommendation: Add TRY/CATCH or validation before casting
  - Impact: Low effort, better error messages

- [ ] **Add overflow checks for interval arithmetic** - Lines 64-66, 224
  - Current: Arithmetic without overflow protection
  - Issue: Very large intervals could overflow
  - Recommendation: Add explicit overflow checks for extreme cases
  - Impact: Low effort, prevents unexpected errors

### PostgreSQL Best Practices

- [ ] **Use explicit casting** - Throughout
  - Current: Mix of `::TYPE` and `CAST(x AS TYPE)`
  - Issue: Inconsistent casting style
  - Recommendation: Standardize on one approach (prefer `::` for readability)
  - Impact: Very low effort, consistency improvement

- [ ] **Add LANGUAGE SQL STABLE where appropriate** - Throughout
  - Current: All functions marked IMMUTABLE
  - Issue: Some functions might benefit from STABLE if they depend on session state
  - Recommendation: Review each function's volatility classification
  - Impact: Low effort, could improve query optimization

- [ ] **Consider adding PARALLEL SAFE** - Selected functions
  - Current: No parallel safety annotations
  - Issue: Query planner can't use parallel execution
  - Recommendation: Mark pure functions as PARALLEL SAFE
  - Impact: Medium effort, enables parallel query execution

- [ ] **Add explicit schemas in function calls** - Some internal functions
  - Current: Mix of `_rrule.function()` and unqualified calls
  - Issue: Search path dependency
  - Recommendation: Always use schema-qualified names
  - Impact: Low effort, more robust code

## 📋 Summary Statistics

| Category                  | Items  | Estimated Effort |
| ------------------------- | ------ | ---------------- |
| Code Style & Consistency  | 6      | Low              |
| Performance Optimizations | 5      | Medium           |
| Code Quality              | 6      | Medium           |
| Documentation             | 5      | Low              |
| Refactoring               | 4      | Medium-High      |
| Security & Best Practices | 4      | Low-Medium       |
| **Total**                 | **30** | **Mixed**        |

## 🎯 Recommended Priority Order

1. **Quick Wins** (1-2 hours):
   - Remove TODO comments
   - Standardize CTE naming in key functions
   - Add function-level documentation for public APIs
   - Standardize error message formatting

2. **Medium Effort** (4-8 hours):
   - Replace FOREACH loops with set operations
   - Extract complex validation logic
   - Add parameter documentation
   - Optimize array operations

3. **Long-term** (Future sprints):
   - Split large functions
   - Comprehensive refactoring of duplicate patterns
   - Add parallel safety annotations
   - Create comprehensive inline documentation

## 📝 Notes

- This analysis is based on the compiled `postgres-rrule.sql` file
- Some improvements may require changes to source files in `src/`
- Test coverage should be verified before and after any refactoring
- Breaking changes should be avoided or carefully documented
- Performance improvements should be benchmarked to verify gains

## 🔗 Related Files

- Source files: `src/functions/*.sql`, `src/types/*.sql`
- Tests: `tests/test_*.sql`
- Documentation: `README.md`, `DOCKER.md`

---

**Created**: 2026-02-02
**Status**: Pending Review
**Assignee**: TBD
