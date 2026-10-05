*! _regtab_frameopts Version 2.5.0  2026/10/06
*! parse and check frame() and eplotframe()
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_frameopts: parse and check frame() and eplotframe()
* =============================================================================
* Usage: _regtab_frameopts `"<eplotframe>"' `"<frame>"'
* Returns _eplotframe_name, _eplotframe_replace, _displayframe_name,
* _displayframe_replace, _displayframe_flat, and _displayframe_keys in the
* caller.
capture program drop _regtab_frameopts
program define _regtab_frameopts, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken eplotframe 0 : 0
	gettoken frame 0 : 0
	capture noisily {

	local _eplotframe_name ""
	local _eplotframe_replace 0
		if `"`eplotframe'"' != "" {
	    local _ep_spec = subinstr(strtrim(`"`eplotframe'"'), char(34), "", .)
	    gettoken _eplotframe_name _ep_rest : _ep_spec, parse(",")
	    local _eplotframe_name = strtrim(`"`_eplotframe_name'"')
	    if `"`_eplotframe_name'"' == "" {
	        noisily display as error "eplotframe() requires a frame name"
	        exit 198
	    }
	    capture confirm name `_eplotframe_name'
	    if _rc {
	        noisily display as error "eplotframe() must start with a valid Stata frame name"
	        exit 198
	    }
	    local _ep_rest : subinstr local _ep_rest "," "", all
	    local _ep_rest = lower(strtrim(`"`_ep_rest'"'))
	    if `"`_ep_rest'"' != "" {
	        if `"`_ep_rest'"' == "replace" {
	            local _eplotframe_replace 1
	        }
	        else {
	            noisily display as error "eplotframe() only allows the replace suboption"
	            exit 198
	        }
		    }
		}
		local _displayframe_name ""
		local _displayframe_replace 0
		local _displayframe_flat 0
		local _displayframe_keys 0
		if `"`frame'"' != "" {
			local _fr_spec = subinstr(strtrim(`"`frame'"'), char(34), "", .)
			gettoken _displayframe_name _fr_rest : _fr_spec, parse(",")
			local _displayframe_name = strtrim(`"`_displayframe_name'"')
			local _fr_rest : subinstr local _fr_rest "," "", all
			local _fr_rest = lower(strtrim(`"`_fr_rest'"'))
			capture confirm name `_displayframe_name'
			if _rc {
				noisily display as error "frame() must start with a valid Stata frame name"
				exit 198
			}
			* Suboptions replace, flat, and keys, in any order. flat writes one
			* row per body line with the printed headers as variable labels;
			* keys adds the key variables (_order, _term, _rowtype, _state#)
			* to a flat frame.
			foreach _fr_w of local _fr_rest {
				if `"`_fr_w'"' == "replace" local _displayframe_replace 1
				else if `"`_fr_w'"' == "flat" local _displayframe_flat 1
				else if `"`_fr_w'"' == "keys" local _displayframe_keys 1
				else {
					noisily display as error "frame() only allows the replace, flat, and keys suboptions"
					exit 198
				}
			}
			if `_displayframe_keys' & !`_displayframe_flat' {
				noisily display as error "frame(): keys requires flat, as in frame(`_displayframe_name', flat keys)"
				exit 198
			}
		}
		if `"`_displayframe_name'"' != "" & ///
			`"`_eplotframe_name'"' != "" & ///
			`"`_displayframe_name'"' == `"`_eplotframe_name'"' {
			noisily display as error "frame() and eplotframe() must name different frames"
			exit 198
		}
		foreach _dest in _displayframe_name _eplotframe_name {
			if `"``_dest''"' != "" & ///
				`"``_dest''"' == `"`c(frame)'"' {
				noisily display as error "output frames cannot replace the current frame"
				exit 198
			}
		}
		if `"`_displayframe_name'"' != "" {
			capture confirm frame `_displayframe_name'
			if !_rc & !`_displayframe_replace' {
				noisily display as error "frame `_displayframe_name' already exists; specify frame(`_displayframe_name', replace)"
				exit 110
			}
		}
		if `"`_eplotframe_name'"' != "" {
			capture confirm frame `_eplotframe_name'
			if !_rc & !`_eplotframe_replace' {
				noisily display as error "frame `_eplotframe_name' already exists; specify eplotframe(`_eplotframe_name', replace)"
				exit 110
			}
		}
		c_local _eplotframe_name `"`_eplotframe_name'"'
		c_local _eplotframe_replace `_eplotframe_replace'
		c_local _displayframe_name `"`_displayframe_name'"'
		c_local _displayframe_replace `_displayframe_replace'
		c_local _displayframe_flat `_displayframe_flat'
		c_local _displayframe_keys `_displayframe_keys'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
