<img src="../_resources/logos/simtab_hex.svg" align="right" width="150" alt="simtab hex logo">

# simtab — Monte Carlo simulation performance tables

**Version 2.0.4** | 2026-10-13

[![version](https://img.shields.io/badge/version-2.0.4-1a5f91?style=flat-square)](#version-history) [![Stata 17+](https://img.shields.io/badge/Stata-17%2B-1a5f91?style=flat-square)](#requirements) [![MIT license](https://img.shields.io/badge/license-MIT-1a5f91?style=flat-square)](../LICENSE) [![Part of Stata-Tools](https://img.shields.io/badge/part%20of-Stata--Tools-0e3a5a?style=flat-square)](../README.md)

**[Quick Start](#quick-start)** · **[Installation](#installation)** · **[Key Options](#key-options)** · **[Worked Examples](#worked-examples)** · **[Stata-Tools](../README.md)** · **[Report a bug](https://github.com/tpcopeland/Stata-Tools/issues)**

`simtab` computes and renders publication-ready performance tables from replication-level simulation results or pre-computed summaries. It exports styled Excel, CSV, Markdown, rendered-frame, and numeric-frame outputs.

## Quick Start

After [installing](#installation), summarize a small two-method simulation (20 replications each) and keep the numeric results in a frame:

```stata
clear
set obs 40
generate long sim = ceil(_n / 2)
bysort sim: generate byte method = _n
generate double true_value = 0
generate double estimate = cond(method == 1, 0, .05) + (sim - 10.5) / 100
generate double se = .10

simtab method, estimate(estimate) se(se) true(true_value) sim(sim) ///
    metrics(mean bias empse meanse coverage n) ///
    plotframe(sim_plot, replace) display
```

## Features

- **Performance measures with their Monte Carlo SEs.** Compute mode reports bias, empirical SE, root-mean-square model SE, relative SE error, MSE/RMSE, coverage, power, and nonconvergence, with closed-form Monte Carlo SEs.
- **Off-nominal coverage is flagged.** A cell whose coverage differs from the nominal level by more than twice its Monte Carlo SE is marked with an asterisk and named in a note, and `warnreps()` warns when a cell has too few replications for precise results.
- **Compute or ingest.** `from(simsum)`, `from(siman)`, and `from(summary)` render an existing summary in the same layout without recomputing its measures.
- **A table and the numbers behind it.** `frame()` keeps the rendered table, and `plotframe()` keeps one numeric row per cell with the raw measures and Monte Carlo SEs, as the source for figures.

## Requirements

- Stata 17 or later

## Installation

```stata
capture ado uninstall simtab
net install simtab, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/simtab") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `simtab` | Compute or ingest Monte Carlo performance measures and render publication tables |

## How It Works

In compute mode, one observation represents one replication × estimator × estimand × scenario. `simtab` computes bias, empirical SE, root-mean-square model SE, relative SE error, MSE/RMSE, coverage, power, nonconvergence, and closed-form Monte Carlo SEs.

In ingest mode, `from(simsum)`, `from(siman)`, and `from(summary)` map an existing summary to the same internal cell layout without recomputing its measures. Coverage and power are stored internally as proportions.

## Worked Examples

### 1. Styled Excel export

Continuing from the Quick Start fixture:

```stata
simtab method, estimate(estimate) se(se) true(true_value) sim(sim) ///
    metrics(mean bias empse meanse coverage n) ///
    xlsx("simulation.xlsx") sheet("Performance") theme(nejm)
```

### 2. Render a generic summary

```stata
clear
input str8 method double(mean bias empse meanse coverage n)
"Method A" 0.01  0.01 0.10 0.11 0.94 500
"Method B" 0.03  0.03 0.12 0.13 0.91 500
end

simtab, from(summary) estimatorvar(method) ///
    measures(mean=mean bias=bias empse=empse meanse=meanse ///
        coverage=coverage n=n) display
```

### 3. Portable table outputs

Continuing from the Quick Start fixture:

```stata
simtab method, estimate(estimate) se(se) true(true_value) ///
    csv("simulation.csv") markdown("simulation.md")
```

## Demo

Run [`demo/demo_simtab.do`](demo/demo_simtab.do) from a repository checkout to regenerate the tracked [`demo/demo_simtab.xlsx`](demo/demo_simtab.xlsx) workbook. Its one sheet, `Performance`, summarizes two methods across two scenarios and two estimands with 100 replications each, using a supplied `coverage()` indicator, `nsim(100)` for nonconvergence, and `theme(nejm)`. The workbook is a repository documentation asset and is not part of the `net install` payload.

## Key Options

| Option | Contract |
|--------|----------|
| `estimate(varname)` | Replication-level point estimate; required in compute mode |
| `se(varname)` | Replication-level model-based standard error; required in compute mode |
| `true(#\|varname)` | True value, supplied as a literal or variable; required in compute mode |
| `by(varname)` | Scenario or data-generating-process groups |
| `estimand(varname)` | Target-parameter column groups |
| `sim(varname)` | Replication identifier used for duplicate detection |
| `metrics(tokens)` | Measures to display |
| `coverage(varname)` | Pre-computed 0/1 coverage indicator |
| `lci(varname)` | Lower confidence limit used to derive coverage |
| `uci(varname)` | Upper confidence limit used to derive coverage |
| `pvalue(varname)` | Replication-level p-value; rejection is `pvalue <= alpha` |
| `reject(varname)` | Pre-computed 0/1 rejection indicator |
| `nsim(#)` | Intended replications per cell; enables nonconvergence measures |
| `level(#)` | Wald coverage level; default `95` |
| `alpha(#)` | Rejection cutoff; default `0.05` |
| `minreps(#)` | Minimum usable replications per cell; default `2` |
| `warnreps(#)` | Low-precision warning threshold; default `100` |
| `order(data\|sort)` | Level ordering; default first occurrence in `data` order |
| `digits(#)` | Estimate-scale decimal places; default `2` |
| `pctdigits(#)` | Percentage decimal places; default `0` |
| `sedigits(#)` | SE-scale decimal places; default follows `digits()` |
| `nosign` | Suppress the leading plus sign on signed metrics |
| `xlsx(file)` | Excel workbook output |
| `excel(file)` | Synonym for `xlsx()` |
| `sheet(name)` | Excel worksheet name; default `Simulation` |
| `title(string)` | Table title |
| `footnote(string)` | Table footnote |
| `frame(name[, replace])` | Rendered string-table frame |
| `plotframe(name[, replace])` | Numeric cell-level companion frame |
| `csv(file)` | CSV output |
| `markdown(file)` | Markdown output |
| `mdappend` | Append rather than replace a Markdown file |
| `theme(name)` | Journal-formatting theme |
| `borderstyle(name)` | `default`, `thin`, `medium`, or `academic` borders |
| `headercolor(c)` | Header fill color |
| `zebracolor(c)` | Zebra-stripe fill color |
| `headershade` | Enable header shading |
| `zebra` | Enable alternate-row shading |
| `display` | Show the table in the Results window |
| `open` | Open the exported Excel workbook |
| `from(spec)` | Ingest `simsum`, `siman`, or `summary` data |
| `byvar(name)` | Scenario column for `from(summary)` |
| `estimatorvar(name)` | Method column for `from(summary)` |
| `estimandvar(name)` | Target column for `from(summary)` |
| `measures(map)` | Explicit measure-to-column mapping for `from(summary)` |

## Stored Results

| Result | Meaning |
|--------|---------|
| `r(N_cells)` | Number of by × estimator × estimand cells |
| `r(N_input)` | Replications passing `if`/`in` and non-SE requirements |
| `r(n_dropped_se)` | Replications excluded for missing `se()` |
| `r(n_by)` | Number of scenario groups |
| `r(n_estimators)` | Number of estimator levels |
| `r(n_estimands)` | Number of estimand levels |
| `r(n_reps_min)` | Minimum usable cell replications in compute mode |
| `r(n_reps_max)` | Maximum usable cell replications in compute mode |
| `r(n_fail_max)` | Maximum nonconvergence count when `nsim()` is set |
| `r(level)` | Coverage level |
| `r(alpha)` | Rejection cutoff |
| `r(markdown_rows)` | Markdown row count when exported |
| `r(markdown_cols)` | Markdown column count when exported |
| `r(mode)` | `compute` or `ingest` |
| `r(source)` | `compute`, `simsum`, `siman`, or `summary` |
| `r(metrics)` | Displayed metric tokens |
| `r(methods)` | Plain-language method summary |
| `r(frame)` | Rendered table frame when created |
| `r(plotframe)` | Numeric companion frame when created |
| `r(xlsx)` | Excel workbook path when exported |
| `r(sheet)` | Excel worksheet name when exported |
| `r(csv)` | CSV path when exported |
| `r(markdown)` | Markdown path when exported |

## Assumptions and Limits

- Compute mode uses one SE-complete analysis sample per cell; a missing `se()` excludes that replication from every metric.
- The true value must be invariant within each scenario × estimand cell.
- `from(summary)` requires coverage and power mappings to be proportions in `[0,1]`.
- Ratio estimands should be supplied on the scale on which bias and coverage are meaningful, such as log hazard ratios.

## References

- Morris TP, White IR, Crowther MJ. Using simulation studies to evaluate statistical methods. *Statistics in Medicine*. 2019;38(11):2074–2102. [doi:10.1002/sim.8086](https://doi.org/10.1002/sim.8086)
- White IR. simsum: Analyses of simulation studies including Monte Carlo error. *Stata Journal*. 2010;10(3):369–385.

## QA

QA suites and how to run them are documented in [`qa/README.md`](qa/README.md).

## Version History

- **2.0.4** (2026-10-13): A metric value that rounds to zero prints without a sign: a bias of -0.003 at two decimals showed `-0.00` (and a tiny positive bias `+0.00`); both now show `0.00`, in the console, frames and every export. Values that survive rounding keep their sign. The first call in a session no longer echoes Mata source to the console, and a helper that does not compile now stops with an explicit message and its return code.
- **2.0.3** (2026-10-09): Help References now give a DOI for every entry.
- **2.0.2** (2026-09-30): Retain double precision for computed means and empirical standard errors when input estimates use byte, int, or float storage; preserve original caller values, types and order. Restore the caller's Mata strict setting after helper compilation, including failed compilation. Preserve prior caller `r()` on refusals before analytical results are prepared; late output failures retain analytical publication.
- **2.0.1** (2026-08-30): Corrected RMS model-SE and inclusive alpha-boundary calculations, protected caller Mata state during Excel export, rejected ambiguous or out-of-range ingest data, and expanded documentation contracts.

<details>
<summary>Earlier versions</summary>

- **2.0.0** (2026-08-19): Extracted `simtab` into a standalone package while preserving its compute, ingest, export, and stored-result contracts.

</details>

## Author

Timothy P Copeland, Karolinska Institutet

Questions and bug reports: [GitHub issues](https://github.com/tpcopeland/Stata-Tools/issues). Please include the first line of `which simtab` and your Stata version.

To cite: Copeland TP. *simtab: Monte Carlo simulation performance tables*. Stata-Tools, https://github.com/tpcopeland/Stata-Tools/tree/main/simtab. Please give the version you used (`which simtab` prints it).

## License

MIT (see [LICENSE](../LICENSE))
