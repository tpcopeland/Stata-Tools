*! _regtab_modelnoun Version 2.5.6  2026/10/07
*! the model named in the methods sentence
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* =============================================================================
* _regtab_modelnoun: the model named in the methods sentence
* =============================================================================
* Usage: _regtab_modelnoun "<command word>" `"<option text>"' "<scale>" "<prefixes>"
* Returns _mnoun in the caller, built from the estimation command, glm/xtgee
* family and link, the survival metric (the scale header: HR or TR), and the
* estimation prefixes; never from a coef() or cdisc relabel.
capture program drop _regtab_modelnoun
program define _regtab_modelnoun, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _w 0 : 0
		gettoken _o 0 : 0
		gettoken _sc 0 : 0
		gettoken _pf 0 : 0
		local _w = lower(`"`_w'"')
		local _n ""
		local _me ""
		if inlist("`_w'", "melogit", "meprobit", "mecloglog", "mepoisson", "menbreg", ///
			"meologit", "meoprobit", "mestreg", "meglm") | ///
			inlist("`_w'", "meintreg", "metobit", "meqrlogit", "meqrpoisson") {
			local _me "mixed-effects "
			local _w = substr("`_w'", 3, .)
		}
		if inlist("`_w'", "glm", "xtgee") {
			_regtab_cmdopts "Family(string) Link(string)" `"`_o'"'
			gettoken _fam : _ro_family
			gettoken _lnk : _ro_link
			local _fam = lower(`"`_fam'"')
			local _lnk = lower(`"`_lnk'"')
			local _fl = strlen(`"`_fam'"')
			local _ll = strlen(`"`_lnk'"')
			local _f "other"
			if `_fl' == 0 local _f "gaussian"
			else if `"`_fam'"' == substr("gaussian", 1, max(`_fl', 3)) | ///
				`"`_fam'"' == substr("normal", 1, `_fl') local _f "gaussian"
			else if `"`_fam'"' == substr("igaussian", 1, max(`_fl', 2)) local _f "igaussian"
			else if `"`_fam'"' == substr("binomial", 1, `_fl') | ///
				`"`_fam'"' == substr("bernoulli", 1, `_fl') local _f "binomial"
			else if `"`_fam'"' == substr("poisson", 1, `_fl') local _f "poisson"
			else if `"`_fam'"' == substr("nbinomial", 1, max(2, `_fl')) local _f "nbinomial"
			else if `"`_fam'"' == substr("gamma", 1, max(3, `_fl')) local _f "gamma"
			local _l "other"
			if `_ll' == 0 {
				if "`_f'" == "binomial" local _l "logit"
				else if inlist("`_f'", "poisson", "nbinomial") local _l "log"
				else if "`_f'" == "gaussian" local _l "identity"
				else if "`_f'" == "gamma" local _l "reciprocal"
			}
			else if `"`_lnk'"' == substr("identity", 1, `_ll') local _l "identity"
			else if `"`_lnk'"' == "log" local _l "log"
			else if `"`_lnk'"' == substr("logit", 1, `_ll') local _l "logit"
			else if `"`_lnk'"' == substr("probit", 1, `_ll') local _l "probit"
			else if `"`_lnk'"' == substr("cloglog", 1, `_ll') local _l "cloglog"
			else if `"`_lnk'"' == substr("reciprocal", 1, `_ll') local _l "reciprocal"
			if "`_f'" == "binomial" & "`_l'" == "logit" local _n "logistic regression"
			else if "`_f'" == "binomial" & "`_l'" == "probit" local _n "probit regression"
			else if "`_f'" == "binomial" & "`_l'" == "cloglog" local _n "complementary log-log regression"
			else if "`_f'" == "binomial" & "`_l'" == "log" local _n "log-binomial regression"
			else if "`_f'" == "poisson" & "`_l'" == "log" local _n "Poisson regression"
			else if "`_f'" == "nbinomial" & "`_l'" == "log" local _n "negative binomial regression"
			else if "`_f'" == "gaussian" & "`_l'" == "identity" local _n "linear regression"
			else if "`_f'" == "gamma" & "`_l'" == "log" local _n "gamma regression with a log link"
			else {
				local _fn = cond("`_f'" == "other", `"`_fam'"', "`_f'")
				local _lnn = cond("`_l'" == "other", `"`_lnk'"', "`_l'")
				local _n "generalized linear model (`_fn' family, `_lnn' link)"
			}
			if "`_w'" == "xtgee" local _n "generalized estimating equation (GEE) `_n'"
		}
		else if inlist("`_w'", "logit", "logistic", "qrlogit") local _n "logistic regression"
		else if "`_w'" == "clogit" local _n "conditional logistic regression"
		else if "`_w'" == "probit" local _n "probit regression"
		else if "`_w'" == "hetprobit" local _n "heteroskedastic probit regression"
		else if inlist("`_w'", "qreg", "bsqreg", "sqreg") local _n "quantile regression"
		else if "`_w'" == "ivregress" local _n "instrumental-variables regression"
		else if "`_w'" == "cloglog" local _n "complementary log-log regression"
		else if inlist("`_w'", "poisson", "qrpoisson") local _n "Poisson regression"
		else if "`_w'" == "nbreg" local _n "negative binomial regression"
		else if "`_w'" == "gnbreg" local _n "generalized negative binomial regression"
		else if "`_w'" == "zip" local _n "zero-inflated Poisson regression"
		else if "`_w'" == "zinb" local _n "zero-inflated negative binomial regression"
		else if "`_w'" == "regress" local _n "linear regression"
		else if "`_w'" == "ologit" local _n "ordered logistic regression"
		else if "`_w'" == "oprobit" local _n "ordered probit regression"
		else if "`_w'" == "mlogit" local _n "multinomial logistic regression"
		else if "`_w'" == "mprobit" local _n "multinomial probit regression"
		else if "`_w'" == "stcox" local _n "Cox proportional hazards regression"
		else if inlist("`_w'", "streg", "stintreg") {
			if "`_sc'" == "HR" local _n "parametric proportional hazards survival regression"
			else local _n "accelerated failure-time survival regression"
			if "`_w'" == "stintreg" local _n "interval-censored `_n'"
		}
		else if inlist("`_w'", "stcrreg", "finegray") local _n "Fine-Gray competing-risks regression"
		else if "`_w'" == "mixed" local _n "linear mixed-effects regression"
		else if "`_w'" == "tobit" local _n "tobit regression"
		else if "`_w'" == "intreg" local _n "interval regression"
		else if "`_w'" == "xtreg" local _n "linear panel-data regression"
		else if "`_w'" == "xtlogit" local _n "panel-data logistic regression"
		else if "`_w'" == "xtpoisson" local _n "panel-data Poisson regression"
		else if "`_w'" == "churdle" local _n "Cragg hurdle regression"
		else local _n "regression"
		local _n "`_me'`_n'"
		if strpos(" `_pf' ", " svy ") local _n "survey-weighted `_n'"
		if strpos(" `_pf' ", " mi ") local _n "`_n' with multiple imputation"
		if strpos(" `_pf' ", " bootstrap ") local _n "`_n' with bootstrap standard errors"
		if strpos(" `_pf' ", " jackknife ") local _n "`_n' with jackknife standard errors"
		c_local _mnoun `"`_n'"'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
