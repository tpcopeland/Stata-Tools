*! test_tvmerge_idname.do
*! Contract pins for tvmerge's output-key name.
*!
*! tvmerge renames the caller's id() variable to the literal name `id' for its
*! internal work. Before 1.9.1 it committed the result under that name, so a
*! cohort keyed on pid came back keyed on id and every downstream tvtools call
*! -- tvevent, tvdiagnose, tvweight, a second tvmerge -- needed a rename
*! spliced in between. tvexpose has always restored its id()/start()/stop()
*! names on the way out. idname() closes the gap.
*!
*! Axes probed, and why each one is here:
*!   M1-M2   the default is unchanged. This option is additive; a released
*!           script that never mentions idname() must see the byte-identical
*!           result it saw before, including r().
*!   M3-M5   idname() renames the committed key, and only the key: values,
*!           storage type, format, variable label, and row order are the ones
*!           the default run produced. A rename that also re-sorted, or that
*!           lost the label, would still "work" by a name check alone.
*!   M6      the chaining case the option exists for -- tvmerge straight into
*!           tvevent on the caller's own key, with no intervening rename.
*!   M7      a second tvmerge over a tvmerge result, same reason.
*!   M8-M12  the refusals. idname() must be a legal name, must differ from
*!           startname()/stopname(), and must not collide with an internal
*!           name, an exposure output name, or a keep() output name. Each is
*!           checked BEFORE any source is opened, so a rejected call leaves
*!           the caller's data untouched -- M12 asserts that, because a
*!           collision caught late would already have replaced it.
*!   M13     the diagnostic listings use the committed key name too. They read
*!           from tempfiles built after the rename; a listing still headed
*!           `id' would mean one of them was built before it.
*!   M14     r(idname) is returned and matches the committed schema.

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvmerge_idname.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TVM_PASS = 0
global TVM_FAIL = 0
global TVM_FAILED ""
local test_count = 0

display as result "tvtools QA: tvmerge idname() -- $S_DATE $S_TIME"

capture program drop _tvm_check
program define _tvm_check
    args ok label detail
    if `ok' {
        global TVM_PASS = $TVM_PASS + 1
        display as result "  PASS `label'"
    }
    else {
        global TVM_FAIL = $TVM_FAIL + 1
        global TVM_FAILED "$TVM_FAILED `label'"
        display as error "  FAIL `label': `detail'"
    }
end

* Two interval sources on a key deliberately NOT named id, plus a variable
* label and a display format on it, so a rename that drops metadata shows up.
* Built at top level: an `input' block inside `program define' would end the
* program at its own `end'.
clear
quietly input long pid double a_start double a_stop byte drug
    1 100 199 1
    1 250 399 2
    2 120 260 1
    3 100 400 2
end
label variable pid "Person identifier"
format pid %9.0g
quietly save "srcA.dta", replace

clear
quietly input long pid double b_start double b_stop byte care
    1 150 299 1
    1 300 449 2
    2 100 200 2
    3 150 350 1
end
label variable pid "Person identifier"
format pid %9.0g
quietly save "srcB.dta", replace

clear
quietly input long pid double evt_dt
    1 260
    2 150
    3 300
end
quietly save "evts.dta", replace

**# M1 the default output key is still the literal name id
local ++test_count
clear
quietly tvmerge "srcA.dta" "srcB.dta", id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drug care)
capture confirm variable id, exact
local has_id = (_rc == 0)
capture confirm variable pid, exact
local no_pid = (_rc != 0)
local ok = (`has_id' & `no_pid')
_tvm_check `ok' "M1 the default committed key is still named id" ///
    "id_present=`has_id' pid_absent=`no_pid'"

quietly datasignature
local base_sig "`r(datasignature)'"
quietly ds
local base_vars "`r(varlist)'"
local base_start "`r(startname)'"
quietly save "base.dta", replace
local base_n = _N

**# M2 the default run returns no idname surprise and matches the old surface
local ++test_count
clear
quietly tvmerge "srcA.dta" "srcB.dta", id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drug care)
local ret_idname "`r(idname)'"
local ok = ("`ret_idname'" == "id")
_tvm_check `ok' "M2 r(idname) is id when the option is not specified" ///
    "r(idname)=`ret_idname'"

**# M3 idname() renames the committed key
local ++test_count
clear
quietly tvmerge "srcA.dta" "srcB.dta", id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drug care) idname(pid)
capture confirm variable pid, exact
local has_pid = (_rc == 0)
capture confirm variable id, exact
local no_id = (_rc != 0)
local ok = (`has_pid' & `no_id')
_tvm_check `ok' "M3 idname(pid) commits the key under that name" ///
    "pid_present=`has_pid' id_absent=`no_id'"

**# M4 only the name changed: values, order, and the rest of the schema
local ++test_count
local named_n = _N
quietly ds
local named_vars "`r(varlist)'"
local expect_vars = subinstr("`base_vars'", "id", "pid", 1)
rename pid id
quietly datasignature
local named_sig "`r(datasignature)'"
local ok = ("`named_sig'" == "`base_sig'" & `named_n' == `base_n' & ///
    "`named_vars'" == "`expect_vars'")
_tvm_check `ok' ///
    "M4 idname() changes the key name and nothing else" ///
    "sig=`named_sig' vs `base_sig'; vars=`named_vars' vs `expect_vars'; N=`named_n' vs `base_n'"

**# M5 the key keeps its storage type, format, and variable label
local ++test_count
clear
quietly tvmerge "srcA.dta" "srcB.dta", id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drug care) idname(pid)
local named_type : type pid
local named_fmt : format pid
local named_lbl : variable label pid
quietly use "base.dta", clear
local base_type : type id
local base_fmt : format id
local base_lbl : variable label id
local ok = ("`named_type'" == "`base_type'" & "`named_fmt'" == "`base_fmt'" & ///
    "`named_lbl'" == "`base_lbl'")
_tvm_check `ok' ///
    "M5 the renamed key keeps its type, format, and variable label" ///
    "type=`named_type'/`base_type' fmt=`named_fmt'/`base_fmt' lbl=`named_lbl'/`base_lbl'"

**# M6 the chaining case: tvmerge straight into tvevent, no rename between
* tvevent takes the event data as the master in memory and the intervals as
* using, and id() must resolve in both. The event file is keyed on pid, so the
* merged intervals have to be too. This is the whole reason the option exists,
* so the test asserts BOTH directions: it works with idname(pid) and fails
* without it. Only the pair is evidence -- a passing chain alone would not
* show that the default was ever a problem.
local ++test_count
clear
quietly tvmerge "srcA.dta" "srcB.dta", id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drug care) idname(pid)
local mrg_start "`r(startname)'"
local mrg_stop "`r(stopname)'"
local mrg_id "`r(idname)'"
quietly save "merged_named.dta", replace

quietly use "evts.dta", clear
capture noisily tvevent using "merged_named.dta", id(`mrg_id') ///
    start(`mrg_start') stop(`mrg_stop') date(evt_dt) generate(_fail)
local chain_rc = _rc
capture confirm variable _fail
local chain_var = (_rc == 0)
capture confirm variable pid, exact
local chain_key = (_rc == 0)

clear
quietly tvmerge "srcA.dta" "srcB.dta", id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drug care)
quietly save "merged_default.dta", replace
quietly use "evts.dta", clear
capture tvevent using "merged_default.dta", id(pid) start(start) stop(stop) ///
    date(evt_dt) generate(_fail)
local default_rc = _rc

local ok = (`chain_rc' == 0 & `chain_var' & `chain_key' & `default_rc' != 0)
_tvm_check `ok' ///
    "M6 idname() lets the merged result feed tvevent on the caller's key" ///
    "named_rc=`chain_rc' event_var=`chain_var' key=`chain_key'; default_rc=`default_rc' (0 = the option is pointless)"

**# M7 a second tvmerge consumes the first result on the same key
local ++test_count
clear
quietly tvmerge "srcA.dta" "srcB.dta", id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drug care) idname(pid)
quietly save "stage1.dta", replace
clear
capture noisily tvmerge "stage1.dta" "srcA.dta", id(pid) ///
    start(start a_start) stop(stop a_stop) exposure(drug drug) ///
    generate(drug1 drug2) idname(pid)
local chain2_rc = _rc
capture confirm variable pid, exact
local chain2_key = (_rc == 0)
local ok = (`chain2_rc' == 0 & `chain2_key')
_tvm_check `ok' ///
    "M7 a merged result chains into a second tvmerge on the same key" ///
    "rc=`chain2_rc' key_kept=`chain2_key'"

**# M8-M12 the refusals, each before any source is opened
capture program drop _tvm_refusal
program define _tvm_refusal, rclass
    version 16.0
    args opts
    clear
    quietly set obs 3
    quietly generate byte sentinel = _n
    capture noisily tvmerge "srcA.dta" "srcB.dta", id(pid) ///
        start(a_start b_start) stop(a_stop b_stop) exposure(drug care) `opts'
    return scalar rc = _rc
    capture confirm variable sentinel
    return scalar caller_intact = (_rc == 0 & _N == 3)
end

local ++test_count
_tvm_refusal "idname(2bad)"
local rc = r(rc)
local ok = (`rc' == 198)
_tvm_check `ok' "M8 idname() with an illegal Stata name is r(198)" "rc=`rc'"

local ++test_count
_tvm_refusal "idname(start)"
local rc = r(rc)
local ok = (`rc' == 198)
_tvm_check `ok' "M9 idname() equal to startname() is r(198)" "rc=`rc'"

local ++test_count
_tvm_refusal "idname(stop)"
local rc = r(rc)
local ok = (`rc' == 198)
_tvm_check `ok' "M10 idname() equal to stopname() is r(198)" "rc=`rc'"

local ++test_count
_tvm_refusal "idname(drug)"
local rc = r(rc)
local ok = (`rc' == 198)
_tvm_check `ok' ///
    "M11 idname() colliding with an exposure output name is r(198)" "rc=`rc'"

local ++test_count
_tvm_refusal "idname(2bad)"
local intact = r(caller_intact)
local ok = `intact'
_tvm_check `ok' ///
    "M12 a refused idname() leaves the caller's data untouched" ///
    "caller_intact=`intact'"

**# M13 the diagnostic listings use the committed key name
* validateoverlap builds its listing from a tempfile written after the rename.
* One built before it would print a column headed `id' while the committed
* result is headed pid.
local ++test_count
clear
capture noisily tvmerge "srcA.dta" "srcB.dta", id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drug care) idname(pid) ///
    validatecoverage validateoverlap verbose check
local diag_rc = _rc
capture confirm variable pid, exact
local diag_key = (_rc == 0)
local ok = (`diag_rc' == 0 & `diag_key')
_tvm_check `ok' ///
    "M13 the diagnostic options run and keep the committed key name" ///
    "rc=`diag_rc' key=`diag_key'"

**# M14 r(idname) matches the committed schema
local ++test_count
clear
quietly tvmerge "srcA.dta" "srcB.dta", id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drug care) idname(person)
local ret "`r(idname)'"
capture confirm variable `ret', exact
local matches = (_rc == 0)
local ok = ("`ret'" == "person" & `matches')
_tvm_check `ok' "M14 r(idname) names a variable that exists in the output" ///
    "r(idname)=`ret' present=`matches'"

foreach f in srcA srcB evts base stage1 merged_named merged_default {
    capture erase "`f'.dta"
}

**# Summary
local pass_count = $TVM_PASS
local fail_count = $TVM_FAIL
display "RESULT: test_tvmerge_idname tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "tvmerge idname failures:$TVM_FAILED"
    exit 1
}
