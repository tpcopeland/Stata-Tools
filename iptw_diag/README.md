# iptw_diag

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

IPTW weight diagnostics - distribution summaries, effective sample size, extreme weight detection, and trimming/stabilization utilities.

## Description

`iptw_diag` provides comprehensive diagnostics for inverse probability of treatment weights (IPTW). It helps identify potential issues with propensity score weights and provides tools to address them.

Key features:
- Weight distribution summaries (mean, SD, min, max, percentiles)
- Effective sample size (ESS) calculation
- Extreme weight detection
- Weight trimming at specified percentiles
- Weight truncation at maximum values
- Stabilized weight calculation
- Distribution visualization

## Installation

```stata
net install iptw_diag, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/iptw_diag")
```

## Syntax

```stata
iptw_diag wvar [if] [in], treatment(varname) [options]
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| **treatment(varname)** | *(required)* | Binary treatment indicator (0/1) |
| **trim(#)** | - | Trim weights at specified percentile (50-99.9) |
| **truncate(#)** | - | Truncate weights at maximum value |
| **stabilize** | off | Calculate stabilized weights |
| **generate(name)** | - | Name for modified weight variable |
| **replace** | off | Allow replacing existing variable |
| **detail** | off | Show detailed percentile distribution |
| **graph** | off | Display weight distribution histogram |
| **saving(filename)** | - | Save graph to file |

## Examples

### Basic diagnostics

```stata
* Create IPTW weights
webuse cattaneo2, clear
logit mbsmoke mage medu fage
predict ps, pr
gen ipw = cond(mbsmoke==1, 1/ps, 1/(1-ps))

* Run diagnostics
iptw_diag ipw, treatment(mbsmoke)
```

### With detailed percentiles

```stata
iptw_diag ipw, treatment(mbsmoke) detail
```

### Trim at 99th percentile

```stata
iptw_diag ipw, treatment(mbsmoke) trim(99) generate(ipw_trim)
```

### Create stabilized weights

```stata
iptw_diag ipw, treatment(mbsmoke) stabilize generate(ipw_stab)
```

### With histogram

```stata
iptw_diag ipw, treatment(mbsmoke) graph saving(weights.png)
```

## Interpretation Guidelines

### Effective Sample Size (ESS)

| ESS as % of N | Interpretation |
|---------------|----------------|
| > 50% | Acceptable |
| 25-50% | Concerning |
| < 25% | Problematic |

### When to Modify Weights

Consider trimming or truncating when:
- Maximum weight > 10-20
- Coefficient of variation > 1
- ESS < 50% of N
- Few observations with extreme weights drive results

### Stabilized vs Unstabilized Weights

- **Unstabilized IPTW**: w = 1/P(T|X) for treated, 1/(1-P(T|X)) for controls
- **Stabilized IPTW**: w = P(T)/P(T|X) for treated, (1-P(T))/(1-P(T|X)) for controls

Stabilized weights typically have mean 1 and smaller variance, often providing more stable estimates.

## Stored Results

`iptw_diag` stores the following in `r()`:

**Scalars:**

| Result | Description |
|--------|-------------|
| `r(N)` | Total number of observations |
| `r(mean_wt)` | Mean weight |
| `r(sd_wt)` | Standard deviation of weights |
| `r(min_wt)` | Minimum weight |
| `r(max_wt)` | Maximum weight |
| `r(cv)` | Coefficient of variation |
| `r(ess)` | Effective sample size |
| `r(ess_pct)` | ESS as percentage of N |
| `r(n_extreme)` | Number of extreme weights (>10) |

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

- `help balancetab` - Propensity score balance diagnostics
- `help effecttab` - Format treatment effects tables
- `help teffects ipw` - IPTW estimation
