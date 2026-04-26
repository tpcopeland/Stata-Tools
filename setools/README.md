# setools - Swedish registry tools for epidemiological cohort studies

**Version 1.2.1** | 2026-04-26

`setools` is a registry-workflow toolkit rather than a single estimation command. It groups together utilities for Swedish diagnosis and procedure coding, migration-based cohort construction, and multiple-sclerosis disability progression endpoints built from repeated EDSS measurements.

The package is most useful when you need practical building blocks for cohort definition, comorbidity scoring, and endpoint derivation in Swedish register-based research.

The package metadata, help files, and `setools` return value are synchronized at version 1.2.1 dated 2026-04-26.

## Requirements

- Stata 16 or later
- Internet access if you want to run the `_data/` example workflows below directly from GitHub

## Installation

```stata
capture ado uninstall setools
net install setools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/setools") replace
```

## Commands

### Registry code utilities

| Command | Description |
|---------|-------------|
| `setools` | Package overview and command browser |
| `cci_se` | Compute the Swedish Charlson Comorbidity Index from ICD-7 through ICD-10 data |
| `procmatch` | Match KVÅ procedure codes and extract first-occurrence dates |

### Cohort construction

| Command | Description |
|---------|-------------|
| `migrations` | Apply migration-based exclusions and derive emigration censoring dates |

### Multiple sclerosis progression endpoints

| Command | Description |
|---------|-------------|
| `sustainedss` | Compute sustained EDSS threshold dates |
| `cdp` | Compute confirmed disability progression dates from baseline EDSS |
| `pira` | Classify confirmed progression as PIRA or relapse-associated worsening |

## How It Works

`setools` covers three distinct data shapes, and the right command depends on which one you have in memory:

1. `cci_se` and `procmatch` work on long diagnosis-level or procedure-level registry data. `cci_se` can read one diagnosis variable or a list of diagnosis variables per row.
2. `migrations` works on a person-level cohort in memory plus a separate migration file supplied in either wide `in_#`/`out_#` format or long `event_date`/`event_type` format.
3. `sustainedss`, `cdp`, and `pira` work on repeated EDSS measurements, and `pira` also needs a relapse file.

Start with `setools` or `setools, detail` inside Stata if you want a menu-style overview before choosing a command.

## Choosing the Right Command

| If you need to... | Use |
|-------------------|-----|
| Turn diagnosis codes into a Swedish Charlson score | `cci_se` |
| Search one or more procedure variables for a KVÅ code set | `procmatch` |
| Exclude people not resident in Sweden at study start and derive emigration censoring | `migrations` |
| Find the first sustained EDSS threshold crossing | `sustainedss` |
| Define confirmed disability progression from baseline EDSS | `cdp` |
| Separate confirmed progression into PIRA versus relapse-associated worsening | `pira` |

## Worked Examples

### 1. Inspect the package inside Stata

```stata
setools
setools, detail
```

### 2. Swedish Charlson Comorbidity Index with `cci_se`

`cci_se` expects long diagnosis-level data. You can pass one ICD variable or a list of diagnosis variables in `icd()`, as long as the row-level `date()` applies to all of them. The public example file already has the variables used in the help file: `id`, `icd`, and `visit_date`.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/diagnoses.dta", clear
cci_se, id(id) icd(icd) date(visit_date) components noisily
summarize charlson
```

Use `components` when you want the individual comorbidity indicators as well as the total score.

### 3. Migration-based exclusions and censoring with `migrations`

`migrations` needs a local file path in `migfile()`, so this example first downloads both the cohort and migration files into the working directory. `migfile()` may point either to the traditional wide `migrations_wide.dta` file or to a long event file with `event_date` and `event_type` (`Inv`/`Utv`). The master `startvar()`, long `event_date`, and wide `in_#`/`out_#` variables must all be Stata daily dates with `%td` display formats; `%tc` datetime variables are rejected.

```stata
copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta" "cohort_example.dta", replace
copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/migrations_wide.dta" "migrations_wide.dta", replace

use "cohort_example.dta", clear
migrations, migfile("migrations_wide.dta") startvar(study_entry) verbose

gen double admin_end = mdy(12,31,2023)
gen double exit_date = min(admin_end, death_date, migration_out_dt)
format exit_date %td
```

After `migrations`, excluded people are dropped and `migration_out_dt` is ready for use as a right-censoring date in downstream survival setup.

### 4. Procedure code matching with `procmatch`

`procmatch match` searches one or more code variables for any member of a code list. `procmatch first` then adds a subject-level first-occurrence date.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/procedures.dta", clear
procmatch match, codes("FNG02 FNG05") procvars(kva_code) ///
    generate(cardiac_proc_match) prefix noisily

procmatch first, codes("FNG02 FNG05") procvars(kva_code) ///
    datevar(proc_date) idvar(id) ///
    generate(cardiac_proc_ever) gendatevar(cardiac_proc_dt)
```

### 5. Sustained EDSS and CDP from repeated EDSS data

The `_data/relapses.dta` example file contains repeated EDSS measurements together with diagnosis and relapse dates. `sustainedss` and `cdp` use the visit-level EDSS fields directly.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear
sustainedss id edss edss_date, threshold(4) keepall
cdp id edss edss_date, dxdate(dx_date) keepall
```

Use `confirmwindow()` in `sustainedss` or `confirmdays()` in `cdp` when your study uses a shorter or longer confirmation rule than the defaults.

### 6. PIRA versus relapse-associated worsening with `pira`

`pira` requires a separate relapse file, so this workflow downloads both the EDSS visits file and the relapse-only file referenced by the help file.

```stata
copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta" "relapses_example.dta", replace
copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses_only.dta" "relapses_only.dta", replace

use "relapses_example.dta", clear
pira id edss edss_date, dxdate(dx_date) relapses("relapses_only.dta") keepall
```

Adjust `windowbefore()` and `windowafter()` if your protocol uses a different relapse exclusion window.

## Data Shape Notes

- `cci_se` expects diagnosis-level long data with an ID, a date variable, and one or more diagnosis-code variables.
- `procmatch` expects one or more procedure-code variables, and `procmatch first` also needs a date variable and subject ID.
- `migrations` expects one row per person in memory plus a migration file in either wide `in_#`/`out_#` format or long `event_date`/`event_type` format.
- `sustainedss`, `cdp`, and `pira` expect EDSS visits sorted within person by date.

## References

- Charlson ME, Pompei P, Ales KL, MacKenzie CR. A new method of classifying prognostic comorbidity in longitudinal studies: development and validation. *Journal of Chronic Diseases*. 1987;40(5):373-383.
- Ludvigsson JF, Appelros P, Askling J, et al. Adaptation of the Charlson comorbidity index for register-based research in Sweden. *Clinical Epidemiology*. 2021;13:21-41.
- Kappos L, et al. Inclusion of brain volume loss in a revised measure of no evidence of disease activity in relapsing-remitting multiple sclerosis. *Multiple Sclerosis Journal*. 2016;22(10):1297-1305.
- Lublin FD, et al. Defining the clinical course of multiple sclerosis: the 2013 revisions. *Neurology*. 2014;83(3):278-286.

## Version History

- **1.2.0** (2026-04-24): Added `dates` option to `cci_se` — generates earliest diagnosis date per comorbidity component alongside the binary indicators. Also includes the v1.1.0 Mata hash-table engine for faster ICD classification.
- **1.0.1** (2026-04-22): Added long-format migration-file support in `migrations`, enforced `%td` daily-date formats for `migrations` inputs, extended `cci_se` to accept multiple diagnosis variables in `icd()`, and expanded QA coverage for both features
- **1.0.0** (2026-04-08): Initial Stata-Tools release of the Swedish registry toolkit

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
