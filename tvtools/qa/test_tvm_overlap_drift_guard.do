*! test_tvm_overlap_drift_guard.do
*! B1 drift guard: the tvtools interval-overlap engine (_tvm_build_pairs_overlap,
*! via _tvmerge_overlap_pairs) is a slimmed, renamed specialisation of rangematch's
*! _rm_build_pairs_overlap. The two implementations are hand-maintained in separate
*! packages and could silently diverge. This test pins them together:
*!
*!   ORACLE  : independent joinby+overlap-filter (the very approach tvmerge replaced),
*!             with missing bounds treated as open-ended (+/- inf). Ground truth.
*!   TVM     : _tvmerge_overlap_pairs over work frames.
*!   RM      : rangematch ... overlap(ulo uhi) by(gid) closed(both) unmatched(none).
*!
*! All three must emit the identical set of (master_obs, using_obs) pairs.

clear all
set more off
set varabbrev off
version 16.0

* --- bootstrap: tvtools into a sandboxed PLUS, plus rangematch (the co-engine) ---
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"                 // .../tvtools
local stata_tools = substr("`pkg_dir'", 1, strrpos("`pkg_dir'", "/") - 1)
local rm_dir "`stata_tools'/rangematch"
capture confirm file "`rm_dir'/rangematch.ado"
if _rc {
    display as error "rangematch package not found at `rm_dir'; cannot run drift guard"
    exit 601
}
capture ado uninstall rangematch
quietly net install rangematch, from("`rm_dir'") replace

* _tvmerge_overlap_pairs / _tvm_build_pairs_overlap live in the library file
* _tvmerge_mata.ado, which tvmerge runs on demand (not autoloaded by name).
findfile _tvmerge_mata.ado
run "`r(fn)'"

local FAIL 0
tempfile MAS USG ORACLE TVMOUT RMOUT

* ---------------------------------------------------------------------------
* Fixed random interval data with person groups (gid), some open-ended bounds.
* ---------------------------------------------------------------------------
clear
set obs 50
set seed 80531
gen int    gid  = 1 + mod(_n, 5)            // groups 1..5
gen double mlo  = floor(runiform()*40)
gen double mhi  = mlo + floor(runiform()*8)
gen long   mobs = _n
replace mlo = . in 4                         // open-below master
replace mhi = . in 9                         // open-above master
replace mlo = . in 13
replace mhi = . in 13                        // fully open master
save "`MAS'"

clear
set obs 70
set seed 24601
gen int    gid  = 1 + mod(_n, 6)            // groups 1..6 (6 absent in master)
gen double ulo  = floor(runiform()*40)
gen double uhi  = ulo + floor(runiform()*6)
gen long   uobs = _n
replace ulo = . in 7                          // open-below using
replace uhi = . in 15                         // open-above using
save "`USG'"

* ---------------------------------------------------------------------------
* ORACLE: joinby within gid, overlap filter with missing -> +/- inf.
* ---------------------------------------------------------------------------
use "`MAS'", clear
joinby gid using "`USG'"
gen double _mlo = cond(missing(mlo), -1e300, mlo)
gen double _mhi = cond(missing(mhi),  1e300, mhi)
gen double _ulo = cond(missing(ulo), -1e300, ulo)
gen double _uhi = cond(missing(uhi),  1e300, uhi)
keep if _mlo <= _mhi & _ulo <= _mhi & _uhi >= _mlo
keep mobs uobs
gsort mobs uobs
save "`ORACLE'"
quietly count
local n_oracle = r(N)

* ---------------------------------------------------------------------------
* TVM: build the two work frames (gid low high obs) and call the engine.
* ---------------------------------------------------------------------------
capture frame drop _dg_m
capture frame drop _dg_u
capture frame drop _dg_out
frame create _dg_m
frame _dg_m {
    use "`MAS'", clear
    keep gid mlo mhi mobs
    order gid mlo mhi mobs
}
frame create _dg_u
frame _dg_u {
    use "`USG'", clear
    keep gid ulo uhi uobs
    order gid ulo uhi uobs
}
frame create _dg_out
_tvmerge_overlap_pairs _dg_m _dg_u _dg_out
frame _dg_out {
    rename __tvm_mi mobs
    rename __tvm_ui uobs
    quietly destring, replace
    gsort mobs uobs
    save "`TVMOUT'", replace
    quietly count
    local n_tvm = r(N)
}

* ---------------------------------------------------------------------------
* RM: rangematch interval-overlap, inner join, closed boundaries.
* ---------------------------------------------------------------------------
use "`MAS'", clear
rangematch mlo mhi using "`USG'", overlap(ulo uhi) by(gid) ///
    closed(both) unmatched(none) keepusing(uobs) masterid(_mi) usingid(_ui)
keep _mi _ui
rename _mi mobs
rename _ui uobs
gsort mobs uobs
save "`RMOUT'", replace
quietly count
local n_rm = r(N)

* ---------------------------------------------------------------------------
* Compare all three pair sets.
* ---------------------------------------------------------------------------
display as text "oracle pairs=`n_oracle'  tvm pairs=`n_tvm'  rm pairs=`n_rm'"

if `n_tvm' != `n_oracle' {
    display as error "DRIFT: tvm pair count `n_tvm' != oracle `n_oracle'"
    local ++FAIL
}
else {
    use "`TVMOUT'", clear
    capture cf _all using "`ORACLE'"
    if _rc {
        display as error "DRIFT: tvm pair SET != oracle (cf rc=`=_rc')"
        local ++FAIL
    }
}
if `n_rm' != `n_oracle' {
    display as error "DRIFT: rangematch pair count `n_rm' != oracle `n_oracle'"
    local ++FAIL
}
else {
    use "`RMOUT'", clear
    capture cf _all using "`ORACLE'"
    if _rc {
        display as error "DRIFT: rangematch pair SET != oracle (cf rc=`=_rc')"
        local ++FAIL
    }
}

capture frame drop _dg_m
capture frame drop _dg_u
capture frame drop _dg_out

display as text "{hline 60}"
if `FAIL' > 0 {
    display as error "test_tvm_overlap_drift_guard: FAILED (`FAIL')"
    exit 9
}
display as result "test_tvm_overlap_drift_guard: PASSED (tvm == rangematch == oracle, `n_oracle' pairs)"
