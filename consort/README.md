# consort - CONSORT-style exclusion flowcharts for observational research

**Version 1.0.0** | 2026-04-08

`consort` generates CONSORT-style exclusion flowcharts for observational research directly from Stata. It records each exclusion step, writes those steps to a backing CSV file, and uses a bundled Python renderer to produce a publication-ready diagram.

The command is designed for real data-cleaning workflows, not just drawing. Each exclusion step actually drops observations from the active dataset, so the README examples emphasize `preserve` and `restore` when you want to keep the original data in memory.

## Requirements

- Stata 16 or later
- Python 3.7 or later
- Python package `matplotlib`

Install `matplotlib` from a shell:

```bash
python -m pip install matplotlib
```

Or from Stata:

```stata
shell python -m pip install matplotlib
```

## Installation

```stata
capture ado uninstall consort
net install consort, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/consort") replace
```

## Commands

| Command | Description |
|---------|-------------|
| `consort` | Initialize, update, save, and clear a CONSORT-style exclusion flowchart through subcommands |

## How It Works

`consort` is a stateful four-step workflow:

1. `consort init` records the current observation count and creates a CSV backing file.
2. `consort exclude` drops matching observations and appends each exclusion step to that CSV.
3. `consort save` calls the bundled Python renderer to turn the recorded steps into a diagram.
4. `consort clear` removes the active state if you want to abandon or reset the workflow.

Operational details that matter:

- `consort exclude` really does `drop` observations from the active dataset
- zero-match exclusions are skipped, so they do not add a step to the diagram
- `consort save` requires at least one exclusion step and clears the active state after a successful save
- if you want to keep the original data after drawing the figure, wrap the workflow in `preserve` and `restore`

## Subcommands

| Subcommand | Syntax | Purpose |
|------------|--------|---------|
| `init` | `consort init, initial(string) [file(filename)]` | Start a new diagram from the current dataset |
| `exclude` | `consort exclude if condition, label(string) [remaining(string)]` | Record an exclusion and drop matching observations |
| `save` | `consort save, output(filename) [final(string) shading python(string) dpi(#)]` | Render the diagram to disk |
| `clear` | `consort clear [, quiet]` | Abandon the active diagram state |

## Worked Examples

### 1. Basic workflow with built-in data

This example is runnable immediately after installation. It shows the full workflow from initialization to a saved diagram while preserving the original dataset.

```stata
sysuse auto, clear
preserve

consort init, initial("Cars in auto.dta")
consort exclude if missing(rep78), ///
    label("Missing repair record") ///
    remaining("Cars with repair data")
consort exclude if foreign, ///
    label("Foreign cars")
consort save, output("consort_auto.png") ///
    final("Domestic analytic sample") ///
    shading dpi(300)

restore
```

This sequence starts from the full `auto` dataset, removes observations in order, and writes a high-resolution PNG flowchart to the current working directory.

### 2. Cohort-style example using the shared `_data/` example file

This mirrors the main epidemiology-oriented help-file workflow while keeping the example copy-paste runnable after installation.

```stata
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear
preserve

consort init, initial("Persons with antidepressant dispensing")
consort exclude if index_age < 18, ///
    label("Age < 18 years") ///
    remaining("Adult cohort")
consort exclude if study_exit <= study_entry + 30, ///
    label("Follow-up < 30 days")
consort exclude if missing(education), ///
    label("Missing education data")
consort save, output("cohort_flowchart.png") ///
    final("Analytic cohort") dpi(300)

restore
```

### 3. Saving with an explicit Python executable

Use `python()` when Python is not on the system path that Stata sees or when you need a specific interpreter.

```stata
sysuse auto, clear
preserve

consort init, initial("Cars in auto.dta")
consort exclude if missing(rep78), label("Missing repair record")
consort save, output("consort_auto.png") ///
    python("/usr/local/bin/python3") ///
    final("Analytic sample")

restore
```

## Practical Notes

- `file()` in `consort init` lets you keep the intermediate CSV instead of using a temporary file
- `remaining()` is useful when you want the post-exclusion population boxes to carry milestone labels rather than counts only
- `final()` overrides the default final label of `"Final Cohort"`
- `dpi(300)` is usually the right choice for manuscript figures; the default is 150
- `shading` adds blue shading to flow boxes and red shading to exclusion boxes

## Troubleshooting

### Python not found

Specify the interpreter explicitly:

```stata
consort save, output("diagram.png") python("/usr/local/bin/python3")
```

### `matplotlib` not installed

```stata
shell python -m pip install matplotlib
```

### Permission errors or missing output

Make sure the target output directory exists and is writable from Stata before running `consort save`.

## Version History

- **1.0.0** (2026-04-08): Initial Stata-Tools release for stateful CONSORT-style flowchart generation from Stata

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT
