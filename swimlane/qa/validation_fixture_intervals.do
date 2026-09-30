*! validation_fixture_intervals.do -- independent interval tuples, subject spans and audits
* Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set more off
set varabbrev off
set graphics off
capture log close _all
log using "validation_fixture_intervals.log",text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a4.do"
quietly do "_qa_hostile.do"
quietly do "_qa_state.do"
mata:
void qa_swim_interval_oracle()
{
    real matrix X, S, W
    real colvector ids, ix, prior
    real scalar j, k, lo, hi, overlaps, gaps
    X=st_data(.,("id","start","stop","category"))
    X=select(X,!rowmissing(X))
    X=sort(X,(1,2,3))
    ids=uniqrows(X[,1]);S=J(rows(ids),3,.)
    overlaps=0;gaps=0
    for(j=1;j<=rows(ids);j++) {
        ix=selectindex(X[,1]:==ids[j]);W=X[ix,]
        lo=min(W[,2]);hi=max(W[,3]);S[j,]=(ids[j],lo,hi)
        for(k=2;k<=rows(W);k++) {
            prior=W[|1,3\k-1,3|]
            overlaps=overlaps+(W[k,2]<max(prior))
            gaps=gaps+(W[k,2]>max(prior))
        }
    }
    st_matrix("segments",X);st_matrix("spans",S)
    st_numscalar("expected_overlap",overlaps);st_numscalar("expected_gap",gaps)
}
end
capture program drop _qa_swim_interval_compare
program define _qa_swim_interval_compare
    version 16.0
    mata: qa_swim_interval_oracle()
    scalar expected_segments=rowsof(segments)
    scalar expected_subjects=rowsof(spans)
    scalar expected_span=spans[1,3]-spans[1,2]
    foreach mode in state swimmer {
        local stateopt ""
        if "`mode'"=="state" local stateopt "state(category) intervalcheck(off)"
        local original_frame "`c(frame)'"
        qa_state_snapshot,tag(interval)
        quietly swimlane, id(id) start(start) stop(stop) `stateopt' mode(`mode') maxids(all) nograph frame(fxinterval,replace)
        qa_state_compare,tag(interval) allow(frame)
        assert "`c(frame)'"=="`original_frame'"
        assert r(N_subjects)==expected_subjects & r(N_subjects_total)==expected_subjects & r(N_events)==0 & r(N_intervals)==0
        assert r(min_duration)==expected_span & r(max_duration)==expected_span & r(median_duration)==expected_span
        if "`mode'"=="state" {
            assert r(N_segments)==expected_segments & r(N_overlaps)==expected_overlap & r(N_gaps)==expected_gap
            frame fxinterval:assert _N==expected_segments & rowtype=="bar"
            forvalues j=1/`=rowsof(segments)' {
                scalar wantid=segments[`j',1]
                scalar wantstart=segments[`j',2]
                scalar wantstop=segments[`j',3]
                scalar wantcat=segments[`j',4]
                mata: st_numscalar("wantcount",sum((st_matrix("segments")[,1]:==st_numscalar("wantid")):&(st_matrix("segments")[,2]:==st_numscalar("wantstart")):&(st_matrix("segments")[,3]:==st_numscalar("wantstop")):&(st_matrix("segments")[,4]:==st_numscalar("wantcat"))))
                frame fxinterval:count if id==wantid & start==wantstart & stop==wantstop & real(series)==wantcat
                assert r(N)==wantcount
            }
        }
        else {
            assert r(N_segments)==expected_subjects
            frame fxinterval:assert _N==expected_subjects & rowtype=="bar"
            forvalues j=1/`=rowsof(spans)' {
                frame fxinterval:assert start==spans[`j',2] & stop==spans[`j',3] if id==spans[`j',1]
            }
        }
        frame fxinterval:assert !missing(start,stop,duration) & duration==stop-start
        frame drop fxinterval
    }
end
local tests=0
local pass=0
local fail=0
local ++tests
capture noisily {
    qa_fx_a4_spells,clear tier(micro)
    _qa_swim_interval_compare
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a4_spells,clear tier(micro) perturb(overlap)
    _qa_swim_interval_compare
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a4_spells,clear tier(micro) perturb(abut)
    _qa_swim_interval_compare
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a4_spells,clear tier(micro) perturb(zero_length)
    _qa_swim_interval_compare
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    * Missing stops are excluded by the public long-input sample contract.
    qa_fx_a4_spells,clear tier(micro) perturb(open_end)
    _qa_swim_interval_compare
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a4_spells,clear tier(micro) perturb(unsorted)
    _qa_swim_interval_compare
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a4_spells,clear tier(micro) perturb(dup_key)
    _qa_swim_interval_compare
}
if _rc local ++fail
else local ++pass
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a4_spells,clear tier(micro) perturb(boundary_values)
    _qa_swim_interval_compare
}
if _rc local ++fail
else local ++pass
display "RESULT: validation_fixture_intervals tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
