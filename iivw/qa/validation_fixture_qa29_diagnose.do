*! validation_fixture_qa29_diagnose.do — A3 operator cells and export boundaries for iivw_diagnose
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Each cell builds qa_fx_a3_seq with one operator, weights it, fits the three
* roles (unweighted, weighted, weighted + adjustment) and checks
* iivw_diagnose two ways: r(estimates) and r(decomp) against arithmetic on
* the stored e(b)/e(V) (_q29_diag_check), and each stored slope against
* weighted least squares solved in Mata (_q29_wls) -- the independence-GEE
* point equation, a route the package does not use. Sample identity is
* asserted against the fixture's design, not against e(sample). Refusals
* assert the exact rc and an unchanged session. The export cells sweep
* decimals() and font() through qa_option_domain and read the rendered
* workbook cell. The theme() cell pins the removed option on a synthetic
* fixture.
version 16.0
clear all
set more off
set varabbrev off
local qa_dir "`c(pwd)'"
do _iivw_qa_common.do
iivw_qa_bootstrap
do _qa_fx_a3.do
do _qa_state.do
do _qa_metamorphic.do
do _iivw_fixture_qa29.do

* Weight, then store the three roles as q29u q29w q29a. adj() is the
* adjustment added in the third role.
capture program drop _q29_diag_fit
program define _q29_diag_fit
    version 16.0
    syntax , WOPTs(string asis) [ADJ(varlist numeric)]
    quietly iivw_weight, `wopts'
    quietly iivw_fit y, unweighted id(id) time(period) timespec(linear) nolog
    estimates store q29u
    quietly iivw_fit y, vce(fixed) timespec(linear) nolog
    estimates store q29w
    quietly iivw_fit y `adj', vce(fixed) timespec(linear) nolog
    estimates store q29a
end

* The three stored slopes equal Mata WLS on the same rows.
capture program drop _q29_diag_wls
program define _q29_diag_wls
    version 16.0
    syntax [, ADJ(varlist numeric) WVAR(name)]
    if "`wvar'" == "" local wvar _iivw_weight
    tempname H
    _estimates hold `H', restore nullok
    _q29_wls y period
    quietly estimates restore q29u
    assert !missing(scalar(_q29_b), _b[period]) & reldif(_b[period], scalar(_q29_b)) < 1e-9
    _q29_wls y period, wvar(`wvar')
    quietly estimates restore q29w
    assert !missing(scalar(_q29_b), _b[period]) & reldif(_b[period], scalar(_q29_b)) < 1e-9
    _q29_wls y period `adj', wvar(`wvar')
    quietly estimates restore q29a
    assert !missing(scalar(_q29_b), _b[period]) & reldif(_b[period], scalar(_q29_b)) < 1e-9
    scalar drop _q29_b
end

* One EXACT cell: the decomposition, the WLS slopes and full-sample identity.
capture program drop _q29_diag_exact
program define _q29_diag_exact
    version 16.0
    syntax [, ADJ(varlist numeric)]
    quietly count if !missing(y, period)
    local npop = r(N)
    iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous)
    assert r(sample_identical) == 1 & r(decomposable) == 1
    assert r(n_sample_unweighted) == `npop' & r(n_sample_weighted) == `npop' & r(n_sample_adjusted) == `npop'
    _q29_diag_check, coef(period) exogenous
    _q29_diag_wls, adj(`adj')
end

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""
local seed 2910
local wopts id(id) time(period) visit_cov(l0 l_t) maxfu(4) breslow nolog

**# D01: separate -- the adjustment is the separated-subgroup indicator
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(separate)
    quietly count if sep == 1 & y == 1
    assert r(N) == 0
    _q29_diag_fit, wopts(`wopts') adj(sep)
    _q29_diag_exact, adj(sep)
}
if _rc == 0 {
    display as result "  PASS: D01 separate: exact decomposition and WLS slopes"
    local ++pass_count
}
else {
    display as error "  FAIL: D01 separate (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D01"
}

**# D02: separate(switch) -- the adjustment is a treatment fixed in the subgroup
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(separate(switch))
    tempvar chg
    quietly bysort id (period): gen byte `chg' = (a != a[1])
    quietly count if `chg' & sep == 1
    assert r(N) == 0
    drop `chg'
    _q29_diag_fit, wopts(`wopts') adj(a)
    _q29_diag_exact, adj(a)
}
if _rc == 0 {
    display as result "  PASS: D02 separate(switch): exact decomposition and WLS slopes"
    local ++pass_count
}
else {
    display as error "  FAIL: D02 separate(switch) (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D02"
}

**# D03: separate(censor) -- weights from a per-subject censor()
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(separate(censor))
    _q29_fu_end
    quietly count if c == 1
    assert r(N) > 0 & !missing(r(N))
    quietly count if c == 1 & sep == 1
    assert r(N) == 0
    _q29_diag_fit, wopts(id(id) time(period) visit_cov(l0 l_t) censor(fu_end) breslow nolog) adj(sep)
    _q29_diag_exact, adj(sep)
}
if _rc == 0 {
    display as result "  PASS: D03 separate(censor): exact decomposition and WLS slopes"
    local ++pass_count
}
else {
    display as error "  FAIL: D03 separate(censor) (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D03"
}

**# D04: separate_time -- no outcome at period 1
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(separate_time)
    quietly count if y == 1 & period == 1
    assert r(N) == 0
    _q29_diag_fit, wopts(`wopts') adj(l0)
    _q29_diag_exact, adj(l0)
}
if _rc == 0 {
    display as result "  PASS: D04 separate_time: exact decomposition and WLS slopes"
    local ++pass_count
}
else {
    display as error "  FAIL: D04 separate_time (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D04"
}

**# D05: absorb -- the adjustment is the absorbed arm's baseline treatment
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(absorb)
    quietly bysort id (period): gen byte a0 = a[1]
    quietly count if a0 == 1 & period > 1
    assert r(N) == 0
    _q29_diag_fit, wopts(`wopts') adj(a0)
    _q29_diag_exact, adj(a0)
}
if _rc == 0 {
    display as result "  PASS: D05 absorb: exact decomposition and WLS slopes"
    local ++pass_count
}
else {
    display as error "  FAIL: D05 absorb (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D05"
}

**# D06: gap -- missed visits in the fitted panel
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(gap)
    local ngap = r(perturb_n_gap)
    assert `ngap' > 0 & !missing(`ngap')
    _q29_diag_fit, wopts(`wopts') adj(l0)
    _q29_diag_exact, adj(l0)
}
if _rc == 0 {
    display as result "  PASS: D06 gap: exact decomposition and WLS slopes"
    local ++pass_count
}
else {
    display as error "  FAIL: D06 gap (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D06"
}

**# D07: dup_key -- a duplicated (id, time) row after the three fits
* Appending the generator's duplicate (no estimation marker) leaves all
* three samples as fitted: the decomposition is unchanged. Duplicating the
* row together with its stored markers (expand) makes every marker count
* N + 1 rows against e(N) = N: declared unverifiable, never "identical".
local ++test_count
capture noisily {
    tempname E0 E1 D0 D1
    * expect: DEGRADED-DECLARED
    qa_fx_a3_seq, clear seed(`seed') perturb(dup_key)
    local did = r(perturb_id_dup_key)
    assert !missing(`did')
    tempvar copy
    quietly bysort id period: gen byte `copy' = (_n == 2)
    quietly count if `copy'
    assert r(N) == 1
    tempfile extra
    preserve
    quietly keep if `copy'
    drop `copy'
    gen byte _q29_app = 1
    save `extra'
    restore
    quietly drop if `copy'
    drop `copy'
    _q29_diag_fit, wopts(`wopts') adj(l0)
    _q29_diag_wls, adj(l0)
    local n0 = _N
    iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous)
    matrix `E0' = r(estimates)
    matrix `D0' = r(decomp)
    quietly append using `extra'
    quietly duplicates report id period
    assert r(N) - r(unique_value) == 1
    iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous)
    assert r(sample_identical) == 1 & r(decomposable) == 1
    assert r(n_sample_unweighted) == `n0'
    matrix `E1' = r(estimates)
    matrix `D1' = r(decomp)
    assert mreldif(`E0', `E1') == 0 & mreldif(`D0', `D1') == 0
    quietly drop if _q29_app == 1
    drop _q29_app
    quietly expand 2 if id == `did' & period == 1
    quietly duplicates report id period
    assert r(N) - r(unique_value) == 1
    iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous)
    assert missing(r(sample_identical)) & r(decomposable) == 0
    assert r(n_sample_unweighted) == `n0' + 1
    _q29_diag_check, coef(period) exogenous
}
if _rc == 0 {
    display as result "  PASS: D07 dup_key: unmarked duplicate invariant; marked duplicate declared stale"
    local ++pass_count
}
else {
    display as error "  FAIL: D07 dup_key (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D07"
}

**# D08: single_period -- no time variation, so the slope is an omitted placeholder
local ++test_count
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear seed(`seed') perturb(single_period)
    quietly summarize period
    assert r(min) == 0 & r(max) == 0
    quietly regress y period
    estimates store q29u
    quietly regress y period [pweight = w]
    estimates store q29w
    quietly regress y period l0 [pweight = w]
    estimates store q29a
    assert _b[period] == 0 & _se[period] == 0
    qa_state_snapshot, tag(d08)
    capture noisily iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a)
    assert _rc == 459
    qa_state_compare, tag(d08)
}
if _rc == 0 {
    display as result "  PASS: D08 single_period: omitted slope refused rc 459, state unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: D08 single_period (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D08"
}

**# D09: miss_partial -- the adjusted role loses the rows where l0 is missing
local ++test_count
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear seed(`seed') perturb(miss_partial)
    quietly count if mod(id, 7) == 0 & period >= 1
    local n_miss = r(N)
    assert `n_miss' > 0
    quietly count
    local npop = r(N)
    _q29_diag_fit, wopts(id(id) time(period) visit_cov(l_t) maxfu(4) breslow nolog) adj(l0)
    qa_state_snapshot, tag(d09)
    capture noisily iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous)
    assert _rc == 198
    qa_state_compare, tag(d09)
    iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous) force
    assert r(sample_identical) == 0 & r(decomposable) == 0
    assert r(n_sample_unweighted) == `npop' & r(n_sample_weighted) == `npop'
    assert r(n_sample_adjusted) == `npop' - `n_miss'
    tempname D
    matrix `D' = r(decomp)
    assert missing(`D'[4, 1]) & missing(`D'[5, 1])
}
if _rc == 0 {
    display as result "  PASS: D09 miss_partial: rc 198; force reports the design's sample sizes"
    local ++pass_count
}
else {
    display as error "  FAIL: D09 miss_partial (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D09"
}

**# D10: codes_multidigit -- glm roles with i.xcat at codes 1 11 111
local ++test_count
capture noisily {
    tempname E0 E1 D0 D1
    qa_fx_a3_seq, clear seed(`seed')
    quietly iivw_weight, `wopts'
    quietly glm y period, vce(cluster id)
    estimates store q29u
    quietly glm y period [pweight = _iivw_weight], vce(cluster id)
    estimates store q29w
    quietly glm y period l0 i.xcat [pweight = _iivw_weight], vce(cluster id)
    estimates store q29a
    iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous)
    matrix `E0' = r(estimates)
    matrix `D0' = r(decomp)
    * expect: INVARIANT
    qa_fx_a3_seq, clear seed(`seed') perturb(codes_multidigit)
    quietly levelsof xcat, local(codes)
    assert "`codes'" == "1 11 111"
    quietly iivw_weight, `wopts'
    quietly glm y period, vce(cluster id)
    estimates store q29u
    quietly glm y period [pweight = _iivw_weight], vce(cluster id)
    estimates store q29w
    quietly glm y period l0 i.xcat [pweight = _iivw_weight], vce(cluster id)
    estimates store q29a
    local cn : colnames e(b)
    assert strpos("`cn'", "111.xcat") > 0
    iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous)
    matrix `E1' = r(estimates)
    matrix `D1' = r(decomp)
    assert !matmissing(`E0') & !matmissing(`E1')
    assert mreldif(`E0', `E1') < 1e-12 & mreldif(`D0', `D1') < 1e-12
    _q29_diag_check, coef(period) exogenous
}
if _rc == 0 {
    display as result "  PASS: D10 codes_multidigit: identical decomposition under relabelled factor"
    local ++pass_count
}
else {
    display as error "  FAIL: D10 codes_multidigit (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D10"
}

**# D11: prefix_collision -- user columns named as prefixes of package columns
local ++test_count
capture noisily {
    tempname E0 E1 D0 D1
    qa_fx_a3_seq, clear seed(`seed')
    _q29_diag_fit, wopts(`wopts') adj(l0)
    iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous)
    matrix `E0' = r(estimates)
    matrix `D0' = r(decomp)
    * expect: INVARIANT
    qa_fx_a3_seq, clear seed(`seed') perturb(prefix_collision) collide(_iivw_w _iivw_i _est_q29)
    set varabbrev on
    capture noisily {
        _q29_diag_fit, wopts(`wopts') adj(l0)
        iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous)
        matrix `E1' = r(estimates)
        matrix `D1' = r(decomp)
        local si = r(sample_identical)
    }
    local drc = _rc
    set varabbrev off
    assert `drc' == 0 & `si' == 1
    assert !matmissing(`E0') & !matmissing(`E1')
    assert mreldif(`E0', `E1') < 1e-12 & mreldif(`D0', `D1') < 1e-12
    foreach v in _iivw_w _iivw_i _est_q29 {
        quietly count if `v' == 999
        assert r(N) == _N
    }
}
if _rc == 0 {
    display as result "  PASS: D11 prefix_collision: identical under varabbrev on, user columns intact"
    local ++pass_count
}
else {
    display as error "  FAIL: D11 prefix_collision (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D11"
}

**# D12: singleton_clusters -- clustering on cl = id equals clustering on id
local ++test_count
capture noisily {
    tempname E0 E1 D0 D1
    * expect: INVARIANT
    qa_fx_a3_seq, clear seed(`seed') perturb(singleton_clusters)
    assert cl == id
    quietly iivw_weight, `wopts'
    foreach cv in id cl {
        quietly glm y period, vce(cluster `cv')
        estimates store q29u
        quietly glm y period [pweight = _iivw_weight], vce(cluster `cv')
        estimates store q29w
        quietly glm y period l0 [pweight = _iivw_weight], vce(cluster `cv')
        estimates store q29a
        assert e(N_clust) == 400 & "`e(clustvar)'" == "`cv'"
        iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous)
        local k = cond("`cv'" == "id", 0, 1)
        matrix `E`k'' = r(estimates)
        matrix `D`k'' = r(decomp)
    }
    assert !matmissing(`E0') & !matmissing(`E1')
    assert mreldif(`E0', `E1') < 1e-12 & mreldif(`D0', `D1') < 1e-12
    _q29_diag_check, coef(period) exogenous
    _q29_diag_wls, adj(l0)
}
if _rc == 0 {
    display as result "  PASS: D12 singleton_clusters: cluster(cl) == cluster(id), WLS slopes"
    local ++pass_count
}
else {
    display as error "  FAIL: D12 singleton_clusters (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D12"
}

**# D13: extreme_weight -- a 1e4 covariate in the visit model and the adjustment
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(extreme_weight)
    quietly summarize w
    assert r(max) == 1e4 & r(min) == 1
    _q29_diag_fit, wopts(id(id) time(period) visit_cov(l0 l_t w) maxfu(4) breslow nolog) adj(w)
    _q29_diag_exact, adj(w)
}
if _rc == 0 {
    display as result "  PASS: D13 extreme_weight: exact decomposition and WLS slopes"
    local ++pass_count
}
else {
    display as error "  FAIL: D13 extreme_weight (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D13"
}

**# D14: boundary_values:decimals -- 0 and 6 render exactly; outside values refuse
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear seed(`seed')
    _q29_diag_fit, wopts(`wopts') adj(l0)
    * Workbook C4 is the unweighted slope; its oracle is Mata OLS.
    _q29_wls y period
    scalar _q29_val = scalar(_q29_b)
    scalar drop _q29_b
    tempfile stub
    local wb "`stub'_d14.xlsx"
    foreach d in 0 6 {
        qa_option_domain, command(iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous) decimals(@v@) xlsx("`wb'") sheet(Q29)) inside(`d') check(_q29_xcheck diagnostics `d' _q29_val "`wb'" Arial)
        assert r(n_cells) == 1 & r(n_violations) == 0
    }
    local wbo "`stub'_d14o.xlsx"
    qa_option_domain, command(iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous) decimals(@v@) xlsx("`wbo'") sheet(Q29)) inside(4) outside(-1;7;2.5;.;abc)
    assert r(n_cells) == 6 & r(n_violations) == 0
    capture erase "`wbo'"
    capture noisily iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous) decimals(7) xlsx("`wbo'") sheet(Q29)
    assert _rc == 198
    capture confirm file "`wbo'"
    assert _rc == 601
    scalar drop _q29_val
}
if _rc == 0 {
    display as result "  PASS: D14 decimals(): 0 and 6 exact text, -1 7 2.5 . abc refused"
    local ++pass_count
}
else {
    display as error "  FAIL: D14 boundary_values:decimals (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D14"
}

**# D15: boundary_values:font -- empty, one-character and long family names
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear seed(`seed')
    _q29_diag_fit, wopts(`wopts') adj(l0)
    _q29_wls y period
    scalar _q29_val = scalar(_q29_b)
    scalar drop _q29_b
    tempfile stub
    local wb "`stub'_d15.xlsx"
    local long "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDE"
    * An empty family name falls back to the documented default, Arial.
    qa_option_domain, command(iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous) font("@v@") decimals(6) xlsx("`wb'") sheet(Q29)) inside(;) check(_q29_xcheck diagnostics 6 _q29_val "`wb'" Arial)
    assert r(n_cells) == 2 & r(n_violations) == 0
    qa_option_domain, command(iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous) font("@v@") decimals(6) xlsx("`wb'") sheet(Q29)) inside(X) check(_q29_xcheck diagnostics 6 _q29_val "`wb'" X)
    assert r(n_cells) == 1 & r(n_violations) == 0
    qa_option_domain, command(iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous) font("@v@") decimals(6) xlsx("`wb'") sheet(Q29)) inside(`long') check(_q29_xcheck diagnostics 6 _q29_val "`wb'" `long')
    assert r(n_cells) == 1 & r(n_violations) == 0
    * A 32-character family is refused: an Excel workbook stores at most 31.
    _q29_refusal, command(iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous) font("`long'F") decimals(6) xlsx("`wb'") sheet(Q29)) rc(198) cause("font() must be at most 31 characters") workbook(`wb')
    * Refused before any computation: a late refusal posted r() first.
    capture iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous) font("`long'F") decimals(6) xlsx("`wb'") sheet(Q29)
    local frc = _rc
    capture confirm matrix r(estimates)
    assert `frc' == 198 & _rc == 111
    * fontsize(): 1 and 72 render exactly; 0 and 73 refuse with the message.
    foreach fs in 1 72 {
        qa_option_domain, command(iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous) fontsize(@v@) decimals(6) xlsx("`wb'") sheet(Q29)) inside(`fs') check(_q29_xsize "`wb'" `fs')
        assert r(n_cells) == 1 & r(n_violations) == 0
    }
    foreach fs in 0 73 {
        _q29_refusal, command(iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous) fontsize(`fs') decimals(6) xlsx("`wb'") sheet(Q29)) rc(198) cause("fontsize() must be between 1 and 72") workbook(`wb')
    }
    scalar drop _q29_val
}
if _rc == 0 {
    display as result "  PASS: D15 font() empty/X/31 chars exact, 32 refused; fontsize() 1 72 exact, 0 73 refused"
    local ++pass_count
}
else {
    display as error "  FAIL: D15 boundary_values:font (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D15"
}

**# D16: theme() on a synthetic fixture -- the removed option is refused unchanged
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear seed(`seed')
    _q29_diag_fit, wopts(`wopts') adj(l0)
    qa_state_snapshot, tag(d16)
    capture noisily iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) theme(lancet)
    assert _rc == 198
    qa_state_compare, tag(d16)
    * The same call without theme() runs and matches the stored estimates.
    iivw_diagnose period, unweighted(q29u) weighted(q29w) adjusted(q29a) exogeneity(exogenous)
    _q29_diag_check, coef(period) exogenous
}
if _rc == 0 {
    display as result "  PASS: D16 theme(): rc 198 and no change; control call matches"
    local ++pass_count
}
else {
    display as error "  FAIL: D16 theme() (rc `=_rc')"
    local ++fail_count
    local failed "`failed' D16"
}

capture estimates drop q29u q29w q29a
iivw_qa_summary, name(validation_fixture_qa29_diagnose) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed'")
