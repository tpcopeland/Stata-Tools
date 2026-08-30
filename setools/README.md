# setools — Swedish registry tools for epidemiological cohort studies

**Version 1.5.7** | 2026-08-30

`setools` provides Stata commands for Swedish registry cohort construction, Charlson comorbidity scoring, and multiple-sclerosis disability-progression endpoints. It is for applied epidemiologists who need reproducible person-level migration, diagnosis, EDSS, and relapse workflows.

## Quick Start

Install `setools`, open its command browser, and inspect the multiple-sclerosis commands:

```stata
capture ado uninstall setools
net install setools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/setools") replace
setools, detail category(ms)
return list
```

## Requirements

- Stata 16 or later

The public commands have no external software dependency. `pira` additionally requires a separate relapse-event dataset, described below.

## Installation

Install or update the released package from Stata:

```stata
capture ado uninstall setools
net install setools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/setools") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `setools` | Browse the package commands and their registry or MS categories |
| `cci_se` | Compute the Swedish Charlson Comorbidity Index from ICD-7 through ICD-10 diagnosis data |
| `migrations` | Exclude non-residents and derive permanent-emigration censoring dates |
| `sustainedss` | Find the first sustained EDSS threshold date |
| `cdp` | Compute confirmed disability progression from a patient-specific baseline EDSS |
| `pira` | Classify the first confirmed progression as PIRA or relapse-associated worsening |

## How It Works

`setools` is a suite with three data workflows: diagnosis-level registry records, person-level cohorts with migration histories, and repeated EDSS visits with optional relapse events.

- `cci_se` collapses long diagnosis data to one row per patient, selects ICD definitions by diagnosis year, and optionally returns component indicators and earliest component dates.
- `migrations` joins a one-row-per-person cohort to a wide or long migration file, applies residency rules, and adds emigration censoring dates.
- `sustainedss` detects an absolute EDSS threshold crossing, whereas `cdp` measures a confirmed increase from a diagnosis-anchored baseline.
- `pira` runs the first-event CDP algorithm and classifies that event by its distance from relapse dates.

## Choosing a Workflow

| If you need to... | Use |
|-------------------|-----|
| Inspect the available commands | `setools` |
| Score Swedish registry comorbidities from ICD codes | `cci_se` |
| Enforce residency at cohort entry or create emigration censoring | `migrations` |
| Detect the first absolute EDSS milestone | `sustainedss` |
| Define confirmed disability progression from baseline | `cdp` |
| Separate the first confirmed progression into PIRA and RAW | `pira` |

## Worked Examples

### 1. Browse commands by category

Use the dispatcher when you want a compact list or descriptions before choosing an analysis command.

```stata
setools, list category(ms)
return list
```

### 2. Score the Swedish Charlson Index

The repository provides diagnosis-level example data at `_data/diagnoses.dta`. `cci_se` returns a patient-level score; `components` and `dates` add the component outputs.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/diagnoses.dta", clear
cci_se, id(id) icd(icd) date(visit_date) components dates noisily
summarize charlson
```

### 3. Use custom CCI output names

Choose a different score name or component prefix when the analysis dataset already uses the default names.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/diagnoses.dta", clear
cci_se, id(id) icd(icd) date(visit_date) generate(cci_score) components prefix(ch_)
tab ch_mi
```

### 4. Apply migration exclusions and censoring

`migrations` accepts a separate wide migration file. The temporary destination keeps the downloaded file out of the working directory.

```stata
local migfile "`c(tmpdir)'/migrations_wide.dta"
copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/migrations_wide.dta" "`migfile'", replace
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear
migrations, migfile("`migfile'") startvar(study_entry) quietly
return list
```

The returned data contain `migration_out_dt` for the first permanent emigration after study start. By default, people excluded by the migration criteria have been dropped.

### 5. Find a sustained EDSS threshold

This uses the repeated-visit example data and retains patients without an event so that `edss4_event` can be used downstream.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear
sustainedss id edss edss_date, threshold(4) keepall eventvar(edss4_event)
return list
```

### 6. Compute first confirmed disability progression

`cdp` uses the diagnosis date to select a baseline and the default two-tier EDSS change rule, with a 180-day confirmation interval.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear
cdp id edss edss_date, dxdate(dx_date) keepall eventvar(cdp_event)
return list
```

### 7. Track all roving CDP events

`roving allevents` changes the output to one row per confirmed event. The event number and baseline names can be supplied explicitly.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear
cdp id edss edss_date, dxdate(dx_date) roving allevents eventnumvar(cdp_number) baseedssvar(cdp_baseline) quietly
```

### 8. Classify the first CDP as PIRA or RAW

`pira` reads relapse events from a separate file. The default relapse window is 90 days before through 30 days after relapse onset.

```stata
local relapsefile "`c(tmpdir)'/relapses_only.dta"
copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses_only.dta" "`relapsefile'", replace
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear
pira id edss edss_date, dxdate(dx_date) relapses("`relapsefile'") keepall eventvar(pira_event)
gen str4 progression = cond(!missing(pira_date), "PIRA", cond(!missing(raw_date), "RAW", "None"))
tab progression
```

### 9. Require an observed sustained confirmation

Use `confirmvisit(window)` for a bounded observed confirmation instead of the default implied sustainment.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear
sustainedss id edss edss_date, threshold(4) confirmvisit(window) confirmwindow(90) keepall generate(edss4_confirmed)
```

## Demo

From a repository checkout, [`demo/demo_setools.do`](demo/demo_setools.do) runs one console workflow for each public command using the repository's `_data/` fixtures and converts the logs to HTML with `logdoc`. The script expects the repository's `logdoc` package alongside `setools`; generated console and HTML files are local outputs.

## Command Reference

### setools

```stata
setools [, list detail category(string)]
```

The `setools` display options are summarized under [Key Options](#key-options).

The default grouped display covers five public commands: `cci_se migrations sustainedss cdp pira`. The `codes` category contains `cci_se`, `migration` contains `migrations`, and `ms` contains `sustainedss cdp pira`.

### cci_se

```stata
cci_se [if] [in], id(varname) icd(varlist) date(varname) [generate(name) components dates prefix(string) dateformat(string) indexdate(varname) lookback(integer) noisily]
```

| Option | Default | Effect |
|--------|---------|--------|
| `id(varname)` | Required | Patient identifier; missing IDs are excluded |
| `icd(varlist)` | Required | One or more string diagnosis-code variables; multiple space-separated codes per cell are allowed |
| `date(varname)` | Required | Diagnosis date used to select ICD-7, ICD-8, ICD-9, or ICD-10 definitions |
| `generate(name)` | `charlson` | Name of the weighted CCI score |
| `components` | Off | Generate 18 binary component variables |
| `dates` | Off | Generate earliest component dates; also enables `components` |
| `prefix(string)` | `cci_` | Prefix for component and component-date variables |
| `dateformat(string)` | Numeric date: `stata`; string date: `yyyymmdd` | Parse dates as `stata`, `yyyymmdd`, or `ymd` |
| `indexdate(varname)` | None | Exclude diagnoses after the row's index date |
| `lookback(#)` | Disabled | Keep only diagnoses in the positive-number-of-days window ending at `indexdate()`; requires `indexdate()` |
| `noisily` | Off | Display patient counts, CCI summary statistics, and component prevalence when components are requested |

Numeric Stata dates require a `%td` format for `dateformat(stata)` and whole-number values. Numeric YYYYMMDD dates require explicit `dateformat(yyyymmdd)`; string dates default to YYYYMMDD parsing, including strings with dashes or slashes. The exact `ymd` mode accepts only string dates in YYYY-MM-DD form.

`cci_se` replaces the data in memory with one row per unique patient. The score uses the Swedish adaptation in Ludvigsson et al. (2021), with hierarchy rules for liver disease, diabetes, and metastatic cancer. Component variables use the default names `cci_mi`, `cci_chf`, and so on through `cci_aids`; `dates` adds matching `_date` variables.

### migrations

```stata
migrations, migfile(filename) [idvar(varname) startvar(varname) minresidence(#) saveexclude(filename) savecensor(filename) replace verbose quietly keepimmigrants intype(codes) outtype(codes) flag]
```

| Option | Default | Effect |
|--------|---------|--------|
| `migfile(filename)` | Required | Migration dataset in wide or long format |
| `idvar(varname)` | `id` | ID variable in both the cohort and migration file; must be unique in the cohort |
| `startvar(varname)` | `study_start` | Nonmissing Stata daily study-start date |
| `minresidence(#)` | `0` | Require this many days of residence before study start; positive values enable Type 4 exclusions |
| `saveexclude(filename)` | None | Save excluded IDs and `exclude_reason` |
| `savecensor(filename)` | None | Save IDs with nonmissing `migration_out_dt` |
| `replace` | Off | Allow replacement of existing save targets |
| `verbose` | Off | Display format-detection and processing messages |
| `quietly` | Off | Suppress the processing summary; warnings remain visible |
| `keepimmigrants` | Off | Retain Type 2 post-start immigrants and create `migration_in_dt` |
| `intype(codes)` | Built-in recognition | Map custom long-format immigration codes |
| `outtype(codes)` | Built-in recognition | Map custom long-format emigration codes |
| `flag` | Off | Retain all cohort rows and add `mig_excluded` and `mig_exclude_reason` |

Wide migration files have one row per person and numeric-suffixed `in_1`/`out_1`, `in_2`/`out_2`, and later slots, all formatted as `%td`. Long files have `event_date` and `event_type`; built-in recognition covers Swedish and English immigration/emigration vocabularies plus short forms, while `intype()` and `outtype()` support custom or unlabeled numeric codes.

The default exclusion sequence identifies people who emigrated before study start and never returned, people with insufficient pre-entry residence when enabled, people abroad at baseline who returned later, and people whose first post-start event is immigration. `keepimmigrants` changes the last case from exclusion to inclusion and records the post-start entry date.

### sustainedss

```stata
sustainedss idvar edssvar datevar [if] [in], threshold(#) [generate(name) confirmwindow(#) confirmvisit(mode) baselinethreshold(#) eventvar(name) exit(varname) keepall quietly]
```

| Option | Default | Effect |
|--------|---------|--------|
| `threshold(#)` | Required | Positive EDSS threshold for the absolute crossing |
| `generate(name)` | `sustained#_dt` | Date variable; decimal points in `threshold()` become underscores in the default name |
| `confirmwindow(#)` | `182` | Days used by `confirmvisit(window)` |
| `confirmvisit(mode)` | No observed visit required | Use `window` or `unlimited` to require a later assessment |
| `baselinethreshold(#)` | `threshold()` | Nonnegative EDSS reversal floor |
| `eventvar(name)` | None | New 0/1 indicator for a nonmissing sustained date |
| `exit(varname)` | None | Censor event dates strictly after a per-person Stata daily exit date |
| `keepall` | Off | Retain all original rows, including people without an accepted event |
| `quietly` | Off | Suppress iteration and summary messages |

Without `confirmvisit()`, a candidate is accepted if no later observed EDSS is below the reversal floor; no later visit is required. `confirmvisit(window)` uses the first later visit within the confirmation window, while `confirmvisit(unlimited)` uses the first later visit without a time limit and still checks the later values against the floor. Same-date EDSS duplicates are reduced conservatively to the lowest value.

### cdp

```stata
cdp idvar edssvar datevar [if] [in], dxdate(varname) [generate(name) confirmdays(#) baselinewindow(#) threetier confirmtype(type) eventvar(name) eventnumvar(name) baseedssvar(name) exit(varname) roving allevents keepall quietly]
```

| Option | Default | Effect |
|--------|---------|--------|
| `dxdate(varname)` | Required | Person-level diagnosis date anchoring baseline selection |
| `generate(name)` | `cdp_date` | Confirmed progression date |
| `confirmdays(#)` | `180` | Days from candidate to required confirmation |
| `baselinewindow(#)` | `730` | Days after diagnosis in which to search for baseline EDSS |
| `threetier` | Off | Use thresholds of 1.5 at baseline 0, 1.0 at 1.0–5.5, and 0.5 above 5.5 |
| `confirmtype(type)` | `sustained` | Use `sustained` or `visit` confirmation |
| `eventvar(name)` | None | New 0/1 indicator for a nonmissing CDP date |
| `eventnumvar(name)` | `event_num` under `roving allevents` | Name of the event-number variable; invalid without both options |
| `baseedssvar(name)` | `baseline_edss_at_event` under `roving allevents` | Name of the event-baseline EDSS variable; invalid without both options |
| `exit(varname)` | None | Censor CDP dates strictly after a per-person exit date |
| `roving` | Off | Reset baseline after each confirmed progression |
| `allevents` | Off | Return all roving events; requires `roving` |
| `keepall` | Off | Retain original measurement rows outside `roving allevents` |
| `quietly` | Off | Suppress the summary output |

The first baseline is the first EDSS within `baselinewindow()` days of diagnosis, or the earliest available measurement when none falls in that window. The default two-tier progression rule requires an increase of at least 1.0 for baseline EDSS up to 5.5 and 0.5 above 5.5. `confirmtype(sustained)` requires the minimum later EDSS to meet the threshold; `confirmtype(visit)` uses the first visit at least `confirmdays()` later. `roving` without `allevents` retains the first-event estimand; with both options, output is event-level.

### pira

```stata
pira idvar edssvar datevar [if] [in], dxdate(varname) relapses(filename) [relapseidvar(varname) relapsedatevar(varname) windowbefore(#) windowafter(#) generate(name) rawgenerate(name) confirmdays(#) baselinewindow(#) threetier confirmtype(type) rebaselinerelapse eventvar(name) exit(varname) keepall quietly]
```

| Option | Default | Effect |
|--------|---------|--------|
| `dxdate(varname)` | Required | Person-level diagnosis date anchoring baseline selection |
| `relapses(filename)` | Required | Separate relapse-event dataset |
| `relapseidvar(varname)` | Same as the EDSS ID variable | ID variable in the relapse file |
| `relapsedatevar(varname)` | `relapse_date` | Stata daily relapse date variable |
| `windowbefore(#)` | `90` | Days before relapse included in the RAW window |
| `windowafter(#)` | `30` | Days after relapse included in the RAW window |
| `generate(name)` | `pira_date` | Date of the first confirmed progression outside relapse windows |
| `rawgenerate(name)` | `raw_date` | Date of the first confirmed progression inside a relapse window |
| `confirmdays(#)` | `180` | CDP confirmation interval |
| `baselinewindow(#)` | `730` | Baseline search window after diagnosis |
| `threetier` | Off | Use the three-tier EDSS thresholds |
| `confirmtype(type)` | `sustained` | Use `sustained` or `visit` confirmation |
| `rebaselinerelapse` | Off | Reset baseline after a relapse using the first EDSS at least 30 days later |
| `eventvar(name)` | None | New 0/1 indicator equal to 1 for a PIRA date |
| `exit(varname)` | None | Censor both PIRA and RAW dates strictly after a per-person exit date |
| `keepall` | Off | Retain all original EDSS rows, including patients without CDP |
| `quietly` | Off | Suppress the summary output |

The relapse file must contain one row per relapse event, a matching ID type, and a numeric whole-number `%td` date. `pira` classifies only the first confirmed CDP per person: outside every relapse window is PIRA, and inside any window is RAW. An event indicator from `eventvar()` marks PIRA only; RAW-only progressors receive 0.

## Key Options

The package overview command accepts these display options:

| Option | Default | Effect |
|--------|---------|--------|
| `list` | Off | Display only command names for the selected category |
| `detail` | Off | Display grouped command descriptions; mutually exclusive with `list` |
| `category(string)` | `all` | Select `all`, `codes`, `migration`, or `ms` |

### Date windows and registry coding

`cci_se` selects ICD definitions from the diagnosis year: ICD-7 through 1968, ICD-8 from 1969 through 1986, ICD-9 from 1987 through 1997, and ICD-10 from 1997 onward, with the overlap year checked against both ICD-9 and ICD-10. Dots and Swedish comma separators are stripped from diagnosis codes before matching.

Use `indexdate()` to exclude post-index diagnoses and add `lookback()` for a positive lower bound in days. This is the relevant safeguard when a comorbidity history must be defined before cohort entry.

### Migration classification

`migrations` recognizes wide files with numeric-suffixed migration slots and long files with `event_date`/`event_type`. Long-format string or labeled numeric event types use built-in Swedish and English recognition; unlabeled numeric codes require `intype()` and `outtype()`, whose values must be disjoint.

Use `flag` when you need the full starting cohort for a CONSORT-style flow or sensitivity analysis. Use `keepimmigrants` when post-start immigrants should remain in the data with `migration_in_dt` as their effective entry date. The two options can be combined.

### MS confirmation and censoring

`sustainedss` is an absolute threshold measure and defaults to implied sustainment; `cdp` and `pira` are baseline-referenced measures that require an observed confirmation. The `confirmtype(visit)` alternative checks the first eligible confirming visit, while `threetier` selects the 1.5/1.0/0.5 EDSS thresholds used in the Lublin/Kappos rule.

The `exit()` option handles per-person administrative censoring inside each MS command. It sets post-exit event dates to missing, recomputes event indicators, and returns `r(N_censored_exit)` when requested.

## Stored Results

All public commands are `rclass` commands. Results are available immediately after the command and are overwritten by subsequent Stata commands that return results.

### `setools`

| Result | Class | Meaning |
|--------|-------|---------|
| `r(n_commands)` | Scalar | Number of commands in the selected category |
| `r(commands)` | Local macro | Space-separated selected command names |
| `r(version)` | Local macro | Package version |
| `r(categories)` | Local macro | `all codes migration ms` |
| `r(category)` | Local macro | Selected category |
| `r(display)` | Local macro | `grouped`, `list`, or `detail` |

### `cci_se`

| Result | Class | Meaning |
|--------|-------|---------|
| `r(N_input)` | Scalar | Diagnosis rows scored after exclusions and date-window filters |
| `r(N_patients)` | Scalar | Unique patients in the output |
| `r(N_any)` | Scalar | Patients with CCI greater than zero |
| `r(mean_cci)` | Scalar | Mean patient-level CCI |
| `r(max_cci)` | Scalar | Maximum patient-level CCI |
| `r(N_excluded_window)` | Scalar | Rows excluded by index-date or lookback windowing |
| `r(lookback)` | Scalar, with `lookback()` | Requested lookback in days |

### `migrations`

| Result | Class | Meaning |
|--------|-------|---------|
| `r(N_excluded_emigrated)` | Scalar | Type 1 exclusions: emigrated before study start and never returned |
| `r(N_excluded_inmigration)` | Scalar | Type 2 exclusions: first post-start migration is immigration; zero when `keepimmigrants` is used |
| `r(N_excluded_abroad)` | Scalar | Type 3 exclusions: abroad at baseline and returned later |
| `r(N_excluded_minresidence)` | Scalar | Type 4 exclusions for insufficient pre-entry residence |
| `r(N_excluded_total)` | Scalar | Total excluded across applied criteria |
| `r(N_censored)` | Scalar | People with a permanent-emigration censoring date |
| `r(N_included_inmigration)` | Scalar | Type 2 people retained under `keepimmigrants` |
| `r(N_final)` | Scalar | Analytic cohort size after exclusions |
| `r(N_analytic)` | Scalar | Analytic cohort size after exclusions |
| `r(N_returned)` | Scalar | Rows returned to memory |
| `r(flow)` | Matrix | Named exclusion-flow column vector |

The row names of `r(flow)` identify cohort start, exclusion stages, total excluded, censoring dates, analytic cohort, and returned rows. When `flag` is used, the analytic cohort excludes flagged people while returned rows retain the starting cohort.

### `sustainedss`

| Result | Class | Meaning |
|--------|-------|---------|
| `r(N_events)` | Scalar | Patients with an accepted sustained event after exit censoring |
| `r(iterations)` | Scalar | Algorithm iterations |
| `r(converged)` | Scalar | Convergence indicator; the public command returns 1 on success |
| `r(threshold)` | Scalar | EDSS threshold used |
| `r(confirmwindow)` | Scalar | Confirmation window in days |
| `r(N_censored_exit)` | Scalar, with `exit()` | Events censored after study exit |
| `r(varname)` | Local macro | Generated date variable name |
| `r(confirmvisit)` | Local macro | Blank, `window`, or `unlimited` |
| `r(eventvar)` | Local macro, if requested | Event-indicator name |
| `r(exit)` | Local macro, with `exit()` | Study-exit variable name |

### `cdp`

| Result | Class | Meaning |
|--------|-------|---------|
| `r(N_persons)` | Scalar | Persons with confirmed CDP after exit censoring |
| `r(N_events)` | Scalar | Confirmed CDP events after exit censoring |
| `r(confirmdays)` | Scalar | Confirmation interval in days |
| `r(baselinewindow)` | Scalar | Baseline window in days |
| `r(converged)` | Scalar | Confirmation-loop convergence indicator |
| `r(N_censored_exit)` | Scalar, with `exit()` | Events censored after study exit |
| `r(varname)` | Local macro | Generated CDP date variable |
| `r(confirmtype)` | Local macro | `sustained` or `visit` |
| `r(threetier)` | Local macro | `yes` or `no` |
| `r(roving)` | Local macro | `yes` or `no` |
| `r(eventvar)` | Local macro, if requested | Event-indicator name |
| `r(eventnumvar)` | Local macro, under `roving allevents` | Event-number variable name |
| `r(baseedssvar)` | Local macro, under `roving allevents` | Event-baseline variable name |
| `r(exit)` | Local macro, with `exit()` | Study-exit variable name |

### `pira`

| Result | Class | Meaning |
|--------|-------|---------|
| `r(N_cdp)` | Scalar | First CDP count after exit censoring |
| `r(N_cdp_preexit)` | Scalar | First CDP count before exit censoring |
| `r(N_pira)` | Scalar | First CDPs outside relapse windows |
| `r(N_raw)` | Scalar | First CDPs inside relapse windows |
| `r(windowbefore)` | Scalar | Pre-relapse window in days |
| `r(windowafter)` | Scalar | Post-relapse window in days |
| `r(confirmdays)` | Scalar | CDP confirmation interval in days |
| `r(baselinewindow)` | Scalar | Baseline window in days |
| `r(converged)` | Scalar | Confirmation-loop convergence indicator |
| `r(N_censored_exit)` | Scalar, with `exit()` | Events censored after study exit |
| `r(pira_varname)` | Local macro | Generated PIRA date variable |
| `r(raw_varname)` | Local macro | Generated RAW date variable |
| `r(confirmtype)` | Local macro | `sustained` or `visit` |
| `r(threetier)` | Local macro | `yes` or `no` |
| `r(rebaselinerelapse)` | Local macro | `yes` or `no` |
| `r(event_scope)` | Local macro | `first_confirmed_cdp` |
| `r(eventvar)` | Local macro, if requested | Event-indicator name |
| `r(exit)` | Local macro, with `exit()` | Study-exit variable name |

## Assumptions and Limits

- All MS EDSS, diagnosis, migration, relapse, index, and exit dates that the commands validate as Stata dates must be numeric whole-number daily dates with a `%td` format; `cci_se` additionally supports its documented YYYYMMDD and YYYY-MM-DD parsing modes.
- `migrations` requires one cohort row per ID and nonmissing study-start dates; its migration file must share the ID and resolve to one row per ID.
- `cci_se` expects long diagnosis-level data and replaces memory with the patient-level result. Save the result before merging it into a separate analysis cohort.
- `sustainedss`, `cdp`, and `pira` modify the data in memory and drop non-event patients by default; exit-censored patients are retained with a valid 0 event indicator, and `keepall` retains the full input cohort or visit structure.
- `cdp` and `pira` require a nonmissing, person-consistent diagnosis date; `pira` also requires matching ID types and valid relapse dates in its separate file.
- Generated output names must be new. Drop or rename prior output variables before rerunning a command; `migrations` reserves names beginning `_mig_`, and `pira` reserves its documented internal prefixes.
- Same-day migration semantics are explicit: immigration on study start counts as present at baseline, emigration on study start is not pre-start exclusion or post-start censoring, and post-start censoring uses strictly later emigration dates.
- `pira` classifies only the first confirmed CDP per person, while `cdp` can return multiple events only with `roving allevents`.
- An all-zero `cci_se` result when diagnosis codes are present triggers an informational warning; check separators and the diagnosis years before interpreting it as a genuinely healthy cohort.

## References

- Charlson ME, Pompei P, Ales KL, MacKenzie CR. A new method of classifying prognostic comorbidity in longitudinal studies: development and validation. `Journal of Chronic Diseases`. 1987;40(5):373-383.
- Ludvigsson JF, Appelros P, Askling J, et al. Adaptation of the Charlson comorbidity index for register-based research in Sweden. `Clinical Epidemiology`. 2021;13:21-41. doi:10.2147/CLEP.S282475.
- Lublin FD, Reingold SC, Cohen JA, et al. Defining the clinical course of multiple sclerosis: the 2013 revisions. `Neurology`. 2014;83(3):278-286.
- Kappos L, Butzkueven H, Wiendl H, et al. Greater sensitivity to multiple sclerosis disability worsening and progression events using a roving versus a fixed reference value. `Multiple Sclerosis Journal`. 2018;24:963-973.
- Kappos L, Wolinsky JS, Giovannoni G, et al. Contribution of relapse-independent progression versus relapse-associated worsening to overall confirmed disability accumulation. `JAMA Neurology`. 2020;77:1132-1140.
- Kappos L, et al. Inclusion of brain volume loss in a revised measure of no evidence of disease activity in relapsing-remitting multiple sclerosis. `Multiple Sclerosis Journal`. 2016;22(10):1297-1305.

## QA

QA suites and how to run them are documented in [`qa/README.md`](qa/README.md).

## Version History

- **1.5.7** (2026-08-30): Rejected missing or nonpositive sustained-EDSS thresholds, missing or negative reversal floors, and negative CCI lookback windows instead of accepting public sentinel values. Added exact rollback, installed-helper, and self-contained help-render coverage, and repaired over-wide help-table descriptions.
- **1.5.6** (2026-08-28): Accelerated the registry-scale longitudinal engines without changing their public interface or numerical definitions. `pira, rebaselinerelapse` now uses one forward Mata state-machine pass, while `cdp`, `pira`, and `sustainedss` use a shared sort-free grouped-minimum helper inside their iterative confirmation loops. Added row-level legacy-equivalence validation and a reproducible one-million-visit benchmark.
- **1.5.5** (2026-08-13): Fixed `migrations` silently dropping the emigration censoring date for a person who immigrated before study start and emigrated permanently after it; because `in_`/`out_` are independently numbered, both events could share one reshape row and the immigration-only pre-filter discarded the row wholesale. This also made wide- and long-format migration files disagree. Corrected the `r(converged)` description in `cdp`, `pira`, and `sustainedss` (it is always 1; non-convergence exits with error r(430)) and removed the unreachable display branches, a no-op wide-format date assignment, and a duplicate-name hazard in the `pira` working varlist.
- **1.5.4** (2026-08-11): Enforced person-level diagnosis and exit-date consistency across the full sampled data, rejected invalid PIRA relapse-file variable names during syntax parsing, removed a PIRA scratch/output namespace collision, isolated internal helpers from variable-abbreviation state, hardened file-handle cleanup, and simplified decorative console output.
- **1.5.3** (2026-08-05): Corrected the `migrations` reserved-namespace documentation to match its `_mig_*` working-state contract.
- **1.5.2** (2026-08-05): Restored the documented `q` minimum abbreviation for `migrations`' `quietly`, moved the `migrations` internal workspace fully into the reserved `_mig_*` namespace, and added an up-front refusal when master data already occupies that namespace.
- **1.5.1** (2026-07-19): Fixed the no-candidate roving CDP path, long-format migration files whose first observed event is emigration, macOS path aliasing, and wide-format date-slot handling; added `migrations` `quietly` and clarified exit-censored results and same-day migration boundaries.
- **1.5.0** (2026-07-13): Corrected Swedish CCI mappings, repaired roving CDP and event-level output contracts, hardened migration exclusions and exports, treated extended missings as missing, and clarified analytic versus returned migration counts.
- **1.4.1** (2026-07-03): Corrected post-start immigration classification, retained permanent-emigration censoring for included immigrants, and prevented migration-file columns from shadowing master values; made roving CDP row selection deterministic.
- **1.4.0** (2026-06-15): Added opt-in exit censoring, migration event-type recognition and overrides, migration flag mode and flow results, and a CCI zero-match diagnostic.
- **1.3.0** (2026-06-14): Added three-tier EDSS thresholds, confirmation-type choices, event indicators, convergence results, and CCI index-date lookback windowing; consolidated the shared CDP engine.
- **1.2.3** (2026-05-06): Hardened known-answer and boundary behavior, corrected ICD-era restrictions, and preserved row order after CDP/PIRA merges.
- **1.2.2** (2026-05-04): Removed the superseded `procmatch` command and corrected help-file abbreviations.
- **1.2.1** (2026-04-26): Expanded help files and added cross-references and command-selection guidance.
- **1.2.0** (2026-04-24): Added `dates` to `cci_se` and included the Mata ICD classification engine.
- **1.0.1** (2026-04-22): Added long-format migration files, strict daily-date checks, multiple diagnosis variables in `icd()`, and broader workflow coverage.
- **1.0.0** (2026-04-08): Initial Stata-Tools release of the Swedish registry toolkit.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
