# QA fixture manifest

## Cross-validation fixtures

| Files | Owner and regeneration | Consumer |
|---|---|---|
| `data/crossval_tabtools_r_results.csv` | `crossval_tabtools_companion.R`; deterministic base R formulas | `crossval_tabtools.do` CV1–CV18 and CV20 |
| `data/crossval_smd_data.csv` | `crossval_tabtools_companion.R`, seed 42 | Continuous-SMD command bridges |
| `data/crossval_cat_smd_data.csv` | `crossval_tabtools_companion.R`, seed 123 | Categorical-SMD command bridge |
| `data/crossval_ess_data.csv` | `crossval_tabtools_companion.R`, seed 99 | Kish-ESS command bridge |

The cross-validation suite regenerates all four files into a unique temporary
directory and compares them before loading any reference value. Tracked files
must be updated only from a reviewed companion-script change.

## Golden-output summaries

`baseline/baseline_manifest.tsv` owns the TSV files in
`baseline/summaries/`. Each row identifies the command, worksheet, summary
file, and gate status.

- `regenerated` rows are recreated by `test_package_release.do` and compared
  against the tracked semantic digest.
- `stored-only` rows are retained historical references and are not described
  as regenerated gates.
- The staged demo gate separately regenerates and semantically compares all 15
  tracked demo workbooks, including workbook inventory, worksheet content,
  widths, text anomalies, Markdown, and PNG assets.

No generated workbook is tracked under `qa/baseline/`; ordinary QA writes
workbooks to the per-run output directory.

## Manual stress generator

`_visual_stress_gen.do` produces disposable visual-inspection workbooks. It is
support tooling, not a release-lane test, and its products remain ignored.
