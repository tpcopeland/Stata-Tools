Read the skill file `.claude/skills/stata-validate.md` and use it to guide writing validation tests.

When creating validation tests:
1. Check if validation file exists in `_validation/validation_COMMANDNAME.do`
2. If not, copy from `_templates/validation_TEMPLATE.do` and customize
3. Create minimal datasets with **known expected values**
4. Write tests that verify computed values match expected (not just execution)

Key validation principles:
1. **Known-Answer Testing**: Create data where you can hand-calculate expected results
2. **Invariant Testing**: Properties that must always hold (proportions 0-1, conservation)
3. **Boundary Testing**: Test at exact edges (zero, max, missing)
4. **Comparison Testing**: Compare to known-good implementations

Always use tolerances for floating-point comparisons:
```stata
assert abs(r(result) - expected) < 0.001
```
