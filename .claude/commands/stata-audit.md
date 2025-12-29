Read the skill file `.claude/skills/stata-audit.md` and use it to audit Stata .ado files.

When auditing an .ado file:
1. Run the quick error detection checklist from the skill
2. Check for all common error patterns:
   - Missing backticks on macro references
   - Macro names > 31 characters
   - Missing marksample/markout
   - Unchecked capture statements
   - Tempvars without backticks
3. Verify cross-file consistency (versions in .ado/.sthlp/.pkg/README)
4. Trace logic for complex sections using mental execution

If you can run `.claude/hooks/validate-ado.sh`:
```bash
.claude/hooks/validate-ado.sh command.ado
```

Generate an audit report following the template in the skill with:
- Summary table of issues by category and severity
- Detailed findings with line numbers and fixes
- Recommendations
- Verification checklist
