*! _qba_plot_distribution Version 1.0.1  2026/06/19
*! Internal helper: qba distribution plot branch
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

capture program drop _qba_plot_distribution
program define _qba_plot_distribution, rclass
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    local _restore_needed = 0
    local graph_rc = 0
    local measure_return ""
    set varabbrev off
    capture noisily {

        syntax , USing(string) OBServed(real) NUll(real) MEAsure(string) ///
            MEASUREuser(integer) SCHeme(string) ///
            [TItle(string) SAving(string) name(string) ///
             EXPORT_replace(string) GRAPH_replace(string) PLOTOPTSFILE(string)]

        local plotopts ""
        if `"`plotoptsfile'"' != "" {
            tempname _plotopts_fh
            file open `_plotopts_fh' using "`plotoptsfile'", read text
            file read `_plotopts_fh' plotopts
            file close `_plotopts_fh'
        }

        if `"`using'"' == "" {
            display as error "distribution plot requires using(filename)"
            exit 198
        }
        if `observed' == -999 {
            display as error "observed() required for distribution plot"
            exit 198
        }
        if missing(`observed') {
            display as error "observed() must be nonmissing"
            exit 198
        }
        if `null' != -999 & missing(`null') {
            display as error "null() must be nonmissing"
            exit 198
        }

        preserve
        local _restore_needed = 1
        quietly {
            use `"`using'"', clear

            local result_var ""
            local result_count = 0
            foreach v in corrected_or corrected_rr corrected_coefficient {
                capture confirm variable `v'
                if !_rc {
                    local ++result_count
                    local result_var "`v'"
                }
            }
            if `result_count' == 0 {
                noisily display as error "no supported corrected result variable found in `using'"
                noisily display as error "expected corrected_or, corrected_rr, or corrected_coefficient"
                exit 198
            }
            if `measureuser' {
                local requested_measure = lower("`measure'")
                local requested_var "corrected_`requested_measure'"
                if "`measure'" == "COEFFICIENT" local requested_var "corrected_coefficient"
                capture confirm variable `requested_var'
                if _rc {
                    noisily display as error "measure(`requested_measure') requested, but `requested_var' was not found in `using'"
                    exit 198
                }
                local result_var "`requested_var'"
            }
            else if `result_count' > 1 {
                noisily display as error "`using' contains multiple corrected result variables"
                noisily display as error "specify measure(OR), measure(RR), or measure(coefficient)"
                exit 198
            }
            capture confirm numeric variable `result_var'
            if _rc {
                noisily display as error "`result_var' must be numeric"
                exit 198
            }

            count if `result_var' < .
            if r(N) == 0 {
                noisily display as error "`result_var' contains no nonmissing values"
                exit 198
            }

            local inferred_measure = strupper(subinstr("`result_var'", "corrected_", "", 1))
            if !`measureuser' local measure "`inferred_measure'"
            if `measureuser' & "`measure'" != "`inferred_measure'" {
                noisily display as error "measure() does not match `result_var' in `using'"
                exit 198
            }
            local measurelabel "`measure'"
            if "`measure'" == "COEFFICIENT" local measurelabel "Coefficient"
            if `null' == -999 {
                if "`measure'" == "COEFFICIENT" local null 0
                else local null 1
            }

            summarize `result_var', detail
            local med = r(p50)

            if `"`title'"' == "" local title "Distribution of Corrected `measurelabel'"

            twoway (histogram `result_var', fcolor(navy%40) lcolor(navy%80) ///
                    bin(50) density) ///
                (kdensity `result_var', lcolor(navy) lwidth(medthick)), ///
                xline(`observed', lcolor(red) lwidth(medthick) lpattern(dash)) ///
                xline(`null', lcolor(gs8) lwidth(medium) lpattern(dot)) ///
                xline(`med', lcolor(dkgreen) lwidth(medium) lpattern(shortdash)) ///
                title(`"`title'"') ///
                xtitle("Corrected `measurelabel'") ///
                ytitle("Density") ///
                legend(order(1 "Monte Carlo" 2 "Density") ///
                    note("Red=observed, Gray=null, Green=median") pos(6) rows(1)) ///
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
            local measure_return "`measure'"
        }

    }
    local rc = _rc
    if `_restore_needed' {
        capture restore
    }
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'

    return scalar graph_rc = `graph_rc'
    return local measure "`measure_return'"
end
