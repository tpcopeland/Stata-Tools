# setools - Swedish registry tools for epidemiological cohort studies

**Version**: 1.0.0 | 2026-04-08

`setools` is a toolbox for common Swedish registry workflows in epidemiology. It groups together utilities for diagnosis and procedure coding, migration-based cohort exclusions and censoring, and multiple sclerosis disability progression endpoints.

Unlike a single-command estimation package, `setools` is meant to be used as a menu of purpose-built tools. Run `setools` to see the package overview, or `setools, detail` for a fuller command listing inside Stata.

## Requirements

- Stata 16 or later
- Internet access if you want to run the public example-data workflows shown below

## Installation

```stata
capture ado uninstall setools
net install setools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/setools") replace
```

## Commands

### Registry code tools

| Command | Description |
|---------|-------------|
| `cci_se` | Compute the Swedish Charlson Comorbidity Index from ICD-7 to ICD-10 codes |
| `procmatch` | Match KVÅ procedure codes and extract first procedure dates |

### Cohort construction

| Command | Description |
|---------|-------------|
| `migrations` | Apply migration-based exclusions and generate emigration censoring dates |

### Multiple sclerosis progression endpoints

| Command | Description |
|---------|-------------|
| `sustainedss` | Compute sustained EDSS threshold dates |
| `cdp` | Compute confirmed disability progression dates |
| `pira` | Classify progression as PIRA or relapse-associated worsening |

### Package index

| Command | Description |
|---------|-------------|
| `setools` | Package overview and command browser |

## How It Works

`setools` covers three distinct data shapes.

1. `cci_se` and `procmatch` work on long diagnosis-level or procedure-level registry data.
2. `migrations` works on a person-level cohort plus a wide migration file with `in_1`, `out_1`, and related variables.
3. `sustainedss`, `cdp`, and `pira` work on repeated EDSS measurements. `pira` also needs a relapse file.

Because Stata does not ship `sysuse` or `webuse` datasets with Swedish registry structures, the worked examples below use public example files hosted in the `Stata-Tools/_data/` directory. Those examples are copy-paste runnable after installation.

## Worked Examples

### 1. Inspect the package inside Stata

Start by listing what is installed.

```stata
setools
setools, detail
```

### 2. Swedish Charlson Comorbidity Index with `cci_se`

This workflow starts from diagnosis-level data with one ICD code per row. `cci_se` collapses those records to the patient level and generates the Charlson score.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/diagnoses.dta", clear
cci_se, id(id) icd(icd) date(visit_date) components noisily
summarize charlson
```

Use `components` when you want the individual comorbidity indicators in addition to the total score.

### 3. Migration-based exclusions and censoring with `migrations`

`migrations` expects a local migration file path in `migfile()`, so this example first downloads the cohort and migration files to the working directory.

```stata
copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta" "cohort_example.dta", replace
copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/migrations_wide.dta" "migrations_wide.dta", replace

use "cohort_example.dta", clear
migrations, migfile("migrations_wide.dta") startvar(study_entry) verbose

gen double end_date = min(death_date, migration_out_dt, mdy(12,31,2023))
stset end_date, failure(outcome) origin(study_entry)
```

After `migrations`, excluded people are dropped and `migration_out_dt` is available for censoring the remaining cohort.

### 4. Procedure code matching with `procmatch`

`procmatch match` creates an indicator for any matching procedure code. `procmatch first` collapses to the subject level and returns the first matching procedure date.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/procedures.dta", clear
procmatch match, codes("FNG02 FNG05") procvars(kva_code) ///
    generate(cardiac_proc_match) prefix noisily

procmatch first, codes("FNG02 FNG05") procvars(kva_code) ///
    datevar(proc_date) idvar(id) ///
    generate(cardiac_proc_ever) gendatevar(cardiac_proc_dt)
```

Use `prefix` when you want prefix matching instead of exact code matching.

### 5. Sustained EDSS and CDP with repeated EDSS data

These commands operate on repeated neurologic assessments with one row per visit. `sustainedss` looks for a sustained threshold crossing, while `cdp` uses diagnosis date and a confirmation rule to define confirmed progression.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear
sustainedss id edss edss_date, threshold(4)
cdp id edss edss_date, dxdate(dx_date) keepall
```

`keepall` is useful when you want to retain the full visit-level file and simply mark the progression date variables.

### 6. PIRA versus RAW with `pira`

`pira` needs a relapse file. The example below derives that file from the same public demo dataset and then classifies each confirmed progression event as PIRA or relapse-associated worsening.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear
preserve
keep if relapse_date < .
keep id relapse_date
save "relapses_only.dta", replace
restore

pira id edss edss_date, dxdate(dx_date) relapses("relapses_only.dta") keepall
```

Adjust `windowbefore()` and `windowafter()` if your study uses a different relapse exclusion window.

## Choosing the Right Command

| If you need to... | Use |
|-------------------|-----|
| Turn diagnosis codes into a Swedish Charlson score | `cci_se` |
| Search many procedure variables for a KVÅ code set | `procmatch` |
| Exclude non-resident person-time and derive emigration censoring | `migrations` |
| Find the first sustained EDSS threshold crossing | `sustainedss` |
| Estimate confirmed disability progression from baseline EDSS | `cdp` |
| Split confirmed progression into PIRA versus relapse-associated worsening | `pira` |

## Notes on Data Shape

- `cci_se` expects diagnosis-level long data with an ID, ICD code, and date.
- `procmatch` expects one or more procedure-code variables, and `procmatch first` also needs a procedure date and person ID.
- `migrations` expects one row per person in both the cohort and migration files, with the migration file already reshaped to `in_#` and `out_#`.
- `sustainedss`, `cdp`, and `pira` expect EDSS visits sorted within person by date.

## References

- Charlson ME, Pompei P, Ales KL, MacKenzie CR. A new method of classifying prognostic comorbidity in longitudinal studies: development and validation. *Journal of Chronic Diseases*. 1987;40(5):373-383.
- Ludvigsson JF, Appelros P, Askling J, et al. Adaptation of the Charlson comorbidity index for register-based research in Sweden. *Clinical Epidemiology*. 2021;13:21-41.
- Kappos L, et al. Inclusion of brain volume loss in a revised measure of no evidence of disease activity in relapsing-remitting multiple sclerosis. *Multiple Sclerosis Journal*. 2016;22(10):1297-1305.
- Lublin FD, et al. Defining the clinical course of multiple sclerosis: the 2013 revisions. *Neurology*. 2014;83(3):278-286.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
