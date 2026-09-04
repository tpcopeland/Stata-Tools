* =============================================================================
* test_iivw_stacked.do - the two-step (stacked) influence-function sandwich
* =============================================================================
* iivw_fit, vce(stacked) reports the variance both source papers derive -- the
* one that carries the uncertainty from having ESTIMATED the weights -- instead
* of the fixed-weight sandwich that treats them as known. Getting it wrong
* produces a positive-definite matrix full of plausible standard errors, so the
* cases below are chosen to have a right answer that is knowable independently
* of the implementation.
*
* Three of them are exact identities that hold to machine precision. They are
* the ones that would catch a sign error, a transposed cross-derivative, or a
* mis-scaled information matrix -- none of which a coverage-style check has the
* power to see, because the correction is small in the mean for this estimator
* (se_recovery.md sec 6: the fixed sandwich and the refit bootstrap agree to
* 0.06% on the FIPTIW gate DGP).
*
* Cases:
*   S1  stcox e(V) + per-subject scores reproduce vce(cluster id)  [the input]
*   S2  logit e(V) + scores reproduce vce(robust)                  [the input]
*   S3  the helper's own FIXED sandwich reproduces glm vce(cluster) [the bread]
*   S4  zeroing the nuisance derivative collapses stacked onto fixed [the term]
*   S5  the correction is NOT zero on a real fit                   [it does work]
*   S6  poisson/log and binomial/logit breads reproduce glm too    [the families]
*   S7  vce(stacked) without iivw_weight, scores errors            [fail closed]
*   S8  scores + trimming is refused                               [fail closed]
*   S9  non-canonical link is refused                              [scope]
*   S10 unweighted, model(mixed) and collect are refused           [scope]
*   S11 a rerun WITHOUT scores clears the stale columns            [no stale state]
*   S12 row order does not change the answer                       [no hidden sort]
*   S13 e() stamps are present and say uncleared                   [the contract]
*   S14 the gamma derivative EQUALS -(Z - weighted mean Z)          [the formula]
*   S15 assembled hand fixture matches the full stacked covariance  [the oracle]
* =============================================================================

clear all
version 16.0
set varabbrev off

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_stacked.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

local test_count = 15
local pass_count = 0
local fail_count = 0
local failed_tests ""

* -----------------------------------------------------------------------------
* A reusable irregular-visit panel with a confounded binary treatment.
* -----------------------------------------------------------------------------
capture program drop mkpanel
program define mkpanel
    syntax , NSub(integer) Seed(integer)
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double k1 = rnormal()
    gen double z1 = rnormal()
    gen byte a = runiform() < invlogit(0.8*k1)
    expand 6
    bysort id: gen int j = _n
    gen double t = j
    gen double y = 1 + 0.5*a + 0.4*z1 + 0.3*k1 + 0.1*t + rnormal()
    gen byte ybin = runiform() < invlogit(-0.2 + 0.5*a + 0.3*z1)
    gen int ycnt = rpoisson(exp(0.1 + 0.3*a + 0.2*z1))
    gen double keeppr = invlogit(0.4 + 0.9*z1 - 0.3*a)
    drop if runiform() > keeppr & j > 1
    drop keeppr
    sort id t
end

**# S1 -- the Cox stage inputs are what the sandwich needs them to be

* A_gamma^-1 is taken as the UNROBUST stcox e(V) and s_gamma_i as the subject sum
* of predict, scores. If that pairing is right then
*   (m/(m-1)) * e(V) * sum_i s_i s_i' * e(V)
* must reproduce stcox, vce(cluster id)'s own e(V). Nothing else about the
* implementation is involved, so a failure here localizes to the inputs.
mkpanel, nsub(150) seed(4711)
quietly gen double _start = t - 1
quietly gen byte _ev = 1
quietly stset t, enter(time _start) failure(_ev) id(id) exit(time .)
quietly stcox z1 a, efron
tempname Ainv Vman Vrob
matrix `Ainv' = e(V)
quietly predict double _sc*, scores
quietly egen double _s1 = total(_sc1), by(id)
quietly egen double _s2 = total(_sc2), by(id)
quietly egen byte _tag = tag(id)
preserve
quietly keep if _tag == 1
mkmat _s1 _s2, matrix(S)
local m = _N
restore
matrix `Vman' = `Ainv' * (S' * S) * `Ainv' * (`m'/(`m'-1))
quietly stcox z1 a, efron vce(cluster id)
matrix `Vrob' = e(V)
local d1 = mreldif(`Vman', `Vrob')
display as text "S1: mreldif(reconstructed, stcox vce(cluster)) = " %12.3e `d1'
if `d1' < 1e-10 {
    local ++pass_count
    display "PASS S1: the Cox information and score inputs are exact"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S1"
    display "FAIL S1: the Cox stage inputs do not reproduce the robust VCE"
}

**# S2 -- the logit stage inputs

mkpanel, nsub(400) seed(4712)
quietly egen byte _tag2 = tag(id)
preserve
quietly keep if _tag2 == 1
quietly logit a k1
tempname AinvL VmanL VrobL
matrix `AinvL' = e(V)
quietly predict double _sc0, score
quietly gen double _a1 = _sc0 * k1
quietly gen double _a2 = _sc0
mkmat _a1 _a2, matrix(SL)
local nl = _N
matrix `VmanL' = `AinvL' * (SL' * SL) * `AinvL' * (`nl'/(`nl'-1))
quietly logit a k1, vce(robust)
matrix `VrobL' = e(V)
local d2 = mreldif(`VmanL', `VrobL')
restore
display as text "S2: mreldif(reconstructed, logit vce(robust)) = " %12.3e `d2'
if `d2' < 1e-10 {
    local ++pass_count
    display "PASS S2: the logit information and score inputs are exact"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S2"
    display "FAIL S2: the logit stage inputs do not reproduce the robust VCE"
}

**# S3 -- the bread, via the helper's own fixed sandwich

* iivw_fit refuses to post the stacked matrix unless the helper's FIXED sandwich
* reproduces glm's vce(cluster) e(V). e(iivw_stacked_selfcheck) is that
* comparison, so asserting on it tests the gate as well as the bread.
mkpanel, nsub(200) seed(4713)
quietly iivw_weight, id(id) time(t) visit_cov(z1) treat(a) treat_cov(k1) ///
    wtype(fiptiw) maxfu(7) scores nolog

* Verify r(score_terms) and r(n_score) are populated by the scores option
assert "`r(score_terms)'" != ""
assert !missing(r(n_score))
assert r(n_score) > 0

quietly iivw_fit y a z1, timespec(linear) vce(stacked)
local sc = e(iivw_stacked_selfcheck)
display as text "S3: selfcheck (fixed sandwich vs glm e(V)) = " %12.3e `sc'
if `sc' < 1e-10 & !missing(`sc') {
    local ++pass_count
    display "PASS S3: the analytic bread reproduces glm's cluster sandwich"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S3"
    display "FAIL S3: the bread does not reproduce glm's cluster sandwich"
}

**# S4 -- zeroing the derivative must collapse stacked onto fixed

* The correction enters only through G = sum_j w_j (y-mu) x_j (dlog w/dtheta)'.
* Set every dlog w/dtheta to 0 and G is the zero matrix, so the stacked variance
* must equal the fixed one EXACTLY -- not approximately. This is the strongest
* available statement that the correction is the only thing that differs, and it
* would fail if any other quantity had been changed along the way.
tempname Vstk0 Vfix0
quietly iivw_fit y a z1, timespec(linear) vce(fixed)
matrix `Vfix0' = e(V)
local nterm : word count `: char _dta[_iivw_score_terms]'
preserve
forvalues q = 1/`nterm' {
    quietly replace _iivw_nd`q' = 0
}
quietly iivw_fit y a z1, timespec(linear) vce(stacked)
matrix `Vstk0' = e(V)
restore
local d4 = mreldif(`Vstk0', `Vfix0')
display as text "S4: mreldif(stacked with dlogw=0, fixed) = " %12.3e `d4'
if `d4' < 1e-12 {
    local ++pass_count
    display "PASS S4: a zero derivative collapses stacked onto fixed exactly"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S4"
    display "FAIL S4: stacked and fixed differ even with a zero correction"
}

**# S5 -- the correction is not silently zero

* S4 proves the correction CAN be switched off. This proves it is switched ON in
* the ordinary case. Without it, a bug that dropped the term entirely would pass
* every other case in this file.
quietly iivw_fit y a z1, timespec(linear) vce(stacked)
tempname VstkR
matrix `VstkR' = e(V)
local d5 = mreldif(`VstkR', `Vfix0')
display as text "S5: mreldif(stacked, fixed) on a real fit = " %12.3e `d5'
if `d5' > 1e-12 {
    local ++pass_count
    display "PASS S5: the weight-estimation term is actually applied"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S5"
    display "FAIL S5: stacked is identical to fixed -- the term was dropped"
}

**# S6 -- the bread is right for the other canonical families

* varfunc() picks v(mu) per family. A wrong pick still yields a plausible SE, so
* each family is checked through the same selfcheck gate S3 uses.
local fam_ok = 1
foreach spec in "ycnt poisson" "ybin binomial" {
    local dv : word 1 of `spec'
    local fm : word 2 of `spec'
    capture quietly iivw_fit `dv' a z1, timespec(linear) family(`fm') ///
        vce(stacked)
    if _rc {
        display as error "S6: `fm' fit failed with rc=" _rc
        local fam_ok = 0
        continue
    }
    local scf = e(iivw_stacked_selfcheck)
    display as text "S6: `fm' selfcheck = " %12.3e `scf'
    if `scf' >= 1e-10 | missing(`scf') local fam_ok = 0
}
if `fam_ok' {
    local ++pass_count
    display "PASS S6: poisson/log and binomial/logit breads reproduce glm"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S6"
    display "FAIL S6: a canonical-family bread does not reproduce glm"
}

**# S7 -- weights built without scores must refuse, not approximate

mkpanel, nsub(150) seed(4714)
quietly iivw_weight, id(id) time(t) visit_cov(z1) wtype(iivw) maxfu(7) nolog
capture quietly iivw_fit y z1, timespec(linear) vce(stacked)
local rc7 = _rc
display as text "S7: rc without scores = `rc7'"
if `rc7' == 198 {
    local ++pass_count
    display "PASS S7: vce(stacked) refuses weights that carry no scores"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S7"
    display "FAIL S7: expected rc 198, got `rc7'"
}

**# S8 -- trimming and scores are incompatible and must say so

* A clipped weight has zero derivative on the clipped rows and the cutpoint is
* itself an estimated quantile, so the delta method does not apply. Emitting
* derivative columns anyway would be silently wrong on exactly the rows the
* trimming was for.
capture quietly iivw_weight, id(id) time(t) visit_cov(z1) wtype(iivw) ///
    maxfu(7) truncvisit(1 99) scores nolog
local rc8 = _rc
display as text "S8: rc for scores + truncvisit() = `rc8'"
if `rc8' == 198 {
    local ++pass_count
    display "PASS S8: scores refuses a trimmed weight"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S8"
    display "FAIL S8: expected rc 198, got `rc8'"
}

**# S9 -- non-canonical links are out of scope and must be refused

mkpanel, nsub(150) seed(4715)
quietly iivw_weight, id(id) time(t) visit_cov(z1) wtype(iivw) maxfu(7) ///
    scores nolog
capture quietly iivw_fit ybin z1, timespec(linear) family(binomial) ///
    link(probit) vce(stacked)
local rc9 = _rc
display as text "S9: rc for link(probit) = `rc9'"
if `rc9' == 198 {
    local ++pass_count
    display "PASS S9: a non-canonical link is refused"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S9"
    display "FAIL S9: expected rc 198, got `rc9'"
}

**# S10 -- unweighted and model(mixed) are refused

capture quietly iivw_fit y z1, timespec(linear) unweighted id(id) time(t) ///
    vce(stacked)
local rc10a = _rc
capture quietly iivw_fit y z1, timespec(linear) model(mixed) ///
    experimentalmixed vce(stacked)
local rc10b = _rc
* collect would freeze the fitter's own table -- the fixed-weight SEs -- while
* e(V) holds the stacked ones. Two different numbers under one label.
capture quietly iivw_fit y z1, timespec(linear) vce(stacked) collect
local rc10c = _rc
display as text "S10: unweighted rc=`rc10a'  mixed rc=`rc10b'  collect rc=`rc10c'"
if `rc10a' == 198 & `rc10b' == 198 & `rc10c' == 198 {
    local ++pass_count
    display "PASS S10: all three out-of-scope combinations are refused"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S10"
    display "FAIL S10: expected rc 198 for all three, got `rc10a', `rc10b', `rc10c'"
}

**# S11 -- a rerun without scores must clear the stale columns

* Stale derivative columns describing a weight that no longer exists are the
* dangerous residue here: vce(stacked) would read them and build a sandwich for
* the previous weighting. The contract characteristic must be cleared with them,
* so the refusal in S7 is what a later fit gets.
quietly iivw_weight, id(id) time(t) visit_cov(z1) wtype(iivw) maxfu(7) ///
    replace nolog
local terms_after : char _dta[_iivw_score_terms]
capture confirm variable _iivw_nd1
local nd_gone = _rc
capture confirm variable _iivw_ns1
local ns_gone = _rc
display as text "S11: terms=[`terms_after'] nd rc=`nd_gone' ns rc=`ns_gone'"
if "`terms_after'" == "" & `nd_gone' != 0 & `ns_gone' != 0 {
    local ++pass_count
    display "PASS S11: a rerun without scores clears columns and contract"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S11"
    display "FAIL S11: stale score state survived a rerun"
}

**# S12 -- row order must not change the variance

* The helper builds its own cluster index rather than sorting, precisely so the
* caller's row order survives. If it ever reverts to a -sort-, the accumulation
* is still correct but iivw_fit's e(sample) and display are not -- and a shuffle
* test is the only thing that would notice.
mkpanel, nsub(180) seed(4716)
quietly iivw_weight, id(id) time(t) visit_cov(z1) treat(a) treat_cov(k1) ///
    wtype(fiptiw) maxfu(7) scores nolog
quietly iivw_fit y a z1, timespec(linear) vce(stacked)
tempname Vord
matrix `Vord' = e(V)
set seed 8899
quietly gen double _shuf = runiform()
sort _shuf
quietly iivw_fit y a z1, timespec(linear) vce(stacked)
tempname Vshuf
matrix `Vshuf' = e(V)
quietly drop _shuf
local d12 = mreldif(`Vord', `Vshuf')
display as text "S12: mreldif(sorted, shuffled) = " %12.3e `d12'
if `d12' < 1e-10 {
    local ++pass_count
    display "PASS S12: row order does not change the stacked variance"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S12"
    display "FAIL S12: the stacked variance depends on row order"
}

**# S13 -- the e() contract, including the uncleared stamp

* The stamp is the whole reason this variance may ship at all: it is derived, it
* is not calibrated, and e(iivw_inference_status) has to keep saying so. A
* status that silently became cleared would claim a coverage result for a
* source manifest the package has not run.
quietly iivw_fit y a z1, timespec(linear) vce(stacked)
local st_status "`e(iivw_inference_status)'"
local st_vce    "`e(vce)'"
local st_uvce   "`e(iivw_vce)'"
local st_terms  "`e(iivw_stacked_terms)'"
local st_nc     = e(iivw_stacked_nclust)
display as text "S13: status=`st_status' vce=`st_vce' iivw_vce=`st_uvce'"
display as text "     terms=[`st_terms'] nclust=`st_nc'"
if "`st_status'" == "uncleared-stacked-analytic" & "`st_vce'" == "stacked" ///
    & "`st_uvce'" == "stacked" & "`st_terms'" != "" & `st_nc' > 0 {
    local ++pass_count
    display "PASS S13: the e() contract is complete and stamped uncleared"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S13"
    display "FAIL S13: the e() contract is incomplete or mis-stamped"
}

**# S14 -- the gamma derivative carries the mean-1 renormalization term

* The single most consequential line of the derivation, and the one neither
* source paper states. The papers differentiate the bare rate ratio and get
* -Z_j. This package divides the IIW component by its mean over the modeled
* events, and that divisor is itself a function of gamma, so the correct
* derivative is
*
*     d log iw_j / d gamma = -(Z_j - Zbar_omega)
*
* the deviation of Z_j from the WEIGHT-WEIGHTED mean of Z over the modeled
* events. Omitting the second term is not a rescaling -- it is a different
* vector -- and no other case in this file would notice, because S4 only zeroes
* the column and S5 only checks it is nonzero. This one reconstructs the
* quantity independently from the shipped weight and the covariate, and asserts
* equality.
*
* Study-entry rows are pinned at exactly 1 by the weighting, are not functions
* of gamma, and must carry derivative 0. They are checked separately rather
* than excluded, because "0 there" is part of the contract.
mkpanel, nsub(220) seed(4717)
quietly iivw_weight, id(id) time(t) visit_cov(z1) wtype(iivw) maxfu(7) ///
    scores nolog
local vterms : char _dta[_iivw_score_terms]
local nv : word count `vterms'
display as text "S14: score terms = [`vterms']"

* The modeled events are the rows the fitted component reached. A study-entry
* row took the hard-coded 1 and is identified here by its zero derivative, so
* the reconstruction is done on the complement.
tempvar modeled
quietly gen byte `modeled' = (_iivw_nd1 != 0) & !missing(_iivw_nd1)
quietly count if `modeled'
local n_modeled = r(N)
quietly count if !`modeled' & !missing(_iivw_weight)
local n_entry = r(N)

local s14_ok = 1
local s14_worst = 0
forvalues q = 1/`nv' {
    local term : word `q' of `vterms'
    local zv = subinstr("`term'", "g:", "", 1)
    quietly summarize `zv' [aw=_iivw_iw] if `modeled', meanonly
    local zbar = r(mean)
    tempvar want dev
    quietly gen double `want' = -(`zv' - `zbar') if `modeled'
    quietly gen double `dev' = abs(_iivw_nd`q' - `want') if `modeled'
    quietly summarize `dev', meanonly
    local wmax = r(max)
    if `wmax' > `s14_worst' local s14_worst = `wmax'
    if `wmax' > 1e-10 local s14_ok = 0
    drop `want' `dev'
}

* The reconstruction must not be vacuous: if the weighted mean of Z happened to
* be 0 the term would be invisible. Assert it is materially nonzero.
quietly summarize z1 [aw=_iivw_iw] if `modeled', meanonly
local zbar_used = abs(r(mean))
quietly summarize z1 if `modeled', meanonly
local zbar_plain = abs(r(mean))

display as text "S14: modeled rows `n_modeled', entry rows `n_entry'"
display as text "     worst |nd - reconstructed| = " %12.3e `s14_worst'
display as text "     |weighted mean Z| = " %8.5f `zbar_used' ///
    "  (unweighted " %8.5f `zbar_plain' ")"
if `s14_ok' & `n_modeled' > 0 & `zbar_used' > 1e-4 {
    local ++pass_count
    display "PASS S14: the gamma derivative carries the renormalization term"
}
else if `zbar_used' <= 1e-4 {
    local ++fail_count
    local failed_tests "`failed_tests' S14"
    display "FAIL S14: the weighted mean of Z is ~0, so the check is vacuous"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S14"
    display "FAIL S14: the gamma derivative does not match -(Z - weighted mean)"
}

**# S15 -- assembled full covariance oracle, with mutation calibration

* This fixture is intentionally independent of every fitted-model route above.
* Its raw rows were chosen so the four ingredients can be checked by hand:
*
*   D = [19.95 8.65 \ 8.65 7.05]
*   G = [.7925 .193125 \ .235 -.173125]
*   U = [-1 0 \ 2.875 .5 \ .6375 -.2875]
*   S = [.5 -.25 \ -.4 .6 \ .3 .2],  A^-1 = [1.2 .1 \ .1 .8]
*
* The oracle assembles Psi = U + S A^-T G' and the M/(M-1) sandwich
* directly from those matrices. It shares no package fitting, score-building,
* or Mata accumulation path with _iivw_stacked_vce.
clear
input byte id double(x wt err nd1 nd2 ns1 ns2)
1  0    1     1      .2  -.3    .5  -.25
1  1    2    -.5    -.1   .25   .5  -.25
2  2    1.5   .75    .3   .1   -.4   .6
2 -1     .5 -1.25    .4  -.2   -.4   .6
3  3    1.25  .25   -.2   .35   .3   .2
3   .5   .8  -.75    .15 -.05   .3   .2
end
gen double mu = 2 + .4*x
gen double y = mu + err
gen double _iivw_nd1 = nd1
gen double _iivw_nd2 = nd2
gen double _iivw_ns1 = ns1
gen double _iivw_ns2 = ns2
char _dta[_iivw_prefix] "_iivw_"

tempname Dh Gh Uh Sh Ah Dih Ch Psih Vhand Vgot Vfhand Vfgot ///
    Psiminus Vminus Psitrans Vtrans Psiscale Vscale Ggot
matrix `Dh' = (19.95, 8.65 \ 8.65, 7.05)
matrix `Gh' = (.7925, .193125 \ .235, -.173125)
matrix `Uh' = (-1, 0 \ 2.875, .5 \ .6375, -.2875)
matrix `Sh' = (.5, -.25 \ -.4, .6 \ .3, .2)
matrix `Ah' = (1.2, .1 \ .1, .8)
matrix `Dih' = invsym(`Dh')
matrix `Ch' = `Sh' * `Ah'' * `Gh''
matrix `Psih' = `Uh' + `Ch'
matrix `Vhand' = `Dih' * (`Psih'' * `Psih') * (3/2) * `Dih'
matrix `Vfhand' = `Dih' * (`Uh'' * `Uh') * (3/2) * `Dih'

capture noisily _iivw_stacked_vce x, depvar(y) mu(mu) wtvar(wt) ///
    cluster(id) varfunc(constant) scoreterms("q1 q2") ///
    ainv("1.2 .1 .1 .8")
local rc15 = _rc
local d15 = .
local df15 = .
local dg15 = .
if `rc15' == 0 {
    matrix `Vgot' = r(V_stacked)
    matrix `Vfgot' = r(V_fixed)
    matrix `Ggot' = r(G)
    local d15 = mreldif(`Vgot', `Vhand')
    local df15 = mreldif(`Vfgot', `Vfhand')
    local dg15 = mreldif(`Ggot', `Gh')
}

* Three plausible transcription defects must be materially distinguishable:
* the Buzkova sign, a transposed cross-derivative, and an erroneous 1/M on the
* nuisance correction. This calibrates the oracle against the exact mistakes
* it is meant to catch, rather than merely observing that one fixture passes.
matrix `Psiminus' = `Uh' - `Ch'
matrix `Vminus' = `Dih' * (`Psiminus'' * `Psiminus') * (3/2) * `Dih'
matrix `Psitrans' = `Uh' + `Sh' * `Gh' * `Ah''
matrix `Vtrans' = `Dih' * (`Psitrans'' * `Psitrans') * (3/2) * `Dih'
matrix `Psiscale' = `Uh' + `Ch'/3
matrix `Vscale' = `Dih' * (`Psiscale'' * `Psiscale') * (3/2) * `Dih'

display as text "S15: full oracle mreldif=" %12.3e `d15' ///
    " fixed=" %12.3e `df15' " G=" %12.3e `dg15'
if `rc15' == 0 & !missing(`d15', `df15', `dg15') & ///
        `d15' < 1e-12 & `df15' < 1e-12 & `dg15' < 1e-12 & ///
        mreldif(`Vhand', `Vminus') > 1e-4 & ///
        mreldif(`Vhand', `Vtrans') > 1e-4 & ///
        mreldif(`Vhand', `Vscale') > 1e-4 {
    local ++pass_count
    display "PASS S15: assembled full covariance matches and detects three mutations"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' S15"
    display "FAIL S15: assembled covariance oracle or mutation calibration failed"
}

**# SUMMARY

iivw_qa_summary, name(test_iivw_stacked) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed_tests'")
