*! _regtab_fvbase Version 2.5.0  2026/10/06
*! base levels of a model's factor variables, from its own specification
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_fvbase: base levels of a model's factor variables
* =============================================================================
* Usage: _regtab_fvbase `"<command line>"' `"<keys>"' <varabbrev>
* <varabbrev> is the caller's own setting: e(cmdline) is expanded under it,
* so a varlist the user typed with abbreviations still expands.
* <keys> are the main-effect factor-level keys the model holds in the
* collection ("0.drug 1.drug 1.rep78 ..."). Returns, in the caller:
*   _fvb_vars  the factor variables whose base level was decided
*   _fvb_keys  the keys of those factors that are the model's base level
*   _fvb_soft  the factors whose base came from fvset (char _fv_base), not
*              from the command line: fvset may postdate the fit
* regtab asks only for a model whose classes collect could not record: Stata
* 17 stamps every constrained cell of nbreg, zinb, intreg, and some streg fits
* "empty", so their base level and a level dropped as collinear look alike,
* and both used to read "Reference". The base follows
* Stata's own rule instead: the model's varlist, as typed in e(cmdline), is
* expanded with fvexpand over the observations holding the levels the model
* holds, so the default (lowest level), ib#., ib(first|last)., ibn., and
* fvset base all resolve as they did at fit time; the level fvexpand marks
* "b." is the base. A factor is left undecided (absent from _fvb_vars, so the
* caller keeps collect's classes) when the varlist cannot be expanded on the
* data in memory, when its base depends on frequencies in the estimation
* sample (ib(freq)., fvset base frequent), when the model holds fewer than two
* of its levels, or when the expansion names no single base among them.
program define _regtab_fvbase, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _cl 0 : 0
		gettoken _keys 0 : 0
		gettoken _vab 0 : 0
		if !inlist("`_vab'", "on", "off") local _vab "off"
		local _vars_out ""
		local _soft_out ""
		local _keys_out ""
		* varlist: up to "||" (mixed-model random parts), if, in, weights, or
		* the options; after any prefix ("svy:", "bootstrap, ...:"); without
		* the command word
		local _vl `"`_cl'"'
		foreach _cut in "||" " if " " in " "[" "," {
			local _p = strpos(`"`_vl'"', "`_cut'")
			if `_p' > 0 local _vl = substr(`"`_vl'"', 1, `_p' - 1)
		}
		local _p = strrpos(`"`_vl'"', ":")
		if `_p' > 0 local _vl = substr(`"`_vl'"', `_p' + 1, .)
		gettoken _cmd _vl : _vl
		local _vl = strtrim(`"`_vl'"')
		if `"`_vl'"' != "" & !strpos(`"`_vl'"', "freq") {
			* the factor variables this model holds levels of
			local _fvs ""
			foreach _k of local _keys {
				if ustrregexm(`"`_k'"', "^[0-9]+\.([A-Za-z_][A-Za-z0-9_]*)$") {
					local _fv = ustrregexs(1)
					local _fvs : list _fvs | _fv
				}
			}
			* each factor operator as typed, with its variable resolved under
			* the user's varabbrev: which factors name their base in the command
			* line itself (ib#., ib(last).); fvunab would fold fvset in
			local _vu ""
			local _vp = subinstr(`"`_vl'"', "#", " ", .)
			foreach _pt of local _vp {
				if !ustrregexm(`"`_pt'"', "^([^.]*)\.([A-Za-z_][A-Za-z0-9_]*)$") continue
				local _op = ustrregexs(1)
				local _nm = ustrregexs(2)
				if !strpos("`_op'", "b") continue
				set varabbrev `_vab'
				capture unab _nm : `_nm'
				local _urc = _rc
				set varabbrev off
				if !`_urc' local _vu "`_vu' `_nm'"
			}
			foreach _fv of local _fvs {
				local _levs ""
				foreach _k of local _keys {
					if ustrregexm(`"`_k'"', "^([0-9]+)\.`_fv'$") {
						local _levs `"`_levs' `=ustrregexs(1)'"'
					}
				}
				capture confirm numeric variable `_fv', exact
				if _rc continue
				local _fvb : char `_fv'[_fv_base]
				if strpos(`"`_fvb'"', "freq") continue
				if `: word count `_levs'' < 2 continue
				tempvar _in
				quietly generate byte `_in' = 0
				foreach _lv of local _levs {
					quietly replace `_in' = 1 if `_fv' == `_lv'
				}
				set varabbrev `_vab'
				capture fvexpand `_vl' if `_in'
				local _xrc = _rc
				set varabbrev off
				local _xl `"`r(varlist)'"'
				drop `_in'
				if `_xrc' continue
				local _main = 0
				local _base ""
				foreach _t of local _xl {
					if !ustrregexm(`"`_t'"', "^([0-9]+)([a-z]*)\.`_fv'$") continue
					local _lv = ustrregexs(1)
					local _op = ustrregexs(2)
					local _held : list _lv in _levs
					if !`_held' continue
					local ++_main
					if "`_op'" == "b" local _base "`_base' `_lv'.`_fv'"
				}
				if `_main' == 0 | `: word count `_base'' > 1 continue
				local _vars_out "`_vars_out' `_fv'"
				local _keys_out "`_keys_out'`_base'"
				* a base from fvset (char _fv_base) and not from the command
				* line may have been set after the fit
				local _expl : list _fv in _vu
				if `"`_fvb'"' != "" & !`_expl' local _soft_out "`_soft_out' `_fv'"
			}
		}
		local _vars_out = strtrim("`_vars_out'")
		local _keys_out = strtrim("`_keys_out'")
		c_local _fvb_vars "`_vars_out'"
		c_local _fvb_keys "`_keys_out'"
		local _soft_out = strtrim("`_soft_out'")
		c_local _fvb_soft "`_soft_out'"
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
