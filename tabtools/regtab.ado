*! regtab Version 1.8.0  2026/03/14
*! Original Author: Tim Copeland

/*
DESCRIPTION:
	Formats the collected regression tables; exports point estimate, 95% CI, and p-value to excel; and applies excel formatting (column widths, merges cells, sets column widths). Title appears in cell A1. Top left cell of table is B2.

SYNTAX:
	regtab, xlsx(string) sheet(string) [models(string) sep(string asis) coef(string) title(string) noint nore stats(string) relabel]

	xlsx:	Required option. Excel file name. Requires .xlsx suffix
	sheet:	Required option. Excel sheet name.
	models:	Label models, separating model names using backslash (e.g., Model 1 \ Model 2...)
	coef:	Labels the point estimate (e.g., OR, Coef., HR)
	title:	Gives spreasheet a table name in cell A1
	noint:	Drops intercept row
	nore:	Drops random effects rows
	sep:    character separating 95% CI, default is ", "
	stats:	Model statistics to add at bottom (space-separated): n aic bic icc ll groups
	        - n: Number of observations
	        - aic: Akaike Information Criterion
	        - bic: Bayesian Information Criterion
	        - icc: Intraclass Correlation Coefficient (for mixed models)
	        - ll: Log-likelihood
	        - groups: Number of groups (for mixed models)
	relabel: Relabel random effects nicely (e.g., "var(_cons)" -> "Variance (Intercept)")

	Automatic MOR/MHR: For melogit models, random intercept variance is
	        automatically converted to Median Odds Ratio (MOR). For mestreg
	        and mecloglog, it becomes Median Hazard Ratio (MHR). CI bounds
	        are transformed on the same scale. Use nore to suppress.

*/

program define regtab, rclass
	version 17.0
	set varabbrev off
	set more off

	* Auto-load shared helper programs if not already in memory
	capture program list _tabtools_validate_path
	if _rc {
		capture findfile _tabtools_common.ado
		if _rc == 0 {
			run "`r(fn)'"
		}
		else {
			display as error "_tabtools_common.ado not found; reinstall tabtools"
			exit 111
		}
	}

syntax, xlsx(string) sheet(string) [sep(string asis) models(string) coef(string) title(string) NOINTercept NOREeffects stats(string) RELABel]

* Map option names for internal use
local noint `nointercept'
local nore `noreeffects'

quietly{
    * Validation: Check if collect table exists
    capture quietly collect query row
    if _rc {
        noisily display as error "No active collect table found"
        noisily display as error "Run regression commands with collect prefix first"
        exit 119
    }

    * Validation: Check if file name has .xlsx extension
    if !strmatch("`xlsx'", "*.xlsx") {
        noisily display as error "Excel filename must have .xlsx extension"
        exit 198
    }

    * Validation: Check for dangerous characters in file path
    _tabtools_validate_path "`xlsx'" "xlsx()"
    _tabtools_validate_path "`sheet'" "sheet()"

    * Create temporary file for intermediate processing
    tempfile temp_export
    local temp_xlsx "`temp_export'.xlsx"

    return local xlsx "`xlsx'"
    return local sheet "`sheet'"

	if `"`sep'"' == "" local sep ", "      // Default CI delimiter

    * =========================================================================
    * STORE MODEL STATISTICS BEFORE COLLECT EXPORT
    * =========================================================================
    * Store e() statistics for each model in the collection
    * These may get cleared during processing, so capture them now

    local add_stats = 0
    tempname temp_b
    if "`stats'" != "" {
        local add_stats = 1

        * Parse requested statistics
        local want_n = 0
        local want_aic = 0
        local want_bic = 0
        local want_icc = 0
        local want_ll = 0
        local want_groups = 0

        local stats_lower = " " + strlower("`stats'") + " "
        if strpos("`stats_lower'", " n ") local want_n = 1
        if strpos("`stats_lower'", " aic ") local want_aic = 1
        if strpos("`stats_lower'", " bic ") local want_bic = 1
        if strpos("`stats_lower'", " icc ") local want_icc = 1
        if strpos("`stats_lower'", " ll ") local want_ll = 1
        if strpos("`stats_lower'", " groups ") | strpos("`stats_lower'", " group ") local want_groups = 1

        * ================================================================
        * EXTRACT PER-MODEL STATS FROM COLLECTION
        * ================================================================
        * The collect framework stores e() scalars per cmdset.
        * Extract via temporary layout + export + import cycle.
        local n_stat_models = 0

        * Build list of result levels needed
        local result_levels ""
        if `want_n' local result_levels "N"
        if `want_ll' | `want_aic' | `want_bic' {
            local result_levels "`result_levels' ll"
        }
        if `want_aic' local result_levels "`result_levels' aic"
        if `want_bic' local result_levels "`result_levels' bic"
        if `want_aic' | `want_bic' {
            local result_levels "`result_levels' rank"
        }
        if `want_groups' local result_levels "`result_levels' N_g"
        local result_levels : list uniq result_levels

        if "`result_levels'" != "" {
            tempfile stats_temp
            local stats_xlsx_file "`stats_temp'.xlsx"

            * Save original labels, set short labels for export headers
            foreach rlevel of local result_levels {
                capture local _orig_lbl_`rlevel' : collect label levels result `rlevel'
                capture collect label levels result `rlevel' "`rlevel'", modify
            }

            capture {
                collect layout (cmdset) (result[`result_levels'])
                collect export "`stats_xlsx_file'", sheet(_stats, replace) modify
            }

            * Restore original labels
            foreach rlevel of local result_levels {
                if `"`_orig_lbl_`rlevel''"' != "" {
                    capture collect label levels result `rlevel' `"`_orig_lbl_`rlevel''"', modify
                }
            }

            if _rc == 0 {
                preserve
                capture {
                    import excel "`stats_xlsx_file'", sheet(_stats) clear allstring

                    * Map header row to column positions
                    local stat_col_N ""
                    local stat_col_ll ""
                    local stat_col_aic ""
                    local stat_col_bic ""
                    local stat_col_rank ""
                    local stat_col_N_g ""

                    ds
                    local stat_allvars `r(varlist)'
                    foreach v of local stat_allvars {
                        local hdr = `v'[1]
                        if "`hdr'" == "N" local stat_col_N "`v'"
                        if "`hdr'" == "ll" local stat_col_ll "`v'"
                        if "`hdr'" == "aic" local stat_col_aic "`v'"
                        if "`hdr'" == "bic" local stat_col_bic "`v'"
                        if "`hdr'" == "rank" local stat_col_rank "`v'"
                        if "`hdr'" == "N_g" local stat_col_N_g "`v'"
                    }

                    local n_stat_models = _N - 1

                    forvalues m = 1/`n_stat_models' {
                        local r = `m' + 1

                        * Extract each result level
                        foreach sname in N ll aic bic rank N_g {
                            if "`sname'" == "N_g" local lname "groups"
                            else local lname "`sname'"
                            local stat_`lname'_`m' = .
                            if "`stat_col_`sname''" != "" {
                                local val = `stat_col_`sname''[`r']
                                local val = subinstr("`val'", ",", "", .)
                                if "`val'" != "" & "`val'" != "." {
                                    local stat_`lname'_`m' = real("`val'")
                                }
                            }
                        }

                        * Compute AIC from ll + rank if not directly available
                        if `stat_aic_`m'' == . & `stat_ll_`m'' != . & `stat_rank_`m'' != . {
                            local stat_aic_`m' = -2 * `stat_ll_`m'' + 2 * `stat_rank_`m''
                        }

                        * Compute BIC from ll + rank + N if not directly available
                        if `stat_bic_`m'' == . & `stat_ll_`m'' != . & `stat_rank_`m'' != . & `stat_N_`m'' != . {
                            local stat_bic_`m' = -2 * `stat_ll_`m'' + `stat_rank_`m'' * ln(`stat_N_`m'')
                        }
                    }
                }
                if _rc local n_stat_models = 0
                restore
                capture erase "`stats_xlsx_file'"
            }
        }

        * Backfill groups from e() when collection extraction found none
        * (mixed stores N_g as matrix, not scalar — invisible to collect)
        if `n_stat_models' > 0 & `want_groups' == 1 {
            local _all_grp_miss = 1
            forvalues m = 1/`n_stat_models' {
                if `stat_groups_`m'' != . local _all_grp_miss = 0
            }
            if `_all_grp_miss' {
                local _grp = .
                capture local _grp = e(N_g)
                if `_grp' == . {
                    capture {
                        tempname ng_mat
                        matrix `ng_mat' = e(N_g)
                        local _grp = `ng_mat'[1,1]
                    }
                }
                if `_grp' == . capture local _grp = e(N_clust)
                if `_grp' != . {
                    local stat_groups_`n_stat_models' = `_grp'
                }
            }
        }

        * Fallback: if collection extraction failed, use e() for c1 only
        if `n_stat_models' == 0 {
            local stat_N_1 = .
            local stat_aic_1 = .
            local stat_bic_1 = .
            local stat_ll_1 = .
            local stat_groups_1 = .
            local stat_k_1 = .

            capture local stat_N_1 = e(N)
            capture local stat_ll_1 = e(ll)

            capture {
                local stat_groups_1 = e(N_g)
            }
            if `stat_groups_1' == . {
                capture {
                    tempname ng_mat
                    matrix `ng_mat' = e(N_g)
                    local stat_groups_1 = `ng_mat'[1,1]
                }
            }
            if `stat_groups_1' == . {
                capture local stat_groups_1 = e(N_clust)
            }

            capture local stat_aic_1 = e(aic)
            capture local stat_bic_1 = e(bic)

            if `stat_aic_1' == . & `stat_ll_1' != . {
                capture local stat_k_1 = e(rank)
                if `stat_k_1' == . {
                    capture local stat_k_1 = e(k)
                }
                if `stat_k_1' != . {
                    local stat_aic_1 = -2 * `stat_ll_1' + 2 * `stat_k_1'
                }
            }

            if `stat_bic_1' == . & `stat_ll_1' != . & `stat_N_1' != . {
                if `stat_k_1' == . {
                    capture local stat_k_1 = e(rank)
                    if `stat_k_1' == . {
                        capture local stat_k_1 = e(k)
                    }
                }
                if `stat_k_1' != . {
                    local stat_bic_1 = -2 * `stat_ll_1' + `stat_k_1' * ln(`stat_N_1')
                }
            }

            * Flag as single-model fallback
            local n_stat_models = 1
        }

        * ICC: extract variance components per model from collection
        * Collection stores var(_cons) = random intercept variance,
        * var(e) = residual variance (continuous), not log-SD values
        local n_icc_models = 0
        if `want_icc' == 1 {
            forvalues m = 1/`n_stat_models' {
                local stat_icc_`m' = .
            }

            tempfile icc_temp
            local icc_xlsx_file "`icc_temp'.xlsx"

            capture {
                collect layout (cmdset) (colname[var(_cons) var(e)]#result[_r_b])
                collect export "`icc_xlsx_file'", sheet(_icc, replace) modify
            }

            if _rc == 0 {
                preserve
                capture {
                    import excel "`icc_xlsx_file'", sheet(_icc) clear allstring

                    * Find first data row (column A has cmdset number)
                    local _icc_hdr = 0
                    forvalues _ir = 1/`=_N' {
                        if real(A[`_ir']) != . {
                            local _icc_hdr = `_ir' - 1
                            continue, break
                        }
                    }
                    local n_icc_models = _N - `_icc_hdr'

                    * Find columns for each variance component
                    ds
                    local icc_allvars `r(varlist)'
                    local icc_col_re ""
                    local icc_col_resid ""
                    foreach v of local icc_allvars {
                        local hdr = `v'[1]
                        if strpos("`hdr'", "var(_cons)") local icc_col_re "`v'"
                        if strpos("`hdr'", "var(e)") local icc_col_resid "`v'"
                    }

                    forvalues m = 1/`n_icc_models' {
                        local r = `m' + `_icc_hdr'
                        local val_re = ""
                        local val_resid = ""

                        if "`icc_col_re'" != "" {
                            local val = subinstr(`icc_col_re'[`r'], ",", "", .)
                            if "`val'" != "" & "`val'" != "." {
                                local val_re = real("`val'")
                            }
                        }
                        if "`icc_col_resid'" != "" {
                            local val = subinstr(`icc_col_resid'[`r'], ",", "", .)
                            if "`val'" != "" & "`val'" != "." {
                                local val_resid = real("`val'")
                            }
                        }

                        if "`val_re'" != "" & "`val_resid'" != "" {
                            local stat_icc_`m' = `val_re' / (`val_re' + `val_resid')
                        }
                        else if "`val_re'" != "" & "`val_resid'" == "" {
                            * Binary outcome (melogit): use pi^2/3 for level-1 variance
                            local stat_icc_`m' = `val_re' / (`val_re' + c(pi)^2/3)
                        }
                    }
                }
                if _rc local n_icc_models = 0
                restore
                capture erase "`icc_xlsx_file'"
            }

            * Fallback: e(b) for last model only (backward compat)
            if `n_icc_models' == 0 {
                local var_re = ""
                local var_resid = ""
                capture {
                    matrix `temp_b' = e(b)
                    local colnames : colfullnames `temp_b'
                    local col = 1
                    foreach colname of local colnames {
                        if strpos("`colname'", "lns1_1_1:") {
                            local log_sd = `temp_b'[1,`col']
                            local var_re = exp(2 * `log_sd')
                        }
                        if strpos("`colname'", "lnsig_e:") {
                            local log_sd = `temp_b'[1,`col']
                            local var_resid = exp(2 * `log_sd')
                        }
                        local col = `col' + 1
                    }
                }
                if "`var_re'" != "" & "`var_resid'" != "" {
                    local stat_icc_`n_stat_models' = `var_re' / (`var_re' + `var_resid')
                }
                else if "`var_re'" != "" {
                    local stat_icc_`n_stat_models' = `var_re' / (`var_re' + c(pi)^2/3)
                }
                local n_icc_models = `n_stat_models'
            }
        }
    }

    * =========================================================================
    * DETECT MODEL TYPE FOR RANDOM EFFECTS TRANSFORMATION
    * =========================================================================
    * melogit -> Median Odds Ratio (MOR)
    * mestreg / mecloglog -> Median Hazard Ratio (MHR)
    * Note: melogit stores e(cmd)="meglm", mestreg stores e(cmd)="gsem"
    * The original command name is in e(cmd2)
    * For multi-model tables, e(cmd2) reflects the last model only.
    * RE rows only exist for mixed-effects models, so if the last model
    * is melogit/mestreg, MOR/MHR applies to its RE rows. Mixing
    * different mixed-effects model types (e.g., mixed + melogit) in one
    * table is not supported for MOR/MHR — use separate tables instead.
    local re_transform = "none"
    local model_cmd2 = ""
    capture local model_cmd2 = e(cmd2)
    if "`model_cmd2'" == "melogit" {
        local re_transform = "mor"
    }
    else if inlist("`model_cmd2'", "mecloglog", "mestreg") {
        local re_transform = "mhr"
    }

    * =========================================================================
    * STORE RANDOM EFFECTS LABELS BEFORE COLLECT EXPORT (for relabel option)
    * =========================================================================
    local re_groupvar = ""
    local re_grouplbl = ""
    local re_vars = ""

    * Always capture grouping variable info (needed for relabel AND MOR/MHR)
    capture local re_groupvar = e(ivars)
    * Check for empty string AND "." (missing value returned by OLS models)
    if "`re_groupvar'" != "" & "`re_groupvar'" != "." {
        * For single-level models, get the label
        local re_grouplbl : variable label `re_groupvar'
        if "`re_grouplbl'" == "" local re_grouplbl "`re_groupvar'"

        * Get random effects variables
        capture local re_vars = e(revars)
        if "`re_vars'" != "" {
            * Store labels for each random effect variable
            foreach revar of local re_vars {
                if "`revar'" == "_cons" {
                    local lbl_`revar' "Intercept"
                }
                else {
                    local lbl_`revar' : variable label `revar'
                    if "`lbl_`revar''" == "" local lbl_`revar' "`revar'"
                }
            }
        }
    }

collect label levels result _r_b "`coef'", modify
collect style cell result[_r_b], warn nformat(%4.2fc) halign(center) valign(center)
collect style cell result[_r_ci], warn nformat(%12.8f) sformat("(%s)") cidelimiter("`sep'") halign(center) valign(center)
collect style cell result[_r_p], warn nformat(%5.4f) halign(center) valign(center)
collect style column, dups(center)
collect style row stack, nodelimiter nospacer indent length(.) wrapon(word) noabbreviate wrap(.) truncate(tail)
collect layout (colname) (cmdset#result[_r_b _r_ci _r_p]) ()

capture collect export "`temp_xlsx'", sheet(temp,replace) modify
if _rc {
	noisily display as error "Failed to export collect table to temporary Excel file"
	noisily display as error "Check that collect table is properly structured"
	exit _rc
}

* Preserve user data before import
preserve

capture import excel "`temp_xlsx'", sheet(temp) clear
if _rc {
	noisily display as error "Failed to import temporary Excel file"
	capture erase "`temp_xlsx'"
	restore
	exit _rc
}
* Note: DO NOT TRIM WHITE SPACE--NEED IT FOR LEADING INDENT FOR CATEGORICAL VARIABLE

if "`noint'" != "" {
	drop if regexm(strlower(A), "^(intercept|_cons|constant)$")
}

if "`nore'" != "" {
	drop if strpos(A,"var(") > 0 | strpos(A,"cov(") > 0 | strpos(A,"sd(") > 0
}

* Reorder: fixed effects first, then random effects (collect may interleave them)
gen _orig_order = _n
gen byte _is_re_sort = (strpos(A, "var(") > 0) | (strpos(A, "cov(") > 0) | (strpos(A, "sd(") > 0)
* Row 1 is header — keep at top
replace _is_re_sort = 0 if _n <= 2
sort _is_re_sort _orig_order
drop _orig_order _is_re_sort

* Mark random effects row numbers for adaptive formatting
gen _temp_re_row = _n if (strpos(A, "var(") > 0) | (strpos(A, "cov(") > 0) | (strpos(A, "sd(") > 0)
levelsof _temp_re_row, local(re_row_nums)
drop _temp_re_row

* Mark random intercept row numbers for MOR/MHR (before relabel changes names)
* Note: melogit uses var(_cons[groupvar]) format, not var(_cons)
* Search for "var(_cons" without closing paren to match both formats
local re_int_row_nums ""
if "`re_transform'" != "none" & "`nore'" == "" {
    gen _temp_re_int = _n if strpos(A, "var(_cons") > 0
    levelsof _temp_re_int, local(re_int_row_nums)
    drop _temp_re_int
}

* Relabel random effects if requested
if "`relabel'" != "" {
    if "`re_grouplbl'" != "" {
        * Use grouping variable label for random effects

        * Random intercept: var(_cons) -> "GroupLabel (Intercept)"
        replace A = "`re_grouplbl' (Intercept)" if A == "var(_cons)"

        * Handle melogit/mepoisson format: var(_cons[groupvar]) -> "GroupLabel (Intercept)"
        * Pattern: var(_cons[...]) where ... is any groupvar name
        replace A = "`re_grouplbl' (Intercept)" if strpos(A, "var(_cons[") > 0

        * Handle melogit/mepoisson random slopes: var(varname[groupvar]) -> "GroupLabel (VarLabel)"
        foreach revar of local re_vars {
            if "`revar'" != "_cons" {
                local slope_lbl "`lbl_`revar''"
                replace A = "`re_grouplbl' (`slope_lbl')" if strpos(A, "var(`revar'[") > 0
            }
        }

        * Random slopes: var(varname) -> "GroupLabel (VarLabel)"
        foreach revar of local re_vars {
            if "`revar'" != "_cons" {
                local slope_lbl "`lbl_`revar''"
                replace A = "`re_grouplbl' (`slope_lbl')" if A == "var(`revar')"
            }
        }

        * Covariances: cov(var1,var2) -> "GroupLabel (Label1, Label2)"
        * Parse and replace covariance terms
        count if strpos(A, "cov(") > 0
        if r(N) > 0 {
            * For each row with cov(), extract and replace
            gen _temp_row = _n
            levelsof _temp_row if strpos(A, "cov(") > 0, local(cov_rows)
            foreach row of local cov_rows {
                local cov_str = A[`row']
                * Extract variable names from cov(var1,var2)
                local cov_inner = subinstr("`cov_str'", "cov(", "", 1)
                local cov_inner = subinstr("`cov_inner'", ")", "", 1)
                * Split by comma
                gettoken cov_v1 cov_v2 : cov_inner, parse(",")
                local cov_v2 = subinstr("`cov_v2'", ",", "", 1)
                local cov_v1 = strtrim("`cov_v1'")
                local cov_v2 = strtrim("`cov_v2'")
                * Get labels
                local cov_lbl1 "`lbl_`cov_v1''"
                if "`cov_lbl1'" == "" local cov_lbl1 "`cov_v1'"
                local cov_lbl2 "`lbl_`cov_v2''"
                if "`cov_lbl2'" == "" local cov_lbl2 "`cov_v2'"
                * Replace
                replace A = "`re_grouplbl' (`cov_lbl1', `cov_lbl2')" in `row'
            }
            drop _temp_row
        }

        * Residual variance: var(e) -> "Residual Variance"
        replace A = "Residual Variance" if A == "var(e)"

        * Standard deviations (if present)
        replace A = "`re_grouplbl' SD (Intercept)" if A == "sd(_cons)"
        foreach revar of local re_vars {
            if "`revar'" != "_cons" {
                local slope_lbl "`lbl_`revar''"
                replace A = "`re_grouplbl' SD (`slope_lbl')" if A == "sd(`revar')"
            }
        }
        replace A = "Residual SD" if A == "sd(e)"

        * Log-scale parameters (raw coefficient names)
        replace A = subinstr(A, "lns1_1_1", "`re_grouplbl' Log SD (Intercept)", .)
        replace A = subinstr(A, "lnsig_e", "Residual Log SD", .)
    }
    else {
        * Fallback: no random effects info, use generic labels
        replace A = subinstr(A, "var(_cons)", "Variance (Intercept)", .)
        replace A = subinstr(A, "var(e.", "Variance (Residual", .)
        replace A = subinstr(A, "var(e)", "Residual Variance", .)
        replace A = subinstr(A, "var(", "Variance (", .)
        replace A = subinstr(A, "cov(", "Covariance (", .)
        replace A = subinstr(A, "sd(_cons)", "SD (Intercept)", .)
        replace A = subinstr(A, "sd(e.", "SD (Residual", .)
        replace A = subinstr(A, "sd(", "SD (", .)
        replace A = subinstr(A, "lns1_1_1", "Log SD (Intercept)", .)
        replace A = subinstr(A, "lnsig_e", "Log SD (Residual)", .)
    }

    * Clean up _cons in fixed effects (Intercept row)
    replace A = subinstr(A, "_cons", "Intercept", .)
}

* Apply MOR/MHR labels to random intercept rows (using stored row numbers)
if "`re_transform'" == "mor" & "`nore'" == "" {
    foreach row of local re_int_row_nums {
        if "`re_grouplbl'" != "" {
            replace A = "Median Odds Ratio (`re_grouplbl')" in `row'
        }
        else {
            replace A = "Median Odds Ratio" in `row'
        }
    }
}
else if "`re_transform'" == "mhr" & "`nore'" == "" {
    foreach row of local re_int_row_nums {
        if "`re_grouplbl'" != "" {
            replace A = "Median Hazard Ratio (`re_grouplbl')" in `row'
        }
        else {
            replace A = "Median Hazard Ratio" in `row'
        }
    }
}

* Get all variables - first variable is row labels, rest are data columns
ds
local allvars `r(varlist)'

* Get the first variable name (row labels column)
gettoken firstvar allvars : allvars

* Rename the first variable to A if it's not already named A
if "`firstvar'" != "A" {
	rename `firstvar' A
}

* Rename remaining variables to c1, c2, c3, etc.
local n 1
foreach var of local allvars {
	rename `var' c`n'
	replace c`n' = "" if _n == 1
	local n `=`n'+1'
}
local n2 `=`n'-3'
local n `=`n'-1'
* Model count (used by stats() and ICC placement)
local n_models = `n' / 3

if "`models'" != "" {
    * Split models string by backslashes
	local models : subinstr local models " \ " "\", all
	local models : subinstr local models "\  " "\", all
	local models : subinstr local models "  \" "\", all
    tokenize `"`models'"', parse("\")
    local model_idx = 1
    local col_idx = 1

    * Loop through tokenized results
    while "``model_idx''" != "" {
        if "``model_idx''" != "\" {
            * Apply label to appropriate column
            replace c`col_idx' = "``model_idx''" if _n == 1
            local col_idx = `col_idx' + 3
        }
        local model_idx = `model_idx' + 1
    }
}
local last = `n' - 2
* Recreate RE row indicator from stored row numbers
gen byte _is_re = 0
foreach row of local re_row_nums {
    replace _is_re = 1 in `row'
}
* Recreate random intercept indicator for MOR/MHR formatting
gen byte _is_re_intercept = 0
foreach row of local re_int_row_nums {
    replace _is_re_intercept = 1 in `row'
}
forvalues i = 1(3)`last'{
destring c`i', gen(double c`i'z) force
replace c`i' = "Reference" if inlist(c`i', "0", "1") & c`=`i'+1' == ""
* MOR/MHR transformation: variance -> exp(sqrt(2*var) * invnormal(0.75))
if "`re_transform'" != "none" {
    replace c`i'z = exp(sqrt(2 * c`i'z) * invnormal(0.75)) ///
        if _is_re_intercept == 1 & !missing(c`i'z) & c`i'z >= 0
}
* Fixed effects: 2 decimal places
gen str20 c`i'_fmt = string(round(c`i'z, 0.01), "%9.2f") if !_is_re & !missing(c`i'z)
* Transformed random intercept (MOR/MHR): 2 decimal places
replace c`i'_fmt = string(round(c`i'z, 0.01), "%9.2f") ///
    if _is_re_intercept == 1 & "`re_transform'" != "none" & !missing(c`i'z)
* Other random effects: 4 decimal places
replace c`i'_fmt = string(c`i'z, "%9.4f") ///
    if _is_re & _is_re_intercept == 0 & !missing(c`i'z)
replace c`i' = c`i'_fmt if c`i'_fmt != "" & c`i' != "Reference" & _n >= 3
drop c`i'z c`i'_fmt
capture confirm variable c`=`i'+1'
if _rc == 0 replace c`=`i'+1' = "" if _n == 1
capture confirm variable c`=`i'+2'
if _rc == 0 replace c`=`i'+2' = "" if _n == 1
}
* Reformat CI columns with appropriate precision
local sep_len = strlen(`"`sep'"')
forvalues i = 2(3)`=`last'+1' {
    capture confirm variable c`i'
    if _rc continue
    gen _ci_raw = strtrim(c`i') if _n >= 3
    replace _ci_raw = subinstr(subinstr(_ci_raw, "(", "", 1), ")", "", 1)
    gen int _ci_dpos = strpos(_ci_raw, `"`sep'"')
    gen _ci_lo_s = strtrim(substr(_ci_raw, 1, _ci_dpos - 1)) if _ci_dpos > 0
    gen _ci_hi_s = strtrim(substr(_ci_raw, _ci_dpos + `sep_len', .)) if _ci_dpos > 0
    destring _ci_lo_s, gen(double _ci_lo) force
    destring _ci_hi_s, gen(double _ci_hi) force
    * MOR/MHR transformation of CI bounds
    if "`re_transform'" != "none" {
        replace _ci_lo = exp(sqrt(2 * _ci_lo) * invnormal(0.75)) ///
            if _is_re_intercept == 1 & !missing(_ci_lo) & _ci_lo >= 0
        replace _ci_hi = exp(sqrt(2 * _ci_hi) * invnormal(0.75)) ///
            if _is_re_intercept == 1 & !missing(_ci_hi) & _ci_hi >= 0
    }
    gen str50 _ci_fmt = ""
    * Fixed effects: 2 decimal places
    replace _ci_fmt = "(" + string(_ci_lo, "%4.2fc") + `"`sep'"' + string(_ci_hi, "%4.2fc") + ")" ///
        if !_is_re & !missing(_ci_lo) & !missing(_ci_hi) & _n >= 3
    * Transformed random intercept (MOR/MHR): 2 decimal places
    replace _ci_fmt = "(" + string(_ci_lo, "%4.2fc") + `"`sep'"' + string(_ci_hi, "%4.2fc") + ")" ///
        if _is_re_intercept == 1 & "`re_transform'" != "none" & !missing(_ci_lo) & !missing(_ci_hi) & _n >= 3
    * Other random effects: 4 decimal places
    replace _ci_fmt = "(" + string(_ci_lo, "%9.4f") + `"`sep'"' + string(_ci_hi, "%9.4f") + ")" ///
        if _is_re & _is_re_intercept == 0 & !missing(_ci_lo) & !missing(_ci_hi) & _n >= 3
    replace c`i' = _ci_fmt if _ci_fmt != ""
    drop _ci_raw _ci_dpos _ci_lo_s _ci_hi_s _ci_lo _ci_hi _ci_fmt
}
drop _is_re _is_re_intercept
forvalues i = 3(3)`n'{
* Store original string value to detect genuinely missing p-values
gen str20 c`i'_orig = c`i'
* Convert to numeric - force will set non-numeric to missing
destring c`i', gen(c`i'z) force
gen str20 c`i'_fmt = ""
* Handle genuinely missing p-values (e.g., omitted variables, base categories)
* If original string was "." or empty or converted to missing, leave blank
replace c`i'_fmt = "" if missing(c`i'z) & (strtrim(c`i'_orig) == "." | strtrim(c`i'_orig) == "")
* Handle very small p-values
replace c`i'_fmt = "<0.001" if c`i'z < 0.001 & !missing(c`i'z)
* Handle negative p-values (shouldn't happen but safety check)
replace c`i'_fmt = "<0.001" if c`i'z < 0 & !missing(c`i'z)
* Format p-values 0.001 to 0.05 with 3 decimal places
replace c`i'_fmt = string(c`i'z, "%5.3f") if c`i'z >= 0.001 & c`i'z < 0.05 & !missing(c`i'z)
* Format p-values >= 0.05 with 2 decimal places
replace c`i'_fmt = string(c`i'z, "%4.2f") if c`i'z >= 0.05 & !missing(c`i'z)
* Cap p-values so they never display as 1.00
replace c`i'_fmt = "0.99" if c`i'z >= 0.995 & !missing(c`i'z)
* Handle p-values that are exactly 0 (edge case from some models)
replace c`i'_fmt = "<0.001" if c`i'z == 0 & !missing(c`i'z)
* Add leading zero if missing (e.g., .123 -> 0.123)
replace c`i'_fmt = "0" + c`i'_fmt if substr(c`i'_fmt, 1, 1) == "."
* Apply formatting - only if we have a non-missing formatted value
replace c`i' = c`i'_fmt if c`i'_fmt != "" & _n >= 3
* Leave blank for missing p-values (omitted/base categories)
replace c`i' = "" if missing(c`i'z) & _n >= 3
drop c`i'z c`i'_fmt c`i'_orig
}
*
* =========================================================================
* ADD MODEL STATISTICS ROWS (if requested)
* =========================================================================
local stats_start_row = 0
local stats_rows = ""
if `add_stats' == 1 {
    local stats_start_row = _N + 1
    local use_models = min(`n_stat_models', `n_models')

    * Add N row
    if `want_n' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if `stat_N_`m'' != . local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "Observations" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if `stat_N_`m'' != . {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_N_`m'', "%12.0fc") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    * Add Groups row
    if `want_groups' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if `stat_groups_`m'' != . local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "Groups" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if `stat_groups_`m'' != . {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_groups_`m'', "%12.0fc") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    * Add AIC row
    if `want_aic' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if `stat_aic_`m'' != . local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "AIC" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if `stat_aic_`m'' != . {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_aic_`m'', "%12.2f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    * Add BIC row
    if `want_bic' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if `stat_bic_`m'' != . local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "BIC" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if `stat_bic_`m'' != . {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_bic_`m'', "%12.2f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    * Add Log-likelihood row
    if `want_ll' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if `stat_ll_`m'' != . local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "Log-likelihood" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if `stat_ll_`m'' != . {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_ll_`m'', "%12.2f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    * Add ICC row (per model)
    if `want_icc' == 1 {
        local has_icc = 0
        local use_icc_models = min(`n_icc_models', `n_models')
        forvalues m = 1/`use_icc_models' {
            if `stat_icc_`m'' != . local has_icc = 1
        }
        if `has_icc' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "ICC" in `=`curr_n'+1'
            forvalues m = 1/`use_icc_models' {
                if `stat_icc_`m'' != . {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_icc_`m'', "%5.3f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    local stats_rows = strtrim("`stats_rows'")
}

gen id = _n
count
local count `=`r(N)'+1'
set obs `count'
replace id = 0 if id == .
sort id
drop id
gen title = ""
order title
replace title = "`title'" if _n == 1

capture export excel using "`xlsx'", sheet("`sheet'") sheetreplace
if _rc {
	noisily display as error "Failed to export to `xlsx', sheet `sheet'"
	noisily display as error "Check file permissions and that file is not open in Excel"
	capture erase "`temp_xlsx'"
	restore
	exit _rc
}

local num_rows = _N
local num_cols = c(k)

forvalues i = 1(1)`n'{
gen c`i'_length = length(c`i')
}
egen label_length = rowmax(c*_length)
sum label_length, d
local max_header_length = `=`r(max)' - 0.5'
drop label_length
forvalues i = 1(1)`n'{
replace c`i'_length = . if _n == 2
egen c`i'_max = max(c`i'_length)
}
forvalues i = 1(1)`=`n'-1'{
replace c1_max = c`=`i'+1'_max if c`=`i'+1'_max > c1_max
}
sum c1_max, d
local max_length = (`r(max)' * 3 / 8) + 2

    /* Ensure reasonable min/max bounds */
    if `max_length' < 8 local max_length = 8
    if `max_length' > 60 local max_length = 60

gen A_length = length(A)
egen factor_length = max(A_length)
sum factor_length, d
local factor_length = `=ceil(`=`r(max)'*0.95')'

drop A_length factor_length c*_max c*_length

forvalues i = 1(3)`last'{
gen ref`i' = _n if c`i' == "Reference"
order ref`i', after(c`i')
levelsof ref`i', local(ref`i'_levels)
}
local ref_rows ""
forvalues i = 1(3)`last'{
local ref_rows "`ref_rows' `ref`i'_levels'"
}
local ref_rows: list uniq ref_rows
clear

* Apply Excel formatting with error handling
capture {
	mata: b = xl()
	mata: b.load_book("`xlsx'")
	mata: b.set_sheet("`sheet'")
	mata: b.set_row_height(1,1,30)
	mata: b.set_column_width(2,2,`factor_length')
	forvalues i = 3(3)`=`num_cols'-2'{
		mata: b.set_column_width(`i',`i',`=`max_length'*.55')
	}
	forvalues i = 4(3)`=`num_cols'-1'{
		mata: b.set_column_width(`i',`i',`=`max_length'*1.3')
	}
	forvalues i = 5(3)`num_cols'{
		mata: b.set_column_width(`i',`i',`=`max_length'*.875')
	}
	if `=`max_header_length'*.9' > `=(`max_length'*.55)+(`max_length'*1.3)+(`max_length'*.875)' {
		local headerheight = ceil(`=`max_header_length'*.9'/`=(`max_length'*.55)+(`max_length'*1.3)+(`max_length'*.875)')
		mata: b.set_row_height(2,2,`=`headerheight'*15')
	}
	mata: b.close_book()
}
if _rc {
	local saved_rc = _rc
	* Ensure Excel file handle is closed on error
	capture mata: b.close_book()
	capture mata: mata drop b
	noisily display as error "Excel formatting failed with error `saved_rc'"
	* Clean up temporary file
	capture erase "`temp_xlsx'"
	restore
	exit `saved_rc'
}
capture mata: mata drop b

* Apply putexcel formatting with error handling
_tabtools_col_letter `num_cols'
local letterright "`result'"

capture {
	putexcel set "`xlsx'", sheet("`sheet'") modify
	local letterleft B
	local lettertwo C
	local n1 2
	local n2 `num_rows'
	local tl1 `letterleft'`n1'
	local tl2 `letterleft'`=1+`n1''
	local tl3 `letterleft'`=2+`n1''
	local tr1 `letterright'`n1'
	local tr2 `letterright'`=1+`n1''
	local tr3 `letterright'`=2+`n1''
	local bl `letterleft'`n2'
	local br `letterright'`n2'
	foreach row of local ref_rows {
		local col_num = 3
		while `col_num' <= `n' {
			_tabtools_col_letter `col_num'
			local col_letter = "`result'"

			_tabtools_col_letter `=`col_num'+1'
			local col_letter_next1 = "`result'"

			_tabtools_col_letter `=`col_num'+2'
			local col_letter_next2 = "`result'"

			putexcel (`col_letter'`row':`col_letter_next2'`row'), merge hcenter vcenter
			local col_num = `col_num' + 3
		}
	}
	*Merge Headers over models
	local col_num = 3
	while `col_num' <= `n' {
		_tabtools_col_letter `col_num'
		local col_letter = "`result'"

		_tabtools_col_letter `=`col_num'+1'
		local col_letter_next1 = "`result'"

		_tabtools_col_letter `=`col_num'+2'
		local col_letter_next2 = "`result'"

		putexcel (`col_letter'`n1':`col_letter_next2'`n1'), merge hcenter vcenter bold txtwrap // merge headers
		putexcel (`col_letter_next2'`n1':`col_letter_next2'`n2'), border(right, thin) // right border
		local col_num = `col_num' + 3
	}
	putexcel (A1:`letterright'1), merge txtwrap left top bold // merge title cells
	putexcel (`letterleft'3:`letterright'3), hcenter vcenter bold // bold and center column labels
	putexcel (`tl1':`tr1'), border(top, thin) // top
	putexcel (`lettertwo'`n1':`tr2'), border(top, thin) // above column labels
	putexcel (`tl2':`tr2'), border(bottom, thin) // header bottom
	putexcel (`tr1':`br'), border(right, thin) // right
	putexcel (`tl1':`bl'), border(left, thin) // left
	putexcel (`tl1':`bl'), border(right, thin) // middle (right of variables)
	putexcel (`bl':`br'), border(bottom, thin) // bottom
	putexcel (`letterright'`n1':`letterright'`n2'), border(right, thin) // right of model "x"

	* Add border above first random-effects row (separates FE from RE)
	if "`re_row_nums'" != "" {
	    local first_re : word 1 of `re_row_nums'
	    local re_excel_row = `first_re' + 1
	    putexcel (`letterleft'`re_excel_row':`letterright'`re_excel_row'), border(top, thin)
	}

	* Add borders for statistics rows (if any)
	if "`stats_rows'" != "" {
	    * stats_rows contains row numbers before title row was added
	    * After title row, actual Excel rows are stats_rows + 1
	    local first_stat = 1
	    foreach stat_row of local stats_rows {
	        local excel_row = `stat_row' + 1
	        * Add top border to first stats row (separates from coefficients)
	        if `first_stat' == 1 {
	            putexcel (`letterleft'`excel_row':`letterright'`excel_row'), border(top, thin)
	            local first_stat = 0
	        }
	        * Add bottom border to each stats row
	        putexcel (`letterleft'`excel_row':`letterright'`excel_row'), border(bottom, thin)
	    }
	}

	putexcel (A1:`br'), font(Arial, 10)
	putexcel clear
}
if _rc {
	local saved_rc = _rc
	noisily display as error "Excel cell formatting failed with error `saved_rc'"
	* Clean up temporary file
	capture erase "`temp_xlsx'"
	restore
	exit `saved_rc'
}

* Clean up temporary file
capture erase "`temp_xlsx'"

* Restore user data
restore

* Return statistics
return scalar N_rows = `num_rows'
return scalar N_cols = `num_cols'
}

end
*
