# fvgen export comparison

Each pair below is the *same regression* — identical coefficients, standard errors, and R-squared. Native factor-variable notation makes export tools print cryptic coefficient names (`1.foreign#c.mpg`) and base/omitted reference rows; fvgen yields one clean, self-labeled row per coefficient, ready to drop straight into a manuscript table.

## Example 1: `i.foreign##c.mpg`

**Before — regress price i.foreign##c.mpg**

| Term | Coef. | 95% CI | p |
|---|---:|:---:|---:|
| 0b.foreign | _(base)_ |  |  |
| 1.foreign | -14 | (-5268, 5241) | 0.996 |
| mpg | -329 | (-479, -180) | 0.000 |
| 0b.foreign#co.mpg | _(base)_ |  |  |
| 1.foreign#c.mpg | 79 | (-145, 303) | 0.485 |
| Intercept | 12601 | (9553, 15648) | 0.000 |

**After — fvgen i.foreign##c.mpg; regress price r(allvars)**

| Term | Coef. | 95% CI | p |
|---|---:|:---:|---:|
| Foreign | -14 | (-5268, 5241) | 0.996 |
| Mileage (mpg) | -329 | (-479, -180) | 0.000 |
| Foreign × Mileage (mpg) | 79 | (-145, 303) | 0.485 |
| Intercept | 12601 | (9553, 15648) | 0.000 |

## Example 2: `i.foreign##i.rep78`

**Before — regress price i.foreign##i.rep78**

| Term | Coef. | 95% CI | p |
|---|---:|:---:|---:|
| 0b.foreign | _(base)_ |  |  |
| 1.foreign | 2088 | (-2615, 6791) | 0.378 |
| 1b.rep78 | _(base)_ |  |  |
| 2.rep78 | 1403 | (-3353, 6159) | 0.557 |
| 3.rep78 | 2043 | (-2366, 6451) | 0.358 |
| 4.rep78 | 1317 | (-3386, 6020) | 0.578 |
| 5.rep78 | -360 | (-6376, 5656) | 0.905 |
| 0b.foreign#1b.rep78 | _(base)_ |  |  |
| 0b.foreign#2o.rep78 | _(base)_ |  |  |
| 0b.foreign#3o.rep78 | _(base)_ |  |  |
| 0b.foreign#4o.rep78 | _(base)_ |  |  |
| 0b.foreign#5o.rep78 | _(base)_ |  |  |
| 1o.foreign#1b.rep78 | _(base)_ |  |  |
| 1o.foreign#2o.rep78 | _(base)_ |  |  |
| 1.foreign#3.rep78 | -3867 | (-9826, 2093) | 0.199 |
| 1.foreign#4.rep78 | -1708 | (-7200, 3783) | 0.536 |
| 1o.foreign#5o.rep78 | _(base)_ |  |  |
| Intercept | 4565 | (311, 8818) | 0.036 |

**After — fvgen i.foreign##i.rep78; regress price r(allvars)**

| Term | Coef. | 95% CI | p |
|---|---:|:---:|---:|
| Foreign | 2088 | (-2615, 6791) | 0.378 |
| Fair | 1403 | (-3353, 6159) | 0.557 |
| Avg | 2043 | (-2366, 6451) | 0.358 |
| Good | 1317 | (-3386, 6020) | 0.578 |
| Best | -360 | (-6376, 5656) | 0.905 |
| Foreign × Avg | -3867 | (-9826, 2093) | 0.199 |
| Foreign × Good | -1708 | (-7200, 3783) | 0.536 |
| Foreign × Best | _(base)_ |  |  |
| Intercept | 4565 | (311, 8818) | 0.036 |

_fvgen composes with the tabtools `regtab`/`table1_tc` export family and `esttab`/`collect`: the clean labels and the `fvgen_term`/`fvgen_role` provenance characteristics carry straight through to the rendered table._
