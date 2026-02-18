# Template Catalog

## Available Templates

| Template | Purpose | Location |
|----------|---------|----------|
| TEMPLATE.ado | Main command with full structure | `_devkit/_templates/` |
| TEMPLATE.sthlp | Help file with all sections | `_devkit/_templates/` |
| TEMPLATE.pkg | Package metadata | `_devkit/_templates/` |
| TEMPLATE.dlg | Dialog with common controls | `_devkit/_templates/` |
| TEMPLATE_README.md | README with badges and formatting | `_devkit/_templates/` |
| testing_TEMPLATE.do | Functional test structure | `_devkit/_templates/` |
| validation_TEMPLATE.do | Validation test structure | `_devkit/_templates/` |

## Required Files for a New Command

```
mycommand/
├── mycommand.ado       # Main command
├── mycommand.sthlp     # Help file
├── mycommand.pkg       # Package metadata
├── stata.toc           # Table of contents
├── mycommand.dlg       # Dialog (optional)
└── README.md           # Documentation
```

## SMCL Quick Reference

- `{cmd:text}` - command style (bold blue)
- `{opt option}` - option style
- `{it:text}` - italic
- `{bf:text}` - bold
- `{p_end}` - end paragraph
- `{synopt:{opt name}}desc{p_end}` - option in synoptset table
- `{phang2}` - hanging indent for examples
