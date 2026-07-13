clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"

capture program drop make_save_tv
program define make_save_tv
    clear
    set seed 9201
    set obs 800
    gen long id=1000+7*ceil(_n/4)
    bysort id: gen double time=2*_n-1
    gen double L=rnormal()+.1*time
    gen byte A=rbinomial(1,invlogit(-.8+.2*L))
    gen double Y=.5*A+.3*L+rnormal()
end

local unicode_path `"/tmp/gcomp schema ü 'quoted'.dta"'
capture erase `"`unicode_path'"'
make_save_tv
tempfile caller_before
save `caller_before'
gcomp Y L A id time, outcome(Y) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) eofu pooled ///
    commands(L: regress, A: logit, Y: regress) ///
    equations(L: time, A: L time, Y: A L time) ///
    sim(140) samples(3) seed(141) saving(`"`unicode_path'"') replace
assert `"`e(saving)'"'==`"`unicode_path'"'
assert "`e(saved_schema_version)'"=="1"
local run_id "`e(run_id)'"
local rngstate `"`e(rngstate)'"'
cf _all using `caller_before', all

preserve
use `"`unicode_path'"', clear
confirm numeric variable _int
confirm numeric variable _id
confirm numeric variable _source_id
assert !missing(_int,_id,_source_id)
assert _source_id>=1007
assert mod(_source_id-1000,7)==0
assert "`: char _dta[gcomp_schema_version]'"=="1"
assert "`: char _dta[gcomp_run_id]'"=="`run_id'"
assert `"`: char _dta[gcomp_rngstate]'"'==`"`rngstate'"'
restore

* Existing file fails without replace and leaves caller data untouched.
make_save_tv
save `caller_before', replace
capture noisily gcomp Y L A id time, outcome(Y) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) eofu pooled ///
    commands(L: regress, A: logit, Y: regress) ///
    equations(L: time, A: L time, Y: A L time) ///
    sim(140) samples(3) seed(142) saving(`"`unicode_path'"')
assert _rc!=0
cf _all using `caller_before', all

* replace deliberately overwrites the same quoted/non-ASCII path.
gcomp Y L A id time, outcome(Y) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) eofu pooled ///
    commands(L: regress, A: logit, Y: regress) ///
    equations(L: time, A: L time, Y: A L time) ///
    sim(140) samples(3) seed(143) saving(`"`unicode_path'"') replace
assert e(bootstrap_failed)==0

* A write failure is surfaced and restores caller data.
make_save_tv
save `caller_before', replace
capture noisily gcomp Y L A id time, outcome(Y) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) eofu pooled ///
    commands(L: regress, A: logit, Y: regress) ///
    equations(L: time, A: L time, Y: A L time) ///
    sim(140) samples(3) seed(144) saving("/tmp/no-such-gcomp-dir/out.dta") replace
assert _rc!=0
cf _all using `caller_before', all

* Reserved schema names are rejected only when they are part of the saved
* analysis surface; unrelated caller variables are safely omitted and restored.
foreach reserved in _id _int _source_id {
    make_save_tv
    gen double `reserved'=rnormal()
    save `caller_before', replace
    capture noisily gcomp Y L A `reserved' id time, outcome(Y) idvar(id) tvar(time) ///
        varyingcovariates(L) intvars(A) interventions(A=1, A=0) eofu pooled ///
        commands(L: regress, A: logit, Y: regress) ///
        equations(L: `reserved' time, A: L time, Y: A L time) ///
        sim(140) samples(3) seed(145) saving(`"`unicode_path'"') replace
    assert _rc==110
    cf _all using `caller_before', all
}

make_save_tv
gen double _id=rnormal()
tempfile unrelated_before
save `unrelated_before'
gcomp Y L A id time, outcome(Y) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) eofu pooled ///
    commands(L: regress, A: logit, Y: regress) ///
    equations(L: time, A: L time, Y: A L time) ///
    sim(140) samples(3) seed(146) saving(`"`unicode_path'"') replace
cf _all using `unrelated_before', all

capture erase `"`unicode_path'"'
display "RESULT: H14 saved schema/path/identity status=PASS"
display "RESULT: gcomp_saving_schema_probe status=PASS"

display "RESULT: test_saving_schema tests=1 pass=1 fail=0 status=PASS"

