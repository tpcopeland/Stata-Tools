*! test_runner_contracts.do -- runner receipts must prove actual test outcomes
*! Author: Timothy P Copeland, Karolinska Institutet
* budget: 30
version 17.0
clear all
set more off
capture log close _all
log using "test_runner_contracts.log", text replace name(_runner_contracts)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local outer_output "$TABTOOLS_QA_OUTPUT_DIR"
tempfile fixture_token
local fixture_root "`fixture_token'_runner_contracts"
local tests 0
local pass 0
local fail 0

* Each case runs the actual runner with a single deliberately controlled child.
* Only lane membership is narrowed in the scratch copy; verdict logic stays
* byte for byte identical to the runner under test (including --against runs).
python:
from pathlib import Path
import shutil
from sfi import Macro
src = Path(Macro.getLocal("pkg_dir"))
dst = Path(Macro.getLocal("fixture_root")) / "tabtools"
shutil.copytree(src, dst, ignore=shutil.ignore_patterns("qa", "demo", "*.log", "*.smcl"))
(dst / "qa" / "tools").mkdir(parents=True)
runner = (src / "qa" / "run_all.do").read_text()
assert runner.count("* Read skip list") == 1
runner = runner.replace("* Read skip list", 'local all_files "test_review_2026_10_01_runner_receipt.do"\n\n* Read skip list')
(dst / "qa" / "run_all.do").write_text(runner)
checker = src / "qa" / "tools" / "check_suite_result.py"
if checker.exists():
    shutil.copy2(checker, dst / "qa" / "tools" / checker.name)

end

**# Rc-zero children require reconciled, nonempty, unique receipts
foreach case in good wrap wrapnumber mismatch failed missing empty duplicate wrongname skipfull skipquick badrc screen stale core {
    local ++tests
    capture noisily {
        clear
        set obs 1
        generate double marker = 1
        local wanted_rc 1
        local mode full
        if inlist("`case'", "good", "wrap", "wrapnumber", "skipquick", "screen", "core") local wanted_rc 0
        if "`case'" == "skipquick" local mode quick
        if "`case'" == "core" local mode core
        local orig_plus "`c(sysdir_plus)'"
        local orig_personal "`c(sysdir_personal)'"
        python script "`qa_dir'/tools/runner_fixture.py", args("`case'" "`fixture_root'/tabtools/qa")
        cd "`fixture_root'/tabtools/qa"
        log off _runner_contracts
        capture noisily do run_all.do `mode'
        local actual_rc = _rc
        log on _runner_contracts
        global TABTOOLS_QA_OUTPUT_DIR "`outer_output'"
        python script "`qa_dir'/tools/runner_fixture.py", args("restore" "`fixture_root'/tabtools/qa")
        cd "`qa_dir'"
        assert `actual_rc' == `wanted_rc'
        assert "`c(sysdir_plus)'" == "`orig_plus'"
        assert "`c(sysdir_personal)'" == "`orig_personal'"
    }
    local case_rc = _rc
    global TABTOOLS_QA_OUTPUT_DIR "`outer_output'"
    quietly cd "`qa_dir'"
    if `case_rc' {
        local ++fail
        display as error "FAIL: runner `case' (rc=`case_rc')"
    }
    else {
        local ++pass
        display as result "PASS: runner `case'"
    }
}

**# Unknown or surplus lane arguments are refused before installation
foreach arguments in "unknown" "full unexpected" {
    local ++tests
    capture noisily {
        clear
        cd "`fixture_root'/tabtools/qa"
        log off _runner_contracts
        capture noisily do run_all.do `arguments'
        local argument_rc = _rc
        log on _runner_contracts
        global TABTOOLS_QA_OUTPUT_DIR "`outer_output'"
        cd "`qa_dir'"
        assert `argument_rc' == 198
    }
    local argument_test_rc = _rc
    global TABTOOLS_QA_OUTPUT_DIR "`outer_output'"
    quietly cd "`qa_dir'"
    if `argument_test_rc' {
        local ++fail
        display as error "FAIL: runner rejects `arguments' arguments"
    }
    else {
        local ++pass
        display as result "PASS: runner rejects `arguments' arguments"
    }
}

python:
import shutil
from sfi import Macro
shutil.rmtree(Macro.getLocal("fixture_root"))
end
display "RESULT: test_runner_contracts tests=`tests' pass=`pass' fail=`fail'"
log close _runner_contracts
if `fail' exit 1
