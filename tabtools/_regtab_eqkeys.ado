*! _regtab_eqkeys Version 2.6.2  2026/10/10
*! equation key of every row of a coleq#colname rendering
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_eqkeys: equation key of every row of a coleq#colname rendering
* =============================================================================
* The renderer marks an equation's header row with an empty raw key and prints
* its label; headers appear in the order of the coleq levels, one per level
* with data. Walking that order maps each header back to its level (so a
* dependent variable labelled "/" is never read as the ancillary equation),
* and every row below it inherits the level in _eq_key.
capture program drop _regtab_eqkeys
program define _regtab_eqkeys, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		* Same level order and labels as the renderer's dimension helper:
		* collect's level order, purely numeric levels sorted numerically,
		* the .m total level last, and a level's label defaulting to itself.
		quietly collect levelsof coleq
		local _levels `"`s(levels)'"'
		local _ord ""
		local _tot ""
		local _allnum = 1
		foreach _lev of local _levels {
			if "`_lev'" == ".m" local _tot "`_tot' `_lev'"
			else {
				local _ord "`_ord' `_lev'"
				if missing(real("`_lev'")) local _allnum = 0
			}
		}
		if `_allnum' & "`_ord'" != "" {
			* sorted on the numeric value, the level strings themselves kept
			* (never rebuilt from a number): the order is a permutation
			mata: _rg_s = tokens(st_local("_ord"))'; st_local("_ord", invtokens((_rg_s[order((strtoreal(_rg_s), (1::rows(_rg_s))), (1, 2))])'))
			capture mata: mata drop _rg_s
		}
		local _levels = strtrim("`_ord' `_tot'")
		local _lk = 0
		capture quietly collect label list coleq
		if _rc == 0 {
			local _lk = real("`s(k)'")
			if missing(`_lk') local _lk = 0
			forvalues _i = 1/`_lk' {
				local _mlev_`_i' `"`s(level`_i')'"'
				local _mlab_`_i' `"`s(label`_i')'"'
			}
		}
		local _en : word count `_levels'
		forvalues _e = 1/`_en' {
			local _elev_`_e' : word `_e' of `_levels'
			local _elab_`_e' `"`_elev_`_e''"'
			forvalues _i = 1/`_lk' {
				if `"`_mlev_`_i''"' == `"`_elev_`_e''"' local _elab_`_e' `"`_mlab_`_i''"'
			}
			local _elab_`_e' = strtrim(`"`_elab_`_e''"')
		}
		quietly generate strL _eq_key = ""
		local _ep = 0
		local _cur ""
		forvalues _r = 3/`=_N' {
			if strtrim(_raw_colname[`_r']) == "" {
				local _hl = strtrim(A[`_r'])
				local _found = 0
				forvalues _e = `=`_ep'+1'/`_en' {
					if `"`_elab_`_e''"' == `"`_hl'"' {
						local _ep = `_e'
						local _cur `"`_elev_`_e''"'
						local _found = 1
						continue, break
					}
				}
				if !`_found' {
					display as error `"equation header "`_hl'" does not match a collected equation"'
					exit 459
				}
			}
			quietly replace _eq_key = `"`_cur'"' in `_r'
		}
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
