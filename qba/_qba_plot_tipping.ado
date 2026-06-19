*! _qba_plot_tipping Version 1.0.1  2026/06/19
*! Internal helper: qba tipping plot branch
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

capture program drop _qba_plot_tipping
program define _qba_plot_tipping, rclass
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
            PARAM2(string) RANGE2(numlist min=2 max=2) ///
            P1type(string) P2type(string) ///
            P1label(string) P2label(string) ///
            Steps(integer) BASE_se(real) BASE_sp(real) ///
            BASE_p1(real) BASE_p0(real) BASE_conf_rr(real) BASE_conf_formula(string) ///
            NUll(real) SCHeme(string) MEASURElabel(string) ///
            [TItle(string) SAving(string) name(string) ///
             EXPORT_replace(string) GRAPH_replace(string) PLOTOPTSFILE(string)]

        local param1type "`p1type'"
        local param2type "`p2type'"
        local param1label `"`p1label'"'
        local param2label `"`p2label'"'
        local plotopts ""
        if `"`plotoptsfile'"' != "" {
            tempname _plotopts_fh
            file open `_plotopts_fh' using "`plotoptsfile'", read text
            file read `_plotopts_fh' plotopts
            file close `_plotopts_fh'
        }

        _qba_plot_validate_cells, plot(tipping) a(`a') b(`b') c(`c') d(`d')

        if "`param1'" == "" | "`range1'" == "" | "`param2'" == "" | "`range2'" == "" {
            display as error "tipping requires param1() range1() param2() range2()"
            exit 198
        }
        if "`param1type'" != "`param2type'" {
            display as error "tipping requires param1() and param2() to be the same bias type"
            display as error "use two misclassification parameters or two confounding parameters"
            exit 198
        }
        if "`param1type'" == "selection" {
            display as error "tipping does not support selection parameters"
            display as error "use two misclassification parameters or two confounding parameters"
            exit 198
        }
        if inlist("`param1'", "rrcd", "rrud") & inlist("`param2'", "rrcd", "rrud") {
            display as error "tipping cannot sweep rrcd() and rrud() together"
            display as error "use one confounder-disease parameterization per plot"
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

        preserve
        local _restore_needed = 1
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

            local both_misclass = 0
            if "`param1type'" == "misclass" & "`param2type'" == "misclass" {
                local both_misclass = 1
            }
            local both_confound = 0
            if "`param1type'" == "confound" & "`param2type'" == "confound" {
                local both_confound = 1
            }

            forvalues i = 1/`steps' {
                local v1 = `lo1' + (`i' - 1) * `step1'
                forvalues j = 1/`steps' {
                    local ++row
                    local v2 = `lo2' + (`j' - 1) * `step2'
                    replace x = `v1' in `row'
                    replace y = `v2' in `row'

                    if `both_misclass' {
                        local se_val = `base_se'
                        local sp_val = `base_sp'
                        if inlist("`param1'", "se", "seca") local se_val = `v1'
                        else if inlist("`param1'", "sp", "spca") local sp_val = `v1'
                        if inlist("`param2'", "se", "seca") local se_val = `v2'
                        else if inlist("`param2'", "sp", "spca") local sp_val = `v2'

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
                    else if `both_confound' {
                        local t_p1 = `base_p1'
                        local t_p0 = `base_p0'
                        local t_rr_val = `base_conf_rr'
                        local t_formula "`base_conf_formula'"
                        if "`param1'" == "p1" local t_p1 = `v1'
                        else if "`param1'" == "p0" local t_p0 = `v1'
                        else if "`param1'" == "rrcd" {
                            local t_rr_val = `v1'
                            local t_formula "rrcd"
                        }
                        else if "`param1'" == "rrud" {
                            local t_rr_val = `v1'
                            local t_formula "rrud"
                        }
                        if "`param2'" == "p1" local t_p1 = `v2'
                        else if "`param2'" == "p0" local t_p0 = `v2'
                        else if "`param2'" == "rrcd" {
                            local t_rr_val = `v2'
                            local t_formula "rrcd"
                        }
                        else if "`param2'" == "rrud" {
                            local t_rr_val = `v2'
                            local t_formula "rrud"
                        }
                        if "`t_formula'" == "rrud" {
                            local t_bf = (`t_p1' * `t_rr_val' + (1 - `t_p1')) / (`t_p0' * `t_rr_val' + (1 - `t_p0'))
                        }
                        else {
                            local t_bf = (`t_p1' * (`t_rr_val' - 1) + 1) / (`t_p0' * (`t_rr_val' - 1) + 1)
                        }
                        if `t_bf' != 0 & `obs_meas' < . {
                            replace z = `obs_meas' / `t_bf' in `row'
                        }
                    }
                }
            }

            gen byte crosses_null = (z < `null' & `obs_meas' >= `null') | ///
                (z >= `null' & `obs_meas' < `null') if z < .
            gen byte above_obs = z > `obs_meas' if z < .

            count if z < .
            local n_usable = r(N)
            if `n_usable' == 0 {
                noisily display as error "all grid points are infeasible or undefined"
                exit 198
            }

            if `"`title'"' == "" local title "Tipping Point Analysis: `measurelabel'"

            twoway (scatter y x if crosses_null == 1, ///
                    mcolor(cranberry%60) msymbol(square) msize(large)) ///
                (scatter y x if crosses_null == 0 & above_obs == 1, ///
                    mcolor(navy%40) msymbol(square) msize(large)) ///
                (scatter y x if crosses_null == 0 & above_obs == 0, ///
                    mcolor(dkgreen%40) msymbol(square) msize(large)), ///
                title(`"`title'"') ///
                xtitle("`param1label'") ytitle("`param2label'") ///
                legend(order(1 "Crosses null" 2 "Above observed" 3 "Below observed") rows(1) pos(6)) ///
                scheme(`scheme') ///
                `plotopts'

            if `"`saving'"' != "" {
                capture noisily graph export `"`saving'"', `export_replace'
                local graph_rc = _rc
            }
            if `"`name'"' != "" {
                local _rename_replace ""
                if "`graph_replace'" != "" {
                    quietly graph dir
                    local _graph_list " `r(list)' "
                    if strpos("`_graph_list'", " `name' ") {
                        local _rename_replace "`graph_replace'"
                    }
                }
                capture noisily graph rename Graph `name', `_rename_replace'
                if _rc & !`graph_rc' local graph_rc = _rc
            }
            count if missing(z)
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
