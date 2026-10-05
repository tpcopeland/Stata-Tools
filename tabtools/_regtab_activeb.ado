*! _regtab_activeb Version 2.4.0  2026/10/05
*! b. and o. markers of a collected model that is the active fit
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_activeb: factor markers from the active e(b), when it is the model
* =============================================================================
* Usage: _regtab_activeb <cmdset level> `"<command line>"'
* The collection keeps no b./o. markers. When the active estimation results
* are exactly the collected model - the same command line, and every e(b)
* coefficient the collection also holds equal to its collected _r_b (or its
* exponent) to reldif < 1e-12, the identity tabtools fitcount checks - its
* e(b) column stripe is the fit's own record. Returns in the caller:
*   _ab_ok    1 when the active fit is the model, else 0 (nothing else set)
*   _ab_base  main-effect factor keys e(b) marks b. (1b.x -> 1.x)
*   _ab_omit  main-effect factor keys e(b) marks o. (3o.x -> 3.x)
capture program drop _regtab_activeb
program define _regtab_activeb, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken _k 0 : 0
	gettoken _cl 0 : 0
	local _ok = 0
	local _base ""
	local _omit ""
	capture noisily {
		capture confirm matrix e(b)
		local _hasb = !_rc
		if `_hasb' & `"`e(cmdline)'"' == `"`_cl'"' & `"`_cl'"' != "" {
			tempfile _cjf
			local _cjs `"`_cjf'.stjson"'
			quietly collect save `"`_cjs'"', replace
			mata: _rt_ab_L = cat(st_local("_cjs"))
			mata: _rt_ab_h = selectindex(ustrregexm(_rt_ab_L, `"[#"]cmdset\[`_k'\][#"]"') :& ustrregexm(_rt_ab_L, `"[#"]result\[_r_b\][#"]"'))
			mata: _rt_ab_kk = _rt_ab_L[_rt_ab_h]
			mata: _rt_ab_d = rows(_rt_ab_h) ? strtoreal(ustrregexra(_rt_ab_L[_rt_ab_h :+ 1], `"^\s*"d":\s*([^,]*),?\s*$"', "$1")) : J(0, 1, .)
			mata: _rt_ab_ce = ustrregexra(_rt_ab_kk, `"^.*[#"]coleq\[([^\]]*)\][#"].*$"', "$1") :* ustrregexm(_rt_ab_kk, `"[#"]coleq\["')
			mata: _rt_ab_cn = ustrregexra(_rt_ab_kk, `"^.*?[#"]colname\[(.+?)\][#"].*$"', "$1")
			mata: _rt_ab_s = st_matrixcolstripe("e(b)")
			mata: _rt_ab_b = st_matrix("e(b)")'
			mata: _rt_ab_bn = ustrregexra(ustrregexra(_rt_ab_s[., 2], "(^|#)([0-9]+)[a-z]+\.", "$1$2."), "(^|#)c\.", "$1")
			mata: _rt_ab_q = all((_rt_ab_s[., 1] :== "") :| (_rt_ab_s[., 1] :== "_"))
			mata: _rt_ab_bk = _rt_ab_q ? _rt_ab_bn : (_rt_ab_s[., 1] :+ ":" :+ _rt_ab_bn)
			mata: _rt_ab_ck = _rt_ab_q ? _rt_ab_cn : (_rt_ab_ce :+ ":" :+ _rt_ab_cn)
			mata: _rt_ab_m = 0; _rt_ab_x = 0
			mata: for (_rt_ab_j = 1; _rt_ab_j <= rows(_rt_ab_bk); _rt_ab_j++) { _rt_ab_i = selectindex(_rt_ab_ck :== _rt_ab_bk[_rt_ab_j]); if (rows(_rt_ab_i) != 1) continue; if (missing(_rt_ab_d[_rt_ab_i])) continue; _rt_ab_m++; if (!(reldif(_rt_ab_d[_rt_ab_i], _rt_ab_b[_rt_ab_j]) < 1e-12 | reldif(_rt_ab_d[_rt_ab_i], exp(_rt_ab_b[_rt_ab_j])) < 1e-12)) _rt_ab_x++; }
			mata: st_local("_m", strofreal(_rt_ab_m)); st_local("_x", strofreal(_rt_ab_x))
			mata: st_local("_names", invtokens(_rt_ab_s[., 2]'))
			capture mata: mata drop _rt_ab_*
			capture erase `"`_cjs'"'
			if `_m' > 0 & `_x' == 0 {
				local _ok = 1
				foreach _nm of local _names {
					if !ustrregexm(`"`_nm'"', "^([0-9]+)([a-z]+)\.([A-Za-z_][A-Za-z0-9_]*)$") continue
					local _key = ustrregexs(1) + "." + ustrregexs(3)
					local _op = ustrregexs(2)
					if strpos("`_op'", "o") local _omit : list _omit | _key
					else if strpos("`_op'", "b") & !strpos("`_op'", "n") local _base : list _base | _key
				}
			}
		}
		c_local _ab_ok `_ok'
		c_local _ab_base `"`_base'"'
		c_local _ab_omit `"`_omit'"'
	}
	local _rc = _rc
	capture mata: mata drop _rt_ab_*
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
