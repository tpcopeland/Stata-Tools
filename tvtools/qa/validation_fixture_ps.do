*! validation_fixture_ps.do — finite-cell propensity and hostile input contracts
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "validation_fixture_ps.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_fx_a1.do"
do "`qa_dir'/_qa_state.do"
* Finite fitted saturated probabilities, not the stochastic population PS.
* Oracle computes each complete analysis cell's observed treated fraction.
capture program drop _fx_tvps
program define _fx_tvps, rclass
    version 16.0
    args op
    tempfile input
    if "`op'"=="separate" {
        * The fixture separates outcome y, whereas tvweight models treatment.
        * Feed the actual separated response as exposure, rather than credit
        * an unused outcome perturbation. This is a declared treatment adapter.
        replace a=y
        assert a==0 if xcat==3
        quietly count if a==1 & xcat!=3
        assert r(N)>0
    }
    gen byte sample=1
    if "`op'"=="base_absent" replace sample=insample
    egen long cell=group(x1 x2 xcat)
    replace sample=0 if missing(cell)
    gen double sampled_a=cond(sample,a,.)
    bysort cell: egen double probability=mean(sampled_a)
    replace probability=. if !sample
    local covariates "i.cell"
    if "`op'"=="collinear" local covariates "i.cell x3 x4"
    if "`op'"=="miss_all_column" local covariates "x1 x2 i.xcat"
    if "`op'"=="scale_shift" local covariates "i.cell x1"
    save `input'
    local tests=0
    local pass=0
    local fail=0
    foreach target in iptw ato matching stabilized {
        local ++tests
        capture noisily {
            use `input', clear
            local option "wtype(`target')"
            if "`target'"=="stabilized" local option "stabilized"
            qa_state_snapshot, tag(tvps)
            if inlist("`op'","near_positivity","miss_all_column","separate") {
                tempfile cause_log
                capture log close ps_cause
                log using `cause_log', name(ps_cause) text replace nomsg
                capture noisily tvweight a if sample, covariates(`covariates') generate(got) denominator(ps) `option' nolog
                local call_rc=_rc
                log close ps_cause
                local named_cause=0
                local expected_cause=cond("`op'"=="miss_all_column","no valid observations","weights are undefined at the probability boundary")
                tempname cause_handle
                file open `cause_handle' using `cause_log', read text
                file read `cause_handle' cause_line
                while r(eof)==0 {
                    if strpos(`"`macval(cause_line)'"',"`expected_cause'") local named_cause=1
                    file read `cause_handle' cause_line
                }
                file close `cause_handle'
                assert `named_cause'==1
                * Missing whole covariate cannot form a fit; a saturated
                * all-treated cell has undefined boundary probabilities.
                assert `call_rc'==cond("`op'"=="miss_all_column",2000,498)
                if "`op'"=="miss_all_column" assert missing(x2) & sample==0
                if "`op'"=="near_positivity" {
                    quietly count if probability==1 & sample
                    assert r(N)==600
                    assert a==1 if probability==1 & sample
                }
                qa_state_compare, tag(tvps)
            }
            else {
                gen double want=cond(a,1/probability,1/(1-probability)) if sample
                if "`target'"=="ato" replace want=cond(a,1-probability,probability) if sample
                if "`target'"=="matching" replace want=min(probability,1-probability)*want if sample
                if "`target'"=="stabilized" {
                    quietly summarize a if sample, meanonly
                    local marginal=r(mean)
                    replace want=cond(a,`marginal',1-`marginal')*want if sample
                }
                * Include the explicit oracle column in the snapshot.
                unab original_columns : _all
                tempname Before
                mata: st_matrix("`Before'",st_data(.,tokens(st_local("original_columns"))))
                qa_state_snapshot, tag(tvps)
                tvweight a if sample, covariates(`covariates') generate(got) denominator(ps) `option' nolog
                unab after_columns : _all
                local ordinal=0
                foreach name of local original_columns {
                    local ++ordinal
                    local observed : word `ordinal' of `after_columns'
                    assert "`name'"=="`observed'"
                }
                mata: assert(all(st_data(.,tokens(st_local("original_columns"))):==st_matrix("`Before'")))
                qa_state_compare, tag(tvps) allow(data)
                assert !missing(got,ps,want,probability) if sample
                assert missing(got) & missing(ps) if !sample
                gen double err=max(reldif(got,want),reldif(ps,probability)) if sample
                quietly summarize err, meanonly
                di "ORACLE tvweight `op' `target' max relative error=" r(max)
                assert r(max)<1e-5
                * Independent saturated-cell Newton decrement: each observed
                * Bernoulli cell has score n*(p_emp-p_fit) and information
                * n*p_fit*(1-p_fit). Summing per-row yields g*inv(H)*g'.
                * Official maximize.sthlp documents nrtolerance(1e-5).
                gen double decrement=(probability-ps)^2/(ps*(1-ps)) if sample
                quietly summarize decrement, meanonly
                di "ORACLE tvweight `op' `target' scaled gradient=" r(sum)
                assert r(sum)<1e-5
            }
        }
        local call_rc=_rc
        if `call_rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL tvweight PS `op' `target' rc=`call_rc'"
        }
    }
    return scalar qa_tests=`tests'
    return scalar qa_pass=`pass'
    return scalar qa_fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a1_logit, clear tier(unit) n(3600) seed(931)
_fx_tvps friendly
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
qa_fx_a1_logit, clear tier(unit) n(3600) seed(931) perturb(collinear)
_fx_tvps collinear
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
qa_fx_a1_logit, clear tier(unit) n(3600) seed(931) perturb(single_level)
_fx_tvps single_level
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
qa_fx_a1_logit, clear tier(unit) n(3600) seed(931) perturb(base_absent)
_fx_tvps base_absent
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
qa_fx_a1_logit, clear tier(unit) n(3600) seed(931) perturb(miss_subgroup)
_fx_tvps miss_subgroup
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
qa_fx_a1_logit, clear tier(unit) n(3600) seed(931) perturb(miss_all_column)
_fx_tvps miss_all_column
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
qa_fx_a1_logit, clear tier(unit) n(3600) seed(931) perturb(near_positivity)
_fx_tvps near_positivity
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
qa_fx_a1_logit, clear tier(unit) n(3600) seed(931) perturb(scale_shift)
_fx_tvps scale_shift
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
qa_fx_a1_logit, clear tier(unit) n(3600) seed(931) perturb(separate)
_fx_tvps separate
local tests=`tests'+r(qa_tests)
local pass=`pass'+r(qa_pass)
local fail=`fail'+r(qa_fail)
di "RESULT: validation_fixture_ps tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
