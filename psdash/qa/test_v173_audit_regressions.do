* test_v173_audit_regressions.do -- regressions for the 2026-09-29 review
* Usage: cd psdash/qa && stata-mp -b do test_v173_audit_regressions.do
*
* Covers:
*   A. Common-support bounds are data values. They used to travel through a
*      decimal local, which does not round-trip a double for about a third of
*      values, so the observation that DEFINES a bound was counted outside its
*      own support (overlap, support, qtrim, generate(), multi-group, and the
*      longitudinal helper) and r(lower_bound)/r(upper_bound) were off by an
*      ulp. Every fixture asserts first that its bound value does NOT survive
*      the macro round trip, so the fixture stays adversarial.
*   B. A two-valued covariate stored as a non-round-trip double (a centred or
*      rescaled indicator) was misread as continuous: sample variance instead
*      of p(1-p), and counted in the VR verdict.
*   C. Balance-table cells were narrower than their headers, so a negative
*      value fused with the previous cell ("1.04-0.032").

clear all
version 16.0
set linesize 200

capture log close _all
log using "test_v173_audit_regressions.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"

global PSDASH_V173_TEST = 0
global PSDASH_V173_PASS = 0
global PSDASH_V173_FAIL = 0

capture program drop _v173_record
program define _v173_record
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
        global PSDASH_V173_PASS = $PSDASH_V173_PASS + 1
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        global PSDASH_V173_FAIL = $PSDASH_V173_FAIL + 1
    }
    global PSDASH_V173_TEST = $PSDASH_V173_TEST + 1
end

* Find a double in (lo, hi) whose decimal macro text lands on the given side
* of the true value: side "up" means the text parses ABOVE the double (a lower
* bound that would push its own observation outside), "down" means below.
capture program drop _v173_find_value
program define _v173_find_value, rclass
    args lo hi side
    tempname x
    local found = 0
    forvalues k = 1/5000 {
        scalar `x' = `lo' + (`hi' - `lo') * `k' / 5003.7
        local txt = `x'
        if "`side'" == "up" & `txt' > `x' {
            local found = 1
            continue, break
        }
        if "`side'" == "down" & `txt' < `x' {
            local found = 1
            continue, break
        }
    }
    if !`found' {
        display as error "no adversarial value found in (`lo', `hi')"
        exit 9
    }
    return scalar value = `x'
end

* Binary fixture: treated {L, .3, .35, .7}, control {.1, .3, .38, U} with L the
* treated minimum (the lower bound) and U the control maximum (upper bound).
* Truth: exactly the control .1 and the treated .7 lie outside [L, U].
capture program drop _v173_binary_data
program define _v173_binary_data
    args L U
    * L and U are placeholders; callers overwrite rows 1 and 8 with the exact
    * scalars (passing them as arguments would round them through text).
    clear
    set obs 8
    gen byte t = _n <= 4
    gen double ps = .
    replace ps = `L' in 1
    replace ps = .3 in 2
    replace ps = .35 in 3
    replace ps = .7 in 4
    replace ps = .1 in 5
    replace ps = .3 in 6
    replace ps = .38 in 7
    replace ps = `U' in 8
end

tempname L U
_v173_find_value .2 .29 up
scalar `L' = r(value)
* Doubles in [.5, 1) always survive the round trip, so the adversarial upper
* bound must lie below .5.
_v173_find_value .4 .45 down
scalar `U' = r(value)

**# A1: fixture is adversarial (bounds do not survive a decimal local)
capture noisily {
    local Ltxt = `L'
    local Utxt = `U'
    assert `Ltxt' > `L'
    assert `Utxt' < `U'
}
_v173_record `=_rc' "A1: fixture bound values do not round-trip through a macro"

**# A2: psdash overlap counts only the true outside observations
capture noisily {
    _v173_binary_data 0 0
    replace ps = `L' in 1
    replace ps = `U' in 8
    quietly psdash overlap t ps, nograph
    assert r(n_outside) == 2
    assert !missing(r(pct_outside))
    assert reldif(r(pct_outside), 25) < 1e-12
    assert r(overlap_lower) == `L'
    assert r(overlap_upper) == `U'
    count if ps < r(overlap_lower) | ps > r(overlap_upper)
    assert r(N) == 2
}
_v173_record `=_rc' "A2: overlap n_outside and exact overlap bounds"

**# A3: psdash support min-max bounds, arm split, and generate() indicator
capture noisily {
    _v173_binary_data 0 0
    replace ps = `L' in 1
    replace ps = `U' in 8
    quietly psdash support t ps, nograph generate(insup)
    assert r(n_outside) == 2
    assert r(n_outside_treated) == 1
    assert r(n_outside_control) == 1
    assert r(lower_bound) == `L'
    assert r(upper_bound) == `U'
    * The bound-defining observations are inside their own support.
    assert insup[1] == 1
    assert insup[8] == 1
    quietly count if insup == 1
    assert r(N) == 6
    assert insup[4] == 0 & insup[5] == 0
}
_v173_record `=_rc' "A3: support bounds exact; generate() keeps bound observations"

**# A4: quantile-bound route (qtrim) uses the same exact comparison
capture noisily {
    _v173_binary_data 0 0
    replace ps = `L' in 1
    replace ps = `U' in 8
    * With 4 observations per arm, p1/p99 are the arm minimum/maximum.
    _pctile ps if t == 1, p(1 99)
    assert r(r1) == `L'
    _pctile ps if t == 0, p(1 99)
    assert r(r2) == `U'
    quietly psdash support t ps, nograph qtrim(1)
    assert r(n_outside) == 2
    assert r(lower_bound) == `L'
    assert r(upper_bound) == `U'
}
_v173_record `=_rc' "A4: qtrim bounds exact"

**# A5: multi-group observed-arm overlap counts
capture noisily {
    clear
    set obs 9
    gen byte arm = floor((_n - 1) / 3)
    gen double own = .
    * arm 0: {L, .35, .9}; arm 1: {.15, .35, U}; arm 2: {.15, .35, .8}
    replace own = `L' in 1
    replace own = .35 in 2
    replace own = .9 in 3
    replace own = .15 in 4
    replace own = .35 in 5
    replace own = `U' in 6
    replace own = .15 in 7
    replace own = .35 in 8
    replace own = .8 in 9
    gen double p0 = cond(arm == 0, own, (1 - own) / 2)
    gen double p1 = cond(arm == 1, own, (1 - own) / 2)
    gen double p2 = cond(arm == 2, own, (1 - own) / 2)
    quietly psdash overlap arm, psvars(p0 p1 p2) nograph
    * Truth: .9 (arm 0), .15 (arm 1), .15 and .8 (arm 2) lie outside [L, U].
    assert r(overlap_lower) == `L'
    assert r(overlap_upper) == `U'
    assert r(n_outside) == 4
    quietly psdash support arm, psvars(p0 p1 p2) nograph
    assert r(n_outside) == 4
    assert r(n_outside_group_0) == 1
    assert r(n_outside_group_1) == 1
    assert r(n_outside_group_2) == 2
    assert r(lower_bound) == `L'
    assert r(upper_bound) == `U'
}
_v173_record `=_rc' "A5: multi-group overlap/support outside counts and bounds"

**# A6: longitudinal per-period overlap uses exact bounds
capture noisily {
    _v173_binary_data 0 0
    replace ps = `L' in 1
    replace ps = `U' in 8
    gen int period = 0
    tempfile one
    save `one'
    replace period = 1
    append using `one'
    gen double w = cond(t, 1 / ps, 1 / (1 - ps))
    gen byte touse = 1
    quietly _psdash_ltmle_diagnostics, treatment(t) period(period) ///
        psvar(ps) wvar(w) samplevar(touse)
    tempname O
    matrix `O' = r(overlap_by_period)
    assert rowsof(`O') == 2
    forvalues p = 1/2 {
        assert !missing(`O'[`p', 12])
        assert reldif(`O'[`p', 12], 25) < 1e-12
        assert `O'[`p', 10] == `L'
        assert `O'[`p', 11] == `U'
    }
    assert !missing(r(max_pct_outside))
    assert reldif(r(max_pct_outside), 25) < 1e-12
}
_v173_record `=_rc' "A6: longitudinal per-period pct_outside and bounds"

**# A7: seeded sweep against an independent scalar oracle (all routes)
capture noisily {
    local nbad = 0
    forvalues s = 1/20 {
        clear
        set seed `s'
        set obs 300
        gen int period = mod(_n, 3)
        gen byte t = runiform() < .5
        gen double ps = cond(t, .2 + .7 * runiform(), .1 + .7 * runiform())
        gen double w = cond(t, 1 / ps, 1 / (1 - ps))
        gen byte touse = 1
        * Oracle: bounds held in scalars, pooled over periods and per period.
        tempname a1 b1 a0 b0
        quietly summarize ps if t == 1
        scalar `a1' = r(min)
        scalar `b1' = r(max)
        quietly summarize ps if t == 0
        scalar `a0' = r(min)
        scalar `b0' = r(max)
        quietly count if ps < max(`a1', `a0') | ps > min(`b1', `b0')
        local truth = r(N)
        quietly psdash overlap t ps, nograph
        if r(n_outside) != `truth' local ++nbad
        quietly psdash support t ps, nograph
        if r(n_outside) != `truth' local ++nbad
        quietly _psdash_ltmle_diagnostics, treatment(t) period(period) ///
            psvar(ps) wvar(w) samplevar(touse)
        tempname O
        matrix `O' = r(overlap_by_period)
        forvalues p = 0/2 {
            quietly summarize ps if t == 1 & period == `p'
            scalar `a1' = r(min)
            scalar `b1' = r(max)
            quietly summarize ps if t == 0 & period == `p'
            scalar `a0' = r(min)
            scalar `b0' = r(max)
            quietly count if period == `p' & ///
                (ps < max(`a1', `a0') | ps > min(`b1', `b0'))
            local ptruth = 100 * r(N) / 100
            if reldif(`O'[`p' + 1, 12], `ptruth') > 1e-12 local ++nbad
        }
    }
    display as text "  sweep disagreements: `nbad'"
    assert `nbad' == 0
}
_v173_record `=_rc' "A7: 20-seed sweep, overlap/support/longitudinal vs scalar oracle"

**# B1: two-valued double covariate is binary (binary treatment)
capture noisily {
    clear
    set seed 11
    set obs 300
    gen byte t = runiform() < .5
    gen byte b = runiform() < .3 + .2 * t
    gen double bs = (b - .4) / .49
    * Adversarial: at least one support point does not survive a macro.
    summarize bs
    tempname smin smax
    scalar `smin' = r(min)
    scalar `smax' = r(max)
    local mintxt = `smin'
    local maxtxt = `smax'
    assert `mintxt' != `smin' | `maxtxt' != `smax'
    quietly psdash balance t, nowvar covariates(b bs)
    tempname B
    matrix `B' = r(balance)
    assert !missing(`B'[1, 3]) & !missing(`B'[2, 3])
    * The SMD is invariant to an affine recoding of an indicator.
    assert reldif(`B'[2, 3], `B'[1, 3]) < 1e-10
    assert !missing(`B'[1, 4]) & !missing(`B'[2, 4])
    assert reldif(`B'[2, 4], `B'[1, 4]) < 1e-10
    assert r(n_binary_vr) == 2
    assert "`r(vr_na_vars)'" == "b bs"
    * Independent oracle: Austin (2009) binary SMD from prevalences.
    summarize b if t == 1, meanonly
    local p1 = r(mean)
    summarize b if t == 0, meanonly
    local p0 = r(mean)
    local smd = (`p1' - `p0') / sqrt((`p1' * (1 - `p1') + `p0' * (1 - `p0')) / 2)
    assert !missing(`smd') & !missing(`B'[2, 3])
    assert reldif(`B'[2, 3], `smd') < 1e-10
}
_v173_record `=_rc' "B1: rescaled indicator classified binary; Austin binary SMD"

**# B2: two-valued double covariate is binary (multi-group treatment)
capture noisily {
    clear
    set seed 12
    set obs 450
    gen byte arm = mod(_n, 3)
    gen byte b = runiform() < .3 + .15 * arm
    gen double bs = (b - .4) / .49
    gen double w = 1
    quietly psdash balance arm, wvar(w) covariates(b bs)
    tempname B
    matrix `B' = r(balance)
    assert r(n_binary_vr) == 2
    assert "`r(vr_na_vars)'" == "b bs"
    * SMD columns 3 and 8 (raw 1v0, 2v0) must agree across b and bs.
    foreach c in 3 8 {
        assert !missing(`B'[1, `c']) & !missing(`B'[2, `c'])
        assert reldif(`B'[2, `c'], `B'[1, `c']) < 1e-10
    }
}
_v173_record `=_rc' "B2: multi-group rescaled indicator classified binary"

* Read the table row that begins with a covariate label from a text log.
capture program drop _v173_row
program define _v173_row, rclass
    args logfile label
    tempname fh
    local row ""
    local raw ""
    file open `fh' using `"`logfile'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local t = strtrim(`"`macval(line)'"')
        if substr(`"`t'"', 1, strlen("`label' |")) == "`label' |" {
            local row `"`t'"'
            local raw `"`macval(line)'"'
        }
        file read `fh' line
    }
    file close `fh'
    return local row `"`row'"'
    return local raw `"`raw'"'
end

**# C1: binary balance table separates every cell, including negatives
capture noisily {
    * Deterministic fixture whose adjusted SMD (printed after the KS cell) is
    * negative: one heavily weighted high-x control pulls the weighted
    * control mean above the treated mean.
    clear
    input byte t double x double w
    1 1   1
    1 2   1
    1 3   1
    1 4   1
    0 1.5 1
    0 2.5 1
    0 3.5 1
    0 6   5
    end
    tempfile disp
    tempname B
    capture log close v173disp
    log using `"`disp'"', text name(v173disp) replace
    psdash balance t, wvar(w) covariates(x) ks
    * r(balance) is read before log close, which replaces r().
    matrix `B' = r(balance)
    log close v173disp
    assert `B'[1, 8] < 0
    _v173_row `"`disp'"' "x"
    local row `"`r(row)'"'
    assert `"`row'"' != ""
    assert !regexm(`"`row'"', "[0-9]-")
    * Covariate, bar, 6 numeric cells (SMD/VR/KS raw and adjusted), status.
    local body = substr(`"`row'"', strpos(`"`row'"', "|") + 1, .)
    assert wordcount(`"`body'"') == 7
    local smd_adj : word 4 of `body'
    assert `"`smd_adj'"' == strtrim(string(`B'[1, 8], "%6.3f"))
}
_v173_record `=_rc' "C1: binary table cells separated (negative adjusted SMD)"

**# C2: multi-group balance table separates every cell
capture noisily {
    clear
    set seed 7
    set obs 900
    gen x1 = rnormal()
    gen u = runiform()
    gen byte a = cond(u < .33, 0, cond(u < .66, 1, 2))
    replace a = 2 if x1 > 1.5 & runiform() < .5
    quietly mlogit a x1
    predict double p0 p1 p2, pr
    gen double w = cond(a == 0, 1 / p0, cond(a == 1, 1 / p1, 1 / p2))
    tempfile disp
    tempname B
    capture log close v173disp
    log using `"`disp'"', text name(v173disp) replace
    psdash balance a, wvar(w) covariates(x1) ks
    matrix `B' = r(balance)
    log close v173disp
    * Adversarial: some adjusted SMD is negative.
    assert `B'[1, 13] < 0 | `B'[1, 18] < 0
    _v173_row `"`disp'"' "x1"
    local row `"`r(row)'"'
    assert `"`row'"' != ""
    assert !regexm(`"`row'"', "[0-9]-")
    * 2 contrasts x (SMD VR KS), raw and adjusted, + status = 13
    local body = substr(`"`row'"', strpos(`"`row'"', "|") + 1, .)
    assert wordcount(`"`body'"') == 13
}
_v173_record `=_rc' "C2: multi-group table cells separated"

**# C3: matched table aligns values under the wider "SMD (Matched)" header
capture noisily {
    clear
    input byte t double x
    1 1
    1 2
    1 3
    1 4
    0 1.5
    0 2.5
    0 3.5
    0 6
    end
    tempfile disp
    tempname B
    capture log close v173disp
    log using `"`disp'"', text name(v173disp) replace
    psdash balance t, covariates(x) matched nowvar
    matrix `B' = r(balance)
    log close v173disp
    _v173_row `"`disp'"' "Covariate"
    local hdr `"`r(raw)'"'
    _v173_row `"`disp'"' "x"
    local row `"`r(raw)'"'
    assert `"`hdr'"' != "" & `"`row'"' != ""
    local cell = strtrim(string(`B'[1, 3], "%6.3f"))
    local hdr_end = strpos(`"`hdr'"', "SMD (Matched)") + strlen("SMD (Matched)") - 1
    local row_end = strpos(`"`row'"', " `cell' ") + strlen("`cell'")
    assert strpos(`"`hdr'"', "SMD (Matched)") > 0
    assert strpos(`"`row'"', " `cell' ") > 0
    assert `hdr_end' == `row_end'
}
_v173_record `=_rc' "C3: matched SMD column aligned under its header"

**# D1: treatment-only matched balance needs no PS and ignores stale e()
capture noisily {
    clear
    input byte t double x
    1 1
    1 2
    1 3
    1 4
    0 1.5
    0 2.5
    0 3.5
    0 6
    end
    * Oracle: Austin (2009) continuous SMD with the pooled sample SD.
    quietly summarize x if t == 1
    local m1 = r(mean)
    local v1 = r(Var)
    quietly summarize x if t == 0
    local m0 = r(mean)
    local v0 = r(Var)
    local smd = abs(`m1' - `m0') / sqrt((`v1' + `v0') / 2)
    ereturn clear
    psdash balance t, covariates(x) matched
    assert r(N) == 8
    assert !missing(r(max_smd_raw)) & !missing(`smd')
    assert reldif(r(max_smd_raw), `smd') < 1e-12
    * A stale, unrelated model must not be consumed by an explicit call.
    quietly logit t x
    psdash balance t, covariates(x) matched
    assert r(N) == 8
    assert !missing(r(max_smd_raw)) & !missing(`smd')
    assert reldif(r(max_smd_raw), `smd') < 1e-12
    * matched and wvar() stay mutually exclusive on this route.
    gen double w = 1
    capture psdash balance t, covariates(x) matched wvar(w)
    assert _rc == 198
}
_v173_record `=_rc' "D1: treatment-only matched balance"

**# D2: strategies() refuses a strategy whose weight is undefined at PS 0/1
capture noisily {
    clear
    set seed 5
    set obs 200
    gen byte t = _n <= 100
    gen x = rnormal() + .5 * t
    gen double ps = invlogit(.5 * x)
    * One control at PS = 1: its ATT (e/(1-e)) and ATE (1/(1-e)) weights do
    * not exist, while its supplied weight and the ATC weight (1) do.
    replace ps = 1 in 200
    gen double w = 1
    capture noisily psdash balance t ps, covariates(x) wvar(w) ///
        strategies(raw att) name(v173_s1)
    assert _rc == 459
    * The analytical table is still posted on the full sample.
    assert r(N) == 200
    assert r(n_ps_boundary) == 1
    capture noisily psdash balance t ps, covariates(x) wvar(w) ///
        strategies(raw ate) name(v173_s2)
    assert _rc == 459
    capture noisily psdash balance t ps, covariates(x) wvar(w) ///
        strategies(raw atc) name(v173_s3)
    assert _rc == 0
    replace ps = .99 in 200
    capture noisily psdash balance t ps, covariates(x) wvar(w) ///
        strategies(raw ate att atc) name(v173_s4)
    assert _rc == 0
    graph drop _all
}
_v173_record `=_rc' "D2: strategies() boundary weights refused"

* Does file f contain the exact text built in Mata expression e? Mata reads
* the file and compares without any macro expansion of label text.
capture program drop _v173_file_has
program define _v173_file_has, rclass
    args file expr
    mata: st_local("found", strofreal(strpos(invtokens(cat(st_local("file"))', char(10)), `expr') > 0))
    return scalar found = `found'
end

**# E1: weight-histogram frequency axes print whole counts
capture noisily {
    clear
    set seed 2
    set obs 800
    gen x = rnormal()
    gen t = runiform() < invlogit(x)
    quietly logit t x
    predict double ps, pr
    tempfile svg1 svg2 svg3
    quietly psdash weights t ps, graph name(v173w1)
    quietly graph export `"`svg1'.svg"', name(v173w1) replace as(svg)
    mata: st_numscalar("v173_dec", ustrregexm(invtokens(cat(st_local("svg1") + ".svg")', char(10)), ">[0-9]+\.00<"))
    mata: st_numscalar("v173_int", ustrregexm(invtokens(cat(st_local("svg1") + ".svg")', char(10)), ">[1-9][0-9]+<"))
    assert scalar(v173_dec) == 0
    assert scalar(v173_int) == 1
    * The binary dashboard's weights panel runs the same graph code.
    * Overlap + weights panels; a density axis never reaches 10, so a
    * multi-digit ".00" label can only be a histogram count.
    quietly psdash combined t ps, covariates(x) nobalance nosupport
    quietly graph export `"`svg2'.svg"', name(psdash_combined) replace as(svg)
    mata: st_numscalar("v173_dec", ustrregexm(invtokens(cat(st_local("svg2") + ".svg")', char(10)), ">[1-9][0-9]+\.00<"))
    mata: st_numscalar("v173_int", ustrregexm(invtokens(cat(st_local("svg2") + ".svg")', char(10)), ">[1-9][0-9]+<"))
    assert scalar(v173_int) == 1
    assert scalar(v173_dec) == 0
    * The compact fraction axis keeps its decimals.
    quietly psdash weights t ps, graph compact name(v173w3)
    quietly graph export `"`svg3'.svg"', name(v173w3) replace as(svg)
    mata: st_numscalar("v173_frac", ustrregexm(invtokens(cat(st_local("svg3") + ".svg")', char(10)), ">0\.[0-9][0-9]<"))
    assert scalar(v173_frac) == 1
    graph drop _all
    scalar drop v173_dec v173_int v173_frac
}
_v173_record `=_rc' "E1: weight histogram frequency axis prints whole counts"

* Multi-group fixture with a value-labelled treatment.
capture program drop _v173_mg_labelled
program define _v173_mg_labelled
    clear
    set seed 7
    set obs 900
    gen x1 = rnormal()
    gen u = runiform()
    gen byte a = cond(u < .33, 0, cond(u < .66, 1, 2))
    replace a = 2 if x1 > 1.5 & runiform() < .5
    quietly mlogit a x1
    predict double p0 p1 p2, pr
    gen double w = cond(a == 0, 1 / p0, cond(a == 1, 1 / p1, 1 / p2))
end

**# E2: multi-group Love plot names contrasts by value label, raw and adjusted
capture noisily {
    _v173_mg_labelled
    label define v173arm 0 "Placebo" 1 "Low dose"
    label values a v173arm
    tempfile svg
    quietly psdash balance a, wvar(w) covariates(x1) loveplot name(v173mg)
    quietly graph export `"`svg'.svg"', name(v173mg) replace as(svg)
    local f `"`svg'.svg"'
    * Unlabelled level 2 falls back to its code.
    foreach e in `"">Low dose vs Placebo<""' `"">2 vs Placebo<""' ///
        `""Hollow markers: unadjusted; solid markers: adjusted""' {
        _v173_file_has `"`f'"' `"`e'"'
        assert r(found) == 1
    }
    _v173_file_has `"`f'"' `"">1 vs 0<""'
    assert r(found) == 0
    * Raw (hollow, fill:none) and adjusted (filled) markers are both drawn.
    mata: st_local("v173_hollow", strofreal(ustrregexm(invtokens(cat(st_local("f"))', char(10)), "<circle[^>]*fill:none")))
    mata: st_local("v173_solid", strofreal(ustrregexm(invtokens(cat(st_local("f"))', char(10)), "<circle[^>]*fill:#")))
    assert `v173_hollow' == 1 & `v173_solid' == 1
    * Unweighted: one raw series per contrast and no raw/adjusted note.
    quietly psdash balance a, nowvar covariates(x1) loveplot name(v173mg2)
    quietly graph export `"`svg'.svg"', name(v173mg2) replace as(svg)
    _v173_file_has `"`f'"' `"">Low dose vs Placebo<""'
    assert r(found) == 1
    _v173_file_has `"`f'"' `""Hollow markers""'
    assert r(found) == 0
    graph drop _all
}
_v173_record `=_rc' "E2: multi-group Love plot uses value labels, raw and adjusted"

**# E3: hostile value labels print verbatim (console, Love plot, panels)
capture noisily {
    _v173_mg_labelled
    global V173_HOSTILE "EXPANDED"
    label define v173hl 0 `"Plac\`q'ebo {bf:X} \$V173_HOSTILE "q" }{"' 1 "Low"
    label values a v173hl
    * Expected text, built in Mata from character codes.
    local lab `"("Plac" + char(96) + "q" + char(39) + "ebo {bf:X} " + char(36) + "V173_HOSTILE " + char(34) + "q" + char(34) + " }{")"'
    tempfile disp svg
    capture log close v173disp
    log using `"`disp'"', text name(v173disp) replace
    psdash balance a, wvar(w) covariates(x1) loveplot name(v173hl)
    log close v173disp
    _v173_file_has `"`disp'"' `"("N (Group " + `lab' + "):")"'
    assert r(found) == 1
    quietly graph export `"`svg'.svg"', name(v173hl) replace as(svg)
    _v173_file_has `"`svg'.svg"' `"(">Low vs " + `lab' + "<")"'
    assert r(found) == 1
    _v173_file_has `"`svg'.svg"' `""EXPANDED""'
    assert r(found) == 0
    quietly psdash overlap a, psvars(p0 p1 p2) name(v173ho)
    quietly graph export `"`svg'.svg"', name(v173ho) replace as(svg)
    _v173_file_has `"`svg'.svg"' `"("Pr(A=" + `lab' + " | X)")"'
    assert r(found) == 1
    quietly psdash support a, psvars(p0 p1 p2) nograph
    quietly psdash weights a, wvar(w) graph name(v173hw)
    quietly graph export `"`svg'.svg"', name(v173hw) replace as(svg)
    _v173_file_has `"`svg'.svg"' `"`lab'"'
    assert r(found) == 1
    graph drop _all
    macro drop V173_HOSTILE
}
_v173_record `=_rc' "E3: hostile value labels verbatim across panels"

**# E4: adjusted KS is shown, returned, and equals an independent weighted ECDF
capture noisily {
    clear
    set seed 2
    set obs 800
    gen x = rnormal()
    gen t = runiform() < invlogit(x)
    quietly logit t x
    predict double ps, pr
    gen double w = cond(t, 1 / ps, 1 / (1 - ps))
    tempfile disp
    tempname B
    capture log close v173disp
    log using `"`disp'"', text name(v173disp) replace
    psdash balance t, wvar(w) covariates(x) ks
    matrix `B' = r(balance)
    local max_ks_adj = r(max_ks_adj)
    log close v173disp
    * Oracle: sup over distinct x of |F1w(x) - F0w(x)|, by direct summation.
    mata: _v173x = st_data(., "x"); _v173t = st_data(., "t"); _v173w = st_data(., "w")
    mata: _v173u = uniqrows(_v173x); _v173d = 0
    mata: _v173W1 = sum(_v173w :* (_v173t :== 1)); _v173W0 = sum(_v173w :* (_v173t :== 0))
    mata: for (k = 1; k <= rows(_v173u); k++) _v173d = max((_v173d, abs(sum(_v173w :* (_v173t :== 1) :* (_v173x :<= _v173u[k])) / _v173W1 - sum(_v173w :* (_v173t :== 0) :* (_v173x :<= _v173u[k])) / _v173W0)))
    mata: st_numscalar("v173_ks", _v173d)
    mata: mata drop _v173x _v173t _v173w _v173u _v173d _v173W1 _v173W0
    assert !missing(`B'[1, 10]) & !missing(scalar(v173_ks))
    assert reldif(`B'[1, 10], scalar(v173_ks)) < 1e-10
    assert !missing(`max_ks_adj')
    assert reldif(`max_ks_adj', `B'[1, 10]) < 1e-12
    _v173_row `"`disp'"' "x"
    local body = substr(`"`r(row)'"', strpos(`"`r(row)'"', "|") + 1, .)
    local ks_adj_cell : word 6 of `body'
    assert `"`ks_adj_cell'"' == strtrim(string(`B'[1, 10], "%6.3f"))
    _v173_row `"`disp'"' "Covariate"
    assert strpos(`"`r(row)'"', "KS Adj") > 0
    scalar drop v173_ks
    * Multi-group: the adjusted maximum equals the largest shown adjusted KS.
    _v173_mg_labelled
    capture log close v173disp
    log using `"`disp'"', text name(v173disp) replace
    psdash balance a, wvar(w) covariates(x1) ks
    matrix `B' = r(balance)
    local max_ks_adj = r(max_ks_adj)
    log close v173disp
    local mx = max(`B'[1, 15], `B'[1, 20])
    assert !missing(`mx') & !missing(`max_ks_adj')
    assert reldif(`max_ks_adj', `mx') < 1e-12
    _v173_row `"`disp'"' "x1"
    local body = substr(`"`r(row)'"', strpos(`"`r(row)'"', "|") + 1, .)
    local c1 : word 9 of `body'
    local c2 : word 12 of `body'
    assert `"`c1'"' == strtrim(string(`B'[1, 15], "%6.3f"))
    assert `"`c2'"' == strtrim(string(`B'[1, 20], "%6.3f"))
}
_v173_record `=_rc' "E4: adjusted KS column, return, and independent ECDF agree"

display as text _n "RESULT: test_v173_audit_regressions tests=$PSDASH_V173_TEST pass=$PSDASH_V173_PASS fail=$PSDASH_V173_FAIL skip=0"

local final_rc = cond($PSDASH_V173_FAIL > 0, 9, 0)
_psdash_qa_cleanup
macro drop PSDASH_V173_TEST PSDASH_V173_PASS PSDASH_V173_FAIL
capture log close _all
exit `final_rc'
