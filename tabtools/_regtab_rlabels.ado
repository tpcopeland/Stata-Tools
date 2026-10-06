*! _regtab_rlabels Version 2.5.2  2026/10/06
*! hand result levels to a layout under their own names
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_rlabels: hand result levels to a layout under their own names
* =============================================================================
* Usage: _regtab_rlabels <level> [<level> ...]
* Keeps the listed result levels present in the current collection (a layout
* naming an absent level adds that level to the user's collection), records
* each one's current label, and relabels it with its level name, so a layout
* of them exports the level names as column headers. Returns in the caller:
* _rl_present (the present levels, in collection order), _rl_n, and _rl_lbl_#
* (the label of the #th present level, "" when it had none). The caller
* restores each with collect label levels result <level> `"<label>"', modify;
* an empty label removes the one set here, as collect label documents. The
* labels are read from collect label list's s() results through Mata, so no
* label text is macro-expanded.
capture program drop _regtab_rlabels
program define _regtab_rlabels, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	c_local _rl_present ""
	c_local _rl_n 0
	capture noisily {
		local _want `0'
		local _k ""
		capture quietly collect label list result, all
		if _rc == 0 mata: st_local("_k", st_global("s(k)"))
		if "`_k'" == "" local _k 0
		local _n 0
		local _present ""
		forvalues _i = 1/`_k' {
			mata: st_local("_lv", st_global("s(level`_i')"))
			local _hit : list _lv in _want
			if !`_hit' continue
			local ++_n
			local _present `_present' `_lv'
			mata: st_local("_lb`_n'", st_global("s(label`_i')"))
		}
		forvalues _j = 1/`_n' {
			local _lv : word `_j' of `_present'
			quietly collect label levels result `_lv' "`_lv'", modify
			c_local _rl_lbl_`_j' `"`macval(_lb`_j')'"'
		}
		c_local _rl_present "`_present'"
		c_local _rl_n `_n'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
