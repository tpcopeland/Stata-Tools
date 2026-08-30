# diagtab — Diagnostic accuracy and cutoff analysis

**Version 2.0.1** | 2026-08-30

`diagtab` computes diagnostic accuracy measures and confidence intervals from binary classifications or continuous scores. It produces publication-ready console, Excel, CSV, Markdown, and frame output for clinical diagnostic and screening studies.

## Quick Start

```stata
webuse lbw, clear
logit low age lwt smoke
predict double phat
diagtab phat low, cutoff(0.30) auc
```

## Requirements

- Stata 17 or later

## Installation

```stata
capture ado uninstall diagtab
net install diagtab, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/diagtab") replace
```

## Commands

| Command | Description |
| --- | --- |
| `diagtab` | Diagnostic accuracy, confidence intervals, ROC AUC, and cutoff analysis |

## How It Works

With a binary test variable, `diagtab` builds the 2 × 2 classification table directly. For a continuous score, use `cutoff()` for one threshold, `cutoffs()` for a threshold table, `auc` for ROC area, or `optimal` to select the cutoff that maximizes Youden's J.

The command reports sensitivity, specificity, PPV, NPV, accuracy, likelihood ratios, diagnostic odds ratio, and Youden's index. Wilson score intervals are the default; `exact` selects Clopper–Pearson intervals for directly estimated binomial proportions. `prevalence()` recalculates predictive values for a fixed target prevalence and uses delta-method intervals when sensitivity and specificity are both interior estimates.

## Worked Examples

### 1. Binary classification

```stata
webuse lbw, clear
logit low age lwt smoke
predict double phat
generate byte predicted = phat >= 0.30
diagtab predicted low
```

### 2. Continuous score with AUC

```stata
webuse lbw, clear
logit low age lwt smoke
predict double phat
diagtab phat low, cutoff(0.30) auc level(95)
```

### 3. Compare thresholds and export

```stata
webuse lbw, clear
logit low age lwt smoke
predict double phat
diagtab phat low, cutoffs(0.20 0.30 0.40 0.50) ///
    xlsx("diagnostic_cutoffs.xlsx") sheet("Cutoffs") ///
    title("Low birth weight prediction")
```

### 4. Target-population predictive values

```stata
webuse lbw, clear
logit low age lwt smoke
predict double phat
generate byte predicted = phat >= 0.30
diagtab predicted low, prevalence(0.07) exact
```

## Demo

Run `demo/demo_diagtab.do` from a repository checkout to regenerate `demo/demo_diagtab.xlsx` with single-cutoff, prevalence-adjusted, and multi-cutoff sheets.

## Options

| Option | Purpose |
| --- | --- |
| `cutoff(#)` | Evaluate one nonmissing threshold; values at or above it are test-positive |
| `cutoffs(numlist)` | Evaluate sorted, distinct thresholds, return exact round-trip values in `r(cutoffs)`, and use unique row identifiers in `r(cutoff_table)` |
| `prevalence(#)` | Adjust PPV and NPV to a fixed external prevalence strictly between 0 and 1 |
| `exact` | Use Clopper–Pearson intervals for directly estimated binomial proportions |
| `wilson` | Use Wilson score intervals, the default |
| `auc` | Report ROC area and its confidence interval through Stata's `roctab` |
| `optimal` | Choose the cutoff maximizing Youden's J |
| `level(#)` | Set the confidence level; default `c(level)` |
| `digits(#)` | Set displayed decimal places from 0 through 6; default 1 |
| `xlsx(filename)` | Export an `.xlsx` workbook |
| `excel(filename)` | Alias for `xlsx()`; the two aliases may not be specified together |
| `sheet(string)` | Set the Excel sheet name; default `Diagnostics` |
| `csv(filename)` | Export the rendered output dataset as CSV |
| `markdown(filename)` | Export a GitHub-Flavored Markdown table |
| `mdappend` | Append to an existing Markdown file; requires `markdown()` |
| `frame(name[, replace])` | Store output in a named Stata frame, optionally replacing it |
| `open` | Open the workbook after export; requires `xlsx()` or `excel()` |
| `title(string)` | Set the table title |
| `footnote(string)` | Add text below the table |
| `theme(string)` | Apply `lancet`, `nejm`, `bmj`, `apa`, `jama`, `plos`, `nature`, `cell`, `annals`, or `custom` formatting |
| `borderstyle(string)` | Set `default`, `thin`, `medium`, or `academic` workbook borders |
| `headercolor(string)` | Set the header fill using a Stata color name or RGB triplet |
| `headershade` | Fill workbook header rows |
| `zebracolor(string)` | Set the alternating-row fill color |
| `zebra` | Enable alternating-row shading |

## Stored Results

### Scalars

| Result | Description |
| --- | --- |
| `r(TP)`, `r(FP)`, `r(FN)`, `r(TN)` | Two-by-two cell counts in single-cutoff mode |
| `r(ci_level)` | Resolved confidence level |
| `r(sensitivity)`, `r(sensitivity_lb)`, `r(sensitivity_ub)` | Sensitivity and confidence bounds |
| `r(specificity)`, `r(specificity_lb)`, `r(specificity_ub)` | Specificity and confidence bounds |
| `r(ppv)`, `r(ppv_lb)`, `r(ppv_ub)` | Positive predictive value and confidence bounds |
| `r(npv)`, `r(npv_lb)`, `r(npv_ub)` | Negative predictive value and confidence bounds |
| `r(accuracy)`, `r(accuracy_lb)`, `r(accuracy_ub)` | Accuracy and confidence bounds |
| `r(lr_pos)`, `r(lr_pos_lb)`, `r(lr_pos_ub)` | Positive likelihood ratio and confidence bounds |
| `r(lr_neg)`, `r(lr_neg_lb)`, `r(lr_neg_ub)` | Negative likelihood ratio and confidence bounds |
| `r(dor)`, `r(dor_lb)`, `r(dor_ub)` | Diagnostic odds ratio and confidence bounds |
| `r(youden)` | Youden's J index |
| `r(auc)`, `r(auc_lb)`, `r(auc_ub)` | ROC area and confidence bounds when `auc` is requested |
| `r(optimal_cutoff)` | Youden-optimal cutoff when `optimal` is requested |
| `r(markdown_rows)`, `r(markdown_cols)` | Markdown body dimensions when exported |

### Macros and matrix

| Result | Description |
| --- | --- |
| `r(cutoffs)` | Normalized cutoff values used in multi-cutoff mode |
| `r(xlsx)`, `r(sheet)` | Workbook filename and sheet name when exported |
| `r(frame)` | Output frame name when requested |
| `r(markdown)` | Markdown filename when exported |
| `r(methods)` | Methods paragraph describing interval choices |
| `r(cutoff_table)` | Multi-cutoff matrix with sensitivity, specificity, PPV, NPV, accuracy, and bounds |

## Assumptions and Limits

- The gold-standard variable must be coded 0/1 and contain both classes for AUC analysis.
- Without a cutoff option, the test variable must be coded 0/1.
- `prevalence()` is treated as fixed without uncertainty. Adjusted PPV/NPV confidence bounds are missing when sensitivity or specificity equals 0 or 1, avoiding a degenerate point interval.
- Undefined measures caused by zero cells are displayed as `--` and retained as missing numeric results.

## References

- Clopper CJ, Pearson ES. The use of confidence or fiducial limits illustrated in the case of the binomial. *Biometrika*. 1934;26:404–413.
- DeLong ER, DeLong DM, Clarke-Pearson DL. Comparing the areas under two or more correlated receiver operating characteristic curves: a nonparametric approach. *Biometrics*. 1988;44:837–845.
- Glas AS, Lijmer JG, Prins MH, Bonsel GJ, Bossuyt PMM. The diagnostic odds ratio: a single indicator of test performance. *Journal of Clinical Epidemiology*. 2003;56:1129–1135.
- Wilson EB. Probable inference, the law of succession, and statistical inference. *Journal of the American Statistical Association*. 1927;22:209–212.
- Youden WJ. Index for rating diagnostic tests. *Cancer*. 1950;3:32–35.

## QA

QA suites and how to run them are documented in [`qa/README.md`](qa/README.md).

## Version History

- **2.0.1** (2026-08-30): Preserved all real cutoff values, made multi-cutoff identifiers lossless and unique, preflighted output conflicts, rejected conflicting Excel aliases and invalid font sizes before export, and avoided degenerate prevalence-adjusted intervals at boundary estimates.
- **2.0.0** (2026-08-19): Extracted `diagtab` into a standalone package while preserving its command and stored-result contracts.

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
