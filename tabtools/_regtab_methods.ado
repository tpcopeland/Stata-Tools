*! _regtab_methods Version 2.6.1  2026/10/09
*! regtab block: the methods sentence (r(methods))
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_methods" from inside its quietly block and the body is quietly
* again, so only the block's own noisily lines print. Data in memory, frames,
* and the collection are shared state and need no transport.
program define _regtab_methods, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
* Build methods description (I2)
local _methods_coef ""
local _methods_model ""
if `_model_headers_mixed' {
    local _methods "Collected regression estimates with `_ci_level'% confidence intervals across `n_models' models."
}
else if `"`macval(coef)'"' == "OR" {
    local _methods_coef "Odds ratios"
    local _methods_model "logistic regression"
}
else if `"`macval(coef)'"' == "HR" {
    * HR headers come from stcox and from the hazard metric of streg,
    * mestreg, and mecloglog; only the first is a Cox model.
    local _methods_coef "Hazard ratios"
    local _methods_model "Cox proportional hazards regression"
    if `_meta_models' > 0 {
        gettoken _methods_word : model_cmdline_1
        local _methods_word = lower(`"`_methods_word'"')
        if inlist("`_methods_word'", "streg", "stintreg", "mestreg") {
            local _methods_model "parametric proportional hazards survival regression"
        }
        else if "`_methods_word'" == "mecloglog" {
            local _methods_model "mixed-effects complementary log-log regression"
        }
    }
}
else if `"`macval(coef)'"' == "TR" {
    local _methods_coef "Time ratios"
    local _methods_model "accelerated failure-time survival regression"
}
else if `"`macval(coef)'"' == "IRR" {
    local _methods_coef "Incidence rate ratios"
    local _methods_model "Poisson regression"
}
else if `"`macval(coef)'"' == "RRR" {
    local _methods_coef "Relative risk ratios"
    local _methods_model "multinomial logistic regression"
}
else if `"`macval(coef)'"' == "Coef." {
    local _methods_coef "Coefficients"
    local _methods_model "linear regression"
}
else {
    local _methods_coef : copy local coef
    local _methods_model "regression"
}
if `n_models' > 1 local _methods_multi " across `n_models' models"
else local _methods_multi ""
* With per-model metadata the sentence names what each model is: the estimate
* scale the model reports (not a coef()/cdisc relabel of the header), the
* model built from its command, family, link, metric, and prefixes, and
* "univariable" or "multivariable" from the number of predictor variables in
* the collected coefficients (a factor variable counts once). The header-based
* sentence above remains the fallback for a collection without metadata.
if !`_model_headers_mixed' & `_meta_models' > 0 {
    local _mc `"`model_coef_1'"'
    if "`_mc'" == "OR" local _methods_coef "Odds ratios"
    else if "`_mc'" == "HR" local _methods_coef "Hazard ratios"
    else if "`_mc'" == "TR" local _methods_coef "Time ratios"
    else if "`_mc'" == "IRR" local _methods_coef "Incidence rate ratios"
    else if "`_mc'" == "RRR" local _methods_coef "Relative risk ratios"
    else if "`_mc'" == "SHR" local _methods_coef "Subhazard ratios"
    else if "`_mc'" == "RR" local _methods_coef "Risk ratios"
    else if "`_mc'" == "exp(b)" local _methods_coef "Exponentiated coefficients"
    else if "`_mc'" == "Coef." local _methods_coef "Coefficients"
    local _mnouns ""
    local _mn_n = 0
    local _madjs ""
    forvalues m = 1/`_meta_models' {
        * a cmdset without command metadata (a failed fit) names no model
        if `"`model_cmdline_`m''`model_cmd_`m''"' == "" continue
        _regtab_modelnoun "`model_cmdword_`m''" `"`model_optstr_`m''"' ///
            "`model_coef_`m''" "`model_prefix_`m''"
        local _seen = 0
        forvalues _j = 1/`_mn_n' {
            if `"`_mnoun_`_j''"' == `"`_mnoun'"' local _seen = 1
        }
        if !`_seen' {
            local ++_mn_n
            local _mnoun_`_mn_n' `"`_mnoun'"'
        }
        local _npred = 0
        if `m' <= `_sm_n' local _npred : word count `_sm_pred_`m''
        if `_npred' == 1 local _madjs "`_madjs' univariable"
        else if `_npred' > 1 local _madjs "`_madjs' multivariable"
    }
    local _madjs : list uniq _madjs
    local _madj ""
    local _na : word count `_madjs'
    if `_na' == 1 local _madj "`_madjs' "
    else if `_na' == 2 local _madj "univariable and multivariable "
    local _methods_model `"`_mnoun_1'"'
    forvalues _j = 2/`_mn_n' {
        if `_j' < `_mn_n' local _methods_model `"`_methods_model', `_mnoun_`_j''"'
        else if `_mn_n' == 2 local _methods_model `"`_methods_model' and `_mnoun_`_j''"'
        else local _methods_model `"`_methods_model', and `_mnoun_`_j''"'
    }
    local _methods `"`macval(_methods_coef)' with `_ci_level'% confidence intervals from `_madj'`_methods_model'`_methods_multi'."'
}
if `"`macval(_methods)'"' == "" {
    local _methods `"`macval(_methods_coef)' with `_ci_level'% confidence intervals from multivariable `_methods_model'`_methods_multi'."'
}
if "`stars'" != "" {
    local _methods `"`macval(_methods)' Statistical significance denoted as * p<`_sl1', ** p<`_sl2', *** p<`_sl3'."'
}
local _methods `"`macval(_methods)' Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."'
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end
