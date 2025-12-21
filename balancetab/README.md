# balancetab

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

Propensity score balance diagnostics with standardized mean differences, Love plots, and Excel export.

## Description

`balancetab` calculates and displays covariate balance diagnostics for propensity score analysis. It computes standardized mean differences (SMD) before and after matching or weighting, generates Love plots for visualization, and exports balance tables to Excel.

Key features:
- Standardized mean differences before/after matching or weighting
- Love plot visualization for balance assessment
- Excel export of balance tables
- Configurable imbalance thresholds
- Pairs naturally with `effecttab` for causal inference workflows

## Installation

```stata
net install balancetab, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/balancetab")
```

## Syntax

```stata
balancetab varlist [if] [in], treatment(varname) [options]
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| **treatment(varname)** | *(required)* | Binary treatment indicator (0/1) |
| **wvar(varname)** | - | Weight variable (e.g., IPTW weights) |
| **matched** | off | Indicates data has been matched |
| **threshold(#)** | 0.1 | SMD threshold for imbalance |
| **xlsx(filename)** | - | Export balance table to Excel |
| **sheet(name)** | "Balance" | Excel sheet name |
| **loveplot** | off | Generate Love plot |
| **saving(filename)** | - | Save Love plot to file |
| **format(fmt)** | %6.3f | Display format for SMD |
| **title(string)** | - | Title for output/plot |

## Examples

### Basic balance check (unadjusted)

```stata
webuse cattaneo2, clear
balancetab mage medu fage, treatment(mbsmoke)
```

### Balance after IPTW

```stata
* Estimate propensity scores and create weights
logit mbsmoke mage medu fage
predict ps, pr
gen ipw = cond(mbsmoke==1, 1/ps, 1/(1-ps))

* Check balance
balancetab mage medu fage, treatment(mbsmoke) wvar(ipw)
```

### With Love plot and Excel export

```stata
balancetab mage medu fage, treatment(mbsmoke) wvar(ipw) ///
    xlsx(balance.xlsx) loveplot saving(loveplot.png)
```

### With matched data

```stata
teffects psmatch (bweight) (mbsmoke mage medu), atet
balancetab mage medu, treatment(mbsmoke) matched
```

## Interpreting SMD

The standardized mean difference quantifies the difference between treatment and control groups in standard deviation units:

| SMD | Interpretation |
|-----|----------------|
| < 0.1 | Good balance |
| 0.1-0.25 | Acceptable balance |
| > 0.25 | Poor balance |

## Stored Results

`balancetab` stores the following in `r()`:

**Scalars:**

| Result | Description |
|--------|-------------|
| `r(N)` | Total number of observations |
| `r(N_treated)` | Number in treatment group |
| `r(N_control)` | Number in control group |
| `r(max_smd_raw)` | Maximum absolute SMD before adjustment |
| `r(max_smd_adj)` | Maximum absolute SMD after adjustment |
| `r(n_imbalanced)` | Number of covariates exceeding threshold |

**Matrices:**

| Result | Description |
|--------|-------------|
| `r(balance)` | Matrix of balance statistics |

## Requirements

- Stata 16.0 or higher

## Version

- **Version 1.0.0** (21 December 2025): Initial release

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## See Also

- `help effecttab` - Format treatment effects tables
- `help iptw_diag` - IPTW weight diagnostics
- `help teffects` - Treatment effects estimation
