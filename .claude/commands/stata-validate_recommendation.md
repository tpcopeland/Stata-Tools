# Audit Recommendation: stata-validate.md

## Audit Summary
Excellent guide on numerical validation. The distinction regarding floating-point comparisons (`tolerance`) is critical and well-explained.

## Findings

### 1. `float` vs `double` Precision `[High]`
- **Location:** General validation logic.
- **Issue:** Stata's default `float` has only ~7 digits of precision. Validation tests often fail mysteriously because the reference expectations were calculated in a 64-bit environment (like Python/R) but stored in Stata as `float`.
- **Recommendation:** **Mandate** `input double` and `generate double` in all validation datasets to align with modern 64-bit precision standards.

### 2. Date/Time Precision `[Medium]`
- **Location:** Date tests.
- **Issue:** Stata date/times (especially `clock` / `%tc`) are highly sensitive to precision. Storing them as `float` results in rounding errors of minutes/seconds.
- **Recommendation:** Explicitly warn to ALWAYS use `double` for datetime variables (`%tc`, `%tC`).

## Recommendations

1.  **Enforce `double`:**
    - Update examples to show `input double val` instead of generic input, ensuring high-precision validation.

2.  **Add "Sorting" to Invariants:**
    - Validation should check that the command handles unsorted data correctly (i.e., it internally sorts if needed) or explicitly errors if sort is required.

3.  **Reference `mreldif()`:**
    - Introduce Stata's built-in `reldif()` and `mreldif()` functions for relative difference checking, which is robust standardized checking.
