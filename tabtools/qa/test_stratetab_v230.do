* test_stratetab_v230.do - stratetab 2.3.0: cformat()/sep() (O1),
* smallcells()/nosmallcells and the session default (W1, brief section 4),
* zeroexact (R3), footnote forwarding (O4).
* Oracles: the strate files' own _Rate/_Lower/_Upper values, the exact
* zero-count limit -ln(alpha/2)/Y from [R] ci, and the files read back.

clear all
set more off
set varabbrev off
version 17.0

capture log close _st230
log using "test_stratetab_v230.log", replace text name(_st230)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global ST_OUT "`output_dir'"
global ST_TOOLS "`qa_dir'/tools"
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
global TABTOOLS_set_smallcells

local pass_count = 0
local fail_count = 0

capture program drop _st_has
program define _st_has, rclass
    version 17.0
    args file needle
    tempname h
    local found 0
    file open `h' using `"`file'"', read text
    file read `h' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`needle'"') local found 1
        file read `h' line
    }
    file close `h'
    return scalar found = `found'
end

* strate files: _st_a (age band, 3 levels), _st_b (drug, 2 levels)
capture program drop _st_files
program define _st_files
    version 17.0
    webuse drugtr, clear
    gen byte agegrp = cond(age < 55, 1, cond(age < 60, 2, 3))
    label define _stag 1 "<55" 2 "55-59" 3 "60+", replace
    label values agegrp _stag
    quietly strate agegrp, output("$ST_OUT/_st_a", replace) nolist
    quietly strate drug, output("$ST_OUT/_st_b", replace) nolist
end

**# S1: cformat() and sep() against the strate file, in every sink
capture noisily {
    _st_files
    use "$ST_OUT/_st_a", clear
    local want = strtrim(string(_Rate[2] * 1000, "%6.2f")) + " (" + strtrim(string(_Lower[2] * 1000, "%6.2f")) + ///
        " to " + strtrim(string(_Upper[2] * 1000, "%6.2f")) + ")"
    local x "$ST_OUT/st_s1.xlsx"
    local c "$ST_OUT/st_s1.csv"
    local m "$ST_OUT/st_s1.md"
    capture erase "`x'"
    stratetab, using("$ST_OUT/_st_a") outcomes(1) cformat(%6.2f) sep(" to ") ///
        frame(_sts1, replace) xlsx("`x'") csv("`c'") markdown("`m'")
    frame _sts1: assert c4[6] == "`want'"
    _st_has "`c'" "`want'"
    assert r(found)
    _st_has "`m'" "`want'"
    assert r(found)
    capture erase "$ST_OUT/st_s1.txt"
    shell python3 "$ST_TOOLS/xlsx_facts.py" "`x'" "Results" "$ST_OUT/st_s1.txt"
    _st_has "$ST_OUT/st_s1.txt" "`want'"
    assert r(found)
    * sep() also reaches the rate-ratio interval
    stratetab, using("$ST_OUT/_st_a" "$ST_OUT/_st_a") outcomes(1) rateratio sep(" to ") frame(_sts1r, replace)
    frame _sts1r: assert strpos(c5[10], " to ") > 0
    capture stratetab, using("$ST_OUT/_st_a") outcomes(1) cformat(%6.2f) digits(2)
    assert _rc == 198
    capture stratetab, using("$ST_OUT/_st_a") outcomes(1) cformat(%td)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: S1 cformat()/sep() equal the strate file in frame, CSV, Markdown, Excel; refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: S1 cformat/sep (rc=`=_rc')"
    local ++fail_count
}

**# S2: smallcells(): 1..#-1 events print as <#, person-time and rate withheld
capture noisily {
    _st_files
    use "$ST_OUT/_st_a", clear
    local d3 = _D[3]
    local r3 = _Rate[3] * 1000
    assert `d3' == 9
    stratetab, using("$ST_OUT/_st_a") outcomes(1) smallcells(10) frame(_sts2, replace)
    assert r(smallcells) == 10
    matrix R = r(rates)
    assert !missing(R[3,1], `r3')
    assert reldif(R[3,1], `r3') < 1e-12
    frame _sts2 {
        assert c2[7] == "<10" & c3[7] == "–" & c4[7] == "–"
        assert c2[6] == "12" & c4[6] != "–"
        local sc : char _dta[tabtools_smallcells]
        assert "`sc'" == "10"
    }
    * the threshold is exclusive: 10 events are printed
    stratetab, using("$ST_OUT/_st_a") outcomes(1) smallcells(9) frame(_sts2b, replace)
    frame _sts2b: assert c2[7] == "9"
    capture stratetab, using("$ST_OUT/_st_a") outcomes(1) smallcells(-2)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: S2 smallcells(): <# with person-time and rate withheld; r(rates) unmasked"
    local ++pass_count
}
else {
    display as error "  FAIL: S2 smallcells (rc=`=_rc')"
    local ++fail_count
}

**# S3: session smallcells default, nosmallcells, explicit precedence
capture noisily {
    _st_files
    global TABTOOLS_set_smallcells 10
    stratetab, using("$ST_OUT/_st_a") outcomes(1) frame(_sts3, replace)
    assert r(smallcells) == 10
    frame _sts3: assert c2[7] == "<10"
    stratetab, using("$ST_OUT/_st_a") outcomes(1) nosmallcells frame(_sts3b, replace)
    assert r(smallcells) == 0
    frame _sts3b: assert c2[7] == "9"
    stratetab, using("$ST_OUT/_st_a") outcomes(1) smallcells(5) frame(_sts3c, replace)
    assert r(smallcells) == 5
    frame _sts3c: assert c2[7] == "9"
    capture stratetab, using("$ST_OUT/_st_a") outcomes(1) smallcells(5) nosmallcells
    assert _rc == 198
    global TABTOOLS_set_smallcells abc
    capture stratetab, using("$ST_OUT/_st_a") outcomes(1)
    assert _rc == 198
    global TABTOOLS_set_smallcells
    stratetab, using("$ST_OUT/_st_a") outcomes(1)
    assert r(smallcells) == 0
}
if _rc == 0 {
    display as result "  PASS: S3 session smallcells default applies; nosmallcells and explicit values take precedence"
    local ++pass_count
}
else {
    display as error "  FAIL: S3 session default (rc=`=_rc')"
    local ++fail_count
}
global TABTOOLS_set_smallcells

**# S4: rateratio withholds ratios whose numerator or reference is masked
capture noisily {
    clear
    input byte g double(_D _Y)
    1 20 1000
    2 3 500
    3 30 900
    end
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.8
    gen double _Upper = _Rate * 1.2
    label variable _Lower "Lower 95% bound"
    label variable _Upper "Upper 95% bound"
    save "$ST_OUT/_st_r1", replace
    replace _D = cond(g == 1, 4, _D * 2)
    replace _Rate = _D / _Y
    replace _Lower = _Rate * 0.8
    replace _Upper = _Rate * 1.2
    save "$ST_OUT/_st_r2", replace
    stratetab, using("$ST_OUT/_st_r1" "$ST_OUT/_st_r2") outcomes(1) rateratio smallcells(5) frame(_sts4, replace)
    frame _sts4 {
        * exposure 2 rows 9-11: g1 has reference D 20 but own D 4 (masked),
        * g2 reference D 3 masked, g3 both visible
        assert c2[9] == "<5" & c5[9] == "–"
        assert c5[10] == "–"
        assert c5[11] != "–" & strpos(c5[11], "(")
    }
}
if _rc == 0 {
    display as result "  PASS: S4 rate ratios withheld when the numerator or the reference count is masked"
    local ++pass_count
}
else {
    display as error "  FAIL: S4 rateratio masking (rc=`=_rc')"
    local ++fail_count
}

**# S5: zeroexact prints the exact zero-count limit; default unchanged
capture noisily {
    clear
    input byte g double(_D _Y)
    1 10 400
    2 0 250
    end
    gen double _Rate = _D / _Y
    gen double _Lower = cond(_D > 0, _Rate * exp(-invnormal(.975) / sqrt(_D)), .)
    gen double _Upper = cond(_D > 0, _Rate * exp(invnormal(.975) / sqrt(_D)), .)
    label variable _Lower "Lower 95% bound"
    label variable _Upper "Upper 95% bound"
    save "$ST_OUT/_st_z", replace
    stratetab, using("$ST_OUT/_st_z") outcomes(1) frame(_sts5a, replace)
    frame _sts5a: assert c4[6] == "0.0 (–)"
    stratetab, using("$ST_OUT/_st_z") outcomes(1) zeroexact digits(2) frame(_sts5b, replace)
    local u = strtrim(string(round(-ln(0.025) / 250 * 1000, 0.01), "%9.2f"))
    frame _sts5b: assert c4[6] == "0.00 (0.00, `u')"
    * the same limit Stata's ci reports for a zero count
    quietly cii means 250 0, poisson
    assert !missing(r(ub) * 1000, -ln(0.025) / 250 * 1000)
    assert reldif(r(ub) * 1000, -ln(0.025) / 250 * 1000) < 1e-6
    stratetab, using("$ST_OUT/_st_z") outcomes(1) zeroexact level(95) cformat(%9.3f) frame(_sts5c, replace)
    frame _sts5c: assert c4[6] == "0.000 (0.000, " + strtrim(string(-ln(0.025) / 250 * 1000, "%9.3f")) + ")"
}
if _rc == 0 {
    display as result "  PASS: S5 zeroexact gives (0, -ln(alpha/2)/Y) as ci means, poisson does; default stays 0.0 (–)"
    local ++pass_count
}
else {
    display as error "  FAIL: S5 zeroexact (rc=`=_rc')"
    local ++fail_count
}

**# S6: footnote forwarded unchanged; Excel writes one row per paragraph
capture noisily {
    _st_files
    local x "$ST_OUT/st_s6.xlsx"
    local c "$ST_OUT/st_s6.csv"
    capture erase "`x'"
    stratetab, using("$ST_OUT/_st_a") outcomes(1) xlsx("`x'") csv("`c'") footnote("One. \ Two.")
    capture erase "$ST_OUT/st_s6.txt"
    shell python3 "$ST_TOOLS/xlsx_facts.py" "`x'" "Results" "$ST_OUT/st_s6.txt"
    _st_has "$ST_OUT/st_s6.txt" "value B8 One."
    assert r(found)
    _st_has "$ST_OUT/st_s6.txt" "value B9 Two."
    assert r(found)
    _st_has "`c'" "One."
    assert r(found)
}
if _rc == 0 {
    display as result "  PASS: S6 footnote forwarded; Excel one row per paragraph"
    local ++pass_count
}
else {
    display as error "  FAIL: S6 footnote (rc=`=_rc')"
    local ++fail_count
}

local _tc = `pass_count' + `fail_count'
display "RESULT: test_stratetab_v230 tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _st230
if `fail_count' > 0 exit 1
