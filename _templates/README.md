# Stata Command Templates

This folder contains templates for creating new Stata commands, based on the structure of `tvexpose`. Replace `NAME` with your actual command name when using these templates.

## Template Files

| File | Purpose |
|------|---------|
| `template_NAME.ado` | Main command file with placeholder code structure |
| `template_NAME.sthlp` | Help file in SMCL format |
| `template_NAME.pkg` | Package metadata for `net install` |
| `template_NAME.dlg` | Dialog file for GUI (kept complete for reference) |
| `testing_NAME.do` | Functional tests (does it run?) |
| `validation_NAME.do` | Validation tests (is it correct?) |

## How to Use

### 1. Copy and Rename Files

```bash
# Create your package directory
mkdir mycommand

# Copy templates
cp _templates/template_NAME.ado mycommand/mycommand.ado
cp _templates/template_NAME.sthlp mycommand/mycommand.sthlp
cp _templates/template_NAME.pkg mycommand/mycommand.pkg
cp _templates/template_NAME.dlg mycommand/mycommand.dlg

# Copy test files to testing/validation directories
cp _templates/testing_NAME.do _testing/testing_mycommand.do
cp _templates/validation_NAME.do _validation/validation_mycommand.do
```

### 2. Search and Replace

Replace all instances of `NAME` with your command name in each file:

```stata
* In Stata or a text editor, replace:
*   NAME → mycommand
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

#### `testing_NAME.do`
- Replace placeholder command calls with your actual command
- Add tests for each option your command supports
- Include edge case tests (single obs, missing values, empty data)
- Tests verify the command **runs** without errors

#### `validation_NAME.do`
- Create minimal datasets with known expected outputs
- Write tests that verify **computed values** match expected
- Use hand-calculable examples
- Tests verify the command produces **correct results**

## Testing vs Validation

| Testing | Validation |
|---------|------------|
| Does it **run** without errors? | Does it produce **correct** results? |
| Uses realistic datasets | Uses minimal hand-crafted datasets |
| Checks return codes, variable existence | Checks specific computed values |
| "The command executed successfully" | "The output value is exactly 5.0" |

Both are required for production-ready commands.

## Dialog File Tips

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

- [ ] All `NAME` placeholders replaced
- [ ] Version numbers consistent (X.Y.Z format)
- [ ] Distribution-Date updated in .pkg
- [ ] All tests pass
- [ ] Help file examples work
- [ ] Dialog builds correct command syntax
