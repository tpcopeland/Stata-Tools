# Audit Recommendation: stata-develop.md

## Audit Summary
`stata-develop.md` is a solid guide for new command development. It correctly emphasizes the directory structure and critical settings like `varabbrev off`.

## Findings

### 1. `preserve`/`restore` Logic Flaw in Mental Model `[Critical]`
- **Location:** Implicit in general advice, explicitly observed in linked templates.
- **Issue:** The guide doesn't explicitly warn about the danger of modifying data (e.g., `generate`) inside a `preserve`/`restore` block. If a user follows a pattern of "Preserve -> Keep if touse -> Generate -> Restore", the generated variable is lost.
- **Recommendation:** Explicitly document the "Merge Back" pattern or "No Preserve" pattern for adding variables.

### 2. Missing `byte` / `int` / `long` / `double` Guidance `[Medium]`
- **Location:** General coding advice.
- **Issue:** Stata code should be memory efficient. Using `double` is safe, but `byte` should be used for simple flags.
- **Recommendation:** Add a section on "Data Types and Memory" encouraging explicit type usage.

### 3. `syntax` Repeats `[Low]`
- **Location:** Line 155 (`version` usage)
- **Issue:** The example shows `version 18.0`. It is often good practice to permit users to set the version if needed, or explicitly document the minimum version supported in the `.pkg` file (which is covered, but consistency is key).
- **Recommendation:** Ensure the `.ado` version matches the `.pkg` requirement.

## Recommendations

1.  **Add "Data Preservation" Warning:**
    > **CRITICAL:** Do not `generate` variables intended for the user inside a `preserve` ... `restore` block without using `restore, not` or saving/merging the results. The `restore` command will revert the dataset to the state *before* the variable was created.

2.  **Include `sortpreserve` in Standard Definitions:**
    - Recommend adding `sortpreserve` to `program define` for any command that uses `bysort` or `sort` internally.

3.  **Clarify `syntax` Options:**
    - Add an example of `syntax [anything] [using/] [if] [in]` for more complex parsing scenarios (e.g., subcommands).
