# setools — Swedish registry tools for epidemiological cohort studies

**Version 1.3.0** | 2026-06-14

`setools` provides practical Stata commands for working with Swedish health registries. Instead of writing one-off data-management code for each new project, you get tested, documented building blocks for the steps that recur across register-based cohort studies: comorbidity scoring, migration-based exclusions, and MS disability-progression endpoints.

The package covers two data shapes:

1. **Diagnosis-level data** — `cci_se` computes the Swedish Charlson Comorbidity Index (ICD-7 through ICD-10).
2. **Person-level cohort data** — `migrations` applies migration-based exclusions and derives emigration censoring dates; `sustainedss`, `cdp`, and `pira` define MS disability-progression endpoints from repeated EDSS measurements.

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

1. `cci_se` works on long diagnosis-level registry data. It can read one diagnosis variable or a list of diagnosis variables per row.
2. `migrations` works on a person-level cohort in memory plus a separate migration file supplied in either wide `in_#`/`out_#` format or long `event_date`/`event_type` format.
3. `sustainedss`, `cdp`, and `pira` work on repeated EDSS measurements, and `pira` also needs a relapse file.

Start with `setools` or `setools, detail` inside Stata if you want a menu-style overview before choosing a command.

## Choosing the Right Command

| If you need to... | Use |
|-------------------|-----|
| Turn diagnosis codes into a Swedish Charlson score | `cci_se` |
| Exclude people not resident in Sweden at study start and derive emigration censoring | `migrations` |
| Find the first sustained EDSS threshold crossing | `sustainedss` |
| Define confirmed disability progression from baseline EDSS | `cdp` |
| Separate confirmed progression into PIRA versus relapse-associated worsening | `pira` |

## Quick Start

### Swedish Charlson Comorbidity Index

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/diagnoses.dta", clear
cci_se, id(id) icd(icd) date(visit_date) components noisily
summarize charlson
```

Use `components` to get individual comorbidity indicators alongside the total score. Use `dates` to also get the earliest diagnosis date per component.

### Migration exclusions and censoring

`migrations` needs a local file path in `migfile()`. It accepts both wide `in_#`/`out_#` format and long `event_date`/`event_type` format. All date variables must be Stata daily dates with `%td` formats.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear
copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/migrations_wide.dta" "migrations_wide.dta", replace
migrations, migfile("migrations_wide.dta") startvar(study_entry) verbose
```

After `migrations`, excluded people are dropped and `migration_out_dt` is ready for use as a right-censoring date.

### MS disability progression endpoints

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear
sustainedss id edss edss_date, threshold(4) keepall
cdp id edss edss_date, dxdate(dx_date) keepall
```

`pira` requires a separate relapse file to classify progression as PIRA versus relapse-associated worsening:

```stata
copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses_only.dta" "relapses_only.dta", replace
pira id edss edss_date, dxdate(dx_date) relapses("relapses_only.dta") keepall
```

Use `confirmwindow()` / `confirmdays()` when your study uses a different confirmation rule, and `windowbefore()` / `windowafter()` to adjust the relapse exclusion window.

## Data Shape Notes

- `cci_se` expects diagnosis-level long data with an ID, a date variable, and one or more diagnosis-code variables.
- `migrations` expects one row per person in memory plus a migration file in either wide `in_#`/`out_#` format or long `event_date`/`event_type` format.
- `sustainedss`, `cdp`, and `pira` expect EDSS visits sorted within person by date.

## References

- Charlson ME, Pompei P, Ales KL, MacKenzie CR. A new method of classifying prognostic comorbidity in longitudinal studies: development and validation. *Journal of Chronic Diseases*. 1987;40(5):373-383.
- Ludvigsson JF, Appelros P, Askling J, et al. Adaptation of the Charlson comorbidity index for register-based research in Sweden. *Clinical Epidemiology*. 2021;13:21-41.
- Kappos L, et al. Inclusion of brain volume loss in a revised measure of no evidence of disease activity in relapsing-remitting multiple sclerosis. *Multiple Sclerosis Journal*. 2016;22(10):1297-1305.
- Lublin FD, et al. Defining the clinical course of multiple sclerosis: the 2013 revisions. *Neurology*. 2014;83(3):278-286.

## Version History

- **1.3.0** (2026-06-14): New methodological options on the MS progression commands, all opt-in (released defaults unchanged): `threetier` (Lublin 2014 / Kappos three-tier EDSS threshold) and `confirmtype(sustained|visit)` on `cdp`/`pira`; `eventvar()` stset-ready 0/1 event indicator on `cdp`/`pira`/`sustainedss`; `converged` stored result + warning parity on `cdp`/`pira`. `cci_se` gains `indexdate()`/`lookback()` windowing to score comorbidities in a pre-index lookback window. Internals: the CDP engine shared by `cdp` and `pira` is consolidated into shared helpers (no more copy-paste desync). Bug fixes: `cci_se` now matches ICD-7/8 sub-codes regardless of separator (comma/dot/none — previously dotted input silently scored 0); `migrations` no longer leaks a blank `exclude_reason` column into the returned dataset; `migrations` preflights the `_mig_*`/`_neg_*` working namespace.
- **1.2.3** (2026-05-06): Hardened known-answer and adversarial QA; restricted ICD-10 Charlson matching to valid Swedish ICD-10 eras; fixed CDP/PIRA baseline-window selection when pre-diagnosis EDSS visits exist; preserved row order after CDP/PIRA keepall merges
- **1.2.2** (2026-05-04): Removed `procmatch` (superseded by `codescan` package); documentation fixes — abbreviation corrections across help files
- **1.2.1** (2026-04-26): Documentation improvements — richer help files for all Stata fluency levels, consistent cross-references across all commands, "Choosing the right command" guidance in the overview help file
- **1.2.0** (2026-04-24): Added `dates` option to `cci_se` — generates earliest diagnosis date per comorbidity component alongside the binary indicators. Also includes the v1.1.0 Mata hash-table engine for faster ICD classification
- **1.0.1** (2026-04-22): Added long-format migration-file support in `migrations`, enforced `%td` daily-date formats for `migrations` inputs, extended `cci_se` to accept multiple diagnosis variables in `icd()`, and expanded QA coverage for both features
- **1.0.0** (2026-04-08): Initial Stata-Tools release of the Swedish registry toolkit

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
