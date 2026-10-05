*! _regtab_keys Version 2.5.0  2026/10/06
*! regtab block: key variables of frame(name, flat keys)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end.
* regtab calls it as "noisily _regtab_keys <step>" from inside its quietly
* block, only for frame(name, flat keys).
*
* Steps:
*   rows   on the coefficient body (rows 3 on, while each model's constraint
*          class _constraint# is still there), creates _kty (row type),
*          _ktm (term), and _kst1, _kst2, ... (the state of each model's cell)
*   stats  marks the stats() rows: _kty "stat", _ktm "stat:<item>"
*   save   (before the title row is added) gives every row without a state
*          one from its printed cell, copies rows 3 on into the Mata matrix
*          _regtab_K, and drops the variables
*   put    on the flat frame's data (one row per body line, in the same
*          order), adds _order, _term, _rowtype, and _state1 ... _state<n>
*          for the n printed columns, each marked char <var>[tabtools_key] 1
*
* _term is the row's raw coefficient name in keep()'s form (factor operators
* and b./o./n markers dropped: 9.edss_t, 1.a#2.b, age, 1.g#x), preceded in a
* multi-equation table by its equation as the collection names it (4:mpg),
* and for a random-effects row by its level (district:var(_cons)). A factor's
* heading row carries the factor (edss_t, a#b), a stats() row
* stat:<item>, an addrow() row addrow:<k> (its position in addrow()).
* _rowtype is factor, level, var, re, stat, or addrow. _state# is the state of
* the model cell that printed column c# belongs to: est (an estimate), ref
* (refcat()), omit (omitlabel()), notest (notestlabel()), masked
* (emptylabel() under mincount(), too few events), absent (absentlabel()), constrained (the
* estimate with cnslabel()), note (cellnote()), stat (a stats() value), text
* (an addrow() value), or empty (a blank cell: no such coefficient).
program define _regtab_keys, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	gettoken _rtns_step 0 : 0
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
if "`_rtns_step'" == "rows" {
	quietly generate str8 _kty = ""
	quietly generate strL _ktm = ""
	forvalues _ky_mm = 1/`n_models' {
		quietly generate str11 _kst`_ky_mm' = ""
	}
	* the factor headings: every parent of a level row
	local _ky_par ""
	forvalues _ky_r = 3/`=_N' {
		local _ky_key = strtrim(_raw_A[`_ky_r'])
		if `"`_ky_key'"' == "" continue
		_regtab_fvparent `"`_ky_key'"'
		if `"`_fp_parent'"' != "" local _ky_par : list _ky_par | _fp_parent
	}
	forvalues _ky_r = 3/`=_N' {
		local _ky_key = strtrim(_raw_A[`_ky_r'])
		local _ky_eq = strtrim(_raw_eq[`_ky_r'])
		local _ky_ty "var"
		local _ky_hl = ustrregexm(`"`_ky_key'"', "(^|#)[0-9]+[a-z]*\.")
		local _ky_ip : list _ky_key in _ky_par
		if `"`_ky_key'"' == "" local _ky_ty "header"
		else if `_ky_hl' local _ky_ty "level"
		else if `_ky_ip' local _ky_ty "factor"
		else if _is_re[`_ky_r'] == 1 local _ky_ty "re"
		* keep()'s form: factor operators and level markers dropped
		local _ky_t = ustrregexra(ustrregexra(`"`_ky_key'"', ///
			"(^|#)(i|c|o|b|bn|ibn|ib[0-9]+)\.", "$1"), "(^|#)([0-9]+)(b|bn|o)\.", "$1$2.")
		if `"`_ky_eq'"' != "" & (`_is_multieq' | "`_ky_ty'" == "re") local _ky_t `"`_ky_eq':`_ky_t'"'
		quietly replace _kty = "`_ky_ty'" in `_ky_r'
		mata: st_sstore(`_ky_r', "_ktm", st_local("_ky_t"))
		if inlist("`_ky_ty'", "factor", "header") continue
		forvalues _ky_mm = 1/`n_models' {
			local _ky_cs = _constraint`_ky_mm'[`_ky_r']
			local _ky_ce = 3 * `_ky_mm' - 2
			local _ky_ab : list _ky_r in _mc_ab_`_ky_mm'
			local _ky_st = cond(strtrim(c`_ky_ce'[`_ky_r']) != "", "est", "empty")
			if "`_ky_cs'" == "base" local _ky_st "ref"
			else if "`_ky_cs'" == "omit" local _ky_st "omit"
			else if inlist("`_ky_cs'", "empty", "mk_ne") local _ky_st "notest"
			else if "`_ky_cs'" == "cns" local _ky_st "constrained"
			else if "`_ky_cs'" == "note" local _ky_st "note"
			else if "`_ky_cs'" == "mk_th" local _ky_st "masked"
			else if "`_ky_cs'" == "mk_ab" | `_ky_ab' local _ky_st "absent"
			quietly replace _kst`_ky_mm' = "`_ky_st'" in `_ky_r'
		}
	}
}
else if "`_rtns_step'" == "stats" {
	* stats_row_ids, when the stats() block names its rows, holds one item
	* per row of stats_rows; otherwise a row is known by its position
	local _ky_sn : word count `stats_rows'
	local _ky_nmd = (`: word count `stats_row_ids'' == `_ky_sn')
	local _ky_si = 0
	foreach _ky_r of local stats_rows {
		local ++_ky_si
		local _ky_id = cond(`_ky_nmd', "`: word `_ky_si' of `stats_row_ids''", "`_ky_si'")
		quietly replace _kty = "stat" in `_ky_r'
		mata: st_sstore(`_ky_r', "_ktm", "stat:" + st_local("_ky_id"))
	}
}
else if "`_rtns_step'" == "save" {
	forvalues _ky_mm = 1/`n_models' {
		local _ky_ce = 3 * `_ky_mm' - 2
		quietly replace _kst`_ky_mm' = cond(strtrim(c`_ky_ce') != "", cond(_kty == "stat", "stat", "text"), "empty") ///
			if _n >= 3 & inlist(_kty, "stat", "addrow")
		quietly replace _kst`_ky_mm' = "empty" if _n >= 3 & _kst`_ky_mm' == ""
	}
	local _ky_v "_kty _ktm"
	forvalues _ky_mm = 1/`n_models' {
		local _ky_v "`_ky_v' _kst`_ky_mm'"
	}
	mata: _regtab_K = st_sdata((3::st_nobs()), tokens(st_local("_ky_v")))
	drop `_ky_v'
}
else if "`_rtns_step'" == "put" {
	mata: st_local("_ky_n", strofreal(rows(_regtab_K)))
	if `_ky_n' != _N {
		noisily display as error "frame(, flat keys): the keys do not align with the frame's rows"
		exit 459
	}
	quietly generate double _order = _n
	label variable _order "row order (sort on it)"
	local _ky_cols "2 1"
	local _ky_names "_term _rowtype"
	local _ky_lab `""term: coefficient name, keep() form" "row type""'
	forvalues _ky_j = 1/`n' {
		local _ky_m = ceil(`_ky_j' / `_cols_per_model')
		local _ky_cols "`_ky_cols' `=2 + `_ky_m''"
		local _ky_names "`_ky_names' _state`_ky_j'"
		local _ky_lab `"`_ky_lab' "state of c`_ky_j'""'
	}
	local _ky_k : word count `_ky_names'
	forvalues _ky_i = 1/`_ky_k' {
		local _ky_vn : word `_ky_i' of `_ky_names'
		local _ky_c : word `_ky_i' of `_ky_cols'
		mata: st_local("_ky_w", strofreal(max((max(strlen(_regtab_K[., `_ky_c'])), 1))))
		if `_ky_w' > 2045 quietly generate strL `_ky_vn' = ""
		else quietly generate str`_ky_w' `_ky_vn' = ""
		mata: st_sstore(., st_local("_ky_vn"), _regtab_K[., `_ky_c'])
		local _ky_l : word `_ky_i' of `_ky_lab'
		label variable `_ky_vn' `"`_ky_l'"'
	}
	foreach _ky_vn in _order `_ky_names' {
		char `_ky_vn'[tabtools_key] 1
	}
	char _dta[tabtools_keys] "_order `_ky_names'"
}
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end
