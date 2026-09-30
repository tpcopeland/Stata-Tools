*! validation_fixture_intervals.do — canonical SPELLS overlap Cartesian oracle
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.1
clear all
set more off
set varabbrev off
capture log close _all
log using "validation_fixture_intervals.log", replace text nomsg
args strict
if "`strict'"=="" local strict off
assert inlist("`strict'","off","on")
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_fx_a4.do"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_hostile.do"
do "`qa_dir'/_qa_metamorphic.do"
mata: mata set matastrict `strict'
* Every caller global except the two native filename aliases stays strict.
mata: st_global("FX_RANGE_CALLER",char(36)+"opaque"+char(34)+char(96)+char(39))
* Reuse the state collector/differ; remove only the native filename aliases.
* rangematch memory output is a replacement dataset, whose filename is empty.
mata:
void _fx_output_metadata_diff(string scalar was, string scalar now)
{
    pointer(transmorphic scalar) scalar pw, pn
    pw=findexternal(was);pn=findexternal(now)
    asarray_remove(*pw,"global|S_FN")
    asarray_remove(*pw,"global|S_FNDATE")
    asarray_remove(*pn,"global|S_FN")
    asarray_remove(*pn,"global|S_FNDATE")
    _qa_st_diff(was,now,"overlap_state","data sort char")
}
end
capture program drop _fx_intervals
program define _fx_intervals, rclass
    version 16.1
    args op
    tempfile source usingdata master expected
    quietly save `source'
    keep id start stop
    generate long uid=_n
    rename start ulo
    rename stop uhi
    if "`op'"!="time_hostile" {
        replace ulo=ulo+1
        replace uhi=uhi+1 if !missing(uhi)
    }
    quietly save `usingdata'
    quietly use `source', clear
    keep id start stop
    generate long mid=_n
    rename start mlo
    rename stop mhi
    quietly save `master'
    local tests=0
    local pass=0
    local fail=0
    foreach closed in both none {
        use `master', clear
        joinby id using `usingdata'
        if "`closed'"=="both" keep if mlo<=mhi & ulo<=uhi & mlo<=uhi & ulo<=mhi
        else keep if mlo<mhi & ulo<uhi & mlo<uhi & ulo<mhi
        keep mid uid
        sort mid uid
        local pairs=_N
        quietly save `expected', replace
        foreach shape in memory frame dryrun {
            local ++tests
            capture noisily {
                use `master', clear
                local opts ""
                if "`shape'"=="frame" local opts "frame(fx_overlap) replace"
                if "`shape'"=="dryrun" local opts "dryrun"
                qa_state_snapshot, tag(overlap_state)
                rangematch mlo mhi using `usingdata', overlap(ulo uhi) by(id) keepusing(uid) closed(`closed') missing(wildcard) unmatched(none) `opts'
                assert r(N_pairs)==`pairs'
                if "`shape'"=="dryrun" qa_state_compare, tag(overlap_state)
                else if "`shape'"=="frame" {
                    qa_state_compare, tag(overlap_state) allow(frame)
                    frame fx_overlap {
                        keep mid uid
                        sort mid uid
                        cf _all using `expected', all
                    }
                    frame drop fx_overlap
                }
                else {
                    * No active estimates: replacement does not promise an old sample.
                    assert "`e(cmd)'"==""
                    assert c(filename)==""
                    mata: assert(st_global("S_FN")=="" & st_global("S_FNDATE")=="")
                    _qa_st_collect __qa_state_memnow "" "" ""
                    mata: _fx_output_metadata_diff("__qa_state_overlap_state","__qa_state_memnow")
                    local state_diffs=`ndiff'
                    mata: rmexternal("__qa_state_memnow")
                    qa_state_drop, tag(overlap_state)
                    assert `state_diffs'==0
                    keep mid uid
                    sort mid uid
                    cf _all using `expected', all
                }
                di "ORACLE SPELLS `op' overlap `closed' `shape': all `pairs' row pairs exact"
            }
            local rc=_rc
            capture frame drop fx_overlap
            if `rc'==0 local ++pass
            else {
                local ++fail
                di as error "FAIL SPELLS `op' overlap `closed' `shape' rc=`rc'"
            }
        }
    }
    local ++tests
    capture noisily {
        use `master', clear
        * expect: EXACT
        qa_option_domain, command(rangematch mlo mhi using `usingdata', overlap(ulo uhi) by(id) keepusing(uid) closed(both) missing(wildcard) unmatched(none) maxpairs(@v@)) inside(0;1000) outside(-1;0.5)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `master', clear
        * expect: EXACT
        qa_option_domain, command(rangematch mlo mhi using `usingdata', overlap(ulo uhi) by(id) keepusing(uid) closed(both) missing(wildcard) unmatched(none) tolerance(@v@)) inside(0;0.0000000000001) outside(-1)
    }
    if _rc==0 local ++pass
    else local ++fail
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a4_spells, clear tier(micro)
_fx_intervals friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(overlap)
_fx_intervals overlap
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(abut)
_fx_intervals abut
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(zero_length)
_fx_intervals zero_length
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(open_end)
_fx_intervals open_end
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(unsorted)
_fx_intervals unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(dup_key)
_fx_intervals dup_key
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a4_spells, clear tier(micro) perturb(boundary_values)
_fx_intervals boundary_values
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* Near-jump endpoint relations are tested without decimal transport/epsilon.
qa_fx_a4_spells, clear tier(micro)
* expect: EXACT
qa_hostile_times, generate(hostile_time)
replace start=hostile_time
sort id start
by id: replace stop=cond(_n<_N,start[_n+1],start)
drop hostile_time
_fx_intervals time_hostile
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
di "RESULT: validation_fixture_intervals tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
