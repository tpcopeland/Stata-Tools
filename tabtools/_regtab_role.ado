*! _regtab_role Version 2.5.3  2026/10/06
*! structural role of one collected coefficient
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_role: structural role of one collected coefficient
* =============================================================================
* Usage: _regtab_role "<coleq level>" "<colname level>"
* Returns _role in the caller: cons (_cons in any equation), re (a random-
* effects parameter), cut (cut# in the ancillary equation), anc (any other
* parameter of the "/" or _diparm# equations), scale (a coefficient of an
* lnsigma scale equation), or reg (an ordinary coefficient).
capture program drop _regtab_role
program define _regtab_role, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _rr_eq 0 : 0
		gettoken _rr_key 0 : 0
		local _rr_anceq = (`"`_rr_eq'"' == "/" | regexm(`"`_rr_eq'"', "^_diparm"))
		if `"`_rr_key'"' == "_cons" local _rr "cons"
		else if ustrregexm(`"`_rr_key'"', "^(var|cov|sd|corr)\(") local _rr "re"
		else if `_rr_anceq' & regexm(`"`_rr_key'"', "^cut[0-9]+$") local _rr "cut"
		else if `_rr_anceq' local _rr "anc"
		else if lower(`"`_rr_eq'"') == "lnsigma" local _rr "scale"
		else local _rr "reg"
		c_local _role "`_rr'"
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
