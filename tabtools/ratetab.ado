*! ratetab Version 2.3.0  2026/10/05
*! Events, person-time and incidence rates (CI) by grouping variables
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
ESTIMAND
    The incidence rate D/Y per level of each grouping variable, D events in
    Y person-time, scaled by per(); one column group per outcome.

INTERVALS (ci())
    exact    (default) Exact Poisson limits for the count, divided by Y:
             Pr(K >= D | l1) = alpha/2 and Pr(K <= D | l2) = alpha/2
             ([R] ci, Methods and formulas, "Poisson mean"; Ulm 1990, Am J
             Epidemiol 131:373-375, the chi-square form of the same limits).
             l1 = invpoissontail(D, alpha/2), l2 = invpoisson(D, alpha/2).
    poisson  strate's default: rate * exp(-/+ z / sqrt(D)), the quadratic
             approximation to the Poisson log likelihood for the log rate
             ([ST] strate).
    cluster(id)  One saturated Poisson model per grouping variable and
             outcome, an indicator per level, person-time as exposure and
             vce(cluster id): exp(b_j -/+ z se_j). The point estimate equals
             D/Y; the sandwich variance allows arbitrary dependence within a
             cluster (repeated events in one person). Few clusters make it
             unreliable, so the cluster count is reported.
    A level with zero events has no likelihood-based interval; every method
    then shows the exact limits (0, -ln(alpha/2)/Y) (R3).

The table is rendered by stratetab from strate-format files, so its frame()
is a stratetab frame that comptab, rateframe() accepts.
*/

capture program drop ratetab
program define ratetab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname _work _est _clus
    local _work_made 0
    local _files ""
    capture noisily {
        syntax varlist(min=1) [if] [in] , [EVents(varlist numeric) ///
            EXPosure(varname numeric) PER(real 1000) CI(string) Level(real -1) ///
            SMALLcells(integer -1) NOSMALLcells CFormat(string) DIGits(integer -1) ///
            PYDigits(integer 0) PYScale(real 1) SEP(string) ///
            OUTLabels(string) EXPLabels(string) UNITlabel(string) *]

        **# Source of events and person-time
        local _st 0
        if "`events'" == "" & "`exposure'" == "" {
            if `"`: char _dta[_dta]'"' != "st" {
                display as error "ratetab: give events() and exposure(), or stset the data"
                exit 119
            }
            local _st 1
        }
        else if "`events'" == "" | "`exposure'" == "" {
            display as error "events() and exposure() go together"
            exit 198
        }
        if `per' <= 0 | missing(`per') {
            display as error "per() must be a positive number"
            exit 198
        }
        if `pyscale' <= 0 | missing(`pyscale') {
            display as error "pyscale() must be a positive number"
            exit 198
        }
        if `level' == -1 local level = c(level)
        if `level' < 10 | `level' > 99.99 {
            display as error "level() must be between 10 and 99.99"
            exit 198
        }
        if `smallcells' != -1 & "`nosmallcells'" != "" {
            display as error "smallcells() and nosmallcells may not be combined"
            exit 198
        }
        if `"`cformat'"' != "" & `digits' != -1 {
            display as error "cformat() and digits() may not be combined"
            exit 198
        }

        **# ci()
        local _ci = strtrim(lower(`"`ci'"'))
        local _clusvar ""
        if `"`_ci'"' == "" local _ci "exact"
        if regexm(`"`ci'"', "^[ ]*[cC][lL][uU][sS][tT][eE][rR][ ]*\(([^()]+)\)[ ]*$") {
            local _clusvar = strtrim(regexs(1))
            capture confirm variable `_clusvar', exact
            if _rc {
                display as error `"ci(cluster()): variable "`_clusvar'" not found"'
                exit 111
            }
            local _ci "cluster"
        }
        else if !inlist(`"`_ci'"', "exact", "poisson") {
            display as error "ci() must be exact, poisson, or cluster(varname)"
            exit 198
        }

        **# Sample
        * Each grouping variable keeps its own nonmissing rows (as strate run
        * per variable): a missing value in one grouping variable must not
        * remove the row from another variable's table.
        marksample touse, strok novarlist
        tempvar _nm
        quietly egen int `_nm' = rownonmiss(`varlist'), strok
        quietly replace `touse' = 0 if `_nm' == 0
        drop `_nm'
        if `_st' {
            quietly replace `touse' = 0 if _st != 1
            tempvar _ev _py
            quietly gen double `_ev' = _d if `touse'
            quietly gen double `_py' = _t - _t0 if `touse'
            local events "`_ev'"
            local exposure "`_py'"
            local _evnames "_d"
        }
        else {
            local _evnames "`events'"
            markout `touse' `events' `exposure'
        }
        if "`_clusvar'" != "" {
            quietly count if `touse' & missing(`_clusvar')
            if r(N) {
                display as error "ci(cluster()): `_clusvar' is missing in `r(N)' observation(s) of the sample"
                exit 459
            }
        }
        quietly count if `touse'
        if r(N) == 0 {
            display as error "no observations"
            exit 2000
        }
        local _N = r(N)
        quietly count if `touse' & `exposure' < 0
        if r(N) {
            display as error "exposure is negative in `r(N)' observation(s)"
            exit 459
        }
        foreach _e of local events {
            quietly count if `touse' & (`_e' < 0 | `_e' != floor(`_e'))
            if r(N) {
                display as error "events must be nonnegative integers (counts); `r(N)' observation(s) are not"
                exit 459
            }
            quietly count if `touse' & `_e' > 0 & `exposure' == 0
            if r(N) {
                display as error "`r(N)' observation(s) have events but no person-time"
                exit 459
            }
        }
        local n_out : word count `events'
        local n_grp : word count `varlist'

        **# Labels
        if `"`outlabels'"' == "" {
            forvalues _o = 1/`n_out' {
                local _en : word `_o' of `_evnames'
                if `_st' {
                    local _fv : char _dta[st_bd]
                    local _lab ""
                    if "`_fv'" != "" capture local _lab : variable label `_fv'
                    if `"`_lab'"' == "" local _lab "Events"
                }
                else {
                    local _lab : variable label `_en'
                    if `"`_lab'"' == "" local _lab "`_en'"
                }
                local outlabels = cond(`_o' == 1, `"`_lab'"', `"`outlabels' \ `_lab'"')
            }
        }
        if `"`explabels'"' == "" {
            forvalues _g = 1/`n_grp' {
                local _gv : word `_g' of `varlist'
                local _lab : variable label `_gv'
                if `"`_lab'"' == "" local _lab "`_gv'"
                local explabels = cond(`_g' == 1, `"`_lab'"', `"`explabels' \ `_lab'"')
            }
        }
        if `"`unitlabel'"' == "" local unitlabel = strtrim(string(`per', "%21.0fc"))

        **# Per level counts and intervals, in a work frame
        local _alpha = (1 - `level' / 100) / 2
        local _z = invnormal(1 - `_alpha')
        local _keep "`varlist' `events' `exposure' `_clusvar'"
        local _keep : list uniq _keep
        frame put `_keep' if `touse', into(`_work')
        local _work_made 1
        local _nrows 0
        matrix `_clus' = J(`n_grp', `n_out', .)
        local _n_zero 0
        local _n_noci 0
        forvalues _g = 1/`n_grp' {
            local _gv : word `_g' of `varlist'
            frame `_work': quietly count if !missing(`_gv')
            if r(N) == 0 {
                display as error "ratetab: `_gv' is missing in every observation of the sample"
                exit 2000
            }
            forvalues _o = 1/`n_out' {
                local _e : word `_o' of `events'
                tempfile _tf
                frame `_work' {
                    tempvar _grp _dl _lo _hi
                    quietly egen long `_grp' = group(`_gv'), label
                    quietly levelsof `_grp', local(_levs)
                    quietly gen double `_lo' = .
                    quietly gen double `_hi' = .
                    if "`_ci'" == "cluster" {
                        quietly bysort `_grp': egen double `_dl' = total(`_e')
                        * rows without person-time carry no events (refused above)
                        * and no information; leave them out explicitly so the
                        * fit's sample is known in advance
                        quietly count if `_dl' > 0 & `exposure' > 0 & !missing(`_grp')
                        local _nfit = r(N)
                        if `_nfit' {
                            * start at the closed-form MLE, ln(D/Y) per level, so
                            * b and its sandwich variance are evaluated at the
                            * exact rate rather than at ml's stopping point
                            tempname _init
                            capture matrix drop `_init'
                            foreach _l of local _levs {
                                quietly summarize `_e' if `_grp' == `_l' & `_dl' > 0 & `exposure' > 0, meanonly
                                if r(N) == 0 continue
                                local _Dl = r(sum)
                                quietly summarize `exposure' if `_grp' == `_l' & `_dl' > 0 & `exposure' > 0, meanonly
                                matrix `_init' = nullmat(`_init'), ln(`_Dl' / r(sum))
                            }
                            capture noisily quietly poisson `_e' ibn.`_grp' if `_dl' > 0 & `exposure' > 0 & !missing(`_grp'), ///
                                exposure(`exposure') noconstant vce(cluster `_clusvar') from(`_init', copy)
                            if _rc {
                                local _prc = _rc
                                display as error "ratetab: the clustered Poisson fit for `_gv' failed (r(`_prc'))"
                                exit `_prc'
                            }
                            if e(converged) != 1 {
                                display as error "ratetab: the clustered Poisson fit for `_gv' did not converge"
                                exit 430
                            }
                            if e(N) != `_nfit' {
                                display as error "ratetab: the clustered Poisson fit for `_gv' used e(N) = `e(N)' of `_nfit' rows"
                                exit 459
                            }
                            matrix `_clus'[`_g', `_o'] = e(N_clust)
                            foreach _l of local _levs {
                                quietly summarize `_dl' if `_grp' == `_l', meanonly
                                if r(max) > 0 {
                                    local _b = _b[`_l'.`_grp']
                                    local _s = _se[`_l'.`_grp']
                                    if `_s' > 0 & !missing(`_s') {
                                        quietly replace `_lo' = exp(_b[`_l'.`_grp'] - `_z' * _se[`_l'.`_grp']) if `_grp' == `_l'
                                        quietly replace `_hi' = exp(_b[`_l'.`_grp'] + `_z' * _se[`_l'.`_grp']) if `_grp' == `_l'
                                    }
                                }
                            }
                        }
                        drop `_dl'
                    }
                    preserve
                    quietly drop if missing(`_grp')
                    quietly collapse (sum) _D = `_e' _Y = `exposure' (max) _lo_c = `_lo' _hi_c = `_hi', by(`_grp')
                    quietly count if _Y <= 0
                    if r(N) {
                        display as error "ratetab: a level of `_gv' has no person-time"
                        exit 459
                    }
                    quietly decode `_grp', gen(cat)
                    * person-time in pyscale units (what stratetab prints) and
                    * rates per unit of it
                    quietly replace _Y = _Y / `pyscale'
                    quietly gen double _Rate = _D / _Y
                    quietly gen double _Lower = .
                    quietly gen double _Upper = .
                    if "`_ci'" == "exact" {
                        quietly replace _Lower = invpoissontail(_D, `_alpha') / _Y if _D > 0
                        quietly replace _Upper = invpoisson(_D, `_alpha') / _Y if _D > 0
                    }
                    else if "`_ci'" == "poisson" {
                        quietly replace _Lower = _Rate * exp(-`_z' / sqrt(_D)) if _D > 0
                        quietly replace _Upper = _Rate * exp(`_z' / sqrt(_D)) if _D > 0
                    }
                    else {
                        * exp(b) is a rate per unit of the exposure variable
                        quietly replace _Lower = _lo_c * `pyscale' if _D > 0
                        quietly replace _Upper = _hi_c * `pyscale' if _D > 0
                        quietly count if _D > 0 & (missing(_Lower) | missing(_Upper))
                        local _n_noci = `_n_noci' + r(N)
                    }
                    * R3: zero events -> exact limits (0, -ln(alpha/2)/Y)
                    quietly count if _D == 0
                    local _n_zero = `_n_zero' + r(N)
                    quietly replace _Lower = 0 if _D == 0
                    quietly replace _Upper = -ln(`_alpha') / _Y if _D == 0
                    local _lvtxt = strtrim(string(`level', "%21.15g"))
                    label variable _Lower "Lower `_lvtxt'% bound"
                    label variable _Upper "Upper `_lvtxt'% bound"
                    * one row per level, for r(estimates)
                    local _nl = _N
                    forvalues _i = 1/`_nl' {
                        local ++_nrows
                        matrix `_est' = nullmat(`_est') \ (`_o', `_g', `_i', _D[`_i'], _Y[`_i'], ///
                            _Rate[`_i'] * `per', _Lower[`_i'] * `per', _Upper[`_i'] * `per')
                    }
                    keep cat _D _Y _Rate _Lower _Upper
                    order cat _D _Y _Rate _Lower _Upper
                    quietly save "`_tf'.dta", replace
                    restore
                    drop `_grp' `_lo' `_hi'
                }
                local _files `"`_files' `_tf'"'
            }
        }
        matrix colnames `_est' = outcome group level events persontime rate lb ub

        **# Render with stratetab
        local _sc_opt ""
        if `smallcells' != -1 local _sc_opt "smallcells(`smallcells')"
        if "`nosmallcells'" != "" local _sc_opt "nosmallcells"
        local _fmt_opt ""
        if `"`cformat'"' != "" local _fmt_opt `"cformat(`cformat')"'
        else if `digits' != -1 local _fmt_opt "digits(`digits')"
        local _sep_opt ""
        if `"`sep'"' != "" local _sep_opt `"sep(`"`sep'"')"'
        capture noisily stratetab, using(`_files') outcomes(`n_out') ///
            outlabels(`"`outlabels'"') explabels(`"`explabels'"') level(`level') ///
            ratescale(`per') unitlabel(`"`unitlabel'"') pydigits(`pydigits') ///
            `_fmt_opt' `_sep_opt' `_sc_opt' `macval(options)'
        local _st_rc = _rc
        * read what is needed before return add hands r() over
        local _sc_used = r(smallcells)
        local _frame_out `"`r(frame)'"'
        return add
        if `_st_rc' exit `_st_rc'
        if `"`_frame_out'"' != "" {
            frame `_frame_out': char _dta[tabtools_producer] "ratetab"
            frame `_frame_out': char _dta[tabtools_ci_method] "`_ci'"
        }

        **# Returns and the methods sentence
        local _m "Incidence rates per `unitlabel' person-years with `level'% confidence intervals"
        if "`_ci'" == "exact" local _m "`_m' from exact Poisson limits for the event count"
        if "`_ci'" == "poisson" local _m "`_m' from the quadratic approximation to the Poisson log likelihood for the log rate"
        if "`_ci'" == "cluster" {
            local _m "`_m' from one Poisson model per grouping variable with an indicator per level, person-time as exposure and variance clustered on `_clusvar'"
            forvalues _g = 1/`n_grp' {
                local _gv : word `_g' of `varlist'
                forvalues _o = 1/`n_out' {
                    local _G = el(`_clus', `_g', `_o')
                    if !missing(`_G') display as text "(ratetab: `_gv': " as result `_G' as text " clusters of `_clusvar')"
                }
            }
            local _m "`_m' (cluster counts in r(clusters))"
        }
        if `_n_zero' local _m "`_m'; cells with no events show the exact upper limit"
        if `_sc_used' > 0 local _m "`_m'; cells with 1 to `=`_sc_used' - 1' events are shown as <`_sc_used' with their person-time and rate withheld"
        local _m "`_m'."
        return local methods `"`_m'"'
        return local ci_method "`_ci'"
        if "`_clusvar'" != "" {
            return local cluster "`_clusvar'"
            matrix rownames `_clus' = `varlist'
            return matrix clusters = `_clus'
        }
        return scalar N = `_N'
        return scalar per = `per'
        return scalar level = `level'
        return scalar N_zero = `_n_zero'
        return scalar N_noci = `_n_noci'
        return matrix estimates = `_est'
    }
    local rc = _rc
    if `_work_made' capture frame drop `_work'
    foreach _f of local _files {
        capture erase "`_f'.dta"
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
