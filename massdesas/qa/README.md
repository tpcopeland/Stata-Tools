# massdesas QA

The QA suite tests local installation, SAS-to-Stata conversion, error paths, documentation examples, and hostile filesystem inputs. `run_all.do` is the curated full release gate; each test file is independently runnable from this directory.

## How to run

```bash
cd massdesas/qa
stata-mp -b do run_all.do              # full release gate
stata-mp -b do test_massdesas_hostile.do
```

## Isolation

The suites install `massdesas`, `filelist`, and `fs` into process-specific temporary PLUS/PERSONAL directories through `_massdesas_qa_common.do`. Run in an isolated scratch copy when another lane could write `qa/*.log` concurrently.

## Conventions

- `test_*` covers functional and regression behavior; `validation_*` covers known-answer invariants; no independent cross-validation suite is present.
- Each suite ends with `RESULT: <name> tests=N pass=N fail=N [skip=N]` and exits nonzero on a failure.
- `_massdesas_qa_common.do` sandboxes PLUS/PERSONAL and restores them after a suite.
- Paths derive from `c(pwd)`; temporary SAS and Stata files are generated at runtime.
- Generated logs and conversion outputs are runtime artifacts and are not tracked.

## Dependencies

| Suite | Needs | If missing |
|---|---|---|
| Functional, validation, and hostile suites | `filelist`, `fs`, `Rscript`, and R `haven` | hard failure after the bootstrap attempts installation |

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_massdesas.do` | Installation, conversion, errors, paths, CWD, varabbrev, and data preservation |
| `test_documentation_examples.do` | Executable help-file conversion examples |
| `test_massdesas_hostile.do` | Missing and empty directories, 31-character filenames, spaces, extended missing values, and caller-state preservation |
| `test_massdesas_errors.do` | Exact parser, missing-directory, and empty-directory error contracts with CWD, data, order, and varabbrev preservation |
| `test_massdesas_documentation_exact.do` | Literal documentation command-line and setup-contract checks |
| `test_massdesas_oracle.do` | Independent conversion-output oracle checks |

### Validation

| File | Covers |
|---|---|
| `validation_massdesas.do` | Returned conversion counts and converted-data invariants |

### Support

| Path | Contents |
|---|---|
| `run_all.do`, `_massdesas_qa_common.do` | Curated runner and isolated-install bootstrap |

## Coverage map

| Command | Functional | Validation | Also exercised in |
|---|---|---|---|
| `massdesas` | `test_massdesas.do`, hostile and error-contract suites | `validation_massdesas.do` | Documentation-example and independent-oracle suites |

## Lane membership

`full` is the default release gate.

| Lane | Suites |
|---|---|
| `full` | The explicit suite list in `run_all.do` |
