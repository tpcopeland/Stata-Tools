* test_rb12_kimi_audit.do — RB-12 regressions from the 2026-07-24 kimi audit
*
* Six defects, each reproduced against shipped psdash 1.5.0 before the fix:
*
*   F1 (HIGH)  _psdash_detect took the FIRST element of psvars() as "the" PS for a
*              binary 0/1 treatment. Under the documented ascending-level
*              convention that element is P(A=0|X), so every binary formula ran on
*              an inverted score at rc=0. Old: psvars(ps0 ps1) gave mean weight
*              2.2854 where the correct value is 2.0000.
*   F2 (MOD)   multi-group psdash overlap called _psdash_support_stats and threw
*              away its GPS-positivity returns, so the M1 design (observed-arm
*              probability in [.55,.65], 107 units with another arm at ~.001)
*              produced "Overlap: Good", n_warnings = 0. support saw all 107.
*   F3 (MOD)   stabilize applied the ATE formula sw = P(A=a)*w to ATT/ATC weights.
*              The cautionary note fired only for USER-supplied weights, so
*              auto-generated ATT weights were rescaled silently. Old: rc=0 with
*              treated-arm "stabilized" weights = P(T=1) instead of 1.
*   F4 (MIN)   untrimmed multi-group generate() built the indicator from the
*              observed-arm min-max rule that the same output labels "informational
*              only; NOT a valid multi-arm common-support rule". Old: 104 of 107
*              GPS-positivity violators marked in-support.
*   F7 (NIT)   multi-group support displayed and returned a two-sided trim region
*              [t, 1-t]; the code applies only the lower floor min_j e_j >= t.
*   F8 (NIT)   longitudinal result matrices used positional rownames p1 p2 ...
*              rather than the period values, forcing a positional join.
*   F10 (NIT)  balance never reported that a covariate with missing values is
*              summarized on fewer observations than the panel N.
*
* Fail-on-old: every assertion below was run against a copy of shipped 1.5.0.
* F1/F2/F4/F7/F8/F10 assertions fail there; F3's reject assertion fails there.
*
* Three false greens named and defused:
*   FG1  "the F1 assertion passes because both paths are broken the same way" ->
*        S1 pins the psvars() answer to an independently computed known truth
*        (mean of 1/P(A=own)), not merely to the positional-argument path.
*   FG2  "the F2 finding fires on the observed-arm rule, not on GPS" -> the M1
*        design keeps every observed-arm probability inside [.55,.65], so
*        pct_outside is small and only a GPS-based finding can raise n_warnings;
*        the assertion names r(n_gps_violate) explicitly.
*   FG3  "F3 rejects everything, including valid ATE stabilization" -> a positive
*        control stabilizes ATE weights and asserts rc=0 plus the ATE identity
*        mean(sw) ~ 1.
*
* Usage: cd psdash/qa && stata-mp -b do test_rb12_kimi_audit.do

clear all
version 16.0
set more off

capture log close _all
log using "test_rb12_kimi_audit.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"

global N_PASS = 0
global N_FAIL = 0
global FAILED ""

capture program drop _t
program define _t
    args id rc
    if `rc' == 0 {
        display as result "  PASS: `id'"
        global N_PASS = $N_PASS + 1
    }
    else {
        display as error "  FAIL: `id' (rc=`rc')"
        global N_FAIL = $N_FAIL + 1
        global FAILED "$FAILED `id'"
    }
end

* Binary fixture: known-truth ATE weight is 1/P(A=own arm)
capture program drop _rb12_binary
program define _rb12_binary
    clear
    set seed 12345
    set obs 400
    gen double x = rnormal()
    gen double ps1 = invlogit(0.5*x)
    gen byte treat = runiform() < ps1
    gen double ps0 = 1 - ps1
    gen double w_truth = cond(treat == 1, 1/ps1, 1/ps0)
end

* M1 fixture (Li & Li 2019 Assumption 2 failure): every unit's OBSERVED-arm
* probability sits in [.55,.65], so the observed-arm min-max rule sees nothing;
* 107 units carry a ~.001 probability of one UNRECEIVED arm.
capture program drop _rb12_m1
program define _rb12_m1
    clear
    set seed 4242
    set obs 1000
    gen byte arm = floor(3*runiform())
    gen double own = 0.55 + 0.10*runiform()
    gen byte viol = (_n <= 107)
    gen double rest = 1 - own
    gen double small = cond(viol, 0.001, rest/2)
    gen double other = rest - small
    gen double p0 = .
    gen double p1 = .
    gen double p2 = .
    replace p0 = own if arm == 0
    replace p1 = own if arm == 1
    replace p2 = own if arm == 2
    replace p1 = small if arm == 0
    replace p2 = other if arm == 0
    replace p0 = small if arm == 1
    replace p2 = other if arm == 1
    replace p0 = small if arm == 2
    replace p1 = other if arm == 2
    assert abs(p0 + p1 + p2 - 1) < 1e-9
end

**# F1a — binary psvars() maps to P(A=1|X), matching the known-truth weight
capture noisily {
    _rb12_binary
    quietly summarize w_truth
    local truth = r(mean)
    psdash weights treat, psvars(ps0 ps1) nograph
    * OLD: r(mean_wt) = 2.2854 (built on ps0 = P(A=0|X)); truth = 2.0000
    assert abs(r(mean_wt) - `truth') < 1e-8
}
_t "F1a_binary_psvars_maps_by_level" `=_rc'

**# F1b — a lone psvars() variable is still the ordinary binary PS
capture noisily {
    _rb12_binary
    quietly summarize w_truth
    local truth = r(mean)
    psdash weights treat, psvars(ps1) nograph
    assert abs(r(mean_wt) - `truth') < 1e-8
}
_t "F1b_binary_single_psvar_unchanged" `=_rc'

**# F1c — the binary psvars() path now gets the multi-group [0,1] / sum-to-1 checks
capture noisily {
    _rb12_binary
    gen double ps_bad = 0.3                      // 0.3 + ps1 != 1
    capture noisily psdash weights treat, psvars(ps_bad ps1) nograph
    assert _rc == 198                            // OLD: rc=0, silently used ps_bad
    drop ps_bad
    gen double ps_oob = 1.4
    capture noisily psdash weights treat, psvars(ps_oob ps1) nograph
    assert _rc == 198                            // OLD: rc=0
}
_t "F1c_binary_psvars_validated" `=_rc'

**# F1d — more than two psvars() for a binary treatment is an explicit error
capture noisily {
    _rb12_binary
    gen double junk = 0
    capture noisily psdash weights treat, psvars(ps0 ps1 junk) nograph
    assert _rc == 198                            // OLD: rc=0, silently used ps0
}
_t "F1d_binary_psvars_too_many_rejected" `=_rc'

**# F1e — the fix reaches every panel, not just weights
capture noisily {
    _rb12_binary
    psdash overlap treat, psvars(ps0 ps1) nograph
    local a_mt = r(mean_ps_treated)
    psdash overlap treat ps1, nograph
    assert abs(`a_mt' - r(mean_ps_treated)) < 1e-10   // OLD: differed
}
_t "F1e_binary_psvars_panels_agree" `=_rc'

**# F2 — multi-group overlap surfaces full-vector GPS positivity
capture noisily {
    _rb12_m1
    psdash overlap arm, psvars(p0 p1 p2) nograph
    confirm scalar r(n_gps_violate)              // OLD: not returned at all
    assert r(n_gps_violate) == 107
    assert abs(r(min_gps) - 0.001) < 1e-9
    assert r(gps_floor) == 0.01
    assert !missing(r(n_warnings))
    assert r(n_warnings) >= 1                    // OLD: 0 ("Overlap: Good")
    * FG2: the finding is GPS-based, not the observed-arm rule
    assert r(pct_outside) <= 10
    assert strpos(`"`r(warnings)'"', "GPS positivity floor") > 0
}
_t "F2_multigroup_overlap_gps_finding" `=_rc'

**# F2b — overlap and support agree on the GPS block
capture noisily {
    _rb12_m1
    psdash overlap arm, psvars(p0 p1 p2) nograph
    local o_nv = r(n_gps_violate)
    local o_mg = r(min_gps)
    psdash support arm, psvars(p0 p1 p2) nograph
    assert `o_nv' == r(n_gps_violate)
    assert abs(`o_mg' - r(min_gps)) < 1e-12
}
_t "F2b_overlap_support_gps_agree" `=_rc'

**# F2c — gpsfloor() is honoured and validated in overlap
capture noisily {
    _rb12_m1
    psdash overlap arm, psvars(p0 p1 p2) nograph gpsfloor(0.0005)
    assert r(gps_floor) == 0.0005
    assert r(n_gps_violate) == 0                 // .001 clears a .0005 floor
    capture noisily psdash overlap arm, psvars(p0 p1 p2) nograph gpsfloor(0)
    assert _rc == 198
    capture noisily psdash overlap arm, psvars(p0 p1 p2) nograph gpsfloor(1)
    assert _rc == 198
}
_t "F2c_overlap_gpsfloor_option" `=_rc'

**# F2d — combined forwards gpsfloor() to both panels and fails on M1
capture noisily {
    _rb12_m1
    gen double x = rnormal()
    * overlap panel alone: OLD reported PASS on this design
    psdash combined arm, psvars(p0 p1 p2) covariates(x) nobalance noweights nosupport
    assert "`r(verdict)'" == "FAIL"
    assert !missing(r(n_warnings))
    assert r(n_warnings) >= 1
    * gpsfloor() must reach the panels, not be silently dropped
    psdash combined arm, psvars(p0 p1 p2) covariates(x) ///
        nobalance noweights nosupport gpsfloor(0.0005)
    assert "`r(verdict)'" == "PASS"
    capture noisily psdash combined arm, psvars(p0 p1 p2) covariates(x) gpsfloor(1.5)
    assert _rc == 198
}
_t "F2d_combined_gpsfloor_forwarded" `=_rc'

**# F3 — stabilize is refused for auto-generated ATT/ATC weights
capture noisily {
    _rb12_binary
    capture noisily psdash weights treat ps1, estimand(att) stabilize ///
        generate(w_att_st) nograph
    assert _rc == 198                            // OLD: rc=0, treated w = P(T=1)
    capture confirm variable w_att_st            // must not be created
    assert _rc != 0
    capture noisily psdash weights treat ps1, estimand(atc) stabilize ///
        generate(w_atc_st) nograph
    assert _rc == 198
}
_t "F3_stabilize_rejected_for_att_atc" `=_rc'

**# F3b — FG3 positive control: ATE stabilization still works and is on scale
capture noisily {
    _rb12_binary
    psdash weights treat ps1, estimand(ate) stabilize generate(w_ate_st) nograph
    assert _rc == 0
    quietly summarize w_ate_st
    * sw = P(A=a)/P(A=a|X) has mean 1 in expectation; 400 obs -> loose tolerance
    assert abs(r(mean) - 1) < 0.05
}
_t "F3b_stabilize_ate_positive_control" `=_rc'

**# F4 — untrimmed multi-group generate() uses the GPS floor, not the disowned rule
capture noisily {
    _rb12_m1
    psdash support arm, psvars(p0 p1 p2) nograph generate(insup)
    quietly count if insup == 1 & viol
    assert r(N) == 0                             // OLD: 104 violators kept
    quietly count if insup == 1
    assert r(N) == 893                           // OLD: 992
    local lbl : variable label insup
    assert strpos("`lbl'", "All GPS components") == 1
}
_t "F4_multigroup_generate_uses_gps_floor" `=_rc'

**# F4b — generate() tracks gpsfloor()
capture noisily {
    _rb12_m1
    psdash support arm, psvars(p0 p1 p2) nograph gpsfloor(0.0005) generate(insup2)
    quietly count if insup2 == 1
    assert r(N) == 1000
}
_t "F4b_multigroup_generate_tracks_gpsfloor" `=_rc'

**# F7 — no two-sided trim bound for multi-group
capture noisily {
    _rb12_m1
    psdash support arm, psvars(p0 p1 p2) nograph threshold(0.05)
    assert abs(r(trim_lower) - 0.05) < 1e-12
    capture confirm scalar r(trim_upper)         // OLD: returned 0.95
    assert _rc != 0
    * binary support keeps the genuine two-sided region
    _rb12_binary
    psdash support treat ps1, nograph threshold(0.05)
    confirm scalar r(trim_upper)
    assert abs(r(trim_upper) - 0.95) < 1e-12
}
_t "F7_multigroup_trim_is_one_sided" `=_rc'

**# F8 — longitudinal matrices carry period-value rownames
capture noisily {
    clear
    set seed 77
    set obs 400
    gen long id = ceil(_n/4)
    bysort id: gen int period = _n - 1           // periods 0..3, NOT 1..4
    gen double ps = 0.3 + 0.4*runiform()
    gen byte t = runiform() < ps
    gen double w = cond(t == 1, 1/ps, 1/(1-ps))
    gen byte touse = 1
    _psdash_ltmle_diagnostics, treatment(t) period(period) ///
        psvar(ps) wvar(w) samplevar(touse)
    matrix OV = r(overlap_by_period)
    local rn : rownames OV
    assert "`rn'" == "p0 p1 p2 p3"               // OLD: "p1 p2 p3 p4"
    matrix WP = r(weights_by_period)
    local rnw : rownames WP
    assert "`rnw'" == "p0 p1 p2 p3"
    * rownames must line up with r(periods) value by value
    assert "`r(periods)'" == "0 1 2 3"
}
_t "F8_longitudinal_rownames_are_period_values" `=_rc'

**# F10 — balance reports per-covariate missingness instead of hiding it
capture noisily {
    _rb12_binary
    gen double z = rnormal()
    replace z = . in 1/40                        // 40 obs missing on z only
    psdash balance treat ps1, covariates(x z)
    confirm scalar r(n_cov_incomplete)           // OLD: not returned
    assert r(n_cov_incomplete) == 1
    assert r(n_cov_min) == 360
    assert "`r(cov_miss_vars)'" == "z"
    * complete covariates report nothing
    psdash balance treat ps1, covariates(x)
    assert r(n_cov_incomplete) == 0
    capture confirm scalar r(n_cov_min)
    assert _rc == 0
    assert r(n_cov_min) == r(N)
}
_t "F10_balance_reports_covariate_missingness" `=_rc'

local rb12_tests = $N_PASS + $N_FAIL
display as text _n "RESULT: test_rb12_kimi_audit tests=`rb12_tests' pass=$N_PASS fail=$N_FAIL skip=0"
if "$FAILED" != "" display as error "  failed: $FAILED"

capture _rb12_qa_cleanup
capture _psdash_qa_cleanup
capture log close _all
if $N_FAIL > 0 exit 9
