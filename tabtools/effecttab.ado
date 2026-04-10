*! effecttab Version 1.0.1  2026/04/09
*! Format treatment effects and margins results for Excel export
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
DESCRIPTION:
	Formats treatment effects (teffects) and margins results into polished Excel
	tables. Exports point estimate, 95% CI, and p-value with professional formatting.
	Designed for causal inference workflows including IPTW, g-computation, and
	marginal effects.

SYNTAX:
	effecttab, xlsx(string) sheet(string) [type(string) effect(string) models(string)
	           sep(string asis) title(string) clean tlabels(string asis)]

	xlsx:    Required. Excel file name (requires .xlsx suffix)
	sheet:   Required. Excel sheet name
	type:    Type of results: teffects, margins, or auto (default: auto)
	effect:  Label for effect column (e.g., ATE, RD, RR, AME). Default varies by type.
	models:  Label models, separating names with backslash (e.g., Model 1 \ Model 2)
	sep:     Character separating 95% CI bounds (default: ", ")
	title:   Table title for cell A1
	clean:   Clean up teffects row labels. Automatically uses value labels from the
	         treatment variable when available (e.g., "r1vs0.treated" → "SNRI vs SSRI").
	         Falls back to basic cleanup if no value labels exist.
	tlabels: Explicit treatment level labels as value-label pairs. Implies clean.
	         Example: tlabels(0 "SSRI" 1 "SNRI") → ATE row becomes "SNRI vs SSRI"

SUPPORTED COMMANDS:
	- teffects ipw, teffects ra, teffects aipw, teffects ipwra
	- teffects psmatch, teffects nnmatch
	- margins (with or without post option)
	- margins with dydx(), over(), at() options

EXAMPLES:
	* IPTW treatment effect
	teffects ipw (outcome) (treatment age sex), ate
	effecttab, xlsx(results.xlsx) sheet("ATE") effect("ATE") title("Treatment Effect")

	* Margins for predicted probabilities
	logit outcome i.treatment age sex
	margins treatment
	effecttab, xlsx(results.xlsx) sheet("Margins") type(margins) effect("Pr(Y)")

	* G-computation style marginal effects
	logit outcome i.treatment##c.age sex
	margins, dydx(treatment)
	effecttab, xlsx(results.xlsx) sheet("Effects") effect("AME")
*/

program define effecttab, rclass
	version 17.0
	local _prev_varabbrev = c(varabbrev)
	set varabbrev off

	* Auto-load shared helper programs if not already in memory
	capture program list _tabtools_validate_path
	if _rc {
		capture findfile _tabtools_common.ado
		if _rc == 0 {
			run "`r(fn)'"
		}
		else {
			display as error "_tabtools_common.ado not found; reinstall tabtools"
			set varabbrev `_prev_varabbrev'
			exit 111
		}
	}

	capture noisily {

	syntax, [xlsx(string) excel(string) sheet(string)] [sep(string asis) type(string) effect(string) ///
	        models(string) title(string) SUBTitle(string) clean TLABels(string asis) ///
	        FOOTnote(string) open zebra HIGHlight(real -1) BOLDp(real -1) ///
	        BORDERStyle(string) full THEme(string) digits(integer -1) ///
	        HEADERColor(string) ZEBRAColor(string) csv(string) FRAme(string) DISPlay ///
	        FROM(name) ADDRow(string asis) pdp(integer -1) highpdp(integer -1)]

	* Accept excel() as synonym for xlsx()
	if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
	local _has_xlsx = "`xlsx'" != ""
	if "`sheet'" == "" local sheet "Effects"

	* Resolve persistent defaults
	if `digits' == -1 {
		if "$TABTOOLS_DIGITS" != "" local digits = $TABTOOLS_DIGITS
		else local digits = 2
	}
	if `boldp' == -1 & "$TABTOOLS_BOLDP" != "" local boldp = $TABTOOLS_BOLDP
	if `pdp' == -1 local pdp = 3
	if `highpdp' == -1 local highpdp = 2

	* Validate sheet name for Excel constraints
	_tabtools_validate_sheet "`sheet'" "sheet()"

quietly {
	* =========================================================================
	* VALIDATION
	* =========================================================================

	* Check if from() matrix or collect table
	local _from_matrix = "`from'" != ""
	if !`_from_matrix' {
		capture quietly collect query row
		if _rc {
			noisily display as error "No active collect table found"
			noisily display as error "Run teffects or margins with {bf:collect:} prefix first"
			noisily display as error "Hint: {bf:collect clear} then {bf:collect: teffects ipw ...}"
			noisily display as error "Or use from(matrix_name) to pass a matrix directly"
			exit 119
		}
	}

	* Check xlsx if specified
	if `_has_xlsx' {
		if !strmatch("`xlsx'", "*.xlsx") {
			noisily display as error "Excel filename must have .xlsx extension"
			exit 198
		}
		_tabtools_validate_path "`xlsx'" "xlsx()"
	}
	_tabtools_validate_path "`sheet'" "sheet()"

	* Validate highlight
	local has_highlight = `highlight' != -1
	if `has_highlight' & (`highlight' <= 0 | `highlight' >= 1) {
		noisily display as error "highlight() must be between 0 and 1"
		exit 198
	}

	* Validate boldp
	local has_boldp = `boldp' != -1
	if `has_boldp' & (`boldp' <= 0 | `boldp' >= 1) {
		noisily display as error "boldp() must be between 0 and 1"
		exit 198
	}

	* Validate digits range
	if `digits' < 0 | `digits' > 6 {
		noisily display as error "digits() must be between 0 and 6"
		exit 198
	}

	* Build format strings from digits
	local coef_fmt "%9.`digits'f"
	local coef_round = 10^(-`digits')

	* Resolve formatting
	_tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle')
	if !inlist("`borderstyle'", "thin", "medium", "academic") {
		noisily display as error "borderstyle() must be thin, medium, or academic"
		exit 198
	}

	* Resolve header/zebra colors (O4)
	local _headercolor "219 229 241"
	local _zebracolor "237 242 249"
	if "$TABTOOLS_HEADERCOLOR" != "" local _headercolor "$TABTOOLS_HEADERCOLOR"
	if "$TABTOOLS_ZEBRACOLOR" != "" local _zebracolor "$TABTOOLS_ZEBRACOLOR"
	if "`headercolor'" != "" local _headercolor "`headercolor'"
	if "`zebracolor'" != "" local _zebracolor "`zebracolor'"

	* Set defaults
	if `"`sep'"' == "" local sep ", "
	if "`type'" == "" local type "auto"

	* Validate type option
	if !inlist("`type'", "auto", "teffects", "margins") {
		noisily display as error "type() must be auto, teffects, or margins"
		exit 198
	}

	* Create temporary file for intermediate processing
	* Note: tempfile on Unix creates paths like /tmp/StXXXXX.XXXXXX without .tmp
	* We append .xlsx to ensure a valid Excel file path
	tempfile temp_export
	local temp_xlsx "`temp_export'.xlsx"

	* =========================================================================
	* AUTO-DETECT RESULT TYPE
	* =========================================================================

	if "`type'" == "auto" {
		* Check e(cmd) to detect teffects vs margins
		* After teffects, e(cmd) = "teffects"
		* After margins, e(cmd) = the underlying model (logit, probit, etc.)
		local ecmd "`e(cmd)'"

		if "`ecmd'" == "teffects" {
			local type "teffects"
		}
		else {
			local type "margins"
		}
	}

	* Return input/detected values
	if `_has_xlsx' return local xlsx "`xlsx'"
	return local sheet "`sheet'"
	return local type "`type'"

	* Set default effect label based on type
	if "`effect'" == "" {
		if "`type'" == "teffects" {
			local effect "Effect"
		}
		else {
			local effect "Estimate"
		}
	}

	* =========================================================================
	* CAPTURE TREATMENT LABELS (before import clears data)
	* =========================================================================

	* tlabels() implies clean
	if `"`tlabels'"' != "" local clean "clean"

	local has_vlabels = 0
	local tlevels ""
	local tvar ""
	local tvarlabel ""

	* Always capture treatment variable info for teffects (needed for row filtering)
	* The clean option controls label relabeling; filtering is always applied
	if "`type'" == "teffects" {
		local tvar "`e(tvar)'"

		if "`clean'" != "" & `"`tlabels'"' != "" {
			* Parse user-provided tlabels: 0 "SSRI" 1 "SNRI"
			local tl_rest `"`tlabels'"'
			while `"`tl_rest'"' != "" {
				gettoken tl_val tl_rest : tl_rest
				gettoken tl_lab tl_rest : tl_rest
				if "`tl_val'" != "" & `"`tl_lab'"' != "" {
					local tlab_`tl_val' `"`tl_lab'"'
					local has_vlabels = 1
				}
			}
		}
		else if "`clean'" != "" & "`tvar'" != "" {
			* Auto-detect from value labels on treatment variable
			capture confirm variable `tvar'
			if _rc == 0 {
				local vallabname : value label `tvar'
				if "`vallabname'" != "" {
					levelsof `tvar', local(tlevels)
					foreach lev of local tlevels {
						local lab : label `vallabname' `lev'
						* Only use if label differs from numeric value
						if "`lab'" != "`lev'" {
							local tlab_`lev' `"`lab'"'
							local has_vlabels = 1
						}
					}
				}
			}
		}

		* Capture treatment levels and variable label while data is in memory
		if "`tvar'" != "" {
			if "`tlevels'" == "" {
				capture confirm variable `tvar'
				if _rc == 0 {
					levelsof `tvar', local(tlevels)
				}
			}
			capture {
				local tvarlabel : variable label `tvar'
			}
			if "`tvarlabel'" == "" local tvarlabel "`tvar'"
			* Capitalize and clean variable label for display
			local tvarlabel = upper(substr("`tvarlabel'", 1, 1)) + substr("`tvarlabel'", 2, .)
			local tvarlabel = subinstr("`tvarlabel'", "_", " ", .)
		}
	}

	* =========================================================================
	* CONFIGURE COLLECT LAYOUT
	* =========================================================================

	* Apply formatting to result items
	collect label levels result _r_b "`effect'", modify
	collect style cell result[_r_b], warn nformat(%`=`digits'+2'.`digits'fc) halign(center) valign(center)
	collect style cell result[_r_ci], warn nformat(%`=`digits'+3'.`digits'fc) sformat("(%s)") ///
	        cidelimiter("`sep'") halign(center) valign(center)
	collect style cell result[_r_p], warn nformat(%5.4f) halign(center) valign(center)
	collect style column, dups(center)
	collect style row stack, nodelimiter nospacer indent length(.) ///
	        wrapon(word) noabbreviate wrap(.) truncate(tail)

	* Set layout based on type
	* Both teffects and margins use colname for row dimension
	* Multiple models (cmdset) go on columns

	* Build colname filter for teffects: only ATE/POmean rows (not PS model)
	* This suppresses nuisance parameters (propensity score model coefficients)
	* that appear in IPW/AIPW/IPWRA results. Use full option to show everything.
	local _colname_filter ""
	if "`type'" == "teffects" & "`full'" == "" & "`tvar'" != "" & "`tlevels'" != "" {
		local base : word 1 of `tlevels'
		* Add ATE comparison rows: r{lev}vs{base}.{tvar}
		foreach lev of local tlevels {
			if "`lev'" != "`base'" {
				local _colname_filter "`_colname_filter' r`lev'vs`base'.`tvar'"
			}
		}
		* Add POmean rows: {lev}.{tvar}
		foreach lev of local tlevels {
			local _colname_filter "`_colname_filter' `lev'.`tvar'"
		}
	}

	* Note: collect levelsof cmdset returns r(levels) as empty even when cmdset
	* has levels (Stata quirk). So we try multi-model layout first regardless.

	* Set layout - ALWAYS try multi-model first since r(levels) is unreliable
	local layout_ok = 0

	if "`_colname_filter'" != "" {
		* Filtered layout for teffects: only ATE/POmean rows
		capture collect layout (colname[`_colname_filter']) (cmdset#result[_r_b _r_ci _r_p])
		if _rc == 0 {
			local layout_ok = 1
		}
		if `layout_ok' == 0 {
			capture collect layout (colname[`_colname_filter']) (result[_r_b _r_ci _r_p])
			if _rc == 0 local layout_ok = 1
		}
	}

	if `layout_ok' == 0 {
		* Try multi-model layout with cmdset dimension
		capture collect layout (colname) (cmdset#result[_r_b _r_ci _r_p])
		if _rc == 0 {
			local layout_ok = 1
		}
	}

	if `layout_ok' == 0 {
		* Try single model layout (for cases with only one model)
		capture collect layout (colname) (result[_r_b _r_ci _r_p])
		if _rc == 0 {
			local layout_ok = 1
		}
	}

	if `layout_ok' == 0 {
		* Try generic layout without result specification
		capture collect layout (colname) (result)
		if _rc == 0 {
			local layout_ok = 1
		}
	}

	if `layout_ok' == 0 {
		noisily display as error "Could not set collect layout"
		noisily display as error "Check that teffects/margins results are in the collection"
		exit 198
	}

	* =========================================================================
	* APPLY TREATMENT LABELS TO COLLECT TABLE
	* =========================================================================

	local _ate_keep ""
	if "`clean'" != "" & "`type'" == "teffects" & "`tlevels'" != "" {
		local base : word 1 of `tlevels'

		* Relabel ATE/ATET comparison rows (rXvsBase.varname)
		foreach lev of local tlevels {
			if "`lev'" != "`base'" {
				if `has_vlabels' {
					local lab_lev `"`tlab_`lev''"'
					local lab_base `"`tlab_`base''"'
					if `"`lab_lev'"' != "" & `"`lab_base'"' != "" {
						capture collect label levels colname ///
							r`lev'vs`base'.`tvar' ///
							`"`lab_lev' vs `lab_base'"', modify
						local _ate_keep `"`_ate_keep' `"`lab_lev' vs `lab_base'"'"'
					}
				}
				else {
					* No value labels: use variable label + numbers
					capture collect label levels colname ///
						r`lev'vs`base'.`tvar' ///
						"`tvarlabel' (`lev' vs `base')", modify
					local _ate_keep `"`_ate_keep' "`tvarlabel' (`lev' vs `base')""'
				}
				local _ate_keep `"`_ate_keep' "r`lev'vs`base'.`tvar'""'
			}
		}

		* Relabel POmean rows (level.varname)
		foreach lev of local tlevels {
			if `has_vlabels' {
				local lab_lev `"`tlab_`lev''"'
				if `"`lab_lev'"' != "" {
					capture collect label levels colname ///
						`lev'.`tvar' ///
						`"`lab_lev' (PO Mean)"', modify
					local _ate_keep `"`_ate_keep' `"`lab_lev' (PO Mean)"'"'
				}
			}
			else {
				* No value labels: use variable label + number
				capture collect label levels colname ///
					`lev'.`tvar' ///
					"`tvarlabel' = `lev' (PO Mean)", modify
				local _ate_keep `"`_ate_keep' "`tvarlabel' = `lev' (PO Mean)""'
			}
			local _ate_keep `"`_ate_keep' "`lev'.`tvar'""'
		}
	}

	* =========================================================================
	* EXPORT AND IMPORT FOR PROCESSING
	* =========================================================================

	if `_from_matrix' {
		* Build dataset directly from input matrix
		* Matrix must have columns: estimate, ci_lower, ci_upper, pvalue
		preserve
		local _nrows = rowsof(`from')
		local _ncols = colsof(`from')
		if `_ncols' < 4 {
			noisily display as error "from() matrix must have at least 4 columns (estimate, ci_lower, ci_upper, pvalue)"
			exit 198
		}
		clear
		qui set obs `=`_nrows'+2'
		* Create columns: A (label), c1 (estimate), c2 (CI), c3 (p-value)
		qui gen str244 A = ""
		qui gen str244 c1 = ""
		qui gen str244 c2 = ""
		qui gen str244 c3 = ""
		* Row 1: title-level placeholder
		qui replace A = "" in 1
		* Row 2: headers
		if "`effect'" == "" local effect "Effect"
		qui replace A = "" in 2
		qui replace c1 = "`effect'" in 2
		qui replace c2 = "(95% CI)" in 2
		qui replace c3 = "p" in 2
		* Data rows
		local _rnames : rownames `from'
		forvalues _fr = 1/`_nrows' {
			local _obs = `_fr' + 2
			local _rn : word `_fr' of `_rnames'
			local _rn = subinstr("`_rn'", "_", " ", .)
			qui replace A = "`_rn'" in `_obs'
			local _est = `from'[`_fr', 1]
			local _cilo = `from'[`_fr', 2]
			local _cihi = `from'[`_fr', 3]
			local _pv = `from'[`_fr', 4]
			if !missing(`_est') qui replace c1 = string(`_est', "%9.`digits'f") in `_obs'
			if !missing(`_cilo') & !missing(`_cihi') {
				qui replace c2 = "(" + string(`_cilo', "%9.`digits'f") + `"`sep'"' + string(`_cihi', "%9.`digits'f") + ")" in `_obs'
			}
			if !missing(`_pv') {
				local _pmin = 10^(-`pdp')
				local _pfmt_lo = "%`=`pdp'+2'.`pdp'f"
				local _pfmt_hi = "%`=`highpdp'+2'.`highpdp'f"
				if `_pv' < `_pmin' qui replace c3 = "<" + string(`_pmin', "`_pfmt_lo'") in `_obs'
				else if `_pv' < 0.10 qui replace c3 = string(`_pv', "`_pfmt_lo'") in `_obs'
				else qui replace c3 = string(`_pv', "`_pfmt_hi'") in `_obs'
			}
		}
		local n 3
		local last 1
	}
	else {
	* Export collect table to temporary Excel file
	* Note: Don't use 'modify' option as temp file is new
	capture collect export "`temp_xlsx'", sheet("temp", replace)
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
	}

	* Guard against empty collect tables (R3)
	if _N < 3 {
		noisily display as error "Collect table appears empty or has insufficient data"
		capture erase "`temp_xlsx'"
		restore
		exit 2000
	}

	* =========================================================================
	* PROCESS COLUMNS (same logic as regtab)
	* =========================================================================

	* Get all variables - first variable is row labels, rest are data columns
	ds
	local allvars `r(varlist)'

	* Check that we have data to process
	local nvars : word count `allvars'
	if `nvars' < 2 {
		noisily display as error "Insufficient columns in collect export"
		noisily display as error "Expected at least 2 columns, found `nvars'"
		capture erase "`temp_xlsx'"
		exit 198
	}

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
	local n `=`n'-1'

	* =========================================================================
	* CLEAN UP EFFECT LABELS (post-import fallback)
	* =========================================================================

	* Note: When clean/tlabels was used AND treatment levels were captured,
	* labels were already applied to the collect table before export via
	* collect label levels colname. This section is a fallback for edge cases
	* where the pre-export relabeling couldn't run (e.g., data was cleared
	* before effecttab, or treatment variable not found).

	if "`clean'" != "" & "`type'" == "teffects" & "`tlevels'" == "" {
		* Fallback: basic regex clean on post-import strings
		replace A = regexr(A, "^r([0-9]+)vs([0-9]+)\.(.+)$", "\3 (\1 vs \2)")
		replace A = regexr(A, "^POmean: ([0-9]+)\.(.+)$", "\2 = \1 (PO Mean)")

		* Capitalize first letter
		replace A = upper(substr(A, 1, 1)) + substr(A, 2, .) if !missing(A)

		* Clean underscores to spaces
		replace A = subinstr(A, "_", " ", .)
	}

	* Filter to ATE/POmean rows only (default for teffects; bypass with full)
	* Note: When _colname_filter was used, the collect layout already filtered rows.
	* Post-import filter only needed when clean relabeled rows (_ate_keep populated).
	if "`type'" == "teffects" & "`full'" == "" & "`_colname_filter'" == "" {
		if `"`_ate_keep'"' != "" {
			* Use labels built during relabeling phase
			gen byte _keep = (_n <= 2)
			foreach _lab of local _ate_keep {
				replace _keep = 1 if A == `"`_lab'"'
			}
			drop if !_keep
			drop _keep
		}
		else if "`tvar'" != "" {
			* Fallback: use regex patterns on raw colname levels
			gen byte _keep = (_n <= 2)
			replace _keep = 1 if regexm(A, "^r[0-9]+vs[0-9]+\.")
			replace _keep = 1 if regexm(A, "^[0-9]+\.")
			replace _keep = 1 if regexm(A, " vs ")
			replace _keep = 1 if regexm(A, "\(PO Mean\)")
			drop if !_keep
			drop _keep
		}
	}

	* Apply model labels if provided
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

	* Build raw r(table) before display formatting changes values
	local last = `n' - 2
	local _mat_nrows = 0
	local _keep_obs ""
	local _n_models = 0
	forvalues _mi = 1(3)`last' {
		local _n_models = `_n_models' + 1
	}
	forvalues _obs = 3/`=_N' {
		local _row_has_data = 0
		forvalues _ci = 1(3)`last' {
			capture {
				local _cell = strtrim(c`_ci'[`_obs'])
				local _cicell = strtrim(c`=`_ci'+1'[`_obs'])
				local _pcell = strtrim(c`=`_ci'+2'[`_obs'])
				local _numval = real("`_cell'")
				local _pnum = real("`_pcell'")
				if `_numval' < . {
					if !(inlist("`_cell'", "0", "0.0", "0.00", ".00") & "`_cicell'" == "") {
						local _row_has_data = 1
					}
				}
				if `_pnum' < . local _row_has_data = 1
			}
		}
		if `_row_has_data' {
			local _mat_nrows = `_mat_nrows' + 1
			local _keep_obs "`_keep_obs' `_obs'"
		}
	}
	tempname _rtable
	if `_mat_nrows' > 0 & `_mat_nrows' <= 100 {
		matrix `_rtable' = J(`_mat_nrows', `_n_models' * 2, .)
		local _rnames ""
		local _mr = 0
		foreach _obs of local _keep_obs {
			local _mr = `_mr' + 1
			local _mc = 0
			forvalues _ci = 1(3)`last' {
				local _mc = `_mc' + 1
				capture {
					local _cell = strtrim(c`_ci'[`_obs'])
					local _cicell = strtrim(c`=`_ci'+1'[`_obs'])
					local _numval = real("`_cell'")
					if `_numval' < . {
						if !(inlist("`_cell'", "0", "0.0", "0.00", ".00") & "`_cicell'" == "") {
							matrix `_rtable'[`_mr', `_mc'] = `_numval'
						}
					}
				}
				local _mc = `_mc' + 1
				local _pcol = `_ci' + 2
				capture {
					local _cell = strtrim(c`_pcol'[`_obs'])
					local _numval = real("`_cell'")
					if `_numval' < . matrix `_rtable'[`_mr', `_mc'] = `_numval'
				}
			}
			local _rname = A[`_obs']
			local _rname = subinstr("`_rname'", ".", "_", .)
			local _rname = subinstr("`_rname'", " ", "_", .)
			local _rname = subinstr("`_rname'", ",", "", .)
			local _rname = substr("`_rname'", 1, 32)
			if "`_rname'" == "" local _rname "row`_mr'"
			local _rnames "`_rnames' `_rname'"
		}
		capture matrix rownames `_rtable' = `_rnames'
	}

	* Format numeric columns
	forvalues i = 1(3)`last' {
		destring c`i', gen(c`i'z) force
		replace c`i'z = round(c`i'z, `coef_round')
		tostring c`i'z, replace force format(`coef_fmt')
		* Mark base level as "Reference" when ATE is 0 and CI is empty
		replace c`i' = "Reference" if inlist(strtrim(c`i'), "0", "0.00", ".00") ///
			& strtrim(c`=`i'+1') == "" & _n >= 3
		replace c`i' = c`i'z if c`i'z != "." & _n >= 3 & c`i' != "Reference"
		* Clear CI and p-value for Reference rows
		replace c`=`i'+1' = "" if c`i' == "Reference" & _n >= 3
		capture replace c`=`i'+2' = "" if c`i' == "Reference" & _n >= 3
		drop c`i'z
		capture confirm variable c`=`i'+1'
		if _rc == 0 replace c`=`i'+1' = "" if _n == 1
		capture confirm variable c`=`i'+2'
		if _rc == 0 replace c`=`i'+2' = "" if _n == 1
	}

	* Format p-values
	forvalues i = 3(3)`n' {
		* Store original string value to detect genuinely missing p-values
		gen str20 c`i'_orig = c`i'
		* Convert to numeric - force will set non-numeric to missing
		destring c`i', gen(c`i'z) force
		gen str20 c`i'_fmt = ""
		* Handle genuinely missing p-values
		replace c`i'_fmt = "" if missing(c`i'z) & (strtrim(c`i'_orig) == "." | strtrim(c`i'_orig) == "")
		* Format p-values using pdp/highpdp
		local _pmin = 10^(-`pdp')
		local _pmax = 1 - 10^(-`highpdp')
		local _pfmt_lo = "%`=`pdp'+2'.`pdp'f"
		local _pfmt_hi = "%`=`highpdp'+2'.`highpdp'f"
		replace c`i'_fmt = "<" + string(`_pmin', "`_pfmt_lo'") if c`i'z < `_pmin' & !missing(c`i'z)
		replace c`i'_fmt = string(c`i'z, "`_pfmt_lo'") if c`i'z >= `_pmin' & c`i'z < 0.10 & !missing(c`i'z)
		replace c`i'_fmt = string(c`i'z, "`_pfmt_hi'") if c`i'z >= 0.10 & !missing(c`i'z)
		replace c`i'_fmt = string(`_pmax', "`_pfmt_hi'") if c`i'z >= `_pmax' & c`i'z < 1 & !missing(c`i'z)
		replace c`i'_fmt = "<" + string(`_pmin', "`_pfmt_lo'") if c`i'z == 0 & !missing(c`i'z)
		* Add leading zero if missing (e.g., .123 -> 0.123)
		replace c`i'_fmt = "0" + c`i'_fmt if substr(c`i'_fmt, 1, 1) == "."
		* Apply formatting - only if we have a non-missing formatted value
		replace c`i' = c`i'_fmt if c`i'_fmt != "" & _n >= 3
		* Leave blank for missing p-values
		replace c`i' = "" if missing(c`i'z) & _n >= 3
		drop c`i'z c`i'_fmt c`i'_orig
	}

	* =========================================================================
	* ADD CUSTOM ROWS (addrow option)
	* =========================================================================
	if `"`addrow'"' != "" {
		local _ar_rest `"`addrow'"'
		while `"`_ar_rest'"' != "" {
			local _bs_pos = strpos(`"`_ar_rest'"', "\")
			if `_bs_pos' > 0 {
				local _ar_chunk = substr(`"`_ar_rest'"', 1, `_bs_pos' - 1)
				local _ar_rest = substr(`"`_ar_rest'"', `_bs_pos' + 1, .)
			}
			else {
				local _ar_chunk `"`_ar_rest'"'
				local _ar_rest ""
			}
			local _ar_chunk = strtrim(`"`_ar_chunk'"')
			if `"`_ar_chunk'"' == "" continue

			gettoken _ar_label _ar_vals : _ar_chunk
			local _ar_label : subinstr local _ar_label `"""' "", all

			local curr_n = _N
			set obs `=`curr_n'+1'
			replace A = "`_ar_label'" in `=`curr_n'+1'

			local _ar_m = 0
			local _ar_vals = strtrim(`"`_ar_vals'"')
			while `"`_ar_vals'"' != "" {
				gettoken _ar_v _ar_vals : _ar_vals
				local _ar_m = `_ar_m' + 1
				local col = (`_ar_m' - 1) * 3 + 1
				if `col' <= `n' {
					replace c`col' = "`_ar_v'" in `=`curr_n'+1'
				}
			}
		}
	}

	* =========================================================================
	* EXPORT TO EXCEL
	* =========================================================================

	* Add title row
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
	if "`subtitle'" != "" {
		replace title = "`title'" + char(10) + "`subtitle'" if _n == 1
	}

	* Track Reference rows for merged cell formatting (after title row added)
	local ref_rows ""
	forvalues i = 1(3)`last' {
		gen ref`i' = _n if c`i' == "Reference"
		levelsof ref`i', local(ref`i'_levels)
		local ref_rows "`ref_rows' `ref`i'_levels'"
		drop ref`i'
	}
	local ref_rows: list uniq ref_rows

	if `_has_xlsx' {
		capture export excel using "`xlsx'", sheet("`sheet'") sheetreplace
		if _rc {
			noisily display as error "Failed to export to `xlsx', sheet `sheet'"
			noisily display as error "Check file permissions and that file is not open in Excel"
			capture erase "`temp_xlsx'"
			restore
			exit _rc
		}
	}

	local num_rows = _N
	local num_cols = c(k)

	* =========================================================================
	* CALCULATE COLUMN WIDTHS
	* =========================================================================

	forvalues i = 1(1)`n' {
		gen c`i'_length = length(c`i')
	}
	* Compute max header length from row 2 only (model labels)
	local max_header_length = 0
	forvalues i = 1/`n' {
	    local _h2len = strlen(c`i'[2])
	    if `_h2len' > `max_header_length' local max_header_length = `_h2len'
	}
	* Compute minimum estimate column width from header labels (row 3)
	* and estimate column data to ensure headers like "Pr(CV Event)" fit
	local est_max = 0
	forvalues i = 1(3)`last' {
		sum c`i'_length if _n >= 3, meanonly
		if `r(max)' > `est_max' local est_max = `r(max)'
		* Also consider the column header in row 3
		local _hdr_len = c`i'_length[3]
		if !missing(`_hdr_len') & `_hdr_len' > `est_max' local est_max = `_hdr_len'
	}
	local est_min_width = (`est_max' * 3 / 8) + 2
	forvalues i = 1(1)`n' {
		replace c`i'_length = . if _n == 2
		egen c`i'_max = max(c`i'_length)
	}
	forvalues i = 1(1)`=`n'-1' {
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
	* Include effect label length in factor_length calculation
	local _effect_len = strlen(`"`effect'"')
	if ceil(`_effect_len' * 0.85) + 2 > `factor_length' {
	    local factor_length = ceil(`_effect_len' * 0.85) + 2
	}

	drop A_length factor_length c*_max c*_length

	* CSV export (F2) — must happen before clear
	if "`csv'" != "" {
		_tabtools_validate_path "`csv'" "csv()"
		export delimited using "`csv'", replace
	}

	* Console display (when no xlsx or display option specified)
	if !`_has_xlsx' | "`display'" != "" {
		noisily {
			if "`subtitle'" != "" {
				if "`title'" != "" {
					display as text ""
					display as result "`title'"
				}
				display as text "`subtitle'"
				_tabtools_console_display `n' "", labelvar(A)
			}
			else {
				_tabtools_console_display `n' `"`title'"', labelvar(A)
			}
		}
	}

	* Store output in frame if requested
	if `"`frame'"' != "" {
		_tabtools_frame_put `"`frame'"'
		local frame "`_frame_name'"
	}

	if `_has_xlsx' {
	* =========================================================================
	* APPLY EXCEL FORMATTING (MATA)
	* =========================================================================

	capture {
		mata: b = xl()
		mata: b.load_book("`xlsx'")
		mata: b.set_sheet("`sheet'")
		mata: b.set_row_height(1,1,30)
		mata: b.set_column_width(1,1,1)
		mata: b.set_column_width(2,2,`factor_length')
		local est_width = max(`=`max_length'*.55', `est_min_width')
		forvalues i = 3(3)`=`num_cols'-2' {
			mata: b.set_column_width(`i',`i',`est_width')
		}
		forvalues i = 4(3)`=`num_cols'-1' {
			mata: b.set_column_width(`i',`i',`=`max_length'*1.3')
		}
		forvalues i = 5(3)`num_cols' {
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
		capture erase "`temp_xlsx'"
		restore
		exit `saved_rc'
	}
	capture mata: mata drop b

	* =========================================================================
	* APPLY PUTEXCEL FORMATTING
	* =========================================================================

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

		* Merge Reference rows (estimate + CI + p merged with "Reference" text)
		foreach row of local ref_rows {
			local col_num = 3
			while `col_num' <= `n' {
				_tabtools_col_letter `col_num'
				local col_letter = "`result'"
				_tabtools_col_letter `=`col_num'+2'
				local col_letter_next2 = "`result'"
				putexcel (`col_letter'`row':`col_letter_next2'`row'), merge hcenter vcenter italic
				local col_num = `col_num' + 3
			}
		}

		* Merge headers over models
		local col_num = 3
		while `col_num' <= `n' {
			_tabtools_col_letter `col_num'
			local col_letter = "`result'"

			_tabtools_col_letter `=`col_num'+1'
			local col_letter_next1 = "`result'"

			_tabtools_col_letter `=`col_num'+2'
			local col_letter_next2 = "`result'"

			putexcel (`col_letter'`n1':`col_letter_next2'`n1'), merge hcenter vcenter bold txtwrap
			if "`borderstyle'" != "academic" {
				putexcel (`col_letter_next2'`n1':`col_letter_next2'`n2'), border(right, `borderstyle')
			}
			local col_num = `col_num' + 3
		}

		putexcel (A1:`letterright'1), merge txtwrap left vcenter bold
		putexcel (`letterleft'2:`letterright'3), fpattern(solid, "`_headercolor'") // header background
		putexcel (`letterleft'3:`letterright'3), bold hcenter vcenter
		putexcel (`tl1':`tr1'), border(top, `_hborder')
		putexcel (`lettertwo'`n1':`tr2'), border(top, `_hborder')
		putexcel (`tl2':`tr2'), border(bottom, `_hborder')
		if "`borderstyle'" != "academic" {
			putexcel (`tr1':`br'), border(right, `borderstyle')
			putexcel (`tl1':`bl'), border(left, `borderstyle')
			putexcel (`tl1':`bl'), border(right, `borderstyle')
			putexcel (`letterright'`n1':`letterright'`n2'), border(right, `borderstyle')
		}
		putexcel (`bl':`br'), border(bottom, `_hborder')
		* Zebra striping (O3)
		if "`zebra'" != "" {
			forvalues _zr = 5(2)`n2' {
				putexcel (`letterleft'`_zr':`letterright'`_zr'), fpattern(solid, "`_zebracolor'")
			}
		}

		putexcel (A1:`br'), font("`_font'", `_fontsize')
		putexcel (A1:`letterright'1), font("`_font'", `=`_fontsize'+2')

		* Center-align numeric data columns
		putexcel (`lettertwo'4:`letterright'`n2'), hcenter

		* Bold significant p-values / highlight significant rows
		* P-value columns are c3, c6, c9, ... (every 3rd data column)
		* Excel columns: col 5, 8, 11, ... (B=1 + row label col + 3*m)
		if `has_boldp' | `has_highlight' {
			local _n_models = `n' / 3
			forvalues _m = 1/`_n_models' {
				local _pcol = 2 + `_m' * 3
				_tabtools_col_letter `_pcol'
				local _p_letter "`result'"
				forvalues _dr = 4/`n2' {
					capture {
						local _pstr = c`=`_m'*3'[`_dr']
						local _pstr = strtrim("`_pstr'")
						if substr("`_pstr'", 1, 1) == "<" {
							local _pnum = 0
						}
						else {
							local _pnum = real("`_pstr'")
						}
						if `_pnum' < . {
							if `has_boldp' & `_pnum' < `boldp' {
								putexcel (`_p_letter'`_dr'), bold
							}
							if `has_highlight' & `_pnum' < `highlight' {
								putexcel (`letterleft'`_dr':`letterright'`_dr'), fpattern(solid, "255 255 204")
							}
						}
					}
				}
			}
		}

		* Footnote (F2)
		if `"`footnote'"' != "" {
			_tabtools_footnote `"`footnote'"' "`letterright'" `n2' "`_font'" `_fontsize'
		}

		putexcel clear
	}
	if _rc {
		local saved_rc = _rc
		noisily display as error "Excel cell formatting failed with error `saved_rc'"
		capture erase "`temp_xlsx'"
		restore
		exit `saved_rc'
	}

	} // end if _has_xlsx (Excel formatting)

	* Clean up temporary file
	capture erase "`temp_xlsx'"

	clear
	restore

	* Open file if requested (W3)
	if `_has_xlsx' & "`open'" != "" _tabtools_open_file "`xlsx'"

	* Console confirmation (O1)
	if `_has_xlsx' {
		capture confirm file "`xlsx'"
		if _rc {
			noisily display as error "Warning: expected output file not found"
		}
		else {
			noisily display as text "Exported " as result "`num_rows'" as text " rows × " as result "`num_cols'" as text " cols to " as result `"`xlsx'"' as text ", sheet " as result `"`sheet'"'
		}
	}

	* Build methods description (I2)
	local _methods ""
	if `_from_matrix' {
		local _methods "Effect estimates were formatted from the supplied matrix with 95% confidence intervals and p-values."
	}
	else if `_n_models' > 1 {
		local _methods "Effect estimates from multiple collected models were formatted with 95% confidence intervals."
	}
	else if "`type'" == "teffects" {
		if `_n_models' == 1 {
			local _te_subcmd "`e(subcmd)'"
			if "`_te_subcmd'" == "ipw" local _methods "Average treatment effects estimated using inverse probability weighting"
			else if "`_te_subcmd'" == "ra" local _methods "Average treatment effects estimated using regression adjustment"
			else if "`_te_subcmd'" == "aipw" local _methods "Average treatment effects estimated using augmented inverse probability weighting"
			else if "`_te_subcmd'" == "ipwra" local _methods "Average treatment effects estimated using inverse probability weighted regression adjustment"
			else if "`_te_subcmd'" == "psmatch" local _methods "Average treatment effects estimated using propensity score matching"
			else if "`_te_subcmd'" == "nnmatch" local _methods "Average treatment effects estimated using nearest-neighbor matching"
			else local _methods "Average treatment effects estimated using teffects"
			local _methods "`_methods' with 95% confidence intervals."
		}
	}
	else {
		local _methods "Marginal effects estimated using the margins command with 95% confidence intervals."
	}
	local _methods "`_methods' Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."

	* Return statistics (I1)
	if `_mat_nrows' > 0 & `_mat_nrows' <= 100 {
		capture return matrix table = `_rtable'
	}
	return scalar N_rows = `num_rows'
	return scalar N_cols = `num_cols'
	return local effect_label "`effect'"
	return local type "`type'"
	return local xlsx "`xlsx'"
	return local sheet "`sheet'"
	return local methods "`_methods'"
	if "`frame'" != "" return local frame "`frame'"
}

	} // end capture noisily
	local _rc = _rc
	set varabbrev `_prev_varabbrev'
	if `_rc' exit `_rc'
end
*
