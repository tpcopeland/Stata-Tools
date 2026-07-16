*! _finegray_check_data Version 1.2.0  2026/07/16
*! Verify that post-estimation commands still see the finegray estimation data
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: internal

capture program drop _finegray_check_data
program define _finegray_check_data
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        if `"`_dta[_finegray_estimated]'"' != "1" {
            display as error "finegray estimation state is not active"
            display as error "re-run {bf:finegray} before this post-estimation command"
            exit 301
        }

        local _sig `"`e(datasignature)'"'
        local _sigvars `"`e(datasignaturevars)'"'
        if `"`_sig'"' == "" | `"`_sigvars'"' == "" {
            display as error "finegray estimation signature is not available"
            display as error "re-run {bf:finegray} before this post-estimation command"
            exit 301
        }

        foreach _v of local _sigvars {
            capture confirm numeric variable `_v'
            if _rc {
                display as error "estimation variable `_v' is missing or has changed type"
                display as error "re-run {bf:finegray} before this post-estimation command"
                exit 459
            }
        }

        capture quietly _datasignature `_sigvars' if e(sample), nodefault nonames
        if _rc | `"`r(datasignature)'"' != `"`_sig'"' {
            display as error "data have changed since finegray was estimated"
            display as error "re-run {bf:finegray} before this post-estimation command"
            exit 459
        }

        * The package-owned _fg_* design columns are DERIVED from the raw factor
        * variables, so they are not in the data signature: dropping them is
        * supported, and the consumers that need them rebuild them on demand.
        * But a _fg_ column that is still present and no longer equals what the
        * fit-time expansion implies is tampering, and it is invisible to a
        * signature over the raw variables -- finegray_cif and finegray_phtest
        * read these columns by name, so flipping _fg_grp_2 silently moved the
        * CIF from 0.21287138 to 0.21088124 at rc 0.
        *
        * e(fvsemantic) lists the fit-time terms in order and e(covariates) the
        * columns they were stored in, so the two pair up positionally HERE --
        * both were written by the same fit, which is what makes it safe (the
        * defect this guards was pairing against the *current* data instead).
        local _fvsem `"`e(fvsemantic)'"'
        if `"`_fvsem'"' != "" {
            local _nb_terms ""
            foreach _t of local _fvsem {
                if regexm("`_t'", "[0-9]+b\.") continue
                local _nb_terms "`_nb_terms' `_t'"
            }
            local _covcols "`e(covariates)'"
            local _n_nb : word count `_nb_terms'
            local _n_cc : word count `_covcols'
            if `_n_nb' != `_n_cc' {
                display as error "internal error: e(fvsemantic) and e(covariates) disagree"
                exit 198
            }

            forvalues _k = 1/`_n_nb' {
                local _term : word `_k' of `_nb_terms'
                local _col  : word `_k' of `_covcols'
                * A dropped column is fine -- it gets rebuilt downstream.
                capture confirm numeric variable `_col'
                if _rc continue

                tempvar _want
                quietly gen double `_want' = 1 if e(sample)
                local _parts = subinstr(subinstr("`_term'", "##", "#", .), "#", " ", .)
                local _bad = 0
                foreach _p of local _parts {
                    if regexm("`_p'", "^([0-9]+)\.(.+)$") {
                        local _lv = regexs(1)
                        local _vr = regexs(2)
                        capture confirm numeric variable `_vr'
                        if _rc {
                            local _bad = 1
                            continue, break
                        }
                        quietly replace `_want' = `_want' * (`_vr' == `_lv') ///
                            if e(sample)
                    }
                    else {
                        local _vr = subinstr("`_p'", "c.", "", .)
                        capture confirm numeric variable `_vr'
                        if _rc {
                            local _bad = 1
                            continue, break
                        }
                        quietly replace `_want' = `_want' * `_vr' if e(sample)
                    }
                }
                if `_bad' {
                    drop `_want'
                    continue
                }

                quietly count if e(sample) & ///
                    (abs(`_col' - `_want') > 1e-9 | ///
                     missing(`_col') != missing(`_want'))
                local _ndiff = r(N)
                drop `_want'
                if `_ndiff' > 0 {
                    display as error "design column `_col' (`_term') has been modified since estimation"
                    display as error "`_ndiff' observation(s) no longer match the fitted factor term"
                    display as error "re-run {bf:finegray} before this post-estimation command"
                    exit 459
                }
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
