*! test_package_fixtures.do
*! Inventory, provenance, schema, and checksum contracts for tracked fixtures.

clear all
set varabbrev off
set more off
version 16.0

capture log close _all
quietly log using "test_package_fixtures.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local manifest "$TVTOOLS_QA_DIR/fixtures_manifest.tsv"
tempfile manifest_data

**# Manifest shape

local ++test_count
capture noisily {
    confirm file "`manifest'"
    import delimited using "`manifest'", delimiters(tab) ///
        varnames(1) stringcols(_all) clear
    confirm variable fixture sha256 bytes rows columns schema producer ///
        consumers classification
    assert _N == 217
    isid fixture
    save `manifest_data'
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' shape"
}

**# Exact tracked inventory

local ++test_count
capture noisily {
    use `manifest_data', clear
    local fixture_files : dir "$TVTOOLS_QA_DIR/data" files "*.dta"
    local fixture_count : word count `fixture_files'
    assert `fixture_count' == _N
    foreach fixture of local fixture_files {
        count if fixture == "`fixture'"
        assert r(N) == 1
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' inventory"
}

**# Independent checksum and schema recomputation

local ++test_count
capture noisily {
    local status "$TVTOOLS_QA_RUN_DIR/fixture_manifest_status.txt"
    local validator_log "$TVTOOLS_QA_RUN_DIR/fixture_manifest_validator.log"
    capture erase "`status'"
    capture erase "`validator_log'"
    shell python3 "$TVTOOLS_QA_DIR/tools/fixture_manifest.py" --check ///
        --qa-dir "$TVTOOLS_QA_DIR" --status "`status'" ///
        > "`validator_log'" 2>&1
    confirm file "`status'"
    local status_text = strtrim(fileread("`status'"))
    assert strpos("`status_text'", "OK fixtures=217") == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' checksums_schemas"
}

**# Producer/consumer and lifecycle classification

local ++test_count
capture noisily {
    use `manifest_data', clear
    assert producer != ""
    assert consumers != ""
    assert schema != ""
    assert strlen(sha256) == 64
    assert regexm(sha256, "^[0-9a-f]+$")
    assert inlist(classification, "canonical", "disposable")
    assert classification == "canonical"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' provenance"
}

**# Summary

display "RESULT: test_package_fixtures tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "fixture-contract failures:`failed_tests'"
    exit 1
}
