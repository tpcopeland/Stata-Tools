*! _regtab_cmdsets Version 2.5.0  2026/10/06
*! cmdset levels in the order regtab's columns use
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_cmdsets: the collection's cmdset levels in column order
* =============================================================================
* Usage: _regtab_cmdsets
* collect levelsof lists levels in string order ("1 10 11 2 ..."); the
* renderer (_tt_collect_dim_locals in _tabtools_collect_render) orders a
* purely numeric dimension numerically, and leaves .m (a total) out. Column m
* of the table is the m-th level of that order, so anything matched to a
* model by its cmdset reads the levels from here. Returns _cs_levels in the
* caller.
capture program drop _regtab_cmdsets
program define _regtab_cmdsets, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		quietly collect levelsof cmdset
		local _lv `"`s(levels)'"'
		local _ord ""
		local _num = 1
		foreach _l of local _lv {
			if "`_l'" == ".m" continue
			local _ord "`_ord' `_l'"
			if missing(real("`_l'")) local _num = 0
		}
		if `_num' & `"`_ord'"' != "" {
			mata: st_local("_ord", invtokens(strofreal(sort(strtoreal(tokens(st_local("_ord")))', 1)', "%21.0g")))
		}
		local _ord = strtrim(`"`_ord'"')
		c_local _cs_levels `"`_ord'"'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
