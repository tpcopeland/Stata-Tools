# Error Pattern Catalog

## Category 1: Macro Errors

| Pattern | Detection | Fix |
|---------|-----------|-----|
| Missing backticks | Variable name without backticks after `local` | Add backticks |
| Unclosed quote | Count backticks != single quotes | Close quotes |
| Name > 31 chars | Count characters | Shorten name |
| Nested macro error | Complex `` `\`var'' `` patterns | Verify nesting |

## Category 2: Structure Errors

| Pattern | Detection | Fix |
|---------|-----------|-----|
| No version | First 10 lines lack `version` | Add version |
| No varabbrev off | Missing after version | Add statement |
| No marksample | Has if/in but no marksample | Add marksample |
| No obs check | Has marksample but no count | Add check |

## Category 3: Tempvar Errors

| Pattern | Detection | Fix |
|---------|-----------|-----|
| No declaration | Creates permanent vars in program | Use tempvar |
| No backticks | `gen tempname` after tempvar decl | Add backticks |
| Unnecessary drop | `drop \`tempvar'` | Remove (auto-dropped) |

## Category 4: Error Handling

| Pattern | Detection | Fix |
|---------|-----------|-----|
| Unchecked capture | `capture` without `_rc` | Add check |
| Stale _rc | Commands between capture and if | Save _rc immediately |
| Wrong error code | Non-standard codes | Use Stata conventions |

## Category 5: Batch Mode

| Pattern | Detection | Fix |
|---------|-----------|-----|
| cls | Interactive command | Remove |
| pause | Interactive command | Remove |
| browse | Interactive command | Remove |
| edit | Interactive command | Remove |

## Category 6: Cross-File

| Check | Files | How |
|-------|-------|-----|
| Version number | .ado, .sthlp, .pkg, README | All must match X.Y.Z |
| Syntax | .ado syntax line vs .sthlp | Must match exactly |
| Options | .ado syntax vs .sthlp synoptset | All documented |
| Returns | .ado return statements vs .sthlp results | All documented |

## Common Stata Error Codes

| Code | Meaning | Common Cause |
|------|---------|--------------|
| 100 | varlist required | Empty varlist |
| 109 | type mismatch | Numeric/string confusion |
| 110 | already defined | Missing replace option |
| 111 | variable not found | Typo or wrong scope |
| 198 | invalid syntax | Syntax parsing failed |
| 601 | file not found | Wrong path |
| 2000 | no observations | if/in eliminated all obs |
