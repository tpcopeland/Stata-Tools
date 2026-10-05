* test_effecttab_v230.do - effecttab 2.3.0: cformat(), frame(name, flat),
* sep() in every sink, footnote() paragraphs
* Expected cells are built by hand from the supplied matrix or the margins
* fit's own r(table), never from the table effecttab builds.

clear all
set more off
set varabbrev off
version 17.0

capture log close _ev230
log using "test_effecttab_v230.log", replace text name(_ev230)

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

* Trimmed cell of column `col' on the one row whose label (variable `lv') is
* `label', from row `from' on.
capture program drop _e23_cell
program define _e23_cell, rclass
    version 17.0
    args fr lv label col from
    frame `fr' {
        tempvar rn
        quietly generate long `rn' = _n
        quietly count if strtrim(`lv') == `"`label'"' & _n >= `from'
        if r(N) != 1 {
            display as error `"frame `fr': `r(N)' rows labelled "`label'""'
            exit 459
        }
        quietly summarize `rn' if strtrim(`lv') == `"`label'"' & _n >= `from', meanonly
        local cell = strtrim(`col'[r(min)])
    }
    return local cell `"`cell'"'
end

capture program drop _e23_slurp
program define _e23_slurp, rclass
    version 17.0
    args fn
    tempname fh
    local all ""
    file open `fh' using `"`fn'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local all `"`macval(all)'|`macval(line)'"'
        file read `fh' line
    }
    file close `fh'
    return local text `"`macval(all)'"'
end

**# cformat() on the from() matrix route
local ++test_count
capture noisily {
    clear
    matrix M = (1234.5678, 1000.125, 1500.9, 0.03 \ 2.5, 1, 3, 0.5)
    matrix rownames M = alpha beta
    effecttab, from(M) cformat(%12.2fc) sep(" to ") frame(_e1, replace) ///
        eplotframe(_e1e, replace)
    _e23_cell _e1 A "alpha" c1 4
    assert "`r(cell)'" == strtrim(string(1234.5678, "%12.2fc"))
    _e23_cell _e1 A "alpha" c2 4
    local w = "(" + strtrim(string(1000.125, "%12.2fc")) + " to " + strtrim(string(1500.9, "%12.2fc")) + ")"
    assert `"`r(cell)'"' == `"`w'"'
    * a format with more decimals than digits() sees the full-precision input
    effecttab, from(M) cformat(%9.4f) frame(_e2, replace)
    _e23_cell _e2 A "alpha" c1 4
    assert "`r(cell)'" == "1234.5678"
    _e23_cell _e2 A "alpha" c2 4
    assert "`r(cell)'" == "(1000.1250, 1500.9000)"
    frame _e1e {
        quietly summarize ll if label == "alpha", meanonly
        assert reldif(r(mean), 1000.125) < 1e-12
    }
}
if _rc == 0 {
    display as result "  PASS: E1 cformat() on from(): estimate and bounds as formatted by hand"
    local ++pass_count
}
else {
    display as error "  FAIL: E1 cformat() from() (rc=`=_rc')"
    local ++fail_count
}

**# cformat() + sep() on a collected margins result, every sink
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly logit foreign mpg weight
    collect clear
    quietly collect: margins, dydx(mpg weight)
    matrix T = r(table)
    local f "`output_dir'/_e23_cf"
    capture erase "`f'.xlsx"
    capture erase "`f'.csv"
    capture erase "`f'.md"
    effecttab, cformat(%9.5f) sep(" to ") frame(_e3, replace flat) ///
        xlsx("`f'.xlsx") sheet("M") csv("`f'.csv") markdown("`f'.md")
    local wb = strtrim(string(T[1, 1], "%9.5f"))
    local wci = "(" + strtrim(string(T[5, 1], "%9.5f")) + " to " + strtrim(string(T[6, 1], "%9.5f")) + ")"
    _e23_cell _e3 rowlabel "Mileage (mpg)" c1 1
    assert "`r(cell)'" == "`wb'"
    _e23_cell _e3 rowlabel "Mileage (mpg)" c2 1
    assert `"`r(cell)'"' == `"`wci'"'
    import excel using "`f'.xlsx", sheet("M") clear allstring
    quietly count if strtrim(B) == "Mileage (mpg)" & strtrim(C) == "`wb'" & strtrim(D) == `"`wci'"'
    assert r(N) == 1
    _e23_slurp "`f'.csv"
    assert strpos(`"`r(text)'"', `"`wci'"') > 0
    _e23_slurp "`f'.md"
    assert strpos(`"`r(text)'"', `"| `wci' |"') > 0
    * refusals
    sysuse auto, clear
    matrix M = (1, 0.5, 1.5, 0.2)
    foreach bad in "%td" "%9s" "%21x" "junk" {
        capture effecttab, from(M) cformat(`bad')
        assert _rc == 198
    }
    capture effecttab, from(M) cformat(%9.2f) digits(2)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: E2 cformat()/sep() in frame, xlsx, csv, md; refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: E2 cformat()/sep() sinks (rc=`=_rc')"
    local ++fail_count
}

**# frame(name, flat)
local ++test_count
capture noisily {
    clear
    matrix M = (1.2, 1.0, 1.4, 0.04 \ 0.8, 0.6, 1.1, 0.2)
    matrix rownames M = Treated Untreated
    effecttab, from(M) effect("RR") models("Main") frame(_e4, flat replace)
    frame _e4 {
        unab vv : *
        assert "`vv'" == "rowlabel c1 c2 c3"
        assert _N == 2
        assert rowlabel[1] == "Treated"
        assert "`: variable label c1'" == "Main, RR"
        assert "`: variable label c2'" == "Main, 95% CI"
        assert "`: variable label c3'" == "Main, p-value"
        assert "`: char _dta[tabtools_layout]'" == "flat"
        assert c1[1] == "1.20"
    }
    effecttab, from(M) effect("RR") frame(_e5, flat replace)
    frame _e5 {
        assert "`: variable label c1'" == "RR"
    }
    capture effecttab, from(M) frame(_e6, flatter)
    assert _rc == 198
    effecttab, from(M) frame(_e7, replace)
    frame _e7: confirm variable title A c1 c2 c3
}
if _rc == 0 {
    display as result "  PASS: E3 frame(name, flat) contract; refusal; plain frame unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: E3 frame(name, flat) (rc=`=_rc')"
    local ++fail_count
}

**# footnote() paragraphs
local ++test_count
capture noisily {
    clear
    matrix M = (1.2, 1.0, 1.4, 0.04)
    matrix rownames M = Treated
    local f "`output_dir'/_e23_fn"
    capture erase "`f'.xlsx"
    capture erase "`f'.csv"
    effecttab, from(M) xlsx("`f'.xlsx") sheet("F") csv("`f'.csv") ///
        footnote("Alpha paragraph. \ Beta paragraph.")
    import excel using "`f'.xlsx", sheet("F") clear allstring
    local n0 = _N
    assert strtrim(B[`n0' - 1]) == "Alpha paragraph."
    assert strtrim(B[`n0']) == "Beta paragraph."
    _e23_slurp "`f'.csv"
    assert strpos(`"`r(text)'"', "Alpha paragraph.") & strpos(`"`r(text)'"', "Beta paragraph.")
}
if _rc == 0 {
    display as result "  PASS: E4 footnote paragraphs: one Excel row each; text forwarded to CSV"
    local ++pass_count
}
else {
    display as error "  FAIL: E4 footnote paragraphs (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text ""
display "RESULT: test_effecttab_v230 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _ev230
if `fail_count' > 0 exit 1
