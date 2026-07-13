# setools — Swedish registry tools for epidemiological cohort studies

**Version 1.5.0** | 2026-07-13

`setools` provides Stata commands for Swedish Charlson scoring, migration-based cohort construction, and MS disability-progression endpoints.

## Install and start

```stata
capture ado uninstall setools
net install setools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/setools") replace
setools
setools, detail category(ms)
return list
```

The flagship browser accepts `list`, `detail`, and `category(all|codes|migration|ms)`; `list` and `detail` are mutually exclusive. It returns `r(n_commands)`, `r(commands)`, `r(version)`, `r(categories)`, `r(category)`, and `r(display)`.

## Options

| Option | Meaning |
|--------|---------|
| `list` | Display only command names for the selected category |
| `detail` | Display grouped command descriptions; may not be combined with `list` |
| `category(all\|codes\|migration\|ms)` | Filter the displayed and returned command list; default is `all` |

## Stored Results

| Result | Meaning |
|--------|---------|
| `r(n_commands)` | Number of commands in the selected category |
| `r(commands)` | Space-separated command names in the selected category |
| `r(version)` | Package version |
| `r(categories)` | Allowed values for `category()`: `all codes migration ms` |
| `r(category)` | Selected category |
| `r(display)` | Display mode: `grouped`, `list`, or `detail` |

The package covers three data shapes:

1. **Diagnosis-level long data** — `cci_se` computes the Swedish Charlson Comorbidity Index from ICD-7 through ICD-10.
2. **Person-level cohort plus migration history** — `migrations` applies residence exclusions and derives censoring dates from a separate wide or long migration file.
3. **Repeated-visit EDSS long data** — `sustainedss`, `cdp`, and `pira` define MS disability-progression endpoints; `pira` also reads a relapse-event file.

## Requirements

- Stata 16 or later
- Internet access if you want to run the `_data/` example workflows below directly from GitHub

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

## Command Examples

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

Require an observed sustained-threshold confirmation, or request event-level roving CDP output with collision-safe names:

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear
sustainedss id edss edss_date, threshold(4) confirmvisit(window) confirmwindow(182) keepall

use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses.dta", clear
cdp id edss edss_date, dxdate(dx_date) roving allevents eventnumvar(cdp_event) baseedssvar(cdp_base)
```

`pira` requires a separate relapse file to classify progression as PIRA versus relapse-associated worsening:

```stata
copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/relapses_only.dta" "relapses_only.dta", replace
pira id edss edss_date, dxdate(dx_date) relapses("relapses_only.dta") keepall
```

By default, `sustainedss` needs no confirming visit and rejects a candidate if any later observed EDSS is below the reversal floor. Add `confirmvisit(window)` for confirmation within `confirmwindow()` (182 days by default), or `confirmvisit(unlimited)` to require the first later visit with no maximum delay. `cdp` and `pira` use `confirmdays()` and always require an observed confirmation. Use `windowbefore()` / `windowafter()` to adjust the PIRA relapse window.

## Data Shape Notes

- `cci_se` expects diagnosis-level long data with an ID, a date variable, and one or more diagnosis-code variables.
- `migrations` expects one row per person in memory plus a migration file in either wide `in_#`/`out_#` format or long `event_date`/`event_type` format.
- `sustainedss`, `cdp`, and `pira` accept unsorted repeated-visit EDSS data and sort their analytic copies internally. Outside event-level `cdp, roving allevents`, original visit order is restored where rows are retained.

## References

- Charlson ME, Pompei P, Ales KL, MacKenzie CR. A new method of classifying prognostic comorbidity in longitudinal studies: development and validation. *Journal of Chronic Diseases*. 1987;40(5):373-383.
- Ludvigsson JF, Appelros P, Askling J, et al. Adaptation of the Charlson comorbidity index for register-based research in Sweden. *Clinical Epidemiology*. 2021;13:21-41.
- Kappos L, et al. Inclusion of brain volume loss in a revised measure of no evidence of disease activity in relapsing-remitting multiple sclerosis. *Multiple Sclerosis Journal*. 2016;22(10):1297-1305.
- Lublin FD, et al. Defining the clinical course of multiple sclerosis: the 2013 revisions. *Neurology*. 2014;83(3):278-286.

## Version History

- **1.5.0** (2026-07-13): Corrected Swedish CCI mappings against the pinned Ludvigsson reference, including uncovered dementia/AIDS prefix overlap; repaired roving CDP candidate retry, confirmation-baseline transition, event-level output, collision preflight, and per-person date contracts; made migration path aliases and multi-file exports transactional and treated all extended missings as missing; defined analytic versus returned migration counts; corrected post-exit PIRA counts and documented its first-CDP scope; and changed `sustainedss` to implied sustainment by default with opt-in bounded or unlimited confirming visits. Rebuilt isolated QA with authoritative Python parity, exact rollback/error tests, reproducible fixtures, lanes, and installed documentation/release checks.
- **1.4.1** (2026-07-03): Correctness fixes. `migrations`: a person whose first-ever migration event is a post-start immigration is now classified Type 2 (abroad at baseline) even when a later post-start emigration exists — previously such persons were silently retained with person-time from study start; under `keepimmigrants`, included immigrants who later emigrate permanently now receive their `migration_out_dt` censoring date; migration-file columns other than the ID and `in_*`/`out_*` dates are now dropped before processing, so a stray `study_start` (or other master-named) column in the migration file can no longer silently shadow master values. `cdp`: with `roving` `allevents`, the retained covariate row per person is now deterministically the first row of the original data, and same-day duplicate visits re-baseline deterministically on the lower EDSS (previously both depended on Stata's non-stable sort order).
- **1.4.0** (2026-06-15): Usability and robustness additions, all opt-in (released defaults unchanged). `exit(varname)` on `sustainedss`/`cdp`/`pira` censors event dates that fall after a per-person study-exit date (sets the date to missing and `eventvar()` to 0), replacing the hand-written post-exit clipping these endpoints usually need; adds `r(N_censored_exit)` and `r(exit)`. `migrations` now recognizes the Swedish register `event_type` vocabulary (`Invandring`/`Utvandring`) and English variants in long-format files, with `intype()`/`outtype()` to map any other coding (including unlabeled numeric codes) and a clear diagnostic listing unrecognized values — fixing the long-format failure that forced manual fallbacks. `migrations` also gains `flag` (mark excluded individuals in `mig_excluded`/`mig_exclude_reason` instead of dropping them) and returns `r(flow)`, a CONSORT-style exclusion-flow matrix. `cci_se` warns when ICD codes are present but no patient matches any Charlson component (catches separator/era mismatches).
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
