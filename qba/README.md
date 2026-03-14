# qba

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Quantitative Bias Analysis (QBA) for epidemiologic data.

## Description

`qba` provides a comprehensive toolkit for quantitative bias analysis in epidemiologic studies, implementing methods from Lash, Fox, and Fink's *Applying Quantitative Bias Analysis to Epidemiologic Data* (2nd ed, Springer 2021).

The package addresses three major sources of systematic error:

- **Misclassification** of exposure or outcome (nondifferential and differential)
- **Selection bias** from differential study participation
- **Unmeasured confounding** with E-value computation

All commands support both simple (fixed parameter) and probabilistic (Monte Carlo) bias analysis, with multiple distribution families for parameter uncertainty.

## Installation

```stata
net install qba, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/qba")
```

## Commands

| Command | Description |
|---------|-------------|
| `qba` | Package overview and available commands |
| `qba_misclass` | Misclassification bias analysis |
| `qba_selection` | Selection bias analysis |
| `qba_confound` | Unmeasured confounding analysis with E-values |
| `qba_multi` | Multi-bias analysis (chains all three) |
| `qba_plot` | Tornado, distribution, and tipping point plots |

## Quick Start

### Simple bias analysis

```stata
* Correct for nondifferential exposure misclassification
qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)

* Correct for selection bias
qba_selection, a(136) b(297) c(1432) d(6738) sela(.9) selb(.85) selc(.7) seld(.8)

* Correct for unmeasured confounding with E-value
qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0) evalue
```

### Probabilistic bias analysis

```stata
* Monte Carlo with trapezoidal distributions (Lash/Fox/Fink recommended)
qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) ///
    reps(10000) dist_se("trapezoidal .75 .82 .88 .95") ///
    dist_sp("trapezoidal .90 .93 .97 1.0") saving(mc_results, replace)
```

### Multi-bias analysis

```stata
* Chain misclassification + selection + confounding corrections
qba_multi, a(136) b(297) c(1432) d(6738) reps(10000) ///
    seca(.85) spca(.95) dist_se("trapezoidal .75 .82 .88 .95") ///
    sela(.9) selb(.85) selc(.7) seld(.8) ///
    p1(.4) p0(.2) rrcd(2.0)
```

### Visualization

```stata
* Distribution plot from Monte Carlo results
qba_plot, distribution using(mc_results) observed(1.5)

* Tornado sensitivity plot
qba_plot, tornado a(136) b(297) c(1432) d(6738) ///
    param1(se) range1(.7 1) param2(sp) range2(.8 1)

* Tipping point plot
qba_plot, tipping a(136) b(297) c(1432) d(6738) ///
    param1(se) range1(.6 1) param2(sp) range2(.6 1)
```

## Supported Distributions

For probabilistic analysis, parameters can be drawn from:

| Distribution | Syntax | Parameters |
|-------------|--------|------------|
| Trapezoidal | `trapezoidal min m1 m2 max` | Recommended by Lash/Fox/Fink |
| Triangular | `triangular min mode max` | |
| Uniform | `uniform min max` | |
| Beta | `beta a b` | Shape parameters |
| Logit-normal | `logit-normal mean sd` | Bounded (0,1) |
| Constant | `constant value` | Fixed value |

## Stored Results

All commands are `rclass` and store results in `r()`:

### Simple mode (all commands)

| Result | Description |
|--------|-------------|
| `r(observed)` | Observed measure of association |
| `r(corrected)` | Corrected measure of association |
| `r(ratio)` | Corrected / observed |
| `r(measure)` | Measure type (OR or RR) |
| `r(method)` | "simple" or "probabilistic" |

### Probabilistic mode (when `reps()` specified)

| Result | Description |
|--------|-------------|
| `r(corrected)` | Median corrected measure |
| `r(mean)` | Mean of MC distribution |
| `r(sd)` | Standard deviation |
| `r(ci_lower)` / `r(ci_upper)` | Percentile CI bounds |
| `r(reps)` | Number of replications |
| `r(n_valid)` | Valid (non-missing) replications |

### Command-specific results

- **qba_misclass**: `r(corrected_a)` through `r(corrected_d)` (corrected cells), `r(type)` (exposure/outcome)
- **qba_selection**: `r(bias_factor)` (selection bias factor), `r(corrected_a)` through `r(corrected_d)`
- **qba_confound**: `r(bias_factor)`, `r(evalue)`, `r(evalue_ci)`, `r(p1)`, `r(p0)`
- **qba_multi**: `r(n_biases)`, `r(order)` (correction order)

See individual help files (`help qba_misclass`, etc.) for full details.

## Validation

The `qa/` directory contains tests across 2 test files:

- **test_qba.do** — Functional tests for all commands (simple and probabilistic modes, all three bias types, multi-bias chaining, plotting)
- **validation_qba.do** — Validates corrected estimates against hand-computed values and published examples from Lash, Fox, and Fink (2021)

## Requirements

- Stata 16.0 or higher

## Version

- **Version 1.0.0** (13 March 2026): Initial release

## Author

Timothy P Copeland
Department of Clinical Neuroscience
Karolinska Institutet

## License

MIT License

## References

- Lash TL, Fox MP, Fink AK. *Applying Quantitative Bias Analysis to Epidemiologic Data*. 2nd ed. Springer; 2021.
- VanderWeele TJ, Ding P. Sensitivity analysis in observational research: introducing the E-value. *Ann Intern Med*. 2017;167(4):268-274.
- Schneeweiss S. Sensitivity analysis and external adjustment for unmeasured confounders. *Pharmacoepidemiol Drug Saf*. 2006;15(5):291-303.
- Fox MP, Lash TL, Greenland S. A method to automate probabilistic sensitivity analyses of misclassified binary variables. *Int J Epidemiol*. 2005;34(6):1370-1376.
- Greenland S. Basic methods for sensitivity analysis of biases. *Int J Epidemiol*. 1996;25(6):1107-1116.
