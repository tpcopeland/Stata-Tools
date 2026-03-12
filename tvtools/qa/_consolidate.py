#!/usr/bin/env python3
"""
Consolidate tvtools test and validation .do files into two unified files.

Reads all test_*.do and validation_*.do files, extracts test blocks,
organizes by command, and writes consolidated test_tvtools.do and
validation_tvtools.do.
"""

import re
import os
from pathlib import Path
from collections import defaultdict

QA_DIR = Path(__file__).parent
DATA_DIR = QA_DIR / "data"

# ============================================================================
# Configuration: which files map to which command sections
# ============================================================================

# Test files grouped by command (order = section order in output)
TEST_FILE_GROUPS = {
    "tvage": [
        "test_tvage.do",
        "test_tvage_fixes.do",
        "test_tvage_v111.do",
    ],
    "tvbalance": [
        "test_tvbalance.do",
    ],
    "tvestimate": [
        "test_tvestimate.do",
    ],
    "tvevent": [
        "test_tvevent.do",
        "test_tvevent_keepvars_fix.do",
        "test_tvevent_stress.do",
    ],
    "tvexpose": [
        "test_tvexpose.do",
        "test_tvexpose_stress.do",
        "test_tvexpose_v142_fixes.do",
    ],
    "tvmerge": [
        "test_tvmerge.do",
        "test_tvmerge_stress.do",
    ],
    "tvtrial": [
        "test_tvtrial.do",
    ],
    "tvweight": [
        "test_tvweight.do",
    ],
    # Cross-cutting files (tvcalendar, tvdiagnose, tvplot, integration, errors)
    "_cross_cutting": [
        "test_tvtools_gold.do",
        "test_tvtools_review.do",
        "test_tvtools_comprehensive.do",
        "test_tvtools_review_fixes.do",
        "test_tvtools_review_fixes2.do",
        "test_tvtools_secondary.do",
    ],
}

# Validation files grouped by command
VALIDATION_FILE_GROUPS = {
    "tvage": [
        "validation_tvage_mathematical.do",
    ],
    "tvbalance": [
        "validation_tvbalance_mathematical.do",
    ],
    "tvestimate": [
        "validation_tvestimate.do",
    ],
    "tvevent": [
        "validation_tvevent.do",
        "validation_tvevent_mathematical.do",
        "validation_tvevent_registry.do",
    ],
    "tvexpose": [
        "validation_tvexpose.do",
        "validation_tvexpose_mathematical.do",
        "validation_tvexpose_options_untested.do",
        "validation_tvexpose_registry.do",
    ],
    "tvmerge": [
        "validation_tvmerge.do",
        "validation_tvmerge_mathematical.do",
        "validation_tvmerge_registry.do",
    ],
    "tvweight": [
        "validation_tvweight.do",
        "validation_tvweight_mathematical.do",
    ],
    "_cross_cutting": [
        "validation_tvtools_boundary.do",
        "validation_tvtools_bugfixes.do",
        "validation_tvtools_comprehensive.do",
        "validation_tvtools_gold.do",
        "validation_tvtools_pipeline.do",
        "validation_tvtools_pipeline_mathematical.do",
        "validation_tvtools_pipeline_stress.do",
    ],
}

# Files to skip (helpers, data generators, debug)
SKIP_FILES = {
    "validation_helpers.do",
    "_debug_pt.do",
    "_consolidate.py",
}


def find_test_body_bounds(lines):
    """Find the start and end line indices of the test body in a .do file.

    Start: after the last counter initialization line (local xxx_count = 0)
    End: before the summary/footer section
    """
    start_idx = 0
    end_idx = len(lines)

    # Find start: look for last counter initialization or run_only setup
    for i, line in enumerate(lines):
        stripped = line.strip()
        # Counter initialization patterns
        if re.match(r'local\s+(test_count|pass_count|fail_count|run_only)\s*=\s*0', stripped):
            start_idx = i + 1
        if re.match(r'global\s+(TEST_COUNT|PASS_COUNT|FAIL_COUNT|test_count|pass_count|fail_count)\s*=\s*0', stripped):
            start_idx = i + 1
        if stripped == '_test_start':
            start_idx = i + 1
        # Also skip blank lines and comments right after init
        if re.match(r'local\s+failed_tests\s*""', stripped):
            start_idx = i + 1
        if re.match(r'local\s+failed_tests\s*$', stripped):
            start_idx = i + 1

    # Find end: look for summary section
    for i in range(len(lines) - 1, max(start_idx, 0), -1):
        stripped = lines[i].strip()
        # Summary patterns (search from bottom up)
        if any(pat in stripped.lower() for pat in [
            'test results', 'test summary', 'summary', 'all tests passed',
            'tests run:', 'passed:', 'failed:', '_test_summary',
            'display as text "tests run"', 'display as result "all',
        ]):
            # Found a summary line - look for the section header above it
            for j in range(i, max(start_idx, i - 10), -1):
                stripped_j = lines[j].strip()
                if re.match(r'\*\s*=+', stripped_j) or re.match(r'display as text _dup', stripped_j):
                    end_idx = j
                    break
            else:
                end_idx = i
            break

    # Skip leading blank lines
    while start_idx < end_idx and lines[start_idx].strip() == '':
        start_idx += 1

    # Skip trailing blank lines
    while end_idx > start_idx and lines[end_idx - 1].strip() == '':
        end_idx -= 1

    return start_idx, end_idx


def clean_body(body):
    """Clean extracted test body: remove setup lines, normalize counters."""
    cleaned_lines = []
    for line in body.splitlines(True):
        stripped = line.strip()

        # Remove lines that belong in the header, not the body
        if re.match(r'clear\s+all\b', stripped):
            cleaned_lines.append(line.replace('clear all', 'clear'))
            continue
        if re.match(r'(capture\s+)?ado\s+uninstall', stripped):
            continue
        if re.match(r'(capture\s+)?(quietly\s+)?net\s+(install|uninstall)', stripped):
            continue
        if re.match(r'(capture\s+)?net\s+install', stripped):
            continue
        if re.match(r'set\s+more\s+off', stripped):
            continue
        if re.match(r'set\s+varabbrev\s+off', stripped):
            continue
        if re.match(r'version\s+\d+', stripped):
            continue
        if stripped == '_test_start':
            continue
        if re.match(r'do\s+"?validation_helpers', stripped):
            continue
        if re.match(r'do\s+"?\.\./validation_helpers', stripped):
            continue
        if re.match(r'global\s+DATA_DIR\b', stripped):
            continue
        if re.match(r'global\s+failed_tests\s', stripped):
            cleaned_lines.append(line.replace('global', 'local'))
            continue

        cleaned_lines.append(line)

    body = ''.join(cleaned_lines)

    # Normalize counter patterns to use local variables
    body = re.sub(r'global\s+(TEST_COUNT|test_count)\s*=\s*\$\1\s*\+\s*1',
                  r'local ++test_count', body)
    body = re.sub(r'global\s+(PASS_COUNT|pass_count)\s*=\s*\$\1\s*\+\s*1',
                  r'local ++pass_count', body)
    body = re.sub(r'global\s+(FAIL_COUNT|fail_count)\s*=\s*\$\1\s*\+\s*1',
                  r'local ++fail_count', body)
    # Also handle $test_count patterns in display statements
    body = body.replace('$TEST_COUNT', '`test_count\'')
    body = body.replace('$PASS_COUNT', '`pass_count\'')
    body = body.replace('$FAIL_COUNT', '`fail_count\'')
    body = body.replace('$test_count', '`test_count\'')
    body = body.replace('$pass_count', '`pass_count\'')
    body = body.replace('$fail_count', '`fail_count\'')

    # Replace _test_result calls with inline counter pattern
    # Pattern: _test_result _rc "Test name" or _test_result `rc' "Test name"
    def replace_test_result(match):
        rc_var = match.group(1)
        test_name = match.group(2)
        indent = match.group(3) if match.group(3) else ''
        return (
            f'local ++test_count\n'
            f'if {rc_var} == 0 {{\n'
            f'    display as result "  PASS: {test_name}"\n'
            f'    local ++pass_count\n'
            f'}}\n'
            f'else {{\n'
            f'    display as error "  FAIL: {test_name}"\n'
            f'    local ++fail_count\n'
            f'}}'
        )
    body = re.sub(
        r'(\s*)_test_result\s+(_rc|`\w+\')\s+"([^"]+)"',
        lambda m: replace_test_result(m) if m.group(0) else m.group(0),
        body
    )
    # Simpler replacement for _test_result calls
    body = re.sub(
        r'_test_result\s+(_rc|`\w+\')\s+"([^"]+)"',
        lambda m: (
            f'local ++test_count\n'
            f'if {m.group(1)} == 0 {{\n'
            f'    display as result "  PASS: {m.group(2)}"\n'
            f'    local ++pass_count\n'
            f'}}\n'
            f'else {{\n'
            f'    display as error "  FAIL: {m.group(2)}"\n'
            f'    local ++fail_count\n'
            f'}}'
        ),
        body
    )

    # Remove _test_summary calls
    body = re.sub(r'\s*_test_summary\s*\n?', '\n', body)

    return body


def extract_test_body(filepath):
    """Extract the test body from a .do file, stripping header/footer."""
    if not filepath.exists():
        print(f"  WARNING: {filepath} not found, skipping")
        return ""

    with open(filepath, 'r') as f:
        lines = f.readlines()

    start, end = find_test_body_bounds(lines)
    body = ''.join(lines[start:end])

    return clean_body(body)


def build_section_header(section_num, command_name, description):
    """Build a section header comment block."""
    return f"""
* =============================================================================
* SECTION {section_num}: {command_name.upper()} - {description}
* =============================================================================
"""


def write_test_file(output_path, file_groups):
    """Write the consolidated test file."""

    sections = []
    section_num = 0

    command_descriptions = {
        "tvage": "Age interval creation and grouping",
        "tvbalance": "Covariate balance and SMD calculation",
        "tvestimate": "Weighted regression estimation",
        "tvevent": "Event splitting and interval construction",
        "tvexpose": "Time-varying exposure creation",
        "tvmerge": "Multi-dataset interval merging",
        "tvtrial": "Trial emulation cloning and censoring",
        "tvweight": "IPTW weight calculation",
        "_cross_cutting": "Cross-cutting, integration, and error handling",
    }

    for command, files in file_groups.items():
        section_num += 1
        desc = command_descriptions.get(command, command)
        header = build_section_header(section_num, command, desc)

        file_bodies = []
        for fname in files:
            filepath = QA_DIR / fname
            print(f"  Processing {fname}...")
            body = extract_test_body(filepath)
            if body.strip():
                file_bodies.append(f"* --- From {fname} ---\n\n{body}")

        if file_bodies:
            section_content = header + "\n".join(file_bodies)
            sections.append(section_content)

    # Write the file
    with open(output_path, 'w') as f:
        f.write(TEST_HEADER)
        f.write("\n".join(sections))
        f.write(TEST_FOOTER)

    print(f"  Written to {output_path}")
    print(f"  {section_num} sections from {sum(len(v) for v in file_groups.values())} files")


def write_validation_file(output_path, file_groups):
    """Write the consolidated validation file."""

    sections = []
    section_num = 0

    command_descriptions = {
        "tvage": "Age interval mathematical validation",
        "tvbalance": "SMD formula and weighted balance validation",
        "tvestimate": "Weighted regression validation",
        "tvevent": "Event splitting and person-time conservation",
        "tvexpose": "Exposure tracking and person-time validation",
        "tvmerge": "Merge correctness and person-time additivity",
        "tvweight": "IPTW weight properties validation",
        "_cross_cutting": "Pipeline, boundary, bugfix, and stress validation",
    }

    for command, files in file_groups.items():
        section_num += 1
        desc = command_descriptions.get(command, command)
        header = build_section_header(section_num, command, desc)

        file_bodies = []
        for fname in files:
            filepath = QA_DIR / fname
            print(f"  Processing {fname}...")
            body = extract_test_body(filepath)
            if body.strip():
                file_bodies.append(f"* --- From {fname} ---\n\n{body}")

        if file_bodies:
            section_content = header + "\n".join(file_bodies)
            sections.append(section_content)

    with open(output_path, 'w') as f:
        f.write(VALIDATION_HEADER)
        f.write("\n".join(sections))
        f.write(VALIDATION_FOOTER)

    print(f"  Written to {output_path}")
    print(f"  {section_num} sections from {sum(len(v) for v in file_groups.values())} files")


# ============================================================================
# File templates
# ============================================================================

TEST_HEADER = """/*******************************************************************************
* test_tvtools.do
*
* Purpose: Consolidated functional tests for all tvtools commands
*
* Commands tested:
*   tvage, tvbalance, tvcalendar, tvdiagnose, tvestimate, tvevent,
*   tvexpose, tvmerge, tvplot, tvtools, tvtrial, tvweight
*
* Usage:
*   cd ~/Stata-Tools/tvtools/qa
*   do test_tvtools.do
*
*   To run a single test:
*   local run_only = N
*   do test_tvtools.do
*
* Author: Timothy P Copeland
* Date: 2026-03-12
*******************************************************************************/

clear all
set more off
set varabbrev off
version 16.0

* Path configuration
global DATA_DIR "`c(pwd)'/data"

* Install tvtools from package root
capture ado uninstall tvtools
quietly net install tvtools, from("`c(pwd)'/..") replace

* Generate test data if needed
capture confirm file "${DATA_DIR}/cohort.dta"
if _rc != 0 {
    cd data
    do generate_test_data.do
    cd ..
}

* Initialize test counters
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local run_only = 0

display as text ""
display as text "tvtools Functional Test Suite"
display as text "Date: $S_DATE $S_TIME"
display as text ""

"""

TEST_FOOTER = """

* =============================================================================
* TEST RESULTS SUMMARY
* =============================================================================

display as text ""
display as text "tvtools Test Results"
display as text ""
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display as text ""

if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
"""

VALIDATION_HEADER = """/*******************************************************************************
* validation_tvtools.do
*
* Purpose: Consolidated validation tests for all tvtools commands
*          Mathematical correctness, known-answer tests, registry scenarios
*
* Commands validated:
*   tvage, tvbalance, tvestimate, tvevent, tvexpose, tvmerge, tvweight
*   Plus pipeline integration and boundary condition validation
*
* Usage:
*   cd ~/Stata-Tools/tvtools/qa
*   do validation_tvtools.do
*
* Author: Timothy P Copeland
* Date: 2026-03-12
*******************************************************************************/

clear all
set more off
set varabbrev off
version 16.0

* Path configuration
global DATA_DIR "`c(pwd)'/data"

* Install tvtools from package root
capture ado uninstall tvtools
quietly net install tvtools, from("`c(pwd)'/..") replace

* Generate test data if needed
capture confirm file "${DATA_DIR}/cohort.dta"
if _rc != 0 {
    cd data
    do generate_test_data.do
    cd ..
}

* Load validation helpers
do validation_helpers.do

* Initialize test counters
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local quiet = 0

display as text ""
display as text "tvtools Validation Test Suite"
display as text "Date: $S_DATE $S_TIME"
display as text ""

"""

VALIDATION_FOOTER = """

* =============================================================================
* VALIDATION RESULTS SUMMARY
* =============================================================================

display as text ""
display as text "tvtools Validation Results"
display as text ""
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display as text ""

if `fail_count' > 0 {
    display as error "VALIDATION FAILED: `failed_tests'"
    exit 1
}
else {
    display as result "ALL VALIDATIONS PASSED"
}
"""


# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("Consolidating tvtools test files")
    print("=" * 60)

    print("\n--- Building test_tvtools.do ---")
    write_test_file(QA_DIR / "test_tvtools_NEW.do", TEST_FILE_GROUPS)

    print("\n--- Building validation_tvtools.do ---")
    write_validation_file(QA_DIR / "validation_tvtools_NEW.do", VALIDATION_FILE_GROUPS)

    print("\n" + "=" * 60)
    print("Done! Review the _NEW.do files, then rename to replace originals.")
    print("=" * 60)
