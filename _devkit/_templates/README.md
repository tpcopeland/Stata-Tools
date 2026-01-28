# Stata Command Templates

This folder contains templates for creating new Stata commands, based on the structure of `tvexpose`. Replace `TEMPLATE` with your actual command name when using these templates.

## Template Files

| File | Purpose |
|------|---------|
| `TEMPLATE.ado` | Main command file with placeholder code structure |
| `TEMPLATE.sthlp` | Help file in SMCL format |
| `TEMPLATE.pkg` | Package metadata for `net install` |
| `TEMPLATE.dlg` | Dialog file for GUI **(Optional - most commands don't need this)** |
| `TEMPLATE_README.md` | Package README.md documentation template |
| `testing_TEMPLATE.do` | Functional tests (does it run?) |
| `validation_TEMPLATE.do` | Validation tests (is it correct?) |

**Note**: Dialog files (`.dlg`) are rarely needed for modern Stata packages. Most users prefer command-line syntax. Only create dialogs if your command targets users who specifically need GUI access.

## Quick Start

```bash
# One-liner to set up a new command (from repo root):
.claude/scripts/scaffold-command.sh mycommand "Description of what it does"
```

This creates the directory structure, copies templates, and replaces placeholders automatically.

## Manual Setup

### 1. Copy and Rename Files

```bash
# Create your package directory
mkdir mycommand

# Copy templates
cp _devkit/_templates/TEMPLATE.ado mycommand/mycommand.ado
cp _devkit/_templates/TEMPLATE.sthlp mycommand/mycommand.sthlp
cp _devkit/_templates/TEMPLATE.pkg mycommand/mycommand.pkg
cp _devkit/_templates/TEMPLATE.dlg mycommand/mycommand.dlg
cp _devkit/_templates/TEMPLATE_README.md mycommand/README.md

# Copy test files to testing/validation directories
cp _devkit/_templates/testing_TEMPLATE.do _devkit/_testing/testing_mycommand.do
cp _devkit/_templates/validation_TEMPLATE.do _devkit/_validation/validation_mycommand.do
```

### 2. Search and Replace

Replace all instances of `TEMPLATE` with your command name in each file:

```stata
* In Stata or a text editor, replace:
*   TEMPLATE → mycommand
*   YYYY/MM/DD → actual date
*   Your Name → your name
*   etc.
```

### 3. Customize Each File

#### `.ado` File
- Update the header with version, description, author
- Modify the `syntax` statement for your options
- Implement your computation logic in the main section
- Update return values as needed

#### `.sthlp` File
- Write clear descriptions for each option
- Add realistic examples
- Document all stored results
- Update author information

#### `.pkg` File
- Update the description
- Set correct Distribution-Date (YYYYMMDD format)
- Add relevant keywords
- List all files to include

#### `.dlg` File (Dialog)
- The dialog template is kept more complete since dialog syntax is tricky
- Modify control names, labels, and positions
- Update the PROGRAM command section to build your syntax
- Test with `db mycommand` in Stata

#### `testing_TEMPLATE.do`
- Replace placeholder command calls with your actual command
- Add tests for each option your command supports
- Include edge case tests (single obs, missing values, empty data)
- Tests verify the command **runs** without errors

#### `validation_TEMPLATE.do`
- Create minimal datasets with known expected outputs
- Write tests that verify **computed values** match expected
- Use hand-calculable examples
- Tests verify the command produces **correct results**

#### `README.md`
- Update badges (Stata version, License, Status)
- Write clear description and examples
- Document all options and stored results
- Include installation command with correct path
- Use `<br>` for line breaks in Author section

## Testing vs Validation

| Testing | Validation |
|---------|------------|
| Does it **run** without errors? | Does it produce **correct** results? |
| Uses realistic datasets | Uses minimal hand-crafted datasets |
| Checks return codes, variable existence | Checks specific computed values |
| "The command executed successfully" | "The output value is exactly 5.0" |

Both are required for production-ready commands.

## Dialog File Tips (Optional/Advanced)

> **Most commands don't need dialog files.** Only create one if you specifically need GUI support.

The `.dlg` template is kept complete because dialog syntax is difficult for LLMs. Key patterns:

```stata
* Control naming convention
TEXT     tx_varname    x  y  width  height, label("Label")
VARNAME  vn_varname    x  y  width  height, option(optname)
CHECKBOX ck_option     x  y  width  height, option(optname)

* Positioning
@    = same as previous control
+20  = 20 pixels below previous
-20  = 20 pixels above previous
.    = auto/default

* In PROGRAM command section
require main.vn_var       // Required field
optionarg main.vn_var     // Outputs: , option(value)
option main.ck_option     // Outputs: option (if checked)
```

## Checklist Before Release

- [ ] All `TEMPLATE` placeholders replaced
- [ ] Version numbers consistent (X.Y.Z format)
- [ ] Distribution-Date updated in .pkg
- [ ] README.md has correct installation path and version
- [ ] README.md Author section uses `<br>` for line breaks
- [ ] All tests pass
- [ ] Help file examples work
- [ ] Dialog builds correct command syntax
