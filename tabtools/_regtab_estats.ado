*! _regtab_estats Version 2.5.0  2026/10/06
*! generic stats() e(name) values from the collection
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_estats: generic stats() e(name) values from the collection
* =============================================================================
* Usage: _regtab_estats <models> <name> [<name> ...]
* Read from the collection, never from the active e(). Models are matched by
* their cmdset level, in regtab's column order (_regtab_cmdsets), so a model
* without the scalar stays blank (missing). A name no collected model holds
* is an error. Returns _cstv_<k>_<m> and _cst_int_<k> (1 when every value is
* an integer) in the caller, k indexing the names as given.
capture program drop _regtab_estats
program define _regtab_estats, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken _nmod 0 : 0
	local _names `0'
	local _nn : word count `_names'
	local _rl_n 0
	local _rl_present ""
	capture noisily {
		forvalues _k = 1/`_nn' {
			forvalues m = 1/`_nmod' {
				local _v_`_k'_`m' = .
			}
		}
		* column order, not collect's string order (1 10 11 2 ...)
		_regtab_cmdsets
		local _levels `"`_cs_levels'"'
		_regtab_rlabels `_names'
		local _present "`_rl_present'"
		if "`_present'" != "" {
			quietly collect layout (cmdset) (result[`_present'])
			preserve
			_tabtools_collect_render, type(stats) rowdim(cmdset) results(`_present')
			quietly ds A, not
			local _vars `r(varlist)'
			forvalues _k = 1/`_nn' {
				local _nm : word `_k' of `_names'
				local _col_`_k' ""
				foreach v of local _vars {
					if strtrim(`v'[1]) == "`_nm'" local _col_`_k' "`v'"
				}
			}
			forvalues _r = 2/`=_N' {
				local _lev = strtrim(A[`_r'])
				local m : list posof "`_lev'" in _levels
				if `m' < 1 | `m' > `_nmod' continue
				forvalues _k = 1/`_nn' {
					if "`_col_`_k''" == "" continue
					local _x = real(subinstr(strtrim(`_col_`_k''[`_r']), ",", "", .))
					if !missing(`_x') local _v_`_k'_`m' = `_x'
				}
			}
			restore
		}
	}
	local _rc = _rc
	forvalues _rli = 1/`_rl_n' {
		local _rlv : word `_rli' of `_rl_present'
		capture quietly collect label levels result `_rlv' `"`macval(_rl_lbl_`_rli')'"', modify
	}
	if `_rc' {
		display as error "stats(): could not read the e() statistics from the collection"
	}
	else {
		forvalues _k = 1/`_nn' {
			local _any = 0
			local _int = 1
			forvalues m = 1/`_nmod' {
				c_local _cstv_`_k'_`m' `_v_`_k'_`m''
				if !missing(`_v_`_k'_`m'') {
					local _any = 1
					if `_v_`_k'_`m'' != round(`_v_`_k'_`m'') local _int = 0
				}
			}
			c_local _cst_int_`_k' `_int'
			if !`_any' & !`_rc' {
				local _nm : word `_k' of `_names'
				display as error "stats(): e(`_nm') is not in any collected model"
				local _rc = 111
			}
		}
	}
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
