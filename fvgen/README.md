# fvgen

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

**Version 1.1.0** | 2026-06-27

Flatten factor-variable interactions into labeled main-effect and product variables for friendlier regression export.

## Description

When you estimate a model with native factor-variable notation — `regress y i.sex##c.age` — table and export commands (`collect`, `esttab`, and the [tabtools](https://github.com/tpcopeland/Stata-Tools) family) emit extra factor-variable *header* rows for every interaction. The exported table ends up cluttered with parent rows you have to clean by hand.

`fvgen` removes that friction. It expands the interaction specification into ordinary variables:

- an **indicator** variable for each categorical level (the base level is dropped, just like `i.`),
- a **product** variable for each interaction term, and
- it turns **value labels into variable labels** — level `2 "Female"` becomes a variable labeled `Female`, and its interaction with `age` becomes `Female × Age`.

Running the same model on the flattened variables gives **one clean, self-labeled row per coefficient**. The reparameterization is exact: the flattened regression reproduces the native model's coefficients, standard errors, and R-squared to within numerical precision.

## Installation

```stata
net install fvgen, from("https://raw.githubusercontent.com/tpcopeland/Stata-Dev/main/fvgen")
```

## Syntax

```stata
fvgen fvvarlist [if] [in] [weight] [, alllevels center ref(spec) simple(varname) vsref(string) prefix(name) replace xsymbol(string)]
fvgen, drop
```

`fvvarlist` is a factor-variable varlist using the usual `i.`, `c.`, `#`, and `##` operators (for example `i.group##c.age` or `i.arm##i.sex`). Up to two-way interactions are supported. `aweight`s, `fweight`s, `pweight`s, and `iweight`s are allowed and used only by `center`.

`fvgen, drop` removes every variable a previous run generated (recognized by their provenance characteristics), completing the create-use-drop loop.

The generated variables and a ready-to-use combined varlist are returned in `r()`:

```stata
fvgen i.sex##c.age
regress wage `r(allvars)'
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| **alllevels** | off | Materialize an indicator for every categorical level, including the base level. Applies to main effects; interaction terms always use the estimable cells. |
| **center** | off | Mean-center continuous terms (over the `if`/`in` sample) before they enter main effects and products. Keeps lower-order coefficients interpretable at the mean. When a `weight` is supplied the centering mean is weighted (`pweight` is treated as `aweight` for the mean). |
| **ref(spec)** | lowest level | Set the reference (base) level per factor as variable/level pairs (commas optional), e.g. `ref(sex 2, race 3)`. A level may be an integer code or a value-label string in quotes, so `ref(foreign "Domestic")` works. Those levels are dropped and everything else is referenced to them. Equivalent to `ibN.` operators; does not alter `fvset` settings. |
| **simple(varname)** | off | Report per-group slopes: each continuous term interacting with `varname` becomes one standalone slope *within* each level of `varname` (main + interaction combined), instead of a reference slope plus a difference. `varname` must be a factor interacting with a continuous term. |
| **vsref(string)** | off | Append the reference (base) level to each categorical **main-effect** label. The argument is a template in which `@` is replaced by the base level's label: `vsref("(vs. @)")` gives `Foreign (vs. Domestic)`, `vsref("versus @")` gives `Foreign versus Domestic`. The template must contain `@`. Interaction and continuous-slope labels are unchanged; the reference shown honors `ref()`. |
| **prefix(name)** | `_` | Prefix for generated variable names. Names exceeding Stata's 32-character limit raise an error. |
| **replace** | off | Overwrite previously generated variables of the same name. |
| **xsymbol(string)** | `×` | Symbol joining the two sides of an interaction label. Use `xsymbol(x)` for plain ASCII (`Female x Age`). A continuous self-interaction (`c.age##c.age`) is always labeled `Age²`. |
| **drop** | off | Used alone (`fvgen, drop`): drop every fvgen-generated variable in the dataset, leaving pass-through originals untouched. Returns `r(k_dropped)` and `r(dropped)`. |

## Examples

### Example 1: Categorical-by-continuous interaction

```stata
sysuse auto, clear
fvgen i.foreign##c.mpg
regress price `r(allvars)'
```

Creates `_foreign_1` (labeled *Foreign*) and `_foreignXmpg_1` (labeled *Foreign × Mileage (mpg)*); `mpg` passes through unchanged.

### Example 2: Categorical-by-categorical interaction

```stata
sysuse auto, clear
label define rl 1 "Poor" 2 "Fair" 3 "Avg" 4 "Good" 5 "Best"
label values rep78 rl
fvgen i.foreign##i.rep78
regress price `r(allvars)'
```

Empty cells (level combinations with no observations) are skipped automatically, exactly as the native model omits them.

### Example 3: Continuous-by-continuous interaction, centered

```stata
sysuse auto, clear
fvgen c.mpg##c.weight, center
regress price `r(allvars)'
```

Creates `_mpg_c`, `_weight_c`, and `_mpgXweight`.

### Example 4: Keep all levels, ASCII interaction symbol

```stata
sysuse auto, clear
fvgen i.foreign##i.rep78, alllevels xsymbol(x)
```

### Example 5: Choose a different reference level per factor

```stata
sysuse auto, clear
fvgen i.foreign##i.rep78, ref(rep78 3)
regress price `r(allvars)'
```

Makes `rep78==3` the base for `rep78` (instead of the default lowest level), so the indicators and interactions are expressed relative to it. Equivalent to writing `ib3.rep78`, but set via an option without rewriting the specification.

### Example 6: Per-group slopes (simple effects)

```stata
sysuse auto, clear
fvgen i.foreign##c.mpg, simple(foreign)
regress price `r(allvars)'
```

Instead of a reference slope (`mpg`) plus a difference (`1.foreign#c.mpg`), this produces one standalone slope per group — `_foreignXmpg_0` labeled *Mileage (mpg) (Domestic)* and `_foreignXmpg_1` *Mileage (mpg) (Foreign)* — so the regression reports each group's mpg slope directly. The `foreign` indicators remain as group intercepts. Equivalent to the nested `i.foreign i.foreign#c.mpg` parameterization.

### Example 7: Show the reference level in main-effect labels

```stata
sysuse auto, clear
label define rl 1 "Poor" 2 "Fair" 3 "Avg" 4 "Good" 5 "Best"
label values rep78 rl
fvgen i.foreign##i.rep78, vsref("(vs. @)")
regress price `r(allvars)'
```

The main-effect indicators now carry their reference: `_foreign_1` is labeled *Foreign (vs. Domestic)* and `_rep78_2` *Fair (vs. Poor)*, so an exported coefficient table states what each level is contrasted against. The template is free-form — `vsref("versus @")` yields *Foreign versus Domestic* — and `@` is replaced by the base label, which honors `ref()` (with `ref(rep78 3)`, `_rep78_1` becomes *Poor (vs. Avg)*). Interaction labels (`Foreign × Avg`) are left unchanged.

## Demo

This is the whole point of the package. Each pair below is the **same regression** — identical coefficients, standard errors, and R² — exported as a coefficient table. Native factor-variable notation makes export tools (`collect`, `esttab`, the [tabtools](https://github.com/tpcopeland/Stata-Tools) family) print cryptic coefficient names (`1.foreign#c.mpg`) and base/omitted *reference* rows; `fvgen` yields one clean, self-labeled row per coefficient. Regenerate with `stata-mp -b do fvgen/demo/demo_fvgen.do` ([demo/export_comparison.md](demo/export_comparison.md)).

### `i.foreign##c.mpg`

**Before** — `regress price i.foreign##c.mpg`

| Term | Coef. | 95% CI | p |
|---|---:|:---:|---:|
| 0b.foreign | _(base)_ |  |  |
| 1.foreign | -14 | (-5268, 5241) | 0.996 |
| mpg | -329 | (-479, -180) | 0.000 |
| 0b.foreign#co.mpg | _(base)_ |  |  |
| 1.foreign#c.mpg | 79 | (-145, 303) | 0.485 |
| Intercept | 12601 | (9553, 15648) | 0.000 |

**After** — `fvgen i.foreign##c.mpg`, then regress on the returned `r(allvars)`

| Term | Coef. | 95% CI | p |
|---|---:|:---:|---:|
| Foreign | -14 | (-5268, 5241) | 0.996 |
| Mileage (mpg) | -329 | (-479, -180) | 0.000 |
| Foreign × Mileage (mpg) | 79 | (-145, 303) | 0.485 |
| Intercept | 12601 | (9553, 15648) | 0.000 |

A categorical-by-categorical model makes the contrast starker — 19 cluttered native rows collapse to 9 clean labeled ones (the lone omitted collinear cell, *Foreign × Best*, is still labeled and marked base, exactly as the native model drops it):

<details>
<summary><code>i.foreign##i.rep78</code> — before/after</summary>

**Before** — `regress price i.foreign##i.rep78`

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

**After** — `fvgen i.foreign##i.rep78`, then regress on the returned `r(allvars)`

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

</details>

## Naming convention

| Term | Generated variable | Variable label |
|------|--------------------|----------------|
| `i.sex` (level 2 = Female) | `_sex_2` | `Female` |
| `c.age` | *(original `age`, passed through)* | *(unchanged)* |
| `c.age` with `center` | `_age_c` | `Age (centered)` |
| `i.sex#c.age` | `_sexXage_2` | `Female × Age` |
| `i.sex#i.race` | `_sexXrace_2_3` | `Female × Asian` |
| `c.x#c.z` | `_xXz` | `X × Z` |
| `c.age#c.age` | `_ageXage` | `Age²` |

## Provenance and teardown

Every generated variable carries two characteristics so downstream tools (and you) can recognize, group, and remove them:

- `char `*var*`[fvgen_role]` — `main`, `interaction`, or `centered`
- `char `*var*`[fvgen_term]` — the factor-variable term it came from (e.g. `1.foreign#c.mpg`)

`fvgen, drop` uses `fvgen_role` to remove exactly the variables fvgen created, leaving pass-through originals (like `mpg`) untouched:

```stata
fvgen i.foreign##c.mpg
regress price `r(allvars)'
fvgen, drop          // removes _foreign_1 and _foreignXmpg_1; mpg survives
```

A no-base specification (`ibn.var`) materializes an indicator for every level (like `alllevels` for that factor). The explicit omit operator (`o.`, `#o.`) is rejected with a clear message — restrict the sample with `if`/`in` or set a base with `ref()` instead.

## Stored Results

`fvgen` stores the following in `r()`:

**Scalars:**

| Result | Description |
|--------|-------------|
| `r(k_all)` | Number of variables in `r(allvars)` |
| `r(k_main)` | Number of main-effect variables |
| `r(k_int)` | Number of interaction variables |

**Macros:**

| Result | Description |
|--------|-------------|
| `r(spec)` | The factor-variable specification expanded, reflecting any `ref()` bases |
| `r(allvars)` | All model variables, ordered, ready for an estimation command |
| `r(mainvars)` | Main-effect variables only |
| `r(intvars)` | Interaction variables only |
| `r(genvars)` | Newly created variables (excludes pass-through originals) |

With `drop`, `fvgen` instead returns `r(k_dropped)` (number of variables dropped) and `r(dropped)` (their names).

## Testing

The `qa/` directory holds the test suite, run with `stata-mp -b do run_all.do`
(lanes: `quick`, `core`, `full`):

- `test_fvgen.do` — 15 functional tests (surface, returns, naming, labels, options, missing, `if`/`in`, squared self-interaction, `ibn.` all-levels, weight-aware centering, `vsref()` reference labels, long-varname resolution)
- `test_ref.do` — 6 tests (`ref()` per-factor reference levels, equivalence to native `ibN.`, by quoted value-label string)
- `test_simple.do` — 5 tests (`simple()` per-group slopes, equivalence to native main+interaction, `simple()`+`center` combined)
- `test_provenance.do` — 7 tests (provenance characteristics + strict `fvgen, drop` teardown)
- `test_errors.do` — 11 tests (failure paths 198/110/2000, `ref()`/`simple()`/`vsref()` errors, omit operator `o.`, `varabbrev` restoration)
- `validation_fvgen.do` — 5 validations (hand-computed values + exact equivalence to native `##`)
- `test_package_release.do` — 4 tests (install smoke, autoload, documented examples)

See `qa/README.md` for the full coverage map and lane membership.

## Requirements

- Stata 16.0 or higher

## Version

- **Version 1.1.0** (27 June 2026): Add `vsref(string)` — append the reference (base) level to categorical main-effect labels via an `@`-placeholder template (e.g. `vsref("(vs. @)")` → *Foreign (vs. Domestic)*).
- **Version 1.0.0** (21 June 2026): Initial release

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT License

## See Also

- `help fvvarlist` — factor-variable operators
- `help regress` — linear regression
- `help label` — value and variable labels
