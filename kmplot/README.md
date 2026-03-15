# kmplot v1.1.0

Publication-ready Kaplan-Meier and cumulative incidence plots for Stata.

## Installation

```stata
net install kmplot, from("path/to/kmplot") replace
```

## Quick Start

```stata
sysuse cancer, clear
stset studytime, failure(died)

* Basic KM curve by group
kmplot, by(drug)

* Full publication plot
kmplot, by(drug) ci risktable median medianannotate pvalue censor
```

## Features

- **Confidence intervals**: Shaded bands or dashed lines with log-log, log, or plain transforms
- **Number-at-risk table**: Aligned below the plot with matching group colors
- **Median survival lines**: Horizontal + vertical reference lines at median
- **Censoring marks**: Tick marks at censoring times with optional thinning
- **Log-rank p-value**: Displayed on the plot with configurable position
- **Cumulative incidence**: `failure` option inverts KM to show 1-S(t)
- **Colorblind-safe**: Default `plotplainblind` scheme with 8-color palette
- **Export**: Direct PDF/PNG/EPS/SVG export

## Syntax

```
kmplot [if] [in] , [by(varname) failure
    ci cistyle(band|line) ciopacity(#) citransform(loglog|log|plain)
    median medianannotate
    risktable timepoints(numlist)
    censor censorthin(#)
    pvalue pvaluepos(topright|topleft|bottomright|bottomleft)
    colors(colorlist) lwidth(string) lpattern(patternlist)
    title(string) subtitle(string) xtitle(string) ytitle(string)
    xlabel(string) ylabel(string) legend(string) note(string)
    scheme(string) name(string) aspectratio(string)
    export(string)]
```

## Stored Results

| Result | Description |
|--------|-------------|
| `r(N)` | Number of observations |
| `r(n_groups)` | Number of groups |
| `r(p)` | Log-rank p-value (if `pvalue`) |
| `r(median_1)` | Median for group 1 (if `median`) |
| `r(cmd)` | `kmplot` |
| `r(scheme)` | Graph scheme used |

## Requirements

- Stata 16+
- Data must be `stset`

## Author

Timothy P Copeland
Department of Clinical Neuroscience, Karolinska Institutet
