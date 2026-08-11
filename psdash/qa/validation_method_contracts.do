* validation_method_contracts.do
* Published-formula and multi-treatment diagnostic contracts for psdash.

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "validation_method_contracts.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

global PSDASH_MC_TESTS = 0
global PSDASH_MC_PASS = 0
global PSDASH_MC_FAIL = 0
global PSDASH_MC_FAILED ""

capture program drop _psdash_mc_record
program define _psdash_mc_record
    args id rc
    global PSDASH_MC_TESTS = $PSDASH_MC_TESTS + 1
    if `rc' == 0 {
        display as result "PASS: `id'"
        global PSDASH_MC_PASS = $PSDASH_MC_PASS + 1
    }
    else {
        display as error "FAIL: `id' (rc=`rc')"
        global PSDASH_MC_FAIL = $PSDASH_MC_FAIL + 1
        global PSDASH_MC_FAILED "$PSDASH_MC_FAILED `id'"
    }
end

**# Binary covariates use Bernoulli p(1-p), not n/(n-1) p(1-p)
capture noisily {
    clear
    set obs 6
    generate byte treat = _n <= 2
    generate byte xbin = inlist(_n, 1, 3)
    generate double ps = 0.5

    psdash balance treat ps, covariates(xbin) nowvar
    matrix B = r(balance)

    scalar expected_smd = ///
        (0.5 - 0.25) / sqrt((0.5*(1-0.5) + 0.25*(1-0.25))/2)
    scalar expected_vr = (0.5*(1-0.5)) / (0.25*(1-0.25))
    assert abs(B[1, 3] - expected_smd) < 1e-10
    assert abs(B[1, 4] - expected_vr) < 1e-10
}
_psdash_mc_record binary_bernoulli_raw_variance `=_rc'

**# Weighted binary variance is p_w(1-p_w), independent of group N
capture noisily {
    clear
    input byte(treat xbin) double(ps wt)
    1 0 .5 1
    1 1 .5 1
    1 1 .5 8
    0 0 .5 6
    0 1 .5 1
    0 1 .5 1
    0 1 .5 1
    0 1 .5 1
    end

    psdash balance treat ps, covariates(xbin) wvar(wt)
    matrix B = r(balance)

    scalar p_t = 0.9
    scalar p_c = 0.4
    scalar expected_vr = (p_t*(1-p_t)) / (p_c*(1-p_c))
    assert abs(B[1, 9] - expected_vr) < 1e-10
}
_psdash_mc_record binary_bernoulli_weighted_variance `=_rc'

**# Continuous weighted variance uses the scale-invariant unbiased formula
capture noisily {
    clear
    input byte(treat) double(x ps wt)
    1 0 .5 1
    1 1 .5 1
    1 2 .5 8
    0 0 .5 1
    0 1 .5 1
    0 2 .5 1
    end

    psdash balance treat ps, covariates(x) wvar(wt)
    matrix B = r(balance)

    * Treated: sum(w)=10, sum(w^2)=66, mean=1.7, weighted SSE=4.1.
    scalar var_t = 10/(10^2-66) * 4.1
    * Control: ordinary sample variance of {0,1,2}.
    scalar var_c = 1
    assert abs(B[1, 9] - var_t/var_c) < 1e-10
}
_psdash_mc_record continuous_weighted_variance_formula `=_rc'

**# Auto-generated balance weights must not silently drop boundary PS rows
capture noisily {
    clear
    input byte(treat) double(ps x)
    1 0.0 0
    1 0.4 1
    1 0.6 2
    0 0.4 0
    0 0.5 1
    0 0.6 2
    end

    capture noisily psdash balance treat ps, covariates(x)
    assert _rc == 459
}
_psdash_mc_record balance_rejects_undefined_auto_weight `=_rc'

**# Printed exact-boundary warnings are present in machine-readable findings
capture noisily {
    clear
    input byte(treat) double(ps x)
    1 0.0 0
    1 0.5 1
    1 0.6 2
    0 0.0 0
    0 0.5 1
    0 0.6 2
    end

    psdash overlap treat ps, nograph
    assert r(n_ps_boundary) == 2
    assert r(n_warnings) == 1
    assert strpos(`"`r(warnings)'"', "boundary") > 0

    psdash balance treat ps, covariates(x) nowvar
    assert r(n_ps_boundary) == 2
    assert r(n_warnings) == 1
    assert strpos(`"`r(warnings)'"', "boundary") > 0

    psdash support treat ps, nograph
    assert r(n_ps_boundary) == 2
    assert r(n_warnings) == 1
    assert strpos(`"`r(warnings)'"', "boundary") > 0
}
_psdash_mc_record boundary_warning_return_contract `=_rc'

**# Optimized Crump search is numerically identical to the defining grid search
capture noisily {
    clear
    set obs 240
    generate byte treat = mod(_n, 2)
    generate double ps = (_n - 0.25) / 241
    generate double invvar = 1 / (ps * (1 - ps))

    local best_alpha = 0
    local best_diff = .
    quietly summarize invvar
    local full_sample = r(max) <= 2 * r(mean)
    if !`full_sample' {
        forvalues a = 1/49 {
            local alpha = `a' / 100
            quietly summarize invvar if inrange(ps, `alpha', 1 - `alpha')
            if r(N) {
                local diff = abs(1/(`alpha'*(1-`alpha')) - 2*r(mean))
                if missing(`best_diff') | `diff' < `best_diff' {
                    local best_diff = `diff'
                    local best_alpha = `alpha'
                }
            }
        }
        local lo = max(1, round(100 * (`best_alpha' - .01)))
        local hi = min(49, round(100 * (`best_alpha' + .01)))
        forvalues a = `=`lo'*10'/`=`hi'*10' {
            local alpha = `a' / 1000
            quietly summarize invvar if inrange(ps, `alpha', 1 - `alpha')
            if r(N) {
                local diff = abs(1/(`alpha'*(1-`alpha')) - 2*r(mean))
                if `diff' < `best_diff' {
                    local best_diff = `diff'
                    local best_alpha = `alpha'
                }
            }
        }
    }

    psdash support treat ps, crump nograph
    assert abs(r(crump_alpha) - `best_alpha') < 1e-12
}
_psdash_mc_record crump_optimized_search_matches_bruteforce `=_rc'

tempfile multigroup_data
clear
input byte(treat) double(p1 p2 p3)
1 .80 .15 .05
1 .70 .20 .10
1 .60 .25 .15
2 .50 .40 .10
2 .40 .50 .10
2 .30 .60 .10
3 .20 .20 .60
3 .10 .20 .70
3 .05 .15 .80
end
quietly save "`multigroup_data'"

**# Legacy observed-arm scalarization is informational, never a finding
capture noisily {
    use "`multigroup_data'", clear
    psdash overlap treat, psvars(p1 p2 p3) nograph
    assert r(n_gps_violate) == 0
    assert abs(r(pct_outside) - 100*6/9) < 1e-8
    assert r(n_warnings) == 0
    assert strpos(`"`r(warnings)'"', "observed-arm") == 0
}
_psdash_mc_record overlap_ignores_legacy_observed_arm_verdict `=_rc'

**# Each GPS component is summarized within every observed treatment group
capture noisily {
    use "`multigroup_data'", clear
    psdash overlap treat, psvars(p1 p2 p3) nograph
    matrix G = r(gps_means)
    assert rowsof(G) == 3
    assert colsof(G) == 3
    assert abs(G[1,1] - .70) < 1e-10
    assert abs(G[1,2] - .20) < 1e-10
    assert abs(G[1,3] - .10) < 1e-10
    assert abs(G[2,1] - .40) < 1e-10
    assert abs(G[2,2] - .50) < 1e-10
    assert abs(G[2,3] - .10) < 1e-10
    assert abs(G[3,1] - 7/60) < 1e-10
    assert abs(G[3,2] - 11/60) < 1e-10
    assert abs(G[3,3] - .70) < 1e-10
}
_psdash_mc_record overlap_full_gps_by_observed_group `=_rc'

**# Multi-group overlap graph is one panel per GPS component
capture noisily {
    use "`multigroup_data'", clear
    psdash overlap treat, psvars(p1 p2 p3) name(psd_mc_overlap)
    graph describe psd_mc_overlap
    assert strpos("`r(command)'", "combine ") == 1
    graph drop psd_mc_overlap

    generate byte graph_sample = 1
    _psdash_mgps_graph, treatment(treat) samplevar(graph_sample) ///
        psvars(p1 p2 p3) levels(1 2 3) name(psd_mc_design) gpsfloor(.01)
    assert r(K) == 3
    assert "`r(design)'" == "gps_component_by_observed_treatment"
    assert "`r(panel_1_score)'" == "p1"
    assert "`r(panel_2_score)'" == "p2"
    assert "`r(panel_3_score)'" == "p3"
    assert "`r(panel_1_groups)'" == "1 2 3"
    graph drop psd_mc_design
}
_psdash_mc_record overlap_component_panel_graph `=_rc'

**# Detailed GPS panels use relevant floor lines and fill a three-panel row
capture noisily {
    use "`multigroup_data'", clear
    replace p1 = .005 in 1
    generate byte graph_sample = 1

    _psdash_mgps_graph, treatment(treat) samplevar(graph_sample) ///
        psvars(p1 p2 p3) levels(1 2 3) name(psd_mc_detail_layout) ///
        gpsfloor(.01) title("Regression Title")

    assert r(combine_cols) == 3
    assert r(panel_1_floor_line) == 1
    assert r(panel_2_floor_line) == 0
    assert r(panel_3_floor_line) == 0
    assert r(panel_2_min) > .01
    assert r(panel_3_min) > .01

    graph describe psd_mc_detail_layout
    assert strpos("`r(command)'", "cols(3)") > 0
    assert real("`r(xsize)'") >= 2 * real("`r(ysize)'")
    graph drop psd_mc_detail_layout
}
_psdash_mc_record detailed_multigroup_graph_layout `=_rc'

**# Support verdict also ignores the legacy observed-arm scalarization
capture noisily {
    use "`multigroup_data'", clear
    psdash support treat, psvars(p1 p2 p3) nograph
    assert r(n_gps_violate) == 0
    assert abs(r(pct_outside) - 100*6/9) < 1e-8
    assert r(n_warnings) == 0
    assert strpos(`"`r(warnings)'"', "observed-arm") == 0
    matrix G = r(gps_means)
    assert rowsof(G) == 3
    assert colsof(G) == 3
}
_psdash_mc_record support_ignores_legacy_observed_arm_verdict `=_rc'

**# Multi-group support graph uses the same component-panel design
capture noisily {
    use "`multigroup_data'", clear
    psdash support treat, psvars(p1 p2 p3) name(psd_mc_support)
    graph describe psd_mc_support
    assert strpos("`r(command)'", "combine ") == 1
    graph drop psd_mc_support
}
_psdash_mc_record support_component_panel_graph `=_rc'

**# Public compact graphs flatten each diagnostic to one graph region
capture noisily {
    use "`multigroup_data'", clear
    psdash overlap treat, psvars(p1 p2 p3) compact name(psd_mc_overlap_compact)
    graph describe psd_mc_overlap_compact
    assert strpos(`"`r(command)'"', "box ") == 1

    psdash support treat, psvars(p1 p2 p3) compact name(psd_mc_support_compact)
    graph describe psd_mc_support_compact
    assert strpos(`"`r(command)'"', "box ") == 1

    graph drop psd_mc_overlap_compact psd_mc_support_compact
}
_psdash_mc_record public_compact_multigroup_graphs `=_rc'

**# Combined dashboard flattens multi-group overlap/support to one graph region
capture noisily {
    use "`multigroup_data'", clear
    generate double x = _n
    generate double wt = 1

    psdash combined treat, psvars(p1 p2 p3) covariates(x) wvar(wt)

    graph describe psdash_c_overlap
    assert strpos(`"`r(command)'"', "box ") == 1
    assert strpos(`"`r(command)'"', `"`"PS Overlap"'"') > 0
    assert strpos(`"`r(command)'"', `"`"`"PS Overlap"'"'"') == 0

    graph describe psdash_c_support
    assert strpos(`"`r(command)'"', "box ") == 1
    assert strpos(`"`r(command)'"', `"`"Common Support"'"') > 0
    assert strpos(`"`r(command)'"', `"`"`"Common Support"'"'"') == 0

    graph drop psdash_c_overlap psdash_c_balance psdash_c_weights ///
        psdash_c_support psdash_combined
}
_psdash_mc_record combined_multigroup_single_region_graphs `=_rc'

**# Automatic weight axis uses compact nice ticks and caps a remote tail explicitly
capture noisily {
    clear
    set obs 1000
    generate byte treat = mod(_n, 2)
    generate double ps = 0.5
    generate double wt = 1 + 4 * mod(_n, 100) / 99
    replace wt = 100 in 1000

    psdash weights treat ps, wvar(wt) graph compact name(psd_mc_weight_axis)
    graph describe psd_mc_weight_axis
    assert strpos(`"`r(command)'"', "xlabel(0(2)10,") > 0
    assert strpos(`"`r(command)'"', "wt <= 10") > 0
    assert strpos(`"`r(command)'"', "1 weight above 10") > 0
    assert strpos(`"`r(command)'"', "fraction") > 0
    graph drop psd_mc_weight_axis
}
_psdash_mc_record weights_adaptive_tail_axis `=_rc'

display as text _n "RESULT: validation_method_contracts tests=$PSDASH_MC_TESTS pass=$PSDASH_MC_PASS fail=$PSDASH_MC_FAIL skip=0"

local final_fail = $PSDASH_MC_FAIL
local failed "$PSDASH_MC_FAILED"
macro drop PSDASH_MC_TESTS PSDASH_MC_PASS PSDASH_MC_FAIL PSDASH_MC_FAILED

_psdash_qa_cleanup
capture log close _all

if `final_fail' > 0 {
    display as error "Failed tests:`failed'"
    exit 9
}
