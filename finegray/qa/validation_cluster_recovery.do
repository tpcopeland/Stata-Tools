* validation_cluster_recovery.do - Known-truth clustered Fine-Gray recovery
* Package: finegray
*
* Source: Zhou, Fine, Latouche, and Labopin (2012), Biostatistics
* 13(3):371-383, section 4.1, p.377. Their shared positive-stable frailty
* construction has an exact marginal Fine-Gray coefficient beta = alpha*tau,
* despite correlated outcomes within clusters. Censoring follows the paper's
* U[0.3,1.5] design. This is a marginal-model oracle, not a frailty-model fit.
*
* The positive-stable draws use the Chambers-Mallows-Stuck construction and
* are independently checked against E{exp(-s V)} = exp(-s^alpha).

clear all
set varabbrev off
version 16.0

capture log close _all
log using "validation_cluster_recovery.log", replace text name(_clrec)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qadir "`c(pwd)'"
local pkg_dir = regexr("`qadir'", "/qa$", "")
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "validation_cluster_recovery.do must run from finegray/qa"
    capture log close _clrec
    exit 601
}

capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

capture program drop _zhou_cluster_dgp
program define _zhou_cluster_dgp
    syntax , CLUSTERS(integer) ALPHA(real) GAMMA(real) BETA(real) ///
        [DESIGN(string) BETA2(real 0.3)]

    if !inrange(`alpha', 0.01, 0.99) | !inrange(`gamma', 0.01, 0.99) {
        display as error "alpha and gamma must lie strictly between zero and one"
        exit 198
    }
    if "`design'" == "" local design "constant"
    if !inlist("`design'", "constant", "matched") {
        display as error "design() must be constant or matched"
        exit 198
    }

    quietly {
        clear
        set obs `clusters'
        gen long clid = _n
        if "`design'" == "matched" {
            gen byte m = 2
        }
        else {
            * stata-dev-ignore: unseeded-draw — this is a generator PROGRAM, not a script: every call site seeds immediately before calling it (`set seed 291002', `291003', `291004' below, and `291001' before K1's inline draws), so every draw in this file replays
            gen byte m = 2 + floor(4*runiform())
        }

        * One cause-specific positive-stable frailty per cluster and cause.
        gen double av = c(pi)*max(runiform(), 1e-12)
        gen double ev = -ln(max(runiform(), 1e-12))
        gen double v = (sin(`alpha'*av)/(sin(av)^(1/`alpha'))) * ///
            (sin((1-`alpha')*av)/ev)^((1-`alpha')/`alpha')
        gen double ah = c(pi)*max(runiform(), 1e-12)
        gen double eh = -ln(max(runiform(), 1e-12))
        gen double h = (sin(`gamma'*ah)/(sin(ah)^(1/`gamma'))) * ///
            (sin((1-`gamma')*ah)/eh)^((1-`gamma')/`gamma')

        expand m
        bysort clid: gen byte member = _n
        if "`design'" == "matched" {
            gen byte z = member - 1
        }
        else {
            by clid: gen double z = rnormal() if _n == 1
            by clid: replace z = z[1]
        }

        local tau1 = `beta'/`alpha'
        local tau2 = `beta2'/`gamma'
        gen double p1 = 1 - exp(-v*exp(`tau1'*z))
        gen byte cause = cond(runiform() < p1, 1, 2)
        gen double u1 = runiform()
        gen double m1 = -ln(1-u1*p1)/(v*exp(`tau1'*z))
        replace m1 = min(m1, 1-1e-12)
        gen double t1 = -ln(1-m1)
        gen double t2 = -ln(max(runiform(), 1e-12))/(h*exp(`tau2'*z))
        gen double tevent = cond(cause == 1, t1, t2)
        gen double censor = 0.3 + 1.2*runiform()
        gen double time = min(tevent, censor)
        gen byte status = cond(tevent <= censor, cause, 0)
        gen byte anyevent = status != 0
        gen long sid = _n
        drop m member av ev ah eh p1 u1 m1 t1 t2 tevent censor
    }
end

**# K1: Positive-stable generator satisfies its defining Laplace transform
local ++test_count
capture noisily {
    clear
    set seed 291001
    set obs 250000
    local alpha = 0.3
    gen double a = c(pi)*max(runiform(), 1e-12)
    gen double e = -ln(max(runiform(), 1e-12))
    gen double v = (sin(`alpha'*a)/(sin(a)^(1/`alpha'))) * ///
        (sin((1-`alpha')*a)/e)^((1-`alpha')/`alpha')
    foreach spec in "s05 0.5" "s1 1" "s2 2" {
        gettoken tag s : spec
        gen double l_`tag' = exp(-`s'*v)
        quietly summarize l_`tag', meanonly
        local err_`tag' = abs(r(mean) - exp(-(`s'^`alpha')))
        assert `err_`tag'' < 0.003
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K1 positive-stable Laplace identity (max error < 0.003)"
}
else {
    local ++fail_count
    display as error "  FAIL: K1 positive-stable generator (rc=`=_rc')"
}

**# K2: Cluster-constant covariate, strong dependence (alpha=0.3)
local ++test_count
capture noisily {
    set seed 291002
    _zhou_cluster_dgp, clusters(5000) alpha(0.3) gamma(0.7) ///
        beta(0.5) design(constant)
    quietly stset time, failure(anyevent == 1) id(sid)
    quietly finegray z, compete(status) cause(1) nuisance noadjust nolog
    local b_naive = _b[z]
    local se_naive = _se[z]
    quietly finegray z, compete(status) cause(1) cluster(clid) ///
        nuisance noadjust nolog
    local b_cluster = _b[z]
    local se_cluster = _se[z]
    local z_truth = abs(`b_cluster' - 0.5)/`se_cluster'
    assert e(converged) == 1
    assert e(N_clust) == 5000
    assert abs(`b_cluster' - `b_naive') < 1e-10
    assert `z_truth' < 4
    assert abs(`b_cluster' - 0.5/0.3) > 8*`se_cluster'
    assert `se_cluster'/`se_naive' > 1.25
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K2 cluster-constant truth b=0.5 (b=`=string(`b_cluster',"%7.4f")', z=`=string(`z_truth',"%5.2f")', SE ratio=`=string(`se_cluster'/`se_naive',"%5.2f")')"
}
else {
    local ++fail_count
    display as error "  FAIL: K2 cluster-constant recovery (rc=`=_rc')"
}

**# K3: Matched pairs reverse the naive-versus-cluster variance direction
local ++test_count
capture noisily {
    set seed 291003
    _zhou_cluster_dgp, clusters(8000) alpha(0.3) gamma(0.7) ///
        beta(0.5) design(matched)
    quietly stset time, failure(anyevent == 1) id(sid)
    quietly finegray z, compete(status) cause(1) nuisance noadjust nolog
    local b_match_naive = _b[z]
    local se_match_naive = _se[z]
    quietly finegray z, compete(status) cause(1) cluster(clid) ///
        nuisance noadjust nolog
    local b_match = _b[z]
    local se_match = _se[z]
    local z_match = abs(`b_match' - 0.5)/`se_match'
    display as text "    matched clusters used=" e(N_clust) ///
        ", SE ratio=" %6.3f (`se_match'/`se_match_naive')
    assert e(converged) == 1
    * A cluster whose two records both lie beyond the last cause-1 risk set is
    * trimmed by the estimator; require essentially the full generated sample.
    assert !missing(e(N_clust))
    assert e(N_clust) >= 7995
    assert abs(`b_match' - `b_match_naive') < 1e-10
    assert `z_match' < 4
    assert abs(`b_match' - 0.5/0.3) > 8*`se_match'
    assert `se_match'/`se_match_naive' < 0.95
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K3 matched truth b=0.5 (b=`=string(`b_match',"%7.4f")', z=`=string(`z_match',"%5.2f")', SE ratio=`=string(`se_match'/`se_match_naive',"%5.2f")')"
}
else {
    local ++fail_count
    display as error "  FAIL: K3 matched-pair recovery/direction (rc=`=_rc')"
}

**# K4: Weaker cause-1 dependence and different competing-event frailty
local ++test_count
capture noisily {
    set seed 291004
    _zhou_cluster_dgp, clusters(6000) alpha(0.7) gamma(0.3) ///
        beta(-0.4) beta2(-0.2) design(constant)
    quietly stset time, failure(anyevent == 1) id(sid)
    quietly finegray z, compete(status) cause(1) cluster(clid) ///
        nuisance noadjust nolog
    local b_weak = _b[z]
    local se_weak = _se[z]
    local z_weak = abs(`b_weak' + 0.4)/`se_weak'
    assert e(converged) == 1
    assert `z_weak' < 4
    assert abs(`b_weak' - (-0.4/0.7)) > 4*`se_weak'
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K4 varied frailties truth b=-0.4 (b=`=string(`b_weak',"%7.4f")', z=`=string(`z_weak',"%5.2f")')"
}
else {
    local ++fail_count
    display as error "  FAIL: K4 varied-frailty recovery (rc=`=_rc')"
}

display as text "RESULT: validation_cluster_recovery tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _clrec

if `fail_count' > 0 exit 1
