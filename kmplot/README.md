<p align="center"><img src="../_resources/logos/kmplot_hex.svg" width="150" alt="kmplot hex logo"></p>

# kmplot — Kaplan-Meier curves with risk tables

**Version 1.0.0** | 2026-10-15

[![version](https://img.shields.io/badge/version-1.0.0-1a5f91?style=flat-square)](#version-history) [![Stata 16+](https://img.shields.io/badge/Stata-16%2B-1a5f91?style=flat-square)](#requirements) [![MIT license](https://img.shields.io/badge/license-MIT-1a5f91?style=flat-square)](../LICENSE) [![Part of Stata-Tools](https://img.shields.io/badge/part%20of-Stata--Tools-0e3a5a?style=flat-square)](../README.md)

**[Quick Start](#quick-start)** · **[Installation](#installation)** · **[Options](#options)** · **[Gallery](#gallery)** · **[Stata-Tools](../README.md)** · **[Report a bug](https://github.com/tpcopeland/Stata-Tools/issues)**

`kmplot` draws Kaplan-Meier survival or cumulative failure curves from `stset` data, with confidence bands, a number-at-risk table, medians, and a log-rank p-value in one command. It returns the risk table, landmark estimates, and plot metadata in `r()`, and can save the curve data for reuse.

## Quick Start

After [installing](#installation), draw a publication-style figure from Stata's own cancer trial data (the `label define` line names the two active drugs, which `cancer.dta` labels "Other" and "NA"):

```stata
sysuse cancer, clear
label define type 2 "Drug A" 3 "Drug B", modify
stset studytime, failure(died)
kmplot, by(drug) ci median medianannotate pvalue censor risktable riskevents timepoints(0 5 10 15 20 25 30 35)
```

<p align="center"><img src="demo/km_publication.png" width="720" alt="Survival by treatment in the cancer data: three Kaplan-Meier curves with shaded confidence bands, censor marks, dashed median lines, a log-rank p-value, and a number-at-risk table with cumulative events below the time axis"></p>

<sub>Drawn by `demo/demo_kmplot.do`, which also sets the `white_tableau` scheme and adds `title()`, `subtitle()`, and `xtitle("Time (months)")`.</sub>

## Features

- **Risk tables that line up.** The number-at-risk table shares the plot's time axis, and its counts honour delayed entry, active `stset` weights, and multiple-record data.
- **Colour-blind-safe by default.** Curves use the Okabe-Ito palette, chosen to stay distinguishable under simulated red-green colour-vision deficiency for up to five groups; `colors()` takes Stata colour names or quoted RGB triplets.
- **The numbers behind the picture.** `median`, `landmark()`, and `pvalue` add median lines, fixed-time estimates, and the log-rank p-value, and store them in `r(medians)`, `r(landmarks)`, and `r(p)`.
- **Follows `sts` conventions.** Greenwood standard errors with log-log (default), log, or plain intervals; bounds are missing where the estimate is exactly 1 or 0, as in `sts list`.
- **Reusable output.** `saving()` and `risksaving()` write the curve and risk-table datasets; `export()` writes the graph to PDF, PNG, EPS, or SVG.

## Requirements

- Stata 16 or later
- Data declared with `stset`
- No external packages

## Installation

```stata
capture ado uninstall kmplot
net install kmplot, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/kmplot") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `kmplot` | Draw Kaplan-Meier survival or cumulative failure curves with publication-oriented defaults |

## How It Works

`kmplot` reads the current `stset` definition and plots a step-function Kaplan-Meier estimate for the analysis sample; no separate model-fitting command is required.

- The default graph is survival, `S(t)`. Add `failure` to plot cumulative failure, `1 - S(t)`.
- Add `by(varname)` for one curve per group; numeric and string grouping variables are supported, and value labels are used when available (unlabelled numeric levels show as `varname=value` in the variable's display format).
- Add `ci` for confidence intervals. The default is a shaded log-log interval; `cistyle(line)` draws dashed interval lines, and `citransform(log)` or `citransform(plain)` changes the transformation.
- Add `risktable` for a number-at-risk table, `landmark()` for fixed-time estimates, `median` for median reference lines, and `censor` for censoring marks. Risk tables place the time axis above a separating rule, use larger default text, count subjects in multiple-record data, and honor active `stset` weights.
- Add `pvalue` with `by()` when at least two groups are present to display the Stata log-rank p-value; invalid p-value requests exit with return code 198.
- `saving()` and `risksaving()` write reusable curve and risk-table datasets, while `export()` writes the graph through Stata's `graph export`.
- Standard `twoway` graph options are passed through after the named `kmplot` options.

## Choosing a Workflow

| Goal | Starting point |
|------|----------------|
| One overall survival curve | `kmplot` |
| Curves by treatment or another group | `kmplot, by(group)` |
| Manuscript-style comparison | `kmplot, by(group) ci risktable median pvalue censor` |
| Cumulative failure display | Add `failure` to the stratified workflow |
| Fixed-time reporting or reproducible data export | Add `landmark()`, `saving()`, or `risksaving()` |

## Worked Examples

### 1. Basic Kaplan-Meier curve

The default is a single survival curve with step-function rendering.

```stata
sysuse cancer, clear
stset studytime, failure(died)
kmplot
```

### 2. Stratified publication-style figure

This combines confidence bands, a risk table, median reference lines, censoring marks, and a log-rank p-value for the treatment groups.

```stata
sysuse cancer, clear
stset studytime, failure(died)
kmplot, by(drug) ci risktable median medianannotate pvalue censor
```

### 3. Cumulative failure with selected risk-table times

Use `failure` for `1 - S(t)` and specify the risk-table columns explicitly with `timepoints()`.

```stata
sysuse cancer, clear
stset studytime, failure(died)
kmplot, by(drug) failure risktable timepoints(0 5 10 15 20 25 30 35)
```

### 4. Fixed-time estimates and saved datasets

`landmark()` returns estimates at the requested analysis times; the two saving options create datasets that can be reused in a table or downstream figure.

```stata
sysuse cancer, clear
stset studytime, failure(died)
kmplot, by(drug) ci risktable landmark(12 24) saving(km_curve.dta, replace) risksaving(km_risk.dta, replace)
matrix list r(landmarks)
matrix list r(risktable)
```

### 5. Custom confidence intervals, styling, and export

The graph can use line confidence intervals, a different transform, custom colors and patterns, a repositioned p-value, and a directly exported PDF.

```stata
sysuse cancer, clear
stset studytime, failure(died)
kmplot, by(drug) ci cistyle(line) citransform(log) colors(navy maroon dkorange) lpattern(solid dash dot) pvalue pvaluepos(bottomleft) export(km_figure.pdf, replace)
```

## Gallery

Run `demo/demo_kmplot.do` from a repository checkout to regenerate the PNGs below from `sysuse cancer` and, for the registry-scale panel and the landmark output, from the synthetic cohort in the repository's `_data/`. The images are repository documentation assets and are not part of the `net install` payload.

| Output | Command focus |
|--------|---------------|
| ![Single-group step-function Kaplan-Meier survival curve](demo/km_basic.png) | Basic `kmplot` workflow |
| ![Kaplan-Meier survival curves stratified by treatment group](demo/km_by_group.png) | `by()` |
| ![Stratified survival curves with shaded confidence intervals and median lines](demo/km_ci_median.png) | `ci`, `median`, and `medianannotate` |
| ![Cumulative failure curves with a number-at-risk table](demo/km_failure_risktable.png) | `failure`, `risktable`, and `timepoints()` |
| ![Risk table with cumulative events, monochrome labels, and censor marks](demo/km_risk_censor.png) | `riskevents`, `riskmono`, and `censor` |
| ![Publication-style survival plot with confidence bands, risk table, medians, and log-rank p-value](demo/km_publication.png) | Combined manuscript workflow |
| ![Custom survival plot with line confidence intervals, colors, patterns, and p-value placement](demo/km_custom_style.png) | `cistyle(line)`, `colors()`, `lpattern()`, and `pvaluepos()` |
| ![Plain Wald confidence bands with custom opacity and a p-value note](demo/km_plain_ci.png) | `citransform(plain)`, `ciopacity()`, and `note()` |
| ![Stratified survival plot with a 90 percent confidence level and custom p-value label](demo/km_pvalue_level.png) | `level(90)`, `pvaluetext()`, and `pvalueformat()` |
| ![Cumulative incidence of a first cardiovascular event in 15,000 synthetic SSRI and SNRI initiators, with a risk table and log-rank p-value](demo/km_registry_failure.png) | Registry-scale `failure` with `risktable`; p-value in its default position |

### Landmark output from the demo

`landmark()` returns the estimate at fixed analysis times in `r(landmarks)`, with bounds when `ci` is specified. Rows are indexed by group in the order of `r(group_labels)`. From the same synthetic cohort:

```stata
kmplot, by(treated) failure ci landmark(1 5 10)
matrix list r(landmarks), format(%7.4f)
```

```
Groups: SSRI | SNRI

r(landmarks)[6,5]
       group      time  estimate     lower     upper
r1    1.0000    1.0000    0.0536    0.0491    0.0585
r2    1.0000    5.0000    0.2243    0.2154    0.2335
r3    1.0000   10.0000    0.3678    0.3564    0.3795
r4    2.0000    1.0000    0.0517    0.0463    0.0576
r5    2.0000    5.0000    0.2258    0.2150    0.2370
r6    2.0000   10.0000    0.3816    0.3675    0.3961
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `by(varname)` | none | Stratify curves by a numeric or string variable |
| `failure` | survival | Plot cumulative failure, `1 - S(t)`, instead of survival |
| `ci` | off | Draw confidence intervals |
| `level(#)` | `c(level)` (95 unless changed by `set level`) | Set the confidence level for `ci`; values must lie between 10 and 99.99 with at most two decimal places |
| `cistyle(string)` | `band` | Use shaded bands or dashed `line` intervals; requires `ci` |
| `ciopacity(#)` | 12 | Set shaded-band opacity from 0 to 100; requires `ci` with band intervals |
| `citransform(string)` | `loglog` | Use `loglog`, `log`, or `plain` confidence intervals; requires `ci` |
| `median` | off | Draw median reference lines for groups whose median is reached |
| `medianannotate` | off | Add median values to the graph note; requires `median` |
| `medianformat(%fmt)` | `%9.0g` | Numeric (`%f`, `%g`, `%e`) display format for medians in the graph note and console summary; requires `median` |
| `risktable` | off | Add a separated number-at-risk table below the graph, with the time axis above it |
| `riskevents` | off | Add cumulative events as `N (events)` in the risk table; requires `risktable` |
| `riskcompact` | off | Synonym for `riskevents`; requires `risktable` |
| `riskmono` | off | Display risk-table numbers in black instead of line colors; requires `risktable` |
| `riskheight(#)` | auto | Set risk-table height; requires `risktable`; supplied values must be greater than 0 and no more than 80 |
| `timepoints(numlist)` | auto | Set risk-table timepoints; requires `risktable` or `risksaving()` |
| `landmark(numlist)` | none | Return survival or cumulative-failure estimates at fixed analysis times |
| `censor` | off | Show censoring marks on the curves |
| `censorthin(#)` | 1 | Show every Nth censor mark; requires `censor` and a value of at least 1 |
| `pvalue` | off | Display the log-rank p-value; requires `by()` |
| `pvaluepos(string)` | `bottomright` | Place the p-value at `bottomright`, `topright`, `topleft`, or `bottomleft`, anchored 5% inside the drawn y range |
| `pvalueformat(string)` | `%5.3f` | Set the numeric display format for the p-value; p-values below 0.001 are shown as `< 0.001` whatever the format |
| `pvaluetext(string)` | `Log-rank p` | Set the text printed before the p-value |
| `pvalueat(y x)` | none | Place the p-value at explicit graph coordinates; may not be combined with `pvaluepos()` |
| `colors(colorlist)` | Okabe-Ito palette | Set curve colors as Stata color names or quoted RGB triplets; the default is blue, vermilion, black, sky blue, reddish purple, orange, and bluish green, which stay distinguishable under simulated red-green color-vision deficiency for up to five groups |
| `lwidth(string)` | `medthick` | Set curve line width |
| `lpattern(patternlist)` | `solid` | Set curve line patterns |
| `title(string)` | none | Set the graph title |
| `subtitle(string)` | none | Set the graph subtitle |
| `xtitle(string)` | `Analysis time` | Set the x-axis title |
| `ytitle(string)` | mode-dependent | Set the y-axis title; the default is `Survival probability` or `Cumulative failure` |
| `xlabel(string)` | automatic | Set x-axis labels; numeric positions also set risk-table columns when `timepoints()` is omitted |
| `ylabel(string)` | `0(0.25)1` | Set y-axis labels |
| `legend(string)` | automatic | Supply a custom legend specification |
| `note(string)` | none | Add a graph note; if `medianannotate` is also requested, the user note replaces the automatic median annotation |
| `scheme(string)` | current Stata scheme | Set the graph scheme |
| `name(string)` | `kmplot` | Set the graph name |
| `aspectratio(string)` | none | Set the graph aspect ratio |
| `export(string)` | none | Export to a file; the format is inferred from `.pdf`, `.png`, `.eps`, or `.svg`, and graph-export suboptions are passed through |
| `saving(filename[, replace])` | none | Save curve data with `group`, `group_label`, `time`, `estimate`, `se`, `lower`, `upper`, `censor`, and `anchor` variables; `se`, `lower`, and `upper` are missing where the survival estimate is 1 or 0 |
| `risksaving(filename[, replace])` | none | Save risk-table data with `group`, `group_label`, `time`, `at_risk`, `events`, and cumulative censoring exits in `censored` |

`kmplot` also accepts standard `twoway` graph options through its trailing pass-through syntax.

## Stored Results

`kmplot` is an `rclass` command and stores the following results after it computes a plot. If a requested graph or dataset write fails after plotting, analytical results remain available even though the command returns an error; `r(export)` records an attempted export path, while `r(saving)` and `r(risksaving)` are stored only after successful dataset saves.

### Scalars

| Result | Meaning |
|--------|---------|
| `r(N)` | Number of observations in the analysis sample |
| `r(n_groups)` | Number of plotted groups |
| `r(level)` | Confidence level that applies to `ci` (stored even when `ci` is not requested) |
| `r(failure)` | 1 if `failure` was requested, otherwise 0 |
| `r(ci)` | 1 if `ci` was requested, otherwise 0 |
| `r(n_landmarks)` | Number of requested landmark timepoints |
| `r(n_timepoints)` | Number of risk-table timepoints, or 0 when neither `risktable` nor `risksaving()` was used |
| `r(riskheight)` | Risk-table height when `risktable` is specified |
| `r(p)` | Log-rank p-value when `pvalue` was used with `by()` and at least two groups were present |
| `r(pvalue_y)` | Y coordinate of the drawn p-value text when the log-rank p-value was computed |
| `r(pvalue_x)` | X coordinate of the drawn p-value text when the log-rank p-value was computed |
| `r(median_#)` | Median for group `#` (`r(median_1)`, `r(median_2)`, ...), stored with `median` for groups whose median is reached |

### Macros

| Result | Meaning |
|--------|---------|
| `r(cmd)` | `kmplot` |
| `r(graph_name)` | Graph name |
| `r(plot_type)` | `survival` or `failure` |
| `r(scheme)` | Graph scheme used |
| `r(by)` | Grouping-variable name when `by()` was specified |
| `r(cistyle)` | CI style used |
| `r(citransform)` | CI transformation used |
| `r(colors)` | Color list used |
| `r(lpattern)` | Line-pattern list supplied, if any |
| `r(timepoints)` | Risk-table timepoints used |
| `r(landmark_times)` | Landmark timepoints requested |
| `r(group_labels)` | Group labels joined by a vertical bar |
| `r(xtitle)` | X-axis title |
| `r(ytitle)` | Y-axis title |
| `r(export)` | Requested export path when `export()` was specified, including after a failed file write |
| `r(saving)` | Curve dataset path when `saving()` succeeded |
| `r(risksaving)` | Risk-table dataset path when `risksaving()` succeeded |
| `r(pvalue_text)` | Displayed p-value text when the log-rank p-value was computed |
| `r(pvalue_label)` | P-value label text when the log-rank p-value was computed |
| `r(pvalue_format)` | P-value numeric format when the log-rank p-value was computed |
| `r(pvalue_pos)` | P-value position keyword when the log-rank p-value was computed |
| `r(pvalue_at)` | Explicit p-value coordinates when supplied; otherwise empty when the log-rank p-value was computed |
| `r(pvalue_placement)` | Placement of the p-value text relative to its anchor (`c` with `pvalueat()`) when the log-rank p-value was computed |

### Matrices

| Result | Columns |
|--------|---------|
| `r(medians)` | Group and median for each group when `median` was requested |
| `r(landmarks)` | Group, time, estimate, lower, and upper when `landmark()` was requested; bounds are populated when `ci` is requested |
| `r(risktable)` | Group, time, at-risk, events, and censored when `risktable` or `risksaving()` was used |

## Assumptions and Limits

- Run `stset` before `kmplot`; the command uses the current survival-time definition and analysis sample.
- `failure` is the complement of the Kaplan-Meier survival estimate, `1 - S(t)`. It is not a competing-risk cumulative incidence function, and `kmplot` does not implement Aalen-Johansen or Fine-Gray estimators.
- Confidence intervals use Greenwood standard errors with the selected `level()` and `citransform()`; `loglog` is the default, with `log` and `plain` alternatives. Bounds are reported only where 0 < S(t) < 1: where the estimate is exactly 1 (before the first event, including the time-zero anchor) or exactly 0, they are missing under every transform, as in `sts list`, so shaded bands begin at the first event. Where a curve steps to 0 (1 with `failure`), the drawn band or CI lines carry the last bounds to that time, as `sts graph, ci` does; the returned and saved bounds stay missing there.
- `pvalue` uses Stata's log-rank test and requires `by()` with at least two groups in the analysis sample.
- If a group's survival curve does not reach 0.5, `median` draws no line for that group and its median entry is missing in `r(medians)`.
- Risk-table counts honor delayed entry, active `stset` weights, and subject identifiers. In multiple-record data, each subject is counted once at a timepoint; contiguous records within the same group are not marked as censoring, while departures from a group and terminal censored records are counted in `censored`.
- Landmarks beyond a group's last observed follow-up are missing unless its survival curve has reached zero.
- Probability weights support point estimates and weighted counts; `ci` and `pvalue` are refused, and saved standard errors are missing. Fractional weighted counts are printed to one decimal place in the risk table, while `r(risktable)` and `risksaving()` keep the full values.
- With importance weights, `ci` and `pvalue` are allowed, as in `sts`, and treat the weights as frequency counts.
- `saving()` and `risksaving()` support the `replace` suboption only; `export()` passes graph-export suboptions to Stata.

## References

- Kaplan EL, Meier P. “Nonparametric Estimation from Incomplete Observations.” *Journal of the American Statistical Association* 53(282), 457–481 (1958). [doi:10.1080/01621459.1958.10501452](https://doi.org/10.1080/01621459.1958.10501452)
- StataCorp. [Survival Analysis Reference Manual](https://www.stata.com/manuals/st.pdf), including `stset`, `sts generate`, `sts list`, and `sts test`.
- Machado GM, Oliveira MM, Fernandes LAF. “A Physiologically-based Model for Simulation of Color Vision Deficiency.” *IEEE Transactions on Visualization and Computer Graphics* 15(6), 1291–1298 (2009). [doi:10.1109/TVCG.2009.113](https://doi.org/10.1109/TVCG.2009.113)
- Okabe M, Ito K. “Color Universal Design (CUD): How to make figures and presentations that are friendly to Colorblind people” (2008). [jfly.uni-koeln.de/color](https://jfly.uni-koeln.de/color/)

## QA

QA suites and how to run them are documented in [`qa/README.md`](qa/README.md).

## Version History

- **1.0.0** (2026-10-15): Initial release.

## Author

Timothy P Copeland, Karolinska Institutet

Questions and bug reports: [GitHub issues](https://github.com/tpcopeland/Stata-Tools/issues). Please include the first line of `which kmplot` and your Stata version.

To cite: Copeland TP. *kmplot: Kaplan-Meier curves with risk tables*. Stata-Tools, https://github.com/tpcopeland/Stata-Tools/tree/main/kmplot. Please give the version you used (`which kmplot` prints it).

## License

MIT (see [LICENSE](../LICENSE))
