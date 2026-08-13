### Table 1. Baseline Characteristics

| No. (Column %) or Mean±SD | SSRI (N=8,934) | SNRI (N=6,066) | p-value |
| --- | --- | --- | --- |
| Age at cohort entry (years) | 58.3±13.4 | 58.5±13.3 | 0.24 |
| Female sex | 5,351 (60) | 3,621 (60) | 0.80 |
| Diabetes | 4,107 (46) | 2,818 (46) | 0.56 |
| Hypertension | 4,112 (46) | 2,935 (48) | 0.005 |

### Table 2. Treatment by Sex

| Treatment group | Male | Female | Total |
| --- | --- | --- | --- |
| SSRI | 3,583 (59.4%) | 5,351 (59.6%) | 8,934 |
| SNRI | 2,445 (40.6%) | 3,621 (40.4%) | 6,066 |
| Total | 6,028 | 8,972 | 15,000 |
| Pearson's chi-squared test: chi2 = 0.06, p = 0.805 |  |  |  |
| OR = 1.0 (95% CI: 0.9, 1.1) |  |  |  |

### Table 3. Correlation Matrix

|  | Age at cohort entry (years) | C-reactive protein (mg/L) | Prior hospitalizations |
| --- | --- | --- | --- |
| Age at cohort entry (years) | 1.00 |  |  |
| C-reactive protein (mg/L) | -0.01 | 1.00 |  |
| Prior hospitalizations | 0.00 | 0.01 | 1.00 |

*\* p<0.05, \*\* p<0.01, \*\*\* p<0.001*

### Table 4. First Six Analysis Records

| Person identifier | Age at cohort entry (years) | Treatment group | Female sex | Cardiovascular event |
| --- | --- | --- | --- | --- |
| 1 | 73.75 | SSRI | Male | Yes |
| 2 | 61.80 | SSRI | Female | No |
| 3 | 46.22 | SSRI | Female | No |
| 4 | 51.62 | SNRI | Female | Yes |
| 5 | 54.89 | SSRI | Female | Yes |
| 6 | 75.15 | SSRI | Male | No |

### Simulation results by scenario and estimand

| Scenario | Estimator | Marginal slope: Mean | Marginal slope: Bias | Marginal slope: Coverage | Marginal slope: N | Treatment contrast: Mean | Treatment contrast: Bias | Treatment contrast: Coverage | Treatment contrast: N |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A | Unweighted | 0.142 | +0.042 | 86%\* | 372 | 0.540 | +0.040 | 85%\* | 372 |
|  | IIW | 0.093 | -0.007 | 95% | 400 | 0.493 | -0.007 | 95% | 400 |
|  | IIW + log(test) | 0.109 | +0.009 | 96% | 400 | 0.512 | +0.012 | 94% | 400 |
| B | Unweighted | 0.151 | +0.051 | 75%\* | 379 | 0.553 | +0.053 | 80%\* | 376 |
|  | IIW | 0.102 | +0.002 | 96% | 400 | 0.499 | -0.001 | 97%\* | 400 |
|  | IIW + log(test) | 0.120 | +0.020 | 94% | 400 | 0.520 | +0.020 | 92%\* | 400 |
| C | Unweighted | 0.157 | +0.057 | 74%\* | 379 | 0.557 | +0.057 | 72%\* | 376 |
|  | IIW | 0.110 | +0.010 | 96% | 400 | 0.508 | +0.008 | 96% | 400 |
|  | IIW + log(test) | 0.128 | +0.028 | 92%\* | 400 | 0.528 | +0.028 | 89%\* | 400 |

*\* coverage differs from the nominal 95% by more than 2 Monte Carlo SEs*
