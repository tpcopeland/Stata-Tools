# raincloud - Raincloud plots for Stata

**Version 1.0.0** | 2026-04-08

`raincloud` draws raincloud plots: a half-violin density, jittered raw points, and a box-and-whisker summary in one figure. The command is meant for fast distributional comparisons where you want both a smooth shape and the underlying observations on the same graph.

It supports grouped displays through `over()`, horizontal or vertical orientation, mirror-mode split violins, analytic and frequency weights, and pass-through graph styling options.

## Requirements

- Stata 16 or later

## Installation

```stata
capture ado uninstall raincloud
net install raincloud, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/raincloud") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `raincloud` | Draw a raincloud plot with density, scatter, and box elements |

## Quick Start

The easiest place to start is Stata's built-in `auto` dataset.

```stata
sysuse auto, clear
raincloud mpg, over(foreign)
```

This draws separate rainclouds for domestic and foreign cars so you can compare the full MPG distributions, not just the means.

## How It Works

Each raincloud combines three pieces:

- The **cloud** is a half-violin kernel density.
- The **rain** is jittered raw data, so you can see the observed values directly.
- The **box** is a compact quartile-and-whisker summary.

You can turn any element off with `nocloud`, `norain`, or `nobox`/`noumbrella`. Only one numeric outcome variable is allowed at a time. If you want to compare multiple measures, reshape to long format and use `over()` for the grouping variable.

## Worked Examples

### 1. Single distribution

This is the simplest use: show one variable with all three elements.

```stata
sysuse auto, clear
raincloud mpg
```

### 2. Grouped comparison

`over()` creates one raincloud per group. Value labels are used automatically when available.

```stata
sysuse auto, clear
raincloud mpg, over(foreign)
```

Use this when the main question is whether two or more groups differ in spread, skewness, overlap, or outliers.

### 3. Vertical layout with a mean marker

For some figures, especially when the variable names belong on the x-axis, the vertical layout reads better.

```stata
sysuse auto, clear
raincloud price, over(foreign) vertical mean
```

### 4. Mirror mode and styling

`mirror` draws the density on both sides of the center line. Pass-through styling options let you tune the cloud, points, and box without leaving the command.

```stata
sysuse auto, clear
raincloud mpg, over(foreign) mirror ///
    opacity(70) jitter(0.6) ///
    cloudopts(lwidth(medium)) ///
    pointopts(msymbol(d) msize(tiny)) ///
    boxopts(lwidth(thick)) ///
    colors(navy cranberry)
```

## Common Options

| Option | Description |
|--------|-------------|
| `over(varname)` | Draw one raincloud per group |
| `horizontal` / `vertical` | Choose the plot orientation; horizontal is the default |
| `mirror` | Draw a split-violin style cloud on both sides of center |
| `nocloud` | Suppress the half-violin density |
| `norain` | Suppress the jittered raw data points |
| `nobox` / `noumbrella` | Suppress the box-and-whisker element |
| `bandwidth(#)` | Set the kernel-density bandwidth; `0` uses Stata's default selector |
| `jitter(#)` | Control point jitter from `0` to `1` |
| `opacity(#)` | Control cloud fill opacity from `0` to `100` |
| `colors(string)` | Supply a space-separated custom palette |
| `mean` | Add a mean marker |
| `seed(#)` | Make the jitter reproducible |

## Gallery

### Basic grouped comparison

![Grouped raincloud](demo/raincloud_basic.png)

### Vertical orientation

![Vertical raincloud](demo/raincloud_vertical.png)

### Mirror layout

![Mirror raincloud](demo/raincloud_mirror.png)

## Returned Results

`raincloud` stores the following in `r()`:

- `r(N)`: number of observations
- `r(n_groups)`: number of groups
- `r(varname)`: plotted variable
- `r(over)`: grouping variable, if used
- `r(stats)`: matrix with group-wise `n`, `mean`, `sd`, `median`, `q25`, `q75`, `iqr`, and bandwidth

## Reference

Allen M, Poggiali D, Whitaker K, Marshall TR, Kievit RA. 2019. Raincloud plots: a multi-platform tool for robust data visualization. *Wellcome Open Research* 4:63. https://doi.org/10.12688/wellcomeopenres.15191.1

## Version History

- **1.0.0** (2026-04-08): Current Stata-Tools release
