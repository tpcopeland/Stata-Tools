# compress_tc QA

Run `stata-mp -b do run_all.do [quick|core|full]` from this directory. The runner isolates PLUS/PERSONAL.

archetypes: A7(compress_tc)

## Suites

| File | Coverage | Lanes |
| --- | --- | --- |
| `test_compress_tc.do` | Functional tests: strL conversion, `nostrl`/`nocompress`/`minlength()`/`dryrun`/`report` modes, returns and data preservation | quick/core/full |
| `test_compress_tc_report.do` | `report` table arithmetic, explanatory notes, dryrun-vs-real agreement and `lowmem` notes | quick/core/full |
| `test_compress_tc_errors.do` | Mutually exclusive modes, negative `minlength()` and empty-data behaviour | quick/core/full |
| `test_compress_tc_hostile.do` | Hostile inputs: 32-character names under `dryrun`, constant variables, repeated calls, numeric-only data | quick/core/full |
| `test_compress_tc_documentation_examples.do` | Every example in `compress_tc.sthlp` run verbatim with a result contract | quick/core/full |
| `validation_compress_tc.do` | Known-answer validation of storage types, byte savings and value preservation | core/full |
| `crossval_compress_tc.do` | Cross-validation against plain `compress`, manual `recast strL` + `compress` and `memory` | full |
| `test_compress_tc_oracle.do` | Randomized preservation oracle (seed 26082304, 200 repetitions) | full |

## Canonical fixture adoption

All labelled fixture variants preserve every cell, labels and date format; exact memory arithmetic, dryrun and invalid-option fingerprints. These are implemented suites; independent adoption signoff is pending. Remaining unexercised public routes and generic minima remain visible in the fixture census.

| File | Coverage | Lanes |
| --- | --- | --- |
| `validation_compress_tc_fixture_contract.do` | Canonical fixture truth and hostile contracts | core/full |
| `validation_compress_tc_fixture_primitives.do` | Every actual hostile name/code/string value survives compression; full dryrun state, exact inclusive244-byte minlength boundary and negative refusal | core/full |

## Numerical precision suites

These suites compare actual returned, dataset, text or workbook values to independently derived numerical truth. Lane membership below follows the existing runner; full-lane results after these additions remain unverified.

| File | Scope | Cases | Lanes |
| --- | --- | --- | --- |
| `validation_compress_tc_precision.do` | Signed/tiny/large/near-one doubles and exact storage types survive compression. | 2 | core/full |
