* test_adversarial.do — adversarial QA for psdash
* Maximally hostile, stupid, and malicious user inputs
* Usage: cd psdash/qa && stata-mp -b do test_adversarial.do

version 16.0
do "`c(pwd)'/_psdash_bootstrap.do"
local repo_dir = subinstr("`pkg_dir'", "/psdash", "", 1)

local test_count = 0
local pass_count = 0
local fail_count = 0

* ============================================================================
* SECTION 1: GARBAGE INPUTS (the "I have no idea what I'm doing" user)
* ============================================================================

* T1: Completely empty command — no subcommand, no data, no estimation context
local ++test_count
capture noisily {
    clear
    psdash
}
if _rc == 0 {
    display as result "  PASS: T1 bare psdash shows help without error"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 bare psdash (error `=_rc')"
    local ++fail_count
}

* T2: Garbage subcommand name
local ++test_count
capture noisily {
    clear
    sysuse auto, clear
    psdash flargleblarg
}
assert _rc == 198
display as result "  PASS: T2 garbage subcommand rejected (rc=198)"
local ++pass_count

* T3: String variable as treatment
local ++test_count
capture noisily {
    clear
    input str10 treat double ps
    "drug" 0.3
    "placebo" 0.7
    end
    psdash overlap treat ps, nograph
}
assert _rc != 0
display as result "  PASS: T3 string treatment rejected"
local ++pass_count

* T4: No data in memory at all
local ++test_count
capture noisily {
    clear
    psdash overlap, nograph
}
assert _rc != 0
display as result "  PASS: T4 no data rejected"
local ++pass_count

* T5: Three positional arguments (only 2 allowed)
local ++test_count
capture noisily {
    sysuse auto, clear
    gen byte treat = foreign
    gen double ps = price / 20000
    psdash overlap treat ps price, nograph
}
assert _rc == 103
display as result "  PASS: T5 three positional args rejected (rc=103)"
local ++pass_count

* T6: Nonexistent variable name
local ++test_count
capture noisily {
    sysuse auto, clear
    psdash overlap totally_fake_var also_fake, nograph
}
assert _rc == 111
display as result "  PASS: T6 nonexistent variable rejected (rc=111)"
local ++pass_count

* ============================================================================
* SECTION 2: DEGENERATE DATA (the "my dataset is cursed" user)
* ============================================================================

* T7: All observations in one treatment group (no controls)
local ++test_count
capture noisily {
    clear
    set obs 50
    gen byte treat = 1
    gen double ps = runiform()
    psdash overlap treat ps, nograph
}
assert _rc == 198
display as result "  PASS: T7 single treatment group rejected (rc=198)"
local ++pass_count

* T8: Exactly 1 obs per group (need >= 2 for density estimation)
local ++test_count
capture noisily {
    clear
    set obs 2
    gen byte treat = _n - 1
    gen double ps = 0.3 + 0.4 * treat
    psdash overlap treat ps, nograph
}
assert _rc == 2001
display as result "  PASS: T8 single obs per group rejected (rc=2001)"
local ++pass_count

* T9: Empty dataset after if restriction — detect passes through K=0,
*      subcommand hits N=0 check
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform()
    gen byte keep_me = 0
    psdash overlap treat ps if keep_me == 1, nograph
}
assert _rc == 2000
display as result "  PASS: T9 empty after if rejected (rc=2000)"
local ++pass_count

* T10: Constant covariate — zero variance -> pooled SD = 0 in balance
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = 0.3 + 0.4 * treat + rnormal() * 0.1
    replace ps = max(0.01, min(0.99, ps))
    gen double constant_var = 42
    gen double real_var = rnormal()
    psdash balance treat ps, covariates(constant_var real_var) nowvar
}
if _rc == 0 {
    assert r(max_smd_raw) != .
    display as result "  PASS: T10 constant covariate handled gracefully"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 constant covariate crashed (error `=_rc')"
    local ++fail_count
}

* T11: All PS exactly 0.5 — zero SD in PS, but balance should still work
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = 0.5
    gen double x1 = rnormal()
    psdash balance treat ps, covariates(x1) nowvar
}
if _rc == 0 {
    display as result "  PASS: T11 constant PS handled"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 constant PS crashed (error `=_rc')"
    local ++fail_count
}

* T12: PS exactly 0 for all treated — weights undefined, all treated excluded
*      After markout, only controls remain → "must have exactly 2 levels"
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = cond(treat == 1, 0, 0.5)
    psdash weights treat ps, nograph
}
if _rc == 198 | _rc == 2001 {
    display as result "  PASS: T12 PS=0 for all treated → group excluded (rc=`=_rc')"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 PS=0 expected rc=198 or 2001, got `=_rc'"
    local ++fail_count
}

* T13: PS exactly 1 for all controls — weights undefined, all controls excluded
*      After markout, only treated remain → "must have exactly 2 levels"
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = cond(treat == 0, 1, 0.5)
    psdash weights treat ps, nograph
}
if _rc == 198 | _rc == 2001 {
    display as result "  PASS: T13 PS=1 for all controls → group excluded (rc=`=_rc')"
    local ++pass_count
}
else {
    display as error "  FAIL: T13 PS=1 expected rc=198 or 2001, got `=_rc'"
    local ++fail_count
}

* T14: Massive extreme weights — PS near epsilon
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double ps = cond(treat == 1, 0.001, 0.999)
    psdash weights treat ps, nograph
}
if _rc == 0 {
    assert r(max_wt) > 100
    assert r(n_extreme) > 0
    display as result "  PASS: T14 extreme weights detected (max_wt=" ///
        string(r(max_wt), "%9.1f") ")"
    local ++pass_count
}
else {
    display as error "  FAIL: T14 extreme weights crashed (error `=_rc')"
    local ++fail_count
}

* T15: Negative PS values — should reject
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = rnormal() * 0.5 + 0.5
    replace ps = -0.1 in 1
    psdash overlap treat ps, nograph
}
assert _rc == 198
display as result "  PASS: T15 negative PS rejected (rc=198)"
local ++pass_count

* T16: PS > 1 — should reject
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    replace ps = 1.5 in 1
    psdash overlap treat ps, nograph
}
assert _rc == 198
display as result "  PASS: T16 PS>1 rejected (rc=198)"
local ++pass_count

* T17: All missing PS — markout should yield N=0
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = .
    psdash overlap treat ps, nograph
}
assert _rc == 2000
display as result "  PASS: T17 all-missing PS rejected (rc=2000)"
local ++pass_count

* T18: Treatment with missing values — should be excluded by markout
local ++test_count
capture noisily {
    clear
    set obs 100
    gen double treat = cond(_n <= 40, 0, cond(_n <= 80, 1, .))
    gen double ps = runiform() * 0.8 + 0.1
    psdash overlap treat ps, nograph
}
if _rc == 0 {
    assert r(N) == 80
    display as result "  PASS: T18 missing treatment excluded (N=" ///
        string(r(N), "%3.0f") ")"
    local ++pass_count
}
else {
    display as error "  FAIL: T18 missing treatment crashed (error `=_rc')"
    local ++fail_count
}

* ============================================================================
* SECTION 3: NAME COLLISIONS (the "I named everything _psdash_*" user)
* ============================================================================

* T19: User variable named _psdash_ps already exists (used internally)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double _psdash_ps = runiform()
    gen double x1 = rnormal()
    logit treat x1
    predict double my_ps, pr
    psdash overlap treat my_ps, nograph
}
if _rc == 0 {
    display as result "  PASS: T19 existing _psdash_ps no collision with manual PS"
    local ++pass_count
}
else {
    display as error "  FAIL: T19 _psdash_ps collision (error `=_rc')"
    local ++fail_count
}

* T20: generate() with _psdash_ prefix — reserved, should reject
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash support treat ps, generate(_psdash_evil) nograph
}
assert _rc == 198
display as result "  PASS: T20 generate(_psdash_*) rejected (rc=198)"
local ++pass_count

* T21: generate() same as treatment variable
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash weights treat ps, trim(99) generate(treat)
}
assert _rc == 198
display as result "  PASS: T21 generate(treatment) rejected"
local ++pass_count

* T22: generate() same as PS variable
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash weights treat ps, trim(99) generate(ps)
}
assert _rc == 198
display as result "  PASS: T22 generate(ps) rejected"
local ++pass_count

* T23: generate() already exists without replace
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen byte in_support = 1
    psdash support treat ps, generate(in_support) nograph
}
assert _rc == 110
display as result "  PASS: T23 generate() exists without replace rejected (rc=110)"
local ++pass_count

* T24: generate() already exists WITH replace — should succeed
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen byte in_support = 1
    psdash support treat ps, generate(in_support) replace nograph
}
if _rc == 0 {
    confirm variable in_support
    display as result "  PASS: T24 generate() with replace succeeds"
    local ++pass_count
}
else {
    display as error "  FAIL: T24 generate() with replace (error `=_rc')"
    local ++fail_count
}

* ============================================================================
* SECTION 4: CONFLICTING OPTIONS (the "I'll try everything at once" user)
* ============================================================================

* T25: wvar and matched together in balance
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double wt = 1 / cond(treat == 1, ps, 1 - ps)
    gen double x1 = rnormal()
    psdash balance treat ps, wvar(wt) matched covariates(x1)
}
assert _rc == 198
display as result "  PASS: T25 wvar + matched rejected"
local ++pass_count

* T26: trim + truncate together in weights
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash weights treat ps, trim(99) truncate(10) generate(w_new)
}
assert _rc == 198
display as result "  PASS: T26 trim + truncate rejected"
local ++pass_count

* T27: stabilize + trim together in weights
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash weights treat ps, stabilize trim(99) generate(w_new)
}
assert _rc == 198
display as result "  PASS: T27 stabilize + trim rejected"
local ++pass_count

* T28: crump + threshold together in support
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash support treat ps, crump threshold(0.1) nograph
}
assert _rc == 198
display as result "  PASS: T28 crump + threshold rejected"
local ++pass_count

* T29: trim without generate
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash weights treat ps, trim(99)
}
assert _rc == 198
display as result "  PASS: T29 trim without generate rejected"
local ++pass_count

* T30: generate without modification option
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash weights treat ps, generate(w_new)
}
assert _rc == 198
display as result "  PASS: T30 generate without trim/truncate/stabilize rejected"
local ++pass_count

* ============================================================================
* SECTION 5: BOUNDARY VALUES (the "I set everything to the limit" user)
* ============================================================================

* T31: threshold(0) in balance — should reject (must be positive)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double x1 = rnormal()
    psdash balance treat ps, covariates(x1) threshold(0) nowvar
}
assert _rc == 198
display as result "  PASS: T31 threshold(0) rejected"
local ++pass_count

* T32: threshold(-1) in balance
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double x1 = rnormal()
    psdash balance treat ps, covariates(x1) threshold(-1) nowvar
}
assert _rc == 198
display as result "  PASS: T32 negative threshold rejected"
local ++pass_count

* T33: trim(49.9) — below minimum 50
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash weights treat ps, trim(49.9) generate(w_new)
}
assert _rc == 198
display as result "  PASS: T33 trim(49.9) rejected"
local ++pass_count

* T34: trim(100) — above maximum 99.9
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash weights treat ps, trim(100) generate(w_new)
}
assert _rc == 198
display as result "  PASS: T34 trim(100) rejected"
local ++pass_count

* T35: truncate(0) — must be positive
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash weights treat ps, truncate(0) generate(w_new)
}
assert _rc == 198
display as result "  PASS: T35 truncate(0) rejected"
local ++pass_count

* T36: truncate(-5) — negative
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash weights treat ps, truncate(-5) generate(w_new)
}
assert _rc == 198
display as result "  PASS: T36 truncate(-5) rejected"
local ++pass_count

* T37: support threshold(0.5) — boundary, should reject (must be < 0.5)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash support treat ps, threshold(0.5) nograph
}
assert _rc == 198
display as result "  PASS: T37 support threshold(0.5) rejected"
local ++pass_count

* T38: support threshold(0.6) — above 0.5
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash support treat ps, threshold(0.6) nograph
}
assert _rc == 198
display as result "  PASS: T38 support threshold(0.6) rejected"
local ++pass_count

* T39: bins(0) in overlap
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash overlap treat ps, histogram bins(0) nograph
}
assert _rc == 198
display as result "  PASS: T39 bins(0) rejected"
local ++pass_count

* T40: bins(-1) in overlap
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash overlap treat ps, histogram bins(-1) nograph
}
assert _rc == 198
display as result "  PASS: T40 bins(-1) rejected"
local ++pass_count

* ============================================================================
* SECTION 6: INVALID FORMAT AND EXCEL OPTIONS
* ============================================================================

* T41: Invalid display format
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double x1 = rnormal()
    psdash balance treat ps, covariates(x1) format(%garbage) nowvar
}
assert _rc == 198
display as result "  PASS: T41 invalid format rejected"
local ++pass_count

* T42: Time format (not numeric)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double x1 = rnormal()
    psdash balance treat ps, covariates(x1) format(%td) nowvar
}
assert _rc == 198
display as result "  PASS: T42 time format rejected"
local ++pass_count

* T43: String format
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double x1 = rnormal()
    psdash balance treat ps, covariates(x1) format(%10s) nowvar
}
assert _rc == 198
display as result "  PASS: T43 string format rejected"
local ++pass_count

* T44: Excel file without .xlsx extension
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double x1 = rnormal()
    psdash balance treat ps, covariates(x1) xlsx(output.csv) nowvar
}
assert _rc == 198
display as result "  PASS: T44 non-xlsx extension rejected"
local ++pass_count

* ============================================================================
* SECTION 7: VARABBREV LEAK (the "varabbrev better be restored" tests)
* ============================================================================

* T45: varabbrev restored on success
local ++test_count
capture noisily {
    set varabbrev on
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash overlap treat ps, nograph
}
assert c(varabbrev) == "on"
display as result "  PASS: T45 varabbrev restored after success"
local ++pass_count

* T46: varabbrev restored on error
local ++test_count
set varabbrev on
capture noisily {
    clear
    psdash overlap
}
assert c(varabbrev) == "on"
display as result "  PASS: T46 varabbrev restored after error"
local ++pass_count

* T47: varabbrev restored when initially off
local ++test_count
capture noisily {
    set varabbrev off
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash overlap treat ps, nograph
}
assert c(varabbrev) == "off"
display as result "  PASS: T47 varabbrev=off preserved"
local ++pass_count
set varabbrev on

* T48: varabbrev restored from router on bogus subcommand
local ++test_count
set varabbrev on
capture noisily {
    clear
    sysuse auto, clear
    psdash nonsense_subcmd
}
assert c(varabbrev) == "on"
display as result "  PASS: T48 varabbrev restored from router error"
local ++pass_count

* ============================================================================
* SECTION 8: DATA PRESERVATION (the "you better not touch my data" user)
* ============================================================================

* T49: overlap preserves data unchanged
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double myvar = rnormal()
    sort myvar
    local orig_N = _N
    local orig_sum = 0
    quietly summarize myvar
    local orig_mean = r(mean)
    local orig_vars : char _dta[_varlist_count]
    local nvars_before = 3
    describe, short
    local nvars_before = r(k)
    psdash overlap treat ps, nograph
    assert _N == `orig_N'
    describe, short
    assert r(k) == `nvars_before'
    quietly summarize myvar
    assert abs(r(mean) - `orig_mean') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: T49 overlap preserves data"
    local ++pass_count
}
else {
    display as error "  FAIL: T49 overlap data preservation (error `=_rc')"
    local ++fail_count
}

* T50: balance preserves data unchanged
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    sort x1
    local orig_N = _N
    quietly summarize x1
    local orig_mean = r(mean)
    describe, short
    local nvars_before = r(k)
    psdash balance treat ps, covariates(x1 x2) nowvar
    assert _N == `orig_N'
    describe, short
    assert r(k) == `nvars_before'
    quietly summarize x1
    assert abs(r(mean) - `orig_mean') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: T50 balance preserves data"
    local ++pass_count
}
else {
    display as error "  FAIL: T50 balance data preservation (error `=_rc')"
    local ++fail_count
}

* T51: support with generate adds exactly one variable
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    local orig_N = _N
    describe, short
    local nvars_before = r(k)
    psdash support treat ps, generate(in_supp) nograph
    assert _N == `orig_N'
    describe, short
    assert r(k) == `nvars_before' + 1
    confirm variable in_supp
}
if _rc == 0 {
    display as result "  PASS: T51 support generate adds exactly 1 var"
    local ++pass_count
}
else {
    display as error "  FAIL: T51 support generate (error `=_rc')"
    local ++fail_count
}

* ============================================================================
* SECTION 9: REPEATED CALLS (the "I'll run it 5 times in a row" user)
* ============================================================================

* T52: Running overlap twice after teffects — auto-generated _psdash_ps
*      Second call should re-create without error
local ++test_count
capture noisily {
    clear
    set obs 500
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double ps_true = invlogit(0.5 * x1 + 0.3 * x2)
    gen byte treat = runiform() < ps_true
    gen double y = treat + x1 + rnormal()
    teffects ipw (y) (treat x1 x2)
    psdash overlap, nograph
    psdash overlap, nograph
}
if _rc == 0 {
    display as result "  PASS: T52 repeated overlap after teffects works"
    local ++pass_count
}
else {
    display as error "  FAIL: T52 repeated overlap (error `=_rc')"
    local ++fail_count
}

* T53: Running support twice with generate — second should fail without replace
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash support treat ps, generate(supp_flag) nograph
    psdash support treat ps, generate(supp_flag) nograph
}
assert _rc == 110
display as result "  PASS: T53 second generate without replace rejected (rc=110)"
local ++pass_count

* T54: Running support twice with generate + replace — should succeed
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash support treat ps, generate(supp_flag2) nograph
    psdash support treat ps, generate(supp_flag2) replace nograph
}
if _rc == 0 {
    confirm variable supp_flag2
    display as result "  PASS: T54 second generate with replace works"
    local ++pass_count
}
else {
    display as error "  FAIL: T54 generate replace (error `=_rc')"
    local ++fail_count
}

* ============================================================================
* SECTION 10: PATHOLOGICAL ESTIMATION CONTEXTS
* ============================================================================

* T55: Stale estimation — run regress, then psdash (not logit/probit/teffects)
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double y = treat + rnormal()
    gen double ps = runiform() * 0.8 + 0.1
    regress y treat
    psdash overlap, nograph
}
assert _rc == 198
display as result "  PASS: T55 stale non-PS estimation context rejected"
local ++pass_count

* T56: teffects ra (doesn't produce PS) — should reject auto-detect
local ++test_count
capture noisily {
    clear
    set obs 500
    gen double x1 = rnormal()
    gen byte treat = runiform() < invlogit(0.5 * x1)
    gen double y = treat + x1 + rnormal()
    teffects ra (y x1) (treat)
    psdash overlap, nograph
}
assert _rc == 198
display as result "  PASS: T56 teffects ra (no PS) rejected"
local ++pass_count

* T57: After logit, user gives one var — ambiguous (is it treat or ps?)
local ++test_count
capture noisily {
    clear
    set obs 200
    gen double x1 = rnormal()
    gen byte treat = runiform() < invlogit(0.5 * x1)
    logit treat x1
    predict double ps_var, pr
    psdash overlap ps_var, nograph
}
if _rc == 0 {
    display as result "  PASS: T57 single arg after logit interpreted as PS"
    local ++pass_count
}
else {
    display as error "  FAIL: T57 single arg after logit (error `=_rc')"
    local ++fail_count
}

* ============================================================================
* SECTION 11: EXTREME / WEIRD DATA SHAPES
* ============================================================================

* T58: 2 obs per group (minimum viable)
local ++test_count
capture noisily {
    clear
    set obs 4
    gen byte treat = cond(_n <= 2, 0, 1)
    gen double ps = cond(_n <= 2, 0.3, 0.7)
    psdash overlap treat ps, nograph
}
if _rc == 0 {
    assert r(N) == 4
    assert r(N_treated) == 2
    assert r(N_control) == 2
    display as result "  PASS: T58 minimum viable (2 per group) works"
    local ++pass_count
}
else {
    display as error "  FAIL: T58 2 per group (error `=_rc')"
    local ++fail_count
}

* T59: Massive imbalance — 990 treated, 10 controls
local ++test_count
capture noisily {
    clear
    set obs 1000
    gen byte treat = _n > 10
    gen double ps = cond(treat, 0.7 + rnormal() * 0.1, 0.3 + rnormal() * 0.1)
    replace ps = max(0.01, min(0.99, ps))
    gen double x1 = rnormal()
    psdash balance treat ps, covariates(x1) nowvar
}
if _rc == 0 {
    assert r(N_treated) == 990
    assert r(N_control) == 10
    display as result "  PASS: T59 massive imbalance (990 vs 10) handled"
    local ++pass_count
}
else {
    display as error "  FAIL: T59 massive imbalance (error `=_rc')"
    local ++fail_count
}

* T60: Treatment coded as 0/1 but float type (not byte/int)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen float treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash overlap treat ps, nograph
}
if _rc == 0 {
    display as result "  PASS: T60 float 0/1 treatment accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: T60 float treatment (error `=_rc')"
    local ++fail_count
}

* T61: Treatment with non-integer values (0.5, 1.5) — not 0/1
local ++test_count
capture noisily {
    clear
    set obs 100
    gen double treat = cond(_n <= 50, 0.5, 1.5)
    gen double ps = runiform() * 0.8 + 0.1
    psdash overlap treat ps, nograph
}
assert _rc == 198
display as result "  PASS: T61 non-integer treatment rejected"
local ++pass_count

* T62: Huge number of covariates in balance (50 vars)
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    forvalues i = 1/50 {
        gen double cov`i' = rnormal()
    }
    local covlist ""
    forvalues i = 1/50 {
        local covlist "`covlist' cov`i'"
    }
    psdash balance treat ps, covariates(`covlist') nowvar
}
if _rc == 0 {
    assert r(n_imbalanced) != .
    assert r(max_smd_raw) != .
    display as result "  PASS: T62 50 covariates handled"
    local ++pass_count
}
else {
    display as error "  FAIL: T62 50 covariates (error `=_rc')"
    local ++fail_count
}

* T63: Balance with covariates that have different missingness per pair
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    replace x1 = . in 1/20
    replace x2 = . in 180/200
    psdash balance treat ps, covariates(x1 x2) nowvar
}
if _rc == 0 {
    display as result "  PASS: T63 pairwise missingness handled"
    local ++pass_count
}
else {
    display as error "  FAIL: T63 pairwise missingness (error `=_rc')"
    local ++fail_count
}

* ============================================================================
* SECTION 12: WEIGHTS SANITY
* ============================================================================

* T64: All weights zero — should reject
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double wt = 0
    psdash weights treat ps, wvar(wt)
}
assert _rc == 198
display as result "  PASS: T64 all-zero weights rejected"
local ++pass_count

* T65: Negative weights — should reject
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double wt = -1
    psdash weights treat ps, wvar(wt)
}
assert _rc == 198
display as result "  PASS: T65 negative weights rejected"
local ++pass_count

* T66: Weights zero for all treated — should reject
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double wt = cond(treat == 1, 0, 1)
    psdash weights treat ps, wvar(wt)
}
assert _rc == 198
display as result "  PASS: T66 zero weights for treated rejected"
local ++pass_count

* T67: Weights zero for all controls — should reject
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double wt = cond(treat == 0, 0, 1)
    psdash weights treat ps, wvar(wt)
}
assert _rc == 198
display as result "  PASS: T67 zero weights for controls rejected"
local ++pass_count

* T68: ESS formula verification — constant weights should give ESS = N
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double wt = 1
    psdash weights treat ps, wvar(wt)
    assert abs(r(ess) - r(N)) < 1e-6
    assert abs(r(ess_pct) - 100) < 1e-3
}
if _rc == 0 {
    display as result "  PASS: T68 constant weights -> ESS = N"
    local ++pass_count
}
else {
    display as error "  FAIL: T68 ESS formula (error `=_rc')"
    local ++fail_count
}

* T69: Stabilized weights — new_mean < original mean (stabilization reduces scale)
local ++test_count
capture noisily {
    clear
    set obs 1000
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.6 + 0.2
    psdash weights treat ps, stabilize generate(sw)
    assert r(new_mean) < r(mean_wt)
    assert r(new_mean) > 0
}
if _rc == 0 {
    display as result "  PASS: T69 stabilized weights mean near 1"
    local ++pass_count
}
else {
    display as error "  FAIL: T69 stabilized weights (error `=_rc')"
    local ++fail_count
}

* ============================================================================
* SECTION 13: ESTIMAND EDGE CASES
* ============================================================================

* T70: Invalid estimand value
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash overlap treat ps, estimand(garbage) nograph
}
assert _rc == 198
display as result "  PASS: T70 invalid estimand rejected"
local ++pass_count

* T71: ATT weights — treated get weight=1, controls get ps/(1-ps)
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.6 + 0.2
    psdash weights treat ps, estimand(att)
    assert r(estimand) == "att"
    assert r(N) == 200
}
if _rc == 0 {
    display as result "  PASS: T71 ATT estimand accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: T71 ATT estimand (error `=_rc')"
    local ++fail_count
}

* T72: ATC weights
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.6 + 0.2
    psdash weights treat ps, estimand(atc)
    assert r(estimand) == "atc"
}
if _rc == 0 {
    display as result "  PASS: T72 ATC estimand accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: T72 ATC estimand (error `=_rc')"
    local ++fail_count
}

* ============================================================================
* SECTION 14: COMBINED SUBCOMMAND TORTURE
* ============================================================================

* T73: Combined with no covariates and no estimation context (balance needs them)
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    psdash combined treat ps, nobalance
}
if _rc == 0 {
    display as result "  PASS: T73 combined with nobalance skips covariate requirement"
    local ++pass_count
}
else {
    display as error "  FAIL: T73 combined nobalance (error `=_rc')"
    local ++fail_count
}

* T74: Combined with all panels skipped -> must ERROR (RB-12): a verdict
* requires at least one executed panel. (Previously returned a bare false-green
* PASS with no evidence.)
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    gen double x1 = rnormal()
    capture psdash combined treat ps, covariates(x1) nooverlap nobalance noweights nosupport
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T74 combined all panels skipped errors (no evidence -> no verdict)"
    local ++pass_count
}
else {
    display as error "  FAIL: T74 combined all skipped should error 198 (got `=_rc')"
    local ++fail_count
}

* ============================================================================
* SECTION 15: MULTI-GROUP ADVERSARIAL
* ============================================================================

* T75: Multi-group with wrong number of psvars
local ++test_count
capture noisily {
    clear
    set obs 150
    gen byte treat = cond(_n <= 50, 1, cond(_n <= 100, 2, 3))
    gen double ps1 = runiform() * 0.5
    gen double ps2 = runiform() * 0.5
    psdash overlap treat, psvars(ps1 ps2) nograph
}
assert _rc == 198
display as result "  PASS: T75 wrong psvars count rejected"
local ++pass_count

* T76: Multi-group with K > 2 but no psvars
local ++test_count
capture noisily {
    clear
    set obs 150
    gen byte treat = cond(_n <= 50, 1, cond(_n <= 100, 2, 3))
    gen double ps1 = runiform()
    psdash overlap treat ps1, nograph
}
assert _rc == 198
display as result "  PASS: T76 K>2 without psvars rejected"
local ++pass_count

* T77: Multi-group with invalid reference level
local ++test_count
capture noisily {
    clear
    set obs 150
    gen byte treat = cond(_n <= 50, 1, cond(_n <= 100, 2, 3))
    gen double ps1 = 0.33
    gen double ps2 = 0.33
    gen double ps3 = 0.34
    psdash overlap treat, psvars(ps1 ps2 ps3) reference(99) nograph
}
assert _rc == 198
display as result "  PASS: T77 invalid reference level rejected"
local ++pass_count

* T78: Multi-group crump — should be rejected (binary only)
local ++test_count
capture noisily {
    clear
    set obs 150
    gen byte treat = cond(_n <= 50, 1, cond(_n <= 100, 2, 3))
    gen double ps1 = 0.33
    gen double ps2 = 0.33
    gen double ps3 = 0.34
    psdash support treat, psvars(ps1 ps2 ps3) crump nograph
}
assert _rc == 198
display as result "  PASS: T78 crump with multi-group rejected"
local ++pass_count

* T79: Multi-group with one empty group after if
local ++test_count
capture noisily {
    clear
    set obs 150
    gen byte treat = cond(_n <= 50, 1, cond(_n <= 100, 2, 3))
    gen double ps1 = runiform() / 3
    gen double ps2 = runiform() / 3
    gen double ps3 = 1 - ps1 - ps2
    replace ps3 = max(0.01, ps3)
    gen byte include = treat != 3
    psdash overlap treat if include, psvars(ps1 ps2 ps3) nograph
}
assert _rc != 0
display as result "  PASS: T79 multi-group empty group after if rejected"
local ++pass_count

* T80: Multi-group balance with covariates
local ++test_count
capture noisily {
    clear
    set obs 300
    gen byte treat = cond(_n <= 100, 1, cond(_n <= 200, 2, 3))
    gen double ps1 = runiform() / 3 + 0.1
    gen double ps2 = runiform() / 3 + 0.1
    gen double ps3 = 1 - ps1 - ps2
    replace ps3 = max(0.01, ps3)
    gen double x1 = rnormal() + treat * 0.5
    gen double x2 = rnormal()
    gen double wt = 1 / cond(treat == 1, ps1, cond(treat == 2, ps2, ps3))
    psdash balance treat, covariates(x1 x2) psvars(ps1 ps2 ps3) ///
        wvar(wt)
}
if _rc == 0 {
    assert r(K) == 3
    assert r(N) == 300
    display as result "  PASS: T80 multi-group balance works"
    local ++pass_count
}
else {
    display as error "  FAIL: T80 multi-group balance (error `=_rc')"
    local ++fail_count
}

* ============================================================================
* SECTION 16: RETURN VALUE SANITY (semantic correctness, not just existence)
* ============================================================================

* T81: overlap r() values are correct (overlapping PS)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = 0
    replace treat = 1 in 1/40
    gen double ps = cond(treat == 1, 0.7, 0.3)
    replace ps = 0.5 in 1
    replace ps = 0.5 in 41
    psdash overlap treat ps, nograph
    assert r(N) == 100
    assert r(N_treated) == 40
    assert r(N_control) == 60
    assert r(mean_ps_treated) != .
    assert r(mean_ps_control) != .
    assert r(overlap_lower) >= 0 & r(overlap_lower) <= 1
    assert r(overlap_upper) >= 0 & r(overlap_upper) <= 1
    assert r(overlap_lower) <= r(overlap_upper)
    assert r(n_outside) >= 0
    assert r(pct_outside) >= 0 & r(pct_outside) <= 100
}
if _rc == 0 {
    display as result "  PASS: T81 overlap r() exact values correct"
    local ++pass_count
}
else {
    display as error "  FAIL: T81 overlap r() values (error `=_rc')"
    local ++fail_count
}

* T82: balance SMD = 0 when groups are identical
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps = 0.5
    gen double x1 = 1
    psdash balance treat ps, covariates(x1) nowvar
    assert r(max_smd_raw) == 0
    assert r(n_imbalanced) == 0
}
if _rc == 0 {
    display as result "  PASS: T82 identical groups -> SMD=0"
    local ++pass_count
}
else {
    display as error "  FAIL: T82 SMD=0 check (error `=_rc')"
    local ++fail_count
}

* T83: support lower_bound and upper_bound are correct
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte treat = 0
    replace treat = 1 in 1/50
    gen double ps = .
    replace ps = 0.2 + 0.6 * (_n - 1) / 49 in 1/50
    replace ps = 0.3 + 0.4 * (_n - 51) / 49 in 51/100
    psdash support treat ps, nograph
    assert abs(r(lower_bound) - 0.3) < 1e-10
    assert abs(r(upper_bound) - 0.7) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: T83 support bounds correct"
    local ++pass_count
}
else {
    display as error "  FAIL: T83 support bounds (error `=_rc')"
    local ++fail_count
}

* T84: weights trim actually reduces max weight
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    replace ps = 0.001 in 1
    psdash weights treat ps, trim(95) generate(w_trimmed)
    assert r(new_max) <= r(max_wt)
    assert r(new_max) < r(max_wt)
}
if _rc == 0 {
    display as result "  PASS: T84 trim reduces max weight"
    local ++pass_count
}
else {
    display as error "  FAIL: T84 trim effect (error `=_rc')"
    local ++fail_count
}

* T85: support generate indicator values are 0 or 1 (no missing inside touse)
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte treat = mod(_n, 2)
    gen double ps = runiform() * 0.8 + 0.1
    replace ps = 0.02 in 1
    replace ps = 0.98 in 2
    psdash support treat ps, generate(in_s) threshold(0.1) nograph
    assert in_s == 0 | in_s == 1
    quietly count if in_s == 1
    assert r(N) > 0
    quietly count if in_s == 0
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: T85 support indicator is clean 0/1"
    local ++pass_count
}
else {
    display as error "  FAIL: T85 support indicator values (error `=_rc')"
    local ++fail_count
}

* ============================================================================
* SUMMARY
* ============================================================================
display ""
display as text "============================================"
display as text "Adversarial QA Summary"
display as text "============================================"
display as text "Total tests: " as result `test_count'
display as text "Passed:      " as result `pass_count'
display as text "Failed:      " as result `fail_count'
display as text "============================================"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    _psdash_qa_cleanup
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
_psdash_qa_cleanup
