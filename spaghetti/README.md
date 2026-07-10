# spaghetti - Longitudinal trajectory plots with mean overlays

**Version 1.0.0** | 2026-07-10

`spaghetti` draws individual-level trajectory plots for long-format repeated-measures data and can layer group means and confidence bands on top. It is built for panels that are too dense for one-line-per-person graph code, so it uses broken-line grouping internally to stay practical on large datasets.

## Requirements

- Stata 16 or later
- Long-format data with one row per person-time observation
- A numeric outcome variable and a numeric time variable

## Installation

```stata
capture ado uninstall spaghetti
net install spaghetti, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/spaghetti") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `spaghetti` | Draw longitudinal trajectory plots with optional mean overlays |

## How It Works

- `spaghetti outcome, id() time()` draws all individual trajectories in one command.
- Add `by()` when you want separate groups, or `colorby()` when you want colors driven by another variable.
- Add `mean(bold ci)` when you want an overlaid summary trend with optional confidence bands.
- Use `sample()` to thin very dense panels without changing the mean overlay, which is still computed on the full sample.
- Use `highlight()`, `individual()`, `refline()`, and `export()` to control emphasis and presentation.

## Worked Examples

All examples below use `webuse nlswork`, so they are runnable immediately after installation.

### 1. Basic trajectories

```stata
webuse nlswork, clear
spaghetti ln_wage, id(idcode) time(year)
```

### 2. By-group trajectories with a mean overlay

This is the default presentation many users want: thin background lines for individuals and a bold summary line for each group.

```stata
webuse nlswork, clear
spaghetti ln_wage, id(idcode) time(year) by(race) mean(bold ci)
```

### 3. Sample a dense panel without changing the mean trend

`sample()` reduces the number of displayed trajectories, but the mean overlay is still computed before sampling.

```stata
webuse nlswork, clear
spaghetti ln_wage, id(idcode) time(year) sample(100) seed(12345) mean(bold)
```

### 4. Highlight specific individuals

Use `highlight()` when a few trajectories deserve emphasis and the rest should fade into the background.

```stata
webuse nlswork, clear
spaghetti ln_wage, id(idcode) time(year) ///
    highlight(idcode == 1 | idcode == 2 bgopacity(10))
```

### 5. Add a vertical reference line

```stata
webuse nlswork, clear
spaghetti ln_wage, id(idcode) time(year) ///
    sample(50) ///
    refline(80, label("Policy change") style(dash))
```

## Notes

- `by()` supports up to 8 levels.
- `colorby()` cannot be combined with `by()` or `highlight()`.
- `mean(smooth(lowess))` and `mean(smooth(linear))` smooth the mean overlay, not the individual trajectories.
- Standard graph options such as `title()`, `subtitle()`, `note()`, `ytitle()`, `xtitle()`, `plotregion()`, `graphregion()`, `name()`, and `saving()` pass through to the underlying `twoway` call.

## Version History

- **1.0.0** (2026-04-08): Initial Stata-Tools release

## Author

Timothy P Copeland, Karolinska Institutet
