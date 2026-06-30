*! stratetab Version 1.8.8  2026/06/30
*! Author: Timothy P Copeland, Karolinska Institutet

/*
DESCRIPTION:
		Combines pre-computed strate output files and formats them with outcomes
		as column groups and exposure variables as rows. Output can be displayed,
		stored in a frame, exported to CSV, or exported to Excel.

	SYNTAX:
		stratetab, using(filelist) [xlsx(string)] outcomes(integer) [sheet(string) ///
		  title(string) outlabels(string) explabels(string) digits(integer 1) ///
		  eventdigits(integer 0) pydigits(integer 0) unitlabel(string) ///
		  pyscale(real 1) ratescale(real 1000) frame(name) display]

	using:       Space-separated list of strate output files (.dta extension added automatically)
	             Format: out1_exp1 out2_exp1 out3_exp1 out1_exp2 out2_exp2 out3_exp2 ...
	             (all outcomes for exposure 1, then all outcomes for exposure 2, etc.)
	xlsx:        Excel output file (must have .xlsx extension)
	outcomes:    Number of outcomes (required)
	sheet:       Sheet name (default: Results)
	title:       Title text for row 1
	outlabels:   Outcome labels separated by \ (e.g., "Sustained EDSS 4 \ Sustained EDSS 6 \ First Relapse")
	explabels:   Exposure group labels separated by \ (e.g., "Time-Varying HRT \ HRT Duration")
	digits:      Decimal places for rate and CI (default 1)
	eventdigits: Decimal places for events (default 0)
	pydigits:    Decimal places for person-years (default 0)
	unitlabel:   Unit label for rate column (default "1,000")
	pyscale:     Divides person-years by this value (default 1 = no scaling)
	ratescale:   Multiplies rates by this value (default 1000)
*/

program define stratetab, rclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	local _xlsx_ok 0
	local _fatal_rc 0

tempfile _userdata_outer
local _userdata_path "`_userdata_outer'"

* Save user data immediately on entry so restore always works, even if memory is empty
qui save "`_userdata_path'", emptyok

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
			noisily display as error "_tabtools_common.ado failed to load fully; reinstall tabtools"
			exit 111
		}
	}
	else {
		noisily display as error "_tabtools_common.ado not found; reinstall tabtools"
		exit 111
	}
}
_tabtools_require_helpers

syntax, using(string asis) [xlsx(string) excel(string)] outcomes(integer) ///
	[sheet(string) title(string) outlabels(string) explabels(string) ///
	digits(integer 1) eventdigits(integer 0) pydigits(integer 0) ///
	unitlabel(string) pyscale(real 1) ratescale(real 1000) ///
	rateratio RATIOdigits(integer 2) FOOTnote(string) open zebra ///
	BORDERstyle(string) THEme(string) HEADERShade ///
	HEADERColor(string) ZEBRAColor(string) csv(string) MARKdown(string) MDAPPend FRAme(string) DISplay]

* Accept excel() as synonym for xlsx()
if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
local _has_xlsx = "`xlsx'" != ""
if "`open'" != "" & !`_has_xlsx' {
	di as err "open requires xlsx() or excel()"
	exit 198
}

if `_has_xlsx' & !strmatch("`xlsx'", "*.xlsx") {
	di as err "xlsx must have .xlsx extension"
	exit 198
}

* Sanitize file path and sheet name to prevent injection
if `_has_xlsx' _tabtools_validate_path "`xlsx'" "xlsx()"
if "`csv'" != "" _tabtools_validate_path "`csv'" "csv()"
if "`mdappend'" != "" & `"`markdown'"' == "" {
	di as err "mdappend requires markdown()"
	exit 198
}
if `"`markdown'"' != "" {
	_tabtools_validate_path `"`markdown'"' "markdown()"
	local _md_lower = lower(`"`markdown'"')
	if !(strmatch(`"`_md_lower'"', "*.md") | ///
		 strmatch(`"`_md_lower'"', "*.markdown") | ///
		 strmatch(`"`_md_lower'"', "*.qmd") | ///
		 strmatch(`"`_md_lower'"', "*.rmd")) {
		di as err "markdown() must specify a .md, .markdown, .qmd, or .rmd file"
		exit 198
	}
}
if "`sheet'" != "" {
	_tabtools_validate_sheet "`sheet'" "sheet()"
}

if `digits' < 0 | `digits' > 10 | `eventdigits' < 0 | `eventdigits' > 10 | `pydigits' < 0 | `pydigits' > 10 {
	di as err "digit options must be 0-10"
	exit 198
}

if `pyscale' <= 0 {
	di as err "pyscale must be positive"
	exit 198
}

if `ratescale' <= 0 {
	di as err "ratescale must be positive"
	exit 198
}

if `outcomes' < 1 {
	di as err "outcomes must be at least 1"
	exit 198
}

	* Resolve formatting
	_tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle') headershade(`headershade') zebra(`zebra')

	_tabtools_resolve_colors, headercolor(`"`headercolor'"') zebracolor(`"`zebracolor'"')

	* Validate ratiodigits
if `ratiodigits' < 0 | `ratiodigits' > 10 {
	di as err "ratiodigits must be 0-10"
	exit 198
}

local n_files : word count `using'
if mod(`n_files', `outcomes') != 0 {
	di as err "Number of files must be divisible by number of outcomes"
	exit 198
}

local n_exposures = `n_files' / `outcomes'
if "`rateratio'" != "" & `n_exposures' < 2 {
	di as err "rateratio requires at least two exposure groups"
	exit 198
}

	* Sanitize file paths in using()
	foreach file of local using {
	if regexm("`file'", "[;&|><\$\`]") {
		di as err "using() contains invalid characters: `file'"
		exit 198
	}
}

* Parse outcome labels
if "`outlabels'" != "" {
	local outlabels = subinstr("`outlabels'", " \ ", "\", .)
	local outlabels = subinstr("`outlabels'", "\  ", "\", .)
	local outlabels = subinstr("`outlabels'", "  \", "\", .)
	tokenize `"`outlabels'"', parse("\")
	local n_outlabs = 0
	forvalues i = 1/100 {
		local j = (`i'-1)*2 + 1
		if "``j''" == "" continue, break
		local n_outlabs = `n_outlabs' + 1
		local outlab`i' = strtrim("``j''")
	}
	if `n_outlabs' != `outcomes' {
		di as err "Number of outcome labels (`n_outlabs') must match outcomes (`outcomes')"
		exit 198
	}
}
else {
	forvalues i = 1/`outcomes' {
		local outlab`i' "Outcome `i'"
	}
}

* Parse exposure labels
if "`explabels'" != "" {
	local explabels = subinstr("`explabels'", " \ ", "\", .)
	local explabels = subinstr("`explabels'", "\  ", "\", .)
	local explabels = subinstr("`explabels'", "  \", "\", .)
	tokenize `"`explabels'"', parse("\")
	local n_explabs = 0
	forvalues i = 1/100 {
		local j = (`i'-1)*2 + 1
		if "``j''" == "" continue, break
		local n_explabs = `n_explabs' + 1
		local explab`i' = strtrim("``j''")
	}
	if `n_explabs' != `n_exposures' {
		di as err "Number of exposure labels (`n_explabs') must match number of exposure groups (`n_exposures')"
		exit 198
	}
}
else {
	forvalues i = 1/`n_exposures' {
		local explab`i' "Exposure `i'"
	}
}

qui {

* Set default unit label
if "`unitlabel'" == "" {
	local unitlabel "1,000"
}

* Process each file and store data
* Files are organized: out1_exp1 out2_exp1 out3_exp1 out1_exp2 out2_exp2 out3_exp2 ...
local filenum = 0
forvalues e = 1/`n_exposures' {
	forvalues o = 1/`outcomes' {
		local filenum = `filenum' + 1
		local file : word `filenum' of `using'
		
		preserve
		cap use "`file'.dta", clear
		if _rc {
			noi di as err "File not found: `file'.dta"
			noi di as err "Hint: using() expects strate output file names without .dta extension"
			restore
			exit 601
		}
		
		cap confirm var _Rate _Lower _Upper _D _Y
		if _rc {
			noi di as err "`file'.dta missing required columns"
			noi di as err "Hint: file must contain _Rate, _Lower, _Upper, _D, and _Y from strate output"
			restore
			exit 111
		}
		
		* Find the categorical variable
		unab allvars : *
		local catvar ""
		foreach v of local allvars {
			if "`v'" != "_D" & "`v'" != "_Y" & "`v'" != "_Rate" & "`v'" != "_Lower" & "`v'" != "_Upper" {
				local catvar "`v'"
				continue, break
			}
		}
		
		* Convert categorical to string if needed
		cap confirm string var `catvar'
		if _rc {
			* Check if variable has a value label before decoding
			local vallabel : value label `catvar'
			if "`vallabel'" != "" {
				decode `catvar', gen(catvar_str)
			}
			else {
				* No value label - convert to string directly
				gen catvar_str = string(`catvar')
			}
			}
			else {
				gen catvar_str = `catvar'
			}
			replace catvar_str = strtrim(catvar_str)
			qui count if catvar_str == ""
			if r(N) > 0 {
				noi di as err "Blank category labels are not allowed in `file'.dta"
				restore
				exit 198
			}
			tempvar _dup_cat _obs_id
			gen long `_obs_id' = _n
			qui bysort catvar_str: gen byte `_dup_cat' = (_N > 1)
			sort `_obs_id'
			qui count if `_dup_cat'
			if r(N) > 0 {
				noi di as err "Duplicate category labels found in `file'.dta"
				noi di as err "Each strate file must have unique category labels"
				restore
				exit 198
			}
			
			* Scale and format rate
			gen double _Rate_scaled = _Rate * `ratescale'
			gen double _Lower_scaled = _Lower * `ratescale'
			gen double _Upper_scaled = _Upper * `ratescale'
			
			* Store and validate canonical categories for this exposure
			if `o' == 1 {
				local ncat_e`e' = _N
				forvalues i = 1/`=_N' {
					local cat_e`e'_`i' = catvar_str[`i']
					local D_o`o'_e`e'_`i' = _D[`i']
					local Y_o`o'_e`e'_`i' = _Y[`i'] / `pyscale'
					local Rate_o`o'_e`e'_`i' = _Rate_scaled[`i']
					local Lower_o`o'_e`e'_`i' = _Lower_scaled[`i']
					local Upper_o`o'_e`e'_`i' = _Upper_scaled[`i']
				}
			}
			else {
				if _N != `ncat_e`e'' {
					noi di as err "Category count mismatch for exposure `e': outcome 1 has `ncat_e`e'' categories but outcome `o' has `=_N'"
					noi di as err "All outcome files for the same exposure must have identical categories"
					restore
					exit 198
				}
				forvalues i = 1/`ncat_e`e'' {
					local _target_cat `"`cat_e`e'_`i''"'
					local _match_row = 0
					local _match_count = 0
					forvalues _j = 1/`=_N' {
						local _current_cat = catvar_str[`_j']
						if `"`_current_cat'"' == `"`_target_cat'"' {
							local _match_row = `_j'
							local _match_count = `_match_count' + 1
						}
					}
					if `_match_count' != 1 {
						noi di as err "Category label mismatch for exposure `e', outcome `o' in `file'.dta"
						noi di as err `"Expected category `"_target_cat'" from outcome 1"'
						restore
						exit 198
					}
					local D_o`o'_e`e'_`i' = _D[`_match_row']
					local Y_o`o'_e`e'_`i' = _Y[`_match_row'] / `pyscale'
					local Rate_o`o'_e`e'_`i' = _Rate_scaled[`_match_row']
					local Lower_o`o'_e`e'_`i' = _Lower_scaled[`_match_row']
					local Upper_o`o'_e`e'_`i' = _Upper_scaled[`_match_row']
				}
			}
			
			restore
		}
	}

* Compute rate ratios if requested (F4)
if "`rateratio'" != "" & `n_exposures' >= 2 {
	forvalues e = 2/`n_exposures' {
		forvalues o = 1/`outcomes' {
			forvalues i = 1/`ncat_e`e'' {
				local _target_cat `"`cat_e`e'_`i''"'
				local _ref_i = 0
				local _ref_count = 0
				forvalues _j = 1/`ncat_e1' {
					if `"`cat_e1_`_j''"' == `"`_target_cat'"' {
						local _ref_i = `_j'
						local _ref_count = `_ref_count' + 1
					}
				}
				if `_ref_count' != 1 {
					noi di as err "rateratio requires exposure `e' categories to match exposure 1"
					noi di as err `"No unique match for category `"_target_cat'" in exposure 1"'
					exit 198
				}
				local _d_ref = `D_o`o'_e1_`_ref_i''
				local _d_exp = `D_o`o'_e`e'_`i''
				local _r_ref = `Rate_o`o'_e1_`_ref_i''
				local _r_exp = `Rate_o`o'_e`e'_`i''
				if `_d_ref' > 0 & `_d_exp' > 0 & `_r_ref' > 0 {
					local _irr = `_r_exp' / `_r_ref'
					local _se_ln = sqrt(1/`_d_exp' + 1/`_d_ref')
					local IRR_o`o'_e`e'_`i' = `_irr'
					local IRRlo_o`o'_e`e'_`i' = exp(ln(`_irr') - 1.96 * `_se_ln')
					local IRRhi_o`o'_e`e'_`i' = exp(ln(`_irr') + 1.96 * `_se_ln')
				}
				else {
					local IRR_o`o'_e`e'_`i' .
					local IRRlo_o`o'_e`e'_`i' .
					local IRRhi_o`o'_e`e'_`i' .
				}
			}
		}
	}
}

* Build output dataset
clear
local _cols_per_outcome = 3
if "`rateratio'" != "" local _cols_per_outcome = 4
local ncols = 1 + `outcomes' * `_cols_per_outcome'
forvalues c = 1/`ncols' {
	quietly gen str244 c`c' = ""
}
quietly gen str244 title = ""

* Row 1: Title (in title column, will be merged across all)
quietly set obs 1
quietly replace title = "`title'" in 1

* Row 2: Outcome headers (merged across columns)
local new = _N + 1
quietly set obs `new'
quietly replace c1 = "Exposure" in `new'
local col = 2
forvalues o = 1/`outcomes' {
	quietly replace c`col' = "`outlab`o''" in `new'
	local col = `col' + `_cols_per_outcome'
}

* Row 3: Sub-headers (Events, Person-Years, Rate [, IRR])
local new = _N + 1
quietly set obs `new'
quietly replace c1 = "Exposure" in `new'
local col = 2
forvalues o = 1/`outcomes' {
	quietly replace c`col' = "Events" in `new'
	local col = `col' + 1
	quietly replace c`col' = "Person-Years (PY)" in `new'
	local col = `col' + 1
	quietly replace c`col' = "Per `unitlabel' PY (95% CI)" in `new'
	local col = `col' + 1
	if "`rateratio'" != "" {
		quietly replace c`col' = "IRR (95% CI)" in `new'
		local col = `col' + 1
	}
}

* Data rows by exposure group
forvalues e = 1/`n_exposures' {
	* Exposure header row
	local new = _N + 1
	quietly set obs `new'
	quietly replace c1 = "`explab`e''" in `new'
	
	* Category rows (indented)
	forvalues i = 1/`ncat_e`e'' {
		local new = _N + 1
		quietly set obs `new'
		quietly replace c1 = "   `cat_e`e'_`i''" in `new'
		
		local col = 2
		forvalues o = 1/`outcomes' {
			* Events
			if `eventdigits' == 0 {
				local ev_fmt = string(`D_o`o'_e`e'_`i'', "%11.0fc")
			}
			else {
				local ev_fmt = string(`D_o`o'_e`e'_`i'', "%11.`eventdigits'fc")
			}
			quietly replace c`col' = "`ev_fmt'" in `new'
			local col = `col' + 1

			* Person-years
			if `pydigits' == 0 {
				local py_fmt = string(round(`Y_o`o'_e`e'_`i'',1), "%11.0fc")
			}
			else {
				local py_fmt = string(`Y_o`o'_e`e'_`i'', "%11.`pydigits'fc")
			}
			quietly replace c`col' = "`py_fmt'" in `new'
			local col = `col' + 1

			* Rate (95% CI)
			local rt_fmt = strtrim(string(round(`Rate_o`o'_e`e'_`i'',10^(-`digits')), "%11.`digits'f")) + ///
				" (" + strtrim(string(round(`Lower_o`o'_e`e'_`i'',10^(-`digits')), "%11.`digits'f")) + ///
				"-" + strtrim(string(round(`Upper_o`o'_e`e'_`i'',10^(-`digits')), "%11.`digits'f")) + ")"
			quietly replace c`col' = "`rt_fmt'" in `new'
			local col = `col' + 1

			* Rate Ratio (IRR) if requested
			if "`rateratio'" != "" {
				if `e' == 1 {
					quietly replace c`col' = "Ref." in `new'
				}
				else if missing(`IRR_o`o'_e`e'_`i'') {
					quietly replace c`col' = "–" in `new'
				}
				else {
					local irr_fmt = strtrim(string(round(`IRR_o`o'_e`e'_`i'', 10^(-`ratiodigits')), "%11.`ratiodigits'f")) + ///
						" (" + strtrim(string(round(`IRRlo_o`o'_e`e'_`i'', 10^(-`ratiodigits')), "%11.`ratiodigits'f")) + ///
						"-" + strtrim(string(round(`IRRhi_o`o'_e`e'_`i'', 10^(-`ratiodigits')), "%11.`ratiodigits'f")) + ")"
					quietly replace c`col' = "`irr_fmt'" in `new'
				}
				local col = `col' + 1
			}
		}
	}
}

* Identify exposure header rows (for borders)
local lastrow = _N
tempvar exp_row
gen `exp_row' = (c2 == "" & c1 != "" & c1 != "Exposure" & _n > 3)
local exp_rows ""
forvalues r = 4/`lastrow' {
	if `exp_row'[`r'] == 1 {
		local exp_rows "`exp_rows' `r'"
	}
}
drop `exp_row'

* CSV export (if requested)
if "`csv'" != "" {
	_tabtools_validate_path "`csv'" "csv()"
	order title c*
	_tabtools_csv_write using "`csv'"
}

local sht = cond("`sheet'" != "", "`sheet'", "Results")
_tabtools_validate_sheet "`sht'" "sheet()"
local _ret_markdown ""
local _ret_markdown_rows .
local _ret_markdown_cols .
if `"`markdown'"' != "" {
	local _mdappend_opt ""
	if "`mdappend'" != "" local _mdappend_opt "append"
	capture noisily _tabtools_markdown_write using `"`markdown'"', ///
		`_mdappend_opt' title(`"`title'"') footnote(`"`footnote'"') strictheaders
	if _rc {
		local _md_rc = _rc
		noi di as err "Failed to export Markdown to `markdown'"
		qui use "`_userdata_path'", clear
		set varabbrev `_orig_varabbrev'
		exit `_md_rc'
	}
	local _ret_markdown `"`markdown'"'
	local _ret_markdown_rows = r(n_rows)
	local _ret_markdown_cols = r(n_cols)
	noi di as text "Markdown exported to `markdown'"
}
* Console display
noisily _tabtools_console_display `ncols' `"`title'"', datastart(4)

* Frame output
if `"`frame'"' != "" {
	_tabtools_frame_put `"`frame'"'
	local frame "`_frame_name'"
}

* Build r(rates) matrix: rows = exposure categories, columns = outcomes
* Each cell contains the rate per exposure-category × outcome
tempname _rrates
local _total_cats 0
forvalues e = 1/`n_exposures' {
	local _total_cats = `_total_cats' + `ncat_e`e''
}
	if `_total_cats' > 0 {
			matrix `_rrates' = J(`_total_cats', `outcomes', .)
			local _rnames ""
			local _used_rnames ""
			local _rr = 0
			forvalues e = 1/`n_exposures' {
				forvalues i = 1/`ncat_e`e'' {
				local _rr = `_rr' + 1
				forvalues o = 1/`outcomes' {
				capture matrix `_rrates'[`_rr', `o'] = `Rate_o`o'_e`e'_`i''
			}
				local _rname = subinstr("`cat_e`e'_`i''", " ", "_", .)
				local _rname = substr("`_rname'", 1, 32)
				if "`_rname'" == "" local _rname "row`_rr'"
					if `n_exposures' > 1 {
						local _rname = "e`e'_`_rname'"
						local _rname = substr("`_rname'", 1, 32)
					}
					local _base_rname "`_rname'"
					local _rname_i = 1
					while strpos(" `_used_rnames' ", " `_rname' ") {
						local ++_rname_i
						local _suffix "_`_rname_i'"
						local _stem_len = 32 - strlen("`_suffix'")
						local _rname = substr("`_base_rname'", 1, `_stem_len')
						local _rname "`_rname'`_suffix'"
					}
					local _used_rnames "`_used_rnames' `_rname'"
					local _rnames "`_rnames' `_rname'"
				}
				}
		local _cnames ""
		forvalues o = 1/`outcomes' {
			local _cname = subinstr(`"`outlab`o''"', " ", "_", .)
			local _cname = subinstr("`_cname'", ".", "_", .)
			local _cname = subinstr("`_cname'", ",", "", .)
			local _cname = substr("`_cname'", 1, 32)
			if "`_cname'" == "" local _cname "outcome`o'"
			local _cnames "`_cnames' `_cname'"
		}
		capture matrix rownames `_rrates' = `_rnames'
		capture matrix colnames `_rrates' = `_cnames'
	}

* Build r(ratios) matrix if rate ratios were computed
tempname _rratios
if "`rateratio'" != "" & `n_exposures' >= 2 {
	local _ratio_cats 0
	forvalues e = 2/`n_exposures' {
		local _ratio_cats = `_ratio_cats' + `ncat_e`e''
	}
		if `_ratio_cats' > 0 {
				matrix `_rratios' = J(`_ratio_cats', `outcomes', .)
				local _rnames ""
				local _used_rnames ""
				local _rr = 0
				forvalues e = 2/`n_exposures' {
					forvalues i = 1/`ncat_e`e'' {
					local _rr = `_rr' + 1
				forvalues o = 1/`outcomes' {
					capture matrix `_rratios'[`_rr', `o'] = `IRR_o`o'_e`e'_`i''
				}
					local _rname = subinstr("`cat_e`e'_`i''", " ", "_", .)
					local _rname = substr("`_rname'", 1, 32)
					if "`_rname'" == "" local _rname "row`_rr'"
						if `n_exposures' > 2 {
							local _rname = "e`e'_`_rname'"
							local _rname = substr("`_rname'", 1, 32)
						}
						local _base_rname "`_rname'"
						local _rname_i = 1
						while strpos(" `_used_rnames' ", " `_rname' ") {
							local ++_rname_i
							local _suffix "_`_rname_i'"
							local _stem_len = 32 - strlen("`_suffix'")
							local _rname = substr("`_base_rname'", 1, `_stem_len')
							local _rname "`_rname'`_suffix'"
						}
						local _used_rnames "`_used_rnames' `_rname'"
						local _rnames "`_rnames' `_rname'"
					}
				}
			local _cnames ""
			forvalues o = 1/`outcomes' {
				local _cname = subinstr(`"`outlab`o''"', " ", "_", .)
				local _cname = subinstr("`_cname'", ".", "_", .)
				local _cname = subinstr("`_cname'", ",", "", .)
				local _cname = substr("`_cname'", 1, 32)
				if "`_cname'" == "" local _cname "outcome`o'"
				local _cnames "`_cnames' `_cname'"
			}
			capture matrix rownames `_rratios' = `_rnames'
			capture matrix colnames `_rratios' = `_cnames'
		}
	}

* Return results
	if `_total_cats' > 0 {
		capture return matrix rates = `_rrates'
	}
	if "`rateratio'" != "" & `n_exposures' >= 2 {
		capture return matrix ratios = `_rratios'
	}
if "`frame'" != "" return local frame "`frame'"
if `"`_ret_markdown'"' != "" {
	return local markdown `"`_ret_markdown'"'
	return scalar markdown_rows = `_ret_markdown_rows'
	return scalar markdown_cols = `_ret_markdown_cols'
}
return scalar N_rows = `lastrow'
return scalar N_exposures = `n_exposures'
return scalar N_outcomes = `outcomes'

	* Export to Excel
	if `_has_xlsx' {
		order title c*
		capture noisily _tabtools_xlsx_write using "`xlsx'", sheet("`sht'") book(b)
		if _rc {
			local saved_rc = _rc
			noi di as err "Failed to export to `xlsx'"
			noi di as err "Hint: ensure the xlsx file is not open in another application"
		qui use "`_userdata_path'", clear
		set varabbrev `_orig_varabbrev'
		local _fatal_rc = `saved_rc'
		exit `saved_rc'
	}
	else {
			* Apply formatting (Mata xl()) in the open workbook returned by
			* _tabtools_xlsx_write; avoid a save/reload pass.
			local _total_cols = `ncols' + 1
			local _xlsx_widths "1 18"
			forvalues col = 3/`_total_cols' {
				local _data_col = `col' - 1
				local _hdr = c`_data_col'[3]
				local _hdrlen = strlen("`_hdr'")
				local _cw = max(8, `_hdrlen' + 2)
				local _xlsx_widths "`_xlsx_widths' `_cw'"
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
				matrix `_style_rules' = (12, 1, 1, 1, 1, 30, 0, 0, 0)
				local _width_col = 1
				foreach _width of numlist `_xlsx_widths' {
					matrix `_style_rules' = `_style_rules' \ ///
						(13, 1, 1, `_width_col', `_width_col', `_width', 0, 0, 0)
					local ++_width_col
				}
				matrix `_style_rules' = `_style_rules' \ ///
					(1, 1, `lastrow', 1, `_total_cols', `_fontsize', 1, 0, 0) \ ///
					(1, 1, 1, 1, `_total_cols', `=`_fontsize'+2', 1, 0, 0) \ ///
					(14, 1, 1, 1, `_total_cols', 0, 0, 0, 0) \ ///
					(2, 1, 1, 1, 1, 0, 1, 0, 0) \ ///
					(4, 1, 1, 1, 1, 0, 1, 0, 0) \ ///
					(5, 1, 1, 1, 1, 0, 1, 0, 0) \ ///
					(6, 1, 1, 1, 1, 0, 2, 0, 0) \ ///
					(8, 2, 2, 2, `_total_cols', 0, `_hborder_code', 0, 0) \ ///
					(9, 3, 3, 2, `_total_cols', 0, `_hborder_code', 0, 0)

				local col = 3
				forvalues o = 1/`outcomes' {
					local _col_end = `col' + `_cols_per_outcome' - 1
					matrix `_style_rules' = `_style_rules' \ ///
						(14, 2, 2, `col', `_col_end', 0, 0, 0, 0) \ ///
						(2, 2, 2, `col', `col', 0, 1, 0, 0) \ ///
						(5, 2, 2, `col', `col', 0, 2, 0, 0) \ ///
						(6, 2, 2, `col', `col', 0, 3, 0, 0) \ ///
						(9, 2, 2, `col', `_col_end', 0, `_hborder_code', 0, 0)
					local col = `col' + `_cols_per_outcome'
				}

				matrix `_style_rules' = `_style_rules' \ ///
					(14, 2, 3, 2, 2, 0, 0, 0, 0) \ ///
					(2, 2, 3, 2, 2, 0, 1, 0, 0) \ ///
					(5, 2, 3, 2, 2, 0, 2, 0, 0) \ ///
					(6, 2, 3, 2, 2, 0, 2, 0, 0) \ ///
					(9, 3, 3, 2, 2, 0, `_hborder_code', 0, 0) \ ///
					(2, 3, 3, 3, `_total_cols', 0, 1, 0, 0) \ ///
					(5, 3, 3, 3, `_total_cols', 0, 2, 0, 0) \ ///
					(6, 3, 3, 3, `_total_cols', 0, 2, 0, 0)

				if "`headershade'" != "" {
					matrix `_style_rules' = `_style_rules' \ ///
						(7, 2, 3, 2, `_total_cols', 0, -1, 0, 0)
				}
				if "`zebra'" != "" {
					forvalues _zr = 5(2)`lastrow' {
						matrix `_style_rules' = `_style_rules' \ ///
							(7, `_zr', `_zr', 2, `_total_cols', 0, -2, 0, 0)
					}
				}
				if `lastrow' >= 4 & `_total_cols' >= 3 {
					matrix `_style_rules' = `_style_rules' \ ///
						(5, 4, `lastrow', 3, `_total_cols', 0, 2, 0, 0)
				}
				if "`borderstyle'" != "academic" {
					matrix `_style_rules' = `_style_rules' \ ///
						(10, 2, `lastrow', 2, 2, 0, `_vborder_code', 0, 0) \ ///
						(11, 2, `lastrow', 2, 2, 0, `_vborder_code', 0, 0)
					local col = 3
					forvalues o = 1/`outcomes' {
						local _col_end = `col' + `_cols_per_outcome' - 1
						matrix `_style_rules' = `_style_rules' \ ///
							(11, 2, `lastrow', `_col_end', `_col_end', 0, `_vborder_code', 0, 0)
						local col = `col' + `_cols_per_outcome'
					}
				}
				foreach r of local exp_rows {
					local border_row = `r' - 1
					if `border_row' > 3 {
						matrix `_style_rules' = `_style_rules' \ ///
							(9, `border_row', `border_row', 2, `_total_cols', 0, `_hborder_code', 0, 0)
					}
				}
				matrix `_style_rules' = `_style_rules' \ ///
					(9, `lastrow', `lastrow', 2, `_total_cols', 0, `_hborder_code', 0, 0)

				if `"`footnote'"' != "" {
					local _fn_row = `lastrow' + 1
					local _fn_fontsize = max(`_fontsize' - 2, 6)
					mata: b.put_string(`_fn_row', 2, `"`footnote'"')
					matrix `_style_rules' = `_style_rules' \ ///
						(14, `_fn_row', `_fn_row', 2, `_total_cols', 0, 0, 0, 0) \ ///
						(5, `_fn_row', `_fn_row', 2, 2, 0, 1, 0, 0) \ ///
						(6, `_fn_row', `_fn_row', 2, 2, 0, 2, 0, 0) \ ///
						(4, `_fn_row', `_fn_row', 2, 2, 0, 1, 0, 0) \ ///
						(1, `_fn_row', `_fn_row', 2, 2, `_fn_fontsize', 1, 0, 0) \ ///
						(3, `_fn_row', `_fn_row', 2, 2, 0, 1, 0, 0)
				}

				_tabtools_xlsx_apply_styles, book(b) sheet("`sht'") ///
					rules(`_style_rules') font("`_font'") ///
					color1("`_headercolor'") color2("`_zebracolor'")
				mata: b.close_book()
			}
			if _rc {
				local saved_rc = _rc
				capture mata: b.close_book()
				capture mata: mata drop b
				noi di as err "Excel formatting failed with error `saved_rc'"
				noi di as err "Hint: ensure the xlsx file is not open in another application"
				qui use "`_userdata_path'", clear
				set varabbrev `_orig_varabbrev'
				local _fatal_rc = `saved_rc'
				exit `saved_rc'
			}
			else {
				capture mata: mata drop b
				capture confirm file "`xlsx'"
				if _rc {
				    noisily display as error "Export command succeeded but file not found"
				    qui use "`_userdata_path'", clear
				    set varabbrev `_orig_varabbrev'
				    local _fatal_rc = 601
				    error 601
				}
				else {
					local _xlsx_ok 1
					noisily display as text "Exported to " as result `"`xlsx'"' as text ", sheet " as result `"`sheet'"'
				}
			}
			}
		}

	} // end quietly block

* Restore user data
qui use "`_userdata_path'", clear

if `_xlsx_ok' {
	return local xlsx "`xlsx'"
	return local sheet "`sht'"
}

* Open file if requested (W3)
if "`open'" != "" & `_xlsx_ok' _tabtools_open_file "`xlsx'"

} // end capture noisily
local _rc = _rc
if `_rc' == 0 & `_fatal_rc' != 0 local _rc = `_fatal_rc'
if `_rc' {
    capture qui use "`_userdata_path'", clear
}
set varabbrev `_orig_varabbrev'
if `_rc' error `_rc'
end
