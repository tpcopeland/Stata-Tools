*! gcomptab Version 1.2.1  01mar2026
*! Format gcomp mediation analysis results for Excel export
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
DESCRIPTION:
	Formats gcomp (parametric g-formula for causal mediation) results into
	polished Excel tables. Exports point estimates, 95% CIs, and standard errors
	with professional formatting.

	gcomp is a user-written command for causal mediation analysis that uses
	Monte Carlo simulation to estimate total causal effects (TCE), natural direct
	effects (NDE), natural indirect effects (NIE), proportion mediated (PM),
	and controlled direct effects (CDE).

SYNTAX:
	gcomptab, xlsx(string) sheet(string) [ci(string) effect(string) title(string)
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
	Run gcomp first. gcomptab reads from global matrices left by gcomp:
	- b[1,N]          - point estimates (cols: TCE, NDE, NIE, PM, [CDE])
	- se[1,N]         - standard errors
	- ci_normal[2,N]  - normal CIs (row 1=lower, row 2=upper)
	- ci_percentile, ci_bc, ci_bca - alternative CI matrices

EXAMPLES:
	* After running gcomp
	gcomp ... , ... bootstrap(500)
	gcomptab, xlsx(results.xlsx) sheet("Mediation") title("Causal Mediation Analysis")

	* With percentile CIs
	gcomptab, xlsx(results.xlsx) sheet("Mediation") ci(percentile)

	* Custom labels for specific analysis
	gcomptab, xlsx(results.xlsx) sheet("Table 2") ///
	    labels("Total Effect \ Direct Effect \ Indirect Effect \ % Mediated") ///
	    title("Table 2. Mediation Analysis Results")
*/

program define gcomptab, rclass
	version 16.0
	set varabbrev off
	set more off

	syntax, xlsx(string) sheet(string) [ci(string) effect(string) title(string) ///
	        labels(string) decimal(integer 3)]

quietly {
	* =========================================================================
	* VALIDATION
	* =========================================================================

	* Check if gcomp mediation results exist in global matrices
	* gcomp posts to r() and global matrices (b, se, ci_normal, etc.)
	* not to e(). Global matrices persist across program calls.
	capture confirm matrix b
	local has_b = (_rc == 0)
	capture confirm matrix se
	local has_se = (_rc == 0)
	if !`has_b' | !`has_se' {
		noisily display as error "No gcomp mediation results found"
		noisily display as error "Run {bf:gcomp} with {bf:mediation} option first"
		exit 119
	}

	* Validate matrix dimensions: mediation produces 5 cols (TCE NDE NIE PM CDE)
	* or 4 cols without CDE
	local n_cols = colsof(b)
	if `n_cols' < 4 | `n_cols' > 5 {
		noisily display as error "Unexpected matrix dimensions from gcomp"
		noisily display as error "Expected 4-5 columns, found `n_cols'"
		exit 198
	}

	* Check if file name has .xlsx extension
	if !strmatch("`xlsx'", "*.xlsx") {
		noisily display as error "Excel filename must have .xlsx extension"
		exit 198
	}

	* Check for dangerous characters in file path
	_gcomptab_validate_path "`xlsx'" "xlsx()"
	_gcomptab_validate_path "`sheet'" "sheet()"

	* Set defaults
	if "`ci'" == "" local ci "normal"
	if "`effect'" == "" local effect "Estimate"

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
	* EXTRACT GCOMP RESULTS
	* =========================================================================

	* gcomp leaves global matrices with bootstrap column names (_bs_1, etc.)
	* Column order: 1=TCE, 2=NDE, 3=NIE, 4=PM, 5=CDE (if present)

	* Point estimates from global matrix b
	local tce = b[1, 1]
	local nde = b[1, 2]
	local nie = b[1, 3]
	local pm  = b[1, 4]
	if `n_cols' >= 5 {
		local cde = b[1, 5]
	}
	else {
		local cde = .
	}

	* Standard errors from global matrix se
	local se_tce = se[1, 1]
	local se_nde = se[1, 2]
	local se_nie = se[1, 3]
	local se_pm  = se[1, 4]
	if `n_cols' >= 5 {
		local se_cde = se[1, 5]
	}
	else {
		local se_cde = .
	}

	* Get confidence intervals from global matrix ci_<type>
	* gcomp CI matrices are 2 x N: row 1 = lower, row 2 = upper
	tempname ci_mat
	capture matrix `ci_mat' = ci_`ci'
	if _rc != 0 {
		noisily display as error "CI matrix ci_`ci' not found"
		noisily display as error "Available CI types depend on gcomp bootstrap options"
		exit 111
	}

	local ci_tce_lo = `ci_mat'[1, 1]
	local ci_tce_hi = `ci_mat'[2, 1]
	local ci_nde_lo = `ci_mat'[1, 2]
	local ci_nde_hi = `ci_mat'[2, 2]
	local ci_nie_lo = `ci_mat'[1, 3]
	local ci_nie_hi = `ci_mat'[2, 3]
	local ci_pm_lo  = `ci_mat'[1, 4]
	local ci_pm_hi  = `ci_mat'[2, 4]
	if `n_cols' >= 5 {
		local ci_cde_lo = `ci_mat'[1, 5]
		local ci_cde_hi = `ci_mat'[2, 5]
	}
	else {
		local ci_cde_lo = .
		local ci_cde_hi = .
	}

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
	tokenize `"`labels'"', parse("\")

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

	* Determine if CDE is available
	local has_cde = (`cde' != .)

	* Preserve current data
	preserve

	* Create dataset with results (include CDE row only if present)
	clear
	if `has_cde' {
		set obs 7
	}
	else {
		set obs 6
	}

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

	* Row 7: CDE (only if control() was specified)
	if `has_cde' {
		replace effect_label = "`lab5'" in 7
		replace estimate = string(`cde', "`fmt'") in 7
		replace ci_95 = "(" + string(`ci_cde_lo', "`fmt'") + ", " + string(`ci_cde_hi', "`fmt'") + ")" in 7
		replace se = string(`se_cde', "`fmt'") in 7
	}

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
		local saved_rc = _rc
		* Ensure Excel file handle is closed on error
		capture mata: b.close_book()
		noisily display as error "Excel formatting failed with error `saved_rc'"
		exit `saved_rc'
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
		local saved_rc = _rc
		noisily display as error "Excel cell formatting failed with error `saved_rc'"
		exit `saved_rc'
	}

	* Return statistics
	if `has_cde' {
		return scalar N_effects = 5
	}
	else {
		return scalar N_effects = 4
	}
	return scalar tce = `tce'
	return scalar nde = `nde'
	return scalar nie = `nie'
	return scalar pm = `pm'
	if `has_cde' {
		return scalar cde = `cde'
	}
}

end

* =============================================================================
* _gcomptab_validate_path: Validate file path for security
* =============================================================================

program _gcomptab_validate_path
	version 16.0
	set varabbrev off
	set more off
	args filepath option_name

	* Check for shell metacharacters and command injection vectors
	if regexm("`filepath'", "[;&|><\$\`]") {
		display as error "`option_name' contains invalid characters"
		exit 198
	}
end
*
