*! qba_plot Version 1.0.0  2026/03/13
*! Visualization for quantitative bias analysis
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass

/*
Creates visualizations for QBA results:
  - tornado: Tornado plot showing parameter sensitivity
  - distribution: Histogram/density of Monte Carlo corrected estimates
  - tipping: Tipping point contour plot

References:
  Lash TL, Fox MP, Fink AK. Applying Quantitative Bias Analysis to
    Epidemiologic Data. 2nd ed. Springer; 2021.
*/

capture program drop qba_plot
program define qba_plot, rclass
    version 16.0
    set varabbrev off

    * Load distribution helper
    capture program list _qba_draw_one
    if _rc {
        capture findfile _qba_distributions.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_qba_distributions.ado not found; reinstall qba"
            exit 111
        }
    }

    syntax , [TORnado DISTribution TIPping ///
        A(real -1) B(real -1) C(real -1) D(real -1) ///
        MEAsure(string) TYpe(string) ///
        PARAM1(string) RANGE1(numlist min=2 max=2) ///
        PARAM2(string) RANGE2(numlist min=2 max=2) ///
        PARAM3(string) RANGE3(numlist min=2 max=2) ///
        Steps(integer 20) ///
        BASE_se(real 0.9) BASE_sp(real 0.9) ///
        USing(string) OBServed(real -999) NUll(real 1) ///
        SCHeme(string) TItle(string) SAving(string) ///
        name(string) replace ///
        *]

    * Must specify exactly one plot type
    local n_types = ("`tornado'" != "") + ("`distribution'" != "") + ("`tipping'" != "")
    if `n_types' != 1 {
        display as error "specify exactly one of: tornado, distribution, tipping"
        exit 198
    }

    if "`scheme'" == "" local scheme "plotplainblind"
    if "`measure'" == "" local measure "OR"
    local measure = strupper("`measure'")
    if "`type'" == "" local type "exposure"

    * Map short parameter names to readable labels
    foreach _p in param1 param2 param3 {
        local _lab ""
        if "``_p''" == "se" | "``_p''" == "seca"  local _lab "Sensitivity"
        if "``_p''" == "sp" | "``_p''" == "spca"  local _lab "Specificity"
        if "``_p''" == "secb"  local _lab "Sensitivity (group B)"
        if "``_p''" == "spcb"  local _lab "Specificity (group B)"
        if "``_p''" == "sela"  local _lab "Sel: exposed cases"
        if "``_p''" == "selb"  local _lab "Sel: unexposed cases"
        if "``_p''" == "selc"  local _lab "Sel: exposed non-cases"
        if "``_p''" == "seld"  local _lab "Sel: unexposed non-cases"
        if "``_p''" == "p1"    local _lab "P(confounder|exposed)"
        if "``_p''" == "p0"    local _lab "P(confounder|unexposed)"
        if "``_p''" == "rrcd"  local _lab "RR(confounder-disease)"
        if "``_p''" == "rrud"  local _lab "RR(confounder-disease)"
        if "`_lab'" == "" local _lab "``_p''"
        local `_p'_label "`_lab'"
    }

    * =====================================================================
    * TORNADO PLOT
    * =====================================================================
    if "`tornado'" != "" {
        if `a' == -1 | `b' == -1 | `c' == -1 | `d' == -1 {
            display as error "tornado plot requires a() b() c() d()"
            exit 198
        }
        if "`param1'" == "" | "`range1'" == "" {
            display as error "tornado requires at least param1() and range1()"
            exit 198
        }

        * Compute observed measure
        local obs_or = (`a' * `d') / (`b' * `c')
        local N1 = `a' + `c'
        local N0 = `b' + `d'
        local M1 = `a' + `b'
        local M0 = `c' + `d'
        if "`measure'" == "RR" {
            local obs_meas = (`a' / `N1') / (`b' / `N0')
        }
        else {
            local obs_meas = `obs_or'
        }

        * Collect parameters to sweep
        local n_params = 0
        forvalues p = 1/3 {
            if "`param`p''" != "" {
                local ++n_params
                local pnames "`pnames' `param`p''"
            }
        }

        preserve
        quietly {
            clear
            local total_rows = `n_params' * `steps'
            set obs `total_rows'

            gen str20 parameter = ""
            gen double param_value = .
            gen double corrected = .
            gen int param_id = .

            local row = 0
            forvalues p = 1/`n_params' {
                local pname : word `p' of `pnames'
                local lo : word 1 of `range`p''
                local hi : word 2 of `range`p''
                local step_size = (`hi' - `lo') / (`steps' - 1)

                forvalues s = 1/`steps' {
                    local ++row
                    local val = `lo' + (`s' - 1) * `step_size'
                    replace parameter = "`pname'" in `row'
                    replace param_value = `val' in `row'
                    replace param_id = `p' in `row'

                    * Default Se/Sp values for non-swept parameters
                    local se_val = `base_se'
                    local sp_val = `base_sp'

                    * Override with swept parameter
                    if "`pname'" == "se" | "`pname'" == "seca" {
                        local se_val = `val'
                    }
                    else if "`pname'" == "sp" | "`pname'" == "spca" {
                        local sp_val = `val'
                    }

                    * Compute corrected table for this parameter value
                    if inlist("`pname'", "se", "seca", "sp", "spca") {
                        * Misclassification correction
                        if "`type'" == "exposure" {
                            local a_c = (`a' - (1 - `sp_val') * `M1') / (`se_val' + `sp_val' - 1)
                            local b_c = `M1' - `a_c'
                            local c_c = (`c' - (1 - `sp_val') * `M0') / (`se_val' + `sp_val' - 1)
                            local d_c = `M0' - `c_c'
                        }
                        else {
                            local a_c = (`a' - (1 - `sp_val') * `N1') / (`se_val' + `sp_val' - 1)
                            local c_c = `N1' - `a_c'
                            local b_c = (`b' - (1 - `sp_val') * `N0') / (`se_val' + `sp_val' - 1)
                            local d_c = `N0' - `b_c'
                        }
                        if "`measure'" == "OR" {
                            if `b_c' * `c_c' != 0 {
                                replace corrected = (`a_c' * `d_c') / (`b_c' * `c_c') in `row'
                            }
                        }
                        else {
                            local n1c = `a_c' + `c_c'
                            local n0c = `b_c' + `d_c'
                            if `n1c' != 0 & `n0c' != 0 {
                                replace corrected = (`a_c' / `n1c') / (`b_c' / `n0c') in `row'
                            }
                        }
                    }
                    else if inlist("`pname'", "sela", "selb", "selc", "seld") {
                        * Selection bias: sweep one selection probability
                        local sela = 1
                        local selb = 1
                        local selc = 1
                        local seld = 1
                        local `pname' = `val'
                        local a_c = `a' / `sela'
                        local b_c = `b' / `selb'
                        local c_c = `c' / `selc'
                        local d_c = `d' / `seld'
                        if "`measure'" == "OR" {
                            replace corrected = (`a_c' * `d_c') / (`b_c' * `c_c') in `row'
                        }
                        else {
                            local n1c = `a_c' + `c_c'
                            local n0c = `b_c' + `d_c'
                            replace corrected = (`a_c' / `n1c') / (`b_c' / `n0c') in `row'
                        }
                    }
                }
            }

            * Plot
            local obs_line "yline(`obs_meas', lcolor(red) lpattern(dash))"
            local null_line "yline(`null', lcolor(gs8) lpattern(dot))"

            if "`title'" == "" local title "Sensitivity of `measure' to Bias Parameters"

            if `n_params' == 1 {
                twoway (line corrected param_value, lwidth(medthick)), ///
                    `obs_line' `null_line' ///
                    ytitle("Corrected `measure'") ///
                    xtitle("`param1_label'") ///
                    title("`title'") ///
                    scheme(`scheme') ///
                    `options'
            }
            else {
                twoway (line corrected param_value if param_id == 1, lwidth(medthick)) ///
                    (line corrected param_value if param_id == 2, lwidth(medthick)) ///
                    (line corrected param_value if param_id == 3 & param_id < ., lwidth(medthick)), ///
                    `obs_line' `null_line' ///
                    ytitle("Corrected `measure'") ///
                    xtitle("Parameter value") ///
                    title("`title'") ///
                    legend(order(1 "`param1_label'" 2 "`param2_label'" 3 "`param3_label'") rows(1) pos(6)) ///
                    scheme(`scheme') ///
                    `options'
            }

            if `"`saving'"' != "" {
                graph export `"`saving'"', `replace'
            }
            if "`name'" != "" {
                graph rename Graph `name', `replace'
            }
        }
        restore
    }

    * =====================================================================
    * DISTRIBUTION PLOT
    * =====================================================================
    if "`distribution'" != "" {
        if "`using'" == "" {
            display as error "distribution plot requires using(filename)"
            exit 198
        }

        preserve
        quietly {
            use "`using'", clear

            * Find the corrected measure variable
            local result_var ""
            foreach v of varlist * {
                if regexm("`v'", "^corrected_") {
                    local result_var "`v'"
                    continue, break
                }
            }
            if "`result_var'" == "" {
                display as error "no corrected_* variable found in `using'"
                exit 198
            }

            * Get observed value
            if `observed' == -999 {
                display as error "observed() required for distribution plot"
                exit 198
            }

            summarize `result_var', detail
            local med = r(p50)
            local mn = r(mean)

            if "`title'" == "" local title "Distribution of Corrected `measure'"

            twoway (histogram `result_var', fcolor(navy%40) lcolor(navy%80) ///
                    bin(50) density) ///
                (kdensity `result_var', lcolor(navy) lwidth(medthick)), ///
                xline(`observed', lcolor(red) lwidth(medthick) lpattern(dash)) ///
                xline(`null', lcolor(gs8) lwidth(medium) lpattern(dot)) ///
                xline(`med', lcolor(dkgreen) lwidth(medium) lpattern(shortdash)) ///
                title("`title'") ///
                xtitle("Corrected `measure'") ///
                ytitle("Density") ///
                legend(order(1 "Monte Carlo" 2 "Density") ///
                    note("Red=observed, Gray=null, Green=median") pos(6) rows(1)) ///
                scheme(`scheme') ///
                `options'

            if `"`saving'"' != "" {
                graph export `"`saving'"', `replace'
            }
            if "`name'" != "" {
                graph rename Graph `name', `replace'
            }
        }
        restore
    }

    * =====================================================================
    * TIPPING POINT PLOT
    * =====================================================================
    if "`tipping'" != "" {
        if `a' == -1 | `b' == -1 | `c' == -1 | `d' == -1 {
            display as error "tipping plot requires a() b() c() d()"
            exit 198
        }
        if "`param1'" == "" | "`range1'" == "" | "`param2'" == "" | "`range2'" == "" {
            display as error "tipping requires param1() range1() param2() range2()"
            exit 198
        }

        local M1 = `a' + `b'
        local M0 = `c' + `d'
        local N1 = `a' + `c'
        local N0 = `b' + `d'
        local obs_or = (`a' * `d') / (`b' * `c')

        preserve
        quietly {
            clear
            local total = `steps' * `steps'
            set obs `total'

            local lo1 : word 1 of `range1'
            local hi1 : word 2 of `range1'
            local lo2 : word 1 of `range2'
            local hi2 : word 2 of `range2'

            gen double x = .
            gen double y = .
            gen double z = .

            local row = 0
            local step1 = (`hi1' - `lo1') / (`steps' - 1)
            local step2 = (`hi2' - `lo2') / (`steps' - 1)

            forvalues i = 1/`steps' {
                local v1 = `lo1' + (`i' - 1) * `step1'
                forvalues j = 1/`steps' {
                    local ++row
                    local v2 = `lo2' + (`j' - 1) * `step2'
                    replace x = `v1' in `row'
                    replace y = `v2' in `row'

                    * Compute corrected OR for this (param1, param2) pair
                    local se_val = `v1'
                    local sp_val = `v2'
                    if "`param1'" == "sp" | "`param1'" == "spca" {
                        local sp_val = `v1'
                        local se_val = `v2'
                    }

                    * Skip if not identifiable
                    if `se_val' + `sp_val' <= 1 {
                        replace z = . in `row'
                    }
                    else {
                        if "`type'" == "exposure" {
                            local a_c = (`a' - (1-`sp_val')*`M1') / (`se_val'+`sp_val'-1)
                            local b_c = `M1' - `a_c'
                            local c_c = (`c' - (1-`sp_val')*`M0') / (`se_val'+`sp_val'-1)
                            local d_c = `M0' - `c_c'
                        }
                        else {
                            local a_c = (`a' - (1-`sp_val')*`N1') / (`se_val'+`sp_val'-1)
                            local c_c = `N1' - `a_c'
                            local b_c = (`b' - (1-`sp_val')*`N0') / (`se_val'+`sp_val'-1)
                            local d_c = `N0' - `b_c'
                        }
                        if `b_c' > 0 & `c_c' > 0 & `a_c' > 0 & `d_c' > 0 {
                            if "`measure'" == "OR" {
                                replace z = (`a_c' * `d_c') / (`b_c' * `c_c') in `row'
                            }
                            else {
                                local n1c = `a_c' + `c_c'
                                local n0c = `b_c' + `d_c'
                                replace z = (`a_c'/`n1c') / (`b_c'/`n0c') in `row'
                            }
                        }
                    }
                }
            }

            * Create contour-like plot using colored scatter
            * Color by whether corrected estimate crosses null
            gen byte crosses_null = (z < `null' & `obs_or' >= `null') | ///
                (z >= `null' & `obs_or' < `null') if z < .
            gen byte above_obs = z > `obs_or' if z < .

            if "`title'" == "" local title "Tipping Point Analysis: `measure'"

            twoway (scatter y x if crosses_null == 1, ///
                    mcolor(cranberry%60) msymbol(square) msize(large)) ///
                (scatter y x if crosses_null == 0 & above_obs == 1, ///
                    mcolor(navy%40) msymbol(square) msize(large)) ///
                (scatter y x if crosses_null == 0 & above_obs == 0, ///
                    mcolor(dkgreen%40) msymbol(square) msize(large)), ///
                title("`title'") ///
                xtitle("`param1_label'") ytitle("`param2_label'") ///
                legend(order(1 "Crosses null" 2 "Above observed" 3 "Below observed") rows(1) pos(6)) ///
                scheme(`scheme') ///
                `options'

            if `"`saving'"' != "" {
                graph export `"`saving'"', `replace'
            }
            if "`name'" != "" {
                graph rename Graph `name', `replace'
            }
        }
        restore
    }

    return local plot_type "`tornado'`distribution'`tipping'"
    return local scheme "`scheme'"
end
