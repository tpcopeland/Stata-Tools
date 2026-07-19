*! gcomp Version 1.4.6  2026/07/19
*! G-computation formula via Monte Carlo simulation
*! Forked from SSC gformula v1.16 beta (Rhian Daniel, 2021)
*! with bug fixes, modernization, and SSC dependency removal
*! Author: Timothy P Copeland, Karolinska Institutet
*! Original author: Rhian Daniel
*!
*! Changes from SSC v1.16:
*!   - Refactored gformula_.ado internals into _gcomp_bootstrap_impl
*!   - Fixed hardcoded `by id:` bug (idvar not honored in survival/death)
*!   - Fixed broken baseline auto-detect with oce (backtick macro bug)
*!   - Eliminated global macro pollution and protected caller matrix state
*!   - Replaced SSC-era deprecated RNG calls with runiform()/rnormal()
*!   - Added double precision to gen statements
*!   - Inlined detangle/formatline/chkin (no more ice/SSC dependency)
*!   - Added version 16.0, set varabbrev off, set more off
/*------------------------------------------------------------*\ 
|  This .ado file fits Robins' G-computation formula (Robins   |
|   1986, Mathematical Modelling) to longitudinal datasets in  |
|   which the relationship between a time-varying exposure and |
|   an outcome of interest is potentially confounded by time-  |
|   varying confounders that are themselves affected by        |
|   previous levels of the exposure.                           |
|                                                              |
|  It can also be used (via the 'mediation' option) to         |
|   estimate controlled direct effects, and natural direct/    |
|   indirect effects, in datasets with an exposure (or         |
|   exposures), mediator(s), an outcome, and confounders of    |
|   the mediator-outcome relationship(s) that are themselves   |
|   affected by the exposure.                                  |
|                                                              |
|  The user specifies hypothetical interventions of interest   |
|   and Monte Carlo simulation is then used to generate how    |
|   the population would have looked under each intervention.  |
|   The parameters needed for the MC simulations are estimated |
|   from user-defined parametric models fitted to the observed |
|   data.                                                      |  
|                                                              |
|  If the outcome is binary or continuous, measured at the     |
|   end-of-follow up, the expected values of the potential     |
|   outcome under each intervention is estimated from the      |
|   simulated data. In addition, the parameters of a marginal  |
|   structural model may be estimated. The user specifies the  |
|   MSM of interest.                                           |
|                                                              |
|  If the outcome is time-to-event, the incidence rate and     |
|   cumulative incidence under each intervention are estimated |
|   from the simulated data. In addition, the parameters of a  |
|   marginal structural Cox model may be estimated. The user   |
|   specifies the MSCM of interest. Kaplan-Meier plots are     |
|   produced.                                                  |
|                                                              |
|  Estimates of precision and subsequent inferences are        |
|   obtained by bootstrapping.                                 |
|                                                              |
|  In the time-varying exposure setting, missing data due to   |
|   MAR (missing at random) dropout are dealt with implicitly. |
|   For intermittent patterns of missingness, a single         |
|   stochastic imputation method can be implemented.           |
|                                                              |
|  In the mediation setting, missing data can also be dealt    |
|   with using the single stochastic imputation method.        |
|                                                              |
|                                                              |
|                                                              |
|  Author: Rhian Daniel                                        |
|  Date: 21st May 2013                                         |
|  Version: 1.12 beta (original SSC)                            |
|                                                              |
|                                                              |
|                                                              | 
|  Acknowledgements: This macro uses the 'detangle' and        |
|   'formatlist' procedures used in ice.ado, by kind           |
|   permission of Patrick Royston. The macro is inspired by    |
|   the GCOMP macro in SAS written by Sarah Taubman         |
|   (Taubman et al 2009, IJE).                                 |
|   I am very grateful to Bianca De Stavola, Simon Cousens,    |
|   Daniela Zugna, Debbie Ford and Linda Harrison for spotting |
|   bugs, and suggesting improvements and additional features. |
|                                                              | 
|  Disclaimer: This .ado file may contain errors. If you spot  |
|   any, please let me know (Rhian.Daniel@LSHTM.ac.uk) and I   |
|   will endeavour to correct as soon as possible for a future |
|   version. Thank you.                                        |
\*------------------------------------------------------------*/

capture program drop gcomp
program define gcomp, eclass
version 16.0
local _gc_varabbrev = c(varabbrev)
set varabbrev off
* A failed estimation command must leave the caller's previously active e()
* result intact.  Hold before preserve so the hidden e(sample) marker is part
* of the data snapshot; discard the hold only after new gcomp results are
* posted successfully.
tempname _gc_caller_estimates
_estimates hold `_gc_caller_estimates', restore copy nullok
* The legacy engine still uses several literal matrix names internally.  Save
* any caller matrices under tempnames and restore them on every exit path.
local _gc_literal_matrices "b V se ci_normal ci_percentile ci_bc ci_bca _matrow matvis _gc_diag_result EPO catvals out_mlogit msm_params matem1 matem2"
local _gc_matrix_index 0
foreach _gc_matrix_name of local _gc_literal_matrices {
	local ++_gc_matrix_index
	tempname _gc_caller_matrix`_gc_matrix_index'
	capture confirm matrix `_gc_matrix_name'
	local _gc_had_matrix`_gc_matrix_index' = (_rc == 0)
	if `_gc_had_matrix`_gc_matrix_index'' {
		matrix `_gc_caller_matrix`_gc_matrix_index'' = `_gc_matrix_name'
	}
}
capture noisily {
syntax varlist(min=2 numeric) [if] [in] , OUTcome(varname) COMmands(string) EQuations(string) [Idvar(varname) ///
    Tvar(varname) VARyingcovariates(varlist) intvars(varlist) interventions(string) monotreat dynamic eofu pooled death(varname) ///
    derived(varlist) derrules(string) FIXedcovariates(varlist) LAGgedvars(varlist) lagrules(string) msm(string) ///
    mediation EXposure(varlist) mediator(varlist) control(string) baseline(string) alternative(string) base_confs(varlist) ///
    post_confs(varlist) impute(varlist) imp_eq(string) imp_cmd(string) imp_cycles(int 10) SIMulations(int 99999) ///
	    SAMples(int 1000) SEED(string) obe oce specific boceam linexp minsim moreMC logOR logRR all DIAGnostics graph saving(string) replace ///
	SAVEModels SHOWmodels MODELStyle(string)]
* --- Component-model capture (savemodels/showmodels): normalize options ---
if "`showmodels'"!="" local savemodels savemodels
if "`modelstyle'"=="" local modelstyle compact
if "`modelstyle'"!="" {
	local modelstyle = lower("`modelstyle'")
	if !inlist("`modelstyle'", "compact", "native") {
		noi di as err "modelstyle() must be compact or native"
		exit 198
	}
}
local _gc_cmdline `"gcomp `0'"'
local _gc_keepvars `varlist'
foreach _gc_varblock in outcome idvar tvar varyingcovariates intvars death derived fixedcovariates laggedvars exposure mediator base_confs post_confs impute {
	local _gc_keepvars `"`_gc_keepvars' ``_gc_varblock''"'
}
local _gc_keepvars : list uniq _gc_keepvars
preserve
tempvar _gc_original_obs _gc_esample
quietly gen long `_gc_original_obs'=_n
if "`in'"!="" {
	qui keep `in'
}
if "`if'"!="" {
	qui keep `if'
}
* Keep the selected observation rows, but retain all variables.  Equation and
* rule dependencies are allowed to be omitted from the positional varlist and
* are parsed/validated below before the internal reshape.
local if
local in

* Mode-shaping options are rejected before any package-side data mutation.
if "`mediation'"=="" & "`idvar'"=="" {
	noi di as err "idvar() is required for time-varying analysis"
	exit 198
}
if "`mediation'"=="" & "`tvar'"=="" {
	noi di as err "tvar() is required for time-varying analysis"
	exit 198
}
if "`mediation'"!="" & "`exposure'"=="" {
	noi di as err "exposure() is required with mediation"
	exit 198
}
if "`mediation'"!="" & "`mediator'"=="" {
	noi di as err "mediator() is required with mediation"
	exit 198
}
if "`mediation'"!="" & "`eofu'"!="" {
	noi di as err "eofu is not defined for mediation analysis"
	exit 198
}
if "`mediation'"!="" & "`graph'"!="" {
	noi di as err "graph is currently supported only for time-varying survival analyses"
	exit 198
}
if "`mediation'"=="" & "`eofu'"!="" & "`graph'"!="" {
	noi di as err "graph is not supported with eofu"
	exit 198
}
if "`mediation'"=="" & "`moreMC'"!="" {
	noi di as err "moreMC is currently supported only for mediation analysis"
	exit 198
}
if "`boceam'"!="" & "`msm'"=="" {
	noi di as err "boceam requires a supported msm() specification"
	exit 198
}
if "`seed'"!="" {
	capture confirm integer number `seed'
	if _rc {
		noi di as err "seed() must contain one integer"
		exit 198
	}
	if `seed' <= 0 {
		noi di as err "seed() must be a positive legal Stata seed"
		exit 198
	}
	capture set seed `seed'
	if _rc {
		noi di as err "seed(`seed') is outside Stata's legal seed domain"
		exit 198
	}
}
if `simulations'<1 {
	noi di as err "number of Monte Carlo simulations must be 1 or more"
	exit 198
}
if `samples'<2 {
	noi di as err "number of bootstrap samples must be 2 or more"
	exit 198
}
if `imp_cycles'<1 {
	noi di as err "number of imputation cycles must be 1 or more"
	exit 198
}
if "`mediation'"=="" {
	capture confirm numeric variable `idvar'
	if _rc {
		noi di as err "idvar() must be numeric; string identifiers are not supported"
		exit 109
	}
	capture confirm numeric variable `tvar'
	if _rc {
		noi di as err "tvar() must be numeric"
		exit 109
	}
	capture isid `idvar' `tvar'
	if _rc {
		noi di as err "idvar() and tvar() must uniquely identify one row per subject and visit"
		exit 459
	}
	quietly levelsof `tvar' if !missing(`tvar'), local(_gc_visit_levels)
	local _gc_n_visits : word count `_gc_visit_levels'
	if `_gc_n_visits' < 2 {
		noi di as err "time-varying analysis requires at least two observed visit values"
		exit 2000
	}
	foreach _gc_fixed of local fixedcovariates {
		tempvar _gc_fixed_min _gc_fixed_max
		quietly bysort `idvar': egen double `_gc_fixed_min' = min(`_gc_fixed')
		quietly bysort `idvar': egen double `_gc_fixed_max' = max(`_gc_fixed')
		quietly count if `_gc_fixed_min' != `_gc_fixed_max' & !missing(`_gc_fixed_min', `_gc_fixed_max')
		if r(N) {
			quietly summarize `idvar' if `_gc_fixed_min' != `_gc_fixed_max', meanonly
			noi di as err "fixedcovariates(): `_gc_fixed' varies within id `=r(min)'"
			exit 459
		}
	}
	sort `idvar' `tvar'
}
if "`mediation'"=="" {
	noi di
	noi di as text "G-computation procedure using Monte Carlo simulation: time-varying confounding"
}
else {
	noi di
	noi di as text "G-computation procedure using Monte Carlo simulation: mediation"
}
noi di
*drop observations that cannot be used because of missing data
tempvar missing
qui gen `missing'=0
if "`mediation'"=="" {
	local varlist_info=" "+"`idvar'"+" "+"`tvar'"+" "
	foreach var in `varlist_info' {
		if strmatch(" "+"`impute'"+" ","* `var' *")==1 {
			noi di as err "Missing values of " as text "`var'" as err " cannot be imputed."
			exit 198
		}
		qui count if `var'>=.
		qui replace `missing'=1 if `var'>=.
		if r(N)!=0 {
			noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
		}
	}
	qui tab `tvar', matrow(matvis)
	local maxv=rowsof(matvis)
	local maxvlab=matvis[`maxv',1]
	local firstv=matvis[1,1]
	foreach var in `intvars' {
		if strmatch(" "+"`impute'"+" ","* `var' *")==0 {
			if "`death'"=="" {
				qui count if `var'>=. & `tvar'!=`maxvlab'
				qui replace `missing'=1 if `var'>=. & `tvar'!=`maxvlab'
				if r(N)!=0 {
					noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
				}
			}
			else {
				qui count if `var'>=. & `tvar'!=`maxvlab' & `death'!=1
				qui replace `missing'=1 if `var'>=. & `tvar'!=`maxvlab' & `death'!=1
				if r(N)!=0 {
					noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
				}
			}
		}
	}
	foreach var in `fixedcovariates' {
		if strmatch(" "+"`impute'"+" ","* `var' *")==0 {
			if "`death'"=="" {
				qui count if `var'>=. & `tvar'!=`maxvlab'
				qui replace `missing'=1 if `var'>=. & `tvar'!=`maxvlab'
				if r(N)!=0 {
					noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
				}
			}
			else {
				qui count if `var'>=. & `tvar'!=`maxvlab' & `death'!=1
				qui replace `missing'=1 if `var'>=. & `tvar'!=`maxvlab' & `death'!=1
				if r(N)!=0 {
					noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
				}
			}
		}
	}
	if "`death'"!="" {
		local varlist2="`death'"+" "+"`outcome'"+" "+"`varyingcovariates'"+" "+"`intvars'"
		local nvar: word count `varlist2'
		_gcomp_detangle "`commands'" command "`varlist2'"
		forvalues i=1/`nvar' {
			local command`i' `"`r(value`i')'"'
		}
		if "`command1'"!="logit" {
			noi di as err "Error: death must be simulated from a sequence of logistic regressions." 
			exit 198
		}
		if strmatch(" "+"`impute'"+" ","* `death' *")==1 {
			noi di as err "Missing values of " as text "`death'" as err " cannot be imputed."
			exit 198
		}
		qui count if `death'>=. & `tvar'!=`firstv'
		qui replace `missing'=1 if `death'>=. & `tvar'!=`firstv'
		if r(N)!=0 {
			noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`death'" as err "." 
		}
	}
	foreach var in `varyingcovariates' {
		if strmatch(" "+"`impute'"+" ","* `var' *")==0 {
			if "`death'"=="" {
				qui count if `var'>=. & `tvar'!=`firstv' & `tvar'!=`maxvlab'
				qui replace `missing'=1 if `var'>=. & `tvar'!=`firstv' & `tvar'!=`maxvlab'
				if r(N)!=0 {
					noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
				}
			}
			else {
				qui count if `var'>=. & `tvar'!=`firstv' & `tvar'!=`maxvlab' & `death'!=1
				qui replace `missing'=1 if `var'>=. & `tvar'!=`firstv' & `tvar'!=`maxvlab' & `death'!=1
				if r(N)!=0 {
					noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
				}
			}
		}
	}
	* An end-of-follow-up outcome (eofu) is only observed at the final visit; its
	* intermediate-visit values are legitimately missing and are ignored by the
	* simulation engine. Requiring it at every non-first visit would drop those
	* intermediate rows and sever any lagged-confounder cascade (silently flat
	* effects with a continuous/regress outcome). In eofu mode require the
	* outcome only at the last visit; otherwise require it at every non-first visit.
	if "`eofu'"!="" {
		local _gc_out_visit "`tvar'==`maxvlab'"
	}
	else {
		local _gc_out_visit "`tvar'!=`firstv'"
	}
	if "`death'"!="" {
		if strmatch(" "+"`impute'"+" ","* `outcome' *")==1 {
			noi di as err "Missing values of " as text "`outcome'" as err " cannot be imputed."
			exit 198
		}
		qui count if `outcome'>=. & `_gc_out_visit' & `death'!=1
		qui replace `missing'=1 if `outcome'>=. & `_gc_out_visit' & `death'!=1
		if r(N)!=0 {
			noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`outcome'" as err "."
		}
	}
	else {
		if strmatch(" "+"`impute'"+" ","* `outcome' *")==1 {
			noi di as err "Missing values of " as text "`outcome'" as err " cannot be imputed."
			exit 198
		}
		qui count if `outcome'>=. & `_gc_out_visit'
		qui replace `missing'=1 if `outcome'>=. & `_gc_out_visit'
		if r(N)!=0 {
			noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`outcome'" as err "."
		}
	}
	if "`monotreat'"!="" {
		local nint_vars: word count `intvars'
		if `nint_vars'>1 {
			noi di as err "Error: the monotreat option can only be used with one binary intervention variable." 
			exit 198
		}
		if "`death'"=="" {
			local varlist2="`varyingcovariates'"+" "+"`intvars'"+" "+"`outcome'"
		}
		else {
			local varlist2="`death'"+" "+"`varyingcovariates'"+" "+"`intvars'"+" "+"`outcome'"
		}
		local nvar: word count `varlist2'
		_gcomp_detangle "`commands'" command "`varlist2'"
		forvalues i=1/`nvar' {
			local command`i' `"`r(value`i')'"'
		}
		local _gc_mono_var : word 1 of `intvars'
		local _gc_mono_pos : list posof "`_gc_mono_var'" in varlist2
		if `_gc_mono_pos'==0 | "`command`_gc_mono_pos''"!="logit" {
			noi di as err "Error: monotreat requires a logistic model for intervention variable `_gc_mono_var'."
			exit 198
		}
	}
}
else {
	foreach var in `exposure' {
		if strmatch(" "+"`impute'"+" ","* `var' *")==0 {
			qui count if `var'>=.
			qui replace `missing'=1 if `var'>=.
			if r(N)!=0 {
				noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
			}
		}
	}
	foreach var in `mediator' {
		if strmatch(" "+"`impute'"+" ","* `var' *")==0 {
			qui count if `var'>=.
			qui replace `missing'=1 if `var'>=.
			if r(N)!=0 {
				noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
			}
		}
	}
	foreach var in `base_confs' {
		if strmatch(" "+"`impute'"+" ","* `var' *")==0 {
			qui count if `var'>=.
			qui replace `missing'=1 if `var'>=.
			if r(N)!=0 {
				noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
			}
		}
	}
	foreach var in `post_confs' {
		if strmatch(" "+"`impute'"+" ","* `var' *")==0 {
			qui count if `var'>=.
			qui replace `missing'=1 if `var'>=.
			if r(N)!=0 {
				noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
			}
		}
	}
}
*this next part drops any further observations that need to be dropped because, despite containing observations to be imputed, 
*ALL variables needed for imputation are also missing
if "`impute'"!="" {
	tempvar missing2
	qui gen `missing2'=1
	local imp_nvar: word count `impute'
	_gcomp_detangle "`imp_eq'" imp_eq "`impute'"
	forvalues i=1/`imp_nvar' {
		local imp_eq`i' `"`r(value`i')'"'
	}
	forvalues i=1/`imp_nvar' {
		qui replace `missing2'=1
		local imp_var`i': word `i' of `impute'
		qui count if missing(`imp_var`i'')
		local _gc_imp_needed_`i' = r(N)
		* Resolve every imp_eq() predictor to its underlying variable(s) with fvunab/
		* fvrevar so factor-variable syntax (i.arm, ib2.arm, 2.arm, interactions) is
		* screened for donor availability instead of mis-parsing (ib#. -> r198;
		* #.var -> silently true).  Unexpandable terms error clearly and name imp_eq().
		local _gc_imp_pred`i' ""
		capture fvrevar `imp_eq`i'', list
		if _rc {
			noi di as err "imp_eq(): could not interpret predictor term(s) for `imp_var`i'': `imp_eq`i''"
			exit 198
		}
		local _gc_imp_pred`i' `r(varlist)'
		foreach var of local _gc_imp_pred`i' {
			qui replace `missing2'=0 if `var'<.
		}
		qui count if `missing2'==1 & missing(`imp_var`i'')
		local _gc_imp_dropped_`i' = r(N)
		local _gc_imp_eligible_`i' = `_gc_imp_needed_`i'' - `_gc_imp_dropped_`i''
		if r(N)!=0 {
			noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on all variables needed to impute " as text "`imp_var`i''" as err "." 
		}	
		qui drop if `missing2'==1 & missing(`imp_var`i'')
	}
}

qui drop if `missing'==1

if _N == 0 {
	noi di as err "Error: no observations remain after dropping missing data."
	exit 2000
}
if "`impute'"!="" {
	foreach _gc_iv of local impute {
		quietly count if !missing(`_gc_iv')
		if r(N)==0 {
			noi di as err "impute(): `_gc_iv' has no nonmissing donor values"
			exit 2000
		}
		if "`mediation'"=="" {
			quietly levelsof `tvar', local(_gc_imp_visits)
			foreach _gc_visit of local _gc_imp_visits {
				quietly count if missing(`_gc_iv') & `tvar'==`_gc_visit'
				local _gc_need = r(N)
				quietly count if !missing(`_gc_iv') & `tvar'==`_gc_visit'
				if `_gc_need'>0 & r(N)==0 {
					noi di as err "impute(): `_gc_iv' has no donor at visit `_gc_visit'"
					exit 2000
				}
			}
		}
	}
}
tempname _gc_sample_frame
frame put `_gc_original_obs', into(`_gc_sample_frame')
local _gc_N_rows = _N
drop `_gc_original_obs'

if "`mediation'"=="" {
	tempvar _gc_idtag
	qui egen byte `_gc_idtag' = tag(`idvar')
	qui count if `_gc_idtag'
	local maxid = r(N)
	drop `_gc_idtag'
	if `maxid'<`simulations'  {
		if `simulations'!=99999 {
			noi di as err "Warning: the number of MC simulations exceeds the sample size, which is not allowed."
			noi di as err "The number of MC simulations has been set to " as result `maxid' as err "."
		}
		local simulations=`maxid'
	}
	if `simulations'==99999 {
		local simulations=`maxid'
	}
	if "`logOR'"!="" | "`logRR'"!="" {
		noi di as err "Warning: options logOR and logRR are for use with the mediation option only and hence will be ignored."
	}
}
else {
	local maxid = _N
	if _N<`simulations' & "`moreMC'"=="" {
		if `simulations'!=99999 {
			noi di as err "Warning: the number of MC simulations exceeds the sample size, which is not allowed since you have not specified the -moreMC- option."
			noi di as err "The number of MC simulations has been set to " as result _N as err "."
		}
		local simulations=_N
	}
	if `simulations'==99999 {
		local simulations=_N
	}
	if "`logOR'"!="" & "`logRR'"!="" {
		noi di as err "Error: you cannot specify BOTH logOR and logRR."
		exit 198
	}
}
if "`mediation'"=="" & "`idvar'"=="" {
	noi di as err "Error: idvar() must be specified for a time-varying confounding analysis."
	exit 198
}
if "`mediation'"=="" & "`tvar'"=="" {
	noi di as err "Error: tvar() must be specified for a time-varying confounding analysis."
	exit 198
}
if "`mediation'"=="" & "`varyingcovariates'"=="" {
	noi di as text "Note: no varyingcovariates() supplied; running baseline-standardized g-computation (no post-baseline confounder simulation). Intervention and outcome are simulated forward over fixedcovariates() held at baseline."
}
if "`mediation'"=="" & "`intvars'"=="" {
	noi di as err "Error: intvars() must be specified for a time-varying confounding analysis."
	exit 198
}
if "`mediation'"=="" & "`interventions'"=="" {
	noi di as err "Error: interventions() must be specified for a time-varying confounding analysis."
	exit 198
}
if "`mediation'"=="" {
	* Validate every intervention component as executable Stata replace syntax
	* and require its assignment target to be an intervention variable.
	tokenize `"`interventions'"', parse(",")
	local _gc_pre_nint 0
	while `"`1'"'!="" {
		if `"`1'"'!="," {
			local ++_gc_pre_nint
			local _gc_pre_arm`_gc_pre_nint' `"`1'"'
		}
		mac shift
	}
	forvalues _gc_ai=1/`_gc_pre_nint' {
		tokenize `"`_gc_pre_arm`_gc_ai''"', parse("\")
		local _gc_ci 0
		while `"`1'"'!="" {
			if `"`1'"'!="\" {
				local ++_gc_ci
				local _gc_rule = strtrim(`"`1'"')
				local _gc_equal = strpos(`"`_gc_rule'"', "=")
				if `_gc_equal'<=1 {
					noi di as err `"interventions(): arm `_gc_ai' component `_gc_ci' is not an assignment: `_gc_rule'"'
					exit 198
				}
				local _gc_lhs = strtrim(substr(`"`_gc_rule'"', 1, `_gc_equal'-1))
				local _gc_is_intvar : list posof "`_gc_lhs'" in intvars
				if `_gc_is_intvar'==0 {
					noi di as err `"interventions(): assignment target `_gc_lhs' is not listed in intvars()"'
					exit 198
				}
				local _gc_rhs = strtrim(substr(`"`_gc_rule'"', `_gc_equal'+1, .))
				local _gc_ifpos = strpos(lower(`" `_gc_rhs' "'), " if ")
				if `_gc_ifpos'>0 local _gc_rhs = strtrim(substr(`"`_gc_rhs'"', 1, `_gc_ifpos'-1))
				if `"`_gc_rhs'"' == "`_gc_lhs'" {
					noi di as err `"interventions(): arm `_gc_ai' component `_gc_ci' is a no-op self-assignment: `_gc_rule'"'
					exit 198
				}
				_gcomp_apply_rule, rule(`"`_gc_rule'"') condition("if 0") context("interventions() arm `_gc_ai', component `_gc_ci'")
			}
			mac shift
		}
	}
}
if "`mediation'"!="" & "`exposure'"=="" {
	noi di as err "Error: With the mediation option, exposure() must be specified."
	exit 198
}
if "`mediation'"!="" & "`mediator'"=="" {
	noi di as err "Error: With the mediation option, mediator() must be specified."
	exit 198
}
if "`mediation'"!="" & "`baseline'"=="" & "`obe'"=="" & "`oce'"=="" & "`linexp'"=="" {
	noi di as err "Error: With the mediation option, either baseline(), obe, oce or linexp must be specified."
	exit 198
}
if "`mediation'"!="" & "`control'"!="" {
	local _gc_n_control : word count `mediator'
	if `_gc_n_control' > 1 & !strpos(`"`control'"', ":") {
		noi di as err "control() with multiple mediators must be keyed, e.g. control(m1: 0, m2: 1)"
		exit 198
	}
	capture noisily _gcomp_detangle `"`control'"' control `"`mediator'"'
	if _rc exit 198
	forvalues _gc_ci=1/`_gc_n_control' {
		local _gc_cv `"`r(value`_gc_ci')'"'
		local _gc_cmed : word `_gc_ci' of `mediator'
		local _gc_cn : word count `_gc_cv'
		if `"`_gc_cv'"'=="" | `_gc_cn' != 1 {
			noi di as err "control(): specify exactly one value for mediator `_gc_cmed'"
			exit 198
		}
		capture confirm number `_gc_cv'
		if _rc {
			noi di as err "control(): value for `_gc_cmed' must be numeric"
			exit 198
		}
		local _gc_control_value`_gc_ci' `_gc_cv'
	}
}
if "`boceam'"!="" {
	local _nmed: word count `mediator'
	if `_nmed' > 1 {
		noi di as err "Error: boceam (BOCE-AM) currently supports a single mediator; mediator() lists `_nmed'."
		noi di as err "       Specify a single mediator, or combine the mediators into one variable."
		exit 198
	}
	if "`msm'"=="" {
		noi di as err "Error: boceam requires msm(); ordinary mediation arms cannot be reused safely."
		exit 198
	}
}
if "`obe'"!="" | "`oce'"!="" | "`linexp'"!="" | "`specific'"!="" {
	local nexp: word count `exposure'
	if `nexp'>1 {
		noi di as err "Error: options obe, oce, specific or linexp cannot be specified when there is more than one exposure."
		exit 198
	}
}
if "`obe'"!="" & "`oce'"!="" {
	cap tab `exposure'
	if _rc==0 & r(r)>=2 {
		if r(r)==2 {
			noi di as err "Warning: You cannot specify both obe and oce. Your exposure variable appears to be binary; try dropping oce."
			exit 198
		}
		else {
			noi di as err "Warning: You cannot specify both obe and oce. Your exposure variable appears to be categorical; try dropping obe."
			exit 198
		}
	}
	else {
		noi di as err "Warning: You cannot specify both obe and oce."
		exit 198
	}
}
if "`obe'"!="" & "`specific'"!="" {
	noi di as err "Warning: You cannot specify both obe and specific."
	exit 198
}
if "`oce'"!="" & "`specific'"!="" {
	noi di as err "Warning: You cannot specify both oce and specific."
	exit 198
}
if "`linexp'"!="" & "`specific'"!="" {
	noi di as err "Warning: You cannot specify both linexp and specific."
	exit 198
}
if "`obe'"!="" & "`linexp'"!="" {
	cap tab `exposure'
	if _rc==0 & r(r)>=2 {
		if r(r)==2 {
			noi di as err "Warning: You cannot specify both obe and linexp. Your exposure variable appears to be binary; try dropping linexp."
			exit 198
		}
		else {
			noi di as err "Warning: You cannot specify both obe and linexp. Your exposure variable appears to be continuous; try dropping obe."
			exit 198		
		}
	}
	else {
		noi di as err "Warning: You cannot specify both obe and linexp."
		exit 198
	}
}
if "`oce'"!="" & "`linexp'"!="" {
	cap tab `exposure'
	if _rc==0 & r(r)<=50 {
		noi di as err "Warning: You cannot specify both oce and linexp. Your exposure variable appears to be categorical; try dropping linexp."
		exit 198
	}
	else {
		noi di as err "Warning: You cannot specify both oce and linexp."
		exit 198
	}
}
if "`mediation'"!="" & "`dynamic'"!="" {
	noi di as err "Warning: the dynamic option is not allowed with the mediation option. Try dropping it."
	exit 198
}
if "`mediation'"!="" & "`monotreat'"!="" {
	noi di as err "Warning: the monotreat option is not allowed with the mediation option. Try dropping it."
	exit 198
}
if "`msm'"!="" & "`dynamic'"!="" {
	noi di as err "Warning: the msm option is not available when comparing dynamic regimes. Try dropping it."
	exit 198
}
if "`mediation'"=="" & "`exposure'"!="" {
	noi di as err "Warning: exposure() only allowed with the mediation option. Try dropping it."
	exit 198
}
if "`mediation'"=="" & "`mediator'"!="" {
	noi di as err "Warning: mediator() only allowed with the mediation option. Try dropping it."
	exit 198
}
if "`mediation'"=="" & "`control'"!="" {
	noi di as err "Warning: control() only allowed with the mediation option. Try dropping it."
	exit 198
}
if "`mediation'"=="" & "`baseline'"!="" {
	noi di as err "Warning: baseline() only allowed with the mediation option. Try dropping it."
	exit 198
}
if "`mediation'"=="" & "`base_confs'"!="" {
	noi di as err "Warning: base_confs() only allowed with the mediation option. Try dropping it."
	exit 198
}
if "`mediation'"=="" & "`post_confs'"!="" {
	noi di as err "Warning: post_confs() only allowed with the mediation option. Try dropping it."
	exit 198
}
if "`obe'"!="" & "`mediation'"=="" {
	noi di as err "Warning: Option obe not relevant for the time-varying confounding analysis. Try dropping it."
	exit 198
}
if "`specific'"!="" & "`mediation'"=="" {
	noi di as err "Warning: Option specific not relevant for the time-varying confounding analysis. Try dropping it."
	exit 198
}
if "`oce'"!="" & "`mediation'"=="" {
	noi di as err "Warning: Option oce not relevant for the time-varying confounding analysis. Try dropping it."
	exit 198
}
if "`linexp'"!="" & "`mediation'"=="" {
	noi di as err "Warning: Option linexp not relevant for the time-varying confounding analysis. Try dropping it."
	exit 198
}
if "`obe'"!="" & "`baseline'"!="" {
	noi di as err "Warning: Option baseline() is irrelevant when obe is also specified. Try dropping it."
	exit 198
}
if "`specific'"!="" & ("`baseline'"=="" | "`alternative'"=="") {
	noi di as err "Warning: Options baseline() and alternative() must be specified when specific is also specified."
	exit 198
}
if "`linexp'"!="" & "`baseline'"!="" {
	noi di as err "Warning: Option baseline() is irrelevant when linexp is also specified. Try dropping it."
	exit 198
}
if "`oce'"!="" & "`baseline'"=="" {
	cap tab `exposure', matrow(_matrow)
	if _rc==0 {
		local _ass_bas=_matrow[1,1]
		noi di as err "Warning: Option baseline() has not been specified, and therefore the baseline will be assumed to be " as result `_ass_bas' as err "."
		local baseline "`exposure':`_ass_bas'"
	}
	else {
		noi di as err "Error: Option baseline() is required."
		exit 198
	}
}
if "`mediation'"!="" & "`baseline'"!="" & "`obe'"=="" & "`linexp'"=="" {
	local _gc_nbase : word count `exposure'
	capture noisily _gcomp_detangle `"`baseline'"' baseline `"`exposure'"'
	if _rc exit 198
	forvalues _gc_bi=1/`_gc_nbase' {
		local _gc_bvar : word `_gc_bi' of `exposure'
		local _gc_bval `"`r(value`_gc_bi')'"'
		capture confirm number `_gc_bval'
		if _rc {
			noi di as err "baseline(): value for `_gc_bvar' must be numeric"
			exit 198
		}
		quietly count if `_gc_bvar' == `_gc_bval'
		if r(N)==0 {
			noi di as err "baseline(): `_gc_bval' is not observed for exposure `_gc_bvar'"
			exit 459
		}
	}
}
if "`idvar'"!="" & "`mediation'"!="" {
	noi di as err "Warning: Option idvar() not relevant for the mediation analysis. Try dropping it."
	exit 198
}
if "`tvar'"!="" & "`mediation'"!="" {
	noi di as err "Warning: Option tvar() not relevant for the mediation analysis. Try dropping it."
	exit 198
}
if "`varyingcovariates'"!="" & "`mediation'"!="" {
	noi di as err "Warning: Option varyingcovariates() not relevant for the mediation analysis. Try dropping it."
	exit 198
}
if "`intvars'"!="" & "`mediation'"!="" {
	noi di as err "Warning: Option intvars() not relevant for the mediation analysis. Try dropping it."
	exit 198
}
if "`interventions'"!="" & "`mediation'"!="" {
	noi di as err "Warning: Option interventions() not relevant for the mediation analysis. Try dropping it."
	exit 198
}
if "`pooled'"!="" & "`mediation'"!="" {
	noi di as err "Warning: Option pooled not allowed for the mediation analysis. Try dropping it."
	exit 198
}
if "`death'"!="" & "`mediation'"!="" {
	noi di as err "Warning: Option death() not allowed for the mediation analysis. Try dropping it."
	exit 198
}
if "`fixedcovariates'"!="" & "`mediation'"!="" {
	noi di as err "Warning: Option fixedcovariates() not relevant for the mediation analysis. Try dropping it."
	exit 198
}
if "`laggedvars'"!="" & "`mediation'"!="" {
	noi di as err "Warning: Option laggedvars() not relevant for the mediation analysis. Try dropping it."
	exit 198
}
if "`lagrules'"!="" & "`mediation'"!="" {
	noi di as err "Warning: Option lagrules() not relevant for the mediation analysis. Try dropping it."
	exit 198
}
if "`mediation'"=="" {
	if "`msm'"!="" {
		if word("`msm'",1)!="logit" & word("`msm'",1)!="logi" & word("`msm'",1)!="reg" & word("`msm'",1)!="regr" ///
			& word("`msm'",1)!="regre" & word("`msm'",1)!="regres" & word("`msm'",1)!="regress" ///
			& word("`msm'",1)!="stcox" {
			noi di as err "Warning: The command " _cont
			noi di as result word("`msm'",1) _cont
			noi di as err " is not supported by gcomp.ado."
			exit 198
		}
	}
}
else {
	if "`msm'"!="" {
		if word("`msm'",1)!="logit" & word("`msm'",1)!="logi" & word("`msm'",1)!="reg" & word("`msm'",1)!="regr" ///
			& word("`msm'",1)!="regre" & word("`msm'",1)!="regres" & word("`msm'",1)!="regress" {
			noi di as err "Warning: The command " _cont
			noi di as result word("`msm'",1) _cont
			noi di as err " is not supported by gcomp.ado with the mediation option."
			exit 198
		}
	}
}
* === Input validation: commands/equations cross-check ===
if "`mediation'"=="" {
	if "`death'"=="" {
		local varlist2 "`varyingcovariates' `intvars' `outcome'"
	}
	else {
		local varlist2 "`death' `varyingcovariates' `intvars' `outcome'"
	}
}
else {
	local varlist2 "`post_confs' `mediator' `outcome'"
}
local nvar: word count `varlist2'
capture noisily _gcomp_detangle "`commands'" command "`varlist2'"
if _rc {
	noi di as err ""
	noi di as err "commands() must specify a model for each of these variables:"
	noi di as err "  `varlist2'"
	noi di as err ""
	noi di as err "Example: commands(`=word("`varlist2'",1)': logit, `=word("`varlist2'",2)': regress)"
	exit 198
}
forvalues i=1/`nvar' {
	local command`i' `"`r(value`i')'"'
}
forvalues i=1/`nvar' {
	local _v: word `i' of `varlist2'
	if "`command`i''"=="" {
		noi di as err "commands(): no model specified for `_v'"
		noi di as err "  Every variable that gcomp simulates needs a model command."
		noi di as err "  Add `_v': logit (or regress/mlogit/ologit) to commands()."
		exit 198
	}
}
capture noisily _gcomp_detangle "`equations'" equation "`varlist2'"
if _rc {
	noi di as err ""
	noi di as err "equations() must specify predictors for each of these variables:"
	noi di as err "  `varlist2'"
	noi di as err ""
	noi di as err "Example: equations(`=word("`varlist2'",1)': x1 x2, `=word("`varlist2'",2)': x1 x3)"
	exit 198
}
forvalues i=1/`nvar' {
	local equation`i' `"`r(value`i')'"'
}
forvalues i=1/`nvar' {
	local _v: word `i' of `varlist2'
	if "`equation`i''"=="" {
		noi di as err "equations(): no prediction equation specified for `_v'"
		noi di as err "  Every variable that gcomp simulates needs at least one predictor."
		noi di as err "  Add `_v': predictor1 predictor2 to equations()."
		exit 198
	}
}
forvalues i=1/`nvar' {
	local simvar`i': word `i' of `varlist2'
}
* Validate full Stata factor-variable syntax, collect all equation dependencies,
* and enforce the declared simulation order as a topological order.
unab _gc_dataset_vars : _all
local _gc_dependency_vars ""
forvalues i=1/`nvar' {
	local _v: word `i' of `varlist2'
	local _eq `"`equation`i''"'
	capture fvunab _gc_fv_terms : `_eq'
	if _rc {
		noi di as err `"equations(): invalid factor-variable equation for `_v': `_eq'"'
		exit 111
	}
	foreach _candidate of local _gc_dataset_vars {
		mata: st_local("_gc_dep_hit", strofreal(_gcomp_expression_uses_variable(st_local("_eq"), st_local("_candidate"))))
		if `_gc_dep_hit' {
			capture confirm numeric variable `_candidate'
			if _rc {
				noi di as err "equations(): string predictor `_candidate' is not supported"
				exit 109
			}
			local _gc_dependency_vars "`_gc_dependency_vars' `_candidate'"
		}
	}
	forvalues _j=`i'/`nvar' {
		local _later : word `_j' of `varlist2'
		mata: st_local("_gc_dep_hit", strofreal(_gcomp_expression_uses_variable(st_local("_eq"), st_local("_later"))))
		if `_gc_dep_hit' {
			if `_j'==`i' {
				noi di as err "equations(): `_v' appears in its own equation"
				exit 198
			}
			* Intervention nodes are assigned by interventions() before the
			* counterfactual predictions for a visit.  A death/covariate model
			* may therefore use a declared intervention even when the internal
			* component-model list places that intervention later.  Ordinary
			* simulated nodes must still form the declared acyclic order.
			local _gc_policy_node : list posof "`_later'" in intvars
			if "`mediation'"=="" & `_gc_policy_node' continue
			noi di as err "equations(): `_v' depends on later simulated variable `_later'; reorder the variables"
			exit 198
		}
	}
}
local _gc_dependency_vars : list uniq _gc_dependency_vars
local varlist "`varlist' `_gc_keepvars' `_gc_dependency_vars'"
local varlist : list uniq varlist
* Command <-> variable type consistency
forvalues i=1/`nvar' {
	local _v: word `i' of `varlist2'
	local _cmd "`command`i''"
	if !inlist("`_cmd'", "logit", "regress", "mlogit", "ologit") {
		noi di as err "commands(): `_cmd' is not a supported model command for `_v'"
		noi di as err "  Supported commands: logit, regress, mlogit, ologit"
		exit 198
	}
	if "`_cmd'" == "logit" {
		quietly count if !missing(`_v') & !inlist(`_v', 0, 1)
		if r(N) {
			noi di as err "commands(): logit outcome `_v' must be coded exactly 0/1"
			exit 459
		}
		quietly count if `_v'==0
		local _gc_has0 = r(N)>0
		quietly count if `_v'==1
		local _gc_has1 = r(N)>0
		if !`_gc_has0' | !`_gc_has1' {
			noi di as err "commands(): logit outcome `_v' must contain both 0 and 1"
			exit 2000
		}
	}
	if "`_cmd'" == "regress" {
		* Robust binary check (see logit branch above): `tabulate' would error
		* r(134) on a continuous regress-modeled covariate at moderate N.
		qui count if `_v' < . & `_v' != 0 & `_v' != 1
		local _n_non01 = r(N)
		qui count if `_v' < .
		if `_n_non01' == 0 & r(N) > 0 {
			qui summ `_v' if `_v' < .
			if r(min) == 0 & r(max) == 1 {
				noi di as text "  Note: `_v' appears binary (0/1) but is modeled with regress."
				noi di as text "  This is valid (linear probability model) but logit is more common."
			}
		}
	}
}
if "`obe'"!="" {
	quietly count if !missing(`exposure') & !inlist(`exposure', 0, 1)
	if r(N) {
		noi di as err "obe requires exposure(`exposure') to be coded exactly 0/1"
		exit 459
	}
	quietly count if `exposure'==0
	local _gc_obe0 = r(N)>0
	quietly count if `exposure'==1
	local _gc_obe1 = r(N)>0
	if !`_gc_obe0' | !`_gc_obe1' {
		noi di as err "obe requires both exposure levels 0 and 1"
		exit 2000
	}
}
if "`death'"!="" {
	quietly count if !missing(`death') & !inlist(`death', 0, 1)
	if r(N) {
		noi di as err "death() must be coded exactly 0/1"
		exit 459
	}
	tempvar _gc_prior_death
	sort `idvar' `tvar'
	quietly by `idvar': gen long `_gc_prior_death' = sum(`death'==1) - (`death'==1)
	quietly count if `_gc_prior_death'>0 & !missing(`death')
	if r(N) {
		noi di as err "death() contains observations after an earlier death event"
		exit 459
	}
}
if "`monotreat'"!="" {
	local _gc_monovar : word 1 of `intvars'
	local _gc_monopos : list posof "`_gc_monovar'" in varlist2
	if "`command`_gc_monopos''" != "logit" {
		noi di as err "monotreat requires a logistic model for intervention variable `_gc_monovar'"
		exit 198
	}
	quietly count if !missing(`_gc_monovar') & !inlist(`_gc_monovar', 0, 1)
	if r(N) {
		noi di as err "monotreat intervention `_gc_monovar' must be coded exactly 0/1"
		exit 459
	}
	tempvar _gc_prior_treat
	sort `idvar' `tvar'
	quietly by `idvar': gen long `_gc_prior_treat' = sum(`_gc_monovar'==1) - (`_gc_monovar'==1)
	quietly count if `_gc_prior_treat'>0 & `_gc_monovar'==0
	if r(N) {
		noi di as err "monotreat requires histories that remain treated after initiation"
		exit 459
	}
}
if "`control'"!="" {
	forvalues _gc_ci=1/`_gc_n_control' {
		local _gc_cmed : word `_gc_ci' of `mediator'
		local _gc_cval `_gc_control_value`_gc_ci''
		local _gc_cpos : list posof "`_gc_cmed'" in varlist2
		local _gc_ccmd "`command`_gc_cpos''"
		if inlist("`_gc_ccmd'", "logit", "mlogit", "ologit") {
			quietly count if `_gc_cmed'==`_gc_cval'
			if r(N)==0 {
				noi di as err "control(): value `_gc_cval' is outside observed support for `_gc_cmed'"
				exit 459
			}
		}
	}
}
* Mediation-specific validation
if "`mediation'" != "" {
	foreach _exp in `exposure' {
		local _found: list posof "`_exp'" in base_confs
		if `_found' > 0 {
			noi di as err "base_confs() includes the exposure variable `_exp'"
			noi di as err "  Baseline confounders should be pre-exposure variables only."
			noi di as err "  Remove `_exp' from base_confs()."
			exit 198
		}
	}
	foreach _med in `mediator' {
		local _found: list posof "`_med'" in base_confs
		if `_found' > 0 {
			noi di as err "base_confs() includes the mediator variable `_med'"
			noi di as err "  Baseline confounders should not include the mediator."
			noi di as err "  Remove `_med' from base_confs()."
			exit 198
		}
	}
	foreach _bc in `base_confs' {
		local _found: list posof "`_bc'" in varlist2
		if `_found' > 0 {
			noi di as err "base_confs() variable `_bc' also appears in the simulation variable list"
			noi di as err "  Baseline confounders are not re-simulated. If `_bc' is post-treatment,"
			noi di as err "  move it to post_confs() instead."
			exit 198
		}
	}
}
* Time-varying-specific validation
if "`mediation'" == "" {
	foreach _iv in `intvars' {
		local _found: list posof "`_iv'" in varlist
		if `_found' == 0 {
			noi di as err "intvars(): variable `_iv' is not in the main varlist"
			noi di as err "  Add `_iv' to the variable list after the gcomp command name."
			exit 198
		}
	}
	if "`laggedvars'" != "" {
		local _nlag: word count `laggedvars'
		capture _gcomp_detangle "`lagrules'" lagrule "`laggedvars'"
		if _rc {
			noi di as err "lagrules(): could not parse lag rules for laggedvars(`laggedvars')"
			noi di as err "  Syntax: lagrules(lagvar1: sourcevar1 1, lagvar2: sourcevar2 2)"
			exit 198
		}
		forvalues _li=1/`_nlag' {
			if `"`r(value`_li')'"' != "" {
				tokenize `"`r(value`_li')'"', parse(" ")
				local _lagsrc "`1'"
				capture confirm variable `_lagsrc'
				if _rc {
					local _lagv: word `_li' of `laggedvars'
					noi di as err "lagrules(): source variable `_lagsrc' for lag of `_lagv' does not exist"
					exit 111
				}
			}
		}
	}
	if "`derived'" != "" {
		capture _gcomp_detangle "`derrules'" derrule "`derived'"
		if _rc {
			noi di as err "derrules(): could not parse derivation rules for derived(`derived')"
			noi di as err "  Syntax: derrules(derivedvar1: expression1, derivedvar2: expression2)"
			exit 198
		}
		local _gc_nder : word count `derived'
		forvalues _di=1/`_gc_nder' {
			local _gc_dvar : word `_di' of `derived'
			local _gc_dexpr `"`r(value`_di')'"'
			if `"`_gc_dexpr'"'=="" {
				noi di as err "derrules(): no derivation rule specified for `_gc_dvar'"
				exit 198
			}
			* Derived variables are recalculated in the declared order.  A rule
			* may use an earlier derived value but cannot depend on itself or a
			* later rule, which would otherwise leave stale/cyclic state.
			forvalues _dj=`_di'/`_gc_nder' {
				local _gc_later_dvar : word `_dj' of `derived'
			mata: st_local("_gc_dep_hit", strofreal(_gcomp_expression_uses_variable(st_local("_gc_dexpr"), st_local("_gc_later_dvar"))))
			if `_gc_dep_hit' {
					if `_dj'==`_di' noi di as err "derrules(): `_gc_dvar' cannot depend on itself"
					else noi di as err "derrules(): `_gc_dvar' depends on later derived variable `_gc_later_dvar'; reorder derived()"
					exit 198
				}
			}
			_gcomp_apply_rule, rule(`"`_gc_dvar'=`_gc_dexpr'"') condition("if 0") context("derrules() for `_gc_dvar'")
		}
	}
}
* Imputation-specific validation
if "`impute'" != "" {
	local _gc_imp_unique : list uniq impute
	local _gc_imp_n : word count `impute'
	local _gc_imp_un : word count `_gc_imp_unique'
	if `_gc_imp_n' != `_gc_imp_un' {
		noi di as err "impute() contains duplicate target variables"
		exit 198
	}
	if "`mediation'"=="" local _gc_imp_allowed "`varyingcovariates' `fixedcovariates' `derived' `laggedvars'"
	else local _gc_imp_allowed "`mediator' `base_confs' `post_confs'"
	foreach _gc_iv of local impute {
		local _gc_allowed : list posof "`_gc_iv'" in _gc_imp_allowed
		if `_gc_allowed'==0 {
			noi di as err "impute(): `_gc_iv' is not an eligible covariate or mediator target"
			exit 198
		}
	}
	if "`imp_cmd'" == "" {
		noi di as err "impute() specified but imp_cmd() is missing"
		noi di as err "  Specify the model command for each imputed variable."
		exit 198
	}
	if "`imp_eq'" == "" {
		noi di as err "impute() specified but imp_eq() is missing"
		noi di as err "  Specify the prediction equation for each imputed variable."
		exit 198
	}
	local _imp_nvar: word count `impute'
	capture _gcomp_detangle "`imp_cmd'" imp_cmd "`impute'"
	if _rc {
		noi di as err "imp_cmd() must specify a model for each variable in impute(`impute')"
		exit 198
	}
	forvalues _ii=1/`_imp_nvar' {
		local _imp_c `"`r(value`_ii')'"'
		local _gc_imp_command_`_ii' `"`_imp_c'"'
		if "`_imp_c'"=="" {
			local _imp_v: word `_ii' of `impute'
			noi di as err "imp_cmd(): no model specified for `_imp_v'"
			exit 198
		}
		if !inlist("`_imp_c'", "logit", "regress", "mlogit", "ologit") {
			local _imp_v: word `_ii' of `impute'
			noi di as err "imp_cmd(): `_imp_c' is not a supported imputation command for `_imp_v'"
			noi di as err "  Supported: logit, regress, mlogit, ologit"
			exit 198
		}
		local _imp_v: word `_ii' of `impute'
		if "`_imp_c'"=="logit" {
			quietly count if !missing(`_imp_v') & !inlist(`_imp_v', 0, 1)
			if r(N) {
				noi di as err "imp_cmd(): logit target `_imp_v' must be coded exactly 0/1"
				exit 459
			}
			quietly count if `_imp_v'==0
			local _gc_imp_has0 = r(N)>0
			quietly count if `_imp_v'==1
			local _gc_imp_has1 = r(N)>0
			if !`_gc_imp_has0' | !`_gc_imp_has1' {
				noi di as err "imp_cmd(): logit target `_imp_v' needs nonmissing donors at both 0 and 1"
				exit 2000
			}
		}
		if inlist("`_imp_c'", "mlogit", "ologit") {
			quietly levelsof `_imp_v' if !missing(`_imp_v'), local(_gc_imp_levels)
			local _gc_imp_nlevels : word count `_gc_imp_levels'
			if `_gc_imp_nlevels'<2 {
				noi di as err "imp_cmd(): `_imp_c' target `_imp_v' needs at least two observed donor levels"
				exit 2000
			}
		}
	}
	capture _gcomp_detangle "`imp_eq'" imp_eq "`impute'"
	if _rc {
		noi di as err "imp_eq() must specify one equation for each imputation target"
		exit 198
	}
	forvalues _ii=1/`_imp_nvar' {
		local _imp_v: word `_ii' of `impute'
		local _imp_e `"`r(value`_ii')'"'
		if `"`_imp_e'"'=="" {
			noi di as err "imp_eq(): no equation specified for `_imp_v'"
			exit 198
		}
		capture fvunab _gc_imp_fv : `_imp_e'
		if _rc {
			noi di as err `"imp_eq(): invalid equation for `_imp_v': `_imp_e'"'
			exit 111
		}
		mata: st_local("_gc_dep_hit", strofreal(_gcomp_expression_uses_variable(st_local("_imp_e"), st_local("_imp_v"))))
		if `_gc_dep_hit' {
			noi di as err "imp_eq(): `_imp_v' cannot predict itself"
			exit 198
		}
	}
}
* === End input validation ===
noi di
noi di as text "   Outcome variable: " _cont
noi di as result "`outcome'"
if "`mediation'"=="" {
	noi di as text "   Intervention variable(s): " _cont
	noi di as result "`intvars'"
	noi di as text "   Outcome type: " _cont
	if "`eofu'"=="" {
		noi di as result "survival"
	}
	else {
		tempvar out_check
		qui gen double `out_check'=`outcome'*(1-`outcome')
		qui summ `out_check'
		if r(mean)==0 {
			noi di as result "binary, measured at end of follow-up"
		}
		else {
			noi di as result "continuous, measured at end of follow-up"
		}
		drop `out_check'
	}
}
else {
	noi di as text "   Exposure variable(s): " _cont
	noi di as result "`exposure'"
	noi di as text "   Mediator variable(s): " _cont
	noi di as result "`mediator'"
}
noi di as text "   Size of MC sample: " _cont
noi di as result "`simulations'"
noi di as text "   No. of bootstrap samples: " _cont
noi di as result "`samples'"
noi di
noi di as text _n "   A summary of the specified parametric models:"
noi di as text _n "   (for simulation under different interventions)"
local longstring 55
local off 16
noi di as text _n "      Variable {c |} Command {c |} Prediction equation" _n ///
	 "   {hline 12}{c +}{hline 9}{c +}{hline `longstring'}"
forvalues i=1/`nvar' {
	local eq `equation`i''
	if "`eq'"=="" {
		local eq "null"
	}
	_gcomp_formatline, n(`eq') maxlen(`longstring')
	local nlines=r(lines)
	forvalues j=1/`nlines' {
		if `j'==1 noi di as text "   " %11s abbrev("`simvar`i''",11) ///
			 " {c |} " %-8s "`command`i''" "{c |} `r(line`j')'"
		else noi di as text _col(`off') ///
			 "{c |}" _col(26) "{c |} `r(line`j')'"
	}
}
noi di as text "   {hline 12}{c BT}{hline 9}{c BT}{hline `longstring'}"
noi di
noi di
* === Component-model capture (savemodels/showmodels) ===
* Refit each simulation specification once on the analytic sample (data is
* still in original long form here).  These are explicitly labelled refit
* approximations: nonpooled visit-specific fits and loop-created variables
* cannot be reconstructed faithfully outside the simulation engine.
local _gc_n_models 0
if "`savemodels'"!="" {
	quietly estimates dir
	local _gc_existing_estimates "`r(names)'"
	local _gc_model_stub ""
	forvalues _gc_stub_try = 1/100 {
		tempname _gc_model_token
		local _gc_model_suffix = substr("`_gc_model_token'", 3, 8)
		local _gc_candidate_stub "_gcmp`_gc_model_suffix'"
		local _gc_stub_collision 0
		forvalues _gc_stub_i = 1/`nvar' {
			local _gc_candidate_name "`_gc_candidate_stub'_`_gc_stub_i'"
			local _gc_hit : list posof "`_gc_candidate_name'" in _gc_existing_estimates
			if `_gc_hit' local _gc_stub_collision 1
		}
		if !`_gc_stub_collision' {
			local _gc_model_stub "`_gc_candidate_stub'"
			continue, break
		}
	}
	if "`_gc_model_stub'" == "" {
		noi di as err "savemodels could not allocate collision-free stored-estimate names"
		exit 110
	}
	local _gc_refit_panelopts ""
	if "`idvar'" != "" local _gc_refit_panelopts "`_gc_refit_panelopts' idvar(`idvar')"
	if "`tvar'" != "" local _gc_refit_panelopts "`_gc_refit_panelopts' tvar(`tvar')"
	if "`intvars'" != "" local _gc_refit_panelopts "`_gc_refit_panelopts' intvars(`intvars')"
	capture noisily _gcomp_refit_models, vars(`varlist2') ///
		commands(`commands') equations(`equations') stub(`_gc_model_stub') ///
		analysis(`=cond("`mediation'"!="","mediation","time_varying")') `pooled' ///
		`_gc_refit_panelopts' `monotreat'
	if _rc {
		local _gc_model_rc = _rc
		noi di as err "savemodels failed while constructing explicitly labelled refit approximations"
		exit `_gc_model_rc'
	}
	else {
		local _gc_n_models     = r(n_models)
		local _gc_model_names   "`r(model_names)'"
		local _gc_model_cmds    "`r(model_cmds)'"
		local _gc_model_depvars "`r(model_depvars)'"
		local _gc_model_skipped "`r(skipped)'"
		forvalues _gck = 1/`_gc_n_models' {
			local _gc_model_eq_`_gck' "`r(model_eq_`_gck')'"
		}
		if "`_gc_model_skipped'"!="" {
			noi di as text "   Note: component-model capture skipped (predictors unavailable at fit time): " as result "`_gc_model_skipped'"
		}
		noi di as text "   Note: savemodels stores analytic-sample refit approximations, not the exact simulation-loop fits."
		if "`showmodels'"!="" & `_gc_n_models'>0 {
			_gcomp_display_models, names(`_gc_model_names') style(`modelstyle') digits(4)
		}
	}
}
if "`impute'"!="" {
	* Display in a table the parametric models that have been specified for imputation
	local imp_nvar: word count `impute'
	* _gcomp_detangle imputation commands
	_gcomp_detangle "`imp_cmd'" imp_cmd "`impute'"
	forvalues i=1/`imp_nvar' {
		local imp_cmd`i' `"`r(value`i')'"'
	}
	* _gcomp_detangle imputation equations
	_gcomp_detangle "`imp_eq'" imp_eq "`impute'"
	forvalues i=1/`imp_nvar' {
		local imp_eq`i' `"`r(value`i')'"'
	}
	forvalues i=1/`imp_nvar' {
		local imp_var`i': word `i' of `impute'
	}
	noi di as text _n "   A summary of the specified parametric models:"
	noi di as text _n "   (for imputation of missing values)"
	local longstring 55
	local off 16
	noi di as text _n "      Variable {c |} Command {c |} Prediction equation" _n ///
		 "   {hline 12}{c +}{hline 9}{c +}{hline `longstring'}"
	forvalues i=1/`imp_nvar' {
		local imp_eq_disp `imp_eq`i''
		if "`imp_eq_disp'"=="" {
			local imp_eq_disp "null"
		}
		_gcomp_formatline, n(`imp_eq_disp') maxlen(`longstring')
		local nlines=r(lines)
		forvalues j=1/`nlines' {
			if `j'==1 noi di as text "   " %11s abbrev("`imp_var`i''",11) ///
				 " {c |} " %-8s "`imp_cmd`i''" "{c |} `r(line`j')'"
			else noi di as text _col(`off') ///
				 "{c |}" _col(26) "{c |} `r(line`j')'"
		}
	}
	noi di as text "   {hline 12}{c BT}{hline 9}{c BT}{hline `longstring'}"
	noi di
	noi di
}

local _gc_check_delete = 0
local _gc_check_print = 0
local _gc_check_save = 0
if "`saving'"!="" {
	local _gc_check_save = 1
}

* All option/equation dependencies have now been resolved into varlist.
* Remove unrelated caller variables from the preserved working copy before
* reshape; they cannot be constant-by-ID by assumption and are restored on
* every exit.  The original-row marker has already been copied to its frame.
quietly keep `varlist'

local originallist "varlist varlist2 if in outcome commands equations idvar tvar varyingcovariates intvars interventions eofu pooled death derived derrules fixedcovariates laggedvars lagrules msm mediation exposure mediator control baseline alternative base_confs post_confs impute imp_eq imp_cmd imp_cycles simulations samples seed all graph"
foreach member of local originallist {
	local original`member' "``member''"
}
	* Map every working variable to a collision-free tempvar.  The mapping is
	* independent of user-name length and supports factor/interactions because
	* expressions are rewritten token by token rather than by suffixing names.
	local _gc_original_names "`varlist'"
	local _gc_alias_names ""
	if "`saving'"!="" {
		foreach _gc_reserved in _int _id _source_id {
			local _gc_reserved_hit : list posof "`_gc_reserved'" in _gc_original_names
			if `_gc_reserved_hit' {
				noi di as err "saving(): variable name `_gc_reserved' is reserved by the saved-data schema"
				exit 110
			}
		}
	}
	foreach _gc_original of local _gc_original_names {
		tempvar _gc_alias
		rename `_gc_original' `_gc_alias'
		local _gc_alias_names "`_gc_alias_names' `_gc_alias'"
	}
	local _gc_alias_names : list retokenize _gc_alias_names

	* The first token of msm() is a Stata command, not a variable reference.  It
	* must not be rewritten when a legal caller variable happens to share that
	* name (for example, a covariate named regress).
	local _gc_msm_command ""
	local _gc_msm_rest ""
	if `"`msm'"' != "" {
		gettoken _gc_msm_command _gc_msm_rest : msm
	}
	local listofstrings "varlist varlist2 outcome idvar tvar varyingcovariates intvars interventions death derived derrules fixedcovariates laggedvars lagrules exposure mediator base_confs post_confs impute control baseline alternative"
	foreach currstring of local listofstrings {
		mata: st_local("`currstring'", _gcomp_alias_expression(st_local("`currstring'"), st_local("_gc_original_names"), st_local("_gc_alias_names")))
	}
	if `"`_gc_msm_command'"' != "" {
		mata: st_local("_gc_msm_rest", _gcomp_alias_expression(st_local("_gc_msm_rest"), st_local("_gc_original_names"), st_local("_gc_alias_names")))
		local msm `"`_gc_msm_command' `_gc_msm_rest'"'
	}

	* Rebuild keyed command/equation maps so model-command words are never
	* mistaken for variable identifiers during alias rewriting.
	local commands ""
	local equations ""
	forvalues i=1/`nvar' {
		local _gc_old_dep : word `i' of `originalvarlist2'
		local _gc_new_dep "`_gc_old_dep'"
		local _gc_new_eq `"`equation`i''"'
		mata: st_local("_gc_new_dep", _gcomp_alias_expression(st_local("_gc_new_dep"), st_local("_gc_original_names"), st_local("_gc_alias_names")))
		mata: st_local("_gc_new_eq", _gcomp_alias_expression(st_local("_gc_new_eq"), st_local("_gc_original_names"), st_local("_gc_alias_names")))
		if `i'==1 {
			local commands `"`_gc_new_dep': `command`i''"'
			local equations `"`_gc_new_dep': `_gc_new_eq'"'
		}
		else {
			local commands `"`commands', `_gc_new_dep': `command`i''"'
			local equations `"`equations', `_gc_new_dep': `_gc_new_eq'"'
		}
	}
	if "`impute'"!="" {
		local imp_cmd ""
		local imp_eq ""
		forvalues i=1/`imp_nvar' {
			local _gc_old_imp : word `i' of `originalimpute'
			local _gc_new_imp "`_gc_old_imp'"
			local _gc_new_ieq `"`imp_eq`i''"'
			mata: st_local("_gc_new_imp", _gcomp_alias_expression(st_local("_gc_new_imp"), st_local("_gc_original_names"), st_local("_gc_alias_names")))
			mata: st_local("_gc_new_ieq", _gcomp_alias_expression(st_local("_gc_new_ieq"), st_local("_gc_original_names"), st_local("_gc_alias_names")))
			if `i'==1 {
				local imp_cmd `"`_gc_new_imp': `imp_cmd`i''"'
				local imp_eq `"`_gc_new_imp': `_gc_new_ieq'"'
			}
			else {
				local imp_cmd `"`imp_cmd', `_gc_new_imp': `imp_cmd`i''"'
				local imp_eq `"`imp_eq', `_gc_new_imp': `_gc_new_ieq'"'
			}
		}
	}
if `simulations'<1 {
	noi di as err "number of Monte Carlo simulations must be 1 or more"
	exit 198
}
if `samples'<2 {
	noi di as err "number of bootstrap samples must be 2 or more"
	exit 198
}
if `imp_cycles'<1 {
	noi di as err "number of imputation cycles must be 1 or more"
	exit 198
}
if "`all'"!="" {
	local bca="bca"
}
if "`seed'"!="" set seed `seed'
local _gc_rngstate_initial `"`c(rngstate)'"'
tempname _gc_run_token
local _gc_run_id `"gcomp-`c(current_date)'-`c(current_time)'-`_gc_run_token'"'
local _gc_graph_name "gcomp`=substr("`_gc_run_token'",3,8)'"

*now, for the time-varying confounding option, we must reshape the dataset into wide format so that the 
*bootstrapping is done at the subject level, rather than the observation level
if "`mediation'"=="" {
	tokenize "`varlist'"
	local i=1
	while "`1'"!="" {
		if "`1'"!=rtrim(ltrim("`idvar'")) & "`1'"!=rtrim(ltrim("`tvar'")) {
			local bit_`i' "`1'"
			local i=`i'+1
		}
		mac shift
	}
	local i=`i'-1
	local _gc_almost_varlist ""
	forvalues j=1(1)`i' {
		local _gc_almost_varlist "`_gc_almost_varlist' `bit_`j''"
	}
	qui reshape wide `_gc_almost_varlist', i(`idvar') j(`tvar')
	qui gen double `tvar'=.
	foreach pastvar of local _gc_almost_varlist {
		qui gen double `pastvar'=.
	}
}
capture matrix drop _gc_diag_result
if "`diagnostics'" != "" {
	local _gc_diag_show "gcdiagshow"
}
_gcomp_bootstrap_impl `varlist' `if' `in', out(`outcome') com(`commands') eq(`equations') i(`idvar') t(`tvar') ///
	var(`varyingcovariates') intvars(`intvars') interventions(`interventions') `monotreat' `eofu' `pooled' death(`death') ///
	derived(`derived') derrules(`derrules') fix(`fixedcovariates') lag(`laggedvars') lagrules(`lagrules') ///
	msm(`msm') `mediation' ex(`exposure') mediator(`mediator') control(`control') baseline(`baseline') alternative(`alternative') ///
	base_confs(`base_confs') post_confs(`post_confs') impute(`impute') imp_eq(`imp_eq') imp_cmd(`imp_cmd') ///
	imp_cycles(`imp_cycles') sim(`simulations') `obe' `oce' `specific' `boceam' `linexp' `minsim' `moreMC' `logOR' `logRR' `graph' saving(`"`saving'"') `replace' ///
	_gc_maxid(`maxid') _gc_chk_del(`_gc_check_delete') _gc_chk_prt(`_gc_check_print') _gc_chk_sav(`_gc_check_save') _gc_almost(`_gc_almost_varlist') ///
	_gc_origvars(`"`_gc_original_names'"') _gc_runid(`"`_gc_run_id'"') _gc_rngstate(`"`_gc_rngstate_initial'"') ///
	_gc_graphname(`_gc_graph_name') gcdiagnostics `_gc_diag_show'
local _gc_saved_arm_schema `"`r(saved_arm_schema)'"'
* Display diagnostics summary if requested
if "`diagnostics'" != "" {
	capture confirm matrix _gc_diag_result
	if _rc == 0 {
		local _diag_nrows = rowsof(_gc_diag_result)
		noi di
		noi di as text "{hline 78}"
		noi di as text "Model diagnostics (initial estimation, pre-bootstrap)"
		noi di as text "{hline 78}"
		local _any_nc = 0
		forvalues _di=1/`_diag_nrows' {
			if _gc_diag_result[`_di', 2] == 0 {
				local _any_nc = 1
			}
		}
		if `_any_nc' {
			noi di as err ""
			noi di as err ">>> One or more models did not converge. Examine the equations."
			noi di as err "    Non-convergence in the initial fit will propagate to bootstrap CIs."
		}
		noi di as text "{hline 78}"
		noi di
	}
}
* Save diagnostics matrix for later e() posting
tempname _gc_diag_saved
capture confirm matrix _gc_diag_result
if _rc == 0 {
	matrix `_gc_diag_saved' = _gc_diag_result
	capture matrix drop _gc_diag_result
}

if "`mediation'"=="" {
	local _b=""
	if "`msm'"!="" {
		local r1=r(N_msm_params)
		local colnames "`r(msm_colnames)'"
		forvalues i=1/`r1' {
			local colname`i' : word `i' of `colnames'
			mata: st_local("colname`i'", _gcomp_alias_expression(st_local("colname`i'"), st_local("_gc_alias_names"), st_local("_gc_original_names")))
			local _b "`_b' r(msm_`i')"
		}
	}
	local _po=""
	local r2=r(N_PO)
	forvalues i=1/`r2' {
		local _po="`_po'"+" "+"r(PO`i')"
	}
	local PO0=r(PO0)
	local _cinc=""
	if "`eofu'"=="" {
		local out0=r(out0)
		local ltfu0=r(ltfu0)
		if "`death'"!="" {
			local death0=r(death0)
		}
		forvalues i=1/`r2' {
			local _cinc="`_cinc'"+" "+"r(out`i')"
			if "`death'"!="" {
				local _cinc="`_cinc'"+" "+"r(death`i')"
			}
		}
	}
}
else {
	local _cinc=""
    local _b=""
	if "`msm'"!="" {
		local r1=r(N_msm_params)
		local colnames "`r(msm_colnames)'"
		forvalues i=1/`r1' {
			local colname`i' : word `i' of `colnames'
			mata: st_local("colname`i'", _gcomp_alias_expression(st_local("colname`i'"), st_local("_gc_alias_names"), st_local("_gc_original_names")))
			local _b "`_b' r(msm_`i')"
		}
	}	
	if "`oce'"=="" {
        if `r(cde)' != . {
			local _po="r(tce) r(nde) r(nie) r(pm) r(cde)"
        }
        else {
            local _po="r(tce) r(nde) r(nie) r(pm)"
        }
     }
	else {
		local _po=""
		qui tab `exposure', matrow(_matrow)
		local nexplev=r(r)-1
		forvalues j=1/`nexplev' {
			local _po="`_po'"+" "+"r(tce_`j')"
		}
		forvalues j=1/`nexplev' {
			local _po="`_po'"+" "+"r(nde_`j')"
		}
		forvalues j=1/`nexplev' {
			local _po="`_po'"+" "+"r(nie_`j')"
		}
		forvalues j=1/`nexplev' {
			local _po="`_po'"+" "+"r(pm_`j')"
		}
		if "`control'"!="" {
			forvalues j=1/`nexplev' {
				local _po="`_po'"+" "+"r(cde_`j')"
			}
		}
	}
}
set rngstate `_gc_rngstate_initial'
bootstrap `_b' `_po' `_cinc', reps(`samples') `bca' noheader nolegend notable: _gcomp_bootstrap `varlist' `if' `in', ///
	out(`outcome') com(`commands') eq(`equations') i(`idvar') t(`tvar') var(`varyingcovariates') ///
	intvars(`intvars') interventions(`interventions') `monotreat' `eofu' `pooled' death(`death') derived(`derived') ///
	derrules(`derrules') fix(`fixedcovariates') lag(`laggedvars') lagrules(`lagrules') msm(`msm') `mediation' ///
	ex(`exposure') mediator(`mediator') control(`control') baseline(`baseline') alternative(`alternative') base_confs(`base_confs') ///
	post_confs(`post_confs') impute(`impute') imp_eq(`imp_eq') imp_cmd(`imp_cmd') imp_cycles(`imp_cycles') ///
		sim(`simulations') `obe' `oce' `specific' `boceam' `linexp' `minsim' `moreMC' `logOR' `logRR' saving(`"`saving'"') `replace' ///
		_gc_maxid(`maxid') _gc_chk_del(`_gc_check_delete') _gc_chk_prt(`_gc_check_print') _gc_chk_sav(`_gc_check_save') _gc_almost(`_gc_almost_varlist') ///
		_gc_origvars(`"`_gc_original_names'"') _gc_runid(`"`_gc_run_id'"') _gc_rngstate(`"`_gc_rngstate_initial'"')
	local _gc_samples_successful=e(N_reps)
	local _gc_samples_failed=e(N_misreps)
	local _gc_samples_attempted=`_gc_samples_successful'+`_gc_samples_failed'
	local _gc_samples_required=max(2,ceil(0.90*`samples'))
	if `_gc_samples_attempted'!=`samples' | `_gc_samples_successful'<`_gc_samples_required' {
		noi di as err "bootstrap inference inadequate: requested `samples', attempted `_gc_samples_attempted', successful `_gc_samples_successful', failed `_gc_samples_failed'; at least `_gc_samples_required' successful replications required"
		exit 459
	}
	if `_gc_samples_failed'>0 {
		noi di as text "Warning: bootstrap completed with `_gc_samples_successful' of `samples' successful replications (`_gc_samples_failed' failed); inference uses the successful replications."
	}
mat b=e(b)
mat V=e(V)
mat se=e(se)
mat ci_normal=e(ci_normal)
mat ci_percentile=e(ci_percentile)
mat ci_bc=e(ci_bc)
mat ci_bca=e(ci_bca)
	local _gc_ci_required "ci_normal"
	if "`all'"!="" local _gc_ci_required "ci_normal ci_percentile ci_bc ci_bca"
	foreach _gc_ci_name of local _gc_ci_required {
		if rowsof(`_gc_ci_name')!=2 | colsof(`_gc_ci_name')!=colsof(b) {
			noi di as err "requested interval matrix `_gc_ci_name' is unavailable or incomplete"
			exit 459
		}
		forvalues _gc_cr=1/2 {
			forvalues _gc_cc=1/`=colsof(b)' {
				if missing(`_gc_ci_name'[`_gc_cr',`_gc_cc']) {
					noi di as err "requested interval matrix `_gc_ci_name' contains missing limits"
					exit 459
				}
			}
		}
	}
local originallist "if in outcome commands equations idvar tvar varyingcovariates intvars interventions eofu pooled death derived derrules fixedcovariates laggedvars lagrules msm mediation base_confs post_confs impute imp_eq imp_cmd imp_cycles simulations samples seed all graph"
foreach member of local originallist {
	local `member' "`original`member''"
}
* =========================================================================
* Column naming for e(b)/e(V) posting
* =========================================================================
local _colnames ""
if "`mediation'"!="" {
	if "`oce'"=="" {
		if "`msm'"!="" {
			forvalues _i=1/`r1' {
				local _colnames "`_colnames' `colname`_i''"
			}
		}
		local _colnames "`_colnames' tce nde nie pm"
		local _n_med = colsof(b)
		if "`msm'"!="" {
			local _n_med = `_n_med' - `r1'
		}
		if `_n_med' >= 5 {
			local _colnames "`_colnames' cde"
		}
	}
	else {
		if "`msm'"!="" {
			forvalues _i=1/`r1' {
				local _colnames "`_colnames' `colname`_i''"
			}
		}
		forvalues _j=1/`nexplev' {
			local _colnames "`_colnames' tce_`_j'"
		}
		forvalues _j=1/`nexplev' {
			local _colnames "`_colnames' nde_`_j'"
		}
		forvalues _j=1/`nexplev' {
			local _colnames "`_colnames' nie_`_j'"
		}
		forvalues _j=1/`nexplev' {
			local _colnames "`_colnames' pm_`_j'"
		}
		if "`control'"!="" {
			forvalues _j=1/`nexplev' {
				local _colnames "`_colnames' cde_`_j'"
			}
		}
	}
}
else {
	if "`msm'"!="" {
		forvalues _i=1/`r1' {
			local _colnames "`_colnames' `colname`_i''"
		}
	}
	forvalues _i=1/`r2' {
		local _colnames "`_colnames' PO`_i'"
	}
	if "`eofu'"=="" {
		forvalues _i=1/`r2' {
			local _colnames "`_colnames' out`_i'"
			if "`death'"!="" {
				local _colnames "`_colnames' death`_i'"
			}
		}
	}
}
local _colnames = strtrim("`_colnames'")
matrix colnames b = `_colnames'
matrix colnames V = `_colnames'
matrix rownames V = `_colnames'
matrix colnames se = `_colnames'
matrix colnames ci_normal = `_colnames'
capture matrix colnames ci_percentile = `_colnames'
capture matrix colnames ci_bc = `_colnames'
capture matrix colnames ci_bca = `_colnames'
* Build V matrix and save copies for ereturn post
tempname b_post V_post se_post cin_post
local _k = colsof(b)
matrix `b_post' = b
matrix `se_post' = se
matrix `cin_post' = ci_normal
matrix `V_post' = V
matrix colnames `V_post' = `_colnames'
matrix rownames `V_post' = `_colnames'
tempname cip_post cibc_post cibca_post
capture matrix `cip_post' = ci_percentile
capture matrix `cibc_post' = ci_bc
capture matrix `cibca_post' = ci_bca
if "`msm'"!="" {
	noi di as text " "
	noi di as text "G-computation formula estimates for the parameters of the specified marginal structural model"
	noi di as text " "
	noi di as text _col(10) "Specified MSM: " _cont 
	noi di as result "`msm'"
	noi di as text " "
	if "`all'"=="" {
		noi di as text _col(2)  "{hline 13}{c TT}{hline 68}"
		noi di as text _col(15) "{c |}" _col(18)  "G-computation" 
		
		
		noi di as text _col(15) "{c |}" _col(19) "estimate of" _col(34) "Bootstrap" _col(68) "Normal-based"
		local w=14-length(abbrev("`outcome'",12))
		if "`eofu'"!="" {
			noi di as text _col(`w')  abbrev("`outcome'",12) _col(15) "{c |}" _col(22) "Coef." ///
                _col(34) "Std. Err." _col(49) "z" _col(54) "P>|z|" _col(64) "[95% Conf. Interval]"         
		}
		else {
			noi di as text _col(`w')  abbrev("`outcome'",12) _col(15) "{c |}" _col(22) ///
            "Coef." _col(34) "Std. Err." _col(49) "z" _col(54) "P>|z|" _col(64) "[95% Conf. Interval]"         
		}
		noi di as text _col(2)  "{hline 13}{c +}{hline 68}"
		forvalues i=1/`r1' {
			local w=14-length(abbrev("`colname`i''",12))
			noi di as text _col(`w') abbrev("`colname`i''",12) _col(15) "{c |}" _cont
			_gcomp_display_stats, est(`=b[1,`i']') se(`=se[1,`i']') ci_lo(`=ci_normal[1,`i']') ci_hi(`=ci_normal[2,`i']')
		}
		noi di as text _col(2)  "{hline 13}{c BT}{hline 68}"
	}
	else {
		noi di as text _col(2)  "{hline 13}{c TT}{hline 74}"
		noi di as text _col(15) "{c |}" _col(18)  "G-computation" 
		noi di as text _col(15) "{c |}" _col(19) "estimate of" _col(34) "Bootstrap"
		local w=14-length(abbrev("`outcome'",12))
		if "`eofu'"!="" {
			noi di as text _col(`w')  abbrev("`outcome'",12) _col(15) "{c |}" _col(22) ///
            "Coef." _col(34) "Std. Err." _col(49) "z" _col(54) "P>|z|" _col(64) "[95% Conf. Interval]"         
		}
		else {
			noi di as text _col(`w')  abbrev("`outcome'",12) _col(15) "{c |}" _col(22) ///
            "Coef." _col(34) "Std. Err." _col(49) "z" _col(54) "P>|z|" _col(64) "[95% Conf. Interval]"         
		}
		noi di as text _col(2)  "{hline 13}{c +}{hline 74}"
		forvalues i=1/`r1' {
			local w=14-length(abbrev("`colname`i''",12))
			noi di as text _col(`w') abbrev("`colname`i''",12) _col(15) "{c |}" _cont
			_gcomp_display_stats, est(`=b[1,`i']') se(`=se[1,`i']') ci_lo(`=ci_normal[1,`i']') ci_hi(`=ci_normal[2,`i']') continue
			noi di as text "   (N)"
			noi di as text _col(15) "{c |}" _cont
			noi di as result _col(63) %9.0g ci_percentile[1,`i'] _cont
			noi di as result _col(75) %9.0g ci_percentile[2,`i'] _cont
			noi di as text "   (P)"
			noi di as text _col(15) "{c |}" _cont
			noi di as result _col(63) %9.0g ci_bc[1,`i'] _cont
			noi di as result _col(75) %9.0g ci_bc[2,`i'] _cont
			noi di as text "  (BC)"
			noi di as text _col(15) "{c |}" _cont
			noi di as result _col(63) %9.0g ci_bca[1,`i'] _cont
			noi di as result _col(75) %9.0g ci_bca[2,`i'] _cont
			noi di as text " (BCa)"
		}
		noi di as text _col(2)  "{hline 13}{c BT}{hline 74}"
		noi di as text " (N)    normal confidence interval"
		noi di as text " (P)    percentile confidence interval"
		noi di as text " (BC)   bias-corrected confidence interval"
		noi di as text " (BCa)  bias-corrected and accelerated confidence interval"
		noi di
		noi di
	}
}
if "`mediation'"=="" {
	noi di as text " "
	if "`eofu'"!="" {
		noi di as text "G-computation formula estimates of the expected values of the potential outcome under each of the specified interventions"
		noi di as text "   and under no intervention (i.e. as simulated under the observational regime). For comparison, the mean outcome in the"
		noi di as text "   observed data is also shown."
	}
	else {
		noi di as text "G-computation formula estimates of the average log incidence rates under each of the specified interventions and under no"
		noi di as text "   intervention (i.e. as simulated under the observational regime). For comparison, the average log incidence rate in the"
		noi di as text "   observed data is also shown."
	}
	noi di as text " "
	noi di as text _col(10) "Specified interventions: "
	* tokenize interventions
	tokenize "`interventions'", parse(",")
	local nint 0 			
	while "`1'"!="" {
		if "`1'"!="," {
			local nint=`nint'+1
			local int`nint' "`1'"
		}
		mac shift
	}
	forvalues i=1/`nint' { 	
		noi di as text _col(15) "Intervention " `i' ": " _cont
		noi di as result "`int`i''"
	}
	noi di as text " "
	if "`all'"=="" {
		noi di as text _col(2)  "{hline 13}{c TT}{hline 68}"
		noi di as text _col(15) "{c |}" _col(18)  "G-computation" 
		noi di as text _col(15) "{c |}" _col(19) "estimate of" _col(34) "Bootstrap" _col(68) "Normal-based"
		local w=14-length(abbrev("`outcome'",12))
		if "`eofu'"!="" {
			noi di as text _col(`w')  abbrev("`outcome'",12) _col(15) "{c |}" _col(21) "mean PO" _col(34) ///
                "Std. Err." _col(49) "z" _col(54) "P>|z|" _col(64) "[95% Conf. Interval]"         
		}
		else {
			noi di as text _col(`w')  abbrev("`outcome'",12) _col(15) "{c |}" _col(19) "av. log IR" _col(34) ///
                "Std. Err." _col(49) "z" _col(54) "P>|z|" _col(64) "[95% Conf. Interval]"         
		}
		noi di as text _col(2)  "{hline 13}{c +}{hline 68}"
		if "`msm'"!="" {
			local r3=`r1'+1
			local r4=`r1'+`r2'
			local subtract=`r1'
		}
		else {
			local r3=1
			local r4=`r2'
			local subtract=0
		}
		forvalues i=`r3'/`r4' {
			local j=`i'-`subtract'
			if `j'<=`nint' {
				noi di as text _col(7) "Int. " `j' _col(15) "{c |}" _cont
			}
			else {
				noi di as result _col(2) "Obs. regime" _col(15) "{c |}"
				noi di as text _col(4)   "simulated" _col(15) "{c |}" _cont
			}
			_gcomp_display_stats, est(`=b[1,`i']') se(`=se[1,`i']') ci_lo(`=ci_normal[1,`i']') ci_hi(`=ci_normal[2,`i']')
			if `j'==`nint' {
				noi di as text _col(2)  "{hline 13}{c +}{hline 68}"
			}
		}
		noi di as text _col(5) "observed" _col(15) "{c |}" _cont
		noi di as result %9.0g _col(19) `PO0'
		noi di as text _col(2)  "{hline 13}{c BT}{hline 68}"
	}
	else {
		noi di as text _col(2)  "{hline 13}{c TT}{hline 74}"
		noi di as text _col(15) "{c |}" _col(18)  "G-computation" 
		noi di as text _col(15) "{c |}" _col(19) "estimate of" _col(34) "Bootstrap"
		local w=14-length(abbrev("`outcome'",12))
		if "`eofu'"!="" {
			noi di as text _col(`w')  abbrev("`outcome'",12) _col(15) "{c |}" _col(21) "mean PO" _col(34) ///
                "Std. Err." _col(49) "z" _col(54) "P>|z|" _col(64) "[95% Conf. Interval]"         
		}
		else {
			noi di as text _col(`w')  abbrev("`outcome'",12) _col(15) "{c |}" _col(19) "av. log IR" _col(34) ///
                "Std. Err." _col(49) "z" _col(54) "P>|z|" _col(64) "[95% Conf. Interval]"         
		}
		noi di as text _col(2)  "{hline 13}{c +}{hline 74}"
		if "`msm'"!="" {
			local r3=`r1'+1
			local r4=`r1'+`r2'
			local subtract=`r1'
		}
		else {
			local r3=1
			local r4=`r2'
			local subtract=0
		}
		forvalues i=`r3'/`r4' {
			local j=`i'-`subtract'
			if `j'<=`nint' {
				noi di as text _col(7) "Int. " `j' _col(15) "{c |}" _cont
			}
			else {
				noi di as result _col(2) "Obs. regime" _col(15) "{c |}"
				noi di as text _col(4)   "simulated" _col(15) "{c |}" _cont
			}
			_gcomp_display_stats, est(`=b[1,`i']') se(`=se[1,`i']') ci_lo(`=ci_normal[1,`i']') ci_hi(`=ci_normal[2,`i']') continue
			noi di as text "   (N)"
			noi di as text _col(15) "{c |}" _cont
			noi di as result _col(63) %9.0g ci_percentile[1,`i'] _cont
			noi di as result _col(75) %9.0g ci_percentile[2,`i'] _cont
			noi di as text "   (P)"
			noi di as text _col(15) "{c |}" _cont
			noi di as result _col(63) %9.0g ci_bc[1,`i'] _cont
			noi di as result _col(75) %9.0g ci_bc[2,`i'] _cont
			noi di as text "  (BC)"
			noi di as text _col(15) "{c |}" _cont
			noi di as result _col(63) %9.0g ci_bca[1,`i'] _cont
			noi di as result _col(75) %9.0g ci_bca[2,`i'] _cont
			noi di as text " (BCa)"
			if `j'==`nint' {
				noi di as text _col(2)  "{hline 13}{c +}{hline 74}"
			}
		}
		noi di as text _col(5) "observed" _col(15) "{c |}" _cont
		noi di as result %9.0g _col(19) `PO0'
		noi di as text _col(2)  "{hline 13}{c BT}{hline 74}"
		noi di as text " (N)    normal confidence interval"
		noi di as text " (P)    percentile confidence interval"
		noi di as text " (BC)   bias-corrected confidence interval"
		noi di as text " (BCa)  bias-corrected and accelerated confidence interval"
	}
	if "`eofu'"=="" {
		noi di as text " "
		noi di as text "G-computation formula estimates of the cumulative incidence under each of the specified interventions and under no"
		noi di as text "   intervention (i.e. as simulated under the observational regime). For comparison, the cumulative incidence in the"
		noi di as text "   observed data is also shown."
		noi di as text " "
		noi di as text _col(10) "Specified interventions: "
		* tokenize interventions
		tokenize "`interventions'", parse(",")
		local nint 0 			
		while "`1'"!="" {
			if "`1'"!="," {
				local nint=`nint'+1
				local int`nint' "`1'"
			}
			mac shift
		}
		forvalues i=1/`nint' { 	
			noi di as text _col(15) "Intervention " `i' ": " _cont
			noi di as result "`int`i''"
		}
		noi di as text " "
		if "`all'"=="" {
			noi di as text _col(2)  "{hline 13}{c TT}{hline 68}"
			noi di as text _col(15) "{c |}" _col(18)  "G-computation" 
			noi di as text _col(15) "{c |}" _col(19) "estimate of" _col(34) "Bootstrap" _col(68) "Normal-based"
			local w=14-length(abbrev("`outcome'",12))
			noi di as text _col(`w')  abbrev("`outcome'",12) _col(15) "{c |}" _col(18) "cum. incidence" _col(34) ///
				"Std. Err." _col(49) "z" _col(54) "P>|z|" _col(64) "[95% Conf. Interval]" 			
			noi di as text _col(2)  "{hline 13}{c +}{hline 68}"
			if "`msm'"!="" {
				local r3=`r1'+`r2'+1
				if "`death'"=="" {
					local r4=`r1'+2*`r2'
				}
				else {
					local r4=`r1'+3*`r2'
				}
				local subtract=`r1'+`r2'
			}
			else {
				local r3=1+`r2'
				if "`death'"=="" {
					local r4=2*`r2'
				}
				else {
					local r4=3*`r2'
				}
				local subtract=`r2'
			}
			local od=0
			forvalues i=`r3'/`r4' {
				local j=`i'-`subtract'
				if "`death'"=="" {
					if `j'<=`nint' {
						noi di as text _col(7) "Int. " `j'  _col(15) "{c |}" _cont
					}
					else {
						noi di as result _col(2) "Obs. regime" _col(15) "{c |}"
						noi di as text _col(4) "simulated" _col(15) "{c |}" _cont
					}
				}
				else {
					local k=ceil(`j'/2)
					if `k'<=`nint' {
						if `od'==0 {
							noi di as text _col(3) "Int. " `k' " (o)" _col(15) "{c |}" _cont
						}
						else {
							local indent=9+ceil(log10(`k'+1))
							noi di as text _col(`indent') "(d)" _col(15) "{c |}" _cont
						}
						local od=1-`od'
					}
					else {
						if `od'==0 {
							noi di as result _col(2) "Obs. regime" _col(15) "{c |}"
							noi di as text _col(2) "simulated (o)" _col(15) "{c |}" _cont
						}
						else {
							noi di as text _col(2) "          (d)" _col(15) "{c |}" _cont
						}
						local od=1-`od'
					}
				}
				_gcomp_display_stats, est(`=b[1,`i']') se(`=se[1,`i']') ci_lo(`=ci_normal[1,`i']') ci_hi(`=ci_normal[2,`i']')
				if "`death'"=="" {
					if `j'==`nint' {
						noi di as text _col(2)  "{hline 13}{c +}{hline 68}"
					}
				}
				else {
					if `k'==`nint' & `od'==0 {
						noi di as text _col(2)  "{hline 13}{c +}{hline 68}"
					}
				}
			}
			if "`death'"=="" {
				if `ltfu0'==0 {
					noi di as text _col(5) "observed" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `out0'
				}
				else {
					noi di as text _col(2) "observed (o)" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `out0'
					noi di as text _col(2) "observed (l)" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `ltfu0'
				}
			}
			else {
				if `ltfu0'==0 {
					noi di as text _col(2) "observed (o)" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `out0'
					noi di as text _col(2) "         (d)" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `death0'
				}
				else {
					noi di as text _col(2) "observed (o)" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `out0'
					noi di as text _col(2) "         (d)" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `death0'
					noi di as text _col(2) "         (l)" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `ltfu0'
				}
			}
			noi di as text _col(2)  "{hline 13}{c BT}{hline 68}"
			if "`death'"!="" & `ltfu0'==0 {
				noi di as text _col(2)  "Key: " _cont
				noi di as text _col(2)  as result "(o) " as text "= outcome, " as result "(d) " as text "= death"
			}
			if "`death'"!="" & `ltfu0'!=0 {
				noi di as text _col(2)  "Key: " _cont
				noi di as text _col(2)  as result "(o) " as text "= outcome, " as result "(d) " as text "= death, " ///
					as result "(l) " as text "= lost to follow-up"
			}
		}
		else {
			noi di as text _col(2)  "{hline 13}{c TT}{hline 74}"
			noi di as text _col(15) "{c |}" _col(18)  "G-computation" 
			noi di as text _col(15) "{c |}" _col(19) "estimate of" _col(34) "Bootstrap"
			local w=14-length(abbrev("`outcome'",12))
			noi di as text _col(`w')  abbrev("`outcome'",12) _col(15) "{c |}" _col(18) "cum. incidence" _col(34) ///
				"Std. Err." _col(49) "z" _col(54) "P>|z|" _col(64) "[95% Conf. Interval]" 			
			noi di as text _col(2)  "{hline 13}{c +}{hline 74}"
			if "`msm'"!="" {
				local r3=`r1'+`r2'+1
				if "`death'"=="" {
					local r4=`r1'+2*`r2'
				}
				else {
					local r4=`r1'+3*`r2'
				}
				local subtract=`r1'+`r2'
			}
			else {
				local r3=1+`r2'
				if "`death'"=="" {
					local r4=2*`r2'
				}
				else {
					local r4=3*`r2'
				}
				local subtract=`r2'
			}
			local od=0
			forvalues i=`r3'/`r4' {
				local j=`i'-`subtract'
				if "`death'"=="" {
					if `j'<=`nint' {
						noi di as text _col(7) "Int. " `j'  _col(15) "{c |}" _cont
					}
					else {
						noi di as result _col(2) "Obs. regime" _col(15) "{c |}"
						noi di as text _col(4) "simulated" _col(15) "{c |}" _cont
					}
				}
				else {
					local k=ceil(`j'/2)
					if `k'<=`nint' {
						if `od'==0 {
							noi di as text _col(3) "Int. " `k' " (o)" _col(15) "{c |}" _cont
						}
						else {
							local indent=9+ceil(log10(`k'+1))
							noi di as text _col(`indent') "(d)" _col(15) "{c |}" _cont
						}
						local od=1-`od'
					}
					else {
						if `od'==0 {
							noi di as result _col(2) "Obs. regime" _col(15) "{c |}"
							noi di as text _col(2) "simulated (o)" _col(15) "{c |}" _cont
						}
						else {
							noi di as text _col(2) "          (d)" _col(15) "{c |}" _cont
						}
						local od=1-`od'
					}
				}
				_gcomp_display_stats, est(`=b[1,`i']') se(`=se[1,`i']') ci_lo(`=ci_normal[1,`i']') ci_hi(`=ci_normal[2,`i']') continue
				noi di as text "   (N)"
				noi di as text _col(15) "{c |}" _cont
				noi di as result _col(63) %9.0g ci_percentile[1,`i'] _cont
				noi di as result _col(75) %9.0g ci_percentile[2,`i'] _cont
				noi di as text "   (P)"
				noi di as text _col(15) "{c |}" _cont
				noi di as result _col(63) %9.0g ci_bc[1,`i'] _cont
				noi di as result _col(75) %9.0g ci_bc[2,`i'] _cont
				noi di as text "  (BC)"
				noi di as text _col(15) "{c |}" _cont
				noi di as result _col(63) %9.0g ci_bca[1,`i'] _cont
				noi di as result _col(75) %9.0g ci_bca[2,`i'] _cont
				noi di as text " (BCa)"
				if "`death'"=="" {
					if `j'==`nint' {
						noi di as text _col(2)  "{hline 13}{c +}{hline 74}"
					}
				}
				else {
					if `k'==`nint' & `od'==0 {
						noi di as text _col(2)  "{hline 13}{c +}{hline 74}"
					}
				}
			}
			if "`death'"=="" {
				if `ltfu0'==0 {
					noi di as text _col(5) "observed" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `out0'
				}
				else {
					noi di as text _col(2) "observed (o)" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `out0'
					noi di as text _col(2) "observed (l)" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `ltfu0'
				}
			}
			else {
				if `ltfu0'==0 {
					noi di as text _col(2) "observed (o)" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `out0'
					noi di as text _col(2) "         (d)" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `death0'
				}
				else {
					noi di as text _col(2) "observed (o)" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `out0'
					noi di as text _col(2) "         (d)" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `death0'
					noi di as text _col(2) "         (l)" _col(15) "{c |}" _cont
					noi di as result %9.0g _col(19) `ltfu0'
				}
			}
			noi di as text _col(2)  "{hline 13}{c BT}{hline 74}"
			if "`death'"!="" & `ltfu0'==0 {
				noi di as text _col(2)  "Key: " _cont
				noi di as text _col(2)  as result "(o) " as text "= outcome, " as result "(d) " as text "= death"
			}
			if "`death'"!="" & `ltfu0'!=0 {
				noi di as text _col(2)  "Key: " _cont
				noi di as text _col(2)  as result "(o) " as text "= outcome, " as result "(d) " as text "= death, " ///
					as result "(l) " as text "= lost to follow-up"
			}
			noi di
			noi di as text " (N)    normal confidence interval"
			noi di as text " (P)    percentile confidence interval"
			noi di as text " (BC)   bias-corrected confidence interval"
			noi di as text " (BCa)  bias-corrected and accelerated confidence interval"
		}
	}
	if "`graph'"!="" {
		graph display `_gc_graph_name'
	}
}
else {
	if "`msm'"!="" {
		local r1plus1=`r1'+1
		local r1end=colsof(b)
		matrix b=b[1,`r1plus1'..`r1end']
		matrix se=se[1,`r1plus1'..`r1end']
		matrix ci_normal=ci_normal[1..2,`r1plus1'..`r1end']
		cap matrix ci_percentile=ci_percentile[1..2,`r1plus1'..`r1end']
		cap matrix ci_bc=ci_bc[1..2,`r1plus1'..`r1end']
		cap matrix ci_bca=ci_bca[1..2,`r1plus1'..`r1end']
	}
	noi di as text " "
    if "`control'"=="" {
    	noi di as text "G-computation formula estimates of the total causal effect and the natural direct/indirect effects"
    }
    else {
    	noi di as text "G-computation formula estimates of the total causal effect, the natural direct/indirect effects,"
        noi di as text "and the controlled direct effect"
    }
    noi di
	if "`obe'"=="" & "`oce'"=="" & "`linexp'"=="" & "`specific'"=="" {
		noi di as text _col(5) "Note: The total causal effect (" as result "TCE" as text ") is a comparison between the"
		noi di as text _col(11) "mean outcome under the observational regime and the mean potential"
		noi di as text _col(11) "outcome if, contrary to fact, all subjects' exposure(s) were"
		noi di as text _col(11) "set at the baseline values. Writing X for the exposure(s), M"
		noi di as text _col(11) "for the mediator(s), Y for the outcome and 0 for the baseline"
		noi di as text _col(11) "value(s) of the exposure(s), then:"
		noi di
		if "`logOR'"=="" & "`logRR'"=="" {
			noi di as result _col(23) "TCE" as text "=E[Y{X,M(X)}]-E[Y{0,M(0)}]"
		}
		if "`logOR'"!="" & "`logRR'"=="" {
			noi di as result _col(23) "TCE" as text "=log{E[Y{X,M(X)}]/(1-E[Y{X,M(X)}])}-log{E[Y{0,M(0)}]/(1-E[Y{0,M(0)}])}"
		}
		if "`logOR'"=="" & "`logRR'"!="" {
			noi di as result _col(23) "TCE" as text "=log(E[Y{X,M(X)}])-log(E[Y{0,M(0)}])"
		}
		noi di
		noi di as text _col(11) "The natural direct effect (" as result "NDE" as text ") is a comparison between the"
		noi di as text _col(11) "mean of two potential outcomes. The first is the potential"
		noi di as text _col(11) "outcome if, contrary to fact, all subjects' mediator(s) were" 
		noi di as text _col(11) "set to their potential value(s) under the baseline value(s)" 
		noi di as text _col(11) "of the exposure, but the exposure value(s) are those actually" 
		noi di as text _col(11) "observed in the observational data. The second is the" 
		noi di as text _col(11) "potential outcome if, contrary to fact, all subjects'" 
		noi di as text _col(11) "exposure(s) were set at the baseline value(s). That is:"
		noi di
		if "`logOR'"=="" & "`logRR'"=="" {
			noi di as result _col(23) "NDE" as text "=E[Y{X,M(0)}]-E[Y{0,M(0)}]"
		}
		if "`logOR'"!="" & "`logRR'"=="" {
			noi di as result _col(23) "NDE" as text "=log{E[Y{X,M(0)}]/(1-E[Y{X,M(0)}])}-log{E[Y{0,M(0)}]/(1-E[Y{0,M(0)}])}"
		}
		if "`logOR'"=="" & "`logRR'"!="" {
			noi di as result _col(23) "NDE" as text "=log(E[Y{X,M(0)}])-log(E[Y{0,M(0)}])"
		}
		noi di
		noi di as text _col(11) "The natural indirect effect (" as result "NIE" as text ") is the difference between"
		noi di as text _col(11) "the " as result "TCE" as text " and the " as result "NDE" as text ". That is:"
		noi di
		if "`logOR'"=="" & "`logRR'"=="" {
			noi di as result _col(19) "NIE" as text "=" as result "TCE" as text "-" as result "NDE" as text "=E[Y{X,M(X)}]-E[Y{X,M(0)}]"
		}
		if "`logOR'"!="" & "`logRR'"=="" {
			noi di as result _col(19) "NIE" as text "=" as result "TCE" as text "-" as result "NDE" as text "=log{E[Y{X,M(X)}]/(1-E[Y{X,M(X)}])}-log{E[Y{X,M(0)}]/(1-E[Y{X,M(0)}])}"
		}
		if "`logOR'"=="" & "`logRR'"!="" {
			noi di as result _col(19) "NIE" as text "=" as result "TCE" as text "-" as result "NDE" as text "=log(E[Y{X,M(X)}])-log(E[Y{X,M(0)}])"
		}
		noi di
		noi di as text _col(11) "The proportion mediated (" as result "PM" as text ") is the " as result "NIE " as text "divided by"
		noi di as text _col(11) "the " as result "TCE" as text "."
		noi di
		if "`control'"!="" {
			noi di as text _col(11) "The controlled direct effect (" as result "CDE" as text ") is a comparison between"
			noi di as text _col(11) "the mean potential outcome when subjects' exposure value(s)"
			noi di as text _col(11) "were those actually observed under the observational regime and" 
			noi di as text _col(11) "the mean potential outcome when, contrary to fact, all" 
			noi di as text _col(11) "subjects' exposure(s) were set at the baseline value(s); and,"
			noi di as text _col(11) "in addition, in both cases, the mediator(s) were set to their" 
			noi di as text _col(11) "control value(s). Write m for the control value(s) of the" 
			noi di as text _col(11) "mediator(s), then:"
			noi di
			if "`logOR'"=="" & "`logRR'"=="" {
				noi di as result _col(23) "CDE" as text "=E{Y(X,m)}-E{Y(0,m)}"
			}
			if "`logOR'"!="" & "`logRR'"=="" {
				noi di as result _col(23) "CDE" as text "=log(E{Y(X,m)}/[1-E{Y(X,m)}])-log(E{Y(0,m)}/[1-E{Y(0,m)}])"
			}
			if "`logOR'"=="" & "`logRR'"!="" {
				noi di as result _col(23) "CDE" as text "=log[E{Y(X,m)}]-log[E{Y(0,m)}]"
			}
			noi di
		}
	}
	else {
		if "`obe'"!="" {
			noi di as text _col(5) "Note: The total causal effect (" as result "TCE" as text ") is a comparison between the"
			noi di as text _col(11) "mean potential outcome if, contrary to fact, all subjects were"
			noi di as text _col(11) "exposed, and the mean potential outcome if all subjects were"
			noi di as text _col(11) "unexposed. Writing X for the exposure, M for the mediator(s),"
			noi di as text _col(11) "and Y for the outcome and 0 for the baseline, then:"
			noi di
			if "`logOR'"=="" & "`logRR'"=="" {
				noi di as result _col(19) "TCE" as text "=E[Y{X=1,M(X=1)}]-E[Y{X=0,M(X=0)}]"
			}
			if "`logOR'"!="" & "`logRR'"=="" {
				noi di as result _col(19) "TCE" as text "=log{E[Y{X=1,M(X=1)}]/(1-E[Y{X=1,M(X=1)}])}-log{E[Y{X=0,M(X=0)}]/(1-E[Y{X=0,M(X=0)}])}"
			}
			if "`logOR'"=="" & "`logRR'"!="" {
				noi di as result _col(19) "TCE" as text "=log(E[Y{X=1,M(X=1)}])-log(E[Y{X=0,M(X=0)}])"
			}
			noi di
			noi di as text _col(11) "The natural direct effect (" as result "NDE" as text ") is a comparison between the"
			noi di as text _col(11) "mean of two potential outcomes. The first is the potential"
			noi di as text _col(11) "outcome if, contrary to fact, all subjects were exposed, and"
			noi di as text _col(11) "subjects' mediator(s) were set to their potential value(s)"
			noi di as text _col(11) "under no exposure. The second is the potential outcome if,"
			noi di as text _col(11) "contrary to fact, all subjects were unexposed. That is:"
			noi di
			if "`logOR'"=="" & "`logRR'"=="" {
				noi di as result _col(19) "NDE" as text "=E[Y{X=1,M(X=0)}]-E[Y{X=0,M(X=0)}]"
			}
			if "`logOR'"!="" & "`logRR'"=="" {
				noi di as result _col(19) "NDE" as text "=log{E[Y{X=1,M(X=0)}]/(1-E[Y{X=1,M(X=0)}])}-log{E[Y{X=0,M(X=0)}]/(1-E[Y{X=0,M(X=0)}])}"
			}
			if "`logOR'"=="" & "`logRR'"!="" {
				noi di as result _col(19) "NDE" as text "=log(E[Y{X=1,M(X=0)}])-log(E[Y{X=0,M(X=0)}])"
			}
			noi di
			noi di as text _col(11) "The natural indirect effect (" as result "NIE" as text ") is the difference between"
			noi di as text _col(11) "the " as result "TCE" as text " and the " as result "NDE" as text ". That is:"
			noi di
			if "`logOR'"=="" & "`logRR'"=="" {
				noi di as result _col(15) "NIE" as text "=" as result "TCE" as text "-" as result "NDE" as text "=E[Y{X=1,M(X=1)}]-E[Y{X=1,M(X=0)}]"
			}
			if "`logOR'"!="" & "`logRR'"=="" {
				noi di as result _col(15) "NIE" as text "=" as result "TCE" as text "-" as result "NDE" as text "=log{E[Y{X=1,M(X=1)}]/(1-E[Y{X=1,M(X=1)}])}-log{E[Y{X=1,M(X=0)}]/(1-E[Y{X=1,M(X=0)}])}"
			}
			if "`logOR'"=="" & "`logRR'"!="" {
				noi di as result _col(15) "NIE" as text "=" as result "TCE" as text "-" as result "NDE" as text "=log(E[Y{X=1,M(X=1)}])-log(E[Y{X=1,M(X=0)}])"
			}
			noi di
			noi di as text _col(11) "The proportion mediated (" as result "PM" as text ") is the " as result "NIE " as text "divided by"
			noi di as text _col(11) "the " as result "TCE" as text "."
			noi di
			if "`control'"!="" {
				noi di as text _col(11) "The controlled direct effect (" as result "CDE" as text ") is a comparison between"
				noi di as text _col(11) "the mean potential outcome when all subjects were exposed"
				noi di as text _col(11) "and the mean potential outcome when all subjects were"
				noi di as text _col(11) "unexposed; and, in addition, in both cases, the mediator(s)"
				noi di as text _col(11) "were set to their control value(s). Write m for the control"
				noi di as text _col(11) "value(s) of the mediator(s), then:"
				noi di
				if "`logOR'"=="" & "`logRR'"=="" {
					noi di as result _col(19) "CDE" as text "=E{Y(X=1,M=m)}-E{Y(X=0,M=m)}"
				}	
				if "`logOR'"!="" & "`logRR'"=="" {
					noi di as result _col(19) "CDE" as text "=log(E{Y(X=1,M=m)}/[1-E{Y(X=1,M=m)}])-log(E{Y(X=0,M=m)}/[1-E{Y(X=0,M=m)}])"
				}
				if "`logOR'"=="" & "`logRR'"!="" {
					noi di as result _col(19) "CDE" as text "=log[E{Y(X=1,M=m)}]-log[E{Y(X=0,M=m)}]"
				}
				noi di
			}
		}
		else {
			if "`oce'"=="" & "`specific'"=="" {
				noi di as text _col(5) "Note: The total causal effect (" as result "TCE" as text ") is a comparison between the"
				noi di as text _col(11) "mean potential outcome if, contrary to fact, all subjects'" 
				noi di as text _col(11) "exposure were set to one value higher than they were in the"
				noi di as text _col(11) "observed data, and the mean outcome when the exposures are left"
				noi di as text _col(11) "unchanged. Writing X for the exposure, M for the mediator(s)" 
				noi di as text _col(11) "and Y for the outcome, then:"
				noi di
				if "`logOR'"=="" & "`logRR'"=="" {
					noi di as result _col(23) "TCE" as text "=E[Y{X+1,M(X+1)}]-E[Y{X,M(X)}]"
				}
				if "`logOR'"!="" & "`logRR'"=="" {
					noi di as result _col(23) "TCE" as text "=log{E[Y{X+1,M(X+1)}]/(1-E[Y{X+1,M(X+1)}])}-log{E[Y{X,M(X)}]/(1-E[Y{X,M(X)}])}"
				}
				if "`logOR'"=="" & "`logRR'"!="" {
					noi di as result _col(23) "TCE" as text "=log(E[Y{X+1,M(X+1)}])-log(E[Y{X,M(X)}])"
				}
				noi di
				noi di as text _col(11) "The natural direct effect (" as result "NDE" as text ") is also a comparison between"
				noi di as text _col(11) "the mean of a potential outcome and the mean of the actual" 
				noi di as text _col(11) "outcome. The potential outcome in question here is the one we"
				noi di as text _col(11) "would observe if, contrary to fact, all subjects' exposure" 
				noi di as text _col(11) "value were increased by 1, but their mediator value(s) are" 
				noi di as text _col(11) "those actually observed in the observational data. That is:"
				noi di
				if "`logOR'"=="" & "`logRR'"=="" {
					noi di as result _col(23) "NDE" as text "=E[Y{X+1,M(X)}]-E[Y{X,M(X)}]"
				}
				if "`logOR'"!="" & "`logRR'"=="" {
					noi di as result _col(23) "NDE" as text "=log{E[Y{X+1,M(X)}]/(1-E[Y{X+1,M(X)}])}-log{E[Y{X,M(X)}]/(1-E[Y{X,M(X)}])}"
				}
				if "`logOR'"=="" & "`logRR'"!="" {
					noi di as result _col(23) "NDE" as text "=log(E[Y{X+1,M(X)}])-log(E[Y{X,M(X)}])"
				}				
				noi di
				noi di as text _col(11) "The natural indirect effect (" as result "NIE" as text ") is the difference between"
				noi di as text _col(11) "the " as result "TCE" as text " and the " as result "NDE" as text ". That is:"
				noi di
				if "`logOR'"=="" & "`logRR'"=="" {
					noi di as result _col(19) "NIE" as text "=" as result "TCE" as text "-" as result "NDE" as text "=E[Y{X+1,M(X+1)}]-E[Y{X+1,M(X)}]"
				}
				if "`logOR'"!="" & "`logRR'"=="" {
					noi di as result _col(19) "NIE" as text "=" as result "TCE" as text "-" as result "NDE" as text "=log{E[Y{X+1,M(X+1)}]/(1-E[Y{X+1,M(X+1)}])}-log{E[Y{X+1,M(X)}]/(1-E[Y{X+1,M(X)}])}"
				}
				if "`logOR'"=="" & "`logRR'"!="" {
					noi di as result _col(19) "NIE" as text "=" as result "TCE" as text "-" as result "NDE" as text "=log(E[Y{X+1,M(X+1)}])-log(E[Y{X+1,M(X)}])"
				}				
				noi di
				noi di as text _col(11) "The proportion mediated (" as result "PM" as text ") is the " as result "NIE " as text "divided by"
				noi di as text _col(11) "the " as result "TCE" as text "."
				noi di
				if "`control'"!="" {
					noi di as text _col(11) "The controlled direct effect (" as result "CDE" as text ") is a comparison between"
					noi di as text _col(11) "the mean potential outcome when subjects' exposure values"
					noi di as text _col(11) "were increased by 1 and the mean potential outcome when, the" 
					noi di as text _col(11) "subjects' exposures were left unchanged; and, in addition, in"
					noi di as text _col(11) "both cases, the mediator(s) were set to their control"
					noi di as text _col(11) "value(s). Write m for the control value(s) of the" 
					noi di as text _col(11) "mediator(s), then:"
					noi di
					if "`logOR'"=="" & "`logRR'"=="" {
						noi di as result _col(23) "CDE" as text "=E{Y(X+1,m)}-E{Y(X,m)}"
					}
					if "`logOR'"!="" & "`logRR'"=="" {
						noi di as result _col(23) "CDE" as text "=log(E{Y(X+1,m)}/[1-E{Y(X+1,m)}])-log(E{Y(X,m)}/[1-E{Y(X,m)}])"
					}
					if "`logOR'"=="" & "`logRR'"!="" {
						noi di as result _col(23) "CDE" as text "=log[E{Y(X+1,m)}]-log[E{Y(X,m)}]"
					}					
					noi di
				}
			}
			else {
				if "`specific'"!="" {

					noi di as text _col(5) "Note: The total causal effect (" as result "TCE" as text ") is a comparison between the"
					noi di as text _col(11) "mean potential outcome if, contrary to fact, all subjects were"
					noi di as text _col(11) "exposed to x1, and the mean potential outcome if all subjects were"
					noi di as text _col(11) "exposed to x0. Writing X for the exposure, M for the mediator(s),"
					noi di as text _col(11) "and Y for the outcome, then:"
					noi di
					if "`logOR'"=="" & "`logRR'"=="" {
						noi di as result _col(19) "TCE" as text "=E[Y{X=x1,M(X=x1)}]-E[Y{X=x0,M(X=x0)}]"
					}
					if "`logOR'"!="" & "`logRR'"=="" {
						noi di as result _col(19) "TCE" as text "=log{E[Y{X=x1,M(X=x1)}]/(1-E[Y{X=x1,M(X=x1)}])}-log{E[Y{X=x0,M(X=x0)}]/(1-E[Y{X=x0,M(X=x0)}])}"
					}
					if "`logOR'"=="" & "`logRR'"!="" {
						noi di as result _col(19) "TCE" as text "=log(E[Y{X=x1,M(X=x1)}])-log(E[Y{X=x0,M(X=x0)}])"
					}
					noi di
					noi di as text _col(11) "The natural direct effect (" as result "NDE" as text ") is a comparison between the"
					noi di as text _col(11) "mean of two potential outcomes. The first is the potential"
					noi di as text _col(11) "outcome if, contrary to fact, all subjects were exposed to x1, and"
					noi di as text _col(11) "subjects' mediator(s) were set to their potential value(s)"
					noi di as text _col(11) "under exposure to x0. The second is the potential outcome if,"
					noi di as text _col(11) "contrary to fact, all subjects were exposed to x0. That is:"
					noi di
					if "`logOR'"=="" & "`logRR'"=="" {
						noi di as result _col(19) "NDE" as text "=E[Y{X=x1,M(X=x0)}]-E[Y{X=x0,M(X=x0)}]"
					}
					if "`logOR'"!="" & "`logRR'"=="" {
						noi di as result _col(19) "NDE" as text "=log{E[Y{X=x1,M(X=x0)}]/(1-E[Y{X=x1,M(X=x0)}])}-log{E[Y{X=x0,M(X=x0)}]/(1-E[Y{X=x0,M(X=x0)}])}"
					}
					if "`logOR'"=="" & "`logRR'"!="" {
						noi di as result _col(19) "NDE" as text "=log(E[Y{X=x1,M(X=x0)}])-log(E[Y{X=x0,M(X=x0)}])"
					}
					noi di
					noi di as text _col(11) "The natural indirect effect (" as result "NIE" as text ") is the difference between"
					noi di as text _col(11) "the " as result "TCE" as text " and the " as result "NDE" as text ". That is:"
					noi di
					if "`logOR'"=="" & "`logRR'"=="" {
						noi di as result _col(15) "NIE" as text "=" as result "TCE" as text "-" as result "NDE" as text "=E[Y{X=x1,M(X=x1)}]-E[Y{X=x1,M(X=x0)}]"
					}
					if "`logOR'"!="" & "`logRR'"=="" {
						noi di as result _col(15) "NIE" as text "=" as result "TCE" as text "-" as result "NDE" as text "=log{E[Y{X=x1,M(X=x1)}]/(1-E[Y{X=x1,M(X=x1)}])}-log{E[Y{X=x1,M(X=x0)}]/(1-E[Y{X=x1,M(X=x0)}])}"
					}
					if "`logOR'"=="" & "`logRR'"!="" {
						noi di as result _col(15) "NIE" as text "=" as result "TCE" as text "-" as result "NDE" as text "=log(E[Y{X=x1,M(X=x1)}])-log(E[Y{X=x1,M(X=x0)}])"
					}
					noi di
					noi di as text _col(11) "The proportion mediated (" as result "PM" as text ") is the " as result "NIE " as text "divided by"
					noi di as text _col(11) "the " as result "TCE" as text "."
					noi di
					if "`control'"!="" {
						noi di as text _col(11) "The controlled direct effect (" as result "CDE" as text ") is a comparison between"
						noi di as text _col(11) "the mean potential outcome when all subjects were exposed to x1"
						noi di as text _col(11) "and the mean potential outcome when all subjects were"
						noi di as text _col(11) "exposed to x0; and, in addition, in both cases, the mediator(s)"
						noi di as text _col(11) "were set to their control value(s). Write m for the control"
						noi di as text _col(11) "value(s) of the mediator(s), then:"
						noi di
						if "`logOR'"=="" & "`logRR'"=="" {
							noi di as result _col(19) "CDE" as text "=E{Y(X=x1,M=m)}-E{Y(X=x0,M=m)}"
						}	
						if "`logOR'"!="" & "`logRR'"=="" {
							noi di as result _col(19) "CDE" as text "=log(E{Y(X=x1,M=m)}/[1-E{Y(X=x1,M=m)}])-log(E{Y(X=x0,M=m)}/[1-E{Y(X=x0,M=m)}])"
						}
						if "`logOR'"=="" & "`logRR'"!="" {
							noi di as result _col(19) "CDE" as text "=log[E{Y(X=x1,M=m)}]-log[E{Y(X=x0,M=m)}]"
						}
						noi di
					}			
				}
				else {
					noi di as text _col(5) "Note: The total causal effect (" as result "TCE(k)" as text "), comparing level k"
					noi di as text _col(11) "of the exposure against the baseline, is a comparison" 
					noi di as text _col(11) "between the mean potential outcome if, contrary to fact," 
					noi di as text _col(11) "all subjects were exposed at level k, and the mean"
					noi di as text _col(11) "potential outcome if all subjects received the baseline" 
					noi di as text _col(11) "level of exposure. Writing X for the exposure, M for the" 
					noi di as text _col(11) "mediator(s), Y for the outcome, and 0 for the baseline:"
					noi di
					if "`logOR'"=="" & "`logRR'"=="" {
						noi di as result _col(19) "TCE(k)" as text "=E[Y{X=k,M(X=k)}]-E[Y{X=0,M(X=0)}]"
					}	
					if "`logOR'"!="" & "`logRR'"=="" {
						noi di as result _col(19) "TCE(k)" as text "=log{E[Y{X=k,M(X=k)}]/(1-E[Y{X=k,M(X=k)}])}-log{E[Y{X=0,M(X=0)}]/(1-E[Y{X=0,M(X=0)}])}"
					}
					if "`logOR'"=="" & "`logRR'"!="" {
						noi di as result _col(19) "TCE(k)" as text "=log(E[Y{X=k,M(X=k)}])-log(E[Y{X=0,M(X=0)}])"
					}	
					noi di
					noi di as text _col(11) "The natural direct effect (" as result "NDE(k)" as text ") is a comparison between the"
					noi di as text _col(11) "mean of two potential outcomes. The first is the potential"
					noi di as text _col(11) "outcome if, contrary to fact, all subjects received exposure" 
					noi di as text _col(11) "k, and subjects' mediator(s) were set to their potential"
					noi di as text _col(11) "value(s) under baseline exposure. The second is the potential"
					noi di as text _col(11) "outcome if, contrary to fact, all subjects experienced the"
					noi di as text _col(11) "baseline exposure. That is:"
					noi di
					if "`logOR'"=="" & "`logRR'"=="" {
						noi di as result _col(19) "NDE(k)" as text "=E[Y{X=k,M(X=0)}]-E[Y{X=0,M(X=0)}]"
					}
					if "`logOR'"!="" & "`logRR'"=="" {
						noi di as result _col(19) "NDE(k)" as text "=log{E[Y{X=k,M(X=0)}]/(1-E[Y{X=k,M(X=0)}])}-log{E[Y{X=0,M(X=0)}]/(1-E[Y{X=0,M(X=0)}])}"
					}
					if "`logOR'"=="" & "`logRR'"!="" {
						noi di as result _col(19) "NDE(k)" as text "=log(E[Y{X=k,M(X=0)}])-log(E[Y{X=0,M(X=0)}])"
					}
					noi di
					noi di as text _col(11) "The natural indirect effect (" as result "NIE(k)" as text ") is the difference between"
					noi di as text _col(11) "the " as result "TCE(k)" as text " and the " as result "NDE(k)" as text ". That is:"
					noi di
					if "`logOR'"=="" & "`logRR'"=="" {
						noi di as result _col(15) "NIE(k)" as text "=" as result "TCE(k)" as text "-" as result "NDE(k)" as text "=E[Y{X=k,M(X=k)}]-E[Y{X=k,M(X=0)}]"
					}
					if "`logOR'"!="" & "`logRR'"=="" {
						noi di as result _col(15) "NIE(k)" as text "=" as result "TCE(k)" as text "-" as result "NDE(k)" as text "=log{E[Y{X=k,M(X=k)}]/(1-E[Y{X=k,M(X=k)}])}-log{E[Y{X=k,M(X=0)}]/(1-E[Y{X=k,M(X=0)}])}"
					}
					if "`logOR'"=="" & "`logRR'"!="" {
						noi di as result _col(15) "NIE(k)" as text "=" as result "TCE(k)" as text "-" as result "NDE(k)" as text "=log(E[Y{X=k,M(X=k)}])-log(E[Y{X=k,M(X=0)}])"
					}				
					noi di
					noi di as text _col(11) "The proportion mediated (" as result "PM(k)" as text ") is the " as result "NIE(k) " as text "divided by"
					noi di as text _col(11) "the " as result "TCE(k)" as text "."
					noi di
					if "`control'"!="" {
						noi di as text _col(11) "The controlled direct effect (" as result "CDE(k,m)" as text ") is a comparison between"
						noi di as text _col(11) "the mean potential outcome if all subjects were exposed at"
						noi di as text _col(11) "level k, and the mean potential outcome if all subjects" 
						noi di as text _col(11) "received the baseline exposure; and, in addition, in both"
						noi di as text _col(11) "cases, the mediator(s) were set to their control value(s)."
						noi di as text _col(11) "Write m for the control value(s) of the mediator(s), then:"
						noi di
						if "`logOR'"=="" & "`logRR'"=="" {
							noi di as result _col(19) "CDE(k,m)" as text "=E{Y(X=k,M=m)}-E{Y(X=0,M=m)}"
						}
						if "`logOR'"!="" & "`logRR'"=="" {
							noi di as result _col(19) "CDE(k,m)" as text "=log(E{Y(X=k,M=m)}/[1-E{Y(X=k,M=m)}])-log(E{Y(X=0,M=m)}/[1-E{Y(X=0,M=m)}])"
						}	
						if "`logOR'"=="" & "`logRR'"!="" {
							noi di as result _col(19) "CDE(k,m)" as text "=log[E{Y(X=k,M=m)}]-log[E{Y(X=0,M=m)}]"
						}					
						noi di
					}
				}
			}
		}
	}	
	noi di as text " "
	if "`obe'"=="" & "`linexp'"=="" {
		noi di as text _col(10) "Baseline value(s): "
	}
	* Display labels must use the caller's names; working aliases remain active
	* until the data-restoration block below.
	local _gc_display_exposure `"`originalexposure'"'
	local _gc_display_mediator `"`originalmediator'"'
	local _gc_display_control `"`originalcontrol'"'
	local _gc_display_baseline `"`originalbaseline'"'
	local _gc_display_alternative `"`originalalternative'"'
	tokenize "`_gc_display_exposure'"
	local nbase 0 			
	while "`1'"!="" {
		if "`1'"!="," {
			local nbase=`nbase'+1
			local expos`nbase' "`1'"
		}
		mac shift
	}
    tokenize "`_gc_display_mediator'"
	local nmed 0 			
	while "`1'"!="" {
		if "`1'"!="," {
			local nmed=`nmed'+1
			local medi`nmed' "`1'"
		}
		mac shift
	}
	if "`obe'"=="" & "`linexp'"=="" {
		_gcomp_detangle `"`baseline'"' baseline `"`exposure'"'
		forvalues i=1/`nbase' {
			local baseline`i' `"`r(value`i')'"'
		}
	}
    if "`control'"!="" {
        _gcomp_detangle `"`control'"' control `"`mediator'"'
        forvalues i=1/`nmed' {
	        	local control`i' `"`r(value`i')'"'
        }
    }
	if "`obe'"=="" & "`linexp'"=="" {
		forvalues i=1/`nbase' {
			local expos`i'="`expos`i''"+" "
			noi di as text _col(15) subinstr("`expos`i''","_ ","",.) "=" _cont
			noi di as result "`baseline`i''"
		}
	}
	if "`specific'"!="" {
		noi di as text _col(10) "Alternative value(s): "
		tokenize "`_gc_display_exposure'"
		local nbase 0 			
		while "`1'"!="" {
			if "`1'"!="," {
				local nbase=`nbase'+1
				local expos`nbase' "`1'"
			}
			mac shift
		}
		_gcomp_detangle `"`alternative'"' alternative `"`exposure'"'
		forvalues i=1/`nbase' {
			local alternative`i' `"`r(value`i')'"'
		}
		forvalues i=1/`nbase' {
			local expos`i'="`expos`i''"+" "
			noi di as text _col(15) subinstr("`expos`i''","_ ","",.) "=" _cont
			noi di as result "`alternative`i''"
		}
	}
    if "`control'"!="" {
    	noi di as text " "
    	noi di as text _col(10) "Control value(s): "
    	forvalues i=1/`nmed' { 	
			local medi`i'="`medi`i''"+" "
			noi di as text _col(15) subinstr("`medi`i''","_ ","",.) "=" _cont
			noi di as result "`control`i''"
	    }
    }
	noi di as text " "
	if "`all'"=="" {
		noi di as text _col(2)  "{hline 13}{c TT}{hline 71}"
		noi di as text _col(15) "{c |}" _col(18) "G-computation" _col(37) "Bootstrap" _col(71) "Normal-based"
		if "`logOR'"=="" & "`logRR'"=="" {
			noi di as text _col(15) "{c |}" _col(18) "estimate (MD)" _col(37) "Std. Err." _col(52) ///
            "z" _col(57) "P>|z|" _col(67) "[95% Conf. Interval]"         
		}
		if "`logOR'"!="" & "`logRR'"=="" {
			noi di as text _col(15) "{c |}" _col(18) "estimate (logOR)" _col(37) "Std. Err." _col(52) ///
            "z" _col(57) "P>|z|" _col(67) "[95% Conf. Interval]"         
		}
		if "`logOR'"=="" & "`logRR'"!="" {
			noi di as text _col(15) "{c |}" _col(18) "estimate (logRR)" _col(37) "Std. Err." _col(52) ///
            "z" _col(57) "P>|z|" _col(67) "[95% Conf. Interval]"         
		}		
		noi di as text _col(2)  "{hline 13}{c +}{hline 71}"
		if "`control'"=="" {
			local maxrowtab=4
		}
		else {
			local maxrowtab=5
		}
		if "`oce'"!="" {
			qui tab `exposure', matrow(_matrow)
			local nexplev=r(r)-1
		}
		else {
			local nexplev=1			
		}
        forvalues i=1/`maxrowtab' {
			forvalues j=1/`nexplev' {
				if `i'==1 {
					if `nexplev'==1 {
						noi di as text _col(8) "TCE" _col(15) "{c |}" _cont
					}
					else {
						local checkbase=0
						forvalues jj=1/`j' {
							local kk=_matrow[`jj',1]
							if `kk'==`baseline1' {
								local checkbase=1
							}
						}
						if `checkbase'==0 {
							local k=_matrow[`j',1]
						}
						else {
							local kkk=`j'+1
							local k=_matrow[`kkk',1]
						}
						noi di as text _col(5) "TCE(" as result "`k'" as text")" _col(15) "{c |}" _cont
					}
				}
				if `i'==2 {
					if `nexplev'==1 {
						noi di as text _col(8) "NDE" _col(15) "{c |}" _cont
					}
					else {
						local checkbase=0
						forvalues jj=1/`j' {
							local kk=_matrow[`jj',1]
							if `kk'==`baseline1' {
								local checkbase=1
							}
						}
						if `checkbase'==0 {
							local k=_matrow[`j',1]
						}
						else {
							local kkk=`j'+1
							local k=_matrow[`kkk',1]
						}
						noi di as text _col(5) "NDE(" as result "`k'" as text")" _col(15) "{c |}" _cont
					}
				}
				if `i'==3 {
					if `nexplev'==1 {
						noi di as text _col(8) "NIE" _col(15) "{c |}" _cont
					}
					else {
						local checkbase=0
						forvalues jj=1/`j' {
							local kk=_matrow[`jj',1]
							if `kk'==`baseline1' {
								local checkbase=1
							}
						}
						if `checkbase'==0 {
							local k=_matrow[`j',1]
						}
						else {
							local kkk=`j'+1
							local k=_matrow[`kkk',1]
						}
						noi di as text _col(5) "NIE(" as result "`k'" as text")" _col(15) "{c |}" _cont
					}
				}
				if `i'==4 {
					if `nexplev'==1 {
						noi di as text _col(8) "PM" _col(15) "{c |}" _cont
					}
					else {
						local checkbase=0
						forvalues jj=1/`j' {
							local kk=_matrow[`jj',1]
							if `kk'==`baseline1' {
								local checkbase=1
							}
						}
						if `checkbase'==0 {
							local k=_matrow[`j',1]
						}
						else {
							local kkk=`j'+1
							local k=_matrow[`kkk',1]
						}
						noi di as text _col(5) "PM(" as result "`k'" as text")" _col(15) "{c |}" _cont
					}
				}
				if `i'==5 {
					if `nexplev'==1 {
						noi di as text _col(8) "CDE" _col(15) "{c |}" _cont
					}
					else {
						local checkbase=0
						forvalues jj=1/`j' {
							local kk=_matrow[`jj',1]
							if `kk'==`baseline1' {
								local checkbase=1
							}
						}
						if `checkbase'==0 {
							local k=_matrow[`j',1]
						}
						else {
							local kkk=`j'+1
							local k=_matrow[`kkk',1]
						}
						noi di as text _col(5) "CDE(" as result "`k'" as text")" _col(15) "{c |}" _cont
					}
				}
				if "`oce'"=="" {
					_gcomp_display_stats, est(`=b[1,`i']') se(`=se[1,`i']') ci_lo(`=ci_normal[1,`i']') ci_hi(`=ci_normal[2,`i']') se_col(37) p_col(57)
				}
				else {
					qui tab `exposure', matrow(_matrow)
					local nexplev=r(r)-1
					local ii=(`i'-1)*`nexplev'+`j'
					_gcomp_display_stats, est(`=b[1,`ii']') se(`=se[1,`ii']') ci_lo(`=ci_normal[1,`ii']') ci_hi(`=ci_normal[2,`ii']') se_col(36) p_col(57)
					if `j'==`nexplev' & `i'!=`maxrowtab' {
						noi di as text _col(2)  "{hline 13}{c +}{hline 71}"
					}
				}
			}	
		}
		noi di as text _col(2)  "{hline 13}{c BT}{hline 71}"
	}
	else {
		noi di as text _col(2)  "{hline 13}{c TT}{hline 77}"
		noi di as text _col(15) "{c |}" _col(18) "G-computation" _col(37) "Bootstrap"
		if "`logOR'"=="" & "`logRR'"=="" {
			noi di as text _col(15) "{c |}" _col(18) "estimate (MD)" _col(37) "Std. Err." _col(52) ///
            "z" _col(57) "P>|z|" _col(67) "[95% Conf. Interval]"         
		}
		if "`logOR'"!="" & "`logRR'"=="" {
			noi di as text _col(15) "{c |}" _col(18) "estimate (logOR)" _col(37) "Std. Err." _col(52) ///
            "z" _col(57) "P>|z|" _col(67) "[95% Conf. Interval]"         
		}
		if "`logOR'"=="" & "`logRR'"!="" {
			noi di as text _col(15) "{c |}" _col(18) "estimate (logRR)" _col(37) "Std. Err." _col(52) ///
            "z" _col(57) "P>|z|" _col(67) "[95% Conf. Interval]"         
		}		
		noi di as text _col(2)  "{hline 13}{c +}{hline 77}"
        if "`control'"=="" {
            local maxrowtab=4
        }
        else {
            local maxrowtab=5
        }
		if "`oce'"!="" {
			qui tab `exposure', matrow(_matrow)
			local nexplev=r(r)-1
		}
		else {
			local nexplev=1			
		}
        forvalues i=1/`maxrowtab' {
			forvalues j=1/`nexplev' {
				if `i'==1 {
					if `nexplev'==1 {
						noi di as text _col(8) "TCE" _col(15) "{c |}" _cont
					}
					else {
						local checkbase=0
						forvalues jj=1/`j' {
							local kk=_matrow[`jj',1]
							if `kk'==`baseline1' {
								local checkbase=1
							}
						}
						if `checkbase'==0 {
							local k=_matrow[`j',1]
						}
						else {
							local kkk=`j'+1
							local k=_matrow[`kkk',1]
						}
						noi di as text _col(5) "TCE(" as result "`k'" as text")" _col(15) "{c |}" _cont
					}
				}
				if `i'==2 {
					if `nexplev'==1 {
						noi di as text _col(8) "NDE" _col(15) "{c |}" _cont
					}
					else {
						local checkbase=0
						forvalues jj=1/`j' {
							local kk=_matrow[`jj',1]
							if `kk'==`baseline1' {
								local checkbase=1
							}
						}
						if `checkbase'==0 {
							local k=_matrow[`j',1]
						}
						else {
							local kkk=`j'+1
							local k=_matrow[`kkk',1]
						}
						noi di as text _col(5) "NDE(" as result "`k'" as text")" _col(15) "{c |}" _cont
					}
				}
				if `i'==3 {
					if `nexplev'==1 {
						noi di as text _col(8) "NIE" _col(15) "{c |}" _cont
					}
					else {
						local checkbase=0
						forvalues jj=1/`j' {
							local kk=_matrow[`jj',1]
							if `kk'==`baseline1' {
								local checkbase=1
							}
						}
						if `checkbase'==0 {
							local k=_matrow[`j',1]
						}
						else {
							local kkk=`j'+1
							local k=_matrow[`kkk',1]
						}
						noi di as text _col(5) "NIE(" as result "`k'" as text")" _col(15) "{c |}" _cont
					}
				}
				if `i'==4 {
					if `nexplev'==1 {
						noi di as text _col(8) "PM" _col(15) "{c |}" _cont
					}
					else {
						local checkbase=0
						forvalues jj=1/`j' {
							local kk=_matrow[`jj',1]
							if `kk'==`baseline1' {
								local checkbase=1
							}
						}
						if `checkbase'==0 {
							local k=_matrow[`j',1]
						}
						else {
							local kkk=`j'+1
							local k=_matrow[`kkk',1]
						}
						noi di as text _col(5) "PM(" as result "`k'" as text")" _col(15) "{c |}" _cont
					}
				}
				if `i'==5 {
					if `nexplev'==1 {
						noi di as text _col(8) "CDE" _col(15) "{c |}" _cont
					}
					else {
						local checkbase=0
						forvalues jj=1/`j' {
							local kk=_matrow[`jj',1]
							if `kk'==`baseline1' {
								local checkbase=1
							}
						}
						if `checkbase'==0 {
							local k=_matrow[`j',1]
						}
						else {
							local kkk=`j'+1
							local k=_matrow[`kkk',1]
						}
						noi di as text _col(5) "CDE(" as result "`k'" as text")" _col(15) "{c |}" _cont
					}
				}
				if "`oce'"=="" {
					_gcomp_display_stats, est(`=b[1,`i']') se(`=se[1,`i']') ci_lo(`=ci_normal[1,`i']') ci_hi(`=ci_normal[2,`i']') se_col(36) p_col(57) continue
					noi di as text "   (N)"
					noi di as text _col(15) "{c |}" _cont
					noi di as result _col(66) %9.0g ci_percentile[1,`i'] _cont
					noi di as result _col(78) %9.0g ci_percentile[2,`i'] _cont
					noi di as text "   (P)"
					noi di as text _col(15) "{c |}" _cont
					noi di as result _col(66) %9.0g ci_bc[1,`i'] _cont
					noi di as result _col(78) %9.0g ci_bc[2,`i'] _cont
					noi di as text "  (BC)"
					noi di as text _col(15) "{c |}" _cont
					noi di as result _col(66) %9.0g ci_bca[1,`i'] _cont
					noi di as result _col(78) %9.0g ci_bca[2,`i'] _cont
					noi di as text " (BCa)"
				}
				else {
					qui tab `exposure', matrow(_matrow)
					local nexplev=r(r)-1
					local ii=(`i'-1)*`nexplev'+`j'
					_gcomp_display_stats, est(`=b[1,`ii']') se(`=se[1,`ii']') ci_lo(`=ci_normal[1,`ii']') ci_hi(`=ci_normal[2,`ii']') se_col(36) p_col(57) continue
					noi di as text "   (N)"
					noi di as text _col(15) "{c |}" _cont
					noi di as result _col(66) %9.0g ci_percentile[1,`ii'] _cont
					noi di as result _col(78) %9.0g ci_percentile[2,`ii'] _cont
					noi di as text "   (P)"
					noi di as text _col(15) "{c |}" _cont
					noi di as result _col(66) %9.0g ci_bc[1,`ii'] _cont
					noi di as result _col(78) %9.0g ci_bc[2,`ii'] _cont
					noi di as text "  (BC)"
					noi di as text _col(15) "{c |}" _cont
					noi di as result _col(66) %9.0g ci_bca[1,`ii'] _cont
					noi di as result _col(78) %9.0g ci_bca[2,`ii'] _cont
					noi di as text " (BCa)"
					if `j'==`nexplev' & `i'!=`maxrowtab' {
						noi di as text _col(2)  "{hline 13}{c +}{hline 77}"
					}
				}
			}
		}
		noi di as text _col(2)  "{hline 13}{c BT}{hline 77}"
		noi di as text " (N)    normal confidence interval"
		noi di as text " (P)    percentile confidence interval"
		noi di as text " (BC)   bias-corrected confidence interval"
		noi di as text " (BCa)  bias-corrected and accelerated confidence interval"
    }
}
	* =========================================================================
	* Post results to e()
	* =========================================================================
	if "`mediation'"=="" {
		local _N_obs = `maxid'
		local _N_subjects = `maxid'
		local _post_po0 = `PO0'
	}
	else {
		local _N_obs = `_gc_N_rows'
		local _N_subjects = `_gc_N_rows'
		local _post_po0 = .
	}
	local _post_nexplev = 0
	capture local _post_nexplev = `nexplev'
	local _post_logor ""
	local _post_logrr ""
	if "`logOR'" != "" local _post_logor "logor"
	if "`logRR'" != "" local _post_logrr "logrr"

	capture matrix drop b
	capture matrix drop V
	capture matrix drop se
	capture matrix drop ci_normal
	capture matrix drop ci_percentile
	capture matrix drop ci_bc
	capture matrix drop ci_bca

	* Restore the caller's data before posting so e(sample) refers to the
	* original observation rows, including an if/in-restricted analysis.
	restore
	tempvar _gc_sample_link
	quietly gen long `_gc_original_obs' = _n
	quietly frlink m:1 `_gc_original_obs', frame(`_gc_sample_frame') generate(`_gc_sample_link')
	quietly gen byte `_gc_esample' = !missing(`_gc_sample_link')
	drop `_gc_original_obs' `_gc_sample_link'

	_gcomp_post_results, b(`b_post') v(`V_post') se(`se_post') ci(`cin_post') ///
		cip(`cip_post') cibc(`cibc_post') cibca(`cibca_post') diag(`_gc_diag_saved') ///
		nobs(`_N_obs') sims(`simulations') samples(`samples') outcome(`"`outcome'"') ///
		exposure(`"`originalexposure'"') mediator(`"`originalmediator'"') ///
		po0(`_post_po0') nexplev(`_post_nexplev') esample(`_gc_esample') ///
		`mediation' `oce' `obe' `linexp' `specific' `_post_logor' `_post_logrr'
	ereturn local cmdline `"`_gc_cmdline'"'
	ereturn local idvar "`originalidvar'"
	ereturn local tvar "`originaltvar'"
	ereturn local intvars "`originalintvars'"
	ereturn local interventions `"`originalinterventions'"'
	ereturn local rngstate `"`_gc_rngstate_initial'"'
	ereturn local run_id `"`_gc_run_id'"'
	if "`graph'"!="" ereturn local graph "`_gc_graph_name'"
	ereturn scalar N_rows = `_gc_N_rows'
	ereturn scalar N_subjects = `_N_subjects'
	ereturn scalar bootstrap_requested = `samples'
	ereturn scalar bootstrap_attempted = `_gc_samples_attempted'
	ereturn scalar bootstrap_successful = `_gc_samples_successful'
	ereturn scalar bootstrap_failed = `_gc_samples_failed'
	if "`seed'"!="" ereturn scalar seed = `seed'
	if "`saving'"!="" {
		ereturn local saving `"`saving'"'
		ereturn local saved_schema_version "1"
		ereturn local saved_arm_schema `"`_gc_saved_arm_schema'"'
	}
	if "`originalimpute'"!="" {
		local _gc_post_imp_n : word count `originalimpute'
		ereturn local impute_targets "`originalimpute'"
		ereturn scalar N_impute_targets = `_gc_post_imp_n'
		forvalues _gc_ii=1/`_gc_post_imp_n' {
			local _gc_imp_name : word `_gc_ii' of `originalimpute'
			ereturn local impute_target_`_gc_ii' "`_gc_imp_name'"
			ereturn scalar impute_needed_`_gc_ii' = `_gc_imp_needed_`_gc_ii''
			ereturn scalar impute_eligible_`_gc_ii' = `_gc_imp_eligible_`_gc_ii''
			ereturn scalar impute_dropped_`_gc_ii' = `_gc_imp_dropped_`_gc_ii''
		}
	}
	if "`msm'"!="" {
		ereturn local msm `"`originalmsm'"'
		tempname _gc_posted_b_names
		matrix `_gc_posted_b_names' = e(b)
		local _gc_posted_fullnames : colfullnames `_gc_posted_b_names'
		local _gc_msm_names ""
		forvalues _gc_mi=1/`r1' {
			local _gc_posted_name : word `_gc_mi' of `_gc_posted_fullnames'
			local _gc_msm_names "`_gc_msm_names' `_gc_posted_name'"
		}
		local _gc_msm_names = strtrim("`_gc_msm_names'")
		ereturn local msm_colnames "`_gc_msm_names'"
	}
	* --- Component-model manifest (savemodels): record what was captured ---
	if "`savemodels'"!="" & `_gc_n_models'>0 {
		ereturn local model_names   "`_gc_model_names'"
		ereturn local model_cmds    "`_gc_model_cmds'"
		ereturn local model_depvars "`_gc_model_depvars'"
		ereturn local model_skipped "`_gc_model_skipped'"
		ereturn local model_capture "analytic_sample_refit_approximation"
		ereturn scalar N_models = `_gc_n_models'
		forvalues _gck = 1/`_gc_n_models' {
			ereturn local model_eq_`_gck' "`_gc_model_eq_`_gck''"
		}
	}
	_estimates unhold `_gc_caller_estimates', not

	} /* end capture noisily */
local _gc_rc = _rc

* Restore is still pending on any error before the successful posting path.
capture restore
capture frame drop `_gc_sample_frame'
if `_gc_rc' & "`_gc_graph_name'" != "" capture graph drop `_gc_graph_name'
if `_gc_rc' & `"`_gc_model_names'"' != "" capture estimates drop `_gc_model_names'

* Clean up non-temp matrices (outside capture noisily so they're always cleaned)
capture matrix drop b
capture matrix drop V
capture matrix drop se
capture matrix drop ci_normal
capture matrix drop ci_percentile
capture matrix drop ci_bc
capture matrix drop ci_bca
capture matrix drop _matrow
capture matrix drop matvis
capture matrix drop _gc_diag_result

* Restore every literal matrix name to its entry state.  This runs after the
* gcomp results have been copied to tempnames and posted to e().
local _gc_matrix_index 0
foreach _gc_matrix_name of local _gc_literal_matrices {
	local ++_gc_matrix_index
	if `_gc_had_matrix`_gc_matrix_index'' {
		matrix `_gc_matrix_name' = `_gc_caller_matrix`_gc_matrix_index''
	}
	else {
		capture matrix drop `_gc_matrix_name'
	}
}

* Restore settings
set varabbrev `_gc_varabbrev'
if `_gc_rc' exit `_gc_rc'

end


* =============================================================================
* Post estimation results to e()
* =============================================================================
capture program drop _gcomp_post_results
program define _gcomp_post_results, eclass
version 16.0
local _gc_varabbrev = c(varabbrev)
set varabbrev off
capture noisily {
		syntax, B(name) V(name) SE(name) CI(name) NOBS(integer) SIMS(integer) SAMples(integer) OUTcome(string) ///
		[CIP(name) CIBC(name) CIBCA(name) DIAG(name) MEDiation OCE OBE LINEXP SPECIFIC LOGOR LOGRR ///
		EXposure(string) MEDIator(string) PO0(real 0) NEXPLEV(integer 0) ESAMPLE(varname)]

	ereturn post `b' `v', obs(`nobs') esample(`esample')
	ereturn local cmd "gcomp"
	if "`mediation'" != "" {
		ereturn local analysis_type "mediation"
		ereturn local outcome "`outcome'"
		ereturn local exposure "`exposure'"
		ereturn local mediator "`mediator'"
		if "`obe'" != "" ereturn local mediation_type "obe"
		else if "`oce'" != "" ereturn local mediation_type "oce"
		else if "`linexp'" != "" ereturn local mediation_type "linexp"
		else if "`specific'" != "" ereturn local mediation_type "specific"
		else ereturn local mediation_type "baseline"
		if "`logor'" != "" ereturn local scale "logOR"
		else if "`logrr'" != "" ereturn local scale "logRR"
		else ereturn local scale "RD"
	}
	else {
		ereturn local analysis_type "time_varying"
		ereturn local outcome "`outcome'"
	}
	ereturn scalar N = `nobs'
	ereturn scalar MC_sims = `sims'
	ereturn scalar samples = `samples'
	ereturn matrix se = `se'
	ereturn matrix ci_normal = `ci'
	if "`cip'" != "" capture ereturn matrix ci_percentile = `cip'
	if "`cibc'" != "" capture ereturn matrix ci_bc = `cibc'
	if "`cibca'" != "" capture ereturn matrix ci_bca = `cibca'
	if "`diag'" != "" {
		capture confirm matrix `diag'
		if _rc == 0 {
			ereturn matrix model_diagnostics = `diag'
		}
	}

	* Convenience scalars
	if "`mediation'" != "" {
		if "`oce'" == "" {
			tempname _bvec
			matrix `_bvec' = e(b)
			ereturn scalar tce = `_bvec'[1, colnumb(`_bvec', "tce")]
			ereturn scalar nde = `_bvec'[1, colnumb(`_bvec', "nde")]
			ereturn scalar nie = `_bvec'[1, colnumb(`_bvec', "nie")]
			ereturn scalar pm = `_bvec'[1, colnumb(`_bvec', "pm")]
			if colnumb(`_bvec', "cde") != . {
				ereturn scalar cde = `_bvec'[1, colnumb(`_bvec', "cde")]
			}
			tempname _sevec
			matrix `_sevec' = e(se)
			ereturn scalar se_tce = `_sevec'[1, colnumb(`_sevec', "tce")]
			ereturn scalar se_nde = `_sevec'[1, colnumb(`_sevec', "nde")]
			ereturn scalar se_nie = `_sevec'[1, colnumb(`_sevec', "nie")]
			ereturn scalar se_pm = `_sevec'[1, colnumb(`_sevec', "pm")]
			if colnumb(`_sevec', "cde") != . {
				ereturn scalar se_cde = `_sevec'[1, colnumb(`_sevec', "cde")]
			}
		}
		else {
			tempname _bvec_oce
			matrix `_bvec_oce' = e(b)
			forvalues j = 1/`nexplev' {
				ereturn scalar tce_`j' = `_bvec_oce'[1, colnumb(`_bvec_oce', "tce_`j'")]
				ereturn scalar nde_`j' = `_bvec_oce'[1, colnumb(`_bvec_oce', "nde_`j'")]
				ereturn scalar nie_`j' = `_bvec_oce'[1, colnumb(`_bvec_oce', "nie_`j'")]
				ereturn scalar pm_`j' = `_bvec_oce'[1, colnumb(`_bvec_oce', "pm_`j'")]
				if colnumb(`_bvec_oce', "cde_`j'") != . {
					ereturn scalar cde_`j' = `_bvec_oce'[1, colnumb(`_bvec_oce', "cde_`j'")]
				}
			}
		}

		* Build e(effects) matrix for effecttab integration
		if "`oce'" == "" {
			tempname _eff_bvec _eff_civec
			matrix `_eff_bvec' = e(b)
			matrix `_eff_civec' = e(ci_normal)
			local _eff_names "TCE NDE NIE PM"
			if colnumb(`_eff_bvec', "cde") != . {
				local _eff_names "`_eff_names' CDE"
			}
			local _n_eff : word count `_eff_names'
			tempname _effects _eff_sevec
			matrix `_effects' = J(`_n_eff', 4, .)
			matrix `_eff_sevec' = e(se)
			local _ei 0
			foreach _en in tce nde nie pm cde {
				if colnumb(`_eff_bvec', "`_en'") == . continue
				local _ei = `_ei' + 1
				local _col_idx = colnumb(`_eff_bvec', "`_en'")
				matrix `_effects'[`_ei', 1] = `_eff_bvec'[1, `_col_idx']
				matrix `_effects'[`_ei', 2] = `_eff_civec'[1, `_col_idx']
				matrix `_effects'[`_ei', 3] = `_eff_civec'[2, `_col_idx']
				local _se_val = `_eff_sevec'[1, `_col_idx']
				if `_se_val' > 0 {
					local _z = `_eff_bvec'[1, `_col_idx'] / `_se_val'
					matrix `_effects'[`_ei', 4] = 2 * normal(-abs(`_z'))
				}
			}
			matrix colnames `_effects' = estimate ci_lower ci_upper pvalue
			capture matrix rownames `_effects' = `_eff_names'
			ereturn matrix effects = `_effects'
		}
	}
	else {
		ereturn scalar obs_data = `po0'
	}
}
local _gc_rc = _rc
set varabbrev `_gc_varabbrev'
if `_gc_rc' exit `_gc_rc'
end

capture mata: mata drop _gcomp_alias_expression()
capture mata: mata drop _gcomp_expression_uses_variable()
mata:
real scalar _gcomp_expression_uses_variable(string scalar s,
                                            string scalar target)
{
    string scalar ch, tok, next
    real scalar i, j, k

    i = 1
    while (i <= strlen(s)) {
        ch = substr(s, i, 1)
        if (regexm(ch, "[A-Za-z_]")) {
            j = i + 1
            while (j <= strlen(s) & regexm(substr(s, j, 1), "[A-Za-z0-9_]")) {
                j++
            }
            tok = substr(s, i, j-i)
            if (tok == target) {
                k = j
                while (k <= strlen(s) & strpos(" " + char(9), substr(s, k, 1))) k++
                next = k <= strlen(s) ? substr(s, k, 1) : ""
                if (next != "." & next != "(") return(1)
            }
            i = j
        }
        else i++
    }
    return(0)
}

string scalar _gcomp_alias_expression(string scalar s,
                                      string scalar from_string,
                                      string scalar to_string)
{
    string rowvector from, to
    string scalar out, ch, tok, next
    real rowvector hit
    real scalar i, j, k

    from = tokens(from_string)
    to = tokens(to_string)
    if (cols(from) != cols(to)) _error(3200)

    out = ""
    i = 1
    while (i <= strlen(s)) {
        ch = substr(s, i, 1)
        if (regexm(ch, "[A-Za-z_]")) {
            j = i + 1
            while (j <= strlen(s) & regexm(substr(s, j, 1), "[A-Za-z0-9_]")) {
                j++
            }
            tok = substr(s, i, j-i)
            hit = selectindex(from :== tok)
            k = j
            while (k <= strlen(s) & strpos(" " + char(9), substr(s, k, 1))) k++
            next = k <= strlen(s) ? substr(s, k, 1) : ""
            if (cols(hit) & next != "." & next != "(") tok = to[hit[1]]
            out = out + tok
            i = j
        }
        else {
            out = out + ch
            i++
        }
    }
    return(out)
}
end

exit
