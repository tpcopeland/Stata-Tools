*! effecttab Version 1.0.0  19dec2025
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
	           sep(string asis) title(string) clean]

	xlsx:    Required. Excel file name (requires .xlsx suffix)
	sheet:   Required. Excel sheet name
	type:    Type of results: teffects, margins, or auto (default: auto)
	effect:  Label for effect column (e.g., ATE, RD, RR, AME). Default varies by type.
	models:  Label models, separating names with backslash (e.g., Model 1 \ Model 2)
	sep:     Character separating 95% CI bounds (default: ", ")
	title:   Table title for cell A1
	clean:   Clean up teffects colname labels (e.g., "r1vs0.treat" → "Treatment (1 vs 0)")

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

capture program drop effecttab
capture program drop col_to_letter_effect

* Helper program to convert column number to Excel letter
program col_to_letter_effect
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

program define effecttab, rclass
	version 17.0
	set varabbrev off

	syntax, xlsx(string) sheet(string) [sep(string asis) type(string) effect(string) ///
	        models(string) title(string) clean]

quietly {
	* =========================================================================
	* VALIDATION
	* =========================================================================

	* Check if collect table exists
	capture quietly collect query row
	if _rc {
		noisily display as error "No active collect table found"
		noisily display as error "Run teffects or margins with collect prefix first"
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
	return local xlsx "`xlsx'"
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
	* CONFIGURE COLLECT LAYOUT
	* =========================================================================

	* Apply formatting to result items
	collect label levels result _r_b "`effect'", modify
	collect style cell result[_r_b], warn nformat(%4.2fc) halign(center) valign(center)
	collect style cell result[_r_ci], warn nformat(%4.2fc) sformat("(%s)") ///
	        cidelimiter("`sep'") halign(center) valign(center)
	collect style cell result[_r_p], warn nformat(%5.4f) halign(center) valign(center)
	collect style column, dups(center)
	collect style row stack, nodelimiter nospacer indent length(.) ///
	        wrapon(word) noabbreviate wrap(.) truncate(tail)

	* Set layout based on type
	* Both teffects and margins use colname for row dimension
	* Multiple models (cmdset) go on columns

	* Note: collect levelsof cmdset returns r(levels) as empty even when cmdset
	* has levels (Stata quirk). So we try multi-model layout first regardless.

	* Set layout - ALWAYS try multi-model first since r(levels) is unreliable
	local layout_ok = 0

	* Try multi-model layout with cmdset dimension
	capture collect layout (colname) (cmdset#result[_r_b _r_ci _r_p])
	if _rc == 0 {
		local layout_ok = 1
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
	* EXPORT AND IMPORT FOR PROCESSING
	* =========================================================================

	* Export collect table to temporary Excel file
	* Note: Don't use 'modify' option as temp file is new
	capture collect export "`temp_xlsx'", sheet("temp", replace)
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
	local n2 `=`n'-3'
	local n `=`n'-1'

	* =========================================================================
	* CLEAN UP EFFECT LABELS (if requested)
	* =========================================================================

	if "`clean'" != "" & "`type'" == "teffects" {
		* Clean up teffects-style labels
		* "r1vs0.treatment" → "Treatment (1 vs 0)"
		* "POmean: 0.treatment" → "Treatment = 0 (PO Mean)"
		* "POmean: 1.treatment" → "Treatment = 1 (PO Mean)"

		replace A = regexr(A, "^r([0-9]+)vs([0-9]+)\.(.+)$", "\3 (\1 vs \2)")
		replace A = regexr(A, "^POmean: ([0-9]+)\.(.+)$", "\2 = \1 (PO Mean)")

		* Capitalize first letter of variable names
		replace A = upper(substr(A, 1, 1)) + substr(A, 2, .) if !missing(A)

		* Clean underscores to spaces
		replace A = subinstr(A, "_", " ", .)
	}

	* Apply model labels if provided
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

	* Format numeric columns
	local last = `n' - 2
	forvalues i = 1(3)`last' {
		destring c`i', gen(c`i'z) force
		replace c`i'z = round(c`i'z, 0.01)
		tostring c`i'z, replace force format(%9.2f)
		* Note: For treatment effects, we don't mark "Reference" - all effects are estimated
		replace c`i' = c`i'z if c`i'z != "." & _n >= 3
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
		* Leave blank for missing p-values
		replace c`i' = "" if missing(c`i'z) & _n >= 3
		drop c`i'z c`i'_fmt c`i'_orig
	}

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

	* =========================================================================
	* EXPORT TO EXCEL
	* =========================================================================

	capture export excel using "`xlsx'", sheet("`sheet'") sheetreplace
	if _rc {
		noisily display as error "Failed to export to `xlsx', sheet `sheet'"
		noisily display as error "Check file permissions and that file is not open in Excel"
		capture erase "`temp_xlsx'"
		exit _rc
	}

	local num_rows = _N
	local num_cols = c(k)

	* =========================================================================
	* CALCULATE COLUMN WIDTHS
	* =========================================================================

	forvalues i = 1(1)`n' {
		gen c`i'_length = length(c`i')
	}
	egen label_length = rowmax(c*_length)
	sum label_length, d
	local max_header_length = `=`r(max)' - 0.5'
	drop label_length
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

	drop A_length factor_length c*_max c*_length

	clear

	* =========================================================================
	* APPLY EXCEL FORMATTING (MATA)
	* =========================================================================

	capture {
		mata: b = xl()
		mata: b.load_book("`xlsx'")
		mata: b.set_sheet("`sheet'")
		mata: b.set_row_height(1,1,30)
		mata: b.set_column_width(2,2,`factor_length')
		forvalues i = 3(3)`=`num_cols'-2' {
			mata: b.set_column_width(`i',`i',`=`max_length'*.55')
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
		* Ensure Excel file handle is closed on error
		capture mata: b.close_book()
		noisily display as error "Excel formatting failed with error `=_rc'"
		capture erase "`temp_xlsx'"
		exit `=_rc'
	}

	* =========================================================================
	* APPLY PUTEXCEL FORMATTING
	* =========================================================================

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

		* Merge headers over models
		local col_num = 3
		while `col_num' <= `n' {
			col_to_letter_effect `col_num'
			local col_letter = "`result'"

			col_to_letter_effect `=`col_num'+1'
			local col_letter_next1 = "`result'"

			col_to_letter_effect `=`col_num'+2'
			local col_letter_next2 = "`result'"

			putexcel (`col_letter'`n1':`col_letter_next2'`n1'), merge hcenter vcenter bold txtwrap
			putexcel (`col_letter_next2'`n1':`col_letter_next2'`n2'), border(right, thin)
			local col_num = `col_num' + 3
		}

		putexcel (A1:`letterright'1), merge txtwrap left top bold
		putexcel (`letterleft'3:`letterright'3), bold
		putexcel (`tl1':`tr1'), border(top, thin)
		putexcel (`lettertwo'`n1':`tr2'), border(top, thin)
		putexcel (`tl2':`tr2'), border(bottom, thin)
		putexcel (`tr1':`br'), border(right, thin)
		putexcel (`tl1':`bl'), border(left, thin)
		putexcel (`tl1':`bl'), border(right, thin)
		putexcel (`bl':`br'), border(bottom, thin)
		putexcel (`letterright'`n1':`letterright'`n2'), border(right, thin)
		putexcel (A1:`br'), font(Arial, 10)
		putexcel clear
	}
	if _rc {
		noisily display as error "Excel cell formatting failed with error `=_rc'"
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
