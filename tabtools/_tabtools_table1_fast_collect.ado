*! _tabtools_table1_fast_collect Version 1.8.1  2026/06/17
*! Fast pre-finalization aggregation helper for table1_tc
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _tabtools_table1_fast_collect, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _restore_needed 0

    capture noisily {

        capture _tabtools_helpers_ready
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
            SAVing(string) ///
            [ REPLACE STUB(name) TOTAL(string) TOTALCode(real -1) ///
              WT(varname numeric) SMD TEST STATistic NOPvalue WTCompare ///
              MISsing PERCENT percent_n slashN CATROWPERC VARLABPLUS ///
              Format(string) PERCFormat(string) NFormat(string) ///
              iqrmiddle(string) sdleft(string) sdright(string) ///
              gsdleft(string) gsdright(string) ///
              percsign(string) NOSPACElowpercent extraspace ]

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
        if `has_fw' local fwvar = substr("`exp'", 2, .)
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

        local output_levels "`group_levels'"
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
                    _tabtools_detect_vartype `varname'
                    local vartype "`result'"
                }
                if !inlist("`vartype'", "contn", "contln", "conts", "cat", "cate", "bin", "bine") {
                    display as error "-`varname' `vartype'- not allowed in vars() option"
                    display as error "Variables must be classified as contn, contln, conts, cat, cate, bin or bine"
                    exit 498
                }

                local ++nvars
                local var_`nvars' "`varname'"
                local processed_varlist "`processed_varlist' `varname'"
                local type_`nvars' "`vartype'"
                local fmt1_`nvars' "`varformat'"
                local fmt2_`nvars' "`varformat2'"
                local datafmt_`nvars' : format `varname'
                local varlab : variable label `varname'
                if `"`varlab'"' == "" local varlab "`varname'"
                local varlab_`nvars' `"`varlab'"'

                local workvar "`varname'"
                if inlist("`vartype'", "cat", "cate") {
                    capture confirm numeric variable `varname'
                    if _rc {
                        tempvar _catwork
                        quietly encode `varname', gen(`_catwork')
                        local workvar "`_catwork'"
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

                local work_`nvars' "`workvar'"
                local workvars "`workvars' `workvar'"
                local typelist "`typelist' `vartype'"

                if inlist("`vartype'", "cat", "cate") {
                    local any_cat 1
                    quietly levelsof `workvar' if `touse' & `by' < . & `workvar' < ., local(_clevels)
                    if `include_missing' {
                        quietly count if `touse' & `by' < . & `workvar' >= .
                        if r(N) > 0 local _clevels "`_clevels' ."
                    }
                    local cat_levels_`nvars' "`_clevels'"
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
                            if `"`_llab'"' == "" local _llab "`_cl'"
                        }
                        local level_label_`nvars'_`_lo' `"`_llab'"'
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

            local v "`work_`i''"
            local typ "`type_`i''"
            local orig "`var_`i''"
            local testvar "`v'"
            if "`typ'" == "contln" {
                tempvar _lnv
                quietly gen double `_lnv' = log(`v') if `touse' & `by' < . & `v' > 0
                local testvar "`_lnv'"
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
                    capture quietly anova `testvar' `by' [`weight'`exp'] if `touse' & `by' < . & `testvar' < .
                    if _rc == 0 {
                        local p`i' = Ftail(e(df_m), e(df_r), e(F))
                        local f : display %6.2f e(F)
                        local df1 = e(df_m)
                        local df2 = e(df_r)
                        if `nglevels' > 2 {
                            local _used_anova 1
                            local test`i' "ANOVA"
                            if "`typ'" == "contln" local test`i' "ANOVA, logged data"
                            local statistic`i' "F(`df1',`df2')=`f'"
                        }
                    }
                    if `nglevels' == 2 {
                        capture quietly regress `testvar' ib(first).`by' [`weight'`exp'] if `touse' & `by' < . & `testvar' < .
                        if _rc == 0 {
                            tempname Tmat
                            matrix `Tmat' = r(table)
                            local tstat : display %6.2f -1 * `Tmat'[3,2]
                            local _used_ttest 1
                            local test`i' "Ind. t test"
                            if "`typ'" == "contln" local test`i' "Ind. t test, logged data"
                            local statistic`i' "t(`df2')=`tstat'"
                        }
                    }
                }
                else if "`typ'" == "conts" & `nglevels' >= 2 {
                    if `has_fw' {
                        preserve
                        local _restore_needed 1
                        quietly keep if `touse' & `by' < . & `v' < .
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
                    if `include_missing' local _cat_missing_opt "m"
                    else local _cat_test_if "`_cat_test_if' & `v' < ."
                    if "`typ'" == "cat" {
                        capture quietly tab `v' `by' [`weight'`exp'] if `_cat_test_if', chi2 `_cat_missing_opt'
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
                        capture quietly tab `v' `by' [`weight'`exp'] if `_cat_test_if', exact `_cat_missing_opt'
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

            if "`smd'" != "" & "`level1'" != "" & "`level2'" != "" {
                if inlist("`typ'", "contn", "contln", "conts") {
                    local _smd_if1 "`touse' & `by' == `level1' & `testvar' < ."
                    local _smd_if2 "`touse' & `by' == `level2' & `testvar' < ."
                    if `has_wt' {
                        quietly summarize `testvar' [aw=`wt'] if `_smd_if1'
                        local _m1 = r(mean)
                        local _s1 = r(sd)
                        quietly summarize `testvar' [aw=`wt'] if `_smd_if2'
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
                        local _poolsd = sqrt(((`_n1' - 1) * `_s1'^2 + (`_n2' - 1) * `_s2'^2) / (`_n1' + `_n2' - 2))
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
                        local _poolsd = sqrt(((`_n1' - 1) * `_s1'^2 + (`_n2' - 1) * `_s2'^2) / (`_n1' + `_n2' - 2))
                    }
                    if `_poolsd' > 0 & `_poolsd' < . local smd`i' = (`_m1' - `_m2') / `_poolsd'
                }
                else if inlist("`typ'", "bin", "bine") {
                    if `has_wt' {
                        quietly summarize `v' [aw=`wt'] if `touse' & `by' == `level1' & `v' < .
                        local _p1 = r(mean)
                        quietly summarize `v' [aw=`wt'] if `touse' & `by' == `level2' & `v' < .
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
                    local _ssq 0
                    quietly levelsof `v' if `touse' & `by' < . & `v' < ., local(_smd_lvls)
                    foreach _clv of local _smd_lvls {
                        if `has_wt' {
                            local _den_if1 "`touse' & `by' == `level1' & `v' < ."
                            local _den_if2 "`touse' & `by' == `level2' & `v' < ."
                            quietly summarize `wt' if `_den_if1'
                            local _tot1 = r(sum)
                            quietly summarize `wt' if `_den_if2'
                            local _tot2 = r(sum)
                            quietly summarize `wt' if `touse' & `by' == `level1' & `v' == `_clv'
                            local _num1 = r(sum)
                            quietly summarize `wt' if `touse' & `by' == `level2' & `v' == `_clv'
                            local _num2 = r(sum)
                        }
                        else if `has_fw' {
                            local _den_if1 "`touse' & `by' == `level1' & `v' < ."
                            local _den_if2 "`touse' & `by' == `level2' & `v' < ."
                            quietly summarize `fwvar' if `_den_if1', meanonly
                            local _tot1 = r(sum)
                            quietly summarize `fwvar' if `_den_if2', meanonly
                            local _tot2 = r(sum)
                            quietly summarize `fwvar' if `touse' & `by' == `level1' & `v' == `_clv', meanonly
                            local _num1 = r(sum)
                            quietly summarize `fwvar' if `touse' & `by' == `level2' & `v' == `_clv', meanonly
                            local _num2 = r(sum)
                        }
                        else {
                            quietly count if `touse' & `by' == `level1' & `v' < .
                            local _tot1 = r(N)
                            quietly count if `touse' & `by' == `level2' & `v' < .
                            local _tot2 = r(N)
                            quietly count if `touse' & `by' == `level1' & `v' == `_clv'
                            local _num1 = r(N)
                            quietly count if `touse' & `by' == `level2' & `v' == `_clv'
                            local _num2 = r(N)
                        }
                        if `_tot1' > 0 & `_tot2' > 0 {
                            local _p1 = `_num1' / `_tot1'
                            local _p2 = `_num2' / `_tot2'
                            local _pavg = (`_p1' + `_p2') / 2
                            local _den = sqrt(`_pavg' * (1 - `_pavg'))
                            if `_den' > 0 & `_den' < . local _ssq = `_ssq' + ((`_p1' - `_p2') / `_den')^2
                        }
                    }
                    local smd`i' = sqrt(`_ssq')
                }
            }
        }

        tempname sample contnmat contamat contbmat contcmat catmat
        mata: _t1tcfc_collect_mata("`touse'", "`by'", ///
            "`workvars'", "`typelist'", "`group_levels'", "`fwvar'", "`wt'", ///
            `has_fw', `has_wt', `include_total', `include_missing', `totalcode', ///
            "`sample'", "`contnmat'", "`contamat'", "`contbmat'", "`contcmat'", "`catmat'")

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
        }
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
            local _cell = "N=" + string(`_nval', "`nformat'")
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
                local _cell = "ESS=" + string(`_ess', "`nformat'")
                quietly replace `stub'`_lv' = `"`_cell'"' in `row'
            }
            local ++sortorder
        }

        forvalues i = 1/`nvars' {
            local typ "`type_`i''"
            local varlab `"`varlab_`i''"'
            local fmt1 "`fmt1_`i''"
            local fmt2 "`fmt2_`i''"
            if "`fmt1'" == "" {
                if "`format'" == "" local fmt1 "`datafmt_`i''"
                else local fmt1 "`format'"
            }
            if "`fmt2'" == "" local fmt2 "`fmt1'"

            if inlist("`typ'", "contn", "contln", "conts") {
                local ++row
                quietly set obs `row'
                if "`typ'" == "contn" {
                    local _statdesc "mean`sdleft'SD`sdright'"
                    local _factor `"`varlab', `_statdesc'"'
                }
                else if "`typ'" == "contln" {
                    local _statdesc "geometric mean`gsdleft'GSD`gsdright'"
                    local _factor `"`varlab', `_statdesc'"'
                }
                else {
                    local _factor `"`varlab', median (Q1, Q3)"'
                }
                if "`varlabplus'" == "" local _factor `"`varlab'"'
                quietly replace factor = `"`_factor'"' in `row'
                quietly replace factor_sep = `"`_factor'"' in `row'
                quietly replace sort1 = `sortorder' in `row'
                if `p`i'' < . quietly replace p = `p`i'' in `row'
                if `smd`i'' < . quietly replace smd_val = `smd`i'' in `row'
                if "`test'" == "test" & "`test`i''" != "" quietly replace test = "`test`i''" in `row'
                if "`statistic'" == "statistic" & "`statistic`i''" != "" quietly replace statistic = "`statistic`i''" in `row'

                foreach _lv of local output_levels {
                    local _gi = `gidx_`_lv''
                    local _nval = `contnmat'[`i', `_gi']
                    local _a = `contamat'[`i', `_gi']
                    local _b = `contbmat'[`i', `_gi']
                    local _c = `contcmat'[`i', `_gi']
                    local _cell ""
                    local _cola ""
                    local _colb ""
                    if `_a' < . {
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
                local _factor `"`varlab', `percfootnote'"'
                if "`varlabplus'" == "" local _factor `"`varlab'"'
                quietly replace factor = `"`_factor'"' in `row'
                quietly replace factor_sep = `"`_factor'"' in `row'
                quietly replace sort1 = `sortorder' in `row'
                if `p`i'' < . quietly replace p = `p`i'' in `row'
                if `smd`i'' < . quietly replace smd_val = `smd`i'' in `row'
                if "`test'" == "test" & "`test`i''" != "" quietly replace test = "`test`i''" in `row'
                if "`statistic'" == "statistic" & "`statistic`i''" != "" quietly replace statistic = "`statistic`i''" in `row'

                foreach _lv of local output_levels {
                    local _gi = `gidx_`_lv''
                    local _mrow = `cat_start_`i'' + `_gi' - 1
                    local _cnt = `catmat'[`_mrow', 5]
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
                    local _pfmt "`fmt1'"
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
                    local _nstr = string(`_cnt', "`nformat'")
                    if "`slashN'" == "slashN" local _nstr = "`_nstr'" + "/" + string(`_grpN', "`nformat'")
                    if "`percent_n'" == "" & "`percent'" == "" {
                        local _cola "`_nstr'"
                        local _colb "(`_perc')"
                    }
                    else {
                        local _cola "`_perc'"
                        local _colb ""
                    }
                    if "`percent_n'" == "percent_n" & "`percent'" == "" local _colb "(`_nstr')"
                    local _cell = `"`_cola' "' + `"`_colb'"'
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
                local _factor `"`varlab', `percfootnote2'"'
                if "`varlabplus'" == "" local _factor `"`varlab'"'
                quietly replace factor = `"`_factor'"' in `top'
                quietly replace factor_sep = `"`varlab'"' in `top'
                quietly replace sort1 = `sortorder' in `top'
                quietly replace sort2 = 1 in `top'
                if `p`i'' < . quietly replace p = `p`i'' in `top'
                if `smd`i'' < . quietly replace smd_val = `smd`i'' in `top'
                if "`test'" == "test" & "`test`i''" != "" quietly replace test = "`test`i''" in `top'
                if "`statistic'" == "statistic" & "`statistic`i''" != "" quietly replace statistic = "`statistic`i''" in `top'

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
                    local _llab `"`level_label_`i'_`_lo''"'
                    quietly replace factor = `"   `_llab'"' in `row'
                    quietly replace factor_sep = `"`varlab'"' in `row'
                    quietly replace sort1 = `sortorder' in `row'
                    quietly replace sort2 = `_lo' + 1 in `row'
                    quietly replace cat_not_top_row = 1 in `row'

                    foreach _lv of local output_levels {
                        local _gi = `gidx_`_lv''
                        local _mrow = `cat_start_`i'' + (`_lo' - 1) * `ngout' + `_gi' - 1
                        local _cnt = `catmat'[`_mrow', 5]
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
                        local _pfmt "`fmt1'"
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
                        local _nstr = string(`_cnt', "`nformat'")
                        if "`slashN'" == "slashN" {
                            if "`catrowperc'" == "" local _nstr = "`_nstr'" + "/" + string(`_grpN', "`nformat'")
                            else local _nstr = "`_nstr'" + "/" + string(`_den', "`nformat'")
                        }
                        if "`percent_n'" == "" & "`percent'" == "" {
                            local _cola "`_nstr'"
                            local _colb "(`_perc')"
                        }
                        else {
                            local _cola "`_perc'"
                            local _colb ""
                        }
                        if "`percent_n'" == "percent_n" & "`percent'" == "" local _colb "(`_nstr')"
                        local _cell = `"`_cola' "' + `"`_colb'"'
                        quietly replace `stub'`_lv' = `"`_cell'"' in `row'
                        quietly replace _columna_`_lv' = `"`_cola'"' in `row'
                        quietly replace _columnb_`_lv' = `"`_colb'"' in `row'
                    }
                }
                local ++sortorder
            }
        }

        quietly save `"`saving'"', replace
        restore
        local _restore_needed 0

        return local saving `"`saving'"'
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
        return matrix sample = `sample'
        return matrix continuous_n = `contnmat'
        return matrix continuous_a = `contamat'
        return matrix continuous_b = `contbmat'
        return matrix continuous_c = `contcmat'
        return matrix categorical = `catmat'
        return local varlist "`=strtrim("`processed_varlist'")'"
    }
    local rc = _rc
    if `_restore_needed' capture restore
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture mata: mata drop _t1tcfc_group_index()
capture mata: mata drop _t1tcfc_level_index()
capture mata: mata drop _t1tcfc_wquantile()
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
    if (total <= 0) return(.)
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
    real scalar dispw, mean, var, ss, denom
    real scalar swg, sxg, sx2g, nobsg, brow

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
        sample[g, 5] = .
    }
    if (include_total) {
        sample[ngout, 1] = ngout
        sample[ngout, 2] = total_code
        sample[ngout, 3] = 0
        sample[ngout, 4] = 0
        sample[ngout, 5] = .
    }

    for (i = 1; i <= n; i++) {
        gi = gid[i]
        if (gi >= .) continue
        dispw = disp_source[i]
        sample[gi, 3] = sample[gi, 3] + dispw
        if (has_wt) {
            sample[gi, 4] = sample[gi, 4] + wt[i]
            sample[gi, 5] = (sample[gi, 5] >= . ? 0 : sample[gi, 5]) + wt[i] * wt[i]
        }
        if (include_total) {
            sample[ngout, 3] = sample[ngout, 3] + dispw
            if (has_wt) {
                sample[ngout, 4] = sample[ngout, 4] + wt[i]
                sample[ngout, 5] = (sample[ngout, 5] >= . ? 0 : sample[ngout, 5]) + wt[i] * wt[i]
            }
        }
    }
    if (has_wt) {
        for (g = 1; g <= ngout; g++) {
            if (sample[g, 5] > 0 & sample[g, 5] < .) sample[g, 5] = sample[g, 4]^2 / sample[g, 5]
            else sample[g, 5] = .
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
                mask = (gid :< .) :& (xcol :< .)
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
            mask = (gid :< .) :& (xcol :< .)
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
            if (swg <= 0) continue
            sxg = sum(wvals :* yvals)
            sx2g = sum(wvals :* (yvals:^2))
            mean = sxg / swg
            ss = sx2g - sxg * sxg / swg
            if (ss < 0 & ss > -1e-8) ss = 0
            var = .
            if (has_wt) {
                if (nobsg > 1) var = (nobsg / (swg * (nobsg - 1))) * ss
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
            mask = (gid :< .) :& (xcol :< .)
            if (sum(mask) > 0) rawlevels = select(X[, j], mask)
            else rawlevels = J(0, 1, .)
            if (rows(rawlevels) > 0) levels = uniqrows(sort(rawlevels, 1))
            else levels = J(0, 1, .)
            if (include_missing) {
                mask = (gid :< .) :& (xcol :>= .)
                if (sum(mask) > 0) levels = levels \ .
            }
        }
        xcol = X[, j]
        L = rows(levels)
        if (L == 0) continue
        cell_disp = J(L, ngout, 0)
        cell_w = J(L, ngout, 0)
        group_disp = J(1, ngout, 0)
        group_w = J(1, ngout, 0)

        if (types[j] == "bin" | types[j] == "bine") {
            base_mask = (gid :< .) :& (xcol :< .)
        }
        else if (include_missing) {
            base_mask = (gid :< .)
        }
        else {
            base_mask = (gid :< .) :& (xcol :< .)
        }

        for (g = 1; g <= ngout; g++) {
            mask = base_mask
            if (g <= ng) mask = mask :& (gid :== g)
            if (sum(mask) > 0) {
                group_disp[1, g] = sum(select(disp_source, mask))
                group_w[1, g] = sum(select(stat_source, mask))
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
                    cell_w[li, g] = sum(select(stat_source, mask))
                }
            }
        }

        rowden = J(L, 1, 0)
        for (li = 1; li <= L; li++) {
            for (g = 1; g <= ng; g++) rowden[li] = rowden[li] + cell_w[li, g]
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
