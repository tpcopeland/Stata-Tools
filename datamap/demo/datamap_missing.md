## 1. _demo_missing

- Source: `datamap/demo/_demo_missing.dta`
- Label: Biomarker Study with Missing Data Patterns
- Observations: 80
- Variables: 6
- Data signature: `80:6(26080):323884870:1380290782`
- Disclosure: 1 excluded (`id`); cells below 5 suppressed; date-safe off; likely identifiers not excluded: none

### Variables

| Variable | Label | Type | Missing | Values/Statistics |
|---|---|---|---|---|
| `id` | Subject ID | double | 0 (0.0%) | excluded (structure only) |
| `x1` | Biomarker A | double | 20 (25.0%) | N=60; mean=-0.097; SD=1.13; median=-0.035; IQR=-0.659 to 0.361; range=-3.15 to 3.33 |
| `x2` | Biomarker B | double | 20 (25.0%) | N=60; mean=0.048; SD=1.19; median=0.134; IQR=-0.790 to 0.858; range=-2.79 to 2.81 |
| `x3` | Biomarker C | double | 28 (35.0%) | N=52; mean=0.010; SD=1.02; median=0.022; IQR=-0.712 to 0.816; range=-2.16 to 2.37 |
| `x4` | Biomarker D | double | 10 (12.5%) | N=70; mean=-0.011; SD=1.03; median=0.003; IQR=-0.679 to 0.433; range=-2.00 to 4.66 |
| `outcome` | Binary outcome | double | 0 (0.0%) | 0 No: 50 (62.5%)<br>1 Yes: 30 (37.5%) |

### Flags

No quality flags.

### Candidates (not applied)

No placeholder candidates.

### Missingness

- Variables more than 50% missing: 0
- Variables more than 10% missing: 4
- Complete rows: 38 (47.5%)
- Missing-value patterns (+ observed, . missing) over `x1`, `x2`, `x3`, `x4`: 8 distinct
  - `++++`: 38 (47.5%)
  - `+.++`: 14 (17.5%)
  - `.+.+`: suppressed (complementary)
  - `++.+`: suppressed (complementary)
  - `.+..`: suppressed (complementary)
  - `....`: suppressed (<5)
  - `...+`: suppressed (<5)
  - `+..+`: suppressed (<5)

