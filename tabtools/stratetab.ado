*! stratetab Version 2.5.0  2026/10/06
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
		  pyscale(real 1) ratescale(real 1000) frame(name)]

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
	local _restore_needed 0
	local _frame_stage_created 0
	tempname _xlsx_book _frame_stage

capture noisily {

* preserve (not save/use): a tempfile round-trip left c(filename) pointing at
* the deleted tempfile and c(changed) at 0, so unsaved edits could later be
* discarded without Stata's "no; data in memory would be lost" guard.
preserve
local _restore_needed 1

capture putexcel close

* Auto-load shared helper programs if not already in memory
capture _tabtools_helpers_ready
if !_rc capture mata: assert(findexternal("_tt_sep_parse()") != NULL)
* (a session can hold an older _tabtools_common.ado's programs: run,
* so discard keeps them; this release's Mata must be there too)
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
	[sheet(string) title(string) outlabels(string) OUTCOMEIDs(string asis) explabels(string) ///
	digits(integer -1) eventdigits(integer 0) pydigits(integer 0) ///
	unitlabel(string) pyscale(real 1) ratescale(real 1000) ///
	rateratio RATIOdigits(integer 2) FOOTnote(string) open zebra ///
	BORDERstyle(string) FONT(string) FONTSIZE(integer -1) HEADERShade ///
	HEADERColor(string) ZEBRAColor(string) csv(string) MARKdown(string) MDAPPend FRAme(string) ///
	Level(real -1) CFormat(string) SEP(string) SMALLcells(integer -1) NOSMALLcells ///
	ZEROexact ZEROCells(string) MASKtext(string)]

* O1: cformat() is a full display format for the rate and both bounds; it
* replaces digits(), so giving both is an error.
if `"`cformat'"' != "" {
	if `digits' != -1 {
		di as err "cformat() and digits() may not be combined"
		exit 198
	}
	capture confirm numeric format `cformat'
	if _rc | regexm(`"`cformat'"', "^%-?t") {
		di as err `"cformat(): "`cformat'" is not a numeric display format"'
		exit 198
	}
}
if `digits' == -1 local digits 1
* sep() is data (help tabtools##sep): the default is applied in Mata and the
* text is joined into the cells by Mata, never re-expanded
mata: st_local("sep", st_local("sep") == "" ? ", " : st_local("sep"))
* a decimal-comma cformat() with a comma in sep(): a warning, as before
* printed (regtab and effecttab refuse it)
mata: st_local("_sep_comma", strofreal(strpos(st_local("sep"), ",") > 0))
if `_sep_comma' & ustrregexm(`"`cformat'"', "^%-?0?[0-9]*,") {
	di as text "(stratetab: cformat(`cformat') writes a decimal comma and the interval separator holds a comma: the two limits are hard to tell apart (help tabtools##sep))"
}
* Small cells: explicit option > session default (tabtools set smallcells)
* > none. nosmallcells switches a session default off for this call.
if `smallcells' != -1 & "`nosmallcells'" != "" {
	di as err "smallcells() and nosmallcells may not be combined"
	exit 198
}
if `smallcells' == -1 & "`nosmallcells'" == "" & `"$TABTOOLS_set_smallcells"' != "" {
	capture confirm integer number $TABTOOLS_set_smallcells
	if _rc | real(`"$TABTOOLS_set_smallcells"') < 0 {
		di as err `"session smallcells default "$TABTOOLS_set_smallcells" is not a nonnegative integer"'
		exit 198
	}
	local smallcells = $TABTOOLS_set_smallcells
	di as text "(tabtools: using session smallcells `smallcells')"
}
if `smallcells' == -1 local smallcells 0
if `smallcells' < 0 {
	di as err "smallcells() must be a nonnegative integer"
	exit 198
}
* zerocells(): a level with no events prints a dash or nothing in place of
* its count and rate (CI); its person-time stays unless the persontime
* suboption withholds it too. masktext(): the text of a masked event count,
* in place of <#.
_parse comma _zc_mode _zc_rest : zerocells
local zerocells = strtrim(lower(`"`_zc_mode'"'))
local _zc_rest = strtrim(lower(substr(strtrim(`"`_zc_rest'"'), 2, .)))
if !inlist(`"`zerocells'"', "", "dash", "blank") | !inlist(`"`_zc_rest'"', "", "persontime") | ///
	(`"`zerocells'"' == "" & `"`_zc_rest'"' != "") {
	di as err "zerocells() must be dash or blank, optionally with the suboption persontime: zerocells(dash, persontime)"
	exit 198
}
local _zc_pt = ("`_zc_rest'" == "persontime")
local _zero_txt = cond("`zerocells'" == "dash", "–", "")
local _mask_given = (`"`macval(masktext)'"' != "")
if `_mask_given' & `smallcells' == 0 {
	di as err "masktext() requires a small-cell threshold (smallcells() or tabtools set smallcells)"
	exit 198
}

* Accept excel() as synonym for xlsx()
if `"`macval(xlsx)'"' == "" & `"`macval(excel)'"' != "" {
    local xlsx `"`macval(excel)'"'
}
* Session destinations (tabtools set workbook/markdown) apply only when
* sheet() asks for a sheet; an explicit option wins (as in corrtab). The
* first write to the session workbook starts it over: _tabtools_xlsx_write
* calls _tabtools_set_sinks xlsxstart for every write.
if `"`macval(sheet)'"' != "" {
	_tabtools_set_sinks resolve, xlsx(`"`xlsx'"') markdown(`"`markdown'"') `mdappend'
	local xlsx `"`_ss_xlsx'"'
	local markdown `"`_ss_md'"'
	local mdappend "`_ss_mdappend'"
	if `"`macval(xlsx)'"' == "" {
		di as text "(tabtools: sheet() ignored; no xlsx() and no session workbook)"
	}
}
local _has_xlsx = `"`macval(xlsx)'"' != ""
if "`open'" != "" & !`_has_xlsx' {
	di as err "open requires xlsx() or excel()"
	exit 198
}

if `_has_xlsx' & !strmatch(lower(`"`macval(xlsx)'"'), "*.xlsx") {
	di as err "xlsx must have .xlsx extension"
	exit 198
}

* Sanitize file path and sheet name to prevent injection
if `_has_xlsx' {
    _tabtools_validate_path `"`macval(xlsx)'"' "xlsx()"
}
if `"`macval(csv)'"' != "" {
    _tabtools_validate_path `"`macval(csv)'"' "csv()"
}
if "`mdappend'" != "" & `"`macval(markdown)'"' == "" {
	di as err "mdappend requires markdown()"
	exit 198
}
if `"`macval(markdown)'"' != "" {
	_tabtools_validate_path `"`macval(markdown)'"' "markdown()"
	local _md_lower = lower(`"`macval(markdown)'"')
	if !(strmatch(`"`macval(_md_lower)'"', "*.md") | ///
		 strmatch(`"`macval(_md_lower)'"', "*.markdown") | ///
		 strmatch(`"`macval(_md_lower)'"', "*.qmd") | ///
		 strmatch(`"`macval(_md_lower)'"', "*.rmd")) {
		di as err "markdown() must specify a .md, .markdown, .qmd, or .rmd file"
		exit 198
	}
}
_tabtools_check_sinks, xlsx(`"`macval(xlsx)'"') csv(`"`macval(csv)'"') markdown(`"`macval(markdown)'"')
if `"`macval(sheet)'"' != "" {
	_tabtools_validate_sheet `"`macval(sheet)'"' "sheet()"
}

if `digits' < 0 | `digits' > 10 | `eventdigits' < 0 | `eventdigits' > 10 | `pydigits' < 0 | `pydigits' > 10 {
	di as err "digit options must be 0-10"
	exit 198
}

* Missing values (., .a-.z) pass a "<= 0" test, so check them explicitly
if missing(`pyscale') | `pyscale' <= 0 {
	di as err "pyscale must be a positive, nonmissing number"
	exit 198
}

if missing(`ratescale') | `ratescale' <= 0 {
	di as err "ratescale must be a positive, nonmissing number"
	exit 198
}

if `outcomes' < 1 {
	di as err "outcomes must be at least 1"
	exit 198
}
if `level' != -1 & (`level' <= 0 | `level' >= 100) {
	di as err "level() must be between 0 and 100"
	exit 198
}

* Resolve frame() now; the destination is written only after every export.
local _frame_name ""
if `"`frame'"' != "" {
	_tabtools_frame_preflight `"`frame'"' "frame()"
	local _frame_name `"`r(name)'"'
}

	* Resolve formatting
	_tabtools_resolve_format, font(`"`font'"') fontsize(`fontsize') borderstyle(`borderstyle') headershade(`headershade') zebra(`zebra')

	_tabtools_resolve_colors, headercolor(`"`headercolor'"') zebracolor(`"`zebracolor'"')

	* Validate ratiodigits
if `ratiodigits' < 0 | `ratiodigits' > 10 {
	di as err "ratiodigits must be 0-10"
	exit 198
}

local n_files : word count `macval(using)'
if mod(`n_files', `outcomes') != 0 {
	di as err "Number of files must be divisible by number of outcomes"
	exit 198
}

local n_exposures = `n_files' / `outcomes'
if "`rateratio'" != "" & `n_exposures' < 2 {
	di as err "rateratio requires at least two exposure groups"
	exit 198
}

* Validate each source path before loading any source file. A literal $ or
* backtick must be refused, rather than expanded into a different filename.
foreach file of local using {
    _tabtools_validate_path `"`macval(file)'"' "using()"
}

* Parse outcome labels
if `"`macval(outlabels)'"' != "" {
	local outlabels = subinstr(`"`macval(outlabels)'"', " \ ", "\", .)
	local outlabels = subinstr(`"`macval(outlabels)'"', "\  ", "\", .)
	local outlabels = subinstr(`"`macval(outlabels)'"', "  \", "\", .)
	tokenize `"`macval(outlabels)'"', parse("\")
	local n_outlabs = 0
	forvalues i = 1/100 {
		local j = (`i'-1)*2 + 1
		if `"`macval(`j')'"' == "" continue, break
		local n_outlabs = `n_outlabs' + 1
		local outlab`i' = strtrim(`"`macval(`j')'"')
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

* Machine-readable outcome identities default to the outcome labels, but can
* be supplied separately when presentation text is not a stable identifier.
if `"`macval(outcomeids)'"' != "" {
	* outcomeids() is string asis: when the whole list is one quoted string,
	* "a \ b", drop that layer so it is split like the unquoted a \ b. Items
	* quoted one by one ("a" \ "b") are left for tokenize.
	gettoken _oid_first _oid_rest : outcomeids, qed(_oid_quoted)
	if `_oid_quoted' & strtrim(`"`macval(_oid_rest)'"') == "" {
		local outcomeids `"`macval(_oid_first)'"'
	}
	local outcomeids : subinstr local outcomeids " \ " "\", all
	local outcomeids : subinstr local outcomeids "\  " "\", all
	local outcomeids : subinstr local outcomeids "  \" "\", all
	tokenize `"`macval(outcomeids)'"', parse("\")
	local _n_outcome_ids = 0
	forvalues i = 1/100 {
		local j = (`i' - 1) * 2 + 1
		if `"`macval(`j')'"' == "" continue, break
		local ++_n_outcome_ids
		local outcome_id_`i' = strtrim(`"`macval(`j')'"')
	}
	if `_n_outcome_ids' != `outcomes' {
		di as err "Number of outcome IDs (`_n_outcome_ids') must match outcomes (`outcomes')"
		exit 198
	}
}
else {
	forvalues i = 1/`outcomes' {
		local outcome_id_`i' `"`macval(outlab`i')'"'
	}
}
forvalues i = 1/`outcomes' {
	local outcome_id_`i' = strtrim(`"`macval(outcome_id_`i')'"')
	if `"`macval(outcome_id_`i')'"' == "" {
		di as err "outcome identities may not be blank"
		exit 198
	}
	if `i' > 1 {
		forvalues j = 1/`=`i'-1' {
			if lower(`"`macval(outcome_id_`i')'"') == lower(`"`macval(outcome_id_`j')'"') {
				di as err `"duplicate outcome identity "`macval(outcome_id_`i')'""'
				exit 198
			}
		}
	}
}

* Matrix column identities are derived from outcomeids(), not display labels.
* Sanitize, truncate, and suffix after truncation so every name is legal and
* distinct under Stata's 32-character name limit.
local _matrix_cnames ""
local _used_cnames ""
forvalues i = 1/`outcomes' {
	mata: st_local("_cname", subinstr(subinstr(subinstr(subinstr(strtoname(st_local("outcome_id_`i'")), char(96), "_"), char(39), "_"), char(36), "_"), char(34), "_"))
	local _cname = substr(`"`_cname'"', 1, 32)
	if `"`_cname'"' == "" | strtrim(subinstr(`"`_cname'"', "_", "", .)) == "" {
		local _cname "outcome`i'"
	}
	local _base_cname `"`_cname'"'
	local _cname_i = 1
	while strpos(" `_used_cnames' ", " `_cname' ") {
		local ++_cname_i
		local _suffix "_`_cname_i'"
		local _stem_len = 32 - strlen("`_suffix'")
		local _cname = substr(`"`_base_cname'"', 1, `_stem_len')
		local _cname `"`_cname'`_suffix'"'
	}
	local _used_cnames `"`_used_cnames' `_cname'"'
	local _matrix_cnames `"`_matrix_cnames' `_cname'"'
}

* Parse exposure labels
if `"`macval(explabels)'"' != "" {
	local explabels = subinstr(`"`macval(explabels)'"', " \ ", "\", .)
	local explabels = subinstr(`"`macval(explabels)'"', "\  ", "\", .)
	local explabels = subinstr(`"`macval(explabels)'"', "  \", "\", .)
	tokenize `"`macval(explabels)'"', parse("\")
	local n_explabs = 0
	forvalues i = 1/100 {
		local j = (`i'-1)*2 + 1
		if `"`macval(`j')'"' == "" continue, break
		local n_explabs = `n_explabs' + 1
		local explab`i' = strtrim(`"`macval(`j')'"')
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
if `"`macval(unitlabel)'"' == "" {
	local unitlabel "1,000"
}

* Process each file and store data
* Files are organized: out1_exp1 out2_exp1 out3_exp1 out1_exp2 out2_exp2 out3_exp2 ...
local filenum = 0
* Cells (level x outcome) whose person-time is zero: no rate is computable,
* so the cell is left empty in every sink.
local _n_cells 0
local _n_nopt 0
local _ci_level = cond(`level' == -1, ., `level')
local _ci_provenance_seen = 0
local _ci_unknown_seen = 0
forvalues e = 1/`n_exposures' {
	forvalues o = 1/`outcomes' {
		local filenum = `filenum' + 1
		local file : word `filenum' of `macval(using)'
		
		* The caller's data is preserved above, so each source file can be
		* loaded over it; every failure path exits to that single restore.
		cap use `"`macval(file)'.dta"', clear
		if _rc {
			noi di as err "File not found: `macval(file)'.dta"
			noi di as err "Hint: using() expects strate output file names without .dta extension"
			exit 601
		}
		
		cap confirm var _Rate _Lower _Upper _D _Y
		if _rc {
			noi di as err "`macval(file)'.dta missing required columns"
			noi di as err "Hint: file must contain _Rate, _Lower, _Upper, _D, and _Y from strate output"
			exit 111
		}

		* strate saves the confidence level in the _Lower/_Upper variable labels.
		* Read and compare it before copying any interval values.
		local _lower_vlabel : variable label _Lower
		local _upper_vlabel : variable label _Upper
		* strate writes the level with strsubdp(), so under set dp comma a
		* 97.5% interval is labelled "97,5%"; a period-only pattern would read
		* it as 5%.
		local _file_level = .
		if regexm(lower(`"`macval(_lower_vlabel)'"'), "([0-9]+([.,][0-9]+)?)%") {
			local _file_level = real(subinstr(regexs(1), ",", ".", .))
		}
		local _upper_level = .
		if regexm(lower(`"`macval(_upper_vlabel)'"'), "([0-9]+([.,][0-9]+)?)%") {
			local _upper_level = real(subinstr(regexs(1), ",", ".", .))
		}
		if !missing(`_file_level') & !missing(`_upper_level') & ///
			abs(`_file_level' - `_upper_level') > 1e-8 {
			noi di as err "`macval(file)'.dta has conflicting confidence levels in _Lower and _Upper labels"
			exit 459
		}
		if missing(`_file_level') local _file_level = `_upper_level'
		if missing(`_file_level') {
			local _ci_unknown_seen = 1
		}
		else {
			local _ci_provenance_seen = 1
			if `level' != -1 & abs(`level' - `_file_level') > 1e-8 {
				noi di as err "level(`level') conflicts with `macval(file)'.dta's `_file_level'% intervals"
				exit 198
			}
			if missing(`_ci_level') local _ci_level = `_file_level'
			else if abs(`_ci_level' - `_file_level') > 1e-8 {
				noi di as err "strate source files contain mixed confidence levels"
				exit 459
			}
		}
		
		* Find the categorical variable. strate without a grouping variable
		* saves only _D _Y _Rate _Lower _Upper; that file is one overall row.
		unab allvars : *
		local catvar ""
		foreach v of local allvars {
			if "`v'" != "_D" & "`v'" != "_Y" & "`v'" != "_Rate" & "`v'" != "_Lower" & "`v'" != "_Upper" {
				local catvar `"`v'"'
				continue, break
			}
		}
		
		* These scratch columns are built on the SOURCE FILE's data, so they
		* must be tempvars. A strate file whose grouping variable is legally
		* named catvar_str, or that already carries the scaled rate columns,
		* collided with the old fixed names and died with r(110).
		tempvar catvar_str _Rate_scaled _Lower_scaled _Upper_scaled
		* Convert categorical to string if needed
		if "`catvar'" == "" {
			gen `catvar_str' = "Overall"
		}
		else {
		cap confirm string var `catvar'
		if _rc {
			* Check if variable has a value label before decoding
			local vallabel : value label `catvar'
			if "`vallabel'" != "" {
				decode `catvar', gen(`catvar_str')
			}
			else {
				* No value label - convert to string directly. %21.0g keeps
				* integer codes of any size exact (default string() turns
				* 10000000 into "1.00e+07").
				gen `catvar_str' = string(`catvar', "%21.0g")
			}
			}
			else {
				gen `catvar_str' = `catvar'
			}
		}
			replace `catvar_str' = strtrim(`catvar_str')
			qui count if `catvar_str' == ""
			if r(N) > 0 {
				noi di as err "Blank category labels are not allowed in `macval(file)'.dta"
				exit 198
			}
			tempvar _dup_cat _obs_id
			gen long `_obs_id' = _n
			* bysort creates no variable on an empty file (an exposure with no
			* rows), so test for duplicates only when there are rows to test.
			local _n_dup 0
			if _N > 0 {
				qui bysort `catvar_str': gen byte `_dup_cat' = (_N > 1)
				sort `_obs_id'
				qui count if `_dup_cat'
				local _n_dup = r(N)
			}
			if `_n_dup' > 0 {
				noi di as err "Duplicate category labels found in `macval(file)'.dta"
				noi di as err "Each strate file must have unique category labels"
				exit 198
			}
			qui count if _D > 0 & !missing(_D) & _Y == 0
			if r(N) > 0 {
				noi di as err "`macval(file)'.dta has events without person-time in `r(N)' row(s)"
				exit 459
			}
			qui count if _Y == 0
			local _n_nopt = `_n_nopt' + r(N)
			local _n_cells = `_n_cells' + _N
			
			* Scale and format rate
			gen double `_Rate_scaled' = _Rate * `ratescale'
			gen double `_Lower_scaled' = _Lower * `ratescale'
			gen double `_Upper_scaled' = _Upper * `ratescale'
			* R3, zeroexact: strate gives no interval for zero events; the
			* exact Poisson limits are 0 and -ln(alpha/2)/Y ([R] ci, Methods
			* and formulas: Pr(K <= 0 | lambda2) = alpha/2).
			if "`zeroexact'" != "" {
				local _zx_level = cond(`level' != -1, `level', `_file_level')
				if missing(`_zx_level') {
					noi di as err "zeroexact needs the confidence level; specify level()"
					exit 459
				}
				replace `_Lower_scaled' = 0 if _D == 0 & _Y > 0 & missing(_Lower) & missing(_Upper)
				replace `_Upper_scaled' = -ln((1 - `_zx_level' / 100) / 2) / _Y * `ratescale' ///
					if _D == 0 & _Y > 0 & missing(_Upper) & `_Lower_scaled' == 0
			}
			
			* Store and validate canonical categories for this exposure
			if `o' == 1 {
				local ncat_e`e' = _N
				forvalues i = 1/`=_N' {
					* C1 (codex audit 2026-09-26): category labels are data;
					* they are read, compared and written in Mata or with
					* macval(), never re-expanded as macro syntax.
					mata: st_local("cat_e`e'_`i'", st_sdata(`i', "`catvar_str'"))
					local D_o`o'_e`e'_`i' = _D[`i']
					local Y_o`o'_e`e'_`i' = _Y[`i'] / `pyscale'
					local Rate_o`o'_e`e'_`i' = regexr(string(`_Rate_scaled'[`i'], "%21x"), "^[+]", "")
					local Lower_o`o'_e`e'_`i' = regexr(string(`_Lower_scaled'[`i'], "%21x"), "^[+]", "")
					local Upper_o`o'_e`e'_`i' = regexr(string(`_Upper_scaled'[`i'], "%21x"), "^[+]", "")
				}
			}
			else {
				if _N != `ncat_e`e'' {
					noi di as err "Category count mismatch for exposure `e': outcome 1 has `ncat_e`e'' categories but outcome `o' has `=_N'"
					noi di as err "All outcome files for the same exposure must have identical categories"
					exit 198
				}
				forvalues i = 1/`ncat_e`e'' {
					local _target_cat : copy local cat_e`e'_`i'
					local _match_row = 0
					local _match_count = 0
					forvalues _j = 1/`=_N' {
						mata: st_local("_same", strofreal(st_sdata(`_j', "`catvar_str'") == st_local("_target_cat")))
						if `_same' {
							local _match_row = `_j'
							local _match_count = `_match_count' + 1
						}
					}
					if `_match_count' != 1 {
						noi di as err "Category label mismatch for exposure `e', outcome `o' in `macval(file)'.dta"
						noi di as err `"Expected category "`macval(_target_cat)'" from outcome 1"'
						exit 198
					}
					local D_o`o'_e`e'_`i' = _D[`_match_row']
					local Y_o`o'_e`e'_`i' = _Y[`_match_row'] / `pyscale'
					local Rate_o`o'_e`e'_`i' = regexr(string(`_Rate_scaled'[`_match_row'], "%21x"), "^[+]", "")
					local Lower_o`o'_e`e'_`i' = regexr(string(`_Lower_scaled'[`_match_row'], "%21x"), "^[+]", "")
					local Upper_o`o'_e`e'_`i' = regexr(string(`_Upper_scaled'[`_match_row'], "%21x"), "^[+]", "")
				}
			}
			
	}
}

* Any source file without recoverable provenance requires an explicit level().
* This previously only fired when SOME files had provenance and others did not;
* when NO file carried it the code fell through to a silent `= 95', so intervals
* computed at another level were labeled "95% CI" and returned r(ci_level)=95.
* strate records the level in the _Lower/_Upper variable labels, so an absent
* label means the level is genuinely unknown and must be supplied, not guessed.
if `_ci_unknown_seen' & `level' == -1 {
	if `_ci_provenance_seen' {
		noi di as err "some strate source files lack confidence-level provenance; specify level() explicitly"
	}
	else {
		noi di as err "strate source file(s) carry no confidence-level provenance in the _Lower/_Upper labels"
		noi di as err "specify level() explicitly; the level is not recoverable and 95% is not assumed"
	}
	exit 459
}
if `level' != -1 & missing(`_ci_level') local _ci_level = `level'
if missing(`_ci_level') local _ci_level = 95
* The level as shown: at most 15 significant digits, so 99.9 never prints
* as the double's 17-digit 99.90000000000001; r(ci_level) stays numeric.
local _ci_level_txt = strtrim(string(`_ci_level', "%21.15g"))
local _ci_alpha = (100 - `_ci_level') / 200
local _ci_z = invnormal(1 - `_ci_alpha')

if `_n_cells' > 0 & `_n_nopt' == `_n_cells' {
	noi di as err "no category has person-time for any outcome; no rate is computable"
	exit 459
}

* Compute rate ratios if requested (F4)
if "`rateratio'" != "" & `n_exposures' >= 2 {
	forvalues e = 2/`n_exposures' {
		forvalues o = 1/`outcomes' {
			forvalues i = 1/`ncat_e`e'' {
				local _target_cat : copy local cat_e`e'_`i'
				local _ref_i = 0
				local _ref_count = 0
				forvalues _j = 1/`ncat_e1' {
					mata: st_local("_same", strofreal(st_local("cat_e1_`_j'") == st_local("_target_cat")))
					if `_same' {
						local _ref_i = `_j'
						local _ref_count = `_ref_count' + 1
					}
				}
				if `_ref_count' != 1 {
					noi di as err "rateratio requires exposure `e' categories to match exposure 1"
					noi di as err `"No unique match for category "`macval(_target_cat)'" in exposure 1"'
					exit 198
				}
				local _d_ref = `D_o`o'_e1_`_ref_i''
				local _d_exp = `D_o`o'_e`e'_`i''
				local _r_ref = `Rate_o`o'_e1_`_ref_i''
				local _r_exp = `Rate_o`o'_e`e'_`i''
				local _ref_masked_o`o'_e`e'_`i' = (`smallcells' > 0 & `_d_ref' >= 1 & `_d_ref' < `smallcells')
				if `_d_ref' > 0 & `_d_exp' > 0 & `_r_ref' > 0 {
					local _irr = `_r_exp' / `_r_ref'
					local _se_ln = sqrt(1/`_d_exp' + 1/`_d_ref')
					local IRR_o`o'_e`e'_`i' = `_irr'
					local IRRlo_o`o'_e`e'_`i' = exp(ln(`_irr') - `_ci_z' * `_se_ln')
					local IRRhi_o`o'_e`e'_`i' = exp(ln(`_irr') + `_ci_z' * `_se_ln')
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
quietly replace title = `"`macval(title)'"' in 1

* Row 2: Outcome headers (merged across columns)
local new = _N + 1
quietly set obs `new'
quietly replace c1 = "Exposure" in `new'
local col = 2
forvalues o = 1/`outcomes' {
	quietly replace c`col' = `"`macval(outlab`o')'"' in `new'
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
	quietly replace c`col' = `"Per `macval(unitlabel)' PY (`_ci_level_txt'% CI)"' in `new'
	local col = `col' + 1
	if "`rateratio'" != "" {
		quietly replace c`col' = "IRR (`_ci_level_txt'% CI)" in `new'
		local col = `col' + 1
	}
}

* Rounding units, held as macro text so they read back as the exact decimal
* (0.01, not 10^(-2), which is one ulp above it), as regtab rounds.
local _unit = 10^(-`digits')
local _runit = 10^(-`ratiodigits')
local exp_rows ""

* Data rows by exposure group
forvalues e = 1/`n_exposures' {
	* Exposure header row (recorded here for the rule above each block, so
	* the rule does not depend on the label text)
	local new = _N + 1
	quietly set obs `new'
	quietly replace c1 = `"`macval(explab`e')'"' in `new'
	local exp_rows `"`exp_rows' `new'"'
	
	* Category rows (indented)
	forvalues i = 1/`ncat_e`e'' {
		local new = _N + 1
		quietly set obs `new'
			quietly replace c1 = `"   `macval(cat_e`e'_`i')'"' in `new'
		
		local col = 2
		forvalues o = 1/`outcomes' {
			* Small cells: 1..#-1 events print as <#, with their person-time
			* and rate withheld (printed output only; r() keeps the numbers).
			local _masked = (`smallcells' > 0 & `D_o`o'_e`e'_`i'' >= 1 & `D_o`o'_e`e'_`i'' < `smallcells')
			* No person-time: nothing is computable, so the events,
			* person-time and rate cells are left empty (not 0, not a dash,
			* which zerocells() uses for a computable zero-event rate).
			local _nopt = (`Y_o`o'_e`e'_`i'' == 0)
			* Events
			if `eventdigits' == 0 {
				local ev_fmt = string(`D_o`o'_e`e'_`i'', "%24.0fc")
			}
			else {
				local ev_fmt = string(`D_o`o'_e`e'_`i'', "%24.`eventdigits'fc")
			}
			if `_masked' {
				if `_mask_given' local ev_fmt `"`macval(masktext)'"'
				else local ev_fmt "<`smallcells'"
			}
			local _zero_cell = ("`zerocells'" != "" & `D_o`o'_e`e'_`i'' == 0 & !`_nopt')
			if `_zero_cell' local ev_fmt `"`_zero_txt'"'
			if `_nopt' local ev_fmt ""
			quietly replace c`col' = strtrim(`"`macval(ev_fmt)'"') in `new'
			local col = `col' + 1

			* Person-years
			if `pydigits' == 0 {
				local py_fmt = string(round(`Y_o`o'_e`e'_`i'',1), "%24.0fc")
			}
			else {
				local py_fmt = string(`Y_o`o'_e`e'_`i'', "%24.`pydigits'fc")
			}
			if `_masked' local py_fmt "–"
			if `_zero_cell' & `_zc_pt' local py_fmt `"`_zero_txt'"'
			if `_nopt' local py_fmt ""
			quietly replace c`col' = strtrim(`"`py_fmt'"') in `new'
			local col = `col' + 1

			* Rate (95% CI)
			* ", " matches the CI separator every other tabtools command uses.
			* A bare "-" also reads as a minus sign once a bound is negative,
			* and hrcomptab places these rate CIs beside comma-separated model
			* CIs in one table.
			* A rate without bounds (strate gives none for zero events) shows
			* the en dash the IRR column uses for a missing estimate.
			if `"`cformat'"' != "" {
				local rt_fmt = strtrim(string(`Rate_o`o'_e`e'_`i'', "`cformat'"))
			}
			else {
				local rt_fmt = strtrim(string(round(`Rate_o`o'_e`e'_`i'', `_unit'), "%24.`digits'f"))
			}
			if missing(`Lower_o`o'_e`e'_`i'') | missing(`Upper_o`o'_e`e'_`i'') {
				local rt_fmt `"`rt_fmt' (–)"'
			}
			else {
				if `"`cformat'"' != "" {
					local _lo_txt = strtrim(string(`Lower_o`o'_e`e'_`i'', "`cformat'"))
					local _hi_txt = strtrim(string(`Upper_o`o'_e`e'_`i'', "`cformat'"))
				}
				else {
					local _lo_txt = strtrim(string(round(`Lower_o`o'_e`e'_`i'', `_unit'), "%24.`digits'f"))
					local _hi_txt = strtrim(string(round(`Upper_o`o'_e`e'_`i'', `_unit'), "%24.`digits'f"))
				}
				mata: st_local("rt_fmt", st_local("rt_fmt") + " (" + st_local("_lo_txt") + st_local("sep") + st_local("_hi_txt") + ")")
			}
			if `_masked' local rt_fmt "–"
			if `_zero_cell' local rt_fmt `"`_zero_txt'"'
			if `_nopt' local rt_fmt ""
			quietly replace c`col' = `"`macval(rt_fmt)'"' in `new'
			local col = `col' + 1

			* Rate Ratio (IRR) if requested
			if "`rateratio'" != "" {
				* a reference row without person-time has no rate to be the
				* reference for, so it is empty like the rest of the row
				if `e' == 1 & `_nopt' {
					quietly replace c`col' = "" in `new'
				}
				else if `e' == 1 {
					quietly replace c`col' = "Ref." in `new'
				}
				else if `_nopt' {
					quietly replace c`col' = "" in `new'
				}
				else if missing(`IRR_o`o'_e`e'_`i'') {
					quietly replace c`col' = "–" in `new'
				}
				else {
					local _est_txt = strtrim(string(round(`IRR_o`o'_e`e'_`i'', `_runit'), "%11.`ratiodigits'f"))
					local _lo_txt = strtrim(string(round(`IRRlo_o`o'_e`e'_`i'', `_runit'), "%11.`ratiodigits'f"))
					local _hi_txt = strtrim(string(round(`IRRhi_o`o'_e`e'_`i'', `_runit'), "%11.`ratiodigits'f"))
					mata: st_local("irr_fmt", st_local("_est_txt") + " (" + st_local("_lo_txt") + st_local("sep") + st_local("_hi_txt") + ")")
					* a ratio whose numerator or reference count is masked is withheld
					if `_masked' | `_ref_masked_o`o'_e`e'_`i'' local irr_fmt "–"
					quietly replace c`col' = `"`macval(irr_fmt)'"' in `new'
				}
				local col = `col' + 1
			}
		}
	}
}

local lastrow = _N

* CSV export (if requested)
if `"`macval(csv)'"' != "" {
	_tabtools_validate_path `"`macval(csv)'"' "csv()"
	order title c*
	_tabtools_csv_write using `"`macval(csv)'"', reservedrow title(`"`macval(title)'"') footnote(`"`macval(footnote)'"')
	local _ret_csv `"`macval(csv)'"'
}

local sht = cond(`"`macval(sheet)'"' != "", `"`macval(sheet)'"', "Results")
_tabtools_validate_sheet `"`macval(sht)'"' "sheet()"
local _ret_markdown ""
local _ret_markdown_rows .
local _ret_markdown_cols .
if `"`macval(markdown)'"' != "" {
	local _mdappend_opt ""
	if "`mdappend'" != "" local _mdappend_opt "append"
	* Markdown has one header row: flatten the outcome and statistic rows to
	* "outcome: statistic" (as regtab writes "model: statistic") in a copy,
	* so the statistic row is not written as the first body row.
	tempname _md_frame
	frame put *, into(`_md_frame')
	local _md_rc 0
	frame `_md_frame' {
		local col = 2
		forvalues o = 1/`outcomes' {
			forvalues _s = 1/`_cols_per_outcome' {
				quietly replace c`col' = `"`macval(outlab`o')'"' + ": " + c`col' in 3
				local ++col
			}
		}
		capture noisily _tabtools_markdown_write using `"`macval(markdown)'"', ///
			`_mdappend_opt' title(`"`macval(title)'"') footnote(`"`macval(footnote)'"') ///
			headerstart(3) datastart(4) strictheaders
		local _md_rc = _rc
		if !`_md_rc' {
			local _ret_markdown_rows = r(n_rows)
			local _ret_markdown_cols = r(n_cols)
		}
	}
	frame drop `_md_frame'
	if `_md_rc' {
		noi di as err "Failed to export Markdown to `macval(markdown)'"
		exit `_md_rc'
	}
	local _ret_markdown `"`macval(markdown)'"'
	noi di as text "Markdown exported to `macval(markdown)'"
}
* Console display. Row 3 repeats "Exposure" under row 2 so the merged
* workbook header (B2:B3) and the frame layout keep it; the console lists
* both header rows, so it is shown once there.
local _c1_row3 = c1[3]
quietly replace c1 = "" in 3
noisily _tabtools_console_display `ncols' `"`macval(title)'"', datastart(4)
quietly replace c1 = `"`_c1_row3'"' in 3

* Frame output is staged here and committed only after every export has
* succeeded, so a failed xlsx write neither creates nor replaces frame().
if `"`_frame_name'"' != "" {
	frame put *, into(`_frame_stage')
	local _frame_stage_created 1
	frame `_frame_stage': char _dta[tabtools_source] "stratetab"
	frame `_frame_stage': char _dta[tabtools_ci_level] "`_ci_level_txt'"
	* A rateratio table has a fourth column per outcome; say so, so comptab
	* can refuse it by name rather than by a width that can coincide with a
	* plain table of more outcomes.
	if "`rateratio'" != "" {
		frame `_frame_stage': char _dta[tabtools_statistic_ids] "events person_years rate_ci irr_ci"
	}
	else {
		frame `_frame_stage': char _dta[tabtools_statistic_ids] "events person_years rate_ci"
	}
	frame `_frame_stage': char _dta[tabtools_n_outcomes] "`outcomes'"
	frame `_frame_stage': char _dta[tabtools_smallcells] "`smallcells'"
	forvalues _meta_o = 1/`outcomes' {
		frame `_frame_stage': char _dta[tabtools_outcome_id_`_meta_o'] `"`macval(outcome_id_`_meta_o')'"'
	}
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
				mata: st_local("_rname", subinstr(subinstr(subinstr(subinstr(strtoname(st_local("cat_e`e'_`i'")), char(96), "_"), char(39), "_"), char(36), "_"), char(34), "_"))
				local _rname = substr(`"`_rname'"', 1, 32)
				if `"`_rname'"' == "" | strtrim(subinstr(`"`_rname'"', "_", "", .)) == "" local _rname "row`_rr'"
					if `n_exposures' > 1 {
						local _rname = "e`e'_`_rname'"
						local _rname = substr("`_rname'", 1, 32)
					}
					local _base_rname `"`_rname'"'
					local _rname_i = 1
					while strpos(" `_used_rnames' ", " `_rname' ") {
						local ++_rname_i
						local _suffix "_`_rname_i'"
						local _stem_len = 32 - strlen("`_suffix'")
						local _rname = substr("`_base_rname'", 1, `_stem_len')
						local _rname `"`_rname'`_suffix'"'
					}
					local _used_rnames `"`_used_rnames' `_rname'"'
					local _rnames `"`_rnames' `_rname'"'
				}
				}
		matrix rownames `_rrates' = `_rnames'
		matrix colnames `_rrates' = `_matrix_cnames'
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
					mata: st_local("_rname", subinstr(subinstr(subinstr(subinstr(strtoname(st_local("cat_e`e'_`i'")), char(96), "_"), char(39), "_"), char(36), "_"), char(34), "_"))
					local _rname = substr(`"`_rname'"', 1, 32)
					if `"`_rname'"' == "" | strtrim(subinstr(`"`_rname'"', "_", "", .)) == "" local _rname "row`_rr'"
						if `n_exposures' > 2 {
							local _rname = "e`e'_`_rname'"
							local _rname = substr("`_rname'", 1, 32)
						}
						local _base_rname `"`_rname'"'
						local _rname_i = 1
						while strpos(" `_used_rnames' ", " `_rname' ") {
							local ++_rname_i
							local _suffix "_`_rname_i'"
							local _stem_len = 32 - strlen("`_suffix'")
							local _rname = substr("`_base_rname'", 1, `_stem_len')
							local _rname `"`_rname'`_suffix'"'
						}
						local _used_rnames `"`_used_rnames' `_rname'"'
						local _rnames `"`_rnames' `_rname'"'
					}
				}
			matrix rownames `_rratios' = `_rnames'
			matrix colnames `_rratios' = `_matrix_cnames'
		}
	}

* Return results
	if `_total_cats' > 0 {
		return matrix rates = `_rrates'
	}
	if "`rateratio'" != "" & `n_exposures' >= 2 {
		* No matrix exists when every comparison exposure is empty.
		if `_ratio_cats' > 0 return matrix ratios = `_rratios'
	}
if `"`macval(_ret_csv)'"' != "" {
    return local csv `"`macval(_ret_csv)'"'
}
if `"`macval(_ret_markdown)'"' != "" {
	return local markdown `"`macval(_ret_markdown)'"'
	return scalar markdown_rows = `_ret_markdown_rows'
	return scalar markdown_cols = `_ret_markdown_cols'
}
return scalar N_rows = `lastrow'
return scalar N_exposures = `n_exposures'
return scalar N_outcomes = `outcomes'
return scalar ci_level = `_ci_level'
return scalar smallcells = `smallcells'
return scalar N_nopt = `_n_nopt'
local _outcome_ids_return ""
forvalues _meta_o = 1/`outcomes' {
	local _outcome_ids_return `"`macval(_outcome_ids_return)' \ `macval(outcome_id_`_meta_o')'"'
}
local _outcome_ids_return = substr(strtrim(`"`macval(_outcome_ids_return)'"'), 3, .)
return local outcome_ids `"`macval(_outcome_ids_return)'"'
return local methods "Incidence rates and confidence intervals were formatted at the `_ci_level_txt'% level; rate-ratio intervals use an independent-rate log-normal approximation at the same level."

	* Export to Excel
	if `_has_xlsx' {
		order title c*
		capture noisily _tabtools_xlsx_write using `"`macval(xlsx)'"', sheet(`"`macval(sht)'"') book(`_xlsx_book')
		if _rc {
			local saved_rc = _rc
			noi di as err "Failed to export to `macval(xlsx)'"
			noi di as err "Hint: ensure the xlsx file is not open in another application"
		local _fatal_rc = `saved_rc'
		exit `saved_rc'
	}
	else {
			* Excel sheet names are case-insensitive; keep the workbook's own
			* spelling when an existing sheet was replaced.
			mata: st_local("sht", st_global("r(sheet)"))
			* Apply formatting (Mata xl()) in the open workbook returned by
			* _tabtools_xlsx_write; avoid a save/reload pass.
			local _total_cols = `ncols' + 1
			local _xlsx_widths "1 18"
			forvalues col = 3/`_total_cols' {
				local _data_col = `col' - 1
				local _hdr = c`_data_col'[3]
				local _hdrlen = strlen("`_hdr'")
				local _cw = max(8, `_hdrlen' + 2)
				local _xlsx_widths `"`_xlsx_widths' `_cw'"'
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

				if `"`macval(footnote)'"' != "" {
					local _fn_fontsize = max(`_fontsize' - 2, 6)
					* One row per paragraph; " \ " separates paragraphs.
					local _fn_rest `"`macval(footnote)'"'
					local _fp 0
					while `"`macval(_fn_rest)'"' != "" {
						local _fn_at = strpos(`"`macval(_fn_rest)'"', " \ ")
						if `_fn_at' == 0 {
							local _fn_piece `"`macval(_fn_rest)'"'
							local _fn_rest ""
						}
						else {
							local _fn_piece = substr(`"`macval(_fn_rest)'"', 1, `_fn_at' - 1)
							local _fn_rest = substr(`"`macval(_fn_rest)'"', `_fn_at' + 3, .)
						}
						local ++_fp
						local _fn_row = `lastrow' + `_fp'
						mata: `_xlsx_book'.put_string(`_fn_row', 2, strtrim(st_local("_fn_piece")))
						matrix `_style_rules' = `_style_rules' \ ///
							(14, `_fn_row', `_fn_row', 2, `_total_cols', 0, 0, 0, 0) \ ///
							(5, `_fn_row', `_fn_row', 2, 2, 0, 1, 0, 0) \ ///
							(6, `_fn_row', `_fn_row', 2, 2, 0, 2, 0, 0) \ ///
							(4, `_fn_row', `_fn_row', 2, 2, 0, 1, 0, 0) \ ///
							(1, `_fn_row', `_fn_row', 2, 2, `_fn_fontsize', 1, 0, 0) \ ///
							(3, `_fn_row', `_fn_row', 2, 2, 0, 1, 0, 0)
					}
				}

				_tabtools_xlsx_apply_styles, defer book(`_xlsx_book') sheet(`"`macval(sht)'"') ///
					rules(`_style_rules') font("`_font'") ///
					color1("`_headercolor'") color2("`_zebracolor'")
				mata: `_xlsx_book'.close_book()

				* xl() appends a style record for every styled cell instead of
				* reusing one per distinct format, so collapse the pools here;
				* a workbook that keeps growing would otherwise reach Stata's
				* 65,536-record ceiling and fail with r(16147).
				_tabtools_xlsx_compact_styles using `"`macval(xlsx)'"'
			}
			if _rc {
				local saved_rc = _rc
				capture mata: `_xlsx_book'.close_book()
				capture mata: mata drop `_xlsx_book'
				noi di as err "Excel formatting failed with error `saved_rc'"
				noi di as err "Hint: ensure the xlsx file is not open in another application"
				local _fatal_rc = `saved_rc'
				exit `saved_rc'
			}
			else {
				capture mata: mata drop `_xlsx_book'
				capture confirm file `"`macval(xlsx)'"'
				if _rc {
				    noisily display as error "Export command succeeded but file not found"
				    local _fatal_rc = 601
				    exit 601
				}
				else {
					local _xlsx_ok 1
					noisily display as text "Exported to " as result `"`macval(xlsx)'"' as text ", sheet " as result `"`macval(sht)'"'
				}
			}
			}
		}

	} // end quietly block

* Every export succeeded: commit the staged frame, then restore user data.
if `_frame_stage_created' {
	capture confirm frame `_frame_name'
	if !_rc frame drop `_frame_name'
	frame rename `_frame_stage' `_frame_name'
	local _frame_stage_created 0
	return local frame "`_frame_name'"
}
restore
local _restore_needed 0

if `_xlsx_ok' {
	return local xlsx `"`macval(xlsx)'"'
	return local sheet `"`macval(sht)'"'
}

* Open file if requested (W3)
if "`open'" != "" & `_xlsx_ok' {
    _tabtools_open_file `"`macval(xlsx)'"'
}

} // end capture noisily
local _rc = _rc
if `_rc' == 0 & `_fatal_rc' != 0 local _rc = `_fatal_rc'
if `_frame_stage_created' capture frame drop `_frame_stage'
if `_restore_needed' capture restore
set varabbrev `_orig_varabbrev'
* exit, not error: the failing step already printed its own message, and
* error would append Stata's generic text for the code ("invalid syntax").
if `_rc' exit `_rc'
end
