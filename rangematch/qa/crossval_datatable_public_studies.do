* crossval_datatable_public_studies.do - overlap parity on public study data
*
* Independent oracle: data.table::foverlaps(). Public datasets: the built-in R
* ChickWeight longitudinal experiment and survival::pbcseq follow-up data. The
* R companion exports the inputs and computes every expected pair at runtime.
clear all
version 16.1
set varabbrev off

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
local qa_dir "`r(qa_dir)'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# Oracle generation
tempfile ref_probe
local ref_dir "`ref_probe'_datatable"
mkdir "`ref_dir'"
local r_script "`qa_dir'/crossval_datatable_public_studies_r.R"

local ++test_count
capture noisily {
    confirm file "`r_script'"
    shell Rscript "`r_script'" "`ref_dir'"
    confirm file "`ref_dir'/R_OK"
    foreach stem in chick_master chick_using chick_expected ///
            pbc_master pbc_using pbc_expected {
        confirm file "`ref_dir'/`stem'.csv"
    }
}
if _rc == 0 {
    display as result "PASS: data.table public-study oracles generated"
    local ++pass_count
}
else {
    display as error "FAIL: Rscript with data.table and survival is required"
    local ++fail_count
    local failed_tests "`failed_tests' oracle"
}

if `fail_count' > 0 {
    display "RESULT: crossval_datatable_public_studies tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

tempfile chick_master chick_using chick_expected
import delimited using "`ref_dir'/chick_master.csv", clear varnames(1)
save "`chick_master'", replace
import delimited using "`ref_dir'/chick_using.csv", clear varnames(1)
save "`chick_using'", replace
import delimited using "`ref_dir'/chick_expected.csv", clear varnames(1)
sort master_id using_id
save "`chick_expected'", replace

tempfile pbc_master pbc_using pbc_expected
import delimited using "`ref_dir'/pbc_master.csv", clear varnames(1)
save "`pbc_master'", replace
import delimited using "`ref_dir'/pbc_using.csv", clear varnames(1)
save "`pbc_using'", replace
import delimited using "`ref_dir'/pbc_expected.csv", clear varnames(1)
sort master_id using_id
save "`pbc_expected'", replace

**# ChickWeight point observations within grouped growth phases
local ++test_count
capture noisily {
    use "`chick_master'", clear
    local n_master = _N
    assert `n_master' == 151
    rangematch time phase_lo phase_hi using "`chick_using'", ///
        by(chick diet) keepusing(using_id weight) ///
        unmatched(none) closed(both) stats
    local got_pairs = r(N_matched_pairs)
    local got_matched_master = r(N_matched_master)
    local got_unmatched_master = r(N_unmatched_master)
    assert r(N_using) == 578
    assert r(N_pairs) == r(N_matched_pairs)

    keep master_id using_id
    sort master_id using_id
    cf _all using "`chick_expected'"

    use "`chick_expected'", clear
    local expected_pairs = _N
    contract master_id
    local expected_matched_master = _N
    assert `got_pairs' == `expected_pairs'
    assert `got_matched_master' == `expected_matched_master'
    assert `got_unmatched_master' == `n_master' - `expected_matched_master'
    assert `got_pairs' == 578
    * Three chicks have no observation in one phase; the fourth empty window is
    * the deliberately absent chick 999 group.
    assert `got_unmatched_master' == 4
}
if _rc == 0 {
    display as result "PASS: ChickWeight phase pairs match data.table::foverlaps"
    local ++pass_count
}
else {
    display as error "FAIL: ChickWeight phase pairs differ from data.table::foverlaps"
    local ++fail_count
    local failed_tests "`failed_tests' ChickWeight"
}

**# pbcseq irregular visit spells overlapping follow-up windows
local ++test_count
capture noisily {
    use "`pbc_master'", clear
    local n_master = _N
    assert `n_master' == 161
    rangematch window_lo window_hi using "`pbc_using'", ///
        overlap(spell_lo spell_hi) by(id) keepusing(using_id bili albumin) ///
        unmatched(none) closed(both) stats
    local got_pairs = r(N_matched_pairs)
    local got_matched_master = r(N_matched_master)
    local got_unmatched_master = r(N_unmatched_master)
    * `>' alone passes on missing: Stata orders missing above every finite
    * number, so a using load that returned nothing would satisfy it.
    assert r(N_using) < . & r(N_using) > 250
    assert r(N_pairs) == r(N_matched_pairs)
    assert "`r(backend)'" == "overlap"

    keep master_id using_id
    sort master_id using_id
    cf _all using "`pbc_expected'"

    use "`pbc_expected'", clear
    local expected_pairs = _N
    contract master_id
    local expected_matched_master = _N
    assert `got_pairs' == `expected_pairs'
    assert `got_matched_master' == `expected_matched_master'
    assert `got_unmatched_master' == `n_master' - `expected_matched_master'
    assert `got_pairs' > 300
    assert `got_unmatched_master' > 1
}
if _rc == 0 {
    display as result "PASS: pbcseq spell overlaps match data.table::foverlaps"
    local ++pass_count
}
else {
    display as error "FAIL: pbcseq spell overlaps differ from data.table::foverlaps"
    local ++fail_count
    local failed_tests "`failed_tests' pbcseq"
}

**# Summary
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
}
else {
    display as result "ALL DATA.TABLE PUBLIC-STUDY CROSS-VALIDATIONS PASSED"
}
display "RESULT: crossval_datatable_public_studies tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
