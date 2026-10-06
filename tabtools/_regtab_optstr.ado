*! _regtab_optstr Version 2.5.2  2026/10/06
*! display-option text of a collected command line
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_optstr: display-option text of a collected command line
* =============================================================================
* Returns, in the caller's local <target>, the text after the option comma of
* every ||-separated equation. A comma or || inside parentheses or a quoted
* string is not a separator, so a comma in an if() expression cannot start the
* option list, and nothing before the option comma (a covariate literally
* named "or", say) is ever read as an option.
* Estimation prefixes ("svy [vcetype][, opts]:", "bootstrap|bs|bstrap
* [, opts]:", "jackknife|jknife [, opts]:", "mi estimate [, opts]:", nested
* in any order, as e(cmdline) and e(cmdline_mi) record them) are set aside
* first: <target>_line receives the command line after the last prefix colon
* (a colon outside parentheses and quotes), so the caller classifies the
* estimation command and a prefix's options are never read as the command's
* display options. <target>_prefix lists the prefixes found (svy, bootstrap,
* jackknife, mi), and <target>_prefopt holds the option text of the
* bootstrap, jackknife, and mi estimate prefixes (svy's options are not
* display options and are not returned). Any other command line is returned
* unchanged in <target>_line with empty prefix locals.
capture program drop _regtab_optstr
program define _regtab_optstr, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _ro_target 0 : 0
		gettoken _ro_str 0 : 0
		local _ro_prefix ""
		local _ro_prefopt ""
		local _ro_more 1
		while `_ro_more' {
			local _ro_more 0
			local _ro_str = strtrim(`"`_ro_str'"')
			local _ro_lc = lower(`"`_ro_str'"')
			local _ro_pname ""
			if regexm(`"`_ro_lc'"', "^svy([ ,:]|$)") local _ro_pname "svy"
			else if regexm(`"`_ro_lc'"', "^(bootstrap|bstrap|bs)([ ,:]|$)") local _ro_pname "bootstrap"
			else if regexm(`"`_ro_lc'"', "^(jackknife|jknife)([ ,:]|$)") local _ro_pname "jackknife"
			else if regexm(`"`_ro_lc'"', "^mi +est(i|im|ima|imat|imate)?([ ,:]|$)") local _ro_pname "mi"
			if "`_ro_pname'" == "" continue, break
			local _ro_len = strlen(`"`_ro_str'"')
			local _ro_depth 0
			local _ro_inq 0
			local _ro_comma 0
			local _ro_i 1
			while `_ro_i' <= `_ro_len' {
				* 1 quote, 2 (, 3 ), 4 colon, 5 comma, 0 anything else
				local _ro_k = strpos(char(34) + "():,", ///
					substr(`"`_ro_str'"', `_ro_i', 1))
				if `_ro_inq' {
					if `_ro_k' == 1 local _ro_inq 0
				}
				else if `_ro_k' == 1 local _ro_inq 1
				else if `_ro_k' == 2 local ++_ro_depth
				else if `_ro_k' == 3 & `_ro_depth' > 0 local --_ro_depth
				else if `_ro_k' == 5 & `_ro_depth' == 0 & !`_ro_comma' {
					local _ro_comma = `_ro_i'
				}
				else if `_ro_k' == 4 & `_ro_depth' == 0 {
					if "`_ro_pname'" != "svy" & `_ro_comma' > 0 {
						local _ro_prefopt = `"`_ro_prefopt' "' + ///
							substr(`"`_ro_str'"', `_ro_comma' + 1, `_ro_i' - `_ro_comma' - 1)
					}
					local _ro_prefix `"`_ro_prefix' `_ro_pname'"'
					local _ro_str = strtrim(substr(`"`_ro_str'"', `_ro_i' + 1, .))
					local _ro_more 1
					continue, break
				}
				local ++_ro_i
			}
		}
		c_local `_ro_target'_prefix = strtrim(`"`_ro_prefix'"')
		c_local `_ro_target'_prefopt = strtrim(`"`_ro_prefopt'"')
		c_local `_ro_target'_line `"`_ro_str'"'
		local _ro_len = strlen(`"`_ro_str'"')
		local _ro_depth 0
		local _ro_inq 0
		local _ro_inopt 0
		local _ro_start 0
		local _ro_out ""
		local _ro_i 1
		while `_ro_i' <= `_ro_len' {
			local _ro_step 1
			* Character class by position, so a quote character never has to
			* be held in a macro: 1 quote, 2 (, 3 ), 4 comma, 0 anything else.
			local _ro_k = strpos(char(34) + "(),", ///
				substr(`"`_ro_str'"', `_ro_i', 1))
			if `_ro_inq' {
				if `_ro_k' == 1 local _ro_inq 0
			}
			else if `_ro_k' == 1 local _ro_inq 1
			else if `_ro_k' == 2 local ++_ro_depth
			else if `_ro_k' == 3 & `_ro_depth' > 0 local --_ro_depth
			else if `_ro_depth' == 0 & substr(`"`_ro_str'"', `_ro_i', 2) == "||" {
				if `_ro_inopt' {
					local _ro_out = `"`_ro_out' "' + ///
						substr(`"`_ro_str'"', `_ro_start', `_ro_i' - `_ro_start')
				}
				local _ro_inopt 0
				local _ro_step 2
			}
			else if `_ro_depth' == 0 & !`_ro_inopt' & `_ro_k' == 4 {
				local _ro_inopt 1
				local _ro_start = `_ro_i' + 1
			}
			local _ro_i = `_ro_i' + `_ro_step'
		}
		if `_ro_inopt' {
			local _ro_out = `"`_ro_out' "' + substr(`"`_ro_str'"', `_ro_start', .)
		}
		local _ro_out = strtrim(`"`_ro_out'"')
		c_local `_ro_target' `"`_ro_out'"'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
