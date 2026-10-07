*! outtab Version 2.5.6  2026/10/07
*! Binary outcomes by a binary exposure: events/N (%) per group and one ratio per model
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
SYNTAX
    outtab outcomes [if] [in], EXPosure(varname) [MODels(spec \ spec ...)
        MODELLabels(lab \ lab ...) ESTimator(cmd[, options]) EFORM
        MINEvents(#) MINText(str) SMALLcells(#) NOSMALLcells PANels(varlist)
        OBSprefix(str) GROUPLabels(exposed \ comparator) RATIOLabel(str)
        Format(%fmt) SEP(str) NONCONVtext(str) FAILtext(str)
        frame(name[, replace]) and puttab output options]

One row per outcome (and per panel when panels() names sample indicators).
Each model is fitted with the estimator the user names (default
poisson, irr vce(robust): Zou 2004's modified Poisson); the ratio is read from
r(table) for the exposure and formatted by tabcell, so a failed, non-converged
or non-estimable fit prints text, never ". (., .)". Rows are written by
puttab.
*/

capture program drop outtab
program define outtab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname _stage _res _hold
    local _stage_made 0
    local _held 0
    capture noisily {
        syntax varlist(numeric min=1) [if] [in] , EXPosure(varname numeric) ///
            [MODels(string asis) MODELLabels(string asis) ESTimator(string asis) EFORM ///
            MINEvents(integer 0) MINText(string asis) SMALLcells(integer -1) NOSMALLcells ///
            PANels(varlist numeric) OBSprefix(name) GROUPLabels(string asis) ///
            RATIOLabel(string) Format(string) SEP(string) ///
            NONCONVtext(string asis) FAILtext(string asis) DROPtext(string asis) FRAme(string) ///
            XLSX(string) EXCEL(string) SHeet(string) TItle(string) FOOTnote(string) ///
            CSV(string) MARKdown(string) MDAPPend BORDERstyle(string) HEADERShade ///
            FONT(string) FONTSIZE(integer -1)]

        **# Options
        if `"`excel'"' != "" & `"`xlsx'"' == "" local xlsx `"`excel'"'
        if `minevents' < 0 {
            display as error "minevents() must be a nonnegative integer"
            exit 198
        }
        if `smallcells' != -1 & "`nosmallcells'" != "" {
            display as error "smallcells() and nosmallcells may not be combined"
            exit 198
        }
        if `smallcells' == -1 & "`nosmallcells'" == "" & `"$TABTOOLS_set_smallcells"' != "" {
            capture confirm integer number $TABTOOLS_set_smallcells
            if _rc | real(`"$TABTOOLS_set_smallcells"') < 0 {
                display as error `"session smallcells default "$TABTOOLS_set_smallcells" is not a nonnegative integer"'
                exit 198
            }
            local smallcells = $TABTOOLS_set_smallcells
            display as text "(tabtools: using session smallcells `smallcells')"
        }
        if `smallcells' == -1 local smallcells 0
        if `smallcells' < 0 {
            display as error "smallcells() must be a nonnegative integer"
            exit 198
        }
        if `"`format'"' == "" local format "%4.2f"
        * sep() is data (help tabtools##sep): read and written in Mata only,
        * never re-expanded; _sep_opt hands it to tabcell unchanged
        mata: st_local("sep", st_local("sep") == "" ? ", " : st_local("sep"))
        mata: st_local("_sep_opt", "sep(" + (strpos(st_local("sep"), char(34)) ? char(96) + char(34) + st_local("sep") + char(34) + char(39) : char(34) + st_local("sep") + char(34)) + ")")
        * a decimal-comma format() with a comma in sep(): a warning, as before
        * printed (regtab and effecttab refuse it)
        mata: st_local("_sep_comma", strofreal(strpos(st_local("sep"), ",") > 0))
        if `_sep_comma' & ustrregexm(`"`format'"', "^%-?0?[0-9]*,") {
            display as text "(outtab: format(`format') writes a decimal comma and the interval separator holds a comma: the two limits are hard to tell apart (help tabtools##sep))"
        }
        if `"`ratiolabel'"' == "" local ratiolabel "RR"
        capture confirm numeric format `format'
        if _rc | regexm(`"`format'"', "^%-?t") {
            display as error `"format(): "`format'" is not a numeric display format"'
            exit 198
        }
        foreach _t in mintext nonconvtext failtext droptext {
            local _has_`_t' = (`"`macval(`_t')'"' != "")
            if `_has_`_t'' {
                gettoken _a _b : `_t', qed(_q)
                if `_q' & strtrim(`"`macval(_b)'"') == "" local `_t' `"`macval(_a)'"'
            }
        }
        if !`_has_mintext' local mintext "–"
        if !`_has_nonconvtext' local nonconvtext "did not converge"
        if !`_has_failtext' local failtext "failed, r(#)"
        if !`_has_droptext' local droptext "not estimable (sample reduced)"

        **# Estimator: command and options
        if `"`estimator'"' == "" local estimator "poisson, irr vce(robust)"
        gettoken _ecmd _eopt : estimator, parse(",")
        local _ecmd = strtrim(`"`_ecmd'"')
        local _eopt = strtrim(subinstr(`"`_eopt'"', ",", "", 1))
        capture which `_ecmd'
        if _rc | `"`_ecmd'"' == "" {
            display as error `"estimator(): "`_ecmd'" is not a command"'
            exit 199
        }
        * the interval level is the estimator's: its level() option or c(level)
        local level = c(level)
        if regexm(`"`_eopt'"', "(^| )le?v?e?l?\(([0-9.]+)\)") local level = real(regexs(2))

        **# Model specifications (\ separated; "" is the crude model)
        local _K 0
        if `"`models'"' == "" local models `""""'
        local _rest `"`models'"'
        while `"`macval(_rest)'"' != "" {
            gettoken _m _rest : _rest, parse("\") qed(_mq)
            if `"`macval(_m)'"' == "\" & !`_mq' continue
            local ++_K
            local _spec`_K' = strtrim(`"`_m'"')
            if `"`_spec`_K''"' != "" {
                capture fvunab _tmp : `_spec`_K''
                if _rc {
                    display as error `"models(): "`_spec`_K''" is not a list of covariates"'
                    exit 111
                }
            }
        }
        if `_K' == 0 {
            display as error "models() is empty"
            exit 198
        }
        local _nl 0
        if `"`modellabels'"' != "" {
            local _rest `"`macval(modellabels)'"'
            while `"`macval(_rest)'"' != "" {
                gettoken _m _rest : _rest, parse("\") qed(_mq)
                if `"`macval(_m)'"' == "\" & !`_mq' continue
                local ++_nl
                local _mlab`_nl' = strtrim(`"`macval(_m)'"')
            }
            if `_nl' != `_K' {
                display as error "modellabels() needs `_K' labels separated by \"
                exit 198
            }
        }
        else {
            forvalues _k = 1/`_K' {
                local _mlab`_k' = cond(`_K' == 1 & `"`_spec1'"' == "", "Crude", "Model `_k'")
            }
        }

        **# Group labels: exposed (1) first, then comparator (0)
        if `"`grouplabels'"' != "" {
            local _rest `"`macval(grouplabels)'"'
            local _ng 0
            while `"`macval(_rest)'"' != "" {
                gettoken _m _rest : _rest, parse("\") qed(_mq)
                if `"`macval(_m)'"' == "\" & !`_mq' continue
                local ++_ng
                local _glab`_ng' = strtrim(`"`macval(_m)'"')
            }
            if `_ng' != 2 {
                display as error "grouplabels() needs two labels: exposed \ comparator"
                exit 198
            }
        }
        else {
            local _vl : value label `exposure'
            forvalues _g = 1/2 {
                local _code = 2 - `_g'
                * extended function, not cond(): an inline label lookup is
                * rescanned, so "$name" in a value label was expanded away
                if "`_vl'" != "" local _glab`_g' : label (`exposure') `_code'
                else local _glab`_g' "`exposure' = `_code'"
            }
        }

        **# Sample checks
        marksample touse, novarlist
        markout `touse' `exposure'
        quietly count if `touse'
        if r(N) == 0 {
            display as error "no observations"
            exit 2000
        }
        quietly count if `touse' & !inlist(`exposure', 0, 1)
        if r(N) {
            display as error "exposure() must be coded 0/1; `r(N)' observation(s) are not"
            exit 459
        }
        foreach _y of local varlist {
            quietly count if `touse' & !missing(`_y') & !inlist(`_y', 0, 1)
            if r(N) {
                display as error "outcome `_y' must be coded 0/1; `r(N)' observation(s) are not"
                exit 459
            }
            if "`obsprefix'" != "" {
                capture confirm numeric variable `obsprefix'`_y', exact
                if _rc {
                    display as error "obsprefix(): variable `obsprefix'`_y' not found"
                    exit 111
                }
            }
        }
        local _npan 1
        if "`panels'" != "" {
            local _npan : word count `panels'
            foreach _p of local panels {
                quietly count if `touse' & !missing(`_p') & !inlist(`_p', 0, 1)
                if r(N) {
                    display as error "panel indicator `_p' must be coded 0/1"
                    exit 459
                }
            }
        }
        local _ny : word count `varlist'

        **# Fit and format, one row per panel x outcome
        local _ncol = 2 + `_K'
        frame create `_stage' strL rowlabel
        local _stage_made 1
        forvalues _c = 1/`_ncol' {
            frame `_stage': quietly gen strL c`_c' = ""
        }
        local _row 0
        local _head_rows ""
        local _nres = `_npan' * `_ny'
        matrix `_res' = J(`_nres', 4 + 4 * `_K', .)
        * per fit: table row, model, e(N), complete-case N, e(N_clust),
        * e(df_m), e(converged), code
        tempname _fits
        matrix `_fits' = J(`_nres' * `_K', 8, .)
        tempvar _cc
        local _ri 0
        tempvar _s
        quietly gen byte `_s' = 0
        _estimates hold `_hold', nullok
        local _held 1
        forvalues _pi = 1/`_npan' {
            local _pv ""
            if "`panels'" != "" {
                local _pv : word `_pi' of `panels'
                local _plab : variable label `_pv'
                if `"`_plab'"' == "" local _plab "`_pv'"
                local ++_row
                frame `_stage': quietly set obs `_row'
                frame `_stage': mata: st_sstore(`_row', "rowlabel", st_local("_plab"))
                local _head_rows "`_head_rows' `_row'"
            }
            foreach _y of local varlist {
                local ++_ri
                quietly replace `_s' = `touse' & !missing(`_y')
                if "`_pv'" != "" quietly replace `_s' = `_s' & `_pv' == 1
                if "`obsprefix'" != "" quietly replace `_s' = `_s' & `obsprefix'`_y' == 1
                quietly count if `_s' & `exposure' == 1
                local n1 = r(N)
                quietly count if `_s' & `exposure' == 1 & `_y' == 1
                local e1 = r(N)
                quietly count if `_s' & `exposure' == 0
                local n0 = r(N)
                quietly count if `_s' & `exposure' == 0 & `_y' == 1
                local e0 = r(N)
                matrix `_res'[`_ri', 1] = (`n1', `e1', `n0', `e0')
                local _ylab : variable label `_y'
                if `"`_ylab'"' == "" local _ylab "`_y'"
                if "`panels'" != "" local _ylab `"   `_ylab'"'
                local ++_row
                frame `_stage': quietly set obs `_row'
                frame `_stage': mata: st_sstore(`_row', "rowlabel", st_local("_ylab"))
                quietly tabcell enp, e(`e1') n(`n1') mincell(`smallcells')
                local _t1 `"`r(cell)'"'
                quietly tabcell enp, e(`e0') n(`n0') mincell(`smallcells')
                local _t0 `"`r(cell)'"'
                frame `_stage': mata: st_sstore(`_row', "c1", st_local("_t1"))
                frame `_stage': mata: st_sstore(`_row', "c2", st_local("_t0"))
                local _masked = `smallcells' > 0 & ((`e1' >= 1 & `e1' < `smallcells') | ///
                    (`e0' >= 1 & `e0' < `smallcells') | (`n1' >= 1 & `n1' < `smallcells') | ///
                    (`n0' >= 1 & `n0' < `smallcells'))
                forvalues _k = 1/`_K' {
                    local _col = 2 + `_k'
                    local _cellk ""
                    local _fe1 1
                    local _fe0 1
                    local _has_rt 1
                    if `e1' < `minevents' {
                        local _cellk `"`mintext'"'
                        local _frc = -1
                    }
                    else {
                        * the model's complete-case sample: the analysis rows with
                        * every covariate of this model observed, i.e. what the
                        * estimator receives before its own drops
                        capture drop `_cc'
                        quietly gen byte `_cc' = `_s'
                        if `"`_spec`_k''"' != "" {
                            fvrevar `_spec`_k'', list
                            markout `_cc' `r(varlist)'
                        }
                        quietly count if `_cc'
                        local _ncc = r(N)
                        local _fi = (`_ri' - 1) * `_K' + `_k'
                        matrix `_fits'[`_fi', 4] = `_ncc'
                        capture quietly `_ecmd' `_y' `exposure' `_spec`_k'' if `_s', `_eopt'
                        local _frc = _rc
                        if (`_frc' == 0) & !missing(e(converged)) & e(converged) != 1 local _frc = 430
                        if (`_frc' == 0) | `_frc' == 430 {
                            matrix `_fits'[`_fi', 3] = e(N)
                            matrix `_fits'[`_fi', 5] = (e(N_clust), e(df_m), e(converged))
                        }
                        * the estimator dropped complete-case rows (perfect
                        * prediction and the like): its ratio describes a
                        * sample other than the one the model was given
                        if (`_frc' == 0) & e(N) < `_ncc' local _frc = -2
                        if `_frc' == 430 local _cellk `"`nonconvtext'"'
                        else if `_frc' == -2 local _cellk `"`droptext'"'
                        else if `_frc' {
                            local _cellk = subinstr(`"`failtext'"', "#", "`_frc'", .)
                        }
                        else {
                            * r(table) is copied before any r-class call below
                            tempname _rt
                            capture matrix `_rt' = r(table)
                            local _has_rt = !_rc
                            * eform on top of a ratio the estimator already
                            * reports (irr, or, eform) would exponentiate twice
                            if "`eform'" != "" & `_has_rt' {
                                local _jx = colnumb(`_rt', "`exposure'")
                                * stata-dev-ignore: omitted-coef-display — _bx is only compared with r(table) to refuse a doubled eform, never displayed or exported; an omitted exposure prints not estimable (459) through the tabcell est matrix() branch below
                                capture local _bx = _b[`exposure']
                                if !_rc & !missing(`_jx') {
                                    if reldif(el(`_rt', 1, `_jx'), exp(`_bx')) < 1e-8 {
                                        display as error "outtab: eform given, but estimator(`_ecmd', `_eopt') already reports the exponentiated coefficient; drop eform or the estimator's ratio option"
                                        exit 198
                                    }
                                }
                            }
                            * a group with no events in the fitted sample has a
                            * boundary estimate (b -> -/+ infinity): never a ratio
                            quietly count if e(sample) & `exposure' == 1 & `_y' == 1
                            local _fe1 = r(N)
                            quietly count if e(sample) & `exposure' == 0 & `_y' == 1
                            local _fe0 = r(N)
                        }
                        if (`_frc' == 0) & (`_fe1' == 0 | `_fe0' == 0 | !`_has_rt') {
                            local _cellk "not estimable"
                            local _frc = 459
                        }
                        else if (`_frc' == 0) {
                            capture quietly tabcell est, matrix(`_rt'' `exposure') ///
                                format(`format') `macval(_sep_opt)' `eform'
                            if _rc == 459 | _rc == 111 {
                                local _cellk "not estimable"
                                local _frc = 459
                            }
                            else if _rc {
                                local _trc = _rc
                                display as error "outtab: formatting the `_y' ratio failed (r(`_trc'))"
                                exit `_trc'
                            }
                            else {
                                * the cell as tabcell printed it, copied in Mata
                                mata: st_local("_cellk", st_global("r(cell)"))
                                matrix `_res'[`_ri', 4 + (`_k' - 1) * 4 + 1] = (r(estimate), r(lb), r(ub))
                            }
                        }
                    }
                    matrix `_res'[`_ri', 4 + `_k' * 4] = `_frc'
                    matrix `_fits'[(`_ri' - 1) * `_K' + `_k', 1] = (`_ri', `_k')
                    matrix `_fits'[(`_ri' - 1) * `_K' + `_k', 8] = `_frc'
                    if `_masked' local _cellk ""
                    frame `_stage': mata: st_sstore(`_row', "c`_col'", st_local("_cellk"))
                }
            }
        }
        _estimates unhold `_hold'
        local _held 0

        **# Column labels and names
        local _cn "n1 e1 n0 e0"
        forvalues _k = 1/`_K' {
            local _cn "`_cn' b`_k' lb`_k' ub`_k' rc`_k'"
        }
        matrix colnames `_res' = `_cn'
        frame `_stage' {
            mata: st_varlabel("c1", st_local("_glab1") + ", events/N (%)")
            mata: st_varlabel("c2", st_local("_glab2") + ", events/N (%)")
            forvalues _k = 1/`_K' {
                local _lab `"`macval(_mlab`_k')', `macval(ratiolabel)' (`=strtrim(string(`level', "%9.0g"))'% CI)"'
                mata: st_varlabel("c`=2 + `_k''", st_local("_lab"))
            }
            mata: st_varlabel("rowlabel", " ")
            quietly compress
            char _dta[tabtools_source] "outtab"
            char _dta[tabtools_layout] "flat"
            * Console preview: the column labels as a header row, since
            * list shows variable names (c1, c2, ...) otherwise
            preserve
            quietly {
                set obs `=_N + 1'
                tempvar _ord _hd
                generate long `_ord' = cond(_n == _N, 0, _n)
                sort `_ord'
                generate byte `_hd' = _n == 1
                foreach _v of varlist c* {
                    local _vl : variable label `_v'
                    replace `_v' = `"`macval(_vl)'"' in 1
                }
            }
            * The 2.4.0 layout (string(40)) unless a data cell is longer:
            * then wide enough that no result (a long sep() among it) is
            * cut to "..". The header row (obs 1) does not widen it.
            local _cw 40
            foreach _v of varlist c* {
                mata: st_local("_cw", strofreal(max((strtoreal(st_local("_cw")), (st_nobs() >= 2 ? max(udstrlen(st_sdata(2::st_nobs(), st_local("_v")))) : 0)))))
            }
            noisily list rowlabel c*, noobs noheader table sepby(`_hd') string(`_cw')
            restore
        }

        **# Sinks through puttab
        local _put_opts ""
        if `"`macval(title)'"' != "" local _put_opts `"`_put_opts' title(`"`macval(title)'"')"'
        if `"`macval(footnote)'"' != "" local _put_opts `"`_put_opts' footnote(`"`macval(footnote)'"')"'
        if `"`sheet'"' != "" local _put_opts `"`_put_opts' sheet(`"`sheet'"')"'
        if `"`csv'"' != "" local _put_opts `"`_put_opts' csv(`"`csv'"')"'
        if `"`markdown'"' != "" local _put_opts `"`_put_opts' markdown(`"`markdown'"')"'
        if "`mdappend'" != "" local _put_opts `"`_put_opts' mdappend"'
        if `"`borderstyle'"' != "" local _put_opts `"`_put_opts' borderstyle(`borderstyle')"'
        if "`headershade'" != "" local _put_opts `"`_put_opts' headershade"'
        if `"`font'"' != "" local _put_opts `"`_put_opts' font(`"`font'"')"'
        if `fontsize' != -1 local _put_opts `"`_put_opts' fontsize(`fontsize')"'
        local _head_rows : list clean _head_rows
        if "`_head_rows'" != "" {
            * puttab counts the header row: body row i is sheet row i + 1
            local _bold ""
            foreach _h of local _head_rows {
                local _bold "`_bold' `=`_h' + 1'"
            }
            local _put_opts `"`_put_opts' boldrows(`_bold')"'
        }
        if `"`xlsx'"' != "" | `"`csv'"' != "" | `"`markdown'"' != "" {
            local _using ""
            if `"`xlsx'"' != "" local _using `"using `"`xlsx'"'"'
            capture noisily puttab rowlabel c* `_using', frame(`_stage') varlabels `macval(_put_opts)'
            if _rc {
                local _prc = _rc
                display as error "outtab: writing the table failed"
                exit `_prc'
            }
        }

        **# frame(): committed last
        if `"`frame'"' != "" {
            gettoken _fname _fopt : frame, parse(",")
            local _fname = strtrim("`_fname'")
            local _fopt = strtrim(subinstr("`_fopt'", ",", "", 1))
            capture confirm name `_fname'
            if _rc | !inlist("`_fopt'", "", "replace") {
                display as error "frame() must be name[, replace]"
                exit 198
            }
            capture confirm frame `_fname'
            if !_rc & "`_fopt'" != "replace" {
                display as error "frame `_fname' already exists; specify frame(`_fname', replace)"
                exit 110
            }
            if !_rc frame drop `_fname'
            frame rename `_stage' `_fname'
            local _stage_made 0
            return local frame "`_fname'"
        }

        return matrix table = `_res'
        matrix colnames `_fits' = row model N N_cc N_clust df_m converged rc
        return matrix fits = `_fits'
        return scalar N_rows = `_row'
        return scalar N_models = `_K'
        return scalar N_outcomes = `_ny'
        return scalar N_panels = `_npan'
        return scalar smallcells = `smallcells'
        return scalar minevents = `minevents'
        return local estimator `"`_ecmd', `_eopt'"'
        if `"`xlsx'"' != "" return local xlsx `"`xlsx'"'
    }
    local rc = _rc
    if `_held' capture _estimates unhold `_hold'
    if `_stage_made' capture frame drop `_stage'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
