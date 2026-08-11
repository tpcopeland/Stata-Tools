# fvgen — Flatten factor-variable interactions into labeled variables

**Version 1.2.4** | 2026-08-11

`fvgen` turns Stata factor-variable specifications into ordinary, labeled main-effect and interaction variables for regression tables and other exports. It returns a ready-to-use `r(allvars)` varlist while preserving the estimable design of the native model.

## Quick Start

Flatten a categorical-by-continuous interaction and estimate the same model with readable labels:

```stata
sysuse auto, clear
fvgen i.foreign##c.mpg
regress price `r(allvars)'
```

`r(allvars)` contains the pass-through `mpg` variable plus generated indicator and interaction variables. Use that varlist with any downstream table or export command, then run `fvgen, drop` when you are finished.

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

The command supports main effects and up to two-way interactions. It returns a combined `r(allvars)` varlist in estimation order, along with separate main-effect, interaction, and newly generated-variable lists. Generated variables carry `fvgen_role` and `fvgen_term` characteristics so `fvgen, drop` can remove only variables created by `fvgen`. Dataset-level provenance includes a signature of the relevant source and generated values so the margins bridge can reject stale data.

The `if` or `in` qualifier controls which levels and interaction cells are discovered, while generated variables are filled for all observations. To reproduce the native model for a restricted sample, use the same `if` or `in` qualifier (and weights, when relevant) in the estimation command. Source-variable missing values remain missing in the generated indicators and products. Weights are accepted only to calculate the centering mean for `center`.

In the default uncentered workflow, estimating on `r(allvars)` spans the same model space and reproduces the corresponding native factor-variable model's fit. When the design is full rank, matching terms also have the same coefficients and standard errors. With empty cells or other exact collinearity, Stata may choose a different omitted-column basis, so individual reported coefficients and standard errors need not map one-to-one even though fitted values and fit agree. Centering changes the interpretation of lower-order coefficients but leaves the interaction coefficient and model fit unchanged.

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

`fvvarlist` uses Stata's `i.`, `c.`, `#`, and `##` operators. The supported weights are `aweight`, `fweight`, `pweight`, and `iweight`; they affect only the centering mean.

### Margins bridge

```stata
fvgen, margins [store(name) replace]
```

Use this after estimating with the exact varlist returned in `r(allvars)`. Without `store()`, the native factor-variable refit becomes active. With `store(name)`, the refit is stored and the flattened estimate is restored. If source or generated variables changed after `fvgen`, the bridge exits with error 498; rerun `fvgen` and the flattened estimator first.

### Teardown mode

```stata
fvgen, drop
```

This mode takes no varlist, qualifiers, weights, or other generation options. It drops every variable tagged as generated by `fvgen` and leaves pass-through originals untouched.

## Key Options

| Option | Default | Use and limits |
|--------|---------|---------------|
| `alllevels` | Off | Materialize the base level in categorical main effects; interaction terms still use estimable cells. |
| `center` | Off | Center continuous terms over the `if`/`in` sample before forming products; a weight affects only that mean. The margins bridge is unavailable after centering. |
| `ref(spec)` | Stata factor-variable base | Set bases with variable/level pairs such as `ref(sex 2, race 3)`; quoted tokens resolve as value-label strings even when numeric, ambiguous duplicate labels are rejected, and levels must be observed in the marked sample. |
| `simple(varname)` | Off | Report each interacting continuous term as a slope within levels of `varname`; `varname` must be a factor and categorical-by-categorical simple effects are not supported. |
| `vsref(string)` | Off | Append the base label to categorical main-effect labels; the template must contain `@`, and the displayed base honors `ref()`. |
| `prefix(name)` | `_` | Prefix generated names; a name longer than Stata's 32-character limit is an error. |
| `replace` | Off | Overwrite unrelated existing variables whose names collide with generated names; structural output/output and output/source collisions are always rejected. With `margins store(name)`, refresh an existing stored clone. |
| `xsymbol(string)` | `×` | Set the symbol joining interaction labels; `xsymbol(x)` uses ASCII, while a continuous self-interaction is always labeled with `²`. |
| `margins` | Off | Rebuild the active estimate with native factor-variable syntax for Stata's `margins` command. |
| `store(name)` | Not used | Use only with `margins` to store the native refit under `name` and restore the flattened estimate. |
| `drop` | Off | Use alone to remove all `fvgen`-generated variables and return their names and count. |

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
- A no-base factor such as `ibn.foreign` materializes every observed level, equivalent to `alllevels` for that factor. Empty cells and omitted interaction terms are not materialized.
- With empty cells or other exact collinearity, native and flattened regressions can choose different omitted columns. Their fitted values and fit agree, but individual coefficient values and standard errors need not map one-to-one; use the native factor-variable model for factor-aware contrasts.
- Generated variable names must fit Stata's 32-character limit, and generated variable labels are truncated at Stata's 80-character limit.
- The `margins` bridge requires active estimation results with `e(b)`, `e(V)`, and a saved command line, plus current `fvgen` provenance from the exact `r(allvars)` varlist. Changing, dropping, or recasting a relevant source or generated variable invalidates the bridge; adding an unrelated variable does not. The estimator must be rerunnable with native factor variables and support `margins`. Use the native model directly for `contrast` and `pwcompare`; the bridge is not available after `center`.

## References

- Stata factor-variable syntax: `help fvvarlist`
- Estimation and postestimation: `help regress` and `help margins`
- Variable and value labels: `help label`

## QA

QA suites and how to run them are documented in [`qa/README.md`](qa/README.md).

## Version History

- **1.2.4** (2026-08-11): Added atomic generated-name preflight, exact and ambiguity-safe `ref()` label resolution, and stale-data guards for margins refits.
- **1.2.3** (2026-08-05): Clarified full-rank versus rank-deficient equivalence and repaired quoted clickable help examples.
- **1.2.2** (2026-08-05): Corrected `vsref()` abbreviation, `replace` collision, and margins-clone stored-result documentation.
- **1.2.1** (2026-07-27): Documentation hygiene aligned shipped documentation with the released package and kept contributor material out of user-facing files.
- **1.2.0** (2026-06-30): Added `fvgen, margins` for margins-ready native factor-variable estimator clones after flattened models, plus `store(name)` to preserve the active flattened estimate for table export.
- **1.1.0** (2026-06-27): Added `vsref(string)` to append the reference level to categorical main-effect labels via an `@` placeholder.
- **1.0.0** (2026-06-21): Initial release.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT License
