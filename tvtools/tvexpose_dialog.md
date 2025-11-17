# tvexpose dialog — Graphical user interface for tvexpose

## Syntax

**Command line:**
```stata
db tvexpose
```

**Optional menu access:**
The dialog can be added to Stata menus. To set up menu integration, see [INSTALLATION.md](INSTALLATION.md).

After menu setup: **User > Time-varying exposures > Create exposure variables (tvexpose)**

## Description

The **tvexpose** dialog provides a graphical interface for creating time-varying exposure variables for survival analysis. The dialog guides you through specifying exposure data, defining the exposure type, handling data issues, and configuring output options.

## Dialog structure

The tvexpose dialog consists of five tabs:

1. [Main](#main-tab) — Required variables and basic setup
2. [Exposure Definition](#exposure-definition-tab) — Exposure type and options
3. [Data Handling](#data-handling-tab) — Gap handling and data cleaning
4. [Advanced](#advanced-tab) — Timing adjustments and pattern tracking
5. [Output](#output-tab) — Variable naming, saving, and diagnostics

---

## Main tab

The Main tab contains all required inputs for creating time-varying exposure variables.

### Exposure dataset

**Exposure dataset** — Specifies the dataset containing exposure periods. Click **Browse...** to select a Stata dataset (.dta file). This file should contain one row per exposure period per person.

### Required variables

**Person ID variable** — Variable that uniquely identifies individuals in your data. Must be present in both the exposure dataset and the current dataset in memory.

**Start date variable** — Variable indicating when each exposure period begins. Must be in Stata date format (e.g., %td or %tc).

**Exposure variable** — Categorical variable indicating exposure status during each period. The values in this variable define different exposure types.

**Reference value** — Numeric value from the exposure variable that indicates unexposed/reference status (e.g., 0). Periods with this value are treated as unexposed time.

**Study entry date** — Variable from the current dataset indicating when each person entered the study. Must be in the same date format as start/stop dates.

**Study exit date** — Variable from the current dataset indicating when each person exited the study (e.g., event date, censoring date, or end of follow-up).

### Stop date options

**Point-in-time data (no stop date)** — Check this if your exposure data represents point-in-time measurements rather than periods. When checked, the stop date variable is not required. tvexpose will extend each exposure forward until the next measurement or study exit.

**Stop date variable** — Variable indicating when each exposure period ends. Required unless "Point-in-time data" is checked. Must be in the same date format as the start date.

---

## Exposure Definition tab

The Exposure Definition tab allows you to specify how exposure should be measured and tracked over time.

### Exposure type (select one)

These options are mutually exclusive. Select the exposure definition that matches your research question:

**Basic time-varying (default)** — Creates a categorical time-varying exposure variable that tracks exposure status as it changes over time. Each person can move between exposure categories. Use this for standard time-varying exposure analysis.

**Ever-treated (binary switch at first exposure)** — Creates a binary indicator that switches from 0 to 1 at first exposure and remains 1 thereafter. Once a person is exposed, they are always considered exposed. Use this for "intention to treat" or "ever exposed" analyses.

**Current/former (never=0, current=1, former=2)** — Creates a three-category variable tracking never exposed (0), currently exposed (1), and formerly exposed (2). Allows you to distinguish between current and past exposure. Former exposure begins when an exposure period ends.

**Duration categories** — Creates categorical variables based on cumulative duration of exposure. Specify cutpoints (e.g., `1 5 10`) to create categories like <1 unit, 1-<5 units, 5-<10 units, 10+ units. The unit is determined by the "Cumulative exposure unit" setting below.

**Continuous cumulative exposure** — Tracks the exact cumulative amount of exposure. The exposure variable will contain the total duration of exposure accumulated up to each time point, expressed in the unit specified by "Cumulative exposure unit."

**Recency categories** — Creates categorical variables based on time since last exposure. Specify cutpoints in years (e.g., `0.5 1 5`) to create categories like <0.5 years since exposure, 0.5-<1 years, 1-<5 years, 5+ years. Use this to study how effects change with time since exposure.

### Units (for duration and continuous exposure types)

These options apply when using duration or continuous exposure types:

**Cumulative exposure unit** — Specifies the unit for measuring cumulative exposure time. Choose from:
- **days** — Cumulative exposure measured in days
- **weeks** — Cumulative exposure measured in weeks
- **months** — Cumulative exposure measured in calendar months
- **quarters** — Cumulative exposure measured in calendar quarters
- **years** — Cumulative exposure measured in years

This also determines the unit for duration category cutpoints.

**Row expansion unit** — Controls how finely exposure periods are split for continuous tracking. Choose from:
- **days** — No row expansion; one row per original exposure period
- **weeks** — Create 7-day bins starting at exposure start
- **months** — Split into calendar months
- **quarters** — Split into calendar quarters
- **years** — Split into calendar years

For example, if a person has an exposure from Jan 1 to March 31 and you select "months," this will create three rows (January, February, March) with cumulative exposure calculated at each month boundary.

### Output variables

**Create separate variable for each exposure type** — When checked, creates separate time-varying variables for each unique value in the exposure variable (except the reference value). For example, if exposure has values 0, 1, 2, where 0 is reference, this creates two variables (one tracking exposure type 1, one tracking type 2) instead of a single combined variable. Not available for basic time-varying exposure.

---

## Data Handling tab

The Data Handling tab provides options for dealing with gaps and irregularities in exposure data.

### Gap handling

**Grace period (days)** — Number of days allowed between consecutive exposure periods of the same type before considering them separate episodes. For example, `grace(30)` merges exposure periods of the same type if they are separated by 30 days or less.

You can also specify different grace periods by exposure type using the syntax `1=30 2=60` to give 30 days grace for type 1 and 60 days for type 2.

**Merge same-type periods within (days)** — Maximum gap (in days) between consecutive periods of the same exposure type that should be merged into a single period. Default is 120 days. For example, if a person has two periods of exposure type 1 separated by 100 days, they will be merged into one continuous period.

**Fill gaps beyond last record (days)** — Assumes exposure continues for this many days beyond the last recorded exposure. Useful when you believe exposure continues after the last available record. For example, `fillgaps(30)` extends each person's final exposure period by 30 days.

**Carry forward through gaps (days)** — Extends the last known exposure forward through gaps up to this many days. Different from fillgaps; this applies to all gaps, not just the final period. For example, `carryforward(14)` assumes exposure status remains unchanged during gaps up to 14 days.

---

## Advanced tab

The Advanced tab provides options for timing adjustments, handling overlapping exposures, and tracking exposure patterns.

### Timing adjustments

**Lag period (days)** — Number of days to delay the start of exposure effects. For example, `lag(30)` shifts all exposure periods forward by 30 days to account for a latency period. Use this when you expect a delay between exposure and biological effect.

**Washout period (days)** — Number of days exposure effects persist after the exposure ends. For example, `washout(60)` extends each exposure period by 60 days to account for lingering effects.

**Acute window (min max days)** — Defines a time window relative to exposure. Specify two values (minimum and maximum days). Only exposure occurring within this window relative to the index date is counted. For example, `7 30` counts only exposure between 7 and 30 days before the outcome.

### Overlapping exposures (select one approach)

When multiple exposure types overlap in time, you must specify how to handle them:

**Layer (default): later exposures take precedence, earlier resume after overlap** — When exposures overlap, the later exposure takes precedence for the overlap period. When the later exposure ends, the earlier exposure resumes. This creates a "layering" effect. Use this when you want recent exposures to override earlier ones temporarily.

**Priority order (space-separated list)** — Specify a priority ranking for exposure types (e.g., `2 1 3`). When exposures overlap, the higher-priority exposure takes precedence. For example, if exposure type 2 is priority 1 and type 1 is priority 2, type 2 will override type 1 during overlaps.

**Split: create separate periods at all exposure boundaries** — Splits overlapping periods at all boundaries, creating separate rows for each unique combination of overlapping exposures. Use this when you need to track all simultaneous exposures. May substantially increase the number of rows.

**Combine overlaps into variable** — Creates a new variable containing a string representation of all overlapping exposures. For example, if exposures 1 and 2 overlap, the combined variable might contain "1+2". Specify the name for this new variable.

### Pattern tracking

**Track exposure switching** — Creates a binary variable indicating whether the person ever switched between exposure types during follow-up. Useful for identifying people with complex exposure histories.

**Detailed switching pattern** — Creates a string variable showing the complete sequence of exposure switches (e.g., "0→1→2→1"). Provides detailed exposure trajectory information.

**Time in current state** — Creates a variable tracking the cumulative time (in days) spent in the current exposure state. Resets to 0 each time exposure changes.

---

## Output tab

The Output tab controls variable naming, file saving, and diagnostic options.

### Output variable naming

**Variable name** — Name for the created time-varying exposure variable. Default is `tv_exposure`. When using the "Create separate variable for each exposure type" option, this becomes the prefix for multiple variables (e.g., `tv_exposure1`, `tv_exposure2`).

**Reference category label** — Label to apply to the reference category in value labels. Default is "Unexposed." This makes output more readable.

**Custom variable label** — Optional descriptive label for the output variable(s). This will appear in output and `describe` commands.

### Additional variables

**Keep from master dataset** — List of variables from the current dataset (in memory) to include in the output. These variables will be duplicated across rows for each person. Useful for keeping demographic or baseline variables.

**Keep entry/exit dates** — When checked, includes the study entry and exit dates in the output dataset. Useful for verifying coverage and time periods.

### Save output

**Save as** — Optional filename for saving the output dataset. Click **Browse...** to specify a location. If not specified, the output replaces the current dataset in memory.

**Replace** — Allow overwriting an existing file with the same name.

### Diagnostics

**Check coverage** — Displays a table showing the number of people with full coverage, partial coverage, and no coverage. Useful for identifying data quality issues.

**Show gaps** — Lists individuals with gaps in exposure coverage during their follow-up period. Helps identify incomplete exposure data.

**Show overlaps** — Lists instances where exposure periods overlap in time. Useful for identifying data quality issues or understanding the extent of overlapping exposures.

**Summarize** — Displays summary statistics for the exposure distribution, including the number of periods and person-time by exposure category.

**Create validation** — Creates additional variables for validating the output, such as counts of exposure switches and coverage indicators.

---

## Remarks

### Order of operations

The tvexpose command processes options in a specific order:

1. Exposure data is loaded and merged with the current dataset
2. Grace period and merge options combine nearby periods
3. Lag and washout periods shift timing
4. Exposure type transformation is applied (duration, recency, etc.)
5. Overlapping exposures are resolved
6. Output variables are created and labeled

### Understanding exposure types

**Time-varying vs. fixed** — Basic time-varying exposure allows changes over time. Ever-treated creates a fixed exposure status after first exposure.

**Current/former** — The "former" status begins immediately when an exposure period ends. Use this to study both acute effects (current) and longer-term effects (former).

**Duration** — Cutpoints for duration are in the units specified by "Cumulative exposure unit." For example, with `continuousunit(years)` and `duration(1 5)`, you get categories of <1 year, 1-<5 years, and 5+ years of cumulative exposure.

**Recency** — Cutpoints are always in years, regardless of other unit settings. Use this to implement time-since-exposure models.

### Handling gaps

Different gap-handling options serve different purposes:

- **Grace period** — Merges brief interruptions in the same exposure
- **Merge** — Combines nearby periods of the same type
- **Fill gaps** — Extends final exposure when you believe it continues
- **Carry forward** — Imputes exposure during data gaps

Use these options carefully and document your choices, as they can substantially affect results.

### Overlapping exposures

When the same person has overlapping exposure periods (e.g., taking two medications simultaneously), you must decide how to represent this:

- **Layer** — Good for time-ordered exposures where recent matters most
- **Priority** — Good when some exposures are more important
- **Split** — Good when you need to model simultaneous exposures explicitly
- **Combine** — Good for identifying and describing overlap patterns

### Memory requirements

Creating time-varying datasets can substantially increase dataset size:

- **Row expansion** — Continuous exposure with monthly expansion can create 12 rows per person-year
- **Split boundaries** — The split option can create many rows when exposures overlap
- **Consider** — Use `expandunit(days)` for continuous exposure without row expansion when memory is limited

---

## Examples

### Example 1: Basic time-varying medication exposure

Create a time-varying variable tracking medication use:

1. Open the tvexpose dialog: `db tvexpose`
2. **Main tab:**
   - Exposure dataset: `medication_records.dta`
   - Person ID: `patient_id`
   - Start date: `rx_start_date`
   - Stop date: `rx_end_date`
   - Exposure variable: `medication_type`
   - Reference value: `0` (no medication)
   - Study entry: `study_entry_date`
   - Study exit: `outcome_date`
3. **Exposure Definition tab:**
   - Select: "Basic time-varying (default)"
4. **Data Handling tab:**
   - Grace period: `30` (merge gaps ≤30 days)
5. **Output tab:**
   - Variable name: `medication`
6. Click **OK**

### Example 2: Ever-treated analysis

Create an indicator for ever being treated with chemotherapy:

1. Open the tvexpose dialog
2. **Main tab:** Specify dataset and variables
3. **Exposure Definition tab:**
   - Select: "Ever-treated (binary switch at first exposure)"
   - Check: "Create separate variable for each exposure type"
4. **Output tab:**
   - Variable name: `ever_chemo`
5. Click **OK**

This creates binary variables (`ever_chemo1`, `ever_chemo2`, etc.) that switch to 1 at first exposure to each chemotherapy type.

### Example 3: Cumulative duration with categories

Track cumulative years of smoking in categories:

1. Open the tvexpose dialog
2. **Main tab:** Specify exposure dataset
3. **Exposure Definition tab:**
   - Select: "Duration categories"
   - Duration cutpoints: `1 5 10 20` (years)
   - Cumulative exposure unit: `years`
4. Click **OK**

This creates categories: <1 year, 1-<5 years, 5-<10 years, 10-<20 years, 20+ years.

### Example 4: Time since exposure (recency)

Study how effects vary by time since exposure:

1. Open the tvexpose dialog
2. **Main tab:** Specify dataset and variables
3. **Exposure Definition tab:**
   - Select: "Recency categories"
   - Recency cutpoints: `0.5 1 5` (years)
4. Click **OK**

This creates categories: <0.5 years since last exposure, 0.5-<1 year, 1-<5 years, 5+ years.

### Example 5: Current/former smoking

Track current vs. former smoking status:

1. Open the tvexpose dialog
2. **Main tab:** Specify dataset where exposure=1 indicates smoking
3. **Exposure Definition tab:**
   - Select: "Current/former (never=0, current=1, former=2)"
4. **Advanced tab:**
   - Washout period: `0` (no washout; former status starts immediately)
5. Click **OK**

This creates a variable with values: 0=never smoker, 1=current smoker, 2=former smoker.

### Example 6: Handling overlapping medications with priority

When two medications overlap, prioritize drug A over drug B:

1. Open the tvexpose dialog
2. **Main tab:** Specify dataset where exposure codes drugs (1=drug A, 2=drug B)
3. **Advanced tab:**
   - Select: "Priority order (space-separated list)"
   - Priority: `1 2` (drug 1 has higher priority)
4. Click **OK**

During overlap periods, drug A (code 1) takes precedence.

---

## Saved results

After running the command via the dialog, the following are stored in `r()`:

**Scalars:**
- `r(N)` — Number of observations in output
- `r(N_persons)` — Number of unique individuals
- `r(min_date)` — Earliest date in output
- `r(max_date)` — Latest date in output

**Macros:**
- `r(cmd)` — `tvexpose`
- `r(exposure_var)` — Name of created exposure variable(s)

---

## Also see

**Manual:** [R] tvexpose, [ST] stset, [ST] stsplit

**Related dialogs:** tvmerge

**Related commands:** `help tvexpose`, `help tvmerge`, `help stset`, `help stsplit`
