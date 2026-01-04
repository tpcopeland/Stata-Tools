# Audit Recommendation: CLAUDE.md

## Audit Summary
`CLAUDE.md` serves as the central context file. It is comprehensive, covering style, tools, and commands.

## Findings

### 1. Versioning Consistency `[Medium]`
- **Location:** Throughout.
- **Issue:** Mentions both Stata 16.0 and 18.0. Stata 18 is current, but 16 offers good backward compatibility.
- **Recommendation:** Standardize advice. If the goal is broad compatibility, stick to `14.1` or `16.0`. If features like `frames` are needed, `16.0` is the floor. If standardizing on modern Stata, just say 18.

### 2. Missing `ssc install` Guidance `[Low]`
- **Location:** Library sections.
- **Issue:** Doesn't explicitly state policy on using community-contributed commands (`ssc install`) within packages.
- **Recommendation:** Add a rule: "Avoid dependencies on SSC commands unless absolutely necessary; if used, check for their existence with `capture which`."

## Recommendations

1.  **Consolidate Version Rule:**
    - Explicitly state: "Target Stata 16.0 for maximum compatibility unless Stata 18 features (e.g., Python integration, vectorization upgrades) are required."

2.  **Add "Data Types" Rule:**
    - Add to Critical Rules: "5. **Use `double` precision**: Always use `double` for new numeric variables to prevent precision loss."

3.  **Refresh "Common Pitfalls":**
    - Add: "Preserving data but failing to keep generated variables (using `restore` instead of `restore, not`)."
