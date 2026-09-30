* test_fixture_reader_refusals.do -- early public boundaries and completed findings
* Author: Timothy P Copeland, Karolinska Institutet
* guard: successful numeric public controls live in test_fixture_public.do; this suite pins caller boundaries.
version 16.0
clear all
set more off
set varabbrev on
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
do "`qa_dir'/_install_msm_isolated.do" "`qa_dir'/.."
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
capture program drop _fx_caller_r
program define _fx_caller_r, rclass
    tempname payload
    matrix `payload'=(1,2\3,4)
    return matrix payload=`payload'
    return scalar fxscalar=17/120
    mata: st_local("bait", "literal " + char(36) + "bait " + char(96) + "tick" + char(39) + char(34))
    return local fxbait `"`macval(bait)'"'
end
local test_count 0
local pass_count 0
local fail_count 0
foreach route in msm prepare validate weight diagnose diagtab fit predict plot table report protocol sensitivity {
 foreach order in friendly unsorted {
  foreach context in empty full {
  local ++test_count
  capture noisily {
   local perturb ""
   if "`order'"=="unsorted" local perturb "perturb(unsorted)"
   if "`route'"=="prepare" local perturb "perturb(dup_key)"
   * expect: REFUSED with full caller results and exact tied/unsorted order preserved
   qa_fx_a3_seq, clear n(500) seed(9197) `perturb'
   set seed 9198
   generate double fx_shuffle=runiform()
   sort fx_shuffle
   drop fx_shuffle
   if "`order'"=="friendly" sort id, stable
   quietly regress l_t l0 a
   local command "msm_`route'"
   local options ""
   local cause "data has not been prepared"
   local expected_rc 198
   if "`route'"=="msm" {
    local command "msm"
    local options "list detail"
    local cause "specify at most one of list"
   }
   if "`route'"=="prepare" {
    local options "id(id) period(period) treatment(a) outcome(y) covariates(l_t)"
    local expected_rc 198
    local cause "duplicate (id, period) combinations"
   }
   if "`route'"=="weight" local options "treat_d_cov(l_t) nolog"
   if "`route'"=="diagtab" {
    local options `"frame(fx_absent) xlsx("fx_absent.xlsx")"'
    local expected_rc 111
    local cause "frame fx_absent not found"
   }
   if "`route'"=="fit" local options "nolog"
   if "`route'"=="predict" {
    local options "times(1 3) samples(10) seed(9199)"
    local cause "no model has been fitted"
   }
   if "`route'"=="plot" local options "type(weights)"
   if "`route'"=="table" {
    local options `"xlsx("fx_absent.xlsx") coefficients replace"'
    local cause "coefficients table requires msm_fit"
   }
   if "`route'"=="protocol" {
    local options `"population("adults") treatment("a") confounders("l") outcome("y") causal_contrast("all versus none") weight_spec("IPTW") analysis("pooled logit") format(bogus)"'
    local cause "format() must be"
   }
   if "`route'"=="sensitivity" {
    local options "evalue"
    local cause "no model has been fitted"
   }
   tempfile refusal
   capture log close fxref
   log using "`refusal'", text name(fxref)
   if "`context'"=="empty" return clear
   else _fx_caller_r
   qa_state_snapshot, tag(readerref) rreturn predict(xb stdp)
   capture noisily `command', `options'
   local command_rc=_rc
   display "REFUSAL_BOUNDARY route=`route' order=`order' r=`context' rc=`command_rc'"
   qa_state_compare, tag(readerref)
   log close fxref
   assert `command_rc'==`expected_rc'
   python: assert __import__('sfi').Macro.getLocal('cause') in open(__import__('sfi').Macro.getLocal('refusal'),encoding='utf-8').read()
   python: assert not __import__('pathlib').Path('fx_absent.xlsx').exists()
  }
  if !_rc {
   local ++pass_count
   display "PASS: `route'/`order'/`context' strict refusal"
  }
  else {
   local ++fail_count
   display "FAIL: `route'/`order'/`context' strict refusal (rc=`=_rc')"
   capture log close fxref
  }
  }
 }
}
**# Completed validation findings: published results are documented even on strict198
foreach mode in ordinary strict {
    local ++test_count
    capture noisily {
        qa_fx_a3_seq, clear n(500) seed(9197)
        quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t)
        * Named missing-covariate adapter retains all rows and changes one required value.
        replace l_t=. in 1
        sort id, stable
        quietly regress l_t l0 a
        tempfile findings
        capture log close fxref
        log using "`findings'", text name(fxref)
        _fx_caller_r
        qa_state_snapshot, tag(finding) rreturn predict(xb stdp)
        local option ""
        if "`mode'"=="strict" local option "strict"
        * expect: DEGRADED-DECLARED through exact completed validation findings
        capture noisily msm_validate, `option'
        local finding_rc=_rc
        assert !missing(r(n_checks),r(n_errors),r(n_warnings))
        assert r(n_checks)==10
        if "`mode'"=="strict" {
            assert `finding_rc'==198
            assert r(n_errors)==1 & r(n_warnings)==0
            assert "`r(validation)'"=="failed"
        }
        else {
            assert `finding_rc'==0
            assert r(n_errors)==0 & r(n_warnings)==1
            assert "`r(validation)'"=="passed"
        }
        local scalars : r(scalars)
        local macros : r(macros)
        local matrices : r(matrices)
        assert "`scalars'"=="n_warnings n_errors n_checks"
        assert "`macros'"=="validation"
        assert "`matrices'"==""
        * r() is the documented findings; every other fingerprint category remains strict.
        qa_state_compare, tag(finding) allow(r)
        log close fxref
        python: assert 'missing values found' in open(__import__('sfi').Macro.getLocal('findings'),encoding='utf-8').read()
    }
    if !_rc {
        local ++pass_count
        display "PASS: `mode' completed validation findings"
    }
    else {
        local ++fail_count
        display "FAIL: `mode' completed validation findings (rc=`=_rc')"
        capture log close fxref
    }
}
do "`qa_dir'/_record_qa_result.do" test_fixture_reader_refusals `test_count' `pass_count' `fail_count' 0
display "RESULT: test_fixture_reader_refusals tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count'>0 exit 1
