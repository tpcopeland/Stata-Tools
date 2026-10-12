* test_kmplot_v140.do
* Regression pins for the 2026-10-12 clarity audit (I1-I6, M1-M4, N1)
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-12
*
* Run from kmplot/qa:  stata-mp -b do test_kmplot_v140.do
* The help-example smoke (I5) runs -webuse diet- and needs network access.

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap
quietly do "`qa_dir'/_qa_state.do"
quietly do "`qa_dir'/_qa_lifecycle.do"
quietly do "`qa_dir'/_qa_parity.do"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

capture program drop _km140_result
program define _km140_result, rclass
    args rc label
    if `rc' == 0 {
        display as result "PASS: `label'"
        return scalar pass = 1
    }
    else {
        display as error "FAIL: `label' (rc=`rc')"
        return scalar pass = 0
    }
end

* CIELAB distance between two sRGB colours (0-255) after applying a
* Machado, Oliveira and Fernandes (2009) severity-1.0 matrix to
* linear-light RGB (_literature/kmplot/machado-2009.notes.md).
* kind: none, prot, deut, trit.
mata:
real matrix _km140_cvd(string scalar kind)
{
    if (kind == "prot") return((0.152286, 1.052583, -0.204868 \
        0.114503, 0.786281, 0.099216 \ -0.003882, -0.048116, 1.051998))
    if (kind == "deut") return((0.367322, 0.860646, -0.227968 \
        0.280085, 0.672501, 0.047413 \ -0.011820, 0.042940, 0.968881))
    if (kind == "trit") return((1.255528, -0.076749, -0.178779 \
        -0.078411, 0.930809, 0.147602 \ 0.004733, 0.691367, 0.303900))
    return(I(3))
}

real rowvector _km140_lab(real rowvector rgb, string scalar kind)
{
    real colvector c, xyz
    real rowvector f, w
    real scalar j
    c = (rgb :/ 255)'
    for (j = 1; j <= 3; j++) {
        c[j] = (c[j] <= 0.04045 ? c[j] / 12.92 : ((c[j] + 0.055) / 1.055)^2.4)
    }
    c = _km140_cvd(kind) * c
    c = rowmin((rowmax((c, J(3, 1, 0))), J(3, 1, 1)))
    xyz = (0.4124564, 0.3575761, 0.1804375 \ 0.2126729, 0.7151522, ///
        0.0721750 \ 0.0193339, 0.1191920, 0.9503041) * c
    w = (0.95047, 1, 1.08883)
    f = J(1, 3, .)
    for (j = 1; j <= 3; j++) {
        f[j] = xyz[j] / w[j]
        f[j] = (f[j] > 216 / 24389 ? f[j]^(1/3) : (24389 / 27 * f[j] + 16) / 116)
    }
    return((116 * f[2] - 16, 500 * (f[1] - f[2]), 200 * (f[2] - f[3])))
}

// Minimum pairwise distance over the first k rows of rgb under each kind.
real scalar _km140_mindist(real matrix rgb, real scalar k, string scalar kinds)
{
    string rowvector kl
    real scalar i, j, m, best
    kl = tokens(kinds)
    best = .
    for (m = 1; m <= cols(kl); m++) {
        for (i = 1; i < k; i++) {
            for (j = i + 1; j <= k; j++) {
                best = min((best, norm(_km140_lab(rgb[i, .], kl[m]) - ///
                    _km140_lab(rgb[j, .], kl[m]))))
            }
        }
    }
    return(best)
}
end

* Parse a colour list (quoted RGB triplets or Stata colour names) into a
* k x 3 Mata matrix, reading named colours from their installed style file.
capture program drop _km140_rgb
program define _km140_rgb
    args matname colors
    local n : word count `colors'
    mata: `matname' = J(`n', 3, .)
    forvalues i = 1/`n' {
        local c : word `i' of `colors'
        if wordcount("`c'") != 3 {
            quietly findfile color-`c'.style
            tempname fh
            file open `fh' using `"`r(fn)'"', read text
            file read `fh' line
            while r(eof) == 0 {
                if regexm(`"`macval(line)'"', `"^set rgb "([0-9 ]+)""') {
                    local c = regexs(1)
                }
                file read `fh' line
            }
            file close `fh'
        }
        mata: `matname'[`i', .] = strtoreal(tokens("`c'"))
    }
end

**# I1 default palette

**## I1a default palette survives simulated red-green deficiency
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    kmplot, by(drug)
    local default_colors `"`r(colors)'"'
    assert `: word count `default_colors'' == 7
    _km140_rgb _km140_new `"`default_colors'"'
    * Okabe-Ito (2008) Fig. 16 values, in kmplot's documented order.
    mata: assert(_km140_new == (0,114,178 \ 213,94,0 \ 0,0,0 \ 86,180,233 \ ///
        204,121,167 \ 230,159,0 \ 0,158,115))
    * Any two of the first five: well apart under every simulation.
    mata: st_numscalar("d5", _km140_mindist(_km140_new, 5, "none prot deut trit"))
    assert !missing(scalar(d5)) & scalar(d5) >= 20
    * All seven: still apart under normal, protan and deutan vision.
    mata: st_numscalar("d7", _km140_mindist(_km140_new, 7, "none prot deut"))
    assert !missing(scalar(d7)) & scalar(d7) >= 15
    * The oracle discriminates: the 1.3.1 default fails it, by the audit's
    * cranberry/forest_green collapse (deutan delta-E about 4.2).
    _km140_rgb _km140_old "navy cranberry forest_green dkorange"
    mata: st_numscalar("dold", _km140_mindist(_km140_old, 4, "deut"))
    assert scalar(dold) < 5 & abs(scalar(dold) - 4.2) < 0.1
    scalar drop d5 d7 dold
    mata: mata drop _km140_new _km140_old
}
_km140_result `=_rc' "I1a default palette survives simulated red-green deficiency"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' I1a"

**## I1b default and RGB colours reach every graph sink
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    local svg "`c(tmpdir)'/kmplot_v140_palette.svg"
    local lg "`c(tmpdir)'/kmplot_v140_palette.log"
    capture erase "`svg'"
    log using "`lg'", text replace name(km140pal)
    kmplot, by(drug) ci risktable censor median export("`svg'", replace)
    kmplot, by(drug) ci colors("10 20 30" navy) export("`svg'_rgb.svg", replace)
    log close km140pal
    _kmplot_assert_file_not_contains using "`lg'", pattern("named style")
    foreach hex in 0072B2 D55E00 {
        _kmplot_assert_file_contains using "`svg'", pattern("stroke:#`hex'")
    }
    _kmplot_assert_file_contains using "`svg'_rgb.svg", pattern("stroke:#0A141E")
    _kmplot_assert_file_contains using "`svg'_rgb.svg", pattern("stroke:#1A476F")
    erase "`svg'"
    erase "`svg'_rgb.svg"
    erase "`lg'"
}
local rc = _rc
capture log close km140pal
_km140_result `rc' "I1b default and RGB colours reach every graph sink"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' I1b"

**# I2 fractional weighted risk-table cells

**## I2 fractional pweight counts print to one decimal
local ++test_count
capture noisily {
    sysuse cancer, clear
    gen double w = cond(mod(_n, 3) == 0, 1/3, 1)
    quietly stset studytime [pweight=w], failure(died)
    local svg "`c(tmpdir)'/kmplot_v140_pw.svg"
    kmplot, by(drug) risktable riskevents timepoints(0 10 20) ///
        export("`svg'", replace)
    tempname rt
    matrix `rt' = r(risktable)
    * Independent weighted at-risk and event sums.
    local row = 0
    forvalues g = 1/3 {
        foreach tp in 0 10 20 {
            local ++row
            quietly summarize w if drug == `g' & _t >= `tp', meanonly
            assert !missing(`rt'[`row', 3], r(sum))
            assert reldif(`rt'[`row', 3], r(sum)) < 1e-12
            local nr = `rt'[`row', 3]
            quietly summarize w if drug == `g' & _t <= `tp' & _d, meanonly
            assert !missing(`rt'[`row', 4], r(sum))
            assert reldif(`rt'[`row', 4], r(sum)) < 1e-12
            local ne = `rt'[`row', 4]
            local fnr = cond(`nr' == int(`nr'), strtrim(string(`nr', "%21.0fc")), ///
                strtrim(string(`nr', "%21.1fc")))
            local fne = cond(`ne' == int(`ne'), strtrim(string(`ne', "%21.0fc")), ///
                strtrim(string(`ne', "%21.1fc")))
            _kmplot_assert_file_contains using "`svg'", pattern(">`fnr' (`fne')<")
        }
    }
    * At least one fractional cell exists, so the format is exercised.
    _kmplot_assert_file_contains using "`svg'", pattern(">6.7 (8.3)<")
    * No risk-table cell carries more than one decimal place, and no label
    * anywhere carries the 1.3.1 full-precision float (y labels use %4.2f).
    tempname fh
    file open `fh' using "`svg'", read text
    file read `fh' line
    local long 0
    while r(eof) == 0 {
        if ustrregexm(`"`line'"', ">[^<]*[0-9][.][0-9]{3,}[^<]*<") local long 1
        if ustrregexm(`"`line'"', ">[0-9,.]*[.][0-9]{2,} [(]|[.][0-9]{2,}[)]<") local long 1
        file read `fh' line
    }
    file close `fh'
    assert `long' == 0
    erase "`svg'"
}
_km140_result `=_rc' "I2 fractional pweight counts print to one decimal"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' I2"

**# I3 level() follows Stata's conventions

**## I3a set level is the default level
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    local old_level = c(level)
    set level 90
    kmplot, ci landmark(10)
    local got_level = r(level)
    tempname lm
    matrix `lm' = r(landmarks)
    set level `old_level'
    assert `got_level' == 90
    * Independent log-log bound at z(0.95) from sts generate's Greenwood SE.
    quietly sts generate s = s
    quietly sts generate se = se(s)
    quietly summarize _t if _t <= 10, meanonly
    quietly summarize s if _t == r(max), meanonly
    local s10 = r(mean)
    quietly summarize se if s == `s10', meanonly
    local se10 = r(mean)
    local z = invnormal(0.95)
    local lo = `s10'^exp(`z' * `se10' / (`s10' * abs(log(`s10'))))
    local hi = `s10'^exp(-`z' * `se10' / (`s10' * abs(log(`s10'))))
    assert !missing(`lm'[1, 4], `lm'[1, 5], `lo', `hi')
    assert reldif(`lm'[1, 4], `lo') < 1e-10
    assert reldif(`lm'[1, 5], `hi') < 1e-10
    kmplot, ci landmark(10)
    assert r(level) == `old_level'
}
local rc = _rc
set level 95
_km140_result `rc' "I3a set level is the default level"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' I3a"

**## I3b level() outside Stata's range refuses with the caller state intact
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    foreach bad in 5 9.99 99.991 95.555 100 {
        qa_state_snapshot, tag(lvl)
        capture kmplot, ci level(`bad')
        assert _rc == 198
        qa_state_compare, tag(lvl)
    }
    foreach ok in 10 99.99 {
        kmplot, ci level(`ok') landmark(10)
        assert r(level) == `ok'
    }
}
_km140_result `=_rc' "I3b level() outside Stata's range refuses with the caller state intact"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' I3b"

**## I3c level() keeps if, in, and twoway passthrough options
* Review C1: an implementation that re-ran -syntax- to validate level()
* reset `if', `in' and `options', silently analysing the full sample.
local ++test_count
capture noisily {
    webuse drug2, clear
    quietly stset studytime, failure(died)
    quietly count if age > 50 in 1/40
    local n_sub = r(N)
    assert `n_sub' > 0 & `n_sub' < _N
    kmplot if age > 50 in 1/40, ci landmark(10)
    local n_def = r(N)
    local lm_def = el(r(landmarks), 1, 3)
    local lo_def = el(r(landmarks), 1, 4)
    foreach lv in 95 90 {
        local svg "`c(tmpdir)'/kmplot_v140_level`lv'.svg"
        kmplot if age > 50 in 1/40, ci level(`lv') landmark(10) ///
            text(.5 5 "KMPASSTHRU`lv'") export("`svg'", replace)
        assert r(N) == `n_sub' & `n_def' == `n_sub'
        assert !missing(el(r(landmarks), 1, 3), `lm_def')
        assert el(r(landmarks), 1, 3) == `lm_def'
        if `lv' == 95 assert el(r(landmarks), 1, 4) == `lo_def'
        else assert el(r(landmarks), 1, 4) > `lo_def'
        _kmplot_assert_file_contains using "`svg'", pattern("KMPASSTHRU`lv'")
        erase "`svg'"
    }
}
_km140_result `=_rc' "I3c level() keeps if, in, and twoway passthrough options"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' I3c"

**## R-a/c/d/e review follow-ups: band opacity, whole weighted sums, date
* formats, and the saved SE at S = 0
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    local lg "`c(tmpdir)'/kmplot_v140_review.log"
    log using "`lg'", text replace name(km140rev)
    kmplot, by(drug) ci colors("0 0 255%40" navy) name(rev1, replace)
    log close km140rev
    _kmplot_assert_file_not_contains using "`lg'", pattern("named style")
    erase "`lg'"
    capture kmplot, by(drug) median medianformat(%td)
    assert _rc == 198
    * Saved SE is missing where the estimate has reached 0, as in sts list.
    clear
    input double t byte d
    1 1
    2 1
    3 1
    end
    quietly stset t, failure(d)
    tempfile curve
    kmplot, ci saving("`curve'", replace)
    preserve
    use "`curve'", clear
    assert missing(se) if estimate == 0
    assert !missing(se) if estimate > 0 & estimate < 1
    restore
    * Thirty weights of 0.1 sum to 3 up to rounding error: printed as "3".
    clear
    set obs 30
    gen double t = _n
    gen byte d = 1
    gen double w = 0.1
    quietly stset t [pweight=w], failure(d)
    local svg "`c(tmpdir)'/kmplot_v140_whole.svg"
    kmplot, risktable timepoints(0) export("`svg'", replace)
    assert abs(el(r(risktable), 1, 3) - 3) < 1e-12
    _kmplot_assert_file_contains using "`svg'", pattern(">3<")
    _kmplot_assert_file_not_contains using "`svg'", pattern(">3.0<")
    erase "`svg'"
}
local rc = _rc
capture log close km140rev
_km140_result `rc' "R-a/c/d/e review follow-ups"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' R-acde"

**# I5 every help-file example runs for an installed user

**## I5 help examples run in order from the installed help file
local ++test_count
capture noisily {
    * The copy -net install- put in the sandbox PLUS tree, whatever else an
    * earlier suite in the same session has placed on the adopath.
    local helpfile "`c(sysdir_plus)'k/kmplot.sthlp"
    assert strpos(`"`helpfile'"', "kmplot_qa_plus") > 0
    confirm file `"`helpfile'"'
    tempname fh
    local n 0
    file open `fh' using `"`helpfile'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "{phang2}{cmd:. ") == 1 {
            local ++n
            local ex`n' = substr(`"`macval(line)'"', 16, .)
            local ex`n' = substr(`"`macval(ex`n')'"', 1, strlen(`"`macval(ex`n')'"') - 8)
        }
        file read `fh' line
    }
    file close `fh'
    assert `n' >= 15
    local here "`c(pwd)'"
    local work "`c(tmpdir)'/kmplot_v140_examples"
    capture mkdir "`work'"
    quietly cd "`work'"
    local bad 0
    forvalues i = 1/`n' {
        display as text `"example `i': `macval(ex`i')'"'
        capture noisily `ex`i''
        if _rc {
            local ++bad
            display as error `"  example `i' failed (rc=`=_rc')"'
        }
    }
    quietly cd "`here'"
    assert `bad' == 0
    * The delayed-entry example ran on data with entry times after zero.
    assert "`r(by)'" == "hienergy"
    assert r(n_timepoints) == 4
    foreach f in km_figure.pdf risk.dta {
        capture erase "`work'/`f'"
    }
}
local rc = _rc
capture cd "`qa_dir'"
_km140_result `rc' "I5 help examples run in order from the installed help file"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' I5"

**# I6 lifecycle and surface parity

**## I6a lifecycle: unrelated estimation results do not reach kmplot output
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    local rfile "`c(tmpdir)'/kmplot_v140_lc_risk.dta"
    qa_lifecycle, fita(stcox i.drug) fitb(stcox age) ///
        post(kmplot, by(drug) ci landmark(10 20) median pvalue risktable name(lc1, replace); kmplot, failure risksaving("`rfile'", replace) timepoints(0 10 20) name(lc2, replace))
    erase "`rfile'"
}
_km140_result `=_rc' "I6a lifecycle: unrelated estimation results do not reach kmplot output"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' I6a"

**## I6b lifecycle: saved files describe the latest successful call
local ++test_count
capture noisily {
    local cfile "`c(tmpdir)'/kmplot_v140_lc_curve.dta"
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    kmplot, saving("`cfile'", replace)
    preserve
    use "`cfile'", clear
    assert _N == 49
    restore
    * A second call on different data replaces the file.
    keep if drug == 1
    quietly stset studytime, failure(died)
    kmplot, saving("`cfile'", replace)
    preserve
    use "`cfile'", clear
    assert _N == 21
    datasignature
    local sig "`r(datasignature)'"
    restore
    * A refused call leaves the file alone and posts nothing.
    qa_state_snapshot, tag(lcfail)
    capture kmplot, ci level(5) saving("`cfile'", replace)
    assert _rc == 198
    qa_state_compare, tag(lcfail)
    preserve
    use "`cfile'", clear
    datasignature
    assert "`r(datasignature)'" == "`sig'"
    restore
    erase "`cfile'"
}
_km140_result `=_rc' "I6b lifecycle: saved files describe the latest successful call"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' I6b"

**## I6c parity: one median, p-value, count, and estimate across every sink
local ++test_count
capture noisily {
    sysuse cancer, clear
    keep if drug > 1
    quietly stset studytime, failure(died)
    * Independent oracles: stci median, sts test p-value, direct count.
    quietly stci if drug == 2, median
    scalar med_oracle = r(p50)
    quietly sts test drug, logrank
    scalar p_oracle = chi2tail(r(df), r(chi2))
    quietly count if drug == 3 & _t >= 10
    scalar n_oracle = r(N)
    local rfile "`c(tmpdir)'/kmplot_v140_parity_risk.dta"
    local lg "`c(tmpdir)'/kmplot_v140_parity.log"
    log using "`lg'", text replace name(km140par)
    kmplot, by(drug) median pvalue pvalueformat(%9.6f) ///
        risksaving("`rfile'", replace) timepoints(0 10 20) name(par, replace)
    scalar med_r = r(median_1)
    scalar p_r = r(p)
    scalar n_r = el(r(risktable), 5, 3)
    log close km140par
    assert !missing(scalar(p_oracle)) & scalar(p_oracle) > 0.001
    qa_surface_parity, expect(scalar(med_oracle)) name(median) ///
        result(scalar(med_r)) log("`lg'") logregex("Median \(Other\): ([0-9.]+)")
    qa_surface_parity, expect(scalar(p_oracle)) name(log-rank p) tol(1e-9) ///
        result(scalar(p_r)) log("`lg'") logregex("Log-rank p = ([0-9.]+)")
    capture frame drop km140risk
    frame create km140risk
    frame km140risk: use "`rfile'", clear
    qa_surface_parity, expect(scalar(n_oracle)) name(at risk) ///
        result(scalar(n_r)) frame(km140risk at_risk 5)
    frame drop km140risk
    * Landmark estimate: r(landmarks) against the saved curve data.  The
    * drawn line itself is pinned to the saved data by test_kmplot_v131.do F1
    * (serset variables are tempvars, renamed on every serset use).
    local cfile "`c(tmpdir)'/kmplot_v140_parity_curve.dta"
    kmplot if drug == 2, landmark(10) saving("`cfile'", replace) name(par1, replace)
    scalar lm_r = el(r(landmarks), 1, 3)
    quietly sts generate s_or = s if drug == 2
    quietly summarize _t if drug == 2 & _t <= 10, meanonly
    quietly summarize s_or if drug == 2 & _t == r(max), meanonly
    scalar lm_oracle = r(mean)
    capture frame drop km140curve
    frame create km140curve
    frame km140curve {
        use "`cfile'", clear
        sort time anchor
        gen long obs = _n
        quietly summarize time if time <= 10 & anchor == 0, meanonly
        quietly summarize obs if time == r(max), meanonly
        local lmobs = r(max)
        drop obs
    }
    qa_surface_parity, expect(scalar(lm_oracle)) name(landmark) ///
        result(scalar(lm_r)) frame(km140curve estimate `lmobs')
    frame drop km140curve
    erase "`cfile'"
    erase "`rfile'"
    erase "`lg'"
    scalar drop med_oracle p_oracle n_oracle med_r p_r n_r lm_r lm_oracle
}
local rc = _rc
capture log close km140par
capture frame drop km140risk
capture frame drop km140curve
_km140_result `rc' "I6c parity: one median, p-value, count, and estimate across every sink"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' I6c"

**# M1 confidence bounds at S = 1 and S = 0

**## M1 bounds are missing where S is 1 or 0, under every transform
local ++test_count
capture noisily {
    clear
    input double t byte d byte g
    1 0 1
    2 1 1
    3 1 1
    4 1 1
    5 1 1
    1 0 2
    2 0 2
    end
    quietly stset t, failure(d)
    tempfile curve
    foreach tr in loglog log plain {
        foreach mode in survival failure {
            local f = cond("`mode'" == "failure", "failure", "")
            kmplot, by(g) ci citransform(`tr') `f' landmark(0 1.5 2 5) ///
                saving("`curve'", replace)
            tempname lm
            matrix `lm' = r(landmarks)
            * Group 1: S=1 at 0 and 1.5, 0<S<1 at 2, S=0 at 5.
            assert missing(`lm'[1, 4], `lm'[1, 5], `lm'[2, 4], `lm'[2, 5])
            assert !missing(`lm'[3, 4], `lm'[3, 5])
            assert `lm'[4, 3] == ("`mode'" == "failure")
            assert missing(`lm'[4, 4], `lm'[4, 5])
            * Group 2 (all censored): S=1, no bounds.
            assert missing(`lm'[5, 4], `lm'[5, 5])
            preserve
            use "`curve'", clear
            local one = ("`mode'" == "survival")
            assert missing(lower, upper) if inlist(estimate, 0, 1)
            assert !missing(lower, upper) if !inlist(estimate, 0, 1)
            assert missing(lower, upper) if anchor
            restore
        }
    }
    * sts list reports the same missing bounds at these times.
    quietly sts generate lb = lb(s)
    assert missing(lb) if g == 1 & t == 1
}
_km140_result `=_rc' "M1 bounds are missing where S is 1 or 0, under every transform"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' M1"

**# M2 median display format

**## M2 medians on a fractional time scale are not rounded away
local ++test_count
capture noisily {
    sysuse cancer, clear
    gen double years = studytime / 12
    quietly stset years, failure(died)
    local lg "`c(tmpdir)'/kmplot_v140_median.log"
    log using "`lg'", text replace name(km140med)
    kmplot, by(drug) median medianannotate
    scalar m1 = r(median_1)
    kmplot, by(drug) median medianformat(%4.2f)
    log close km140med
    assert !missing(scalar(m1))
    assert reldif(scalar(m1), 8/12) < 1e-12
    _kmplot_assert_file_contains using "`lg'", pattern("Median (Placebo): .6666667")
    _kmplot_assert_file_contains using "`lg'", pattern("Median (Placebo): 0.67")
    _kmplot_assert_file_not_contains using "`lg'", pattern("Median (Placebo): 0.7")
    foreach bad in "medianformat(%4.2f)" "median medianformat(abc)" "median medianformat(%s)" {
        capture kmplot, by(drug) `bad'
        assert _rc == 198
    }
    erase "`lg'"
    scalar drop m1
}
local rc = _rc
capture log close km140med
_km140_result `rc' "M2 medians on a fractional time scale are not rounded away"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' M2"

**## M2b medians on tied data agree with stci at exact 0.5 plateaus
* Found by crossval_kmplot_survfit.do: with ties, the product-limit value at
* an exact S = 0.5 can be stored as 0.5000000000000001, and 1.3.1 then took
* the next event time as the median.
local ++test_count
capture noisily {
    set seed 20261012
    clear
    set obs 2400
    gen int rep = ceil(_n / 60)
    gen byte grp = mod(_n, 2) + 1
    gen double t0 = cond(runiform() < .4, runiform() * .5, 0)
    gen double tev = t0 + rexponential(1 / cond(grp == 1, .15, .25))
    gen double tcen = t0 + 1 + runiform() * 12
    gen double t = ceil(min(tev, tcen, 5) * 2) / 2
    gen byte d = (tev <= min(tcen, 5))
    replace t0 = floor(t0 * 2) / 2
    tempfile ties
    save "`ties'"
    local checked 0
    foreach r of numlist 10 1/9 {
        use "`ties'", clear
        quietly keep if rep == `r'
        quietly stset t, failure(d) enter(time t0)
        tempname oracle
        matrix `oracle' = J(1, 2, .)
        forvalues g = 1/2 {
            quietly stci if grp == `g', median
            matrix `oracle'[1, `g'] = r(p50)
        }
        kmplot, by(grp) median failure name(m2b, replace)
        foreach mode in failure survival {
            if "`mode'" == "survival" kmplot, by(grp) median name(m2b, replace)
            forvalues g = 1/2 {
                if missing(`oracle'[1, `g']) {
                    assert missing(r(median_`g'))
                }
                else {
                    assert r(median_`g') == `oracle'[1, `g']
                    local ++checked
                }
            }
        }
    }
    * Replicate 10, group 2 is the plateau case: S = 0.5 exactly at t = 1.5.
    assert `checked' >= 30
}
_km140_result `=_rc' "M2b medians on tied data agree with stci at exact 0.5 plateaus"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' M2b"

**# M3 version-literal guard

**## M3 caller literal matches every installed header
local ++test_count
capture noisily {
    foreach f in kmplot _kmplot_risktable _kmplot_times {
        quietly findfile `f'.ado
        tempname fh
        file open `fh' using `"`r(fn)'"', read text
        file read `fh' line
        assert regexm(`"`line'"', "Version ([0-9]+[.][0-9]+[.][0-9]+)")
        local v_`f' = regexs(1)
        local caller ""
        while r(eof) == 0 {
            if regexm(`"`macval(line)'"', `"callerversion[(]"([0-9.]+)"[)]"') {
                local caller = regexs(1)
            }
            file read `fh' line
        }
        file close `fh'
        if "`f'" == "kmplot" local v_caller "`caller'"
    }
    assert "`v_caller'" != ""
    assert "`v_caller'" == "`v_kmplot'"
    assert "`v_kmplot'" == "`v__kmplot_risktable'"
    assert "`v_kmplot'" == "`v__kmplot_times'"
    * The helper reads its own header and still refuses a stale caller.
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    gen byte gid = drug
    capture _kmplot_risktable, grpvar(gid) ngroups(3) graphname(m3) ///
        colors(black) callerversion("0.0.0")
    assert _rc == 498
    _kmplot_risktable, grpvar(gid) ngroups(3) graphname(m3) ///
        colors(black) callerversion("`v_kmplot'")
    capture graph drop m3
}
_km140_result `=_rc' "M3 caller literal matches every installed header"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' M3"

**# N1 importance weights

**## N1 iweight inference treats weights as frequencies
local ++test_count
capture noisily {
    sysuse cancer, clear
    gen byte w = 1 + mod(_n, 2)
    quietly stset studytime [iweight=w], failure(died)
    kmplot, by(drug) ci pvalue landmark(10)
    scalar p_i = r(p)
    scalar lo_i = el(r(landmarks), 1, 4)
    sysuse cancer, clear
    gen byte w = 1 + mod(_n, 2)
    quietly stset studytime [fweight=w], failure(died)
    kmplot, by(drug) ci pvalue landmark(10)
    assert !missing(r(p), scalar(p_i))
    assert reldif(r(p), scalar(p_i)) < 1e-10
    assert !missing(el(r(landmarks), 1, 4), scalar(lo_i))
    assert reldif(el(r(landmarks), 1, 4), scalar(lo_i)) < 1e-10
    scalar drop p_i lo_i
}
_km140_result `=_rc' "N1 iweight inference treats weights as frequencies"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' N1"

local fail_count = `test_count' - `pass_count'
if "`failed'" != "" display as error "Failed:`failed'"
display "RESULT: test_kmplot_v140 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
