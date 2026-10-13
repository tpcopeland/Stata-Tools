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
foreach route in msm prepare weight diagnose fit predict validate plot table report protocol diagtab sensitivity {
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
   if "`route'"=="fit" local options "nolog"
   if "`route'"=="predict" {
    local options "times(1 3) samples(10) seed(9199)"
    local cause "no model has been fitted"
   }
   * msm 2.0.0 stubs: refuse with 199 and the replacement, touching nothing.
   if inlist("`route'","validate","plot","table","report","protocol","diagtab","sensitivity") {
    local options "anything"
    local expected_rc 199
    local cause "was removed in msm 2.0.0"
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
do "`qa_dir'/_record_qa_result.do" test_fixture_reader_refusals `test_count' `pass_count' `fail_count' 0
display "RESULT: test_fixture_reader_refusals tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count'>0 exit 1
