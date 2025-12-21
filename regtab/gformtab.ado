*! gformtab Version 1.0.1  21dec2025
*! Format gformula mediation analysis results for Excel export
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
DESCRIPTION:
	Formats gformula (parametric g-formula for causal mediation) results into
	polished Excel tables. Exports point estimates, 95% CIs, and standard errors
	with professional formatting.

	gformula is a user-written command for causal mediation analysis that uses
	Monte Carlo simulation to estimate total causal effects (TCE), natural direct
	effects (NDE), natural indirect effects (NIE), proportion mediated (PM),
	and controlled direct effects (CDE).

SYNTAX:
	gformtab, xlsx(string) sheet(string) [ci(string) effect(string) title(string)
	          labels(string) decimal(integer)]

	xlsx:    Required. Excel file name (requires .xlsx suffix)
	sheet:   Required. Excel sheet name
	ci:      CI type: normal, percentile, bc, or bca (default: normal)
	effect:  Label for effect column (default: "Effect")
	title:   Table title for cell A1
	labels:  Custom labels for effects, separated by backslash
	         (default: "TCE \ NDE \ NIE \ PM \ CDE")
	decimal: Decimal places for estimates (default: 3)

PREREQUISITES:
	Run gformula first. gformtab reads from r() scalars:
	- r(tce), r(nde), r(nie), r(pm), r(cde) - point estimates
	- r(se_tce), r(se_nde), r(se_nie), r(se_pm), r(se_cde) - standard errors

	And from matrices in memory:
	- ci_normal, ci_percentile, ci_bc, ci_bca - confidence intervals

EXAMPLES:
	* After running gformula
	gformula ... , ... bootstrap(500)
	gformtab, xlsx(results.xlsx) sheet("Mediation") title("Causal Mediation Analysis")

	* With percentile CIs
	gformtab, xlsx(results.xlsx) sheet("Mediation") ci(percentile)

	* Custom labels for specific analysis
	gformtab, xlsx(results.xlsx) sheet("Table 2") ///
	    labels("Total Effect \ Direct Effect \ Indirect Effect \ % Mediated") ///
	    title("Table 2. Mediation Analysis Results")
*/

capture program drop gformtab
capture program drop col_to_letter_gform

* Helper program to convert column number to Excel letter
program col_to_letter_gform
	version 16.0
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

program define gformtab, rclass
	version 16.0
	set varabbrev off

	syntax, xlsx(string) sheet(string) [ci(string) effect(string) title(string) ///
	        labels(string) decimal(integer 3)]

quietly {
	* =========================================================================
	* VALIDATION
	* =========================================================================

	* Check if gformula results exist in r()
	* gformula stores tce, nde, nie as key results
	local has_results = 0
	capture confirm scalar r(tce)
	if _rc == 0 {
		local has_results = 1
	}

	if `has_results' == 0 {
		noisily display as error "No gformula results found in r()"
		noisily display as error "Run gformula command first before using gformtab"
		exit 119
	}

	* Check if file name has .xlsx extension
	if !strmatch("`xlsx'", "*.xlsx") {
		noisily display as error "Excel filename must have .xlsx extension"
		exit 198
	}

	* Check for dangerous characters in file path
	if regexm("`xlsx'", "[;&|><\$\`]") {
		noisily display as error "Excel filename contains invalid characters"
		exit 198
	}
	if regexm("`sheet'", "[;&|><\$\`]") {
		noisily display as error "Sheet name contains invalid characters"
		exit 198
	}

	* Set defaults
	if "`ci'" == "" local ci "normal"
	if "`effect'" == "" local effect "Effect"

	* Validate ci option
	if !inlist("`ci'", "normal", "percentile", "bc", "bca") {
		noisily display as error "ci() must be normal, percentile, bc, or bca"
		exit 198
	}

	* Validate decimal option
	if `decimal' < 1 | `decimal' > 6 {
		noisily display as error "decimal() must be between 1 and 6"
		exit 198
	}

	return local xlsx "`xlsx'"
	return local sheet "`sheet'"
	return local ci "`ci'"

	* =========================================================================
	* EXTRACT GFORMULA RESULTS
	* =========================================================================

	* Store results from r() before they get cleared
	* Point estimates
	local tce = r(tce)
	local nde = r(nde)
	local nie = r(nie)
	local pm = r(pm)
	local cde = r(cde)

	* Standard errors
	local se_tce = r(se_tce)
	local se_nde = r(se_nde)
	local se_nie = r(se_nie)
	local se_pm = r(se_pm)
	local se_cde = r(se_cde)

	* Get confidence intervals from matrix
	local ci_matrix = "ci_`ci'"
	capture confirm matrix `ci_matrix'
	if _rc != 0 {
		* Try without underscore for "normal" -> "ci_normal"
		noisily display as error "CI matrix `ci_matrix' not found"
		noisily display as error "Available CI types depend on gformula bootstrap options"
		exit 111
	}

	* Extract CI bounds from matrix
	* gformula matrices are typically: rows = effects, cols = [lower, upper]
	matrix ci_mat = `ci_matrix'
	local ci_tce_lo = ci_mat[1,1]
	local ci_tce_hi = ci_mat[1,2]
	local ci_nde_lo = ci_mat[2,1]
	local ci_nde_hi = ci_mat[2,2]
	local ci_nie_lo = ci_mat[3,1]
	local ci_nie_hi = ci_mat[3,2]
	local ci_pm_lo = ci_mat[4,1]
	local ci_pm_hi = ci_mat[4,2]
	local ci_cde_lo = ci_mat[5,1]
	local ci_cde_hi = ci_mat[5,2]

	* =========================================================================
	* BUILD DATASET FOR EXPORT
	* =========================================================================

	* Set up labels
	if "`labels'" == "" {
		local labels "Total Causal Effect (TCE) \ Natural Direct Effect (NDE) \ Natural Indirect Effect (NIE) \ Proportion Mediated (PM) \ Controlled Direct Effect (CDE)"
	}

	* Parse labels
	local labels : subinstr local labels " \ " "\", all
	local labels : subinstr local labels "\  " "\", all
	local labels : subinstr local labels "  \" "\", all
	tokenize "`labels'", parse("\")

	local lab1 "`1'"
	local lab2 "`3'"
	local lab3 "`5'"
	local lab4 "`7'"
	local lab5 "`9'"

	* Default labels if not all provided
	if "`lab1'" == "" local lab1 "Total Causal Effect (TCE)"
	if "`lab2'" == "" local lab2 "Natural Direct Effect (NDE)"
	if "`lab3'" == "" local lab3 "Natural Indirect Effect (NIE)"
	if "`lab4'" == "" local lab4 "Proportion Mediated (PM)"
	if "`lab5'" == "" local lab5 "Controlled Direct Effect (CDE)"

	* Preserve current data
	preserve

	* Create dataset with results
	clear
	set obs 7

	* Create variables
	gen str100 title_col = ""
	gen str60 effect_label = ""
	gen str20 estimate = ""
	gen str30 ci_95 = ""
	gen str20 se = ""

	* Row 1: Title
	replace title_col = "`title'" in 1

	* Row 2: Headers
	replace effect_label = "Effect" in 2
	replace estimate = "`effect'" in 2
	replace ci_95 = "95% CI" in 2
	replace se = "SE" in 2

	* Format string based on decimals
	local fmt "%9.`decimal'f"

	* Row 3: TCE
	replace effect_label = "`lab1'" in 3
	replace estimate = string(`tce', "`fmt'") in 3
	replace ci_95 = "(" + string(`ci_tce_lo', "`fmt'") + ", " + string(`ci_tce_hi', "`fmt'") + ")" in 3
	replace se = string(`se_tce', "`fmt'") in 3

	* Row 4: NDE
	replace effect_label = "`lab2'" in 4
	replace estimate = string(`nde', "`fmt'") in 4
	replace ci_95 = "(" + string(`ci_nde_lo', "`fmt'") + ", " + string(`ci_nde_hi', "`fmt'") + ")" in 4
	replace se = string(`se_nde', "`fmt'") in 4

	* Row 5: NIE
	replace effect_label = "`lab3'" in 5
	replace estimate = string(`nie', "`fmt'") in 5
	replace ci_95 = "(" + string(`ci_nie_lo', "`fmt'") + ", " + string(`ci_nie_hi', "`fmt'") + ")" in 5
	replace se = string(`se_nie', "`fmt'") in 5

	* Row 6: PM
	replace effect_label = "`lab4'" in 6
	replace estimate = string(`pm', "`fmt'") in 6
	replace ci_95 = "(" + string(`ci_pm_lo', "`fmt'") + ", " + string(`ci_pm_hi', "`fmt'") + ")" in 6
	replace se = string(`se_pm', "`fmt'") in 6

	* Row 7: CDE
	replace effect_label = "`lab5'" in 7
	replace estimate = string(`cde', "`fmt'") in 7
	replace ci_95 = "(" + string(`ci_cde_lo', "`fmt'") + ", " + string(`ci_cde_hi', "`fmt'") + ")" in 7
	replace se = string(`se_cde', "`fmt'") in 7

	* Handle missing values (display as blank)
	* For estimate and se: blank if equals "." (missing value string)
	replace estimate = "" if estimate == "."
	replace se = "" if se == "."
	* For CI: blank only if it contains actual missing values (pattern like "(    .,     .)")
	* This checks for the pattern where numeric missing "." appears after opening paren
	* or before the comma, indicating gformula returned missing bounds
	replace ci_95 = "" if regexm(ci_95, "^\([[:space:]]*\.[[:space:]]*,") | regexm(ci_95, ",[[:space:]]*\.[[:space:]]*\)$")

	* =========================================================================
	* EXPORT TO EXCEL
	* =========================================================================

	capture export excel using "`xlsx'", sheet("`sheet'") sheetreplace
	if _rc {
		noisily display as error "Failed to export to `xlsx', sheet `sheet'"
		noisily display as error "Check file permissions and that file is not open in Excel"
		restore
		exit _rc
	}

	local num_rows = _N
	local num_cols = 5

	* Calculate column widths
	gen len_label = length(effect_label)
	gen len_est = length(estimate)
	gen len_ci = length(ci_95)
	gen len_se = length(se)

	sum len_label
	local label_width = max(`r(max)', 15)
	sum len_ci
	local ci_width = max(`r(max)', 15)

	drop len_*

	restore

	* =========================================================================
	* APPLY EXCEL FORMATTING (MATA)
	* =========================================================================

	capture {
		mata: b = xl()
		mata: b.load_book("`xlsx'")
		mata: b.set_sheet("`sheet'")
		mata: b.set_row_height(1,1,30)
		mata: b.set_column_width(1,1,3)
		mata: b.set_column_width(2,2,`=`label_width'*0.9')
		mata: b.set_column_width(3,3,12)
		mata: b.set_column_width(4,4,`=`ci_width'*0.85')
		mata: b.set_column_width(5,5,10)
		mata: b.close_book()
	}
	if _rc {
		* Ensure Excel file handle is closed on error
		capture mata: b.close_book()
		noisily display as error "Excel formatting failed with error `=_rc'"
		exit `=_rc'
	}

	* =========================================================================
	* APPLY PUTEXCEL FORMATTING
	* =========================================================================

	capture {
		putexcel set "`xlsx'", sheet("`sheet'") modify

		* Title row
		putexcel (A1:E1), merge txtwrap left top bold

		* Header row formatting
		putexcel (B2:E2), bold border(bottom, thin)

		* Table borders
		putexcel (B2:E`num_rows'), border(left, thin)
		putexcel (B2:E`num_rows'), border(right, thin)
		putexcel (B2:B`num_rows'), border(right, thin)
		putexcel (B`num_rows':E`num_rows'), border(bottom, thin)
		putexcel (B2:E2), border(top, thin)

		* Center data columns
		putexcel (C3:E`num_rows'), hcenter

		* Font
		putexcel (A1:E`num_rows'), font(Arial, 10)

		putexcel clear
	}
	if _rc {
		noisily display as error "Excel cell formatting failed with error `=_rc'"
		exit `=_rc'
	}

	* Return statistics
	return scalar N_effects = 5
	return scalar tce = `tce'
	return scalar nde = `nde'
	return scalar nie = `nie'
	return scalar pm = `pm'
	return scalar cde = `cde'
}

end
*
