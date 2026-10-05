*! _regtab_remeta Version 2.4.0  2026/10/05
*! regtab block: random-effects, factor, and equation labels before rendering
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_remeta" from inside its quietly block and the body is quietly
* again, so only the block's own noisily lines print. Data in memory, frames,
* and the collection are shared state and need no transport.
program define _regtab_remeta, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
    * =========================================================================
    * STORE RANDOM EFFECTS LABELS BEFORE COLLECT EXPORT (for relabel option)
    * =========================================================================
    local re_groupvar = ""
    local re_grouplbl = ""
    local re_vars = ""
    local _n_re_levels = 0
    local _is_multilevel = 0

    * Random-effects labels must use metadata stored with the collection.  A
    * later estimation command may have replaced every active e() field.
    local re_groupvars = ""
    local _re_redim = ""
    local _re_meta_ambiguous = 0
    if `_meta_models' > 0 {
        forvalues m = 1/`_meta_models' {
            if `"`model_ivars_`m''"' != "" & `"`model_ivars_`m''"' != "." {
                if "`re_groupvars'" == "" {
                    local re_groupvars `"`model_ivars_`m''"'
                    local re_vars `"`model_revars_`m''"'
                    local _re_redim `"`model_redim_`m''"'
                }
                else if `"`model_ivars_`m''"' != `"`re_groupvars'"' | ///
                    `"`model_revars_`m''"' != `"`re_vars'"' | ///
                    `"`model_redim_`m''"' != `"`_re_redim'"' {
                    local _re_meta_ambiguous = 1
                }
            }
        }
    }
    if `_re_meta_ambiguous' {
        * A shared relabel cannot represent different grouping structures.
        * Keep the original collection labels unless relabel was requested.
        if "`relabel'" != "" & "`noreeffects'" == "" {
            noisily display as error ///
                "Random-effects metadata differ across collected models"
            noisily display as error ///
                "Use separate regtab calls, or omit relabel"
            exit 459
        }
        local re_groupvars ""
        local re_vars ""
        local _re_redim ""
    }
    * Check for empty string AND "." (missing value returned by OLS models)
    if "`re_groupvars'" != "" & "`re_groupvars'" != "." {
        local _n_re_levels : word count `re_groupvars'
        local _is_multilevel = (`_n_re_levels' > 1)
        local _path_so_far ""

        * Store label for each grouping variable
        forvalues _lev = 1/`_n_re_levels' {
            local _gvar : word `_lev' of `re_groupvars'
            local re_groupvar_`_lev' `"`_gvar'"'
            if "`_path_so_far'" == "" local _path_so_far "`_gvar'"
            else local _path_so_far "`_path_so_far'>`_gvar'"
            local re_grouppath_`_lev' `"`_path_so_far'"'
            local _glbl ""
            * C1 (codex audit 2026-09-26): labels are data. Every copy,
            * test and write of a label below is macval()/Mata protected, so a
            * $word or a backtick in a label is never expanded.
            capture local _glbl : variable label `_gvar'
            if `"`macval(_glbl)'"' == "" local _glbl "`_gvar'"
            local re_grouplbl_`_lev' : copy local _glbl
        }

        * Detect duplicate labels: if two levels share a label, fall back to
        * variable names so relabeled output is unambiguous
        if `_n_re_levels' > 1 {
            * First pass: flag which levels have duplicate labels
            forvalues _lev = 1/`_n_re_levels' {
                local _lbl_is_dup_`_lev' = 0
                forvalues _other = 1/`_n_re_levels' {
                    mata: st_local("_same", strofreal(st_local("re_grouplbl_`_other'") == st_local("re_grouplbl_`_lev'")))
                    if `_other' != `_lev' & `_same' {
                        local _lbl_is_dup_`_lev' = 1
                    }
                }
            }
            * Second pass: apply fallback for flagged levels
            forvalues _lev = 1/`_n_re_levels' {
                if `_lbl_is_dup_`_lev'' {
                    local re_grouplbl_`_lev' : copy local re_groupvar_`_lev'
                }
            }
        }

        * Backward compat: single-level vars from first grouping variable
        local re_groupvar : word 1 of `re_groupvars'
        local re_grouplbl : copy local re_grouplbl_1

        if "`re_vars'" != "" {
            * Store labels for each random effect variable
            foreach revar of local re_vars {
                if "`revar'" == "_cons" {
                    local lbl_`revar' "Intercept"
                }
                else {
                    capture local lbl_`revar' : variable label `revar'
                    if `"`macval(lbl_`revar')'"' == "" local lbl_`revar' "`revar'"
                }
            }

            * Parse per-level random effects using collected redim metadata.
            if "`_re_redim'" != "" {
                local _re_pos = 1
                forvalues _lev = 1/`_n_re_levels' {
                    local _dim : word `_lev' of `_re_redim'
                    local re_vars_`_lev' = ""
                    forvalues _d = 1/`_dim' {
                        local _rv : word `_re_pos' of `re_vars'
                        local re_vars_`_lev' `"`re_vars_`_lev'' `_rv'"'
                        local _re_pos = `_re_pos' + 1
                    }
                    local re_vars_`_lev' = strtrim("`re_vars_`_lev''")
                }
            }
            else {
                * Assign all revars to level 1 when collected redim is unavailable.
                local re_vars_1 `"`re_vars'"'
                forvalues _lev = 2/`_n_re_levels' {
                    local re_vars_`_lev' ""
                }
            }
        }
    }

    * Labels of every variable named inside a collected random-effects key
    * (var(x[g]), cov(x[g],_cons[g]), sd(x)). The me* estimators record no
    * e(revars) in the collection, and relabel runs on the rendered string
    * data, where the model's variables no longer exist; read them now.
    local _rel_n = 0
    if "`relabel'" != "" {
        capture quietly collect levelsof colname
        if _rc == 0 {
            local _rel_levels `"`s(levels)'"'
            foreach _rk of local _rel_levels {
                if !ustrregexm(`"`_rk'"', "^(var|sd|cov)\(") continue
                local _rk_in = ustrregexra(`"`_rk'"', "^(var|sd|cov)\(|\)$|\[[^\]]*\]", "")
                local _rk_in = subinstr(`"`_rk_in'"', ",", " ", .)
                foreach _rn of local _rk_in {
                    if inlist("`_rn'", "_cons", "e") continue
                    if strtoname("`_rn'") != "`_rn'" continue
                    local _rel_seen = 0
                    forvalues _rli = 1/`_rel_n' {
                        if "`_rel_nm_`_rli''" == "`_rn'" local _rel_seen = 1
                    }
                    if `_rel_seen' continue
                    capture confirm variable `_rn', exact
                    if _rc continue
                    local ++_rel_n
                    local _rel_nm_`_rel_n' "`_rn'"
                    local _rel_lb_`_rel_n' : variable label `_rn'
                    if `"`macval(_rel_lb_`_rel_n')'"' == "" local _rel_lb_`_rel_n' "`_rn'"
                }
            }
        }
    }

    * Capture factor variable value labels for factorlabel option
    if "`factorlabel'" != "" {
        local _fvlabel_cmds ""
        local _fvlc_n = 0
        local _fv_varlist ""
        capture quietly collect levelsof colname
        if _rc == 0 local _fv_varlist `"`s(levels)'"'
        if "`_fv_varlist'" != "" {
            foreach _fvterm of local _fv_varlist {
                if regexm("`_fvterm'", "^([0-9]+)\.(.+)$") {
                    local _fvval = regexs(1)
                    local _fvvar = regexs(2)
                    * Remove interaction prefix if present (e.g., c.var#1.var2)
                    if strpos("`_fvvar'", "#") > 0 continue
                    local _fvlbl ""
                    capture local _fvlbl : label (`_fvvar') `_fvval'
                    if !_rc {
                        mata: st_local("_same", strofreal(st_local("_fvlbl") == st_local("_fvval")))
                        if `"`macval(_fvlbl)'"' != "" & !`_same' {
                            * Indexed, not packed into one list: a label is
                            * never split on its spaces or expanded.
                            local ++_fvlc_n
                            local _fvlc_pat_`_fvlc_n' "`_fvval'.`_fvvar'"
                            local _fvlc_lab_`_fvlc_n' : copy local _fvlbl
                            local _fvlabel_cmds "set"
                        }
                    }
                }
            }
        }
    }

    * collect export renders factor-variable children using value labels under
    * their parent row. The raw .stjson items only carry levels like 2.agecat,
    * so capture the same display labels before preserve switches to the
    * rendered string dataset.
    local _fvrow_label_n = 0
    local _fvrow_parent_n = 0
    capture quietly collect levelsof colname
    if _rc == 0 {
        local _fv_collevels `s(levels)'
        foreach _fvterm of local _fv_collevels {
            if regexm("`_fvterm'", "^([0-9]+)\.(.+)$") {
                local _fvval = regexs(1)
                local _fvvar = regexs(2)
                if strpos("`_fvvar'", "#") > 0 continue
                capture confirm variable `_fvvar'
                if _rc == 0 {
                    local _fvrow_parent_seen = 0
                    if `_fvrow_parent_n' > 0 {
                        forvalues _fvp = 1/`_fvrow_parent_n' {
                            if `"`_fvrow_parent_var_`_fvp''"' == `"`_fvvar'"' {
                                local _fvrow_parent_seen = 1
                            }
                        }
                    }
                    if !`_fvrow_parent_seen' {
                        local _fvplbl : variable label `_fvvar'
                        if `"`macval(_fvplbl)'"' == "" local _fvplbl `"`_fvvar'"'
                        local ++_fvrow_parent_n
                        local _fvrow_parent_var_`_fvrow_parent_n' `"`_fvvar'"'
                        local _fvrow_parent_lab_`_fvrow_parent_n' : copy local _fvplbl
                    }
                    local _fvlbl `"`_fvval'"'
                    capture local _fvlbl : label (`_fvvar') `_fvval'
                    if `"`macval(_fvlbl)'"' == "" local _fvlbl "`_fvval'"
                    local ++_fvrow_label_n
                    local _fvrow_pat_`_fvrow_label_n' `"`_fvterm'"'
                    local _fvrow_lab_`_fvrow_label_n' `"  `macval(_fvlbl)'"'
                }
            }
        }
    }

    * Multi-equation estimators (for example mlogit, zip, zinb, churdle)
    * need coleq#colname rows; colname alone collapses outcome/equation-specific
    * coefficients that share the same term name.
    local _is_multieq = 0
    local _use_coleq_layout = `_is_multilevel'
    local _coleq_label_n = 0
    capture quietly collect levelsof coleq
    if _rc == 0 {
        local _coleq_levels `"`s(levels)'"'
        local _coleq_n : word count `_coleq_levels'
        if `_coleq_n' > 1 & ("`re_groupvars'" == "" | "`re_groupvars'" == ".") ///
            & `_has_multieq_estimator' {
            local _is_multieq = 1
            local _use_coleq_layout = 1
        }

        * If the dependent variable has value labels, map equation names such
        * as Partial_response or 2 back to reader-facing outcome labels.
        local _depvar ""
        local _dep_label ""
        * Outcome labels belong to the collected model. Ambient e() may
        * describe a later fit, so use an unambiguous collected identity.
        if `_meta_models' > 0 {
            local _depvar `"`model_depvar_1'"'
            forvalues _m = 2/`_meta_models' {
                if `"`model_depvar_`_m''"' != `"`_depvar'"' local _depvar ""
            }
        }
        if "`_depvar'" != "" {
            capture local _dep_label : variable label `_depvar'
            local _dep_label_rc = _rc
            local _dep_vallab ""
            capture local _dep_vallab : value label `_depvar'
            local _dep_vallab_rc = _rc
            if "`_dep_vallab'" != "" {
                capture levelsof `_depvar', local(_dep_levels_for_eq)
                local _dep_levels_rc = _rc
                if `_dep_levels_rc' == 0 {
                    foreach _dlev of local _dep_levels_for_eq {
                        local _dlbl ""
                        capture local _dlbl : label `_dep_vallab' `_dlev'
                        if `"`macval(_dlbl)'"' != "" {
                            local ++_coleq_label_n
                            local _coleq_key_`_coleq_label_n' `"`_dlev'"'
                            mata: st_local("_coleq_key2_`_coleq_label_n'", strtoname(st_local("_dlbl")))
                            local _coleq_lab_`_coleq_label_n' : copy local _dlbl
                        }
                    }
                }
            }
        }
    }
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end
