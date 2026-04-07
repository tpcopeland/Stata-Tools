*! gcomptab Version 1.0.0  2026/04/08
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
	          labels(string) decimal(integer) font(string) fontsize(integer)
	          borderstyle(string) zebra footnote(string) open boldp(real)
	          highlight(real)]

	xlsx:    Required. Excel file name (requires .xlsx suffix)
	sheet:   Required. Excel sheet name
	ci:      CI type: normal, percentile, bc, or bca (default: normal)
	effect:  Label for effect column (default: "Estimate")
	title:   Table title for cell A1
	labels:  Custom labels for effects, separated by backslash
	         (default: "TCE \ NDE \ NIE \ PM \ CDE")
	decimal: Decimal places for estimates (default: 3)

PREREQUISITES:
	Run gcomp first. gcomptab reads from e() results posted by gcomp:
	- e(b)[1,N]          - point estimates (cols: tce, nde, nie, pm, [cde])
	- e(se)[1,N]         - standard errors
	- e(ci_normal)[2,N]  - normal CIs (row 1=lower, row 2=upper)
	- e(ci_percentile), e(ci_bc), e(ci_bca) - alternative CI matrices
	- e(cmd) == "gcomp", e(analysis_type) == "mediation"

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
	local _gc_varabbrev = c(varabbrev)
	set varabbrev off

capture noisily {

	syntax, xlsx(string) sheet(string) [ci(string) effect(string) title(string) ///
	        labels(string) decimal(integer 3) Font(string) FONTSize(integer 10) ///
	        BORDERstyle(string) ZEBRA FOOTnote(string) OPEN BOLDp(real 0) ///
	        HIGHlight(real 0)]

quietly {
	* =========================================================================
	* VALIDATION
	* =========================================================================

	* Check that gcomp mediation e() results exist
	if "`e(cmd)'" != "gcomp" {
		noisily display as error "No gcomp mediation results found"
		noisily display as error "Run {bf:gcomp} with {bf:mediation} option first"
		exit 119
	}
	if "`e(analysis_type)'" != "mediation" {
		noisily display as error "gcomp results are not from a mediation analysis"
		noisily display as error "Run {bf:gcomp} with {bf:mediation} option"
		exit 119
	}
	if "`e(mediation_type)'" == "oce" {
		noisily display as error "gcomptab does not support oce mediation results"
		noisily display as error "Use obe, linexp, or specific mediation type instead"
		exit 198
	}

	* Verify e(b) matrix exists with expected dimensions
	capture confirm matrix e(b)
	if _rc != 0 {
		noisily display as error "No gcomp mediation results found"
		noisily display as error "Run {bf:gcomp} with {bf:mediation} option first"
		exit 119
	}
	tempname _eb _ese
	matrix `_eb' = e(b)
	local n_cols = colsof(`_eb')
	if `n_cols' < 4 | `n_cols' > 5 {
		noisily display as error "Unexpected matrix dimensions from gcomp"
		noisily display as error "Expected 4-5 columns, found `n_cols'"
		exit 198
	}

	* Verify e(se) matrix exists
	capture confirm matrix e(se)
	if _rc != 0 {
		noisily display as error "No standard error matrix found in gcomp results"
		exit 119
	}
	matrix `_ese' = e(se)

	* Check if file name has .xlsx extension
	if !strmatch("`xlsx'", "*.xlsx") {
		noisily display as error "Excel filename must have .xlsx extension"
		exit 198
	}

	* Check for dangerous characters in file path
	_gcomp_validate_path "`xlsx'" "xlsx()"
	_gcomp_validate_path "`sheet'" "sheet()"
	_gcomp_xl_validate_sheet "`sheet'" "sheet()"

	* Set defaults
	if "`ci'" == "" local ci "normal"
	if "`effect'" == "" local effect "Estimate"
	if "`font'" == "" local font "Arial"
	if "`borderstyle'" == "" local borderstyle "academic"
	local _hborder = cond("`borderstyle'" == "academic", "medium", "`borderstyle'")

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

	* Validate borderstyle option
	if !inlist("`borderstyle'", "academic", "thin", "medium") {
		noisily display as error "borderstyle() must be academic, thin, or medium"
		exit 198
	}

	* Validate boldp
	if `boldp' != 0 & (`boldp' <= 0 | `boldp' >= 1) {
		noisily display as error "boldp() must be between 0 and 1"
		exit 198
	}

	* Validate highlight
	if `highlight' != 0 & (`highlight' <= 0 | `highlight' >= 1) {
		noisily display as error "highlight() must be between 0 and 1"
		exit 198
	}

	return local xlsx "`xlsx'"
	return local sheet "`sheet'"
	return local ci "`ci'"

	* =========================================================================
	* EXTRACT GCOMP RESULTS
	* =========================================================================

	* Extract point estimates from e(b) using named column lookups
	* Guard: verify expected columns exist
	foreach _col in tce nde nie pm {
		if colnumb(`_eb', "`_col'") == . {
			noisily display as error "e(b) matrix missing expected column '`_col''"
			noisily display as error "gcomp results may be from an incompatible version"
			exit 198
		}
	}
	local tce = `_eb'[1, colnumb(`_eb', "tce")]
	local nde = `_eb'[1, colnumb(`_eb', "nde")]
	local nie = `_eb'[1, colnumb(`_eb', "nie")]
	local pm  = `_eb'[1, colnumb(`_eb', "pm")]
	if `n_cols' >= 5 {
		local cde = `_eb'[1, colnumb(`_eb', "cde")]
	}
	else {
		local cde = .
	}

	* Standard errors from e(se) matrix
	local se_tce = `_ese'[1, colnumb(`_ese', "tce")]
	local se_nde = `_ese'[1, colnumb(`_ese', "nde")]
	local se_nie = `_ese'[1, colnumb(`_ese', "nie")]
	local se_pm  = `_ese'[1, colnumb(`_ese', "pm")]
	if `n_cols' >= 5 {
		local se_cde = `_ese'[1, colnumb(`_ese', "cde")]
	}
	else {
		local se_cde = .
	}

	* Get confidence intervals from e(ci_<type>) matrix
	* gcomp CI matrices are 2 x N: row 1 = lower, row 2 = upper
	tempname ci_mat
	capture matrix `ci_mat' = e(ci_`ci')
	if _rc != 0 {
		noisily display as error "CI matrix ci_`ci' not found"
		noisily display as error "Available CI types depend on gcomp bootstrap options"
		exit 111
	}

	local ci_tce_lo = `ci_mat'[1, colnumb(`ci_mat', "tce")]
	local ci_tce_hi = `ci_mat'[2, colnumb(`ci_mat', "tce")]
	local ci_nde_lo = `ci_mat'[1, colnumb(`ci_mat', "nde")]
	local ci_nde_hi = `ci_mat'[2, colnumb(`ci_mat', "nde")]
	local ci_nie_lo = `ci_mat'[1, colnumb(`ci_mat', "nie")]
	local ci_nie_hi = `ci_mat'[2, colnumb(`ci_mat', "nie")]
	local ci_pm_lo  = `ci_mat'[1, colnumb(`ci_mat', "pm")]
	local ci_pm_hi  = `ci_mat'[2, colnumb(`ci_mat', "pm")]
	if `n_cols' >= 5 {
		local ci_cde_lo = `ci_mat'[1, colnumb(`ci_mat', "cde")]
		local ci_cde_hi = `ci_mat'[2, colnumb(`ci_mat', "cde")]
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

	* Compute p-values for boldp/highlight (Wald test: p = 2*normal(-|z|))
	local p_tce = 2 * normal(-abs(`tce' / `se_tce'))
	local p_nde = 2 * normal(-abs(`nde' / `se_nde'))
	local p_nie = 2 * normal(-abs(`nie' / `se_nie'))
	local p_pm  = 2 * normal(-abs(`pm' / `se_pm'))
	if `has_cde' {
		local p_cde = 2 * normal(-abs(`cde' / `se_cde'))
	}
	else {
		local p_cde = .
	}

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
	replace title_col = `"`title'"' in 1

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
	gen len_ci = length(ci_95)

	quietly summarize len_label
	local label_width = max(`r(max)', 15)
	quietly summarize len_ci
	local ci_width = max(`r(max)', 15)

	drop len_*

	* Store raw p-values in locals indexed by Excel row for boldp/highlight
	local _pval_3 = `p_tce'
	local _pval_4 = `p_nde'
	local _pval_5 = `p_nie'
	local _pval_6 = `p_pm'
	if `has_cde' {
		local _pval_7 = `p_cde'
	}

	* =========================================================================
	* APPLY EXCEL FORMATTING (MATA)
	* =========================================================================

	* Determine last column letter
	_gcomp_col_letter `num_cols'
	local lastcol "`result'"

	* Mata: column widths + numeric conversion (dataset still in memory)
	capture {
		mata: b = xl()
		mata: b.load_book("`xlsx'")
		mata: b.set_sheet("`sheet'")
		mata: b.set_row_height(1, 1, 30)
		mata: b.set_column_width(1, 1, 1)
		mata: b.set_column_width(2, 2, `=`label_width' * 0.9')
		mata: b.set_column_width(3, 3, 12)
		mata: b.set_column_width(4, 4, `=`ci_width' * 0.85')
		mata: b.set_column_width(5, 5, 10)

		* Convert string cells to proper Excel numbers
		* Variables: title_col(1) effect_label(2) estimate(3) ci_95(4) se(5)
		local _varlist "title_col effect_label estimate ci_95 se"
		forvalues _r = 3/`num_rows' {
			forvalues _c = 3/`num_cols' {
				local _vname : word `_c' of `_varlist'
				local _cellstr = `_vname'[`_r']
				if `"`_cellstr'"' == "" | `"`_cellstr'"' == "." continue
				if strpos(`"`_cellstr'"', "(") > 0 continue
				if strpos(`"`_cellstr'"', "%") > 0 continue
				if strpos(`"`_cellstr'"', "<") > 0 continue
				if `"`_cellstr'"' == "(omitted)" continue
				local _cellclean = subinstr(`"`_cellstr'"', ",", "", .)
				local _cellnum = real("`_cellclean'")
				if `_cellnum' != . {
					mata: b.put_number(`_r', `_c', `_cellnum')
				}
			}
		}

		mata: b.close_book()
	}
	if _rc {
		local saved_rc = _rc
		* Ensure Excel file handle is closed on error
		capture mata: b.close_book()
		capture mata: mata drop b
		noisily display as error "Excel formatting failed with error `saved_rc'"
		restore
		exit `saved_rc'
	}
	capture mata: mata drop b

	restore

	* =========================================================================
	* APPLY PUTEXCEL FORMATTING
	* =========================================================================

	capture {
		putexcel set "`xlsx'", sheet("`sheet'") modify

		* Title row
		putexcel (A1:`lastcol'1), merge txtwrap left vcenter bold
		putexcel (A1:`lastcol'1), font("`font'", `=`fontsize' + 2')

		* Header row formatting
		putexcel (B2:`lastcol'2), bold hcenter font("`font'", `fontsize')
		putexcel (B2:`lastcol'2), border(top, `_hborder')
		putexcel (B2:`lastcol'2), border(bottom, `_hborder')
		putexcel (B2:`lastcol'2), fpattern(solid, "219 229 241")

		* Body font
		putexcel (B3:`lastcol'`num_rows'), font("`font'", `fontsize')

		* Bottom border on last data row
		putexcel (B`num_rows':`lastcol'`num_rows'), border(bottom, `_hborder')

		* Vertical borders (skip for academic)
		if "`borderstyle'" != "academic" {
			putexcel (B2:`lastcol'`num_rows'), border(left, `_hborder')
			putexcel (B2:`lastcol'`num_rows'), border(right, `_hborder')
		}

		* Center data columns
		putexcel (C3:`lastcol'`num_rows'), hcenter

		* Zebra striping on alternating data rows
		if "`zebra'" != "" {
			forvalues _zr = 4(2)`num_rows' {
				putexcel (B`_zr':`lastcol'`_zr'), fpattern(solid, "237 242 249")
			}
		}

		* Bold p-value cells where p < threshold
		if `boldp' > 0 {
			forvalues _br = 3/`num_rows' {
				if `_pval_`_br'' < . & `_pval_`_br'' < `boldp' {
					putexcel (C`_br':`lastcol'`_br'), bold
				}
			}
		}

		* Highlight rows where p < threshold
		if `highlight' > 0 {
			forvalues _hr = 3/`num_rows' {
				if `_pval_`_hr'' < . & `_pval_`_hr'' < `highlight' {
					putexcel (B`_hr':`lastcol'`_hr'), fpattern(solid, "255 255 204")
				}
			}
		}

		* Footnote
		local _fn_row = `num_rows'
		if `"`footnote'"' != "" {
			_gcomp_xl_footnote `"`footnote'"' "`lastcol'" `_fn_row' "`font'" `fontsize'
		}

		putexcel clear
	}
	if _rc {
		local saved_rc = _rc
		capture putexcel clear
		noisily display as error "Excel cell formatting failed with error `saved_rc'"
		exit `saved_rc'
	}

	* Open file if requested
	if "`open'" != "" {
		_gcomp_xl_open "`xlsx'"
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
} /* end capture noisily */
local _gc_rc = _rc
set varabbrev `_gc_varabbrev'
if `_gc_rc' exit `_gc_rc'

end
*
