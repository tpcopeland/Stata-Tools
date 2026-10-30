*! validation_fixture_qa29_exogtest.do — A3 operator cells and export boundaries for iivw_exogtest
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Each cell builds qa_fx_a3_seq with one operator, reads the rows as an
* irregular-visit panel (id, visit time period, follow-up to maxfu(4) or to a
* per-subject fu_end), and checks iivw_exogtest against a hand-built
* Andersen-Gill risk set refitted with stcox (_q29_exog_oracle). Refusals
* assert the exact rc and an unchanged session (qa_state_compare). The export
* cells sweep decimals() and font() through qa_option_domain and read the
* rendered workbook cell. The theme() cell pins the removed option on a
* synthetic fixture.
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

**# E01: separate -- a subgroup whose visit schedule carries no information
* With no primary events in xcat 3, every xcat 3 subject is seen at every
* period, so at each event time the whole risk set visits: each cluster's
* score is zero and the robust variance is zero. That group's test is
* unknown, its term statistics are missing, and it must not reach r(min_p).
local ++test_count
capture noisily {
    tempname R
    * expect: DEGRADED-DECLARED
    qa_fx_a3_seq, clear seed(`seed') perturb(separate)
    assert r(sep_level) == 3
    quietly count if sep == 1 & (y == 1 | c == 1 | comp == 1)
    assert r(N) == 0
    tempvar nr
    quietly bysort id: gen int `nr' = _N
    quietly count if sep == 1 & `nr' != 4
    assert r(N) == 0
    drop `nr'
    iivw_exogtest l_t, id(id) time(period) maxfu(4) by(sep) nolog
    matrix `R' = r(results)
    assert r(n_models) == 2 & r(n_unknown) == 1 & r(n_skipped) == 0
    assert "`r(unknown_label_1)'" == "1"
    assert rowsof(`R') == 2 & `R'[2, 1] == 2
    assert missing(`R'[2, 5]) & missing(`R'[2, 6]) & missing(`R'[2, 8]) & missing(`R'[2, 9])
    assert !missing(`R'[1, 6], r(min_p)) & reldif(r(min_p), `R'[1, 6]) < 1e-15
    _q29_exog_check l_t, endpoint(4) cond(sep == 0) rrows(1)
    drop _iivw_exog_l_t_lag1
    * The separated subgroup's lagged outcome has no variation: refused.
    qa_state_snapshot, tag(e01)
    capture noisily iivw_exogtest y if sep == 1, id(id) time(period) maxfu(4) nolog
    assert _rc == 2000
    capture confirm variable _iivw_exog_y_lag1
    assert _rc == 111
    qa_state_compare, tag(e01)
}
if _rc == 0 {
    display as result "  PASS: E01 separate: uninformative group declared unknown, other group exact"
    local ++pass_count
}
else {
    display as error "  FAIL: E01 separate (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E01"
}

**# E02: separate(switch) -- a by() arm constant within id only under the operator
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear seed(`seed')
    tempvar chg
    quietly bysort id (period): gen byte `chg' = (a != a[1])
    quietly count if `chg' & xcat == 3
    assert r(N) > 0 & !missing(r(N))
    drop `chg'
    qa_state_snapshot, tag(e02f)
    capture noisily iivw_exogtest l_t if xcat == 3, id(id) time(period) maxfu(4) by(a) nolog
    assert _rc == 198
    qa_state_compare, tag(e02f)
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(separate(switch))
    quietly bysort id (period): gen byte `chg' = (a != a[1])
    quietly count if `chg' & sep == 1
    assert r(N) == 0
    drop `chg'
    iivw_exogtest l_t if sep == 1, id(id) time(period) maxfu(4) by(a) nolog
    _q29_exog_check l_t, endpoint(4) by(a) cond(sep == 1)
}
if _rc == 0 {
    display as result "  PASS: E02 separate(switch): by(a) accepted only when constant, per-arm oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: E02 separate(switch) (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E02"
}

**# E03: separate(censor) -- per-subject censor(), ends on and after the last visit
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
    iivw_exogtest l_t, id(id) time(period) censor(fu_end) by(xcat) nolog
    assert r(N) == `n_rows' - `n_ids' + `n_term'
    _q29_exog_check l_t, endpoint(fu_end) by(xcat)
}
if _rc == 0 {
    display as result "  PASS: E03 separate(censor): terminal intervals exactly where fu_end > last visit"
    local ++pass_count
}
else {
    display as error "  FAIL: E03 separate(censor) (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E03"
}

**# E04: separate_time -- no outcome at period 1, outcome as adjust()
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(separate_time)
    quietly count if y == 1 & period == 1
    assert r(N) == 0
    quietly count if y == 1
    assert r(N) > 0 & !missing(r(N))
    iivw_exogtest l_t, id(id) time(period) maxfu(4) adjust(y) nolog
    _q29_exog_check l_t, endpoint(4) adjust(y)
}
if _rc == 0 {
    display as result "  PASS: E04 separate_time: adjusted model equals the hand risk set"
    local ++pass_count
}
else {
    display as error "  FAIL: E04 separate_time (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E04"
}

**# E05: absorb -- the period-0-treated arm has at most two visits per subject
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(absorb)
    quietly bysort id (period): gen byte a0 = a[1]
    tempvar ny
    quietly bysort id: egen `ny' = total(y)
    quietly count if a0 == 1 & (`ny' != 1 | period > 1)
    assert r(N) == 0
    drop `ny'
    iivw_exogtest l_t, id(id) time(period) maxfu(4) by(a0) nolog
    _q29_exog_check l_t, endpoint(4) by(a0)
}
if _rc == 0 {
    display as result "  PASS: E05 absorb: per-arm oracle with an absorbed arm"
    local ++pass_count
}
else {
    display as error "  FAIL: E05 absorb (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E05"
}

**# E06: gap -- a missing visit makes one interval span two periods
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(gap)
    local ngap = r(perturb_n_gap)
    assert `ngap' > 0 & !missing(`ngap')
    tempvar span
    quietly bysort id (period): gen double `span' = period - period[_n - 1]
    quietly count if `span' == 2
    assert r(N) == `ngap'
    drop `span'
    iivw_exogtest l_t, id(id) time(period) maxfu(4) by(xcat) nolog
    _q29_exog_check l_t, endpoint(4) by(xcat)
}
if _rc == 0 {
    display as result "  PASS: E06 gap: two-period intervals in the hand risk set"
    local ++pass_count
}
else {
    display as error "  FAIL: E06 gap (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E06"
}

**# E07: dup_key -- a duplicated (id, time) row is refused before any change
local ++test_count
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear seed(`seed') perturb(dup_key)
    quietly duplicates report id period
    assert r(N) - r(unique_value) == 1
    qa_state_snapshot, tag(e07)
    capture noisily iivw_exogtest l_t, id(id) time(period) maxfu(4) nolog
    assert _rc == 198
    capture confirm variable _iivw_exog_l_t_lag1
    assert _rc == 111
    qa_state_compare, tag(e07)
}
if _rc == 0 {
    display as result "  PASS: E07 dup_key: rc 198, no lag column, state unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: E07 dup_key (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E07"
}

**# E08: single_period -- one visit per subject leaves no visit event to model
local ++test_count
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear seed(`seed') perturb(single_period)
    quietly summarize period
    assert r(min) == 0 & r(max) == 0
    qa_state_snapshot, tag(e08)
    capture noisily iivw_exogtest l_t, id(id) time(period) maxfu(4) nolog
    assert _rc == 2000
    capture confirm variable _iivw_exog_l_t_lag1
    assert _rc == 111
    qa_state_compare, tag(e08)
}
if _rc == 0 {
    display as result "  PASS: E08 single_period: rc 2000, state unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: E08 single_period (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E08"
}

**# E09: miss_partial -- missing adjust() values drop intervals, and say so
local ++test_count
capture noisily {
    * expect: DEGRADED-DECLARED
    qa_fx_a3_seq, clear seed(`seed') perturb(miss_partial)
    assert r(perturb_n_miss_partial) > 0 & !missing(r(perturb_n_miss_partial))
    * Population count of dropped intervals, from the operator's design: each
    * period >= 1 row of a mod(id, 7) == 0 subject ends a modeled interval,
    * and its terminal interval copies the last row's missing l0.
    quietly count if mod(id, 7) == 0 & period >= 1
    local n_rowmiss = r(N)
    tempvar last
    quietly bysort id (period): gen byte `last' = (_n == _N)
    quietly count if `last' & mod(id, 7) == 0 & period >= 1
    local n_termmiss = r(N)
    * Every subject has a terminal interval (last period < maxfu 4), so the
    * complete data carry one modeled interval per row: N rows less n ids
    * first visits, plus n ids terminal intervals.
    quietly summarize period
    assert r(max) < 4
    quietly count
    local n_rows = r(N)
    drop `last'
    iivw_exogtest l_t, id(id) time(period) maxfu(4) adjust(l0) nolog
    assert r(n_excluded_missing) == `n_rowmiss' + `n_termmiss'
    assert r(N) == `n_rows' - `n_rowmiss' - `n_termmiss'
    _q29_exog_check l_t, endpoint(4) adjust(l0)
}
if _rc == 0 {
    display as result "  PASS: E09 miss_partial: declared exclusion count and exact complete-case fit"
    local ++pass_count
}
else {
    display as error "  FAIL: E09 miss_partial (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E09"
}

**# E10: codes_multidigit -- by() levels 1 11 111 map to the same groups as 1 2 3
local ++test_count
capture noisily {
    tempname R0 R1
    qa_fx_a3_seq, clear seed(`seed')
    iivw_exogtest l_t, id(id) time(period) maxfu(4) by(xcat) nolog
    matrix `R0' = r(results)
    assert "`r(group_label_1)' `r(group_label_2)' `r(group_label_3)'" == "1 2 3"
    * expect: INVARIANT
    qa_fx_a3_seq, clear seed(`seed') perturb(codes_multidigit)
    quietly levelsof xcat, local(codes)
    assert "`codes'" == "1 11 111"
    iivw_exogtest l_t, id(id) time(period) maxfu(4) by(xcat) nolog
    matrix `R1' = r(results)
    assert "`r(group_label_1)' `r(group_label_2)' `r(group_label_3)'" == "1 11 111"
    assert !matmissing(`R0') & !matmissing(`R1')
    assert mreldif(`R0', `R1') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: E10 codes_multidigit: identical results, exact label mapping"
    local ++pass_count
}
else {
    display as error "  FAIL: E10 codes_multidigit (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E10"
}

**# E11: prefix_collision -- a user column holding the generated lag name
local ++test_count
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear seed(`seed') perturb(prefix_collision) collide(_iivw_exog_l_t_lag1)
    quietly count if _iivw_exog_l_t_lag1 == 999
    assert r(N) == _N
    qa_state_snapshot, tag(e11)
    capture noisily iivw_exogtest l_t, id(id) time(period) maxfu(4) nolog
    assert _rc == 110
    qa_state_compare, tag(e11) keep
    * replace may overwrite only an iivw-owned lag column, never this one.
    capture noisily iivw_exogtest l_t, id(id) time(period) maxfu(4) replace nolog
    assert _rc == 110
    qa_state_compare, tag(e11) keep
    quietly count if _iivw_exog_l_t_lag1 == 999
    assert r(N) == _N
    qa_state_drop, tag(e11)
}
if _rc == 0 {
    display as result "  PASS: E11 prefix_collision: rc 110 with and without replace, column intact"
    local ++pass_count
}
else {
    display as error "  FAIL: E11 prefix_collision (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E11"
}

**# E12: singleton_clusters -- id(cl) with cl = id equals id(id)
local ++test_count
capture noisily {
    tempname R0 R1
    * expect: INVARIANT
    qa_fx_a3_seq, clear seed(`seed') perturb(singleton_clusters)
    assert cl == id
    iivw_exogtest l_t, id(id) time(period) maxfu(4) by(xcat) nolog
    matrix `R0' = r(results)
    local n0 = r(n_ids)
    drop _iivw_exog_l_t_lag1
    iivw_exogtest l_t, id(cl) time(period) maxfu(4) by(xcat) nolog
    matrix `R1' = r(results)
    assert r(n_ids) == `n0' & "`r(id)'" == "cl"
    assert !matmissing(`R0') & !matmissing(`R1')
    assert mreldif(`R0', `R1') < 1e-12
    _q29_exog_check l_t, endpoint(4) by(xcat) idvar(cl)
}
if _rc == 0 {
    display as result "  PASS: E12 singleton_clusters: id(cl) == id(id), hand oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: E12 singleton_clusters (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E12"
}

**# E13: extreme_weight -- an extreme covariate value (1e4) in adjust()
local ++test_count
capture noisily {
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed') perturb(extreme_weight)
    quietly summarize w
    assert r(max) == 1e4 & r(min) == 1
    iivw_exogtest l_t, id(id) time(period) maxfu(4) adjust(w) nolog
    _q29_exog_check l_t, endpoint(4) adjust(w)
}
if _rc == 0 {
    display as result "  PASS: E13 extreme_weight: hand oracle with w = 1e4 in adjust()"
    local ++pass_count
}
else {
    display as error "  FAIL: E13 extreme_weight (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E13"
}

**# E14: boundary_values:decimals -- 0 and 6 render exactly; outside values refuse
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear seed(`seed')
    _q29_exog_oracle l_t, endpoint(4)
    scalar _q29_val = exp(_q29_O[1, 2])
    tempfile stub
    local wb "`stub'_e14.xlsx"
    foreach d in 0 6 {
        qa_option_domain, command(iivw_exogtest l_t, id(id) time(period) maxfu(4) generate(_q29x_) replace nolog decimals(@v@) xlsx("`wb'") sheet(Q29)) inside(`d') check(_q29_xcheck exogeneity `d' _q29_val "`wb'" Arial)
        assert r(n_cells) == 1 & r(n_violations) == 0
    }
    local wbo "`stub'_e14o.xlsx"
    qa_option_domain, command(iivw_exogtest l_t, id(id) time(period) maxfu(4) generate(_q29x_) replace nolog decimals(@v@) xlsx("`wbo'") sheet(Q29)) inside(4) outside(-1;7;2.5;.;abc)
    assert r(n_cells) == 6 & r(n_violations) == 0
    capture erase "`wbo'"
    capture noisily iivw_exogtest l_t, id(id) time(period) maxfu(4) generate(_q29x_) replace nolog decimals(7) xlsx("`wbo'") sheet(Q29)
    assert _rc == 198
    capture confirm file "`wbo'"
    assert _rc == 601
    scalar drop _q29_val
}
if _rc == 0 {
    display as result "  PASS: E14 decimals(): 0 and 6 exact text, -1 7 2.5 . abc refused"
    local ++pass_count
}
else {
    display as error "  FAIL: E14 boundary_values:decimals (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E14"
}

**# E15: boundary_values:font -- empty, one-character and long family names
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear seed(`seed')
    _q29_exog_oracle l_t, endpoint(4)
    scalar _q29_val = exp(_q29_O[1, 2])
    tempfile stub
    local wb "`stub'_e15.xlsx"
    local long "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDE"
    * An empty family name falls back to the documented default, Arial.
    qa_option_domain, command(iivw_exogtest l_t, id(id) time(period) maxfu(4) generate(_q29x_) replace nolog font("@v@") decimals(6) xlsx("`wb'") sheet(Q29)) inside(;) check(_q29_xcheck exogeneity 6 _q29_val "`wb'" Arial)
    assert r(n_cells) == 2 & r(n_violations) == 0
    qa_option_domain, command(iivw_exogtest l_t, id(id) time(period) maxfu(4) generate(_q29x_) replace nolog font("@v@") decimals(6) xlsx("`wb'") sheet(Q29)) inside(X) check(_q29_xcheck exogeneity 6 _q29_val "`wb'" X)
    assert r(n_cells) == 1 & r(n_violations) == 0
    qa_option_domain, command(iivw_exogtest l_t, id(id) time(period) maxfu(4) generate(_q29x_) replace nolog font("@v@") decimals(6) xlsx("`wb'") sheet(Q29)) inside(`long') check(_q29_xcheck exogeneity 6 _q29_val "`wb'" `long')
    assert r(n_cells) == 1 & r(n_violations) == 0
    * A 32-character family is refused: an Excel workbook stores at most 31.
    _q29_refusal, command(iivw_exogtest l_t, id(id) time(period) maxfu(4) generate(_q29x_) replace nolog font("`long'F") decimals(6) xlsx("`wb'") sheet(Q29)) rc(198) cause("font() must be at most 31 characters") workbook(`wb')
    * Refused before any computation: no lag column was created.
    capture confirm variable _q29x_l_t_lag1
    assert _rc == 111
    * fontsize(): 1 and 72 render exactly; 0 and 73 refuse with the message.
    foreach fs in 1 72 {
        qa_option_domain, command(iivw_exogtest l_t, id(id) time(period) maxfu(4) generate(_q29x_) replace nolog fontsize(@v@) decimals(6) xlsx("`wb'") sheet(Q29)) inside(`fs') check(_q29_xsize "`wb'" `fs')
        assert r(n_cells) == 1 & r(n_violations) == 0
    }
    foreach fs in 0 73 {
        _q29_refusal, command(iivw_exogtest l_t, id(id) time(period) maxfu(4) generate(_q29x_) replace nolog fontsize(`fs') decimals(6) xlsx("`wb'") sheet(Q29)) rc(198) cause("fontsize() must be between 1 and 72") workbook(`wb')
    }
    scalar drop _q29_val
}
if _rc == 0 {
    display as result "  PASS: E15 font() empty/X/31 chars exact, 32 refused; fontsize() 1 72 exact, 0 73 refused"
    local ++pass_count
}
else {
    display as error "  FAIL: E15 boundary_values:font (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E15"
}

**# E16: theme() on a synthetic fixture -- the removed option is refused unchanged
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear seed(`seed')
    qa_state_snapshot, tag(e16)
    capture noisily iivw_exogtest l_t, id(id) time(period) maxfu(4) nolog theme(lancet)
    assert _rc == 198
    capture confirm variable _iivw_exog_l_t_lag1
    assert _rc == 111
    qa_state_compare, tag(e16)
    * The same call without theme() runs and matches the hand oracle.
    iivw_exogtest l_t, id(id) time(period) maxfu(4) nolog
    _q29_exog_check l_t, endpoint(4)
}
if _rc == 0 {
    display as result "  PASS: E16 theme(): rc 198 and no change; control call matches the oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: E16 theme() (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E16"
}

**# E17-E19 share these helpers
* Rows: lines of the log at path holding text.
capture program drop _q29_logcount
program define _q29_logcount, rclass
    version 16.0
    args path text
    tempname fh
    local n = 0
    file open `fh' using `"`path'"', read text
    file read `fh' line
    while !r(eof) {
        if strpos(`"`macval(line)'"', `"`text'"') local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

* The seq fixture with an extra visit half a period after the terminal
* primary event of odd-id xcat 1 subjects. In xcat 1 a lagged event is then
* followed by a visit for some subjects and by none for others, so neither
* sign of the lag puts every visit at the extreme of its risk set: a finite
* maximum. (Augmenting every such subject makes each lagged event a visit,
* which separates in the other direction.) xcat 2 and 3 keep "no visit after
* an event".
capture program drop _q29_break_xcat1
program define _q29_break_xcat1
    version 16.0
    recast double period
    tempvar last aug
    quietly bysort id (period): gen byte `last' = (_n == _N)
    quietly expand 2 if `last' & y == 1 & xcat == 1 & mod(id, 2) == 1, gen(`aug')
    quietly replace period = period + 0.5 if `aug'
    quietly replace y = 0 if `aug'
    quietly count if `aug'
    assert r(N) > 0 & !missing(r(N))
    drop `last' `aug'
    sort id period
end

**# E17: separate (monotone likelihood) -- a lagged outcome never followed by a visit
* In the seq fixture a primary event ends the trajectory, so a lagged event
* is never followed by another visit in any group: the partial likelihood
* has no finite maximum. stcox still returned b = -38, se = 0.21, p = 0.
local ++test_count
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear seed(`seed')
    tempvar nxt
    quietly bysort id (period): gen byte `nxt' = (y == 1 & _n < _N)
    quietly count if `nxt'
    assert r(N) == 0
    drop `nxt'
    tempfile clog
    qa_state_snapshot, tag(e17)
    log using `clog', name(q29e17) text replace nomsg
    capture noisily iivw_exogtest y, id(id) time(period) maxfu(4) by(xcat) nolog
    local erc = _rc
    log close q29e17
    assert `erc' == 2000
    qa_state_compare, tag(e17)
    _q29_logcount `clog' "Diverging: _iivw_exog_y_lag1."
    assert r(n) == 3
}
if _rc == 0 {
    display as result "  PASS: E17 monotone likelihood: every group withheld, rc 2000, state unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: E17 monotone likelihood (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E17"
}

**# E18: separate (monotone likelihood) beside a near-extreme finite group
* xcat 1 is the negative control: a strong but finite association whose
* row must equal the hand risk-set refit, interval included.
local ++test_count
capture noisily {
    tempname R
    * expect: DEGRADED-DECLARED
    qa_fx_a3_seq, clear seed(`seed')
    _q29_break_xcat1
    tempfile clog
    log using `clog', name(q29e18) text replace nomsg
    capture noisily iivw_exogtest y, id(id) time(period) maxfu(4) by(xcat) nolog
    local erc = _rc
    * log close is r-class: copy the results before it runs.
    matrix `R' = r(results)
    local rr n_models n_monotone n_unknown n_tests min_p holm_min_p joint_min_p
    foreach k of local rr {
        local r_`k' = r(`k')
    }
    local ul "`r(unknown_label_1)' `r(unknown_label_2)'"
    log close q29e18
    assert `erc' == 0
    assert `r_n_models' == 3 & `r_n_monotone' == 2 & `r_n_unknown' == 2 & `r_n_tests' == 1
    assert "`ul'" == "2 3"
    forvalues i = 2/3 {
        assert missing(`R'[`i', 5]) & missing(`R'[`i', 6]) & missing(`R'[`i', 7])
        assert missing(`R'[`i', 8]) & missing(`R'[`i', 9])
    }
    assert !missing(`R'[1, 6], `R'[1, 8], `R'[1, 9]) & `R'[1, 8] > 0 & `R'[1, 9] < 1
    assert !missing(`r_min_p') & reldif(`r_min_p', `R'[1, 6]) < 1e-12
    assert !missing(`r_holm_min_p', `r_joint_min_p') & reldif(`r_holm_min_p', `r_joint_min_p') < 1e-12
    * The oracle reads r(results); put the command's results back first.
    iivw_exogtest y, id(id) time(period) maxfu(4) by(xcat) nolog replace
    _q29_exog_check y, endpoint(4) cond(xcat == 1) rrows(1)
    _q29_logcount `clog' "Diverging: _iivw_exog_y_lag1."
    assert r(n) == 2
}
if _rc == 0 {
    display as result "  PASS: E18 monotone groups withheld; finite near-extreme group exact"
    local ++pass_count
}
else {
    display as error "  FAIL: E18 monotone beside finite (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E18"
}

**# E19: separate (monotone likelihood) in a combination of two lags only
* u varies within every risk set and v1 = y + u does too, so neither lag
* separates by itself (a one-term screen passes both), but v1 - u = y does.
local ++test_count
capture noisily {
    tempname R
    * expect: DEGRADED-DECLARED
    qa_fx_a3_seq, clear seed(`seed')
    _q29_break_xcat1
    quietly gen byte u = mod(id * 7 + round(2 * period) * 3, 2)
    quietly gen byte v1 = y + u
    tempfile clog
    local ls = c(linesize)
    set linesize 200
    log using `clog', name(q29e19) text replace nomsg
    capture noisily iivw_exogtest v1 u, id(id) time(period) maxfu(4) by(xcat) nolog
    local erc = _rc
    matrix `R' = r(results)
    local rr n_models n_monotone n_unknown min_p
    foreach k of local rr {
        local r_`k' = r(`k')
    }
    log close q29e19
    set linesize `ls'
    assert `erc' == 0
    assert `r_n_models' == 3 & `r_n_monotone' == 2 & `r_n_unknown' == 2
    assert rowsof(`R') == 6
    forvalues i = 3/6 {
        assert missing(`R'[`i', 5]) & missing(`R'[`i', 6]) & missing(`R'[`i', 8]) & missing(`R'[`i', 9])
    }
    assert !missing(`R'[1, 6], `R'[2, 6])
    tempname mp
    scalar `mp' = min(`R'[1, 6], `R'[2, 6])
    assert !missing(`r_min_p', scalar(`mp')) & reldif(`r_min_p', scalar(`mp')) < 1e-12
    _q29_logcount `clog' "Diverging: _iivw_exog_v1_lag1 _iivw_exog_u_lag1."
    assert r(n) == 2
    * Each lag alone has a finite maximum in every group: nothing withheld.
    drop _iivw_exog_v1_lag1 _iivw_exog_u_lag1
    iivw_exogtest u, id(id) time(period) maxfu(4) by(xcat) nolog
    assert r(n_monotone) == 0 & r(n_unknown) == 0
    _q29_exog_check u, endpoint(4) by(xcat)
}
if _rc == 0 {
    display as result "  PASS: E19 two-lag combination detected; single lag left exact"
    local ++pass_count
}
else {
    display as error "  FAIL: E19 multivariable monotone likelihood (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E19"
}

**# E20: miss_partial on first visits -- a first visit is never an excluded interval
* First visits at time 1 (period + 1) give the first row a positive-length
* (0, 1] span. It has no lagged value by design, so its missing adjust()
* value must not be counted in r(n_excluded_missing).
local ++test_count
capture noisily {
    * expect: DEGRADED-DECLARED
    qa_fx_a3_seq, clear seed(`seed') perturb(miss_partial)
    quietly replace period = period + 1
    tempvar first
    quietly bysort id (period): gen byte `first' = (_n == 1)
    quietly gen double a1 = l0
    quietly replace a1 = . if `first' & mod(id, 3) == 0
    quietly replace a1 = l0 if !`first'
    quietly replace a1 = 0 if missing(a1) & !`first'
    quietly count if missing(a1) & `first'
    assert r(N) > 0 & !missing(r(N))
    quietly count if missing(a1) & !`first'
    assert r(N) == 0
    * A one-visit subject's terminal interval copies that first row, so its
    * missing adjust() value excludes the terminal interval: those, and only
    * those, are counted.
    tempvar nv
    quietly bysort id: gen int `nv' = _N
    quietly count if `first' & missing(a1) & `nv' == 1
    local n_excl = r(N)
    quietly count
    local n_rows = r(N)
    drop `first' `nv'
    iivw_exogtest l_t, id(id) time(period) maxfu(5) adjust(a1) nolog
    assert r(n_excluded_missing) == `n_excl'
    assert r(N) == `n_rows' - `n_excl'
    _q29_exog_check l_t, endpoint(5) adjust(a1)
}
if _rc == 0 {
    display as result "  PASS: E20 first-visit missing adjust() not counted as excluded"
    local ++pass_count
}
else {
    display as error "  FAIL: E20 first-visit exclusion count (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E20"
}

**# E21: miss_partial after maxfu() -- a visit beyond follow-up is refused even with missing adjust()
local ++test_count
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear seed(`seed') perturb(miss_partial)
    recast double period
    quietly gen double a1 = l0
    quietly replace a1 = 0 if missing(a1)
    * One extra visit at 3.75, adjust() missing, for the first subject seen
    * at period 3.
    quietly summarize id if period == 3, meanonly
    local xid = r(min)
    quietly expand 2 if id == `xid' & period == 3, gen(_q29x)
    quietly count if _q29x
    assert r(N) == 1
    quietly replace period = 3.75 if _q29x
    quietly replace a1 = . if _q29x
    drop _q29x
    sort id period
    qa_state_snapshot, tag(e21)
    _q29_refusal, command(iivw_exogtest l_t, id(id) time(period) maxfu(3.5) adjust(a1) nolog) rc(198) cause("occur after maxfu(3.5)") workbook(q29_none.xlsx)
    qa_state_compare, tag(e21)
}
if _rc == 0 {
    display as result "  PASS: E21 visit after maxfu() with missing adjust() refused rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: E21 maxfu with missing adjust() (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E21"
}

**# E22: scale sweep -- inference does not depend on a lag's units
* z = l_t * scale for scale 1 to 1e12, beside l0. z, p and the omnibus test
* are identical; b and se scale by exactly 1/scale.
local ++test_count
capture noisily {
    tempname R0 R1 S0 S1
    * expect: INVARIANT
    qa_fx_a3_seq, clear seed(`seed')
    local first 1
    foreach sc in 1 1e5 1e9 1e12 {
        capture drop z _iivw_exog_z_lag1 _iivw_exog_l0_lag1
        quietly gen double z = l_t * `sc'
        iivw_exogtest z l0, id(id) time(period) maxfu(4) nolog
        matrix `R1' = r(results)
        matrix `S1' = (r(min_p), r(joint_min_p), r(n_unknown), r(N))
        assert !matmissing(`R1') & !matmissing(`S1')
        if `first' {
            matrix `R0' = `R1'
            matrix `S0' = `S1'
            local first 0
            continue
        }
        assert mreldif(`S0', `S1') < 1e-9
        * z and p of both terms; b and se of the scaled term times scale;
        * b, se, HR and CI of l0 unchanged (matmissing was ruled out above).
        tempname Q0 Q1
        matrix `Q0' = (`R0'[1, 5], `R0'[1, 6], `R0'[2, 5], `R0'[2, 6], ///
            `R0'[1, 3], `R0'[1, 4], `R0'[2, 3], `R0'[2, 4], `R0'[2, 8], `R0'[2, 9])
        matrix `Q1' = (`R1'[1, 5], `R1'[1, 6], `R1'[2, 5], `R1'[2, 6], ///
            `R1'[1, 3] * `sc', `R1'[1, 4] * `sc', `R1'[2, 3], `R1'[2, 4], `R1'[2, 8], `R1'[2, 9])
        assert !matmissing(`Q0') & !matmissing(`Q1')
        assert mreldif(`Q0', `Q1') < 1e-9
    }
    * The single-term model at 1e12 is a valid fit, not a refusal.
    drop _iivw_exog_z_lag1 _iivw_exog_l0_lag1
    iivw_exogtest z, id(id) time(period) maxfu(4) nolog
    assert r(n_models) == 1 & r(n_unknown) == 0 & !missing(r(min_p), r(joint_min_p))
}
if _rc == 0 {
    display as result "  PASS: E22 z, p and omnibus identical from scale 1 to 1e12"
    local ++pass_count
}
else {
    display as error "  FAIL: E22 scale sweep (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E22"
}

**# E23: a legitimate lag beside a collinear (omitted) one
* l2 = 2 * l_t: stcox omits the second lag. The first is the single-lag fit,
* the second is missing, and the omnibus test is the 1-df test of l_t.
local ++test_count
capture noisily {
    tempname R
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed')
    quietly gen double l2 = 2 * l_t
    iivw_exogtest l_t l2, id(id) time(period) maxfu(4) nolog
    matrix `R' = r(results)
    local jp = r(joint_min_p)
    assert r(n_unknown) == 0 & rowsof(`R') == 2
    assert missing(`R'[2, 5]) & missing(`R'[2, 6]) & missing(`R'[2, 8]) & missing(`R'[2, 9])
    assert !missing(`R'[1, 6], `jp') & reldif(`jp', `R'[1, 6]) < 1e-9
    _q29_exog_check l_t, endpoint(4) rrows(1)
}
if _rc == 0 {
    display as result "  PASS: E23 legitimate lag exact beside an omitted collinear lag"
    local ++pass_count
}
else {
    display as error "  FAIL: E23 legitimate beside omitted (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E23"
}

**# E24: a well-estimated two-lag fit on continuous visit times is not flagged
* Replicate 378 of cell B in validation_iivw_exogtest_recovery.do (seed
* 20261015; 400 one-lag draws, then two-lag draws, gamma = (0.4, -0.3)):
* z = 20 and -14 on 2,377 visits. An early detector accepted a tiny interior
* LP direction there as a verified recession direction and withheld the fit.
local ++test_count
capture noisily {
    tempname R
    * expect: EXACT
    do _iivw_exogtest_dgp.do
    set seed 20261015
    forvalues r = 1/400 {
        quietly iivw_exog_dgp, groups(1) n(500) gammas(.4)
    }
    forvalues r = 1/378 {
        quietly iivw_exog_dgp, groups(1) n(500) gammas(.4) gammatwo(-.3)
    }
    iivw_exogtest y y2, id(id) time(time) maxfu(5) nolog
    matrix `R' = r(results)
    assert r(n_monotone) == 0 & r(n_unknown) == 0 & r(n_models) == 1
    assert !matmissing(`R')
    assert abs(`R'[1, 5]) > 10 & abs(`R'[2, 5]) > 10
}
if _rc == 0 {
    display as result "  PASS: E24 continuous-time two-lag fit reported, not withheld"
    local ++pass_count
}
else {
    display as error "  FAIL: E24 two-lag continuous fit (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E24"
}

**# E25: separate -- a separated lag beside rows that start exactly at an event time
* v = y, except that subjects seen through period 3 without an event carry
* v = -1 at that last visit, so only their terminal interval (3, 4], which
* starts AT event time 3, holds the low value. A row is at risk at t only when
* its start < t, so the separation (every visit at the lowest lag of its risk
* set) holds; counting that row at t = 3 would hide it.
local ++test_count
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear seed(`seed') perturb(separate)
    tempvar last
    quietly bysort id (period): gen byte `last' = (_n == _N)
    quietly gen double v = y
    quietly replace v = -1 if `last' & period == 3 & y == 0
    quietly count if v == -1
    assert r(N) > 0 & !missing(r(N))
    drop `last'
    tempfile clog
    qa_state_snapshot, tag(e25)
    log using `clog', name(q29e25) text replace nomsg
    capture noisily iivw_exogtest v, id(id) time(period) maxfu(4) nolog
    local erc = _rc
    log close q29e25
    assert `erc' == 2000
    qa_state_compare, tag(e25)
    _q29_logcount `clog' "Diverging: _iivw_exog_v_lag1."
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: E25 separation with rows starting at an event time detected"
    local ++pass_count
}
else {
    display as error "  FAIL: E25 risk-set start boundary (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E25"
}

**# E26: a flat (non-strict) direction -- an exact copy of a lag is not monotone
local ++test_count
capture noisily {
    tempname R R1
    * expect: EXACT
    qa_fx_a3_seq, clear seed(`seed')
    quietly gen double lcopy = l_t
    iivw_exogtest l_t, id(id) time(period) maxfu(4) nolog
    matrix `R1' = r(results)
    iivw_exogtest l_t lcopy, id(id) time(period) maxfu(4) nolog replace
    matrix `R' = r(results)
    assert r(n_monotone) == 0 & r(n_unknown) == 0 & rowsof(`R') == 2
    assert missing(`R'[2, 5]) & missing(`R'[2, 6])
    tempname Q0 Q1
    matrix `Q0' = `R1'[1, 3..9]
    matrix `Q1' = `R'[1, 3..9]
    assert !matmissing(`Q0') & !matmissing(`Q1') & mreldif(`Q0', `Q1') < 1e-12
    _q29_exog_check l_t, endpoint(4) rrows(1)
}
if _rc == 0 {
    display as result "  PASS: E26 exact lag copy (flat direction) not flagged; first lag exact"
    local ++pass_count
}
else {
    display as error "  FAIL: E26 flat direction (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E26"
}

**# E27: a constant adjust() term changes nothing
local ++test_count
capture noisily {
    tempname R0 R1
    * expect: INVARIANT
    qa_fx_a3_seq, clear seed(`seed')
    quietly gen double cst = 3
    iivw_exogtest l_t, id(id) time(period) maxfu(4) nolog
    matrix `R0' = r(results)
    local p0 = r(joint_min_p)
    iivw_exogtest l_t, id(id) time(period) maxfu(4) adjust(cst) nolog replace
    matrix `R1' = r(results)
    assert r(n_unknown) == 0 & r(n_monotone) == 0
    assert !missing(`p0', r(joint_min_p)) & reldif(`p0', r(joint_min_p)) < 1e-12
    assert !matmissing(`R0') & !matmissing(`R1') & mreldif(`R0', `R1') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: E27 constant adjust() leaves the test unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: E27 constant adjust() (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E27"
}

**# E28: separate -- the separation runs through an adjust() term
* adjust(period): a visit at t carries period t, while the subjects at risk
* without a visit at t are on terminal intervals that copy an earlier last
* visit (period < t). Every visit is at the top of its risk set: no finite
* maximum, through the adjustment, not the lag.
local ++test_count
capture noisily {
    * expect: REFUSED
    qa_fx_a3_seq, clear seed(`seed')
    tempfile clog
    qa_state_snapshot, tag(e28)
    log using `clog', name(q29e28) text replace nomsg
    capture noisily iivw_exogtest l_t, id(id) time(period) maxfu(4) adjust(period) nolog
    local erc = _rc
    log close q29e28
    assert `erc' == 2000
    qa_state_compare, tag(e28)
    _q29_logcount `clog' "Diverging: period."
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: E28 separation through adjust() detected and named"
    local ++pass_count
}
else {
    display as error "  FAIL: E28 separation through adjust() (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E28"
}

**# E29: nearly collinear lags (y and y + 1e-9 noise) are a valid fit
* The pair differences along y2 - y are 1e-9 of the rest; the check must
* still settle (no separation: the noise has no pattern) and report the fit
* the released package reported, not withhold it.
local ++test_count
capture noisily {
    tempname R
    * expect: EXACT
    do _iivw_exogtest_dgp.do
    set seed 31
    quietly iivw_exog_dgp, groups(2) n(120) gammas(0.4 0.2) maxfu(5)
    quietly gen double near = y + 1e-9 * rnormal()
    iivw_exogtest y near, id(id) time(time) maxfu(5) nolog
    matrix `R' = r(results)
    assert r(n_unknown) == 0 & r(n_monotone) == 0 & r(n_models) == 1
    assert !missing(`R'[1, 3], `R'[2, 3], r(joint_min_p))
}
if _rc == 0 {
    display as result "  PASS: E29 nearly collinear lags settle and are reported"
    local ++pass_count
}
else {
    display as error "  FAIL: E29 nearly collinear lags (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E29"
}

**# E30-E34 share a control group: a well-estimated second by() group
capture program drop _q29_ctrl
program define _q29_ctrl
    version 16.0
    * Appends 80 subjects from the exogeneity DGP as grp == 2 (id + 1000,
    * time t, test variables y1 y2), so the command returns rc 0 and r().
    tempfile hold ctl
    quietly save `hold'
    do _iivw_exogtest_dgp.do
    set seed 41
    quietly iivw_exog_dgp, groups(1) n(80) gammas(0.3) gammatwo(0.1) maxfu(6)
    rename (time y) (t y1)
    quietly replace id = id + 1000
    quietly replace grp = 2
    keep id t y1 y2 grp
    quietly save `ctl'
    use `hold', clear
    quietly append using `ctl'
    sort id t
end

**# E30: separate -- a lag that is the wave number is flat, not monotone
* 40 subjects seen at waves 1-5: at every event time every subject at risk
* has the same lag (the previous wave), so every pair difference is zero.
* There is no strict direction (no finite-maximum failure), only no
* information.
local ++test_count
capture noisily {
    * expect: DEGRADED-DECLARED
    qa_fx_a3_seq, clear seed(`seed')
    clear
    quietly set obs 40
    gen long id = _n
    quietly expand 5
    quietly bysort id: gen double t = _n
    gen double y1 = t
    gen double y2 = 0
    gen byte grp = 1
    _q29_ctrl
    iivw_exogtest y1, id(id) time(t) maxfu(6) by(grp) nolog
    assert r(n_monotone) == 0 & r(n_models) == 2
}
if _rc == 0 {
    display as result "  PASS: E30 wave-number lag (all pairs flat) is not monotone"
    local ++pass_count
}
else {
    display as error "  FAIL: E30 flat single term (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E30"
}

**# E31: two lags whose cluster scores are complementary (z1 = -z2)
* Four subjects (the reviewer's case 176): the robust variance of the two
* lags has rank 1, so a Wald test of both cannot be formed and is withheld.
local ++test_count
capture noisily {
    * expect: DEGRADED-DECLARED
    qa_fx_a3_seq, clear seed(`seed')
    clear
    quietly set obs 11
    gen long id = cond(_n <= 3, 1, cond(_n <= 5, 2, cond(_n <= 8, 3, 4)))
    gen double t = cond(_n == 1, 1, cond(_n == 2, 4, cond(_n == 3, 5, cond(_n == 4, 4, ///
        cond(_n == 5, 5, cond(_n == 6, 1, cond(_n == 7, 2, cond(_n == 8, 4, ///
        cond(_n == 9, 1, cond(_n == 10, 3, 4))))))))))
    gen double y1 = inlist(_n, 3, 5, 6, 8, 10)
    gen double y2 = inlist(_n, 2, 4, 8, 10, 11)
    gen byte grp = 1
    _q29_ctrl
    tempfile clog
    log using `clog', name(q29e31) text replace nomsg
    iivw_exogtest y1 y2, id(id) time(t) maxfu(6) by(grp) nolog
    local nu = r(n_unknown)
    local nm = r(n_monotone)
    log close q29e31
    assert `nu' == 1 & `nm' == 0
    _q29_logcount `clog' "the omnibus test is withheld: the robust variance has no"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: E31 rank-deficient robust variance withholds the omnibus"
    local ++pass_count
}
else {
    display as error "  FAIL: E31 rank guard (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E31"
}

**# E32: a lag of -1e9 on two visits: the check may not settle, and says so
* The reviewer's case 40. Whatever the check concludes it must not claim a
* verdict it cannot support: here it reports "did not settle", which counts
* the group unknown but not monotone.
local ++test_count
capture noisily {
    * expect: DEGRADED-DECLARED
    qa_fx_a3_seq, clear seed(`seed')
    clear
    quietly set obs 11
    gen long id = cond(_n <= 2, 1, cond(_n <= 5, 2, cond(_n <= 9, 3, 4)))
    gen double t = cond(_n == 1, 2, cond(_n == 2, 5, cond(_n == 3, 2, cond(_n == 4, 3, ///
        cond(_n == 5, 5, cond(_n == 6, 1, cond(_n == 7, 2, cond(_n == 8, 4, ///
        cond(_n == 9, 5, cond(_n == 10, 3, 5))))))))))
    gen double y1 = inlist(_n, 1, 4, 7, 9, 10, 11)
    gen double y2 = cond(inlist(_n, 3, 8), -1e9, inlist(_n, 2, 4, 5))
    gen byte grp = 1
    _q29_ctrl
    tempfile clog
    log using `clog', name(q29e32) text replace nomsg
    iivw_exogtest y1 y2, id(id) time(t) maxfu(6) by(grp) nolog
    local nu = r(n_unknown)
    local nm = r(n_monotone)
    log close q29e32
    assert `nu' == 1 & `nm' == 0
    _q29_logcount `clog' "the monotone-likelihood check did not settle"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: E32 unsettled check declared: unknown, not monotone"
    local ++pass_count
}
else {
    display as error "  FAIL: E32 unsettled check (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E32"
}

**# E33: the check itself on certified extreme-scale inputs (Mata level)
* Labels certified by an exact rational cone test. A separated input may get
* "did not settle" (2) but never "finite maximum" (0).
local ++test_count
capture noisily {
    * The Mata is in memory from the exogtest calls above; load it only if not.
    capture mata: st_local("q29m", strofreal(findexternal("_iivw_cox_recession()") != NULL))
    if "`q29m'" != "1" {
        quietly findfile _iivw_mlib.ado
        run "`r(fn)'"
    }
    * heavy case 8: separated (a value of 1e12)
    clear
    quietly set obs 4
    gen double t0 = 0
    gen double t = cond(_n <= 2, 4, 3)
    gen double d = _n > 1
    gen double x1 = cond(_n == 3, 0, 2)
    gen double x2 = cond(_n == 1, 2, cond(_n == 4, 1, 0))
    gen double x3 = cond(_n == 1, 1, cond(_n == 3, 1e12, 2))
    gen byte tu = 1
    mata: st_local("s1", strofreal(_iivw_cox_recession("t0", "t", "d", "x1 x2 x3", "tu")[1]))
    assert inlist(`s1', 1, 2)
    * One strict pair among ~4.5 million flat ones (x2 = x1 except one
    * censored row at the last event time, x2 = x1 + 1e-6): separated.
    clear
    quietly set obs 3001
    gen double t0 = 0
    gen double t = cond(_n == 3001, 3000, _n)
    gen double d = _n <= 3000
    gen double x1 = mod(_n * 7919, 1009) / 1009
    gen double x2 = x1 + 1e-6 * (_n == 3001)
    gen byte tu = 1
    mata: st_local("s3", strofreal(_iivw_cox_recession("t0", "t", "d", "x1 x2", "tu")[1]))
    assert inlist(`s3', 1, 2)
    display "E33 statuses: `s1' `s3'"
}
if _rc == 0 {
    display as result "  PASS: E33 certified extreme-scale inputs: no wrong verdict"
    local ++pass_count
}
else {
    display as error "  FAIL: E33 extreme-scale verdicts (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E33"
}

**# E34: a near-copy lag that stcox omits does not enter the check
* l2 = l_t + 1e-12 * u: stcox drops it as collinear; the check must judge the
* model stcox fitted (l_t alone), so the result is the single-lag result.
local ++test_count
capture noisily {
    tempname R0 R1
    * expect: INVARIANT
    qa_fx_a3_seq, clear seed(`seed')
    quietly gen double l2 = l_t + 1e-12 * mod(id, 7)
    iivw_exogtest l_t, id(id) time(period) maxfu(4) nolog
    matrix `R0' = r(results)
    iivw_exogtest l_t l2, id(id) time(period) maxfu(4) nolog replace
    matrix `R1' = r(results)
    assert r(n_monotone) == 0 & r(n_unknown) == 0
    assert missing(`R1'[2, 5])
    tempname Q0 Q1
    matrix `Q0' = `R0'[1, 3..9]
    matrix `Q1' = `R1'[1, 3..9]
    assert !matmissing(`Q0') & !matmissing(`Q1') & mreldif(`Q0', `Q1') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: E34 omitted near-copy lag kept out of the check"
    local ++pass_count
}
else {
    display as error "  FAIL: E34 omitted near-copy lag (rc `=_rc')"
    local ++fail_count
    local failed "`failed' E34"
}

iivw_qa_summary, name(validation_fixture_qa29_exogtest) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed'")
