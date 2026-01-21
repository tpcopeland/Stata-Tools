*! regtab Version 1.4.1  2026/01/08
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

*/

* Helper program to convert column number to Excel letter
program col_to_letter
	version 17.0
	set varabbrev off
	args col_num
	local col_letter = ""
	local temp_col_num = `col_num'
	while `temp_col_num' > 0 {
		local remainder = mod(`temp_col_num' - 1, 26)
		local col_letter = char(`remainder' + 65) + "`col_letter'"
		local temp_col_num = floor((`temp_col_num' - 1) / 26)
	}
	c_local result "`col_letter'"
end

program define regtab, rclass
	version 17.0
	set varabbrev off

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
    if regexm("`xlsx'", "[;&|><\$\`]") {
        noisily display as error "Excel filename contains invalid characters"
        exit 198
    }
    if regexm("`sheet'", "[;&|><\$\`]") {
        noisily display as error "Sheet name contains invalid characters"
        exit 198
    }

    * Create temporary file for intermediate processing
    tempfile temp_export
    local temp_xlsx "`temp_export'.xlsx"

    return local xlsx "`xlsx'"
    return local sheet "`sheet'"

	if `"`sep'"' == "" local sep ", "      // Default separator for IQR

    * =========================================================================
    * STORE MODEL STATISTICS BEFORE COLLECT EXPORT
    * =========================================================================
    * Store e() statistics for each model in the collection
    * These may get cleared during processing, so capture them now

    local add_stats = 0
    if "`stats'" != "" {
        local add_stats = 1

        * Parse requested statistics
        local want_n = 0
        local want_aic = 0
        local want_bic = 0
        local want_icc = 0
        local want_ll = 0
        local want_groups = 0

        local stats_lower = strlower("`stats'")
        if strpos("`stats_lower'", "n") local want_n = 1
        if strpos("`stats_lower'", "aic") local want_aic = 1
        if strpos("`stats_lower'", "bic") local want_bic = 1
        if strpos("`stats_lower'", "icc") local want_icc = 1
        if strpos("`stats_lower'", "ll") local want_ll = 1
        if strpos("`stats_lower'", "group") local want_groups = 1

        * Store current e() values (from most recent estimation)
        * For multi-model tables, we'd need to query collect, but for now
        * we store what's available
        local stat_N = .
        local stat_aic = .
        local stat_bic = .
        local stat_ll = .
        local stat_groups = .
        local stat_k = .

        capture local stat_N = e(N)
        capture local stat_ll = e(ll)

        * For groups, try multiple possible e() scalar names
        * Note: For mixed models, e(N_g) is a matrix (1x1), not a scalar
        capture {
            * Try as scalar first
            local stat_groups = e(N_g)
        }
        if `stat_groups' == . {
            * Try as matrix element (for mixed models)
            capture {
                tempname ng_mat
                matrix `ng_mat' = e(N_g)
                local stat_groups = `ng_mat'[1,1]
            }
        }
        if `stat_groups' == . {
            capture local stat_groups = e(k_g)
        }
        if `stat_groups' == . {
            * Try getting from N_clust (for xtlogit etc.)
            capture local stat_groups = e(N_clust)
        }
        if `stat_groups' == . {
            * For nbreg, poisson etc.
            capture local stat_groups = e(nrgroups)
        }

        * Try to get AIC/BIC directly first
        capture local stat_aic = e(aic)
        capture local stat_bic = e(bic)

        * If AIC/BIC not available, calculate from log-likelihood
        * AIC = -2*ll + 2*k
        * BIC = -2*ll + k*ln(N)
        if `stat_aic' == . & `stat_ll' != . {
            * Get number of parameters (k) from e(rank) or e(k)
            capture local stat_k = e(rank)
            if `stat_k' == . {
                capture local stat_k = e(k)
            }
            if `stat_k' == . {
                * Try to get from coefficient matrix
                capture {
                    matrix temp_b = e(b)
                    local stat_k = colsof(temp_b)
                }
            }
            if `stat_k' != . & `stat_ll' != . {
                local stat_aic = -2 * `stat_ll' + 2 * `stat_k'
            }
        }

        if `stat_bic' == . & `stat_ll' != . & `stat_N' != . {
            if `stat_k' == . {
                capture local stat_k = e(rank)
                if `stat_k' == . {
                    capture local stat_k = e(k)
                }
            }
            if `stat_k' != . {
                local stat_bic = -2 * `stat_ll' + `stat_k' * ln(`stat_N')
            }
        }

        * For ICC, calculate from variance components for mixed models
        * ICC = var(random intercept) / (var(random intercept) + var(residual))
        local stat_icc = .
        if `want_icc' == 1 {
            * Try to get ICC from stored e() matrices
            * For mixed/melogit/mepoisson, variance components are in e(b)
            * They are stored as log-std deviations that need to be exponentiated

            local var_re = ""
            local var_resid = ""

            capture {
                matrix temp_b = e(b)
                local colnames : colfullnames temp_b

                local col = 1
                foreach colname of local colnames {
                    if strpos("`colname'", "lns1_1_1:") {
                        local log_sd = temp_b[1,`col']
                        local var_re = exp(2 * `log_sd')
                    }
                    if strpos("`colname'", "lnsig_e:") {
                        local log_sd = temp_b[1,`col']
                        local var_resid = exp(2 * `log_sd')
                    }
                    local col = `col' + 1
                }
            }

            * Calculate ICC if we have both components
            if "`var_re'" != "" & "`var_resid'" != "" {
                local stat_icc = `var_re' / (`var_re' + `var_resid')
            }
        }
    }

    * =========================================================================
    * STORE RANDOM EFFECTS LABELS BEFORE COLLECT EXPORT (for relabel option)
    * =========================================================================
    local re_groupvar = ""
    local re_grouplbl = ""
    local re_vars = ""

    if "`relabel'" != "" {
        * Get grouping variable(s) and label(s) from e(ivars)
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
    }

collect label levels result _r_b "`coef'", modify
collect style cell result[_r_b], warn nformat(%4.2fc) halign(center) valign(center)
collect style cell result[_r_ci], warn nformat(%4.2fc) sformat("(%s)") cidelimiter("`sep'") halign(center) valign(center)
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

capture import excel "`temp_xlsx'", sheet(temp) clear
if _rc {
	noisily display as error "Failed to import temporary Excel file"
	capture erase "`temp_xlsx'"
	exit _rc
}
* Note: DO NOT TRIM WHITE SPACE--NEED IT FOR LEADING INDENT FOR CATEGORICAL VARIABLE

if "`noint'" != "" {
	drop if regexm(strlower(A), "^(intercept|_cons|constant)$")
}

if "`nore'" != "" {
	drop if strpos(A,"var(") > 0
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

ds
local varlist `r(varlist)'
local varlist = "_"+"`r(varlist)'"
local allvars: subinstr local varlist "_A B " "B ", all
local n 1
foreach var of local allvars{
rename `var' c`n'
replace c`n' = "" if _n == 1
local n `=`n'+1'
}
local n2 `=`n'-3'
local n `=`n'-1'

if "`models'" != "" {
    * Split models string by backslashes
	local models : subinstr local models " \ " "\", all
	local models : subinstr local models "\  " "\", all
	local models : subinstr local models "  \" "\", all
    tokenize "`models'", parse("\")
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
forvalues i = 1(3)`last'{
destring c`i', gen(c`i'z) force 
replace c`i'z = round(c`i'z, 0.01) 
tostring c`i'z, replace force format(%9.2f)
replace c`i' = "Reference" if inlist(c`i', "0", "1") & c`=`i'+1' == ""
replace c`i' = c`i'z if c`i'z != "." & c`i' != "Reference" & _n >= 3
drop c`i'z
capture confirm variable c`=`i'+1'
if _rc == 0 replace c`=`i'+1' = "" if _n == 1
capture confirm variable c`=`i'+2'
if _rc == 0 replace c`=`i'+2' = "" if _n == 1
}
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
    * Get number of data columns (excluding A)
    local data_cols = `n'

    * Track the first stats row (will be current N + 1 after title row adjustment)
    local stats_start_row = _N + 1

    * Add N row
    if `want_n' == 1 & `stat_N' != . {
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = "Observations" in `=`curr_n'+1'
        replace c1 = string(`stat_N', "%12.0fc") in `=`curr_n'+1'
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
    }

    * Add Groups row
    if `want_groups' == 1 & `stat_groups' != . {
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = "Groups" in `=`curr_n'+1'
        replace c1 = string(`stat_groups', "%12.0fc") in `=`curr_n'+1'
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
    }

    * Add AIC row
    if `want_aic' == 1 & `stat_aic' != . {
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = "AIC" in `=`curr_n'+1'
        replace c1 = string(`stat_aic', "%12.2f") in `=`curr_n'+1'
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
    }

    * Add BIC row
    if `want_bic' == 1 & `stat_bic' != . {
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = "BIC" in `=`curr_n'+1'
        replace c1 = string(`stat_bic', "%12.2f") in `=`curr_n'+1'
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
    }

    * Add Log-likelihood row
    if `want_ll' == 1 & `stat_ll' != . {
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = "Log-likelihood" in `=`curr_n'+1'
        replace c1 = string(`stat_ll', "%12.2f") in `=`curr_n'+1'
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
    }

    * Add ICC row
    if `want_icc' == 1 & `stat_icc' != . {
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = "ICC" in `=`curr_n'+1'
        replace c1 = string(`stat_icc', "%5.3f") in `=`curr_n'+1'
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
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
	* Ensure Excel file handle is closed on error
	capture mata: b.close_book()
	noisily display as error "Excel formatting failed with error `=_rc'"
	* Clean up temporary file
	capture erase "`temp_xlsx'"
	exit `=_rc'
}

* Apply putexcel formatting with error handling
capture {
	putexcel set "`xlsx'", sheet("`sheet'") modify
	local letterleft B
	local lettertwo C

	local n1 = mod(`num_cols' - 1, 26)
	local letterright = upper(char(65 + `n1'))
	if `num_cols' > 26 {
		local n2 = floor((`num_cols' - 1) / 26)
		if `n2' > 0 {
			local firstletter = upper(char(64 + `n2'))
			local letterright = "`firstletter'" + "`letterright'"
		}
	}
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
			col_to_letter `col_num'
			local col_letter = "`result'"

			col_to_letter `=`col_num'+1'
			local col_letter_next1 = "`result'"

			col_to_letter `=`col_num'+2'
			local col_letter_next2 = "`result'"

			putexcel (`col_letter'`row':`col_letter_next2'`row'), merge hcenter vcenter
			local col_num = `col_num' + 3
		}
	}
	*Merge Headers over models
	local col_num = 3
	while `col_num' <= `n' {
		col_to_letter `col_num'
		local col_letter = "`result'"

		col_to_letter `=`col_num'+1'
		local col_letter_next1 = "`result'"

		col_to_letter `=`col_num'+2'
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
	noisily display as error "Excel cell formatting failed with error `=_rc'"
	* Clean up temporary file
	capture erase "`temp_xlsx'"
	exit `=_rc'
}

collect clear

* Clean up temporary file
capture erase "`temp_xlsx'"

* Return statistics
return scalar N_rows = `num_rows'
return scalar N_cols = `num_cols'
}

end
*
