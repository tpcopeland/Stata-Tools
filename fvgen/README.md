<img src="../_resources/logos/fvgen_hex.svg" align="right" width="150" alt="fvgen hex logo">

# fvgen — Labeled variables from factor-variable interactions

**Version 1.2.10** | 2026-10-12

[![version](https://img.shields.io/badge/version-1.2.10-1a5f91?style=flat-square)](#version-history) [![Stata 16+](https://img.shields.io/badge/Stata-16%2B-1a5f91?style=flat-square)](#requirements) [![MIT license](https://img.shields.io/badge/license-MIT-1a5f91?style=flat-square)](../LICENSE) [![Part of Stata-Tools](https://img.shields.io/badge/part%20of-Stata--Tools-0e3a5a?style=flat-square)](../README.md)

**[Quick Start](#quick-start)** · **[Installation](#installation)** · **[Worked Examples](#worked-examples)** · **[Key Options](#key-options)** · **[Stata-Tools](../README.md)** · **[Report a bug](https://github.com/tpcopeland/Stata-Tools/issues)**

`fvgen` turns Stata factor-variable specifications into ordinary, labeled main-effect and interaction variables for regression tables and other exports. It returns a ready-to-use `r(allvars)` varlist while preserving the estimable design of the native model.

## Quick Start

After [installing](#installation), flatten a categorical-by-continuous interaction and fit the same model on the labeled variables:

```stata
sysuse auto, clear
regress price i.foreign##c.mpg
fvgen i.foreign##c.mpg
regress price `r(allvars)'
```

The same coefficients, exported from each fit's `r(table)`:

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

<sub>From `demo/export_comparison.md`, written by `demo/demo_fvgen.do`, whose small table helper renders each row from `r(table)` using the variable label (after) or the coefficient name (before). Run `fvgen, drop` when you are finished.</sub>

## Features

- **Labels from your data.** Value labels become variable labels, interaction labels join their parts with `×` (or `xsymbol()`), and `vsref()` can name the reference level in each main-effect label.
- **The same model, flattened.** In the default uncentered workflow, a fit on `r(allvars)` reproduces the native factor-variable model's fit; full-rank designs also reproduce each coefficient and standard error.
- **Nothing overwritten by accident.** Before changing the dataset, `fvgen` rejects plans in which two terms map to one generated name or an output would overwrite a source variable.
- **Clean teardown.** Generated variables carry provenance characteristics, so `fvgen, drop` removes only what `fvgen` created and leaves pass-through originals, `clonevar` copies and renamed variables alone.
- **Back to `margins`.** `fvgen, margins` rebuilds the fit with native factor variables for `margins`, and refuses (r(498)) when the data or the model no longer match.

## Requirements

- Stata 16.0 or later
- No additional Stata packages or external software

## Installation

```stata
capture ado uninstall fvgen
net install fvgen, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/fvgen") replace
```

For a local Stata-Tools checkout, use the same command with `from("/path/to/Stata-Tools/fvgen")`.

## Commands

| Command | Description |
|---------|-------------|
| `fvgen` | Flatten factor-variable terms, remove generated variables, or rebuild a margins-ready estimate |

## How It Works

`fvgen` expands `i.` factors into indicator variables, passes continuous terms through as ordinary variables, and turns `#` or `##` interactions into products. The default base level is omitted for categorical main effects; value labels become variable labels, and generated names use a prefix plus the source variable and level. Before changing the dataset, it rejects output plans in which distinct terms collapse to one generated name or an output would overwrite a source variable.

The command supports main effects and up to two-way interactions. It returns a combined `r(allvars)` varlist in estimation order, along with separate main-effect, interaction, and newly generated-variable lists. Generated variables carry `fvgen_role`, `fvgen_term`, and `fvgen_name` characteristics so `fvgen, drop` can remove only variables created by `fvgen` that still have the name `fvgen` gave them; a `clonevar` copy or a renamed generated variable is kept. Dataset-level provenance conservatively signs every variable present when `fvgen` runs, plus its generated variables, so the margins bridge can reject stale data.

The `if` or `in` qualifier and any weight control which levels and interaction cells are discovered, while generated variables are filled for all observations. To reproduce the native model for a restricted sample, use the same qualifiers and weights in the estimation command. Source-variable missing values remain missing in the generated indicators and products. With `center`, the weight also determines the centering mean.

In the default uncentered workflow, estimating on `r(allvars)` spans the same model space and reproduces the corresponding native factor-variable model's fit. When the design is full rank, matching terms also have the same coefficients and standard errors. With empty cells or other exact collinearity, Stata may choose a different omitted-column basis, so individual reported coefficients and standard errors need not map one-to-one even though fitted values and fit agree. Centering changes the interpretation of lower-order coefficients but leaves the interaction coefficient and model fit unchanged.

Official `xi` also creates indicator and product variables (`xi i.foreign*mpg` makes `_Iforeign_1` and `_IforXmpg_1`, labeled `foreign==1` and `(foreign==1)*mpg`). `fvgen` adds labels built from value labels, modern factor-variable syntax (`ibN.`, `ibn.`, `c.`, `##`), per-factor reference levels and per-group slopes, provenance with a matching teardown, and a bridge back to native factor variables for `margins`.

## Worked Examples

### 1. Categorical-by-continuous interaction

The standard workflow creates a labeled indicator and product, then passes the returned varlist to the estimator.

```stata
sysuse auto, clear
fvgen i.foreign##c.mpg
regress price `r(allvars)'
fvgen, drop
```

### 2. Reference level and comparison labels

`ref()` changes the base used for a factor, while `vsref()` makes that comparison visible in main-effect labels.

```stata
sysuse auto, clear
fvgen i.foreign##i.rep78, ref(rep78 3) vsref("(vs. @)")
regress price `r(allvars)'
```

### 3. Centered continuous interaction

`center` creates centered copies before forming the product; `xsymbol(x)` requests an ASCII interaction label.

```stata
sysuse auto, clear
fvgen c.mpg##c.weight, center xsymbol(x)
regress price `r(allvars)'
```

### 4. Per-group slopes

With `simple(foreign)`, the continuous slope is reported separately within each level of the categorical moderator instead of as a reference slope plus a difference.

```stata
sysuse auto, clear
fvgen i.foreign##c.mpg, simple(foreign)
regress price `r(allvars)'
```

### 5. Margins after a flattened regression

`store()` preserves the active flattened estimate for export and saves a native factor-variable clone for `margins`.

```stata
sysuse auto, clear
fvgen i.foreign##c.mpg
regress price `r(allvars)'
fvgen, margins store(m_price)
estimates restore m_price
margins, dydx(mpg) at(foreign=(0 1))
```

## Demo

The checkout demo compares native and flattened coefficient tables for `i.foreign##c.mpg` and `i.foreign##i.rep78`. From a Stata-Tools checkout root, run:

```bash
stata-mp -b do fvgen/demo/demo_fvgen.do
```

The script installs the local package and regenerates [`demo/export_comparison.md`](demo/export_comparison.md); it is a checkout workflow, not part of the `net install` payload. The categorical-by-categorical example contains empty cells, so Stata may select a different omitted-column basis across equivalent fits; treat its individual coefficients as presentation examples, not a one-to-one parity check.

## Command Reference

### Main generation mode

```stata
fvgen fvvarlist [if] [in] [weight] [, alllevels center prefix(name) ref(spec) simple(varname) vsref(string) replace xsymbol(string)]
```

`fvvarlist` uses Stata's `i.`, `c.`, `#`, and `##` operators. The supported weights are `aweight`, `fweight`, `pweight`, and `iweight`; they define the sample used to discover levels and cells and, with `center`, determine the centering mean.

### Margins bridge

```stata
fvgen, margins [store(name) replace]
```

Use this after estimating with the exact varlist returned in `r(allvars)`. Without `store()`, the native factor-variable refit becomes active. With `store(name)`, the refit is stored and the flattened estimate is restored. If any variable present when `fvgen` ran, or any generated variable, changed afterward, the bridge exits with error 498; rerun `fvgen` and the flattened estimator first. A variable added later does not invalidate the bridge. A replay error or nonconvergence also restores the original active estimate.

### Teardown mode

```stata
fvgen, drop
```

This mode takes no varlist, qualifiers, weights, or other generation options. It drops every variable tagged as generated by `fvgen` that still carries its generated name; `clonevar` copies and renamed generated variables are kept, and pass-through originals are untouched.

## Key Options

| Option | Default | Use and limits |
|--------|---------|---------------|
| `alllevels` | Off | Materialize the base level in categorical main effects; interaction terms still use estimable cells. |
| `center` | Off | Center continuous terms over the marked sample before forming products; a weight defines that sample and determines the mean. The margins bridge is unavailable after centering. |
| `ref(spec)` | Stata factor-variable base | Set bases with variable/level pairs such as `ref(sex 2, race 3)`; quoted tokens resolve as value-label strings even when numeric, ambiguous duplicate labels are rejected, and levels must be observed in the marked sample. |
| `simple(varname)` | Off | Report each interacting continuous term as a slope within levels of `varname`; `varname` must be a factor and categorical-by-categorical simple effects are not supported. |
| `vsref(string)` | Off | Append the base label to categorical main-effect labels; the template must contain `@`, and the displayed base honors `ref()`. |
| `prefix(name)` | `_` | Prefix generated names; a name longer than Stata's 32-character limit is an error. |
| `replace` | Off | Overwrite unrelated existing variables whose names collide with generated names; structural output/output and output/source collisions are always rejected. With `margins store(name)`, refresh an existing stored clone; without `replace`, an existing stored estimate of that name is an error (r(110)). |
| `xsymbol(string)` | `×` | Set the symbol joining interaction labels; `xsymbol(x)` uses ASCII; a continuous self-interaction is labeled with `²`, or `^2` when `xsymbol()` is plain ASCII. |
| `margins` | Off | Rebuild the active estimate with native factor-variable syntax for Stata's `margins` command. |
| `store(name)` | Not used | Use only with `margins` to store the native refit under `name` and restore the flattened estimate. |
| `drop` | Off | Use alone to remove all `fvgen`-generated variables still under their generated names and return their names and count; `clonevar` copies and renamed generated variables are kept. |

## Stored Results

For ordinary generation, `fvgen` returns these scalars:

| Result | Description |
|--------|-------------|
| `r(k_all)` | Number of variables in `r(allvars)` |
| `r(k_main)` | Number of main-effect variables |
| `r(k_int)` | Number of interaction variables |

For ordinary generation, it also returns these macros:

| Result | Description |
|--------|-------------|
| `r(spec)` | Effective expanded factor-variable specification, including `ref()` bases and any `simple()` reparameterization |
| `r(allvars)` | All model variables in estimation order |
| `r(mainvars)` | Main-effect variables only |
| `r(intvars)` | Interaction variables only |
| `r(genvars)` | Newly created variables, excluding pass-through originals |

With `fvgen, drop`, the returned results are `r(k_dropped)` (a scalar count) and `r(dropped)` (the dropped variable names). With `fvgen, margins`, `r(margins)` is `active` or `stored`, and `r(stored)` contains the estimate name when `store()` was used.

The native-factor result produced by `fvgen, margins` also carries these nonstandard `e()` macros (including in an estimate saved with `store(name)`):

| Result | Description |
|--------|-------------|
| `e(fvgen_margins)` | Marks the result as the margins-ready native-factor clone (`1`) |
| `e(fvgen_flat_cmdline)` | Original estimation command using the flattened variables |
| `e(fvgen_native_cmdline)` | Reconstructed estimation command using native factor-variable syntax |

## Assumptions and Limits

- Higher-order interactions with three or more factors are rejected; use a native factor-variable model or split the workflow.
- The explicit omit operator `o.` is rejected because `fvgen` cannot infer whether it should be materialized; restrict the sample with `if` or `in`, or set a base with `ref()` instead.
- A no-base factor such as `ibn.foreign` materializes every observed level, equivalent to `alllevels` for that factor. Empty cells and omitted interaction terms are not materialized. Naming an `ibn.` factor in `ref()` is an error (r(198)).
- Generated variable names must fit Stata's 32-character limit, and generated variable labels are truncated at Stata's 80-character limit.
- The `margins` bridge requires active estimation results with `e(b)`, `e(V)`, and a saved command line, plus current `fvgen` provenance from the exact `r(allvars)` varlist. Changing, dropping, or recasting any variable present when `fvgen` ran, or any generated variable, invalidates the bridge; adding a variable afterward does not. The estimator must be rerunnable and converge with native factor variables and support `margins`, and the native refit must be the same model as the flattened fit (same estimation sample, N, rank, free coefficients, log likelihood where posted, and variance matrix); a mismatch, e.g. after running `fvgen` on a different `if`/`in` sample than the estimator or with `alllevels` plus `noconstant`, exits with r(498). Bootstrap and jackknife variances (`bootstrap:` prefix or `vce(bootstrap)`) are replayed from the fit's posted `e(rngstate)` so the native refit redraws the same replicates, then checked against the flattened variance; the caller's random-number state is left unchanged. A resampling variance is refused (r(498)) when the generator type was changed after the fit (`set rng`) or when exact collinearity, such as `alllevels` with a constant, gives the native refit a different omitted-column basis; fit such models natively. Because the bridge reruns the saved command line, a command line with `saving()` or any other `sav*()` option (including `bootstrap, saving()`, `jackknife, saving()`, and `vce(bootstrap, saving())`) is refused with r(198) so the replay never rewrites that file, and `mi estimate` results are refused with r(198); refit without `saving()` or fit natively; a user-written estimator that writes files without a `sav*()` option is not detected. A failed replay shows the estimator's own error message. Use the native model directly for `contrast` and `pwcompare`; the bridge is not available after `center`.

## References

- Stata factor-variable syntax: `help fvvarlist`
- Estimation and postestimation: `help regress` and `help margins`
- Variable and value labels: `help label`

## QA

QA suites and how to run them are documented in [`qa/README.md`](qa/README.md).

## Version History

- **1.2.10** (2026-10-12): `fvgen, margins` refuses (r(198)) a command line carrying a `saving()`-type option instead of replaying it, which silently rewrote the user's bootstrap or jackknife replicate file; it also refuses `mi estimate` results by name. A failed native replay now shows the estimator's own error message. The README teardown description now states that `clonevar` copies and renamed generated variables are kept.
- **1.2.9** (2026-10-12): `fvgen, margins` no longer swaps in a different bootstrap variance: a resampling fit is replayed from its posted `e(rngstate)`, the model check now also compares the variance matrix (r(498) on mismatch), and the caller's random-number state is restored afterward. `fvgen, drop` no longer deletes `clonevar` copies of generated variables (generated variables are stamped with their own name in `fvgen_name`). `ref()` naming an `ibn.` factor is now an error instead of silently imposing a base. `xsymbol()` containing a double quote works. The console listing shows labels literally and falls back to the variable name for an unlabeled pass-through variable. A squared continuous term is labeled `^2` when `xsymbol()` is plain ASCII. The help file positions `fvgen` against `xi` and links `xi`, `margins`, and `fvset`.
- **1.2.8** (2026-10-12): A rejected `fvgen` call no longer erases the previous run's provenance, so `fvgen, margins` still works for the earlier model. `fvgen, margins` replays the estimator under the caller's `varabbrev` setting. Generated-name length is counted in characters, not bytes, so Unicode names up to 32 characters are accepted. `ref()` naming one variable twice now reports the duplicate. Under `center` and `replace`, a weight that reads a centered copy `fvgen` would regenerate is refused instead of being dropped mid-run. Internal simplification: one parse and one name check per term.

<details><summary>Earlier versions</summary>

- **1.2.7** (2026-09-30): Preserve literal quotes, backticks, dollar signs and Unicode when building labels for centered copies, factor indicators and interactions, including reference suffixes. The documented 80-character label limit and suffix rules are unchanged.
- **1.2.6** (2026-09-29): The margins bridge now refuses (r(498)) a native refit that is not the same model as the flattened fit (different estimation sample, N, rank, free coefficients, or log likelihood), which previously substituted a different model silently after `fvgen ... if` or `alllevels` with `noconstant`; `margins store(name)` no longer silently overwrites an existing stored estimate without `replace`; a level missing from an attached value label is labeled `var=level` instead of a bare number; string variables and `i(numlist)` factors with `ref()`/`simple()` get accurate errors.
- **1.2.5** (2026-08-30): Strengthened margins provenance to include outcomes and other pre-existing data, restored active estimates after replay failures, rejected nonconverged native replays, and corrected weight documentation.
- **1.2.4** (2026-08-11): Added atomic generated-name preflight, exact and ambiguity-safe `ref()` label resolution, and stale-data guards for margins refits.
- **1.2.3** (2026-08-05): Clarified full-rank versus rank-deficient equivalence and repaired quoted clickable help examples.
- **1.2.2** (2026-08-05): Corrected `vsref()` abbreviation, `replace` collision, and margins-clone stored-result documentation.
- **1.2.1** (2026-07-27): Documentation hygiene aligned shipped documentation with the released package and kept contributor material out of user-facing files.
- **1.2.0** (2026-06-30): Added `fvgen, margins` for margins-ready native factor-variable estimator clones after flattened models, plus `store(name)` to preserve the active flattened estimate for table export.
- **1.1.0** (2026-06-27): Added `vsref(string)` to append the reference level to categorical main-effect labels via an `@` placeholder.
- **1.0.0** (2026-06-21): Initial release.

</details>

## Author

Timothy P Copeland, Karolinska Institutet

Questions and bug reports: [GitHub issues](https://github.com/tpcopeland/Stata-Tools/issues). Please include the first line of `which fvgen` and your Stata version.

To cite: Copeland TP. *fvgen: Labeled variables from factor-variable interactions*. Stata-Tools, https://github.com/tpcopeland/Stata-Tools/tree/main/fvgen. Please give the version you used (`which fvgen` prints it).

## License

MIT (see [LICENSE](../LICENSE))
