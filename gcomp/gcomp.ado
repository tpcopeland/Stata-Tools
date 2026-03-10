*! gcomp Version 1.2.1  01mar2026
*! G-computation formula via Monte Carlo simulation
*! Forked from SSC gformula v1.16 beta (Rhian Daniel, 2021)
*! with bug fixes, modernization, and SSC dependency removal
*! Author: Timothy P Copeland (fork), Rhian Daniel (original)
*!
*! Changes from SSC v1.16:
*!   - Merged gformula_.ado into single file (_gcomp_bootstrap)
*!   - Fixed hardcoded `by id:` bug (idvar not honored in survival/death)
*!   - Fixed broken baseline auto-detect with oce (backtick macro bug)
*!   - Eliminated global macro pollution (`_gc_maxid', $check_*, `_gc_almost')
*!   - Replaced deprecated runiform() with rruniform()
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
|  Version: 1.12 beta                                          |
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
set varabbrev off
set more off
syntax varlist(min=2 numeric) [if] [in] , OUTcome(varname) COMmands(string) EQuations(string) [Idvar(varname) ///
    Tvar(varname) VARyingcovariates(varlist) intvars(varlist) interventions(string) monotreat dynamic eofu pooled death(varname) ///
    derived(varlist) derrules(string) FIXedcovariates(varlist) LAGgedvars(varlist) lagrules(string) msm(string) ///
    mediation EXposure(varlist) mediator(varlist) control(string) baseline(string) alternative(string) base_confs(varlist) /// 
    post_confs(varlist) impute(varlist) imp_eq(string) imp_cmd(string) imp_cycles(int 10) SIMulations(int 99999) ///
	SAMples(int 1000) seed(int 0) obe oce specific boceam linexp minsim moreMC logOR logRR all graph saving(string) replace]
preserve
keep `varlist'
if "`in'"!="" {
	qui keep if _n `in'
}
if "`if'"!="" {
	qui keep `if'
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
		local varlist2="`death'"+" "+"`outcome'"+" "+"`varyingcovariates'"+" "+"`intvars'"
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


if "`mediation'"=="" {
	tempvar countid
	qui gen long `countid'=1 in 1
	local N=_N
	forvalues i=2(1)`N' {
		local j=`i'-1          
		if `idvar'[`i']==`idvar'[`j'] {
			qui replace `countid'=`countid'[`j'] in `i'
		}
		else {
			qui replace `countid'=`countid'[`j']+1 in `i'
		}
	}
	local maxid=`countid'[`N']
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
	noi di as err "Error: varyingcovariates() must be specified for a time-varying confounding analysis."
	exit 198
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
if "`obe'"!="" | "`oce'"!="" | "`linexp'"!=="" | "`specific'"!=="" {
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
* Display in a table the parametric models that have been specified (for simulation under different interventions)
if "`mediation'"=="" {
	local varlist2="`death'"+" "+"`outcome'"+" "+"`varyingcovariates'"+" "+"`intvars'"
}
else {
	local varlist2="`post_confs'"+" "+"`mediator'"+" "+"`outcome'"
}
local nvar: word count `varlist2'
* _gcomp_detangle commands
_gcomp_detangle "`commands'" command "`varlist2'"
forvalues i=1/`nvar' {
	if "${S_`i'}"!="" {
		local command`i' ${S_`i'}
	}
}
* _gcomp_detangle equations
_gcomp_detangle "`equations'" equation "`varlist2'"
forvalues i=1/`nvar' {
	if "${S_`i'}"!="" {
		local equation`i' ${S_`i'}
	}
}
forvalues i=1/`nvar' {
	local simvar`i': word `i' of `varlist2'
}
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
if `samples'<1 {
	noi di as err "number of bootstrap samples must be 1 or more"
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
	qui gen `tvar'=.
	foreach pastvar of local _gc_almost_varlist {
		qui gen `pastvar'=.
	}
}
_gcomp_bootstrap `varlist' `if' `in', out(`outcome') com(`commands') eq(`equations') i(`idvar') t(`tvar') ///
	var(`varyingcovariates') intvars(`intvars') interventions(`interventions') `monotreat' `eofu' `pooled' death(`death') ///
	derived(`derived') derrules(`derrules') fix(`fixedcovariates') lag(`laggedvars') lagrules(`lagrules') ///
	msm(`msm') `mediation' ex(`exposure') mediator(`mediator') control(`control') baseline(`baseline') alternative(`alternative') ///
	base_confs(`base_confs') post_confs(`post_confs') impute(`impute') imp_eq(`imp_eq') imp_cmd(`imp_cmd') ///
	imp_cycles(`imp_cycles') sim(`simulations') `obe' `oce' `specific' `boceam' `linexp' `minsim' `moreMC' `logOR' `logRR' `graph' saving(`saving') `replace' ///
	_gc_maxid(`maxid') _gc_chk_del(`_gc_check_delete') _gc_chk_prt(`_gc_check_print') _gc_chk_sav(`_gc_check_save') _gc_almost(`_gc_almost_varlist')

local _gc_check_delete `_gc_check_delete'
local _gc_check_print `_gc_check_print'
local _gc_check_save `_gc_check_save'

if "`mediation'"=="" {	
	local _b=""
	if "`msm'"!="" {
		local r1=r(N_msm_params)
		local colnames: colfullnames msm_params
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
		local colnames: colfullnames msm_params
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
			local _po="`_po'"+"r(tce_`j')"
		}
		forvalues j=1/`nexplev' {
			local _po="`_po'"+"r(nde_`j')"
		}
		forvalues j=1/`nexplev' {
			local _po="`_po'"+"r(nie_`j')"
		}
		forvalues j=1/`nexplev' {
			local _po="`_po'"+"r(pm_`j')"
		}
		forvalues j=1/`nexplev' {
			local _po="`_po'"+"r(cde_`j')"
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
		forvalues _j=1/`nexplev' {
			local _colnames "`_colnames' cde_`_j'"
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
matrix `V_post' = J(`_k', `_k', 0)
forvalues _i=1/`_k' {
	matrix `V_post'[`_i', `_i'] = se[1, `_i']^2
}
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
            local maxrowtab=3
        }
        else {
            local maxrowtab=4
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
* Clean up global matrices created during display code
capture matrix drop b
capture matrix drop se
capture matrix drop ci_normal
capture matrix drop ci_percentile
capture matrix drop ci_bc
capture matrix drop ci_bca
if "`mediation'"=="" {
	local _N_obs = `maxid'
}
else {
	local _N_obs = _N
}
ereturn post `b_post' `V_post', obs(`_N_obs')
ereturn local cmd "gcomp"
if "`mediation'"!="" {
	ereturn local analysis_type "mediation"
	ereturn local outcome "`outcome'"
	ereturn local exposure "`originalexposure'"
	ereturn local mediator "`originalmediator'"
	if "`obe'"!="" ereturn local mediation_type "obe"
	if "`oce'"!="" ereturn local mediation_type "oce"
	if "`linexp'"!="" ereturn local mediation_type "linexp"
	if "`specific'"!="" ereturn local mediation_type "specific"
	if "`logOR'"!="" ereturn local scale "logOR"
	else if "`logRR'"!="" ereturn local scale "logRR"
	else ereturn local scale "RD"
}
else {
	ereturn local analysis_type "time_varying"
	ereturn local outcome "`outcome'"
	if "`msm'"!="" ereturn local msm "`msm'"
}
ereturn scalar N = `_N_obs'
ereturn scalar MC_sims = `simulations'
ereturn scalar samples = `samples'
ereturn matrix se = `se_post'
ereturn matrix ci_normal = `cin_post'
capture ereturn matrix ci_percentile = `cip_post'
capture ereturn matrix ci_bc = `cibc_post'
capture ereturn matrix ci_bca = `cibca_post'
* Convenience scalars
if "`mediation'"!="" {
	if "`oce'"=="" {
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
		forvalues j=1/`nexplev' {
			ereturn scalar tce_`j' = `_bvec_oce'[1, colnumb(`_bvec_oce', "tce_`j'")]
			ereturn scalar nde_`j' = `_bvec_oce'[1, colnumb(`_bvec_oce', "nde_`j'")]
			ereturn scalar nie_`j' = `_bvec_oce'[1, colnumb(`_bvec_oce', "nie_`j'")]
			ereturn scalar pm_`j' = `_bvec_oce'[1, colnumb(`_bvec_oce', "pm_`j'")]
			ereturn scalar cde_`j' = `_bvec_oce'[1, colnumb(`_bvec_oce', "cde_`j'")]
		}
	}
}
else {
	ereturn scalar obs_data = `PO0'
}

* Clean up _gcomp_detangle globals
forvalues _gc_i = 1/50 {
	global S_`_gc_i'
}

* Clean up non-temp matrices
capture matrix drop _matrow
capture matrix drop matvis

end


* =============================================================================
* Inner bootstrap program (was gformula_.ado in SSC)
* =============================================================================

capture program drop _gcomp_bootstrap
program define _gcomp_bootstrap, rclass
version 16.0
set varabbrev off
set more off
syntax varlist(min=2 numeric) [if] [in] , OUTcome(varname) COMmands(string) EQuations(string) [Idvar(varname) ///
	Tvar(varname) VARyingcovariates(varlist) intvars(varlist) interventions(string) monotreat eofu pooled death(varname) ///
	derived(varlist) derrules(string) FIXedcovariates(varlist) LAGgedvars(varlist) lagrules(string) msm(string) ///
	mediation EXposure(varlist) mediator(varlist) control(string) baseline(string) alternative(string) base_confs(varlist) ///
	post_confs(varlist) impute(varlist) imp_eq(string) imp_cmd(string) imp_cycles(int 10) SIMulations(int 10000) ///
	obe oce specific boceam linexp minsim moreMC logOR logRR graph saving(string) replace ///
	_gc_maxid(integer 0) _gc_chk_del(integer 0) _gc_chk_prt(integer 0) _gc_chk_sav(integer 0) _gc_almost(string)]
preserve
*for the time-varying option, the first step is to make the dataset long again; this is how we want it, 
*but we had to start with it wide for the sake of the boostrapping
local maxid=_N
if _N!=`simulations' {
	tempvar choosesample
	qui gen double `choosesample'=runiform()
	sort `choosesample'
}
if "`mediation'"=="" {
	qui replace `idvar'=_n
	drop `_gc_almost'
	drop `tvar'
	qui reshape long `_gc_almost', i(`idvar') j(`tvar')
	qui tab `tvar', matrow(matvis)
	local maxv=rowsof(matvis)
	local maxvlab=matvis[`maxv',1]
	local firstv=matvis[1,1]
}
*for the time-varying option, if the outcome is end-of-follow-up, we must check that there 
*aren't any other measures of the outcome
if "`mediation'"=="" {
	if "`eofu'"!="" {
		local k=matvis[`maxv',1]
		if `_gc_chk_del'==0 {
			if "`graph'"!="" {
				noi di as err "   Warning: graph option not available when outcome type is end-of-follow-up"
				noi di
			}
			qui count if `outcome'!=. & `tvar'!=`k'
			if r(N)>1 {
				noi di as err "   Warning: " _cont
				noi di as result r(N) _cont
				noi di as err " observations of the outcome variable are being ignored because they were recorded before the end of follow-up"
				noi di
			}
			if r(N)==1 {
				noi di as err "   Warning: " _cont
				noi di as result 1 _cont
				noi di as err " observation of the outcome variable is being ignored because it was recorded before the end of follow-up"
				noi di
			}
			local _gc_chk_del = 1
		}
		qui replace `outcome'=. if `tvar'!=`k'
	}
}
*for the time-varying option, if the outcome is survival, we need to give a warning re MSM
*if the pooled option has not been specified, or if a common intercept is not used within the pooled option
if "`mediation'"=="" {
	if "`eofu'"=="" {
		if `_gc_chk_del'==0 {
			if "`pooled'"=="" {
				noi di as err "   Warning: the MC simulations will be generated using a different logistic regression at each visit (since the "
				noi di as result "   pooled " _cont
				noi di as err "option was not specified). But the MSM will be fitted using a time-updated Cox model, asymptotically" 
				noi di as err "   equivalent to a pooled logistic regression. Thus, the MSM is not consistent with the simulation model."
				noi di
			}
			else {
				local varlist2="`death'"+" "+"`outcome'"+" "+"`varyingcovariates'"+" "+"`intvars'"
				local nvar: word count `varlist2'
				_gcomp_detangle "`equations'" equation "`varlist2'"
				forvalues i=1/`nvar' {
					if "${S_`i'}"!="" {
						local equation`i' ${S_`i'}
					}
				}
				forvalues i=1/`nvar' {
					tokenize "`varlist2'"
					if "``i''"=="`outcome'" {	
						local nvareq: word count `equation`i''
						tokenize "`equation`i''"
						forvalues j=1/`nvareq' {
							if "``j''"=="`tvar'" {
								noi di as err "   Warning: the MC simulations will be generated using a pooled logistic regression (since the " _cont
								noi di as result "pooled "
								noi di as err "   option has been specified) but with a different intercept at each visit (since " _cont
								noi di as result substr("`tvar'",1,length("`tvar'")-1) _cont
								noi di as err " was included"
								noi di as err "   in the model for the outcome). But the MSM will be fitted using a time-updated Cox model,"
								noi di as err "   asymptotically equivalent to a pooled logistic regression with a common intercept. Thus, the MSM" 
								noi di as err "   is not consistent with the simulation model."
								noi di
							}
						}
					}
				}			
			}
			local _gc_chk_del = 1
		}
	}
}
local limit=0
local limit_prop=1
local limit_done=0
local limit_could=0
if `_gc_chk_prt'==0 {
	noi di as text "   No. of subjects = " _cont
	noi di as result `maxid'
	if "`mediation'"=="" {
		if "`eofu'"=="" {
			qui count if `outcome'==1
			noi di as text "   No. of events = " _cont
			noi di as result r(N)
		}
		if "`death'"!="" {
			qui count if `death'==1
			noi di as text "   No. of deaths = " _cont
			noi di as result r(N)
		}
	}
	if "`impute'"!="" {
		local imp_nvar: word count `impute'
		if "`mediation'"!="" {
			local maxv=1
		}
		local limit=0
		local k1=max(floor((`imp_cycles'*`maxv'*`imp_nvar'-9)/2),1)
		local k2=max(ceil((`imp_cycles'*`maxv'*`imp_nvar'-9)/2),1)
		if `k2'>26 {
			local limit_prop=60/(`k1'+`k2'+8)
			local k1=26
			local k2=26
			local limit=1
			local limit_done=0
			local limit_could=0
		}
		noi di
		noi di as text "                                              {c LT}" _cont
		noi di as text "{hline `k1'}" _cont
		noi di as text "PROGRESS" _cont
		noi di as text "{hline `k2'}" _cont
		noi di as text "{c RT}"
		noi di as text "   Performing the imputation step:            {c LT}" _cont
	}
}
* The imputation step
if "`impute'"!="" {
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
	if "`mediation'"=="" {
		*lagged variables
		* _gcomp_detangle lag rules
		local nlag: word count `laggedvars'
		if `nlag' > 0 {
    	_gcomp_detangle "`lagrules'" lagrule "`laggedvars'"
    	forvalues i=1/`nlag' {
    		local lagvar`i': word `i' of `laggedvars'
    		if "${S_`i'}"!="" {
    			local lagrule`i' ${S_`i'}
    		}
    	}
    	forvalues i=1/`nlag' {
    		tokenize "`lagrule`i''", parse(" ")
    		local lagrulevar`i' "`1'"
    		local lag`i' "`2'"
    	}
		}
	}
	*derived variables
	* _gcomp_detangle derivation rules
	local nder: word count `derived'	
	if `nder'>0 {
		_gcomp_detangle "`derrules'" derrule "`derived'"
		forvalues i=1/`nder' {
			local der`i': word `i' of `derived'
			if "${S_`i'}"!="" {
				local derrule`i' ${S_`i'}
			}
		}
	}
	* we determine at which visit each variable in impute is to be imputed
	if "`mediation'"=="" {
		forvalues i=1/`imp_nvar' {
			forvalues j=1/`maxv' {
				local k=matvis[`j',1]           
				qui count if `imp_var`i''!=. & `tvar'==`k'
				if r(N)!=0 {
					local visitcalc`i'_`j'=1
				}
				else {
					local visitcalc`i'_`j'=0
				}
			}
		}
	}
	forvalues i=1/`imp_nvar' {
		tempvar imp_imp_var`i'
		qui gen double `imp_imp_var`i''=`imp_var`i''
	}
	* first, we draw the "ad hoc" imputations
	forvalues i=1/`imp_nvar' {
		tempvar adhoc`i'
		qui gen double `adhoc`i''=`imp_var`i''
		qui count if `adhoc`i''==.
		local countmiss=r(N)
		while `countmiss'>0 {
			qui replace `adhoc`i''=`imp_var`i''[1+int(_N*runiform())] if `adhoc`i''==.
			qui count if `adhoc`i''==.
			local countmiss=r(N)
		}
	}
	if "`mediation'"=="" {
		forvalues j=1/`maxv' {
			forvalues i=1/`imp_nvar' {
				local k=matvis[`j',1]
				if `visitcalc`i'_`j''==1 {
					qui replace `imp_var`i''=`adhoc`i'' if `imp_imp_var`i''==. & `tvar'==`k'
				}
				*update derived variables
				forvalues ii=1/`nder' {
					capture qui replace `der`ii''=`derrule`ii'' if `der`ii''==.
					if _rc!=0 {
						local derrule`ii'=subinword("`derrule`ii''","if","if (",1)+" )"
						capture qui replace `der`ii''=`derrule`ii'' & `der`ii''==.
					}
				}
				*update lagged variables
				sort `idvar' `tvar'
				forvalues ii=1/`nlag' {
					qui by `idvar': replace `lagvar`ii''=`lagrulevar`ii''[_n-`lag`ii''] if `lagvar`ii''==.
					qui replace `lagvar`ii''=0 if `tvar'==`firstv'
					if `lag`ii''>1 {
						forvalues next=2/`lag`ii'' {
							local nextv=matvis[`next',1]
							qui replace `lagvar`ii''=0 if `tvar'==`nextv'
						}
					}
				}
			}  
		}
	}
	else {
		forvalues i=1/`imp_nvar' {
			qui replace `imp_var`i''=`adhoc`i'' if `imp_imp_var`i''==.
		}  
		*update derived variables
		forvalues i=1/`nder' {
			capture qui replace `der`i''=`derrule`i'' if `der`i''==.
			if _rc!=0 {
				local derrule`i'=subinword("`derrule`i''","if","if (",1)+" )"
				capture qui replace `der`i''=`derrule`i'' & `der`i''==.
			}
		}
	}
	*and now the real imputations, starting at cycle 1
	forvalues cycle=1/`imp_cycles' {
		if "`mediation'"=="" {
			* fit parametric models and impute according to parameter estimates
			forvalues j=1/`maxv' {
				forvalues i=1/`imp_nvar' {
					if `_gc_chk_prt'==0 & `limit'==0 {
						if `j'==`maxv' & `i'==`imp_nvar' & `cycle'==`imp_cycles' & `maxv'*`imp_nvar'*`imp_cycles'>=11 {
							noi di "{c RT}" _cont
						}	
						else {
							noi di "{hline 1}" _cont
						}
					}
					if `_gc_chk_prt'==0 & `limit'==1 {
						if `j'==`maxv' & `i'==`imp_nvar' & `cycle'==`imp_cycles' & `maxv'*`imp_nvar'*`imp_cycles'>=11 {
							while `limit_done'<60 {
								noi di "{hline 1}" _cont
								local limit_done=`limit_done'+1
							}
							noi di "{c RT}" _cont
						}	
						else {
							if (`limit_done'/(`limit_could'+1))<`limit_prop' & `limit_done'<60 {
								noi di "{hline 1}" _cont
								local limit_done=`limit_done'+1
							}
							local limit_could=`limit_could'+1
						}
					}
					local k=matvis[`j',1]
					if `visitcalc`i'_`j''==1 {
						if "`pooled'"=="" {
							qui `imp_cmd`i'' `imp_imp_var`i'' `imp_eq`i'' if `tvar'==`k'
						}
						else {
							qui `imp_cmd`i'' `imp_imp_var`i'' `imp_eq`i''
						}
						if "`imp_cmd`i''"=="mlogit" | "`imp_cmd`i''"=="ologit" {
							if "`imp_cmd`i''"=="mlogit" {
								local maxl=e(k_out)
								mat out_mlogit=e(out)
							}
							if "`imp_cmd`i''"=="ologit" {
								local maxl=e(k_cat)
								mat out_mlogit=e(cat)
							}
							forvalues l=1/`maxl' {
								local out_mlogit_`l'=out_mlogit[1,`l']
								capture drop _gc_pred_imp`i'_`l'
							}
							qui predict _gc_pred_imp`i'_1'-_gc_pred_imp`i'_`maxl'
						}
						else {
							tempvar pred_imp_var`i'
							qui predict `pred_imp_var`i''
						}
						if "`imp_cmd`i''"=="logit" {
							qui replace `imp_var`i''=runiform()<`pred_imp_var`i'' if `imp_imp_var`i''==. & `tvar'==`k'
						}
						if "`imp_cmd`i''"=="regress" {
							qui replace `imp_var`i''=`pred_imp_var`i''+e(rmse)*rnormal(0,1) if `imp_imp_var`i''==. & `tvar'==`k'
						}
						if "`imp_cmd`i''"=="mlogit" | "`imp_cmd`i''"=="ologit" {
							tempvar u_for_mlogit
							tempvar cumulative_pred
							qui gen double `u_for_mlogit'=runiform()
							qui gen double `cumulative_pred'=0
							forvalues l=1/`maxl' {
								qui replace `imp_var`i''=`out_mlogit_`l'' if `u_for_mlogit'>=`cumulative_pred' & `u_for_mlogit'<(`cumulative_pred'+_gc_pred_imp`i'_`l') & `imp_imp_var`i''==. & `tvar'==`k' 
								qui replace `cumulative_pred'=`cumulative_pred'+_gc_pred_imp`i'_`l'
							}
						}
						if "`imp_cmd`i''"!="regress" & "`imp_cmd`i''"!="logit" & "`imp_cmd`i''"!="mlogit" & "`imp_cmd`i''"!="ologit" {
							noi di as err "Error: only regress, logit, mlogit and ologit are supported as imputation commands in gcomp."
							exit 198
						}
					}
					*update derived variables
					forvalues ii=1/`nder' {
						capture qui replace `der`ii''=`derrule`ii'' if `der`ii''==.
						if _rc!=0 {
							local derrule`ii'=subinword("`derrule`ii''","if","if (",1)+" )"
							capture qui replace `der`ii''=`derrule`ii'' & `der`ii''==.
						}
					}
					*update lagged variables
					sort `idvar' `tvar'
					forvalues ii=1/`nlag' {
						qui by `idvar': replace `lagvar`ii''=`lagrulevar`ii''[_n-`lag`ii''] if `lagvar`ii''==.
						qui replace `lagvar`ii''=0 if `tvar'==`firstv'
						if `lag`ii''>1 {
							forvalues next=2/`lag`ii'' {
								local nextv=matvis[`next',1]
								qui replace `lagvar`ii''=0 if `tvar'==`nextv'
							}
						}
					}
				}  
			}
		}
		else {
			* fit parametric models and impute according to parameter estimates
			forvalues i=1/`imp_nvar' {
			
				if `_gc_chk_prt'==0 & `limit'==0 {
					if `i'==`imp_nvar' & `cycle'==`imp_cycles' & `imp_nvar'*`imp_cycles'>=11 {
						noi di "{c RT}" _cont
					}	
					else {
						noi di "{hline 1}" _cont
					}
				}
				if `_gc_chk_prt'==0 & `limit'==1 {
					if `i'==`imp_nvar' & `cycle'==`imp_cycles' & `imp_nvar'*`imp_cycles'>=11 {
						while `limit_done'<60 {
							noi di "{hline 1}" _cont
							local limit_done=`limit_done'+1
						}
						noi di "{c RT}" _cont
					}	
					else {
						if (`limit_done'/(`limit_could'+1))<`limit_prop' & `limit_done'<60 {
							noi di "{hline 1}" _cont
							local limit_done=`limit_done'+1
						}
						local limit_could=`limit_could'+1
					}
				}
				qui `imp_cmd`i'' `imp_imp_var`i'' `imp_eq`i''
				if "`imp_cmd`i''"=="mlogit" | "`imp_cmd`i''"=="ologit" {
					if "`imp_cmd`i''"=="mlogit" {
						local maxl=e(k_out)
						mat out_mlogit=e(out)
					}
					if "`imp_cmd`i''"=="ologit" {
						local maxl=e(k_cat)
						mat out_mlogit=e(cat)
					}
					forvalues l=1/`maxl' {
						local out_mlogit_`l'=out_mlogit[1,`l']
						capture drop _gc_pred_imp`i'_`l'
					}
					qui predict _gc_pred_imp`i'_1-_gc_pred_imp`i'_`maxl'
				}
				else {
					tempvar pred_imp_var`i'
					qui predict `pred_imp_var`i''
				}				
				if "`imp_cmd`i''"=="logit" {
					qui replace `imp_var`i''=runiform()<`pred_imp_var`i'' if `imp_imp_var`i''==.
				}
				if "`imp_cmd`i''"=="regress" {
					qui replace `imp_var`i''=`pred_imp_var`i''+e(rmse)*rnormal(0,1) if `imp_imp_var`i''==.
				}
				if "`imp_cmd`i''"=="mlogit" | "`imp_cmd`i''"=="ologit" {
					tempvar u_for_mlogit
					tempvar cumulative_pred
					qui gen double `u_for_mlogit'=runiform()
					qui gen double `cumulative_pred'=0
					forvalues l=1/`maxl' {
						qui replace `imp_var`i''=`out_mlogit_`l'' if `u_for_mlogit'>=`cumulative_pred' & `u_for_mlogit'<(`cumulative_pred'+_gc_pred_imp`i'_`l') & `imp_imp_var`i''==.
						qui replace `cumulative_pred'=`cumulative_pred'+_gc_pred_imp`i'_`l'
					}
				}
				if "`imp_cmd`i''"!="regress" & "`imp_cmd`i''"!="logit" & "`imp_cmd`i''"!="mlogit" & "`imp_cmd`i''"!="ologit" {
					noi di as err "Error: only regress, logit, mlogit and ologit are supported as imputation commands in gcomp."
					exit 198
				}
			}  
			*update derived variables
			forvalues i=1/`nder' {
				capture qui replace `der`i''=`derrule`i'' if `der`i''==.
				if _rc!=0 {
					local derrule`i'=subinword("`derrule`i''","if","if (",1)+" )"
					capture qui replace `der`i''=`derrule`i'' & `der`i''==.
				}
			}
		}
	}
	if `_gc_chk_prt'==0 {
		if "`mediation'"!="" {
			local maxv=1
		}	
		if `imp_cycles'*`maxv'*`imp_nvar'<11 {
			local k3=10-`maxv'*`imp_nvar'*`imp_cycles'
			noi di _dup(`k3') "{hline 1}" _cont
			noi di "{c RT}" _cont
		}
		noi di
	}
}
* end of imputation step and on to preparing for the MC simulation
if `_gc_chk_prt'==0 {
	noi di
	noi di as text "                                              {c LT}{hline 1}PROGRESS{hline 1}{c RT}"
	noi di as text "   Preparing dataset for MC simulations:      {c LT}" _cont
}
tempvar int_no
gen long `int_no'=0
* It will be useful to have a list of the variables for which models will be specified
if "`mediation'"=="" {
	local varlist2="`death'"+" "+"`outcome'"+" "+"`varyingcovariates'"+" "+"`intvars'"
}
else {
	local varlist2="`post_confs'"+" "+"`mediator'"+" "+"`outcome'"
}
local nvar: word count `varlist2'
local nvar_formono: word count `intvars'
local nvar_untilmono=`nvar'-`nvar_formono'
* _gcomp_detangle commands
_gcomp_detangle "`commands'" command "`varlist2'"
forvalues i=1/`nvar' {
	if "${S_`i'}"!="" {
		local command`i' ${S_`i'}
	}
}
if `_gc_chk_prt'==0 {
	noi di as text "{hline 1}" _cont
}
* _gcomp_detangle equations
_gcomp_detangle "`equations'" equation "`varlist2'"
forvalues i=1/`nvar' {
	if "${S_`i'}"!="" {
		local equation`i' ${S_`i'}
	}
}
if `_gc_chk_prt'==0 {
	noi di as text "{hline 1}" _cont
}
forvalues i=1/`nvar' {
	local simvar`i': word `i' of `varlist2'
}
if `_gc_chk_prt'==0 {
	noi di as text "{hline 1}" _cont
}
* tokenize interventions
if "`mediation'"=="" {
	tokenize "`interventions'", parse(",")
	local nint 0 			
	while "`1'"!="" {
		if "`1'"!="," {
			local nint=`nint'+1
			local int`nint' "`1'"
		}
		mac shift
	}
}
if `_gc_chk_prt'==0 {
	noi di as text "{hline 1}" _cont
}
if "`mediation'"=="" {
	forvalues i=1/`nint' {
		tokenize "`int`i''", parse("\")
		local nintcomp`i' 0 			
		while "`1'"!="" {
			if "`1'"!="\" {
				local nintcomp`i'=`nintcomp`i''+1
				local intcomp`i'`nintcomp`i'' "`1'"
			}	
			mac shift
		}
	}
}
else {
    local nbase: word count `exposure'
	if "`obe'"=="" | "`linexp'"=="" {
		_gcomp_detangle "`baseline'" baseline "`exposure'"
		forvalues i=1/`nbase' {
			if "${S_`i'}"!="" {
				local baseline`i' ${S_`i'}
			}
		}
	}
	local nbase: word count `exposure'
	if "`specific'"!="" {
		_gcomp_detangle "`alternative'" alternative "`exposure'"
		forvalues i=1/`nbase' {
			if "${S_`i'}"!="" {
				local alternative`i' ${S_`i'}
			}
		}
	}
	local nmed: word count `mediator'
    if "`control'"!="" {
        _gcomp_detangle "`control'" control "`mediator'"
        forvalues i=1/`nmed' {
        	if "${S_`i'}"!="" {
        		local control`i' ${S_`i'}
        	}
        }
    }
}
if `_gc_chk_prt'==0 {
	noi di as text "{hline 1}" _cont
}
*set up dataset ready for Monte Carlo simulation
    *increase size of dataset to make room for the new simulated observations
	local oldN=_N
	*create an id variable for mediation setting
	if "`mediation'"!="" {
		tempvar subjectid
		qui gen long `subjectid'=_n if _n<=`simulations'
	}
    if "`mediation'"=="" {
    	local newN=`oldN'+(`nint'+1)*`simulations'*`maxv'
    }
    else {
		if "`oce'"=="" {
			local nexplev=1
		}
		else {
			qui tab `exposure'
			local nexplev=r(r)-1
		}
		if "`control'"=="" {
			if "`msm'"=="" {
				local newN=`oldN'+`simulations'*(2*`nexplev'+1)
			}
			else {
				if "`boceam'"=="" {
					local newN=`oldN'+`simulations'*(2*`nexplev'+2)
				}
				else {
					qui tab `exposure' `mediator', matrow(matem1) matcol(matem2)
					local comb_em=rowsof(matem1)*colsof(matem2)
					local newN=`oldN'+`simulations'*(2*`nexplev'+1)+`simulations'*`comb_em'
				}
			}
		}
		else {
			if "`msm'"=="" {
				local newN=`oldN'+`simulations'*(3*`nexplev'+2)
			}
			else {
				if "`boceam'"=="" {
					local newN=`oldN'+`simulations'*(3*`nexplev'+3)
				}
				else {
					qui tab `exposure' `mediator', matrow(matem1) matcol(matem2)
					local comb_em=rowsof(matem1)*colsof(matem2)
					local newN=`oldN'+`simulations'*(3*`nexplev'+2)+`simulations'*`comb_em'
				}
			}
		}
    }
    local nump=`oldN'
	capture qui set obs `newN'
	if _rc!=0 {
		noi di as err "Insufficient memory to create simulation dataset."
		exit 198
	}
	*idvar and tvar
    if "`mediation'"=="" {
    	qui replace `idvar'=ceil(_n/`maxv') if `idvar'==.
    	qui replace `tvar'=_n-`maxv'*ceil(_n/`maxv')+`maxv' if `tvar'==.
    	qui replace `tvar'=matvis[`tvar',1] if _n>`oldN'
    }
	if `_gc_chk_prt'==0 {
		noi di as text "{hline 1}" _cont
	}

	*fixedcovariates / base_confs
	if "`mediation'"!="" {
		if "`control'"=="" {
			if "`msm'"=="" {
				local nint=3
			}
			else {
				if "`boceam'"=="" {
					local nint=4
				}
				else {
					qui tab `exposure' `mediator', matrow(matem1) matcol(matem2)
					local comb_em=rowsof(matem1)*colsof(matem2)
					local nint=3+`comb_em'
				}
			}
        }
        else {
			if "`msm'"=="" {
				local nint=5
			}
			else {
				if "`boceam'"=="" {
					local nint=6
				}
				else {
					qui tab `exposure' `mediator', matrow(matem1) matcol(matem2)
					local comb_em=rowsof(matem1)*colsof(matem2)
					local nint=5+`comb_em'
				}
			}
		}
		local maxv=1
	}
	local nintplus1=`nint'+1
	local nintplus2=`nint'+2
	if "`oce'"!="" {
		if "`boceam'"=="" {
			if "`msm'"=="" {
				local nintplus1=(0.5*(`nint'+1))*(`nexplev'+1)
			}
			else {
				local nintplus1=(0.5*(`nint'))*(`nexplev'+1)+1
			}
		}
		else {
			qui tab `exposure' `mediator', matrow(matem1) matcol(matem2)
			local comb_em=rowsof(matem1)*colsof(matem2)
			local nintplus1=(0.5*(`nint'))*(`nexplev'+1)+`comb_em'
		}
	}	
	forvalues i=1/`nintplus1' {
		foreach var in `fixedcovariates' {
			qui replace `var'=`var'[_n-`oldN'-(`i'-1)*`simulations'*`maxv'] if `var'==. & `int_no'[_n-`oldN'-(`i'-1)*`simulations'*`maxv']==0 
		}
		foreach var in `base_confs' {
			if "`moreMC'"=="" {
				qui replace `var'=`var'[_n-`oldN'-(`i'-1)*`simulations'] if `var'==. & `int_no'[_n-`oldN'-(`i'-1)*`simulations']==0 
			}
			else {
				local RA=ceil(`simulations'/`oldN')
				forvalues ra=1(1)`RA' {
					qui replace `var'=`var'[_n-`ra'*`oldN'-(`i'-1)*`simulations'] if `var'==. & `int_no'[_n-`ra'*`oldN'-(`i'-1)*`simulations']==0 
				}
			}
		}
	}
	
	* subject id
	if "`mediation'"!="" {
		forvalues i=1/`nintplus1' {
			if "`moreMC'"=="" {
				qui replace `subjectid'=`subjectid'[_n-`oldN'-(`i'-1)*`simulations'] if `subjectid'==. & `int_no'[_n-`oldN'-(`i'-1)*`simulations']==0
			}
		}
		if "`moreMC'"!="" {
			qui replace `subjectid'=mod(_n-`oldN',`simulations') if `subjectid'==.
			qui replace `subjectid'=`simulations' if `subjectid'==0
		}
	}
	
	*intervention variables
	local M=`oldN'
    if "`mediation'"=="" {
    	local N=`oldN'+`simulations'*`maxv'
    }
    else {
        local N=`oldN'+`simulations'
    }
    if "`mediation'"=="" {
        forvalues i=1/`nint' {
            qui replace `int_no'=`i' if _n>`M' & _n<=`N'
            forvalues j=1/`nintcomp`i'' {
                capture qui replace `intcomp`i'`j'' if _n>`M' & _n<=`N'
                if _rc!=0 {
					local intcomp`i'`j'=subinword("`intcomp`i'`j''","if","if (",1)+" )"
					capture qui replace `intcomp`i'`j'' & _n>`M' & _n<=`N'
                }
            }
            local M=`N'
            local N=`N'+`simulations'*`maxv'
        }
        qui replace `int_no'=`nint'+1 if _n>`M' & _n<=`N'
        foreach var in `intvars' {
             qui replace `var'=`var'[_n-`oldN'-`nint'*`simulations'*`maxv'] if _n>`M' & _n<=`N'
			 qui replace `var'=. if `tvar'!=`firstv' & _n>`M' & _n<=`N'
         }
    }
    else {
		if "`control'"=="" {
			if "`msm'"=="" {
				local nint=3
			}
			else {
				if "`boceam'"=="" {
					local nint=4
				}
				else {
					qui tab `exposure' `mediator', matrow(matem1) matcol(matem2)
					local comb_em=rowsof(matem1)*colsof(matem2)
					local nint=3+`comb_em'
				}
			}
        }
        else {
			if "`msm'"=="" {
				local nint=5
			}
			else {
				if "`boceam'"=="" {
					local nint=6
				}
				else {
					qui tab `exposure' `mediator', matrow(matem1) matcol(matem2)
					local comb_em=rowsof(matem1)*colsof(matem2)
					local nint=5+`comb_em'
				}
			}
		}
		if "`obe'"=="" & "`oce'"=="" & "`linexp'"=="" & "`specific'"=="" {
			forvalues i=1/`nint' {
				qui replace `int_no'=`i' if _n>`M' & _n<=`N'
				forvalues j=1/`nbase' {
					tokenize "`exposure'"
					qui replace ``j''=`baseline`j'' if _n>`M' & _n<=`N'
					if `i'==1 | `i'==3 | `i'==5 {
						if "`moreMC'"=="" {
							qui replace ``j''=``j''[_n-`oldN'-(`i'-1)*`simulations'] if `int_no'==`i'
						}
						else {
							local RA=ceil(`simulations'/`oldN')
							forvalues ra=1(1)`RA' {
								qui replace ``j''=``j''[_n-`ra'*`oldN'-(`i'-1)*`simulations'] if `int_no'==`i' & `int_no'[_n-`ra'*`oldN'-(`i'-1)*`simulations']==0
							}
						}
					}
					if (`i'==4 & "`control'"=="" & "`boceam'"=="") | (`i'==6 & "`control'"!="" & "`boceam'"=="") {
					****************************************************************************************************************************************************************************************************
						tempvar randomorder
						tempvar originalorder
						gen long `originalorder'=_n
						gen double `randomorder'=runiform()
						sort `int_no' `randomorder'
						if "`moreMC'"=="" {
							qui replace ``j''=``j''[_n-`oldN'-(`i'-1)*`simulations'] if `int_no'==`i'
						}
						else {
							local RA=ceil(`simulations'/`oldN')
							forvalues ra=1(1)`RA' {
								qui replace ``j''=``j''[_n-`ra'*`oldN'-(`i'-1)*`simulations'] if `int_no'==`i' & `int_no'[_n-`ra'*`oldN'-(`i'-1)*`simulations']==0
							}
						}
						sort `originalorder'
					****************************************************************************************************************************************************************************************************
					}
					if "`boceam'"!="" {
					****************************************************************************************************************************************************************************************************
						qui tab `exposure' `mediator', matrow(matem1) matcol(matem2)
						local num_lev_e=rowsof(matem1)
						local num_lev_m=colsof(matem2)
						forvalues lev_e=1(1)`num_lev_e' {
							if "`control'"=="" {
								local i_em=`i'-3
							}
							else {
								local i_em=`i'-5
							}
							if `i_em'/`num_lev_m'<=`lev_e' & (`i_em'/`num_lev_m'>`lev_e'-1) {
								qui replace ``j''=matem1[`lev_e',1] if `int_no'==`i' & `i_em'>=1									
							}
						}
					****************************************************************************************************************************************************************************************************
					}
				}
				local M=`N'
				local N=`N'+`simulations'
			}
		}
		else {
			if "`obe'"!="" {
				forvalues i=1/`nint' {
					qui replace `int_no'=`i' if _n>`M' & _n<=`N'
					local M=`N'
					local N=`N'+`simulations'
				}
				qui replace `exposure'=1 if `int_no'==1 | `int_no'==3 | `int_no'==5
				qui replace `exposure'=0 if `int_no'==2 | `int_no'==4
				********************************************************************************************************************************************************************************************************
				if "`boceam'"=="" {
					qui count if `int_no'<6 & `int_no'>0
					local missout=r(N)
					tempvar randomorder
					tempvar originalorder
					gen long `originalorder'=_n
					gen double `randomorder'=runiform()
					sort `int_no' `randomorder'
					if "`moreMC'"=="" {
						qui replace `exposure'=`exposure'[_n-`oldN'-`missout'] if `int_no'==6
					}
					else {
						local RA=ceil(`simulations'/`oldN')
						forvalues ra=1(1)`RA' {
							qui replace `exposure'=`exposure'[_n-`ra'*`oldN'-`missout'] if `int_no'==6 & `int_no'[_n-`ra'*`oldN'-`missout']==0
						}
					}
					sort `originalorder'
				}
				********************************************************************************************************************************************************************************************************
				if "`control'"=="" {
				********************************************************************************************************************************************************************************************************
					if "`boceam'"=="" {
						qui count if `int_no'<4 & `int_no'>0
						local missout=r(N)
						tempvar randomorder
						tempvar originalorder
						gen long `originalorder'=_n
						gen double `randomorder'=runiform()
						sort `int_no' `randomorder'
						if "`moreMC'"=="" {
							qui replace `exposure'=`exposure'[_n-`oldN'-`missout'] if `int_no'==4
						}
						else {
							local RA=ceil(`simulations'/`oldN')
							forvalues ra=1(1)`RA' {
								qui replace `exposure'=`exposure'[_n-`ra'*`oldN'-`missout'] if `int_no'==4 & `int_no'[_n-`ra'*`oldN'-`missout']==0
							}
						}
						sort `originalorder'
					}
				********************************************************************************************************************************************************************************************************
				}	
				if "`boceam'"!="" {
				********************************************************************************************************************************************************************************************************
					qui tab `exposure' `mediator', matrow(matem1) matcol(matem2)
					local num_lev_e=rowsof(matem1)
					local num_lev_m=colsof(matem2)
					if "`control'"=="" {
						qui replace `exposure'=0 if (`int_no'-3)/`num_lev_m'<=1
						qui replace `exposure'=1 if (`int_no'-3)/`num_lev_m'>1
					}
					else {
						qui replace `exposure'=0 if (`int_no'-5)/`num_lev_m'<=1
						qui replace `exposure'=1 if (`int_no'-5)/`num_lev_m'>1
					}
				********************************************************************************************************************************************************************************************************
				}	
			}
			if "`specific'"!="" {
				forvalues i=1/`nint' {
					qui replace `int_no'=`i' if _n>`M' & _n<=`N'
					local M=`N'
					local N=`N'+`simulations'
				}
				qui replace `exposure'=`alternative1' if `int_no'==1 | `int_no'==3 | `int_no'==5
				qui replace `exposure'=`baseline1' if `int_no'==2 | `int_no'==4
				********************************************************************************************************************************************************************************************************
				if "`boceam'"=="" {
					qui count if `int_no'<6 & `int_no'>0
					local missout=r(N)
					tempvar randomorder
					tempvar originalorder
					gen long `originalorder'=_n
					gen double `randomorder'=runiform()
					sort `int_no' `randomorder'
					if "`moreMC'"=="" {
						qui replace `exposure'=`exposure'[_n-`oldN'-`missout'] if `int_no'==6
					}
					else {
						local RA=ceil(`simulations'/`oldN')
						forvalues ra=1(1)`RA' {
							qui replace `exposure'=`exposure'[_n-`ra'*`oldN'-`missout'] if `int_no'==6 & `int_no'[_n-`ra'*`oldN'-`missout']==0
						}
					}
					sort `originalorder'
				}
				********************************************************************************************************************************************************************************************************
				if "`control'"=="" {
				********************************************************************************************************************************************************************************************************
					if "`boceam'"=="" {
						qui count if `int_no'<4 & `int_no'>0
						local missout=r(N)
						tempvar randomorder
						tempvar originalorder
						gen long `originalorder'=_n
						gen double `randomorder'=runiform()
						sort `int_no' `randomorder'
						if "`moreMC'"=="" {
							qui replace `exposure'=`exposure'[_n-`oldN'-`missout'] if `int_no'==4
						}
						else {
							local RA=ceil(`simulations'/`oldN')
							forvalues ra=1(1)`RA' {
								qui replace `exposure'=`exposure'[_n-`ra'*`oldN'-`missout'] if `int_no'==4 & `int_no'[_n-`ra'*`oldN'-`missout']==0
							}
						}
						sort `originalorder'
					}
				********************************************************************************************************************************************************************************************************
				}	
				if "`boceam'"!="" {
				********************************************************************************************************************************************************************************************************
					qui tab `exposure' `mediator', matrow(matem1) matcol(matem2)
					local num_lev_e=rowsof(matem1)
					local num_lev_m=colsof(matem2)
					if "`control'"=="" {
						qui replace `exposure'=`baseline1' if (`int_no'-3)/`num_lev_m'<=1
						qui replace `exposure'=`alternative1' if (`int_no'-3)/`num_lev_m'>1
					}
					else {
						qui replace `exposure'=`baseline1' if (`int_no'-5)/`num_lev_m'<=1
						qui replace `exposure'=`alternative1' if (`int_no'-5)/`num_lev_m'>1
					}
				********************************************************************************************************************************************************************************************************
				}	
			}
			if "`linexp'"!="" {
				forvalues i=1/`nint' {
					qui replace `int_no'=`i' if _n>`M' & _n<=`N'
					if "`moreMC'"=="" {
						qui replace `exposure'=`exposure'[_n-`oldN'-(`i'-1)*`simulations'] if _n>`M' & _n<=`N'
					}
					else {
						local RA=ceil(`simulations'/`oldN')
						forvalues ra=1(1)`RA' {
							qui replace `exposure'=`exposure'[_n-`ra'*`oldN'-(`i'-1)*`simulations'] if _n>`M' & _n<=`N' & `int_no'[_n-`ra'*`oldN'-(`i'-1)*`simulations']==0
						}
					}
					if `i'==1 | `i'==3 | `i'==5 {
						qui replace `exposure'=`exposure'+1 if `int_no'==`i'
					}
					if (`i'==4 & "`control'"=="") | (`i'==6 & "`control'"!="") {
						tempvar randomorder
						tempvar originalorder
						gen long `originalorder'=_n
						gen double `randomorder'=runiform()
						sort `int_no' `randomorder'
						if "`moreMC'"=="" {
							qui replace `exposure'=`exposure'[_n-`oldN'-(`i'-1)*`simulations'] if `int_no'==`i'
						}
						else {
							local RA=ceil(`simulations'/`oldN')
							forvalues ra=1(1)`RA' {
								qui replace `exposure'=`exposure'[_n-`ra'*`oldN'-(`i'-1)*`simulations'] if `int_no'==`i' & `int_no'[_n-`ra'*`oldN'-(`i'-1)*`simulations']==0
							}
						}
						sort `originalorder'
					}
					local M=`N'
					local N=`N'+`simulations'
				}
			}
			if "`oce'"!="" {
				qui tab `exposure', matrow(_matrow)
				local nexplevels=r(r)-1
				forvalues i=1/`nint' {
					if `i'==1 | `i'==3 | `i'==5 {
						forvalues j=1/`nexplevels' {
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
							qui replace `int_no'=`i' if _n>`M' & _n<=`N'
							qui replace `exposure'=`k' if _n>`M' & _n<=`N'
							local M=`N'
							local N=`N'+`simulations'
						}
					}
					else {
						qui replace `int_no'=`i' if _n>`M' & _n<=`N'
						qui replace `exposure'=`baseline1' if _n>`M' & _n<=`N'
						local M=`N'
						local N=`N'+`simulations'
					}
					if `i'==6 & "`boceam'"=="" {
					********************************************************************************************************************************************************************************************************
						qui count if `int_no'<6 & `int_no'>0
						local missout=r(N)
						tempvar randomorder
						tempvar originalorder
						gen long `originalorder'=_n
						gen double `randomorder'=runiform()
						sort `int_no' `randomorder'
						if "`moreMC'"=="" {
							qui replace `exposure'=`exposure'[_n-`oldN'-`missout'] if `int_no'==6
						}
						else {
							local RA=ceil(`simulations'/`oldN')
							forvalues ra=1(1)`RA' {
								qui replace `exposure'=`exposure'[_n-`ra'*`oldN'-`missout'] if `int_no'==6  & `int_no'[_n-`ra'*`oldN'-`missout']==0
							}
						}
						sort `originalorder'
					********************************************************************************************************************************************************************************************************
					}
					if `i'==4 & "`control'"=="" & "`boceam'"=="" {
					********************************************************************************************************************************************************************************************************
						qui count if `int_no'<4 & `int_no'>0
						local missout=r(N)
						tempvar randomorder
						tempvar originalorder
						gen long `originalorder'=_n
						gen double `randomorder'=runiform()
						sort `int_no' `randomorder'
						if "`moreMC'"=="" {
							qui replace `exposure'=`exposure'[_n-`oldN'-`missout'] if `int_no'==4
						}
						else {
							local RA=ceil(`simulations'/`oldN')
							forvalues ra=1(1)`RA' {
								qui replace `exposure'=`exposure'[_n-`ra'*`oldN'-`missout'] if `int_no'==4 & `int_no'[_n-`ra'*`oldN'-`missout']==0
							}
						}
						sort `originalorder'
					********************************************************************************************************************************************************************************************************
					}
					if "`boceam'"!="" {
					********************************************************************************************************************************************************************************************************
						qui tab `exposure' `mediator', matrow(matem1) matcol(matem2)
						local num_lev_e=rowsof(matem1)
						local num_lev_m=colsof(matem2)
						if "`control'"=="" {
							forvalues lev_e=1(1)`num_lev_e' {
								qui replace `exposure'=matem1[`lev_e',1] if (`int_no'-3)/`num_lev_m'<=`lev_e' & (`int_no'-3)/`num_lev_m'>`lev_e'-1
							}
						}
						else {
							forvalues lev_e=1(1)`num_lev_e' {
								qui replace `exposure'=matem1[`lev_e',1] if (`int_no'-5)/`num_lev_m'<=`lev_e' & (`int_no'-5)/`num_lev_m'>`lev_e'-1
							}

						}
					********************************************************************************************************************************************************************************************************
					}
				}
			}
		}
        forvalues j=1/`nmed' {
            tokenize "`mediator'"
			if "`control'"!="" {
				capture qui replace ``j''=`control`j'' if `int_no'==3 | `int_no'==4
			}
			if "`oce'"=="" {
				local nexplevels=1
			}
			if "`control'"!="" & "`msm'"!="" & "`boceam'"==""{
				********************************************************************************************************************************************************************************************************
				tempvar randomorder
				tempvar originalorder
				gen long `originalorder'=_n
				gen double `randomorder'=runiform()
				sort `int_no' `randomorder'
				if "`moreMC'"=="" {
					capture qui replace ``j''=``j''[_n-`oldN'-(3*`nexplevels'+2)*`simulations'] if `int_no'==6
				}
				else {
					local RA=ceil(`simulations'/`oldN')
					forvalues ra=1(1)`RA' {
						capture qui replace ``j''=``j''[_n-`ra'*`oldN'-(3*`nexplevels'+2)*`simulations'] if `int_no'==6 & `int_no'[_n-`ra'*`oldN'-(3*`nexplevels'+2)*`simulations']==0
					}
				}
				sort `originalorder'
				********************************************************************************************************************************************************************************************************
			}
			if "`control'"=="" & "`msm'"!="" & "`boceam'"=="" {
				********************************************************************************************************************************************************************************************************
				tempvar randomorder
				tempvar originalorder
				gen long `originalorder'=_n
				gen double `randomorder'=runiform()
				sort `int_no' `randomorder'
				if "`moreMC'"=="" {
					capture qui replace ``j''=``j''[_n-`oldN'-(2*`nexplevels'+1)*`simulations'] if `int_no'==4
				}
				else {
					local RA=ceil(`simulations'/`oldN')
					forvalues ra=1(1)`RA' {
						capture qui replace ``j''=``j''[_n-`ra'*`oldN'-(2*`nexplevels'+1)*`simulations'] if `int_no'==4 & `int_no'[_n-`ra'*`oldN'-(2*`nexplevels'+1)*`simulations']==0
					}
				}
				sort `originalorder'
				********************************************************************************************************************************************************************************************************
			}
			if "`msm'"!="" & "`boceam'"!=""{
				********************************************************************************************************************************************************************************************************
				qui tab `exposure' `mediator', matrow(matem1) matcol(matem2)
				local num_lev_e=rowsof(matem1)
				local num_lev_m=colsof(matem2)
				if "`control'"=="" {
					forvalues lev_m=1(1)`num_lev_m' {
						qui replace ``j''=matem2[1,`lev_m'] if mod(`int_no'-3,`num_lev_m')==mod(`lev_m',`num_lev_m') & `int_no'>=4
					}
				}
				else {
					forvalues lev_m=1(1)`num_lev_m' {
						qui replace ``j''=matem2[1,`lev_m'] if mod(`int_no'-5,`num_lev_m')==mod(`lev_m',`num_lev_m') & `int_no'>=6
					}
				}
				********************************************************************************************************************************************************************************************************
			}
        }
		tempvar msm_switch_on
		gen `msm_switch_on'=0
		if "`control'"=="" {
			qui replace `msm_switch_on'=1 if `int_no'>=4
		}
		else {
			qui replace `msm_switch_on'=1 if `int_no'>=6
		}
		if "`msm'"!="" & "`boceam'"!="" & "`control'"!="" & ("`oce'"!="" | "`obe'"!="") {
			qui replace `msm_switch_on'=1 if `int_no'==3 | `int_no'==4
			qui count if `int_no'<3
			local int_start_a1=r(N)
			qui count if `int_no'<6
			local int_start_b1=r(N)
			qui count if `int_no'==3 | `int_no'==4
			local max_a=round(r(N)/`simulations',1)
			qui count if `int_no'>=6
			local max_b=round(r(N)/`simulations',1)
			forvalues start_a=1(1)`max_a' {
				forvalues start_b=1(1)`max_b' {
					local check_int_msm=1
					forvalues int_j=1(1)`simulations' {
						local int_k_a`start_a'=`int_start_a`start_a''+`int_j'
						local int_k_b`start_b'=`int_start_b`start_b''+`int_j'
						if `exposure'[`int_k_a`start_a'']!=`exposure'[`int_k_b`start_b''] | `mediator'[`int_k_a`start_a'']!=`mediator'[`int_k_b`start_b''] {
							local check_int_msm=0
						}
					}
					if `check_int_msm'==1 {
						forvalues int_j=1(1)`simulations' {
							local int_k_b`start_b'=`int_start_b`start_b''+`int_j'
							qui replace `msm_switch_on'=0 in `int_k_b`start_b'' 	
						}					
					}
					local start_b_next=`start_b'+1
					local int_start_b`start_b_next'=`int_k_b`start_b''
				}
				local start_a_next=`start_a'+1
				local int_start_a`start_a_next'=`int_k_a`start_a''
			}
		}
    }
	if `_gc_chk_prt'==0 {
		noi di as text "{hline 1}" _cont
	}
	   if "`mediation'"=="" {
	   *lagged variables
    		 * _gcomp_detangle lag rules
    		local nlag: word count `laggedvars'
    		if `nlag' > 0 {
    		_gcomp_detangle "`lagrules'" lagrule "`laggedvars'"
    		forvalues i=1/`nlag' {
    			local lagvar`i': word `i' of `laggedvars'
    			if "${S_`i'}"!="" {
    				local lagrule`i' ${S_`i'}
    			}
    		}
    		forvalues i=1/`nlag' {
    			tokenize "`lagrule`i''", parse(" ")
    			local lagrulevar`i' "`1'"
    			local lag`i' "`2'"
    		}
    		sort `idvar' `tvar'
    		forvalues i=1/`nlag' {
    			qui by `idvar': replace `lagvar`i''=`lagrulevar`i''[_n-`lag`i''] if `lagvar`i''==.
    		}
    		forvalues i=1/`nlag' {
    			forvalues j=1/`nvar' {
    				qui replace `lagvar`i''=0 if `lagvar`i''==. & `simvar`j''!=.
    			}
    		}
    		}
        }
		if `_gc_chk_prt'==0 {
			noi di as text "{hline 1}" _cont
		}
		   
	*derived variables
		* _gcomp_detangle derivation rules
		local nder: word count `derived'	
		if `nder'>0 {
			_gcomp_detangle "`derrules'" derrule "`derived'"
			forvalues i=1/`nder' {
				local der`i': word `i' of `derived'
				if "${S_`i'}"!="" {
					local derrule`i' ${S_`i'}
				}
			}
		}
		if `_gc_chk_prt'==0 {
			noi di as text "{hline 1}" _cont
		}
		forvalues i=1/`nder' {
			capture qui replace `der`i''=`derrule`i'' if `der`i''==.
			if _rc!=0 {
				local derrule`i'=subinword("`derrule`i''","if","if (",1)+" )"
				capture qui replace `der`i''=`derrule`i'' & `der`i''==.
			}
		}
		if `_gc_chk_prt'==0 {
			noi di as text "{hline 1}" _cont
		}
* determine at which visit each variable in varlist2 is to be simulated
if "`mediation'"=="" {
    forvalues i=1/`nvar' {
        forvalues j=1/`maxv' {
            local k=matvis[`j',1]           
            qui count if `simvar`i''!=. & `tvar'==`k'
            if r(N)!=0 {
                local visitcalc`i'_`j'=1
            }
            else {
                local visitcalc`i'_`j'=0
            }
        }
    }
}
if `_gc_chk_prt'==0 {
    if "`mediation'"!="" {
        local maxv=1
    }
	local k1=max(floor((`maxv'*`nvar'-9)/2),1)
	local k2=max(ceil((`maxv'*`nvar'-9)/2),1)
	noi di as text "{c RT}"
	noi di
	noi di as text "                                              {c LT}" _cont
	noi di as text "{hline `k1'}" _cont
	noi di as text "PROGRESS" _cont
	noi di as text "{hline `k2'}" _cont
	noi di as text "{c RT}"
	noi di as text "   Fitting parametric models and simulating:  {c LT}" _cont
}
* generate Monte Carlo population
if "`mediation'"=="" {
   	* fit parametric models and simulate according to parameter estimates
	forvalues j=1/`maxv' {
		forvalues i=1/`nvar' {
			if `_gc_chk_prt'==0 {
				if `j'==`maxv' & `i'==`nvar' & `maxv'*`nvar'>=11 {
					noi di "{c RT}" _cont
				}	
				else {
					noi di "{hline 1}" _cont
				}
			}
			local k=matvis[`j',1]
			if `visitcalc`i'_`j''==1 {
				forvalues l=1/`nlag' {
					qui replace `lagvar`l''=0 if `lagvar`l''==. & `tvar'==`k' & `int_no'>0
				}
				forvalues l=1/`nder' {
					capture qui replace `der`l''=`derrule`l'' if `der`l''==. & `int_no'>0
					if _rc!=0 {
						local derrule`l'=subinword("`derrule`l''","if","if (",1)+" )"
						capture qui replace `der`l''=`derrule`l'' & `der`l''==. & `int_no'>0
					}
				}
				if `j'==1 & strmatch(" "+"`varyingcovariates'"+" ","* "+"`simvar`i''"+" *")==1 {
					qui replace `simvar`i''=`simvar`i''[_n-`oldN'-(`int_no'-1)*`simulations'*`maxv'] if `simvar`i''==. & `tvar'==`k' & `int_no'>0
				}
				else {
					if "`eofu'"!="" {
						if "`pooled'"=="" {
							if "`monotreat'"=="" | `i'<=`nvar_untilmono' {
								qui `command`i'' `simvar`i'' `equation`i'' if `tvar'==`k' & `int_no'==0
							}
							else {
								if `j'==1 {
									qui `command`i'' `simvar`i'' `equation`i'' if `tvar'==`k' & `int_no'==0
								}
								else {
									qui `command`i'' `simvar`i'' `equation`i'' if `tvar'==`k' & `int_no'==0 & `simvar`i''[_n-1]==0
								}
							}
						}
						else {
							if "`monotreat'"=="" | `i'<=`nvar_untilmono' {
								qui `command`i'' `simvar`i'' `equation`i'' if `int_no'==0
							}
							else {
								tempvar checkmono
								gen `checkmono'=(`int_no'==0)
								qui replace `checkmono'=0 if `idvar'[_n]==`idvar'[_n-1] & `simvar`i''[_n-1]==1
								qui `command`i'' `simvar`i'' `equation`i'' if `checkmono'==0
								drop `checkmono'
							}
						}
*****************************************************************************************************************************************************************************
						if "`command`i''"=="logit" | "`command`i''"=="regress" {
							tempvar pred_simvar`i'
							qui predict `pred_simvar`i''
						}
						else {
							if "`command`i''"=="mlogit" {
								local maxcat=e(k_out)
							}
							if "`command`i''"=="ologit" {
								local maxcat=e(k_cat)
							}
							cap drop _gc_p*
							qui predict _gc_p1-_gc_p`maxcat'
						}
*****************************************************************************************************************************************************************************
						if "`command`i''"=="logit" {
							if rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`outcome'")) & "`minsim'"!="" {
								if "`death'"!="" {
									qui replace `simvar`i''=`pred_simvar`i'' if `simvar`i''==. ///
										& `tvar'==`k' & `death'!=1 & `int_no'>0
								}
								else {
									qui replace `simvar`i''=`pred_simvar`i'' if `simvar`i''==. & `tvar'==`k' & `int_no'>0
								}
							}	
							if rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`outcome'")) & "`minsim'"=="" {
								if "`death'"!="" {
									qui replace `simvar`i''=runiform()<`pred_simvar`i'' if `simvar`i''==. ///
										& `tvar'==`k' & `death'!=1 & `int_no'>0
								}
								else {
									qui replace `simvar`i''=runiform()<`pred_simvar`i'' if `simvar`i''==. & `tvar'==`k' & `int_no'>0
								}
							}	
							if rtrim(ltrim("`simvar`i''"))!=rtrim(ltrim("`outcome'")) {
								qui replace `simvar`i''=runiform()<`pred_simvar`i'' if `simvar`i''==. & `tvar'==`k' & `int_no'>0
								if "`monotreat'"!="" & `i'>`nvar_untilmono' {
									qui replace `simvar`i''=1 if `simvar`i''[_n-1]==1 & `idvar'[_n]==`idvar'[_n-1] & `int_no'==`nint'+1
								}
							}
							if rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`death'")) {
								local tc=1
								while `tc'>0 {
									tempvar temp_count
									qui by `idvar': gen `temp_count'=`simvar`i''[_n-1]==1
									qui summ `temp_count'
									local tc=r(mean)*r(N)
									qui by `idvar': drop if `simvar`i''[_n-1]==1
									drop `temp_count'
								}
							}
						}
*****************************************************************************************************************************************************************************
						if ("`command`i''"=="mlogit" | "`command`i''"=="ologit") {
							tempvar umlogitimp
							qui gen double `umlogitimp'=runiform()
							tempvar cum_p1 cum_p2
							qui gen double `cum_p1'=0
							qui gen double `cum_p2'=0
							forvalues cat=1(1)`maxcat' {
								if "`command`i''"=="mlogit" {
									mat catvals=e(out)
								}
								if "`command`i''"=="ologit" {
									mat catvals=e(cat)
								}
								local catval=catvals[1,`cat']
								qui replace `cum_p2'=`cum_p2'+_gc_p`cat'
								if "`death'"!="" & rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`outcome'")) {
									qui replace `simvar`i''=`catval' if `umlogitimp'>`cum_p1' & `umlogitimp'<`cum_p2' & `simvar`i''==. ///
										& `tvar'==`k' & `death'!=1 & `int_no'>0
								}
								else {
									qui replace `simvar`i''=`catval' if `umlogitimp'>`cum_p1' & `umlogitimp'<`cum_p2' & `simvar`i''==. ///
										& `tvar'==`k' & `int_no'>0
								}
								qui replace `cum_p1'=`cum_p2'
							}
						}
*****************************************************************************************************************************************************************************
						if "`command`i''"=="regress" {
							if rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`outcome'")) & "`minsim'"!="" {
								if "`death'"!="" {
									qui replace `simvar`i''=`pred_simvar`i'' if `simvar`i''==. & `tvar'==`k' & `death'!=1 & `int_no'>0
								}
								else {
									qui replace `simvar`i''=`pred_simvar`i'' if `simvar`i''==. & `tvar'==`k' & `int_no'>0								
								}
							}	
							if rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`outcome'")) & "`minsim'"=="" {
								if "`death'"!="" {
									qui replace `simvar`i''=`pred_simvar`i''+e(rmse)*rnormal(0,1) if `simvar`i''==. & `tvar'==`k' & `death'!=1 & `int_no'>0
								}
								else {
									qui replace `simvar`i''=`pred_simvar`i''+e(rmse)*rnormal(0,1) if `simvar`i''==. & `tvar'==`k' & `int_no'>0								
								}
							}	
							if rtrim(ltrim("`simvar`i''"))!=rtrim(ltrim("`outcome'")) {
								qui replace `simvar`i''=`pred_simvar`i''+e(rmse)*rnormal(0,1) if `simvar`i''==. & `tvar'==`k' & `int_no'>0
							}
						}
						if "`command`i''"!="regress" & "`command`i''"!="logit" & "`command`i''"!="mlogit" & "`command`i''"!="ologit" {
							noi di as err "Error: only regress, logit, mlogit and ologit are supported as simulation commands in gcomp."
							exit 198
						}
					}
					else {
						if rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`outcome'")) | ///
							rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`death'")) {
							if "`pooled'"=="" {
								qui `command`i'' `simvar`i'' `equation`i'' if `tvar'==`k'  & `int_no'==0
							}
							else {
								qui `command`i'' `simvar`i'' `equation`i''  if `int_no'==0
							}
*****************************************************************************************************************************************************************************
							if "`command`i''"=="logit" | "`command`i''"=="regress" {
								tempvar pred_simvar`i'
								qui predict `pred_simvar`i''
							}
							else {
								if "`command`i''"=="mlogit" {
									local maxcat=e(k_out)
								}
								if "`command`i''"=="ologit" {
									local maxcat=e(k_cat)
								}
								cap drop _gc_p*
								qui predict _gc_p1-_gc_p`maxcat'
							}
*****************************************************************************************************************************************************************************
							if "`command`i''"=="logit" {
								if "`death'"!="" & rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`outcome'")) {
									qui replace `simvar`i''=runiform()<`pred_simvar`i'' if `simvar`i''==. ///
										& `tvar'==`k' & `death'!=1 & `int_no'>0
								}
								else {
									qui replace `simvar`i''=runiform()<`pred_simvar`i'' if `simvar`i''==. & `tvar'==`k' & `int_no'>0
								}
								local tc=1
								while `tc'>0 {
									tempvar temp_count
									qui by `idvar': gen `temp_count'=`simvar`i''[_n-1]==1
									qui summ `temp_count'
									local tc=r(mean)*r(N)
									qui by `idvar': drop if `simvar`i''[_n-1]==1
									drop `temp_count'
								}
							}
*****************************************************************************************************************************************************************************
							if "`command`i''"=="mlogit" | "`command`i''"=="ologit" {
								tempvar umlogitimp
								qui gen double `umlogitimp'=runiform()
								tempvar cum_p1 cum_p2
								qui gen double `cum_p1'=0
								qui gen double `cum_p2'=0
								forvalues cat=1(1)`maxcat' {
									if "`command`i''"=="mlogit" {
										mat catvals=e(out)
									}
									if "`command`i''"=="ologit" {
										mat catvals=e(cat)
									}
									local catval=catvals[1,`cat']
									qui replace `cum_p2'=`cum_p2'+_gc_p`cat'
									if "`death'"!="" & rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`outcome'")) {
										qui replace `simvar`i''=`catval' if `umlogitimp'>`cum_p1' & `umlogitimp'<`cum_p2' & `simvar`i''==. ///
											& `tvar'==`k' & `death'!=1 & `int_no'>0
									}
									else {
										qui replace `simvar`i''=`catval' if `umlogitimp'>`cum_p1' & `umlogitimp'<`cum_p2' & `simvar`i''==. ///
											& `tvar'==`k' & `int_no'>0
									}
									qui replace `cum_p1'=`cum_p2'
								}
							}
*****************************************************************************************************************************************************************************
							if "`command`i''"=="regress" {
								if "`death'"!="" & rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`outcome'")) {
									qui replace `simvar`i''=`pred_simvar`i''+e(rmse)*rnormal(0,1) if `simvar`i''==. & `tvar'==`k' ///
										& `death'!=1 & `int_no'>0
								}
								else {
									qui replace `simvar`i''=`pred_simvar`i''+e(rmse)*rnormal(0,1) if `simvar`i''==. & `tvar'==`k' & `int_no'>0
								}
							}
							if "`command`i''"!="regress" & "`command`i''"!="logit" & "`command`i''"!="mlogit" & "`command`i''"!="ologit" {
								noi di as err "Error: only regress, logit, mlogit and ologit are supported as simulation commands in gcomp."
								exit 198
							}
						}
						else {
							if "`pooled'"=="" {
								if "`monotreat'"=="" | `i'<=`nvar_untilmono' {
									qui `command`i'' `simvar`i'' `equation`i'' if `tvar'==`k' & `int_no'==0
								}
								else {
									if `j'==1 {
										qui `command`i'' `simvar`i'' `equation`i'' if `tvar'==`k' & `int_no'==0
									}
									else {
										qui `command`i'' `simvar`i'' `equation`i'' if `tvar'==`k' & `int_no'==0 & `simvar`i''[_n-1]==0
									}
								}
							}
							else {
								if "`monotreat'"=="" | `i'<=`nvar_untilmono' {
									qui `command`i'' `simvar`i'' `equation`i'' if `int_no'==0
								}
								else {
									tempvar checkmono
									gen `checkmono'=(`int_no'==0)
									qui replace `checkmono'=0 if `idvar'[_n]==`idvar'[_n-1] & `simvar`i''[_n-1]==1
									qui `command`i'' `simvar`i'' `equation`i'' if `checkmono'==0
									drop `checkmono'
								}
							}
*****************************************************************************************************************************************************************************
							if "`command`i''"=="logit" | "`command`i''"=="regress" {
								tempvar pred_simvar`i'
								qui predict `pred_simvar`i''
							}
							else {
								if "`command`i''"=="mlogit" {
									local maxcat=e(k_out)
								}
								if "`command`i''"=="ologit" {
									local maxcat=e(k_cat)
								}
								cap drop _gc_p*
								qui predict _gc_p1-_gc_p`maxcat'
							}
*****************************************************************************************************************************************************************************
							if "`command`i''"=="logit" {
								qui replace `simvar`i''=runiform()<`pred_simvar`i'' if `simvar`i''==. & `tvar'==`k' & `int_no'>0
							}
*****************************************************************************************************************************************************************************
							if "`command`i''"=="mlogit" | "`command`i''"=="ologit" {
								tempvar umlogitimp
								qui gen double `umlogitimp'=runiform()
								tempvar cum_p1 cum_p2
								qui gen double `cum_p1'=0
								qui gen double `cum_p2'=0
								forvalues cat=1(1)`maxcat' {
									if "`command`i''"=="mlogit" {
										mat catvals=e(out)
									}
									if "`command`i''"=="ologit" {
										mat catvals=e(cat)
									}
									local catval=catvals[1,`cat']
									qui replace `cum_p2'=`cum_p2'+_gc_p`cat'
									qui replace `simvar`i''=`catval' if `umlogitimp'>`cum_p1' & `umlogitimp'<`cum_p2' & `simvar`i''==. ///
											& `tvar'==`k' & `int_no'>0
									qui replace `cum_p1'=`cum_p2'
								}
							}
*****************************************************************************************************************************************************************************
							if "`command`i''"=="regress" {
								qui replace `simvar`i''=`pred_simvar`i''+e(rmse)*rnormal(0,1) if `simvar`i''==. & `tvar'==`k' & `int_no'>0
							}	
							if "`command`i''"!="regress" & "`command`i''"!="logit" & "`command`i''"!="mlogit" & "`command`i''"!="ologit" {
								noi di as err "Error: only regress, logit, mlogit and ologit are supported as simulation commands in gcomp."
								exit 198
							}
						}
					}
				}
			}
			*update derived variables
			forvalues ii=1/`nder' {
				capture qui replace `der`ii''=`derrule`ii'' if `der`ii''==. & `int_no'>0
				if _rc!=0 {
					local derrule`ii'=subinword("`derrule`ii''","if","if (",1)+" )"
					capture qui replace `der`ii''=`derrule`ii'' & `der`ii''==. & `int_no'>0
				}
			}
			*update lagged variables
			sort `idvar' `tvar'
			forvalues ii=1/`nlag' {
				qui by `idvar': replace `lagvar`ii''=`lagrulevar`ii''[_n-`lag`ii''] if `lagvar`ii''==.
				qui replace `lagvar`ii''=0 if `tvar'==`firstv' & `int_no'>0
				if `lag`ii''>1 {
					forvalues next=2/`lag`ii'' {
						local nextv=matvis[`next',1]
						qui replace `lagvar`ii''=0 if `tvar'==`nextv' & `int_no'>0
					}
				}
			}
			*update intervention variables (needed if interventions are dynamic)
			forvalues ii=1/`nint' {
				forvalues jj=1/`nintcomp`ii'' {
					capture qui replace `intcomp`ii'`jj'' if `int_no'==`ii'
					if _rc!=0 {
						local intcomp`ii'`jj'=subinword("`intcomp`ii'`jj''","if","if (",1)+" )"
						capture qui replace `intcomp`ii'`jj'' & `int_no'==`ii'
					}
				}
			}
			*update lagged variables (in case they depend on intervention variables)
			sort `idvar' `tvar'
			forvalues ii=1/`nlag' {
				qui by `idvar': replace `lagvar`ii''=`lagrulevar`ii''[_n-`lag`ii''] if `int_no'>0
				qui replace `lagvar`ii''=0 if `tvar'==`firstv' & `int_no'>0
				if `lag`ii''>1 {
					forvalues next=2/`lag`ii'' {
						local nextv=matvis[`next',1]
						qui replace `lagvar`ii''=0 if `tvar'==`nextv' & `int_no'>0
					}
				}
			}
			*update derived variables again (in case they depend on intervention variables)
			forvalues ii=1/`nder' {
				capture qui replace `der`ii''=`derrule`ii'' if `int_no'>0
			}
		}  
	}
}
else {
   	* fit parametric models and simulate according to parameter estimates
   	forvalues i=1/`nvar' {
   		if `_gc_chk_prt'==0 {
  			if `i'==`nvar' & `nvar'>=11 {
  				noi di "{c RT}" _cont
  			}
   			else {
   				noi di "{hline 1}" _cont
   			}
   		}
		forvalues l=1/`nder' {
   			capture qui replace `der`l''=`derrule`l'' if `der`l''==.
			if _rc!=0 {
				local derrule`l'=subinword("`derrule`l''","if","if (",1)+" )"
				capture qui replace `der`l''=`derrule`l'' & `der`l''==.
			}
		}
		qui `command`i'' `simvar`i'' `equation`i'' if  `int_no'==0
		
*****************************************************************************************************************************************************************************
		if "`command`i''"=="logit" | "`command`i''"=="regress" {
			tempvar pred_simvar`i'
			qui predict `pred_simvar`i''
		}
		else {
			if "`command`i''"=="mlogit" {
				local maxcat=e(k_out)
			}
			if "`command`i''"=="ologit" {
				local maxcat=e(k_cat)
			}
			cap drop _gc_p*
			qui predict _gc_p1-_gc_p`maxcat'
		}
*****************************************************************************************************************************************************************************
		if "`command`i''"=="logit" {
			if rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`outcome'")) & "`minsim'"!="" {
				if "`moreMC'"=="" {
					qui replace `simvar`i''=`simvar`i''[_n-`oldN'-`simulations'] if `simvar`i''==. & `int_no'==2 & "`linexp'"!=""
					qui replace `simvar`i''=`pred_simvar`i'' if `simvar`i''==.
				}
				else {
					local RA=ceil(`simulations'/`oldN')
					forvalues ra=1(1)`RA' {
						qui replace `simvar`i''=`simvar`i''[_n-`ra'*`oldN'-`simulations'] if `simvar`i''==. & `int_no'==2 & "`linexp'"!="" & `int_no'[_n-`ra'*`oldN'-`simulations']==0
						qui replace `simvar`i''=`pred_simvar`i'' if `simvar`i''==.
					}
				}
			}
			else {
				qui replace `simvar`i''=runiform()<`pred_simvar`i'' if `simvar`i''==.				
			}
		}
*****************************************************************************************************************************************************************************
		if "`command`i''"=="mlogit" | "`command`i''"=="ologit" {
			tempvar umlogitimp
			qui gen double `umlogitimp'=runiform()
			tempvar cum_p1 cum_p2
			qui gen double `cum_p1'=0
			qui gen double `cum_p2'=0
			forvalues cat=1(1)`maxcat' {
				if "`command`i''"=="mlogit" {
					mat catvals=e(out)
				}
				if "`command`i''"=="ologit" {
					mat catvals=e(cat)
				}				
				local catval=catvals[1,`cat']
				qui replace `cum_p2'=`cum_p2'+_gc_p`cat'
				qui replace `simvar`i''=`catval' if `umlogitimp'>`cum_p1' & `umlogitimp'<`cum_p2' & `simvar`i''==.
				if "`moreMC'"=="" {
					qui replace `simvar`i''=`simvar`i''[_n-`oldN'-`simulations'] if `int_no'==2 & "`linexp'"!="" & rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`outcome'"))
				}
				else {
					local RA=ceil(`simulations'/`oldN')
					forvalues ra=1(1)`RA' {
						qui replace `simvar`i''=`simvar`i''[_n-`ra'*`oldN'-`simulations'] if `int_no'==2 & "`linexp'"!="" & rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`outcome'")) & `int_no'[_n-`ra'*`oldN'-`simulations']==0
					}
				}
				qui replace `cum_p1'=`cum_p2'
			}
		}
*****************************************************************************************************************************************************************************
		if "`command`i''"=="regress" {
			if rtrim(ltrim("`simvar`i''"))==rtrim(ltrim("`outcome'")) & "`minsim'"!="" {
				if "`moreMC'"=="" {
					qui replace `simvar`i''=`simvar`i''[_n-`oldN'-`simulations'] if `simvar`i''==. & `int_no'==2 & "`linexp'"!=""
				}
				else {
					local RA=ceil(`simulations'/`oldN')
					forvalues ra=1(1)`RA' {
						qui replace `simvar`i''=`simvar`i''[_n-`ra'*`oldN'-`simulations'] if `simvar`i''==. & `int_no'==2 & "`linexp'"!="" & `int_no'[_n-`ra'*`oldN'-`simulations']==0
					}
				}
				qui replace `simvar`i''=`pred_simvar`i'' if `simvar`i''==.
			}
			else {
				tempvar helpU
				qui gen double `helpU'=rnormal(0,1) if _n<=`simulations'
				qui replace `simvar`i''=`pred_simvar`i''+e(rmse)*`helpU'[`subjectid'] if `simvar`i''==.
			}
		}
		if "`command`i''"!="regress" & "`command`i''"!="logit" & "`command`i''"!="mlogit" & "`command`i''"!="ologit" {
			noi di as err "Error: only regress, logit, mlogit and ologit are supported as simulation commands in gcomp."
			exit 198
		}
        forvalues k=1/`nmed' {
            tokenize "`mediator'"
            if "`simvar`i''"=="``k''" {
				if "`command`i''"=="logit" {
					qui replace `simvar`i''=runiform()<`pred_simvar`i''[_n+`simulations'] if `int_no'==1
					if "`moreMC'"=="" {
						qui replace `simvar`i''=`simvar`i''[_n-`oldN'] if `int_no'==1 & "`linexp'"!="" & "`minsim'"!=""
					}
					else {
						local RA=ceil(`simulations'/`oldN')
						forvalues ra=1(1)`RA' {
							qui replace `simvar`i''=`simvar`i''[_n-`ra'*`oldN'] if `int_no'==1 & "`linexp'"!="" & "`minsim'"!="" & `int_no'[_n-`ra'*`oldN']==0
						}	
					}
				}
*****************************************************************************************************************************************************************************
				if "`command`i''"=="mlogit" | "`command`i''"=="ologit" {
					tempvar umlogitimp
					qui gen double `umlogitimp'=runiform()
					tempvar cum_p1 cum_p2
					qui gen double `cum_p1'=0
					qui gen double `cum_p2'=0
					forvalues cat=1(1)`maxcat' {
						if "`command`i''"=="mlogit" {
							mat catvals=e(out)
						}
						if "`command`i''"=="ologit" {
							mat catvals=e(cat)
						}
						local catval=catvals[1,`cat']
						qui replace `cum_p2'=`cum_p2'+_gc_p`cat'
						qui replace `simvar`i''=`catval' if `umlogitimp'>`cum_p1'[_n+`simulations'] & `umlogitimp'<`cum_p2'[_n+`simulations'] & `int_no'==1
						if "`moreMC'"=="" {
							qui replace `simvar`i''=`simvar`i''[_n-`oldN'] if `int_no'==1 & "`linexp'"!="" & "`minsim'"!=""
						}
						else {
							local RA=ceil(`simulations'/`oldN')
							forvalues ra=1(1)`RA' {
								qui replace `simvar`i''=`simvar`i''[_n-`ra'*`oldN'] if `int_no'==1 & "`linexp'"!="" & "`minsim'"!="" & `int_no'[_n-`ra'*`oldN']==0
							}	
						}
						qui replace `cum_p1'=`cum_p2'
					}
				}
*****************************************************************************************************************************************************************************
				if "`command`i''"=="regress" {
					tempvar helpU2
					qui gen double `helpU2'=rnormal(0,1) if _n<=`simulations'
					qui replace `simvar`i''=`pred_simvar`i''[_n+`simulations']+e(rmse)*`helpU2'[`subjectid'] if `int_no'==1
					if "`moreMC'"=="" {
						qui replace `simvar`i''=`simvar`i''[_n-`oldN'] if `int_no'==1 & "`linexp'"!="" & "`minsim'"!=""
					}
					else {
						local RA=ceil(`simulations'/`oldN')
						forvalues ra=1(1)`RA' {
							qui replace `simvar`i''=`simvar`i''[_n-`ra'*`oldN'] if `int_no'==1 & "`linexp'"!="" & "`minsim'"!="" & `int_no'[_n-`ra'*`oldN']==0
						}	
					}
				}
				if "`command`i''"!="regress" & "`command`i''"!="logit" & "`command`i''"!="mlogit" & "`command`i''"!="ologit" {
					noi di as err "Error: only regress, logit, mlogit and ologit are supported as simulation commands in gcomp."
					exit 198
				}
            }
        }
	}  
   	*update derived variables
   	forvalues i=1/`nder' {
   		capture qui replace `der`i''=`derrule`i'' if `der`i''==.
   		if _rc!=0 {
			local derrule`i'=subinword("`derrule`i''","if","if (",1)+" )"
			capture qui replace `der`i''=`derrule`i'' & `der`i''==.
   		}
   	}
}
if `_gc_chk_prt'==0 {
    if "`mediation'"!="" {
        local maxv=1
    }
	if `maxv'*`nvar'<11 {
		local k3=10-`maxv'*`nvar'
		noi di _dup(`k3') "{hline 1}" _cont
		noi di "{c RT}" _cont
	}
    if "`mediation'"=="" {
		noi di
		noi di as text "                                              {c LT}" _cont
		noi di as text "{hline `k1'}" _cont
		noi di as text "PROGRESS" _cont
		noi di as text "{hline `k2'}" _cont
		noi di as text "{c RT}"
    	if "`eofu'"!="" {
    		noi di as text "   Estimating mean potential outcomes:        {c LT}" _cont
    	}
    	else {
	   		noi di as text "   Estimating average log incidence rates:    {c LT}" _cont
    	}
    }
}
if "`mediation'"=="" {
    if "`eofu'"!="" {
    	qui regress `outcome' i.`int_no'
		tempname EPO noomit
	    mat `EPO'=e(b)
		_ms_omit_info `EPO'
		local cols = colsof(`EPO')
		matrix `noomit' =  J(1,`cols',1) - r(omit)
		mata: EPO = select(st_matrix(st_local("EPO")),(st_matrix(st_local("noomit"))))
		mata: st_matrix(st_local("EPO"),EPO)
		mat EPO=`EPO'
    	if `_gc_chk_prt'==0 {
    		noi di as text "{hline 10}{c RT}"
    	}
    }
    else {
    	qui stset `tvar', id(`idvar') failure(`outcome')
    	qui streg i.`int_no', nohr dist(e)
		tempname EPO noomit
	    mat `EPO'=e(b)
		_ms_omit_info `EPO'
		local cols = colsof(`EPO')
		matrix `noomit' =  J(1,`cols',1) - r(omit)
		mata: EPO = select(st_matrix(st_local("EPO")),(st_matrix(st_local("noomit"))))
		mata: st_matrix(st_local("EPO"),EPO)
		mat EPO=`EPO'
    	if `_gc_chk_prt'==0 {
    		if "`graph'"!="" {
    			local leglab " legend(lab(1 Observational data) "			
    			forvalues i=1/`nint' {
    				local j=`i'+1
    				local leglab="`leglab'"+"lab("+"`j'"+" Int. "+"`i'"+") "
    			}
   				local leglab="`leglab'"+"lab("+"`nintplus2'"+" No intervention))"
    			sts graph, by(`int_no') noshow nodraw `leglab'
    		}
    		noi di as text "{hline 10}{c RT}"
			noi di
			noi di as text "                                              {c LT}{hline 1}PROGRESS{hline 1}{c RT}"
			noi di as text "   Estimating cumulative incidences:          {c LT}" _cont    
		}
		tempvar tag
		qui egen `tag'=tag(`idvar')
		local nintplus1=`nint'+1
		qui sort `int_no' `idvar' `tvar'
		forvalues i=0/`nintplus1' {
			qui count if `tag'==1 & `int_no'==`i'
			local tot`i'=r(N)
			if `i'==0 {
				qui count if _d!=1 & `idvar'[_n]!=`idvar'[_n+1] & `int_no'==0
				local d_or_c0=r(N)
				if "`death'"=="" {
					qui count if `outcome'==0 & `outcome'[_n+1]==. & `int_no'==0 & `tvar'!=`maxvlab'
					local ltfu0=r(N)
					qui count if `outcome'==. & `outcome'[_n+1]==. & `int_no'==0 & `tvar'==`firstv'
					local ltfu0=`ltfu0'+r(N)
				}
				else {
					qui count if `outcome'==0 & `death'==0 & `outcome'[_n+1]==. & `death'[_n+1]==. & `int_no'==0 & `tvar'!=`maxvlab'
					local ltfu0=r(N)
					qui count if `outcome'==. & `death'==. & `outcome'[_n+1]==. & `death'[_n+1]==. & `int_no'==0 & `tvar'==`firstv'
					local ltfu0=`ltfu0'+r(N)
				}
			}
			qui count if `outcome'==1 & `int_no'==`i'
			if `i'==0 {
				local tot0=r(N)+`d_or_c0'
				local out_0=r(N)
			}
			else {
				local out_`i'=r(N)/`tot`i''
			}
			if "`death'"!="" {
				qui count if `death'==1 & `int_no'==`i' 
				if `i'==0 {
					local c_at_end_0=`d_or_c0'-r(N)-`ltfu0'
					local ltfu0=`ltfu0'/`tot0'
					local out_0=`out_0'/`tot0'
				}
				local d_`i'=r(N)/`tot`i''
			}
			else {
				if `i'==0 {
					local out_0=`out_0'/`tot0'
					local c_at_end_0=`d_or_c0'-`ltfu0'
					local ltfu0=`ltfu0'/`tot0'
				}
			}
		}
    }
    local nintplus1=`nint'+1
    local nintplus2=`nint'+2
    forvalues i=1/`nintplus1' {
    	mat EPO[1,`i']=EPO[1,`i']+EPO[1,`nintplus2']
    }
   	if `_gc_chk_prt'==0 {
   		noi di as text "{hline 10}{c RT}"
	}
    if "`msm'"!="" {
    	if `_gc_chk_prt'==0 {
			noi di
    		noi di as text "                                              {c LT}{hline 1}PROGRESS{hline 1}{c RT}"
    		noi di as text "   Estimating parameters of MSM:              {c LT}" _cont
    	}
    	qui capture `msm' if `int_no'!=0 & `int_no'!=`nintplus1'
    	if _rc>0 {
    		tokenize "`msm'", parse(",")
    		qui `1' if `int_no'!=0 & `int_no'!=`nintplus1' `2' `3'
    	}
		tempname msm_params noomit
	    mat `msm_params'=e(b)
		_ms_omit_info `msm_params'
		local cols = colsof(`msm_params')
		matrix `noomit' =  J(1,`cols',1) - r(omit)
		mata: msm_params = select(st_matrix(st_local("msm_params")),(st_matrix(st_local("noomit"))))
		mata: st_matrix(st_local("msm_params"),msm_params)
		mat msm_params=`msm_params'
    	local colnames: colfullnames msm_params
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
		return clear
    	forvalues i=1/`nparams' {
    		local p`i'=msm_params[1,`i']
    		return scalar `colname`i''=`p`i''
    	}
    	return scalar N_msm_params=`nparams'
    	if `_gc_chk_prt'==0 {
    		noi di as text "{hline 10}{c RT}"
    		if e(cmd)=="cox" {
    			noi di
    			noi di as err "   Note: MSM results will be reported on the log hazard scale, irrespective of whether or not the " as result "nohr" as err " option was" 
    			noi di as err "   specified" 
    		}
    		if e(cmd)=="logit" {
    			noi di
    			noi di as err "   Note: MSM results will be reported on the log odds scale, irrespective of whether or not the " as result "or" as err " option was specified" 
    		}
    	}
    }
    local nb=colsof(EPO)-1
    forvalues i=1/`nb' {
    	local PO`i'=EPO[1,`i']
    	return scalar PO`i'=`PO`i''
    }
    local PO0=EPO[1,`nb'+1]
    return scalar PO0=`PO0'
    return scalar N_PO=`nb'
	if "`mediation'"=="" {
	    if "`eofu'"=="" {
			forvalues i=0/`nintplus1' {
				return scalar out`i'=`out_`i'' 
				if "`death'"!="" {
					return scalar death`i'=`d_`i'' 
				}
			}
			return scalar ltfu0=`ltfu0' 
		}
	}
}
else {
	if "`oce'"=="" {
		if `_gc_chk_prt'==0 {
			noi di
			noi di
    		noi di as text "                                              {c LT}{hline 1}PROGRESS{hline 1}{c RT}"
    		noi di as text "   Estimating direct/indirect effects:        {c LT}" _cont
    	}
		if "`control'"=="" {
			qui summ `outcome' if `int_no'==3
		}
		else {
			qui summ `outcome' if `int_no'==5
		}
		local e0=r(mean)
		qui summ `outcome' if `int_no'==1
		local e1=r(mean)
		qui summ `outcome' if `int_no'==2
		local e2=r(mean)
		if "`control'"!="" {
			qui summ `outcome' if `int_no'==3
			local e3=r(mean)
			qui summ `outcome' if `int_no'==4
			local e4=r(mean)
		}
		else {
			local e3=0
			local e4=0
		}
		if `_gc_chk_prt'==0 {
			noi di as text "{hline 10}{c RT}"
		}
		if "`logOR'"=="" & "`logRR'"=="" {
			local tce=`e0'-`e2'
			local nde=`e1'-`e2'
			local cde=`e3'-`e4'
		}
		if "`logOR'"!="" & "`logRR'"=="" {
			local tce=log(`e0'/(1-`e0'))-log(`e2'/(1-`e2'))
			local nde=log(`e1'/(1-`e1'))-log(`e2'/(1-`e2'))
			local cde=log(`e3'/(1-`e3'))-log(`e4'/(1-`e4'))
		}
		if "`logOR'"=="" & "`logRR'"!="" {
			local tce=log(`e0')-log(`e2')
			local nde=log(`e1')-log(`e2')
			local cde=log(`e3')-log(`e4')
		}
		local nie=`tce'-`nde'
		local pm=`nie'/`tce'
		return clear
		return scalar tce=`tce'
		return scalar nde=`nde'
		return scalar nie=`nie'
		return scalar pm=`pm'
		return scalar cde=`cde'
	}
	else {
		if `_gc_chk_prt'==0 {
			noi di
			noi di
    		noi di as text "                                              {c LT}{hline 1}PROGRESS{hline 1}{c RT}"
    		noi di as text "   Estimating direct/indirect effects:        {c LT}" _cont
    	}
		qui tab `exposure', matrow(_matrow)
		local nexplev=r(r)-1
		forvalues j=1/`nexplev' {
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
			if "`control'"=="" {
				qui summ `outcome' if `int_no'==3 & `exposure'==`k'
			}
			else {
				qui summ `outcome' if `int_no'==5 & `exposure'==`k'
			}
			local e0_`j'=r(mean)
			qui summ `outcome' if `int_no'==1 & `exposure'==`k'
			local e1_`j'=r(mean)
			qui summ `outcome' if `int_no'==2
			local e2=r(mean)
			if "`control'"!="" {
				qui summ `outcome' if `int_no'==3 & `exposure'==`k'
				local e3_`j'=r(mean)
				qui summ `outcome' if `int_no'==4
				local e4=r(mean)
			}
			else {
				local e3_`j'=0
				local e4=0
			}
			return clear
			if "`logOR'"=="" & "`logRR'"=="" {
				local tce_`j'=`e0_`j''-`e2'
				local nde_`j'=`e1_`j''-`e2'
				local cde_`j'=`e3_`j''-`e4'
			}
			if "`logOR'"!="" & "`logRR'"=="" {
				local tce_`j'=log(`e0_`j''/(1-`e0_`j''))-log(`e2'/(1-`e2'))
				local nde_`j'=log(`e1_`j''/(1-`e1_`j''))-log(`e2'/(1-`e2'))
				local cde_`j'=log(`e3_`j''/(1-`e3_`j''))-log(`e4'/(1-`e4'))
			}
			if "`logOR'"=="" & "`logRR'"!="" {
				local tce_`j'=log(`e0_`j'')-log(`e2')
				local nde_`j'=log(`e1_`j'')-log(`e2')
				local cde_`j'=log(`e3_`j'')-log(`e4')
			}			
			local nie_`j'=`tce_`j''-`nde_`j''
			local pm_`j'=`nie_`j''/`tce_`j''
		}
		if `_gc_chk_prt'==0 {
			noi di as text "{hline 10}{c RT}"			
		}
		forvalues j=1/`nexplev' {
			return scalar tce_`j'=`tce_`j''
			return scalar nde_`j'=`nde_`j''
			return scalar nie_`j'=`nie_`j''
			return scalar pm_`j'=`pm_`j''
			return scalar cde_`j'=`cde_`j''
		}
	}
	if "`msm'"!="" {
		if `_gc_chk_prt'==0 {
			noi di
			noi di as text "                                              {c LT}{hline 1}PROGRESS{hline 1}{c RT}"
			noi di as text "   Estimating parameters of MSM:              {c LT}" _cont
		}
		if "`control'"=="" {
			qui capture `msm' if `msm_switch_on'==1
			if _rc>0 {
				tokenize "`msm'", parse(",")
				qui `1' if `msm_switch_on'==1 & `2' `3'
			}
		}
		else {
			qui capture `msm' if `msm_switch_on'==1
			
			if _rc>0 {
				tokenize "`msm'", parse(",")
				qui `1' if `msm_switch_on'==1 & `2' `3'
			}
		}
		tempname msm_params noomit
		mat `msm_params'=e(b)
		_ms_omit_info `msm_params'
		local cols = colsof(`msm_params')
		matrix `noomit' =  J(1,`cols',1) - r(omit)
		mata: msm_params = select(st_matrix(st_local("msm_params")),(st_matrix(st_local("noomit"))))
		mata: st_matrix(st_local("msm_params"),msm_params)
		mat msm_params=`msm_params'
    	local colnames: colfullnames msm_params
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
    	forvalues i=1/`nparams' {
    		local p`i'=msm_params[1,`i']
    		return scalar `colname`i''=`p`i''
    	}
    	return scalar N_msm_params=`nparams'
    	if `_gc_chk_prt'==0 {
    		noi di as text "{hline 10}{c RT}"
    		if e(cmd)=="cox" {
    			noi di
    			noi di as err "   Note: MSM results will be reported on the log hazard scale, irrespective of whether or not the " as result "nohr" as err " option was" 
    			noi di as err "   specified" 
    		}
    		if e(cmd)=="logit" {
    			noi di
    			noi di as err "   Note: MSM results will be reported on the log odds scale, irrespective of whether or not the " as result "or" as err " option was specified" 
    		}
    	}
    }
}
if "`saving'"!="" {
	if `_gc_chk_sav'==2 {
		rename `int_no' _int
		keep _int `varlist'
		foreach var in `varlist' {
			local newname=substr("`var'",1,length("`var'")-1)
			if "`var'"=="`idvar'" {
				rename `idvar' _id
			}
			else {
				rename `var' `newname'
			}
		}
		qui save `saving', `replace'
		local _gc_chk_sav = 1
	}
	if `_gc_chk_sav'==0 {
		local _gc_chk_sav = 2
	}
}
if `_gc_chk_prt'==0 {
   	noi di
   	noi di
   	noi di as text "   Bootstrapping:"
   	local _gc_chk_prt = 1
}

* Return updated check flags to caller
c_local _gc_check_delete `_gc_chk_del'
c_local _gc_check_print `_gc_chk_prt'
c_local _gc_check_save `_gc_chk_sav'

* Clean up _gcomp_detangle globals
forvalues _gc_i = 1/50 {
	global S_`_gc_i'
}

* Clean up non-temp matrices
capture matrix drop matvis
capture matrix drop _matrow
capture matrix drop out_mlogit
capture matrix drop catvals
capture matrix drop EPO
capture matrix drop msm_params
capture matrix drop matem1
capture matrix drop matem2

ereturn clear
end

capture program drop _gcomp_display_stats
program define _gcomp_display_stats
version 16.0
set varabbrev off
set more off
* Display a single results row: estimate, SE, z, p-value, CI
* Caller writes the row label with _cont, then calls this program
syntax, est(real) se(real) ci_lo(real) ci_hi(real) ///
	[est_col(integer 19) se_col(integer 33) p_col(integer 54) CONTinue]
* Derived column positions from p_col
local z_neg = `p_col' - 7
local z_pos = `p_col' - 6
local ci_col = `p_col' + 9
local ci2_col = `p_col' + 21
* Estimate and SE
noi di as result %9.0g _col(`est_col') `est' _cont
noi di as result _col(`se_col') %9.0g `se' _cont
* z-score
local z = round(`est'/`se', 0.01)
if `est' < 0 {
	local w = `z_neg' - max(ceil(log10(abs(`z'))), 0)
}
else {
	local w = `z_pos' - max(ceil(log10(abs(`z'))), 0)
}
noi di as result _col(`w') `z' _cont
* p-value
local p = round(2*(1-normal(abs(`est'/`se'))), 0.001)
if `p' > 0 {
	noi di as result _col(`p_col') "0" _col(`=`p_col'+1') `p' _cont
	if `p' == round(`p', 0.1) {
		noi di _col(`=`p_col'+3') "00" _cont
	}
	else {
		if `p' == round(`p', 0.01) {
			noi di _col(`=`p_col'+4') "0" _cont
		}
	}
}
else {
	noi di as result _col(`p_col') "0.000" _cont
}
* CI
if "`continue'" != "" {
	noi di as result _col(`ci_col') %9.0g `ci_lo' _cont
	noi di as result _col(`ci2_col') %9.0g `ci_hi' _cont
}
else {
	noi di as result _col(`ci_col') %9.0g `ci_lo' _cont
	noi di as result _col(`ci2_col') %9.0g `ci_hi'
}
end

capture program drop _gcomp_detangle
program define _gcomp_detangle
version 16.0
set varabbrev off
args target tname rhs separator
if "`separator'"=="" {
	local separator ","
}
unab rhs:`rhs'
local nx: word count `rhs'
forvalues j=1/`nx' {
	local n`j': word `j' of `rhs'
}
tokenize "`target'", parse("`separator'")
local ncl 0
while "`1'"!="" {
	if "`1'"=="`separator'" {
		mac shift
	}
	local ncl=`ncl'+1
	local clust`ncl' "`1'"
	mac shift
}
if "`clust`ncl''"=="" {
	local --ncl
}
if `ncl'>`nx' {
	noi di as err "too many `tname'() values specified"
	exit 198
}
forvalues i=1/`ncl' {
	tokenize "`clust`i''", parse(":")
	if "`2'"!=":" {
		if `i'>1 {
			noi di as err "invalid `clust`i'' in `tname'() (syntax error)"
			exit 198
		}
		local 2 ":"
		local 3 `1'
		local 1
		forvalues j=1/`nx' {
			local 1 `1' `n`j''
		}
	}
	local arg3 `3'
	unab arg1:`1'
	tokenize `arg1'
	while "`1'"!="" {
		* Inlined chkin logic
		local _gc_k: list posof "`1'" in rhs
		if `_gc_k' == 0 {
			noi di as err "`1' is not a valid covariate"
			exit 198
		}
		local v`_gc_k' `arg3'
		mac shift
	}
}
forvalues j=1/`nx' {
	if "`v`j''"!="" {
		global S_`j' `v`j''
	}
	else global S_`j'
}
end

capture program drop _gcomp_formatline
program define _gcomp_formatline, rclass
version 16.0
set varabbrev off
syntax, N(string) Maxlen(int) [ Format(string) Leading(int 1) Separator(string) ]
if `leading'<0 {
	noi di as err "invalid leading()"
	exit 198
}
if "`separator'"!="" {
	tokenize "`n'", parse("`separator'")
}
else tokenize "`n'"
local n 0
while "`1'"!="" {
	if "`1'"!="`separator'" {
		local ++n
		local n`n' `1'
	}
	macro shift
}
local j 0
local length 0
forvalues i=1/`n' {
	if "`format'"!="" {
		capture local out: display `format' `n`i''
		if _rc {
			noi di as err "invalid format attempted for: " `"`n`i''"'
			exit 198
		}
	}
	else local out `n`i''
	if `leading'>0 {
		local out " `out'"
	}
	local l1=length("`out'")
	local l2=`length'+`l1'
	if `l2'>`maxlen' {
		local ++j
		return local line`j'="`line'"
		local line "`out'"
		local length `l1'
	}
	else {
		local length `l2'
		local line "`line'`out'"
	}
}
local ++j
return local line`j'="`line'"
return scalar lines=`j'
end

exit
