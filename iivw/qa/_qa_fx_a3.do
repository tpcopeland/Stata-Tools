*! qa-lib _qa_fx_a3 1.3.0 sha256:23cfd9959bb22498b873e074ddc593af69389083288c0473dc63352c66f42a32
* _qa_fx_a3.do -- archetype A3 (person-period longitudinal) fixture generator
*
* Load from a suite with: do "`qa_dir'/_qa_fx_a3.do"
*
* A fixture cannot fail by itself: it goes red through the oracle a suite
* points at it. So the generator (a) re-verifies each hostile property it
* claims and exits 9 if the draw lost it, and (b) returns the design truth in
* r() and in _dta[] chars, computed by exact dynamic programming over the
* discrete DGP -- a code path no package shares.
*
* API
*   qa_fx_a3_seq , clear [tier(micro|unit|recovery) n(#) k(#)
*       perturb(oplist) seed(#) censoring competing trials(first|sequential)
*       confounding(standard|strong) collide(namelist) names(old=new ...)]
*                                                                    rclass
*
*   F fixture (no perturb): n ids, k periods (tier defaults: micro 24 x 3,
*   unit 400 x 4, recovery 20000 x 4). Variables (canonical names):
*     id period   long/byte keys, sorted by id period
*     l0          baseline binary confounder, constant within id
*     xcat        baseline category 1 2 3, xcat = mod(id-1,3)+1 (balanced)
*     l_t         time-varying binary confounder, affected by past a
*     a           treatment 0/1; switching allowed in both directions
*     y           primary outcome 0/1 (last row of a trajectory when 1)
*     c           censoring 0/1 (all 0 unless censoring)
*     comp        competing event 0/1 (all 0 unless competing)
*     elig        1 on period 0 (trials(first)) or while never yet treated
*                 (trials(sequential))
*     cl          cluster, 5 ids per cluster
*     w           case weight, 1
*   DGP, per id and period t (expit = invlogit; lprev, aprev = 0 at t = 0):
*     l_t  ~ expit(-0.5 + 1.0 l0 + 0.8 lprev - 0.7 aprev)
*     a_0  ~ expit(-0.3 + 0.8 l_t + 0.4 l0)
*     a_t  ~ expit( 2.0 - 0.8 l_t) if aprev = 1 (stay), else
*            expit(-2.0 + 1.0 l_t)                     (start)
*     y_t  ~ expit(-3.0 - 0.7 a_t + 0.9 l_t + 0.5 l0 + 0.1 t
*                  + 0.3 [xcat=2] + 0.5 [xcat=3])
*     c_t  ~ expit(-3.0 + 0.8 l_t)      (censoring; c = 1 zeroes y and comp)
*     comp ~ expit(-3.5 + 0.4 l0)       (competing; y = 1 takes precedence)
*   (These are confounding(standard), the default. confounding(strong)
*   changes six of them; see below.)
*   A trajectory stops after its first y, c or comp row. Each id consumes a
*   fixed block of 1 + 5k uniforms whatever its length or perturbation, so an
*   F and a U fixture with the same seed differ only where the operator bites.
*
*   confounding(strong): the same DGP and parameter layout with
*     l_t  ~ expit(-0.5 + 1.0 l0 + 0.8 lprev - 1.2 aprev)
*     a_t  ~ expit( 0.0 + 3.0 l_t) if aprev = 1 (stay), else
*            expit(-3.0 + 3.0 l_t)                     (start)
*            i.e. a_t ~ expit(-3 + 3 l_t + 3 aprev) for t >= 1
*     y_t  ~ expit(-3.0 - 0.7 a_t + 1.5 l_t + ...)    (rest as above)
*   Why. In a trial-0 per-protocol analysis with grace 0 a clone is
*   censored at its first deviation, and switch weights undo the selection
*   that censoring makes. Its size is set by how strongly l_t drives the
*   deviation (l_t -> a) times how strongly l_t drives the concurrent and
*   later hazard (l_t -> y); its sign per arm by which l_t level deviates.
*   Under standard, l_t = 1 makes both starting (never arm) and stopping
*   (always arm) likelier, so both arms lose high-risk rows, both risks are
*   biased down, and the risk-difference bias nearly cancels (exact
*   nonparametric unweighted bias by DP: risk0 -.009, risk1 -.005, RD
*   +.004 at k = 4) -- too small for any single fit to tell weighted from
*   unweighted. Strong makes treatment follow l_t in both arms (log-OR 3,
*   sticky), so the never arm loses l_t = 1 rows and the always arm loses
*   l_t = 0 rows: opposite selections, so the arm biases add in the RD.
*   l_t -> y rises 0.9 -> 1.5 so the lost rows differ in risk, and
*   a -> l_t rises -0.7 -> -1.2 so l_t is more strongly affected by past
*   treatment (the arms' l_t paths and the treatment effect it carries
*   separate further). Positivity is kept by construction: adherence is
*   .953 when l_t agrees with the arm and .5 when it does not, so every
*   unstabilized switch factor is <= 2 (<= 8 over three switch periods).
*   DP at k = 4: truth risk0 .608, risk1 .330, RD -.278; nonparametric
*   unweighted bias risk0 -.055, risk1 +.046, RD +.100. Baseline treatment
*   a_0, censoring and competing parameters are unchanged, so the switch
*   weights are the only thing separating a weighted from an unweighted fit.
*
*   Truth (population: l0 ~ Bernoulli(.5), xcat uniform on its support):
*     r(truth_risk0) r(truth_risk1)  cumulative primary-outcome risk by the end
*                    of follow-up (k periods) under never / always treat from
*                    period 0, no censoring, competing event not eliminated
*     r(truth_rd) r(truth_rr)
*     r(truth_risk)  matrix k x 5: h, risk0, risk1 (population) and
*                    risk0_s, risk1_s (standardized to the realized l0 x xcat
*                    distribution of the ids -- the target of a trial-0
*                    analysis of this sample)
*     r(dgp)         the parameter vector above (as set by confounding()),
*                    named
*   Descriptive: r(N) rows, r(N_ids), r(k), r(n_events), r(tier), r(seed),
*   r(confounding), r(perturb) as requested, r(perturb_applied) as
*   applied, r(expect_class)
*   (the operator's typical class when exactly one operator is applied),
*   r(sep_level) (xcat code of the targeted subgroup), r(perturb_n) (rows
*   or ids changed, per operator: r(perturb_n_<op>)).
*   Chars: _dta[qa_fx_generator] _dta[qa_fx_version] _dta[qa_fx_seed]
*   _dta[qa_fx_perturb] _dta[qa_fx_confounding] and
*   _dta[qa_truth_risk0|risk1] (%21x).
*
*   Operators (perturb()); the targeted subgroup is xcat == 3, flagged by a
*   byte variable sep when a separate* operator is applied:
*     separate          xcat 3 has no primary events (outcome separation)
*     separate(switch)  xcat 3 never changes treatment after period 0
*     separate(censor)  xcat 3 is never censored (turns censoring on)
*     separate_time     no primary event at period 1 (needs k >= 2)
*     absorb            ids treated at period 0 stay treated, are not censored
*                       and have no competing event through period 1, and all
*                       have the primary event by period 1: S = 0 in that arm
*     noevent           no primary events at all
*     all_treated       a = 1 on every row
*     base_absent       xcat 1 ids are never eligible (truth over xcat 2 3)
*     single_period     k = 1
*     gap               period 1 dropped for 5% of ids with >= 3 rows (>= 1)
*     dup_key           one (id, period) row duplicated
*     miss_irrelevant   a and l_t missing on every row after an id's first
*                       treatment change (rows a per-protocol trial-0 analysis
*                       with grace 0 never retains)
*     miss_partial      l0 missing on period >= 1 rows of ids with mod(id,7)=0
*     unsorted          random row order
*     codes_multidigit  xcat relabelled 1 2 3 -> 1 11 111
*     codes_sparse      xcat relabelled 1 2 3 -> 1 5 17
*     prefix_collision  creates each variable in collide() (value 999)
*     singleton_clusters  cl = id
*     extreme_weight    w = 1e4 on id 1
*   The primitive operators wrap existing qa-lib helpers and are refused here
*   with a pointer (rc 198): miss_extended codes_negative codes_big long_names
*   string_hostile time_hostile scale_shift.
*
* Errors: rc 9 when a fixture lost its claimed property; rc 198 for bad
* arguments or an operator this archetype does not provide; clear required.
*
* Deliberately NOT provided: truth for later trials (only trial 0), natural-
* course truth. VISIT, TRAJ and EDSS APIs are documented below the SEQ code.

capture program drop qa_fx_a3_seq
program define qa_fx_a3_seq, rclass
    version 16.0
    return add
    syntax , CLEAR [TIER(string) N(integer 0) K(integer 0) ///
        PERTurb(string) SEED(integer 20260929) CENSoring COMPeting ///
        TRIALS(string) CONFounding(string) COLLide(namelist) NAMES(string)]

    if "`tier'" == "" local tier unit
    if !inlist("`tier'", "micro", "unit", "recovery") {
        display as error "qa_fx_a3_seq: tier() must be micro, unit or recovery"
        exit 198
    }
    if `n' == 0 local n = cond("`tier'" == "micro", 24, cond("`tier'" == "unit", 400, 20000))
    if `k' == 0 local k = cond("`tier'" == "micro", 3, 4)
    if "`trials'" == "" local trials first
    if !inlist("`trials'", "first", "sequential") {
        display as error "qa_fx_a3_seq: trials() must be first or sequential"
        exit 198
    }
    if "`confounding'" == "" local confounding standard
    if !inlist("`confounding'", "standard", "strong") {
        display as error "qa_fx_a3_seq: confounding() must be standard or strong"
        exit 198
    }
    if `n' < 3 | `k' < 1 {
        display as error "qa_fx_a3_seq: n() >= 3 and k() >= 1 required"
        exit 198
    }

    * Parse and validate the operator list.
    local known separate separate(switch) separate(censor) separate_time ///
        absorb noevent all_treated base_absent single_period gap dup_key ///
        miss_irrelevant miss_partial unsorted codes_multidigit codes_sparse ///
        prefix_collision singleton_clusters extreme_weight
    local wrapped miss_extended:qa_hostile_missing codes_negative:qa_hostile_codes ///
        codes_big:qa_hostile_codes long_names:qa_hostile_names ///
        string_hostile:qa_hostile_strings time_hostile:qa_hostile_times ///
        scale_shift:qa_shift_invariance
    local ops ""
    local rest `"`perturb'"'
    while `"`rest'"' != "" {
        gettoken op rest : rest, bind
        local op = strlower(`"`op'"')
        foreach w of local wrapped {
            gettoken wop whelp : w, parse(":")
            local whelp = substr("`whelp'", 2, .)
            if "`op'" == "`wop'" {
                display as error "qa_fx_a3_seq: `op' is a primitive operator; call `whelp' directly"
                exit 198
            }
        }
        if !`: list op in known' {
            display as error `"qa_fx_a3_seq: unknown operator `op' (A3 provides: `known')"'
            exit 198
        }
        local ops `ops' `op'
    }
    local ops : list uniq ops
    foreach op in separate separate(switch) separate(censor) separate_time ///
        absorb noevent all_treated base_absent single_period gap dup_key ///
        miss_irrelevant miss_partial unsorted codes_multidigit codes_sparse ///
        prefix_collision singleton_clusters extreme_weight {
        local f = subinstr(subinstr("`op'", "(", "_", .), ")", "", .)
        local p_`f' = `: list op in ops'
    }
    if `p_codes_multidigit' & `p_codes_sparse' {
        display as error "qa_fx_a3_seq: codes_multidigit and codes_sparse both relabel xcat"
        exit 198
    }
    if `p_prefix_collision' & "`collide'" == "" {
        display as error "qa_fx_a3_seq: prefix_collision needs collide(namelist)"
        exit 198
    }
    if `p_single_period' local k = 1
    if `p_separate_time' & `k' < 2 {
        display as error "qa_fx_a3_seq: separate_time needs k() >= 2"
        exit 198
    }
    if `p_absorb' & `k' < 2 {
        display as error "qa_fx_a3_seq: absorb needs k() >= 2"
        exit 198
    }
    if `p_separate_censor' local censoring censoring
    local cens = ("`censoring'" != "")
    local cmpt = ("`competing'" != "")

    * Validate names/collisions before clearing caller data; draws unchanged.
    local schema id period l0 xcat l_t a y c comp elig cl w
    if `p_separate' | `p_separate_switch' | `p_separate_censor' local schema `schema' sep
    if `p_prefix_collision' {
        local used ""
        foreach v of local collide {
            if `: list v in schema' | `: list v in used' {
                di as error "qa_fx_a3_seq: collide() name `v' already in fixture schema"
                exit 198
            }
            local used `used' `v'
        }
        local schema `schema' `collide'
    }
    _qa_fxa3_new_options, who(qa_fx_a3_seq) vars(`schema') known(`known') tier(`tier') seed(`seed') names(`names')

    * Parameters: one named vector feeds both the data and the truth.
    tempname P
    matrix `P' = (-0.5, 1.0, 0.8, -0.7, -0.3, 0.8, 0.4, 2.0, -0.8, -2.0, 1.0, ///
        -3.0, -0.7, 0.9, 0.5, 0.1, 0.3, 0.5, -3.0, 0.8, -3.5, 0.4)
    matrix colnames `P' = L0 L_l0 L_lprev L_aprev A0 A0_l A0_l0 Stay Stay_l ///
        Start Start_l Y0 Y_a Y_l Y_l0 Y_t Y_x2 Y_x3 C0 C_l D0 D_l0
    if "`confounding'" == "strong" {
        matrix `P'[1, colnumb(`P', "L_aprev")] = -1.2
        matrix `P'[1, colnumb(`P', "Stay")] = 0.0
        matrix `P'[1, colnumb(`P', "Stay_l")] = 3.0
        matrix `P'[1, colnumb(`P', "Start")] = -3.0
        matrix `P'[1, colnumb(`P', "Start_l")] = 3.0
        matrix `P'[1, colnumb(`P', "Y_l")] = 1.5
    }
    tempname F
    * flags: sep, sepswitch, sepcensor, septime, absorb, noevent, alltreat,
    *        base_absent, censoring, competing
    matrix `F' = (`p_separate', `p_separate_switch', `p_separate_censor', ///
        `p_separate_time', `p_absorb', `p_noevent', `p_all_treated', ///
        `p_base_absent', `cens', `cmpt')

    return clear
    clear
    set seed `seed'
    mata: _qa_fxa3_generate(`n', `k', st_matrix("`P'"), st_matrix("`F'"))
    quietly {
        compress id period
        label variable l0 "baseline binary confounder"
        label variable xcat "baseline category"
        label variable l_t "time-varying confounder"
        label variable a "treatment"
        label variable y "primary outcome"
        label variable c "censoring"
        label variable comp "competing event"
        generate byte elig = period == 0
        if "`trials'" == "sequential" {
            bysort id (period): generate int _qa_cum = sum(a)
            by id: replace elig = (_qa_cum[_n-1] == 0) if _n > 1
            drop _qa_cum
        }
        generate long cl = ceil(id / 5)
        generate double w = 1
        sort id period
    }

    * Truth by dynamic programming over (l0, xcat, l_{t-1}).
    tempname T R
    mata: _qa_fxa3_truth(`k', st_matrix("`P'"), st_matrix("`F'"), "`T'")
    local xs = cond(`p_base_absent', "2 3", "1 2 3")

    * Hostility re-checks on the generated draw, before post-processing.
    local applied ""
    if `p_separate' | `p_separate_switch' | `p_separate_censor' {
        quietly generate byte sep = xcat == 3
        label variable sep "separated subgroup (xcat 3)"
    }
    if `p_separate' {
        quietly count if xcat == 3
        local nx = r(N)
        quietly count if xcat == 3 & y == 1
        local ns = r(N)
        quietly count if y == 1
        if `nx' == 0 | `ns' > 0 | r(N) == 0 {
            display as error "qa_fx_a3_seq: separate lost its property (xcat 3 rows `nx', events `ns', all events `r(N)')"
            exit 9
        }
        local applied `applied' separate
    }
    if `p_separate_switch' {
        tempvar chg
        quietly bysort id (period): generate byte `chg' = a != a[_n-1] if _n > 1
        quietly count if xcat == 3 & `chg' == 1
        local ns = r(N)
        quietly count if xcat == 3 & period >= 1
        local nr = r(N)
        quietly count if xcat != 3 & `chg' == 1
        if `ns' > 0 | `nr' == 0 | r(N) == 0 {
            display as error "qa_fx_a3_seq: separate(switch) lost its property (switches in xcat 3: `ns', later rows `nr', switches elsewhere `r(N)')"
            exit 9
        }
        drop `chg'
        local applied `applied' separate(switch)
    }
    if `p_separate_censor' {
        quietly count if xcat == 3 & c == 1
        local ns = r(N)
        quietly count if c == 1
        if `ns' > 0 | r(N) == 0 {
            display as error "qa_fx_a3_seq: separate(censor) lost its property (censored in xcat 3: `ns', elsewhere `r(N)')"
            exit 9
        }
        local applied `applied' separate(censor)
    }
    if `p_separate_time' {
        quietly count if period == 1
        local nr = r(N)
        quietly count if period == 1 & y == 1
        local ns = r(N)
        quietly count if y == 1
        if `nr' == 0 | `ns' > 0 | r(N) == 0 {
            display as error "qa_fx_a3_seq: separate_time lost its property (period-1 rows `nr', events `ns')"
            exit 9
        }
        local applied `applied' separate_time
    }
    if `p_absorb' {
        tempvar a0 ev
        quietly bysort id (period): generate byte `a0' = a[1]
        quietly by id: egen byte `ev' = max(y == 1 & period <= 1)
        quietly count if `a0' == 1 & period == 0
        local na = r(N)
        quietly count if `a0' == 1 & period == 0 & `ev' == 0
        if `na' == 0 | r(N) > 0 {
            display as error "qa_fx_a3_seq: absorb lost its property (treated ids `na', survivors past period 1 `r(N)')"
            exit 9
        }
        drop `a0' `ev'
        local applied `applied' absorb
    }
    if `p_noevent' {
        quietly count if y == 1
        if r(N) > 0 {
            display as error "qa_fx_a3_seq: noevent lost its property"
            exit 9
        }
        local applied `applied' noevent
    }
    if `p_all_treated' {
        quietly count if a != 1
        if r(N) > 0 {
            display as error "qa_fx_a3_seq: all_treated lost its property"
            exit 9
        }
        local applied `applied' all_treated
    }
    if `p_single_period' {
        quietly count if period != 0
        if r(N) > 0 {
            display as error "qa_fx_a3_seq: single_period lost its property"
            exit 9
        }
        local applied `applied' single_period
    }

    * Post-processing operators (data only; truth unchanged).
    if `p_base_absent' {
        quietly replace elig = 0 if xcat == 1
        quietly count if xcat == 1
        local nb = r(N)
        quietly count if xcat == 1 & elig == 1
        if `nb' == 0 | r(N) > 0 {
            display as error "qa_fx_a3_seq: base_absent lost its property"
            exit 9
        }
        return scalar perturb_n_base_absent = `nb'
        local applied `applied' base_absent
    }
    if `p_miss_irrelevant' {
        tempvar chg fs
        quietly bysort id (period): generate byte `chg' = a != a[_n-1] if _n > 1
        quietly by id: egen int `fs' = min(cond(`chg' == 1, period, .))
        quietly count if period > `fs' & !missing(`fs')
        local nm = r(N)
        if `nm' == 0 {
            display as error "qa_fx_a3_seq: miss_irrelevant found no row after a treatment change"
            exit 9
        }
        quietly replace a = . if period > `fs' & !missing(`fs')
        quietly replace l_t = . if period > `fs' & !missing(`fs')
        drop `chg' `fs'
        return scalar perturb_n_miss_irrelevant = `nm'
        local applied `applied' miss_irrelevant
    }
    if `p_miss_partial' {
        quietly count if mod(id, 7) == 0 & period >= 1
        local nm = r(N)
        if `nm' == 0 {
            display as error "qa_fx_a3_seq: miss_partial found no later row to blank"
            exit 9
        }
        quietly replace l0 = . if mod(id, 7) == 0 & period >= 1
        return scalar perturb_n_miss_partial = `nm'
        local applied `applied' miss_partial
    }
    if `p_gap' {
        tempvar len
        quietly bysort id: generate int `len' = _N
        quietly levelsof id if `len' >= 3 & period == 0, local(cand)
        local ncand : word count `cand'
        if `ncand' == 0 {
            display as error "qa_fx_a3_seq: gap needs ids with >= 3 rows"
            exit 9
        }
        quietly count if period == 0
        local ng = max(1, floor(0.05 * r(N)))
        local ng = min(`ng', `ncand')
        local gids ""
        forvalues j = 1/`ng' {
            local gids `gids' `: word `j' of `cand''
        }
        foreach g of local gids {
            quietly drop if id == `g' & period == 1
        }
        drop `len'
        tempvar jump
        quietly bysort id (period): generate byte `jump' = period - period[_n-1] > 1 if _n > 1
        quietly count if `jump' == 1
        if r(N) != `ng' {
            display as error "qa_fx_a3_seq: gap lost its property"
            exit 9
        }
        drop `jump'
        return scalar perturb_n_gap = `ng'
        return local perturb_ids_gap "`gids'"
        local applied `applied' gap
    }
    if `p_dup_key' {
        tempvar len
        quietly bysort id: generate int `len' = _N
        quietly summarize id if `len' >= 2, meanonly
        if r(N) == 0 {
            display as error "qa_fx_a3_seq: dup_key needs an id with >= 2 rows"
            exit 9
        }
        local did = r(min)
        quietly expand 2 if id == `did' & period == 1
        drop `len'
        quietly duplicates report id period
        if r(unique_value) == r(N) {
            display as error "qa_fx_a3_seq: dup_key lost its property"
            exit 9
        }
        sort id period
        return scalar perturb_id_dup_key = `did'
        local applied `applied' dup_key
    }
    if `p_codes_multidigit' | `p_codes_sparse' {
        local m2 = cond(`p_codes_multidigit', 11, 5)
        local m3 = cond(`p_codes_multidigit', 111, 17)
        quietly recast int xcat
        quietly replace xcat = cond(xcat == 3, `m3', cond(xcat == 2, `m2', 1))
        quietly levelsof xcat, local(lv)
        if "`lv'" != "1 `m2' `m3'" {
            display as error "qa_fx_a3_seq: relabel lost its property (levels `lv')"
            exit 9
        }
        return local perturb_map "1=1 2=`m2' 3=`m3'"
        local applied `applied' `= cond(`p_codes_multidigit', "codes_multidigit", "codes_sparse")'
    }
    if `p_prefix_collision' {
        foreach v of local collide {
            capture confirm new variable `v'
            if _rc {
                display as error "qa_fx_a3_seq: collide() name `v' already in the fixture"
                exit 198
            }
            quietly generate double `v' = 999
        }
        return local perturb_collide "`collide'"
        local applied `applied' prefix_collision
    }
    if `p_singleton_clusters' {
        quietly replace cl = id
        local applied `applied' singleton_clusters
    }
    if `p_extreme_weight' {
        quietly replace w = 1e4 if id == 1
        local applied `applied' extreme_weight
    }
    if `p_unsorted' {
        tempvar u
        quietly generate double `u' = runiform()
        sort `u'
        drop `u'
        tempvar ord
        quietly generate long `ord' = _n
        sort id period `ord'
        quietly count if `ord' != _n
        local moved = r(N)
        sort `ord'
        drop `ord'
        if `moved' == 0 {
            display as error "qa_fx_a3_seq: unsorted lost its property"
            exit 9
        }
        local applied `applied' unsorted
    }

    * Rename to package-native names last.
    local rn `"`names'"'
    while `"`rn'"' != "" {
        gettoken pair rn : rn
        gettoken old new : pair, parse("=")
        local new = substr("`new'", 2, .)
        capture confirm variable `old', exact
        if _rc | "`new'" == "" {
            display as error "qa_fx_a3_seq: names() pair `pair' is not old=new over a fixture variable"
            exit 198
        }
        rename `old' `new'
    }

    local napplied : word count `applied'
    local expect ""
    if `napplied' == 1 {
        local cls separate:REFUSED separate(switch):EXACT ///
            separate(censor):EXACT separate_time:REFUSED ///
            absorb:EXACT noevent:REFUSED all_treated:REFUSED ///
            base_absent:REFUSED single_period:EXACT gap:REFUSED ///
            dup_key:REFUSED miss_irrelevant:INVARIANT miss_partial:REFUSED ///
            unsorted:INVARIANT codes_multidigit:INVARIANT ///
            codes_sparse:INVARIANT prefix_collision:REFUSED ///
            singleton_clusters:EXACT extreme_weight:EXACT
        foreach c of local cls {
            gettoken cop ccl : c, parse(":")
            if "`cop'" == "`applied'" local expect = substr("`ccl'", 2, .)
        }
    }

    quietly count if y == 1
    local nev = r(N)
    quietly count
    local nrows = r(N)
    char _dta[qa_fx_generator] "_qa_fx_a3 qa_fx_a3_seq"
    char _dta[qa_fx_version] "1.3.0"
    char _dta[qa_fx_seed] "`seed'"
    char _dta[qa_fx_perturb] "`applied'"
    char _dta[qa_fx_confounding] "`confounding'"
    char _dta[qa_truth_risk0] "`: display %21x `T'[`k', 2]'"
    char _dta[qa_truth_risk1] "`: display %21x `T'[`k', 3]'"

    return matrix dgp = `P'
    return scalar truth_risk0 = `T'[`k', 2]
    return scalar truth_risk1 = `T'[`k', 3]
    return scalar truth_rd = `T'[`k', 3] - `T'[`k', 2]
    return scalar truth_rr = `T'[`k', 3] / `T'[`k', 2]
    return matrix truth_risk = `T'
    return scalar N = `nrows'
    return scalar N_ids = `n'
    return scalar k = `k'
    return scalar n_events = `nev'
    return scalar seed = `seed'
    return scalar sep_level = cond(`p_codes_multidigit', 111, cond(`p_codes_sparse', 17, 3))
    return local tier "`tier'"
    return local trials "`trials'"
    return local confounding "`confounding'"
    return local perturb "`ops'"
    return local perturb_applied "`applied'"
    return local expect_class "`expect'"
    return local xcat_support "`xs'"
end

capture mata: mata drop _qa_fxa3_generate()
capture mata: mata drop _qa_fxa3_hazard()
capture mata: mata drop _qa_fxa3_truth()
mata:
// Outcome hazard for period t under treatment a; f = operator flags.
real scalar _qa_fxa3_hazard(real rowvector p, real rowvector f,
    real scalar t, real scalar a, real scalar l, real scalar l0,
    real scalar x, real scalar absorbed)
{
    if (f[6]) return(0)
    if (f[1] & x == 3) return(0)
    if (f[4] & t == 1) return(0)
    if (absorbed & t == 1) return(1)
    return(invlogit(p[12] + p[13]*a + p[14]*l + p[15]*l0 + p[16]*t +
        p[17]*(x == 2) + p[18]*(x == 3)))
}

void _qa_fxa3_generate(real scalar n, real scalar K, real rowvector p,
    real rowvector f)
{
    real matrix D, U
    real scalar i, t, r, l0, x, l, a, lprev, aprev, a0, h, y, cc, d, q
    real scalar absorbed

    D = J(n*K, 9, .)
    r = 0
    for (i = 1; i <= n; i++) {
        U = runiform(K, 5)
        l0 = runiform(1, 1) < 0.5
        x = mod(i - 1, 3) + 1
        lprev = 0
        aprev = 0
        a0 = .
        for (t = 0; t < K; t++) {
            l = U[t+1, 1] < invlogit(p[1] + p[2]*l0 + p[3]*lprev + p[4]*aprev)
            if (t == 0) a = U[t+1, 2] < invlogit(p[5] + p[6]*l + p[7]*l0)
            else if (f[2] & x == 3) a = aprev
            else if (aprev == 1) a = U[t+1, 2] < invlogit(p[8] + p[9]*l)
            else a = U[t+1, 2] < invlogit(p[10] + p[11]*l)
            if (f[7]) a = 1
            if (t == 0) a0 = a
            absorbed = f[5] & a0 == 1
            if (absorbed & t == 1) a = 1
            h = _qa_fxa3_hazard(p, f, t, a, l, l0, x, absorbed)
            y = U[t+1, 3] < h
            cc = 0
            if (f[9]) cc = U[t+1, 4] < invlogit(p[19] + p[20]*l)
            if (f[3] & x == 3) cc = 0
            d = 0
            if (f[10]) d = U[t+1, 5] < invlogit(p[21] + p[22]*l0)
            if (absorbed & t <= 1) {
                cc = 0
                d = 0
            }
            if (cc) {
                y = 0
                d = 0
            }
            else if (y) d = 0
            r++
            D[r, .] = (i, t, l0, x, l, a, y, cc, d)
            if (y | cc | d) break
            lprev = l
            aprev = a
        }
    }
    D = D[1..r, .]
    (void) st_addvar(("long", "byte", "byte", "byte", "byte", "byte", "byte",
        "byte", "byte"), ("id", "period", "l0", "xcat", "l_t", "a", "y", "c",
        "comp"))
    st_addobs(r)
    st_store(., ., D)
}

// Exact cumulative primary risk under never (col 2) and always (col 3)
// treatment, population and standardized to the realized ids (cols 4-5).
void _qa_fxa3_truth(real scalar K, real rowvector p, real rowvector f,
    string scalar outname)
{
    real matrix T, cum, W
    real scalar reg, l0, x, t, lp, l, m, pl1, ml, h, q, aprev, absorbed
    real scalar j, tot, xlo, dcum
    real rowvector mass, newm

    // cum[t, j] for combination j = (reg, l0, x): cumulative risk after t.
    cum = J(K, 12, 0)
    for (reg = 0; reg <= 1; reg++) {
        for (l0 = 0; l0 <= 1; l0++) {
            for (x = 1; x <= 3; x++) {
                j = reg*6 + l0*3 + x
                mass = (1, 0)
                tot = 0
                dcum = 0
                absorbed = f[5] & reg == 1
                for (t = 0; t < K; t++) {
                    aprev = (t == 0 ? 0 : reg)
                    newm = (0, 0)
                    for (lp = 0; lp <= 1; lp++) {
                        m = mass[lp+1]
                        if (m == 0) continue
                        pl1 = invlogit(p[1] + p[2]*l0 + p[3]*lp + p[4]*aprev)
                        for (l = 0; l <= 1; l++) {
                            ml = m*(l ? pl1 : 1 - pl1)
                            h = _qa_fxa3_hazard(p, f, t, reg, l, l0, x, absorbed)
                            q = (f[10] ? invlogit(p[21] + p[22]*l0) : 0)
                            if (absorbed & t <= 1) q = 0
                            tot = tot + ml*h
                            dcum = dcum + ml*(1 - h)*q
                            newm[l+1] = newm[l+1] + ml*(1 - h)*(1 - q)
                        }
                    }
                    // An absorbing step leaves no survivors: the risk is
                    // exactly 1 - (competing so far), free of roundoff.
                    if (absorbed & t == 1) tot = 1 - dcum
                    mass = newm
                    cum[t+1, j] = tot
                }
            }
        }
    }
    // Population: l0 ~ Bernoulli(.5), xcat uniform on its support.
    xlo = (f[8] ? 2 : 1)
    T = J(K, 5, 0)
    T[., 1] = (1::K)
    for (reg = 0; reg <= 1; reg++) {
        for (l0 = 0; l0 <= 1; l0++) {
            for (x = xlo; x <= 3; x++) {
                T[., 2 + reg] = T[., 2 + reg] + cum[., reg*6 + l0*3 + x]
            }
        }
        T[., 2 + reg] = T[., 2 + reg] :/ (2*(4 - xlo))
    }
    // Standardized to the realized ids (period-0 rows).
    W = st_data(., ("l0", "xcat", "period"))
    W = select(W, W[., 3] :== 0)
    if (f[8]) W = select(W, W[., 2] :!= 1)
    for (reg = 0; reg <= 1; reg++) {
        for (j = 1; j <= rows(W); j++) {
            T[., 4 + reg] = T[., 4 + reg] + cum[., reg*6 + W[j, 1]*3 + W[j, 2]]
        }
        T[., 4 + reg] = T[., 4 + reg] :/ rows(W)
    }
    st_matrix(outname, T)
    st_matrixcolstripe(outname, (J(5, 1, ""), ("h" \ "risk0" \ "risk1" \
        "risk0_s" \ "risk1_s")))
}
end

**# VISIT, TRAJ and EDSS fixtures
* qa_fx_a3_visit, clear [tier(micro|unit|recovery) n(#) tau(real 4)
*   seed(#) perturb(dup_key unsorted miss_irrelevant) names(old=new ...)]
* Schema id time y lag_y visit lambda start stop u aux baseline full_y.
* U is balanced +/-1; full Y(t)=2+.4t+U. Baseline always observed; subsequent
* gaps ~Exp(.6*exp(.6*last observed Y)), piecewise constant between visits.
* The terminal row is a nonvisit at tau, y missing; full_y is the potential
* outcome, supplied only to the fixture oracle. lambda on baseline is1;
* follow-up lambda is the predictable intensity just before that visit/end.
* Exact population/finite-balanced mean(t)=2+.4t, distinct from event-selected
* observed mean. Truth: mean curve at0,tau/4,...,tau; target mean at tau;
* visit coefficients (_cons=ln(.6),lag_y=.6), outcome coefficients(2,.4).
* Tiers20/200/5000 independently sampled visit paths; n4..20000, even.
* Each id consumes a fixed block128 uniforms, independent of perturbations.
* Source: Lin/Scharfstein/Rosenheck2004 DOI10.1111/j.1467-9868.2004.b5543.x,
* pp794–798, original local PDF/fulltext and author metadata read2026-09-30.
* This is a custom DGP with known intensity, not an implementation of IIW.
*
* qa_fx_a3_traj, clear [tier(...) n(#) k(integer 5) model(cnorm|logit|poisson)
*   noiseless seed(#) perturb(empty_group overlapping_groups single_time_id
*   unsorted boundary_values) names(old=new ...)]
* Schema id period time group y eta aux. Three quadratic polynomials; group
* prior probabilities(.3,.4,.3); empty_group changes to(.5,.5,0).
* CNORM latent Normal(eta,.5), censored to[0,10]; LOGIT Bernoulli(expit(eta));
* POISSON count with mean exp(eta), no zero inflation. Time0..k-1, k3..8.
* Tiers24/300/5000 independent iid classes and outcomes; n24..10000.
* Coefficients: cnorm(2,.4,0;5,-.2,.05;8,-.3,0), logit(-2,.2,0;
* -.2,0,.02;1.5,-.1,-.02), poisson(ln(.8),.1,0;ln(2),-.02,.01;
* ln(5),-.03,0). overlapping_groups makes group3 equal group2.
* Truth coefficients/prior probabilities; exact finite-noise posterior by
* Bayes likelihood product over each id's PRESENT rows (not true-class onehot).
* Separate truth_limit_post is CNORM's noiseless limit evaluated on the
* corresponding clipped mean trajectories; indistinguishable groups share
* prior-proportional mass. sigma/lower/upper are missing for Logit/Poisson.
* Logit/Poisson have no defined noiseless limit here:
* truth_limit_available=0 and NO fabricated limit matrix. noiseless only
* cnorm micro/unit; recovery refuses it. single_time_id leaves id1 onlytime0.
* boundary_values only cnorm: bounds[4,6], censored outcomes/posterior recomputed.
* Source: Jones/Nagin/Roeder2001 author CMU ref1.pdf pp375–378, fetched
* 2026-09-30. Conditional independence within groups is explicit.
*
* qa_fx_a3_edss, clear [tier(micro) seed(#)
*   perturb(ties unsorted miss_irrelevant boundary_values) names(...) ]
* Twenty hand-specified profiles. Schema id date edss dx_date relapse_date aux.
* relapse_date is a per-id onset (one or none), constant across measure rows.
* truth_events: id cdp2_s cdp2_v cdp3_s cdp3_v pira raw ss6 ss6_v roving_n.
* CDP: first measurement on/after diagnosis within730 days, otherwise earliest;
* candidate strictly after baseline; two-tier increase1 if baseline<=5.5 else
* .5; three-tier1.5 at baseline0 else same. Confirmation>=180 days; sustained
* requires ALL measures at/after180-day edge high, visit requires FIRST high.
* PIRA/RAW classify first CDP2_s by inclusive relapse onset[-90,+30] days;
* no relapse-rebaselining or recurrent PIRA oracle supplied. ss6: threshold6
* crossing with NO later EDSS<6, including no later visit; ss6_v additionally
* requires the first STRICTLY later visit high (unlimited mode).
* truth_roving: id eventnum onset confirmed_date baseline threshold, uses
* CDP two-tier visit rule and resets baseline at the confirming visit. This
* documented setools definition differs from Kappos's24/48-week scheme.
* Sources: setools cdp/pira/sustainedss documented definitions read2026-09-30;
* Kappos2018 DOI10.1177/1352458517709619 primary author PDF fetched; thresholds
* and roving motivation only, NOT equivalence to its relapse/confirmation rules.
* EDSS unit/recovery refused: hand-series supply exact events, not MC recovery.
* r(truth_*) scalars/matrices and full matrix rows persist in %21x metadata.
* Truth matrix schemas use canonical role names after names().
* New families reject invalid options/names before clear; caller r() retained on refusal. Primitives use the
* established qa_hostile_* helpers directly via a refusal pointer, rc198.

capture program drop _qa_fxa3_new_options
program define _qa_fxa3_new_options, sclass
    version 16.0
    syntax , WHO(string) VARS(string) KNOWN(string) SEED(integer) [TIER(string) PERTurb(string) NAMES(string)]
    if "`tier'"=="" local tier unit
    if !inlist("`tier'","micro","unit","recovery") | `seed'<0 | `seed'>2147483647 {
        di as error "`who': tier(micro|unit|recovery) and seed(0..2147483647) required"
        exit 198
    }
    local ops : list uniq perturb
    foreach op of local ops {
        local helper ""
        if "`op'"=="long_names" local helper qa_hostile_names
        if "`op'"=="string_hostile" local helper qa_hostile_strings
        if "`op'"=="time_hostile" local helper qa_hostile_times
        if "`op'"=="miss_extended" local helper qa_hostile_missing
        if inlist("`op'","codes_negative","codes_big") local helper qa_hostile_codes
        if "`op'"=="scale_shift" local helper qa_shift_invariance
        if "`helper'"!="" {
            di as error "`who': `op' is primitive; call `helper' directly"
            exit 198
        }
        if !`: list op in known' {
            di as error "`who': unknown operator `op'"
            exit 198
        }
    }
    local olds ""
    local news ""
    foreach pair of local names {
        if !regexm("`pair'","^([A-Za-z_][A-Za-z_0-9]*)=([A-Za-z_][A-Za-z_0-9]*)$") {
            di as error "`who': names() requires old=new pairs"
            exit 198
        }
        local old=regexs(1)
        local new=regexs(2)
        capture confirm names `new'
        if _rc | strlen("`new'")>32 | !`: list old in vars' | `: list old in olds' | `: list new in news' {
            di as error "`who': invalid or duplicate names() mapping `pair'"
            exit 198
        }
        if "`old'"!="`new'" & `: list new in vars' {
            di as error "`who': names() target `new' collides with schema"
            exit 198
        }
        local olds `olds' `old'
        local news `news' `new'
    }
    sreturn local tier "`tier'"
    sreturn local ops "`ops'"
end

capture program drop _qa_fxa3_new_store
program define _qa_fxa3_new_store
    version 16.0
    args name M schema
    char _dta[qa_truth_`name'_rows] "`=rowsof(`M')'"
    char _dta[qa_truth_`name'_cols] "`=colsof(`M')'"
    char _dta[qa_truth_`name'_schema] "`schema'"
    forvalues i=1/`=rowsof(`M')' {
        local tokens ""
        forvalues j=1/`=colsof(`M')' {
            local tokens `tokens' `: display %21x `M'[`i',`j']'
        }
        char _dta[qa_truth_`name'_row`i'] "`tokens'"
    }
end

capture program drop _qa_fxa3_new_finish
program define _qa_fxa3_new_finish
    version 16.0
    syntax , GENERATOR(string) TIER(string) SEED(integer) [OPS(string) NAMES(string)]
    foreach pair of local names {
        local eq=strpos("`pair'","=")
        local old=substr("`pair'",1,`eq'-1)
        local new=substr("`pair'",`eq'+1,.)
        if "`old'"!="`new'" rename `old' `new'
    }
    char _dta[qa_fx_generator] "_qa_fx_a3 `generator'"
    char _dta[qa_fx_version] "1.3.0"
    char _dta[qa_fx_seed] "`seed'"
    char _dta[qa_fx_tier] "`tier'"
    char _dta[qa_fx_perturb] "`ops'"
    char _dta[qa_fx_names] "`names'"
end

capture program drop _qa_fxa3_new_shuffle
program define _qa_fxa3_new_shuffle, rclass
    version 16.0
    tempvar u ord
    gen long `ord'=_n
    gen double `u'=runiform()
    sort `u'
    count if `ord'!=_n
    local hits=r(N)
    drop `u' `ord'
    if `hits'==0 {
        di as error "qa_fx_a3: unsorted lost its property"
        exit 9
    }
    return scalar hits=`hits'
end

capture program drop qa_fx_a3_visit
program define qa_fx_a3_visit, rclass
    version 16.0
    return add
    syntax , CLEAR [TIER(string) N(integer 0) TAU(real 4) SEED(integer 20260930) PERTurb(string) NAMES(string)]
    _qa_fxa3_new_options, who(qa_fx_a3_visit) vars(id time y lag_y visit lambda start stop u aux baseline full_y) known(dup_key unsorted miss_irrelevant) tier(`tier') seed(`seed') perturb(`perturb') names(`names')
    local tier `s(tier)'
    local ops `s(ops)'
    if `n'==0 local n=cond("`tier'"=="micro",20,cond("`tier'"=="unit",200,5000))
    if `n'<4 | `n'>20000 | mod(`n',2)!=0 | missing(`tau') | `tau'<=0 | `tau'>4 {
        di as error "qa_fx_a3_visit: even n(4..20000), tau(>0..4) required"
        exit 198
    }
    return clear
    clear
    set seed `seed'
    mata: _qa_fxa3_visit_generate(`n',`tau')
    local dup_key=`: list posof "dup_key" in ops'>0
    local miss_irrelevant=`: list posof "miss_irrelevant" in ops'>0
    if `dup_key' {
        quietly expand 2 if id==1 & baseline
        count if id==1 & baseline
        if r(N)!=2 exit 9
        local hits_dup_key=r(N)
    }
    if `miss_irrelevant' {
        quietly replace aux=. if !visit
        count if missing(aux) & !visit
        if r(N)!=`n' exit 9
        local hits_miss_irrelevant=r(N)
    }
    sort id time
    tempname T B G
    matrix `T'=J(5,2,.)
    forvalues j=1/5 {
        matrix `T'[`j',1]=(`j'-1)*`tau'/4
        matrix `T'[`j',2]=2+.4*(`j'-1)*`tau'/4
    }
    matrix `B'=(2,.4)
    matrix `G'=(ln(.6),.6)
    matrix colnames `T'=time mean
    matrix colnames `B'=_cons time
    matrix colnames `G'=_cons lag_y
    _qa_fxa3_new_store mean_curve `T' "time mean"
    _qa_fxa3_new_store outcome_b `B' "_cons time"
    _qa_fxa3_new_store visit_b `G' "_cons lag_y"
    char _dta[qa_truth_mean] "`: display %21x 2+.4*`tau''"
    char _dta[qa_truth_tau] "`: display %21x `tau''"
    if `: list posof "unsorted" in ops'>0 {
        _qa_fxa3_new_shuffle
        local hits_unsorted=r(hits)
    }
    _qa_fxa3_new_finish, generator(qa_fx_a3_visit) tier(`tier') seed(`seed') ops(`ops') names(`names')
    foreach op of local ops {
        char _dta[qa_perturb_n_`op'] "`hits_`op''"
        return scalar perturb_n_`op'=`hits_`op''
    }
    return matrix truth_mean_curve=`T'
    return matrix truth_outcome_b=`B'
    return matrix truth_visit_b=`G'
    return scalar truth_mean=2+.4*`tau'
    return scalar truth_tau=`tau'
    return scalar N=_N
    return scalar N_ids=`n'
    return scalar seed=`seed'
    return local tier "`tier'"
    return local perturb "`ops'"
    return local perturb_applied "`ops'"
    return local expect_class = cond(`: word count `ops''==1,cond("`ops'"=="dup_key","REFUSED","INVARIANT"),"")
end

capture program drop qa_fx_a3_traj
program define qa_fx_a3_traj, rclass
    version 16.0
    return add
    syntax , CLEAR [TIER(string) N(integer 0) K(integer 5) MODEL(string) NOISELESS SEED(integer 20260930) PERTurb(string) NAMES(string)]
    if "`model'"=="" local model cnorm
    if !inlist("`model'","cnorm","logit","poisson") | `k'<3 | `k'>8 {
        di as error "qa_fx_a3_traj: model(cnorm|logit|poisson), k(3..8) required"
        exit 198
    }
    _qa_fxa3_new_options, who(qa_fx_a3_traj) vars(id period time group y eta aux) known(empty_group overlapping_groups single_time_id unsorted boundary_values) tier(`tier') seed(`seed') perturb(`perturb') names(`names')
    local tier `s(tier)'
    local ops `s(ops)'
    if `n'==0 local n=cond("`tier'"=="micro",24,cond("`tier'"=="unit",300,5000))
    if `n'<24 | `n'>10000 | ("`noiseless'"!="" & ("`model'"!="cnorm" | "`tier'"=="recovery")) {
        di as error "qa_fx_a3_traj: n(24..10000); noiseless only cnorm micro/unit"
        exit 198
    }
    if `: list posof "boundary_values" in ops'>0 & "`model'"!="cnorm" {
        di as error "qa_fx_a3_traj: boundary_values requires cnorm censoring"
        exit 198
    }
    local empty_group=`: list posof "empty_group" in ops'>0
    local overlapping_groups=`: list posof "overlapping_groups" in ops'>0
    local single_time_id=`: list posof "single_time_id" in ops'>0
    local boundary_values=`: list posof "boundary_values" in ops'>0
    tempname B Q P L
    if "`model'"=="cnorm" matrix `B'=(2,.4,0\5,-.2,.05\8,-.3,0)
    if "`model'"=="logit" matrix `B'=(-2,.2,0\-.2,0,.02\1.5,-.1,-.02)
    if "`model'"=="poisson" matrix `B'=(ln(.8),.1,0\ln(2),-.02,.01\ln(5),-.03,0)
    matrix `Q'=(.3,.4,.3)
    if `empty_group' matrix `Q'=(.5,.5,0)
    if `overlapping_groups' {
        forvalues j=1/3 {
            matrix `B'[3,`j']=`B'[2,`j']
        }
    }
    local lower=cond("`model'"=="cnorm",cond(`boundary_values',4,0),.)
    local upper=cond("`model'"=="cnorm",cond(`boundary_values',6,10),.)
    local sigma=cond("`model'"=="cnorm",cond("`noiseless'"!="",0,.5),.)
    return clear
    clear
    set seed `seed'
    mata: _qa_fxa3_traj_generate(`n',`k',"`model'",st_matrix("`B'"),st_matrix("`Q'"),`sigma',`lower',`upper')
    if `single_time_id' quietly drop if id==1 & period>0
    sort id period
    foreach op of local ops {
        if "`op'"=="empty_group" {
            count if group==3
            if r(N)!=0 exit 9
            local hits_empty_group=`n'
        }
        if "`op'"=="overlapping_groups" {
            forvalues j=1/3 {
                if `B'[2,`j']!=`B'[3,`j'] exit 9
            }
            count if inlist(group,2,3)
            if r(N)==0 exit 9
            local hits_overlapping_groups=r(N)
        }
        if "`op'"=="single_time_id" {
            count if id==1
            if r(N)!=1 exit 9
            local hits_single_time_id=r(N)
        }
        if "`op'"=="boundary_values" {
            count if y==`lower' | y==`upper'
            if r(N)==0 exit 9
            local hits_boundary_values=r(N)
        }
    }
    mata: _qa_fxa3_traj_posterior(`n',"`model'",st_matrix("`B'"),st_matrix("`Q'"),`sigma',`lower',`upper',"`P'","`L'")
    matrix colnames `B'=_cons time time2
    matrix rownames `B'=group1 group2 group3
    matrix colnames `Q'=group1 group2 group3
    matrix colnames `P'=id group1 group2 group3
    _qa_fxa3_new_store coefficients `B' "rows=group1..3 cols=_cons time time2"
    _qa_fxa3_new_store prior `Q' "group1 group2 group3"
    _qa_fxa3_new_store posterior `P' "id group1 group2 group3"
    if "`model'"=="cnorm" {
        matrix colnames `L'=id group1 group2 group3
        _qa_fxa3_new_store limit_post `L' "id group1 group2 group3"
    }
    char _dta[qa_truth_limit_available] "`=cond("`model'"=="cnorm",1,0)'"
    char _dta[qa_truth_sigma] "`: display %21x `sigma''"
    char _dta[qa_truth_lower] "`: display %21x `lower''"
    char _dta[qa_truth_upper] "`: display %21x `upper''"
    char _dta[qa_truth_model] "`model'"
    if `: list posof "unsorted" in ops'>0 {
        _qa_fxa3_new_shuffle
        local hits_unsorted=r(hits)
    }
    _qa_fxa3_new_finish, generator(qa_fx_a3_traj) tier(`tier') seed(`seed') ops(`ops') names(`names')
    foreach op of local ops {
        char _dta[qa_perturb_n_`op'] "`hits_`op''"
        return scalar perturb_n_`op'=`hits_`op''
    }
    return matrix truth_coefficients=`B'
    return matrix truth_prior=`Q'
    return matrix truth_posterior=`P'
    if "`model'"=="cnorm" return matrix truth_limit_post=`L'
    return scalar truth_limit_available=cond("`model'"=="cnorm",1,0)
    return scalar truth_sigma=`sigma'
    return scalar truth_lower=`lower'
    return scalar truth_upper=`upper'
    return scalar N=_N
    return scalar N_ids=`n'
    return scalar seed=`seed'
    return local model "`model'"
    return local tier "`tier'"
    return local perturb "`ops'"
    return local perturb_applied "`ops'"
    return local expect_class = cond(`: word count `ops''==1,cond("`ops'"=="unsorted","INVARIANT",cond("`ops'"=="empty_group","REFUSED","EXACT")),"")
end

capture program drop qa_fx_a3_edss
program define qa_fx_a3_edss, rclass
    version 16.0
    return add
    syntax , CLEAR [TIER(string) SEED(integer 20260930) PERTurb(string) NAMES(string)]
    if "`tier'"=="" local tier micro
    _qa_fxa3_new_options, who(qa_fx_a3_edss) vars(id date edss dx_date relapse_date aux) known(ties unsorted miss_irrelevant boundary_values) tier(`tier') seed(`seed') perturb(`perturb') names(`names')
    local tier `s(tier)'
    local ops `s(ops)'
    if "`tier'"!="micro" {
        di as error "qa_fx_a3_edss: only tier(micro); hand series have no recovery DGP"
        exit 198
    }
    return clear
    clear
    set seed `seed'
    tempname D
    matrix `D'=(1,0,2\1,30,3\1,210,3 \ ///
        2,0,2\2,30,3\2,210,3 \ ///
        2,300,2\3,0,2\3,30,3 \ ///
        3,120,3\4,0,6\4,30,6.5 \ ///
        4,210,6.5\5,0,0\5,30,1 \ ///
        5,210,1\6,0,0\6,30,1.5 \ ///
        6,210,1.5\7,0,5.5\7,30,6 \ ///
        7,210,6\8,0,2\8,30,3 \ ///
        8,209,3\9,0,2\9,30,3 \ ///
        9,210,3\10,0,2\10,30,3 \ ///
        10,211,3\11,0,2\11,90,3 \ ///
        11,270,3\12,0,2\12,90,3 \ ///
        12,270,3\13,0,2\13,30,3 \ ///
        13,210,3\14,0,2\14,30,3 \ ///
        14,210,3\15,0,2\15,30,3 \ ///
        15,210,3\16,0,2\16,30,3 \ ///
        16,210,3\16,240,4\16,420,4 \ ///
        17,0,6\17,30,6.5\17,210,6.5 \ ///
        17,240,7\17,420,7\18,0,2 \ ///
        18,30,3\18,210,3\18,300,3 \ ///
        18,480,4\18,660,4\19,-1,3 \ ///
        19,30,2\19,60,3\19,240,3 \ ///
        20,0,6\20,180,6)
    matrix colnames `D'=id day edss
    quietly svmat double `D', names(col)
    quietly recast int id day
    quietly {
        gen double date=mdy(1,1,2020)+day
        gen double dx_date=mdy(1,1,2020)
        gen double relapse_date=.
        replace relapse_date=dx_date if id==11
        replace relapse_date=dx_date-1 if id==12
        replace relapse_date=dx_date+60 if id==13
        replace relapse_date=dx_date+61 if id==14
        replace relapse_date=dx_date+30 if id==15
        gen byte aux=1
        if `: list posof "ties" in ops'>0 expand 2 if id==9 & day==30
        if `: list posof "boundary_values" in ops'>0 replace date=dx_date+210 if id==8 & day==209
        if `: list posof "miss_irrelevant" in ops'>0 replace edss=. if id==19 & day<0
        drop day
        sort id date
    }
    foreach op of local ops {
        if "`op'"=="ties" count if id==9 & date==dx_date+30
        if "`op'"=="boundary_values" count if id==8 & date==dx_date+210
        if "`op'"=="miss_irrelevant" count if id==19 & date<dx_date & missing(edss)
        if "`op'"!="unsorted" {
            if r(N)<1 | ("`op'"=="ties" & r(N)!=2) {
                di as error "qa_fx_a3_edss: `op' lost its property"
                exit 9
            }
            local hits_`op'=r(N)
        }
    }
    tempname E R
    mata: _qa_fxa3_edss_truth("`E'","`R'")
    matrix colnames `E'=id cdp2_s cdp2_v cdp3_s cdp3_v pira raw ss6 ss6_v roving_n
    matrix colnames `R'=id eventnum onset confirmed_date baseline threshold
    _qa_fxa3_new_store events `E' "id cdp2_s cdp2_v cdp3_s cdp3_v pira raw ss6 ss6_v roving_n"
    _qa_fxa3_new_store roving `R' "id eventnum onset confirmed_date baseline threshold"
    char _dta[qa_truth_confirmdays] "180"
    char _dta[qa_truth_windowbefore] "90"
    char _dta[qa_truth_windowafter] "30"
    char _dta[qa_truth_threshold] "6"
    if `: list posof "unsorted" in ops'>0 {
        _qa_fxa3_new_shuffle
        local hits_unsorted=r(hits)
    }
    format date dx_date relapse_date %td
    _qa_fxa3_new_finish, generator(qa_fx_a3_edss) tier(`tier') seed(`seed') ops(`ops') names(`names')
    foreach op of local ops {
        char _dta[qa_perturb_n_`op'] "`hits_`op''"
        return scalar perturb_n_`op'=`hits_`op''
    }
    return matrix truth_events=`E'
    return matrix truth_roving=`R'
    return scalar truth_confirmdays=180
    return scalar truth_windowbefore=90
    return scalar truth_windowafter=30
    return scalar truth_threshold=6
    return scalar N=_N
    return scalar N_ids=20
    return scalar seed=`seed'
    return local tier "`tier'"
    return local perturb "`ops'"
    return local perturb_applied "`ops'"
    return local expect_class = cond(`: word count `ops''==1,cond("`ops'"=="boundary_values","EXACT","INVARIANT"),"")
end

capture mata: mata drop _qa_fxa3_visit_generate()
capture mata: mata drop _qa_fxa3_traj_generate()
capture mata: mata drop _qa_fxa3_traj_posterior()
capture mata: mata drop _qa_fxa3_edss_candidate()
capture mata: mata drop _qa_fxa3_edss_truth()
mata:
void _qa_fxa3_visit_generate(real scalar n, real scalar tau)
{
    real matrix D
    real colvector U
    real scalar i,j,r,u,t,prev,y,rate,next
    D=J(n*130,12,.);r=0
    for(i=1;i<=n;i++) {
        U=runiform(128,1);u=2*mod(i,2)-1;t=0;y=2+u
        r++;D[r,.]=(i,0,y,.,1,1,0,0,u,1,1,y)
        for(j=1;j<=128;j++) {
            rate=.6*exp(.6*y);next=t-ln(U[j])/rate
            if(next>=tau) {
                r++;D[r,.]=(i,tau,.,y,0,rate,t,tau,u,1,0,2+.4*tau+u)
                break
            }
            prev=y;r++;D[r,.]=(i,next,2+.4*next+u,prev,1,rate,t,next,u,1,0,2+.4*next+u)
            t=next;y=2+.4*t+u
        }
        if(j>128) _error(3498,"VISIT exceeded128-draw safety bound")
    }
    D=D[1..r,.]
    (void) st_addvar(("long",J(1,11,"double")),("id","time","y","lag_y","visit","lambda","start","stop","u","aux","baseline","full_y"))
    st_addobs(r);st_store(.,.,D)
}
void _qa_fxa3_traj_generate(real scalar n, real scalar k, string scalar model, real matrix B, real rowvector Q, real scalar sigma, real scalar lower, real scalar upper)
{
    real matrix D
    real colvector U
    real scalar i,t,r,g,eta,y,lambda,p,cdf
    D=J(n*k,7,.);r=0
    for(i=1;i<=n;i++) {
        U=runiform(k+1,1)
        g=1+(U[1]>Q[1])+(U[1]>Q[1]+Q[2])
        for(t=0;t<k;t++) {
            eta=B[g,1]+B[g,2]*t+B[g,3]*t^2
            if(model=="cnorm") y=max((lower,min((upper,eta+sigma*invnormal(U[t+2])))))
            if(model=="logit") y=U[t+2]<invlogit(eta)
            if(model=="poisson") {
                lambda=exp(eta);y=0;p=exp(-lambda);cdf=p
                while(U[t+2]>cdf) {
                    y++;p=p*lambda/y;cdf=cdf+p
                    if(y>1000) _error(3498,"Poisson inverseCDF safety bound")
                }
            }
            r++;D[r,.]=(i,t,t,g,y,eta,1)
        }
    }
    (void) st_addvar(("long","byte","double","byte","double","double","byte"),("id","period","time","group","y","eta","aux"))
    st_addobs(r);st_store(.,.,D)
}
void _qa_fxa3_traj_posterior(real scalar n, string scalar model, real matrix B, real rowvector Q, real scalar sigma, real scalar lower, real scalar upper, string scalar pname, string scalar lname)
{
    real matrix D,V,P,L
    real scalar i,j,g,eta,y,ell,m,eta0,y0,ok
    real rowvector logp,limit
    D=st_data(.,("id","time","group","y"));P=J(n,4,.);L=J(n,4,.)
    for(i=1;i<=n;i++) {
        V=select(D,D[.,1]:==i);logp=J(1,3,-.);limit=J(1,3,0)
        for(g=1;g<=3;g++) {
            if(Q[g]==0) continue
            ell=ln(Q[g]);ok=1
            for(j=1;j<=rows(V);j++) {
                eta=B[g,1]+B[g,2]*V[j,2]+B[g,3]*V[j,2]^2;y=V[j,4]
                if(model=="cnorm") {
                    eta0=B[V[j,3],1]+B[V[j,3],2]*V[j,2]+B[V[j,3],3]*V[j,2]^2
                    y0=max((lower,min((upper,eta0))))
                    if(abs(y0-max((lower,min((upper,eta)))))>1e-12) ok=0
                    if(sigma>0) {
                        if(y<=lower) ell=ell+lnnormal((lower-eta)/sigma)
                        else if(y>=upper) ell=ell+lnnormal((eta-upper)/sigma)
                        else ell=ell-.5*((y-eta)/sigma)^2-ln(sigma)-.5*ln(2*pi())
                    }
                }
                if(model=="logit") ell=ell+y*ln(invlogit(eta))+(1-y)*ln(1-invlogit(eta))
                if(model=="poisson") ell=ell+y*eta-exp(eta)-lngamma(y+1)
            }
            logp[g]=ell
            if(model=="cnorm" & ok) limit[g]=Q[g]
        }
        if(model=="cnorm" & sigma==0) P[i,.]=(i,limit/sum(limit))
        else {
            m=max(select(logp,Q:>0));logp=exp(logp:-m)
            for(g=1;g<=3;g++) if(Q[g]==0) logp[g]=0
            P[i,.]=(i,logp/sum(logp))
        }
        if(model=="cnorm") L[i,.]=(i,limit/sum(limit))
    }
    st_matrix(pname,P)
    if(model=="cnorm") st_matrix(lname,L)
}
real rowvector _qa_fxa3_edss_candidate(real matrix V, real scalar b, real scalar three, real scalar sustained)
{
    real scalar j,h,threshold,first,ok
    threshold=(V[b,2]>5.5 ? .5 : (three & V[b,2]==0 ? 1.5 : 1))
    for(j=b+1;j<=rows(V);j++) {
        if(V[j,1]<=V[b,1] | V[j,2]<V[b,2]+threshold) continue
        first=0;ok=1
        for(h=j+1;h<=rows(V);h++) {
            if(V[h,1]<V[j,1]+180) continue
            if(!first) first=h
            if(V[h,2]<V[b,2]+threshold) ok=0
            if(!sustained) break
        }
        if(first & ok) return((j,first,threshold))
    }
    return((.,.,threshold))
}
void _qa_fxa3_edss_truth(string scalar ename, string scalar rname)
{
    real matrix D,V,E,R
    real scalar id,b,j,h,m,three,sustained,col,ss,ssv,onset,relapse,ne
    real rowvector candidate
    D=st_data(.,("id","date","edss","dx_date","relapse_date"))
    D=select(D,D[.,3]:<.);D=sort(D,(1,2))
    E=J(20,10,.);R=J(200,6,.);m=0
    for(id=1;id<=20;id++) {
        V=select(D,D[.,1]:==id);V=V[.,2..5]
        b=0
        for(j=1;j<=rows(V);j++) if(V[j,1]>=V[j,3] & V[j,1]<=V[j,3]+730) {b=j;break;}
        if(!b) b=1
        E[id,1]=id
        for(three=0;three<=1;three++) for(sustained=0;sustained<=1;sustained++) {
            candidate=_qa_fxa3_edss_candidate(V,b,three,sustained)
            col=2+2*three+(1-sustained)
            if(candidate[1]<.) E[id,col]=V[candidate[1],1]
        }
        onset=E[id,2];relapse=V[1,4]
        if(onset<.) {
            if(relapse>=. | relapse<onset-90 | relapse>onset+30) E[id,6]=onset
            else E[id,7]=onset
        }
        ss=.;ssv=.
        for(j=1;j<=rows(V);j++) {
            if(V[j,2]<6) continue
            if(min(V[j..rows(V),2])<6) continue
            if(ss>=.) ss=V[j,1]
            for(h=j+1;h<=rows(V);h++) if(V[h,1]>V[j,1]) {ssv=V[j,1];break;}
            if(ssv<.) break
        }
        E[id,8..9]=(ss,ssv);ne=0
        while(b<=rows(V)) {
            candidate=_qa_fxa3_edss_candidate(V,b,0,0)
            if(candidate[1]>=.) break
            ne++;m++;R[m,.]=(id,ne,V[candidate[1],1],V[candidate[2],1],V[b,2],candidate[3])
            b=candidate[2]
        }
        E[id,10]=ne
    }
    st_matrix(ename,E);st_matrix(rname,R[1..m,.])
}
end
