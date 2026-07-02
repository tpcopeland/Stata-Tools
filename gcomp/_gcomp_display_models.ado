*! _gcomp_display_models Version 1.4.1  2026/07/02
*! In-window display of captured gcomp component models
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

/*
DESCRIPTION:
    Renders the fitted component models captured by gcomp (savemodels). Two
    styles:
      compact (default) - one gcomp-styled coefficient table per model, scale
                          auto-applied (eform for logit/mlogit/ologit).
      native            - replays each model with Stata's own output.

    Reads the stored estimates named in names(). Display only; no returns.
*/

capture program drop _gcomp_display_models
program define _gcomp_display_models, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , NAMES(string) [STYLE(string) DIGITS(integer 4)]
        if "`style'" == "" local style compact
        if `digits' < 0 | `digits' > 12 local digits 4
        local fmt "%9.`digits'f"

        noi di as text _n "   Fitted component models (refit on the analytic sample):"

        foreach _nm of local names {
            capture estimates restore `_nm'
            if _rc {
                noi di as err "   (could not restore stored model `_nm')"
                continue
            }
            local _cmd "`e(cmd)'"
            local _dep "`e(depvar)'"
            local _N   = e(N)

            * Scale label + eform flag per command
            local _eform 0
            if "`_cmd'" == "logit"  {
                local _scale "odds ratios"
                local _esthdr "OR"
                local _eform 1
            }
            else if "`_cmd'" == "mlogit" {
                local _scale "relative risk ratios"
                local _esthdr "RRR"
                local _eform 1
            }
            else if "`_cmd'" == "ologit" {
                local _scale "odds ratios"
                local _esthdr "OR"
                local _eform 1
            }
            else {
                local _scale "coefficients"
                local _esthdr "Coef."
            }

            if "`style'" == "native" {
                noi di as text _n "   Fitted component model: " as result "`_dep'" ///
                    as text "  (`_cmd', `_scale')"
                capture noisily {
                    if "`_cmd'" == "logit"       noisily logit, or
                    else if "`_cmd'" == "mlogit" noisily mlogit, rrr
                    else if "`_cmd'" == "ologit" noisily ologit, or
                    else                         noisily `_cmd'
                }
                if _rc capture noisily estimates replay `_nm'
                continue
            }

            * ----- compact style -----
            tempname b V
            matrix `b' = e(b)
            matrix `V' = e(V)
            local _k = colsof(`b')
            local _cn : colnames `b'
            local _eq : coleq `b'

            noi di as text _n "   Fitted component model: " as result "`_dep'" ///
                as text "  (`_cmd', `_scale')"
            noi di as text "   {hline 64}"
            noi di as text "   " %18s "Term" " {c |}" _col(28) "`_esthdr'" ///
                _col(40) "[95% Conf. Int.]" _col(61) "p"
            noi di as text "   {hline 19}{c +}{hline 44}"

            forvalues j = 1/`_k' {
                local _vn : word `j' of `_cn'
                local _en : word `j' of `_eq'
                * Build a readable term label. Only prefix with the equation name
                * for genuinely multi-equation models (mlogit/ologit); for
                * single-equation models the equation is just the depvar (noise).
                local _lab "`_vn'"
                if "`_en'" != "" & "`_en'" != "_" & "`_en'" != "`_dep'" {
                    local _lab "`_en':`_vn'"
                }
                local _is_cut = (strpos("`_en'", "cut") > 0) | (strpos("`_vn'", "cut") > 0) | ("`_en'" == "/")

                local _bj = `b'[1, `j']
                local _vj = `V'[`j', `j']
                if `_vj' <= 0 | `_vj' >= . {
                    * omitted / collinear term
                    noi di as result "   " %18s abbrev("`_lab'", 18) " {c |}" ///
                        _col(28) "(omitted)"
                    continue
                }
                local _se = sqrt(`_vj')
                local _z  = `_bj' / `_se'
                local _p  = 2 * normal(-abs(`_z'))
                local _lo = `_bj' - 1.959964 * `_se'
                local _hi = `_bj' + 1.959964 * `_se'
                if `_eform' & !`_is_cut' {
                    local _est = exp(`_bj')
                    local _lo  = exp(`_lo')
                    local _hi  = exp(`_hi')
                }
                else {
                    local _est = `_bj'
                }
                local _pstr : display %7.4f `_p'
                if `_p' < 0.0001 local _pstr "<0.0001"
                noi di as result "   " %18s abbrev("`_lab'", 18) " {c |}" ///
                    _col(26) `fmt' `_est' ///
                    _col(39) `fmt' `_lo' _col(51) `fmt' `_hi' ///
                    _col(61) "`_pstr'"
            }
            noi di as text "   {hline 19}{c BT}{hline 44}"
            noi di as text "   N = " as result `_N'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
