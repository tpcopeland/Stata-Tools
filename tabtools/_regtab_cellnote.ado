*! _regtab_cellnote Version 2.5.1  2026/10/06
*! parse cellnote("row label" model# "text" [\ ...])
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_cellnote: parse cellnote("row label" model# "text" [\ ...])
* =============================================================================
* Usage: _regtab_cellnote `"<cellnote>"'
* Tokens are read quote-aware, so a label or text may hold spaces,
* backslashes, and embedded quotes, and \ may touch its neighbours
* ("a"\"b"), the forms addrow() takes. A specification wrapped whole in one
* more layer of quotes is unwrapped first. Each specification is exactly three
* tokens. Returns _cn_n, _cn_lab_#, _cn_m_#, _cn_txt_# in the caller.
capture program drop _regtab_cellnote
program define _regtab_cellnote, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken _cn_rest 0 : 0
	capture noisily {
		local _cn_n = 0
		_regtab_unwrap `"`macval(_cn_rest)'"'
		local _cn_rest : copy local _uw_spec
		local _cn_k = 0
		local _cn_more = 1
		local _cn_msg `"cellnote() expects "row label" model# "text" [\ ...]"'
		while `_cn_more' {
			local _cn_rest = strtrim(`"`macval(_cn_rest)'"')
			local _cn_tok ""
			if `"`macval(_cn_rest)'"' != "" gettoken _cn_tok _cn_rest : _cn_rest, parse("\ ") quotes
			local _cn_end = (`"`macval(_cn_rest)'"' == "" & `"`macval(_cn_tok)'"' != "\")
			if `"`macval(_cn_tok)'"' != "\" & `"`macval(_cn_tok)'"' != "" {
				local ++_cn_k
				local _cn_tk_`_cn_k' : copy local _cn_tok
				if !`_cn_end' continue
			}
			* a specification is complete: at a \ or at the end
			if `_cn_k' != 3 {
				display as error `"`_cn_msg'"'
				exit 198
			}
			gettoken _cn_lab : _cn_tk_1
			gettoken _cn_m : _cn_tk_2
			gettoken _cn_txt : _cn_tk_3
			capture confirm integer number `_cn_m'
			local _cn_bad = _rc
			if !`_cn_bad' {
				if `_cn_m' < 1 local _cn_bad = 1
			}
			if `_cn_bad' | `"`macval(_cn_lab)'"' == "" {
				display as error `"`_cn_msg'"'
				exit 198
			}
			local ++_cn_n
			c_local _cn_lab_`_cn_n' `"`macval(_cn_lab)'"'
			c_local _cn_m_`_cn_n' `_cn_m'
			c_local _cn_txt_`_cn_n' `"`macval(_cn_txt)'"'
			local _cn_k = 0
			if `_cn_end' local _cn_more = 0
			else if strtrim(`"`macval(_cn_rest)'"') == "" {
				display as error "cellnote(): nothing follows the last separator"
				exit 198
			}
		}
		c_local _cn_n `_cn_n'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
