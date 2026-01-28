# Stata Dialog File (.dlg) Development Guide

Complete reference for creating Stata dialog files.

---

## Basic Structure

```stata
VERSION 16.0
INCLUDE _std_large
DEFINE _dlght 480
DEFINE _dlgwd 640
INCLUDE header

HELP hlp1, view("help mycommand")
RESET res1

DIALOG main, label("mycommand - Description") tabtitle("Main")
BEGIN
  // Controls go here
END

PROGRAM command
BEGIN
    // Command generation logic
END
```

---

## Standard Dialog Sizes

| Size | Dimensions | Use Case |
|------|------------|----------|
| `_std_small` | 320x200 | Simple single-option dialogs |
| `_std_medium` | 480x320 | Standard dialogs |
| `_std_large` | 640x480 | Complex multi-section dialogs |
| `_std_xlarge` | 800x600 | Dialogs with many options |

Custom size:
```stata
DEFINE _dlght 500   // Height in pixels
DEFINE _dlgwd 700   // Width in pixels
```

---

## Control Types

### Text Controls

```stata
TEXT tx_label  x y width ., label("Label text:")
```

### Input Controls

```stata
// Single variable
VARNAME vn_var    x y width ., label("Variable")

// Multiple variables
VARLIST vl_vars   x y width ., label("Variables")

// Text entry
EDIT ed_text      x y width ., label("Text")

// Numeric entry (with validation)
SPINNER sp_num    x y width ., min(1) max(100) default(10) label("Number")

// File selection
FILE fi_file      x y width ., label("File") filter("Stata Data|*.dta") save
```

### Selection Controls

```stata
// Checkbox (boolean)
CHECKBOX ck_opt   x y width ., label("Enable option")

// Radio buttons (mutually exclusive)
RADIO rb_opt1     x y width ., label("Option 1") first
RADIO rb_opt2     x y width ., label("Option 2") last

// Dropdown
COMBOBOX cb_type  x y width ., dropdown contents(type_list) label("Type")
```

### Grouping Controls

```stata
GROUPBOX gb_main  x y width height, label("Group Title")
```

---

## Position Syntax

### Coordinate System

| Element | Description |
|---------|-------------|
| `x` | Horizontal position (pixels from left) |
| `y` | Vertical position (pixels from top) |
| `width` | Control width in pixels |
| `height` | Control height (`.` = auto) |

### Position Shortcuts

| Symbol | Meaning |
|--------|---------|
| `@` | Same as previous control |
| `+N` | Previous + N pixels |
| `-N` | Previous - N pixels |
| `.` | Default/auto height |
| `_lft` | Standard left margin |
| `_iwd` | Inner width (dialog width - margins) |

### Examples

```stata
TEXT     tx_var1   10  30  280  ., label("Variable 1:")
VARNAME  vn_var1   @   +20 @    ., label("Var1")

TEXT     tx_var2   330 -20 280  ., label("Variable 2:")   // Same row, right side
VARNAME  vn_var2   @   +20 @    ., label("Var2")
```

---

## Spacing Rules

| Context | Vertical Spacing |
|---------|------------------|
| After GROUPBOX label (required vars) | +15 |
| After GROUPBOX label (standard) | +20 |
| After GROUPBOX label (FILE in save) | +25 |
| Label to input control | +20 |
| Between field pairs | +25 |
| Side-by-side right column adjustment | -20 |

### Horizontal Guidelines

| Element | X Position |
|---------|------------|
| Left margin | 10 |
| Indented controls | 20 or 40 |
| Right column (side-by-side) | 330 |
| Group box width | 620 |

---

## Control Naming Convention

Use prefixes to identify control types:

| Prefix | Type |
|--------|------|
| `tx_` | TEXT |
| `ed_` | EDIT |
| `vn_` | VARNAME |
| `vl_` | VARLIST |
| `ck_` | CHECKBOX |
| `rb_` | RADIO |
| `cb_` | COMBOBOX |
| `gb_` | GROUPBOX |
| `fi_` | FILE |
| `sp_` | SPINNER |
| `bu_` | BUTTON |

---

## Complete Dialog Template

```stata
VERSION 16.0
INCLUDE _std_large
DEFINE _dlght 480
DEFINE _dlgwd 640
INCLUDE header

HELP hlp1, view("help mycommand")
RESET res1

DIALOG main, label("mycommand - Brief Description") tabtitle("Main")
BEGIN
  // =========================================================================
  // Required Variables Section
  // =========================================================================
  GROUPBOX gb_required  10  10  620  115, label("Required variables")

  TEXT     tx_varlist   20  30  280  ., label("Analysis variables:")
  VARLIST  vl_varlist   @   +20 @    ., label("Variables")

  TEXT     tx_idvar     330 -20 280  ., label("ID variable:")
  VARNAME  vn_idvar     @   +20 @    ., label("ID")

  TEXT     tx_datevar   20  +25 280  ., label("Date variable:")
  VARNAME  vn_datevar   @   +20 @    ., label("Date")

  // =========================================================================
  // Options Section
  // =========================================================================
  GROUPBOX gb_options   10  135 620  100, label("Options")

  CHECKBOX ck_option1   20  155 280  ., label("Enable option 1")
  CHECKBOX ck_option2   20  +25 280  ., label("Enable option 2")

  TEXT     tx_level     330 -25 140  ., label("Confidence level:")
  SPINNER  sp_level     +145 @  100  ., min(10) max(99) default(95) label("Level")

  // =========================================================================
  // Output Section
  // =========================================================================
  GROUPBOX gb_output    10  245 620  80, label("Output")

  TEXT     tx_generate  20  265 140  ., label("Save results as:")
  EDIT     ed_generate  +145 @  195  ., label("Generate")

  CHECKBOX ck_replace   20  +25 280  ., label("Replace existing variable")
END

PROGRAM command
BEGIN
    // Build command string
    put "mycommand "

    // Required variables
    require vl_varlist
    put vl_varlist

    // Required options
    put ", "
    require vn_idvar
    put "id(" vn_idvar ") "

    require vn_datevar
    put "date(" vn_datevar ") "

    // Optional settings
    if ck_option1 {
        put "option1 "
    }
    if ck_option2 {
        put "option2 "
    }

    if !sp_level.isdefault() {
        put "level(" sp_level ") "
    }

    // Output options
    if ed_generate {
        put "generate(" ed_generate ") "
    }
    if ck_replace {
        put "replace "
    }
END
```

---

## Multiple Tabs

```stata
DIALOG main, label("mycommand") tabtitle("Main")
BEGIN
  // Main tab controls
END

DIALOG options, tabtitle("Options")
BEGIN
  // Options tab controls
END

DIALOG advanced, tabtitle("Advanced")
BEGIN
  // Advanced tab controls
END
```

---

## PROGRAM command Reference

### Basic Operations

```stata
PROGRAM command
BEGIN
    put "mycommand "           // Literal text
    put vn_varname             // Variable from VARNAME control
    put vl_varlist             // Variables from VARLIST control
    put ed_text                // Text from EDIT control
    put sp_number              // Value from SPINNER control
END
```

### Conditional Output

```stata
PROGRAM command
BEGIN
    // Checkbox condition
    if ck_option {
        put "option "
    }

    // Radio button condition
    if rb_type1 {
        put "type(1) "
    }
    if rb_type2 {
        put "type(2) "
    }

    // Non-empty text
    if ed_text {
        put "text(" ed_text ") "
    }

    // Non-default spinner
    if !sp_level.isdefault() {
        put "level(" sp_level ") "
    }
END
```

### Required Fields

```stata
PROGRAM command
BEGIN
    require vl_varlist         // Error if empty
    require vn_idvar
END
```

### Option Pairs

```stata
PROGRAM command
BEGIN
    // Option with argument
    optionarg ed_generate
    // Outputs: generate(value) if ed_generate has content

    // Named option with argument
    optionarg /output ed_filename
    // Outputs: output(value) if ed_filename has content
END
```

---

## List Contents

### Static List

```stata
LIST type_list
BEGIN
    "Option A"
    "Option B"
    "Option C"
END

DIALOG main, ...
BEGIN
    COMBOBOX cb_type  x y w ., dropdown contents(type_list)
END
```

### Dynamic List

```stata
LIST vartype_list
BEGIN
    // Populated from Stata's variable list
END

DIALOG main, ...
BEGIN
    COMBOBOX cb_var  x y w ., dropdown contents(vartype_list) values(varnames)
END
```

---

## Enabling/Disabling Controls

```stata
DIALOG main, ...
BEGIN
    CHECKBOX ck_enable  x y w ., label("Enable output") onclickon(script show_output) onclickoff(script hide_output)
    TEXT     tx_output  x y w ., label("Output file:")
    FILE     fi_output  x y w ., label("File")
END

SCRIPT show_output
BEGIN
    main.tx_output.enable
    main.fi_output.enable
END

SCRIPT hide_output
BEGIN
    main.tx_output.disable
    main.fi_output.disable
END
```

---

## Testing Dialogs

1. **Load in Stata:**
   ```stata
   db mycommand
   ```

2. **Check command generation:**
   - Fill in all fields
   - Click Submit (not OK)
   - Review generated command in Results window

3. **Test edge cases:**
   - Empty required fields (should show error)
   - Default values
   - All options enabled

---

## Common Pitfalls

1. **Wrong spacing** - Controls overlap or have inconsistent gaps
2. **Missing require** - Required options not validated
3. **Hardcoded widths** - Dialog doesn't adapt to content
4. **Missing help** - No HELP line at top
5. **Tab order** - Controls visited in wrong order

---

*See also: `_devkit/docs/template-guide.md` for complete .dlg template*
