# mvp - Missing Value Patterns

![Stata 14+](https://img.shields.io/badge/Stata-14%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Enhanced missing value pattern analysis for Stata 14+.

Fork of `mvpatterns` by Jeroen Weesie (STB-61: dm91)

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## Installation

```stata
net install mvp, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/mvp")
```

## Syntax

```stata
mvp [varlist] [if] [in] [, options]
```

Supports `by` prefix.

## Options

| Option | Description |
|--------|-------------|
| **Display** | |
| `notable` | Suppress variable table |
| `skip` | Insert spaces every 5 vars |
| `sort` | Sort vars by missingness (descending) |
| `nodrop` | Include vars with no missing |
| `wide` | Compact display |
| `nosummary` | Suppress summary stats |
| **Filtering** | |
| `minfreq(#)` | Min pattern frequency to display (default 1) |
| `minmissing(#)` | Show patterns with ≥# missing vars |
| `maxmissing(#)` | Show patterns with ≤# missing vars |
| `ascending` | Sort patterns rarest-first |
| **Statistics** | |
| `percent` | Show percentages |
| `cumulative` | Show cumulative freq/pct |
| `correlate` | Tetrachoric correlations of missingness |
| `monotone` | Test for monotone pattern |
| **Output** | |
| `generate(stub)` | Create missingness indicators: `stub_varname`, `stub_pattern`, `stub_nmiss` |
| `save(name)` | Save patterns to file (.dta) or frame (Stata 16+) |
| **Graphics** | |
| `graph(bar)` | Bar chart of % missing by variable |
| `graph(patterns)` | Bar chart of top 20 pattern frequencies |
| `graph(matrix)` | Obs × var heatmap |
| `graph(matrix, sample(#))` | Sample # obs for large data |
| `graph(matrix, sort)` | Sort obs by pattern |
| `graph(correlation)` | Missingness correlation heatmap |
| `scheme(name)` | Graph scheme (requires `graph()`) |
| **Stratification** | |
| `gby(varname)` | Stratify graphs by categorical variable (faceted) |
| `over(varname)` | Overlay groups in same graph (grouped bars) |
| `stacked` | Stacked bar chart (requires `graph(bar)`) |
| `groupgap(#)` | Gap between bar groups in `over()` |
| `legendopts(string)` | Customize legend in grouped charts |

## Pattern Display

- `+` = nonmissing
- `.` = missing

Patterns sorted by frequency (most common first) by default.

## Stored Results

**Scalars:**
- `r(N)` - observations
- `r(N_complete)` - complete cases
- `r(N_incomplete)` - incomplete cases
- `r(N_patterns)` - unique patterns
- `r(N_vars)` - variables analyzed
- `r(max_miss)` - max missing per obs
- `r(mean_miss)` - mean missing per obs
- `r(N_mv_total)` - total missing values
- `r(N_monotone)`, `r(pct_monotone)` - if `monotone` specified

**Macros:**
- `r(varlist)` - analyzed variables
- `r(varlist_nomiss)` - variables with no missing
- `r(monotone_status)` - "monotone" or "non-monotone"
- `r(gby)`, `r(gby_levels)` - if `gby()` specified
- `r(over)`, `r(over_levels)` - if `over()` specified

**Matrices:**
- `r(corr_miss)` - correlation matrix (if `correlate` or `graph(correlation)`)

## Examples

```stata
* Basic
sysuse auto, clear
mvp

* With options
mvp price mpg rep78, percent sort

* Filter patterns
mvp, minfreq(5) minmissing(1) maxmissing(3)

* Test monotonicity
mvp var1 var2 var3, monotone

* Generate indicators
mvp, generate(m)
tab m_pattern

* Graphics
mvp, graph(bar)
mvp, graph(matrix, sample(1000) sort)
mvp, graph(correlation) scheme(s1mono)

* Stratified graphics
mvp price mpg rep78, graph(bar) gby(foreign)     // faceted by group
mvp price mpg rep78, graph(bar) over(foreign)    // grouped bars
mvp, graph(bar) stacked                          // stacked bars
mvp, graph(patterns) gby(treatment) top(10)      // patterns by group

* Save patterns
mvp, save(patterns)  // frame in Stata 16+, .dta in 14-15
```

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

Fork of mvpatterns by Jeroen Weesie (STB-61: dm91)

## License

MIT License

## Version

Version 1.1.1, 2025-12-16
