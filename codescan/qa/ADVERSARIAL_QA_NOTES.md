# Adversarial QA Notes

This audit added the following adversarial and known-answer suites:

- `test_codescan_adversarial.do`
- `test_codescan_describe_adversarial.do`
- `test_codescan_install_docs.do`
- `test_codescan_stress_adversarial.do`
- `test_release_integrity.do`
- `validation_builtin_codefiles.do`
- `validation_codescan_describe_adversarial.do`
- `validation_codescan_known_answers.do`

All of these suites are integrated into `qa/run_all.do`.

## Resolved findings

- Baseline `test_codescan.do` partial-label coverage now expects fallback labels to use the condition name, matching command behavior.
- `run_all.do` restores `c(pwd)` to the QA directory after each suite, preventing install-smoke tests from poisoning downstream path derivation.
- Generated `.log`, `.dta`, `.xlsx`, and scratch `.csv` QA artifacts were removed after validation.
- Built-in basename codefile fallback now matches the shipped Charlson and Elixhauser CSV definitions.

## Added stress coverage

The adversarial suites concentrate coverage on wide varlists, sparse strings, punctuation and regular-expression metacharacters, case variation, missing IDs and dates, duplicate IDs, numeric `tostring`, output-name collisions, invalid option combinations, repeated calls in one session, installation behavior, documentation examples, release metadata, and shipped-codefile known answers.
