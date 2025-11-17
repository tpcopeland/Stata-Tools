# tvmerge dialog — Graphical user interface for tvmerge

## Syntax

**Command line:**
```stata
db tvmerge
```

**Optional menu access:**
The dialog can be added to Stata menus. To set up menu integration, see [INSTALLATION.md](INSTALLATION.md).

After menu setup: **User > Time-varying exposures > Merge TV datasets (tvmerge)**

## Description

The **tvmerge** dialog provides a graphical interface for merging multiple time-varying exposure datasets. The dialog guides you through specifying datasets to merge, defining variables, and configuring output options. This is particularly useful for combining different exposure sources (e.g., multiple medication files, multiple procedure databases) into a single time-varying dataset.

## Dialog structure

The tvmerge dialog consists of three tabs:

1. [Main](#main-tab) — Dataset selection and required variables
2. [Options](#options-tab) — Exposure types and variable naming
3. [Output](#output-tab) — Saving and diagnostics

---

## Main tab

The Main tab contains all required inputs for merging time-varying datasets.

### Datasets to merge

**Dataset 1** — First dataset to merge (required). Click **Browse...** to select a Stata dataset (.dta file). This should contain time-varying exposure data with one row per period per person.

**Dataset 2** — Second dataset to merge (required). Must have the same structure as Dataset 1.

**Dataset 3** through **Dataset 6** — Additional datasets to merge (optional). You can merge 2 to 6 datasets in a single operation. All datasets must contain the same ID variable and have compatible date variables.

### Required variables (one entry per dataset, space-separated)

These fields require you to list variable names in order, with one name per dataset separated by spaces. For example, if Dataset 1 uses `pid` and Dataset 2 uses `patient_id`, you would enter: `pid patient_id`.

**Person ID variable (same in all datasets)** — The variable that uniquely identifies individuals. This variable must have the same name in all datasets. For example: `patient_id`.

**Start date variables** — List of start date variable names, one per dataset, space-separated. These variables indicate when each exposure period begins. All dates must be in Stata date format (e.g., %td or %tc).

Example: `start_date start_dt begin_date`

**Stop date variables** — List of stop date variable names, one per dataset, space-separated. These variables indicate when each exposure period ends. Must be in the same date format as start dates.

Example: `end_date stop_dt end_date`

**Exposure variables** — List of exposure variable names, one per dataset, space-separated. These variables contain the exposure status or type for each period. Can be either categorical (e.g., medication codes) or continuous (e.g., doses).

Example: `medication procedure diagnosis`

---

## Options tab

The Options tab allows you to specify exposure types and control output variable naming.

### Exposure types

**Continuous exposures** — Specifies which exposures should be treated as continuous/rate variables rather than categorical. Enter either:
- **Variable names:** Space-separated list of exposure variable names (e.g., `dose1 dose2`)
- **Positions:** Space-separated list of dataset positions (e.g., `1 3` for datasets 1 and 3)

Continuous exposures are handled as rates per day and summed when overlapping. Categorical exposures create cartesian products of all possible combinations.

**Example:** If you're merging medication doses (continuous) with procedure codes (categorical), enter the dose variable names here.

### Output variable naming (select one approach)

These options are mutually exclusive. Choose how to name the merged exposure variables:

**Use default names (as specified in exposure list)** — Uses the exposure variable names from each dataset as-is. For example, if your exposure variables are `medication`, `procedure`, and `diagnosis`, these same names will be used in the output.

**Specify new names (one per dataset)** — Allows you to rename each exposure variable. Enter new names space-separated, one per dataset.

Example: If merging three datasets, enter: `med_exposure proc_exposure diag_exposure`

**Add prefix to all exposure variables** — Adds a common prefix to all exposure variable names. For example, prefix `tv_` will rename variables to `tv_medication`, `tv_procedure`, `tv_diagnosis`.

### Date variable naming

**Output start variable name** — Name for the start date variable in the merged output. Default is `start`. This variable will contain the beginning of each time period in the merged dataset.

**Output stop variable name** — Name for the stop date variable in the merged output. Default is `stop`. This variable will contain the end of each time period in the merged dataset.

**Date format for output** — Stata date format to apply to start and stop variables in the output. Default is `%tdCCYY/NN/DD` (e.g., 2024/01/15). Common alternatives:
- `%tdDD/NN/CCYY` — Day/month/year (e.g., 15/01/2024)
- `%td` — Stata default date format
- `%tc` — Stata datetime format

### Additional variables

**Keep from source datasets** — List of additional variables to keep from the source datasets. These variables will be suffixed with `_ds1`, `_ds2`, etc., to indicate their source.

Example: `age sex baseline_year` will create `age_ds1`, `sex_ds1`, `baseline_year_ds1`, `age_ds2`, etc.

**Note:** Only include variables that are constant within person (e.g., baseline characteristics). Time-varying variables from source datasets may produce unexpected results.

---

## Output tab

The Output tab controls file saving and diagnostic options.

### Save merged dataset

**Save as** — Filename for saving the merged dataset. Click **Browse...** to specify a location.

**Important:** The tvmerge command replaces the current dataset in memory with the merged result. If you want to preserve the original data, you must either:
- Use this option to save the output to a file, OR
- Save your original data before running tvmerge

**Replace** — Allow overwriting an existing file with the same name.

### Diagnostics and validation

**Display coverage diagnostics** — Shows a summary table of temporal coverage for each person, including:
- Total person-time covered
- Number of periods per person
- Coverage gaps

**Validate coverage (check for gaps)** — Performs validation checks to ensure complete temporal coverage. Displays warnings for:
- Gaps in coverage between entry and exit
- Persons with no exposure data
- Inconsistent date ranges

**Validate overlaps** — Checks for overlapping exposure periods within and across datasets. Reports:
- Number of overlapping periods
- Duration of overlaps
- Whether overlaps are expected (e.g., concurrent medications) or indicate data errors

**Display summary statistics** — Shows summary statistics for the merged dataset:
- Number of unique persons
- Total number of periods
- Date range coverage
- Distribution of exposure combinations

---

## Remarks

### How tvmerge works

The tvmerge command performs the following steps:

1. **Load datasets** — Reads all specified datasets
2. **Validate structure** — Ensures all datasets have compatible ID and date variables
3. **Combine periods** — Merges all exposure periods across datasets
4. **Split at boundaries** — Creates new rows at every exposure start/stop boundary
5. **Calculate exposure status** — For each split period, determines which exposures are active
6. **Handle exposure types** — Applies appropriate logic for categorical vs. continuous exposures
7. **Format output** — Creates final dataset with standardized variable names

### Understanding the output

The merged dataset will contain:

- **One row per unique time period per person** — Time periods are split at every exposure boundary
- **ID variable** — The person identifier
- **Start and stop variables** — Dates defining each period
- **Exposure variables** — One per source dataset, indicating status during the period

**Example:** If person 1 has medication A from days 1-10 and procedure B on days 5-8, the merged dataset will have three rows:
- Days 1-4: medication A only
- Days 5-8: medication A and procedure B
- Days 9-10: medication A only

### Categorical vs. continuous exposures

**Categorical exposures** create combinations:
- If dataset 1 has medication (values: 0, 1, 2) and dataset 2 has procedure (values: 0, 1), the merged data represents all combinations: medication=0/procedure=0, medication=1/procedure=0, medication=1/procedure=1, etc.
- Each unique combination is represented in separate rows

**Continuous exposures** are summed:
- If two datasets both contain medication doses, overlapping periods show the total dose
- Example: 10 mg from dataset 1 + 5 mg from dataset 2 = 15 mg during overlap

### Memory and performance considerations

**Dataset size** — Merging creates new rows at every boundary. With N datasets each having M periods, the output can have up to N×M rows per person. Monitor memory usage when merging many datasets.

**Optimization tips:**
- Merge datasets with similar temporal granularity together
- Pre-process datasets to remove unnecessary periods
- Consider merging in stages (merge 2-3 datasets at a time, then merge the results)

### Variable naming strategies

**Default names** — Good when source variable names are clear and don't conflict

**Custom names (generate)** — Good when you want descriptive names or source names are unclear

**Prefix** — Good when you want to maintain source names but add context (e.g., `merged_medication`)

Choose a strategy that makes your analysis code readable and maintainable.

---

## Examples

### Example 1: Merge two medication datasets

Combine two medication files with overlapping time periods:

1. Open the tvmerge dialog: `db tvmerge`
2. **Main tab:**
   - Dataset 1: `anticoagulants.dta`
   - Dataset 2: `antiplatelets.dta`
   - Person ID variable: `patient_id`
   - Start date variables: `rx_start_date rx_start_date`
   - Stop date variables: `rx_end_date rx_end_date`
   - Exposure variables: `anticoag antiplate`
3. **Options tab:**
   - Variable naming: "Use default names"
4. **Output tab:**
   - Save as: `merged_medications.dta`
   - Replace: checked
5. Click **OK**

Result: Dataset with periods showing all combinations of anticoagulant and antiplatelet exposure.

### Example 2: Merge medication doses (continuous)

Combine two medication dose files where doses should be summed:

1. Open the tvmerge dialog
2. **Main tab:**
   - Dataset 1: `drug_a_doses.dta`
   - Dataset 2: `drug_b_doses.dta`
   - Person ID variable: `id`
   - Start date variables: `start start`
   - Stop date variables: `stop stop`
   - Exposure variables: `dose_a dose_b`
3. **Options tab:**
   - Continuous exposures: `dose_a dose_b` (or `1 2`)
4. Click **OK**

Result: During overlaps, doses are summed (e.g., 10 mg + 5 mg = 15 mg total).

### Example 3: Merge three datasets with custom names

Combine medications, procedures, and diagnoses with clear variable names:

1. Open the tvmerge dialog
2. **Main tab:**
   - Dataset 1: `meds.dta`
   - Dataset 2: `procedures.dta`
   - Dataset 3: `diagnoses.dta`
   - Person ID variable: `patient_id`
   - Start date variables: `med_start proc_date diag_date`
   - Stop date variables: `med_stop proc_date diag_date`
   - Exposure variables: `med_code proc_code diag_code`
3. **Options tab:**
   - Variable naming: "Specify new names"
   - Generate names: `medication procedure diagnosis`
4. Click **OK**

Result: Clear variable names (`medication`, `procedure`, `diagnosis`) in merged dataset.

### Example 4: Merge with additional baseline variables

Include demographic variables from source datasets:

1. Open the tvmerge dialog
2. **Main tab:** Specify datasets as usual
3. **Options tab:**
   - Keep from source datasets: `age sex race enrollment_year`
4. Click **OK**

Result: Output includes `age_ds1`, `sex_ds1`, `race_ds1`, `enrollment_year_ds1`, `age_ds2`, etc.

**Note:** These should be time-invariant within person. If they vary, only the value from the first period will be retained.

### Example 5: Merge with validation

Check for data quality issues during merge:

1. Open the tvmerge dialog
2. **Main tab:** Specify datasets
3. **Output tab:**
   - Check: "Validate coverage (check for gaps)"
   - Check: "Validate overlaps"
   - Check: "Display summary statistics"
4. Click **OK**

Result: Detailed diagnostic output showing any coverage gaps, unexpected overlaps, and summary statistics.

### Example 6: Merge point-in-time data

Combine point-in-time measurements (same start and stop date):

1. Open the tvmerge dialog
2. **Main tab:**
   - Dataset 1: `lab_results.dta`
   - Dataset 2: `vital_signs.dta`
   - Person ID variable: `id`
   - Start date variables: `test_date measure_date`
   - Stop date variables: `test_date measure_date` (same as start)
   - Exposure variables: `lab_value vital_value`
3. **Options tab:**
   - Continuous exposures: `1 2`
4. Click **OK**

Result: Point-in-time measurements merged, with periods split at each measurement date.

---

## Common issues and solutions

### Issue: "Datasets have inconsistent ID variables"

**Cause:** The ID variable name differs across datasets, or the ID values don't match.

**Solution:**
- Ensure the same ID variable name is used in all datasets
- Check that ID values are consistent (e.g., not "001" in one dataset and "1" in another)

### Issue: "Dates are not in compatible formats"

**Cause:** Start/stop dates are stored as strings or in different formats across datasets.

**Solution:**
- Convert all dates to Stata numeric date format before merging
- Use the same date format (%td, %tc, etc.) in all datasets

### Issue: "Output has too many rows"

**Cause:** Many boundaries create many split periods.

**Solution:**
- This is expected behavior; tvmerge splits at all boundaries
- Consider whether you need all datasets merged simultaneously
- Pre-aggregate or simplify some source datasets

### Issue: "Variables from source datasets are missing in output"

**Cause:** Only specified variables are kept by default.

**Solution:**
- Use the "Keep from source datasets" option to include additional variables
- Remember variables will be suffixed with `_ds1`, `_ds2`, etc.

### Issue: "Overlapping periods for same exposure type"

**Cause:** Source dataset has overlapping periods (data error or intentional).

**Solution:**
- If error: Clean source data before merging
- If intentional: Use "Validate overlaps" to confirm expected behavior

---

## Saved results

After running the command via the dialog, the following are stored in `r()`:

**Scalars:**
- `r(N)` — Number of observations in merged output
- `r(N_persons)` — Number of unique individuals
- `r(N_datasets)` — Number of datasets merged
- `r(min_date)` — Earliest date in output
- `r(max_date)` — Latest date in output

**Macros:**
- `r(cmd)` — `tvmerge`
- `r(datasets)` — List of merged dataset names
- `r(exposure_vars)` — List of exposure variable names in output

---

## Technical notes

### Merging algorithm

The tvmerge algorithm:

1. **Union of time points** — Identifies all unique start and stop dates across all datasets
2. **Period creation** — Creates a period for each interval between consecutive time points
3. **Exposure assignment** — For each period, looks up active exposure(s) from each dataset
4. **Cartesian product** — For categorical exposures, creates rows for all active combinations
5. **Summation** — For continuous exposures, sums values across datasets

### Handling missing data

- **Missing exposure values** — Treated as unexposed (zero or reference value)
- **Missing dates** — Periods with missing dates are dropped with a warning
- **Missing ID** — Observations with missing ID are dropped with a warning

### Performance characteristics

**Time complexity:** O(N × P × D) where:
- N = number of persons
- P = average periods per person
- D = number of datasets

**Space complexity:** Output size ≈ N × P × C where:
- C = average combinations per period (usually 1-4)

Large datasets (>1 million observations) may require:
- Increased memory allocation (`set max_memory`)
- Batch processing (subset by date range or ID)

---

## Also see

**Manual:** [R] tvmerge, [D] merge, [ST] stset

**Related dialogs:** tvexpose

**Related commands:** `help tvmerge`, `help tvexpose`, `help merge`, `help append`

---

## Appendix: Workflow recommendations

### Before merging

1. **Verify data quality** — Check each source dataset for:
   - Valid date ranges (stop ≥ start)
   - Consistent ID variables
   - Expected exposure value distributions

2. **Standardize formats** — Ensure:
   - All dates in same format (e.g., %td)
   - ID variables have same name and type
   - Exposure variables properly coded

3. **Document assumptions** — Record:
   - What each exposure variable represents
   - Which exposures are categorical vs. continuous
   - Expected overlap patterns

### During merging

1. **Start simple** — Merge two datasets first to verify logic
2. **Use validation** — Always check coverage and overlaps initially
3. **Inspect output** — Manually check a few persons to confirm expected behavior

### After merging

1. **Verify coverage** — Ensure all persons have expected time coverage
2. **Check combinations** — Confirm exposure combinations make sense
3. **Save metadata** — Document variable names, date ranges, and any issues
4. **Archive source data** — Keep original datasets for reproducibility

### For large datasets

1. **Test on subset** — Run on small subset first (e.g., 100 persons)
2. **Monitor memory** — Watch memory usage during merge
3. **Consider parallel processing** — Split by ID ranges and merge separately
4. **Save intermediate results** — Save merged datasets at each stage
