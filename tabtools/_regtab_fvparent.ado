*! _regtab_fvparent Version 2.5.2  2026/10/06
*! factor parent of a raw colname key
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_fvparent: factor parent of a raw colname key
* =============================================================================
* Mirrors the renderer's _tt_collect_factor_parent: "2.sex" -> "sex",
* "1.grp#c.x" -> "grp#x". No factor component, or a level that is its own
* parent, returns an empty _fp_parent in the caller.
capture program drop _regtab_fvparent
program define _regtab_fvparent, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _fp_key 0 : 0
		local _fp_this ""
		if strpos(`"`_fp_key'"', ".") > 0 {
			local _fp_hasfv 0
			local _fp_bad 0
			local _fp_parts = subinstr(`"`_fp_key'"', "#", " ", .)
			local _fp_i 0
			foreach _fp_p of local _fp_parts {
				local ++_fp_i
				local _fp_dot = strpos(`"`_fp_p'"', ".")
				if `_fp_dot' > 1 & ///
					regexm(substr(`"`_fp_p'"', 1, `_fp_dot' - 1), "^[0-9bon]*[0-9][0-9bon]*$") {
					local _fp_p = substr(`"`_fp_p'"', `_fp_dot' + 1, .)
					local _fp_hasfv 1
				}
				else if `_fp_dot' == 2 & substr(`"`_fp_p'"', 1, 1) == "c" {
					local _fp_p = substr(`"`_fp_p'"', 3, .)
				}
				if `"`_fp_p'"' == "" local _fp_bad 1
				if `_fp_i' == 1 local _fp_this `"`_fp_p'"'
				else local _fp_this `"`_fp_this'#`_fp_p'"'
			}
			if `_fp_bad' | !`_fp_hasfv' | `"`_fp_this'"' == `"`_fp_key'"' local _fp_this ""
		}
		c_local _fp_parent `"`_fp_this'"'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
