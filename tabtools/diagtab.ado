*! diagtab Version 1.0.7  2026/04/18
*! Diagnostic accuracy table
*! Author: Timothy P Copeland
*! Program class: rclass

/*
DESCRIPTION:
    Computes diagnostic accuracy measures (sensitivity, specificity, PPV, NPV,
    LR+, LR-, DOR, AUC) from a 2x2 classification against a gold standard.
    Exports to Excel with professional formatting.

SYNTAX:
    diagtab test_var gold_var [if] [in], xlsx(filename)
        [cutoff(real) cutoffs(numlist) prevalence(real) exact wilson
        auc optimal
        sheet(string) title(string)
        footnote(string) theme(string) borderstyle(string)
        csv(filename) frame(name) display open]
*/

program define diagtab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

capture noisily {

    * Auto-load shared helper programs
    capture program list _tabtools_validate_path
    if _rc {
        capture findfile _tabtools_common.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_tabtools_common.ado not found; reinstall tabtools"
            exit 111
        }
    }

**# Syntax and Validation
    syntax varlist(min=2 max=2 numeric) [if] [in], ///
        [xlsx(string) excel(string) sheet(string) ///
        CUToff(real -999) CUTOffs(numlist sort) ///
        PREValence(real -1) EXact WILson ///
        AUC OPTimal ///
        DIGits(integer -1) ///
        title(string) ///
        FOOTnote(string) THEme(string) BORDERstyle(string) ///
        HEADERColor(string) ZEBRAColor(string) ZEBra HEADERShade ///
        csv(string) FRAme(string) DISplay open]

    gettoken testvar goldvar : varlist

    if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
    local _has_xlsx = "`xlsx'" != ""

    if "`sheet'" == "" local sheet "Diagnostics"

    * Resolve digits option
    if `digits' == -1 {
        if "$TABTOOLS_DIGITS" != "" local digits = $TABTOOLS_DIGITS
        else local digits = 1
    }
    if `digits' < 0 | `digits' > 6 {
        noisily display as error "digits() must be between 0 and 6"
        exit 198
    }
    _tabtools_validate_sheet "`sheet'" "sheet()"
    if `_has_xlsx' _tabtools_validate_path "`xlsx'" "xlsx()"
    if "`csv'" != "" _tabtools_validate_path "`csv'" "csv()"
    if `prevalence' != -1 & (`prevalence' <= 0 | `prevalence' >= 1) {
        noisily display as error "prevalence() must be between 0 and 1"
        exit 198
    }

    * Conflict check: cutoff() and cutoffs() are mutually exclusive
    if `cutoff' != -999 & "`cutoffs'" != "" {
        noisily display as error "cutoff() and cutoffs() are mutually exclusive"
        exit 198
    }
    if "`auc'" != "" & "`cutoffs'" != "" {
        noisily display as error "auc cannot be combined with cutoffs(); use cutoff() or omit auc"
        exit 198
    }
    if "`optimal'" != "" & "`cutoffs'" != "" {
        noisily display as error "optimal cannot be combined with cutoffs(); use cutoff() or omit optimal"
        exit 198
    }

    * Default CI method is Wilson
    if "`exact'" == "" & "`wilson'" == "" local wilson "wilson"

    marksample touse
    quietly count if `touse'
    if r(N) == 0 {
        noisily display as error "no observations"
        noisily display as error "Hint: check your {bf:if}/{bf:in} conditions and whether variables have missing values"
        exit 2000
    }

    * Validate gold standard is binary (0/1)
    qui levelsof `goldvar' if `touse', local(_goldlevels)
    local _ngold : word count `_goldlevels'
    if `_ngold' > 2 {
        noisily display as error "`goldvar' must be binary (0/1); found `_ngold' levels"
        exit 198
    }
    foreach _gl of local _goldlevels {
        if !inlist(`_gl', 0, 1) {
            noisily display as error "`goldvar' must be coded 0/1; found value `_gl'"
            exit 198
        }
    }
    if `cutoff' == -999 & "`cutoffs'" == "" & "`optimal'" == "" {
        qui levelsof `testvar' if `touse', local(_testlevels)
        local _ntest : word count `_testlevels'
        if `_ntest' > 2 {
            noisily display as error "`testvar' must be coded 0/1 unless cutoff() or cutoffs() is specified"
            exit 198
        }
        foreach _tv of local _testlevels {
            if !inlist(`_tv', 0, 1) {
                noisily display as error "`testvar' must be coded 0/1 unless cutoff() or cutoffs() is specified"
                noisily display as error "Hint: use cutoff() for a single threshold or cutoffs() for multiple thresholds"
                exit 198
            }
        }
    }

    * Resolve formatting
    _tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle') ///
        headershade(`headershade') zebra(`zebra')

    * Resolve header/zebra colors
    local _headercolor "219 229 241"
    local _zebracolor "237 242 249"
    if "$TABTOOLS_HEADERCOLOR" != "" local _headercolor "$TABTOOLS_HEADERCOLOR"
    if "$TABTOOLS_ZEBRACOLOR" != "" local _zebracolor "$TABTOOLS_ZEBRACOLOR"
    if "`headercolor'" != "" local _headercolor "`headercolor'"
    if "`zebracolor'" != "" local _zebracolor "`zebracolor'"

    local _ci_method = cond("`exact'" != "", "exact", "wilson")

    if "`cutoffs'" != "" {
        * ============================================================
        * Multi-cutoff path: loop over each cutoff in numlist
        * ============================================================

        * Compute measures for each cutoff (before preserve/clear)
        local _ncuts : word count `cutoffs'
        tempname _cutmat
        matrix `_cutmat' = J(`_ncuts', 15, .)
        matrix colnames `_cutmat' = Se Se_lo Se_hi Sp Sp_lo Sp_hi PPV PPV_lo PPV_hi NPV NPV_lo NPV_hi Acc Acc_lo Acc_hi
        local _cuti 0

        foreach _cv of local cutoffs {
            local _cuti = `_cuti' + 1

            * Dichotomize at this cutoff
            tempvar _tbin
            qui gen byte `_tbin' = (`testvar' >= `_cv') if `touse'

            * 2x2 cells
            qui count if `_tbin' == 1 & `goldvar' == 1 & `touse'
            local TP = r(N)
            qui count if `_tbin' == 1 & `goldvar' == 0 & `touse'
            local FP = r(N)
            qui count if `_tbin' == 0 & `goldvar' == 1 & `touse'
            local FN = r(N)
            qui count if `_tbin' == 0 & `goldvar' == 0 & `touse'
            local TN = r(N)
            local _total = `TP' + `FP' + `FN' + `TN'

            * Diagnostic measures
            local Se = cond(`TP' + `FN' > 0, `TP' / (`TP' + `FN'), .)
            local Sp = cond(`TN' + `FP' > 0, `TN' / (`TN' + `FP'), .)
            local PPV = cond(`TP' + `FP' > 0, `TP' / (`TP' + `FP'), .)
            local NPV = cond(`TN' + `FN' > 0, `TN' / (`TN' + `FN'), .)
            local Acc = cond(`_total' > 0, (`TP' + `TN') / `_total', .)

            * CIs
            local Se_lo = .
            local Se_hi = .
            local Sp_lo = .
            local Sp_hi = .
            local PPV_lo = .
            local PPV_hi = .
            local NPV_lo = .
            local NPV_hi = .
            local Acc_lo = .
            local Acc_hi = .
            if `TP' + `FN' > 0 {
                qui cii proportions `=`TP'+`FN'' `TP', `_ci_method'
                local Se_lo = r(lb)
                local Se_hi = r(ub)
            }
            if `TN' + `FP' > 0 {
                qui cii proportions `=`TN'+`FP'' `TN', `_ci_method'
                local Sp_lo = r(lb)
                local Sp_hi = r(ub)
            }
            if `TP' + `FP' > 0 {
                qui cii proportions `=`TP'+`FP'' `TP', `_ci_method'
                local PPV_lo = r(lb)
                local PPV_hi = r(ub)
            }
            if `TN' + `FN' > 0 {
                qui cii proportions `=`TN'+`FN'' `TN', `_ci_method'
                local NPV_lo = r(lb)
                local NPV_hi = r(ub)
            }
            if `_total' > 0 {
                qui cii proportions `_total' `=`TP'+`TN'', `_ci_method'
                local Acc_lo = r(lb)
                local Acc_hi = r(ub)
            }

            * Adjust PPV/NPV with external prevalence
            if `prevalence' > 0 & `prevalence' < 1 {
                if !missing(`Se') & !missing(`Sp') {
                    local PPV = (`Se' * `prevalence') / (`Se' * `prevalence' + (1 - `Sp') * (1 - `prevalence'))
                    local NPV = (`Sp' * (1 - `prevalence')) / ((1 - `Se') * `prevalence' + `Sp' * (1 - `prevalence'))
                    if !missing(`Se_lo') & !missing(`Sp_lo') {
                        local _p = `prevalence'
                        local _d1 = `Se_lo' * `_p' + (1 - `Sp') * (1 - `_p')
                        local _d2 = `Se_hi' * `_p' + (1 - `Sp') * (1 - `_p')
                        if `_d1' > 0 local PPV_lo = (`Se_lo' * `_p') / `_d1'
                        if `_d2' > 0 local PPV_hi = (`Se_hi' * `_p') / `_d2'
                        local _d3 = (1 - `Se') * `_p' + `Sp_lo' * (1 - `_p')
                        local _d4 = (1 - `Se') * `_p' + `Sp_hi' * (1 - `_p')
                        if `_d3' > 0 local NPV_lo = (`Sp_lo' * (1 - `_p')) / `_d3'
                        if `_d4' > 0 local NPV_hi = (`Sp_hi' * (1 - `_p')) / `_d4'
                    }
                }
            }

            * Store in return matrix
            matrix `_cutmat'[`_cuti', 1] = `Se'
            matrix `_cutmat'[`_cuti', 2] = `Se_lo'
            matrix `_cutmat'[`_cuti', 3] = `Se_hi'
            matrix `_cutmat'[`_cuti', 4] = `Sp'
            matrix `_cutmat'[`_cuti', 5] = `Sp_lo'
            matrix `_cutmat'[`_cuti', 6] = `Sp_hi'
            matrix `_cutmat'[`_cuti', 7] = `PPV'
            matrix `_cutmat'[`_cuti', 8] = `PPV_lo'
            matrix `_cutmat'[`_cuti', 9] = `PPV_hi'
            matrix `_cutmat'[`_cuti', 10] = `NPV'
            matrix `_cutmat'[`_cuti', 11] = `NPV_lo'
            matrix `_cutmat'[`_cuti', 12] = `NPV_hi'
            matrix `_cutmat'[`_cuti', 13] = `Acc'
            matrix `_cutmat'[`_cuti', 14] = `Acc_lo'
            matrix `_cutmat'[`_cuti', 15] = `Acc_hi'

            * Store locals for output building (indexed by cutoff number)
            foreach _m in Se Sp PPV NPV Acc {
                local _cut`_cuti'_`_m' = ``_m''
                local _cut`_cuti'_`_m'_lo = ``_m'_lo'
                local _cut`_cuti'_`_m'_hi = ``_m'_hi'
            }

            drop `_tbin'
        }

        * Return matrix with cutoff row names
        local _rnames ""
        foreach _cv of local cutoffs {
            local _cv_fmt : display %9.0g `_cv'
            local _cv_fmt = strtrim("`_cv_fmt'")
            local _cv_tag = subinstr("`_cv_fmt'", "-", "m", .)
            local _cv_tag = subinstr("`_cv_tag'", ".", "p", .)
            local _rnames "`_rnames' cut_`_cv_tag'"
        }
        matrix rownames `_cutmat' = `_rnames'
        return matrix cutoff_table = `_cutmat'
        return local cutoffs "`cutoffs'"

        **# Build Output Dataset (multi-cutoff)
        preserve
        clear
        local _is_multicut 1

        local out_ncols 3
        forvalues c = 1/`out_ncols' {
            qui gen str244 c`c' = ""
        }
        qui gen str244 title = ""

        * Row 1: Title
        local row 1
        qui set obs 1
        qui replace title = "`title'" in 1

        * Row 2: Column headers
        local row = `row' + 1
        qui set obs `row'
        qui replace c1 = "Cutoff" in `row'
        qui replace c2 = "Estimate" in `row'
        qui replace c3 = "(95% CI)" in `row'
        local _header_row = `row'

        * Build output rows from stored locals
        local _section_rows ""
        local _cuti 0
        foreach _cv of local cutoffs {
            local _cuti = `_cuti' + 1

            * Section header
            local row = `row' + 1
            qui set obs `row'
            local _cv_fmt : display %9.0g `_cv'
            local _cv_fmt = strtrim("`_cv_fmt'")
            qui replace c1 = "Cutoff >= `_cv_fmt'" in `row'
            local _section_rows "`_section_rows' `row'"

            * Measure rows (indented)
            foreach _m in Se Sp PPV NPV Acc {
                local row = `row' + 1
                qui set obs `row'
                if "`_m'" == "Se" qui replace c1 = "  Sensitivity" in `row'
                else if "`_m'" == "Sp" qui replace c1 = "  Specificity" in `row'
                else if "`_m'" == "PPV" qui replace c1 = "  PPV" in `row'
                else if "`_m'" == "NPV" qui replace c1 = "  NPV" in `row'
                else if "`_m'" == "Acc" qui replace c1 = "  Accuracy" in `row'
                if !missing(`_cut`_cuti'_`_m'') {
                    qui replace c2 = string(`_cut`_cuti'_`_m'' * 100, "%5.`digits'f") + "%" in `row'
                }
                if !missing(`_cut`_cuti'_`_m'_lo') & !missing(`_cut`_cuti'_`_m'_hi') {
                    qui replace c3 = "(" + string(`_cut`_cuti'_`_m'_lo' * 100, "%5.`digits'f") + ", " + string(`_cut`_cuti'_`_m'_hi' * 100, "%5.`digits'f") + ")" in `row'
                }
            }
        }

        local num_rows = _N
        local num_cols = `out_ncols' + 1
    }
    else {
        * ============================================================
        * Single-cutoff path (original logic)
        * ============================================================

    * Optimal cutoff (Youden's J = Se + Sp - 1)
    local _opt_cutoff = .
    if "`optimal'" != "" {
        qui levelsof `testvar' if `touse', local(_opt_candidates)
        local _best_j = -1
        foreach _c of local _opt_candidates {
            qui count if `testvar' >= `_c' & `goldvar' == 1 & `touse'
            local _tp_c = r(N)
            qui count if `goldvar' == 1 & `touse'
            local _pos_c = r(N)
            qui count if `testvar' < `_c' & `goldvar' == 0 & `touse'
            local _tn_c = r(N)
            qui count if `goldvar' == 0 & `touse'
            local _neg_c = r(N)
            if `_pos_c' > 0 & `_neg_c' > 0 {
                local _se_c = `_tp_c' / `_pos_c'
                local _sp_c = `_tn_c' / `_neg_c'
                local _j_c = `_se_c' + `_sp_c' - 1
                if `_j_c' > `_best_j' {
                    local _best_j = `_j_c'
                    local _opt_cutoff = `_c'
                }
            }
        }
        if `cutoff' == -999 {
            if missing(`_opt_cutoff') {
                noisily display as error "Could not determine an optimal cutoff from `testvar'"
                exit 498
            }
            local cutoff = `_opt_cutoff'
        }
    }

**# Dichotomize if Cutoff Specified
    tempvar _test_bin
    if `cutoff' != -999 {
        qui gen byte `_test_bin' = (`testvar' >= `cutoff') if `touse'
    }
    else {
        qui gen byte `_test_bin' = `testvar' if `touse'
    }

**# Compute 2x2 Cells
    * TP: test+ & gold+
    qui count if `_test_bin' == 1 & `goldvar' == 1 & `touse'
    local TP = r(N)
    * FP: test+ & gold-
    qui count if `_test_bin' == 1 & `goldvar' == 0 & `touse'
    local FP = r(N)
    * FN: test- & gold+
    qui count if `_test_bin' == 0 & `goldvar' == 1 & `touse'
    local FN = r(N)
    * TN: test- & gold-
    qui count if `_test_bin' == 0 & `goldvar' == 0 & `touse'
    local TN = r(N)

    local _total = `TP' + `FP' + `FN' + `TN'

**# Compute Diagnostic Measures
    * Guard against zero denominators
    local Se = cond(`TP' + `FN' > 0, `TP' / (`TP' + `FN'), .)
    local Sp = cond(`TN' + `FP' > 0, `TN' / (`TN' + `FP'), .)
    local PPV = cond(`TP' + `FP' > 0, `TP' / (`TP' + `FP'), .)
    local NPV = cond(`TN' + `FN' > 0, `TN' / (`TN' + `FN'), .)
    local Acc = cond(`_total' > 0, (`TP' + `TN') / `_total', .)
    * LR+ = Se / (1 - Sp); guard Sp == 1
    local LRp = cond(!missing(`Se') & !missing(`Sp') & `Sp' < 1, `Se' / (1 - `Sp'), .)
    * LR- = (1 - Se) / Sp; guard Sp == 0
    local LRn = cond(!missing(`Se') & !missing(`Sp') & `Sp' > 0, (1 - `Se') / `Sp', .)
    * DOR; guard FP or FN == 0
    local DOR = cond(`FP' * `FN' > 0, (`TP' * `TN') / (`FP' * `FN'), .)
    * Youden's index
    local J = cond(!missing(`Se') & !missing(`Sp'), `Se' + `Sp' - 1, .)

    * Compute CIs for each measure, guarding zero denominators
    local Se_lo = .
    local Se_hi = .
    local Sp_lo = .
    local Sp_hi = .
    local PPV_lo = .
    local PPV_hi = .
    local NPV_lo = .
    local NPV_hi = .
    local Acc_lo = .
    local Acc_hi = .
    if `TP' + `FN' > 0 {
        qui cii proportions `=`TP'+`FN'' `TP', `_ci_method'
        local Se_lo = r(lb)
        local Se_hi = r(ub)
    }
    if `TN' + `FP' > 0 {
        qui cii proportions `=`TN'+`FP'' `TN', `_ci_method'
        local Sp_lo = r(lb)
        local Sp_hi = r(ub)
    }
    if `TP' + `FP' > 0 {
        qui cii proportions `=`TP'+`FP'' `TP', `_ci_method'
        local PPV_lo = r(lb)
        local PPV_hi = r(ub)
    }
    if `TN' + `FN' > 0 {
        qui cii proportions `=`TN'+`FN'' `TN', `_ci_method'
        local NPV_lo = r(lb)
        local NPV_hi = r(ub)
    }
    if `_total' > 0 {
        qui cii proportions `_total' `=`TP'+`TN'', `_ci_method'
        local Acc_lo = r(lb)
        local Acc_hi = r(ub)
    }

    * LR+ CI (log method) — requires TP, FP, FN, TN all > 0
    local LRp_lo = .
    local LRp_hi = .
    local LRn_lo = .
    local LRn_hi = .
    local DOR_lo = .
    local DOR_hi = .
    if `TP' > 0 & `FP' > 0 & `FN' > 0 & `TN' > 0 {
        local _se_ln_lrp = sqrt(1/`TP' - 1/(`TP'+`FN') + 1/`FP' - 1/(`FP'+`TN'))
        local LRp_lo = exp(ln(`LRp') - 1.96 * `_se_ln_lrp')
        local LRp_hi = exp(ln(`LRp') + 1.96 * `_se_ln_lrp')
        local _se_ln_lrn = sqrt(1/`FN' - 1/(`TP'+`FN') + 1/`TN' - 1/(`FP'+`TN'))
        local LRn_lo = exp(ln(`LRn') - 1.96 * `_se_ln_lrn')
        local LRn_hi = exp(ln(`LRn') + 1.96 * `_se_ln_lrn')
        * DOR CI (Woolf's method)
        local _se_ln_dor = sqrt(1/`TP' + 1/`FP' + 1/`FN' + 1/`TN')
        local DOR_lo = exp(ln(`DOR') - 1.96 * `_se_ln_dor')
        local DOR_hi = exp(ln(`DOR') + 1.96 * `_se_ln_dor')
    }

    * AUC
    local _auc = .
    local _auc_lo = .
    local _auc_hi = .
    if "`auc'" != "" {
        capture qui roctab `goldvar' `testvar' if `touse'
        if !_rc {
            local _auc = r(area)
            local _auc_lo = r(lb)
            local _auc_hi = r(ub)
        }
    }

    * Adjust PPV/NPV with external prevalence (point estimates and CIs)
    if `prevalence' > 0 & `prevalence' < 1 {
        if !missing(`Se') & !missing(`Sp') {
            local PPV = (`Se' * `prevalence') / (`Se' * `prevalence' + (1 - `Sp') * (1 - `prevalence'))
            local NPV = (`Sp' * (1 - `prevalence')) / ((1 - `Se') * `prevalence' + `Sp' * (1 - `prevalence'))
            * Transform Se/Sp CI bounds through Bayes' formula for PPV/NPV CIs
            if !missing(`Se_lo') & !missing(`Sp_lo') {
                local _p = `prevalence'
                * PPV CI: use Se bounds with Sp point estimate
                local _d1 = `Se_lo' * `_p' + (1 - `Sp') * (1 - `_p')
                local _d2 = `Se_hi' * `_p' + (1 - `Sp') * (1 - `_p')
                if `_d1' > 0 local PPV_lo = (`Se_lo' * `_p') / `_d1'
                if `_d2' > 0 local PPV_hi = (`Se_hi' * `_p') / `_d2'
                * NPV CI: use Sp bounds with Se point estimate
                local _d3 = (1 - `Se') * `_p' + `Sp_lo' * (1 - `_p')
                local _d4 = (1 - `Se') * `_p' + `Sp_hi' * (1 - `_p')
                if `_d3' > 0 local NPV_lo = (`Sp_lo' * (1 - `_p')) / `_d3'
                if `_d4' > 0 local NPV_hi = (`Sp_hi' * (1 - `_p')) / `_d4'
            }
        }
    }

**# Return Scalars
    return scalar sensitivity = `Se'
    return scalar specificity = `Sp'
    return scalar ppv = `PPV'
    return scalar npv = `NPV'
    return scalar accuracy = `Acc'
    return scalar lr_pos = `LRp'
    return scalar lr_neg = `LRn'
    return scalar dor = `DOR'
    return scalar youden = `J'
    if !missing(`_auc') return scalar auc = `_auc'
    if !missing(`_opt_cutoff') return scalar optimal_cutoff = `_opt_cutoff'

**# Build Output Dataset
    preserve
    clear
    local _is_multicut 0

    local out_ncols 3
    forvalues c = 1/`out_ncols' {
        qui gen str244 c`c' = ""
    }
    qui gen str244 title = ""

    * Row 1: Title
    local row 1
    qui set obs 1
    qui replace title = "`title'" in 1

    * Row 2: Confusion matrix header
    local row = `row' + 1
    qui set obs `row'
    qui replace c1 = "" in `row'
    qui replace c2 = "Gold +" in `row'
    qui replace c3 = "Gold -" in `row'

    * Test positive row
    local row = `row' + 1
    qui set obs `row'
    qui replace c1 = "Test +" in `row'
    qui replace c2 = string(`TP', "%11.0fc") in `row'
    qui replace c3 = string(`FP', "%11.0fc") in `row'

    * Test negative row
    local row = `row' + 1
    qui set obs `row'
    qui replace c1 = "Test -" in `row'
    qui replace c2 = string(`FN', "%11.0fc") in `row'
    qui replace c3 = string(`TN', "%11.0fc") in `row'

    * Blank separator
    local row = `row' + 1
    qui set obs `row'

    * Measures header
    local row = `row' + 1
    qui set obs `row'
    qui replace c1 = "Measure" in `row'
    qui replace c2 = "Estimate" in `row'
    qui replace c3 = "(95% CI)" in `row'
    local _measures_row = `row'

    * Helper to add a measure row
    foreach _m in Se Sp PPV NPV Acc {
        local row = `row' + 1
        qui set obs `row'
        if "`_m'" == "Se" qui replace c1 = "Sensitivity" in `row'
        else if "`_m'" == "Sp" qui replace c1 = "Specificity" in `row'
        else if "`_m'" == "PPV" qui replace c1 = "PPV" in `row'
        else if "`_m'" == "NPV" qui replace c1 = "NPV" in `row'
        else if "`_m'" == "Acc" qui replace c1 = "Accuracy" in `row'
        qui replace c2 = string(``_m'' * 100, "%5.`digits'f") + "%" in `row'
        qui replace c3 = "(" + string(``_m'_lo' * 100, "%5.`digits'f") + ", " + string(``_m'_hi' * 100, "%5.`digits'f") + ")" in `row'
    }

    * LR+, LR-, DOR
    local row = `row' + 1
    qui set obs `row'
    qui replace c1 = "LR+" in `row'
    qui replace c2 = string(`LRp', "%5.`digits'f") in `row'
    qui replace c3 = "(" + string(`LRp_lo', "%5.`digits'f") + ", " + string(`LRp_hi', "%5.`digits'f") + ")" in `row'

    local row = `row' + 1
    qui set obs `row'
    qui replace c1 = "LR-" in `row'
    qui replace c2 = string(`LRn', "%5.`=`digits'+1'f") in `row'
    qui replace c3 = "(" + string(`LRn_lo', "%5.`=`digits'+1'f") + ", " + string(`LRn_hi', "%5.`=`digits'+1'f") + ")" in `row'

    local row = `row' + 1
    qui set obs `row'
    qui replace c1 = "DOR" in `row'
    qui replace c2 = string(`DOR', "%5.`digits'f") in `row'
    qui replace c3 = "(" + string(`DOR_lo', "%5.`digits'f") + ", " + string(`DOR_hi', "%5.`digits'f") + ")" in `row'

    * AUC
    if !missing(`_auc') {
        local row = `row' + 1
        qui set obs `row'
        qui replace c1 = "AUC" in `row'
        qui replace c2 = string(`_auc', "%6.`=`digits'+2'f") in `row'
        if !missing(`_auc_lo') {
            qui replace c3 = "(" + string(`_auc_lo', "%6.`=`digits'+2'f") + ", " + string(`_auc_hi', "%6.`=`digits'+2'f") + ")" in `row'
        }
    }

    * Youden's index
    local row = `row' + 1
    qui set obs `row'
    qui replace c1 = "Youden's index" in `row'
    qui replace c2 = string(`J', "%6.`=`digits'+2'f") in `row'

    * Optimal cutoff
    if !missing(`_opt_cutoff') {
        local row = `row' + 1
        qui set obs `row'
        qui replace c1 = "Optimal cutoff" in `row'
        qui replace c2 = string(`_opt_cutoff', "%9.`=`digits'+2'f") in `row'
    }

    local num_rows = _N
    local num_cols = `out_ncols' + 1
    } // end single-cutoff else

    local _console_header_row = 2
    local _console_data_start = 3
    local _top_header_row = 2

**# Console Display
    if !`_has_xlsx' | "`display'" != "" {
        noisily _tabtools_console_display `out_ncols' `"`title'"'
    }

**# CSV/Frame/Excel Export
    if "`csv'" != "" {
        export delimited using "`csv'", replace
    }

    if `"`frame'"' != "" {
        _tabtools_frame_put `"`frame'"'
        local frame "`_frame_name'"
    }

    if `_has_xlsx' {
        order title c*
        capture export excel using "`xlsx'", sheet("`sheet'") sheetreplace
        if _rc {
            local _export_rc = _rc
            noisily display as error "Failed to export to `xlsx'"
            noisily display as error "Hint: ensure the xlsx file is not open in another application"
            restore
            exit `_export_rc'
        }

        capture {
            putexcel set "`xlsx'", sheet("`sheet'") modify
            _tabtools_build_col_letters `num_cols'
            local letters "`result'"
            local lastcol : word `num_cols' of `letters'

            putexcel (A1:`lastcol'1), merge bold txtwrap left vcenter font("`_font'", `=`_fontsize'+2')
            putexcel (B`_top_header_row':`lastcol'`num_rows'), font("`_font'", `_fontsize')
            if `_is_multicut' {
                putexcel (B`_header_row':`lastcol'`_header_row'), bold hcenter border(bottom, `_hborder')
                foreach _sr of local _section_rows {
                    putexcel (B`_sr':`lastcol'`_sr'), bold
                }
            }
            else {
                putexcel (B`_top_header_row':`lastcol'`_top_header_row'), bold hcenter
                putexcel (B`_measures_row':`lastcol'`_measures_row'), bold
            }
            putexcel (B`num_rows':`lastcol'`num_rows'), border(bottom, `_hborder')

            * Header background fill
            if "`headershade'" != "" {
                if `_is_multicut' {
                    putexcel (A`_header_row':`lastcol'`_header_row'), fpattern(solid, "`_headercolor'")
                }
                else {
                    putexcel (A`_top_header_row':`lastcol'`_top_header_row'), fpattern(solid, "`_headercolor'")
                }
            }

            * Zebra striping
            if "`zebra'" != "" {
                if `_is_multicut' {
                    forvalues _zr = `=`_header_row'+2'(2)`num_rows' {
                        putexcel (A`_zr':`lastcol'`_zr'), fpattern(solid, "`_zebracolor'")
                    }
                }
                else {
                    * Single-cutoff: shade alternating measure rows only,
                    * starting with the first measure (Sensitivity) just below
                    * the bolded measures header. Skip the confusion-matrix block.
                    forvalues _zr = `=`_measures_row'+1'(2)`num_rows' {
                        putexcel (A`_zr':`lastcol'`_zr'), fpattern(solid, "`_zebracolor'")
                    }
                }
            }

            if `"`footnote'"' != "" {
                _tabtools_footnote `"`footnote'"' "`lastcol'" `num_rows' "`_font'" `_fontsize'
            }
            putexcel clear

            * Set column widths via Mata
            mata: b = xl()
            mata: b.load_book("`xlsx'")
            mata: b.set_sheet("`sheet'")
            mata: b.set_column_width(1, 1, 1)
            mata: b.set_column_width(2, 2, 18)
            mata: b.set_column_width(3, 3, 12)
            mata: b.set_column_width(4, 4, 18)
            mata: b.close_book()
            mata: mata drop b
        }
        if _rc {
            local _format_rc = _rc
            capture putexcel clear
            capture mata: mata drop b
            noisily display as error "Excel formatting failed with error `_format_rc'"
            exit `_format_rc'
        }
        capture confirm file "`xlsx'"
        if _rc {
            noisily display as error "Export command succeeded but file not found"
            exit 601
        }
        noisily display as text "Exported to " as result `"`xlsx'"' as text ", sheet " as result `"`sheet'"'
    }

    if "`open'" != "" & `_has_xlsx' _tabtools_open_file "`xlsx'"

    restore

    if `_has_xlsx' {
        return local xlsx "`xlsx'"
        return local sheet "`sheet'"
    }
    if "`frame'" != "" return local frame "`frame'"

    local _ci_method = cond("`exact'" != "", "Clopper-Pearson exact", "Wilson score")
    local _methods "Diagnostic accuracy was assessed against the gold standard (`goldvar')."
    local _methods "`_methods' `_ci_method' 95% confidence intervals are reported."
    local _methods "`_methods' Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."
    return local methods "`_methods'"

} // end capture noisily
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
