*! _qba_plot_tornado Version 1.0.0  2026/06/02
*! Internal helper: qba tornado plot branch
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

capture program drop _qba_plot_tornado
local _drop_rc = _rc
program define _qba_plot_tornado, rclass
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    local _restore_needed = 0
    local graph_rc = 0
    local n_missing = .
    set varabbrev off
    capture noisily {

        syntax , A(real) B(real) C(real) D(real) ///
            MEAsure(string) TYpe(string) ///
            PARAM1(string) RANGE1(numlist min=2 max=2) ///
            P1type(string) P1label(string) ///
            Steps(integer) BASE_se(real) BASE_sp(real) ///
            BASE_sela(real) BASE_selb(real) BASE_selc(real) BASE_seld(real) ///
            BASE_p1(real) BASE_p0(real) BASE_conf_rr(real) BASE_conf_formula(string) ///
            NUll(real) SCHeme(string) MEASURElabel(string) ///
            [PARAM2(string) RANGE2(numlist min=2 max=2) ///
             P2type(string) P2label(string) ///
             PARAM3(string) RANGE3(numlist min=2 max=2) ///
             P3type(string) P3label(string) ///
             TItle(string) SAving(string) name(string) ///
             EXPORT_replace(string) GRAPH_replace(string) PLOTOPTSFILE(string)]

        local param1type "`p1type'"
        local param1label `"`p1label'"'
        local param2type "`p2type'"
        local param2label `"`p2label'"'
        local param3type "`p3type'"
        local param3label `"`p3label'"'
        local plotopts ""
        if `"`plotoptsfile'"' != "" {
            tempname _plotopts_fh
            file open `_plotopts_fh' using "`plotoptsfile'", read text
            file read `_plotopts_fh' plotopts
            file close `_plotopts_fh'
        }

        _qba_plot_validate_cells, plot(tornado) a(`a') b(`b') c(`c') d(`d')

        if "`param1'" == "" | "`range1'" == "" {
            display as error "tornado requires at least param1() and range1()"
            exit 198
        }

        local M1 = `a' + `b'
        local M0 = `c' + `d'
        local N1 = `a' + `c'
        local N0 = `b' + `d'
        if `b' * `c' != 0 {
            local obs_or = (`a' * `d') / (`b' * `c')
        }
        else {
            local obs_or = .
        }
        if "`measure'" == "RR" {
            if `N1' != 0 & `N0' != 0 & `b' != 0 {
                local obs_meas = (`a' / `N1') / (`b' / `N0')
            }
            else {
                local obs_meas = .
            }
        }
        else {
            local obs_meas = `obs_or'
        }

        local n_params = 0
        forvalues p = 1/3 {
            if "`param`p''" != "" {
                local ++n_params
                local pnames "`pnames' `param`p''"
            }
        }

        preserve
        local _restore_needed = 1
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

                    if "`param`p'type'" == "misclass" {
                        local se_val = `base_se'
                        local sp_val = `base_sp'
                        if "`pname'" == "se" | "`pname'" == "seca" {
                            local se_val = `val'
                        }
                        else if "`pname'" == "sp" | "`pname'" == "spca" {
                            local sp_val = `val'
                        }

                        if `se_val' + `sp_val' <= 1 {
                            replace corrected = . in `row'
                        }
                        else {
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
                            if `a_c' > 0 & `b_c' > 0 & `c_c' > 0 & `d_c' > 0 {
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
                    else if "`param`p'type'" == "selection" {
                        local t_sela = `base_sela'
                        local t_selb = `base_selb'
                        local t_selc = `base_selc'
                        local t_seld = `base_seld'
                        local t_`pname' = `val'
                        local a_c = `a' / `t_sela'
                        local b_c = `b' / `t_selb'
                        local c_c = `c' / `t_selc'
                        local d_c = `d' / `t_seld'
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
                    else if "`param`p'type'" == "confound" {
                        local t_p1 = `base_p1'
                        local t_p0 = `base_p0'
                        local t_rr_val = `base_conf_rr'
                        local t_formula "`base_conf_formula'"
                        if "`pname'" == "p1" local t_p1 = `val'
                        else if "`pname'" == "p0" local t_p0 = `val'
                        else if "`pname'" == "rrcd" {
                            local t_rr_val = `val'
                            local t_formula "rrcd"
                        }
                        else if "`pname'" == "rrud" {
                            local t_rr_val = `val'
                            local t_formula "rrud"
                        }
                        if "`t_formula'" == "rrud" {
                            local t_bf = (`t_p1' * `t_rr_val' + (1 - `t_p1')) / (`t_p0' * `t_rr_val' + (1 - `t_p0'))
                        }
                        else {
                            local t_bf = (`t_p1' * (`t_rr_val' - 1) + 1) / (`t_p0' * (`t_rr_val' - 1) + 1)
                        }
                        if `t_bf' != 0 & `obs_meas' < . {
                            replace corrected = `obs_meas' / `t_bf' in `row'
                        }
                    }
                }
            }

            count if corrected < .
            local n_usable = r(N)
            if `n_usable' == 0 {
                noisily display as error "all grid points are infeasible or undefined"
                exit 198
            }

            local obs_line "yline(`obs_meas', lcolor(red) lpattern(dash))"
            local null_line "yline(`null', lcolor(gs8) lpattern(dot))"

            if `"`title'"' == "" local title "Sensitivity of `measurelabel' to Bias Parameters"

            if `n_params' == 1 {
                twoway (line corrected param_value, lwidth(medthick)), ///
                    `obs_line' `null_line' ///
                    ytitle("Corrected `measurelabel'") ///
                    xtitle("`param1label'") ///
                    title(`"`title'"') ///
                    scheme(`scheme') ///
                    `plotopts'
            }
            else if `n_params' == 2 {
                twoway (line corrected param_value if param_id == 1, lwidth(medthick)) ///
                    (line corrected param_value if param_id == 2, lwidth(medthick)), ///
                    `obs_line' `null_line' ///
                    ytitle("Corrected `measurelabel'") ///
                    xtitle("Parameter value") ///
                    title(`"`title'"') ///
                    legend(order(1 "`param1label'" 2 "`param2label'") rows(1) pos(6)) ///
                    scheme(`scheme') ///
                    `plotopts'
            }
            else {
                twoway (line corrected param_value if param_id == 1, lwidth(medthick)) ///
                    (line corrected param_value if param_id == 2, lwidth(medthick)) ///
                    (line corrected param_value if param_id == 3, lwidth(medthick)), ///
                    `obs_line' `null_line' ///
                    ytitle("Corrected `measurelabel'") ///
                    xtitle("Parameter value") ///
                    title(`"`title'"') ///
                    legend(order(1 "`param1label'" 2 "`param2label'" 3 "`param3label'") rows(1) pos(6)) ///
                    scheme(`scheme') ///
                    `plotopts'
            }

            if `"`saving'"' != "" {
                capture noisily graph export `"`saving'"', `export_replace'
                local graph_rc = _rc
            }
            if `"`name'"' != "" {
                capture noisily graph rename Graph `name', `graph_replace'
                if _rc & !`graph_rc' local graph_rc = _rc
            }
            count if missing(corrected)
            local n_missing = r(N)
        }

    }
    local rc = _rc
    if `_restore_needed' {
        capture restore
    }
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'

    return scalar graph_rc = `graph_rc'
    return scalar n_missing = `n_missing'
end
