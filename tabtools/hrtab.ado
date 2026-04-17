*! hrtab Version 1.0.5  2026/04/17
*! Multi-panel hazard ratio table for publication
*! Author: Timothy P Copeland
*! Program class: rclass

/*
DESCRIPTION:
	Automates multi-panel hazard ratio tables (the standard "Table 2" in
	cohort studies). For each outcome × exposure combination, stsets the
	data, computes person-years and events via stptime, runs unadjusted
	and adjusted survival models, and exports results to Excel.

	Supported estimation commands: stcox, stcrreg, finegray.

SYNTAX:
	hrtab [if] [in], exposure(string) model(string) [options]

	See help hrtab for complete documentation.
*/

program define hrtab, rclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off

	capture noisily {

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

	syntax [if] [in] , EXPosure(string) MODel(string) ///
		[OUTcome(string) TIME(string) FAILValue(string) CENSvalue(integer 0) ///
		STSETOpts(string) ///
		COVars(string) MODELOpts(string) NOUNadjusted ///
		EFFect(string) NOPYtime NOEVents PValue DIGits(integer -1) ///
		PYDigits(integer -1) PYSCale(real 1) Level(cilevel) NOLog DOTS ///
		OUTLabels(string) EXPLabels(string) MODELLabels(string) REFLabel(string) ///
		xlsx(string) excel(string) sheet(string) title(string) ///
		FOOTnote(string) THEme(string) BORDERstyle(string) open zebra ///
		HEADERShade HEADERColor(string) ZEBRAColor(string) ///
		BOLDp(real -1) HIGHlight(real -1) csv(string) FRAme(string) ///
		DISplay ADDRow(string asis)]

	* =========================================================================
	* OPTION RESOLUTION
	* =========================================================================

	* Accept excel() as synonym for xlsx()
	if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
	local _has_xlsx = "`xlsx'" != ""
	if "`sheet'" == "" local sheet "Results"

	* Validate model
	local model = strlower(strtrim("`model'"))
	if !inlist("`model'", "stcox", "stcrreg", "finegray") {
		noisily display as error "model() must be stcox, stcrreg, or finegray"
		exit 198
	}

	* Default effect label
	if "`effect'" == "" {
		if "`model'" == "stcox" local effect "HR"
		else local effect "SHR"
	}

	* Default reflabel
	if "`reflabel'" == "" local reflabel "Ref."

	* Resolve digits
	if `digits' == -1 {
		if "$TABTOOLS_DIGITS" != "" local digits = $TABTOOLS_DIGITS
		else local digits = 2
	}
	if `digits' < 0 | `digits' > 6 {
		noisily display as error "digits() must be between 0 and 6"
		exit 198
	}

	* Resolve pydigits
	if `pydigits' == -1 local pydigits = 0
	if `pydigits' < 0 | `pydigits' > 4 {
		noisily display as error "pydigits() must be between 0 and 4"
		exit 198
	}

	* Validate pyscale
	if `pyscale' <= 0 {
		noisily display as error "pyscale() must be positive"
		exit 198
	}

	* Validate xlsx
	if `_has_xlsx' {
		if !strmatch("`xlsx'", "*.xlsx") {
			noisily display as error "xlsx() must have .xlsx extension"
			exit 198
		}
		_tabtools_validate_path "`xlsx'" "xlsx()"
	}
	_tabtools_validate_sheet "`sheet'" "sheet()"

	* Validate highlight/boldp
	local has_highlight = `highlight' != -1
	if `has_highlight' & (`highlight' <= 0 | `highlight' >= 1) {
		noisily display as error "highlight() must be between 0 and 1"
		exit 198
	}
	local has_boldp = `boldp' != -1
	if `has_boldp' & (`boldp' <= 0 | `boldp' >= 1) {
		noisily display as error "boldp() must be between 0 and 1"
		exit 198
	}

	* Resolve formatting
	_tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle') ///
		headershade(`headershade') zebra(`zebra')
	if !inlist("`borderstyle'", "thin", "medium", "academic") {
		noisily display as error "borderstyle() must be thin, medium, or academic"
		exit 198
	}

	* Resolve header/zebra colors
	local _headercolor "219 229 241"
	local _zebracolor "237 242 249"
	if "$TABTOOLS_HEADERCOLOR" != "" local _headercolor "$TABTOOLS_HEADERCOLOR"
	if "$TABTOOLS_ZEBRACOLOR" != "" local _zebracolor "$TABTOOLS_ZEBRACOLOR"
	if "`headercolor'" != "" local _headercolor "`headercolor'"
	if "`zebracolor'" != "" local _zebracolor "`zebracolor'"

	* Validate csv
	if "`csv'" != "" {
		_tabtools_validate_path "`csv'" "csv()"
	}

	* =========================================================================
	* PARSE BACKSLASH-SEPARATED LISTS
	* =========================================================================

	* --- Parse exposure() ---
	local _exp_raw "`exposure'"
	local _exp_raw = subinstr("`_exp_raw'", " \ ", "\", .)
	local _exp_raw = subinstr("`_exp_raw'", "\  ", "\", .)
	local _exp_raw = subinstr("`_exp_raw'", "  \", "\", .)
	tokenize `"`_exp_raw'"', parse("\")
	local n_panels = 0
	forvalues _i = 1/100 {
		local _j = (`_i' - 1) * 2 + 1
		if `"``_j''"' == "" continue, break
		local n_panels = `n_panels' + 1
		local _exp_spec`n_panels' = strtrim(`"``_j''"')
	}
	if `n_panels' == 0 {
		noisily display as error "exposure() is required and must not be empty"
		exit 198
	}

	* --- Parse outcome() ---
	local n_outcomes = 0
	local _single_outcome = 0
	if "`outcome'" == "" {
		* Single-outcome mode — use existing stset
		local _single_outcome = 1
		local n_outcomes = 1
	}
	else {
		local _out_raw "`outcome'"
		local _out_raw = subinstr("`_out_raw'", " \ ", "\", .)
		local _out_raw = subinstr("`_out_raw'", "\  ", "\", .)
		local _out_raw = subinstr("`_out_raw'", "  \", "\", .)
		tokenize `"`_out_raw'"', parse("\")
		forvalues _i = 1/100 {
			local _j = (`_i' - 1) * 2 + 1
			if `"``_j''"' == "" continue, break
			local n_outcomes = `n_outcomes' + 1
			local _outcome`n_outcomes' = strtrim(`"``_j''"')
		}
	}

	* --- Parse time() ---
	local n_times = 0
	if "`time'" != "" {
		local _time_raw "`time'"
		local _time_raw = subinstr("`_time_raw'", " \ ", "\", .)
		local _time_raw = subinstr("`_time_raw'", "\  ", "\", .)
		local _time_raw = subinstr("`_time_raw'", "  \", "\", .)
		tokenize `"`_time_raw'"', parse("\")
		forvalues _i = 1/100 {
			local _j = (`_i' - 1) * 2 + 1
			if `"``_j''"' == "" continue, break
			local n_times = `n_times' + 1
			local _time`n_times' = strtrim(`"``_j''"')
		}
	}

	* --- Parse failvalue() ---
	local n_failvals = 0
	if "`failvalue'" != "" {
		local _fv_raw "`failvalue'"
		local _fv_raw = subinstr("`_fv_raw'", " \ ", "\", .)
		local _fv_raw = subinstr("`_fv_raw'", "\  ", "\", .)
		local _fv_raw = subinstr("`_fv_raw'", "  \", "\", .)
		tokenize `"`_fv_raw'"', parse("\")
		forvalues _i = 1/100 {
			local _j = (`_i' - 1) * 2 + 1
			if `"``_j''"' == "" continue, break
			local n_failvals = `n_failvals' + 1
			local _failval`n_failvals' = strtrim(`"``_j''"')
		}
	}

	* --- Parse covars() ---
	local n_covsets = 0
	if "`covars'" != "" {
		local _cov_raw "`covars'"
		local _cov_raw = subinstr("`_cov_raw'", " \ ", "\", .)
		local _cov_raw = subinstr("`_cov_raw'", "\  ", "\", .)
		local _cov_raw = subinstr("`_cov_raw'", "  \", "\", .)
		tokenize `"`_cov_raw'"', parse("\")
		forvalues _i = 1/100 {
			local _j = (`_i' - 1) * 2 + 1
			if `"``_j''"' == "" continue, break
			local n_covsets = `n_covsets' + 1
			local _covset`n_covsets' = strtrim(`"``_j''"')
		}
	}

	* --- Parse outlabels() ---
	if "`outlabels'" != "" {
		local _olab_raw "`outlabels'"
		local _olab_raw = subinstr("`_olab_raw'", " \ ", "\", .)
		local _olab_raw = subinstr("`_olab_raw'", "\  ", "\", .)
		local _olab_raw = subinstr("`_olab_raw'", "  \", "\", .)
		tokenize `"`_olab_raw'"', parse("\")
		local _n_olabs = 0
		forvalues _i = 1/100 {
			local _j = (`_i' - 1) * 2 + 1
			if `"``_j''"' == "" continue, break
			local _n_olabs = `_n_olabs' + 1
			local _outlab`_n_olabs' = strtrim(`"``_j''"')
		}
		if `_n_olabs' != `n_outcomes' {
			noisily display as error "outlabels() count (`_n_olabs') must match number of outcomes (`n_outcomes')"
			exit 198
		}
	}

	* --- Parse explabels() ---
	if "`explabels'" != "" {
		local _elab_raw "`explabels'"
		local _elab_raw = subinstr("`_elab_raw'", " \ ", "\", .)
		local _elab_raw = subinstr("`_elab_raw'", "\  ", "\", .)
		local _elab_raw = subinstr("`_elab_raw'", "  \", "\", .)
		tokenize `"`_elab_raw'"', parse("\")
		local _n_elabs = 0
		forvalues _i = 1/100 {
			local _j = (`_i' - 1) * 2 + 1
			if `"``_j''"' == "" continue, break
			local _n_elabs = `_n_elabs' + 1
			local _explab`_n_elabs' = strtrim(`"``_j''"')
		}
		if `_n_elabs' != `n_panels' {
			noisily display as error "explabels() count (`_n_elabs') must match number of exposure panels (`n_panels')"
			exit 198
		}
	}

	* --- Parse modellabels() ---
	local n_models = 1 + `n_covsets'
	if "`nounadjusted'" != "" {
		if `n_covsets' == 0 {
			noisily display as error "nounadjusted requires covars()"
			exit 198
		}
		local n_models = `n_covsets'
	}

	if "`modellabels'" != "" {
		local _mlab_raw "`modellabels'"
		local _mlab_raw = subinstr("`_mlab_raw'", " \ ", "\", .)
		local _mlab_raw = subinstr("`_mlab_raw'", "\  ", "\", .)
		local _mlab_raw = subinstr("`_mlab_raw'", "  \", "\", .)
		tokenize `"`_mlab_raw'"', parse("\")
		local _n_mlabs = 0
		forvalues _i = 1/100 {
			local _j = (`_i' - 1) * 2 + 1
			if `"``_j''"' == "" continue, break
			local _n_mlabs = `_n_mlabs' + 1
			local _modlab`_n_mlabs' = strtrim(`"``_j''"')
		}
		if `_n_mlabs' != `n_models' {
			noisily display as error "modellabels() count (`_n_mlabs') must match number of models (`n_models')"
			exit 198
		}
	}
	else {
		* Generate default model labels
		if "`nounadjusted'" == "" {
			local _modlab1 "Unadjusted"
			if `n_covsets' == 1 {
				local _modlab2 "Adjusted"
			}
			else {
				forvalues _m = 1/`n_covsets' {
					local _modlab`=`_m'+1' "Model `=`_m'+1'"
				}
			}
		}
		else {
			if `n_covsets' == 1 {
				local _modlab1 "Adjusted"
			}
			else {
				forvalues _m = 1/`n_covsets' {
					local _modlab`_m' "Model `=`_m'+1'"
				}
			}
		}
	}

	* =========================================================================
	* CROSS-VALIDATION OF OPTIONS
	* =========================================================================

	* outcome() requires time()
	if !`_single_outcome' & `n_times' == 0 {
		noisily display as error "time() is required when outcome() is specified"
		exit 198
	}

	* time() count must be 1 (shared) or match n_outcomes
	if `n_times' > 0 & `n_times' != 1 & `n_times' != `n_outcomes' {
		noisily display as error "time() must specify 1 shared time variable or 1 per outcome"
		exit 198
	}

	* failvalue() requires outcome() with exactly 1 outcome variable
	if `n_failvals' > 0 {
		if `_single_outcome' {
			noisily display as error "failvalue() requires outcome()"
			exit 198
		}
		if `n_outcomes' > 1 {
			noisily display as error "failvalue() requires a single outcome variable (competing risks from one multi-level event variable)"
			exit 198
		}
		* With failvalue, actual outcome columns = n_failvals
		local _cr_outcome "`_outcome1'"
		local n_outcomes = `n_failvals'
		forvalues _fv = 1/`n_failvals' {
			local _outcome`_fv' "`_cr_outcome'"
		}
	}

	* finegray requires stsetopts() with id()
	if "`model'" == "finegray" & !`_single_outcome' {
		if "`stsetopts'" == "" | !strmatch("`stsetopts'", "*id(*") {
			noisily display as error "model(finegray) requires stsetopts() with id()"
			noisily display as error "Example: stsetopts(id(patient_id))"
			exit 198
		}
	}

	* stcrreg requires compete() — either via failvalue() or modelopts()
	if "`model'" == "stcrreg" & `n_failvals' == 0 {
		if !strmatch("`modelopts'", "*compete(*") {
			noisily display as error "model(stcrreg) requires either failvalue() or compete() via modelopts()"
			noisily display as error "Example: failvalue(1 \ 2) or modelopts(compete(event == 2 3))"
			exit 198
		}
	}

	* Single-outcome mode: verify existing stset
	if `_single_outcome' {
		capture st_is 2 analysis
		if _rc {
			noisily display as error "no outcome() specified and data are not stset"
			noisily display as error "Either specify outcome() and time(), or stset your data first"
			exit 119
		}
		* stptime requires id() in stset for all models
		if "`_dta[st_id]'" == "" {
			noisily display as error "hrtab requires stset with id(); current stset has no id()"
			noisily display as error "Hint: re-stset with id(), e.g. stset time, failure(event) id(patient_id)"
			exit 198
		}
	}

	* When outcome()/time() specified, stsetopts must include id() for stptime
	if !`_single_outcome' {
		if "`stsetopts'" == "" | !strmatch("`stsetopts'", "*id(*") {
			noisily display as error "hrtab requires stsetopts() with id() for person-time computation"
			noisily display as error "Example: stsetopts(id(patient_id))"
			exit 198
		}
	}

	* =========================================================================
	* CLASSIFY EXPOSURE PANELS
	* =========================================================================

	forvalues _p = 1/`n_panels' {
		local _es "`_exp_spec`_p''"
		if strmatch("`_es'", "c.*") {
			local _exp_type`_p' "continuous"
			local _exp_var`_p' = substr("`_es'", 3, .)
		}
		else if strmatch("`_es'", "i.*") | strmatch("`_es'", "ib*.*") {
			local _exp_type`_p' "categorical"
			* Extract variable name after i. or ib#.
			if strmatch("`_es'", "ib*.*") {
				* ib#.varname — extract after the dot
				if regexm("`_es'", "ib[0-9]+\.(.+)") {
					local _exp_var`_p' = regexs(1)
				}
			}
			else {
				local _exp_var`_p' = substr("`_es'", 3, .)
			}
		}
		else {
			noisily display as error "exposure() panel `_p' must use factor-variable notation: i.var, ib#.var, or c.var"
			noisily display as error "  Got: `_es'"
			exit 198
		}

		* Confirm exposure variable exists
		capture confirm variable `_exp_var`_p''
		if _rc {
			noisily display as error "exposure variable `_exp_var`_p'' not found"
			exit 111
		}

		* Set panel label
		if "`explabels'" != "" {
			local _panel_label`_p' "`_explab`_p''"
		}
		else {
			local _panel_label`_p' : variable label `_exp_var`_p''
			if "`_panel_label`_p''" == "" local _panel_label`_p' "`_exp_var`_p''"
		}

		* Save continuous variable label now (data cleared later for output)
		if "`_exp_type`_p''" == "continuous" {
			local _cont_label_p`_p' : variable label `_exp_var`_p''
			if "`_cont_label_p`_p''" == "" local _cont_label_p`_p' "`_exp_var`_p'' (per unit)"
		}
	}

	* =========================================================================
	* SET OUTCOME LABELS
	* =========================================================================

	forvalues _o = 1/`n_outcomes' {
		if "`outlabels'" != "" {
			local _out_label`_o' "`_outlab`_o''"
		}
		else if `n_failvals' > 0 {
			local _out_label`_o' "Cause `_failval`_o''"
		}
		else if !`_single_outcome' {
			local _out_label`_o' : variable label `_outcome`_o''
			if "`_out_label`_o''" == "" local _out_label`_o' "`_outcome`_o''"
		}
		else {
			local _out_label`_o' ""
		}
	}

	* =========================================================================
	* COMPUTE TABLE DIMENSIONS
	* =========================================================================

	* Columns per outcome group
	local _has_py = "`nopytime'" == ""
	local _has_ev = "`noevents'" == ""
	local _has_pval = "`pvalue'" != ""

	local _cols_per_model = 1
	if `_has_pval' local _cols_per_model = 2

	local _desc_cols = `_has_py' + `_has_ev'
	local _model_cols = `n_models' * `_cols_per_model'
	local _cols_per_outcome = `_desc_cols' + `_model_cols'

	* Total table columns: 1 (label) + outcomes * cols_per_outcome
	local _total_cols = 1 + `n_outcomes' * `_cols_per_outcome'

	* =========================================================================
	* PRESERVE DATA AND RUN ESTIMATION LOOP
	* =========================================================================

	preserve

	* Apply if/in restriction
	if `"`if'"' != "" | `"`in'"' != "" {
		quietly keep `if' `in'
	}

	local _total_models = 0
	local _stset_notes ""
	local _N_unadj .
	local _N_adj .
	local _adj_mismatch = 0

	* For each outcome
	forvalues _o = 1/`n_outcomes' {

		* Determine time variable for this outcome
		if `n_times' == 1 {
			local _tvar "`_time1'"
		}
		else if `n_times' > 1 {
			local _tvar "`_time`_o''"
		}

		* ---------------------------------------------------------------
		* STSET for this outcome
		* ---------------------------------------------------------------
		if !`_single_outcome' {
			if `n_failvals' > 0 {
				* Competing risks: stset with failure == specific value
				local _fv = `_failval`_o''
				if "`model'" == "stcrreg" {
					quietly stset `_tvar', failure(`_cr_outcome' == `_fv') `stsetopts'
				}
				else if "`model'" == "finegray" {
					* finegray needs failure = any event; it handles cause internally
					quietly stset `_tvar', failure(`_cr_outcome') `stsetopts'
				}
				else {
					* stcox with competing risks: censor at competing event
					quietly stset `_tvar', failure(`_cr_outcome' == `_fv') `stsetopts'
				}
				local _stset_notes "`_stset_notes' Outcome `_o': stset `_tvar', failure(`_cr_outcome'==`_fv') `stsetopts'."
			}
			else {
				* Independent outcomes
				quietly stset `_tvar', failure(`_outcome`_o'') `stsetopts'
				local _stset_notes "`_stset_notes' Outcome `_o': stset `_tvar', failure(`_outcome`_o'') `stsetopts'."
			}

			if "`nolog'" == "" {
				noisily display as text "Outcome `_o': " as result "`_out_label`_o''"
			}
		}

		* Build competing risks model options
		local _cr_opts ""
		if `n_failvals' > 0 {
			local _fv = `_failval`_o''

			if "`model'" == "stcrreg" {
				* Build compete() with all values except censvalue and current failvalue
				quietly levelsof `_cr_outcome', local(_all_levels)
				local _comp_vals ""
				foreach _lv of local _all_levels {
					if `_lv' != `censvalue' & `_lv' != `_fv' {
						local _comp_vals "`_comp_vals' `_lv'"
					}
				}
				local _comp_vals = strtrim("`_comp_vals'")
				if "`_comp_vals'" != "" {
					local _cr_opts "compete(`_cr_outcome' == `_comp_vals')"
				}
			}
			else if "`model'" == "finegray" {
				local _cr_opts "compete(`_cr_outcome') cause(`_fv')"
			}
		}

		* ---------------------------------------------------------------
		* LOOP OVER EXPOSURE PANELS
		* ---------------------------------------------------------------
		forvalues _p = 1/`n_panels' {

			local _evar "`_exp_var`_p''"
			local _espec "`_exp_spec`_p''"
			local _etype "`_exp_type`_p''"

			* -----------------------------------------------------------
			* PERSON-YEARS AND EVENTS via stptime
			* -----------------------------------------------------------
			if "`_etype'" == "categorical" {
				* Get level values and labels
				quietly levelsof `_evar' if _st == 1, local(_evar_levels)
				local _lev_count : word count `_evar_levels'

				* Compute person-years and events per level via stptime
				local _level_i = 0
				foreach _lv of local _evar_levels {
					local _level_i = `_level_i' + 1
					* Get label for this level
					local _vallbl : value label `_evar'
					if "`_vallbl'" != "" {
						local _lev_label`_level_i'_p`_p' : label `_vallbl' `_lv'
					}
					else {
						local _lev_label`_level_i'_p`_p' "`_lv'"
					}
					local _lev_val`_level_i'_p`_p' = `_lv'

					* Per-level stptime for reliable PY/event extraction
					capture noisily quietly stptime if `_evar' == `_lv'
					if _rc {
						noisily display as error "stptime failed for `_evar'==`_lv' in outcome `_o'"
						exit _rc
					}
					local _py_o`_o'_p`_p'_l`_level_i' = r(ptime) / `pyscale'
					local _ev_o`_o'_p`_p'_l`_level_i' = r(failures)
				}
				local _nlevels_p`_p' = `_level_i'

				* Identify base level for factor variable
				local _base_level_p`_p' = 0
				if strmatch("`_espec'", "ib*.*") {
					* Explicit base from ib#.
					if regexm("`_espec'", "ib([0-9]+)\.") {
						local _base_level_p`_p' = regexs(1)
					}
				}
				else {
					* Default base = lowest level
					local _base_level_p`_p' : word 1 of `_evar_levels'
				}
			}
			else {
				* Continuous: total person-years and events
				capture noisily quietly stptime
				if _rc {
					noisily display as error "stptime failed for exposure `_evar' in outcome `_o'"
					exit _rc
				}
				local _py_o`_o'_p`_p'_l1 = r(ptime) / `pyscale'
				local _ev_o`_o'_p`_p'_l1 = r(failures)
				local _nlevels_p`_p' = 1
			}

			* -----------------------------------------------------------
			* ESTIMATION LOOP
			* -----------------------------------------------------------
			local _m_start = 0
			if "`nounadjusted'" != "" local _m_start = 1

			forvalues _m = `_m_start'/`n_covsets' {

				* Build model command
				local _model_covars ""
				if `_m' > 0 {
					local _model_covars "`_covset`_m''"
				}

				* Build full model options
				local _full_opts "`modelopts'"
				if "`_cr_opts'" != "" {
					local _full_opts "`_cr_opts' `modelopts'"
				}

				* Estimation call
				local _est_cmd ""
				if "`model'" == "stcox" {
					local _est_cmd "stcox `_espec' `_model_covars'"
					if "`_full_opts'" != "" local _est_cmd "`_est_cmd', `_full_opts'"
				}
				else if "`model'" == "stcrreg" {
					local _est_cmd "stcrreg `_espec' `_model_covars'"
					if "`_full_opts'" != "" {
						local _est_cmd "`_est_cmd', `_full_opts'"
					}
				}
				else if "`model'" == "finegray" {
					local _est_cmd "finegray `_espec' `_model_covars'"
					if "`_full_opts'" != "" {
						local _est_cmd "`_est_cmd', `_full_opts'"
					}
				}

				if "`nolog'" != "" {
					if inlist("`model'", "stcox", "stcrreg", "finegray") {
						if strpos("`_est_cmd'", ",") == 0 {
							local _est_cmd "`_est_cmd', nolog"
						}
						else {
							local _est_cmd "`_est_cmd' nolog"
						}
					}
				}

				if "`dots'" != "" noisily display as text "." _continue

				capture noisily quietly `_est_cmd'
				if _rc {
					noisily display as error "Estimation failed: `_est_cmd'"
					exit _rc
				}

				local _total_models = `_total_models' + 1

				* Track N for missing covariate detection
				local _this_N = e(N)
				if `_m' == `_m_start' & `_o' == 1 & `_p' == 1 {
					local _N_unadj = `_this_N'
				}
				if `_m' > 0 {
					if `_N_adj' == . {
						local _N_adj = `_this_N'
					}
					else if `_this_N' < `_N_adj' {
						local _N_adj = `_this_N'
					}
				}

				* Determine model index in output
				local _mi = `_m'
				if "`nounadjusted'" != "" {
					local _mi = `_m'
				}
				else {
					local _mi = `_m' + 1
					if `_m' == 0 local _mi = 1
				}

				* ---------------------------------------------------
				* EXTRACT ESTIMATES
				* ---------------------------------------------------
				tempname _b_mat _V_mat
				matrix `_b_mat' = e(b)
				matrix `_V_mat' = e(V)
				local _b_names : colnames `_b_mat'

				if "`_etype'" == "categorical" {
					local _base_val = `_base_level_p`_p''

					forvalues _li = 1/`_nlevels_p`_p'' {
						local _lv = `_lev_val`_li'_p`_p''
						if `_lv' == `_base_val' {
							* Base/reference level — no estimates
							local _hr_o`_o'_p`_p'_l`_li'_m`_mi' .r
							local _lo_o`_o'_p`_p'_l`_li'_m`_mi' .r
							local _hi_o`_o'_p`_p'_l`_li'_m`_mi' .r
							local _pv_o`_o'_p`_p'_l`_li'_m`_mi' .r
							continue
						}

						* Find coefficient position
						local _coef_name "`_lv'.`_evar'"
						if "`model'" == "finegray" {
							local _coef_name "_fg_`_evar'_`_lv'"
							if length("`_coef_name'") > 32 {
								local _coef_name = substr("`_coef_name'", 1, 32)
							}
						}
						local _coef_pos = 0
						local _cn = 0
						foreach _bn of local _b_names {
							local _cn = `_cn' + 1
							if "`_bn'" == "`_coef_name'" {
								local _coef_pos = `_cn'
								continue, break
							}
						}

						if `_coef_pos' == 0 {
							* Coefficient not found — may be omitted
							local _hr_o`_o'_p`_p'_l`_li'_m`_mi' .
							local _lo_o`_o'_p`_p'_l`_li'_m`_mi' .
							local _hi_o`_o'_p`_p'_l`_li'_m`_mi' .
							local _pv_o`_o'_p`_p'_l`_li'_m`_mi' .
							continue
						}

						* Extract log-coefficient and SE
						local _loghr = `_b_mat'[1, `_coef_pos']
						local _se = sqrt(`_V_mat'[`_coef_pos', `_coef_pos'])

						* Compute HR and CI (exponentiated)
						local _z = invnormal(1 - (1 - `level'/100) / 2)
						local _hr_o`_o'_p`_p'_l`_li'_m`_mi' = exp(`_loghr')
						local _lo_o`_o'_p`_p'_l`_li'_m`_mi' = exp(`_loghr' - `_z' * `_se')
						local _hi_o`_o'_p`_p'_l`_li'_m`_mi' = exp(`_loghr' + `_z' * `_se')

						* P-value (two-sided Wald test)
						if `_se' > 0 {
							local _wald = `_loghr' / `_se'
							local _pv_o`_o'_p`_p'_l`_li'_m`_mi' = 2 * normal(-abs(`_wald'))
						}
						else {
							local _pv_o`_o'_p`_p'_l`_li'_m`_mi' .
						}
					}
				}
				else {
					* Continuous exposure: single coefficient
					* Find the continuous variable coefficient
					local _coef_name "`_evar'"
					local _coef_pos = 0
					local _cn = 0
					foreach _bn of local _b_names {
						local _cn = `_cn' + 1
						if "`_bn'" == "`_coef_name'" {
							local _coef_pos = `_cn'
							continue, break
						}
					}

					if `_coef_pos' > 0 {
						local _loghr = `_b_mat'[1, `_coef_pos']
						local _se = sqrt(`_V_mat'[`_coef_pos', `_coef_pos'])
						local _z = invnormal(1 - (1 - `level'/100) / 2)
						local _hr_o`_o'_p`_p'_l1_m`_mi' = exp(`_loghr')
						local _lo_o`_o'_p`_p'_l1_m`_mi' = exp(`_loghr' - `_z' * `_se')
						local _hi_o`_o'_p`_p'_l1_m`_mi' = exp(`_loghr' + `_z' * `_se')
						if `_se' > 0 {
							local _wald = `_loghr' / `_se'
							local _pv_o`_o'_p`_p'_l1_m`_mi' = 2 * normal(-abs(`_wald'))
						}
						else {
							local _pv_o`_o'_p`_p'_l1_m`_mi' .
						}
					}
					else {
						local _hr_o`_o'_p`_p'_l1_m`_mi' .
						local _lo_o`_o'_p`_p'_l1_m`_mi' .
						local _hi_o`_o'_p`_p'_l1_m`_mi' .
						local _pv_o`_o'_p`_p'_l1_m`_mi' .
					}
				}

			} // end model loop
		} // end panel loop
	} // end outcome loop

	if "`dots'" != "" noisily display ""

	* Check for missing covariate mismatch
	if `_N_adj' != . & `_N_unadj' != . & `_N_adj' < `_N_unadj' {
		local _adj_mismatch = 1
	}

	* =========================================================================
	* BUILD OUTPUT DATASET
	* =========================================================================

	restore
	preserve

	clear

	* Create columns
	forvalues _c = 1/`_total_cols' {
		quietly gen str244 c`_c' = ""
	}
	quietly gen str244 labelvar = ""

	* --- Row 1: Title ---
	quietly set obs 1
	if "`title'" != "" {
		quietly replace labelvar = "`title'" in 1
	}

	* --- Row 2: Outcome group headers ---
	local _row = 2
	quietly set obs `_row'
	local _header_row = `_row'
	quietly replace c1 = "" in `_row'
	local _col = 2
	forvalues _o = 1/`n_outcomes' {
		if !`_single_outcome' | `n_outcomes' > 1 {
			quietly replace c`_col' = "`_out_label`_o''" in `_row'
		}
		local _col = `_col' + `_cols_per_outcome'
	}

	* --- Row 4 (or 3): Sub-headers ---
	local _row = `_row' + 1
	quietly set obs `_row'
	local _subheader_row = `_row'
	quietly replace c1 = "" in `_row'
	local _col = 2
	forvalues _o = 1/`n_outcomes' {
		if `_has_py' {
			quietly replace c`_col' = "Person-years" in `_row'
			local _col = `_col' + 1
		}
		if `_has_ev' {
			quietly replace c`_col' = "Events" in `_row'
			local _col = `_col' + 1
		}
		forvalues _m = 1/`n_models' {
			local _eff_hdr "`effect' (95% CI)"
			quietly replace c`_col' = "`_modlab`_m'' `_eff_hdr'" in `_row'
			local _col = `_col' + 1
			if `_has_pval' {
				quietly replace c`_col' = "P" in `_row'
				local _col = `_col' + 1
			}
		}
	}

	* --- Data rows ---
	local _data_start = `_row' + 1

	forvalues _p = 1/`n_panels' {

		* Panel header row
		local _row = `_row' + 1
		quietly set obs `_row'
		quietly replace c1 = "`_panel_label`_p''" in `_row'

		if "`_exp_type`_p''" == "categorical" {

			forvalues _li = 1/`_nlevels_p`_p'' {
				local _row = `_row' + 1
				quietly set obs `_row'

				* Level label (indented)
				quietly replace c1 = "   `_lev_label`_li'_p`_p''" in `_row'

				local _col = 2
				forvalues _o = 1/`n_outcomes' {
					* Person-years
					if `_has_py' {
						if `pydigits' == 0 {
							local _py_str = string(round(`_py_o`_o'_p`_p'_l`_li'', 1), "%11.0fc")
						}
						else {
							local _py_str = string(`_py_o`_o'_p`_p'_l`_li'', "%11.`pydigits'fc")
						}
						quietly replace c`_col' = strtrim("`_py_str'") in `_row'
						local _col = `_col' + 1
					}

					* Events
					if `_has_ev' {
						local _ev_str = string(`_ev_o`_o'_p`_p'_l`_li'', "%11.0fc")
						quietly replace c`_col' = strtrim("`_ev_str'") in `_row'
						local _col = `_col' + 1
					}

					* Model columns
					forvalues _m = 1/`n_models' {
						local _hr_val "`_hr_o`_o'_p`_p'_l`_li'_m`_m''"

						if "`_hr_val'" == ".r" {
							* Reference level
							quietly replace c`_col' = "`reflabel'" in `_row'
							local _col = `_col' + 1
							if `_has_pval' {
								quietly replace c`_col' = "" in `_row'
								local _col = `_col' + 1
							}
						}
						else if "`_hr_val'" == "." | "`_hr_val'" == "" {
							quietly replace c`_col' = "–" in `_row'
							local _col = `_col' + 1
							if `_has_pval' {
								quietly replace c`_col' = "" in `_row'
								local _col = `_col' + 1
							}
						}
						else {
							* Format HR (CI)
							local _hr_fmt = strtrim(string(round(`_hr_val', 10^(-`digits')), "%9.`digits'f"))
							local _lo_val "`_lo_o`_o'_p`_p'_l`_li'_m`_m''"
							local _hi_val "`_hi_o`_o'_p`_p'_l`_li'_m`_m''"
							local _lo_fmt = strtrim(string(round(`_lo_val', 10^(-`digits')), "%9.`digits'f"))
							local _hi_fmt = strtrim(string(round(`_hi_val', 10^(-`digits')), "%9.`digits'f"))

							quietly replace c`_col' = "`_hr_fmt' (`_lo_fmt'-`_hi_fmt')" in `_row'
							local _col = `_col' + 1

							if `_has_pval' {
								local _pv_val "`_pv_o`_o'_p`_p'_l`_li'_m`_m''"
								if "`_pv_val'" != "." & "`_pv_val'" != "" {
									if `_pv_val' < 0.001 {
										quietly replace c`_col' = "<0.001" in `_row'
									}
									else {
										quietly replace c`_col' = strtrim(string(round(`_pv_val', 0.001), "%5.3f")) in `_row'
									}
								}
								local _col = `_col' + 1
							}
						}
					}
				}
			}
		}
		else {
			* Continuous exposure: single data row
			local _row = `_row' + 1
			quietly set obs `_row'

			* Use pre-saved variable label as row label
			quietly replace c1 = "   `_cont_label_p`_p''" in `_row'

			local _col = 2
			forvalues _o = 1/`n_outcomes' {
				if `_has_py' {
					if `pydigits' == 0 {
						local _py_str = string(round(`_py_o`_o'_p`_p'_l1', 1), "%11.0fc")
					}
					else {
						local _py_str = string(`_py_o`_o'_p`_p'_l1', "%11.`pydigits'fc")
					}
					quietly replace c`_col' = strtrim("`_py_str'") in `_row'
					local _col = `_col' + 1
				}
				if `_has_ev' {
					local _ev_str = string(`_ev_o`_o'_p`_p'_l1', "%11.0fc")
					quietly replace c`_col' = strtrim("`_ev_str'") in `_row'
					local _col = `_col' + 1
				}

				forvalues _m = 1/`n_models' {
					local _hr_val "`_hr_o`_o'_p`_p'_l1_m`_m''"
					if "`_hr_val'" == "." | "`_hr_val'" == "" {
						quietly replace c`_col' = "–" in `_row'
						local _col = `_col' + 1
						if `_has_pval' {
							local _col = `_col' + 1
						}
					}
					else {
						local _hr_fmt = strtrim(string(round(`_hr_val', 10^(-`digits')), "%9.`digits'f"))
						local _lo_val "`_lo_o`_o'_p`_p'_l1_m`_m''"
						local _hi_val "`_hi_o`_o'_p`_p'_l1_m`_m''"
						local _lo_fmt = strtrim(string(round(`_lo_val', 10^(-`digits')), "%9.`digits'f"))
						local _hi_fmt = strtrim(string(round(`_hi_val', 10^(-`digits')), "%9.`digits'f"))

						quietly replace c`_col' = "`_hr_fmt' (`_lo_fmt'-`_hi_fmt')" in `_row'
						local _col = `_col' + 1

						if `_has_pval' {
							local _pv_val "`_pv_o`_o'_p`_p'_l1_m`_m''"
							if "`_pv_val'" != "." & "`_pv_val'" != "" {
								if `_pv_val' < 0.001 {
									quietly replace c`_col' = "<0.001" in `_row'
								}
								else {
									quietly replace c`_col' = strtrim(string(round(`_pv_val', 0.001), "%5.3f")) in `_row'
								}
							}
							local _col = `_col' + 1
						}
					}
				}
			}
		}
	}

	* --- Addrow ---
	if `"`addrow'"' != "" {
		local _ar_raw `"`addrow'"'
		local _ar_raw = subinstr(`"`_ar_raw'"', " \ ", "\", .)
		local _ar_raw = subinstr(`"`_ar_raw'"', "\  ", "\", .)
		local _ar_raw = subinstr(`"`_ar_raw'"', "  \", "\", .)
		tokenize `"`_ar_raw'"', parse("\")
		forvalues _ari = 1/100 {
			local _arj = (`_ari' - 1) * 2 + 1
			if `"``_arj''"' == "" continue, break
			local _ar_entry = strtrim(`"``_arj''"')

			local _row = `_row' + 1
			quietly set obs `_row'
			gettoken _ar_label _ar_rest : _ar_entry
			quietly replace c1 = "`_ar_label'" in `_row'
			local _arc = 1
			foreach _arv of local _ar_rest {
				local _arc = `_arc' + 1
				if `_arc' <= `_total_cols' {
					quietly replace c`_arc' = "`_arv'" in `_row'
				}
			}
		}
	}

	local _lastrow = `_row'

	* Identify panel header rows (for border formatting)
	local _panel_rows ""
	forvalues _r = `_data_start'/`_lastrow' {
		local _c2val = c2[`_r']
		local _c1val = c1[`_r']
		if "`_c1val'" != "" & !strmatch("`_c1val'", "   *") & "`_c2val'" == "" {
			local _panel_rows "`_panel_rows' `_r'"
		}
	}

	* =========================================================================
	* CONSOLE DISPLAY
	* =========================================================================

	if "`display'" != "" | !`_has_xlsx' {
		_tabtools_console_display `_total_cols' `"`title'"', ///
			labelvar(labelvar) datastart(`_data_start') headerstart(`_header_row')
	}

	* =========================================================================
	* CSV EXPORT
	* =========================================================================

	if "`csv'" != "" {
		order labelvar c*
		export delimited using "`csv'", replace
	}

	* =========================================================================
	* FRAME STORAGE
	* =========================================================================

	if "`frame'" != "" {
		_tabtools_frame_put "`frame'"
	}

	* =========================================================================
	* EXCEL EXPORT
	* =========================================================================

	if `_has_xlsx' {

		order labelvar c*
		export excel using "`xlsx'", sheet("`sheet'") sheetreplace

		* Mata formatting: column widths
		capture {
			mata: b = xl()
			mata: b.load_book("`xlsx'")
			mata: b.set_sheet("`sheet'")
			mata: b.set_row_height(1, 1, 30)
			mata: b.set_column_width(1, 1, 1)
			mata: b.set_column_width(2, 2, 22)

			forvalues _col = 3/`=`_total_cols' + 1' {
				mata: st_local("_hdr", b.get_string(`_subheader_row', `_col'))
				local _hdrlen = strlen("`_hdr'")
				local _cw = max(14, `_hdrlen' + 2)
				mata: b.set_column_width(`_col', `_col', `_cw')
			}
			mata: b.close_book()
		}
		if _rc {
			local saved_rc = _rc
			capture mata: b.close_book()
			capture mata: mata drop b
			noisily display as error "Excel formatting (Mata) failed with error `saved_rc'"
			exit `saved_rc'
		}
		capture mata: mata drop b

		* Putexcel formatting
		capture {
			putexcel set "`xlsx'", sheet("`sheet'") modify

			* Column letters
			_tabtools_build_col_letters `=`_total_cols' + 1'
			local letters "`result'"
			local lastcol : word `=`_total_cols' + 1' of `letters'

			* Title row
			putexcel (A1:`lastcol'1), merge bold txtwrap left vcenter font("`_font'", `=`_fontsize' + 2')

			* Header rows
			putexcel (B`_header_row':`lastcol'`_header_row'), border(top, `_hborder')
			putexcel (B`_subheader_row':`lastcol'`_subheader_row'), border(bottom, `_hborder')

			* Merge outcome headers
			if !`_single_outcome' | `n_outcomes' > 1 {
				local _col = 2
				forvalues _o = 1/`n_outcomes' {
					local _col1 : word `_col' of `letters'
					local _col_end : word `=`_col' + `_cols_per_outcome' - 1' of `letters'
					putexcel (`_col1'`_header_row':`_col_end'`_header_row'), merge bold hcenter top border(bottom, `_hborder')
					local _col = `_col' + `_cols_per_outcome'
				}
			}

			* Sub-header formatting
			local _col = 2
			forvalues _o = 1/`n_outcomes' {
				forvalues _sh = 1/`_cols_per_outcome' {
					local _sh_col : word `_col' of `letters'
					putexcel (`_sh_col'`_subheader_row'), bold hcenter vcenter
					local _col = `_col' + 1
				}
			}

			* Header shading
			if "`headershade'" != "" {
				putexcel (B`_header_row':`lastcol'`_subheader_row'), fpattern(solid, "`_headercolor'")
			}

			* Font for all data
			putexcel (B`_header_row':`lastcol'`_lastrow'), font("`_font'", `_fontsize')

			* Center-align data columns
			putexcel (C`_data_start':`lastcol'`_lastrow'), hcenter

			* Panel header rows: bold + top border
			foreach _pr of local _panel_rows {
				putexcel (B`_pr':`lastcol'`_pr'), bold
				if `_pr' > `_data_start' {
					local _br = `_pr' - 1
					putexcel (B`_br':`lastcol'`_br'), border(bottom, `_hborder')
				}
			}

			* Zebra striping
			if "`zebra'" != "" {
				forvalues _zr = `=`_data_start' + 1'(2)`_lastrow' {
					putexcel (B`_zr':`lastcol'`_zr'), fpattern(solid, "`_zebracolor'")
				}
			}

			* Vertical borders between outcome groups
			if "`borderstyle'" != "academic" {
				putexcel (B`_header_row':B`_lastrow'), border(left, `borderstyle')
				putexcel (B`_header_row':B`_lastrow'), border(right, `borderstyle')

				local _col = 2
				forvalues _o = 1/`n_outcomes' {
					local _col_end : word `=`_col' + `_cols_per_outcome' - 1' of `letters'
					putexcel (`_col_end'`_header_row':`_col_end'`_lastrow'), border(right, `borderstyle')
					local _col = `_col' + `_cols_per_outcome'
				}
			}

			* Bottom border
			putexcel (B`_lastrow':`lastcol'`_lastrow'), border(bottom, `_hborder')

			* Bold p-values
			if `has_boldp' & `_has_pval' {
				forvalues _r = `_data_start'/`_lastrow' {
					local _col = 2
					forvalues _o = 1/`n_outcomes' {
						local _col = `_col' + `_desc_cols'
						forvalues _m = 1/`n_models' {
							local _col = `_col' + 1
							local _pcol : word `_col' of `letters'
							local _pval_str = c`_col'[`_r']
							if "`_pval_str'" != "" & "`_pval_str'" != "P" {
								capture confirm number `_pval_str'
								if !_rc {
									if `_pval_str' < `boldp' {
										putexcel (`_pcol'`_r'), bold
									}
								}
								else if strmatch("`_pval_str'", "<*") {
									putexcel (`_pcol'`_r'), bold
								}
							}
							local _col = `_col' + 1
						}
					}
				}
			}

			* Highlight significant rows
			if `has_highlight' & `_has_pval' {
				forvalues _r = `_data_start'/`_lastrow' {
					local _sig = 0
					local _col = 2
					forvalues _o = 1/`n_outcomes' {
						local _col = `_col' + `_desc_cols'
						forvalues _m = 1/`n_models' {
							local _col = `_col' + 1
							local _pval_str = c`_col'[`_r']
							if "`_pval_str'" != "" {
								capture confirm number `_pval_str'
								if !_rc {
									if `_pval_str' < `highlight' local _sig = 1
								}
								else if strmatch("`_pval_str'", "<*") {
									local _sig = 1
								}
							}
							local _col = `_col' + 1
						}
					}
					if `_sig' {
						putexcel (B`_r':`lastcol'`_r'), fpattern(solid, "255 255 204")
					}
				}
			}

			* Footnote
			local _fn_text `"`footnote'"'
			if `_adj_mismatch' {
				local _adj_note "N=`_N_adj' in adjusted model(s) due to missing covariates"
				if `"`_fn_text'"' != "" {
					local _fn_text `"`_fn_text'. `_adj_note'"'
				}
				else {
					local _fn_text `"`_adj_note'"'
				}
			}
			if `"`_fn_text'"' != "" {
				_tabtools_footnote `"`_fn_text'"' "`lastcol'" `_lastrow' "`_font'" `_fontsize'
			}

			putexcel clear
		}
		if _rc {
			local saved_rc = _rc
			capture putexcel clear
			noisily display as error "Excel formatting failed with error `saved_rc'"
			exit `saved_rc'
		}

		capture confirm file "`xlsx'"
		if _rc == 0 {
			noisily display as result `"Exported to `xlsx'"'
		}
		else {
			noisily display as error "Export succeeded but file not found at `xlsx'"
		}
	}

	* Open file if requested
	if "`open'" != "" & `_has_xlsx' {
		_tabtools_open_file "`xlsx'"
	}

	* =========================================================================
	* STORED RESULTS
	* =========================================================================

	restore

	return scalar models = `_total_models'
	return scalar outcomes = `n_outcomes'
	return scalar panels = `n_panels'
	if `_N_unadj' != . return scalar N_unadjusted = `_N_unadj'
	if `_N_adj' != . return scalar N_adjusted = `_N_adj'
	if `_has_xlsx' return local xlsx "`xlsx'"
	return local sheet "`sheet'"
	return local cmd "`model'"
	return local stset_notes "`_stset_notes'"

	} // end capture noisily
	local rc = _rc
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end
