*! validation_fixture_qa29_balance.do — A3 operator cells and export boundaries for iivw_balance
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Each cell builds qa_fx_a3_seq with one operator, weights it with iivw_weight
* (id, visit time period, follow-up to maxfu(4) or a per-subject fu_end,
* Breslow so the target-SMD verdict is issued), and checks iivw_balance
* against Mata moments of the stored weight column (_q29_bal_check). Where the
* weights build, a second check sets stabcov() equal to the visit model: the
* weight is then identically 1, so CV is 0, ESS is N and every modeled target
* SMD is 0 (_q29_bal_saturated). Refusals assert the exact rc and an unchanged
* session. The export cells sweep decimals() and font() through
* qa_option_domain and read the rendered workbook cell.
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

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""
local seed 2910
local wopts id(id) time(period) visit_cov(l0 l_t) maxfu(4) breslow nolog

**# B01: separate -- an extra covariate with no variation in the reported subgroup
local ++test_count
capture noisily {
    tempname B
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(separate)
    quietly count if sep == 1 & y == 1
    assert r(N) == 0
    iivw_weight, `wopts'
    iivw_balance y sep, nolog
    _q29_bal_check, covs(l0 l_t y sep)
    tempname T
    matrix `T' = r(target)
    assert !missing(`T'[4, 3]) & abs(`T'[4, 3]) > 1e-4
    _q29_bal_target, covs(l0 l_t y sep) vcov(l0 l_t) endpoint(4)
    iivw_balance y if sep == 1, nolog
    matrix `B' = r(balance)
    assert `B'[3, 1] == 0 & `B'[3, 2] == 0 & `B'[3, 3] == 0 & missing(`B'[3, 4])
    _q29_bal_check, covs(l0 l_t y) cond(sep == 1)
    _q29_bal_saturated, wopts(`wopts') covs(y sep)
}
if _rc == 0 {
    display as result "  PASS: B01 separate: exact moments; zero-SD subgroup covariate has no shift"
    local ++pass_count
}
else {
    display as error "  FAIL: B01 separate (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B01"
}

**# B02: separate(switch) -- a subgroup whose treatment is fixed after period 0
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(separate(switch))
    tempvar chg
    quietly bysort id (period): gen byte `chg' = (a != a[1])
    quietly count if `chg' & sep == 1
    assert r(N) == 0
    drop `chg'
    iivw_weight, `wopts'
    iivw_balance a sep, nolog
    _q29_bal_check, covs(l0 l_t a sep)
    iivw_balance a if sep == 1, nolog
    _q29_bal_check, covs(l0 l_t a) cond(sep == 1)
    _q29_bal_saturated, wopts(`wopts') covs(a sep)
}
if _rc == 0 {
    display as result "  PASS: B02 separate(switch): exact moments overall and in the subgroup"
    local ++pass_count
}
else {
    display as error "  FAIL: B02 separate(switch) (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B02"
}

**# B03: separate(censor) -- per-subject censor(), ends on and after the last visit
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(separate(censor))
    _q29_fu_end
    tempvar last
    quietly bysort id (period): gen byte `last' = (_n == _N)
    quietly count if `last' & fu_end == period
    local n_on = r(N)
    quietly count if `last' & fu_end > period
    local n_term = r(N)
    quietly count if `last' & fu_end == period & sep == 1
    assert `n_on' > 0 & r(N) == 0
    quietly count
    local n_rows = r(N)
    quietly count if `last'
    local n_ids = r(N)
    drop `last'
    local copts id(id) time(period) visit_cov(l0 l_t) censor(fu_end) breslow nolog
    iivw_weight, `copts'
    iivw_balance sep, nolog
    assert r(refit_n_censrows) == `n_term'
    assert r(refit_N) == `n_rows' - `n_ids' + `n_term'
    _q29_bal_check, covs(l0 l_t sep)
    _q29_bal_target, covs(l0 l_t sep) vcov(l0 l_t) endpoint(fu_end)
    _q29_bal_saturated, wopts(`copts') covs(sep)
}
if _rc == 0 {
    display as result "  PASS: B03 separate(censor): terminal intervals counted exactly, exact moments"
    local ++pass_count
}
else {
    display as error "  FAIL: B03 separate(censor) (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B03"
}

**# B04: separate_time -- the outcome has no variation at period 1
local ++test_count
capture noisily {
    tempname B
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(separate_time)
    quietly count if y == 1 & period == 1
    assert r(N) == 0
    iivw_weight, `wopts'
    iivw_balance y, nolog
    _q29_bal_check, covs(l0 l_t y)
    iivw_balance y if period == 1, nolog
    matrix `B' = r(balance)
    assert `B'[3, 3] == 0 & missing(`B'[3, 4])
    _q29_bal_check, covs(l0 l_t y) cond(period == 1)
    _q29_bal_saturated, wopts(`wopts') covs(y)
}
if _rc == 0 {
    display as result "  PASS: B04 separate_time: exact moments; period-1 outcome has no shift"
    local ++pass_count
}
else {
    display as error "  FAIL: B04 separate_time (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B04"
}

**# B05: absorb -- an arm whose subjects all stop by period 1
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(absorb)
    quietly bysort id (period): gen byte a0 = a[1]
    quietly count if a0 == 1 & period > 1
    assert r(N) == 0
    iivw_weight, `wopts'
    iivw_balance a0 y, nolog
    _q29_bal_check, covs(l0 l_t a0 y)
    iivw_balance y if a0 == 1, nolog
    _q29_bal_check, covs(l0 l_t y) cond(a0 == 1)
    _q29_bal_saturated, wopts(`wopts') covs(a0 y)
}
if _rc == 0 {
    display as result "  PASS: B05 absorb: exact moments overall and in the absorbed arm"
    local ++pass_count
}
else {
    display as error "  FAIL: B05 absorb (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B05"
}

**# B06: gap -- missed visits make two-period intervals in the refit
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(gap)
    local ngap = r(perturb_n_gap)
    assert `ngap' > 0 & !missing(`ngap')
    quietly count
    local n_rows = r(N)
    tempvar tag
    quietly egen byte `tag' = tag(id)
    quietly count if `tag'
    local n_ids = r(N)
    drop `tag'
    iivw_weight, `wopts'
    iivw_balance, nolog
    * Every subject has a terminal interval (last period < 4).
    assert r(refit_n_censrows) == `n_ids'
    assert r(refit_N) == `n_rows'
    _q29_bal_check, covs(l0 l_t)
    _q29_bal_target, covs(l0 l_t) vcov(l0 l_t) endpoint(4)
    * Leverage verdict off the low gate: cvcut(0) essratiocut(1) leave the
    * documented adequate/moderate rule to decide.
    iivw_balance, nolog cvcut(0) essratiocut(1)
    assert "`r(leverage)'" == "moderate"
    _q29_bal_check, covs(l0 l_t) cvcut(0) esscut(1)
    _q29_bal_saturated, wopts(`wopts')
}
if _rc == 0 {
    display as result "  PASS: B06 gap: refit interval count and exact moments"
    local ++pass_count
}
else {
    display as error "  FAIL: B06 gap (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B06"
}

**# B07: dup_key -- a duplicated (id, time) row appended after weighting
local ++test_count
capture noisily {
    * expect: REFUSED
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
    save `extra'
    restore
    quietly drop if `copy'
    drop `copy'
    iivw_weight, `wopts'
    iivw_balance, nolog
    _q29_bal_check, covs(l0 l_t)
    quietly append using `extra'
    quietly duplicates report id period
    assert r(N) - r(unique_value) == 1
    qa_state_snapshot, tag(b07)
    capture noisily iivw_balance, nolog
    assert _rc == 459
    qa_state_compare, tag(b07)
}
if _rc == 0 {
    display as result "  PASS: B07 dup_key: rc 459 on the duplicated row, state unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: B07 dup_key (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B07"
}

**# B08: single_period -- no follow-up visit, so no weight and no balance
local ++test_count
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear seed(`seed') perturb(single_period)
    quietly summarize period
    assert r(min) == 0 & r(max) == 0
    qa_state_snapshot, tag(b08)
    capture noisily iivw_weight, `wopts'
    assert _rc == 198
    qa_state_compare, tag(b08) keep
    capture noisily iivw_balance, nolog
    assert _rc == 198
    qa_state_compare, tag(b08)
}
if _rc == 0 {
    display as result "  PASS: B08 single_period: weight and balance both rc 198, state unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: B08 single_period (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B08"
}

**# B09: miss_partial -- an extra covariate missing on some rows
local ++test_count
capture noisily {
    tempname B
    * expect: DEGRADED-DECLARED
    qa_fx_a3_seq, clear seed(`seed') perturb(miss_partial)
    quietly count if mod(id, 7) == 0 & period >= 1
    local n_miss = r(N)
    assert `n_miss' > 0
    iivw_weight, id(id) time(period) visit_cov(l_t) maxfu(4) breslow nolog
    iivw_balance l0, nolog
    matrix `B' = r(balance)
    assert `B'[2, 7] == `n_miss' & `B'[2, 6] == r(N) - `n_miss'
    _q29_bal_check, covs(l_t l0) modeled(l_t)
}
if _rc == 0 {
    display as result "  PASS: B09 miss_partial: missing count declared, moments over the rest exact"
    local ++pass_count
}
else {
    display as error "  FAIL: B09 miss_partial (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B09"
}

**# B10: codes_multidigit -- a subgroup report selected by a relabelled code
local ++test_count
capture noisily {
    tempname B0 B1 S0 S1
    qa_fx_a3_seq, clear seed(`seed')
    iivw_weight, `wopts'
    iivw_balance xcat if xcat == 3, nolog
    matrix `B0' = r(balance)
    matrix `S0' = (r(N), r(n_ids), r(weight_cv), r(ess), r(ess_cluster), ///
        r(balance_max_shift), r(balance_max_tsmd), r(refit_N))
    * expect: INVARIANT
    qa_fx_a3_seq, clear seed(`seed') perturb(codes_multidigit)
    quietly levelsof xcat, local(codes)
    assert "`codes'" == "1 11 111"
    iivw_weight, `wopts'
    iivw_balance xcat if xcat == 111, nolog
    matrix `B1' = r(balance)
    matrix `S1' = (r(N), r(n_ids), r(weight_cv), r(ess), r(ess_cluster), ///
        r(balance_max_shift), r(balance_max_tsmd), r(refit_N))
    assert !matmissing(`S0') & !matmissing(`S1')
    assert mreldif(`S0', `S1') < 1e-12
    * The l0 and l_t rows are invariant; the xcat row is the code itself
    * (constant within the subgroup), so its mean moves 3 -> 111 and its SD
    * stays 0.
    matrix `S0' = `B0'[1..2, 1...]
    matrix `S1' = `B1'[1..2, 1...]
    assert mreldif(`S0', `S1') < 1e-12
    assert `B0'[3, 1] == 3 & `B1'[3, 1] == 111 & `B1'[3, 3] == 0
    _q29_bal_check, covs(l0 l_t xcat) cond(xcat == 111)
}
if _rc == 0 {
    display as result "  PASS: B10 codes_multidigit: subgroup report invariant to 3 -> 111"
    local ++pass_count
}
else {
    display as error "  FAIL: B10 codes_multidigit (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B10"
}

**# B11: prefix_collision -- user columns named as prefixes of package columns
local ++test_count
capture noisily {
    tempname B0 B1 S0 S1
    local lopts id(id) time(period) visit_cov(l0) lagvars(l_t) maxfu(4) breslow nolog
    qa_fx_a3_seq, clear seed(`seed')
    iivw_weight, `lopts'
    iivw_balance, nolog
    matrix `B0' = r(balance)
    matrix `S0' = (r(N), r(weight_cv), r(ess), r(ess_cluster), r(balance_max_tsmd), r(refit_N))
    * expect: INVARIANT
    qa_fx_a3_seq, clear seed(`seed') perturb(prefix_collision) collide(_iivw_w _iivw_i l_t_lag)
    set varabbrev on
    capture noisily {
        iivw_weight, `lopts'
        iivw_balance, nolog
        matrix `B1' = r(balance)
        matrix `S1' = (r(N), r(weight_cv), r(ess), r(ess_cluster), r(balance_max_tsmd), r(refit_N))
    }
    local brc = _rc
    set varabbrev off
    assert `brc' == 0
    assert !matmissing(`S0') & !matmissing(`S1')
    assert mreldif(`S0', `S1') < 1e-12 & mreldif(`B0', `B1') < 1e-12
    foreach v in _iivw_w _iivw_i l_t_lag {
        quietly count if `v' == 999
        assert r(N) == _N
    }
}
if _rc == 0 {
    display as result "  PASS: B11 prefix_collision: identical under varabbrev on, user columns intact"
    local ++pass_count
}
else {
    display as error "  FAIL: B11 prefix_collision (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B11"
}

**# B12: singleton_clusters -- id(cl) with cl = id equals id(id)
local ++test_count
capture noisily {
    tempname B0 B1 S0 S1
    * expect: INVARIANT
    qa_fx_a3_seq, clear seed(`seed') perturb(singleton_clusters)
    assert cl == id
    iivw_weight, `wopts'
    iivw_balance, nolog
    matrix `B0' = r(balance)
    matrix `S0' = (r(N), r(n_ids), r(weight_cv), r(ess), r(ess_cluster), r(balance_max_tsmd))
    iivw_weight, id(cl) time(period) visit_cov(l0 l_t) maxfu(4) breslow nolog replace
    iivw_balance, nolog
    assert "`r(id)'" == "cl"
    matrix `B1' = r(balance)
    matrix `S1' = (r(N), r(n_ids), r(weight_cv), r(ess), r(ess_cluster), r(balance_max_tsmd))
    assert !matmissing(`S0') & !matmissing(`S1')
    assert mreldif(`S0', `S1') < 1e-12 & mreldif(`B0', `B1') < 1e-12
    iivw_balance, nolog
    _q29_bal_check, covs(l0 l_t) idvar(cl)
}
if _rc == 0 {
    display as result "  PASS: B12 singleton_clusters: id(cl) == id(id), exact moments"
    local ++pass_count
}
else {
    display as error "  FAIL: B12 singleton_clusters (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B12"
}

**# B13: extreme_weight -- a 1e4 covariate value inside the visit model
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(extreme_weight)
    quietly summarize w
    assert r(max) == 1e4 & r(min) == 1
    local xopts id(id) time(period) visit_cov(l0 l_t w) maxfu(4) breslow nolog
    iivw_weight, `xopts'
    * The extreme value reaches the weight: id 1's follow-up rows sit below
    * every other subject's.
    quietly count if id == 1 & period > 0
    assert r(N) > 0 & !missing(r(N))
    quietly summarize _iivw_iw if id == 1 & period > 0
    local lo1 = r(min)
    quietly summarize _iivw_iw if id != 1
    assert !missing(`lo1', r(min)) & `lo1' < r(min)
    iivw_balance w, nolog
    _q29_bal_check, covs(l0 l_t w) modeled(l0 l_t w)
    _q29_bal_target, covs(l0 l_t w) vcov(l0 l_t w) endpoint(4)
    _q29_bal_saturated, wopts(`xopts') stab(l0 l_t w) covs(w)
}
if _rc == 0 {
    display as result "  PASS: B13 extreme_weight: exact leverage and moments with w = 1e4 modeled"
    local ++pass_count
}
else {
    display as error "  FAIL: B13 extreme_weight (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B13"
}

**# B14: boundary_values:decimals -- 0 and 6 render exactly; outside values refuse
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear seed(`seed')
    iivw_weight, `wopts'
    mata: st_numscalar("_q29_val", mean(st_data(., "l0")))
    tempfile stub
    local wb "`stub'_b14.xlsx"
    foreach d in 0 6 {
        qa_option_domain, command(iivw_balance, nolog decimals(@v@) xlsx("`wb'") sheet(Q29)) inside(`d') check(_q29_xcheck balance `d' _q29_val "`wb'" Arial)
        assert r(n_cells) == 1 & r(n_violations) == 0
    }
    local wbo "`stub'_b14o.xlsx"
    qa_option_domain, command(iivw_balance, nolog decimals(@v@) xlsx("`wbo'") sheet(Q29)) inside(4) outside(-1;7;2.5;.;abc)
    assert r(n_cells) == 6 & r(n_violations) == 0
    capture erase "`wbo'"
    capture noisily iivw_balance, nolog decimals(7) xlsx("`wbo'") sheet(Q29)
    assert _rc == 198
    capture confirm file "`wbo'"
    assert _rc == 601
    scalar drop _q29_val
}
if _rc == 0 {
    display as result "  PASS: B14 decimals(): 0 and 6 exact text, -1 7 2.5 . abc refused"
    local ++pass_count
}
else {
    display as error "  FAIL: B14 boundary_values:decimals (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B14"
}

**# B15: boundary_values:font -- empty, one-character and long family names
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear seed(`seed')
    iivw_weight, `wopts'
    mata: st_numscalar("_q29_val", mean(st_data(., "l0")))
    tempfile stub
    local wb "`stub'_b15.xlsx"
    local long "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDE"
    * An empty family name falls back to the documented default, Arial.
    qa_option_domain, command(iivw_balance, nolog font("@v@") decimals(6) xlsx("`wb'") sheet(Q29)) inside(;) check(_q29_xcheck balance 6 _q29_val "`wb'" Arial)
    assert r(n_cells) == 2 & r(n_violations) == 0
    qa_option_domain, command(iivw_balance, nolog font("@v@") decimals(6) xlsx("`wb'") sheet(Q29)) inside(X) check(_q29_xcheck balance 6 _q29_val "`wb'" X)
    assert r(n_cells) == 1 & r(n_violations) == 0
    qa_option_domain, command(iivw_balance, nolog font("@v@") decimals(6) xlsx("`wb'") sheet(Q29)) inside(`long') check(_q29_xcheck balance 6 _q29_val "`wb'" `long')
    assert r(n_cells) == 1 & r(n_violations) == 0
    * A 32-character family is refused: an Excel workbook stores at most 31.
    _q29_refusal, command(iivw_balance, nolog font("`long'F") decimals(6) xlsx("`wb'") sheet(Q29)) rc(198) cause("font() must be at most 31 characters") workbook(`wb')
    * Refused before any computation: a late refusal posted r() first.
    capture iivw_balance, nolog font("`long'F") decimals(6) xlsx("`wb'") sheet(Q29)
    local frc = _rc
    capture confirm matrix r(balance)
    assert `frc' == 198 & _rc == 111
    * fontsize(): 1 and 72 render exactly; 0 and 73 refuse with the message.
    foreach fs in 1 72 {
        qa_option_domain, command(iivw_balance, nolog fontsize(@v@) decimals(6) xlsx("`wb'") sheet(Q29)) inside(`fs') check(_q29_xsize "`wb'" `fs')
        assert r(n_cells) == 1 & r(n_violations) == 0
    }
    foreach fs in 0 73 {
        _q29_refusal, command(iivw_balance, nolog fontsize(`fs') decimals(6) xlsx("`wb'") sheet(Q29)) rc(198) cause("fontsize() must be between 1 and 72") workbook(`wb')
    }
    scalar drop _q29_val
}
if _rc == 0 {
    display as result "  PASS: B15 font() empty/X/31 chars exact, 32 refused; fontsize() 1 72 exact, 0 73 refused"
    local ++pass_count
}
else {
    display as error "  FAIL: B15 boundary_values:font (rc `=_rc')"
    local ++fail_count
    local failed "`failed' B15"
}

iivw_qa_summary, name(validation_fixture_qa29_balance) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed'")
