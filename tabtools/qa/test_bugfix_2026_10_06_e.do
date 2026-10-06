* test_bugfix_2026_10_06_e.do - ratetab level(), pydigits(), unitlabel(), r(per), r(level)
*
* Contract gaps (2026-10-06): ratetab options pydigits() and unitlabel() and
* stored results r(per) and r(level) had no QA reference.
*
* Bug found while covering them: the default rate-header label was
* string(per, "%21.0fc"), so per(0.5) printed "Per 0 PY" and per(1500.5)
* "Per 1,500 PY" over rates scaled by 0.5 and 1500.5. Fixed: the label is
* per() as typed ("0.5", "1,500.5").
*
* Oracles (independent of ratetab's invpoissontail()/invpoisson() route):
*   exact     chi-square link, lb = invchi2(2D, a)/2/Y and ub = invchi2(2D+2,
*             1-a)/2/Y, and Stata's cii means ..., poisson
*   poisson   strate's _Lower/_Upper from an stset file, and a literal z
*   cluster   poisson ..., irr vce(cluster) level(#): r(table) ll/ul
*   rendering person-time and rate strings built from the unrounded sums
*
* Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off

capture log close _bfe
log using "test_bugfix_2026_10_06_e.log", replace text name(_bfe)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

local pass_count = 0
local fail_count = 0
local orig_level = c(level)

* Three levels of g. Level 1: D=7, Y=123.323456 (two rows); level 2: D=0,
* Y=123.456; level 3: D=9, Y=1000.55 (two rows). One row per cluster id.
capture program drop _bfe_fix
program define _bfe_fix
    version 17.0
    clear
    quietly set obs 5
    gen long id = _n
    gen byte g = cond(_n <= 2, 1, cond(_n == 3, 2, 3))
    gen long ev = cond(_n == 1, 3, cond(_n == 2, 4, cond(_n == 3, 0, cond(_n == 4, 5, 4))))
    gen double py = cond(_n == 1, 41.123456, cond(_n == 2, 82.2, cond(_n == 3, 123.456, cond(_n == 4, 500.25, 500.3))))
end

* Sums by level into r(D) and r(Y)
capture program drop _bfe_sums
program define _bfe_sums, rclass
    version 17.0
    args lev
    quietly summarize ev if g == `lev'
    return scalar D = r(sum)
    quietly summarize py if g == `lev'
    return scalar Y = r(sum)
end

**# L1 level(90), exact: limits equal the chi-square and cii oracles at 90%
capture noisily {
    _bfe_fix
    ratetab g, events(ev) exposure(py) per(1) level(90)
    matrix E90 = r(estimates)
    ratetab g, events(ev) exposure(py) per(1)
    matrix E95 = r(estimates)
    assert rowsof(E90) == 3
    foreach lev in 1 3 {
        _bfe_sums `lev'
        local D = r(D)
        local Y = r(Y)
        local lo = invchi2(2 * `D', 0.05) / 2 / `Y'
        local hi = invchi2(2 * `D' + 2, 0.95) / 2 / `Y'
        assert !missing(E90[`lev', 7]) & !missing(`lo') & reldif(E90[`lev', 7], `lo') < 1e-10
        assert !missing(E90[`lev', 8]) & !missing(`hi') & reldif(E90[`lev', 8], `hi') < 1e-10
        quietly cii means `Y' `D', poisson level(90)
        assert !missing(E90[`lev', 7]) & !missing(r(lb)) & reldif(E90[`lev', 7], r(lb)) < 1e-10
        assert !missing(E90[`lev', 8]) & !missing(r(ub)) & reldif(E90[`lev', 8], r(ub)) < 1e-10
        * 90% limits sit strictly inside the 95% limits
        assert E90[`lev', 7] > E95[`lev', 7] & E90[`lev', 8] < E95[`lev', 8]
        * and the point estimate is D/Y at either level
        assert !missing(E90[`lev', 6]) & !missing(`D' / `Y') & reldif(E90[`lev', 6], `D' / `Y') < 1e-12
    }
    * zero events: (0, -ln(alpha/2)/Y) with alpha/2 = 0.05 at 90%
    _bfe_sums 2
    assert E90[2, 7] == 0
    assert !missing(E90[2, 8]) & !missing(-ln(0.05) / r(Y)) & reldif(E90[2, 8], -ln(0.05) / r(Y)) < 1e-12
    assert !missing(E95[2, 8]) & !missing(-ln(0.025) / r(Y)) & reldif(E95[2, 8], -ln(0.025) / r(Y)) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: L1 level(90) exact limits"
    local ++pass_count
}
else {
    display as error "  FAIL: L1 level(90) exact limits (rc=`=_rc')"
    local ++fail_count
}

**# L2 level(90), ci(poisson): strate's limits and a literal z = 1.6448536269514722
capture noisily {
    clear
    quietly set obs 20
    set seed 20261006
    gen byte g = 1 + (_n > 10)
    gen double t = 1 + 4 * runiform()
    gen byte d = runiform() < 0.5
    quietly replace d = 1 if inlist(_n, 1, 11)
    ratetab g, events(d) exposure(t) ci(poisson) per(1) level(90)
    matrix P = r(estimates)
    quietly stset t, failure(d)
    tempfile sfile
    quietly strate g, level(90) output(`sfile', replace)
    preserve
    quietly use `sfile', clear
    sort g
    forvalues l = 1/2 {
        assert !missing(P[`l', 6]) & !missing(_Rate[`l']) & reldif(P[`l', 6], _Rate[`l']) < 1e-10
        assert !missing(P[`l', 7]) & !missing(_Lower[`l']) & reldif(P[`l', 7], _Lower[`l']) < 1e-10
        assert !missing(P[`l', 8]) & !missing(_Upper[`l']) & reldif(P[`l', 8], _Upper[`l']) < 1e-10
        assert !missing(P[`l', 7]) & !missing(P[`l', 6] * exp(-1.6448536269514722 / sqrt(P[`l', 4]))) & reldif(P[`l', 7], P[`l', 6] * exp(-1.6448536269514722 / sqrt(P[`l', 4]))) < 1e-10
    }
    restore
}
if _rc == 0 {
    display as result "  PASS: L2 level(90) ci(poisson) equals strate"
    local ++pass_count
}
else {
    display as error "  FAIL: L2 level(90) ci(poisson) equals strate (rc=`=_rc')"
    local ++fail_count
}

**# L3 level(90), ci(cluster): poisson, irr, vce(cluster), level(90) limits
capture noisily {
    _bfe_fix
    ratetab g, events(ev) exposure(py) ci(cluster(id)) per(1) level(90)
    matrix C = r(estimates)
    quietly poisson ev ibn.g if g != 2, exposure(py) noconstant vce(cluster id) irr level(90)
    matrix T = r(table)
    * columns of r(table): 1.g 3.g; rows ll = 5, ul = 6
    assert !missing(C[1, 7]) & !missing(T[5, 1]) & !missing(C[1, 8]) & !missing(T[6, 1]) & reldif(C[1, 7], T[5, 1]) < 1e-8 & reldif(C[1, 8], T[6, 1]) < 1e-8
    assert !missing(C[3, 7]) & !missing(T[5, 2]) & !missing(C[3, 8]) & !missing(T[6, 2]) & reldif(C[3, 7], T[5, 2]) < 1e-8 & reldif(C[3, 8], T[6, 2]) < 1e-8
    * at 95% the cluster limits are wider, so level() reached the fit
    ratetab g, events(ev) exposure(py) ci(cluster(id)) per(1)
    matrix C95 = r(estimates)
    assert C95[1, 7] < C[1, 7] & C95[1, 8] > C[1, 8]
    assert C95[3, 7] < C[3, 7] & C95[3, 8] > C[3, 8]
}
if _rc == 0 {
    display as result "  PASS: L3 level(90) ci(cluster) limits"
    local ++pass_count
}
else {
    display as error "  FAIL: L3 level(90) ci(cluster) limits (rc=`=_rc')"
    local ++fail_count
}

**# L4 r(level), r(ci_level), header, methods text, saved dataset follow the level used
capture noisily {
    _bfe_fix
    set level 95
    ratetab g, events(ev) exposure(py) frame(_bfe_f, replace)
    assert r(level) == 95 & r(ci_level) == 95
    frame _bfe_f: assert c4[3] == "Per 1,000 PY (95% CI)"
    assert strpos(r(methods), "with 95% confidence intervals") > 0
    * set level changes the default
    set level 90
    ratetab g, events(ev) exposure(py) frame(_bfe_f, replace)
    assert r(level) == 90 & r(ci_level) == 90
    frame _bfe_f: assert c4[3] == "Per 1,000 PY (90% CI)"
    assert strpos(r(methods), "with 90% confidence intervals") > 0
    * an explicit level() beats set level
    ratetab g, events(ev) exposure(py) level(80) frame(_bfe_f, replace)
    assert r(level) == 80 & r(ci_level) == 80
    frame _bfe_f: assert c4[3] == "Per 1,000 PY (80% CI)"
    * a fractional level is carried as typed, not rounded
    ratetab g, events(ev) exposure(py) level(99.9) frame(_bfe_f, replace)
    assert abs(r(level) - 99.9) < 1e-12 & abs(r(ci_level) - 99.9) < 1e-12
    frame _bfe_f: assert c4[3] == "Per 1,000 PY (99.9% CI)"
    * saving() records the level in labels and a characteristic
    set level 95
    tempfile sv
    ratetab g, events(ev) exposure(py) level(90) saving(`sv', replace)
    preserve
    quietly use `sv', clear
    assert "`: variable label lb'" == "Lower 90% limit of the rate"
    assert "`: variable label ub'" == "Upper 90% limit of the rate"
    assert "`: char _dta[ratetab_level]'" == "90"
    restore
    * out-of-range levels are refused
    foreach bad in 9 9.99 100 150 {
        capture ratetab g, events(ev) exposure(py) level(`bad')
        assert _rc == 198
    }
    frame drop _bfe_f
}
local _l4rc = _rc
set level `orig_level'
if `_l4rc' == 0 {
    display as result "  PASS: L4 r(level) and level provenance"
    local ++pass_count
}
else {
    display as error "  FAIL: L4 r(level) and level provenance (rc=`_l4rc')"
    local ++fail_count
}

**# P1 pydigits(): person-time decimals in frame, csv and markdown; default 0
capture noisily {
    clear
    input byte g long ev double py
    1 3 123.456
    2 4 1234.5678
    3 2 0.4
    end
    * default: whole person-years, thousands separator
    ratetab g, events(ev) exposure(py) frame(_bfe_p, replace)
    frame _bfe_p: assert c3[5] == "123" & c3[6] == "1,235" & c3[7] == "0"
    ratetab g, events(ev) exposure(py) pydigits(0) frame(_bfe_p, replace)
    frame _bfe_p: assert c3[5] == "123" & c3[6] == "1,235" & c3[7] == "0"
    ratetab g, events(ev) exposure(py) pydigits(2) frame(_bfe_p, replace)
    frame _bfe_p: assert c3[5] == "123.46" & c3[6] == "1,234.57" & c3[7] == "0.40"
    ratetab g, events(ev) exposure(py) pydigits(3) frame(_bfe_p, replace)
    frame _bfe_p: assert c3[5] == "123.456" & c3[6] == "1,234.568" & c3[7] == "0.400"
    * the numbers behind it are not rounded
    matrix E = r(estimates)
    assert !missing(E[1, 5]) & !missing(E[2, 5]) & reldif(E[1, 5], 123.456) < 1e-12 & reldif(E[2, 5], 1234.5678) < 1e-12  // stata-dev-ignore: pinned-constant-no-derivation — 123.456 and 1234.5678 are the person-time inputs typed in the fixture above, not package output
    * csv and markdown carry the same text
    local csvf "`output_dir'/_bfe_pyd.csv"
    local mdf "`output_dir'/_bfe_pyd.md"
    capture erase "`csvf'"
    capture erase "`mdf'"
    ratetab g, events(ev) exposure(py) pydigits(2) csv("`csvf'") markdown("`mdf'")
    tempname fh
    file open `fh' using "`csvf'", read text
    local csvtxt ""
    file read `fh' line
    while r(eof) == 0 {
        local csvtxt `"`csvtxt'|`line'"'
        file read `fh' line
    }
    file close `fh'
    assert strpos(`"`csvtxt'"', ",123.46,") > 0
    assert strpos(`"`csvtxt'"', `",1234.57,"') > 0 | strpos(`"`csvtxt'"', `","1,234.57","') > 0
    assert strpos(`"`csvtxt'"', ",0.40,") > 0
    file open `fh' using "`mdf'", read text
    local mdtxt ""
    file read `fh' line
    while r(eof) == 0 {
        local mdtxt `"`mdtxt'|`line'"'
        file read `fh' line
    }
    file close `fh'
    assert strpos(`"`mdtxt'"', "| 123.46 |") > 0
    assert strpos(`"`mdtxt'"', "| 1,234.57 |") > 0
    * pydigits() works on pyscale()d person-time
    ratetab g, events(ev) exposure(py) pyscale(10) pydigits(2) frame(_bfe_p, replace)
    frame _bfe_p: assert c3[5] == "12.35" & c3[6] == "123.46" & c3[7] == "0.04"
    * the range is 0-10
    foreach bad in -1 11 {
        capture ratetab g, events(ev) exposure(py) pydigits(`bad')
        assert _rc == 198
    }
    frame drop _bfe_p
    capture erase "`csvf'"
    capture erase "`mdf'"
}
if _rc == 0 {
    display as result "  PASS: P1 pydigits() rendering"
    local ++pass_count
}
else {
    display as error "  FAIL: P1 pydigits() rendering (rc=`=_rc')"
    local ++fail_count
}

**# U1 r(per) and the rate scaling: rates and limits are the per(1) values times per
capture noisily {
    _bfe_fix
    ratetab g, events(ev) exposure(py) per(1)
    assert r(per) == 1
    matrix B = r(estimates)
    foreach p in 100 1000 100000 0.5 1500.5 {
        ratetab g, events(ev) exposure(py) per(`p')
        assert r(per) == `p'
        matrix M = r(estimates)
        forvalues r = 1/3 {
            foreach c in 6 7 8 {
                assert !missing(M[`r', `c']) & !missing(B[`r', `c'] * `p') & reldif(M[`r', `c'], B[`r', `c'] * `p') < 1e-12
            }
        }
        forvalues lev = 1/3 {
            _bfe_sums `lev'
            assert !missing(M[`lev', 6]) & !missing(`p' * r(D) / r(Y)) & reldif(M[`lev', 6], `p' * r(D) / r(Y)) < 1e-12
        }
    }
    * default per() is 1000
    ratetab g, events(ev) exposure(py)
    assert r(per) == 1000
    * per() is the multiplier; unitlabel() alone leaves it and the numbers alone
    ratetab g, events(ev) exposure(py) per(100) unitlabel(hundred)
    assert r(per) == 100
    matrix M = r(estimates)
    assert !missing(M[1, 6]) & !missing(100 * B[1, 6]) & reldif(M[1, 6], 100 * B[1, 6]) < 1e-12
    * the rate cell in the frame is the per(100) rate to the printed digits
    ratetab g, events(ev) exposure(py) per(100) digits(2) frame(_bfe_u, replace)
    _bfe_sums 1
    local want = string(round(100 * r(D) / r(Y), 0.01), "%24.2f")
    frame _bfe_u: assert substr(c4[5], 1, strpos(c4[5], " (") - 1) == "`want'"
    frame drop _bfe_u
    * refusals
    foreach bad in 0 -5 {
        capture ratetab g, events(ev) exposure(py) per(`bad')
        assert _rc == 198
    }
}
if _rc == 0 {
    display as result "  PASS: U1 r(per) and rate scaling"
    local ++pass_count
}
else {
    display as error "  FAIL: U1 r(per) and rate scaling (rc=`=_rc')"
    local ++fail_count
}

**# U2 unitlabel(): header, methods sentence, saved label; default label is per() as typed
capture noisily {
    _bfe_fix
    * given label appears where documented, verbatim
    ratetab g, events(ev) exposure(py) per(100) unitlabel(hundred) frame(_bfe_u, replace) saving("`output_dir'/_bfe_ul.dta", replace)
    frame _bfe_u: assert c4[3] == "Per hundred PY (95% CI)"
    assert strpos(r(methods), "Incidence rates per hundred person-years with") == 1
    preserve
    quietly use "`output_dir'/_bfe_ul.dta", clear
    assert "`: variable label rate'" == "Rate per hundred person-time"
    restore
    capture erase "`output_dir'/_bfe_ul.dta"
    * a label with a comma and digits is carried as typed
    ratetab g, events(ev) exposure(py) per(100000) unitlabel("100,000") frame(_bfe_u, replace)
    frame _bfe_u: assert c4[3] == "Per 100,000 PY (95% CI)"
    * default label from per()
    local i 0
    foreach p in 1 100 1000 100000 1000000 0.5 0.25 2.5 1500.5 {
        local lab : word `++i' of 1 100 1,000 100,000 1,000,000 0.5 0.25 2.5 1,500.5
        ratetab g, events(ev) exposure(py) per(`p') frame(_bfe_u, replace)
        frame _bfe_u: assert c4[3] == "Per `lab' PY (95% CI)"
        assert strpos(r(methods), "Incidence rates per `lab' person-years with") == 1
    }
    frame drop _bfe_u
}
if _rc == 0 {
    display as result "  PASS: U2 unitlabel() and default label"
    local ++pass_count
}
else {
    display as error "  FAIL: U2 unitlabel() and default label (rc=`=_rc')"
    local ++fail_count
}

local _tc = `pass_count' + `fail_count'
display "RESULT: test_bugfix_2026_10_06_e tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _bfe
if `fail_count' > 0 exit 1
