*! _regtab_statrows Version 2.5.3  2026/10/06
*! regtab block: model statistics rows below the table body (stats())
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_statrows" from inside its quietly block and the body is quietly
* again, so only the block's own noisily lines print. Data in memory, frames,
* and the collection are shared state and need no transport.
program define _regtab_statrows, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
*
* =========================================================================
* ADD MODEL STATISTICS ROWS (if requested)
* =========================================================================
local stats_start_row = 0
local stats_rows = ""
* stats_row_ids: one id per stats_rows entry, in the same order, for
* frame(, flat keys) (_term "stat:<id>"): the built-in word (n for
* n/n_sub/subjects, aic also when the row shows QICu, F), e(name) or
* e(name1|name2) for a generic item as typed without options or label, and
* text(#) for the #th text() item. Built-in words hold no parenthesis and
* generic e() items are unique, so no two rows share an id.
local stats_row_ids ""
if `add_stats' == 1 {
    local stats_start_row = _N + 1
    local use_models = min(`n_stat_models', `n_models')

    * F statistic only for linear-model F tests (regress/anova type); a
    * svy: logit also stores e(F), which is not that statistic.
    forvalues m = 1/`use_models' {
        if `want_F' {
            local _fcmd ""
            if `m' <= `_meta_models' local _fcmd "`model_cmdword_`m''"
            if !inlist("`_fcmd'", "regress", "anova", "areg", "xtreg", "ivregress", "cnsreg") {
                local stat_F_`m' = .
            }
        }
    }
    local _nr_lab_obs "Observations"
    local _nr_fmt_obs "%12.0fc"
    local _nr_lab_events "Events"
    local _nr_fmt_events "%12.0fc"
    local _nr_lab_people "People"
    local _nr_fmt_people "%12.0fc"
    local _nr_lab_exposure : copy local exposurelabel
    local _nr_fmt_exposure "%12.0fc"
    local _nr_lab_mi_m "Imputations"
    local _nr_fmt_mi_m "%12.0fc"
    local _nr_lab_r2_a "Adjusted R²"
    local _nr_fmt_r2_a "%5.3f"
    local _nr_lab_rmse "Root MSE"
    local _nr_fmt_rmse "%9.3f"
    local _nr_lab_F "F statistic"
    local _nr_fmt_F "%9.2f"
    local _nr_lab_fmi "Largest FMI"
    local _nr_fmt_fmi "%6.4f"
    * statlabels(): a row label the user gave replaces the default
    foreach _nt in obs events people mi_m r2_a rmse fmi {
        if `"`macval(_stl_`_nt')'"' != "" {
        	local _nr_lab_`_nt' `"`macval(_stl_`_nt')'"'
        }
    }
    if `"`macval(_stl_f)'"' != "" {
    	local _nr_lab_F `"`macval(_stl_f)'"'
    }

    * Add N row
    if `want_n' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_N_`m'') local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            local _n_label = cond(`_any_N_sub', "Subjects", "Observations")
            if `"`macval(_stl_n)'"' != "" {
            	local _n_label `"`macval(_stl_n)'"'
            }
            replace A = `"`macval(_n_label)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_N_`m'') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_N_`m'', "%12.0fc") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' n"
        }
    }


    foreach _nt in obs events people exposure {
        if `want_`_nt'' != 1 continue
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') local has_val = 1
        }
        if !`has_val' continue
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = `"`macval(_nr_lab_`_nt')'"' in `=`curr_n'+1'
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') {
                local col = (`m' - 1) * 3 + 1
                replace c`col' = string(`stat_`_nt'_`m'', "`_nr_fmt_`_nt''") in `=`curr_n'+1'
            }
        }
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
        local stats_row_ids "`stats_row_ids' `_nt'"
    }

    * Add Groups row
    if `want_groups' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_groups_`m'') local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            local _grp_label "Groups"
            if `"`macval(_stl_groups)'"' != "" {
            	local _grp_label `"`macval(_stl_groups)'"'
            }
            replace A = `"`macval(_grp_label)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_groups_`m'') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_groups_`m'', "%12.0fc") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' groups"
        }
    }

    foreach _nt in mi_m {
        if `want_`_nt'' != 1 continue
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') local has_val = 1
        }
        if !`has_val' continue
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = `"`macval(_nr_lab_`_nt')'"' in `=`curr_n'+1'
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') {
                local col = (`m' - 1) * 3 + 1
                replace c`col' = string(`stat_`_nt'_`m'', "`_nr_fmt_`_nt''") in `=`curr_n'+1'
            }
        }
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
        local stats_row_ids "`stats_row_ids' `_nt'"
    }

    * Add AIC row (falls back to QICu for fixed-scale GEE models where AIC is
    * undefined). Track that fallback so stats(aic qic) cannot append QICu twice.
    local _qicu_rendered_by_aic 0
    if `want_aic' == 1 {
        local has_val = 0
        local _aic_label "AIC"
        forvalues m = 1/`use_models' {
            if !missing(`stat_aic_`m'') local has_val = 1
        }
        if !`has_val' {
            forvalues m = 1/`use_models' {
                if !missing(`stat_qic_`m'') local has_val = 1
            }
            if `has_val' local _aic_label "QICu"
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            local _aic_shown `"`_aic_label'"'
            if "`_aic_label'" == "AIC" & `"`macval(_stl_aic)'"' != "" {
            	local _aic_shown `"`macval(_stl_aic)'"'
            }
            if "`_aic_label'" == "QICu" & `"`macval(_stl_qic)'"' != "" {
            	local _aic_shown `"`macval(_stl_qic)'"'
            }
            replace A = `"`macval(_aic_shown)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if "`_aic_label'" == "AIC" {
                    if !missing(`stat_aic_`m'') {
                        local col = (`m' - 1) * 3 + 1
                        replace c`col' = string(`stat_aic_`m'', "%12.2f") in `=`curr_n'+1'
                    }
                }
                else {
                    if !missing(`stat_qic_`m'') {
                        local col = (`m' - 1) * 3 + 1
                        replace c`col' = string(`stat_qic_`m'', "%12.2f") in `=`curr_n'+1'
                    }
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' aic"
            if "`_aic_label'" == "QICu" local _qicu_rendered_by_aic 1
        }
    }

    * Add QICu row (explicit stats(qic) request — for GEE/xtgee models)
    if `want_qic' == 1 & !`_qicu_rendered_by_aic' {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_qic_`m'') local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            local _qic_shown "QICu"
            if `"`macval(_stl_qic)'"' != "" {
            	local _qic_shown `"`macval(_stl_qic)'"'
            }
            replace A = `"`macval(_qic_shown)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_qic_`m'') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_qic_`m'', "%12.2f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' qic"
        }
    }

    * Add BIC row
    if `want_bic' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_bic_`m'') local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            local _bic_shown "BIC"
            if `"`macval(_stl_bic)'"' != "" {
            	local _bic_shown `"`macval(_stl_bic)'"'
            }
            replace A = `"`macval(_bic_shown)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_bic_`m'') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_bic_`m'', "%12.2f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' bic"
        }
    }

    * Add Log-likelihood row
    if `want_ll' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_ll_`m'') local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            local _ll_shown "Log-likelihood"
            if `"`macval(_stl_ll)'"' != "" {
            	local _ll_shown `"`macval(_stl_ll)'"'
            }
            replace A = `"`macval(_ll_shown)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_ll_`m'') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_ll_`m'', "%12.2f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' ll"
        }
    }

    * Add ICC row (per model)
    if `want_icc' == 1 {
        local has_icc = 0
        local use_icc_models = min(`n_icc_models', `n_models')
        forvalues m = 1/`use_icc_models' {
            if !missing(`stat_icc_`m'') local has_icc = 1
        }
        if `has_icc' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            local _icc_shown "ICC"
            if `"`macval(_stl_icc)'"' != "" {
            	local _icc_shown `"`macval(_stl_icc)'"'
            }
            replace A = `"`macval(_icc_shown)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_icc_models' {
                if !missing(`stat_icc_`m'') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_icc_`m'', "%5.3f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' icc"
        }
    }

    * Add R² / Pseudo R² row (F6)
    if `want_r2' == 1 {
        local has_r2 = 0
        forvalues m = 1/`use_models' {
            * Prefer r2, fallback to r2_p (pseudo), then r2_a (adjusted)
            if !missing(`stat_r2_`m'') | !missing(`stat_r2_p_`m'') | !missing(`stat_r2_a_`m'') {
                local has_r2 = 1
            }
        }
        if `has_r2' {
            * Use a generic label when regular and pseudo-R² metrics are mixed.
            local r2_label "R²"
            local _any_r2 = 0
            local _any_pseudo_r2 = 0
            forvalues m = 1/`use_models' {
                if !missing(`stat_r2_`m'') local _any_r2 = 1
                if !missing(`stat_r2_p_`m'') local _any_pseudo_r2 = 1
            }
            if !`_any_r2' & `_any_pseudo_r2' local r2_label "Pseudo R²"
            else if `_any_r2' & `_any_pseudo_r2' local r2_label "R² / Pseudo R²"
            if `"`macval(_stl_r2)'"' != "" {
            	local r2_label `"`macval(_stl_r2)'"'
            }

            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = `"`macval(r2_label)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                local _r2val = .
                if !missing(`stat_r2_`m'') local _r2val = `stat_r2_`m''
                else if !missing(`stat_r2_p_`m'') local _r2val = `stat_r2_p_`m''
                else if !missing(`stat_r2_a_`m'') local _r2val = `stat_r2_a_`m''
                if !missing(`_r2val') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`_r2val', "%5.3f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' r2"
        }
    }

    foreach _nt in r2_a rmse F fmi {
        if `want_`_nt'' != 1 continue
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') local has_val = 1
        }
        if !`has_val' continue
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = `"`macval(_nr_lab_`_nt')'"' in `=`curr_n'+1'
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') {
                local col = (`m' - 1) * 3 + 1
                replace c`col' = string(`stat_`_nt'_`m'', "`_nr_fmt_`_nt''") in `=`curr_n'+1'
            }
        }
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
        local stats_row_ids "`stats_row_ids' `_nt'"
    }

    * A built-in row that no collected model reports is left out of the
    * table; the console says which, so a requested row is never dropped
    * without a word.
    local _omit_ids ""
    foreach _nt in n obs events people exposure groups mi_m aic qic bic ll icc ///
        r2 r2_a rmse F fmi {
        if `want_`_nt'' != 1 continue
        local _shown : list _nt in stats_row_ids
        if "`_nt'" == "qic" & `_qicu_rendered_by_aic' local _shown 1
        if !`_shown' local _omit_ids "`_omit_ids' `_nt'"
    }
    local _omit_ids = strtrim("`_omit_ids'")
    if "`_omit_ids'" != "" {
        noisily display as text "(regtab: no model reports " ///
            `"`: word count `_omit_ids'' requested statistic(s), left out of the table: `_omit_ids')"'
    }

    * Generic rows, in the order given. e(name): integers with thousands
    * separators, other values to three decimals, or the item's own format;
    * blank where a model lacks it. mincell(#) prints a value from 1 to #-1
    * as "<#", the package's small-cell text (tabcell, ratetab); a name in
    * several items takes the strictest mincell() given for it
    * (_cst_mc_#, _cst_mc2_#, from _regtab_statspec). e(a|b) prints
    * "a (b)", each part formatted and masked alone; "a" alone when b is
    * missing, and a blank cell when a is. text(): the values as given, one
    * per model; more values than models is an error.
    * maskwith() (complementary masking, this table only): names in one
    * group are masked together. In a model where any member prints <#
    * (primary), every other member with a value prints the withheld text,
    * the en dash, never a number, so no member gives a masked count back.
    local _n_stmask = 0
    local _n_stlink = 0
    local _cst_tk = 0
    local _cst_anymc = 0
    local _cst_dash = uchar(8211)
    local _cst_mods = min(`n_models', max(`_meta_models', 1))
    * primary masks first, so a group knows in which models it is masked
    forvalues _k = 1/`_cst_n' {
        if "`_cst_kind_`_k''" != "e" continue
        forvalues m = 1/`_cst_mods' {
            foreach _s in "" 2 {
                if "`_s'" == "2" & "`_cst_nm2_`_k''" == "" continue
                local _x = `_cstv`_s'_`_k'_`m''
                local _cst_pm`_s'_`_k'_`m' = (`_cst_mc`_s'_`_k'' > 0 & !missing(`_x') & `_x' >= 1 & `_x' < `_cst_mc`_s'_`_k'')
                if `_cst_pm`_s'_`_k'_`m'' & `_cst_g`_s'_`_k'' > 0 {
                    local _cst_trig_`_cst_g`_s'_`_k''_`m' = 1
                }
            }
        }
    }
    forvalues _k = 1/`_cst_n' {
        if "`_cst_kind_`_k''" == "text" & `_cst_tn_`_k'' > `n_models' {
            noisily display as error `"stats(): text("`macval(_cst_lb_`_k')'" ...) has `_cst_tn_`_k'' values for `n_models' models"'
            exit 198
        }
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = `"`macval(_cst_lb_`_k')'"' in `=`curr_n'+1'
        if "`_cst_kind_`_k''" == "text" {
            local ++_cst_tk
            forvalues m = 1/`_cst_tn_`_k'' {
                local col = (`m' - 1) * 3 + 1
                replace c`col' = `"`macval(_cst_tv_`_k'_`m')'"' in `=`curr_n'+1'
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' text(`_cst_tk')"
            continue
        }
        if `_cst_mc_`_k'' > 0 | `_cst_mc2_`_k'' > 0 local _cst_anymc = 1
        forvalues m = 1/`_cst_mods' {
            local _cst_cell ""
            foreach _s in "" 2 {
                if "`_s'" == "2" & "`_cst_nm2_`_k''" == "" continue
                local _x = `_cstv`_s'_`_k'_`m''
                local _cst_txt ""
                if !missing(`_x') {
                    local _cst_fmt "`_cst_fmt_`_k''"
                    if "`_cst_fmt'" == "" local _cst_fmt = cond(`_cst_int`_s'_`_k'', "%12.0fc", "%12.3f")
                    local _cst_txt = strtrim(string(`_x', "`_cst_fmt'"))
                    local _cst_gs = `_cst_g`_s'_`_k''
                    if `_cst_pm`_s'_`_k'_`m'' {
                        local _cst_txt "<`_cst_mc`_s'_`_k''"
                        local ++_n_stmask
                    }
                    else if `_cst_gs' > 0 {
                        if "`_cst_trig_`_cst_gs'_`m''" == "1" {
                            local _cst_txt "`_cst_dash'"
                            local ++_n_stlink
                        }
                    }
                }
                if "`_s'" == "" local _cst_cell `"`_cst_txt'"'
                * a missing first value leaves the cell blank, never "(b)"
                else if `"`_cst_txt'"' != "" & `"`_cst_cell'"' != "" {
                    local _cst_cell = strtrim(`"`_cst_cell' (`_cst_txt')"')
                }
            }
            if `"`_cst_cell'"' != "" {
                local col = (`m' - 1) * 3 + 1
                replace c`col' = `"`_cst_cell'"' in `=`curr_n'+1'
            }
        }
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
        local stats_row_ids "`stats_row_ids' e(`_cst_nm_`_k''`=cond("`_cst_nm2_`_k''" != "", "|`_cst_nm2_`_k''", "")')"
    }

    local stats_rows = strtrim("`stats_rows'")
}
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end
