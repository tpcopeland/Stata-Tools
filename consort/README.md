# consort

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

CONSORT flow diagram generator for clinical trials.

## Package Overview

**consort** generates publication-quality CONSORT (Consolidated Standards of Reporting Trials) flow diagrams showing participant flow through each stage of a randomized trial.

### Key Features

- **Standard CONSORT stages**: Enrollment, Allocation, Follow-up, Analysis
- **Multi-arm support**: 2, 3, or 4 treatment arms with automatic layout
- **Detailed tracking**: Exclusions, losses, and discontinuations with reasons
- **Export formats**: PNG, PDF, EPS, SVG, TIF and other graphics formats
- **Customizable appearance**: Colors, text sizes, dimensions
- **Dialog interface**: Easy-to-use graphical interface

---

## Installation

```stata
net install consort, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/consort")
```

---

## consort - Generate CONSORT Flow Diagrams

### Syntax

```stata
consort, required_options [optional_options]
```

### Required Options

| Option | Description |
|--------|-------------|
| `assessed(#)` | Total participants assessed for eligibility |
| `excluded(#)` | Total participants excluded |
| `randomized(#)` | Total participants randomized |
| `arm1_label(string)` | Label for treatment arm 1 |
| `arm1_allocated(#)` | Participants allocated to arm 1 |
| `arm1_analyzed(#)` | Participants analyzed in arm 1 |
| `arm2_label(string)` | Label for treatment arm 2 |
| `arm2_allocated(#)` | Participants allocated to arm 2 |
| `arm2_analyzed(#)` | Participants analyzed in arm 2 |

### Optional Options - Enrollment Details

| Option | Description |
|--------|-------------|
| `excreasons(string)` | Exclusion reasons; separate multiple with `;;` |

### Optional Options - Arm Details

For each arm (arm1_, arm2_, arm3_, arm4_):

| Option | Description |
|--------|-------------|
| `arm#_received(#)` | Received intervention (-1 = not shown) |
| `arm#_notrec(#)` | Did not receive intervention |
| `arm#_notrec_reasons(string)` | Reasons for not receiving |
| `arm#_lost(#)` | Lost to follow-up |
| `arm#_lost_reasons(string)` | Reasons for loss to follow-up |
| `arm#_discontinued(#)` | Discontinued intervention |
| `arm#_disc_reasons(string)` | Reasons for discontinuation |
| `arm#_analysis_excluded(#)` | Excluded from analysis |
| `arm#_analysis_exc_reasons(string)` | Reasons for analysis exclusion |

### Additional Arms

| Option | Description |
|--------|-------------|
| `arm3_label(string)` | Label for arm 3 |
| `arm3_allocated(#)` | Allocated to arm 3 |
| `arm3_analyzed(#)` | Analyzed in arm 3 |
| `arm4_label(string)` | Label for arm 4 |
| `arm4_allocated(#)` | Allocated to arm 4 |
| `arm4_analyzed(#)` | Analyzed in arm 4 |

### Graph Options

| Option | Description | Default |
|--------|-------------|---------|
| `title(string)` | Graph title | — |
| `subtitle(string)` | Graph subtitle | — |
| `name(name)` | Name graph in memory | — |
| `saving(filename)` | Export graph to file | — |
| `replace` | Replace existing file | — |
| `scheme(schemename)` | Graph scheme | — |
| `nodraw` | Suppress graph display | — |

### Appearance Options

| Option | Description | Default |
|--------|-------------|---------|
| `boxcolor(color)` | Box fill color | white |
| `boxborder(color)` | Box border color | black |
| `arrowcolor(color)` | Arrow color | black |
| `textsize(size)` | Text size in boxes | vsmall |
| `labelsize(size)` | Stage label size | small |
| `width(#)` | Graph width in inches | 7 |
| `height(#)` | Graph height in inches | 10 |

---

## Examples

### Example 1: Basic Two-Arm Trial

```stata
consort, assessed(200) excluded(25) randomized(175) ///
    arm1_label("Treatment") arm1_allocated(88) arm1_analyzed(80) ///
    arm2_label("Control") arm2_allocated(87) arm2_analyzed(82)
```

### Example 2: With Exclusion Reasons and Follow-up Details

```stata
consort, assessed(500) excluded(100) randomized(400) ///
    excreasons("Not meeting criteria (n=60);; Declined (n=30);; Other (n=10)") ///
    arm1_label("Drug A") arm1_allocated(200) ///
    arm1_lost(15) arm1_lost_reasons("Withdrew consent (n=10);; Lost contact (n=5)") ///
    arm1_discontinued(8) arm1_disc_reasons("Adverse events (n=5);; Lack of efficacy (n=3)") ///
    arm1_analyzed(177) ///
    arm2_label("Placebo") arm2_allocated(200) ///
    arm2_lost(12) arm2_lost_reasons("Withdrew consent (n=8);; Lost contact (n=4)") ///
    arm2_discontinued(5) arm2_disc_reasons("Adverse events (n=3);; Other (n=2)") ///
    arm2_analyzed(183) ///
    title("CONSORT Flow Diagram") ///
    saving("consort_diagram.png") replace
```

### Example 3: Three-Arm Trial

```stata
consort, assessed(600) excluded(150) randomized(450) ///
    arm1_label("Low Dose") arm1_allocated(150) arm1_analyzed(140) ///
    arm1_lost(5) arm1_discontinued(3) ///
    arm2_label("High Dose") arm2_allocated(150) arm2_analyzed(138) ///
    arm2_lost(7) arm2_discontinued(5) ///
    arm3_label("Placebo") arm3_allocated(150) arm3_analyzed(145) ///
    arm3_lost(3) arm3_discontinued(2) ///
    title("Three-Arm Dose-Finding Study")
```

### Example 4: Custom Appearance

```stata
consort, assessed(300) excluded(50) randomized(250) ///
    arm1_label("Intervention") arm1_allocated(125) arm1_analyzed(120) ///
    arm2_label("Control") arm2_allocated(125) arm2_analyzed(122) ///
    boxcolor("ltblue") boxborder("navy") arrowcolor("navy") ///
    textsize("small") width(8) height(12) ///
    scheme(s1color) ///
    saving("consort_custom.pdf") replace
```

---

## CONSORT Flow Diagram Structure

The generated diagram follows the standard CONSORT 2010 format:

```
                    ┌─────────────────────────┐
     Enrollment     │  Assessed for eligibility │──────┐
                    └─────────────────────────┘       │
                                │                     ▼
                                │             ┌─────────────┐
                                │             │   Excluded  │
                                ▼             └─────────────┘
                    ┌─────────────────────────┐
                    │       Randomized        │
                    └─────────────────────────┘
                        │               │
     Allocation         ▼               ▼
              ┌──────────────┐   ┌──────────────┐
              │ Allocated to │   │ Allocated to │
              │   Arm 1      │   │    Arm 2     │
              └──────────────┘   └──────────────┘
                    │                   │
     Follow-up      ▼                   ▼
              ┌──────────────┐   ┌──────────────┐
              │ Lost/Discont │   │ Lost/Discont │
              └──────────────┘   └──────────────┘
                    │                   │
     Analysis       ▼                   ▼
              ┌──────────────┐   ┌──────────────┐
              │   Analysed   │   │   Analysed   │
              └──────────────┘   └──────────────┘
```

---

## Stored Results

`consort` stores the following in `r()`:

### Scalars

| Scalar | Description |
|--------|-------------|
| `r(assessed)` | Total assessed for eligibility |
| `r(excluded)` | Total excluded |
| `r(randomized)` | Total randomized |
| `r(narms)` | Number of treatment arms |
| `r(arm#_allocated)` | Allocated to arm # |
| `r(arm#_analyzed)` | Analyzed in arm # |

### Macros

| Macro | Description |
|-------|-------------|
| `r(arm#_label)` | Label for arm # |

---

## Remarks

### Multiple Reasons Format

When specifying multiple reasons for exclusions, losses, or discontinuations, separate each reason with `;;` (double semicolon):

```stata
excreasons("Not meeting criteria (n=60);; Declined to participate (n=30);; Other reasons (n=10)")
```

### Export Formats

The `saving()` option supports any format that Stata's `graph export` command accepts. The format is determined by the file extension:

- `.png` - PNG image (recommended for most uses)
- `.pdf` - PDF document (recommended for publications)
- `.eps` - Encapsulated PostScript
- `.svg` - Scalable Vector Graphics
- `.tif` - TIFF image

### Color Specifications

Colors can be specified using:
- Named colors: `red`, `blue`, `navy`, `forest_green`, etc.
- RGB values: `"100 150 200"`
- Intensity modifiers: `navy*0.5`, `red*1.2`

---

## Requirements

- Stata 16.0 or higher

## Dialog Interface

Access the graphical interface:

```stata
db consort
```

## Documentation

- Command help: `help consort`

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Version

Version 1.0.0, 2025-12-03

## References

- Schulz KF, Altman DG, Moher D (2010). CONSORT 2010 Statement: updated guidelines for reporting parallel group randomised trials. *BMJ* 340:c332.
- Moher D, Hopewell S, Schulz KF, et al. (2010). CONSORT 2010 Explanation and Elaboration: updated guidelines for reporting parallel group randomised trials. *BMJ* 340:c869.

## Also See

- Stata help: `help graph`, `help graph export`
- CONSORT website: [www.consort-statement.org](http://www.consort-statement.org)
