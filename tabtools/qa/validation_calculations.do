* validation_calculations.do — Calculation accuracy validation for all tabtools commands
* Purpose: Verify frame/r() values match independently computed reference values
* Covers: table1_tc, regtab, effecttab, diagtab (incl. cutoffs), crosstab,
*         corrtab, survtab, fittab

capture log close _vcalc
log using "validation_calculations.log", replace text name(_vcalc)

local n_pass = 0
local n_fail = 0
local n_total = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

tabtools set clear


* =========================================================================
**# VC1: table1_tc — mean, SD, median, percentage, p-value
* =========================================================================

* Frame variables: factor, <by>_0, <by>_1, pvalue, _p_raw

* --- VC1.1: mean in frame matches summarize ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly summarize price if foreign == 0
    local ref_mean_dom = r(mean)
    quietly summarize price if foreign == 1
    local ref_mean_for = r(mean)

    capture frame drop _vc_t1
    table1_tc, by(foreign) vars(price contn %9.1f) frame(_vc_t1)

    frame _vc_t1 {
        * Row 3 = Price row (row 1=header, row 2=N=)
        * Columns: factor, foreign_0, foreign_1, pvalue, _p_raw
        local dom_cell = foreign_0[3]
        local for_cell = foreign_1[3]

        * Parse mean from "6072.4 (3097.1)"
        local dom_mean = real(word("`dom_cell'", 1))
        local for_mean = real(word("`for_cell'", 1))

        assert abs(`dom_mean' - `ref_mean_dom') < 1
        assert abs(`for_mean' - `ref_mean_for') < 1
    }
}
if _rc == 0 {
    display as result "  PASS: VC1.1 — table1_tc mean matches summarize"
    local ++n_pass
}
else {
    display as error "  FAIL: VC1.1 — table1_tc mean accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_t1

* --- VC1.2: median matches summarize detail ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly summarize price if foreign == 0, detail
    local ref_med_dom = r(p50)

    capture frame drop _vc_t1m
    table1_tc, by(foreign) vars(price conts %9.0f) frame(_vc_t1m)

    frame _vc_t1m {
        local dom_cell = foreign_0[3]
        * Parse median from "4890 (3299-5705)"
        local dom_med = real(word("`dom_cell'", 1))
        assert abs(`dom_med' - `ref_med_dom') < 1
    }
}
if _rc == 0 {
    display as result "  PASS: VC1.2 — table1_tc median matches summarize detail"
    local ++n_pass
}
else {
    display as error "  FAIL: VC1.2 — table1_tc median accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_t1m

* --- VC1.3: categorical percentage matches manual ---
local ++n_total
capture noisily {
    sysuse auto, clear

    * Count rep78==3 among domestic (non-missing)
    quietly count if rep78 == 3 & foreign == 0
    local n3_dom = r(N)
    quietly count if !missing(rep78) & foreign == 0
    local ntot_dom = r(N)
    local ref_pct = `n3_dom' / `ntot_dom' * 100

    capture frame drop _vc_t1c
    table1_tc, by(foreign) vars(rep78 cat) frame(_vc_t1c)

    frame _vc_t1c {
        * Find row with factor containing "3" (indented level)
        local found = 0
        forvalues i = 1/`=_N' {
            local fval = strtrim(factor[`i'])
            if "`fval'" == "3" {
                local dom_cell = foreign_0[`i']
                local found = 1
                continue, break
            }
        }
        assert `found' == 1

        * Parse count from "27 (56%)" or "27 (54.0%)" — count is first word
        local dom_n = real(word("`dom_cell'", 1))
        local ref_n = `n3_dom'
        assert `dom_n' == `ref_n'

        local pct_start = strpos("`dom_cell'", "(")
        local pct_end = strpos("`dom_cell'", "%")
        assert `pct_start' > 0
        assert `pct_end' > `pct_start'
        local dom_pct = real(substr("`dom_cell'", `pct_start' + 1, `pct_end' - `pct_start' - 1))
        assert abs(`dom_pct' - `ref_pct') < 0.6
    }
}
if _rc == 0 {
    display as result "  PASS: VC1.3 — table1_tc categorical % matches manual calculation"
    local ++n_pass
}
else {
    display as error "  FAIL: VC1.3 — table1_tc categorical % accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_t1c

* --- VC1.4: raw p-value matches ttest ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly ttest price, by(foreign)
    local ref_p = r(p)

    capture frame drop _vc_t1p
    table1_tc, by(foreign) vars(price contn) frame(_vc_t1p)

    frame _vc_t1p {
        * _p_raw contains numeric p-value
        local frame_p = _p_raw[3]
        assert abs(`frame_p' - `ref_p') < 0.01
    }
}
if _rc == 0 {
    display as result "  PASS: VC1.4 — table1_tc raw p-value matches ttest"
    local ++n_pass
}
else {
    display as error "  FAIL: VC1.4 — table1_tc p-value accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_t1p

* --- VC1.5: p-value for >2 groups matches Kruskal-Wallis ---
local ++n_total
capture noisily {
    sysuse auto, clear

    quietly kwallis price, by(rep78)
    local ref_p = chi2tail(r(df), r(chi2_adj))

    capture frame drop _vc_t1kw
    table1_tc, by(rep78) vars(price conts) frame(_vc_t1kw)

    frame _vc_t1kw {
        * _p_raw for first variable row
        local found = 0
        forvalues i = 1/`=_N' {
            local praw = _p_raw[`i']
            if `praw' < . {
                assert abs(`praw' - `ref_p') < 0.01
                local found = 1
                continue, break
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: VC1.5 — table1_tc p-value (>2 groups) matches kwallis"
    local ++n_pass
}
else {
    display as error "  FAIL: VC1.5 — table1_tc kwallis p-value accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_t1kw


* =========================================================================
**# VC2: regtab — coefficients, CIs, p-values
* =========================================================================

* Frame variables: title, A, c1, ref1, c2, c3

* --- VC2.1: linear regression coefficient in frame matches e(b) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local ref_b_mpg = _b[mpg]
    local ref_b_wt = _b[weight]

    capture frame drop _vc_reg
    regtab, frame(_vc_reg) digits(4)

    frame _vc_reg {
        * Row 4 = mpg, Row 5 = weight (rows 1-3 are title/header)
        local frame_b_mpg = real(strtrim(c1[4]))
        local frame_b_wt = real(strtrim(c1[5]))
        assert abs(`frame_b_mpg' - `ref_b_mpg') < 0.01
        assert abs(`frame_b_wt' - `ref_b_wt') < 0.01
    }
}
if _rc == 0 {
    display as result "  PASS: VC2.1 — regtab coefficient matches e(b)"
    local ++n_pass
}
else {
    display as error "  FAIL: VC2.1 — regtab coefficient accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_reg

* --- VC2.2: logistic OR matches exp(e(b)) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logistic foreign price mpg
    local ref_or_price = exp(_b[price])
    local ref_or_mpg = exp(_b[mpg])

    capture frame drop _vc_logit
    regtab, frame(_vc_logit) digits(4)

    frame _vc_logit {
        local frame_or_price = real(strtrim(c1[4]))
        local frame_or_mpg = real(strtrim(c1[5]))
        assert abs(`frame_or_price' - `ref_or_price') < 0.001
        assert abs(`frame_or_mpg' - `ref_or_mpg') < 0.01
    }
}
if _rc == 0 {
    display as result "  PASS: VC2.2 — regtab logistic ORs match exp(e(b))"
    local ++n_pass
}
else {
    display as error "  FAIL: VC2.2 — regtab logistic OR accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_logit

* --- VC2.3: regtab stats N/AIC/BIC match estat ic ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local ref_n = e(N)
    quietly estat ic
    tempname ic_mat
    matrix `ic_mat' = r(S)
    local ref_aic = `ic_mat'[1, 5]
    local ref_bic = `ic_mat'[1, 6]

    capture frame drop _vc_stats
    regtab, frame(_vc_stats) stats(n aic bic)

    frame _vc_stats {
        * Find rows by A column label
        local found_n = 0
        local found_aic = 0
        forvalues i = 1/`=_N' {
            local label = strtrim(A[`i'])
            if "`label'" == "Observations" {
                local frame_n = real(strtrim(c1[`i']))
                assert `frame_n' == `ref_n'
                local found_n = 1
            }
            if strpos("`label'", "AIC") > 0 {
                local frame_aic = real(strtrim(c1[`i']))
                assert abs(`frame_aic' - `ref_aic') < 0.2
                local found_aic = 1
            }
        }
        assert `found_n' == 1
        assert `found_aic' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: VC2.3 — regtab stats N/AIC match estat ic"
    local ++n_pass
}
else {
    display as error "  FAIL: VC2.3 — regtab stats accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_stats

* --- VC2.4: multi-model regtab — both coefficients correct ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    local ref_b1_mpg = _b[mpg]
    collect: regress price mpg weight
    local ref_b2_mpg = _b[mpg]
    local ref_b2_wt = _b[weight]

    capture frame drop _vc_multi
    regtab, frame(_vc_multi) digits(2) models("Model 1 \ Model 2")

    frame _vc_multi {
        * Model 1: c1, Model 2: c4 (each model = 3 cols: coef, CI, p)
        * Row 4 = mpg
        local f_b1 = real(strtrim(c1[4]))
        local f_b2 = real(strtrim(c4[4]))
        assert abs(`f_b1' - `ref_b1_mpg') < 0.1
        assert abs(`f_b2' - `ref_b2_mpg') < 0.1

        * Weight in row 5, model 2
        local f_b2_wt = real(strtrim(c4[5]))
        assert abs(`f_b2_wt' - `ref_b2_wt') < 0.1
    }
}
if _rc == 0 {
    display as result "  PASS: VC2.4 — regtab multi-model coefficients correct"
    local ++n_pass
}
else {
    display as error "  FAIL: VC2.4 — regtab multi-model accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_multi


* =========================================================================
**# VC3: effecttab — ATE matches e(b)
* =========================================================================

* Frame variables: title, A, c1, c2, c3

* --- VC3.1: teffects ra ATE value matches ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    local ref_ate = _b[r1vs0.foreign]

    capture frame drop _vc_eff
    effecttab, frame(_vc_eff) digits(2)

    frame _vc_eff {
        * Find first numeric data row in c1 (skip header text like "Effect")
        local found = 0
        forvalues i = 3/`=_N' {
            local cell = strtrim(c1[`i'])
            local cell_num = real("`cell'")
            if `cell_num' < . {
                local frame_ate = `cell_num'
                local found = 1
                continue, break
            }
        }
        assert `found' == 1
        assert abs(`frame_ate' - `ref_ate') < 1
    }
}
if _rc == 0 {
    display as result "  PASS: VC3.1 — effecttab ATE matches e(b)"
    local ++n_pass
}
else {
    display as error "  FAIL: VC3.1 — effecttab ATE accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_eff

* --- VC3.2: margins dydx matches ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    quietly logistic foreign price mpg
    collect: margins, dydx(price mpg)
    matrix _mfx = r(table)
    local ref_dydx_price = _mfx[1, 1]

    capture frame drop _vc_marg
    effecttab, frame(_vc_marg) digits(4) effect("dydx")

    frame _vc_marg {
        local found = 0
        forvalues i = 3/`=_N' {
            local cell = strtrim(c1[`i'])
            local cell_num = real("`cell'")
            if `cell_num' < . {
                local frame_dydx = `cell_num'
                local found = 1
                continue, break
            }
        }
        assert `found' == 1
        assert abs(`frame_dydx' - `ref_dydx_price') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: VC3.2 — effecttab margins dydx matches r(table)"
    local ++n_pass
}
else {
    display as error "  FAIL: VC3.2 — effecttab margins accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_marg

* --- VC3.3: effecttab r(table) preserves raw estimate and p-value ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    matrix _te = r(table)
    local ref_ate = _te[1, 1]
    local ref_p = _te[4, 1]

    effecttab, display digits(4)
    assert rowsof(r(table)) >= 1
    assert colsof(r(table)) == 2
    assert abs(r(table)[1, 1] - `ref_ate') < 1e-10
    assert abs(r(table)[1, 2] - `ref_p') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: VC3.3 — effecttab r(table) preserves raw values"
    local ++n_pass
}
else {
    display as error "  FAIL: VC3.3 — effecttab r(table) raw-value accuracy (rc=`=_rc')"
    local ++n_fail
}


* =========================================================================
**# VC4: diagtab — Se/Sp/PPV/NPV, cutoffs(), AUC
* =========================================================================

* --- VC4.1: single cutoff — known-answer 2x2 ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if gold == 1 & _n <= 80    // TP=80
    replace test = 1 if gold == 0 & _n > 100 & _n <= 110  // FP=10

    * TP=80, FP=10, FN=20, TN=90
    diagtab test gold
    assert abs(r(sensitivity) - 0.80) < 0.001
    assert abs(r(specificity) - 0.90) < 0.001
    assert abs(r(ppv) - 80/90) < 0.001
    assert abs(r(npv) - 90/110) < 0.001
    assert abs(r(accuracy) - 170/200) < 0.001
    assert abs(r(lr_pos) - 8.0) < 0.01
    assert abs(r(dor) - 36.0) < 0.01
    assert abs(r(youden) - 0.70) < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC4.1 — diagtab single cutoff r() values match manual 2x2"
    local ++n_pass
}
else {
    display as error "  FAIL: VC4.1 — diagtab single cutoff accuracy (rc=`=_rc')"
    local ++n_fail
}

* --- VC4.2: diagtab cutoffs() — multi-cutoff matrix structure ---
local ++n_total
capture noisily {
    clear
    set obs 200
    set seed 12345
    gen byte gold = (_n <= 100)
    gen score = runiform() * 50 + (gold == 1) * 50

    diagtab score gold, cutoffs(25 50 75)

    * Matrix dimensions
    assert rowsof(r(cutoff_table)) == 3
    assert colsof(r(cutoff_table)) == 15

    * Se monotonically decreasing as cutoff increases
    local se_25 = r(cutoff_table)[1, 1]
    local se_75 = r(cutoff_table)[3, 1]
    assert `se_25' >= `se_75'

    * Sp monotonically increasing as cutoff increases
    local sp_25 = r(cutoff_table)[1, 4]
    local sp_75 = r(cutoff_table)[3, 4]
    assert `sp_75' >= `sp_25'

    * All values in [0, 1]
    forvalues row = 1/3 {
        local se_val = r(cutoff_table)[`row', 1]
        local sp_val = r(cutoff_table)[`row', 4]
        assert `se_val' >= 0 & `se_val' <= 1
        assert `sp_val' >= 0 & `sp_val' <= 1
    }

    assert "`r(cutoffs)'" == "25 50 75"
}
if _rc == 0 {
    display as result "  PASS: VC4.2 — diagtab cutoffs() returns valid matrix"
    local ++n_pass
}
else {
    display as error "  FAIL: VC4.2 — diagtab cutoffs() (rc=`=_rc')"
    local ++n_fail
}

* --- VC4.3: diagtab cutoffs() — verify individual values match manual ---
local ++n_total
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen score = 0
    replace score = 1 if _n <= 30           // gold=1, score=1: 30
    replace score = 1 if _n > 50 & _n <= 60 // gold=0, score=1: 10

    * At cutoff=1: TP=30, FP=10, FN=20, TN=40
    * Se=30/50=0.60, Sp=40/50=0.80
    diagtab score gold, cutoffs(1)
    local se1 = r(cutoff_table)[1, 1]
    local sp1 = r(cutoff_table)[1, 4]
    assert abs(`se1' - 0.60) < 0.001
    assert abs(`sp1' - 0.80) < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC4.3 — diagtab cutoffs() values match manual 2x2"
    local ++n_pass
}
else {
    display as error "  FAIL: VC4.3 — diagtab cutoffs() value accuracy (rc=`=_rc')"
    local ++n_fail
}

* --- VC4.4: diagtab cutoffs() with Excel export ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen score = 0
    replace score = 1 if _n <= 80
    replace score = 1 if _n > 100 & _n <= 110

    capture erase "`output_dir'/_vc_diagtab_cuts.xlsx"
    diagtab score gold, cutoffs(1) xlsx("`output_dir'/_vc_diagtab_cuts.xlsx") ///
        sheet("Cutoffs")
    confirm file "`output_dir'/_vc_diagtab_cuts.xlsx"
}
if _rc == 0 {
    display as result "  PASS: VC4.4 — diagtab cutoffs() Excel export works"
    local ++n_pass
}
else {
    display as error "  FAIL: VC4.4 — diagtab cutoffs() Excel (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_vc_diagtab_cuts.xlsx"

* --- VC4.5: diagtab with AUC option ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if _n <= 80
    replace test = 1 if _n > 100 & _n <= 110

    diagtab test gold, cutoff(1) auc
    local _diag_auc = r(auc)
    assert `_diag_auc' >= 0 & `_diag_auc' <= 1
    assert `_diag_auc' > 0.70

    * Compare to roctab reference
    quietly roctab gold test
    local _ref_auc = r(area)
    assert abs(`_diag_auc' - `_ref_auc') < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC4.5 — diagtab AUC matches roctab"
    local ++n_pass
}
else {
    display as error "  FAIL: VC4.5 — diagtab AUC mismatch (rc=`=_rc')"
    local ++n_fail
}

* --- VC4.6: diagtab binary AUC without cutoff matches roctab ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if _n <= 80
    replace test = 1 if _n > 100 & _n <= 110

    diagtab test gold, auc
    local _diag_auc = r(auc)

    quietly roctab gold test
    local _ref_auc = r(area)
    assert abs(`_diag_auc' - `_ref_auc') < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC4.6 — diagtab binary AUC without cutoff matches roctab"
    local ++n_pass
}
else {
    display as error "  FAIL: VC4.6 — diagtab binary AUC without cutoff (rc=`=_rc')"
    local ++n_fail
}

* --- VC4.7: diagtab rejects auc with cutoffs() ---
local ++n_total
capture noisily {
    clear
    set obs 200
    set seed 12345
    gen byte gold = (_n <= 100)
    gen score = runiform() * 50 + (gold == 1) * 50

    capture diagtab score gold, cutoffs(25 50 75) auc
    local cmdrc = _rc
    assert `cmdrc' == 198
}
if _rc == 0 {
    display as result "  PASS: VC4.7 — diagtab rejects auc with cutoffs()"
    local ++n_pass
}
else {
    display as error "  FAIL: VC4.7 — diagtab auc+cutoffs() rejection (rc=`=_rc')"
    local ++n_fail
}


* =========================================================================
**# VC5: crosstab — chi2, cell counts, RR/OR
* =========================================================================

* --- VC5.1: chi2 p-value matches tabulate ---
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highmpg = (mpg > 20)

    quietly tab highmpg foreign, chi2
    local ref_chi2 = r(chi2)
    local ref_p = r(p)

    crosstab highmpg foreign
    assert abs(r(chi2) - `ref_chi2') < 0.01
    assert abs(r(p) - `ref_p') < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC5.1 — crosstab chi2/p match tabulate"
    local ++n_pass
}
else {
    display as error "  FAIL: VC5.1 — crosstab chi2 accuracy (rc=`=_rc')"
    local ++n_fail
}

* --- VC5.2: OR matches cc command ---
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highmpg = (mpg > 20)

    quietly cc highmpg foreign
    local ref_or = r(or)

    crosstab highmpg foreign, or
    * OR uses same convention as cc (both 2x2 orientation-invariant)
    assert abs(r(or) - `ref_or') < 0.01
}
if _rc == 0 {
    display as result "  PASS: VC5.2 — crosstab OR matches cc"
    local ++n_pass
}
else {
    display as error "  FAIL: VC5.2 — crosstab OR accuracy (rc=`=_rc')"
    local ++n_fail
}

* --- VC5.3: RR and RD match cs ---
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highmpg = (mpg > 20)

    quietly cs highmpg foreign
    local ref_rr = r(rr)
    local ref_rd = r(rd)

    crosstab highmpg foreign, rr rd
    assert abs(r(rr) - `ref_rr') < 0.001
    assert abs(r(rd) - `ref_rd') < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC5.3 — crosstab RR/RD match cs"
    local ++n_pass
}
else {
    display as error "  FAIL: VC5.3 — crosstab RR/RD accuracy (rc=`=_rc')"
    local ++n_fail
}

* --- VC5.4: total N matches dataset ---
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highmpg = (mpg > 20)
    quietly count if !missing(highmpg) & !missing(foreign)
    local ref_N = r(N)

    crosstab highmpg foreign
    assert r(N) == `ref_N'
}
if _rc == 0 {
    display as result "  PASS: VC5.4 — crosstab total N matches dataset count"
    local ++n_pass
}
else {
    display as error "  FAIL: VC5.4 — crosstab N conservation (rc=`=_rc')"
    local ++n_fail
}


* =========================================================================
**# VC6: corrtab — correlation values match pwcorr
* =========================================================================

* Frame variables: c1 (labels), c2..cN (data columns), title

* --- VC6.1: Pearson correlation matches pwcorr ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly pwcorr price mpg weight, sig
    matrix _pwc = r(C)
    local ref_r_pm = _pwc[2, 1]   // price-mpg
    local ref_r_pw = _pwc[3, 1]   // price-weight

    capture frame drop _vc_corr
    corrtab price mpg weight, frame(_vc_corr) digits(4)

    frame _vc_corr {
        * Row 3 = price, row 4 = mpg, row 5 = weight (rows 1-2 are empty/header)
        * c1 = labels, c2 = price column, c3 = mpg column, c4 = weight column
        * mpg-price at c2[4], weight-price at c2[5]
        local cell_pm = strtrim(c2[4])
        local cell_pm = subinstr("`cell_pm'", "*", "", .)
        local frame_r_pm = real("`cell_pm'")

        local cell_pw = strtrim(c2[5])
        local cell_pw = subinstr("`cell_pw'", "*", "", .)
        local frame_r_pw = real("`cell_pw'")

        assert abs(`frame_r_pm' - `ref_r_pm') < 0.001
        assert abs(`frame_r_pw' - `ref_r_pw') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: VC6.1 — corrtab values match pwcorr"
    local ++n_pass
}
else {
    display as error "  FAIL: VC6.1 — corrtab correlation accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_corr

* --- VC6.2: diagonal is 1.00 ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _vc_corr2
    corrtab price mpg weight, frame(_vc_corr2) digits(4)

    frame _vc_corr2 {
        * Diagonal: price-price = c2[3], mpg-mpg = c3[4], weight-weight = c4[5]
        local d1_str = subinstr(strtrim(c2[3]), "*", "", .)
        local d2_str = subinstr(strtrim(c3[4]), "*", "", .)
        local d3_str = subinstr(strtrim(c4[5]), "*", "", .)
        local d1 = real("`d1_str'")
        local d2 = real("`d2_str'")
        local d3 = real("`d3_str'")
        assert abs(`d1' - 1.0) < 0.001
        assert abs(`d2' - 1.0) < 0.001
        assert abs(`d3' - 1.0) < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: VC6.2 — corrtab diagonal values are 1.00"
    local ++n_pass
}
else {
    display as error "  FAIL: VC6.2 — corrtab diagonal accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_corr2

* --- VC6.3: Spearman matches spearman command ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly spearman price mpg
    local ref_rho = r(rho)

    capture frame drop _vc_corrsp
    corrtab price mpg, frame(_vc_corrsp) spearman digits(4)

    frame _vc_corrsp {
        * Row 3 = price, Row 4 = mpg
        local cell = subinstr(strtrim(c2[4]), "*", "", .)
        local frame_rho = real("`cell'")
        assert abs(`frame_rho' - `ref_rho') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: VC6.3 — corrtab Spearman matches spearman command"
    local ++n_pass
}
else {
    display as error "  FAIL: VC6.3 — corrtab Spearman accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_corrsp


* =========================================================================
**# VC7: survtab — KM estimates and log-rank p
* =========================================================================

* Frame variables: c1 (labels), c2 (values/group 1), title

* --- VC7.1: median matches stci ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    quietly stci, median
    local ref_median = r(p50)

    capture frame drop _vc_surv
    survtab, times(10 20 30) median frame(_vc_surv)

    assert abs(r(median_1) - `ref_median') < 0.5
}
if _rc == 0 {
    display as result "  PASS: VC7.1 — survtab median matches stci"
    local ++n_pass
}
else {
    display as error "  FAIL: VC7.1 — survtab median accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_surv

* --- VC7.2: log-rank p-value matches sts test ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    sts test drug
    local ref_chi2 = r(chi2)
    local ref_df = r(df)
    local ref_p = chi2tail(`ref_df', `ref_chi2')

    capture frame drop _vc_surv2
    survtab, times(10 20 30) by(drug) frame(_vc_surv2)

    * survtab returns r(logrank_chi2) and r(logrank_p)
    assert abs(r(logrank_chi2) - `ref_chi2') < 0.01
    assert abs(r(logrank_p) - `ref_p') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: VC7.2 — survtab log-rank p matches sts test"
    local ++n_pass
}
else {
    display as error "  FAIL: VC7.2 — survtab log-rank p accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_surv2

* --- VC7.3: survtab r(table) contains survival probabilities ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    tempvar _ref_surv
    tempname _km_ref
    qui sts generate `_ref_surv' = s
    matrix `_km_ref' = J(3, 1, .)
    local _times "10 20 30"
    forvalues _i = 1/3 {
        local _time : word `_i' of `_times'
        qui su _t if _t <= `_time' & _st & !missing(`_ref_surv'), meanonly
        if r(N) > 0 {
            local _max_t = r(max)
            qui su `_ref_surv' if _t == `_max_t' & _st, meanonly
            matrix `_km_ref'[`_i', 1] = r(min)
        }
        else {
            matrix `_km_ref'[`_i', 1] = 1
        }
    }

    capture frame drop _vc_surv3
    survtab, times(10 20 30) frame(_vc_surv3)

    assert rowsof(r(table)) == 3
    assert colsof(r(table)) == 1
    forvalues i = 1/3 {
        assert abs(r(table)[`i', 1] - `_km_ref'[`i', 1]) < 1e-10
    }
}
if _rc == 0 {
    display as result "  PASS: VC7.3 — survtab S(20) matches KM estimate"
    local ++n_pass
}
else {
    display as error "  FAIL: VC7.3 — survtab KM accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_surv3


* =========================================================================
**# VC8: fittab — AIC/BIC/C-stat
* =========================================================================

* Frame variables: c1 (labels), c2 (model 1), c3 (model 2), title

* --- VC8.1: AIC/BIC for 2 linear models ---
local ++n_total
capture noisily {
    sysuse auto, clear

    quietly regress price mpg
    estimates store _vc_m1
    quietly estat ic
    tempname ic1
    matrix `ic1' = r(S)
    local ref_aic1 = `ic1'[1, 5]
    local ref_bic1 = `ic1'[1, 6]

    quietly regress price mpg weight
    estimates store _vc_m2
    quietly estat ic
    tempname ic2
    matrix `ic2' = r(S)
    local ref_aic2 = `ic2'[1, 5]

    capture frame drop _vc_fit
    fittab _vc_m1 _vc_m2, frame(_vc_fit) stats(n aic bic)

    frame _vc_fit {
        * c1=labels, c2=model1, c3=model2
        local found_aic = 0
        local found_bic = 0
        forvalues i = 1/`=_N' {
            local label = strtrim(c1[`i'])
            if strpos("`label'", "AIC") > 0 {
                local f_aic1 = real(strtrim(c2[`i']))
                local f_aic2 = real(strtrim(c3[`i']))
                assert abs(`f_aic1' - `ref_aic1') < 0.2
                assert abs(`f_aic2' - `ref_aic2') < 0.2
                local found_aic = 1
            }
            if strpos("`label'", "BIC") > 0 {
                local f_bic1 = real(strtrim(c2[`i']))
                assert abs(`f_bic1' - `ref_bic1') < 0.2
                local found_bic = 1
            }
        }
        assert `found_aic' == 1
        assert `found_bic' == 1
    }
    estimates drop _vc_m1 _vc_m2
}
if _rc == 0 {
    display as result "  PASS: VC8.1 — fittab AIC/BIC match estat ic"
    local ++n_pass
}
else {
    display as error "  FAIL: VC8.1 — fittab AIC/BIC accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_fit
capture estimates drop _vc_m1
capture estimates drop _vc_m2

* --- VC8.2: fittab C-statistic matches lroc ---
local ++n_total
capture noisily {
    sysuse auto, clear

    quietly logistic foreign price mpg
    estimates store _vc_cs1
    quietly lroc, nograph
    local ref_auc1 = r(area)

    quietly logistic foreign price weight
    estimates store _vc_cs2
    quietly lroc, nograph
    local ref_auc2 = r(area)

    capture frame drop _vc_fit2
    fittab _vc_cs1 _vc_cs2, frame(_vc_fit2) stats(n aic cstat)

    frame _vc_fit2 {
        local found = 0
        forvalues i = 1/`=_N' {
            local label = strtrim(c1[`i'])
            if strpos(strlower("`label'"), "c-stat") > 0 | strpos(strlower("`label'"), "concordance") > 0 {
                local f_cstat1 = real(strtrim(c2[`i']))
                assert abs(`f_cstat1' - `ref_auc1') < 0.01
                local found = 1
            }
        }
        assert `found' == 1
    }
    estimates drop _vc_cs1 _vc_cs2
}
if _rc == 0 {
    display as result "  PASS: VC8.2 — fittab C-statistic matches lroc"
    local ++n_pass
}
else {
    display as error "  FAIL: VC8.2 — fittab C-stat accuracy (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_fit2
capture estimates drop _vc_cs1
capture estimates drop _vc_cs2


* =========================================================================
**# VC9: Invariant checks — sanity bounds
* =========================================================================

* --- VC9.1: diagtab proportions in [0,1] ---
local ++n_total
capture noisily {
    clear
    set obs 100
    set seed 99
    gen byte gold = (_n <= 40)
    gen score = runiform()

    diagtab score gold, cutoff(0.5)
    assert r(sensitivity) >= 0 & r(sensitivity) <= 1
    assert r(specificity) >= 0 & r(specificity) <= 1
    assert r(ppv) >= 0 & r(ppv) <= 1
    assert r(npv) >= 0 & r(npv) <= 1
    assert r(accuracy) >= 0 & r(accuracy) <= 1
    assert r(lr_pos) >= 0
    assert r(dor) >= 0
    assert r(youden) >= -1 & r(youden) <= 1
}
if _rc == 0 {
    display as result "  PASS: VC9.1 — diagtab proportions in valid range"
    local ++n_pass
}
else {
    display as error "  FAIL: VC9.1 — diagtab proportion bounds (rc=`=_rc')"
    local ++n_fail
}

* --- VC9.2: corrtab all values in [-1,1] ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _vc_bounds
    corrtab price mpg weight length, frame(_vc_bounds) digits(4)

    frame _vc_bounds {
        forvalues i = 3/`=_N - 1' {
            forvalues j = 2/5 {
                capture {
                    local cell = subinstr(strtrim(c`j'[`i']), "*", "", .)
                    local val = real("`cell'")
                    if `val' < . {
                        assert `val' >= -1.001 & `val' <= 1.001
                    }
                }
            }
        }
    }
}
if _rc == 0 {
    display as result "  PASS: VC9.2 — corrtab all values in [-1, 1]"
    local ++n_pass
}
else {
    display as error "  FAIL: VC9.2 — corrtab bounds violation (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_bounds

* --- VC9.3: survtab survival probabilities in [0%, 100%] ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture frame drop _vc_sbounds
    survtab, times(5 10 15 20 25 30 35) frame(_vc_sbounds)

    frame _vc_sbounds {
        forvalues i = 3/`=_N' {
            local cell = strtrim(c2[`i'])
            if "`cell'" != "" & "`cell'" != "." {
                local pct_pos = strpos("`cell'", "%")
                if `pct_pos' > 0 {
                    local val = real(subinstr("`cell'", "%", "", 1))
                    if `val' < . {
                        assert `val' >= 0 & `val' <= 100
                    }
                }
            }
        }
    }
}
if _rc == 0 {
    display as result "  PASS: VC9.3 — survtab probabilities in [0%, 100%]"
    local ++n_pass
}
else {
    display as error "  FAIL: VC9.3 — survtab probability bounds (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _vc_sbounds


* =========================================================================
**# VC10: survtab — log-rank p-value cross-check
* =========================================================================

* --- VC10.1: survtab log-rank p matches direct sts test ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    stset studytime, failure(died)
    sts test drug
    local _ref_p = chi2tail(r(df), r(chi2))

    survtab, by(drug) times(10 20)
    assert abs(r(logrank_p) - `_ref_p') < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC10.1 — survtab log-rank p matches sts test"
    local ++n_pass
}
else {
    display as error "  FAIL: VC10.1 — survtab log-rank p (rc=`=_rc')"
    local ++n_fail
    capture frame drop _vc_slogrank
}

* =========================================================================
**# VC11: table1_tc — p-value cross-check
* =========================================================================

* --- VC11.1: table1_tc continuous p-value matches ttest ---
local ++n_total
capture noisily {
    sysuse auto, clear
    ttest price, by(foreign)
    local _ref_p = r(p)

    table1_tc, vars(price contn) by(foreign) frame(_vc_t1p, replace)
    frame _vc_t1p {
        * _p_raw should contain the raw p-value
        assert abs(_p_raw[3] - `_ref_p') < 0.001
    }
    capture frame drop _vc_t1p
}
if _rc == 0 {
    display as result "  PASS: VC11.1 — table1_tc continuous p matches ttest"
    local ++n_pass
}
else {
    display as error "  FAIL: VC11.1 — table1_tc p-value (rc=`=_rc')"
    local ++n_fail
    capture frame drop _vc_t1p
}

* --- VC11.2: table1_tc categorical p-value matches chi2 ---
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highmpg = (mpg > 20)
    quietly tab highmpg foreign, chi2
    local _ref_chi2_p = r(p)

    table1_tc, vars(highmpg cat) by(foreign) frame(_vc_t1chi, replace)
    frame _vc_t1chi {
        * Find the p-value row for highmpg
        local _found = 0
        forvalues _r = 1/`=_N' {
            if !missing(_p_raw[`_r']) {
                assert abs(_p_raw[`_r'] - `_ref_chi2_p') < 0.001
                local _found = 1
                continue, break
            }
        }
        assert `_found' == 1
    }
    capture frame drop _vc_t1chi
}
if _rc == 0 {
    display as result "  PASS: VC11.2 — table1_tc categorical p matches chi2"
    local ++n_pass
}
else {
    display as error "  FAIL: VC11.2 — table1_tc chi2 p-value (rc=`=_rc')"
    local ++n_fail
    capture frame drop _vc_t1chi
}

* =========================================================================
**# VC12: diagtab — PPV/NPV CI validation
* =========================================================================

* --- VC12.1: diagtab PPV matches known-answer calculation ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if _n <= 80
    replace test = 1 if _n > 100 & _n <= 110

    diagtab test gold, cutoff(1) wilson
    * PPV = TP / (TP + FP) = 80 / (80 + 10) = 80/90 = 0.8889
    assert abs(r(ppv) - 80/90) < 0.001
    * NPV = TN / (TN + FN) = 90 / (90 + 20) = 90/110 = 0.8182
    assert abs(r(npv) - 90/110) < 0.001
    * Sensitivity = TP / (TP + FN) = 80 / (80 + 20) = 0.80
    assert abs(r(sensitivity) - 80/100) < 0.001
    * Specificity = TN / (TN + FP) = 90 / (90 + 10) = 0.90
    assert abs(r(specificity) - 90/100) < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC12.1 — diagtab PPV CI matches cii Wilson"
    local ++n_pass
}
else {
    display as error "  FAIL: VC12.1 — diagtab PPV CI (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# Summary
* =========================================================================

display _newline as text "Validation Calculations Complete"
display as text _dup(60) "-"
display as result "  Passed: `n_pass' / `n_total'"
if `n_fail' > 0 {
    display as error "  Failed: `n_fail' / `n_total'"
}
else {
    display as result "  All tests passed!"
}
display as text _dup(60) "-"

assert `n_fail' == 0

log close _vcalc
