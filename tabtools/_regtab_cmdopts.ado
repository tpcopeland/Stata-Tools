*! _regtab_cmdopts Version 2.6.0  2026/10/08
*! parse option text with the estimator's own abbreviations
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_cmdopts: parse option text with the estimator's own abbreviations
* =============================================================================
* Usage: _regtab_cmdopts "<syntax option spec>" `"<option text>"'
* Runs -syntax- on the option text so abbreviations resolve exactly as the
* estimator resolves them (glm's EForm accepts ef/efo/efor/eform; Family() and
* Link() accept f()/l()). Every declared option is returned in the caller as
* local _ro_<name>, where <name> is the local -syntax- creates (noHR -> hr),
* empty when the option is absent or the text cannot be parsed.
capture program drop _regtab_cmdopts
program define _regtab_cmdopts, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _ro_spec 0 : 0
		gettoken _ro_text 0 : 0
		local _ro_names ""
		foreach _ro_w of local _ro_spec {
			local _ro_nm = lower(regexr(`"`_ro_w'"', "\(.*$", ""))
			if substr(`"`_ro_w'"', 1, 2) == "no" & ///
				regexm(substr(`"`_ro_w'"', 3, 1), "[A-Z]") {
				local _ro_nm = substr(`"`_ro_nm'"', 3, .)
			}
			local _ro_names `_ro_names' `_ro_nm'
		}
		local 0 `", `_ro_text'"'
		capture syntax [, `_ro_spec' *]
		local _ro_ok = (_rc == 0)
		foreach _ro_nm of local _ro_names {
			if !`_ro_ok' local `_ro_nm' ""
			c_local _ro_`_ro_nm' `"``_ro_nm''"'
		}
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
