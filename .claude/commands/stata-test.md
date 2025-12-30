Read the skill file `.claude/skills/stata-test.md` and use it to guide writing functional tests.

When creating tests for a command:
1. Check if test file exists in `_testing/test_COMMANDNAME.do`
2. If not, copy from `_templates/testing_TEMPLATE.do` and customize
3. Follow the test file structure from the skill
4. Include all required test categories:
   - Basic functionality
   - Option tests (one per option)
   - Error handling (expected failures)
   - Return value tests
   - Edge cases (single obs, missing, empty)
   - Data preservation

For debugging failing tests:
1. Use quiet mode to find failures: `do run_test.do COMMAND . quiet`
2. Run single failing test: `do run_test.do COMMAND N`
3. If needed, suggest using `set trace on` for deep debugging
