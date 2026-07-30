*! test_tvweight_cumprod.do
*! Contract pins for the in-place tvweight cumulative-product path (1.9.1).
*!
*! 1.9.0 built the three within-person running products by preserving the data,
*! keeping the estimation sample, saving it to a tempfile, restoring, and
*! merging the result back. 1.9.1 builds them in place through
*! _tvweight_cumprod.ado. Nothing a user observes may change, so this suite
*! pins the properties the refactor could plausibly break rather than only
*! re-checking that weights exist.
*!
*! Axes probed, and why each one is here:
*!   C1-C4   the running product itself, against hand-computed known answers.
*!           The released algorithm is NOT the oracle: an oracle that shares
*!           the implementation cannot catch a shared defect.
*!   C5-C6   the excluded-middle-period contract. The 1.9.0 block made
*!           touse==1 rows physically contiguous by dropping the others; in
*!           place, that contiguity has to be manufactured with a sort key.
*!           Getting it wrong restarts a person's product at the gap, which is
*!           a silent bias, not an error.
*!   C7-C9   caller row order and input data survive an in-place sort.
*!   C10-C13 fixed-width string IDs and the helper's own guards.
*!   C14-C17 public cumulative output: values, label, storage type.
*!   C18-C20 cumulative, ipcw(), and both together.
*!   C21-C22 the duplicate-key preflight still fires before any output.
*!   C23     a late failure still rolls back a pre-existing output.
*!   C24     the helper resolves for an installed user.

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvweight_cumprod.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TVW_PASS = 0
global TVW_FAIL = 0
global TVW_FAILED ""
local test_count = 0

display as result "tvtools QA: tvweight cumulative product -- $S_DATE $S_TIME"

* _tvw_check: fold a precomputed 0/1 result into the suite counters.
capture program drop _tvw_check
program define _tvw_check
    args ok label detail
    if `ok' {
        global TVW_PASS = $TVW_PASS + 1
        display as result "  PASS `label'"
    }
    else {
        global TVW_FAIL = $TVW_FAIL + 1
        global TVW_FAILED "$TVW_FAILED `label'"
        display as error "  FAIL `label': `detail'"
    }
end

* Build a deterministic person-period panel whose treatment model converges.
capture program drop _tvw_make_panel
program define _tvw_make_panel
    version 16.0
    args npersons nperiods seed
    clear
    set seed `seed'
    quietly set obs `npersons'
    quietly generate long pid = _n
    quietly generate double frailty = rnormal()
    quietly expand `nperiods'
    quietly bysort pid: generate int period = _n
    quietly generate double age = 50 + frailty * 5 + period
    quietly generate byte sex = mod(pid, 2)
    quietly generate double _xb = -0.3 + 0.25 * frailty + 0.05 * (period - 3)
    quietly generate byte treat = runiform() < invlogit(_xb)
    quietly drop _xb
    * Censoring must vary within every period, or the pooled censoring logit
    * predicts period perfectly, drops those rows, and the run stops at 498
    * before it reaches anything this suite is trying to measure.
    quietly generate byte cens = runiform() < invlogit(-2.2 + 0.15 * frailty)
end


**# ===== C1-C4: known-answer products, helper called directly =====
* Hand-computed, not produced by any tvtools code path. 2, 0.5, 4, and 8 are
* dyadic, so the products are exact in binary and == is the right comparison;
* a tolerance here would hide real drift.
local ++test_count
clear
input int pid int t double w byte insample
1 1 2   1
1 2 0.5 1
1 3 4   1
2 1 0.5 1
2 2 0.5 1
3 1 8   1
end
quietly _tvweight_cumprod w if insample, id(pid) time(t) generate(cp)
quietly generate double want = .
quietly replace want = 2    in 1
quietly replace want = 1    in 2
quietly replace want = 4    in 3
quietly replace want = 0.5  in 4
quietly replace want = 0.25 in 5
quietly replace want = 8    in 6
quietly count if cp != want
local nbad = r(N)
local ok = (`nbad' == 0)
_tvw_check `ok' "C1 running product matches hand-computed answer" ///
    "`nbad' row(s) differ"

local ++test_count
local ok = (cp[2] == 1 & cp[3] == 4)
_tvw_check `ok' "C2 product accumulates rather than resetting per row" ///
    "cp[2]=`=cp[2]' cp[3]=`=cp[3]', expected 1 and 4"

local ++test_count
local dtype : type cp
local ok = ("`dtype'" == "double")
_tvw_check `ok' "C3 product is stored as double" "type is `dtype'"

local ++test_count
local ok = (cp[6] == 8)
_tvw_check `ok' "C4 single-period person gets its own weight" ///
    "cp[6]=`=cp[6]', expected 8"


**# ===== C5-C6: a dropped middle period must not restart the product =====
local ++test_count
clear
input int pid int t double w byte insample
1 1 2 1
1 2 2 1
1 3 9 0
1 4 2 1
end
quietly _tvweight_cumprod w if insample, id(pid) time(t) generate(cp)
local ok = (cp[4] == 8)
_tvw_check `ok' "C5 product continues across an excluded middle period" ///
    "cp[4]=`=cp[4]', expected 8 (2*2*2); 2 would mean the product restarted"

local ++test_count
local ok = missing(cp[3])
_tvw_check `ok' "C6 excluded row keeps a missing product" "cp[3]=`=cp[3]'"


**# ===== C7-C9: caller row order and input data survive the in-place sort =====
local ++test_count
clear
set seed 4711
quietly set obs 40
quietly generate long pid = ceil(_n / 4)
quietly bysort pid: generate int t = _n
quietly generate double w = 0.9 + runiform() / 5
quietly generate byte insample = !(pid == 3 & t == 2)
quietly generate double shuffle = runiform()
sort shuffle
quietly generate long rowid = _n
quietly generate double w_before = w
quietly _tvweight_cumprod w if insample, id(pid) time(t) generate(cp)
quietly count if rowid != _n
local nmoved = r(N)
local ok = (`nmoved' == 0)
_tvw_check `ok' "C7 caller observation order is unchanged" ///
    "`nmoved' row(s) moved"

local ++test_count
quietly count if w != w_before
local nchanged = r(N)
local ok = (`nchanged' == 0)
_tvw_check `ok' "C8 the input variable is not modified" ///
    "`nchanged' row(s) changed"

local ++test_count
quietly generate double cp_unsorted = cp
sort pid t
quietly drop cp
quietly _tvweight_cumprod w if insample, id(pid) time(t) generate(cp)
quietly count if (cp != cp_unsorted) | (missing(cp) != missing(cp_unsorted))
local ndiff = r(N)
local ok = (`ndiff' == 0)
_tvw_check `ok' "C9 result is independent of input row order" ///
    "`ndiff' row(s) differ between shuffled and pre-sorted input"


**# ===== C10-C13: fixed-width string IDs and helper guards =====
local ++test_count
clear
input str8 sid int t double w
"P001" 1 2
"P001" 2 2
"P002" 1 3
"P002" 2 3
end
quietly generate byte insample = 1
quietly _tvweight_cumprod w if insample, id(sid) time(t) generate(cp_str)
quietly egen long nid = group(sid)
quietly _tvweight_cumprod w if insample, id(nid) time(t) generate(cp_num)
quietly count if cp_str != cp_num
local ndiff = r(N)
local ok = (`ndiff' == 0)
_tvw_check `ok' "C10 fixed-width string IDs group as numeric IDs do" ///
    "`ndiff' row(s) differ"

local ++test_count
local ok = (cp_str[2] == 4 & cp_str[4] == 9)
_tvw_check `ok' "C11 string-ID products match hand-computed answers" ///
    "got `=cp_str[2]' and `=cp_str[4]', expected 4 and 9"

local ++test_count
capture _tvweight_cumprod w if insample, id(sid) time(t) generate(cp_str)
local rc_exist = _rc
local ok = (`rc_exist' == 110)
_tvw_check `ok' "C12 an existing output name is refused with r(110)" ///
    "rc=`rc_exist'"

local ++test_count
capture _tvweight_cumprod w if insample, id(nid) time(sid) generate(cp_bad)
local rc_strtime = _rc
capture drop cp_bad
local ok = (`rc_strtime' == 109)
_tvw_check `ok' "C13 a string time() is refused with r(109)" "rc=`rc_strtime'"


**# ===== C14-C17: public cumulative output =====
_tvw_make_panel 60 5 20260729

local ++test_count
quietly tvweight treat, covariates(age sex) id(pid) time(period) ///
    generate(w) cumulative
quietly count if missing(w_cum) | w_cum <= 0
local ninvalid = r(N)
local ok = (`ninvalid' == 0)
_tvw_check `ok' "C14 cumulative produces a positive weight on every row" ///
    "`ninvalid' invalid row(s)"

* The defining recursion, against the fitted per-period weights. C1-C11 carry
* the independent known answers; this pins the public path to the same rule.
local ++test_count
sort pid period
quietly by pid: generate double _recur = w if _n == 1
quietly by pid: replace _recur = _recur[_n-1] * w if _n > 1
quietly generate double _rd = abs(w_cum - _recur)
quietly summarize _rd, meanonly
local maxrd = r(max)
local ok = (`maxrd' == 0)
_tvw_check `ok' ///
    "C15 cumulative equals the within-person running product exactly" ///
    "max abs deviation `maxrd'"
quietly drop _recur _rd

local ++test_count
local vlab : variable label w_cum
local ok = (`"`vlab'"' == "Cumulative iptw weight for treat")
_tvw_check `ok' "C16 cumulative weight keeps its released variable label" ///
    "label is `vlab'"

local ++test_count
local ctype : type w_cum
local ok = ("`ctype'" == "double")
_tvw_check `ok' "C17 cumulative weight is a double" "type is `ctype'"


**# ===== C18-C20: cumulative, ipcw(), and both =====
* w_ipcw is documented as cumulative IPTW x cumulative IPCW. 1.9.1 stops
* building the treatment product twice and reuses cumgenerate() for the left
* factor, so the identity must hold exactly, not to rounding.
local ++test_count
_tvw_make_panel 60 5 20260729
quietly tvweight treat, covariates(age sex) id(pid) time(period) ///
    generate(w) cumulative ipcw(cens)
quietly generate double _combchk = abs(w_ipcw - w_cum * ipcw)
quietly summarize _combchk, meanonly
local maxcomb = r(max)
local ok = (`maxcomb' == 0)
_tvw_check `ok' ///
    "C18 combined weight is exactly cumulative IPTW x cumulative IPCW" ///
    "max abs deviation `maxcomb'"

local ++test_count
_tvw_make_panel 60 5 20260729
quietly tvweight treat, covariates(age sex) id(pid) time(period) ///
    generate(w) ipcw(cens)
capture confirm variable w_cum
local no_cum = (_rc != 0)
quietly count if missing(ipcw) | ipcw <= 0 | missing(w_ipcw) | w_ipcw <= 0
local ninvalid = r(N)
local ok = (`no_cum' & `ninvalid' == 0)
_tvw_check `ok' ///
    "C19 ipcw() alone produces valid weights and no cumulative output" ///
    "cum_absent=`no_cum' invalid_rows=`ninvalid'"

* The censoring product must survive an excluded middle period too.
local ++test_count
_tvw_make_panel 60 5 20260729
quietly replace age = . if pid == 4 & period == 3
quietly tvweight treat, covariates(age sex) id(pid) time(period) ///
    generate(w) cumulative ipcw(cens)
quietly count if pid == 4 & period == 3 & !missing(w_cum)
local gap_blank = (r(N) == 0)
quietly count if pid == 4 & period == 4 & missing(w_cum)
local after_gap_ok = (r(N) == 0)
quietly count if pid == 4 & period == 4 & missing(ipcw)
local cens_after_gap_ok = (r(N) == 0)
local ok = (`gap_blank' & `after_gap_ok' & `cens_after_gap_ok')
_tvw_check `ok' ///
    "C20 a markout-dropped period leaves a gap but does not end either product" ///
    "gap_blank=`gap_blank' iptw_after=`after_gap_ok' ipcw_after=`cens_after_gap_ok'"


**# ===== C21-C22: duplicate-key preflight still fires before any output =====
local ++test_count
_tvw_make_panel 40 4 20260729
quietly replace period = 2 if pid == 5 & period == 3
capture noisily tvweight treat, covariates(age sex) id(pid) time(period) ///
    generate(w) cumulative
local dup_rc = _rc
capture confirm variable w_cum
local no_output = (_rc != 0)
capture confirm variable w
local no_weight = (_rc != 0)
local ok = (`dup_rc' == 459 & `no_output' & `no_weight')
_tvw_check `ok' ///
    "C21 duplicate id-time keys stop with r(459) and write no output" ///
    "rc=`dup_rc' cum_absent=`no_output' weight_absent=`no_weight'"

local ++test_count
_tvw_make_panel 40 4 20260729
quietly expand 2 if pid == 5 & period == 2
quietly replace age = . if pid == 5 & period == 2 & _n == _N
capture noisily tvweight treat, covariates(age sex) id(pid) time(period) ///
    generate(w) cumulative
local outside_rc = _rc
local ok = (`outside_rc' == 0)
_tvw_check `ok' ///
    "C22 duplicate keys outside the estimation sample are not an error" ///
    "rc=`outside_rc'"


**# ===== C23: late failure rolls back a pre-existing output variable =====
* An all-zero censoring indicator passes the 0/1 contract check but the
* censoring logit cannot converge on it, and that fit runs after the
* cumulative product. A pre-existing cumgenerate() must come back byte for
* byte and the new outputs must be gone.
local ++test_count
_tvw_make_panel 60 5 20260729
quietly replace cens = 0
quietly generate double mycum = pid * 1000 + period
quietly generate double mycum_before = mycum
capture noisily tvweight treat, covariates(age sex) id(pid) time(period) ///
    generate(w) cumulative cumgenerate(mycum) replace ipcw(cens)
local late_rc = _rc
capture confirm variable mycum
local restored = (_rc == 0)
local ndiff = .
if `restored' {
    quietly count if mycum != mycum_before
    local ndiff = r(N)
}
capture confirm variable ipcw
local cens_gone = (_rc != 0)
local ok = (`late_rc' != 0 & `restored' & `ndiff' == 0 & `cens_gone')
_tvw_check `ok' ///
    "C23 late failure restores cumgenerate() and removes new outputs" ///
    "rc=`late_rc' restored=`restored' ndiff=`ndiff' cens_gone=`cens_gone'"


**# ===== C24: the helper resolves for an installed user =====
* The suite runs against a sandboxed PLUS install, so which resolves the
* shipped copy rather than a development adopath.
local ++test_count
capture which _tvweight_cumprod
local which_rc = _rc
local ok = (`which_rc' == 0)
_tvw_check `ok' "C24 _tvweight_cumprod resolves from the installed package" ///
    "which returned rc=`which_rc'"


**# ===== C25: an -in- restriction selects the sample the same way -if- does =====
local ++test_count
clear
input int pid int t double w
1 1 2
1 2 2
1 3 2
2 1 3
2 2 3
end
quietly _tvweight_cumprod w in 1/3, id(pid) time(t) generate(cp_in)
local ok = (cp_in[1] == 2 & cp_in[2] == 4 & cp_in[3] == 8 & ///
    missing(cp_in[4]) & missing(cp_in[5]))
_tvw_check `ok' "C25 -in- restricts the product to the selected rows" ///
    "got `=cp_in[3]' at row 3 and `=cp_in[4]' at row 4"


**# ===== C26: overflow to missing, not to a plausible number =====
* The callers screen for missing and non-positive products and stop with 498.
* A log-sum reformulation would return a finite number here instead, which is
* why the helper multiplies directly.
local ++test_count
clear
input int pid int t double w
1 1 1e200
1 2 1e200
end
quietly generate byte insample = 1
quietly _tvweight_cumprod w if insample, id(pid) time(t) generate(cp_of)
local ok = (cp_of[1] == 1e200 & missing(cp_of[2]))
_tvw_check `ok' "C26 an overflowing product becomes missing, not a finite value" ///
    "cp_of[2]=`=cp_of[2]'"


**# ===== C27: stabilized weights =====
local ++test_count
_tvw_make_panel 60 5 20260729
capture noisily quietly tvweight treat, covariates(age sex) id(pid) ///
    time(period) generate(w) cumulative stabilized
local stab_rc = _rc
local maxrd = .
if `stab_rc' == 0 {
    sort pid period
    quietly by pid: generate double _recur = w if _n == 1
    quietly by pid: replace _recur = _recur[_n-1] * w if _n > 1
    quietly generate double _rd = abs(w_cum - _recur)
    quietly summarize _rd, meanonly
    local maxrd = r(max)
    quietly drop _recur _rd
}
local ok = (`stab_rc' == 0 & `maxrd' == 0)
_tvw_check `ok' ///
    "C27 stabilized cumulative equals its running product exactly" ///
    "rc=`stab_rc' max abs deviation `maxrd'"


**# ===== C28: multinomial exposure =====
* mlogit produces a different per-period weight, but the grouped product is
* the same operation and must satisfy the same recursion.
local ++test_count
_tvw_make_panel 60 5 20260729
quietly generate byte treat3 = treat + (runiform() < 0.35)
capture noisily quietly tvweight treat3, covariates(age sex) id(pid) ///
    time(period) generate(w) cumulative
local mlog_rc = _rc
local maxrd = .
if `mlog_rc' == 0 {
    sort pid period
    quietly by pid: generate double _recur = w if _n == 1
    quietly by pid: replace _recur = _recur[_n-1] * w if _n > 1
    quietly generate double _rd = abs(w_cum - _recur)
    quietly summarize _rd, meanonly
    local maxrd = r(max)
    quietly drop _recur _rd
}
local ok = (`mlog_rc' == 0 & `maxrd' == 0)
_tvw_check `ok' ///
    "C28 multinomial-exposure cumulative equals its running product exactly" ///
    "rc=`mlog_rc' max abs deviation `maxrd'"


**# ===== C29: a partial install is diagnosed, not left to fail at r(199) =====
* cumulative and ipcw() both delegate their running product to
* _tvweight_cumprod. If a user carries this tvweight.ado without the helper --
* a stale or hand-copied install -- the run must say so up front rather than
* die deep in the command with a bare r(199) "command _tvweight_cumprod is
* unrecognized" after the treatment model has already been fitted.
*
* The bootstrap installs tvtools into a sandboxed PLUS, so pointing PLUS at an
* empty tree hides the helper from findfile exactly as a partial install does.
* tvweight itself is already compiled in memory from the cases above, so it
* still runs; dropping the helper from memory forces real name resolution.
local ++test_count
_tvw_make_panel 40 4 20260729
capture program drop _tvweight_cumprod
local _plus_save "`c(sysdir_plus)'"
local _noplus "`c(tmpdir)'/tvw_noplus"
capture mkdir "`_noplus'"
sysdir set PLUS "`_noplus'"
capture noisily tvweight treat, covariates(age sex) id(pid) time(period) ///
    generate(w) cumulative
local guard_rc = _rc
sysdir set PLUS "`_plus_save'"
capture confirm variable w
local guard_no_weight = (_rc != 0)
capture confirm variable w_cum
local guard_no_cum = (_rc != 0)
local ok = (`guard_rc' == 111 & `guard_no_weight' & `guard_no_cum')
_tvw_check `ok' ///
    "C29 a missing helper is refused with r(111) before any output is written" ///
    "rc=`guard_rc' (199 = unguarded) weight_absent=`guard_no_weight' cum_absent=`guard_no_cum'"


**# Summary
local pass_count = $TVW_PASS
local fail_count = $TVW_FAIL
display "RESULT: test_tvweight_cumprod tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "tvweight cumulative-product failures:$TVW_FAILED"
    exit 1
}
