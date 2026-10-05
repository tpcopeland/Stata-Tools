*! _regtab_statspec Version 2.4.0  2026/10/05
*! parse stats() e(name) items and statlabels()
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_statspec: parse stats() e(name) items and statlabels()
* =============================================================================
* Usage: _regtab_statspec `"<stats>"' `"<statlabels>"' `"<exposurelabel>"'
* stats(): generic items e(name) or e(name)="label" (also =`"label"'), with
* options e(name, %fmt mincell(#)) and a pair e(name1|name2), and text rows
* text("label" value ...), are taken out of stats(), before any code reads
* stats() as plain words; each becomes its own row, in the order given, after
* the built-in rows.
* statlabels(): key "label" pairs relabelling built-in stats() rows.
* Returns in the caller: stats (the built-in words), _cst_n and per item #:
* _cst_kind_# (e or text), _cst_nm_#, _cst_nm2_# (the pair's second name),
* _cst_lb_#, _cst_fmt_#, _cst_mc_# (0: no mincell), _cst_tn_# and _cst_tv_#_j
* (text values); _stl_<key> for every built-in key, and exposurelabel.
capture program drop _regtab_statspec
program define _regtab_statspec, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken stats 0 : 0
	gettoken statlabels 0 : 0
	gettoken exposurelabel 0 : 0
	capture noisily {
		* stats() and statlabels() are asis: a list quoted whole is unquoted
		foreach _o in stats statlabels {
			gettoken _t _r : `_o', quotes
			if `"`_r'"' == "" gettoken `_o' : `_o'
		}
		* Generic items, in the order given: e(name[, opts])[="label"] and
		* text("label" value1 value2 ...). opts: a display format, as a bare
		* %fmt or fmt(%fmt), and mincell(#). e(a|b) is one row "a (b)".
		local _cst_n = 0
		local _cst_re "(e\((?:[^()]|\([^()]*\))*\)(?:\s*=\s*(?:\x60\x22.*?\x22'|\x22[^\x22]*\x22))?|text\((?:\x22[^\x22]*\x22|\x60\x22.*?\x22'|[^()\x22\x60])*\))"
		local _cst_ere "^e\(((?:[^()]|\([^()]*\))*)\)(?:\s*=\s*(?:\x60\x22(.*?)\x22'|\x22([^\x22]*)\x22))?$"
		local _cst_keys ""
		while ustrregexm(`"`macval(stats)'"', "`_cst_re'") {
			local _cst_all = ustrregexs(0)
			local stats = subinstr(`"`macval(stats)'"', `"`macval(_cst_all)'"', " ", 1)
			local ++_cst_n
			local _k = `_cst_n'
			foreach _x in kind nm nm2 lb fmt {
				local _cst_`_x'_`_k' ""
			}
			local _cst_mc_`_k' = 0
			local _cst_tn_`_k' = 0
			if substr(`"`macval(_cst_all)'"', 1, 5) == "text(" {
				local _cst_kind_`_k' "text"
				local _in = substr(`"`macval(_cst_all)'"', 6, strlen(`"`macval(_cst_all)'"') - 6)
				* gettoken takes one layer of quotes ("" or compound) off
				gettoken _lb _in : _in
				local _cst_lb_`_k' : copy local _lb
				if `"`macval(_cst_lb_`_k')'"' == "" {
					display as error "stats(): text() needs a row label, as in text(" _char(34) "Weighting" _char(34) " " _char(34) "None" _char(34) " " _char(34) "IPW" _char(34) ")"
					exit 198
				}
				local _in = strtrim(`"`macval(_in)'"')
				while `"`macval(_in)'"' != "" {
					gettoken _v _in : _in
					local ++_cst_tn_`_k'
					local _cst_tv_`_k'_`_cst_tn_`_k'' : copy local _v
					local _in = strtrim(`"`macval(_in)'"')
				}
				continue
			}
			local _cst_kind_`_k' "e"
			if !ustrregexm(`"`macval(_cst_all)'"', "`_cst_ere'") {
				display as error `"stats(): could not read `macval(_cst_all)'"'
				exit 198
			}
			local _in = ustrregexs(1)
			local _cst_lb_`_k' = ustrregexs(2) + ustrregexs(3)
			local _cm = strpos(`"`_in'"', ",")
			local _nms `"`_in'"'
			local _opts ""
			if `_cm' > 0 {
				local _nms = substr(`"`_in'"', 1, `_cm' - 1)
				local _opts = strtrim(substr(`"`_in'"', `_cm' + 1, .))
			}
			local _nms = strtrim(`"`_nms'"')
			if !ustrregexm(`"`_nms'"', "^([A-Za-z_][A-Za-z0-9_]*)(?:\s*\|\s*([A-Za-z_][A-Za-z0-9_]*))?$") {
				display as error `"stats(): `macval(_cst_all)': give e(name) or e(name1|name2)"'
				exit 198
			}
			local _cst_nm_`_k' = ustrregexs(1)
			local _cst_nm2_`_k' = ustrregexs(2)
			if `"`_cst_lb_`_k''"' == "" {
				local _cst_lb_`_k' "`_cst_nm_`_k''"
				if "`_cst_nm2_`_k''" != "" local _cst_lb_`_k' "`_cst_nm_`_k'' (`_cst_nm2_`_k'')"
			}
			local _key "`_cst_nm_`_k''|`_cst_nm2_`_k''"
			local _dup : list _key in _cst_keys
			if `_dup' {
				display as error "stats(): e(`_cst_nm_`_k''`=cond("`_cst_nm2_`_k''" != "", "|`_cst_nm2_`_k''", "")') is requested more than once"
				exit 198
			}
			local _cst_keys "`_cst_keys' `_key'"
			* options: a bare %fmt first, then fmt(%fmt) and mincell(#)
			if substr(`"`_opts'"', 1, 1) == "%" {
				gettoken _cst_fmt_`_k' _opts : _opts, parse(" ")
				local _opts = strtrim(`"`_opts'"')
			}
			if `"`_opts'"' != "" {
				local 0 `", `_opts'"'
				capture syntax , [Fmt(string) MINCell(integer 0)]
				if _rc {
					display as error `"stats(): e(`_nms', `_opts'): the options are a display format (%9.0fc or fmt(%9.0fc)) and mincell(#)"'
					exit 198
				}
				if `"`fmt'"' != "" {
					if "`_cst_fmt_`_k''" != "" {
						display as error `"stats(): e(`_nms'): give one display format"'
						exit 198
					}
					local _cst_fmt_`_k' `"`fmt'"'
				}
				local _cst_mc_`_k' = `mincell'
				if `mincell' != 0 & `mincell' < 2 {
					display as error "stats(): e(`_nms'): mincell() must be an integer of 2 or more"
					exit 198
				}
			}
			if "`_cst_fmt_`_k''" != "" {
				local _cst_fmt_`_k' = strtrim("`_cst_fmt_`_k''")
				capture confirm numeric format `_cst_fmt_`_k''
				if _rc | !ustrregexm("`_cst_fmt_`_k''", "^%-?0?[0-9]*[.,][0-9]+[fge]c?$") {
					display as error "stats(): e(`_nms'): `_cst_fmt_`_k'' is not a numeric display format such as %9.0fc or %6.3f"
					exit 198
				}
			}
		}
		if ustrregexm(`"`macval(stats)'"', "[\x22\x60=()]") {
			display as error `"stats(): could not read `macval(stats)'"'
			display as error `"  give built-in statistics as words and others as e(name) or e(name)="label""'
			exit 198
		}
		local stats = strtrim(`"`stats'"')

		local _stl_keys "n obs events people exposure groups mi_m aic qic bic ll icc r2 r2_a rmse f fmi"
		foreach _k of local _stl_keys {
			local _stl_`_k' ""
		}
		if `"`macval(statlabels)'"' != "" {
			local _stl_rest `"`macval(statlabels)'"'
			local _stl_sl = " " + strlower("`stats'") + " "
			foreach _al in n_sub subjects {
				local _stl_sl : subinstr local _stl_sl " `_al' " " n ", all
			}
			local _stl_sl : subinstr local _stl_sl " r-squared " " r2 ", all
			while `"`macval(_stl_rest)'"' != "" {
				gettoken _stl_k _stl_rest : _stl_rest
				local _stl_rest = strtrim(`"`macval(_stl_rest)'"')
				if `"`macval(_stl_rest)'"' == "" {
					display as error `"statlabels(): `_stl_k' has no label; give statlabels(stat "label" [stat "label" ...])"'
					exit 198
				}
				gettoken _stl_l _stl_rest : _stl_rest
				local _stl_k = strlower(`"`_stl_k'"')
				local _stl_ok : list _stl_k in _stl_keys
				if !`_stl_ok' {
					display as error `"statlabels(): `_stl_k' is not a built-in statistic (`_stl_keys')"'
					exit 198
				}
				if !strpos("`_stl_sl'", " `_stl_k' ") {
					display as error `"statlabels(): `_stl_k' is not requested in stats()"'
					exit 198
				}
				local _stl_`_stl_k' `"`macval(_stl_l)'"'
				local _stl_rest = strtrim(`"`macval(_stl_rest)'"')
			}
			if `"`macval(_stl_exposure)'"' != "" & `"`macval(exposurelabel)'"' != "" {
				display as error "exposurelabel() and statlabels(exposure ...) cannot both be specified"
				exit 198
			}
			if `"`macval(_stl_exposure)'"' != "" {
				local exposurelabel `"`macval(_stl_exposure)'"'
			}
		}
		c_local stats `"`stats'"'
		c_local exposurelabel `"`macval(exposurelabel)'"'
		c_local _cst_n `_cst_n'
		forvalues _k = 1/`_cst_n' {
			foreach _x in kind nm nm2 fmt mc tn {
				c_local _cst_`_x'_`_k' "`_cst_`_x'_`_k''"
			}
			c_local _cst_lb_`_k' `"`macval(_cst_lb_`_k')'"'
			forvalues _j = 1/`_cst_tn_`_k'' {
				c_local _cst_tv_`_k'_`_j' `"`macval(_cst_tv_`_k'_`_j')'"'
			}
		}
		foreach _k of local _stl_keys {
			c_local _stl_`_k' `"`macval(_stl_`_k')'"'
		}
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
