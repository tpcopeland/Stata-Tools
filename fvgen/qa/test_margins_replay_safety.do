*! test_margins_replay_safety.do — Side-effect and null-case guards for the fvgen margins replay
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+

clear all
set varabbrev off
version 16.0

* fvgen, margins reruns e(cmdline). These tests pin what the replay must
* refuse (file-writing saving() options, mi estimate), what it must show on
* failure (the estimator's own error message), and the null cases where no
* replayable estimation result exists (r(301)).
do _fvgen_qa_common.do
_fvgen_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Builds the flattened auto model and leaves its varlist in global FVQA_AV.
capture program drop _fvqa_rs_data
program define _fvqa_rs_data
    version 16.0
    sysuse auto, clear
    quietly fvgen i.foreign##c.mpg
    global FVQA_AV `r(allvars)'
end

* Records a saved file's checksum and variable list in globals.
capture program drop _fvqa_rs_fileprint
program define _fvqa_rs_fileprint
    version 16.0
    args path stub
    quietly checksum `"`path'"'
    global `stub'_ck = r(checksum)
    quietly describe using `"`path'"', varlist
    global `stub'_vl `"`r(varlist)'"'
end

* simulate worker: one flattened regression per replication.
capture program drop _fvqa_rs_sim
program define _fvqa_rs_sim
    version 16.0
    regress price `0'
end

* Posts an eclass result with a chosen degenerate shape (null-case fixtures).
capture program drop _fvqa_rs_post
program define _fvqa_rs_post, eclass
    version 16.0
    args shape
    if "`shape'" == "nob" {
        ereturn clear
        ereturn local cmd "regress"
        ereturn local cmdline "regress price $FVQA_AV"
    }
    else if "`shape'" == "nov" {
        tempname b
        matrix `b' = e(b)
        ereturn post `b'
        ereturn local cmd "regress"
        ereturn local cmdline "regress price $FVQA_AV"
    }
    else if "`shape'" == "nocmdline" {
        ereturn local cmdline ""
    }
end

**# 1. bootstrap prefix saving(, replace): refused, saved file untouched
local ++test_count
capture noisily {
    _fvqa_rs_data
    tempfile bs
    set seed 101
    quietly bootstrap, reps(20) saving("`bs'", replace): regress price $FVQA_AV
    _fvqa_rs_fileprint "`bs'" FVQA_BS
    local cmd_before `"`e(cmdline)'"'
    _fvgen_qa_assert_error, rc(198) msg(saving()-type option) : fvgen, margins
    _fvqa_rs_fileprint "`bs'" FVQA_BS2
    assert "$FVQA_BS_ck" == "$FVQA_BS2_ck"
    assert `"$FVQA_BS_vl"' == `"$FVQA_BS2_vl"'
    assert strpos(`"$FVQA_BS2_vl"', "_b_foreign_1") > 0
    * the flattened estimate stays active
    assert `"`e(cmdline)'"' == `"`cmd_before'"' & "`e(fvgen_margins)'" == ""
}
if _rc == 0 {
    display as result "  PASS: bootstrap saving(, replace) refused, file untouched"
    local ++pass_count
}
else {
    display as error "  FAIL: bootstrap saving(, replace) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# 2. saving() without replace: refused with 198, not the estimator's 602
local ++test_count
capture noisily {
    _fvqa_rs_data
    tempfile bs
    set seed 102
    quietly bootstrap, reps(10) saving("`bs'"): regress price $FVQA_AV
    _fvqa_rs_fileprint "`bs'" FVQA_BS
    _fvgen_qa_assert_error, rc(198) msg(saving()-type option) : fvgen, margins
    _fvqa_rs_fileprint "`bs'" FVQA_BS2
    assert "$FVQA_BS_ck" == "$FVQA_BS2_ck"
}
if _rc == 0 {
    display as result "  PASS: saving() without replace refused before replay"
    local ++pass_count
}
else {
    display as error "  FAIL: saving() without replace (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# 3. jackknife prefix saving(): refused, file untouched
local ++test_count
capture noisily {
    _fvqa_rs_data
    tempfile jk
    quietly jackknife, saving("`jk'", replace): regress price $FVQA_AV
    _fvqa_rs_fileprint "`jk'" FVQA_JK
    _fvgen_qa_assert_error, rc(198) msg(saving()-type option) : fvgen, margins
    _fvqa_rs_fileprint "`jk'" FVQA_JK2
    assert "$FVQA_JK_ck" == "$FVQA_JK2_ck"
    assert `"$FVQA_JK_vl"' == `"$FVQA_JK2_vl"'
}
if _rc == 0 {
    display as result "  PASS: jackknife saving() refused, file untouched"
    local ++pass_count
}
else {
    display as error "  FAIL: jackknife saving() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# 4. vce(bootstrap, saving()) suboption and the sa() abbreviation: refused
local ++test_count
capture noisily {
    _fvqa_rs_data
    tempfile vb
    set seed 104
    quietly regress price $FVQA_AV, vce(bootstrap, reps(10) saving("`vb'", replace))
    _fvqa_rs_fileprint "`vb'" FVQA_VB
    _fvgen_qa_assert_error, rc(198) msg(saving()-type option) : fvgen, margins
    _fvqa_rs_fileprint "`vb'" FVQA_VB2
    assert "$FVQA_VB_ck" == "$FVQA_VB2_ck"

    _fvqa_rs_data
    tempfile ab
    set seed 105
    quietly bootstrap, reps(10) sa("`ab'", replace): regress price $FVQA_AV
    _fvqa_rs_fileprint "`ab'" FVQA_AB
    _fvgen_qa_assert_error, rc(198) msg(saving()-type option) : fvgen, margins store(fvqa_ab)
    _fvqa_rs_fileprint "`ab'" FVQA_AB2
    assert "$FVQA_AB_ck" == "$FVQA_AB2_ck"
    capture estimates describe fvqa_ab
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: vce(bootstrap, saving()) and sa() abbreviation refused"
    local ++pass_count
}
else {
    display as error "  FAIL: vce() saving suboption / abbreviation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# 5. no false positive: a variable whose name starts with sav still replays
local ++test_count
capture noisily {
    sysuse auto, clear
    generate double savings = weight / 1000
    generate double sa_x = turn
    quietly fvgen i.foreign##c.mpg
    local av `r(allvars)'
    quietly regress price `av' savings sa_x, robust
    tempname bflat
    matrix `bflat' = e(b)
    fvgen, margins
    assert "`e(fvgen_margins)'" == "1"
    assert !missing(_b[savings]) & !missing(_b[sa_x])
    assert !missing(`bflat'[1, colnumb(`bflat', "savings")]) & !missing(`bflat'[1, colnumb(`bflat', "sa_x")])
    assert reldif(_b[savings], `bflat'[1, colnumb(`bflat', "savings")]) < 1e-10
    assert reldif(_b[sa_x], `bflat'[1, colnumb(`bflat', "sa_x")]) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: sav* variable names are not mistaken for saving()"
    local ++pass_count
}
else {
    display as error "  FAIL: sav* variable false positive (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# 6. mi estimate, post: refused by name, not replayed as the inner command
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 106
    replace weight = . in 1/5
    quietly fvgen i.foreign##c.mpg
    local av `r(allvars)'
    quietly mi set wide
    quietly mi register imputed weight
    quietly mi impute regress weight price mpg, add(2)
    quietly mi estimate, post: regress price `av' weight
    assert "`e(mi)'" == "mi"
    _fvgen_qa_assert_error, rc(198) msg(cannot replay mi estimate) : fvgen, margins
    assert "`e(mi)'" == "mi" & "`e(fvgen_margins)'" == ""
}
if _rc == 0 {
    display as result "  PASS: mi estimate results refused by name"
    local ++pass_count
}
else {
    display as error "  FAIL: mi estimate refusal (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**# 7. a failed replay shows the estimator's own error message
* jackknife, keep adds pseudovalue variables; the replay cannot recreate them,
* and the user must see why (variable already defined), not only the rc.
local ++test_count
capture noisily {
    _fvqa_rs_data
    quietly jackknife, keep: regress price $FVQA_AV
    local cmd_before `"`e(cmdline)'"'
    _fvgen_qa_assert_error, rc(110) msg(already defined) : fvgen, margins
    _fvgen_qa_assert_error, rc(110) msg(could not rerun the estimator) : fvgen, margins
    assert `"`e(cmdline)'"' == `"`cmd_before'"' & "`e(fvgen_margins)'" == ""
}
if _rc == 0 {
    display as result "  PASS: replay failure shows the estimator's error"
    local ++pass_count
}
else {
    display as error "  FAIL: replay failure message (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**# 8. permute and simulate leave nothing replayable: refused, no file touched
local ++test_count
capture noisily {
    _fvqa_rs_data
    tempfile pm
    set seed 108
    quietly permute foreign _b[mpg], reps(5) saving("`pm'", replace): regress price $FVQA_AV
    _fvqa_rs_fileprint "`pm'" FVQA_PM
    capture fvgen, margins
    assert _rc == 301
    _fvqa_rs_fileprint "`pm'" FVQA_PM2
    assert "$FVQA_PM_ck" == "$FVQA_PM2_ck"

    _fvqa_rs_data
    tempfile sm
    set seed 109
    quietly simulate _b, reps(3) saving("`sm'", replace): _fvqa_rs_sim $FVQA_AV
    _fvqa_rs_fileprint "`sm'" FVQA_SM
    _fvgen_qa_assert_error, rc(198) msg(requires fvgen term provenance) : fvgen, margins
    _fvqa_rs_fileprint "`sm'" FVQA_SM2
    assert "$FVQA_SM_ck" == "$FVQA_SM2_ck"
}
if _rc == 0 {
    display as result "  PASS: permute and simulate refused, files untouched"
    local ++pass_count
}
else {
    display as error "  FAIL: permute/simulate (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**# 9. null case: no active estimates
local ++test_count
capture noisily {
    _fvqa_rs_data
    ereturn clear
    _fvgen_qa_assert_error, rc(301) msg(requires active estimation results) : fvgen, margins
    capture fvgen, margins
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: null case, no active estimates -> r(301)"
    local ++pass_count
}
else {
    display as error "  FAIL: null case, no active estimates (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**# 10. null case: missing metadata e(b), e(V), e(cmdline)
local ++test_count
capture noisily {
    _fvqa_rs_data
    quietly regress price $FVQA_AV
    _fvqa_rs_post nob
    _fvgen_qa_assert_error, rc(301) msg(with e(b)) : fvgen, margins

    quietly regress price $FVQA_AV
    _fvqa_rs_post nov
    _fvgen_qa_assert_error, rc(301) msg(with e(V)) : fvgen, margins

    quietly regress price $FVQA_AV
    _fvqa_rs_post nocmdline
    _fvgen_qa_assert_error, rc(301) msg(requires e(cmdline)) : fvgen, margins
    capture fvgen, margins
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: null case, missing metadata e(b)/e(V)/e(cmdline) -> r(301)"
    local ++pass_count
}
else {
    display as error "  FAIL: null case, missing metadata (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

macro drop FVQA_*

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED:`failed_tests'"
    display "RESULT: test_margins_replay_safety tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_margins_replay_safety tests=`test_count' pass=`pass_count' fail=`fail_count'"
