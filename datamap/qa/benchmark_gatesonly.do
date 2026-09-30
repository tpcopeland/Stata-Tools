clear all
set more off
version 16.0
set linesize 255

* benchmark_gatesonly.do - datamap 1.8.0 F1-F3: gatesonly cost on a wide
* interval file.  Benchmark lane only (timing depends on the machine): run
* with set processors 1 in a profile.do in the working directory.
*
* Design (the plan's appendix): 1,000,000 rows, 44 columns (id start stop
* _d, 20 byte categoricals, 20 doubles, year).  Asserts that the 44-column
* gatesonly call costs at most twice the three-column varlist call, that
* by(year) no longer scales with the profile, and that both forms return
* identical verdicts for every gate family.

local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
macro drop DATAMAP_DQ

local test_count = 0
local pass_count = 0
local fail_count = 0

clear
set seed 1
set obs 1000000
gen long id = ceil(_n/5)
bysort id: gen start = _n*100
gen stop = start + 100
gen byte _d = runiform() < 0.01
forvalues j = 1/20 {
    gen byte c`j' = floor(runiform()*4)
    gen double x`j' = rnormal()
}
gen int year = 2000 + floor(runiform()*20)

* warm-up: load and compile the ado files outside the timers
preserve
quietly keep in 1/1000
quietly datacheck, gatesonly isid(id start) rule("ok": start < stop)
restore

timer clear
timer on 1
datacheck, gatesonly isid(id start) rule("ok": start < stop)
timer off 1
timer on 2
datacheck id start stop, gatesonly isid(id start) rule("ok": start < stop)
timer off 2
timer on 3
datacheck, gatesonly isid(id start) by(year)
timer off 3
timer on 4
quietly isid id start
quietly count if !(start < stop)
timer off 4
timer list
quietly timer list
local t_wide = r(t1)
local t_narrow = r(t2)
local t_by = r(t3)
local t_native = r(t4)
display as text "gatesonly, 44 columns: " %6.2f `t_wide' "s; 3-column varlist: " %6.2f `t_narrow' ///
    "s; by(year): " %6.2f `t_by' "s; native: " %6.2f `t_native' "s"

local ++test_count
capture noisily {
    assert `t_wide' <= 2 * max(`t_narrow', 0.05)
    * 20 groups: the by() call must not cost a profile per group (it was
    * 84 s in 1.7.1); allow 10 x the ungrouped call
    assert `t_by' <= 10 * max(`t_wide', 0.3)
}
if _rc == 0 {
    display as result "  PASS: gatesonly cost tracks the gate columns, and by() does not rescan the profile"
    local ++pass_count
}
else {
    display as error "  FAIL: gatesonly timing (rc=`=_rc')"
    local ++fail_count
}

* identical verdicts, with and without a varlist, for every gate family
local ++test_count
capture noisily {
    replace stop = start in 17
    replace c3 = 9 in 1/3
    local call `"isid(id start) nodups rule("ok": start < stop) inrange(x1 -4 4 \ x2 x3 -5 5) allowed(c3 0 1 2 3) notmissing(x4) stat(mean x5 -0.01 0.01 \ sum _d 9000 11000 \ distinct id 200000 200000) binary(_d) events(_d: c1 c2) intervals(id start stop, contiguous) constant(id: year) review("big": x6 > 3) complete(x7 x8) bands(expectn(900000 1100000)) bandwarn warn"'
    capture datacheck, gatesonly `call' violations(bv_wide, replace)
    local v1 "`r(violations)'"
    local c1 "`r(checks_run)'"
    local n1 = r(n_violations)
    capture datacheck id start stop _d c1 c2 c3 x1-x8 year, gatesonly `call' violations(bv_narrow, replace)
    assert "`r(violations)'" == "`v1'" & "`r(checks_run)'" == "`c1'" & r(n_violations) == `n1'
    frame bv_wide: local nw = _N
    frame bv_narrow: assert _N == `nw'
    forvalues j = 1/`nw' {
        frame bv_wide: local m = message[`j']
        frame bv_narrow: assert message[`j'] == `"`m'"'
    }
}
if _rc == 0 {
    display as result "  PASS: the fast path and the varlist form give identical verdicts for every family"
    local ++pass_count
}
else {
    display as error "  FAIL: fast-path verdict parity (rc=`=_rc')"
    local ++fail_count
}
capture frame drop bv_wide
capture frame drop bv_narrow

display "RESULT: benchmark_gatesonly tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
