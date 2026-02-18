# New Command Workflow

## Step 1: Scaffold
```bash
.claude/scripts/scaffold-command.sh mycommand "Brief description"
```

Or manually:
1. Create directory: `mycommand/`
2. Copy templates from `_devkit/_templates/`
3. Replace all `TEMPLATE` with command name
4. Update dates and descriptions

## Step 2: Implement
1. Define syntax with required/optional options
2. Add marksample + markout + obs check
3. Implement main logic using tempvars
4. Set return values
5. Display results

## Step 3: Help File
1. Update .sthlp with SMCL formatting
2. Document all options
3. Add examples
4. List stored results

## Step 4: Package Files
1. Update .pkg with file list and Distribution-Date
2. Verify stata.toc entry
3. Write README.md

## Step 5: Validate
1. Run validate-ado.sh
2. Run check-versions.sh
3. Invoke `/reviewer`
4. Create tests with `/test`
5. Run tests with stata-mp
