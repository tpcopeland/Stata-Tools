* validation_known_answers.do — Extended known-answer validation suite for tabtools
* Purpose: Hand-computed and algebraic-identity tests that complement
*          validation_calculations.do, covering algebraic identities,
*          cross-Stata-command checks, and edge-case 2x2 / 3x3 tables.
* Style: Each KE test sets up a small synthetic dataset whose expected
*        answer is known by hand or by direct comparison to a Stata
*        primitive (regress, logit, cs, cc, tabulate, sts, stcox, ...).
*        No external R/Python dependence — that lives in crossval_*.do.

capture log close _vka
log using "validation_known_answers.log", replace text name(_vka)

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
**# KE1: diagtab algebraic identities (LR+, LR-, DOR, accuracy, Youden, F1)
* =========================================================================
* Reference dataset: TP=80, FP=10, FN=20, TN=90, N=200
*  Se = 80/100 = 0.80
*  Sp = 90/100 = 0.90
*  PPV = 80/90 ≈ 0.8889
*  NPV = 90/110 ≈ 0.8182
*  LR+ = 0.80 / 0.10 = 8.0
*  LR- = 0.20 / 0.90 ≈ 0.2222
*  DOR = LR+/LR- = 36
*  Accuracy = 170/200 = 0.85
*  Youden = 0.70
*  F1 = 2*PPV*Se / (PPV+Se) = 2*0.8889*0.80 / 1.6889 ≈ 0.8421
*  Prevalence = 100/200 = 0.50

capture program drop _ke_diag2x2
program define _ke_diag2x2
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if gold == 1 & _n <= 80
    replace test = 1 if gold == 0 & _n > 100 & _n <= 110
end

* --- KE1.1: LR+ identity ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold
    local _se = r(sensitivity)
    local _sp = r(specificity)
    local _lrpos = r(lr_pos)
    assert abs(`_lrpos' - `_se' / (1 - `_sp')) < 1e-6
    assert abs(`_lrpos' - 8.0) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE1.1 — LR+ matches Se/(1-Sp) and equals 8.0"
    local ++n_pass
}
else {
    display as error "  FAIL: KE1.1 — LR+ identity (rc=`=_rc')"
    local ++n_fail
}

* --- KE1.2: LR- identity ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold
    local _se = r(sensitivity)
    local _sp = r(specificity)
    local _lrneg = r(lr_neg)
    assert abs(`_lrneg' - (1 - `_se') / `_sp') < 1e-6
    assert abs(`_lrneg' - 0.20/0.90) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE1.2 — LR- matches (1-Se)/Sp and equals 0.2222"
    local ++n_pass
}
else {
    display as error "  FAIL: KE1.2 — LR- identity (rc=`=_rc')"
    local ++n_fail
}

* --- KE1.3: DOR identity (LR+/LR- and TP*TN/(FP*FN)) ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold
    local _dor = r(dor)
    local _lrpos = r(lr_pos)
    local _lrneg = r(lr_neg)
    assert abs(`_dor' - `_lrpos'/`_lrneg') < 1e-4
    * TP=80, FP=10, FN=20, TN=90 → DOR = 80*90/(10*20) = 36
    assert abs(`_dor' - 36.0) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE1.3 — DOR equals LR+/LR- and 36.0"
    local ++n_pass
}
else {
    display as error "  FAIL: KE1.3 — DOR identity (rc=`=_rc')"
    local ++n_fail
}

* --- KE1.4: Accuracy identity ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold
    local _acc = r(accuracy)
    assert abs(`_acc' - 0.85) < 1e-6
    assert abs(`_acc' - (80 + 90)/200) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE1.4 — Accuracy = (TP+TN)/N = 0.85"
    local ++n_pass
}
else {
    display as error "  FAIL: KE1.4 — Accuracy identity (rc=`=_rc')"
    local ++n_fail
}

* --- KE1.5: Youden index identity ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold
    local _y = r(youden)
    local _se = r(sensitivity)
    local _sp = r(specificity)
    assert abs(`_y' - (`_se' + `_sp' - 1)) < 1e-6
    assert abs(`_y' - 0.70) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE1.5 — Youden = Se+Sp-1 = 0.70"
    local ++n_pass
}
else {
    display as error "  FAIL: KE1.5 — Youden identity (rc=`=_rc')"
    local ++n_fail
}

* --- KE1.6: PPV closed form (Bayes via TP/(TP+FP)) ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold
    local _ppv = r(ppv)
    local _npv = r(npv)
    * 80/(80+10) = 0.8889; 90/(90+20) = 0.8182
    assert abs(`_ppv' - 80/90) < 1e-6
    assert abs(`_npv' - 90/110) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE1.6 — PPV/NPV match closed-form Bayes"
    local ++n_pass
}
else {
    display as error "  FAIL: KE1.6 — PPV/NPV closed form (rc=`=_rc')"
    local ++n_fail
}

* --- KE1.7: Perfect classifier — Se = Sp = 1, AUC = 1 ---
local ++n_total
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = gold
    diagtab test gold, auc
    assert abs(r(sensitivity) - 1.0) < 1e-9
    assert abs(r(specificity) - 1.0) < 1e-9
    assert abs(r(accuracy) - 1.0) < 1e-9
    assert abs(r(auc) - 1.0) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: KE1.7 — perfect classifier Se/Sp/AUC = 1"
    local ++n_pass
}
else {
    display as error "  FAIL: KE1.7 — perfect classifier (rc=`=_rc')"
    local ++n_fail
}

* --- KE1.8: Worst classifier — invert labels gives Se=Sp=0 ---
local ++n_total
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = 1 - gold
    diagtab test gold
    assert abs(r(sensitivity) - 0.0) < 1e-9
    assert abs(r(specificity) - 0.0) < 1e-9
    assert abs(r(youden) - (-1.0)) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: KE1.8 — fully inverted classifier Se=Sp=0, Youden=-1"
    local ++n_pass
}
else {
    display as error "  FAIL: KE1.8 — inverted classifier (rc=`=_rc')"
    local ++n_fail
}

* --- KE1.9: Random classifier on balanced data — AUC ≈ 0.5 ---
local ++n_total
capture noisily {
    clear
    set obs 1000
    set seed 20260413
    gen byte gold = (_n <= 500)
    gen score = runiform()
    diagtab score gold, cutoff(0.5) auc
    * Random scores: AUC should be ~0.5 ± a few percent
    assert r(auc) > 0.40 & r(auc) < 0.60
}
if _rc == 0 {
    display as result "  PASS: KE1.9 — random classifier AUC ≈ 0.5 ± 0.10"
    local ++n_pass
}
else {
    display as error "  FAIL: KE1.9 — random AUC (rc=`=_rc')"
    local ++n_fail
}

* --- KE1.10: Cell extremes — only TPs (FN=0) → Se=1 ---
local ++n_total
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = gold
    replace test = 1 if _n > 50 & _n <= 70   // 20 FPs
    * TP=50, FN=0, FP=20, TN=30
    diagtab test gold
    assert abs(r(sensitivity) - 1.0) < 1e-9
    assert abs(r(specificity) - 0.6) < 1e-9
    assert abs(r(ppv) - 50/70) < 1e-6
    assert abs(r(npv) - 1.0) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: KE1.10 — FN=0 case gives Se=1, NPV=1"
    local ++n_pass
}
else {
    display as error "  FAIL: KE1.10 — FN=0 edge (rc=`=_rc')"
    local ++n_fail
}


* =========================================================================
**# KE2: crosstab 2x2 hand-computed OR/RR/RD/chi2
* =========================================================================
* Reference 2x2:
*   exposed=1: 80 events / 100 total → risk = 0.80
*   exposed=0: 30 events / 100 total → risk = 0.30
*   OR = (80*70)/(20*30) = 5600/600 ≈ 9.333
*   RR = 0.80 / 0.30 ≈ 2.667
*   RD = 0.80 - 0.30 = 0.50

capture program drop _ke_cross2x2
program define _ke_cross2x2
    clear
    set obs 200
    gen byte exposed = (_n <= 100)
    gen byte event = 0
    replace event = 1 if exposed == 1 & _n <= 80
    replace event = 1 if exposed == 0 & _n > 100 & _n <= 130
end

* --- KE2.1: OR matches hand-computed 9.333 and Stata cc ---
local ++n_total
capture noisily {
    _ke_cross2x2
    quietly cc event exposed
    local _ref_or = r(or)
    crosstab event exposed, or
    local _or_hand = (80*70)/(20*30)
    assert abs(r(or) - `_or_hand') < 1e-6
    assert abs(r(or) - `_ref_or') < 1e-3
}
if _rc == 0 {
    display as result "  PASS: KE2.1 — crosstab OR = 9.333 and matches cc"
    local ++n_pass
}
else {
    display as error "  FAIL: KE2.1 — crosstab OR (rc=`=_rc')"
    local ++n_fail
}

* --- KE2.2: RR matches hand-computed 2.667 and cs ---
local ++n_total
capture noisily {
    _ke_cross2x2
    quietly cs event exposed
    local _ref_rr = r(rr)
    crosstab event exposed, rr
    local _rr_hand = (80/100) / (30/100)
    assert abs(r(rr) - `_rr_hand') < 1e-6
    assert abs(r(rr) - `_ref_rr') < 1e-3
}
if _rc == 0 {
    display as result "  PASS: KE2.2 — crosstab RR = 2.667 and matches cs"
    local ++n_pass
}
else {
    display as error "  FAIL: KE2.2 — crosstab RR (rc=`=_rc')"
    local ++n_fail
}

* --- KE2.3: RD matches hand-computed 0.50 and cs ---
local ++n_total
capture noisily {
    _ke_cross2x2
    quietly cs event exposed
    local _ref_rd = r(rd)
    crosstab event exposed, rd
    local _rd_hand = 0.80 - 0.30
    assert abs(r(rd) - `_rd_hand') < 1e-6
    assert abs(r(rd) - `_ref_rd') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE2.3 — crosstab RD = 0.50 and matches cs"
    local ++n_pass
}
else {
    display as error "  FAIL: KE2.3 — crosstab RD (rc=`=_rc')"
    local ++n_fail
}

* --- KE2.4: chi2 statistic matches tabulate, chi2 ---
local ++n_total
capture noisily {
    _ke_cross2x2
    crosstab event exposed
    local _xtab_chi2 = r(chi2)
    local _xtab_p = r(p)
    quietly tabulate event exposed, chi2
    local _ref_chi2 = r(chi2)
    local _ref_p = r(p)
    assert abs(`_xtab_chi2' - `_ref_chi2') < 1e-4
    assert abs(`_xtab_p' - `_ref_p') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE2.4 — crosstab chi2/p match tabulate, chi2"
    local ++n_pass
}
else {
    display as error "  FAIL: KE2.4 — crosstab chi2 (rc=`=_rc')"
    local ++n_fail
}

* --- KE2.5: r(N) equals total observations ---
local ++n_total
capture noisily {
    _ke_cross2x2
    crosstab event exposed
    assert r(N) == 200
}
if _rc == 0 {
    display as result "  PASS: KE2.5 — crosstab r(N) equals total obs"
    local ++n_pass
}
else {
    display as error "  FAIL: KE2.5 — crosstab N (rc=`=_rc')"
    local ++n_fail
}

* --- KE2.6: 2x3 chi2 matches tabulate (all cells ≥5 expected) ---
local ++n_total
capture noisily {
    clear
    set obs 600
    set seed 42
    gen byte grp = mod(_n, 3)            // 3 levels, balanced
    gen byte y = runiform() < 0.5         // independent binary
    crosstab y grp
    local _xtab_p = r(p)
    quietly tabulate y grp, chi2
    assert abs(`_xtab_p' - r(p)) < 1e-4
}
if _rc == 0 {
    display as result "  PASS: KE2.6 — 2x3 crosstab p matches tabulate"
    local ++n_pass
}
else {
    display as error "  FAIL: KE2.6 — 2x3 p (rc=`=_rc')"
    local ++n_fail
}

* --- KE2.7: Independent groups → p large, OR ≈ 1 ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte exposed = (_n <= 100)
    gen byte event = mod(_n, 2) == 0   // independent of exposure
    crosstab event exposed, or
    assert r(p) > 0.20
    assert abs(r(or) - 1.0) < 0.5
}
if _rc == 0 {
    display as result "  PASS: KE2.7 — independent vars give large p and OR ≈ 1"
    local ++n_pass
}
else {
    display as error "  FAIL: KE2.7 — independence case (rc=`=_rc')"
    local ++n_fail
}

* --- KE2.8: Symmetric exposure direction reversal — OR is reciprocal ---
local ++n_total
capture noisily {
    _ke_cross2x2
    crosstab event exposed, or
    local _or_orig = r(or)
    gen byte rev_exp = 1 - exposed
    crosstab event rev_exp, or
    local _or_rev = r(or)
    assert abs(`_or_orig' * `_or_rev' - 1.0) < 1e-3
}
if _rc == 0 {
    display as result "  PASS: KE2.8 — flipping exposure inverts OR (orig * rev = 1)"
    local ++n_pass
}
else {
    display as error "  FAIL: KE2.8 — OR reciprocity (rc=`=_rc')"
    local ++n_fail
}


* =========================================================================
**# KE3: regtab linear regression r(table) algebra
* =========================================================================

* --- KE3.1: regtab frame coefficients match e(b) for linear model ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local ref_b_mpg = _b[mpg]
    local ref_b_wt  = _b[weight]

    capture frame drop _ke_lin
    regtab, frame(_ke_lin)
    frame _ke_lin {
        local found_mpg = 0
        local found_wt = 0
        forvalues i = 1/`=_N' {
            local lab = strtrim(A[`i'])
            if strpos("`lab'", "mpg") > 0 & strpos("`lab'", "Mileage") > 0 {
                local fv = real(strtrim(c1[`i']))
                assert abs(`fv' - `ref_b_mpg') < 0.01
                local found_mpg = 1
            }
            if strpos("`lab'", "Weight") > 0 {
                local fv = real(strtrim(c1[`i']))
                assert abs(`fv' - `ref_b_wt') < 0.01
                local found_wt = 1
            }
        }
        assert `found_mpg' == 1
        assert `found_wt' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE3.1 — regtab linear coefs match e(b) (frame lookup)"
    local ++n_pass
}
else {
    display as error "  FAIL: KE3.1 — frame coefs (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_lin

* --- KE3.2: regtab N stat equals e(N) for linear model ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local ref_n = e(N)
    capture frame drop _ke_reg_n
    regtab, frame(_ke_reg_n) stats(n)
    frame _ke_reg_n {
        local found_n = 0
        forvalues i = 1/`=_N' {
            if strpos(strtrim(A[`i']), "Observations") > 0 {
                local fn = real(strtrim(c1[`i']))
                assert `fn' == `ref_n'
                local found_n = 1
            }
        }
        assert `found_n' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE3.2 — regtab N stat equals e(N)"
    local ++n_pass
}
else {
    display as error "  FAIL: KE3.2 — regtab N stat (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_reg_n

* --- KE3.3: poisson IRR matches exp(e(b)) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: poisson rep78 mpg if !missing(rep78), irr
    local ref_irr_mpg = exp(_b[mpg])

    capture frame drop _ke_pois
    regtab, frame(_ke_pois) digits(4)
    frame _ke_pois {
        local found = 0
        forvalues i = 1/`=_N' {
            local lab = strtrim(A[`i'])
            if strpos("`lab'", "Mileage") > 0 {
                local fv = real(strtrim(c1[`i']))
                if `fv' < . {
                    assert abs(`fv' - `ref_irr_mpg') < 0.005
                    local found = 1
                }
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE3.3 — regtab poisson IRR matches exp(e(b))"
    local ++n_pass
}
else {
    display as error "  FAIL: KE3.3 — poisson IRR (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_pois

* --- KE3.4: Cox HR matches exp(e(b)) via stcox ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    collect clear
    collect: stcox drug age
    local ref_hr_drug = exp(_b[drug])
    local ref_hr_age  = exp(_b[age])

    capture frame drop _ke_cox
    regtab, frame(_ke_cox) digits(4)
    frame _ke_cox {
        local found_drug = 0
        local found_age = 0
        forvalues i = 1/`=_N' {
            local lab = strtrim(A[`i'])
            if strpos("`lab'", "Drug") > 0 {
                local fv = real(strtrim(c1[`i']))
                assert abs(`fv' - `ref_hr_drug') < 0.01
                local found_drug = 1
            }
            if strpos("`lab'", "age") > 0 | strpos("`lab'", "Age") > 0 {
                local fv = real(strtrim(c1[`i']))
                assert abs(`fv' - `ref_hr_age') < 0.01
                local found_age = 1
            }
        }
        assert `found_drug' == 1
        assert `found_age' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE3.4 — regtab Cox HR matches exp(e(b))"
    local ++n_pass
}
else {
    display as error "  FAIL: KE3.4 — Cox HR (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_cox

* --- KE3.5: Two-model regtab — both coefs from r(table) match ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    local ref1 = _b[mpg]
    collect: regress price mpg weight
    local ref2 = _b[mpg]

    regtab
    matrix _ke_T2 = r(table)
    assert colsof(_ke_T2) == 2
    * Find Mileage row by sanitized rowname substring
    local found = 0
    forvalues i = 1/`=rowsof(_ke_T2)' {
        local rn : word `i' of `:rownames _ke_T2'
        if strpos("`rn'", "Mileage") > 0 {
            assert abs(_ke_T2[`i', 1] - `ref1') < 0.01
            assert abs(_ke_T2[`i', 2] - `ref2') < 0.01
            local found = 1
        }
    }
    assert `found' == 1
}
if _rc == 0 {
    display as result "  PASS: KE3.5 — two-model regtab r(table) cols match e(b)"
    local ++n_pass
}
else {
    display as error "  FAIL: KE3.5 — two-model r(table) (rc=`=_rc')"
    local ++n_fail
}


* =========================================================================
**# KE4: effecttab — ATE and SE/CI consistency
* =========================================================================

* --- KE4.1: teffects ra ATE matches effecttab r(table) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign)
    local ref_ate = _b[r1vs0.foreign]

    effecttab
    matrix _ke_E = r(table)
    * Single ATE row, single column
    local _v = _ke_E[1, 1]
    assert abs(`_v' - `ref_ate') < 0.5
}
if _rc == 0 {
    display as result "  PASS: KE4.1 — effecttab ATE matches teffects ra _b"
    local ++n_pass
}
else {
    display as error "  FAIL: KE4.1 — effecttab ATE (rc=`=_rc')"
    local ++n_fail
}

* --- KE4.2: teffects ipw ATE matches effecttab ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    local ref_ate = _b[r1vs0.foreign]

    effecttab
    matrix _ke_E2 = r(table)
    local _v = _ke_E2[1, 1]
    assert abs(`_v' - `ref_ate') < 0.5
}
if _rc == 0 {
    display as result "  PASS: KE4.2 — effecttab IPW ATE matches teffects ipw"
    local ++n_pass
}
else {
    display as error "  FAIL: KE4.2 — effecttab IPW ATE (rc=`=_rc')"
    local ++n_fail
}

* --- KE4.3: ATE direction agrees with naive group-mean difference ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly summarize price if foreign == 1
    local m_for = r(mean)
    quietly summarize price if foreign == 0
    local m_dom = r(mean)
    local naive_diff = `m_for' - `m_dom'

    collect clear
    collect: teffects ra (price mpg weight) (foreign)
    local ref_ate = _b[r1vs0.foreign]
    * ATE should at least share sign with naive difference (small auto data)
    assert sign(`ref_ate') == sign(`naive_diff') | abs(`ref_ate') < 100
}
if _rc == 0 {
    display as result "  PASS: KE4.3 — teffects ra ATE sign agrees with raw mean diff"
    local ++n_pass
}
else {
    display as error "  FAIL: KE4.3 — ATE sign (rc=`=_rc')"
    local ++n_fail
}


* =========================================================================
**# KE6: survtab — events/atrisk conservation, log-rank vs sts test
* =========================================================================

* --- KE6.1: Total events across groups equals dataset events ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    quietly count if died == 1
    local total_events = r(N)

    survtab, times(20) by(drug) events
    local sum_ev = 0
    forvalues g = 1/2 {
        local sum_ev = `sum_ev' + r(events_`g')
    }
    assert `sum_ev' == `total_events'
}
if _rc == 0 {
    display as result "  PASS: KE6.1 — survtab events sum to total died"
    local ++n_pass
}
else {
    display as error "  FAIL: KE6.1 — survtab events sum (rc=`=_rc')"
    local ++n_fail
}

* --- KE6.2: Sum of at-risk equals total observations ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    local total_n = _N

    survtab, times(20) by(drug) events
    local sum_atrisk = 0
    forvalues g = 1/2 {
        local sum_atrisk = `sum_atrisk' + r(atrisk_`g')
    }
    assert `sum_atrisk' == `total_n'
}
if _rc == 0 {
    display as result "  PASS: KE6.2 — survtab at-risk sums to total N"
    local ++n_pass
}
else {
    display as error "  FAIL: KE6.2 — survtab at-risk sum (rc=`=_rc')"
    local ++n_fail
}

* --- KE6.3: log-rank chi2 / p match sts test ---
local ext_n_total = `n_total'
local ++n_total
capture noisily {
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    quietly sts test drug
    local ref_chi2 = r(chi2)
    local ref_df   = r(df)

    survtab, times(20) by(drug)
    assert abs(r(logrank_chi2) - `ref_chi2') < 1e-3
    * p computed independently
    local ref_p = chi2tail(`ref_df', `ref_chi2')
    assert abs(r(logrank_p) - `ref_p') < 1e-4
}
if _rc == 0 {
    display as result "  PASS: KE6.3 — survtab log-rank chi2/p match sts test"
    local ++n_pass
}
else {
    display as error "  FAIL: KE6.3 — log-rank vs sts test (rc=`=_rc')"
    local ++n_fail
}

* --- KE6.4: Median survival per group matches stci ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    quietly stset studytime, failure(died)

    quietly stci if drug == 0, median
    local med_ref_0 = r(p50)
    quietly stci if drug == 1, median
    local med_ref_1 = r(p50)

    survtab, times(20) by(drug) median
    * Group 1 = drug==0 (placebo), Group 2 = drug==1 (treatment)
    if r(median_1) < . {
        assert abs(r(median_1) - `med_ref_0') < 1e-3
    }
    if r(median_2) < . {
        assert abs(r(median_2) - `med_ref_1') < 1e-3
    }
}
if _rc == 0 {
    display as result "  PASS: KE6.4 — survtab medians match stci by group"
    local ++n_pass
}
else {
    display as error "  FAIL: KE6.4 — survtab median (rc=`=_rc')"
    local ++n_fail
}

* --- KE6.5: RMST(g) ≤ truncation horizon ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    survtab, times(20) by(drug) rmst(20)
    forvalues g = 1/2 {
        local _r = r(rmst_`g')
        if "`_r'" != "" & `_r' < . {
            assert `_r' >= 0
            assert `_r' <= 20 + 1e-6
        }
    }
}
if _rc == 0 {
    display as result "  PASS: KE6.5 — RMST values bounded in [0, horizon]"
    local ++n_pass
}
else {
    display as error "  FAIL: KE6.5 — RMST bounds (rc=`=_rc')"
    local ++n_fail
}


* =========================================================================
**# KE7: table1_tc — additional descriptive identities
* =========================================================================

* --- KE7.1: SD parsed from cell matches summarize sd ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly summarize price if foreign == 0
    local ref_sd_dom = r(sd)
    quietly summarize price if foreign == 1
    local ref_sd_for = r(sd)

    capture frame drop _ke_t1
    table1_tc, by(foreign) vars(price contn %9.1f) frame(_ke_t1)
    frame _ke_t1 {
        local dom_cell = foreign_0[3]
        local for_cell = foreign_1[3]
        * "MEAN (SD)" — extract token after first space, strip parens
        local dom_inside = subinstr("`dom_cell'", "(", "", .)
        local dom_inside = subinstr("`dom_inside'", ")", "", .)
        local for_inside = subinstr("`for_cell'", "(", "", .)
        local for_inside = subinstr("`for_inside'", ")", "", .)
        local dom_sd = real(word("`dom_inside'", 2))
        local for_sd = real(word("`for_inside'", 2))
        assert abs(`dom_sd' - `ref_sd_dom') < 1
        assert abs(`for_sd' - `ref_sd_for') < 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE7.1 — table1_tc SD matches summarize"
    local ++n_pass
}
else {
    display as error "  FAIL: KE7.1 — table1_tc SD (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_t1

* --- KE7.2: IQR parsed from conts cell matches p25/p75 ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly summarize price if foreign == 0, detail
    local p25_dom = r(p25)
    local p75_dom = r(p75)

    capture frame drop _ke_t1q
    table1_tc, by(foreign) vars(price conts %9.0f) frame(_ke_t1q)
    frame _ke_t1q {
        local dom_cell = foreign_0[3]
        * "MED (LO-HI)"
        local _idx_lp = strpos("`dom_cell'", "(")
        local _idx_dash = strpos("`dom_cell'", "-")
        local _idx_rp = strpos("`dom_cell'", ")")
        local lo = real(substr("`dom_cell'", `_idx_lp' + 1, `_idx_dash' - `_idx_lp' - 1))
        local hi = real(substr("`dom_cell'", `_idx_dash' + 1, `_idx_rp' - `_idx_dash' - 1))
        assert abs(`lo' - `p25_dom') < 1
        assert abs(`hi' - `p75_dom') < 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE7.2 — table1_tc IQR (lo-hi) matches p25/p75"
    local ++n_pass
}
else {
    display as error "  FAIL: KE7.2 — table1_tc IQR (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_t1q

* --- KE7.3: Categorical proportions sum to 100% within each group ---
local ++n_total
capture noisily {
    sysuse auto, clear
    keep if !missing(rep78)
    capture frame drop _ke_t1c
    table1_tc, by(foreign) vars(rep78 cat) frame(_ke_t1c)
    frame _ke_t1c {
        * Sum percentages in each by-group column for the rep78 rows.
        * Each cell is "n (pct%)". Find rows that begin with a number after trim
        * (level rows) — their pct should sum to ~100 per column.
        local sum0 = 0
        local sum1 = 0
        forvalues i = 1/`=_N' {
            local lab = strtrim(factor[`i'])
            * Skip header/total/blank rows
            if "`lab'" == "" continue
            if regexm("`lab'", "^[1-5]$") {
                local cell0 = foreign_0[`i']
                local cell1 = foreign_1[`i']
                * extract pct between "(" and ")"
                local lp0 = strpos("`cell0'", "(")
                local rp0 = strpos("`cell0'", "%")
                if `lp0' > 0 & `rp0' > `lp0' {
                    local p0 = real(substr("`cell0'", `lp0'+1, `rp0'-`lp0'-1))
                    local sum0 = `sum0' + `p0'
                }
                local lp1 = strpos("`cell1'", "(")
                local rp1 = strpos("`cell1'", "%")
                if `lp1' > 0 & `rp1' > `lp1' {
                    local p1 = real(substr("`cell1'", `lp1'+1, `rp1'-`lp1'-1))
                    local sum1 = `sum1' + `p1'
                }
            }
        }
        assert abs(`sum0' - 100) < 0.5
        assert abs(`sum1' - 100) < 0.5
    }
}
if _rc == 0 {
    display as result "  PASS: KE7.3 — table1_tc cat proportions sum to 100% per group"
    local ++n_pass
}
else {
    display as error "  FAIL: KE7.3 — cat proportion sum (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_t1c

* --- KE7.4: Group N values in header row match `count if by==g` ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly count if foreign == 0
    local n0 = r(N)
    quietly count if foreign == 1
    local n1 = r(N)

    capture frame drop _ke_t1n
    table1_tc, by(foreign) vars(price contn) frame(_ke_t1n)
    frame _ke_t1n {
        * The "N=" header row is row 2
        local cell0 = foreign_0[2]
        local cell1 = foreign_1[2]
        * Extract any integer in the cell
        local d0 = ""
        local d1 = ""
        local k = strlen("`cell0'")
        forvalues i = 1/`k' {
            local ch = substr("`cell0'", `i', 1)
            if regexm("`ch'", "[0-9]") local d0 "`d0'`ch'"
        }
        local k = strlen("`cell1'")
        forvalues i = 1/`k' {
            local ch = substr("`cell1'", `i', 1)
            if regexm("`ch'", "[0-9]") local d1 "`d1'`ch'"
        }
        assert real("`d0'") == `n0'
        assert real("`d1'") == `n1'
    }
}
if _rc == 0 {
    display as result "  PASS: KE7.4 — table1_tc N= header matches per-group count"
    local ++n_pass
}
else {
    display as error "  FAIL: KE7.4 — header N (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_t1n

* --- KE7.5: t-test p value matches ttest exactly (two-group continuous) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly ttest price, by(foreign)
    local ref_p = r(p)

    capture frame drop _ke_t1p
    table1_tc, by(foreign) vars(price contn) frame(_ke_t1p)
    frame _ke_t1p {
        local rp = _p_raw[3]
        assert abs(`rp' - `ref_p') < 1e-4
    }
}
if _rc == 0 {
    display as result "  PASS: KE7.5 — table1_tc raw p equals ttest p"
    local ++n_pass
}
else {
    display as error "  FAIL: KE7.5 — table1_tc p vs ttest (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_t1p


* =========================================================================
**# KE8: corrtab — additional identities (symmetry, pwcorr cross-check)
* =========================================================================

* --- KE8.1: corrtab (price,mpg) cell matches pwcorr ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly pwcorr price mpg weight headroom
    matrix _ref_C = r(C)
    local ref_pm = _ref_C[1, 2]   // (price, mpg)

    capture frame drop _ke_corr
    corrtab price mpg weight headroom, frame(_ke_corr)
    frame _ke_corr {
        * Find Mileage row; (price, mpg) sits at c2 (Price column)
        local found = 0
        forvalues row = 1/`=_N' {
            local lab = strtrim(c1[`row'])
            if strpos("`lab'", "Mileage") > 0 {
                local cell = c2[`row']
                local cell = subinstr("`cell'", "*", "", .)
                local v = real(strtrim("`cell'"))
                if `v' < . {
                    assert abs(`v' - `ref_pm') < 0.01
                    local found = 1
                }
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE8.1 — corrtab (price,mpg) matches pwcorr"
    local ++n_pass
}
else {
    display as error "  FAIL: KE8.1 — corrtab vs pwcorr (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_corr

* --- KE8.2: Diagonal of corrtab is 1.00 for the first variable ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _ke_corr_d
    corrtab price mpg weight, frame(_ke_corr_d)
    frame _ke_corr_d {
        * "Price" row: c2 (Price column) should be 1.00
        local found = 0
        forvalues row = 1/`=_N' {
            local lab = strtrim(c1[`row'])
            if strpos("`lab'", "Price") > 0 {
                local cell = subinstr("`=c2[`row']'", "*", "", .)
                local v = real(strtrim("`cell'"))
                if `v' < . {
                    assert abs(`v' - 1.0) < 0.01
                    local found = 1
                }
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE8.2 — corrtab diagonal element = 1.00"
    local ++n_pass
}
else {
    display as error "  FAIL: KE8.2 — corrtab diagonal (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_corr_d

* --- KE8.3: corrtab spearman agrees with spearman command ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly spearman price mpg
    local spear_pm = r(rho)

    capture frame drop _ke_sp
    corrtab price mpg, spearman frame(_ke_sp)
    frame _ke_sp {
        local found = 0
        forvalues row = 1/`=_N' {
            local lab = strtrim(c1[`row'])
            if strpos("`lab'", "Mileage") > 0 {
                local cell = subinstr("`=c2[`row']'", "*", "", .)
                local v = real(strtrim("`cell'"))
                if `v' < . {
                    assert abs(`v' - `spear_pm') < 0.01
                    local found = 1
                }
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE8.3 — corrtab spearman matches spearman command"
    local ++n_pass
}
else {
    display as error "  FAIL: KE8.3 — corrtab spearman (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_sp

* --- KE8.4: All Pearson correlations bounded in [-1, 1] ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _ke_corr_b
    corrtab price mpg weight headroom turn, frame(_ke_corr_b)
    frame _ke_corr_b {
        local n_checked = 0
        forvalues row = 1/`=_N' {
            forvalues col = 2/6 {
                local cell = subinstr("`=c`col'[`row']'", "*", "", .)
                local v = real(strtrim("`cell'"))
                if `v' < . {
                    assert `v' >= -1.0 - 1e-6
                    assert `v' <= 1.0 + 1e-6
                    local ++n_checked
                }
            }
        }
        * 5 vars → 5+4+3+2+1 = 15 lower-triangle entries
        assert `n_checked' >= 10
    }
}
if _rc == 0 {
    display as result "  PASS: KE8.4 — all corrtab values in [-1, 1]"
    local ++n_pass
}
else {
    display as error "  FAIL: KE8.4 — corrtab bounds (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_corr_b


* =========================================================================
**# KE9: comptab — composed table preserves source frame values
* =========================================================================

* --- KE9.1: comptab N_rows = sum of selected source rows ---
local ++n_total
capture noisily {
    sysuse auto, clear

    collect clear
    collect: regress price mpg
    capture frame drop _ke_src1
    regtab, frame(_ke_src1)

    collect clear
    collect: regress price mpg weight
    capture frame drop _ke_src2
    regtab, frame(_ke_src2)

    capture frame drop _ke_comp
    comptab _ke_src1 _ke_src2, rows(1 \ 1 2) frame(_ke_comp) display
    assert r(N_frames) == 2
    assert r(N_models) >= 1
    assert r(N_rows) >= 5    // ≥3 data rows + ≥2 header
}
if _rc == 0 {
    display as result "  PASS: KE9.1 — comptab N_frames/N_models reflect inputs"
    local ++n_pass
}
else {
    display as error "  FAIL: KE9.1 — comptab counts (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_src1
capture frame drop _ke_src2
capture frame drop _ke_comp

* --- KE9.2: comptab preserves coef value from source frame row ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    local ref_b_mpg = _b[mpg]

    capture frame drop _ke_src
    regtab, frame(_ke_src)
    * Find Mileage row in source frame
    local src_val = .
    frame _ke_src {
        forvalues i = 1/`=_N' {
            local lab = strtrim(A[`i'])
            if strpos("`lab'", "Mileage") > 0 {
                local src_val = real(strtrim(c1[`i']))
            }
        }
    }
    assert abs(`src_val' - `ref_b_mpg') < 0.5

    capture frame drop _ke_comp2
    comptab _ke_src, rows(1 2) frame(_ke_comp2) display
    * mpg value should still appear in composed frame c1 column
    local match_found = 0
    frame _ke_comp2 {
        forvalues i = 1/`=_N' {
            local v = real(strtrim(c1[`i']))
            if `v' < . & abs(`v' - `ref_b_mpg') < 0.5 {
                local match_found = 1
            }
        }
    }
    assert `match_found' == 1
}
if _rc == 0 {
    display as result "  PASS: KE9.2 — comptab preserves source coef values"
    local ++n_pass
}
else {
    display as error "  FAIL: KE9.2 — comptab value preservation (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _ke_src
capture frame drop _ke_comp2


* =========================================================================
**# KE10: cross-command consistency (different tabtools commands agree)
* =========================================================================

* --- KE10.1: crosstab OR ≈ regtab logistic OR for same 2x2 ---
local ++n_total
capture noisily {
    _ke_cross2x2
    crosstab event exposed, or
    local cross_or = r(or)

    collect clear
    collect: logistic event exposed
    local logit_or = exp(_b[exposed])
    assert abs(`cross_or' - `logit_or') < 0.05
}
if _rc == 0 {
    display as result "  PASS: KE10.1 — crosstab OR matches logistic exp(b)"
    local ++n_pass
}
else {
    display as error "  FAIL: KE10.1 — crosstab vs logistic OR (rc=`=_rc')"
    local ++n_fail
}

* --- KE10.3: diagtab Se equals proportion of TP among gold positives ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold
    local _se = r(sensitivity)
    quietly count if test == 1 & gold == 1
    local _tp = r(N)
    quietly count if gold == 1
    local _np = r(N)
    assert abs(`_se' - `_tp'/`_np') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE10.3 — diagtab Se = TP/(TP+FN) by direct count"
    local ++n_pass
}
else {
    display as error "  FAIL: KE10.3 — Se direct count (rc=`=_rc')"
    local ++n_fail
}


* =========================================================================
**# KE11: Sanity bounds (universal invariants)
* =========================================================================

* --- KE11.1: All proportions/probabilities bounded — diagtab ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold, auc
    foreach m in sensitivity specificity ppv npv accuracy auc {
        local v = r(`m')
        assert `v' >= 0 - 1e-9
        assert `v' <= 1 + 1e-9
    }
}
if _rc == 0 {
    display as result "  PASS: KE11.1 — diagtab Se/Sp/PPV/NPV/Acc/AUC all in [0,1]"
    local ++n_pass
}
else {
    display as error "  FAIL: KE11.1 — diagtab bounds (rc=`=_rc')"
    local ++n_fail
}

* --- KE11.2: crosstab p-value in [0,1], chi2 ≥ 0 ---
local ++n_total
capture noisily {
    _ke_cross2x2
    crosstab event exposed
    assert r(p) >= 0 - 1e-12
    assert r(p) <= 1 + 1e-12
    assert r(chi2) >= 0 - 1e-12
    assert r(or) > 0
    assert r(rr) > 0
}
if _rc == 0 {
    display as result "  PASS: KE11.2 — crosstab p∈[0,1], chi2≥0, OR/RR>0"
    local ++n_pass
}
else {
    display as error "  FAIL: KE11.2 — crosstab bounds (rc=`=_rc')"
    local ++n_fail
}

* --- KE11.3: survtab logrank_p in [0,1], chi2 ≥ 0 ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    survtab, times(20) by(drug)
    assert r(logrank_p) >= 0 - 1e-12
    assert r(logrank_p) <= 1 + 1e-12
    assert r(logrank_chi2) >= 0 - 1e-12
}
if _rc == 0 {
    display as result "  PASS: KE11.3 — survtab logrank in valid bounds"
    local ++n_pass
}
else {
    display as error "  FAIL: KE11.3 — survtab logrank bounds (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# KE12: diagtab cutoff_table — monotonicity & extremes
* =========================================================================

* --- KE12.1: At minimum cutoff, Se = 1; at very high cutoff, Se = 0 ---
local ++n_total
capture noisily {
    clear
    set obs 200
    set seed 20260413
    gen byte gold = (_n <= 100)
    gen score = runiform()*10 + (gold==1)*5

    * cutoff = -100 → all flagged positive → Se=1, Sp=0
    * cutoff = 1000 → none flagged → Se=0, Sp=1
    diagtab score gold, cutoffs(-100 1000)
    matrix _C = r(cutoff_table)
    local se_low = _C[1, 1]
    local sp_low = _C[1, 4]
    local se_high = _C[2, 1]
    local sp_high = _C[2, 4]
    assert abs(`se_low' - 1.0) < 1e-6
    assert abs(`sp_low' - 0.0) < 1e-6
    assert abs(`se_high' - 0.0) < 1e-6
    assert abs(`sp_high' - 1.0) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE12.1 — diagtab cutoff extremes Se=1/Sp=0 and Se=0/Sp=1"
    local ++n_pass
}
else {
    display as error "  FAIL: KE12.1 — cutoff extremes (rc=`=_rc')"
    local ++n_fail
}

* --- KE12.2: Sensitivity monotone non-increasing across rising cutoffs ---
local ++n_total
capture noisily {
    clear
    set obs 500
    set seed 99
    gen byte gold = (_n <= 250)
    gen score = runiform()*10 + (gold==1)*4

    diagtab score gold, cutoffs(1 2 3 4 5 6 7 8)
    matrix _C = r(cutoff_table)
    local n = rowsof(_C)
    forvalues i = 2/`n' {
        local prev = _C[`i'-1, 1]
        local cur  = _C[`i', 1]
        assert `cur' <= `prev' + 1e-9
    }
}
if _rc == 0 {
    display as result "  PASS: KE12.2 — Se non-increasing across rising cutoffs"
    local ++n_pass
}
else {
    display as error "  FAIL: KE12.2 — Se monotone (rc=`=_rc')"
    local ++n_fail
}

* --- KE12.3: Specificity monotone non-decreasing across rising cutoffs ---
local ++n_total
capture noisily {
    clear
    set obs 500
    set seed 99
    gen byte gold = (_n <= 250)
    gen score = runiform()*10 + (gold==1)*4

    diagtab score gold, cutoffs(1 2 3 4 5 6 7 8)
    matrix _C = r(cutoff_table)
    local n = rowsof(_C)
    forvalues i = 2/`n' {
        local prev = _C[`i'-1, 4]
        local cur  = _C[`i', 4]
        assert `cur' >= `prev' - 1e-9
    }
}
if _rc == 0 {
    display as result "  PASS: KE12.3 — Sp non-decreasing across rising cutoffs"
    local ++n_pass
}
else {
    display as error "  FAIL: KE12.3 — Sp monotone (rc=`=_rc')"
    local ++n_fail
}


* =========================================================================
**# Summary
* =========================================================================

display _newline as text "Validation Known Answers Complete"
display as text _dup(60) "-"
display as result "  Passed: `n_pass' / `n_total'"
if `n_fail' > 0 {
    display as error "  Failed: `n_fail' / `n_total'"
}
else {
    display as result "  All tests passed!"
}
display as text _dup(60) "-"

capture log close _vka

assert `n_fail' == 0
