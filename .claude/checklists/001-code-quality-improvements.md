# Code Quality Improvements Checklist

This checklist identifies low-hanging fruit for improving code craftsmanship in `postgres-rrule.sql`.

## 🎯 Priority: High

### Code Style & Consistency

- [ ] **Standardize identifier quoting** - Line 26-42, throughout (Not in Quick Wins)
  - Current: Mixed use of quoted ("freq") and unquoted identifiers
  - Issue: Inconsistent style makes code harder to read
  - Recommendation: Choose one style and apply consistently (prefer unquoted for simple identifiers)
  - Impact: Low effort, high consistency improvement

- [x] **Remove TODO comments from production code** - Lines 646, 683, 810 ✅ **COMPLETED**
  - Current: All TODOs removed or implemented
  - Issue: TODOs should not exist in compiled production SQL
  - Solution implemented:
    - ✅ 0211-last.sql: Replaced with clear documentation
    - ✅ 0212-before.sql: Replaced with function description
    - ✅ 0213-after.sql: Replaced with function description
    - ✅ 0214-contains_timestamp.sql: Replaced with algorithm explanation
    - ✅ 0220-jsonb_to_rruleset.sql: Implemented validation for dtstart/dtend
    - ✅ 0201-occurrences.sql: Replaced with function description

- [x] **Standardize CTE naming conventions** - Lines 246-292 ✅ **COMPLETED**
  - Current: All cryptic CTE names replaced with descriptive snake_case names
  - Solution implemented:
    - ✅ 0017-all_starts.sql: `A10` → `timestamp_combinations`, `A11` → `candidate_timestamps`
    - ✅ 0005-parse_line.sql: `A4` → `trimmed_input`, `A5` → `filtered_lines`, etc.
    - ✅ 0100-rrule.sql: `A20` → `parsed_line`, `A30` → `key_value_pairs`
  - Impact: Significantly improved readability

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

- [x] **Replace FOREACH loops with set-based operations** - Lines 463-469, 890-898, 821-826 ✅ **COMPLETED**
  - Solution implemented: Replaced all 6 FOREACH/FOR loops with set-based operations
  - Changed from plpgsql to SQL language for better performance
  - Functions optimized:
    - ✅ 0200-is_finite.sql: Used `bool_or()` with `unnest()`
    - ✅ 0221-jsonb_to_rruleset_array.sql: Used `array_agg()` instead of loop concatenation
    - ✅ 0240-rruleset_array_to_jsonb.sql: Used `jsonb_agg()` instead of loop concatenation
    - ✅ 0250-rruleset_array_contains_timestamp.sql: Used `bool_or()` with `unnest()`
    - ✅ 0260-rruleset_array_has_after_timestamp.sql: Used `EXISTS` with subquery
    - ✅ 0270-rruleset_array_has_before_timestamp.sql: Used `EXISTS` with subquery
  - Impact: Significant performance improvement for large arrays, all tests passing

- [x] **Optimize array concatenation in loops** - Lines 823, 879 ✅ **COMPLETED**
  - Solution implemented: Replaced array concatenation with `array_agg()` and `jsonb_agg()`
  - Combined with FOREACH loop optimization above
  - Impact: Eliminated O(n²) array copying, improved performance for large arrays

- [ ] **Add indexes for table-based types** - Lines 26-43 ⏭️ **SKIPPED**
  - Note: Not applicable for table-based composite types
  - Decision: Skip per project requirements

- [x] **Optimize `generate_series` usage** - Lines 270-291 ✅ **COMPLETED**
  - Solution implemented: Added NULL checks to short-circuit unnecessary series generation
  - Changes in 0017-all_starts.sql:
    - ✅ Skip 6-day series if `byday` IS NULL
    - ✅ Skip 2-month series if `bymonthday` IS NULL
    - ✅ Skip 1-year series if `bymonth` IS NULL
  - Impact: Prevents generating unnecessary date ranges, improving performance when BY* parameters aren't used

- [x] **Cache interval calculations** - Lines 200, 243 ✅ **COMPLETED**
  - Solution implemented: Added CTE in containment function to cache interval calculations
  - Changes:
    - ✅ 0015-containment.sql: Added CTE to calculate both intervals once
    - ✅ 0017-all_starts.sql: Already optimized (stores in variable)
    - ✅ 0201-occurrences.sql: Already optimized (uses CTE)
  - Impact: Explicit caching makes intent clear, prevents potential recalculation

### Code Quality & Maintainability

- [x] **Extract complex validation logic** - Lines 331-332 ✅ **COMPLETED**
  - Solution implemented: Created helper function `has_any_by_rule()`
  - Changes:
    - ✅ 0089-has_any_by_rule.sql: New helper function checks if any BY* parameter is set
    - ✅ 0090-validate_rrule.sql: Replaced 9-condition check with `NOT _rrule.has_any_by_rule(result)`
  - Impact: Significantly improved readability and maintainability

- [x] **Standardize error messages** - Lines 313, 318, 323, etc. ✅ **COMPLETED**
  - Already completed in Quick Wins phase
  - All error messages now use sentence case with periods
  - Format: "Description of the problem."

- [x] **Add input validation for public functions** - Throughout ✅ **COMPLETED**
  - Solution implemented: Added comprehensive validation to validate_rrule()
  - New validations added:
    - ✅ COUNT must be positive if provided
    - ✅ All BY* arrays cannot be empty (9 checks added)
  - Impact: Better error messages prevent invalid configurations earlier

- [ ] **Extract magic strings to constants** - Lines 228, 406-422 ⏭️ **DEFERRED**
  - Decision: Not beneficial for PostgreSQL
  - Rationale: 'MO' appears 4 times as RFC 5545 default week start; extracting to function would reduce readability
  - Current usage is clear and maintainable in context

- [ ] **Improve function naming consistency** - Throughout ⏭️ **DEFERRED**
  - Decision: Would be a breaking change
  - Rationale: Current API is stable; renaming would break existing users
  - Recommendation: Document in migration guide if changed in future major version

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

1. **Quick Wins** (1-2 hours): ✅ **COMPLETED**
   - ✅ Remove TODO comments (6 instances fixed)
   - ✅ Standardize CTE naming in key functions (3 files updated)
   - ✅ Add function-level documentation for public APIs (~40 functions documented)
   - ✅ Standardize error message formatting (3 messages standardized)

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
