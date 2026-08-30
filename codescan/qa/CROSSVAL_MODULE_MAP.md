# codescan cross-validation module map

`crossval_codescan_icd10.do` compares `codescan` with Stata's independently implemented official `icd10 generate` classifier on the fixed public Australian mortality example. All compared outputs are discrete indicators or counts, so every parity assertion is exact; there is no numeric tolerance or expected-difference tier.

## Sources

| Source | Role |
|---|---|
| Stata Press Release 17 `australia10.dta` | Fixed 3,322-row public ICD-10 fixture used by Stata's documentation |
| Stata `[D] icd10` | Independent row-level ICD range classifier and dotted-code normalizer |
| Quan et al. (2005), Tables 1–2, doi:10.1097/01.mlr.0000182534.19832.83 | Published ICD-10 comorbidity definitions and inclusion boundaries |

## Cross-validation to known-answer mapping

| Cross-validation module | Independent comparison | Known-answer counterpart |
|---|---|---|
| CV1 | Fixed public fixture contract | K1 pins rows and total deaths |
| CV2 | Official manual cancer range, row by row | K4 pins matching rows and deaths |
| CV3 | Five Quan definitions, row by row | K2 pins rows and deaths; K3 pins sex-stratified counts; K7 pins adjacent boundaries |
| CV4 | Official dotted-code normalization plus classification | Existing `nodots` validation remains the internal invariant layer |
| CV5 | Three official one-variable scans summed per wide record | K5 pins total slots, positive records, and the incomplete final record |
| CV6 | Official explicit malignancy codelist versus include/exclude scanning | K7 supplies study-derived boundary cases |
| CV7 | Session settings preserved | Every new suite repeats the same hygiene contract |

## Other validation axes

The existing `validation_codescan*`, `validation_countrows`, and `validation_mata` suites cover date windows, collapse and merge behavior, output artifacts, Mata equivalence, generated-data recovery, and adversarial inventories. They have no direct `icd10` equivalent and remain Stata-only known-answer or invariant checks.

## Revision triggers

Re-resolve the pinned answers and review this map if the fixed Stata Press URL changes, Stata changes `icd10 generate` range semantics, the Quan definitions are replaced, or `codescan` changes prefix, exclusion, `nodots`, or `countmode` behavior.
