*! qa-lib _qa_fx_a1 1.1.0 sha256:be96bf969c1eeb39dc4924d7c8ce61f80a96d33bacfcf02924b25b7866d63beb
* _qa_fx_a1.do -- archetype A1 (cross-sectional unit-level) fixture generators
*
* Load from a suite with: do "`qa_dir'/_qa_fx_a1.do"
*
* A fixture cannot fail by itself: it goes red through the oracle a suite
* points at it. So each generator (a) re-verifies the hostile property it
* claims and exits 9 if the draw lost it, and (b) returns the design truth in
* r() and in _dta[] chars, computed by exact enumeration over a discrete
* design -- a code path no package shares.
*
* API
*   qa_fx_a1_logit , clear [tier(micro|unit|recovery) n(#) perturb(oplist)
*       seed(#) names(old=new ...)]                                  rclass
*
*   Balanced design over 18 covariate cells: x1 in {-1,0,1}, x2 in {0,1},
*   xcat in {1,2,3}; each cell holds n/18 rows (tier defaults micro 36, unit
*   360, recovery 20016; n() is rounded down to a multiple of 18).
*     a ~ Bernoulli(expit(-0.4 + 0.6 x1 + 0.5 x2 + 0.3 [xcat=2] - 0.3 [xcat=3]))
*     y ~ Bernoulli(expit(-1.0 + 0.8 a + 0.5 x1 - 0.4 x2 + 0.2 [xcat=2]
*                         + 0.6 [xcat=3]))
*   Variables: id y a x1 x2 xcat w (1) cl (10 rows per cluster), sorted by id.
*   Truth (population = the cell distribution of the design):
*     r(truth_risk0) r(truth_risk1) r(truth_rd) r(truth_rr)   marginal risks
*     r(truth_att)   E[Y1 - Y0 | A = 1]
*     r(truth_b)     1 x 6 outcome coefficients (a x1 x2 2.xcat 3.xcat _cons)
*     r(truth_g)     1 x 5 treatment coefficients (x1 x2 2.xcat 3.xcat _cons)
*     r(truth_cells) 18 x 6: x1 x2 xcat e(x) m0(x) m1(x)
*   Operators (perturb()):
*     separate         xcat 3 has no events (y = 0; truth m = 0 there)
*     collinear        adds x3 = x1 and x4 = x1 + x2 (truth unchanged)
*     single_level     x2 = 0 on every row (the design is x1 x xcat)
*     base_absent      insample = (xcat != 1); truth over xcat 2 3
*     codes_multidigit xcat relabelled 1 2 3 -> 1 11 111
*     codes_sparse     xcat relabelled 1 2 3 -> 1 5 17
*     miss_subgroup    x1 missing on every second xcat 3 row
*     miss_all_column  x2 missing on every row
*     zero_weight      w = 0 on every tenth row
*     extreme_weight   w = 1e4 on row 1
*     near_positivity  cells xcat 3 & x2 1 all treated; true e(x) = 1 - 1e-4
*     scale_shift      x1 + 1e8 (double); r(perturb_shift) = 1e8; the true
*                      intercept shifts by -0.5e8 (outcome) and -0.6e8 (ps)
*     noevent          y = 0 everywhere
*     all_treated      a = 1 everywhere
*     single_cluster   cl = 1;  singleton_clusters  cl = id
*     unsorted         random row order
*
*   qa_fx_a1_sat , clear [aggregate perturb(oplist) names(old=new ...)]
*                                                                    rclass
*   Saturated 2 x 2 x 2 design (stratum s, x2, a) with integer counts, 120
*   rows (8 rows with frequency f under aggregate). Risks by cell:
*       s x2 | n0 risk0 | n1 risk1
*       0  0 | 24  1/4  | 12  1/3
*       0  1 | 12  1/3  | 24  1/2
*       1  0 | 18  1/2  |  6  2/3
*       1  1 |  6  2/3  | 18  5/6
*   Truth (exact rationals; r(truth_*_q) holds the fraction as text):
*     standardized risks 49/120 (a=0) and 11/20 (a=1), RD 17/120, RR 66/49;
*     crude risks 23/60 and 7/12; ATT-standardized risk0 13/30;
*     Mantel-Haenszel OR and RR over the four s x x2 strata;
*     r(truth_cells) 8 x 5: s x2 a n events.
*   Operators: unsorted, codes_multidigit (s 0 1 -> 1 11),
*   codes_sparse (s 0 1 -> 1 17).
*
*   Both generators return r(N), r(seed) (logit), r(perturb),
*   r(perturb_applied), r(expect_class) (the operator's typical class when
*   exactly one is applied), and set _dta[qa_fx_generator|version|seed|
*   perturb] plus _dta[qa_truth_*] (%21x).
*   The primitive operators wrap existing qa-lib helpers and are refused here
*   with a pointer (rc 198): miss_extended codes_negative codes_big long_names
*   string_hostile time_hostile.
*
* Errors: rc 9 when a fixture lost its claimed property; rc 198 for bad
* arguments or an operator this archetype does not provide; clear required.
* names() is checked before replacing data or advancing RNG; malformed,
* duplicate and colliding maps refuse198 and preserve caller r()/e()/data.
* Coefficient and covariance stripes follow adapted variable names and factor
* codes. Stata may print a factor stripe with its native bn marker; lookup
* by its full factor term remains exact. Grid columns keep canonical roles.
*
* FX-A1-GAUSS: qa_fx_a1_gauss, clear [tier() n() seed() sigma(1)
*   heteroskedastic perturb() names()]. Balanced 36-cell linear Gaussian
*   design: y=1+2a+.5x1-x2+.25[xcat=2]-.25[xcat=3]+epsilon.
*   epsilon has SD sigma, or sigma*(1+.5*x2) with heteroskedastic.
*   r(truth_b), r(truth_v) are the coefficients and true conditional
*   covariance of weighted least squares on a x1 x2 i.xcat; truth_v is the
*   sandwich population target, not the expectation of a finite-sample HC
*   estimate. Singular/missing designs return unavailable covariance.
*   n defaults: micro36/unit360/recovery20016/scale100008, rounded to36.
* FX-A1-DIAG: qa_fx_a1_diag, clear [aggregate tier() seed() perturb() names()].
*   Scores1..5 have negative counts18,14,10,6,2 and positive2,6,10,14,18.
*   Micro divides counts by2 (50 rows), unit100, recovery20000, scale100000.
*   r(truth_auc) is the exact empirical Mann-Whitney probability, with half
*   credit for ties; r(truth_cutoffs) rows contain cutoff sensitivity
*   specificity tp fp tn fn. Positive means score>=cutoff.
*   Diagnostic truth is recomputed after perturbation; undefined ratios are
*   missing, never zero-filled. Both new families persist scalar truths as
*   %21x characteristics. Sources read2026-09-30: Stata regress and roctab
*   manuals, Methods and formulas (https://www.stata.com/manuals/rregress.pdf
*   and https://www.stata.com/manuals/rroctab.pdf).

capture program drop _qa_fxa1_parse
program define _qa_fxa1_parse, sclass
    version 16.0
    gettoken who 0 : 0
    gettoken known 0 : 0
    local wrapped miss_extended:qa_hostile_missing codes_negative:qa_hostile_codes ///
        codes_big:qa_hostile_codes long_names:qa_hostile_names ///
        string_hostile:qa_hostile_strings time_hostile:qa_hostile_times
    local ops ""
    local rest = strtrim(`"`0'"')
    while `"`rest'"' != "" {
        gettoken op rest : rest, bind
        local op = strlower(`"`op'"')
        foreach w of local wrapped {
            gettoken wop whelp : w, parse(":")
            local whelp = substr("`whelp'", 2, .)
            if "`op'" == "`wop'" {
                display as error "`who': `op' is a primitive operator; call `whelp' directly"
                exit 198
            }
        }
        if !`: list op in known' {
            display as error `"`who': unknown operator `op' (provides: `known')"'
            exit 198
        }
        local ops `ops' `op'
    }
    local ops : list uniq ops
    sreturn local ops "`ops'"
end

capture program drop _qa_fxa1_validate_names
program define _qa_fxa1_validate_names
    version 16.0
    syntax , WHO(string) VARS(string) [NAMES(string)]
    local olds ""
    local news ""
    foreach pair of local names {
        if !regexm("`pair'", "^([A-Za-z_][A-Za-z_0-9]*)=([A-Za-z_][A-Za-z_0-9]*)$") {
            display as error "`who': names() requires old=new pairs"
            exit 198
        }
        local old = regexs(1)
        local new = regexs(2)
        capture confirm names `new'
        if _rc | strlen("`new'")>32 | !`: list old in vars' | ///
                `: list old in olds' | `: list new in news' {
            display as error "`who': invalid or duplicate names() mapping `pair'"
            exit 198
        }
        if "`old'"!="`new'" & `: list new in vars' {
            display as error "`who': names() target `new' collides with schema"
            exit 198
        }
        local olds `olds' `old'
        local news `news' `new'
    }
end

capture program drop _qa_fxa1_stripes
program define _qa_fxa1_stripes
    version 16.0
    syntax namelist(min=1 max=1), [NAMES(string) COVariance]
    local columns : colnames `namelist'
    local adapted ""
    foreach column of local columns {
        foreach pair of local names {
            gettoken old new : pair, parse("=")
            local new = substr("`new'",2,.)
            if "`column'"=="`old'" local column `new'
            else if regexm("`column'","[.]`old'$") {
                local column = substr("`column'",1,strlen("`column'")-strlen("`old'"))+"`new'"
            }
        }
        local adapted `adapted' `column'
    }
    matrix colnames `namelist' = `adapted'
    if "`covariance'"!="" matrix rownames `namelist' = `adapted'
end

capture program drop _qa_fxa1_rename
program define _qa_fxa1_rename
    version 16.0
    gettoken who rn : 0
    local rn = strtrim(`"`rn'"')
    while `"`rn'"' != "" {
        gettoken pair rn : rn
        gettoken old new : pair, parse("=")
        local new = substr("`new'", 2, .)
        capture confirm variable `old', exact
        if _rc | "`new'" == "" {
            display as error "`who': names() pair `pair' is not old=new over a fixture variable"
            exit 198
        }
        rename `old' `new'
    }
end

capture program drop _qa_fxa1_shuffle
program define _qa_fxa1_shuffle, rclass
    version 16.0
    args who key
    tempvar u ord
    quietly generate double `u' = runiform()
    sort `u'
    drop `u'
    quietly generate long `ord' = _n
    sort `key' `ord'
    quietly count if `ord' != _n
    local moved = r(N)
    sort `ord'
    drop `ord'
    if `moved' == 0 {
        display as error "`who': unsorted lost its property"
        exit 9
    }
    return scalar moved = `moved'
end

capture program drop qa_fx_a1_logit
program define qa_fx_a1_logit, rclass
    version 16.0
    return add
    syntax , CLEAR [TIER(string) N(integer 0) PERTurb(string) ///
        SEED(integer 20260929) NAMES(string)]

    if "`tier'" == "" local tier unit
    if !inlist("`tier'", "micro", "unit", "recovery") {
        display as error "qa_fx_a1_logit: tier() must be micro, unit or recovery"
        exit 198
    }
    if `n' == 0 local n = cond("`tier'" == "micro", 36, cond("`tier'" == "unit", 360, 20016))
    local per = floor(`n' / 18)
    if `per' < 1 {
        display as error "qa_fx_a1_logit: n() must be at least 18"
        exit 198
    }
    if !inrange(`seed',0,2147483647) {
        display as error "qa_fx_a1_logit: invalid seed()"
        exit 198
    }
    local known separate collinear single_level base_absent codes_multidigit ///
        codes_sparse miss_subgroup miss_all_column zero_weight extreme_weight ///
        near_positivity scale_shift noevent all_treated single_cluster ///
        singleton_clusters unsorted
    _qa_fxa1_parse qa_fx_a1_logit `"`known'"' `perturb'
    local ops `s(ops)'
    foreach op of local known {
        local p_`op' = `: list op in ops'
    }
    if `p_codes_multidigit' & `p_codes_sparse' {
        display as error "qa_fx_a1_logit: codes_multidigit and codes_sparse both relabel xcat"
        exit 198
    }
    if `p_single_cluster' & `p_singleton_clusters' {
        display as error "qa_fx_a1_logit: single_cluster and singleton_clusters conflict"
        exit 198
    }
    local schema id y a x1 x2 xcat w cl
    if `p_base_absent' local schema `schema' insample
    if `p_collinear' local schema `schema' x3 x4
    _qa_fxa1_validate_names, who(qa_fx_a1_logit) vars(`schema') names(`names')
    return clear

    tempname G B
    matrix `G' = (0.6, 0.5, 0.3, -0.3, -0.4)
    matrix colnames `G' = x1 x2 2.xcat 3.xcat _cons
    matrix `B' = (0.8, 0.5, -0.4, 0.2, 0.6, -1.0)
    matrix colnames `B' = a x1 x2 2.xcat 3.xcat _cons
    * flags: separate single_level near_positivity noevent all_treated base_absent
    tempname F C
    matrix `F' = (`p_separate', `p_single_level', `p_near_positivity', ///
        `p_noevent', `p_all_treated', `p_base_absent')

    clear
    set seed `seed'
    mata: _qa_fxa1_logit_gen(`per', st_matrix("`G'"), st_matrix("`B'"), st_matrix("`F'"), "`C'")
    quietly {
        generate long id = _n
        order id y a x1 x2 xcat
        generate double w = 1
        generate long cl = ceil(id / 10)
        label variable y "outcome"
        label variable a "treatment"
        label variable xcat "category"
    }

    local applied ""
    if `p_separate' {
        quietly count if xcat == 3 & y == 1
        local ns = r(N)
        quietly count if xcat != 3 & y == 1
        if `ns' > 0 | r(N) == 0 {
            display as error "qa_fx_a1_logit: separate lost its property"
            exit 9
        }
        local applied `applied' separate
    }
    if `p_single_level' {
        quietly count if x2 != 0
        if r(N) > 0 {
            display as error "qa_fx_a1_logit: single_level lost its property"
            exit 9
        }
        local applied `applied' single_level
    }
    if `p_near_positivity' {
        quietly count if xcat == 3 & x2 == 1 & a == 0
        if r(N) > 0 {
            display as error "qa_fx_a1_logit: near_positivity lost its property"
            exit 9
        }
        local applied `applied' near_positivity
    }
    if `p_noevent' {
        quietly count if y == 1
        if r(N) > 0 {
            display as error "qa_fx_a1_logit: noevent lost its property"
            exit 9
        }
        local applied `applied' noevent
    }
    if `p_all_treated' {
        quietly count if a != 1
        if r(N) > 0 {
            display as error "qa_fx_a1_logit: all_treated lost its property"
            exit 9
        }
        local applied `applied' all_treated
    }
    if `p_base_absent' {
        quietly generate byte insample = xcat != 1
        label variable insample "analysis sample (base level 1 absent)"
        local applied `applied' base_absent
    }
    if `p_collinear' {
        quietly generate byte x3 = x1
        quietly generate byte x4 = x1 + x2
        local applied `applied' collinear
    }
    if `p_miss_subgroup' {
        tempvar j
        quietly bysort xcat (id): generate long `j' = _n
        quietly replace x1 = . if xcat == 3 & mod(`j', 2) == 0
        sort id
        quietly count if missing(x1)
        local nm = r(N)
        quietly count if missing(x1) & xcat != 3
        if `nm' == 0 | r(N) > 0 {
            display as error "qa_fx_a1_logit: miss_subgroup lost its property"
            exit 9
        }
        return scalar perturb_n_miss_subgroup = `nm'
        local applied `applied' miss_subgroup
    }
    if `p_miss_all_column' {
        quietly replace x2 = .
        local applied `applied' miss_all_column
    }
    if `p_zero_weight' {
        quietly replace w = 0 if mod(id, 10) == 0
        quietly count if w == 0
        return scalar perturb_n_zero_weight = r(N)
        local applied `applied' zero_weight
    }
    if `p_extreme_weight' {
        quietly replace w = 1e4 in 1
        local applied `applied' extreme_weight
    }
    if `p_scale_shift' {
        quietly recast double x1
        quietly replace x1 = x1 + 1e8
        quietly count if x1 - 1e8 != floor(x1 - 1e8)
        if r(N) > 0 {
            display as error "qa_fx_a1_logit: scale_shift did not round-trip"
            exit 9
        }
        return scalar perturb_shift = 1e8
        local applied `applied' scale_shift
    }
    if `p_codes_multidigit' | `p_codes_sparse' {
        local m2 = cond(`p_codes_multidigit', 11, 5)
        local m3 = cond(`p_codes_multidigit', 111, 17)
        quietly recast int xcat
        quietly replace xcat = cond(xcat == 3, `m3', cond(xcat == 2, `m2', 1))
        matrix colnames `B' = a x1 x2 `m2'.xcat `m3'.xcat _cons
        matrix colnames `G' = x1 x2 `m2'.xcat `m3'.xcat _cons
        return local perturb_map "1=1 2=`m2' 3=`m3'"
        local applied `applied' `= cond(`p_codes_multidigit', "codes_multidigit", "codes_sparse")'
    }
    if `p_single_cluster' {
        quietly replace cl = 1
        local applied `applied' single_cluster
    }
    if `p_singleton_clusters' {
        quietly replace cl = id
        local applied `applied' singleton_clusters
    }
    if `p_unsorted' {
        _qa_fxa1_shuffle qa_fx_a1_logit id
        local applied `applied' unsorted
    }
    _qa_fxa1_rename qa_fx_a1_logit `names'
    _qa_fxa1_stripes `B', names(`names')
    _qa_fxa1_stripes `G', names(`names')

    local napplied : word count `applied'
    local expect ""
    if `napplied' == 1 {
        local cls separate:REFUSED collinear:EXACT single_level:REFUSED ///
            base_absent:REFUSED codes_multidigit:INVARIANT codes_sparse:INVARIANT ///
            miss_subgroup:DEGRADED-DECLARED miss_all_column:REFUSED ///
            zero_weight:EXACT extreme_weight:EXACT near_positivity:EXACT ///
            scale_shift:SHIFTED noevent:REFUSED all_treated:REFUSED ///
            single_cluster:REFUSED singleton_clusters:EXACT unsorted:INVARIANT
        foreach c of local cls {
            gettoken cop ccl : c, parse(":")
            if "`cop'" == "`applied'" local expect = substr("`ccl'", 2, .)
        }
    }

    * Truth: marginal over the design cells (restricted to the analysis cells).
    tempname T
    mata: st_matrix("`T'", _qa_fxa1_logit_truth(st_matrix("`C'")))
    quietly count
    local nrows = r(N)
    char _dta[qa_fx_generator] "_qa_fx_a1 qa_fx_a1_logit"
    char _dta[qa_fx_version] "1.1.0"
    char _dta[qa_fx_seed] "`seed'"
    char _dta[qa_fx_perturb] "`applied'"
    foreach s in risk0 risk1 {
        local j = cond("`s'" == "risk0", 1, 2)
        char _dta[qa_truth_`s'] "`: display %21x `T'[1, `j']'"
    }
    matrix colnames `C' = x1 x2 xcat e m0 m1
    return matrix truth_cells = `C'
    return matrix truth_b = `B'
    return matrix truth_g = `G'
    return scalar truth_risk0 = `T'[1, 1]
    return scalar truth_risk1 = `T'[1, 2]
    return scalar truth_rd = `T'[1, 2] - `T'[1, 1]
    return scalar truth_rr = `T'[1, 2] / `T'[1, 1]
    return scalar truth_att = `T'[1, 3]
    return scalar N = `nrows'
    return scalar seed = `seed'
    return local tier "`tier'"
    return local perturb "`ops'"
    return local perturb_applied "`applied'"
    return local expect_class "`expect'"
end

capture program drop qa_fx_a1_sat
program define qa_fx_a1_sat, rclass
    version 16.0
    return add
    syntax , CLEAR [AGGregate PERTurb(string) NAMES(string) SEED(integer 20260929)]
    local known unsorted codes_multidigit codes_sparse
    _qa_fxa1_parse qa_fx_a1_sat `"`known'"' `perturb'
    local ops `s(ops)'
    foreach op of local known {
        local p_`op' = `: list op in ops'
    }
    if `p_codes_multidigit' & `p_codes_sparse' {
        display as error "qa_fx_a1_sat: codes_multidigit and codes_sparse both relabel s"
        exit 198
    }
    if !inrange(`seed',0,2147483647) {
        display as error "qa_fx_a1_sat: invalid seed()"
        exit 198
    }
    local schema s x2 a y
    if "`aggregate'"!="" local schema `schema' f
    else local schema `schema' id
    _qa_fxa1_validate_names, who(qa_fx_a1_sat) vars(`schema') names(`names')
    return clear
    clear
    * s x2 a n events
    tempname C
    matrix `C' = (0,0,0,24,6 \ 0,0,1,12,4 \ 0,1,0,12,4 \ 0,1,1,24,12 \ ///
        1,0,0,18,9 \ 1,0,1,6,4 \ 1,1,0,6,4 \ 1,1,1,18,15)
    matrix colnames `C' = s x2 a n events
    quietly {
        set obs 16
        generate byte s = `C'[ceil(_n/2), 1]
        generate byte x2 = `C'[ceil(_n/2), 2]
        generate byte a = `C'[ceil(_n/2), 3]
        generate byte y = mod(_n, 2) == 1
        generate int f = cond(y, `C'[ceil(_n/2), 5], `C'[ceil(_n/2), 4] - `C'[ceil(_n/2), 5])
        if "`aggregate'" == "" {
            expand f
            drop f
            generate long id = _n
            order id
        }
        sort s x2 a y
    }
    * Self-check: the counts reproduce the stated risks.
    if "`aggregate'" == "" {
        quietly count
        local nrows = r(N)
        quietly count if y == 1
        local nev = r(N)
    }
    else {
        quietly summarize f, meanonly
        local nrows = r(sum)
        quietly summarize f if y == 1, meanonly
        local nev = r(sum)
    }
    if `nrows' != 120 | `nev' != 58 {
        display as error "qa_fx_a1_sat: design lost its counts (N `nrows', events `nev')"
        exit 9
    }
    local applied ""
    if `p_codes_multidigit' | `p_codes_sparse' {
        local m1 = cond(`p_codes_multidigit', 11, 17)
        quietly recast int s
        quietly replace s = cond(s == 1, `m1', 1)
        return local perturb_map "0=1 1=`m1'"
        local applied `applied' `= cond(`p_codes_multidigit', "codes_multidigit", "codes_sparse")'
    }
    if `p_unsorted' {
        set seed `seed'
        _qa_fxa1_shuffle qa_fx_a1_sat "s x2 a y"
        local applied `applied' unsorted
    }
    _qa_fxa1_rename qa_fx_a1_sat `names'

    tempname MH
    mata: st_matrix("`MH'", _qa_fxa1_mh(st_matrix("`C'")))
    char _dta[qa_fx_generator] "_qa_fx_a1 qa_fx_a1_sat"
    char _dta[qa_fx_version] "1.1.0"
    char _dta[qa_fx_seed] ""
    char _dta[qa_fx_perturb] "`applied'"
    char _dta[qa_truth_risk0] "`: display %21x 49/120'"
    char _dta[qa_truth_risk1] "`: display %21x 11/20'"
    return matrix truth_cells = `C'
    return scalar truth_risk0 = 49/120
    return scalar truth_risk1 = 11/20
    return scalar truth_rd = 17/120
    return scalar truth_rr = 66/49
    return scalar truth_crude_risk0 = 23/60
    return scalar truth_crude_risk1 = 7/12
    return scalar truth_att_risk0 = 13/30
    return scalar truth_att_risk1 = 7/12
    return scalar truth_mh_or = `MH'[1, 1]
    return scalar truth_mh_rr = `MH'[1, 2]
    return local truth_risk0_q "49/120"
    return local truth_risk1_q "11/20"
    return local truth_rd_q "17/120"
    return local truth_rr_q "66/49"
    return local truth_att_risk0_q "13/30"
    return scalar N = `nrows'
    return local perturb "`ops'"
    return local perturb_applied "`applied'"
    local expect ""
    if "`applied'" == "unsorted" | "`applied'" == "codes_multidigit" | ///
        "`applied'" == "codes_sparse" local expect INVARIANT
    return local expect_class "`expect'"
end

capture program drop qa_fx_a1_gauss
program define qa_fx_a1_gauss, rclass
    version 16.0
    return add
    syntax , CLEAR [TIER(string) N(integer 0) SEED(integer 20260930) ///
        SIGMA(real 1) HETeroskedastic PERTurb(string) NAMES(string)]
    if "`tier'" == "" local tier unit
    if !inlist("`tier'", "micro", "unit", "recovery", "scale") | ///
        missing(`sigma') | `sigma' <= 0 {
        display as error "qa_fx_a1_gauss: invalid tier() or sigma()"
        exit 198
    }
    if `n' == 0 local n = cond("`tier'" == "micro",36, ///
        cond("`tier'" == "unit",360,cond("`tier'" == "recovery",20016,100008)))
    local n = 36*floor(`n'/36)
    if `n' < 36 | !inrange(`seed',0,2147483647) {
        display as error "qa_fx_a1_gauss: n() must be at least36 and seed() valid"
        exit 198
    }
    local known collinear codes_multidigit codes_sparse miss_subgroup ///
        miss_all_column zero_weight extreme_weight scale_shift unsorted ///
        single_cluster singleton_clusters
    _qa_fxa1_parse qa_fx_a1_gauss `"`known'"' `perturb'
    local ops `s(ops)'
    foreach op of local known {
        local p_`op' = `: list op in ops'
    }
    if (`p_codes_multidigit' & `p_codes_sparse') | ///
        (`p_single_cluster' & `p_singleton_clusters') {
        display as error "qa_fx_a1_gauss: conflicting perturbations"
        exit 198
    }
    local schema id a x1 x2 xcat sd mu y w cl
    if `p_collinear' local schema `schema' x3 x4
    _qa_fxa1_validate_names, who(qa_fx_a1_gauss) vars(`schema') names(`names')
    return clear
    clear
    set seed `seed'
    quietly {
        set obs `n'
        generate long id = _n
        generate byte a = mod(id-1,2)
        generate double x1 = mod(floor((id-1)/2),3)-1
        generate byte x2 = mod(floor((id-1)/6),2)
        generate int xcat = mod(floor((id-1)/12),3)+1
        generate double sd = `sigma'*cond("`heteroskedastic'" != "",1+.5*x2,1)
        generate double mu = 1+2*a+.5*x1-x2+.25*(xcat==2)-.25*(xcat==3)
        generate double y = mu + sd*rnormal()
        generate double w = 1
        generate long cl = ceil(id/12)
        if `p_zero_weight' replace w = 0 if mod(id,10)==0
        if `p_extreme_weight' replace w = 1e4 if id==1
        if `p_single_cluster' replace cl = 1
        if `p_singleton_clusters' replace cl = id
    }
    tempname B V NF
    matrix `B' = (2,.5,-1,.25,-.25,1)
    matrix colnames `B' = a x1 x2 2.xcat 3.xcat _cons
    * Covariance computed on the original full design. Missingness below
    * changes the analysis population and its covariance is not asserted.
    mata: _qa_fxa1_gauss_v("`V'")
    local available = !(`p_miss_subgroup' | `p_miss_all_column')
    if !`available' matrix `V' = J(6,6,.)
    if `p_collinear' {
        quietly generate double x3 = x1
        quietly generate double x4 = x1+x2
        assert x3==x1 & x4==x1+x2
    }
    if `p_miss_subgroup' {
        quietly replace x1 = . if xcat==3 & mod(id,2)==0
        quietly count if missing(x1)
        if r(N)==0 exit 9
        assert xcat==3 if missing(x1)
    }
    if `p_miss_all_column' {
        quietly replace x2 = .
        assert missing(x2)
    }
    if `p_codes_multidigit' {
        quietly replace xcat = cond(xcat==2,11,cond(xcat==3,111,1))
        assert inlist(xcat,1,11,111)
        matrix colnames `B' = a x1 x2 11.xcat 111.xcat _cons
    }
    if `p_codes_sparse' {
        quietly replace xcat = cond(xcat==2,5,cond(xcat==3,17,1))
        assert inlist(xcat,1,5,17)
        matrix colnames `B' = a x1 x2 5.xcat 17.xcat _cons
    }
    if `p_scale_shift' {
        quietly replace x1 = x1+1e8
        assert inlist(x1-1e8,-1,0,1) if !missing(x1)
        matrix `B'[1,6] = 1-.5e8
        tempname T
        matrix `T' = I(6)
        matrix `T'[6,2] = -1e8
        matrix `V' = `T'*`V'*`T''
    }
    if `p_zero_weight' {
        quietly count if w==0
        if r(N)==0 exit 9
    }
    if `p_extreme_weight' assert w==1e4 if id==1
    if `p_single_cluster' assert cl==1
    if `p_singleton_clusters' isid cl
    quietly count if !missing(y,a,x1,x2,xcat,w) & w>0
    scalar `NF' = r(N)
    foreach op of local ops {
        local hits_`op' = `n'
        if inlist("`op'","codes_multidigit","codes_sparse") local hits_`op' = 2*`n'/3
        if "`op'"=="miss_subgroup" local hits_`op' = `n'/6
        if "`op'"=="zero_weight" local hits_`op' = floor(`n'/10)
        if "`op'"=="extreme_weight" local hits_`op' = 1
    }
    if `p_unsorted' {
        _qa_fxa1_shuffle qa_fx_a1_gauss id
        local hits_unsorted = r(moved)
    }
    _qa_fxa1_rename qa_fx_a1_gauss `names'
    local columns : colnames `B'
    matrix colnames `V' = `columns'
    matrix rownames `V' = `columns'
    _qa_fxa1_stripes `B', names(`names')
    _qa_fxa1_stripes `V', names(`names') covariance
    char _dta[qa_truth_b_colnames] "`: colnames `B''"
    char _dta[qa_truth_v_colnames] "`: colnames `V''"
    char _dta[qa_fx_generator] "_qa_fx_a1 qa_fx_a1_gauss"
    char _dta[qa_fx_version] "1.1.0"
    char _dta[qa_fx_seed] "`seed'"
    char _dta[qa_fx_perturb] "`ops'"
    char _dta[qa_truth_effect] "`: display %21x 2'"
    char _dta[qa_truth_sigma] "`: display %21x `sigma''"
    char _dta[qa_truth_n_fit] "`: display %21x scalar(`NF')'"
    char _dta[qa_truth_v_available] "`: display %21x `available''"
    char _dta[qa_truth_error_variance] "`: display %21x `sigma'^2*cond("`heteroskedastic'"!="",1.625,1)'"
    forvalues j=1/6 {
        char _dta[qa_truth_b`j'] "`: display %21x `B'[1,`j']'"
        forvalues k=1/6 {
            char _dta[qa_truth_v`j'_`k'] "`: display %21x `V'[`j',`k']'"
        }
    }
    local expect ""
    if `: word count `ops'' == 1 {
        local expect EXACT
        if inlist("`ops'","unsorted","codes_multidigit","codes_sparse") local expect INVARIANT
        if "`ops'"=="scale_shift" local expect SHIFTED
        if "`ops'"=="miss_all_column" | "`ops'"=="single_cluster" local expect REFUSED
        if "`ops'"=="miss_subgroup" local expect DEGRADED-DECLARED
    }
    foreach op of local ops {
        char _dta[qa_perturb_n_`op'] "`hits_`op''"
        return scalar perturb_n_`op' = `hits_`op''
    }
    return matrix truth_b = `B'
    return matrix truth_v = `V'
    return scalar truth_v_available = `available'
    return scalar truth_effect = 2
    return scalar truth_sigma = `sigma'
    return scalar truth_n_fit = scalar(`NF')
    return scalar truth_error_variance = `sigma'^2*cond("`heteroskedastic'"!="",1.625,1)
    return scalar N = `n'
    return scalar seed = `seed'
    return local tier "`tier'"
    return local perturb "`ops'"
    return local perturb_applied "`ops'"
    return local expect_class "`expect'"
end

capture program drop qa_fx_a1_diag
program define qa_fx_a1_diag, rclass
    version 16.0
    return add
    syntax , CLEAR [AGGregate TIER(string) SEED(integer 20260930) ///
        PERTurb(string) NAMES(string)]
    if "`tier'" == "" local tier unit
    if !inlist("`tier'","micro","unit","recovery","scale") | ///
        !inrange(`seed',0,2147483647) {
        display as error "qa_fx_a1_diag: invalid tier() or seed()"
        exit 198
    }
    local known unsorted codes_multidigit codes_sparse single_level noevent miss_subgroup
    _qa_fxa1_parse qa_fx_a1_diag `"`known'"' `perturb'
    local ops `s(ops)'
    foreach op of local known {
        local p_`op' = `: list op in ops'
    }
    if `p_codes_multidigit' & `p_codes_sparse' {
        display as error "qa_fx_a1_diag: conflicting score relabels"
        exit 198
    }
    _qa_fxa1_validate_names, who(qa_fx_a1_diag) ///
        vars(id y score f a x1 x2 xcat w cl) names(`names')
    return clear
    local multiplier = cond("`tier'"=="micro",.5, ///
        cond("`tier'"=="unit",1,cond("`tier'"=="recovery",200,1000)))
    clear
    set seed `seed'
    quietly {
        set obs 10
        generate byte y = mod(_n-1,2)
        generate double score = ceil(_n/2)
        generate long f = `multiplier'*cond(y,4*score-2,22-4*score)
        if "`aggregate'"=="" {
            expand f
            replace f = 1
        }
        generate long id = _n
        generate byte a = y
        generate double x1 = score
        generate byte x2 = y
        generate int xcat = score
        generate double w = f
        generate long cl = id
        if `p_single_level' replace score = 3
        if `p_noevent' replace y = 0
        if `p_miss_subgroup' replace score = . if y==1 & xcat==5
        if `p_codes_multidigit' replace score = cond(score==1,1,11^(score-1)) if !missing(score)
        if `p_codes_sparse' replace score = 1+4*(score-1)^2 if !missing(score)
    }
    if `p_single_level' assert score==3
    if `p_noevent' assert y==0
    if `p_miss_subgroup' {
        quietly count if missing(score)
        if r(N)==0 exit 9
        assert y==1 & xcat==5 if missing(score)
    }
    if `p_codes_multidigit' assert inlist(score,1,11,121,1331,14641) if !missing(score)
    if `p_codes_sparse' assert inlist(score,1,5,17,37,65) if !missing(score)
    tempname C T Q
    mata: _qa_fxa1_diag_truth("`C'","`T'","`Q'")
    matrix colnames `C' = score negatives positives
    matrix colnames `T' = cutoff sensitivity specificity tp fp tn fn
    foreach op of local ops {
        local hits_`op' = _N
        if inlist("`op'","codes_multidigit","codes_sparse") {
            quietly count if !missing(score) & score!=1
            local hits_`op' = r(N)
        }
        if "`op'"=="miss_subgroup" {
            quietly count if missing(score)
            local hits_`op' = r(N)
        }
    }
    if `p_unsorted' {
        _qa_fxa1_shuffle qa_fx_a1_diag id
        local hits_unsorted = r(moved)
    }
    _qa_fxa1_rename qa_fx_a1_diag `names'
    char _dta[qa_fx_generator] "_qa_fx_a1 qa_fx_a1_diag"
    char _dta[qa_fx_version] "1.1.0"
    char _dta[qa_fx_seed] "`seed'"
    char _dta[qa_fx_perturb] "`ops'"
    forvalues j=1/5 {
        local key : word `j' of auc positives negatives n_fit auc_pair_twice
        char _dta[qa_truth_`key'] "`: display %21x `Q'[1,`j']'"
    }
    char _dta[qa_truth_auc_denominator] "`: display %21x 2*`Q'[1,2]*`Q'[1,3]'"
    local expect ""
    if `: word count `ops'' == 1 {
        local expect INVARIANT
        if "`ops'"=="single_level" local expect EXACT
        if "`ops'"=="noevent" local expect REFUSED
        if "`ops'"=="miss_subgroup" local expect DEGRADED-DECLARED
    }
    foreach op of local ops {
        char _dta[qa_perturb_n_`op'] "`hits_`op''"
        return scalar perturb_n_`op' = `hits_`op''
    }
    return matrix truth_cells = `C'
    return matrix truth_cutoffs = `T'
    return scalar truth_auc = `Q'[1,1]
    return scalar truth_positives = `Q'[1,2]
    return scalar truth_negatives = `Q'[1,3]
    return scalar truth_n_fit = `Q'[1,4]
    return scalar truth_auc_pair_twice = `Q'[1,5]
    return scalar truth_auc_denominator = 2*`Q'[1,2]*`Q'[1,3]
    return scalar N = _N
    return scalar seed = `seed'
    return local tier "`tier'"
    return local perturb "`ops'"
    return local perturb_applied "`ops'"
    return local expect_class "`expect'"
end

capture mata: mata drop _qa_fxa1_gauss_v()
capture mata: mata drop _qa_fxa1_diag_truth()
mata:
void _qa_fxa1_gauss_v(string scalar target)
{
    real matrix d, x, a, v
    real colvector w, sd
    d=st_data(.,("a","x1","x2","xcat","w","sd"))
    x=(d[.,1..3],d[.,4]:==2,d[.,4]:==3,J(rows(d),1,1))
    w=d[.,5]
    sd=d[.,6]
    a=luinv(cross(x,w,x))
    v=a*cross(x,(w:*sd):^2,x)*a'
    st_matrix(target,v)
}
void _qa_fxa1_diag_truth(string scalar cells, string scalar table, string scalar truth)
{
    real matrix d, c, t
    real colvector levels, selected
    real scalar i,j,np,nn,twice,tp,fp,auc
    d=st_data(.,("score","y","f"))
    d=select(d,d[.,1]:<.)
    levels=uniqrows(sort(d[.,1],1))
    c=J(rows(levels),3,0)
    for(i=1;i<=rows(levels);i++) {
        c[i,1]=levels[i]
        for(j=0;j<=1;j++) {
            selected=select(d[.,3],(d[.,1]:==levels[i]):&(d[.,2]:==j))
            c[i,j+2]=sum(selected)
        }
    }
    nn=sum(c[.,2]); np=sum(c[.,3]); twice=0
    for(i=1;i<=rows(c);i++) {
        for(j=1;j<=rows(c);j++) {
            twice=twice+c[i,3]*c[j,2]*(2*(c[i,1]>c[j,1])+(c[i,1]==c[j,1]))
        }
    }
    auc=(np>0 & nn>0 ? twice/(2*np*nn) : .)
    t=J(rows(c),7,.)
    for(i=1;i<=rows(c);i++) {
        tp=sum(select(c[.,3],c[.,1]:>=c[i,1]))
        fp=sum(select(c[.,2],c[.,1]:>=c[i,1]))
        t[i,.]=(c[i,1],(np>0 ? tp/np : .),(nn>0 ? (nn-fp)/nn : .),tp,fp,nn-fp,np-tp)
    }
    st_matrix(cells,c); st_matrix(table,t)
    st_matrix(truth,(auc,np,nn,np+nn,twice))
}
end

capture mata: mata drop _qa_fxa1_logit_gen()
capture mata: mata drop _qa_fxa1_logit_truth()
capture mata: mata drop _qa_fxa1_mh()
mata:
// Cells in a fixed order; per cells each. C (returned through cname) holds
// x1 x2 xcat e m0 m1 for the cells that exist after the design operators.
void _qa_fxa1_logit_gen(real scalar per, real rowvector g, real rowvector b,
    real rowvector f, string scalar cname)
{
    real matrix C, D
    real scalar x1, x2, x, e, m0, m1, r, j, nc, a, y

    C = J(0, 6, .)
    for (x = 1; x <= 3; x++) {
        for (x2 = 0; x2 <= 1; x2++) {
            if (f[2] & x2 == 1) continue
            for (x1 = -1; x1 <= 1; x1++) {
                e = invlogit(g[5] + g[1]*x1 + g[2]*x2 + g[3]*(x == 2) + g[4]*(x == 3))
                if (f[3] & x == 3 & x2 == 1) e = 1 - 1e-4
                m0 = invlogit(b[6] + b[2]*x1 + b[3]*x2 + b[4]*(x == 2) + b[5]*(x == 3))
                m1 = invlogit(b[6] + b[1] + b[2]*x1 + b[3]*x2 + b[4]*(x == 2) + b[5]*(x == 3))
                if (f[1] & x == 3) {
                    m0 = 0
                    m1 = 0
                }
                if (f[4]) {
                    m0 = 0
                    m1 = 0
                }
                C = C \ (x1, x2, x, e, m0, m1)
            }
        }
    }
    // single_level folds x2 = 1 into x2 = 0: keep the row count at 18 x per.
    nc = rows(C)
    per = per * 18 / nc
    D = J(nc*per, 5, .)
    r = 0
    for (j = 1; j <= nc; j++) {
        for (x1 = 1; x1 <= per; x1++) {
            a = runiform(1, 1) < C[j, 4]
            if (f[3] & C[j, 3] == 3 & C[j, 2] == 1) a = 1
            if (f[5]) a = 1
            y = runiform(1, 1) < (a ? C[j, 6] : C[j, 5])
            r++
            D[r, .] = (y, a, C[j, 1], C[j, 2], C[j, 3])
        }
    }
    (void) st_addvar(("byte", "byte", "byte", "byte", "byte"),
        ("y", "a", "x1", "x2", "xcat"))
    st_addobs(rows(D))
    st_store(., ., D)
    if (f[6]) C = select(C, C[., 3] :!= 1)
    st_matrix(cname, C)
}

// Marginal risks over equally weighted cells, and the ATT.
real rowvector _qa_fxa1_logit_truth(real matrix C)
{
    real scalar r0, r1, att
    r0 = mean(C[., 5])
    r1 = mean(C[., 6])
    att = sum(C[., 4] :* (C[., 6] - C[., 5])) / sum(C[., 4])
    return((r0, r1, att))
}

// Mantel-Haenszel OR and RR over the s x x2 strata of the saturated design.
real rowvector _qa_fxa1_mh(real matrix C)
{
    real scalar i, a1, n1, a0, n0, nt, orn, ord, rrn, rrd
    orn = ord = rrn = rrd = 0
    for (i = 1; i <= 7; i = i + 2) {
        a0 = C[i, 5]
        n0 = C[i, 4]
        a1 = C[i+1, 5]
        n1 = C[i+1, 4]
        nt = n0 + n1
        orn = orn + a1*(n0 - a0)/nt
        ord = ord + a0*(n1 - a1)/nt
        rrn = rrn + a1*n0/nt
        rrd = rrd + a0*n1/nt
    }
    return((orn/ord, rrn/rrd))
}
end
