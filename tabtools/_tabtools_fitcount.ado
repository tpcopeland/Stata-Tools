*! _tabtools_fitcount Version 2.3.0  2026/10/05
*! Fit-time event, people, and person-time counts for regtab (tabtools fitcount)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
SYNTAX:
	tabtools fitcount, events(varname) [people(varname) exposure(varname) terms
	    name(collection)]

Runs right after an estimation command whose results were collected with the
collect: prefix (or collect get e()). On the fit's own e(sample) it counts

	events     the sum of events() (a 0/1 failure indicator such as _d, or a
	           nonnegative integer event count)
	people     the number of distinct values of people() (clusters)
	exposure   the sum of exposure() (person-time)
	terms      for every factor-level coefficient of e(b), and every 0/1
	           indicator entered as a plain variable, the events in that level
	           (all factor parts of an interaction must match; an indicator's
	           level is 1) and whether the fit estimated a positive, finite
	           variance for it

and stores them with collect get in the active collection, tagged with the
fit's own cmdset, as results tt_events, tt_people, tt_exposure, and tt_terms.
regtab reads them for stats(events people exposure) and mincount(). The
collection does not keep e(sample), which is why the counts are taken here.

The fit is identified exactly: the collection's latest cmdset must carry the
same command line and number of observations as the active e(), and every
e(b) coefficient the collection also holds must equal its collected _r_b (or
its exponent, for an eform collection) to reldif < 1e-12; anything else is
refused rather than attached to the wrong model. name() names the collection
of a collect, name(): fit, which nothing in e() records.
*/

program define _tabtools_fitcount, rclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	local _restore_needed = 0
	local _coll0 `"`c(collect_current)'"'
	local _coll_switched = 0
	capture noisily {
		syntax , EVents(varname numeric) [PEOple(varname) EXPosure(varname numeric) TERMS NAMe(name)]

		* name(): the collection the fit was collected into (collect, name():
		* does not change the current collection, and nothing in e() records
		* it). It is made current for the duration of fitcount only.
		if "`name'" != "" & "`name'" != `"`_coll0'"' {
			capture quietly collect set `name'
			if _rc {
				noisily display as error "tabtools fitcount: collection `name' not found"
				exit 111
			}
			local _coll_switched = 1
		}
		local _coll `"`c(collect_current)'"'
		local _hint "run tabtools fitcount right after collect: <estimation command>, and add name() for collect, name(): fits"

		* Live estimation results with an estimation sample are required.
		if `"`e(cmd)'"' == "" {
			noisily display as error "tabtools fitcount: no estimation results; run it right after the fit"
			exit 301
		}
		if `"`e(cmd_mi)'"' != "" | `"`e(cmd)'"' == "mi estimate" {
			noisily display as error "tabtools fitcount: mi estimate results carry no single estimation sample"
			exit 198
		}
		* An fweight row stands for several people and an iweight has no
		* count meaning, so a count of rows would be wrong: refused. pweights
		* and aweights leave each row one observation, which is what is counted.
		if inlist(`"`e(wtype)'"', "fweight", "iweight") {
			noisily display as error "tabtools fitcount: `e(wtype)'s are not allowed;" ///
				" the counts are of observations (pweights and aweights are ignored)"
			exit 101
		}
		* svy, subpop(): e(sample) holds the whole design sample, not the
		* subpopulation the estimates describe.
		if `"`e(subpop)'"' != "" {
			noisily display as error "tabtools fitcount: svy, subpop() results are refused;" ///
				" e(sample) spans the whole design, not the subpopulation"
			exit 459
		}
		tempvar touse
		capture quietly generate byte `touse' = e(sample)
		if _rc {
			noisily display as error "tabtools fitcount: the active estimation results have no e(sample)"
			exit 459
		}
		quietly count if `touse'
		local _n_sample = r(N)
		if `_n_sample' == 0 {
			noisily display as error "tabtools fitcount: e(sample) is empty in the data in memory;" ///
				" run it right after the fit, on the data the model was fitted to"
			exit 459
		}
		local _e_n = e(N)
		if !missing(`_e_n') & `_e_n' != `_n_sample' {
			noisily display as error "tabtools fitcount: e(sample) holds `_n_sample' observations but e(N) is `_e_n'"
			exit 459
		}

		* The fit must be the collection's latest cmdset: same command line,
		* same number of observations.
		capture quietly collect levelsof cmdset
		if _rc | `"`s(levels)'"' == "" {
			noisily display as error "tabtools fitcount: collection `_coll' holds no collected model"
			noisily display as error "  `_hint'"
			exit 119
		}
		local _k = 0
		foreach _lv in `s(levels)' {
			capture confirm integer number `_lv'
			if !_rc {
				if `_lv' > `_k' local _k = `_lv'
			}
		}
		if `_k' == 0 {
			noisily display as error "tabtools fitcount: the collection has no numbered cmdset"
			exit 459
		}
		local _ecmdline `"`e(cmdline)'"'
		preserve
		local _restore_needed = 1
		capture _tabtools_collect_render, type(meta) rowdim(cmdset) results(cmdline N)
		local _render_rc = _rc
		local _c_cmdline ""
		local _c_N = .
		if !`_render_rc' {
			quietly count
			forvalues _r = 2/`=_N' {
				if strtrim(A[`_r']) == "`_k'" {
					mata: st_local("_c_cmdline", strtrim(st_sdata(`_r', "B")))
					capture confirm variable C
					if !_rc local _c_N = real(subinstr(strtrim(C[`_r']), ",", "", .))
				}
			}
		}
		restore
		local _restore_needed = 0
		if `_render_rc' {
			noisily display as error "tabtools fitcount: could not read the collected models"
			exit `_render_rc'
		}
		mata: st_local("_same_cmd", strofreal(strtrim(st_local("_c_cmdline")) == strtrim(st_local("_ecmdline"))))
		if !`_same_cmd' | `"`_ecmdline'"' == "" {
			noisily display as error "tabtools fitcount: the active estimation results are not the latest model (cmdset `_k') of collection `_coll'"
			noisily display as error "  `_hint'"
			exit 459
		}
		if !missing(`_c_N') & !missing(`_e_n') & `_c_N' != `_e_n' {
			noisily display as error "tabtools fitcount: the collected model (cmdset `_k') has N = `_c_N', the active fit N = `_e_n'"
			exit 459
		}

		* Same coefficients: every e(b) column whose name the collection also
		* holds for cmdset `_k' must carry the collected _r_b (as is, or
		* exponentiated for an eform display) to reldif < 1e-12. A refit of the
		* same command line on changed data passes the checks above but not this.
		capture confirm matrix e(b)
		if _rc {
			noisily display as error "tabtools fitcount: the active estimation results have no e(b)"
			exit 459
		}
		tempfile _cjf
		local _cjs `"`_cjf'.stjson"'
		quietly collect save `"`_cjs'"', replace
		capture noisily {
			mata: _tt_fc_L = cat(st_local("_cjs"))
			mata: _tt_fc_h = selectindex(ustrregexm(_tt_fc_L, `"[#"]cmdset\[`_k'\][#"]"') :& ustrregexm(_tt_fc_L, `"[#"]result\[_r_b\][#"]"'))
			mata: _tt_fc_k = _tt_fc_L[_tt_fc_h]
			mata: _tt_fc_d = rows(_tt_fc_h) ? strtoreal(ustrregexra(_tt_fc_L[_tt_fc_h :+ 1], `"^\s*"d":\s*([^,]*),?\s*$"', "$1")) : J(0, 1, .)
			mata: _tt_fc_ce = ustrregexra(_tt_fc_k, `"^.*[#"]coleq\[([^\]]*)\][#"].*$"', "$1") :* ustrregexm(_tt_fc_k, `"[#"]coleq\["')
			mata: _tt_fc_cn = ustrregexra(_tt_fc_k, `"^.*?[#"]colname\[(.+?)\][#"].*$"', "$1")
			mata: _tt_fc_s = st_matrixcolstripe("e(b)")
			mata: _tt_fc_b = st_matrix("e(b)")'
			* names as the collection keys them: 1b.x -> 1.x, c.z -> z
			mata: _tt_fc_bn = ustrregexra(ustrregexra(_tt_fc_s[., 2], "(^|#)([0-9]+)[a-z]+\.", "$1$2."), "(^|#)c\.", "$1")
			mata: _tt_fc_q = all((_tt_fc_s[., 1] :== "") :| (_tt_fc_s[., 1] :== "_"))
			mata: _tt_fc_bk = _tt_fc_q ? _tt_fc_bn : (_tt_fc_s[., 1] :+ ":" :+ _tt_fc_bn)
			mata: _tt_fc_ck = _tt_fc_q ? _tt_fc_cn : (_tt_fc_ce :+ ":" :+ _tt_fc_cn)
			mata: _tt_fc_m = 0; _tt_fc_x = 0
			mata: for (_tt_fc_j = 1; _tt_fc_j <= rows(_tt_fc_bk); _tt_fc_j++) { _tt_fc_i = selectindex(_tt_fc_ck :== _tt_fc_bk[_tt_fc_j]); if (rows(_tt_fc_i) != 1) continue; if (missing(_tt_fc_d[_tt_fc_i])) continue; _tt_fc_m++; if (!(reldif(_tt_fc_d[_tt_fc_i], _tt_fc_b[_tt_fc_j]) < 1e-12 | reldif(_tt_fc_d[_tt_fc_i], exp(_tt_fc_b[_tt_fc_j])) < 1e-12)) _tt_fc_x++; }
			mata: st_local("_b_matched", strofreal(_tt_fc_m)); st_local("_b_differ", strofreal(_tt_fc_x))
		}
		local _b_rc = _rc
		capture mata: mata drop _tt_fc_*
		if `_b_rc' {
			noisily display as error "tabtools fitcount: could not read the coefficients of collected model `_k'"
			exit `_b_rc'
		}
		if `_b_matched' == 0 {
			noisily display as error "tabtools fitcount: no coefficient of the active fit was found in collected model `_k'; its identity cannot be checked"
			exit 459
		}
		if `_b_differ' > 0 {
			noisily display as error "tabtools fitcount: `_b_differ' of `_b_matched' coefficients of the active fit differ from collected model `_k' (same command line, different estimates)"
			noisily display as error "  `_hint'"
			exit 459
		}

		* events(): nonmissing, nonnegative integers in the estimation sample
		quietly count if `touse' & missing(`events')
		if r(N) > 0 {
			noisily display as error "tabtools fitcount: events() is missing in `r(N)' observations of e(sample)"
			exit 459
		}
		quietly count if `touse' & (`events' < 0 | `events' != floor(`events'))
		if r(N) > 0 {
			noisily display as error "tabtools fitcount: events() must be a nonnegative integer count (0/1 for a failure indicator)"
			exit 459
		}
		tempname _ev _pp _px
		quietly summarize `events' if `touse', meanonly
		scalar `_ev' = r(sum)

		scalar `_pp' = .
		if "`people'" != "" {
			capture confirm string variable `people'
			if _rc quietly count if `touse' & missing(`people')
			else quietly count if `touse' & `people' == ""
			if r(N) > 0 {
				noisily display as error "tabtools fitcount: people() is missing in `r(N)' observations of e(sample)"
				exit 459
			}
			* distinct clusters counted on a copy: the caller's sort order stays
			preserve
			local _restore_needed = 1
			quietly keep if `touse'
			quietly keep `people'
			quietly duplicates drop
			scalar `_pp' = _N
			restore
			local _restore_needed = 0
		}

		scalar `_px' = .
		if "`exposure'" != "" {
			quietly count if `touse' & (missing(`exposure') | `exposure' < 0)
			if r(N) > 0 {
				noisily display as error "tabtools fitcount: exposure() must be nonmissing and nonnegative in e(sample) (`r(N)' observations are not)"
				exit 459
			}
			quietly summarize `exposure' if `touse', meanonly
			scalar `_px' = r(sum)
		}

		* Per-term events: every factor-level coefficient of e(b), keyed as the
		* collection keys it (1b.x -> 1.x, 1b.g#co.z -> 1.g#z).
		local _terms_str ""
		local _n_terms = 0
		if "`terms'" != "" {
			tempname _V
			capture matrix `_V' = e(V)
			local _has_V = (_rc == 0)
			local _names : colnames e(b)
			local _ncol : word count `_names'
			* In a multi-equation model, an equation whose every coefficient
			* is constrained (mlogit's base outcome) estimates nothing and no
			* table shows it; its copies of a term must not decide the term's
			* variance flag. _eqskip holds a 0/1 per column of e(b).
			local _eqskip ""
			if `_has_V' {
				local _eqs : coleq e(b)
				local _ueqs : list uniq _eqs
				if `: word count `_ueqs'' > 1 {
					local _eqok ""
					forvalues _j = 1/`_ncol' {
						local _vjj = `_V'[`_j', `_j']
						if `_vjj' > 0 & `_vjj' < . {
							local _eqj : word `_j' of `_eqs'
							local _eqok : list _eqok | _eqj
						}
					}
					forvalues _j = 1/`_ncol' {
						local _eqj : word `_j' of `_eqs'
						local _eqin : list _eqj in _eqok
						local _eqskip "`_eqskip' `=!`_eqin''"
					}
				}
			}
			local _seen ""
			forvalues _j = 1/`_ncol' {
				if "`_eqskip'" != "" {
					if `: word `_j' of `_eqskip'' continue
				}
				local _nm : word `_j' of `_names'
				local _key ""
				local _cond ""
				local _hasfv = 0
				local _bad = 0
				local _parts = subinstr("`_nm'", "#", " ", .)
				foreach _p of local _parts {
					if regexm("`_p'", "^([0-9]+)[a-z]*\.(.+)$") {
						local _lev = regexs(1)
						local _var = regexs(2)
						capture confirm numeric variable `_var', exact
						if _rc local _bad = 1
						local _kp "`_lev'.`_var'"
						local _cond `"`_cond' & `_var' == `_lev'"'
						local _hasfv = 1
					}
					else if regexm("`_p'", "^[a-z]*\.(.+)$") {
						local _kp = regexs(1)
					}
					else local _kp "`_p'"
					if "`_key'" == "" local _key "`_kp'"
					else local _key "`_key'#`_kp'"
				}
				* a plain 0/1 indicator counts as the level 1 of itself
				if !`_hasfv' & !`_bad' & strpos("`_nm'", "#") == 0 & ///
					strpos("`_nm'", ".") == 0 & "`_nm'" != "_cons" {
					capture confirm numeric variable `_nm', exact
					if !_rc {
						capture assert inlist(`_nm', 0, 1) if `touse'
						if !_rc {
							local _key "`_nm'"
							local _cond `"& `_nm' == 1"'
							local _hasfv = 1
						}
					}
				}
				if !`_hasfv' | `_bad' continue
				local _vok = 0
				if `_has_V' {
					local _vjj = `_V'[`_j', `_j']
					if `_vjj' > 0 & `_vjj' < . local _vok = 1
				}
				local _ti : list posof "`_key'" in _seen
				if `_ti' > 0 {
					* the same term in another equation: one count, and the
					* variance is acceptable only if every copy has one
					if !`_vok' local _tvok_`_ti' = 0
					continue
				}
				local _seen "`_seen' `_key'"
				local ++_n_terms
				quietly summarize `events' if `touse' `_cond', meanonly
				local _tev = r(sum)
				if missing(`_tev') local _tev = 0
				local _tev_`_n_terms' = strofreal(`_tev', "%21.0f")
				local _tvok_`_n_terms' = `_vok'
			}
			forvalues _ti = 1/`_n_terms' {
				local _key : word `_ti' of `_seen'
				if `_ti' > 1 local _terms_str "`_terms_str';"
				local _terms_str "`_terms_str'`_key'=`_tev_`_ti''|`_tvok_`_ti''"
			}
			if `_n_terms' == 0 {
				noisily display as text "(tabtools fitcount: the model has no factor-level coefficients; no per-term counts stored)"
			}
		}

		* Attach to the fit's own cmdset in the active collection.
		quietly collect get tt_events = (scalar(`_ev')), tags(cmdset[`_k'])
		if !missing(`_pp') quietly collect get tt_people = (scalar(`_pp')), tags(cmdset[`_k'])
		if !missing(`_px') quietly collect get tt_exposure = (scalar(`_px')), tags(cmdset[`_k'])
		if "`terms'" != "" {
			if `"`_terms_str'"' == "" local _terms_str "-"
			quietly collect get tt_terms = ("`_terms_str'"), tags(cmdset[`_k'])
		}

		noisily display as text "tabtools fitcount (model `_k', " as result "`_n_sample'" as text " obs): events " ///
			as result strtrim(string(`_ev', "%21.0fc")) ///
			as text cond(missing(`_pp'), "", ", people ") as result cond(missing(`_pp'), "", strtrim(string(`_pp', "%21.0fc"))) ///
			as text cond(missing(`_px'), "", ", exposure ") as result cond(missing(`_px'), "", strtrim(string(`_px', "%21.2fc")))

		return scalar events = `_ev'
		if !missing(`_pp') return scalar people = `_pp'
		if !missing(`_px') return scalar exposure = `_px'
		return scalar N = `_n_sample'
		return scalar cmdset = `_k'
		return local collection `"`_coll'"'
		if "`terms'" != "" {
			return scalar n_terms = `_n_terms'
			return local terms `"`_terms_str'"'
		}
	}
	local rc = _rc
	if `_restore_needed' capture restore
	capture mata: mata drop _tt_fc_*
	if `_coll_switched' capture quietly collect set `_coll0'
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end

