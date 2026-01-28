# Stata Development Documentation

Detailed reference documentation for Stata package development. These files supplement the quick reference in `CLAUDE.md`.

---

## Available Guides

| Document | Description | When to Use |
|----------|-------------|-------------|
| [syntax-reference.md](syntax-reference.md) | Macro functions, syntax patterns, loops | Writing complex .ado logic |
| [template-guide.md](template-guide.md) | Complete file templates | Creating new packages |
| [dialog-guide.md](dialog-guide.md) | Dialog file development | Creating .dlg files |
| [error-codes.md](error-codes.md) | Error code reference | Debugging and error handling |

---

## Quick Navigation

### I want to...

| Task | See |
|------|-----|
| Understand syntax statement options | `syntax-reference.md` → Syntax Statement Patterns |
| Use extended macro functions | `syntax-reference.md` → Extended Macro Functions |
| Create a new .ado file | `template-guide.md` → .ado File Template |
| Create a help file | `template-guide.md` → .sthlp File Template |
| Create a dialog file | `dialog-guide.md` |
| Handle a specific error code | `error-codes.md` |
| Understand marksample/markout | `syntax-reference.md` → Sample Marking |
| Parse option strings | `syntax-reference.md` → gettoken Parsing |

---

## Relationship to CLAUDE.md

`CLAUDE.md` provides:
- Critical rules (always follow)
- Quick reference (one-liners)
- Common pitfalls

These docs provide:
- Detailed explanations
- Complete templates
- Extended examples
- Deep reference material

**Workflow:**
1. Start with `CLAUDE.md` for rules and quick reference
2. Consult these docs for detailed information
3. Use skills (`/stata-develop`, etc.) for guided workflows

---

## Token Efficiency

These documents are designed for **on-demand loading**:
- Don't load all docs at session start
- Load specific sections when needed
- Use the table of contents to find relevant sections

Example: Instead of reading entire `syntax-reference.md`, load just the "gettoken Parsing" section when you need to parse option strings.

---

*Part of the Stata-Tools development kit*
