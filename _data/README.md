# _data — Shared Synthetic Example Data

This directory contains 19 fully synthetic `.dta` datasets used as shared example data across multiple packages in the Stata-Tools collection. No real patient data is included. The datasets simulate a pharmacoepidemiology cohort study comparing SSRI and SNRI antidepressant initiators in a Swedish registry setting.

## Datasets

| File | Description |
|------|-------------|
| `calendar.dta` | Calendar-time covariates and period indicators |
| `cci.dta` | Charlson Comorbidity Index scores |
| `cohort.dta` | Main cohort spine: one row per patient with entry/exit dates and treatment |
| `comorbidities.dta` | Wide-format comorbidity flags at cohort entry |
| `diagnoses.dta` | Long-format diagnosis history (ICD codes, dates) |
| `lisa.dta` | Socioeconomic register data (education, income, employment) |
| `migrations.dta` | Long-format migration/residence history |
| `migrations_wide.dta` | Wide-format version of migration data |
| `outcomes.dta` | Outcome events: dates and types |
| `prescriptions.dta` | Long-format prescription records |
| `procedures.dta` | Long-format procedure records |
| `relapses.dta` | Relapse/recurrence event records |
| `relapses_only.dta` | Relapse records filtered to index events only |
| `treatment.dta` | Treatment assignment and exposure periods |
| `tv_antidep.dta` | Time-varying antidepressant exposure in episode format |
| `tv_antidep_episodes.dta` | Antidepressant episodes with switch/augmentation flags |
| `tv_benzo_episodes.dta` | Benzodiazepine co-prescription episodes |
| `tv_events.dta` | Time-varying event records for outcome analysis |
| `tv_merged.dta` | Pre-merged time-varying dataset for tvtools examples |

## Usage

These datasets are referenced in package READMEs and `.sthlp` help files as `_data/<filename>.dta`. When running examples locally after `net install`, load them from the `_data/` directory of your local clone, or use the raw GitHub URL in `.sthlp` clickable examples.
