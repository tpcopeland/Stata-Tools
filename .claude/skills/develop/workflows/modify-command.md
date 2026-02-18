# Modify Existing Command Workflow

## Step 1: Understand Current State
1. Read the .ado file
2. Read the .sthlp file
3. Check existing tests
4. Note current version

## Step 2: Plan Changes
- What options/features to add?
- What return values change?
- What edge cases to handle?

## Step 3: Implement
1. Add new syntax options
2. Add validation for new inputs
3. Implement new logic
4. Update return values

## Step 4: Update Documentation
1. Update .sthlp with new options
2. Update examples
3. Update stored results section
4. Update README.md

## Step 5: Version Bump
- Bug fix: increment PATCH (1.0.0 -> 1.0.1)
- New feature: increment MINOR (1.0.0 -> 1.1.0)
- Breaking change: increment MAJOR (1.0.0 -> 2.0.0)
- Update ALL files: .ado, .sthlp, .pkg, README.md

## Step 6: Validate
1. Run `/reviewer`
2. Update existing tests
3. Add new tests for new features
4. Run all tests
