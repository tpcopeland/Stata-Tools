# Development Kit

This directory contains all internal development resources, testing infrastructure, and quality assurance materials for the Stata-Tools repository. These files are not distributed as Stata packages but support command development, testing, and validation.

## Directory Structure

```
_devkit/
├── _templates/         # Templates for creating new Stata commands
│   ├── TEMPLATE.ado    # Command implementation template
│   ├── TEMPLATE.sthlp  # Help file template
│   ├── TEMPLATE.pkg    # Package metadata template
│   ├── TEMPLATE.dlg    # Dialog file template (optional)
│   ├── TEMPLATE_README.md
│   ├── testing_TEMPLATE.do
│   └── validation_TEMPLATE.do
│
├── _testing/           # Functional test suites
│   ├── generate_test_data.do   # Creates synthetic test datasets
│   ├── run_all_tests.do        # Master test runner
│   ├── test_*.do               # Individual command tests
│   └── data/                   # Test datasets
│
├── _validation/        # Validation tests (correctness verification)
│   ├── validation_*.do         # Tests with hand-calculated expected values
│   ├── run_all_validation.do   # Master validation runner
│   └── data/                   # Validation datasets
│
└── _resources/         # Development support materials
    ├── context/        # Reference documentation
    ├── logs/           # Log templates
    └── templates/      # Additional templates
```

## Quick Start

### Creating a New Command

```bash
# Automated (recommended)
.claude/scripts/scaffold-command.sh mycommand "Description of what it does"

# Manual
cp _devkit/_templates/TEMPLATE.ado newpackage/newpackage.ado
# ... edit and customize
```

### Running Tests

```stata
cd "_devkit/_testing"
do generate_test_data.do   // First time only
do run_all_tests.do        // Run all functional tests
```

### Running Validations

```stata
cd "_devkit/_validation"
do run_all_validation.do   // Run all validation tests
```

## Testing vs Validation

| Aspect | Testing | Validation |
|--------|---------|------------|
| Question | Does the command **run** without errors? | Does the command produce **correct** results? |
| Data | Realistic synthetic datasets | Minimal hand-crafted datasets |
| Checks | Return codes, variable existence | Specific computed values |
| Example | "Command executed successfully" | "Output value is exactly 5.0" |

**Both are required for production-ready commands.**

## Subdirectory Details

### _templates/

Templates based on established patterns from working commands. Includes:
- Complete `.ado` structure with header, syntax parsing, and return values
- SMCL help file with all required sections
- Package metadata for `net install`
- Test file templates for both functional and validation testing

See `_templates/README.md` for detailed usage instructions.

### _testing/

Functional tests that verify commands execute without errors:
- 17+ test files covering all major commands
- 300+ individual test cases
- Test data generator for reproducible synthetic datasets
- Support for Docker-based sandboxed testing

See `_testing/README.md` for test coverage and running instructions.

### _validation/

Validation tests that verify computational correctness:
- Known-answer tests with hand-calculable expected values
- Invariant tests (e.g., subsetting shouldn't change results)
- Boundary condition tests
- Monte Carlo validation for statistical properties

### _resources/

Supporting materials for development:
- Common Stata error patterns and solutions
- Development log templates
- Context files for AI-assisted development

## Related Automation

The `.claude/` directory contains automation scripts that work with these resources:

| Script | Purpose |
|--------|---------|
| `.claude/scripts/scaffold-command.sh` | Create complete package structure from templates |
| `.claude/scripts/check-versions.sh` | Verify version consistency across files |
| `.claude/scripts/check-test-coverage.sh` | Report test/validation coverage |
| `.claude/validators/validate-ado.sh` | Static analysis of .ado files |
| `.claude/validators/run-stata-check.sh` | Syntax check with Stata runtime |

## License

MIT License - See repository root
