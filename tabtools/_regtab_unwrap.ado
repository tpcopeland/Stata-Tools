*! _regtab_unwrap Version 2.4.0  2026/10/05
*! one extra quote layer around a whole specification
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_unwrap: one extra quote layer around a whole specification
* =============================================================================
* Usage: _regtab_unwrap `"<spec>"'
* Returns _uw_spec in the caller: <spec> itself, or, when <spec> is a single
* quoted token whose content starts with a quote (addrow(`"`spec'"') written
* by a program around "label" ...), that content.
capture program drop _regtab_unwrap
program define _regtab_unwrap, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken _spec 0 : 0
	capture noisily {
		gettoken _t _r2 : _spec, quotes
		if `"`macval(_r2)'"' == "" {
			gettoken _in : _spec
			local _in = strtrim(`"`macval(_in)'"')
			if substr(`"`macval(_in)'"', 1, 1) == char(34) | ///
				substr(`"`macval(_in)'"', 1, 2) == char(96) + char(34) local _spec : copy local _in
		}
	}
	local _rc = _rc
	c_local _uw_spec `"`macval(_spec)'"'
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
