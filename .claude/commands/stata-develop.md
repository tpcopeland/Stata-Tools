Read the skill file `.claude/skills/stata-develop.md` and use it to guide creating or modifying Stata commands.

When the user wants to create a new command:
1. First ask for the command name and brief description
2. Run `.claude/scripts/scaffold-command.sh` to create the package
3. Guide them through customizing the generated files

When fixing bugs or adding features to existing commands:
1. Read the current .ado file
2. Apply the error patterns checklist from the skill
3. Make changes following the mandatory code structure
4. Update version numbers in all files
