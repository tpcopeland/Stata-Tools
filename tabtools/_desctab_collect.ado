*! _desctab_collect Version 2.5.4  2026/10/06
*! Consolidated aggregation helper for desctab and table1_tc
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Method: Standardized mean differences follow Yang and Dalton (2012).
*! smdtype(population): McCaffrey et al. (2013) Stat Med 32:3388, sec. 4.1.2
*!   eq. 5 and sec. 4.2, max_g |mean_g - mean_pop| / sd_pop, pooled mean/SD
*!   unweighted under wt() (frequency-weighted under fweight).
*! smdtype(maxpair): Lopez and Gutman (2017) Stat Sci 32:432, eq. 27, the
*!   largest absolute pairwise difference, every pair on one shared scale:
*!   sqrt(mean of the K group variances) (cobalt 4.6.3 s.d.denom="pooled").

program define _desctab_collect, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _restore_needed 0

    capture noisily {

        capture _tabtools_helpers_ready
        if !_rc capture mata: assert(findexternal("_tt_sep_parse()") != NULL)
        if _rc {
            capture findfile _tabtools_common.ado
            if _rc == 0 {
                run "`r(fn)'"
                capture _tabtools_helpers_ready
                if _rc {
                    display as error "_tabtools_common.ado failed to load fully; reinstall tabtools"
                    exit 111
                }
            }
            else {
                display as error "_tabtools_common.ado not found; reinstall tabtools"
                exit 111
            }
        }

        syntax [if] [in] [fweight], BY(varname numeric) VARS(string asis) ///
            FRAme(name) ///
            [ REPLACE STUB(name) TOTAL(string) TOTALCode(real -1) ///
              WT(varname numeric) SMD TEST STATistic NOPvalue WTCompare ///
              MISsing PERCENT percent_n slashN CATROWPERC VARLABPLUS ///
              Format(string) PERCFormat(string) NFormat(string) ///
              iqrmiddle(string) sdleft(string) sdright(string) ///
              gsdleft(string) gsdright(string) GSDFormat(string) ///
              percsign(string) NOSPACElowpercent extraspace ///
              SMALLCells(string) SCPRIMary MISSINGSummary ///
              smdtype(string) smdpair(numlist min=2 max=2) ]

        * F07 (codex audit 2026-09-27): the continuous-variable tests fit
        * anova/regress on a temporary group variable. Hold the caller's
        * estimation results (e(sample) included) for the life of this
        * program; restore brings them back on success and on error.
        tempname _est_hold
        _estimates hold `_est_hold', restore nullok

        if "`smallcells'" != "" {
            capture confirm integer number `smallcells'
            if _rc {
                display as error "smallcells() must be an integer greater than or equal to 3"
                exit 198
            }
            if `smallcells' < 3 {
                display as error "smallcells() must be an integer greater than or equal to 3"
                exit 198
            }
        }

        local vars = strtrim(`"`vars'"')
        if substr(`"`vars'"', 1, 1) == `"""' & substr(`"`vars'"', -1, 1) == `"""' {
            local vars = substr(`"`vars'"', 2, length(`"`vars'"') - 2)
        }

        marksample touse, novarlist
        markout `touse' `by'

        if "`wt'" != "" {
            markout `touse' `wt'
            quietly count if `touse' & `wt' < 0
            if r(N) {
                display as error "wt() variable must be non-negative"
                exit 498
            }
            quietly replace `touse' = 0 if `touse' & `wt' <= 0
        }

        quietly count if `touse'
        if r(N) == 0 {
            display as error "no observations"
            exit 2000
        }

        if "`total'" != "" & !inlist("`total'", "before", "after") {
            display as error "total() must be before or after"
            exit 198
        }
        local include_total = "`total'" != ""
        if `totalcode' < 0 local totalcode = c(maxlong)

        if "`stub'" == "" local stub "`by'"
        capture confirm name `stub'
        if _rc {
            display as error "stub() must be a legal Stata name"
            exit 198
        }

        if `"`nformat'"' == "" local nformat "%12.0fc"
        if `"`percsign'"' == "" local percsign ""
        if `"`iqrmiddle'"' == "" local iqrmiddle ", "
        if `"`sdleft'"' == "" local sdleft "±"
        if `"`sdright'"' == "" local sdright ""
        if `"`gsdleft'"' == "" local gsdleft " (×/"
        if `"`gsdright'"' == "" local gsdright ")"

        local n "No."
        if "`slashN'" == "slashN" local n "`n'/total"
        local percentage "%"

        if "`catrowperc'" != "" {
            local percentage2 "column `percentage'"
            if "`percent_n'" == "percent_n" & "`percent'" == "" local percfootnote2 "`percentage2' (`n')"
            if "`percent_n'" != "percent_n" & "`percent'" == "" local percfootnote2 "`n' (`percentage2')"
            if "`percent'" == "percent" local percfootnote2 "`percentage2'"
            local percentage "row `percentage'"
        }

        if "`percent_n'" == "percent_n" & "`percent'" == "" local percfootnote "`percentage' (`n')"
        if "`percent_n'" != "percent_n" & "`percent'" == "" local percfootnote "`n' (`percentage')"
        if "`percent'" == "percent" local percfootnote "`percentage'"
        if `"`percfootnote2'"' == "" local percfootnote2 "`percfootnote'"

        local has_wt = "`wt'" != ""
        /* Display policy (percent-only vs n) is owned by the caller (table1_tc),
           which passes `percent' explicitly when counts should be suppressed.
           This helper no longer auto-suppresses counts for weighted data. */
        local has_fw = "`weight'" == "fweight"
        if `has_wt' & `has_fw' {
            display as error "wt() and fweight cannot be used together"
            exit 198
        }
        local fwvar ""
        if `has_fw' {
            local fwexpr = substr("`exp'", 2, .)
            tempvar _fw_materialized
            quietly generate double `_fw_materialized' = `fwexpr' if `touse'
            capture quietly summarize `by' [fw=`_fw_materialized'] if `touse'
            if _rc {
                local _fw_rc = _rc
                exit `_fw_rc'
            }
            markout `touse' `_fw_materialized'
            local fwvar `"`_fw_materialized'"'
        }
        local include_missing = "`missing'" == "missing"
        local suppress_p = `has_wt' | "`nopvalue'" == "nopvalue"

        quietly levelsof `by' if `touse', local(group_levels)
        local groupcount : word count `group_levels'
        if `groupcount' == 0 {
            display as error "no observations"
            exit 2000
        }
        foreach _gl of local group_levels {
            capture confirm integer number `_gl'
            if _rc {
                display as error "by() variable must contain integer group values"
                exit 498
            }
            if `_gl' < 0 {
                display as error "by() variable must contain non-negative group values"
                exit 498
            }
            if `_gl' == `totalcode' {
                display as error "by() variable may not contain the reserved total code `totalcode'"
                exit 498
            }
        }

        local output_levels `"`group_levels'"'
        if `include_total' local output_levels "`output_levels' `totalcode'"
        local ngout : word count `output_levels'
        local gidx = 0
        foreach _gl of local output_levels {
            local ++gidx
            local gidx_`_gl' `gidx'
        }

        local nvars 0
        local workvars ""
        local typelist ""
        local cat_offset 0
        local any_cat 0
        local any_bin 0
        local any_contn 0
        local any_contln 0
        local any_conts 0
        local processed_varlist ""

        gettoken arg rest : vars, parse("\")
        while `"`arg'"' != "" {
            if `"`arg'"' != "\" {
                local varname   : word 1 of `arg'
                local vartype   : word 2 of `arg'
                local varformat : word 3 of `arg'
                local varformat2 : word 4 of `arg'

                if "`varname'" == "" {
                    gettoken arg rest : rest, parse("\")
                    continue
                }
                confirm variable `varname'

                if "`vartype'" == "" | "`vartype'" == "auto" {
                    _tabtools_detect_vartype `varname' if `touse'
                    local vartype `"`result'"'
                }
                if !inlist("`vartype'", "contn", "contln", "conts", "cat", "cate", "bin", "bine") {
                    display as error "-`varname' `vartype'- not allowed in vars() option"
                    display as error "Variables must be classified as contn, contln, conts, cat, cate, bin or bine"
                    exit 498
                }

                local ++nvars
                local var_`nvars' `"`varname'"'
                local processed_varlist `"`processed_varlist' `varname'"'
                local type_`nvars' `"`vartype'"'
                local fmt1_`nvars' `"`varformat'"'
                local fmt2_`nvars' `"`varformat2'"'
                local datafmt_`nvars' : format `varname'
                * C1 (codex audit 2026-09-26): labels are data. Every copy
                * and test below uses macval() or -copy local-, so a $word or
                * a backtick in a variable or value label is never expanded.
                local varlab : variable label `varname'
                if `"`macval(varlab)'"' == "" local varlab "`varname'"
                local varlab_`nvars' : copy local varlab

                local workvar `"`varname'"'
                if inlist("`vartype'", "cat", "cate") {
                    capture confirm numeric variable `varname'
                    if _rc {
                        tempvar _catwork
                        quietly encode `varname', gen(`_catwork')
                        local workvar `"`_catwork'"'
                    }
                }
                else {
                    capture confirm numeric variable `varname'
                    if _rc {
                        display as error "`varname' must be numeric for type `vartype'"
                        exit 109
                    }
                }

                if inlist("`vartype'", "bin", "bine") {
                    quietly count if `touse' & `by' < . & `workvar' < .
                    if r(N) == 0 {
                        display as error "no categories for `varname' ... cannot tabulate"
                        exit 198
                    }
                    capture assert `workvar' == 0 | `workvar' == 1 if `touse' & `by' < . & `workvar' < .
                    if _rc {
                        display as error "binary variable `varname' must be 0 (negative) or 1 (positive)"
                        display as error "Did you mean {it:cat}? Use vars(`varname' cat) for categorical"
                        exit 198
                    }
                }

                if inlist("`vartype'", "cat", "cate") {
                    quietly count if `touse' & `by' < . & (`workvar' < . | `include_missing')
                    if r(N) == 0 {
                        display as error "no categories for `varname' ... cannot tabulate"
                        exit 198
                    }
                }

                local work_`nvars' `"`workvar'"'
                local workvars `"`workvars' `workvar'"'
                local typelist `"`typelist' `vartype'"'

                if inlist("`vartype'", "cat", "cate") {
                    local any_cat 1
                    quietly levelsof `workvar' if `touse' & `by' < . & `workvar' < ., local(_clevels)
                    if `include_missing' {
                        quietly count if `touse' & `by' < . & `workvar' >= .
                        if r(N) > 0 local _clevels "`_clevels' ."
                    }
                    local cat_levels_`nvars' `"`_clevels'"'
                    local cat_nlevels_`nvars' : word count `cat_levels_`nvars''
                    local cat_start_`nvars' = `cat_offset' + 1
                    local cat_offset = `cat_offset' + `cat_nlevels_`nvars'' * `ngout'

                    local _lo = 0
                    foreach _cl of local cat_levels_`nvars' {
                        local ++_lo
                        if "`_cl'" == "." {
                            local _llab "Missing"
                        }
                        else {
                            local _llab : label (`workvar') `_cl'
                            if `"`macval(_llab)'"' == "" local _llab "`_cl'"
                        }
                        local level_label_`nvars'_`_lo' : copy local _llab
                    }
                }
                else if inlist("`vartype'", "bin", "bine") {
                    local any_bin 1
                    local cat_levels_`nvars' "1"
                    local cat_nlevels_`nvars' 1
                    local cat_start_`nvars' = `cat_offset' + 1
                    local cat_offset = `cat_offset' + `ngout'
                    local level_label_`nvars'_1 "1"
                }
                else if "`vartype'" == "contn" {
                    local any_contn 1
                }
                else if "`vartype'" == "contln" {
                    local any_contln 1
                }
                else if "`vartype'" == "conts" {
                    local any_conts 1
                }
            }
            gettoken arg rest : rest, parse("\")
        }

        if `nvars' == 0 {
            display as error "vars() did not contain any variables"
            exit 198
        }

        local level1 : word 1 of `group_levels'
        local level2 : word 2 of `group_levels'
        * smdpair(): desctab has already mapped the user's two by() values
        * to group codes and checked them; the pair SMD compares those two.
        if "`smdpair'" != "" {
            local level1 : word 1 of `smdpair'
            local level2 : word 2 of `smdpair'
            foreach _sp in `level1' `level2' {
                if !`: list _sp in group_levels' {
                    display as error "smdpair(): `_sp' is not a level of by()"
                    exit 198
                }
            }
        }
        if "`smdtype'" == "" local smdtype "pair"
        if !inlist("`smdtype'", "pair", "population", "maxpair") {
            display as error "smdtype() must be pair, population, or maxpair"
            exit 198
        }
        local _smd_multi = ("`smdtype'" != "pair")
        local _smd_kind = cond(`has_wt', 1, cond(`has_fw', 2, 0))
        local _smd_wvar ""
        if `has_wt' {
            local _smd_wvar "`wt'"
            * Probability weights are scale-free. Their sum overflows a double
            * (summarize [aw] then fails) near 1e306, and the Mata variance
            * forms the product (sum w) * (n - 1) as well, so weights large
            * enough for that are rescaled by a power of two for the SMD;
            * dividing by 2^k is exact and every SMD is scale invariant.
            quietly summarize `wt' if `touse' & `by' < ., meanonly
            if r(N) > 0 & r(max) < . {
                if r(max) * r(N)^2 >= 1e300 {
                    tempvar _smd_ws
                    quietly generate double `_smd_ws' = `wt' / 2^ceil(ln(r(max)) / ln(2))
                    local _smd_wvar "`_smd_ws'"
                }
            }
        }
        else if `has_fw' local _smd_wvar "`fwvar'"
        local _used_ttest 0
        local _used_anova 0
        local _used_wilcoxon 0
        local _used_kw 0
        local _used_chi2 0
        local _used_fisher 0

        forvalues i = 1/`nvars' {
            local p`i' "."
            local smd`i' "."
            local test`i' ""
            local statistic`i' ""
            local nglevels 0
            local nvlevels 0

            local v `"`work_`i''"'
            local typ `"`type_`i''"'
            local orig `"`var_`i''"'
            local testvar `"`v'"'
            if "`typ'" == "contln" {
                tempvar _lnv
                quietly gen double `_lnv' = log(`v') if `touse' & `by' < . & `v' > 0
                local testvar `"`_lnv'"'
            }

            if inlist("`typ'", "contn", "contln", "conts") {
                quietly levelsof `by' if `touse' & `by' < . & `testvar' < ., local(glevels)
                local nglevels : word count `glevels'
            }
            else if inlist("`typ'", "cat", "cate") {
                quietly levelsof `by' if `touse' & `by' < . & (`v' < . | `include_missing'), local(glevels)
                local nglevels : word count `glevels'
                quietly levelsof `v' if `touse' & `by' < . & `v' < ., local(vlevels)
                local nvlevels : word count `vlevels'
                if `include_missing' {
                    quietly count if `touse' & `by' < . & `v' >= .
                    if r(N) > 0 local ++nvlevels
                }
            }
            else {
                quietly levelsof `by' if `touse' & `by' < . & `v' < ., local(glevels)
                local nglevels : word count `glevels'
                quietly levelsof `v' if `touse' & `by' < . & `v' < ., local(vlevels)
                local nvlevels : word count `vlevels'
            }

            if !`suppress_p' {
                if inlist("`typ'", "contn", "contln") & `nglevels' >= 2 {
                    * One fit supplies the label, statistic, df and p. It is
                    * weighted by the materialized weight (a weight expression
                    * such as runiform() would otherwise be redrawn here) and
                    * its sample is checked against the intended one in both
                    * directions; on a mismatch the test is left blank rather
                    * than published on a different sample.
                    tempvar _tt_exp
                    quietly generate byte `_tt_exp' = `touse' & `by' < . & `testvar' < .
                    local _tt_w ""
                    if `has_fw' local _tt_w "[fw=`fwvar']"
                    local _tt_bad 0
                    if `nglevels' == 2 {
                        capture quietly regress `testvar' ib(first).`by' `_tt_w' if `touse' & `by' < . & `testvar' < .
                        if _rc == 0 {
                            * r(table) first: count below overwrites r()
                            tempname Tmat
                            matrix `Tmat' = r(table)
                            local df2 = e(df_r)
                            local _tt_dfm = e(df_m)
                            quietly count if `_tt_exp' != e(sample)
                            if r(N) == 0 & `_tt_dfm' == 1 {
                                local tstat : display %6.2f -1 * `Tmat'[3,2]
                                local p`i' = 2 * ttail(`df2', abs(`Tmat'[3,2]))
                                local _used_ttest 1
                                local test`i' "Ind. t test"
                                if "`typ'" == "contln" local test`i' "Ind. t test, logged data"
                                local statistic`i' "t(`df2')=`tstat'"
                            }
                            else local _tt_bad 1
                        }
                    }
                    else {
                        capture quietly anova `testvar' `by' `_tt_w' if `touse' & `by' < . & `testvar' < .
                        if _rc == 0 {
                            local _tt_f = e(F)
                            local df1 = e(df_m)
                            local df2 = e(df_r)
                            quietly count if `_tt_exp' != e(sample)
                            if r(N) == 0 & `df1' == `nglevels' - 1 {
                                local p`i' = Ftail(`df1', `df2', `_tt_f')
                                local f : display %6.2f `_tt_f'
                                local _used_anova 1
                                local test`i' "ANOVA"
                                if "`typ'" == "contln" local test`i' "ANOVA, logged data"
                                local statistic`i' "F(`df1',`df2')=`f'"
                            }
                            else local _tt_bad 1
                        }
                    }
                    if `_tt_bad' {
                        display as text "note: the comparison test for `orig' was not computed; the fitted sample differs from the tabulated sample"
                    }
                }
                else if "`typ'" == "conts" & `nglevels' >= 2 {
                    if `has_fw' {
                        preserve
                        local _restore_needed 1
                        quietly keep if `touse' & `by' < . & `v' < .
                        * expand keeps n<=0 rows, so zero/missing weights must
                        * be dropped explicitly to match weighted results
                        quietly drop if missing(`fwvar') | (`fwvar') <= 0
                        quietly expand `fwvar'
                        if `nglevels' > 2 {
                            capture quietly kwallis `v', by(`by')
                            if _rc == 0 {
                                local p`i' = chi2tail(r(df), r(chi2_adj))
                                local chi2 : display %6.2f r(chi2_adj)
                                local df = r(df)
                                local _used_kw 1
                                local test`i' "Kruskal-Wallis"
                                local statistic`i' "Chi2(`df')=`chi2'"
                            }
                        }
                        if `nglevels' == 2 {
                            capture quietly ranksum `v', by(`by')
                            if _rc == 0 {
                                local z = r(z)
                                local p`i' = 2 * normal(-abs(`z'))
                                local z : display %6.2f `z'
                                local _used_wilcoxon 1
                                local test`i' "Wilcoxon rank-sum"
                                local statistic`i' "Z=`z'"
                            }
                        }
                        restore
                        local _restore_needed 0
                    }
                    else {
                        if `nglevels' > 2 {
                            capture quietly kwallis `v' if `touse' & `by' < . & `v' < ., by(`by')
                            if _rc == 0 {
                                local p`i' = chi2tail(r(df), r(chi2_adj))
                                local chi2 : display %6.2f r(chi2_adj)
                                local df = r(df)
                                local _used_kw 1
                                local test`i' "Kruskal-Wallis"
                                local statistic`i' "Chi2(`df')=`chi2'"
                            }
                        }
                        if `nglevels' == 2 {
                            capture quietly ranksum `v' if `touse' & `by' < . & `v' < ., by(`by')
                            if _rc == 0 {
                                local z = r(z)
                                local p`i' = 2 * normal(-abs(`z'))
                                local z : display %6.2f `z'
                                local _used_wilcoxon 1
                                local test`i' "Wilcoxon rank-sum"
                                local statistic`i' "Z=`z'"
                            }
                        }
                    }
                }
                else if inlist("`typ'", "cat", "cate") & `nglevels' > 1 & `nvlevels' > 1 {
                    local _cat_test_if "`touse' & `by' < ."
                    local _cat_missing_opt ""
                    local _cat_tv `"`v'"'
                    if `include_missing' {
                        local _cat_missing_opt "m"
                        * F02 (codex audit 2026-09-27): the table shows every
                        * missing code (. and .a-.z) as one Missing row, so the
                        * test must see one missing category too; tab, missing
                        * would keep .a and .b apart.
                        tempvar _cat_mtv
                        local _cat_vtype : type `v'
                        quietly generate `_cat_vtype' `_cat_mtv' = cond(missing(`v'), ., `v') ///
                            if `_cat_test_if'
                        local _cat_tv `"`_cat_mtv'"'
                    }
                    else local _cat_test_if "`_cat_test_if' & `v' < ."
                    if "`typ'" == "cat" {
                        capture quietly tab `_cat_tv' `by' [`weight'`exp'] if `_cat_test_if', chi2 `_cat_missing_opt'
                        if _rc == 0 {
                            local p`i' = r(p)
                            local chi2 : display %6.2f r(chi2)
                            local df = (r(r) - 1) * (r(c) - 1)
                            local _used_chi2 1
                            local test`i' "Chi-square"
                            local statistic`i' "Chi2(`df')=`chi2'"
                        }
                    }
                    else {
                        capture quietly tab `_cat_tv' `by' [`weight'`exp'] if `_cat_test_if', exact `_cat_missing_opt'
                        if _rc == 0 {
                            local p`i' = r(p_exact)
                            local _used_fisher 1
                            local test`i' "Fisher's exact"
                            local statistic`i' "N/A"
                        }
                    }
                }
                else if inlist("`typ'", "bin", "bine") & `nglevels' > 1 & `nvlevels' > 1 {
                    if "`typ'" == "bin" {
                        capture quietly tab `v' `by' [`weight'`exp'] if `touse' & `by' < . & `v' < ., chi2
                        if _rc == 0 {
                            local p`i' = r(p)
                            local chi2 : display %6.2f r(chi2)
                            local df = (r(r) - 1) * (r(c) - 1)
                            local _used_chi2 1
                            local test`i' "Chi-square"
                            local statistic`i' "Chi2(`df')=`chi2'"
                        }
                    }
                    else {
                        capture quietly tab `v' `by' [`weight'`exp'] if `touse' & `by' < . & `v' < ., exact
                        if _rc == 0 {
                            local p`i' = r(p_exact)
                            local _used_fisher 1
                            local test`i' "Fisher's exact"
                            local statistic`i' "N/A"
                        }
                    }
                }
            }

            if "`smd'" != "" & `_smd_multi' {
                * Population SB or max pairwise SMD over every by() group.
                local _smd_y `"`testvar'"'
                if inlist("`typ'", "bin", "bine", "cat", "cate") local _smd_y `"`v'"'
                local _smd_class = cond(inlist("`typ'", "bin", "bine"), 1, ///
                    cond(inlist("`typ'", "cat", "cate"), 2, 0))
                tempvar _smd_sel
                quietly gen byte `_smd_sel' = `touse' & `by' < . & `_smd_y' < .
                tempname _smdm
                mata: st_numscalar("`_smdm'", _t1tcfc_smd_multi( ///
                    "`_smd_y'", "`by'", "`_smd_wvar'", "`_smd_sel'", ///
                    "`group_levels'", `_smd_kind', `_smd_class', ///
                    ("`smdtype'" == "population")))
                local smd`i' = scalar(`_smdm')
                drop `_smd_sel'
            }
            else if "`smd'" != "" & "`level1'" != "" & "`level2'" != "" {
                if inlist("`typ'", "contn", "contln", "conts") {
                    local _smd_if1 "`touse' & `by' == `level1' & `testvar' < ."
                    local _smd_if2 "`touse' & `by' == `level2' & `testvar' < ."
                    if `has_wt' {
                        quietly summarize `testvar' [aw=`_smd_wvar'] if `_smd_if1'
                        local _m1 = r(mean)
                        local _s1 = r(sd)
                        quietly summarize `testvar' [aw=`_smd_wvar'] if `_smd_if2'
                        local _m2 = r(mean)
                        local _s2 = r(sd)
                        local _poolsd = sqrt((`_s1'^2 + `_s2'^2) / 2)
                    }
                    else if `has_fw' & inlist("`typ'", "contn", "contln") {
                        quietly summarize `testvar' [fw=`fwvar'] if `_smd_if1'
                        local _m1 = r(mean)
                        local _s1 = r(sd)
                        local _n1 = r(N)
                        quietly summarize `testvar' [fw=`fwvar'] if `_smd_if2'
                        local _m2 = r(mean)
                        local _s2 = r(sd)
                        local _n2 = r(N)
                        local _poolsd = sqrt((`_s1'^2 + `_s2'^2) / 2)
                    }
                    else {
                        quietly summarize `testvar' [`weight'`exp'] if `_smd_if1'
                        local _m1 = r(mean)
                        local _s1 = r(sd)
                        local _n1 = r(N)
                        quietly summarize `testvar' [`weight'`exp'] if `_smd_if2'
                        local _m2 = r(mean)
                        local _s2 = r(sd)
                        local _n2 = r(N)
                        local _poolsd = sqrt((`_s1'^2 + `_s2'^2) / 2)
                    }
                    if `_poolsd' > 0 & `_poolsd' < . local smd`i' = (`_m1' - `_m2') / `_poolsd'
                }
                else if inlist("`typ'", "bin", "bine") {
                    if `has_wt' {
                        quietly summarize `v' [aw=`_smd_wvar'] if `touse' & `by' == `level1' & `v' < .
                        local _p1 = r(mean)
                        quietly summarize `v' [aw=`_smd_wvar'] if `touse' & `by' == `level2' & `v' < .
                        local _p2 = r(mean)
                    }
                    else if `has_fw' {
                        quietly summarize `v' [fw=`fwvar'] if `touse' & `by' == `level1' & `v' < .
                        local _p1 = r(mean)
                        quietly summarize `v' [fw=`fwvar'] if `touse' & `by' == `level2' & `v' < .
                        local _p2 = r(mean)
                    }
                    else {
                        quietly summarize `v' [`weight'`exp'] if `touse' & `by' == `level1' & `v' < .
                        local _p1 = r(mean)
                        quietly summarize `v' [`weight'`exp'] if `touse' & `by' == `level2' & `v' < .
                        local _p2 = r(mean)
                    }
                    local _den = sqrt((`_p1' * (1 - `_p1') + `_p2' * (1 - `_p2')) / 2)
                    if `_den' > 0 & `_den' < . local smd`i' = (`_p1' - `_p2') / `_den'
                }
                else if inlist("`typ'", "cat", "cate") {
                    * Levels observed in the two compared groups only: a level
                    * seen only in a third group has zero share in both, so it
                    * would make the pooled covariance singular and blank an
                    * SMD whose correct value is defined.
                    quietly levelsof `v' if `touse' & inlist(`by', `level1', `level2') ///
                        & `v' < ., local(_smd_lvls)
                    local _smd_k : word count `_smd_lvls'
                    * Level j is selected by its index in the same ascending
                    * order, never by the levelsof text: a fractional float
                    * level (0.1 prints as .1000000014901161) equals no
                    * stored value, so its share was counted as 0 and the SMD
                    * was blank at rc 0.
                    tempvar _smd_ix
                    quietly egen long `_smd_ix' = group(`v') ///
                        if `touse' & inlist(`by', `level1', `level2') & `v' < .
                    local _tot1 .
                    local _tot2 .
                    if `has_wt' {
                        quietly summarize `_smd_wvar' if `touse' & `by' == `level1' & `v' < .
                        local _tot1 = r(sum)
                        quietly summarize `_smd_wvar' if `touse' & `by' == `level2' & `v' < .
                        local _tot2 = r(sum)
                    }
                    else if `has_fw' {
                        quietly summarize `fwvar' if `touse' & `by' == `level1' & `v' < ., meanonly
                        local _tot1 = r(sum)
                        quietly summarize `fwvar' if `touse' & `by' == `level2' & `v' < ., meanonly
                        local _tot2 = r(sum)
                    }
                    else {
                        quietly count if `touse' & `by' == `level1' & `v' < .
                        local _tot1 = r(N)
                        quietly count if `touse' & `by' == `level2' & `v' < .
                        local _tot2 = r(N)
                    }

                    if `_smd_k' >= 2 & `_tot1' > 0 & `_tot2' > 0 {
                        local _smd_dims = `_smd_k' - 1
                        tempname _p1mat _p2mat _catsmd
                        matrix `_p1mat' = J(1, `_smd_dims', .)
                        matrix `_p2mat' = J(1, `_smd_dims', .)
                        forvalues _cj = 1/`_smd_dims' {
                            local _num1 0
                            local _num2 0
                            if `has_wt' {
                                quietly summarize `_smd_wvar' if `touse' & `by' == `level1' & `_smd_ix' == `_cj'
                                local _num1 = r(sum)
                                quietly summarize `_smd_wvar' if `touse' & `by' == `level2' & `_smd_ix' == `_cj'
                                local _num2 = r(sum)
                            }
                            else if `has_fw' {
                                quietly summarize `fwvar' if `touse' & `by' == `level1' & `_smd_ix' == `_cj', meanonly
                                local _num1 = r(sum)
                                quietly summarize `fwvar' if `touse' & `by' == `level2' & `_smd_ix' == `_cj', meanonly
                                local _num2 = r(sum)
                            }
                            else {
                                quietly count if `touse' & `by' == `level1' & `_smd_ix' == `_cj'
                                local _num1 = r(N)
                                quietly count if `touse' & `by' == `level2' & `_smd_ix' == `_cj'
                                local _num2 = r(N)
                            }
                            matrix `_p1mat'[1, `_cj'] = `_num1' / `_tot1'
                            matrix `_p2mat'[1, `_cj'] = `_num2' / `_tot2'
                        }
                        mata: st_numscalar("`_catsmd'", _t1tcfc_cat_smd( ///
                            st_matrix("`_p1mat'"), st_matrix("`_p2mat'")))
                        local smd`i' = scalar(`_catsmd')
                    }
                }
            }
        }

        tempname sample contnmat contamat contbmat contcmat catmat
        mata: _t1tcfc_collect_mata("`touse'", "`by'", ///
            "`workvars'", "`typelist'", "`group_levels'", "`fwvar'", "`wt'", ///
            `has_fw', `has_wt', `include_total', `include_missing', `totalcode', ///
            "`sample'", "`contnmat'", "`contamat'", "`contbmat'", "`contcmat'", "`catmat'")

        /* Build disclosure masks while every count still has numeric lineage.
           Base blocks contain the real group columns only; displayed totals
           are the corresponding row margins. Unreleased complements and
           missingness rows remain logical cells but are not public markers.
           They are still sensitive: printed level counts and the group N
           give the missing row by subtraction, and a printed percentage
           releases the non-missing denominator that gives a binary's
           negative row. Left non-exact, such a row is pinned only when the
           released cells and margins pin it, and a small one is then
           protected like a printed cell. */
        local _smallcells_active = "`smallcells'" != ""
        local _missing_summary = "`missingsummary'" != ""
        tempname sc_samplemask sc_contmask sc_catmask sc_missmask sc_denmask sc_derived
        if `_smallcells_active' {
            matrix `sc_samplemask' = J(1, `ngout', 0)
            matrix `sc_contmask' = J(`nvars', `ngout', 0)
            matrix `sc_catmask' = J(rowsof(`catmat'), 1, 0)
            matrix `sc_missmask' = J(`nvars', `ngout', 0)
            matrix `sc_denmask' = J(`nvars', `ngout', 0)
            matrix `sc_derived' = J(`nvars', 1, 0)
            * Every variable prints the same group and total N, so with more
            * than one variable a block cannot withhold them: another block's
            * levels add back up to them. A one-variable table is the only
            * block that releases them and keeps the full search.
            local _sc_fixed = cond(`nvars' > 1, "fixedmargins", "")
            * smallcells(#, primary): the engine masks printed 1..k-1 cells
            * and margins only; nothing is complementary and no block is
            * marked derived, so percentages and tests stay as computed.
            local _sc_primopt ""
            * _sc_full: the slashN-derived exactness (a hidden missing or
            * negative row released by subtraction from a printed n/N) and
            * the "derived" denominator withholding are full-mode rules. In
            * primary mode a row is exact only when it is printed, and a
            * denominator is masked only when it is itself 1..k-1.
            local _sc_full = ("`scprimary'" == "")
            if "`scprimary'" != "" {
                local _sc_primopt "primary"
                local _sc_fixed ""
            }

            forvalues i = 1/`nvars' {
                local _sctyp `"`type_`i''"'
                tempname _scC _scE _scS _scRE _scRS _scCE _scCS
                tempname _scM _scRM _scCM

                if inlist("`_sctyp'", "contn", "contln", "conts") {
                    matrix `_scC' = J(2, `groupcount', 0)
                    matrix `_scE' = J(2, `groupcount', 0)
                    matrix `_scS' = J(2, `groupcount', 0)
                    forvalues _g = 1/`groupcount' {
                        local _sc_n = `contnmat'[`i', `_g']
                        if missing(`_sc_n') local _sc_n 0
                        local _sc_m = `sample'[`_g', 3] - `_sc_n'
                        matrix `_scC'[1, `_g'] = `_sc_n'
                        matrix `_scC'[2, `_g'] = `_sc_m'
                        matrix `_scS'[1, `_g'] = 1
                        if `_missing_summary' {
                            matrix `_scE'[2, `_g'] = 1
                            matrix `_scS'[2, `_g'] = 1
                        }
                    }
                    matrix `_scRE' = (0 \ `_missing_summary' * `include_total')
                    matrix `_scRS' = (`include_total' \ `_missing_summary' * `include_total')
                    matrix `_scCE' = J(1, `groupcount', 1)
                    matrix `_scCS' = J(1, `groupcount', 1)
                    * The n row is never printed, but its summary is printed only
                    * when n is not masked, so a printed mean or median says
                    * n >= k (and an empty cell n = 0): a released lower bound.
                    * Left out, N = 4 beside a printed mean (n >= 3) and a
                    * Missing <3 pinned the missing count at 1.
                    tempname _scLB _scRLB
                    matrix `_scLB' = (J(1, `groupcount', 1) \ J(1, `groupcount', 0))
                    matrix `_scRLB' = (`include_total' \ 0)

                    capture noisily _tabtools_smallcells, counts(`_scC') exact(`_scE') ///
                        sensitive(`_scS') rowexact(`_scRE') ///
                        rowsensitive(`_scRS') colexact(`_scCE') ///
                        colsensitive(`_scCS') grandexact(`include_total') ///
                        grandsensitive(`include_total') smallcells(`smallcells') ///
                        lower(`_scLB') rowlower(`_scRLB') ///
                        `_sc_fixed' `_sc_primopt'
                    if _rc == 498 & `nvars' > 1 {
                        display as error `"variable `var_`i'': a count below `smallcells' can only be protected by withholding a group or total N, which the other variables in the table release"'
                        display as error "Hint: combine sparse levels or leave the variable out of this table"
                        exit 498
                    }
                    else if _rc exit _rc
                    matrix `_scM' = r(mask)
                    matrix `_scRM' = r(rowmask)
                    matrix `_scCM' = r(colmask)
                    local _scGM = r(totalmask)

                    forvalues _g = 1/`groupcount' {
                        matrix `sc_contmask'[`i', `_g'] = `_scM'[1, `_g']
                        matrix `sc_missmask'[`i', `_g'] = `_scM'[2, `_g']
                        local _old = `sc_samplemask'[1, `_g']
                        local _new = `_scCM'[1, `_g']
                        if `_new' == 1 | (`_new' == 2 & `_old' == 0) ///
                            matrix `sc_samplemask'[1, `_g'] = `_new'
                    }
                    if `include_total' {
                        matrix `sc_contmask'[`i', `ngout'] = `_scRM'[1, 1]
                        matrix `sc_missmask'[`i', `ngout'] = `_scRM'[2, 1]
                        local _old = `sc_samplemask'[1, `ngout']
                        if `_scGM' == 1 | (`_scGM' == 2 & `_old' == 0) ///
                            matrix `sc_samplemask'[1, `ngout'] = `_scGM'
                    }
                    if r(N_primary_suppressed) > 0 & "`scprimary'" == "" ///
                        matrix `sc_derived'[`i', 1] = 1
                }
                else {
                    local _scL = `cat_nlevels_`i''
                    local _sc_hidden = 0
                    if inlist("`_sctyp'", "bin", "bine") local _sc_hidden = 2
                    else if !`include_missing' local _sc_hidden = 1
                    local _scR = `_scL' + `_sc_hidden'
                    matrix `_scC' = J(`_scR', `groupcount', 0)
                    matrix `_scE' = J(`_scR', `groupcount', 0)
                    matrix `_scS' = J(`_scR', `groupcount', 0)

                    forvalues _r = 1/`_scL' {
                        forvalues _g = 1/`groupcount' {
                            local _scrow = `cat_start_`i'' + (`_r' - 1) * `ngout' + `_g' - 1
                            matrix `_scC'[`_r', `_g'] = `catmat'[`_scrow', 5]
                            matrix `_scE'[`_r', `_g'] = 1
                            matrix `_scS'[`_r', `_g'] = 1
                        }
                    }

                    local _sc_missrow 0
                    if inlist("`_sctyp'", "bin", "bine") {
                        local _sc_negrow = `_scL' + 1
                        local _sc_missrow = `_scL' + 2
                        forvalues _g = 1/`groupcount' {
                            local _scrow = `cat_start_`i'' + `_g' - 1
                            local _sc_pos = `catmat'[`_scrow', 5]
                            local _sc_nonmiss = `catmat'[`_scrow', 6]
                            matrix `_scC'[`_sc_negrow', `_g'] = `_sc_nonmiss' - `_sc_pos'
                            matrix `_scC'[`_sc_missrow', `_g'] = `sample'[`_g', 3] - `_sc_nonmiss'
                            matrix `_scS'[`_sc_negrow', `_g'] = 1
                            matrix `_scS'[`_sc_missrow', `_g'] = 1
                            if `_missing_summary' | (`_sc_full' & "`slashN'" == "slashN" & ///
                                (inlist("`_sctyp'", "bin", "bine") | "`catrowperc'" == "")) {
                                matrix `_scE'[`_sc_missrow', `_g'] = 1
                                matrix `_scS'[`_sc_missrow', `_g'] = 1
                            }
                            if `_sc_full' & "`slashN'" == "slashN" & ///
                                (inlist("`_sctyp'", "bin", "bine") | "`catrowperc'" == "") {
                                matrix `_scE'[`_sc_negrow', `_g'] = 1
                                matrix `_scS'[`_sc_negrow', `_g'] = 1
                            }
                        }
                    }
                    else if !`include_missing' {
                        local _sc_missrow = `_scR'
                        forvalues _g = 1/`groupcount' {
                            local _scrow = `cat_start_`i'' + `_g' - 1
                            local _sc_nonmiss = `catmat'[`_scrow', 6]
                            matrix `_scC'[`_sc_missrow', `_g'] = `sample'[`_g', 3] - `_sc_nonmiss'
                            matrix `_scS'[`_sc_missrow', `_g'] = 1
                            if `_missing_summary' | (`_sc_full' & "`slashN'" == "slashN" & "`catrowperc'" == "") {
                                matrix `_scE'[`_sc_missrow', `_g'] = 1
                                matrix `_scS'[`_sc_missrow', `_g'] = 1
                            }
                        }
                    }
                    else {
                        local _sc_li 0
                        foreach _sc_level of local cat_levels_`i' {
                            local ++_sc_li
                            if "`_sc_level'" == "." local _sc_missrow `_sc_li'
                        }
                    }

                    matrix `_scRE' = J(`_scR', 1, 0)
                    matrix `_scRS' = J(`_scR', 1, 0)
                    local _sc_row_released = `include_total' | ///
                        ("`slashN'" == "slashN" & "`catrowperc'" != "")
                    forvalues _r = 1/`_scL' {
                        matrix `_scRE'[`_r', 1] = `_sc_row_released'
                        matrix `_scRS'[`_r', 1] = `_sc_row_released'
                    }
                    forvalues _r = `=`_scL' + 1'/`_scR' {
                        matrix `_scRS'[`_r', 1] = `_sc_row_released'
                    }
                    if `_sc_missrow' > 0 & `_missing_summary' & `include_total' {
                        matrix `_scRE'[`_sc_missrow', 1] = 1
                        matrix `_scRS'[`_sc_missrow', 1] = 1
                    }
                    matrix `_scCE' = J(1, `groupcount', 1)
                    matrix `_scCS' = J(1, `groupcount', 1)

                    capture noisily _tabtools_smallcells, counts(`_scC') exact(`_scE') ///
                        sensitive(`_scS') rowexact(`_scRE') ///
                        rowsensitive(`_scRS') colexact(`_scCE') ///
                        colsensitive(`_scCS') grandexact(`include_total') ///
                        grandsensitive(`include_total') smallcells(`smallcells') ///
                        `_sc_fixed' `_sc_primopt'
                    if _rc == 498 & `nvars' > 1 {
                        display as error `"variable `var_`i'': a count below `smallcells' can only be protected by withholding a group or total N, which the other variables in the table release"'
                        display as error "Hint: combine sparse levels or leave the variable out of this table"
                        exit 498
                    }
                    else if _rc exit _rc
                    matrix `_scM' = r(mask)
                    matrix `_scRM' = r(rowmask)
                    matrix `_scCM' = r(colmask)
                    local _scGM = r(totalmask)
                    local sc_rowmask_`i' `"`_scRM'"'

                    forvalues _r = 1/`_scL' {
                        forvalues _g = 1/`groupcount' {
                            local _scrow = `cat_start_`i'' + (`_r' - 1) * `ngout' + `_g' - 1
                            matrix `sc_catmask'[`_scrow', 1] = `_scM'[`_r', `_g']
                        }
                        if `include_total' {
                            local _scrow = `cat_start_`i'' + (`_r' - 1) * `ngout' + `ngout' - 1
                            matrix `sc_catmask'[`_scrow', 1] = `_scRM'[`_r', 1]
                        }
                    }
                    if `_sc_missrow' > 0 {
                        forvalues _g = 1/`groupcount' {
                            matrix `sc_missmask'[`i', `_g'] = `_scM'[`_sc_missrow', `_g']
                            if `_sc_full' & "`slashN'" == "slashN" & ///
                                (inlist("`_sctyp'", "bin", "bine") | "`catrowperc'" == "") & ///
                                `_scM'[`_sc_missrow', `_g'] > 0 ///
                                matrix `sc_denmask'[`i', `_g'] = 3
                        }
                        if `include_total' {
                            matrix `sc_missmask'[`i', `ngout'] = `_scRM'[`_sc_missrow', 1]
                            if `_sc_full' & "`slashN'" == "slashN" & ///
                                (inlist("`_sctyp'", "bin", "bine") | "`catrowperc'" == "") & ///
                                `_scRM'[`_sc_missrow', 1] > 0 ///
                                matrix `sc_denmask'[`i', `ngout'] = 3
                        }
                    }
                    if `_sc_full' & inlist("`_sctyp'", "bin", "bine") & ///
                        "`slashN'" == "slashN" {
                        forvalues _g = 1/`groupcount' {
                            if `_scM'[`_sc_negrow', `_g'] > 0 ///
                                matrix `sc_denmask'[`i', `_g'] = 3
                        }
                        if `include_total' & `_scRM'[`_sc_negrow', 1] > 0 ///
                            matrix `sc_denmask'[`i', `ngout'] = 3
                    }
                    if "`slashN'" == "slashN" & ///
                        (inlist("`_sctyp'", "bin", "bine") | "`catrowperc'" == "") {
                        forvalues _g = 1/`ngout' {
                            local _scrow = `cat_start_`i'' + `_g' - 1
                            local _sc_denom = `catmat'[`_scrow', 6]
                            * A denominator below k is a small count itself. Full
                            * mode withholds it outright: printed as <k it is a
                            * released upper bound on the sum of the level cells
                            * (x: <3 over cells 1 and 1 pins both at k = 3, and
                            * N = 6 beside a missing <4 pins the missing count).
                            * Primary mode keeps the <k marker.
                            if `_sc_denom' > 0 & `_sc_denom' < `smallcells' ///
                                matrix `sc_denmask'[`i', `_g'] = cond(`_sc_full', 3, 1)
                        }
                    }
                    forvalues _g = 1/`groupcount' {
                        local _old = `sc_samplemask'[1, `_g']
                        local _new = `_scCM'[1, `_g']
                        if `_new' == 1 | (`_new' == 2 & `_old' == 0) ///
                            matrix `sc_samplemask'[1, `_g'] = `_new'
                    }
                    if `include_total' {
                        local _old = `sc_samplemask'[1, `ngout']
                        if `_scGM' == 1 | (`_scGM' == 2 & `_old' == 0) ///
                            matrix `sc_samplemask'[1, `ngout'] = `_scGM'
                    }
                    if r(N_primary_suppressed) > 0 & "`scprimary'" == "" ///
                        matrix `sc_derived'[`i', 1] = 1
                }
            }

            * Each block above is certified with a printed denominator counted
            * as N minus the hidden rows, which holds only while that N is
            * printed. A denominator printed beside a withheld N is a released
            * sum of the level cells the block never saw (x: <3 + 0 + <3 = 4
            * pins both cells), and a Total denominator printed beside one
            * withheld group denominator gives it back by subtraction. So a
            * column whose N header is withheld withholds its denominator,
            * and the Total withholds its own when its N or any group's
            * denominator is withheld. Every printed denominator is then N
            * minus rows the blocks treated as known.
            if `_sc_full' & "`slashN'" == "slashN" {
                forvalues i = 1/`nvars' {
                    if !(inlist("`type_`i''", "bin", "bine") | ///
                        (inlist("`type_`i''", "cat", "cate") & "`catrowperc'" == "")) continue
                    local _sc_anyden 0
                    forvalues _g = 1/`groupcount' {
                        if `sc_samplemask'[1, `_g'] > 0 ///
                            matrix `sc_denmask'[`i', `_g'] = 3
                        if `sc_denmask'[`i', `_g'] > 0 local _sc_anyden 1
                    }
                    if `include_total' {
                        if `sc_samplemask'[1, `ngout'] > 0 | `_sc_anyden' ///
                            matrix `sc_denmask'[`i', `ngout'] = 3
                    }
                }
            }
        }

        preserve
        local _restore_needed 1
        clear
        quietly set obs 0
        quietly gen str244 factor = ""
        quietly gen str244 factor_sep = ""
        quietly gen double sort1 = .
        quietly gen double sort2 = .
        quietly gen byte cat_not_top_row = .
        foreach _lv of local output_levels {
            quietly gen str120 `stub'`_lv' = ""
            quietly gen double N_`_lv' = .
            quietly gen str120 _columna_`_lv' = ""
            quietly gen str120 _columnb_`_lv' = ""
            if `_smallcells_active' {
                quietly gen byte _scmask_`_lv' = 0
                quietly gen byte _scmiss_`_lv' = 0
            }
        }
        if `_smallcells_active' quietly gen byte _sc_derived = 0
        if !`suppress_p' quietly gen double p = .
        if "`smd'" != "" quietly gen double smd_val = .
        if "`test'" == "test" & !`suppress_p' quietly gen str48 test = ""
        if "`statistic'" == "statistic" & !`suppress_p' quietly gen str48 statistic = ""

        local row 0
        local sortorder 1

        local ++row
        quietly set obs `row'
        quietly replace factor = "N" in `row'
        quietly replace factor_sep = "N" in `row'
        quietly replace sort1 = `sortorder' in `row'
        foreach _lv of local output_levels {
            local _gi = `gidx_`_lv''
            local _nval = `sample'[`_gi', 3]
            local _sc_code 0
            if `_smallcells_active' local _sc_code = `sc_samplemask'[1, `_gi']
            if `_sc_code' > 0 {
                _tabtools_smallcells_render, value(`_nval') mask(`_sc_code') ///
                    smallcells(`smallcells') format(`nformat')
                local _cell `"`r(display)'"'
                quietly replace _scmask_`_lv' = `_sc_code' in `row'
            }
            else local _cell = "N=" + string(`_nval', "`nformat'")
            quietly replace `stub'`_lv' = `"`_cell'"' in `row'
            quietly replace N_`_lv' = `_nval' in `row'
        }
        local ++sortorder

        if `has_wt' {
            local ++row
            quietly set obs `row'
            quietly replace factor = "Effective sample size" in `row'
            quietly replace factor_sep = "ESS" in `row'
            quietly replace sort1 = `sortorder' in `row'
            foreach _lv of local output_levels {
                local _gi = `gidx_`_lv''
                local _ess = `sample'[`_gi', 5]
                local _sc_code 0
                if `_smallcells_active' local _sc_code = `sc_samplemask'[1, `_gi']
                if `_sc_code' > 0 {
                    local _cell "Suppressed"
                    quietly replace _scmask_`_lv' = 3 in `row'
                }
                else local _cell = "ESS=" + string(`_ess', "`nformat'")
                quietly replace `stub'`_lv' = `"`_cell'"' in `row'
            }
            local ++sortorder
        }

        forvalues i = 1/`nvars' {
            local typ `"`type_`i''"'
            local varlab : copy local varlab_`i'
            local fmt1 `"`fmt1_`i''"'
            local fmt2 `"`fmt2_`i''"'
            if "`fmt1'" == "" {
                if "`format'" == "" local fmt1 "`datafmt_`i''"
                else local fmt1 "`format'"
            }
            if "`fmt2'" == "" {
                * A GSD with no format of its own follows an explicit fmt1;
                * with neither, the caller's GSD default (desctab passes %4.2f
                * when format() was not given) replaces the mean's format.
                if "`typ'" == "contln" & `"`fmt1_`i''"' == "" & `"`gsdformat'"' != "" {
                    local fmt2 `"`gsdformat'"'
                }
                else local fmt2 "`fmt1'"
            }

            if inlist("`typ'", "contn", "contln", "conts") {
                local ++row
                quietly set obs `row'
                if "`typ'" == "contn" {
                    local _statdesc "mean`sdleft'SD`sdright'"
                    local _factor `"`macval(varlab)', `_statdesc'"'
                }
                else if "`typ'" == "contln" {
                    local _statdesc "geometric mean`gsdleft'GSD`gsdright'"
                    local _factor `"`macval(varlab)', `_statdesc'"'
                }
                else {
                    local _factor `"`macval(varlab)', median (Q1`iqrmiddle'Q3)"'
                }
                if "`varlabplus'" == "" local _factor : copy local varlab
                quietly replace factor = `"`macval(_factor)'"' in `row'
                quietly replace factor_sep = `"`macval(_factor)'"' in `row'
                quietly replace sort1 = `sortorder' in `row'
                if `_smallcells_active' {
                    quietly replace _sc_derived = `sc_derived'[`i', 1] in `row'
                    foreach _lv of local output_levels {
                        local _gi = `gidx_`_lv''
                        quietly replace _scmiss_`_lv' = `sc_missmask'[`i', `_gi'] in `row'
                    }
                }
                if `p`i'' < . quietly replace p = `p`i'' in `row'
                if `smd`i'' < . quietly replace smd_val = `smd`i'' in `row'
                if "`test'" == "test" & "`test`i''" != "" quietly replace test = `"`test`i''"' in `row'
                if "`statistic'" == "statistic" & "`statistic`i''" != "" quietly replace statistic = `"`statistic`i''"' in `row'

                foreach _lv of local output_levels {
                    local _gi = `gidx_`_lv''
                    local _nval = `contnmat'[`i', `_gi']
                    local _a = `contamat'[`i', `_gi']
                    local _b = `contbmat'[`i', `_gi']
                    local _c = `contcmat'[`i', `_gi']
                    local _cell ""
                    local _cola ""
                    local _colb ""
                    local _sc_code 0
                    if `_smallcells_active' local _sc_code = `sc_contmask'[`i', `_gi']
                    if `_sc_code' > 0 {
                        _tabtools_smallcells_render, value(`_nval') mask(`_sc_code') ///
                            smallcells(`smallcells') format(`nformat')
                        local _cell `"`r(display)'"'
                        local _cola `"`r(display)'"'
                        quietly replace _scmask_`_lv' = `_sc_code' in `row'
                    }
                    else if `_a' < . {
                        if inlist("`typ'", "contn", "contln") {
                            local _cola = string(`_a', "`fmt1'")
                            if "`typ'" == "contn" local _colb = `"`sdleft'"' + string(`_b', "`fmt2'") + `"`sdright'"'
                            else local _colb = `"`gsdleft'"' + string(`_b', "`fmt2'") + `"`gsdright'"'
                            local _cell = `"`_cola'"' + `"`_colb'"'
                        }
                        else {
                            local _cola = string(`_a', "`fmt1'")
                            local _colb = "(" + string(`_b', "`fmt2'") + `"`iqrmiddle'"' + string(`_c', "`fmt2'") + ")"
                            local _cell = `"`_cola' "' + `"`_colb'"'
                        }
                    }
                    quietly replace `stub'`_lv' = `"`_cell'"' in `row'
                    quietly replace _columna_`_lv' = `"`_cola'"' in `row'
                    quietly replace _columnb_`_lv' = `"`_colb'"' in `row'
                    quietly replace N_`_lv' = `_nval' in `row'
                }
                local ++sortorder
            }
            else if inlist("`typ'", "bin", "bine") {
                local ++row
                quietly set obs `row'
                local _factor `"`macval(varlab)', `percfootnote'"'
                if "`varlabplus'" == "" local _factor : copy local varlab
                quietly replace factor = `"`macval(_factor)'"' in `row'
                quietly replace factor_sep = `"`macval(_factor)'"' in `row'
                quietly replace sort1 = `sortorder' in `row'
                if `_smallcells_active' {
                    quietly replace _sc_derived = `sc_derived'[`i', 1] in `row'
                    foreach _lv of local output_levels {
                        local _gi = `gidx_`_lv''
                        quietly replace _scmiss_`_lv' = `sc_missmask'[`i', `_gi'] in `row'
                    }
                }
                if `p`i'' < . quietly replace p = `p`i'' in `row'
                if `smd`i'' < . quietly replace smd_val = `smd`i'' in `row'
                if "`test'" == "test" & "`test`i''" != "" quietly replace test = `"`test`i''"' in `row'
                if "`statistic'" == "statistic" & "`statistic`i''" != "" quietly replace statistic = `"`statistic`i''"' in `row'

                foreach _lv of local output_levels {
                    local _gi = `gidx_`_lv''
                    local _mrow = `cat_start_`i'' + `_gi' - 1
                    local _cnt = `catmat'[`_mrow', 5]
                    local _sc_rawcnt = `_cnt'
                    local _grpN = `catmat'[`_mrow', 6]
                    local _num = `catmat'[`_mrow', 7]
                    local _den = `catmat'[`_mrow', 8]
                    // Weighted display: show effective count (weighted % x group
                    // N) so n (%) is internally consistent (n/N = weighted %).
                    // col 5 is the raw count; cols 7/8 are weighted num/denom.
                    // r(categorical) keeps the raw count for programmatic use.
                    if `has_wt' {
                        local _gw = `catmat'[`_mrow', 8]
                        if `_gw' > 0 & `_gw' < . & !missing(`_num') ///
                            local _cnt = (`_num' / `_gw') * `_grpN'
                    }
                    if `_den' <= 0 | `_den' >= . local _pct = .
                    else local _pct = 100 * `_num' / `_den'
                    local _pfmt `"`fmt1'"'
                    if "`fmt1_`i''" == "" {
                        if "`percformat'" != "" local _pfmt "`percformat'"
                        else if `_den' < 100 local _pfmt "%3.0f"
                        else local _pfmt "%5.1f"
                    }
                    local _perc ""
                    if `_pct' < . {
                        local _perc = string(`_pct', "`_pfmt'")
                        if "`nospacelowpercent'" == "" & `_pct' < 10 & !inlist("`_perc'", "10", "10.0", "10.00") {
                            local _perc = " " + "`_perc'"
                        }
                        local _perc = "`_perc'" + `"`percsign'"'
                    }
                    local _sc_code 0
                    if `_smallcells_active' local _sc_code = `sc_catmask'[`_mrow', 1]
                    if `_sc_code' > 0 {
                        _tabtools_smallcells_render, value(`_sc_rawcnt') mask(`_sc_code') ///
                            smallcells(`smallcells') format(`nformat')
                        local _cell `"`r(display)'"'
                        local _cola `"`r(display)'"'
                        local _colb ""
                        quietly replace `stub'`_lv' = `"`_cell'"' in `row'
                        quietly replace _columna_`_lv' = `"`_cola'"' in `row'
                        quietly replace _columnb_`_lv' = "" in `row'
                        quietly replace _scmask_`_lv' = `_sc_code' in `row'
                        quietly replace N_`_lv' = `_grpN' in `row'
                        continue
                    }
                    local _nstr = string(`_cnt', "`nformat'")
                    if "`slashN'" == "slashN" {
                        local _sc_dcode 0
                        if `_smallcells_active' local _sc_dcode = `sc_denmask'[`i', `_gi']
                        if `_sc_dcode' > 0 {
                            _tabtools_smallcells_render, value(`_grpN') mask(`_sc_dcode') ///
                                smallcells(`smallcells') format(`nformat')
                            local _sc_denstr `"`r(display)'"'
                            quietly replace _scmask_`_lv' = `_sc_dcode' in `row'
                        }
                        else local _sc_denstr = string(`_grpN', "`nformat'")
                        local _nstr = "`_nstr'" + "/" + "`_sc_denstr'"
                    }
                    * A published percentage releases its own denominator -- the
                    * per-variable, per-group NON-MISSING count -- which the
                    * suppression engine is not told about: it is handed the
                    * group N as the column margin and leaves the hidden rows
                    * non-exact. A reader who divides a published count by its
                    * published percentage recovers that denominator and then
                    * subtracts, which reconstructs a primary-suppressed count
                    * exactly. Withhold every percentage in a block that carries
                    * a primary suppression, so what is published is exactly
                    * what the engine certified.
                    local _sc_pct_blocked 0
                    if `_smallcells_active' {
                        if `sc_derived'[`i', 1] == 1 {
                            local _sc_pct_blocked 1
                            local _perc ""
                        }
                    }
                    if "`percent_n'" == "" & "`percent'" == "" {
                        local _cola `"`_nstr'"'
                        local _colb "(`_perc')"
                        if `_sc_pct_blocked' local _colb ""
                    }
                    else {
                        local _cola `"`_perc'"'
                        local _colb ""
                        if `_sc_pct_blocked' local _cola `"`_nstr'"'
                    }
                    if "`percent_n'" == "percent_n" & "`percent'" == "" & !`_sc_pct_blocked' ///
                        local _colb "(`_nstr')"
                    * Only separate the two components when there IS a second
                    * component: percent-only cells otherwise end in a literal
                    * trailing space ("60 ") that reaches every flat sink.
                    local _cell = `"`_cola'"'
                    if `"`_colb'"' != "" local _cell = `"`_cola' "' + `"`_colb'"'
                    quietly replace `stub'`_lv' = `"`_cell'"' in `row'
                    quietly replace _columna_`_lv' = `"`_cola'"' in `row'
                    quietly replace _columnb_`_lv' = `"`_colb'"' in `row'
                    quietly replace N_`_lv' = `_grpN' in `row'
                }
                local ++sortorder
            }
            else if inlist("`typ'", "cat", "cate") {
                local top = `row' + 1
                quietly set obs `top'
                local _factor `"`macval(varlab)', `percfootnote2'"'
                if "`varlabplus'" == "" local _factor : copy local varlab
                quietly replace factor = `"`macval(_factor)'"' in `top'
                quietly replace factor_sep = `"`macval(varlab)'"' in `top'
                quietly replace sort1 = `sortorder' in `top'
                quietly replace sort2 = 1 in `top'
                if `_smallcells_active' {
                    quietly replace _sc_derived = `sc_derived'[`i', 1] in `top'
                    foreach _lv of local output_levels {
                        local _gi = `gidx_`_lv''
                        quietly replace _scmiss_`_lv' = `sc_missmask'[`i', `_gi'] in `top'
                    }
                }
                if `p`i'' < . quietly replace p = `p`i'' in `top'
                if `smd`i'' < . quietly replace smd_val = `smd`i'' in `top'
                if "`test'" == "test" & "`test`i''" != "" quietly replace test = `"`test`i''"' in `top'
                if "`statistic'" == "statistic" & "`statistic`i''" != "" quietly replace statistic = `"`statistic`i''"' in `top'

                foreach _lv of local output_levels {
                    local _gi = `gidx_`_lv''
                    local _mrow = `cat_start_`i'' + `_gi' - 1
                    local _grpN = `catmat'[`_mrow', 6]
                    quietly replace N_`_lv' = `_grpN' in `top'
                }

                local row = `top'
                local _lo = 0
                foreach _cl of local cat_levels_`i' {
                    local ++_lo
                    local ++row
                    if `row' < `top' local row = `top'
                    quietly set obs `row'
                    local _llab : copy local level_label_`i'_`_lo'
                    quietly replace factor = `"   `macval(_llab)'"' in `row'
                    quietly replace factor_sep = `"`macval(varlab)'"' in `row'
                    quietly replace sort1 = `sortorder' in `row'
                    quietly replace sort2 = `_lo' + 1 in `row'
                    quietly replace cat_not_top_row = 1 in `row'

                    foreach _lv of local output_levels {
                        local _gi = `gidx_`_lv''
                        local _mrow = `cat_start_`i'' + (`_lo' - 1) * `ngout' + `_gi' - 1
                        local _cnt = `catmat'[`_mrow', 5]
                        local _sc_rawcnt = `_cnt'
                        local _grpN = `catmat'[`_mrow', 6]
                        local _num = `catmat'[`_mrow', 7]
                        if "`catrowperc'" == "" local _den = `catmat'[`_mrow', 8]
                        else local _den = `catmat'[`_mrow', 9]
                        // Weighted display: effective count (weighted % x group N)
                        // for an internally consistent n (%). col 8 is the column
                        // weighted denom regardless of catrowperc.
                        if `has_wt' {
                            local _gw = `catmat'[`_mrow', 8]
                            if `_gw' > 0 & `_gw' < . & !missing(`_num') ///
                                local _cnt = (`_num' / `_gw') * `_grpN'
                        }
                        if `_den' <= 0 | `_den' >= . local _pct = .
                        else local _pct = 100 * `_num' / `_den'
                        local _pfmt `"`fmt1'"'
                        if "`fmt1_`i''" == "" {
                            if "`percformat'" != "" local _pfmt "`percformat'"
                            else if `_den' < 100 local _pfmt "%3.0f"
                            else local _pfmt "%5.1f"
                        }
                        local _perc ""
                        if `_pct' < . {
                            local _perc = string(`_pct', "`_pfmt'")
                            if "`nospacelowpercent'" == "" & "`extraspace'" == "" & `_pct' < 10 & !inlist("`_perc'", "10", "10.0", "10.00") {
                                local _perc = " " + "`_perc'"
                            }
                            if "`nospacelowpercent'" == "" & "`extraspace'" != "" & `_pct' < 10 & !inlist("`_perc'", "10", "10.0", "10.00") {
                                local _perc = "  " + "`_perc'"
                            }
                            local _perc = "`_perc'" + `"`percsign'"'
                        }
                        local _sc_code 0
                        if `_smallcells_active' local _sc_code = `sc_catmask'[`_mrow', 1]
                        if `_sc_code' > 0 {
                            _tabtools_smallcells_render, value(`_sc_rawcnt') mask(`_sc_code') ///
                                smallcells(`smallcells') format(`nformat')
                            local _cell `"`r(display)'"'
                            local _cola `"`r(display)'"'
                            local _colb ""
                            quietly replace `stub'`_lv' = `"`_cell'"' in `row'
                            quietly replace _columna_`_lv' = `"`_cola'"' in `row'
                            quietly replace _columnb_`_lv' = "" in `row'
                            quietly replace _scmask_`_lv' = `_sc_code' in `row'
                            continue
                        }
                        local _nstr = string(`_cnt', "`nformat'")
                        if "`slashN'" == "slashN" {
                            local _sc_dcode 0
                            if `_smallcells_active' {
                                if "`catrowperc'" == "" local _sc_dcode = `sc_denmask'[`i', `_gi']
                                else {
                                    local _sc_rowmat `"`sc_rowmask_`i''"'
                                    local _sc_dcode = `_sc_rowmat'[`_lo', 1]
                                }
                            }
                            if "`catrowperc'" == "" local _sc_den = `_grpN'
                            else local _sc_den = `_den'
                            if `_sc_dcode' > 0 {
                                _tabtools_smallcells_render, value(`_sc_den') mask(`_sc_dcode') ///
                                    smallcells(`smallcells') format(`nformat')
                                local _sc_denstr `"`r(display)'"'
                                quietly replace _scmask_`_lv' = `_sc_dcode' in `row'
                            }
                            else local _sc_denstr = string(`_sc_den', "`nformat'")
                            local _nstr = "`_nstr'" + "/" + "`_sc_denstr'"
                        }
                        * See the companion note above: a published percentage
                        * releases the denominator the engine models as free, so
                        * a protected block publishes counts only.
                        local _sc_pct_blocked 0
                        if `_smallcells_active' {
                            if `sc_derived'[`i', 1] == 1 {
                                local _sc_pct_blocked 1
                                local _perc ""
                            }
                        }
                        if "`percent_n'" == "" & "`percent'" == "" {
                            local _cola `"`_nstr'"'
                            local _colb "(`_perc')"
                            if `_sc_pct_blocked' local _colb ""
                        }
                        else {
                            local _cola `"`_perc'"'
                            local _colb ""
                            if `_sc_pct_blocked' local _cola `"`_nstr'"'
                        }
                        if "`percent_n'" == "percent_n" & "`percent'" == "" & !`_sc_pct_blocked' ///
                            local _colb "(`_nstr')"
                        * Only separate the two components when there IS a second
                        * component: percent-only cells otherwise end in a literal
                        * trailing space ("60 ") that reaches every flat sink.
                        local _cell = `"`_cola'"'
                        if `"`_colb'"' != "" local _cell = `"`_cola' "' + `"`_colb'"'
                        quietly replace `stub'`_lv' = `"`_cell'"' in `row'
                        quietly replace _columna_`_lv' = `"`_cola'"' in `row'
                        quietly replace _columnb_`_lv' = `"`_colb'"' in `row'
                    }
                }
                local ++sortorder
            }
        }

        capture confirm new frame `frame'
        if _rc {
            display as error "internal result frame `frame' already exists"
            exit 110
        }
        frame put *, into(`frame')
        restore
        local _restore_needed 0

        return local frame "`frame'"
        return local levels "`group_levels'"
        return local output_levels "`output_levels'"
        return scalar nvars = `nvars'
        return scalar groups = `groupcount'
        return scalar has_wt = `has_wt'
        return scalar has_cat = `any_cat'
        return scalar has_bin = `any_bin'
        return scalar has_contn = `any_contn'
        return scalar has_contln = `any_contln'
        return scalar has_conts = `any_conts'
        return scalar used_ttest = `_used_ttest'
        return scalar used_anova = `_used_anova'
        return scalar used_wilcoxon = `_used_wilcoxon'
        return scalar used_kwallis = `_used_kw'
        return scalar used_chi2 = `_used_chi2'
        return scalar used_fisher = `_used_fisher'
        if `_smallcells_active' {
            return scalar smallcells = `smallcells'
            return matrix sample_mask = `sc_samplemask'
            return matrix continuous_mask = `sc_contmask'
            return matrix categorical_mask = `sc_catmask'
            return matrix missing_mask = `sc_missmask'
            return matrix denominator_mask = `sc_denmask'
            return matrix derived_mask = `sc_derived'
        }
        else {
            return matrix sample = `sample'
            return matrix continuous_n = `contnmat'
            return matrix continuous_a = `contamat'
            return matrix continuous_b = `contbmat'
            return matrix continuous_c = `contcmat'
            return matrix categorical = `catmat'
        }
        return local varlist "`=strtrim("`processed_varlist'")'"
    }
    local rc = _rc
    if `_restore_needed' capture restore
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture mata: mata drop _t1tcfc_group_index()
capture mata: mata drop _t1tcfc_level_index()
capture mata: mata drop _t1tcfc_wscale()
capture mata: mata drop _t1tcfc_ess()
capture mata: mata drop _t1tcfc_wquantile()
capture mata: mata drop _t1tcfc_cat_smd()
capture mata: mata drop _t1tcfc_smd_wmv()
capture mata: mata drop _t1tcfc_smd_multi()
capture mata: mata drop _t1tcfc_collect_mata()

mata:
real scalar _t1tcfc_group_index(real scalar value, real colvector levels)
{
    real scalar i

    for (i = 1; i <= rows(levels); i++) {
        if (value == levels[i]) return(i)
    }
    return(.)
}

real scalar _t1tcfc_level_index(real scalar value, real colvector levels)
{
    real scalar i

    for (i = 1; i <= rows(levels); i++) {
        if ((value >= . & levels[i] >= .) | value == levels[i]) return(i)
    }
    return(.)
}

// Power of two c with max(w)/c <= 2 (2^1023 is already a missing value in
// Stata, so the exponent stops at 1022). Weighted means, variances, quantiles,
// shares and the ESS are invariant to the scale of the weights, and dividing
// by a power of two is exact (short of underflow for a weight below about
// 1e-308 of the largest), so w/c reproduces the ratios while keeping weighted
// sums, products and squares inside the double range.
// Callers use it only as a fallback after an unscaled sum overflows.
real scalar _t1tcfc_wscale(real colvector w)
{
    real scalar m, k

    if (rows(w) == 0) return(1)
    m = max(w)
    if (m >= . | m <= 0) return(1)
    k = ceil(ln(m) / ln(2))
    if (k > 1022) k = 1022
    if (k < -1021) k = -1021
    return(2^k)
}

// Kish effective sample size (sum w)^2 / sum w^2 from rescaled weights.
real scalar _t1tcfc_ess(real colvector w)
{
    real colvector ws
    real scalar s1, s2

    if (rows(w) == 0) return(.)
    ws = w / _t1tcfc_wscale(w)
    s1 = sum(ws)
    s2 = sum(ws :* ws)
    if (s2 <= 0 | s2 >= . | s1 >= .) return(.)
    return(s1 * (s1 / s2))
}

real scalar _t1tcfc_wquantile(real colvector x, real colvector w, real scalar p)
{
    real colvector keep, ord, xs, ws
    real scalar i, target, running, total, tol

    if (rows(x) == 0) return(.)
    keep = selectindex(w :> 0)
    if (rows(keep) == 0) return(.)
    x = x[keep]
    w = w[keep]
    ord = order(x, 1)
    xs = x[ord]
    ws = w[ord]
    total = sum(ws)
    // An overflowing total would make the target missing and stop the walk
    // at the second record; rescale the weights instead.
    if (total >= .) {
        ws = ws / _t1tcfc_wscale(ws)
        total = sum(ws)
    }
    if (total <= 0 | total >= .) return(.)
    // A total below 1 is rescaled the same way: the tolerance's absolute
    // floor of 1e-10 exceeds every step of the walk when the weights are
    // tiny (all 1e-12), so the first record matched every target and each
    // quartile became the mean of the two smallest values. Dividing by a
    // power of two is exact; totals of 1 and more walk as before.
    if (total < 1) {
        ws = ws / _t1tcfc_wscale(ws)
        total = sum(ws)
    }
    target = p * total
    tol = 1e-10 * max((1, total))
    running = 0
    for (i = 1; i <= rows(xs); i++) {
        running = running + ws[i]
        if (abs(running - target) <= tol) {
            if (i < rows(xs)) return((xs[i] + xs[i + 1]) / 2)
            return(xs[i])
        }
        if (running > target) return(xs[i])
    }
    return(xs[rows(xs)])
}

real scalar _t1tcfc_cat_smd(real rowvector p1, real rowvector p2)
{
    real scalar dims, distance2
    real rowvector delta
    real matrix pooled_cov

    dims = cols(p1)
    if (dims < 1 | cols(p2) != dims) return(.)
    if (any(p1 :>= .) | any(p2 :>= .)) return(.)
    if (any(p1 :< 0) | any(p2 :< 0)) return(.)

    pooled_cov = ((diag(p1') - p1' * p1) +
                  (diag(p2') - p2' * p2)) / 2
    if (rank(pooled_cov) < dims) return(.)

    delta = p1 - p2
    distance2 = delta * invsym(pooled_cov) * delta'
    if (distance2 < 0 & distance2 > -1e-12) distance2 = 0
    if (distance2 < 0 | distance2 >= .) return(.)
    return(sqrt(distance2))
}

// Weighted mean and variance as the pair SMD forms them: summarize with
// [aw] (kind 1: n/(sum w (n - 1)) * SS), [fw] (kind 2: SS/(sum w - 1)),
// or unweighted (kind 0: SS/(n - 1)). Variance is missing when undefined.
real rowvector _t1tcfc_smd_wmv(real colvector y, real colvector w,
                               real scalar kind)
{
    real scalar n, sw, m, ss, v

    n = rows(y)
    if (n == 0) return((., .))
    sw = quadsum(w)
    if (sw <= 0 | sw >= .) return((., .))
    m = quadsum(w :* y) / sw
    ss = quadsum(w :* (y :- m):^2)
    if (kind == 2) v = (sw > 1 ? ss / (sw - 1) : .)
    else v = (n > 1 ? n / (sw * (n - 1)) * ss : .)
    return((m, v))
}

// Multi-group balance statistic for one variable (smdtype population or
// maxpair). selname marks the analysed records (in sample, by() and the
// variable nonmissing). kind: 0 unweighted, 1 wt() analytic, 2 fweight.
// cls: 0 continuous (values already on the analysis scale, log for
// contln), 1 binary 0/1, 2 categorical. pop: 1 population SB, 0 maxpair.
//
// population (McCaffrey et al. 2013, sec. 4.1.2 eq. 5; sec. 4.2 takes the
// max over groups): max_g |m_g - m_pop| / sd_pop. Group means carry the
// weights; the pooled reference is unweighted under wt() and frequency
// weighted under fweight (records replicated). Continuous sd_pop uses
// n - 1; binary sqrt(p(1 - p)); categorical takes the largest per-level
// value with sqrt(p_l(1 - p_l)), as twang 2.6.2 ps.summary.new2() does per
// factor level.
//
// maxpair (Lopez and Gutman 2017, eq. 27): max over pairs of |m_a - m_b|
// divided by one denominator shared by every pair, sqrt(mean_g var_g)
// (cobalt 4.6.3 s.d.denom = "pooled"); binary var_g = p_g(1 - p_g).
// Categorical: Yang-Dalton (2012) eq. 2 with S averaged over all K
// groups -- a tabtools extension with no published source; it reduces to
// Yang-Dalton for K = 2 and to the binary form for a two-level variable.
// Any group with no usable records (or an undefined variance) gives
// missing, never a statistic over fewer groups.
real scalar _t1tcfc_smd_multi(string scalar yname, string scalar gname,
                              string scalar wname, string scalar selname,
                              string scalar levels_string, real scalar kind,
                              real scalar cls, real scalar pop)
{
    real colvector y, g, w, wpop, idx, yl, pp, den, d
    real rowvector lv, mv, m, v
    real matrix pg, pk, S, Sinv
    real scalar G, L, k, a, b, out, val, popm, popv, dd

    lv = strtoreal(tokens(levels_string))
    G = cols(lv)
    if (G < 2) return(.)
    y = st_data(., yname, selname)
    g = st_data(., gname, selname)
    if (wname != "") w = st_data(., wname, selname)
    else w = J(rows(y), 1, 1)
    if (kind == 0) w = J(rows(y), 1, 1)
    wpop = (kind == 2 ? w : J(rows(y), 1, 1))
    for (k = 1; k <= G; k++) {
        if (!any(g :== lv[k])) return(.)
    }

    out = .
    if (cls == 0 | cls == 1) {
        m = J(1, G, .)
        v = J(1, G, .)
        for (k = 1; k <= G; k++) {
            idx = selectindex(g :== lv[k])
            mv = _t1tcfc_smd_wmv(y[idx], w[idx], kind)
            m[k] = mv[1]
            v[k] = mv[2]
        }
        if (hasmissing(m)) return(.)
        if (pop) {
            mv = _t1tcfc_smd_wmv(y, wpop, (kind == 2 ? 2 : 0))
            popm = mv[1]
            popv = mv[2]
            dd = (cls == 1 ? sqrt(popm * (1 - popm)) : sqrt(popv))
            if (dd > 0 & dd < .) out = max(abs(m :- popm)) / dd
        }
        else {
            if (cls == 1) v = m :* (1 :- m)
            if (hasmissing(v)) return(.)
            dd = sqrt(mean(v'))
            if (dd > 0 & dd < .) out = (max(m) - min(m)) / dd
        }
    }
    else {
        yl = uniqrows(y)
        L = rows(yl)
        if (L < 2) return(.)
        pg = J(L, G, .)
        for (k = 1; k <= G; k++) {
            idx = selectindex(g :== lv[k])
            for (a = 1; a <= L; a++) {
                pg[a, k] = quadsum(w[idx] :* (y[idx] :== yl[a])) / quadsum(w[idx])
            }
        }
        if (hasmissing(pg)) return(.)
        if (pop) {
            pp = J(L, 1, .)
            for (a = 1; a <= L; a++) {
                pp[a] = quadsum(wpop :* (y :== yl[a])) / quadsum(wpop)
            }
            den = sqrt(pp :* (1 :- pp))
            if (any(den :<= 0) | hasmissing(den)) return(.)
            out = max(abs(pg :- pp) :/ den)
        }
        else {
            pk = pg[|1, 1 \ L - 1, G|]
            S = J(L - 1, L - 1, 0)
            for (k = 1; k <= G; k++) {
                S = S + diag(pk[., k]) - pk[., k] * pk[., k]'
            }
            S = S / G
            if (rank(S) < L - 1) return(.)
            Sinv = invsym(S)
            for (a = 1; a < G; a++) {
                for (b = a + 1; b <= G; b++) {
                    d = pk[., a] - pk[., b]
                    val = d' * Sinv * d
                    if (val < 0 & val > -1e-12) val = 0
                    if (val < 0 | val >= .) return(.)
                    val = sqrt(val)
                    if (out >= . | val > out) out = val
                }
            }
        }
    }
    if (out >= .) return(.)
    return(out)
}

void _t1tcfc_collect_mata(
    string scalar touse_name,
    string scalar group_name,
    string scalar varlist,
    string scalar typelist,
    string scalar levels_string,
    string scalar fweight_name,
    string scalar wt_name,
    real scalar has_fw,
    real scalar has_wt,
    real scalar include_total,
    real scalar include_missing,
    real scalar total_code,
    string scalar sample_name,
    string scalar contn_name,
    string scalar conta_name,
    string scalar contb_name,
    string scalar contc_name,
    string scalar cat_name)
{
    real colvector touse, group, group_levels, xvals, wvals, dvals, yvals, mask
    real colvector base_mask, level_mask
    real colvector xcol, gid
    real colvector stat_source, disp_source
    real colvector fw, wt
    real matrix X
    string rowvector vars, types
    real matrix sample, cont_n, cont_a, cont_b, cont_c, cat, block
    real matrix cell_disp, cell_w, group_disp, group_w
    real colvector levels, rawlevels, rowden
    real scalar n, nv, ng, ngout, i, j, g, gi, li, L, is_cont, is_cat
    real scalar dispw, mean, var, ss, denom, ess
    real scalar swg, sxg, sx2g, wdevsum, ovf, nobsg, brow, pass
    real colvector wprod, wprod2, wsrc, wdev, wdev2

    st_view(touse, ., touse_name)
    st_view(group, ., group_name)
    vars = tokens(varlist)
    types = tokens(typelist)
    nv = cols(vars)
    st_view(X, ., vars)

    if (has_fw) st_view(fw, ., fweight_name)
    else fw = J(rows(group), 1, 1)
    if (has_wt) st_view(wt, ., wt_name)
    else wt = J(rows(group), 1, 1)
    if (has_wt) {
        stat_source = wt
        disp_source = J(rows(group), 1, 1)
    }
    else if (has_fw) {
        stat_source = fw
        disp_source = fw
    }
    else {
        stat_source = J(rows(group), 1, 1)
        disp_source = stat_source
    }

    group_levels = strtoreal(tokens(levels_string))'
    ng = rows(group_levels)
    ngout = ng + include_total
    n = rows(group)
    gid = J(n, 1, .)
    for (i = 1; i <= n; i++) {
        if (touse[i] == 0 | group[i] >= .) continue
        gid[i] = _t1tcfc_group_index(group[i], group_levels)
    }

    sample = J(ngout, 5, .)
    for (g = 1; g <= ng; g++) {
        sample[g, 1] = g
        sample[g, 2] = group_levels[g]
        sample[g, 3] = 0
        sample[g, 4] = 0
        sample[g, 5] = (has_wt ? 0 : .)
    }
    if (include_total) {
        sample[ngout, 1] = ngout
        sample[ngout, 2] = total_code
        sample[ngout, 3] = 0
        sample[ngout, 4] = 0
        sample[ngout, 5] = (has_wt ? 0 : .)
    }

    for (i = 1; i <= n; i++) {
        gi = gid[i]
        if (gi >= .) continue
        dispw = disp_source[i]
        sample[gi, 3] = sample[gi, 3] + dispw
        if (has_wt) {
            sample[gi, 4] = sample[gi, 4] + wt[i]
            // An overflowed sum of squares stays missing; it must not restart
            sample[gi, 5] = sample[gi, 5] + wt[i] * wt[i]
        }
        if (include_total) {
            sample[ngout, 3] = sample[ngout, 3] + dispw
            if (has_wt) {
                sample[ngout, 4] = sample[ngout, 4] + wt[i]
                sample[ngout, 5] = sample[ngout, 5] + wt[i] * wt[i]
            }
        }
    }
    if (has_wt) {
        for (g = 1; g <= ngout; g++) {
            ess = .
            if (sample[g, 5] > 0 & sample[g, 5] < . & sample[g, 4] < .) {
                ess = sample[g, 4]^2 / sample[g, 5]
                // (sum w)^2 alone can overflow while the ratio is finite
                if (ess >= .) ess = sample[g, 4] * (sample[g, 4] / sample[g, 5])
            }
            // A weighted sum overflowed: recompute from rescaled weights
            if (ess >= .) {
                if (g <= ng) ess = _t1tcfc_ess(select(wt, gid :== g))
                else ess = _t1tcfc_ess(select(wt, gid :< .))
            }
            sample[g, 5] = ess
        }
    }

    cont_n = J(nv, ngout, .)
    cont_a = J(nv, ngout, .)
    cont_b = J(nv, ngout, .)
    cont_c = J(nv, ngout, .)

    for (j = 1; j <= nv; j++) {
        is_cont = (types[j] == "contn" | types[j] == "contln" | types[j] == "conts")
        if (!is_cont) continue

        xcol = X[, j]
        if (types[j] == "conts") {
            for (g = 1; g <= ngout; g++) {
                mask = (gid :< .) :& (xcol :< .) :& (stat_source :> 0)
                if (g <= ng) mask = mask :& (gid :== g)
                if (sum(mask) > 0) {
                    xvals = select(xcol, mask)
                    wvals = select(stat_source, mask)
                    cont_n[j, g] = sum(select(disp_source, mask))
                    cont_a[j, g] = _t1tcfc_wquantile(xvals, wvals, .50)
                    cont_b[j, g] = _t1tcfc_wquantile(xvals, wvals, .25)
                    cont_c[j, g] = _t1tcfc_wquantile(xvals, wvals, .75)
                }
            }
            continue
        }

        for (g = 1; g <= ngout; g++) {
            mask = (gid :< .) :& (xcol :< .) :& (stat_source :> 0)
            if (types[j] == "contln") mask = mask :& (xcol :> 0)
            if (g <= ng) mask = mask :& (gid :== g)
            nobsg = sum(mask)
            if (nobsg == 0) continue
            xvals = select(xcol, mask)
            yvals = (types[j] == "contln" ? log(xvals) : xvals)
            wvals = select(stat_source, mask)
            dvals = select(disp_source, mask)
            cont_n[j, g] = sum(dvals)
            swg = sum(wvals)
            wprod = wvals :* yvals
            wprod2 = wvals :* (yvals:^2)
            // Mata's sum() skips missing elements, so an overflowing product
            // would silently drop out of the sum. Probability weights are
            // scale-free: rescale them when a sum or product overflows (a sum
            // of finite products can overflow on its own: x near 3000 with
            // weights near 1e300), and let a sum that still contains a
            // missing product be missing.
            ovf = (swg >= . | hasmissing(wprod) | hasmissing(wprod2))
            if (!ovf) ovf = (sum(wprod) >= . | sum(wprod2) >= .)
            if (has_wt & ovf) {
                wvals = wvals / _t1tcfc_wscale(wvals)
                swg = sum(wvals)
                wprod = wvals :* yvals
                wprod2 = wvals :* (yvals:^2)
            }
            if (swg <= 0) continue
            sxg = (hasmissing(wprod) ? . : sum(wprod))
            sx2g = (hasmissing(wprod2) ? . : sum(wprod2))
            mean = sxg / swg
            // F05 (codex audit 2026-09-27): the sum of squares is taken about
            // the mean (corrected two-pass), not as sx2 - sx^2/sw, whose two
            // nearly equal raw moments cancelled a finite SD to zero or
            // missing once the values sat far from zero. The raw-moment sum
            // sx2g still decides overflow exactly as before.
            ss = .
            if (mean < . & sx2g < .) {
                wdev = wvals :* (yvals :- mean)
                wdev2 = wdev :* (yvals :- mean)
                if (!hasmissing(wdev2)) {
                    // s^2 overflows to missing once |s| > ~1.3e154 although
                    // s * (s / swg) stays finite (rescaled huge weights)
                    wdevsum = sum(wdev)
                    ss = sum(wdev2) - wdevsum * (wdevsum / swg)
                }
            }
            if (ss < 0 & ss > -1e-8) ss = 0
            var = .
            if (has_wt) {
                if (nobsg > 1) {
                    var = (nobsg / (swg * (nobsg - 1))) * ss
                    // swg * (n - 1) alone can overflow while the ratio is finite
                    if (var >= . & ss < . & swg < .) var = (nobsg / (nobsg - 1)) / swg * ss
                }
            }
            else {
                if (swg > 1) var = ss / (swg - 1)
            }
            if (types[j] == "contln") {
                cont_a[j, g] = exp(mean)
                if (var < .) cont_b[j, g] = exp(sqrt(var))
            }
            else {
                cont_a[j, g] = mean
                if (var < .) cont_b[j, g] = sqrt(var)
            }
        }
    }

    cat = J(0, 9, .)
    for (j = 1; j <= nv; j++) {
        is_cat = (types[j] == "cat" | types[j] == "cate" | types[j] == "bin" | types[j] == "bine")
        if (!is_cat) continue

        if (types[j] == "bin" | types[j] == "bine") {
            levels = 1
        }
        else {
            xcol = X[, j]
            mask = (gid :< .) :& (xcol :< .) :& (stat_source :> 0)
            if (sum(mask) > 0) rawlevels = select(X[, j], mask)
            else rawlevels = J(0, 1, .)
            if (rows(rawlevels) > 0) levels = uniqrows(sort(rawlevels, 1))
            else levels = J(0, 1, .)
            if (include_missing) {
                mask = (gid :< .) :& (xcol :>= .) :& (stat_source :> 0)
                if (sum(mask) > 0) levels = levels \ .
            }
        }
        xcol = X[, j]
        L = rows(levels)
        if (L == 0) continue
        if (types[j] == "bin" | types[j] == "bine") {
            base_mask = (gid :< .) :& (xcol :< .) :& (stat_source :> 0)
        }
        else if (include_missing) {
            base_mask = (gid :< .) :& (stat_source :> 0)
        }
        else {
            base_mask = (gid :< .) :& (xcol :< .) :& (stat_source :> 0)
        }

        // Pass 2 runs only when a weighted total overflowed on pass 1: the
        // shares and effective counts are ratios, so the weights are
        // rescaled rather than printing a raw count with no percentage.
        wsrc = stat_source
        for (pass = 1; pass <= 2; pass++) {
            cell_disp = J(L, ngout, 0)
            cell_w = J(L, ngout, 0)
            group_disp = J(1, ngout, 0)
            group_w = J(1, ngout, 0)

            for (g = 1; g <= ngout; g++) {
                mask = base_mask
                if (g <= ng) mask = mask :& (gid :== g)
                if (sum(mask) > 0) {
                    group_disp[1, g] = sum(select(disp_source, mask))
                    group_w[1, g] = sum(select(wsrc, mask))
                }
            }
            for (li = 1; li <= L; li++) {
                if (levels[li] >= .) level_mask = base_mask :& (xcol :>= .)
                else level_mask = base_mask :& (xcol :== levels[li])
                if (sum(level_mask) == 0) continue
                for (g = 1; g <= ngout; g++) {
                    mask = level_mask
                    if (g <= ng) mask = mask :& (gid :== g)
                    if (sum(mask) > 0) {
                        cell_disp[li, g] = sum(select(disp_source, mask))
                        cell_w[li, g] = sum(select(wsrc, mask))
                    }
                }
            }

            rowden = J(L, 1, 0)
            for (li = 1; li <= L; li++) {
                for (g = 1; g <= ng; g++) rowden[li] = rowden[li] + cell_w[li, g]
            }
            if (!has_wt | pass == 2) break
            if (!(hasmissing(group_w) | hasmissing(cell_w) | hasmissing(rowden))) break
            wsrc = stat_source / _t1tcfc_wscale(select(stat_source, base_mask))
        }
        block = J(L * ngout, 9, .)
        brow = 0
        for (li = 1; li <= L; li++) {
            for (g = 1; g <= ngout; g++) {
                denom = group_w[1, g]
                brow = brow + 1
                block[brow, .] = (j, levels[li], li, g, cell_disp[li, g], group_disp[1, g], cell_w[li, g], denom, rowden[li])
            }
        }
        cat = cat \ block
    }

    if (rows(cat) == 0) cat = J(1, 9, .)

    st_matrix(sample_name, sample)
    st_matrix(contn_name, cont_n)
    st_matrix(conta_name, cont_a)
    st_matrix(contb_name, cont_b)
    st_matrix(contc_name, cont_c)
    st_matrix(cat_name, cat)
}
end
