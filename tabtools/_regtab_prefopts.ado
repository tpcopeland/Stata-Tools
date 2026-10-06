*! _regtab_prefopts Version 2.5.1  2026/10/06
*! display options given to an estimation prefix
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_prefopts: display options given to an estimation prefix
* =============================================================================
* Usage: _regtab_prefopts `"<prefix option text>"'
* Returns in the caller _rp_eform (1 when the text carries an eform option:
* or, hr, shr, irr, rrr, tr, eform, or eform(string)) and _rp_level (the
* level() value, or -1). Text that -syntax- cannot parse returns 0 and -1.
capture program drop _regtab_prefopts
program define _regtab_prefopts, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _rp_text 0 : 0
		local _rp_e 0
		local _rp_l = -1
		local 0 `", `_rp_text'"'
		capture syntax [, OR HR SHR IRR RRR TR EFORM Level(string) *]
		if _rc == 0 {
			if "`or'`hr'`shr'`irr'`rrr'`tr'`eform'" != "" local _rp_e 1
			if regexm(lower(`" `options'"'), "[ ]eform[(]") local _rp_e 1
			if `"`level'"' != "" {
				local _rp_l = real(`"`level'"')
				if missing(`_rp_l') local _rp_l = -1
			}
		}
		c_local _rp_eform `_rp_e'
		c_local _rp_level `_rp_l'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
