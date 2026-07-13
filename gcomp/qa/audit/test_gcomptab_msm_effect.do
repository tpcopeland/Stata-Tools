clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"
capture program drop mock_msm
program define mock_msm, eclass
matrix b=(1.1,2.2,.3,.2,.1,.333,.25)
matrix colnames b=msm1 msm2 tce nde nie pm cde
matrix V=I(7)*.01
matrix colnames V=msm1 msm2 tce nde nie pm cde
matrix rownames V=msm1 msm2 tce nde nie pm cde
ereturn post b V
ereturn local cmd "gcomp"
ereturn local analysis_type "mediation"
ereturn local mediation_type "obe"
matrix se=(.1,.1,.1,.1,.1,.1,.1)
matrix colnames se=msm1 msm2 tce nde nie pm cde
ereturn matrix se=se
matrix ci=(.9,2,.1,0,-.1,.13,.05\1.3,2.4,.5,.4,.3,.53,.45)
matrix colnames ci=msm1 msm2 tce nde nie pm cde
ereturn matrix ci_normal=ci
end
mock_msm
local f "/tmp/gcomptab msm effects.xlsx"
capture erase "`f'"
gcomptab, xlsx("`f'") sheet("Effects")
assert r(N_effects)==5
assert r(has_cde)==1
capture erase "`f'"

* One MSM parameter, unrelated metadata, different effect order, and
* independently ordered/extended uncertainty matrices are all selected by
* effect name rather than by vector position or total width.
capture program drop mock_named_extra
program define mock_named_extra, eclass
matrix b=(.2,9,.1,.3,.4,77)
matrix colnames b=pm msm_aux tce nie nde metadata
matrix V=I(6)*.01
matrix colnames V=pm msm_aux tce nie nde metadata
matrix rownames V=pm msm_aux tce nie nde metadata
ereturn post b V
ereturn local cmd "gcomp"
ereturn local analysis_type "mediation"
ereturn local mediation_type "obe"
matrix se=(.12,.11,.13,.14,.15)
matrix colnames se=nde tce pm nie ignored_se
ereturn matrix se=se
matrix ci=(88,.05,.10,.20,.00,66\99,.55,.30,.60,.20,77)
matrix colnames ci=ignored_ci nie pm nde tce metadata_ci
ereturn matrix ci_normal=ci
end
mock_named_extra
local f2 "/tmp/gcomptab named extra effects.xlsx"
capture erase "`f2'"
gcomptab, xlsx("`f2'") sheet("Named")
assert r(N_effects)==4
assert r(has_cde)==0
assert r(tce)==.1
assert r(nde)==.4
assert r(nie)==.3
assert r(pm)==.2
capture erase "`f2'"

* A genuinely absent required effect remains an error.
capture program drop mock_missing_effect
program define mock_missing_effect, eclass
matrix b=(9,.1,.4,.3)
matrix colnames b=msm_aux tce nde nie
matrix V=I(4)*.01
matrix colnames V=msm_aux tce nde nie
matrix rownames V=msm_aux tce nde nie
ereturn post b V
ereturn local cmd "gcomp"
ereturn local analysis_type "mediation"
ereturn local mediation_type "obe"
matrix se=(.1,.1,.1,.1)
matrix colnames se=msm_aux tce nde nie
ereturn matrix se=se
matrix ci=(8,0,.2,.1\10,.2,.6,.5)
matrix colnames ci=msm_aux tce nde nie
ereturn matrix ci_normal=ci
end
mock_missing_effect
capture noisily gcomptab, xlsx("/tmp/gcomptab missing effect.xlsx") sheet("Bad")
assert _rc==198
capture erase "/tmp/gcomptab missing effect.xlsx"

* Optional CDE must be present consistently in every effect-bearing matrix.
capture program drop mock_cde_mismatch
program define mock_cde_mismatch, eclass
matrix b=(.1,.4,.3,.2,.05)
matrix colnames b=tce nde nie pm cde
matrix V=I(5)*.01
matrix colnames V=tce nde nie pm cde
matrix rownames V=tce nde nie pm cde
ereturn post b V
ereturn local cmd "gcomp"
ereturn local analysis_type "mediation"
ereturn local mediation_type "obe"
matrix se=(.1,.1,.1,.1)
matrix colnames se=tce nde nie pm
ereturn matrix se=se
matrix ci=(0,.2,.1,0,-.1\.2,.6,.5,.4,.2)
matrix colnames ci=tce nde nie pm cde
ereturn matrix ci_normal=ci
end
mock_cde_mismatch
capture noisily gcomptab, xlsx("/tmp/gcomptab cde mismatch.xlsx") sheet("Bad")
assert _rc==198
capture erase "/tmp/gcomptab cde mismatch.xlsx"

display "RESULT: gcomptab_msm_effect_probe status=PASS"

display "RESULT: test_gcomptab_msm_effect tests=1 pass=1 fail=0 status=PASS"
