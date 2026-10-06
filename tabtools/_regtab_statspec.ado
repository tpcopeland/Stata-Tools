*! _regtab_statspec Version 2.5.3  2026/10/06
*! parse stats() e(name) items and statlabels()
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_statspec: parse stats() e(name) items and statlabels()
* =============================================================================
* Usage: _regtab_statspec `"<stats>"' `"<statlabels>"' `"<exposurelabel>"'
* stats(): generic items e(name) or e(name)="label" (also =`"label"'), with
* options e(name, %fmt mincell(#) maskwith(names)) and a pair e(name1|name2),
* and text rows text("label" value ...), are taken out of stats(), before any
* code reads stats() as plain words; each becomes its own row, in the order
* given, after the built-in rows.
* maskwith(names): the item's own names and the names listed (other e()
* names in stats()) are masked together: in a model where one of them prints
* <# under its mincell(), the others print the withheld text. Links close
* transitively into groups; a pair's two parts are linked only through
* maskwith().
* statlabels(): key "label" pairs relabelling built-in stats() rows.
* Returns in the caller: stats (the built-in words), _cst_n and per item #:
* _cst_kind_# (e or text), _cst_nm_#, _cst_nm2_# (the pair's second name),
* _cst_lb_#, _cst_fmt_#, _cst_mc_# and _cst_mc2_# (the mincell() of the
* first and second name, 0: none; a name in several items takes the
* strictest mincell() any of them gives it), _cst_g_# and _cst_g2_#
* (mask group of the first and second name, 0: none), _cst_tn_# and
* _cst_tv_#_j (text values); _cst_anylink (1 when any maskwith() was given);
* _stl_<key> for every built-in key, and exposurelabel.
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
		* every e() name, for maskwith()
		local _cst_allnm ""
		local _cst_anylink = 0
		while ustrregexm(`"`macval(stats)'"', "`_cst_re'") {
			local _cst_all = ustrregexs(0)
			local stats = subinstr(`"`macval(stats)'"', `"`macval(_cst_all)'"', " ", 1)
			local ++_cst_n
			local _k = `_cst_n'
			foreach _x in kind nm nm2 lb fmt mw {
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
			local _cst_allnm : list _cst_allnm | _cst_nm_`_k'
			if "`_cst_nm2_`_k''" != "" local _cst_allnm : list _cst_allnm | _cst_nm2_`_k'
			* options: a bare %fmt first, then fmt(%fmt), mincell(#) and
			* maskwith(names)
			if substr(`"`_opts'"', 1, 1) == "%" {
				gettoken _cst_fmt_`_k' _opts : _opts, parse(" ")
				local _opts = strtrim(`"`_opts'"')
			}
			if `"`_opts'"' != "" {
				local 0 `", `_opts'"'
				local maskwith ""
				capture syntax , [Fmt(string) MINCell(integer 0) MASKwith(string)]
				if _rc {
					display as error `"stats(): e(`_nms', `_opts'): the options are a display format (%9.0fc or fmt(%9.0fc)), mincell(#) and maskwith(names)"'
					exit 198
				}
				local maskwith = strtrim(`"`maskwith'"')
				if `"`maskwith'"' != "" {
					foreach _mw of local maskwith {
						if !ustrregexm(`"`_mw'"', "^[A-Za-z_][A-Za-z0-9_]*$") {
							display as error `"stats(): e(`_nms'): maskwith(): "`_mw'" is not a name"'
							exit 198
						}
					}
					local _cst_mw_`_k' : list uniq maskwith
					local _cst_anylink = 1
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
		* One statistic, one threshold: a name requested in several items (as
		* e(ev, mincell(5)) and e(ev|tot)) is masked in every row with the
		* strictest mincell() any of them gives it, so no row prints a count
		* another row masks. _cst_mc_# and _cst_mc2_# hold the threshold of
		* the item's first and second name.
		* (_mcn_<i> is indexed by the name's position in _cst_allnm: a name
		* of 32 characters would not fit in a macro name)
		local _nall : word count `_cst_allnm'
		forvalues _i = 1/`_nall' {
			local _mcn_`_i' = 0
		}
		forvalues _k = 1/`_cst_n' {
			if "`_cst_kind_`_k''" != "e" continue
			foreach _s in "" 2 {
				if "`_cst_nm`_s'_`_k''" == "" continue
				local _i : list posof "`_cst_nm`_s'_`_k''" in _cst_allnm
				local _mcn_`_i' = max(`_mcn_`_i'', `_cst_mc_`_k'')
			}
		}
		forvalues _k = 1/`_cst_n' {
			local _cst_mc2_`_k' = 0
			if "`_cst_kind_`_k''" != "e" continue
			if "`_cst_nm2_`_k''" != "" {
				local _i : list posof "`_cst_nm2_`_k''" in _cst_allnm
				local _cst_mc2_`_k' = `_mcn_`_i''
			}
			local _i : list posof "`_cst_nm_`_k''" in _cst_allnm
			local _cst_mc_`_k' = `_mcn_`_i''
		}
		* maskwith(): every name must be an e() item of stats(); the links
		* close into groups (connected components of the declared links).
		* Group ids are the position of the group's first name.
		forvalues _k = 1/`_cst_n' {
			local _cst_g_`_k' = 0
			local _cst_g2_`_k' = 0
		}
		if `_cst_anylink' {
			local _gn : word count `_cst_allnm'
			forvalues _i = 1/`_gn' {
				local _gid_`_i' = 0
			}
			forvalues _k = 1/`_cst_n' {
				if `"`_cst_mw_`_k''"' == "" continue
				foreach _mw of local _cst_mw_`_k' {
					local _ok : list _mw in _cst_allnm
					if !`_ok' {
						display as error "stats(): maskwith(`_mw'): `_mw' is not an e() item in stats()"
						exit 198
					}
				}
				* the set: the item's own names and the names listed
				local _set "`_cst_nm_`_k'' `_cst_nm2_`_k'' `_cst_mw_`_k''"
				local _set : list uniq _set
				* one group: the smallest position among the set and every
				* group a member already belongs to
				local _new = .
				local _old ""
				foreach _mw of local _set {
					local _i : list posof "`_mw'" in _cst_allnm
					local _new = min(`_new', `_i')
					if `_gid_`_i'' > 0 {
						local _new = min(`_new', `_gid_`_i'')
						local _old "`_old' `_gid_`_i''"
					}
				}
				foreach _mw of local _set {
					local _i : list posof "`_mw'" in _cst_allnm
					local _gid_`_i' = `_new'
				}
				forvalues _i = 1/`_gn' {
					local _gi = `_gid_`_i''
					local _hit : list _gi in _old
					if `_gi' > 0 & `_hit' local _gid_`_i' = `_new'
				}
			}
			forvalues _k = 1/`_cst_n' {
				if "`_cst_kind_`_k''" != "e" continue
				local _i : list posof "`_cst_nm_`_k''" in _cst_allnm
				local _cst_g_`_k' = `_gid_`_i''
				if "`_cst_nm2_`_k''" != "" {
					local _i : list posof "`_cst_nm2_`_k''" in _cst_allnm
					local _cst_g2_`_k' = `_gid_`_i''
				}
			}
			* a group none of whose names has a mincell() masks nothing: say so
			local _gseen ""
			forvalues _i = 1/`_gn' {
				local _gi = `_gid_`_i''
				if `_gi' == 0 continue
				local _gdone : list _gi in _gseen
				if `_gdone' continue
				local _gseen "`_gseen' `_gi'"
				local _gnames ""
				local _gmc = 0
				forvalues _j = 1/`_gn' {
					if `_gid_`_j'' != `_gi' continue
					local _nmx : word `_j' of `_cst_allnm'
					local _gnames "`_gnames' `_nmx'"
					local _gmc = max(`_gmc', `_mcn_`_j'')
				}
				if `_gmc' == 0 {
					noisily display as text "(regtab: stats(): no mincell() is given for the maskwith() group`_gnames', so nothing in it is masked)"
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
		c_local _cst_anylink `_cst_anylink'
		forvalues _k = 1/`_cst_n' {
			foreach _x in kind nm nm2 fmt mc mc2 tn g g2 {
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
