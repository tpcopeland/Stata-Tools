## 1. test_cohort_miss

- Source: <normalized>
- Label: Test cohort dataset
- Observations: 100
- Variables: 8
- Dataset notes:
  - This is a synthetic test dataset
- Data signature: `100:8(64926):2117236361:54269459`
- Disclosure: 2 excluded (`id`, `name`); cells below 5 suppressed; date-safe on; likely identifiers not excluded: none

### Variables

| Variable | Label | Type | Missing | Values/Statistics |
|---|---|---|---|---|
| `id` | Unique identifier | double | 0 (0.0%) | excluded (structure only) |
| `age` | Age in years | double | 10 (10.0%) | N=90; mean=49.31; SD=18.87; median=46.00; IQR=31.00-68.00; range=20.00-79.00 |
| `sex` | Sex of participant | byte | 0 (0.0%) | 0 Female: 46 (46.0%)<br>1 Male: 54 (54.0%) |
| `bmi` | Body mass index | double | 11 (11.0%) | N=89; mean=25.55; SD=4.39; median=25.81; IQR=21.22-29.54; range=18.61-32.95 |
| `region` | Geographic region | byte | 6 (6.0%) | 1 North: 21 (21.0%)<br>2 South: 30 (30.0%)<br>3 East: 23 (23.0%)<br>4 West: 20 (20.0%) |
| `entry_date` | Study entry date | double %td daily | 0 (0.0%) | N=100; span 357 days (exact dates withheld) |
| `exit_date` | Study exit date | double %td daily | 0 (0.0%) | N=100; span 625 days (exact dates withheld) |
| `name` | Participant name | str20 | 0 (0.0%) | excluded (structure only) |

### Flags

No quality flags.

### Candidates (not applied)

No placeholder candidates.

### Structure (inferred)

- Name patterns: IDs `id`; dates `entry_date`, `exit_date`; demographics `age`, `sex`

### Missingness

- Variables more than 50% missing: 0
- Variables more than 10% missing: 1
- Complete rows: suppressed (complementary)
- Missing-value patterns (+ observed, . missing) over `age`, `bmi`, `region`: 5 distinct
  - `+++`: suppressed (complementary)
  - `++.`: 6 (6.0%)
  - `..+`: suppressed (complementary)
  - `+.+`: suppressed (complementary)
  - `.++`: suppressed (<5)

### Sample rows

First 3 rows (excluded variables masked; dates suppressed):

| id | age | sex | bmi | region | entry_date | exit_date | name |
|---|---|---|---|---|---|---|---|
| [MASKED] | . | 1 | 18.8655699775 | 2 | [DATE SUPPRESSED] | [DATE SUPPRESSED] | [MASKED] |
| [MASKED] | . | 1 | 23.855056112 | 2 | [DATE SUPPRESSED] | [DATE SUPPRESSED] | [MASKED] |
| [MASKED] | . | 0 | 25.8052298575 | 3 | [DATE SUPPRESSED] | [DATE SUPPRESSED] | [MASKED] |

