# simtab — Monte Carlo simulation summaries

**Version 2.0.0** | 2026-08-19

`simtab` creates publication-ready Monte Carlo simulation performance tables from replication-level results or summaries produced by `simsum`, `siman`, or another workflow. It computes bias, empirical and model-based standard errors, MSE/RMSE, coverage, power, nonconvergence, and their Monte Carlo standard errors, then exports the result to Excel, CSV, Markdown, or Stata frames.

## Install

```stata
net install simtab, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/simtab") replace
```

## Quick start

```stata
clear
set seed 20260819
set obs 400
generate int sim = mod(_n - 1, 100) + 1
generate byte estimator = mod(floor((_n - 1) / 100), 2) + 1
generate byte scenario = cond(_n <= 200, 1, 2)
generate double true_value = 1
generate double se = .20
generate double estimate = true_value + (estimator == 2) * .05 + rnormal() * se
generate byte covered = abs(estimate - true_value) <= invnormal(.975) * se

simtab estimator, estimate(estimate) se(se) true(true_value) ///
    by(scenario) sim(sim) coverage(covered) nsim(100) ///
    metrics(mean bias empse meanse coverage n nonconv) ///
    xlsx("simulation.xlsx") sheet("Performance")
```

Use `help simtab` for compute and ingest syntax, metric definitions, options, stored results, and references. The package has no mandatory dependency on `simsum` or `siman`; `from()` consumes their in-memory summary structures when those workflows are used.

## Outputs

- `xlsx()` writes a styled Excel table and supports append-by-sheet workflows.
- `csv()` and `markdown()` write portable publication tables.
- `frame()` stores the rendered table; `plotframe()` stores numeric performance results for downstream plots.
- Returned results describe input mode, dimensions, metrics, exclusions, Monte Carlo settings, and written artifacts.

## Reproducible demo and QA

Run `demo/demo_simtab.do` from the Stata-Tools repository root to regenerate the checked-in workbook. The package-local `qa/run_all.do` offers `quick` and `full` lanes; the full lane includes known-answer MCSE validation.

## Author

Timothy P Copeland, Karolinska Institutet

## Version History

- **2.0.0** (2026-08-19): Extracted `simtab` into a standalone package while preserving its compute, ingest, export, and stored-result contracts.

## License

MIT
