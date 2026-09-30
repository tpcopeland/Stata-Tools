*! validation_fixture_truth.do -- exact life-table Kaplan-Meier/risk/logrank oracle
version 16.0
clear all
set processors 1
set varabbrev off
set graphics off
capture log close _all
log using "validation_fixture_truth.log", text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a2.do"
quietly do "_qa_hostile.do"
capture program drop _qakm_oracle
program define _qakm_oracle
    version 16.0
    args event failmode scale
    if "`scale'"=="" local scale 1
    local opt ""
    if `failmode' local opt failure
    local times ""
    forvalues k=0/5 {
        scalar tk=`scale'*`k'
        local hex: display %21x tk
        local times "`times' `hex'"
    }
    quietly stset t, failure(`event') enter(time t0) id(id)
    quietly kmplot, by(x1) `opt' ci median pvalue risktable riskevents ///
        landmark(`times') timepoints(`times') name(fxkm,replace)
    matrix LM=r(landmarks)
    matrix RT=r(risktable)
    matrix MD=r(medians)
    scalar gotp=r(p)
    assert r(N)==24 & r(n_groups)==2
    assert rowsof(LM)==12 & colsof(LM)==5
    assert rowsof(RT)==12 & colsof(RT)==5
    local si=cond("`event'"=="d",7,11)
    local ei=cond("`event'"=="d",1,2)
    qa_assert_equal gotp chi2tail(1,logranktruth[`ei',3]), property("exact tied logrank pvalue") tol(1e-12)
    forvalues a=0/1 {
        scalar gw=0
        scalar mediantruth=.
        forvalues k=0/5 {
            local row=`a'*6+`k'+1
            local tr=`a'*5+min(`k',4)+1
            scalar S=T[`tr',`si']
            if `k'>0 & `k'<=4 {
                scalar nrisk=T[`tr',3]
                scalar nevt=T[`tr',4]+cond("`event'"=="d",T[`tr',5],0)
                if nrisk>nevt & nevt>0 scalar gw=gw+nevt/(nrisk*(nrisk-nevt))
                if S<=.5 & missing(mediantruth) scalar mediantruth=`k'*`scale'
            }
            // Beyond a group's observed support only terminal S=0 carries.
            quietly summarize t if x1==`a', meanonly
            scalar maxt=r(max)
            scalar mint=r(min)
            scalar tv=`k'*`scale'
            scalar expected=cond(tv>maxt & S!=0,.,cond(`failmode',1-S,S))
            assert LM[`row',1]==`a'+1
            qa_assert_equal LM[`row',2] tv, property("exact keyed landmark time")
            if missing(expected) assert missing(LM[`row',3])
            else qa_assert_equal LM[`row',3] expected, property("enumerated Kaplan-Meier landmark") tol(1e-12)
            if `k'==0 | tv<mint {
                qa_assert_equal LM[`row',4] expected, property("time-zero lower anchor")
                qa_assert_equal LM[`row',5] expected, property("time-zero upper anchor")
            }
            else if !missing(expected) & S>0 & S<1 & gw>0 {
                scalar z=invnormal(.975)
                scalar lo=exp(-exp(ln(-ln(S))+z*sqrt(gw)/abs(ln(S))))
                scalar hi=exp(-exp(ln(-ln(S))-z*sqrt(gw)/abs(ln(S))))
                scalar wantlo=cond(`failmode',1-hi,lo)
                scalar wanthi=cond(`failmode',1-lo,hi)
                qa_assert_equal LM[`row',4] wantlo, property("independent Greenwood loglog lower") tol(1e-11)
                qa_assert_equal LM[`row',5] wanthi, property("independent Greenwood loglog upper") tol(1e-11)
            }
            else assert missing(LM[`row',4],LM[`row',5])
            quietly count if x1==`a' & t>=tv & (t0<tv | (t0==0 & tv==0))
            scalar nr=r(N)
            quietly count if x1==`a' & t<=tv & `event'
            scalar ne=r(N)
            quietly count if x1==`a' & t<=tv & !(`event')
            scalar nc=r(N)
            assert RT[`row',1]==`a'+1
            qa_assert_equal RT[`row',2] tv, property("keyed risk-table time")
            qa_assert_equal RT[`row',3] nr, property("exact delayed-entry risk count")
            qa_assert_equal RT[`row',4] ne, property("exact cumulative events")
            qa_assert_equal RT[`row',5] nc, property("exact cumulative censorings")
        }
        if missing(mediantruth) assert missing(MD[`a'+1,2])
        else qa_assert_equal MD[`a'+1,2] mediantruth, property("first half-survival crossing") tol(1e-14)
    }
end
local tests=0
local pass=0
local fail=0

local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(ties)
    assert !missing(r(perturb_n_ties)) & r(perturb_n_ties)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(noevent)
    assert !missing(r(perturb_n_noevent)) & r(perturb_n_noevent)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(absorb)
    assert !missing(r(perturb_n_absorb)) & r(perturb_n_absorb)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(empty_stratum)
    assert !missing(r(perturb_n_empty_stratum)) & r(perturb_n_empty_stratum)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(late_entry)
    assert !missing(r(perturb_n_late_entry)) & r(perturb_n_late_entry)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(boundary_values)
    assert !missing(r(perturb_n_boundary_values)) & r(perturb_n_boundary_values)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(unsorted)
    assert !missing(r(perturb_n_unsorted)) & r(perturb_n_unsorted)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(codes_multidigit)
    assert !missing(r(perturb_n_codes_multidigit)) & r(perturb_n_codes_multidigit)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 0
    * expect: INVARIANT
    qa_hostile_times
    local scale "`r(up)'"
    replace t=t*`scale'
    replace t0=t0*`scale'
    _qakm_oracle "d" 0 `scale'
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(ties)
    assert !missing(r(perturb_n_ties)) & r(perturb_n_ties)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(noevent)
    assert !missing(r(perturb_n_noevent)) & r(perturb_n_noevent)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(absorb)
    assert !missing(r(perturb_n_absorb)) & r(perturb_n_absorb)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(empty_stratum)
    assert !missing(r(perturb_n_empty_stratum)) & r(perturb_n_empty_stratum)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(late_entry)
    assert !missing(r(perturb_n_late_entry)) & r(perturb_n_late_entry)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(boundary_values)
    assert !missing(r(perturb_n_boundary_values)) & r(perturb_n_boundary_values)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(unsorted)
    assert !missing(r(perturb_n_unsorted)) & r(perturb_n_unsorted)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(codes_multidigit)
    assert !missing(r(perturb_n_codes_multidigit)) & r(perturb_n_codes_multidigit)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "d" 1
    * expect: INVARIANT
    qa_hostile_times
    local scale "`r(up)'"
    replace t=t*`scale'
    replace t0=t0*`scale'
    _qakm_oracle "d" 1 `scale'
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(ties)
    assert !missing(r(perturb_n_ties)) & r(perturb_n_ties)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(noevent)
    assert !missing(r(perturb_n_noevent)) & r(perturb_n_noevent)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(absorb)
    assert !missing(r(perturb_n_absorb)) & r(perturb_n_absorb)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(empty_stratum)
    assert !missing(r(perturb_n_empty_stratum)) & r(perturb_n_empty_stratum)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(late_entry)
    assert !missing(r(perturb_n_late_entry)) & r(perturb_n_late_entry)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(boundary_values)
    assert !missing(r(perturb_n_boundary_values)) & r(perturb_n_boundary_values)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(unsorted)
    assert !missing(r(perturb_n_unsorted)) & r(perturb_n_unsorted)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(codes_multidigit)
    assert !missing(r(perturb_n_codes_multidigit)) & r(perturb_n_codes_multidigit)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 0
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 0
    * expect: INVARIANT
    qa_hostile_times
    local scale "`r(up)'"
    replace t=t*`scale'
    replace t0=t0*`scale'
    _qakm_oracle "cause==1" 0 `scale'
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(ties)
    assert !missing(r(perturb_n_ties)) & r(perturb_n_ties)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(noevent)
    assert !missing(r(perturb_n_noevent)) & r(perturb_n_noevent)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(absorb)
    assert !missing(r(perturb_n_absorb)) & r(perturb_n_absorb)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(empty_stratum)
    assert !missing(r(perturb_n_empty_stratum)) & r(perturb_n_empty_stratum)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(late_entry)
    assert !missing(r(perturb_n_late_entry)) & r(perturb_n_late_entry)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(boundary_values)
    assert !missing(r(perturb_n_boundary_values)) & r(perturb_n_boundary_values)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(unsorted)
    assert !missing(r(perturb_n_unsorted)) & r(perturb_n_unsorted)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(codes_multidigit)
    assert !missing(r(perturb_n_codes_multidigit)) & r(perturb_n_codes_multidigit)>0
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 1
}
if _rc local ++fail
else local ++pass

local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    matrix T=r(truth_table)
    matrix logranktruth=r(truth_logrank)
    _qakm_oracle "cause==1" 1
    * expect: INVARIANT
    qa_hostile_times
    local scale "`r(up)'"
    replace t=t*`scale'
    replace t0=t0*`scale'
    _qakm_oracle "cause==1" 1 `scale'
}
if _rc local ++fail
else local ++pass

display "RESULT: validation_fixture_truth tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
