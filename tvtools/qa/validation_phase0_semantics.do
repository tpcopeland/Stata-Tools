*! validation_phase0_semantics.do
*! Deterministic semantic oracles added during the QA control-plane repair.

clear all
set varabbrev off
version 16.0

capture log close _all
quietly log using "validation_phase0_semantics.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _make_elapsed_interval
program define _make_elapsed_interval
    clear
    set obs 1
    generate long id = 1
    generate double origin = 0
    generate double start = 0
    generate double stop = 30
    generate str4 payload = "keep"
    format origin start stop %td
end

capture program drop _make_weight_panel
program define _make_weight_panel
    clear
    set seed 73191
    set obs 250
    generate long id = _n
    generate double xbase = rnormal()
    expand 4
    bysort id: generate byte t = _n
    generate double xtv = 0.4*xbase + rnormal()
    generate byte a = runiform() < invlogit(-0.2 + 0.5*xbase - 0.7*xtv + 0.15*t)
    sort id t
end

**# tvband exact semantics

local ++test_count
capture noisily {
    _make_elapsed_interval
    tvband, id(id) start(start) stop(stop) type(elapsed) origin(origin) ///
        unit(day) width(10) min(10) max(20) generate(fu) ///
        startgen(s0) stopgen(s1)
    local n_persons = r(n_persons)
    local n_obs = r(n_observations)
    local width = r(width)
    local axistype "`r(axistype)'"
    local varname "`r(varname)'"
    local startvar "`r(startvar)'"
    local stopvar "`r(stopvar)'"
    assert _N == 2
    assert fu[1] == 10 & s0[1] == 10 & s1[1] == 19
    assert fu[2] == 20 & s0[2] == 20 & s1[2] == 29
    assert payload == "keep"
    assert `n_persons' == 1 & `n_obs' == 2 & `width' == 10
    assert "`axistype'" == "elapsed" & "`varname'" == "fu"
    assert "`startvar'" == "s0" & "`stopvar'" == "s1"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' tvband_bounds"
}

local ++test_count
capture noisily {
    _make_elapsed_interval
    datasignature set
    tempfile outbase
    local out "`outbase'.dta"
    tvband, id(id) start(start) stop(stop) type(elapsed) origin(origin) ///
        unit(day) width(10) generate(fu) startgen(s0) stopgen(s1) ///
        saveas("`out'") replace
    datasignature confirm
    use "`out'", clear
    assert _N == 4
    assert fu[1] == 0  & s0[1] == 0  & s1[1] == 9
    assert fu[2] == 10 & s0[2] == 10 & s1[2] == 19
    assert fu[3] == 20 & s0[3] == 20 & s1[3] == 29
    assert fu[4] == 30 & s0[4] == 30 & s1[4] == 30
    assert payload == "keep"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' tvband_saveas"
}

**# tvweight panel and sample semantics

local ++test_count
capture noisily {
    _make_weight_panel
    tvweight a, covariates(xbase) tvcovariates(xtv) id(id) time(t) ///
        generate(w_tv) denominator(ps_tv) nolog
    quietly logit a xbase xtv i.t, vce(cluster id)
    predict double ps_manual, pr
    assert reldif(ps_tv, ps_manual) < 1e-10
    generate double w_manual = cond(a == 1, 1/ps_manual, 1/(1-ps_manual))
    assert reldif(w_tv, w_manual) < 1e-10
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' tvcovariates"
}

local ++test_count
capture noisily {
    _make_weight_panel
    tvweight a in 1/200, covariates(xbase xtv) generate(w_in) nolog
    local n = r(N)
    assert `n' == 200
    count if !missing(w_in)
    assert r(N) == 200
    assert missing(w_in) in 201/L
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' in_qualifier"
}

**# tvdiagnose graph and return semantics

local ++test_count
capture noisily {
    clear
    input long id double(start stop)
    50 1 5
    10 1 5
    40 1 5
    20 1 5
    30 1 5
    end
    generate long exp = id
    format start stop %td
    graph drop _all
    tvdiagnose, id(id) start(start) stop(stop) exposure(exp) swimlane maxids(2)
    tempfile svgbase
    local svg "`svgbase'.svg"
    graph export "`svg'", as(svg) replace
    local content = fileread("`svg'")
    assert strpos(`"`content'"', "exp=10") > 0
    assert strpos(`"`content'"', "exp=20") > 0
    assert strpos(`"`content'"', "exp=30") == 0
    assert strpos(`"`content'"', "exp=40") == 0
    assert strpos(`"`content'"', "exp=50") == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' maxids"
}

local ++test_count
capture noisily {
    clear
    input long id double(start stop)
    1   1   3
    1   6  10
    2 101 110
    end
    format start stop %td
    tvdiagnose, id(id) start(start) stop(stop) gaps threshold(2)
    local n_persons = r(n_persons)
    local n_observations = r(n_observations)
    local n_gaps = r(n_gaps)
    local mean_gap = r(mean_gap)
    local max_gap = r(max_gap)
    local n_large_gaps = r(n_large_gaps)
    assert `n_persons' == 2 & `n_observations' == 3
    assert `n_gaps' == 1 & `mean_gap' == 2 & `max_gap' == 2
    assert `n_large_gaps' == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' gap_returns"
}

local ++test_count
capture noisily {
    clear
    input long id double(start stop) byte exp
    1 1  5 0
    1 6 10 1
    2 1 10 1
    end
    format start stop %td
    tvdiagnose, id(id) start(start) stop(stop) exposure(exp) summarize
    local n_persons = r(n_persons)
    local n_observations = r(n_observations)
    local total_time = r(total_person_time)
    assert `n_persons' == 2 & `n_observations' == 3
    assert `total_time' == 20
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' summary_returns"
}

**# Summary

display "RESULT: validation_phase0_semantics tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "semantic-oracle failures:`failed_tests'"
    exit 1
}
