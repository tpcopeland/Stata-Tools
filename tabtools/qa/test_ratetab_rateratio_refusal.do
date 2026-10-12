* test_ratetab_rateratio_refusal.do - ratetab refuses stratetab's rateratio
*
* stratetab, rateratio divides the rate of each category of exposure group
* e by the same-labelled category of exposure group 1, with the log-rate
* variances added because the groups are independent samples (SAS/STAT 14.1
* STDRATE, "Confidence Interval for Rate Ratio Statistic"; corpus key
* sas-stdrate-2015). ratetab's grouping variables split ONE sample, so the
* pass-through divided rates of overlapping groups (old == 0 over
* hienergy == 0) at rc 0. From 2.6.4 ratetab refuses it.
*
* RR1  ratetab var1 var2, rateratio -> r(198), caller's r() kept
* RR2  ratetab var, rateratio (one variable) -> r(198) from ratetab itself
* RR3  no false refusal: the word inside title() or footnote(), and
*      ratiodigits(), still run; an abbreviation is not the option
* RR4  stratetab's interval itself, on two disjoint (independent) samples,
*      equals the Wald limits of poisson _d i.g, exposure(_t - _t0) irr
*
* Oracles: Stata's poisson e(b)/e(V) and the refusal text. Run from
* tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off
set linesize 255

capture log close _rrr
log using "test_ratetab_rateratio_refusal.log", replace text name(_rrr)

local test_count = 0
local pass_count = 0
local failed ""

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

tempfile scratch
global RRR_DIR "`scratch'_d"
capture mkdir "$RRR_DIR"

capture program drop _rrr_result
program define _rrr_result, rclass
    args rc label
    if `rc' == 0 display as result "  PASS: `label'"
    else display as error "  FAIL: `label' (rc=`rc')"
    return scalar pass = (`rc' == 0)
end

capture program drop _rrr_diet
program define _rrr_diet
    version 17.0
    webuse diet, clear
    quietly stset dox, failure(fail) origin(time doe) id(id) scale(365.25)
    gen byte old = (doe - dob) / 365.25 > 50
    label define _rrr_yn 0 "No" 1 "Yes"
    label values hienergy _rrr_yn
    label values old _rrr_yn
end

**# RR1: two grouping variables, rateratio refused, r() kept
local ++test_count
capture noisily {
    _rrr_diet
    * the pass-through could only run when the levels share labels: here
    * they do, so the old code printed a ratio of overlapping groups
    quietly count if old == 0 & hienergy == 0
    assert !missing(r(N)) & r(N) > 0
    quietly summarize id
    local _mean = r(mean)
    capture noisily ratetab hienergy old, rateratio
    assert _rc == 198
    assert !missing(r(mean)) & !missing(`_mean')
    assert reldif(r(mean), `_mean') < 1e-15
    capture confirm matrix r(ratios)
    assert _rc
}
_rrr_result `=_rc' "RR1 ratetab hienergy old, rateratio is refused (198) and r() is kept"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' RR1"

**# RR2: one grouping variable is refused by ratetab, with its own message
local ++test_count
capture noisily {
    _rrr_diet
    local lf "$RRR_DIR/rr2.log"
    capture log close _rr2
    log using "`lf'", replace text name(_rr2)
    capture noisily ratetab hienergy, rateratio
    local rc = _rc
    log close _rr2
    assert `rc' == 198
    mata: st_local("hit", strofreal(sum(strpos(cat(st_local("lf")), "ratetab: rateratio is not available") :> 0)))
    assert `hit' == 1
    mata: st_local("hint", strofreal(sum(strpos(cat(st_local("lf")), "_t - _t0") :> 0)))
    assert `hint' == 1
}
_rrr_result `=_rc' "RR2 one variable: ratetab's own refusal and the poisson hint"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' RR2"

**# RR3: no false refusal
local ++test_count
capture noisily {
    _rrr_diet
    ratetab hienergy old, title("rateratio by group") footnote("no rateratio here")
    assert r(N_outcomes) == 1
    ratetab hienergy old, ratiodigits(3)
    assert r(N_outcomes) == 1
    * stratetab declares rateratio in lower case: an abbreviation is not it
    * and is refused by stratetab's own syntax, not taken as the option
    capture ratetab hienergy old, raterat
    assert _rc == 198
}
_rrr_result `=_rc' "RR3 the word in title()/footnote() and ratiodigits() still run"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' RR3"

**# RR4: stratetab's IRR interval on independent samples = poisson Wald limits
local ++test_count
capture noisily {
    _rrr_diet
    * two disjoint samples (old 0 and old 1), each tabulated by hienergy:
    * exposure group 1 = old 0, group 2 = old 1, matched by hienergy label
    quietly strate hienergy if old == 0, output("$RRR_DIR/rr4_e1", replace) nolist
    _rrr_diet
    quietly strate hienergy if old == 1, output("$RRR_DIR/rr4_e2", replace) nolist
    _rrr_diet
    stratetab, using("$RRR_DIR/rr4_e1" "$RRR_DIR/rr4_e2") outcomes(1) ///
        rateratio ratiodigits(8) frame(rr4, replace)
    matrix _R = r(ratios)
    forvalues h = 0/1 {
        _rrr_diet
        gen double pt = _t - _t0
        quietly poisson _d i.old if hienergy == `h', exposure(pt) irr
        local b = _b[1.old]
        local se = _se[1.old]
        local z = invnormal(0.975)
        local want = exp(`b')
        local want_lo = exp(`b' - `z' * `se')
        local want_hi = exp(`b' + `z' * `se')
        assert !missing(_R[`h' + 1, 1]) & !missing(`want')
        assert reldif(_R[`h' + 1, 1], `want') < 1e-7
        * the interval as printed: "est (lo, hi)" at 8 decimals
        frame rr4 {
            local lab = cond(`h' == 0, "No", "Yes")
            * second exposure block holds the ratios; its rows come last
            quietly count
            local last = r(N)
            local row = `last' - 1 + `h'
            local cell = c5[`row']
        }
        assert ustrregexm(`"`cell'"', "^([0-9.]+) \(([0-9.]+), ([0-9.]+)\)$")
        local got_lo = real(ustrregexs(2))
        local got_hi = real(ustrregexs(3))
        assert !missing(`got_lo') & !missing(`got_hi') & !missing(`want_lo') & !missing(`want_hi')
        assert abs(`got_lo' - `want_lo') < 1e-7
        assert abs(`got_hi' - `want_hi') < 1e-7
    }
}
_rrr_result `=_rc' "RR4 stratetab rateratio limits = poisson irr Wald limits (independent samples)"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' RR4"

**# Summary
capture frame drop rr4
capture matrix drop _R
capture shell rm -rf "$RRR_DIR"
capture macro drop RRR_DIR
local fail_count = `test_count' - `pass_count'
if `fail_count' display as error "failed:`failed'"
display as text "RESULT: test_ratetab_rateratio_refusal tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _rrr
if `fail_count' > 0 exit 1
exit 0
