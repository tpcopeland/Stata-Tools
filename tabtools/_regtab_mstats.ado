*! _regtab_mstats Version 2.5.0  2026/10/06
*! regtab block: per-model statistics for stats() from the collection
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_mstats" from inside its quietly block and the body is quietly
* again, so only the block's own noisily lines print. Data in memory, frames,
* and the collection are shared state and need no transport.
program define _regtab_mstats, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
    * =========================================================================
    * STORE MODEL STATISTICS BEFORE COLLECT EXPORT
    * =========================================================================
    * Store e() statistics for each model in the collection
    * These may get cleared during processing, so capture them now

    local add_stats = 0
    if "`stats'" != "" | `_cst_n' > 0 {
        local add_stats = 1

        * Parse requested statistics
        local want_n = 0
        local want_obs = 0
        local want_aic = 0
        local want_bic = 0
        local want_qic = 0
        local want_icc = 0
        local want_ll = 0
        local want_groups = 0
        local want_r2 = 0
        local want_events = 0
        local want_r2_a = 0
        local want_rmse = 0
        local want_F = 0
        local want_mi_m = 0
        local want_fmi = 0
        local want_people = 0
        local want_exposure = 0

        local stats_lower = " " + strlower("`stats'") + " "
        if strpos("`stats_lower'", " n ") local want_n = 1
        * obs: e(N), the observations (records, intervals) even where n
        * reports subjects (e(N_sub)) for a survival model
        if strpos("`stats_lower'", " obs ") local want_obs = 1
        if strpos("`stats_lower'", " aic ") local want_aic = 1
        if strpos("`stats_lower'", " bic ") local want_bic = 1
        if strpos("`stats_lower'", " qic ") local want_qic = 1
        if strpos("`stats_lower'", " icc ") local want_icc = 1
        if strpos("`stats_lower'", " ll ") local want_ll = 1
        if strpos("`stats_lower'", " groups ") local want_groups = 1
        if strpos("`stats_lower'", " r2 ") | strpos("`stats_lower'", " r-squared ") local want_r2 = 1
        if strpos("`stats_lower'", " events ") local want_events = 1
        if strpos("`stats_lower'", " r2_a ") local want_r2_a = 1
        if strpos("`stats_lower'", " rmse ") local want_rmse = 1
        if strpos("`stats_lower'", " f ") local want_F = 1
        if strpos("`stats_lower'", " mi_m ") local want_mi_m = 1
        if strpos("`stats_lower'", " fmi ") local want_fmi = 1
        * people and exposure come only from tabtools fitcount; events from
        * fitcount when the model has it, else from e(N_fail)
        if strpos("`stats_lower'", " people ") local want_people = 1
        if strpos("`stats_lower'", " exposure ") local want_exposure = 1

        * Aliases: treat n_sub / subjects as a request for the N row; regtab
        * already prefers N_sub (subjects) over N (rows) for survival models.
        if strpos("`stats_lower'", " n_sub ") | strpos("`stats_lower'", " subjects ") ///
            local want_n = 1

        * Warn (do not silently drop) on unrecognized stats() tokens.
        local _stat_known " n n_sub subjects obs aic bic qic icc ll groups r2 r-squared events people exposure r2_a rmse f mi_m fmi "
        foreach _stok of local stats {
            local _stok_l = strlower("`_stok'")
            if !strpos("`_stat_known'", " `_stok_l' ") {
                noisily display as error ///
                    "warning: stats() token '`_stok'' not recognized and ignored;" ///
                    " valid: n (n_sub/subjects) obs events people exposure groups mi_m aic bic qic ll icc r2 r2_a rmse F fmi"
            }
        }

        * ================================================================
        * EXTRACT PER-MODEL STATS FROM COLLECTION
        * ================================================================
        * The collect framework stores e() scalars per cmdset.
        * Extract via temporary layout + export + import cycle.
        local n_stat_models = 0
        local _qicu_scale_unavailable ""

        * Build list of result levels needed
        * Note: N is always collected when BIC is requested — BIC requires N
        * even if the user didn't ask for the N row in the output.
        local result_levels ""
        local _any_N_sub = 0
        * N_mi: mi estimate, esampvaryok leaves e(N) missing and reports the
        * average number of observations, as its own header prints it
        if `want_n' | `want_bic' | `want_obs' local result_levels "N N_sub N_mi"
        if `want_ll' | `want_aic' | `want_bic' {
            local result_levels "`result_levels' ll"
        }
        if `want_aic' local result_levels "`result_levels' aic"
        if `want_bic' local result_levels "`result_levels' bic"
        if `want_aic' | `want_bic' | `want_qic' {
            * e(rank) and the counts that can cap it under a robust-type vce
            local result_levels "`result_levels' rank N_clust N_reps"
            if `_any_gee' local result_levels "`result_levels' N_g"
        }
        if `want_qic' | `want_aic' {
            local result_levels "`result_levels' deviance"
            if `_any_gee' local result_levels "`result_levels' phi"
        }
        if `want_groups' local result_levels "`result_levels' N_g"
        if `want_r2' local result_levels "`result_levels' r2 r2_p r2_a"
        if `want_events' local result_levels "`result_levels' N_fail tt_events"
        if `want_people' local result_levels "`result_levels' tt_people"
        if `want_exposure' local result_levels "`result_levels' tt_exposure"
        if `want_r2_a' local result_levels "`result_levels' r2_a"
        if `want_rmse' local result_levels "`result_levels' rmse"
        if `want_F' local result_levels "`result_levels' F"
        if `want_mi_m' local result_levels "`result_levels' M_mi"
        if `want_fmi' local result_levels "`result_levels' fmi_max_mi"
        local result_levels : list uniq result_levels

        if "`result_levels'" != "" {
            * Export headers are the level names: relabel the present levels
            * with their names and restore their labels exactly afterwards.
            * Absent levels stay out of the layout, which would add them to
            * the user's collection.
            _regtab_rlabels `result_levels'
            local result_levels "`_rl_present'"
            if "`result_levels'" == "" {
                * none of the requested statistics is in the collection:
                * every model's statistics are blank
                local n_stat_models = `_meta_models'
                forvalues m = 1/`n_stat_models' {
                    foreach lname in N N_sub ll aic bic qic rank deviance phi groups r2 ///
                        r2_p r2_a events rmse F mi_m fmi N_clust N_reps people exposure ///
                        tt_events N_mi obs {
                        local stat_`lname'_`m' = .
                    }
                }
            }
        }
        if "`result_levels'" != "" {
            capture {
                collect layout (cmdset) (result[`result_levels'])
            }
            local _stats_rc = _rc
            if `_stats_rc' == 0 {
                preserve
                capture {
                    _tabtools_collect_render, type(stats) rowdim(cmdset) ///
                        results(`result_levels') dropempty

                    * Map header row to column positions
                    local stat_col_N ""
                    local stat_col_N_sub ""
                    local stat_col_ll ""
                    local stat_col_aic ""
                    local stat_col_bic ""
                    local stat_col_rank ""
                    local stat_col_deviance ""
                    local stat_col_phi ""
                    local stat_col_N_g ""
                    local stat_col_r2 ""
                    local stat_col_r2_p ""
                    local stat_col_r2_a ""
                    foreach _sx in N_fail rmse F M_mi fmi_max_mi N_clust N_reps ///
                        tt_events tt_people tt_exposure N_mi {
                        local stat_col_`_sx' ""
                    }

                    ds
                    local stat_allvars `r(varlist)'
                    foreach v of local stat_allvars {
                        local hdr = `v'[1]
                        if "`hdr'" == "N" local stat_col_N "`v'"
                        if "`hdr'" == "N_sub" local stat_col_N_sub "`v'"
                        if "`hdr'" == "ll" local stat_col_ll "`v'"
                        if "`hdr'" == "aic" local stat_col_aic "`v'"
                        if "`hdr'" == "bic" local stat_col_bic "`v'"
                        if "`hdr'" == "rank" local stat_col_rank "`v'"
                        if "`hdr'" == "deviance" local stat_col_deviance "`v'"
                        if "`hdr'" == "phi" local stat_col_phi "`v'"
                        if "`hdr'" == "N_g" local stat_col_N_g "`v'"
                        if "`hdr'" == "r2" local stat_col_r2 "`v'"
                        if "`hdr'" == "r2_p" local stat_col_r2_p "`v'"
                        if "`hdr'" == "r2_a" local stat_col_r2_a "`v'"
                        foreach _sx in N_fail rmse F M_mi fmi_max_mi N_clust N_reps ///
                            tt_events tt_people tt_exposure N_mi {
                            if "`hdr'" == "`_sx'" local stat_col_`_sx' "`v'"
                        }
                    }

                    local n_stat_models = _N - 1

                    forvalues m = 1/`n_stat_models' {
                        local r = `m' + 1

                        * Extract each result level
                        foreach sname in N N_sub ll aic bic rank deviance phi N_g r2 r2_p r2_a ///
                            N_fail rmse F M_mi fmi_max_mi N_clust N_reps ///
                            tt_events tt_people tt_exposure N_mi {
                            if "`sname'" == "N_g" local lname "groups"
                            else if "`sname'" == "N_fail" local lname "events"
                            else if "`sname'" == "M_mi" local lname "mi_m"
                            else if "`sname'" == "fmi_max_mi" local lname "fmi"
                            else if "`sname'" == "tt_people" local lname "people"
                            else if "`sname'" == "tt_exposure" local lname "exposure"
                            else local lname "`sname'"
                            local stat_`lname'_`m' = .
                            if "`stat_col_`sname''" != "" {
                                local val = `stat_col_`sname''[`r']
                                local val = subinstr("`val'", ",", "", .)
                                local _num = real("`val'")
                                if !missing(`_num') {
                                    local stat_`lname'_`m' = `_num'
                                }
                            }
                        }

                        * Fit-time counts from tabtools fitcount take precedence
                        * over e(N_fail): they are what the user asked to count.
                        if !missing(`stat_tt_events_`m'') local stat_events_`m' = `stat_tt_events_`m''
                        if missing(`stat_N_`m'') & !missing(`stat_N_mi_`m'') {
                            local stat_N_`m' = `stat_N_mi_`m''
                        }
                        * obs keeps e(N) (or e(N_mi)); n may switch to N_sub below
                        local stat_obs_`m' = `stat_N_`m''

                        * Compute QIC_u from deviance + rank only for xtgee
                        * models whose dispersion is fixed at phi=1.
                        * NOTE: this is Pan (2001) QIC_u, the fixed-penalty
                        * approximation, NOT QIC. Pan's QIC penalty is
                        * 2*trace(Omega*Sigma); QIC_u replaces that trace with
                        * the rank. Pan's unknown-dispersion case requires one
                        * common phi across all candidate models; dividing each
                        * model by its own e(phi) would silently invalidate the
                        * comparison. The fixed-phi boundary is therefore
                        * deliberate and conservative.
                        * k, the parameter count of AIC, BIC, and QICu: the
                        * number of estimated free parameters, whatever the
                        * vce. That is e(rank), as estat ic uses: it leaves out
                        * base, omitted and constrained coefficients and nets
                        * out linear constraints, under a robust-type vce too.
                        * The one exception is a robust-type vce over too few
                        * clusters, GEE panels or replications: the sandwich
                        * variance has rank at most G-1 (R-1), so when that cap
                        * is below the count of collected coefficients with a
                        * nonzero standard error, e(rank) cannot reach the
                        * number the model estimated, and k is that count. The
                        * collection holds no e(Cns), so equality constraints
                        * are not netted out in that capped case (a constraint
                        * fixing a coefficient is: its SE is 0).
                        * Pan (2001) defines QICu's penalty as 2p with p the
                        * number of model parameters, so QICu follows suit.
                        local _k_param = `stat_rank_`m''
                        local _vce_m ""
                        if `m' <= `_meta_models' local _vce_m "`model_vce_`m''"
                        local stat_qic_`m' = .
                        local _this_is_gee = 0
                        if `m' <= `_meta_models' {
                            local _this_is_gee = `model_is_gee_`m''
                        }
                        if inlist("`_vce_m'", "robust", "cluster", "bootstrap", ///
                            "jackknife", "linearized", "brr", "sdr") & `m' <= `_sm_n' & ///
                            !missing(`_k_param') {
                            local _k_cap = .
                            if !missing(`stat_N_clust_`m'') local _k_cap = `stat_N_clust_`m'' - 1
                            if !missing(`stat_N_reps_`m'') local _k_cap = min(`_k_cap', `stat_N_reps_`m'' - 1)
                            if `_this_is_gee' & !missing(`stat_groups_`m'') {
                                local _k_cap = min(`_k_cap', `stat_groups_`m'' - 1)
                            }
                            if !missing(`_k_cap') & `_k_cap' < `_sm_k_`m'' & ///
                                `_k_param' < `_sm_k_`m'' {
                                local _k_param = `_sm_k_`m''
                            }
                        }
                        if `_this_is_gee' {
                            * xtgee is quasi-likelihood based: never retain a
                            * backend e(aic)/e(bic) on an incompatible scale.
                            local stat_aic_`m' = .
                            local stat_bic_`m' = .
                            if !missing(`stat_phi_`m'') & abs(`stat_phi_`m'' - 1) <= 1e-10 & ///
                                !missing(`stat_deviance_`m'') & !missing(`_k_param') {
                                local stat_qic_`m' = `stat_deviance_`m'' + 2 * `_k_param'
                            }
                            else if (`want_qic' | `want_aic') {
                                local _qicu_scale_unavailable ///
                                    `"`_qicu_scale_unavailable' `m'"'
                            }
                        }

                        * AIC = -2*ll + 2*k. Always recompute from ll + k when
                        * both are present rather than trusting e(aic): glm (the GEE
                        * backend) stores e(aic) as AIC/N (per observation), ~N times
                        * too small. The formula matches estat ic for every ML/GLM
                        * estimator and keeps glm and mixed models on one scale.
                        if !`_this_is_gee' & !missing(`stat_ll_`m'') & !missing(`_k_param') {
                            local stat_aic_`m' = -2 * `stat_ll_`m'' + 2 * `_k_param'
                        }

                        * BIC = -2*ll + k*ln(N), likewise recomputed from ll + k + N.
                        * glm's e(bic) uses a deviance-based convention that is not
                        * comparable to the likelihood BIC mixed models report.
                        if !`_this_is_gee' & !missing(`stat_ll_`m'') & ///
                            !missing(`_k_param') & !missing(`stat_N_`m'') {
                            local stat_bic_`m' = -2 * `stat_ll_`m'' + `_k_param' * ln(`stat_N_`m'')
                        }

                        * Prefer N_sub (subjects) over N (rows) for survival models
                        if !missing(`stat_N_sub_`m'') {
                            local stat_N_`m' = `stat_N_sub_`m''
                            local _any_N_sub = 1
                        }
                    }
                }
                if _rc local n_stat_models = 0
                restore
            }
            * the table is rendered: back to the collection's own labels
            forvalues _rli = 1/`_rl_n' {
                local _rlv : word `_rli' of `_rl_present'
                quietly collect label levels result `_rlv' `"`macval(_rl_lbl_`_rli')'"', modify
            }
        }

        * A requested group count must come from the collection.  Active e()
        * is separate state and may describe a later, unrelated fit.
        if `n_stat_models' > 0 & `want_groups' == 1 {
            local _all_grp_miss = 1
            local _groups_supported = 0
            forvalues m = 1/`n_stat_models' {
                if !missing(`stat_groups_`m'') local _all_grp_miss = 0
                if `m' <= `_meta_models' {
                    if "`model_re_family_`m''" != "none" local _groups_supported = 1
                }
            }
            if `_all_grp_miss' & `_groups_supported' {
                noisily display as error ///
                    "Could not recover requested group counts from the active collection"
                exit 459
            }
        }

        * Model statistics must come from the collection.  Active e() is a
        * separate state surface and cannot identify an exact collected fit.
        if `n_stat_models' == 0 & "`result_levels'" != "" {
            noisily display as error ///
                "Could not recover model statistics from the active collection"
            exit 459
        }
        if `n_stat_models' == 0 local n_stat_models = `_meta_models'

        if "`_qicu_scale_unavailable'" != "" {
            local _qicu_scale_unavailable : list uniq _qicu_scale_unavailable
            local _qicu_scale_unavailable = strtrim("`_qicu_scale_unavailable'")
            noisily display as text ///
                "Note: QICu unavailable for GEE model(s) `_qicu_scale_unavailable': dispersion is not fixed at 1"
            noisily display as text ///
                "      use xtgee, scale(1), or compute all candidates externally with one common scale"
        }

        * ICC: extract variance components per model from collection
        * Collection stores var(_cons) = random intercept variance,
        * var(e) = residual variance (continuous), not log-SD values
        local n_icc_models = 0
        if `want_icc' == 1 {
            local _icc_slots = max(`n_stat_models', `_meta_models')
            if `_icc_slots' < 1 local _icc_slots = 1
            forvalues m = 1/`_icc_slots' {
                local stat_icc_`m' = .
            }

            * Count data models (mepoisson, menbreg) have no closed-form
            * level-1 variance — ICC is not defined for those rows. Decision is
            * per-model so a multi-model collection containing mepoisson plus
            * melogit still recovers ICC for the binary-outcome model. Build a
            * skip list and a notice list now; values stay missing for skipped
            * positions while non-skipped positions flow through extraction.
            * Iterate over _meta_models (not n_stat_models): when stats(icc)
            * is the ONLY stats option, the per-model stats extraction path
            * is skipped and the metadata model count supplies the slots.
            * model_icc_undef is set during cmdline parsing for count-data mixed
            * models (mepoisson, menbreg). Use it here rather than re-parsing
            * model_cmd_`m', which may report a deeper e(cmd) name like "meglm".
            local _icc_skip_list ""
            local _icc_skip_n = 0
            local _icc_supported = 0
            if `_meta_models' > 0 {
                forvalues m = 1/`_meta_models' {
                    if `model_icc_undef_`m'' {
                        local _icc_skip_list `"`_icc_skip_list' `m'"'
                    }
                    else if "`model_re_family_`m''" != "none" {
                        local ++_icc_supported
                    }
                }
            }
            if "`_icc_skip_list'" != "" {
                local _icc_skip_list = strtrim("`_icc_skip_list'")
                local _icc_skip_n : word count `_icc_skip_list'
                * "all skipped" is measured against the meta-known model count,
                * not the (possibly fallback-shrunk) n_stat_models.
                local _icc_total = cond(`_meta_models' > 0, `_meta_models', `n_stat_models')
                if `_icc_skip_n' == `_icc_total' {
                    noisily display as text "Note: ICC not computed (no closed-form level-1 variance for the requested model family)"
                }
                else {
                    noisily display as text "Note: ICC not computed for model(s) `_icc_skip_list' (no closed-form level-1 variance)"
                }
            }

            local _icc_collevels "var(_cons) var(e)"
            capture quietly collect levelsof colname
            if _rc == 0 {
                local _icc_levels `"`s(levels)'"'
                foreach _icl of local _icc_levels {
                    if `"`_icl'"' == "var(_cons)" | ///
                        regexm(`"`_icl'"', "^var\(_cons\[.*\]\)$") | ///
                        inlist(`"`_icl'"', "var(e)", "var(Residual)") {
                        local _icc_collevels `"`_icc_collevels' `_icl'"'
                    }
                }
            }
            local _icc_collevels : list uniq _icc_collevels

            capture {
                collect layout (cmdset) ///
                    (colname[`_icc_collevels']#result[_r_b])
            }

            if _rc == 0 {
                preserve
                capture {
                    _tabtools_collect_render, type(icc) rowdim(cmdset) ///
                        coldim(colname) collevels(`"`_icc_collevels'"') results(_r_b)

                    * Find first data row (column A has cmdset number)
                    local _icc_hdr = 0
                    forvalues _ir = 1/`=_N' {
                        if !missing(real(A[`_ir'])) {
                            local _icc_hdr = `_ir' - 1
                            continue, break
                        }
                    }
                    local n_icc_models = _N - `_icc_hdr'

                    * Find columns for each variance component
                    ds
                    local icc_allvars `r(varlist)'
                    local icc_cols_re ""
                    local icc_cols_resid ""
                    foreach v of local icc_allvars {
                        local hdr = `v'[1]
                        if "`hdr'" == "var(_cons)" | ///
                            regexm("`hdr'", "^var\(_cons\[.*\]\)$") {
                            local icc_cols_re "`icc_cols_re' `v'"
                        }
                        if inlist("`hdr'", "var(e)", "var(Residual)") ///
                            local icc_cols_resid "`icc_cols_resid' `v'"
                    }

                    forvalues m = 1/`n_icc_models' {
                        * Per-model skip: count families have no closed-form ICC.
                        local _icc_this_skip = 0
                        if "`_icc_skip_list'" != "" {
                            foreach _ism of local _icc_skip_list {
                                if `_ism' == `m' local _icc_this_skip = 1
                            }
                        }
                        if `_icc_this_skip' continue

                        local r = `m' + `_icc_hdr'
                        local val_re = 0
                        local val_re_found = 0
                        local val_resid = ""

                        foreach _re_col of local icc_cols_re {
                            local val = subinstr(`_re_col'[`r'], ",", "", .)
                            local _num = real("`val'")
                            if !missing(`_num') {
                                local val_re = `val_re' + `_num'
                                local val_re_found = 1
                            }
                        }
                        foreach _res_col of local icc_cols_resid {
                            local val = subinstr(`_res_col'[`r'], ",", "", .)
                            local _num = real("`val'")
                            if !missing(`_num') {
                                local val_resid = `_num'
                                continue, break
                            }
                        }

                        if `val_re_found' & "`val_resid'" != "" {
                            local stat_icc_`m' = `val_re' / (`val_re' + `val_resid')
                        }
                        else if `val_re_found' & "`val_resid'" == "" {
                            * Latent-response models have link-specific
                            * level-1 variances. Never default an unknown model
                            * to the logistic pi^2/3 denominator.
                            local _icc_resid = .
                            if `m' <= `_meta_models' {
                                local _icc_resid = `model_icc_resid_`m''
                            }
                            if !missing(`_icc_resid') {
                                local stat_icc_`m' = `val_re' / (`val_re' + `_icc_resid')
                            }
                        }
                    }
                }
                if _rc local n_icc_models = 0
                restore
            }

            * If the collect path found model rows but all ICC values are still
            * missing, reset so supported but unmappable components produce r(459).
            if `n_icc_models' > 0 {
                local _all_icc_miss = 1
                forvalues _im = 1/`n_icc_models' {
                    local _this_icc `"`stat_icc_`_im''"'
                    if `"`_this_icc'"' != "" {
                        if !missing(real(`"`_this_icc'"')) local _all_icc_miss = 0
                    }
                }
                if `_all_icc_miss' local n_icc_models = 0
            }

            * ICC values must also remain collection-derived.  Count-data
            * mixed models are intentionally blank; supported families error
            * if their variance components cannot be mapped exactly.
            if `n_icc_models' == 0 & `_icc_supported' > 0 {
                noisily display as error ///
                    "Could not recover requested ICC components from the active collection"
                exit 459
            }
        }

        * Generic e(name) items: see _regtab_estats. Each distinct name is
        * read once; item # then holds its first name's values in _cstv_#_m
        * (and integer flag _cst_int_#), a pair's second in _cstv2_#_m.
        if `_cst_n' > 0 {
            local _cst_nmod = max(`_meta_models', 1)
            local _cst_names ""
            forvalues _k = 1/`_cst_n' {
                if "`_cst_kind_`_k''" != "e" continue
                local _cst_names : list _cst_names | _cst_nm_`_k'
                if "`_cst_nm2_`_k''" != "" local _cst_names : list _cst_names | _cst_nm2_`_k'
            }
            if "`_cst_names'" != "" {
                _regtab_estats `_cst_nmod' `_cst_names'
                local _cst_np : word count `_cst_names'
                forvalues _p = 1/`_cst_np' {
                    local _cei_`_p' = `_cst_int_`_p''
                    forvalues m = 1/`_cst_nmod' {
                        local _cev_`_p'_`m' = `_cstv_`_p'_`m''
                    }
                }
            }
            forvalues _k = 1/`_cst_n' {
                local _cst_int_`_k' = 1
                local _cst_int2_`_k' = 1
                forvalues m = 1/`_cst_nmod' {
                    local _cstv_`_k'_`m' = .
                    local _cstv2_`_k'_`m' = .
                }
                if "`_cst_kind_`_k''" != "e" continue
                foreach _s in "" 2 {
                    if "`_cst_nm`_s'_`_k''" == "" continue
                    local _p : list posof "`_cst_nm`_s'_`_k''" in _cst_names
                    local _cst_int`_s'_`_k' = `_cei_`_p''
                    forvalues m = 1/`_cst_nmod' {
                        local _cstv`_s'_`_k'_`m' = `_cev_`_p'_`m''
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
