*! _regtab_mincount Version 2.6.0  2026/10/08
*! regtab block: mincount() masks, not-estimable and absent levels
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_mincount" from inside its quietly block (only when
* mincount() is given) and the body is quietly again, so only the block's own
* noisily lines print.
*
* mincount(#): a factor level (or a 0/1 indicator) the model could not
* estimate - its variance is zero or missing, or collect records it as
* omitted or empty - is shown as notestlabel(); one whose events (tabtools
* fitcount, terms) are fewer than # as emptylabel(); both with the interval
* and p-value blank. A model's own base level keeps its reference label, and
* a coefficient a constraint fixes keeps its fixed value (nothing is
* estimated). Every level a model shows must be covered by that model's
* counts. A level of a factor block the model includes that is missing from
* the model's e(b) altogether is told apart by the levels its estimation
* sample holds (tt_levels, stored by tabtools fitcount, terms): a level with
* no observation there was left out by design (an if restriction, a
* subgroup) and is shown as absentlabel(), blank by default; a level the
* sample holds that the model does not estimate is shown as notestlabel().
* When the counts record no sample levels (tt_levels from an older
* fitcount), the level is shown as notestlabel(), the reading that does not
* claim the model left it out, and a note names it. r(N_absent) counts the
* levels missing from a model either way; r(N_masked) keeps its 2.3.1
* meaning, the cells of levels a model holds.
program define _regtab_mincount, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
* the factor block of every row: one id per consecutive run of levels
quietly generate str244 _mc_par = ""
forvalues _rr = 3/`=_N' {
	local _rt_key = strtrim(_raw_A[`_rr'])
	if `"`_rt_key'"' == "" continue
	_regtab_fvparent `"`_rt_key'"'
	if `"`_fp_parent'"' != "" quietly replace _mc_par = `"`_fp_parent'"' in `_rr'
}
quietly generate long _mc_blk = sum(_mc_par != "" & _mc_par != _mc_par[_n - 1])
quietly replace _mc_blk = 0 if _mc_par == ""
forvalues _m = 1/`n_models' {
	local _fct_s `";`_fct_`_m'';"'
	local _fcl_s `"`_fcl_`_m''"'
	local _mc_unk ""
	local _mc_ab_`_m' ""
	local _ce = (`_m' - 1) * 3 + 1
	quietly levelsof _mc_blk if _n >= 3 & _mc_blk > 0 & strtrim(c`_ce') != "", local(_mc_in)
	forvalues _rr = 3/`=_N' {
		local _rt_key = strtrim(_raw_A[`_rr'])
		if `"`_rt_key'"' == "" continue
		local _mc_b = _mc_blk[`_rr']
		if strtrim(c`_ce'[`_rr']) == "" {
			local _mc_has : list _mc_b in _mc_in
			if `_mc_b' == 0 | !`_mc_has' continue
			* missing from the model: did its estimation sample hold the level?
			local _sig = ustrregexra(`"`_rt_key'"', "(^|#)[0-9]+\.", "$1*.")
			local _pos = strpos(`"`_fcl_s'"', `";`_sig'="')
			if `_pos' > 0 {
				local _frag = substr(`"`_fcl_s'"', `_pos' + strlen(`";`_sig'="'), .)
				local _frag = substr(`"`_frag'"', 1, strpos(`"`_frag'"', ";") - 1)
				local _held : list _rt_key in _frag
			}
			else {
				local _held = 1
				local _mc_unk "`_mc_unk' `_rt_key'"
			}
			local ++_n_absent
			local _mc_ab_`_m' "`_mc_ab_`_m'' `_rr'"
			if `_held' {
				local _mc_lbl : copy local notestlabel
				local _mc_kind "mk_ne"
			}
			else {
				if `"`macval(absentlabel)'"' == "" continue
				local _mc_lbl : copy local absentlabel
				local _mc_kind "mk_ab"
			}
		}
		else {
			if inlist(_constraint`_m'[`_rr'], "base", "cns") continue
			local _pos = strpos(`"`_fct_s'"', `";`_rt_key'="')
			* a term that is not a factor level is masked only when the
			* counts cover it (a 0/1 indicator); others have no count
			if `_mc_b' == 0 & `_pos' == 0 continue
			if `_pos' == 0 {
				noisily display as error "mincount(): the fit-time counts of model `_m' do not cover `_rt_key';" ///
					" run tabtools fitcount, terms right after that model's fit"
				exit 459
			}
			local _frag = substr(`"`_fct_s'"', `_pos' + strlen(`";`_rt_key'="'), .)
			local _frag = substr(`"`_frag'"', 1, strpos(`"`_frag'"', ";") - 1)
			local _bar = strpos(`"`_frag'"', "|")
			local _tev = real(substr(`"`_frag'"', 1, `_bar' - 1))
			local _tvok = real(substr(`"`_frag'"', `_bar' + 1, .))
			if missing(`_tev') | missing(`_tvok') {
				noisily display as error "mincount(): unreadable fit-time count for `_rt_key' in model `_m'"
				exit 459
			}
			local _mc_kind "mk_ne"
			if `_tvok' != 1 | _constraint`_m'[`_rr'] != "" local _mc_lbl : copy local notestlabel
			else if `_tev' < `mincount' {
				local _mc_lbl : copy local emptylabel
				local _mc_kind "mk_th"
			}
			else continue
			local ++_n_masked
		}
		quietly replace c`_ce' = `"`macval(_mc_lbl)'"' in `_rr'
		quietly replace c`=`_ce' + 1' = "" in `_rr'
		quietly replace c`=`_ce' + 2' = "" in `_rr'
		quietly replace _constraint`_m' = "`_mc_kind'" in `_rr'
		foreach _ev in est ll ul p {
			capture confirm variable _eplot_`_ev'`_m'
			if !_rc quietly replace _eplot_`_ev'`_m' = . in `_rr'
		}
	}
	if "`_mc_unk'" != "" {
		noisily display as text "(regtab: model `_m': the fit-time counts do not record which levels its" ///
			" estimation sample holds, so`_mc_unk' missing from it" ///
			" are shown as notestlabel(); rerun tabtools fitcount, terms after the fit to tell" ///
			" levels it leaves out, shown as absentlabel())"
	}
}
drop _mc_par _mc_blk
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end
