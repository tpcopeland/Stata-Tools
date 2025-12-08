# Stata-Tools Testing Framework

This directory contains comprehensive test suites for all Stata commands in the Stata-Tools repository.

## Quick Start

```stata
* Change to testing directory
cd "_testing"

* Generate test data (required first)
do generate_test_data.do

* Run all tests
do run_all_tests.do
```

## Directory Structure

```
_testing/
├── README.md                    # This file
├── TESTING_INSTRUCTIONS.md      # Detailed instructions for Claude testing
├── generate_test_data.do        # Creates synthetic test datasets
├── generate_test_data.ado       # Program for data generation
├── run_all_tests.do             # Master test runner
│
├── Test Files (19):
│   ├── test_tvexpose.do         # 37 tests - tvexpose command
│   ├── test_tvmerge.do          # 16 tests - tvmerge command
│   ├── test_tvevent.do          # 13 tests - tvevent command
│   ├── test_datamap.do          # 28 tests - datamap command
│   ├── test_datadict.do         # 21 tests - datadict command
│   ├── test_synthdata.do        # 35 tests - synthdata command
│   ├── test_mvp.do              # 45 tests - mvp command
│   ├── test_table1_tc.do        # 24 tests - table1_tc command
│   ├── test_consort.do          # 5 tests - consort command
│   ├── test_consortq.do         # consortq tests
│   ├── test_regtab.do           # 6 tests - regtab command
│   ├── test_cstat_surv.do       # 4 tests - cstat_surv command
│   ├── test_stratetab.do        # 2 tests - stratetab command
│   ├── test_compress_tc.do      # compress_tc tests
│   ├── test_datefix.do          # datefix tests
│   ├── test_check.do            # check tests
│   ├── test_today.do            # today tests
│   ├── test_migrations.do       # migrations tests
│   └── test_sustainedss.do      # sustainedss tests
│
└── docker/                       # Docker configuration for sandboxed testing
    ├── Dockerfile
    ├── docker-compose.yml
    ├── entrypoint.sh
    ├── .env.example
    ├── .dockerignore
    └── README.md
```

## Test Data Files

After running `generate_test_data.do`, these files are created:

| File | Description | Records |
|------|-------------|---------|
| `cohort.dta` | Patient cohort with demographics, dates, outcomes | 1,000 patients |
| `hrt.dta` | HRT exposure records | Variable |
| `dmt.dta` | DMT exposure records | Variable |
| `hospitalizations.dta` | Hospitalization events | Variable |
| `migrations_wide.dta` | Swedish migration registry format | Variable |
| `edss_long.dta` | EDSS progression data | Variable |

## Running Tests

### Individual Test Files

```stata
cd "_testing"
do test_tvexpose.do
```

### All Tests

```stata
cd "_testing"
do run_all_tests.do
```

### With Logging

```stata
cd "_testing"
log using "test_results.log", replace
do run_all_tests.do
log close
```

## Test Structure

Each test file follows this pattern:

```stata
* Setup
clear all
set more off
version 16.0

* Check prerequisites
capture confirm file "cohort.dta"
if _rc {
    display as error "Run generate_test_data.do first"
    exit 601
}

* Initialize counters
local test_count = 0
local pass_count = 0
local fail_count = 0

* Test cases
local ++test_count
capture noisily {
    * Test code here
    assert condition
    local ++pass_count
}
if _rc {
    local ++fail_count
}

* Summary
display "Total: `test_count' Passed: `pass_count' Failed: `fail_count'"
```

## Test Coverage Summary

| Package | Command | Tests | Coverage |
|---------|---------|-------|----------|
| tvtools | tvexpose | 37 | Complete |
| tvtools | tvmerge | 16 | Complete |
| tvtools | tvevent | 13 | Complete |
| datamap | datamap | 28 | Excellent |
| datamap | datadict | 21 | Excellent |
| synthdata | synthdata | 35 | Excellent |
| mvp | mvp | 45 | Excellent |
| table1_tc | table1_tc | 24 | Good |
| consort | consort | 5 | Partial |
| regtab | regtab | 6 | Good |
| cstat_surv | cstat_surv | 4 | Good |
| stratetab | stratetab | 2 | Partial |
| compress_tc | compress_tc | 4 | Partial |
| datefix | datefix | 4 | Good |
| check | check | 6 | Complete |
| today | today | 4 | Partial |
| setools | migrations | 3 | Partial |
| setools | sustainedss | 5 | Partial |

## Docker Setup for Claude Code Testing

For sandboxed testing with Claude Code via Stata-MCP:

```bash
cd _testing/docker
cp .env.example .env
# Edit .env with your Stata-MCP path
docker-compose build
docker-compose up -d
```

See `docker/README.md` for detailed instructions.

## For Claude Sonnet Testing

If you are Claude Sonnet running autonomous testing:

1. Read `TESTING_INSTRUCTIONS.md` for detailed guidance
2. Ensure test data exists (run `generate_test_data.do`)
3. Run tests in dependency order:
   - tvexpose → tvmerge → tvevent (tvtools suite)
   - Other commands can run in any order
4. Report failures with full error context

## Adding New Tests

1. Create test file: `test_commandname.do`
2. Follow the test structure pattern above
3. Add to `run_all_tests.do`
4. Update this README

## Troubleshooting

### "Test data not found"
```stata
do generate_test_data.do
```

### "Command not found"
```stata
adopath ++ "../packagename"
```

### Test fails with assertion error
Check the exact error code and compare expected vs actual values.

## License

MIT License - See repository root
