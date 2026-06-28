*! gcomp Version 1.4.0  2026/06/28
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
*!   - Eliminated global macro pollution (`_gc_maxid', $check_*, `_gc_almost')
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
capture noisily {
syntax varlist(min=2 numeric) [if] [in] , OUTcome(varname) COMmands(string) EQuations(string) [Idvar(varname) ///
    Tvar(varname) VARyingcovariates(varlist) intvars(varlist) interventions(string) monotreat dynamic eofu pooled death(varname) ///
    derived(varlist) derrules(string) FIXedcovariates(varlist) LAGgedvars(varlist) lagrules(string) msm(string) ///
    mediation EXposure(varlist) mediator(varlist) control(string) baseline(string) alternative(string) base_confs(varlist) ///
    post_confs(varlist) impute(varlist) imp_eq(string) imp_cmd(string) imp_cycles(int 10) SIMulations(int 99999) ///
	SAMples(int 1000) seed(int 0) obe oce specific boceam linexp minsim moreMC logOR logRR all DIAGnostics graph saving(string) replace ///
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
local _gc_keepvars `varlist'
foreach _gc_varblock in outcome idvar tvar varyingcovariates intvars death derived fixedcovariates laggedvars exposure mediator base_confs post_confs impute {
	local _gc_keepvars `"`_gc_keepvars' ``_gc_varblock''"'
}
local _gc_keepvars : list uniq _gc_keepvars
preserve
if "`in'"!="" {
	qui keep `in'
}
if "`if'"!="" {
	qui keep `if'
}
if "`_gc_keepvars'"!="" {
	qui keep `_gc_keepvars'
}
local if
local in
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
		qui count if `var'==.
		qui replace `missing'=1 if `var'==.
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
				qui count if `var'==. & `tvar'!=`maxvlab'
				qui replace `missing'=1 if `var'==. & `tvar'!=`maxvlab'
				if r(N)!=0 {
					noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
				}
			}
			else {
				qui count if `var'==. & `tvar'!=`maxvlab' & `death'!=1
				qui replace `missing'=1 if `var'==. & `tvar'!=`maxvlab' & `death'!=1
				if r(N)!=0 {
					noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
				}
			}
		}
	}
	foreach var in `fixedcovariates' {
		if strmatch(" "+"`impute'"+" ","* `var' *")==0 {
			if "`death'"=="" {
				qui count if `var'==. & `tvar'!=`maxvlab'
				qui replace `missing'=1 if `var'==. & `tvar'!=`maxvlab'
				if r(N)!=0 {
					noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
				}
			}
			else {
				qui count if `var'==. & `tvar'!=`maxvlab' & `death'!=1
				qui replace `missing'=1 if `var'==. & `tvar'!=`maxvlab' & `death'!=1
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
			if "${S_`i'}"!="" {
				local command`i' ${S_`i'}
			}
		}
		if "`command1'"!="logit" {
			noi di as err "Error: death must be simulated from a sequence of logistic regressions." 
			exit 198
		}
		if strmatch(" "+"`impute'"+" ","* `death' *")==1 {
			noi di as err "Missing values of " as text "`death'" as err " cannot be imputed."
			exit 198
		}
		qui count if `death'==. & `tvar'!=`firstv'
		qui replace `missing'=1 if `death'==. & `tvar'!=`firstv'
		if r(N)!=0 {
			noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`death'" as err "." 
		}
	}
	foreach var in `varyingcovariates' {
		if strmatch(" "+"`impute'"+" ","* `var' *")==0 {
			if "`death'"=="" {
				qui count if `var'==. & `tvar'!=`firstv' & `tvar'!=`maxvlab'
				qui replace `missing'=1 if `var'==. & `tvar'!=`firstv' & `tvar'!=`maxvlab'
				if r(N)!=0 {
					noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
				}
			}
			else {
				qui count if `var'==. & `tvar'!=`firstv' & `tvar'!=`maxvlab' & `death'!=1
				qui replace `missing'=1 if `var'==. & `tvar'!=`firstv' & `tvar'!=`maxvlab' & `death'!=1
				if r(N)!=0 {
					noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
				}
			}
		}
	}	
	if "`death'"!="" {
		if strmatch(" "+"`impute'"+" ","* `outcome' *")==1 {
			noi di as err "Missing values of " as text "`outcome'" as err " cannot be imputed."
			exit 198
		}
		qui count if `outcome'==. & `tvar'!=`firstv' & `death'!=1
		qui replace `missing'=1 if `outcome'==. & `tvar'!=`firstv' & `death'!=1
		if r(N)!=0 {
			noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`outcome'" as err "." 
		}
	}
	else {
		if strmatch(" "+"`impute'"+" ","* `outcome' *")==1 {
			noi di as err "Missing values of " as text "`outcome'" as err " cannot be imputed."
			exit 198
		}
		qui count if `outcome'==. & `tvar'!=`firstv'
		qui replace `missing'=1 if `outcome'==. & `tvar'!=`firstv'
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
			if "${S_`i'}"!="" {
				local command`i' ${S_`i'}
			}
		}
		if "`command`nvar''"!="logit" {
			noi di as err "Error: the monotreat option can only be used with the model for the intervention variable specified as a logistic regression." 
			exit 198
		}
	}
}
else {
	foreach var in `exposure' {
		if strmatch(" "+"`impute'"+" ","* `var' *")==0 {
			qui count if `var'==.
			qui replace `missing'=1 if `var'==.
			if r(N)!=0 {
				noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
			}
		}
	}
	foreach var in `mediator' {
		if strmatch(" "+"`impute'"+" ","* `var' *")==0 {
			qui count if `var'==.
			qui replace `missing'=1 if `var'==.
			if r(N)!=0 {
				noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
			}
		}
	}
	foreach var in `base_confs' {
		if strmatch(" "+"`impute'"+" ","* `var' *")==0 {
			qui count if `var'==.
			qui replace `missing'=1 if `var'==.
			if r(N)!=0 {
				noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on " as text "`var'" as err "." 
			}
		}
	}
	foreach var in `post_confs' {
		if strmatch(" "+"`impute'"+" ","* `var' *")==0 {
			qui count if `var'==.
			qui replace `missing'=1 if `var'==.
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
		if "${S_`i'}"!="" {
			local imp_eq`i' ${S_`i'}
		}	
	}
	forvalues i=1/`imp_nvar' {
		qui replace `missing2'=1
		local imp_var`i': word `i' of `impute'
		foreach var in `imp_eq`i'' {
			local var=subinstr("`var'","i.","",1)
			qui replace `missing2'=0 if `var'!=.
		}
		qui count if `missing2'==1
		if r(N)!=0 {
			noi di as err "Warning: " as result r(N) as err " observations dropped due to missing data on all variables needed to impute " as text "`imp_var`i''" as err "." 
		}	
		qui drop if `missing2'==1
	}
}

qui drop if `missing'==1

if _N == 0 {
	noi di as err "Error: no observations remain after dropping missing data."
	exit 2000
}

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
if "`boceam'"!="" {
	local _nmed: word count `mediator'
	if `_nmed' > 1 {
		noi di as err "Error: boceam (BOCE-AM) currently supports a single mediator; mediator() lists `_nmed'."
		noi di as err "       Specify a single mediator, or combine the mediators into one variable."
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
	if "${S_`i'}"!="" {
		local command`i' ${S_`i'}
	}
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
	if "${S_`i'}"!="" {
		local equation`i' ${S_`i'}
	}
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
* Equation predictors exist in the dataset
forvalues i=1/`nvar' {
	local _v: word `i' of `varlist2'
	local _eq "`equation`i''"
	foreach _pred in `_eq' {
		local _pred_clean = subinstr("`_pred'", "i.", "", 1)
		capture confirm variable `_pred_clean'
		if _rc {
			noi di as err "equations(): variable `_pred' in the equation for `_v' does not exist in the dataset"
			noi di as err "  Check spelling. Available variables: `varlist'"
			exit 111
		}
	}
}
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
		* Robust binary check via count of non-0/1 values. (Do NOT use
		* `tabulate' here: it errors r(134) "too many values" on a continuous
		* variable with many distinct levels, which crashes gcomp at moderate N.)
		qui count if `_v' < . & `_v' != 0 & `_v' != 1
		if r(N) > 0 {
			qui summ `_v' if `_v' < .
			noi di as err "Warning: commands() specifies logit for `_v', but it has values outside {0, 1} (min=" r(min) ", max=" r(max) ")."
			noi di as err "  logit requires a binary (0/1) variable. Consider mlogit or ologit."
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
* Outcome not in its own equation
local _out_eq "`equation`nvar''"
foreach _pred in `_out_eq' {
	local _pred_clean = subinstr("`_pred'", "i.", "", 1)
	if "`_pred_clean'" == "`outcome'" {
		noi di as err "equations(): the outcome `outcome' appears as a predictor in its own equation"
		noi di as err "  This creates a circular dependency. Remove `outcome' from the RHS."
		exit 198
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
			if "${S_`_li'}" != "" {
				tokenize "${S_`_li'}", parse(" ")
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
	}
}
* Imputation-specific validation
if "`impute'" != "" {
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
		local _imp_c "${S_`_ii'}"
		if "`_imp_c'" != "" & !inlist("`_imp_c'", "logit", "regress", "mlogit", "ologit") {
			local _imp_v: word `_ii' of `impute'
			noi di as err "imp_cmd(): `_imp_c' is not a supported imputation command for `_imp_v'"
			noi di as err "  Supported: logit, regress, mlogit, ologit"
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
* Refit each simulation model ONCE on the analytic sample (data is still in its
* original long form here, before rename/reshape), est store as _gcomp_m_*, and
* record a manifest in gcomp-scope locals for posting to e() after bootstrap.
local _gc_n_models 0
if "`savemodels'"!="" {
	capture noisily _gcomp_refit_models, vars(`varlist2') ///
		commands(`commands') equations(`equations') stub(_gcomp_m) ///
		analysis(`=cond("`mediation'"!="","mediation","time_varying")') `pooled'
	if _rc {
		noi di as err "Warning: component-model capture (savemodels) failed; continuing without it."
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
		if "`mediation'"=="" & "`pooled'"=="" & `_gc_n_models'>0 {
			noi di as text "   Note: captured component models are pooled across visits (faithful per-visit columns are not yet available)."
		}
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
		if "${S_`i'}"!="" {
			local imp_cmd`i' ${S_`i'}
		}
	}
	* _gcomp_detangle imputation equations
	_gcomp_detangle "`imp_eq'" imp_eq "`impute'"
	forvalues i=1/`imp_nvar' {
		if "${S_`i'}"!="" {
			local imp_eq`i' ${S_`i'}
		}
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

*************************************************************************************************************************************************
if "`mediation'"!="" & "`post_confs'"=="" {
	tempvar junk
	gen double `junk'=rnormal()
	local post_confs="`"+"junk"+"'"
	local varlist2="`post_confs'"+" "+"`mediator'"+" "+"`outcome'"
	local nvar: word count `varlist2'
	local commands="`junk': regress, "+"`commands'"
	local equations="`junk': , "+"`equations'"
	_gcomp_detangle "`commands'" command "`varlist2'"
	forvalues i=1/`nvar' {
		if "${S_`i'}"!="" {
			local command`i' ${S_`i'}
		}	
	}
	_gcomp_detangle "`equations'" equation "`varlist2'"
	forvalues i=1/`nvar' {
		if "${S_`i'}"!="" {
			local equation`i' ${S_`i'}
		}
	}	
	forvalues i=1/`nvar' {
		local simvar`i': word `i' of `varlist2'
	}
}
*************************************************************************************************************************************************

local _gc_check_delete = 0
local _gc_check_print = 0
local _gc_check_save = 0
if "`saving'"!="" {
	local _gc_check_save = 1
}
local originallist "varlist varlist2 if in outcome commands equations idvar tvar varyingcovariates intvars interventions eofu pooled death derived derrules fixedcovariates laggedvars lagrules msm mediation exposure mediator control baseline alternative base_confs post_confs impute imp_eq imp_cmd imp_cycles simulations samples seed all graph"
foreach member of local originallist {
	local original`member' "``member''"
}
*first, we rename each varname as varname_ so that when we change from long to wide format,
*we don't have any problems 
foreach var in `varlist' {
	local newname="`var'"+"_"
	rename `var' `newname'
}
*we also need to change the names in all the macros listed in the syntax command
local listofstrings "varlist varlist2 if in outcome commands equations idvar tvar varyingcovariates intvars interventions death derived derrules fixedcovariates laggedvars lagrules msm exposure mediator base_confs post_confs impute imp_eq imp_cmd control baseline alternative"
foreach currstring of local listofstrings {
	tokenize "``currstring''"
	local i=1
	while "`1'"!="" {
		local match=0
		foreach var in `originalvarlist' {
			if rtrim(ltrim("`1'"))==rtrim(ltrim("`var'")) {
				local match=1
				local bit1_`i'="`1'"+"_"
			}
			if rtrim(ltrim("`1'"))=="i."+rtrim(ltrim("`var'")) {
				local match=1
				local bit1_`i'="`1'"+"_"
			}
		}
		if `match'==0 {
			local bit1_`i' "`1'"
		}
		local i=`i'+1
		local bit1_`i' " "
		local i=`i'+1
		mac shift
	}
	local k1=`i'-1
	local m=1
	local mp=2
	local listofchars ", \ : = < > & | ! ( ) [ ] * / + - ^"
	foreach parchar of local listofchars {
		local k`mp'=0
		local i=1
		forvalues j=1(1)`k`m'' {
			tokenize "`bit`m'_`j''", parse("`parchar'")
			while "`1'"!="" {
				local match=0
				foreach var in `originalvarlist' {
					if rtrim(ltrim("`1'"))==rtrim(ltrim("`var'")) {
						local match=1
						local bit`mp'_`i'="`1'"+"_"
					}
					if rtrim(ltrim("`1'"))=="i."+rtrim(ltrim("`var'")) {
						local match=1
						local bit`mp'_`i'="`1'"+"_"
					}	
				}
				if `match'==0 {
					local bit`mp'_`i' "`1'"
				}
				local i=`i'+1
				mac shift
			}
			if "`bit`m'_`j''"==" " {
				local bit`mp'_`i' " "
				local i=`i'+1
			}
		}
		local k`mp'=`i'-1
		local m=`m'+1
		local mp=`mp'+1
	}
	local `currstring' ""
	forvalues j=1(1)`k`m'' {
		local `currstring' "``currstring'' `bit`m'_`j''"
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
if `seed'>0 set seed `seed'

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
	imp_cycles(`imp_cycles') sim(`simulations') `obe' `oce' `specific' `boceam' `linexp' `minsim' `moreMC' `logOR' `logRR' `graph' saving(`saving') `replace' ///
	_gc_maxid(`maxid') _gc_chk_del(`_gc_check_delete') _gc_chk_prt(`_gc_check_print') _gc_chk_sav(`_gc_check_save') _gc_almost(`_gc_almost_varlist') ///
	gcdiagnostics `_gc_diag_show'
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

local _gc_check_delete `_gc_check_delete'
local _gc_check_print `_gc_check_print'
local _gc_check_save `_gc_check_save'

if "`mediation'"=="" {	
	local _b=""
	if "`msm'"!="" {
		local r1=r(N_msm_params)
		local colnames "`r(msm_colnames)'"
		tokenize "`colnames'", parse(" ")
		local nparams 0 			
		while "`1'"!="" {
			if "`1'"!=" " {
				local nparams=`nparams'+1
				local colname`nparams'=substr(substr("`1'",strpos("`1'",":")+1,.), ///
                    strpos(substr("`1'",strpos("`1'",":")+1,.),".")+1,.)
			}
			mac shift
		}
		forvalues i=1/`r1' {
			local _b="`_b'"+" "+"r("+"`colname`i''"+")"
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
		tokenize "`colnames'", parse(" ")
		local nparams 0 			
		while "`1'"!="" {
			if "`1'"!=" " {
				local nparams=`nparams'+1
				local colname`nparams'=substr(substr("`1'",strpos("`1'",":")+1,.), ///
                    strpos(substr("`1'",strpos("`1'",":")+1,.),".")+1,.)
			}
			mac shift
		}
		forvalues i=1/`r1' {
			local _b="`_b'"+" "+"r("+"`colname`i''"+")"
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
bootstrap `_b' `_po' `_cinc', reps(`samples') `bca' noheader nolegend notable nowarn: _gcomp_bootstrap `varlist' `if' `in', ///
	out(`outcome') com(`commands') eq(`equations') i(`idvar') t(`tvar') var(`varyingcovariates') ///
	intvars(`intvars') interventions(`interventions') `monotreat' `eofu' `pooled' death(`death') derived(`derived') ///
	derrules(`derrules') fix(`fixedcovariates') lag(`laggedvars') lagrules(`lagrules') msm(`msm') `mediation' ///
	ex(`exposure') mediator(`mediator') control(`control') baseline(`baseline') alternative(`alternative') base_confs(`base_confs') ///
	post_confs(`post_confs') impute(`impute') imp_eq(`imp_eq') imp_cmd(`imp_cmd') imp_cycles(`imp_cycles') ///
	sim(`simulations') `obe' `oce' `specific' `boceam' `linexp' `minsim' `moreMC' `logOR' `logRR' saving(`saving') `replace' ///
	_gc_maxid(`maxid') _gc_chk_del(`_gc_check_delete') _gc_chk_prt(`_gc_check_print') _gc_chk_sav(`_gc_check_save') _gc_almost(`_gc_almost_varlist')
mat b=e(b)
mat V=e(V)
mat se=e(se)
mat ci_normal=e(ci_normal)
mat ci_percentile=e(ci_percentile)
mat ci_bc=e(ci_bc)
mat ci_bca=e(ci_bca)
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
	forvalues i=1/`r1' {
		local colname`i'="`colname`i''"+" "
		local colname`i'=subinstr("`colname`i''","_ ","",.)
	}
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
				if `j'<=`nint' {
					if "`death'"=="" {
						noi di as text _col(7) "Int. " `j'  _col(15) "{c |}" _cont
					}
					else {
						if `od'==0 {
							noi di as text _col(3) "Int. " `j' " (o)" _col(15) "{c |}" _cont
						}
						else {
							local indent=9+ceil(log10(`j'+1))
							noi di as text _col(`indent') "(d)" _col(15) "{c |}" _cont
						}
						local od=1-`od'
					}
				}
				else {
					if "`death'"=="" {
						noi di as result _col(2) "Obs. regime" _col(15) "{c |}"
						noi di as text _col(4) "simulated" _col(15) "{c |}" _cont
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
		graph display Graph
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
	tokenize "`exposure'"
	local nbase 0 			
	while "`1'"!="" {
		if "`1'"!="," {
			local nbase=`nbase'+1
			local expos`nbase' "`1'"
		}
		mac shift
	}
    tokenize "`mediator'"
	local nmed 0 			
	while "`1'"!="" {
		if "`1'"!="," {
			local nmed=`nmed'+1
			local medi`nmed' "`1'"
		}
		mac shift
	}
	if "`obe'"=="" & "`linexp'"=="" {
		_gcomp_detangle "`baseline'" baseline "`exposure'"
		forvalues i=1/`nbase' {
			if "${S_`i'}"!="" {
				local baseline`i' ${S_`i'}
			}
		}
	}
    if "`control'"!="" {
        _gcomp_detangle "`control'" control "`mediator'"
        forvalues i=1/`nmed' {
        	if "${S_`i'}"!="" {
        		local control`i' ${S_`i'}
        	}
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
		tokenize "`exposure'"
		local nbase 0 			
		while "`1'"!="" {
			if "`1'"!="," {
				local nbase=`nbase'+1
				local expos`nbase' "`1'"
			}
			mac shift
		}
		_gcomp_detangle "`alternative'" alternative "`exposure'"
		forvalues i=1/`nbase' {
			if "${S_`i'}"!="" {
				local alternative`i' ${S_`i'}
			}
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
					noi di as text _col(18) "{c |}" _cont
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
		local _post_po0 = `PO0'
	}
	else {
		local _N_obs = _N
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

	_gcomp_post_results, b(`b_post') v(`V_post') se(`se_post') ci(`cin_post') ///
		cip(`cip_post') cibc(`cibc_post') cibca(`cibca_post') diag(`_gc_diag_saved') ///
		nobs(`_N_obs') sims(`simulations') samples(`samples') outcome(`"`outcome'"') ///
		exposure(`"`originalexposure'"') mediator(`"`originalmediator'"') ///
		po0(`_post_po0') nexplev(`_post_nexplev') ///
		`mediation' `oce' `obe' `linexp' `specific' `_post_logor' `_post_logrr'
	if "`mediation'"=="" & "`msm'"!="" {
		ereturn local msm "`msm'"
	}
	* --- Component-model manifest (savemodels): record what was captured ---
	if "`savemodels'"!="" & `_gc_n_models'>0 {
		ereturn local model_names   "`_gc_model_names'"
		ereturn local model_cmds    "`_gc_model_cmds'"
		ereturn local model_depvars "`_gc_model_depvars'"
		ereturn scalar N_models = `_gc_n_models'
		forvalues _gck = 1/`_gc_n_models' {
			ereturn local model_eq_`_gck' "`_gc_model_eq_`_gck''"
		}
	}

} /* end capture noisily */
local _gc_rc = _rc

* Clean up _gcomp_detangle globals (runs on both success and error)
forvalues _gc_i = 1/50 {
	global S_`_gc_i'
}

* Clean up non-temp matrices (outside capture noisily so they're always cleaned)
capture matrix drop b
capture matrix drop se
capture matrix drop ci_normal
capture matrix drop ci_percentile
capture matrix drop ci_bc
capture matrix drop ci_bca
capture matrix drop _matrow
capture matrix drop matvis
capture matrix drop _gc_diag_result

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
		EXposure(string) MEDIator(string) PO0(real 0) NEXPLEV(integer 0)]

	ereturn post `b' `v', obs(`nobs')
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

exit
