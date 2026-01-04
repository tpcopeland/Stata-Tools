# Recommendations and Commentary

> **Purpose:** This document provides additional context, recommendations, and commentary for implementing the learning functionality system in a Stata package development repository.

---

## Executive Summary

This learning system was developed through extensive use in a research repository (Plans-and-Proposals) where we discovered that:

1. **AI assistants make the same mistakes repeatedly** without a memory system
2. **Logging errors pays off exponentially** - fix once, prevent forever
3. **Hook scripts are powerful** but need careful tuning
4. **Skills work best as "expertise hats"** rather than independent agents
5. **Token efficiency matters** - three-tier knowledge system prevents bloat

---

## Key Design Decisions

### 1. No Subagents Policy

**Why we don't use subagents:**

```
Problem: When using Task(subagent_type="...") for literature searches:
- Subagents hallucinated citations that didn't exist
- Results were inconsistent between invocations
- Token usage was 3-5x higher than direct calls
- Context was lost between main agent and subagent

Solution: Skills as "expertise hats"
- Main Claude session wears different "hats"
- All context stays in one thread
- WebSearch/WebFetch called directly
- Consistent, verifiable results
```

**For Stata package development:** You likely don't need literature search, but the same principle applies. Don't spawn subagents for code review - just load the code-reviewer skill instructions.

### 2. Three-Tier Knowledge System

```
┌─────────────────────────────────────────────────────────────┐
│ TIER 1: Skills (Always Loaded)          ~50 lines each     │
│ • 5-10 critical patterns per skill                          │
│ • Things that cause fatal errors                            │
│ • Loaded when skill is invoked                              │
├─────────────────────────────────────────────────────────────┤
│ TIER 2: Common Errors (Loaded at Skill Start)  ~200 lines  │
│ • Accumulated patterns from all packages                    │
│ • Reference tables and correct patterns                     │
│ • Skill explicitly loads this file                          │
├─────────────────────────────────────────────────────────────┤
│ TIER 3: Individual Logs (On-Demand)     Unlimited          │
│ • Full error documentation                                   │
│ • Only read when debugging specific issues                  │
│ • Never auto-loaded into context                            │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** If you put 500 lines of error patterns in every skill, you'll waste tokens. The tiered system ensures Claude only loads what's needed.

### 3. Hook Script Architecture

The hook system fires at specific lifecycle points:

```
SessionStart     → Show context, set expectations
UserPromptSubmit → Route to skills before work begins
PreToolUse       → Validate before dangerous operations
PostToolUse      → Format outputs, suggest skills
Stop             → End-of-session reminders
```

**Recommendation:** Start with all hooks disabled, enable one at a time, and watch for false positives.

---

## What Works Well

### Session Context Hook

The `session-context.sh` script is extremely valuable because:

- Sets expectations at the start of each session
- Shows recent work (what was I doing?)
- Highlights failures that need attention
- Reminds of available tools

**Enhancement idea:** Add a "last session summary" by parsing the previous session's stop hook output.

### Skill Routing from Prompts

The `user-prompt-skill-router.sh` catches most task types, but:

- **Tune the regex patterns** for your specific vocabulary
- **Keep patterns specific** - broad matches cause false positives
- **Test with real prompts** from your workflow

### Development Logs

The structured logging format ensures:

- Every error is documented with BEFORE/AFTER code
- Novel patterns are flagged for promotion
- Historical context is preserved

**Key insight:** The log template enforces completeness. Without it, documentation is inconsistent.

---

## What Needs Tuning

### Protected Files List

The `validate-operation.sh` script has a hardcoded list of protected files. You'll need to:

1. Add your critical files (stata.toc, .pkg files)
2. Remove files that don't apply
3. Decide what should BLOCK vs WARN

### Skill Routing Patterns

The patterns in `user-prompt-skill-router.sh` are tuned for our vocabulary. You'll likely need different patterns:

```bash
# Our patterns (research-focused):
["code-reviewer"]="review.*code|check.*stata|validate.*code|code.*correct"

# Your patterns might be (package-focused):
["code-reviewer"]="review.*ado|check.*package|validate.*command|debug"
```

### File Type Detection

The `suggest-skill-on-read.sh` hook suggests skills based on file extensions. Adjust for your file types:

```bash
# Add patterns for your files
*.ado|*.do)
    SUGGESTION="code-reviewer"
    ;;
*.sthlp|*.hlp)
    SUGGESTION="help-file-reviewer"
    ;;
```

---

## Additional Tools from Source Repo

These tools exist in the source repository and could be valuable:

### 1. Synthetic Test Data

**Location:** `_resources/data/synthetic/`

The source repo has 70+ synthetic data files for testing. For Stata packages, you might want:

- Sample datasets for each command
- Edge case data (missing values, duplicates, etc.)
- Large datasets for performance testing

**Recommendation:** Create a `tests/data/` directory with test datasets.

### 2. Code Templates

**Location:** `_resources/code_templates/`

The source repo has templates for different analysis types. For packages:

- Create `.ado` file templates
- Create `.sthlp` help file templates
- Create test file templates

**Already included:** The `stata-code-generator` skill has these embedded.

### 3. Publication/Literature System

**Not included** in this export because it's research-specific. But the pattern could be adapted:

- Store package documentation
- Track version history
- Index by functionality

### 4. AI Consultant Panel

**Location:** `.claude/skills/ai-consultant-panel/`

This skill consults GPT and Gemini as subordinate reviewers. Could be useful for:

- Getting second opinions on code
- Cross-validating syntax

**Caveat:** Requires API keys and setup. Not included in this export.

---

## Implementation Checklist

### Phase 1: Core Setup

- [ ] Copy CLAUDE.md to repo root
- [ ] Copy .claude/ directory
- [ ] Make scripts executable: `chmod +x .claude/scripts/*.sh`
- [ ] Test session-context.sh runs on startup

### Phase 2: Hook Testing

- [ ] Test each hook individually
- [ ] Adjust patterns for your vocabulary
- [ ] Add protected files for your repo
- [ ] Verify no false positives

### Phase 3: Skill Customization

- [ ] Review code-reviewer skill checklist
- [ ] Add package-specific patterns
- [ ] Create help-file-reviewer skill if needed
- [ ] Test skill invocation

### Phase 4: Learning System

- [ ] Create first development log manually
- [ ] Verify log template works
- [ ] Add initial error patterns to common-errors.md
- [ ] Test pattern detection in code-reviewer

### Phase 5: Refinement

- [ ] After 3-5 packages, review logs
- [ ] Distill patterns into common-errors.md
- [ ] Update skill checklists
- [ ] Archive old logs if needed

---

## Troubleshooting

### Hook Not Firing

1. Check script is executable: `ls -la .claude/scripts/`
2. Check settings.json syntax is valid JSON
3. Restart Claude Code session
4. Check Claude Code version supports hooks

### Skill Not Suggested

1. Check regex pattern matches your prompt
2. Test with `echo "your prompt" | grep -E "pattern"`
3. Patterns are case-insensitive (converted to lowercase)

### Protected File Blocking

1. Check exit code: 0 = warn only, 2 = block
2. Review patterns in validate-operation.sh
3. Add exceptions for maintenance files

---

## Future Enhancements

### Potential Additions

1. **Automated test runner** - Hook that runs tests after .ado edits
2. **Version bumper** - Automatically increment version in .ado files
3. **Help file validator** - Check .sthlp matches .ado options
4. **Package builder** - Assemble .pkg files from directory contents
5. **GitHub integration** - Auto-create releases from tags

### Community Contributions

If you develop useful extensions, consider:

- Creating a shared skills library
- Contributing patterns back to common-errors.md
- Documenting your workflow adaptations

---

## Contact and Support

This system was developed for internal use. If you have questions:

1. Review the source repository: Plans-and-Proposals
2. Check the skill files for patterns
3. Examine the hook scripts for logic

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-04 | Initial extraction and adaptation |
