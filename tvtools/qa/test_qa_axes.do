*! test_qa_axes.do
*! Adversarial-axis probes for all 12 public tvtools commands, through the
*! vendored qa-lib helpers (the only probes `check qa tvtools --view axes` counts).
*!
*! Axes probed, and why each is here:
*!   E1-E12   fingerprint-error: a real failing invocation per command, an exact
*!            nonzero rc, and qa_state_compare proving the caller's data, frames,
*!            scalars, globals, characteristics, labels and settings are untouched
*!   P1-P11   parity: one quantity, every sink. The oracle is the dataset or the
*!            design (counted or derived by hand), never the command's own return.
*!            r() must equal the console (text log) or the frame cell it describes
*!   L1       lifecycle (tvspec): a specification frame built before a second one
*!            must still list and dump identically after the second exists and
*!            the first fit is restored
*!   H1-H4    hostile strings: label() and referencelabel() of tvexpose and tvbuild
*!            carry the whole corpus (embedded double quotes, backticks, $global,
*!            apostrophes, backslash, comma, leading blank, unicode) into the
*!            variable label and the value label, byte for byte
*!   F1       hostile fixture (tvweight): five time values that differ in the
*!            11th-13th digit, rows stored against time order; the cumulative
*!            product must follow time, not row order
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
quietly log using "test_qa_axes.log", replace text nomsg
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap
do "`c(pwd)'/_qa_state.do"
do "`c(pwd)'/_qa_parity.do"
do "`c(pwd)'/_qa_lifecycle.do"
do "`c(pwd)'/_qa_hostile.do"

local tests = 0
local pass = 0
local fail = 0

* Distinct values of one variable in the current data (r(n)); r() of the
* command under test is copied into scalars before this is called.
capture program drop _ax_ndistinct
program define _ax_ndistinct, rclass
    version 16.0
    args v
    tempvar tag
    quietly egen byte `tag' = tag(`v')
    quietly count if `tag' == 1
    return scalar n = r(N)
end

* Fixtures. master: two persons, follow-up 01jul2019-31dec2020. ep: episodes.
clear
input long id double(entry exit dob) byte female
1 21730 22280 7305 1
2 21730 22280 9000 0
end
format entry exit dob %td
tempfile master
save `master'
clear
input long id double(rx_start rx_stop) byte drug
1 21930 22000 1
1 22050 22100 2
2 21950 22200 1
end
format rx_start rx_stop %td
tempfile ep
save `ep'
* The same episodes under the names tvpanel expects (start, stop, class).
rename (rx_start rx_stop drug) (start stop eclass)
tempfile epp
save `epp'
* Single-person design with entry 1 and exit 366, so the last stop in the result
* frame equals total person-time by construction.
clear
input long id double(entry exit)
1 1 366
end
tempfile m1
save `m1'
clear
input long id double(rx_start rx_stop) byte drug
1 100 200 1
end
tempfile ep1
save `ep1'
* Two persons, one interval each, so ids 1 2 give person count = highest id.
clear
input long id double(entry exit)
1 1 100
2 1 100
end
tempfile m2
save `m2'
clear
input long id double(rx_start rx_stop) byte drug
1 1 100 1
2 1 100 1
end
tempfile ep2
save `ep2'
clear
input long id double(rx_start rx_stop) byte drug
1 10 50 1
2 10 50 1
end
tempfile mga
save `mga'
clear
input long id double(s2 e2) byte d2
1 30 80 2
2 30 80 2
end
tempfile mgb
save `mgb'
* Tvexpose output, and an event file, for tvevent.
clear
input long id double(rx_start rx_stop) byte drug
1 1 100 1
2 1 100 1
end
tempfile ints
save `ints'
clear
input long id double evdate
1 50
2 200
end
tempfile evs
save `evs'
tempfile lg
local lgf "`lg'.txt"

**# E: fingerprint-error. Every command fails for a real reason; nothing may leak.

* E1: tvtools with an unknown category
local ++tests
capture noisily {
    use `master', clear
    qa_state_snapshot, tag(e_tvtools)
    capture tvtools, category(bogus)
    assert _rc == 198
    qa_state_compare, tag(e_tvtools)
}
if _rc == 0 {
    local ++pass
    display as result "PASS E1"
}
else {
    local ++fail
    display as error "FAIL E1"
}

* E2: tvage with a date-of-birth variable that does not exist
local ++tests
capture noisily {
    use `master', clear
    qa_state_snapshot, tag(e_tvage)
    capture tvage, id(id) dob(nosuch) entry(entry) exit(exit) generate(agex)
    assert _rc == 111
    qa_state_compare, tag(e_tvage)
}
if _rc == 0 {
    local ++pass
    display as result "PASS E2"
}
else {
    local ++fail
    display as error "FAIL E2"
}

* E3: tvband with an unknown axis type
local ++tests
capture noisily {
    use `master', clear
    qa_state_snapshot, tag(e_tvband)
    capture tvband, id(id) start(entry) stop(exit) type(bogus) generate(bandx)
    assert _rc == 198
    qa_state_compare, tag(e_tvband)
}
if _rc == 0 {
    local ++pass
    display as result "PASS E3"
}
else {
    local ++fail
    display as error "FAIL E3"
}

* E4: tvsplit naming an age origin variable that does not exist (rc 109)
local ++tests
capture noisily {
    use `master', clear
    qa_state_snapshot, tag(e_tvsplit)
    capture tvsplit, id(id) start(entry) stop(exit) age(nosuch, width(5))
    assert _rc == 109
    qa_state_compare, tag(e_tvsplit)
}
if _rc == 0 {
    local ++pass
    display as result "PASS E4"
}
else {
    local ++fail
    display as error "FAIL E4"
}

* E5: tvpanel naming an exposure variable the episode file lacks
local ++tests
capture noisily {
    use `master', clear
    qa_state_snapshot, tag(e_tvpanel)
    capture tvpanel using `epp', id(id) entry(entry) exit(exit) ///
        exposure(nosuch) reference(0) width(91)
    assert _rc == 111
    qa_state_compare, tag(e_tvpanel)
}
if _rc == 0 {
    local ++pass
    display as result "PASS E5"
}
else {
    local ++fail
    display as error "FAIL E5"
}

* E6: tvdiagnose with coverage requested and no entry()/exit()
local ++tests
capture noisily {
    use `ep', clear
    qa_state_snapshot, tag(e_tvdiagnose)
    capture tvdiagnose, id(id) start(rx_start) stop(rx_stop) coverage
    assert _rc == 198
    qa_state_compare, tag(e_tvdiagnose)
}
if _rc == 0 {
    local ++pass
    display as result "PASS E6"
}
else {
    local ++fail
    display as error "FAIL E6"
}

* E7: tvexpose naming an exposure variable the episode file lacks, with a
* result frame requested (the frame must not be left behind)
local ++tests
capture noisily {
    use `master', clear
    qa_state_snapshot, tag(e_tvexpose)
    capture tvexpose using `ep', id(id) start(rx_start) stop(rx_stop) ///
        exposure(nosuch) reference(0) entry(entry) exit(exit) ///
        generate(tvx) frameout(ax_leak_e7)
    assert _rc == 111
    qa_state_compare, tag(e_tvexpose)
}
if _rc == 0 {
    local ++pass
    display as result "PASS E7"
}
else {
    local ++fail
    display as error "FAIL E7"
}

* E8: tvmerge naming an exposure variable the first dataset lacks, with a
* result frame requested
local ++tests
capture noisily {
    use `master', clear
    qa_state_snapshot, tag(e_tvmerge)
    capture tvmerge `ep' `ep', id(id) start(rx_start rx_start) ///
        stop(rx_stop rx_stop) exposure(nosuch drug) generate(ma mb) ///
        frameout(ax_leak_e8)
    assert _rc == 111
    qa_state_compare, tag(e_tvmerge)
}
if _rc == 0 {
    local ++pass
    display as result "PASS E8"
}
else {
    local ++fail
    display as error "FAIL E8"
}

* E9: tvevent naming an event date the master data lacks
local ++tests
capture noisily {
    use `evs', clear
    qa_state_snapshot, tag(e_tvevent)
    capture tvevent using `ints', id(id) date(nosuch) startvar(rx_start) ///
        stopvar(rx_stop) generate(evx)
    assert _rc == 111
    qa_state_compare, tag(e_tvevent)
}
if _rc == 0 {
    local ++pass
    display as result "PASS E9"
}
else {
    local ++fail
    display as error "FAIL E9"
}

* E10: tvbuild naming an exposure variable the source lacks, with a result frame
local ++tests
capture noisily {
    use `master', clear
    qa_state_snapshot, tag(e_tvbuild)
    capture tvbuild, sourceusing("`ep'") id(id) entry(entry) exit(exit) ///
        start(rx_start) stop(rx_stop) exposure(nosuch) reference(0) ///
        generate(tvx) frameout(ax_leak_e10)
    assert _rc == 111
    qa_state_compare, tag(e_tvbuild)
}
if _rc == 0 {
    local ++pass
    display as result "PASS E10"
}
else {
    local ++fail
    display as error "FAIL E10"
}

* E11: tvspec add against a frame that does not exist, then create over an
* existing frame without replace (rc 110). The frame the caller owns survives.
local ++tests
capture noisily {
    use `master', clear
    tvspec create ax_e11
    qa_state_snapshot, tag(e_tvspec)
    capture tvspec add ax_e11_missing, name(a) start(s) stop(e) exposure(x) generate(y)
    assert _rc == 111
    capture tvspec create ax_e11
    assert _rc == 110
    qa_state_compare, tag(e_tvspec)
    frame drop ax_e11
}
if _rc == 0 {
    local ++pass
    display as result "PASS E11"
}
else {
    local ++fail
    display as error "FAIL E11"
}

* E12: tvweight with a truncation window given backwards, after its inputs
* validated (no weight variable may be left in the caller's data)
local ++tests
capture noisily {
    clear
    set obs 40
    set seed 12
    generate long id = _n
    generate double x = rnormal()
    generate byte trt = mod(_n, 2)
    qa_state_snapshot, tag(e_tvweight)
    capture tvweight trt, covariates(x) truncate(99 1) generate(wx)
    assert _rc == 198
    qa_state_compare, tag(e_tvweight)
}
if _rc == 0 {
    local ++pass
    display as result "PASS E12"
}
else {
    local ++fail
    display as error "FAIL E12"
}

**# P: parity. r() against the console (text log) and the result frame.

* P1: tvage observations and persons: dataset count = r() = console
local ++tests
capture noisily {
    capture quietly log close axl
    use `master', clear
    quietly log using "`lgf'", text replace name(axl) nomsg
    tvage, id(id) dob(dob) entry(entry) exit(exit) generate(agep) noisily
    scalar ax_obs = r(n_observations)
    scalar ax_per = r(n_persons)
    quietly log close axl
    quietly count
    local nobs = r(N)
    _ax_ndistinct id
    local nper = r(n)
    qa_surface_parity, name("tvage observations") expect(`nobs') result(ax_obs) ///
        log("`lgf'") logregex("observations\s+:\s+([0-9,]+)")
    qa_surface_parity, name("tvage persons") expect(`nper') result(ax_per) ///
        log("`lgf'") logregex("persons\s+:\s+([0-9,]+)")
}
if _rc == 0 {
    local ++pass
    display as result "PASS P1"
}
else {
    local ++fail
    display as error "FAIL P1"
}

* P2: tvband calendar bands: 2019 and 2020 give two rows per person
local ++tests
capture noisily {
    capture quietly log close axl
    use `master', clear
    quietly log using "`lgf'", text replace name(axl) nomsg
    tvband, id(id) start(entry) stop(exit) type(calendar) width(1) ///
        generate(bandp) noisily
    scalar ax_obs = r(n_observations)
    scalar ax_per = r(n_persons)
    quietly log close axl
    quietly count
    local nobs = r(N)
    _ax_ndistinct id
    local nper = r(n)
    assert `nobs' == 4
    qa_surface_parity, name("tvband observations") expect(`nobs') result(ax_obs) ///
        log("`lgf'") logregex("observations\s+:\s+([0-9,]+)")
    qa_surface_parity, name("tvband persons") expect(`nper') result(ax_per) ///
        log("`lgf'") logregex("persons\s+:\s+([0-9,]+)")
}
if _rc == 0 {
    local ++pass
    display as result "PASS P2"
}
else {
    local ++fail
    display as error "FAIL P2"
}

* P3: tvsplit on age and calendar axes
local ++tests
capture noisily {
    capture quietly log close axl
    use `master', clear
    quietly log using "`lgf'", text replace name(axl) nomsg
    tvsplit, id(id) start(entry) stop(exit) age(dob, width(10)) ///
        calendar(, width(1)) noisily
    scalar ax_obs = r(n_observations)
    scalar ax_per = r(n_persons)
    quietly log close axl
    quietly count
    local nobs = r(N)
    _ax_ndistinct id
    local nper = r(n)
    qa_surface_parity, name("tvsplit observations") expect(`nobs') result(ax_obs) ///
        log("`lgf'") logregex("observations\s+:\s+([0-9,]+)")
    qa_surface_parity, name("tvsplit persons") expect(`nper') result(ax_per) ///
        log("`lgf'") logregex("persons\s+:\s+([0-9,]+)")
}
if _rc == 0 {
    local ++pass
    display as result "PASS P3"
}
else {
    local ++fail
    display as error "FAIL P3"
}

* P4: tvtools lists eleven commands: the catalogue (word count of r(commands))
* = r(n_commands) = the console total
local ++tests
capture noisily {
    capture quietly log close axl
    quietly log using "`lgf'", text replace name(axl) nomsg
    tvtools
    scalar ax_n = r(n_commands)
    local listed `"`r(commands)'"'
    quietly log close axl
    local nlisted : word count `listed'
    qa_surface_parity, name("tvtools commands") expect(`nlisted') result(ax_n) ///
        log("`lgf'") logregex("total commands\s+:\s+([0-9,]+)")
}
if _rc == 0 {
    local ++pass
    display as result "PASS P4"
}
else {
    local ++fail
    display as error "FAIL P4"
}

* P5: tvpanel rows: width 91 over 550 days of follow-up gives 7 periods per person
local ++tests
capture noisily {
    capture quietly log close axl
    use `master', clear
    quietly log using "`lgf'", text replace name(axl) nomsg
    tvpanel using `epp', id(id) entry(entry) exit(exit) exposure(eclass) ///
        reference(0) width(91) noisily
    scalar ax_obs = r(n_observations)
    scalar ax_per = r(n_persons)
    quietly log close axl
    quietly count
    local nobs = r(N)
    _ax_ndistinct id
    local nper = r(n)
    assert `nobs' == 14
    qa_surface_parity, name("tvpanel rows") expect(`nobs') result(ax_obs) ///
        log("`lgf'") logregex("periods \(rows\)\s+:\s+([0-9,]+)")
    qa_surface_parity, name("tvpanel persons") expect(`nper') result(ax_per) ///
        log("`lgf'") logregex("persons\s+:\s+([0-9,]+)")
}
if _rc == 0 {
    local ++pass
    display as result "PASS P5"
}
else {
    local ++fail
    display as error "FAIL P5"
}

* P6: tvdiagnose persons, observations, and the one 49-day gap (hand-derived:
* person 1 is covered to day 22000 and again from day 22050)
local ++tests
capture noisily {
    capture quietly log close axl
    use `ep', clear
    quietly log using "`lgf'", text replace name(axl) nomsg
    tvdiagnose, id(id) start(rx_start) stop(rx_stop) exposure(drug) gaps summarize
    scalar ax_obs = r(n_observations)
    scalar ax_per = r(n_persons)
    scalar ax_gaps = r(n_gaps)
    quietly log close axl
    quietly count
    local nobs = r(N)
    _ax_ndistinct id
    local nper = r(n)
    qa_surface_parity, name("tvdiagnose observations") expect(`nobs') result(ax_obs) ///
        log("`lgf'") logregex("observations\s+:\s+([0-9,]+)")
    qa_surface_parity, name("tvdiagnose persons") expect(`nper') result(ax_per) ///
        log("`lgf'") logregex("persons\s+:\s+([0-9,]+)")
    qa_surface_parity, name("tvdiagnose gaps") expect(1) result(ax_gaps) ///
        log("`lgf'") logregex("total gaps\s+:\s+([0-9,]+)")
}
if _rc == 0 {
    local ++pass
    display as result "PASS P6"
}
else {
    local ++fail
    display as error "FAIL P6"
}

* P7: tvexpose total person-time = r() = console = the last stop in the result
* frame (follow-up 1..366, so 366 days); N_periods = 3 (baseline, exposed, after)
local ++tests
capture noisily {
    capture quietly log close axl
    capture frame drop ax_f7
    use `m1', clear
    quietly log using "`lgf'", text replace name(axl) nomsg
    tvexpose using `ep1', id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(entry) exit(exit) generate(tv7) frameout(ax_f7)
    scalar ax_tt = r(total_time)
    scalar ax_et = r(exposed_time)
    scalar ax_np = r(N_periods)
    quietly log close axl
    qa_surface_parity, name("tvexpose total time") expect(366) result(ax_tt) ///
        log("`lgf'") logregex("total person-time \(days\)\s+:\s+([0-9,]+)") ///
        frame(ax_f7 rx_stop 3)
    qa_surface_parity, name("tvexpose exposed time") expect(101) result(ax_et) ///
        log("`lgf'") logregex("exposed person-time\s+:\s+([0-9,]+)")
    qa_surface_parity, name("tvexpose periods") expect(3) result(ax_np) ///
        log("`lgf'") logregex("time-varying periods\s+:\s+([0-9,]+)")
    frame drop ax_f7
}
if _rc == 0 {
    local ++pass
    display as result "PASS P7"
}
else {
    local ++fail
    display as error "FAIL P7"
}

* P8: tvmerge, two persons with one overlapping interval each: rows, persons,
* the console, and the highest id in the result frame (ids are 1 and 2)
local ++tests
capture noisily {
    capture quietly log close axl
    capture frame drop ax_f8
    use `master', clear
    quietly log using "`lgf'", text replace name(axl) nomsg
    tvmerge `mga' `mgb', id(id) start(rx_start s2) stop(rx_stop e2) ///
        exposure(drug d2) generate(ma mb) frameout(ax_f8)
    scalar ax_n = r(N)
    scalar ax_per = r(N_persons)
    quietly log close axl
    qa_surface_parity, name("tvmerge rows") expect(2) result(ax_n) ///
        log("`lgf'") logregex("observations\s+:\s+([0-9,]+)") frame(ax_f8 id 2)
    qa_surface_parity, name("tvmerge persons") expect(2) result(ax_per) ///
        log("`lgf'") logregex("persons\s+:\s+([0-9,]+)") frame(ax_f8 id 2)
    frame drop ax_f8
}
if _rc == 0 {
    local ++pass
    display as result "PASS P8"
}
else {
    local ++fail
    display as error "FAIL P8"
}

* P9: tvevent observations and flagged events: the data in memory is the oracle
local ++tests
capture noisily {
    capture quietly log close axl
    use `evs', clear
    quietly log using "`lgf'", text replace name(axl) nomsg
    tvevent using `ints', id(id) date(evdate) startvar(rx_start) ///
        stopvar(rx_stop) generate(ev9)
    scalar ax_n = r(N)
    scalar ax_ev = r(N_events)
    quietly log close axl
    quietly count
    local nobs = r(N)
    quietly count if ev9 == 1
    local nev = r(N)
    assert `nev' == 1
    qa_surface_parity, name("tvevent rows") expect(`nobs') result(ax_n) ///
        log("`lgf'") logregex("observations\s+:\s+([0-9,]+)")
    qa_surface_parity, name("tvevent events") expect(`nev') result(ax_ev) ///
        log("`lgf'") logregex("events flagged \(ev9\)\s+:\s+([0-9,]+)")
}
if _rc == 0 {
    local ++pass
    display as result "PASS P9"
}
else {
    local ++fail
    display as error "FAIL P9"
}

* P10: tvbuild, two persons covered by one interval each: r(N_persons) and
* r(N_periods) = the highest id in the committed frame (ids 1 and 2, one row each)
local ++tests
capture noisily {
    capture frame drop ax_f10
    use `m2', clear
    tvbuild, sourceusing("`ep2'") id(id) entry(entry) exit(exit) ///
        start(rx_start) stop(rx_stop) exposure(drug) reference(0) ///
        generate(tv10) frameout(ax_f10)
    scalar ax_per = r(N_persons)
    scalar ax_np = r(N_periods)
    qa_surface_parity, name("tvbuild persons") expect(2) result(ax_per) ///
        frame(ax_f10 id 2)
    qa_surface_parity, name("tvbuild periods") expect(2) result(ax_np) ///
        frame(ax_f10 id 2)
    frame drop ax_f10
}
if _rc == 0 {
    local ++pass
    display as result "PASS P10"
}
else {
    local ++fail
    display as error "FAIL P10"
}

* P11: tvweight effective sample size: the independent (sum w)^2 / sum w^2 over
* the analysis weight, r(ess), and the console line all agree
local ++tests
capture noisily {
    capture quietly log close axl
    clear
    set seed 7
    set obs 300
    generate long id = ceil(_n / 5)
    bysort id: generate int t = _n
    generate double x = rnormal()
    generate byte trt = runiform() < invlogit(0.4 * x)
    quietly log using "`lgf'", text replace name(axl) nomsg
    tvweight trt, covariates(x) id(id) time(t) generate(wp) cumulative
    scalar ax_ess = r(ess)
    scalar ax_n = r(N)
    quietly log close axl
    quietly summarize wp_cum
    local wsum = r(sum)
    generate double wsq = wp_cum^2
    quietly summarize wsq
    local ess = `wsum'^2 / r(sum)
    qa_surface_parity, name("tvweight ess") expect(`ess') result(ax_ess) tol(1e-9) ///
        log("`lgf'") logregex("ESS\s+:\s+([0-9.,]+)")
    qa_surface_parity, name("tvweight n") expect(300) result(ax_n) ///
        log("`lgf'") logregex("observations\s+:\s+([0-9,]+)")
}
if _rc == 0 {
    local ++pass
    display as result "PASS P11"
}
else {
    local ++fail
    display as error "FAIL P11"
}

**# L: lifecycle (tvspec). Building specification B must not change what A lists.

* Fit A: a two-source specification frame. Fit B: a different one. The
* postestimation side reads frame A only, so any state shared between the
* frames (a characteristic, a global, a "last used" frame) shows as a change.
capture program drop _ax_specfit
program define _ax_specfit, eclass
    version 16.0
    args which
    tempname b
    if "`which'" == "A" {
        tvspec create ax_spA, replace
        tvspec add ax_spA, name(first) start(s1) stop(e1) exposure(x1) ///
            generate(g1) using("src_a.dta") kind(episodes) reference(0)
        tvspec add ax_spA, name(second) start(s2) stop(e2) exposure(x2) ///
            generate(g2) using("src_b.dta") kind(intervals) total(x2)
    }
    else {
        tvspec create ax_spB, replace
        tvspec add ax_spB, name(only) start(t1) stop(t2) exposure(z) ///
            generate(gz) using("src_c.dta") kind(episodes) reference(9) ///
            referencelabel("Other") label("Z exposure")
    }
    matrix `b' = (1)
    matrix colnames `b' = one
    ereturn post `b'
    ereturn local cmd "axspec"
end

* The content of one specification frame, as r() macros, so every cell is compared.
capture program drop _ax_specdump
program define _ax_specdump, rclass
    version 16.0
    args specframe
    local out ""
    local n 0
    frame `specframe' {
        local n = _N
        forvalues i = 1/`=_N' {
            local out `"`out'|`=source_name[`i']'~`=source_kind[`i']'~`=start_var[`i']'~`=stop_var[`i']'~`=input_vars[`i']'~`=output_vars[`i']'~`=reference[`i']'~`=total_vars[`i']'"'
        }
    }
    return local dump `"`out'"'
    return scalar rows = `n'
end

local ++tests
capture noisily {
    capture frame drop ax_spA
    capture frame drop ax_spB
    qa_lifecycle, fita(_ax_specfit A) fitb(_ax_specfit B) ///
        post(tvspec list ax_spA; _ax_specdump ax_spA)
    * A stayed two rows and B exists beside it, both intact
    frame ax_spA: assert _N == 2
    frame ax_spB: assert _N == 1
    tvspec list ax_spA
    assert r(n_sources) == 2
    assert "`r(source_names)'" == "first second"
    tvspec list ax_spB
    assert r(n_sources) == 1
}
if _rc == 0 {
    local ++pass
    display as result "PASS L1"
}
else {
    local ++fail
    display as error "FAIL L1"
}
capture frame drop ax_spA
capture frame drop ax_spB

**# H: hostile strings. The corpus must reach the labels byte for byte.

* Each check program receives the NAME of a corpus global, passes its content
* intact into the option (st_local + macval, never through a macro expansion the
* corpus could poison), then publishes the stored text through AX_GOT.
capture program drop _ax_hs_expose_label
program define _ax_hs_expose_label
    args g
    mata: st_local("s", st_global("`g'"))
    use "$AX_MASTER", clear
    tvexpose using "$AX_EP", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) ///
        generate(tvh) label(`"`macval(s)'"')
    mata: st_global("AX_GOT", st_varlabel("tvh"))
end

capture program drop _ax_hs_expose_reflabel
program define _ax_hs_expose_reflabel
    args g
    mata: st_local("s", st_global("`g'"))
    use "$AX_MASTER", clear
    tvexpose using "$AX_EP", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) ///
        generate(tvh) referencelabel(`"`macval(s)'"')
    _ax_reflabel tvh
end

capture program drop _ax_hs_build_label
program define _ax_hs_build_label
    args g
    mata: st_local("s", st_global("`g'"))
    use "$AX_MASTER", clear
    capture frame drop ax_hsb
    tvbuild, sourceusing("$AX_EP") id(id) entry(entry) exit(exit) ///
        start(rx_start) stop(rx_stop) exposure(drug) reference(0) ///
        generate(tvh) frameout(ax_hsb) label(`"`macval(s)'"')
    frame ax_hsb: mata: st_global("AX_GOT", st_varlabel("tvh"))
    frame drop ax_hsb
end

capture program drop _ax_hs_build_reflabel
program define _ax_hs_build_reflabel
    args g
    mata: st_local("s", st_global("`g'"))
    use "$AX_MASTER", clear
    capture frame drop ax_hsb
    tvbuild, sourceusing("$AX_EP") id(id) entry(entry) exit(exit) ///
        start(rx_start) stop(rx_stop) exposure(drug) reference(0) ///
        generate(tvh) frameout(ax_hsb) referencelabel(`"`macval(s)'"')
    frame ax_hsb: _ax_reflabel tvh
    frame drop ax_hsb
end

* The text the reference value (0) carries in the value label of one variable.
capture program drop _ax_reflabel
program define _ax_reflabel
    args v
    local lbl : value label `v'
    if "`lbl'" == "" {
        display as error "_ax_reflabel: `v' carries no value label"
        exit 198
    }
    mata: _ax_ref_text("`lbl'")
end
capture mata: mata drop _ax_ref_text()
mata:
void _ax_ref_text(string scalar lbl)
{
    real colvector values
    string colvector text
    real scalar i
    st_vlload(lbl, values, text)
    for (i = 1; i <= rows(values); i++) {
        if (values[i] == 0) {
            st_global("AX_GOT", text[i])
            return
        }
    }
    errprintf("_ax_reflabel: value label has no entry for the reference 0\n")
    exit(198)
}
end

global AX_MASTER "`master'"
global AX_EP "`ep'"

local ++tests
capture noisily {
    qa_hostile_strings, check(_ax_hs_expose_label) result(AX_GOT)
}
if _rc == 0 {
    local ++pass
    display as result "PASS H1"
}
else {
    local ++fail
    display as error "FAIL H1"
}

local ++tests
capture noisily {
    qa_hostile_strings, check(_ax_hs_expose_reflabel) result(AX_GOT)
}
if _rc == 0 {
    local ++pass
    display as result "PASS H2"
}
else {
    local ++fail
    display as error "FAIL H2"
}

local ++tests
capture noisily {
    qa_hostile_strings, check(_ax_hs_build_label) result(AX_GOT)
}
if _rc == 0 {
    local ++pass
    display as result "PASS H3"
}
else {
    local ++fail
    display as error "FAIL H3"
}

local ++tests
capture noisily {
    qa_hostile_strings, check(_ax_hs_build_reflabel) result(AX_GOT)
}
if _rc == 0 {
    local ++pass
    display as result "PASS H4"
}
else {
    local ++fail
    display as error "FAIL H4"
}

**# F: hostile fixture. Time values that survive only as exact doubles.

* Forty persons, each observed at five times that differ in the 11th-13th digit
* (qa_hostile_times), stored in DESCENDING time order so row order is the
* opposite of time order. The cumulative product must be taken in time order:
* the independent oracle sorts by (id, time) and multiplies the per-period
* weights itself.
local ++tests
capture noisily {
    clear
    set obs 200
    set seed 20261012
    generate long id = ceil(_n / 5)
    qa_hostile_times, generate(thost)
    generate double x = rnormal()
    generate byte trt = runiform() < invlogit(0.4 * x)
    gsort id -thost
    tvweight trt, covariates(x) id(id) time(thost) generate(wh) cumulative
    assert !missing(wh, wh_cum)
    quietly count
    assert r(N) == 200
    * Independent oracle: running product of wh in ascending time within person
    sort id thost
    generate double ref_cum = wh
    by id: replace ref_cum = ref_cum[_n - 1] * wh if _n > 1
    generate double rd = abs(ref_cum - wh_cum) / max(abs(ref_cum), 1e-300)
    quietly summarize rd
    assert r(max) < 1e-12
    * The first period of every person is the per-period weight itself
    by id: assert wh_cum == wh if _n == 1
    * The five hostile times are all distinct to the command: 5 per person
    _ax_ndistinct thost
    assert r(n) == 5
}
if _rc == 0 {
    local ++pass
    display as result "PASS F1"
}
else {
    local ++fail
    display as error "FAIL F1"
}

display as text "RESULT: test_qa_axes tests=`tests' pass=`pass' fail=`fail' skip=0"
quietly log close _all
if `fail' exit 1
