*! _regtab_scale Version 2.5.2  2026/10/06
*! display scale of one collected model
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_scale: display scale of one collected model
* =============================================================================
* Usage: _regtab_scale "<command word>" "<e(cmd)>" `"<option text>"'
* Returns in the caller:
*   _rs_coef   estimate header (OR, HR, IRR, RRR, SHR, TR, RR, exp(b), Coef.)
*   _rs_eform  1 when the collected values are coefficients that regtab must
*              exponentiate to reach _rs_coef
*   _rs_null   null value on the displayed scale (1 for ratios, 0 otherwise)
*   _rs_noint  1 when the intercept row is suppressed by default
*   _rs_known  1 when the command has a dedicated rule
*   _rs_level  confidence level requested with level(), or -1 when absent
* Ratio families are always shown on the ratio scale: a fit displayed on the
* coefficient scale (logit without or, stcox with nohr, logistic with coef,
* streg or stintreg in the time metric without tratio) is exponentiated, and a fit Stata
* already exponentiated (or, hr, tr, irr, eform) is left alone. The header
* therefore always names the scale of the numbers printed under it.
* Optional 4th and 5th arguments describe an estimation prefix: mode "mi"
* (mi estimate reports the coefficient metric whatever the command's own
* display options, unless mi estimate itself was given an eform option;
* [MI] mi estimate) or mode "or" (bootstrap/jackknife, whose eform option
* exponentiates as the command's own would), and whether the prefix carried
* an eform option (0/1).
capture program drop _regtab_scale
program define _regtab_scale, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _rs_word 0 : 0
		gettoken _rs_ecmd 0 : 0
		gettoken _rs_opt 0 : 0
		gettoken _rs_pmode 0 : 0
		gettoken _rs_peform 0 : 0
		if "`_rs_peform'" == "" local _rs_peform 0
		local _rs_word = lower(`"`_rs_word'"')
		local _rs_ecmd = lower(`"`_rs_ecmd'"')

		local _c "Coef."
		local _e 0
		local _n 0
		local _i 0
		local _k 1

		if inlist("`_rs_word'", "logit", "ologit", "melogit", "clogit") {
			_regtab_cmdopts "OR" `"`_rs_opt'"'
			local _c "OR"
			local _e = ("`_ro_or'" == "")
			local _n 1
			local _i 1
		}
		else if "`_rs_word'" == "logistic" {
			_regtab_cmdopts "COEF" `"`_rs_opt'"'
			local _c "OR"
			local _e = ("`_ro_coef'" != "")
			local _n 1
			local _i 1
		}
		else if inlist("`_rs_word'", "poisson", "nbreg", "mepoisson", "menbreg") {
			* poisson and nbreg accept ir; the mixed-effects forms need irr.
			local _spec "IRr"
			if inlist("`_rs_word'", "mepoisson", "menbreg") local _spec "IRR"
			_regtab_cmdopts "`_spec'" `"`_rs_opt'"'
			local _c "IRR"
			local _e = ("`_ro_irr'" == "")
			local _n 1
			local _i 1
		}
		else if "`_rs_word'" == "mlogit" {
			_regtab_cmdopts "RRr" `"`_rs_opt'"'
			local _c "RRR"
			local _e = ("`_ro_rrr'" == "")
			local _n 1
			local _i 1
		}
		else if inlist("`_rs_word'", "zip", "zinb", "churdle") {
			local _i 1
		}
		else if inlist("`_rs_word'", "finegray", "stcrreg") {
			_regtab_cmdopts "noSHR" `"`_rs_opt'"'
			local _c "SHR"
			local _e = ("`_ro_shr'" != "")
			local _n 1
			local _i 1
		}
		else if "`_rs_word'" == "stcox" | "`_rs_ecmd'" == "cox" {
			_regtab_cmdopts "noHR" `"`_rs_opt'"'
			local _c "HR"
			local _e = ("`_ro_hr'" != "")
			local _n 1
			local _i 1
		}
		else if inlist("`_rs_word'", "streg", "stintreg", "mestreg") {
			* Metric rules from streg.ado/stintreg.ado/mestreg.ado: exponential
			* and Weibull fit in the log-hazard metric unless time (or, for
			* streg and stintreg, tratio) is given; Gompertz is log-hazard
			* only; lognormal, loglogistic and (generalized) gamma are log-time
			* only. The hazard metric displays hazard ratios unless nohr; the
			* time metric displays coefficients unless tratio. stintreg, like
			* streg, names its distribution in e(cmd) (ereg, weibull,
			* gompertz, lnormal, llogistic, gamma; e(cmd2) is stintreg).
			_regtab_cmdopts "TIme TRatio noHR Distribution(string)" `"`_rs_opt'"'
			local _aft_opt = ("`_ro_time'`_ro_tratio'" != "")
			if "`_rs_word'" == "mestreg" local _aft_opt = ("`_ro_time'" != "")
			local _ph_capable 0
			local _ph_only 0
			if inlist("`_rs_word'", "streg", "stintreg") {
				if regexm("`_rs_ecmd'", "^(ereg|weibull)") local _ph_capable 1
				if regexm("`_rs_ecmd'", "^gompertz") local _ph_only 1
			}
			else {
				gettoken _dist : _ro_distribution, parse(" ,")
				local _dist = lower(`"`_dist'"')
				local _dl = strlen(`"`_dist'"')
				if `_dl' > 0 {
					if `"`_dist'"' == substr("exponential", 1, `_dl') | ///
						`"`_dist'"' == substr("weibull", 1, `_dl') local _ph_capable 1
				}
			}
			local _hazard = `_ph_only' | (`_ph_capable' & !`_aft_opt')
			if `_hazard' {
				local _c "HR"
				local _e = ("`_ro_hr'" != "")
			}
			else {
				local _c "TR"
				local _e = ("`_ro_tratio'" == "")
			}
			local _n 1
			local _i 1
		}
		else if "`_rs_word'" == "mecloglog" {
			_regtab_cmdopts "EFORM" `"`_rs_opt'"'
			local _c "HR"
			local _e = ("`_ro_eform'" == "")
			local _n 1
			local _i 1
		}
		else if inlist("`_rs_word'", "glm", "xtgee") {
			* Family/link abbreviations follow glm.ado's MapFam and MapLink;
			* xtgee takes the same Family(), Link() and EForm options and the
			* same defaults (binomial -> logit, poisson -> log), so a GEE fit
			* is shown on the scale glm gives the same family and link.
			_regtab_cmdopts "EForm Family(string) Link(string)" `"`_rs_opt'"'
			gettoken _fam : _ro_family
			gettoken _lnk : _ro_link
			local _fam = lower(`"`_fam'"')
			local _lnk = lower(`"`_lnk'"')
			local _fl = strlen(`"`_fam'"')
			local _ll = strlen(`"`_lnk'"')
			local _famc "other"
			if `_fl' == 0 local _famc "gaussian"
			else if `"`_fam'"' == substr("gaussian", 1, max(`_fl', 3)) | ///
				`"`_fam'"' == substr("normal", 1, `_fl') local _famc "gaussian"
			else if `"`_fam'"' == substr("binomial", 1, `_fl') | ///
				`"`_fam'"' == substr("bernoulli", 1, `_fl') local _famc "binomial"
			else if `"`_fam'"' == substr("poisson", 1, `_fl') local _famc "poisson"
			else if `"`_fam'"' == substr("nbinomial", 1, max(2, `_fl')) local _famc "nbinomial"
			local _lnkc "other"
			if `_ll' == 0 {
				if "`_famc'" == "binomial" local _lnkc "logit"
				else if inlist("`_famc'", "poisson", "nbinomial") local _lnkc "log"
				else if "`_famc'" == "gaussian" local _lnkc "identity"
			}
			else if `"`_lnk'"' == substr("identity", 1, `_ll') local _lnkc "identity"
			else if `"`_lnk'"' == substr("reciprocal", 1, `_ll') local _lnkc "other"
			else if `"`_lnk'"' == "log" local _lnkc "log"
			else if `"`_lnk'"' == substr("logit", 1, `_ll') local _lnkc "logit"
			local _eopt = ("`_ro_eform'" != "")
			if "`_rs_pmode'" == "mi" local _eopt = `_rs_peform'
			else if "`_rs_pmode'" == "or" local _eopt = `_eopt' | `_rs_peform'
			if "`_famc'" == "binomial" & "`_lnkc'" == "logit" {
				local _c "OR"
				local _e = !`_eopt'
				local _n 1
				local _i 1
			}
			else if "`_famc'" == "poisson" & "`_lnkc'" == "log" {
				local _c "IRR"
				local _e = !`_eopt'
				local _n 1
				local _i 1
			}
			else if `_eopt' {
				* eform on any other family/link: glm already reports exp(b);
				* name it the way glm's own table does.
				local _c "exp(b)"
				if "`_famc'" == "binomial" & "`_lnkc'" == "log" local _c "RR"
				if "`_famc'" == "nbinomial" & "`_lnkc'" == "log" local _c "IRR"
				local _n 1
				local _i 1
			}
		}
		else if !inlist("`_rs_word'", "regress", "mixed", "xtreg") {
			local _k 0
		}

		* level(): glm and the multilevel families also take link(), so their
		* level() needs two letters; every other supported estimator takes l().
		local _lspec "Level(string)"
		if inlist("`_rs_word'", "glm", "xtgee", "meglm", "mestreg") local _lspec "LEvel(string)"
		_regtab_cmdopts "`_lspec'" `"`_rs_opt'"'
		local _lv = -1
		if `"`_ro_level'"' != "" {
			local _lv = real(`"`_ro_level'"')
			if missing(`_lv') local _lv = -1
		}

		* A prefix decides what the collection holds for a ratio family. glm
		* and xtgee already folded the prefix into _eopt above.
		if !inlist("`_rs_word'", "glm", "xtgee") & `_n' == 1 {
			if "`_rs_pmode'" == "mi" local _e = !`_rs_peform'
			else if "`_rs_pmode'" == "or" & `_rs_peform' local _e 0
		}

		c_local _rs_coef `"`_c'"'
		c_local _rs_eform `_e'
		c_local _rs_null `_n'
		c_local _rs_noint `_i'
		c_local _rs_known `_k'
		c_local _rs_level `_lv'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
