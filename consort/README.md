# consort

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![Python 3.7+](https://img.shields.io/badge/Python-3.7%2B-blue) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

Generate CONSORT-style exclusion flowcharts for observational research directly from Stata.

## Installation

```stata
capture ado uninstall consort
net install consort, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/consort") replace
help consort
```

## Requirements

- Stata 16 or newer
- Python 3.7 or newer
- Python package `matplotlib`

Install `matplotlib` from a shell:

```bash
pip install matplotlib
```

Or from Stata:

```stata
shell pip install matplotlib
```

## How It Works

`consort` is a stateful four-step workflow:

1. `consort init` records the current observation count and creates a CSV backing file.
2. `consort exclude` drops matching observations and appends each exclusion step to that CSV.
3. `consort save` calls the bundled Python renderer to turn the recorded steps into a diagram.
4. `consort clear` removes the active state if you want to abandon or reset the workflow.

The important operational detail is that `consort exclude` really does `drop` observations from the active dataset. If you want to keep working with the original data afterward, wrap the workflow in `preserve` and `restore`.

## Worked Example

The example below uses `sysuse auto`, so it is runnable immediately after installation and shows the full command sequence from start to finish.

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

What this does:

- starts from the full `auto` dataset
- removes observations with missing `rep78`
- removes foreign cars from the remaining sample
- writes a publication-ready PNG flowchart at 300 DPI

## Subcommands and Syntax

### Initialize a diagram

```stata
consort init, initial(string) [file(string)]
```

| Option | Description |
| --- | --- |
| `initial(string)` | Required label for the starting population box |
| `file(string)` | Optional CSV path if you want to keep the intermediate step file |

### Add an exclusion step

```stata
consort exclude if condition, label(string) [remaining(string)]
```

| Option | Description |
| --- | --- |
| `if condition` | Required exclusion condition |
| `label(string)` | Required text for the exclusion box |
| `remaining(string)` | Optional label for the surviving cohort after that exclusion |

### Save the diagram

```stata
consort save, output(string) [final(string) shading python(string) dpi(integer)]
```

| Option | Description |
| --- | --- |
| `output(string)` | Required output image path |
| `final(string)` | Label for the final cohort box |
| `shading` | Apply shaded box styling |
| `python(string)` | Explicit Python executable path if auto-detection fails |
| `dpi(integer)` | Output resolution; default is 150 and `dpi(300)` is usually preferable for manuscripts |

### Clear the active state

```stata
consort clear [, quiet]
```

Use `consort clear` when you want to abandon the current diagram without saving it.

## Stored Results

### `consort init`

| Result | Description |
| --- | --- |
| `r(N)` | Initial number of observations |
| `r(initial)` | Initial population label |
| `r(file)` | Backing CSV path |

### `consort exclude`

| Result | Description |
| --- | --- |
| `r(n_excluded)` | Number of observations excluded at that step |
| `r(n_remaining)` | Number of observations remaining |
| `r(step)` | Exclusion step number |
| `r(label)` | Exclusion label |

### `consort save`

| Result | Description |
| --- | --- |
| `r(N_initial)` | Initial observation count |
| `r(N_final)` | Final observation count |
| `r(N_excluded)` | Total excluded across all steps |
| `r(steps)` | Number of exclusion steps |
| `r(output)` | Output image path |
| `r(final)` | Final cohort label |

## Screenshots

### Console output

![Console Output](demo/console_output.png)

### CONSORT flowchart

![CONSORT Flowchart](demo/consort_flowchart.png)

## Troubleshooting

### Python not found

Specify the interpreter explicitly:

```stata
consort save, output("diagram.png") python("/usr/local/bin/python3")
```

### `matplotlib` not installed

```stata
shell pip install matplotlib
```

### Permission errors or missing output

Make sure the target output directory exists and is writable from Stata.

## Version

**Version**: 1.0.0

## Author

Timothy P Copeland, Karolinska Institutet

## License

MIT License
