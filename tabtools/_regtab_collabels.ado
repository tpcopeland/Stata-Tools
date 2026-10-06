*! _regtab_collabels Version 2.5.4  2026/10/06
*! collabels(): column headers of a transposed table, by raw coefficient name
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_collabels: collabels() for a transposed table
* =============================================================================
* Usage: _regtab_collabels `"<spec>"' <multi-equation 0|1>
* <spec> is name "label" [name "label" ...], name a raw coefficient name
* matched exactly and case-sensitively, as keep() matches (mpg, 1.foreign).
* Works on regtab's display dataset before it is transposed: the label
* replaces _tp_lab, the first header of that term's estimate and p-value
* columns, on every row with that raw name (_raw_A). A name that matches no
* row, or a name without a label, is an error (r(198)). In a multi-equation
* table each row reads "eq: label" and keeps its equation; eq:name selects
* one equation, eq as the rows show it.
capture program drop _regtab_collabels
program define _regtab_collabels, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken _cl_rest 0 : 0
	gettoken _cl_meq 0 : 0
	capture noisily {
		_regtab_unwrap `"`macval(_cl_rest)'"'
		local _cl_rest : copy local _uw_spec
		capture drop _cl_nkv
		capture drop _cl_pre
		quietly generate str244 _cl_nkv = ustrregexra(ustrregexra(strtrim(_raw_A), ///
			"(^|#)c\.", "$1"), "(^|#)([0-9]+)[a-z]+\.", "$1$2.")
		* a multi-equation row reads "eq: label": the equation is kept
		quietly generate str244 _cl_pre = ""
		if "`_cl_meq'" == "1" {
			quietly replace _cl_pre = ustrregexs(1) if ustrregexm(_tp_lab, "^(.+?): ")
		}
		local _cl_rest = strtrim(`"`macval(_cl_rest)'"')
		while `"`macval(_cl_rest)'"' != "" {
			gettoken _cl_k _cl_rest : _cl_rest
			local _cl_rest = strtrim(`"`macval(_cl_rest)'"')
			if `"`macval(_cl_rest)'"' == "" {
				display as error `"collabels(): `_cl_k' has no label; give collabels(name "label" [name "label" ...])"'
				exit 198
			}
			gettoken _cl_l _cl_rest : _cl_rest
			local _cl_rest = strtrim(`"`macval(_cl_rest)'"')
			* eq:name selects one equation of a multi-equation table, eq as
			* its rows show it ("4: Mileage (mpg)" is 4:mpg)
			local _cl_eq ""
			if "`_cl_meq'" == "1" & ustrregexm(`"`_cl_k'"', "^(.+):([^:]+)$") {
				local _cl_eq = ustrregexs(1)
				local _cl_k = ustrregexs(2)
			}
			* keep()'s form: c. and level markers (1b.) do not matter
			local _cl_nk = ustrregexra(ustrregexra(`"`_cl_k'"', "(^|#)c\.", "$1"), ///
				"(^|#)([0-9]+)[a-z]+\.", "$1$2.")
			local _cl_if `"_n >= 3 & _cl_nkv == `"`_cl_nk'"'"'
			if `"`_cl_eq'"' != "" local _cl_if `"`_cl_if' & _cl_pre == `"`_cl_eq'"'"'
			quietly count if `_cl_if'
			if r(N) == 0 {
				display as error `"collabels(): `=cond(`"`_cl_eq'"' != "", `"`_cl_eq':"', "")'`_cl_k' matches no coefficient row (give raw names, as keep() takes them, eq:name in a multi-equation table)"'
				exit 198
			}
			tempvar _cl_hit
			quietly generate byte `_cl_hit' = `_cl_if'
			mata: _rt_cl_i = selectindex(st_data(., "`_cl_hit'")); _rt_cl_p = st_sdata(_rt_cl_i, "_cl_pre"); st_sstore(_rt_cl_i, "_tp_lab", _rt_cl_p :+ ((_rt_cl_p :!= "") :* ": ") :+ st_local("_cl_l"))
			capture mata: mata drop _rt_cl_i _rt_cl_p
			drop `_cl_hit'
		}
	}
	local _rc = _rc
	capture drop _cl_nkv
	capture drop _cl_pre
	capture mata: mata drop _rt_cl_i _rt_cl_p
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
