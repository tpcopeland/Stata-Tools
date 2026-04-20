# tc_schemes - Consolidated Stata graph schemes from blindschemes and schemepack

**Version 1.0.0** | 2026-04-08

`tc_schemes` bundles high-quality Stata graph schemes from Daniel Bischof's `blindschemes`, Mead Over's compatibility fixes, and Asjad Naqvi's `schemepack` into one installable package. The practical advantage is that you get both the scheme files and a real Stata command, so `which tc_schemes` succeeds and do-files can check one package instead of juggling multiple upstream installs.

## Requirements

- Stata 16 or later

## Installation

```stata
capture ado uninstall tc_schemes
net install tc_schemes, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tc_schemes") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `tc_schemes` | Browse the installed scheme catalog, filter by source package, and display either a compact list or detailed descriptions |

## Quick Start

The command is mainly a catalog and installation anchor. Once the package is installed, you either set a scheme for the whole session or apply one scheme to a single graph.

```stata
tc_schemes
set scheme plotplain

sysuse auto, clear
scatter mpg weight
```

## How It Works

- Run `tc_schemes` with no options to see the organized catalog of available schemes.
- Use `source(blindschemes)` or `source(schemepack)` when you want to narrow the list to one upstream family.
- Use `list` for a compact machine-readable list or `detail` for human-readable descriptions.
- After browsing, either run `set scheme <name>` to change the session default or use `scheme(<name>)` on a single graph.

## Included Scheme Families

| Family | Count | Examples | Best for |
|--------|-------|----------|----------|
| `blindschemes` | 4 schemes | `plotplain`, `plotplainblind`, `plottig`, `plottigblind` | Clean publication figures and colorblind-safe defaults |
| `white_*`, `black_*`, `gg_*` series | 27 schemes | `white_tableau`, `black_cividis`, `gg_viridis` | Choosing a palette and a background style together |
| Standalone schemepack schemes | 8 schemes | `tab1`, `cblind1`, `ukraine`, `neon` | Distinctive one-off visual styles |
| Custom color styles | 21 styles | `vermillion`, `sky`, `turquoise`, `sea` | Accessible colors used by the bundled scheme families |

The package includes 39 graph schemes in total: 4 from `blindschemes` and 35 from `schemepack`.

## Worked Examples

### 1. Browse the catalog and filter by source

Use the catalog first when you want to see what is available before you commit to a scheme.

```stata
tc_schemes
tc_schemes, detail
tc_schemes, source(blindschemes) list
```

### 2. Set a global scheme for the current Stata session

After `set scheme`, subsequent graphs inherit that scheme until you change it again.

```stata
set scheme plotplain
sysuse auto, clear
scatter mpg weight, ///
    title("Fuel Economy by Vehicle Weight") ///
    xtitle("Weight") ytitle("Miles per gallon")
```

### 3. Apply a scheme to one graph without changing the session default

This is the safer workflow when you want to compare different looks side by side.

```stata
sysuse auto, clear
scatter mpg weight, scheme(white_tableau) ///
    title("Single-graph scheme override")
```

### 4. Compare two schemes visually

Because the schemes are installed locally, you can render the same graph under two visual systems and combine them in one figure.

```stata
sysuse auto, clear
scatter mpg weight, scheme(plotplain) name(g1, replace)
scatter mpg weight, scheme(gg_viridis) name(g2, replace)
graph combine g1 g2
```

### 5. Use `which tc_schemes` as an installation check in project headers

This is one of the main reasons the wrapper command exists.

```stata
capture which tc_schemes
if _rc != 0 {
    net install tc_schemes, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tc_schemes") replace
}
```

## Preview Gallery

Representative outputs from `demo/demo_tc_schemes.do`:

### Blindschemes

![plotplain](demo/scheme_plotplain.png)

![plotplainblind](demo/scheme_plotplainblind.png)

![plottig](demo/scheme_plottig.png)

![plottigblind](demo/scheme_plottigblind.png)

### Selected schemepack variants

![white_tableau](demo/scheme_white_tableau.png)

![white_viridis](demo/scheme_white_viridis.png)

![black_cividis](demo/scheme_black_cividis.png)

![gg_hue](demo/scheme_gg_hue.png)

### Standalone schemes

![neon](demo/scheme_neon.png)

![swift_red](demo/scheme_swift_red.png)

## Acknowledgments

- Daniel Bischof created the original `blindschemes` package and its publication-oriented, accessibility-aware visual style.
- Mead Over supplied `blindschemes_fix`, which resolved compatibility issues with recent Stata versions.
- Asjad Naqvi created `schemepack`, which contributes the larger palette-and-background scheme families collected here.

Wrapper code is distributed under MIT. Individual schemes retain their original licensing and attribution.

## Version History

- **1.0.0** (2026-04-08): Initial Stata-Tools release consolidating `blindschemes`, `blindschemes_fix`, and `schemepack` under one installable package and catalog command.

## Author

Timothy P Copeland, Karolinska Institutet
