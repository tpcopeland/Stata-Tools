*! effecttab Version 1.9.1  2026/07/01
*! Format treatment effects and margins results for Excel export
*! Author: Timothy P Copeland, Karolinska Institutet
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
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off

	capture noisily {

	capture putexcel close

	* Auto-load shared helper programs if not already in memory
	capture _tabtools_helpers_ready
	if _rc {
		capture findfile _tabtools_common.ado
		if _rc == 0 {
			run "`r(fn)'"
			capture _tabtools_helpers_ready
			if _rc {
				display as error "_tabtools_common.ado failed to load fully; reinstall tabtools"
				exit 111
			}
		}
		else {
			display as error "_tabtools_common.ado not found; reinstall tabtools"
			exit 111
		}
	}
	_tabtools_require_helpers

	syntax, [xlsx(string) excel(string) sheet(string)] [sep(string asis) type(string) effect(string) ///
	        models(string) title(string) clean TLABels(string asis) ///
	        FOOTnote(string) open zebra HEADERShade HIGHlight(real -1) BOLDp(real -1) ///
	        BORDERstyle(string) full THEme(string) digits(integer -1) ///
		        HEADERColor(string) ZEBRAColor(string) csv(string) MARKdown(string) MDAPPend FRAme(string) EPLOTFrame(string asis) ///
	        FROM(name) ADDRow(string asis) pdp(integer -1) highpdp(integer -1) ///
	        LABELWidth(integer 0)]

	* Accept excel() as synonym for xlsx()
	if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
		local _has_xlsx = "`xlsx'" != ""
		if "`sheet'" == "" local sheet "Effects"

		local _eplotframe_name ""
		local _eplotframe_replace 0
		if `"`eplotframe'"' != "" {
			local _ep_spec = strtrim(`"`eplotframe'"')
			gettoken _eplotframe_name _ep_rest : _ep_spec, parse(",")
			local _eplotframe_name = strtrim(`"`_eplotframe_name'"')
			if `"`_eplotframe_name'"' == "" {
				noisily display as error "eplotframe() requires a frame name"
				exit 198
			}
			capture confirm name `_eplotframe_name'
			if _rc {
				noisily display as error "eplotframe() must start with a valid Stata frame name"
				exit 198
			}
			local _ep_rest : subinstr local _ep_rest "," "", all
			local _ep_rest = lower(strtrim(`"`_ep_rest'"'))
			if `"`_ep_rest'"' != "" {
				if `"`_ep_rest'"' == "replace" {
					local _eplotframe_replace 1
				}
				else {
					noisily display as error "eplotframe() only allows the replace suboption"
					exit 198
				}
			}
		}

	* Label-column width cap (0 -> default 45): keeps a lone verbose label from
	* stretching the whole column; longer labels wrap (text-wrap rule below).
	local _label_width_cap = `labelwidth'
	if `_label_width_cap' <= 0 local _label_width_cap = 45

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
	if "`open'" != "" & !`_has_xlsx' {
		noisily display as error "open requires xlsx() or excel()"
		exit 198
	}

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
	if `pdp' < 1 | `pdp' > 10 {
		noisily display as error "pdp() must be between 1 and 10"
		exit 198
	}
	if `highpdp' < 1 | `highpdp' > 10 {
		noisily display as error "highpdp() must be between 1 and 10"
		exit 198
	}
	if "`mdappend'" != "" & `"`markdown'"' == "" {
		noisily display as error "mdappend requires markdown()"
		exit 198
	}
	if `"`markdown'"' != "" {
		_tabtools_validate_path `"`markdown'"' "markdown()"
		local _md_lower = lower(`"`markdown'"')
		if !(strmatch(`"`_md_lower'"', "*.md") | ///
			 strmatch(`"`_md_lower'"', "*.markdown") | ///
			 strmatch(`"`_md_lower'"', "*.qmd") | ///
			 strmatch(`"`_md_lower'"', "*.rmd")) {
			noisily display as error "markdown() must specify a .md, .markdown, .qmd, or .rmd file"
			exit 198
		}
	}

	* Build format strings from digits
	local coef_fmt "%9.`digits'f"
	local coef_round = 10^(-`digits')

	* Resolve formatting
	_tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle') headershade(`headershade') zebra(`zebra')
	_tabtools_resolve_colors, headercolor(`"`headercolor'"') zebracolor(`"`zebracolor'"')

	* Set defaults
	if `"`sep'"' == "" local sep ", "
	if "`type'" == "" local type "auto"

	* Validate type option
	if !inlist("`type'", "auto", "teffects", "margins") {
		noisily display as error "type() must be auto, teffects, or margins"
		exit 198
	}

	* Inspect the active collection itself instead of ambient e()
	local _collect_models 0
	local _collect_kind ""
	local _collect_kind_mixed 0
	local _teffects_tvar ""
	if !`_from_matrix' {
		capture {
			collect layout (cmdset) (result[cmd cmdline])
		}
			if _rc == 0 {
				preserve
				capture {
					_tabtools_collect_render, type(meta) rowdim(cmdset) ///
						results(cmd cmdline) dropempty

					local _meta_col_cmd ""
					local _meta_col_cmdline ""
				ds
				local _meta_allvars `r(varlist)'
				foreach _v of local _meta_allvars {
					local _hdr = lower(strtrim(`_v'[1]))
					if "`_hdr'" == "command" local _meta_col_cmd "`_v'"
					if "`_hdr'" == "command line as typed" local _meta_col_cmdline "`_v'"
				}

				if "`_meta_col_cmd'" != "" {
					local _collect_models = _N - 1
					forvalues _m = 1/`_collect_models' {
						local _r = `_m' + 1
						local collect_cmd_`_m' = lower(strtrim(`_meta_col_cmd'[`_r']))
						local collect_cmdline_`_m' = lower(strtrim(`_meta_col_cmdline'[`_r']))
					}
				}
			}
			if _rc local _collect_models = 0
			restore
		}

		if `_collect_models' == 0 {
			noisily display as error "Could not inspect the active collect table"
			noisily display as error "Run teffects or margins with {bf:collect:} prefix first"
			exit 198
		}

		forvalues _m = 1/`_collect_models' {
			local _cmd "`collect_cmd_`_m''"
			local _cmdline `"`collect_cmdline_`_m''"'
			local _kind ""

			if "`_cmd'" == "teffects" local _kind "teffects"
			else if "`_cmd'" == "margins" local _kind "margins"

			if "`_kind'" == "" {
				noisily display as error "effecttab supports only teffects or margins collections"
				noisily display as error "Current collect contains unsupported command: `collect_cmd_`_m''"
				exit 198
			}

			if "`_collect_kind'" == "" local _collect_kind "`_kind'"
			else if "`_collect_kind'" != "`_kind'" local _collect_kind_mixed = 1

			if "`_kind'" == "teffects" & "`_teffects_tvar'" == "" {
				if regexm(`"`_cmdline'"', "^teffects[ ]+[a-z0-9_]+[ ]+\([^)]*\)[ ]+\(([^)]*)\)") {
					local _tblock = strtrim(regexs(1))
					gettoken _teffects_tvar _tblock_rest : _tblock
				}
			}
		}

		if `_collect_kind_mixed' {
			noisily display as error "effecttab does not support mixing teffects and margins in one collection"
			exit 198
		}
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
		if `_from_matrix' {
			local type "margins"
		}
		else {
			local type "`_collect_kind'"
		}
	}
	else if !`_from_matrix' {
		if "`type'" != "`_collect_kind'" {
			noisily display as error "type(`type') does not match the active collect type (`_collect_kind')"
			exit 198
		}
	}

	* Set default effect label based on type
	if "`effect'" == "" {
		if "`type'" == "teffects" {
			local effect "Effect"
		}
		else {
			local effect "Estimate"
		}
	}

	local _ate_keep ""
	if !`_from_matrix' {

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
		local tvar "`_teffects_tvar'"
		if "`tvar'" == "" local tvar "`e(tvar)'"

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
	collect label levels result _r_ci "`=c(level)'% CI", modify
	collect label levels result _r_p "p-value", modify
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
			restore
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
				local _cilo_s : display %9.`digits'f `_cilo'
				local _cihi_s : display %9.`digits'f `_cihi'
				local _cilo_s = strtrim("`_cilo_s'")
				local _cihi_s = strtrim("`_cihi_s'")
				qui replace c2 = "(`_cilo_s'`sep'`_cihi_s')" in `_obs'
			}
			if !missing(`_pv') {
				qui replace c3 = string(`_pv', "%21.0g") in `_obs'
			}
		}
		local n 3
		local last 1
	}
	else {
		* Preserve user data before rendering the collect table into strings
		preserve

		capture _tabtools_collect_render, type(main) rowdim(colname) ///
			rowlevels(`"`_colname_filter'"') coldim(cmdset) ///
			results(_r_b _r_ci _r_p) sep("`sep'")
		local _collect_render_rc = _rc
		if `_collect_render_rc' {
			restore
			* Fallback: use the prior workbook renderer for unsupported layouts.
			capture collect export "`temp_xlsx'", sheet("temp", replace)
			if _rc {
				noisily display as error "Failed to export collect table to temporary Excel file"
				noisily display as error "Check that collect table is properly structured"
				exit _rc
			}
			preserve
			capture _tabtools_xlsx_read using "`temp_xlsx'", sheet(temp)
			if _rc {
				noisily display as error "Failed to import temporary Excel file"
				capture erase "`temp_xlsx'"
				restore
				exit _rc
			}
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
		restore
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

		if `_from_matrix' {
			gen double _eplot_est1 = .
			gen double _eplot_ll1 = .
			gen double _eplot_ul1 = .
			gen double _eplot_p1 = .
			forvalues _fr = 1/`_nrows' {
				local _obs = `_fr' + 2
				replace _eplot_est1 = `from'[`_fr', 1] in `_obs'
				replace _eplot_ll1 = `from'[`_fr', 2] in `_obs'
				replace _eplot_ul1 = `from'[`_fr', 3] in `_obs'
				replace _eplot_p1 = `from'[`_fr', 4] in `_obs'
			}
		}

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
	if `_mat_nrows' > 0 {
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
			local _model_ix = (`i' + 2) / 3
			capture confirm variable _eplot_est`_model_ix'
			if _rc gen double _eplot_est`_model_ix' = .
			replace _eplot_est`_model_ix' = c`i'z ///
				if _n >= 3 & c`i'z < . & missing(_eplot_est`_model_ix')
			tostring c`i'z, replace force format(`coef_fmt')
		* Mark base level as "Reference" when ATE is 0 and CI is empty
		replace c`i' = "Reference" if inlist(strtrim(c`i'), "0", "0.00", ".00") ///
			& strtrim(c`=`i'+1') == "" & _n >= 3
		replace c`i' = c`i'z if c`i'z != "." & _n >= 3 & c`i' != "Reference"
		* Clear CI and p-value for Reference rows
			replace c`=`i'+1' = "" if c`i' == "Reference" & _n >= 3
			capture confirm variable c`=`i'+2'
			if _rc == 0 replace c`=`i'+2' = "" if c`i' == "Reference" & _n >= 3
			replace _eplot_est`_model_ix' = . if c`i' == "Reference" & _n >= 3
			drop c`i'z
		capture confirm variable c`=`i'+1'
		if _rc == 0 replace c`=`i'+1' = "" if _n == 1
		capture confirm variable c`=`i'+2'
		if _rc == 0 replace c`=`i'+2' = "" if _n == 1
	}

	* Normalize and reformat CI cells without changing numeric return values.
	local _ci_sep_len = strlen(`"`sep'"')
	forvalues i = 2(3)`n' {
		capture confirm variable c`i'
		if _rc == 0 {
			replace c`i' = strtrim(c`i') if _n >= 3
			quietly count if strpos(c`i', "( ") > 0 & _n >= 3
			while r(N) > 0 {
				replace c`i' = subinstr(c`i', "( ", "(", .) if _n >= 3
				quietly count if strpos(c`i', "( ") > 0 & _n >= 3
			}
			if `"`sep'"' == ", " {
				quietly count if strpos(c`i', ",  ") > 0 & _n >= 3
				while r(N) > 0 {
					replace c`i' = subinstr(c`i', ",  ", ", ", .) if _n >= 3
					quietly count if strpos(c`i', ",  ") > 0 & _n >= 3
				}
			}
			tempvar _ci_raw _ci_body _ci_pos _ci_lo_s _ci_hi_s _ci_lo _ci_hi _ci_fmt
			gen str244 `_ci_raw' = strtrim(c`i') if _n >= 3
			gen str244 `_ci_body' = `_ci_raw'
			replace `_ci_body' = substr(`_ci_body', 2, length(`_ci_body') - 2) ///
				if length(`_ci_body') >= 2 & substr(`_ci_body', 1, 1) == "(" ///
				& substr(`_ci_body', length(`_ci_body'), 1) == ")"
			gen int `_ci_pos' = strpos(`_ci_body', `"`sep'"')
			gen str122 `_ci_lo_s' = strtrim(substr(`_ci_body', 1, `_ci_pos' - 1)) if `_ci_pos' > 0
			gen str122 `_ci_hi_s' = strtrim(substr(`_ci_body', `_ci_pos' + `_ci_sep_len', .)) if `_ci_pos' > 0
			replace `_ci_lo_s' = subinstr(`_ci_lo_s', ",", "", .)
			replace `_ci_hi_s' = subinstr(`_ci_hi_s', ",", "", .)
				destring `_ci_lo_s', gen(`_ci_lo') force
				destring `_ci_hi_s', gen(`_ci_hi') force
				local _model_ix = (`i' + 1) / 3
				capture confirm variable _eplot_ll`_model_ix'
				if _rc gen double _eplot_ll`_model_ix' = .
				capture confirm variable _eplot_ul`_model_ix'
				if _rc gen double _eplot_ul`_model_ix' = .
				replace _eplot_ll`_model_ix' = `_ci_lo' ///
					if _n >= 3 & `_ci_lo' < . & missing(_eplot_ll`_model_ix')
				replace _eplot_ul`_model_ix' = `_ci_hi' ///
					if _n >= 3 & `_ci_hi' < . & missing(_eplot_ul`_model_ix')
				gen str244 `_ci_fmt' = ""
			replace `_ci_fmt' = "(" + strtrim(string(`_ci_lo', "`coef_fmt'")) + `"`sep'"' + ///
				strtrim(string(`_ci_hi', "`coef_fmt'")) + ")" ///
				if `_ci_lo' < . & `_ci_hi' < . & _n >= 3
			replace c`i' = `_ci_fmt' if `_ci_fmt' != "" & _n >= 3
			drop `_ci_raw' `_ci_body' `_ci_pos' `_ci_lo_s' `_ci_hi_s' `_ci_lo' `_ci_hi' `_ci_fmt'
		}
	}

	* Format p-values
	forvalues i = 3(3)`n' {
		* Store original string value to detect genuinely missing p-values
		gen str20 c`i'_orig = c`i'
			* Convert to numeric - force will set non-numeric to missing
			destring c`i', gen(c`i'z) force
			local _model_ix = `i' / 3
			capture confirm variable _eplot_p`_model_ix'
			if _rc gen double _eplot_p`_model_ix' = .
			replace _eplot_p`_model_ix' = c`i'z ///
				if _n >= 3 & c`i'z < . & missing(_eplot_p`_model_ix')
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

		if `"`_eplotframe_name'"' != "" {
			capture frame `_eplotframe_name': quietly count
			if _rc == 0 {
				if `_eplotframe_replace' {
					frame drop `_eplotframe_name'
				}
				else {
					noisily display as error "frame `_eplotframe_name' already exists; specify eplotframe(`_eplotframe_name', replace)"
					exit 110
				}
			}
			frame create `_eplotframe_name' str244 label double estimate double ll double ul ///
				double pvalue int model str244 model_label str24 rowtype str244 section ///
				long source_row str32 source_frame
			forvalues _ep_obs = 3/`=_N' {
				local _ep_source_row = `_ep_obs' - 2
				local _ep_label = A[`_ep_obs']
				forvalues _ep_m = 1/`_n_models' {
					local _ep_est = .
					local _ep_ll = .
					local _ep_ul = .
					local _ep_p = .
					capture local _ep_est = _eplot_est`_ep_m'[`_ep_obs']
					capture local _ep_ll = _eplot_ll`_ep_m'[`_ep_obs']
					capture local _ep_ul = _eplot_ul`_ep_m'[`_ep_obs']
					capture local _ep_p = _eplot_p`_ep_m'[`_ep_obs']
					local _ep_model_col = (`_ep_m' - 1) * 3 + 1
					local _ep_model_label = c`_ep_model_col'[1]
					if `"`_ep_model_label'"' == "" local _ep_model_label "Model `_ep_m'"
					local _ep_cell = strtrim(c`_ep_model_col'[`_ep_obs'])
					local _ep_rowtype "effect"
					if lower(`"`_ep_cell'"') == "reference" local _ep_rowtype "reference"
					if `_ep_est' < . | `_ep_ll' < . | `_ep_ul' < . | `_ep_p' < . | `"`_ep_rowtype'"' == "reference" {
						frame post `_eplotframe_name' (`"`_ep_label'"') (`_ep_est') (`_ep_ll') (`_ep_ul') ///
							(`_ep_p') (`_ep_m') (`"`_ep_model_label'"') (`"`_ep_rowtype'"') ("") ///
							(`_ep_source_row') ("")
					}
				}
				}
				frame `_eplotframe_name': char _dta[tabtools_source] "effecttab"
			}
		capture drop _eplot_est* _eplot_ll* _eplot_ul* _eplot_p*

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
	replace title = `"`title'"' if _n == 1

	* Track Reference rows for merged cell formatting (after title row added)
	local ref_rows ""
	forvalues i = 1(3)`last' {
		gen ref`i' = _n if c`i' == "Reference"
		levelsof ref`i', local(ref`i'_levels)
		local ref_rows "`ref_rows' `ref`i'_levels'"
		drop ref`i'
	}
	local ref_rows: list uniq ref_rows

	local num_rows = _N
	local num_cols = c(k)
	local _xlsx_ok 0

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
			local _te_subcmd ""
			if `"`collect_cmdline_1'"' != "" {
				if regexm(`"`collect_cmdline_1'"', "^teffects[ ]+([a-z0-9_]+)") {
					local _te_subcmd = lower(regexs(1))
				}
			}
			if "`_te_subcmd'" == "" {
				local _te_subcmd = lower("`e(subcmd)'")
			}
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

	* Return statistics before any file-writing failure can abort the command
	if `_mat_nrows' > 0 {
		capture return matrix table = `_rtable'
	}
	return scalar N_rows = `num_rows'
	return scalar N_cols = `num_cols'
		return local effect_label "`effect'"
		return local type "`type'"
		return local methods "`_methods'"
		if `"`_eplotframe_name'"' != "" return local eplotframe "`_eplotframe_name'"

		if `_has_xlsx' {
			capture noisily _tabtools_xlsx_write using "`xlsx'", sheet("`sheet'") book(b)
			if _rc {
				local _export_rc = _rc
				noisily display as error "Failed to export to `xlsx', sheet `sheet'"
				noisily display as error "Check file permissions and that file is not open in Excel"
			capture erase "`temp_xlsx'"
			restore
			error `_export_rc'
		}
	}

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
	local ci_max = 0
	local p_max = 0
	forvalues i = 1(1)`n' {
		replace c`i'_length = . if _n == 2
		egen c`i'_max = max(c`i'_length)
	}
	forvalues i = 2(3)`n' {
		sum c`i'_max, meanonly
		if `r(max)' > `ci_max' local ci_max = `r(max)'
	}
	forvalues i = 3(3)`n' {
		sum c`i'_max, meanonly
		if `r(max)' > `p_max' local p_max = `r(max)'
	}

	local est_width = ceil(`est_max' * 0.85) + 2
	if `est_width' < 8 local est_width = 8
	if `est_width' > 22 local est_width = 22

	local ci_width = ceil(`ci_max' * 0.85) + 2
	if `ci_width' < 16 local ci_width = 16
	if `ci_width' > 34 local ci_width = 34

	local p_width = ceil(`p_max' * 0.85) + 2
	if `p_width' < 8 local p_width = 8
	if `p_width' > 12 local p_width = 12

	gen A_length = length(A)
	egen factor_length = max(A_length)
	sum factor_length, d
	local factor_length = ceil(r(max) * 0.95) + 2
	* Include effect label length in factor_length calculation
	local _effect_len = strlen(`"`effect'"')
	if ceil(`_effect_len' * 0.85) + 2 > `factor_length' {
	    local factor_length = ceil(`_effect_len' * 0.85) + 2
	}
	if `factor_length' > `_label_width_cap' local factor_length = `_label_width_cap'

	drop A_length factor_length c*_max c*_length

	* CSV export (F2) — must happen before clear
	if "`csv'" != "" {
		_tabtools_csv_write using "`csv'", labelvar(A)
	}

	* Console display
	noisily _tabtools_console_display `n' `"`title'"', labelvar(A)

	* Markdown export
	local _ret_markdown ""
	local _ret_markdown_rows .
	local _ret_markdown_cols .
	if `"`markdown'"' != "" {
		local _mdappend_opt ""
		if "`mdappend'" != "" local _mdappend_opt "append"
		capture noisily _tabtools_markdown_write using `"`markdown'"', ///
			`_mdappend_opt' labelvar(A) title(`"`title'"') footnote(`"`footnote'"') strictheaders
		if _rc {
			local _md_rc = _rc
			noisily display as error "Failed to export Markdown to `markdown'"
			restore
			exit `_md_rc'
		}
		local _ret_markdown `"`markdown'"'
		local _ret_markdown_rows = r(n_rows)
		local _ret_markdown_cols = r(n_cols)
		noisily display as text "Markdown exported to `markdown'"
	}

	* Store output in frame if requested
	if `"`frame'"' != "" {
		_tabtools_frame_put `"`frame'"'
		local frame "`_frame_name'"
		if `"`_eplotframe_name'"' != "" {
			frame `frame': char _dta[tabtools_eplotframe] "`_eplotframe_name'"
		}
		return local frame "`frame'"
	}
	if `"`_ret_markdown'"' != "" {
		return local markdown `"`_ret_markdown'"'
		return scalar markdown_rows = `_ret_markdown_rows'
		return scalar markdown_cols = `_ret_markdown_cols'
	}

	if `_has_xlsx' {
	* =========================================================================
	* APPLY EXCEL FORMATTING (MATA)
	* =========================================================================

	* Pre-extract p-value data for conditional formatting
	if `has_boldp' | `has_highlight' {
		local _n_models = `n' / 3
		forvalues _m = 1/`_n_models' {
			forvalues _dr = 4/`num_rows' {
				capture {
					local _pstr = c`=`_m'*3'[`_dr']
					local _pstr = strtrim("`_pstr'")
					if substr("`_pstr'", 1, 1) == "<" {
						local _bp_m`_m'_r`_dr' = 0
					}
					else {
						local _bp_m`_m'_r`_dr' = real("`_pstr'")
					}
				}
				if _rc local _bp_m`_m'_r`_dr' = .
			}
		}
	}

		capture {
			local _hborder_code = 1
			if "`_hborder'" == "medium" local _hborder_code = 2
			if "`_hborder'" == "thick" local _hborder_code = 3
			if "`_hborder'" == "none" local _hborder_code = 4
			local _vborder_code = 1
			if "`borderstyle'" == "medium" local _vborder_code = 2
			if "`borderstyle'" == "thick" local _vborder_code = 3
			if "`borderstyle'" == "none" local _vborder_code = 4

			tempname _style_rules
			local _style_rule_rows ""
			local _style_rule_rows `"`_style_rule_rows' | 12, 1, 1, 1, 1, 30, 0, 0, 0"'
			local _style_rule_rows `"`_style_rule_rows' | 13, 1, 1, 1, 1, 1, 0, 0, 0"'
			local _style_rule_rows `"`_style_rule_rows' | 13, 1, 1, 2, 2, `factor_length', 0, 0, 0"'
			forvalues i = 3(3)`=`num_cols'-2' {
				local _style_rule_rows `"`_style_rule_rows' | 13, 1, 1, `i', `i', `est_width', 0, 0, 0"'
			}
			forvalues i = 4(3)`=`num_cols'-1' {
				local _style_rule_rows `"`_style_rule_rows' | 13, 1, 1, `i', `i', `ci_width', 0, 0, 0"'
			}
			forvalues i = 5(3)`num_cols' {
				local _style_rule_rows `"`_style_rule_rows' | 13, 1, 1, `i', `i', `p_width', 0, 0, 0"'
			}
			local _total_model_width = `est_width' + `ci_width' + `p_width'
			if `=`max_header_length'*.9' > `_total_model_width' {
				local headerheight = ceil(`=`max_header_length'*.9'/`_total_model_width')
				local _style_rule_rows `"`_style_rule_rows' | 12, 2, 2, 1, 1, `=`headerheight'*15', 0, 0, 0"'
			}
			* Wrap + top-align the label column so labels exceeding the capped
			* width flow onto extra lines instead of being clipped.
			if `num_rows' >= 4 {
				local _style_rule_rows `"`_style_rule_rows' | 4, 4, `num_rows', 2, 2, 0, 1, 0, 0"'
				local _style_rule_rows `"`_style_rule_rows' | 6, 4, `num_rows', 2, 2, 0, 3, 0, 0"'
			}

			local _style_rule_rows `"`_style_rule_rows' | 1, 1, `num_rows', 1, `num_cols', `_fontsize', 1, 0, 0"'
			local _style_rule_rows `"`_style_rule_rows' | 1, 1, 1, 1, `num_cols', `=`_fontsize'+2', 1, 0, 0"'
			local _style_rule_rows `"`_style_rule_rows' | 14, 1, 1, 1, `num_cols', 0, 0, 0, 0"'
			local _style_rule_rows `"`_style_rule_rows' | 4, 1, 1, 1, 1, 0, 1, 0, 0"'
			local _style_rule_rows `"`_style_rule_rows' | 5, 1, 1, 1, 1, 0, 1, 0, 0"'
			local _style_rule_rows `"`_style_rule_rows' | 6, 1, 1, 1, 1, 0, 2, 0, 0"'
			local _style_rule_rows `"`_style_rule_rows' | 2, 1, 1, 1, 1, 0, 1, 0, 0"'
			if "`headershade'" != "" {
				local _style_rule_rows `"`_style_rule_rows' | 7, 2, 3, 2, `num_cols', 0, -1, 0, 0"'
			}
			local _style_rule_rows `"`_style_rule_rows' | 2, 3, 3, 2, `num_cols', 0, 1, 0, 0"'
			local _style_rule_rows `"`_style_rule_rows' | 5, 3, 3, 2, `num_cols', 0, 2, 0, 0"'
			local _style_rule_rows `"`_style_rule_rows' | 6, 3, 3, 2, `num_cols', 0, 2, 0, 0"'

			foreach row of local ref_rows {
				local col_num = 3
				while `col_num' <= `n' {
					local _col_end = `col_num' + 2
					local _style_rule_rows `"`_style_rule_rows' | 14, `row', `row', `col_num', `_col_end', 0, 0, 0, 0"'
					local _style_rule_rows `"`_style_rule_rows' | 5, `row', `row', `col_num', `col_num', 0, 2, 0, 0"'
					local _style_rule_rows `"`_style_rule_rows' | 6, `row', `row', `col_num', `col_num', 0, 2, 0, 0"'
					local _style_rule_rows `"`_style_rule_rows' | 3, `row', `row', `col_num', `col_num', 0, 1, 0, 0"'
					local col_num = `col_num' + 3
				}
			}

			local col_num = 3
			while `col_num' <= `n' {
				local _col_end = `col_num' + 2
				local _style_rule_rows `"`_style_rule_rows' | 14, 2, 2, `col_num', `_col_end', 0, 0, 0, 0"'
				local _style_rule_rows `"`_style_rule_rows' | 5, 2, 2, `col_num', `col_num', 0, 2, 0, 0"'
				local _style_rule_rows `"`_style_rule_rows' | 6, 2, 2, `col_num', `col_num', 0, 2, 0, 0"'
				local _style_rule_rows `"`_style_rule_rows' | 2, 2, 2, `col_num', `col_num', 0, 1, 0, 0"'
				local _style_rule_rows `"`_style_rule_rows' | 4, 2, 2, `col_num', `col_num', 0, 1, 0, 0"'
				if "`borderstyle'" != "academic" {
					local _style_rule_rows `"`_style_rule_rows' | 11, 2, `num_rows', `_col_end', `_col_end', 0, `_vborder_code', 0, 0"'
				}
				local col_num = `col_num' + 3
			}

			local _style_rule_rows `"`_style_rule_rows' | 8, 2, 2, 2, `num_cols', 0, `_hborder_code', 0, 0"'
			local _style_rule_rows `"`_style_rule_rows' | 8, 3, 3, 3, `num_cols', 0, `_hborder_code', 0, 0"'
			local _style_rule_rows `"`_style_rule_rows' | 9, 3, 3, 2, `num_cols', 0, `_hborder_code', 0, 0"'
			local _style_rule_rows `"`_style_rule_rows' | 9, `num_rows', `num_rows', 2, `num_cols', 0, `_hborder_code', 0, 0"'
			if "`borderstyle'" != "academic" {
				local _style_rule_rows `"`_style_rule_rows' | 11, 2, `num_rows', `num_cols', `num_cols', 0, `_vborder_code', 0, 0"'
				local _style_rule_rows `"`_style_rule_rows' | 10, 2, `num_rows', 2, 2, 0, `_vborder_code', 0, 0"'
				local _style_rule_rows `"`_style_rule_rows' | 11, 2, `num_rows', 2, 2, 0, `_vborder_code', 0, 0"'
			}
			if "`zebra'" != "" {
				forvalues _zr = 5(2)`num_rows' {
					local _style_rule_rows `"`_style_rule_rows' | 7, `_zr', `_zr', 2, `num_cols', 0, -2, 0, 0"'
				}
			}
			if `num_rows' >= 4 {
				local _style_rule_rows `"`_style_rule_rows' | 5, 4, `num_rows', 3, `num_cols', 0, 2, 0, 0"'
			}
			if `has_boldp' | `has_highlight' {
				forvalues _m = 1/`_n_models' {
					local _pcol = 2 + `_m' * 3
					forvalues _dr = 4/`num_rows' {
						local _pnum = `_bp_m`_m'_r`_dr''
						if `_pnum' < . {
							if `has_boldp' & `_pnum' < `boldp' {
								local _style_rule_rows `"`_style_rule_rows' | 2, `_dr', `_dr', `_pcol', `_pcol', 0, 1, 0, 0"'
							}
							if `has_highlight' & `_pnum' < `highlight' {
								local _style_rule_rows `"`_style_rule_rows' | 7, `_dr', `_dr', 2, `num_cols', 0, -3, 0, 0"'
							}
						}
					}
				}
			}
			if `"`footnote'"' != "" {
				local _fn_row = `num_rows' + 1
				local _fn_fontsize = max(`_fontsize' - 2, 6)
				mata: b.put_string(`_fn_row', 2, `"`footnote'"')
				local _style_rule_rows `"`_style_rule_rows' | 14, `_fn_row', `_fn_row', 2, `num_cols', 0, 0, 0, 0"'
				local _style_rule_rows `"`_style_rule_rows' | 5, `_fn_row', `_fn_row', 2, 2, 0, 1, 0, 0"'
				local _style_rule_rows `"`_style_rule_rows' | 6, `_fn_row', `_fn_row', 2, 2, 0, 2, 0, 0"'
				local _style_rule_rows `"`_style_rule_rows' | 4, `_fn_row', `_fn_row', 2, 2, 0, 1, 0, 0"'
				local _style_rule_rows `"`_style_rule_rows' | 1, `_fn_row', `_fn_row', 2, 2, `_fn_fontsize', 1, 0, 0"'
				local _style_rule_rows `"`_style_rule_rows' | 3, `_fn_row', `_fn_row', 2, 2, 0, 1, 0, 0"'
			}

			_tabtools_xlsx_build_styles, matrix(`_style_rules') ///
				rules(`"`_style_rule_rows'"') cols(9)
			_tabtools_xlsx_apply_styles, book(b) sheet("`sheet'") ///
				rules(`_style_rules') font("`_font'") ///
				color1("`_headercolor'") color2("`_zebracolor'") ///
				color3("255 255 204")
			mata: b.close_book()
		}
	if _rc {
		local saved_rc = _rc
		capture mata: b.close_book()
		capture mata: mata drop b
		noisily display as error "Excel formatting failed with error `saved_rc'"
		capture erase "`temp_xlsx'"
		restore
		error `saved_rc'
	}
	capture mata: mata drop b

	} // end if _has_xlsx (Excel formatting)

	* Clean up temporary file
	capture erase "`temp_xlsx'"

	clear
	restore

	* Console confirmation (O1)
	if `_has_xlsx' {
		* QA-only hook to exercise the final missing-workbook guard.
		local _qa_erase_xlsx "$TABTOOLS_QA_EFFECTTAB_ERASE_XLSX"
		if `"`_qa_erase_xlsx'"' == `"`xlsx'"' {
			capture erase "`xlsx'"
		}
		capture confirm file "`xlsx'"
		if _rc {
			noisily display as error "Export command succeeded but file not found"
			exit 601
		}
		else {
			local _xlsx_ok 1
			noisily display as text "Exported " as result "`num_rows'" as text " rows × " as result "`num_cols'" as text " cols to " as result `"`xlsx'"' as text ", sheet " as result `"`sheet'"'
		}
	}
	if `_xlsx_ok' {
		return local xlsx "`xlsx'"
		return local sheet "`sheet'"
	}

	* Open file if requested (W3)
	if `_xlsx_ok' & "`open'" != "" _tabtools_open_file "`xlsx'"
}

	} // end capture noisily
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
*
