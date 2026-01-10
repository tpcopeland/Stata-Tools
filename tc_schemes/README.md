# tc_schemes

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

Consolidated Stata graph schemes from blindschemes and schemepack.

## Overview

This package solves a common annoyance: `capture which schemepack` fails because schemepack contains only `.scheme` files without a `.ado` file, triggering unnecessary reinstallation checks in do-files.

With `tc_schemes`, you get:
- A proper `.ado` file so `which tc_schemes` works correctly
- 4 blindschemes (plotplain, plotplainblind, plottig, plottigblind)
- 35 schemepack schemes with modern color palettes
- 21 custom color style files for colorblind accessibility
- Complete documentation of all schemes

## Installation

```stata
net install tc_schemes, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tc_schemes")
```

## Usage

List all available schemes:
```stata
tc_schemes
```

Show detailed descriptions:
```stata
tc_schemes, detail
```

Filter by source:
```stata
tc_schemes, source(blindschemes)
tc_schemes, source(schemepack) list
```

Use a scheme:
```stata
set scheme plotplain
* or
scatter y x, scheme(white_tableau)
```

Check if installed (in do-file headers):
```stata
capture which tc_schemes
if _rc != 0 {
    net install tc_schemes, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tc_schemes")
}
```

## Included Schemes

### Blindschemes (Daniel Bischof)

Clean, publication-ready schemes with colorblind-friendly palettes:

| Scheme | Description |
|--------|-------------|
| `plotplain` | Minimalist white background, no gridlines |
| `plotplainblind` | plotplain with colorblind-safe colors |
| `plottig` | ggplot2-style gray background |
| `plottigblind` | plottig with colorblind-safe colors |

### Schemepack (Asjad Naqvi)

**Series Schemes** - Each palette available with three backgrounds:
- `white_*` - White background (clean, traditional)
- `black_*` - Black background (dramatic, presentations)
- `gg_*` - Gray background (ggplot2-style)

| Palette | Description |
|---------|-------------|
| `tableau` | Tableau Software default colors |
| `cividis` | Perceptually uniform, colorblind-optimized |
| `viridis` | Matplotlib perceptually uniform colormap |
| `hue` | ggplot2 default hue colors |
| `brbg` | Brown-Blue-Green diverging |
| `piyg` | Pink-Yellow-Green diverging |
| `ptol` | Paul Tol's colorblind-safe palette |
| `jet` | Classic rainbow (use cautiously) |
| `w3d` | Web 3D inspired vibrant colors |

**Standalone Schemes:**

| Scheme | Description |
|--------|-------------|
| `tab1`, `tab2`, `tab3` | Qualitative color schemes |
| `cblind1` | Colorblind-friendly option |
| `ukraine` | Ukraine flag colors |
| `swift_red` | Taylor Swift Red album colors |
| `neon` | High-contrast neon styling |
| `rainbow` | Vibrant multicolor |

## Stored Results

```stata
tc_schemes
return list
```

| Result | Description |
|--------|-------------|
| `r(schemes)` | Space-separated list of all scheme names |
| `r(n_schemes)` | Number of schemes |
| `r(sources)` | Source packages included |
| `r(version)` | Package version |

## Acknowledgments

This package consolidates work from three generous contributors:

- **Daniel Bischof** (University of Zurich) - Original [blindschemes](https://ideas.repec.org/c/boc/bocode/s458251.html)
- **Mead Over** (Center for Global Development) - blindschemes_fix compatibility patches
- **Asjad Naqvi** (Vienna University of Economics) - [schemepack](https://github.com/asjadnaqvi/stata-schemepack)

All original attributions preserved. Wrapper code under MIT license; individual schemes retain original licensing.

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License (wrapper code)

## Version

Version 1.0.0, 2025-01-11
