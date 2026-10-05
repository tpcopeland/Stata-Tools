* test_comptab_v230.do - comptab/hrcomptab 2.3.0: cformat()/cisep() (O1),
* frame(name, flat) (I2), several models per outcome, keyed placement,
* rates-only sections and modelonly (F4/R1), footnote forwarding (O4).
* Oracles: each fit's own r(table) and _b/_se (never comptab's companion),
* the regtab source frames' printed cells, hand-built expected strings, and
* the written files read back (openpyxl via tools/xlsx_facts.py; CSV and
* Markdown text).

clear all
set more off
set varabbrev off
version 17.0

capture log close _ct230
log using "test_comptab_v230.log", replace text name(_ct230)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global CT_OUT "`output_dir'"
global CT_TOOLS "`qa_dir'/tools"
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
global TABTOOLS_set_smallcells

local pass_count = 0
local fail_count = 0

* r(found) = 1 when a line of the file contains the text
capture program drop _ct_has
program define _ct_has, rclass
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

* xlsx facts of one sheet into a text file
capture program drop _ct_xlsx
program define _ct_xlsx
    version 17.0
    args book sheet out
    capture erase `"`out'"'
    shell python3 "$CT_TOOLS/xlsx_facts.py" "`book'" "`sheet'" "`out'"
    confirm file `"`out'"'
end

**# Fixtures: two auto regressions and a survival setup
capture program drop _ct_auto_frames
program define _ct_auto_frames
    version 17.0
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight foreign
    quietly regtab, frame(_ctf1, replace) eplotframe(_ctf1e, replace) noint models("Base \ Adjusted")
    collect clear
    quietly collect: regress price i.rep78 mpg
    quietly collect: regress price i.rep78 mpg foreign
    quietly regtab, frame(_ctf2, replace) eplotframe(_ctf2e, replace) noint models("Base \ Adjusted")
end

capture program drop _ct_surv
program define _ct_surv
    version 17.0
    webuse drugtr, clear
    gen byte agegrp = cond(age < 55, 1, cond(age < 60, 2, 3))
    label define _ctag 1 "<55" 2 "55-59" 3 "60+", replace
    label values agegrp _ctag
    label variable agegrp "Age band"
    label define _ctdg 0 "Placebo" 1 "Drug", replace
    label values drug _ctdg
    label variable drug "Treatment"
    gen long id = _n
end

**# C1: vertical cformat() + cisep(): every sink against r(table)
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    matrix T1 = r(table)
    quietly regress price mpg weight foreign
    matrix T2 = r(table)
    _ct_auto_frames
    local x "$CT_OUT/ct_c1.xlsx"
    local c "$CT_OUT/ct_c1.csv"
    local m "$CT_OUT/ct_c1.md"
    capture erase "`x'"
    comptab _ctf1, rows(1 2) cformat(%9.3fc) cisep(" to ") frame(_ctc1, replace) ///
        xlsx("`x'") sheet("C1") csv("`c'") markdown("`m'")
    * mpg row: Base model c1/c2, Adjusted model c4/c5
    local e1 = strtrim(string(T1[1,1], "%9.3fc"))
    local ci1 = "(" + strtrim(string(T1[5,1], "%9.3fc")) + " to " + strtrim(string(T1[6,1], "%9.3fc")) + ")"
    local e2 = strtrim(string(T2[1,2], "%9.3fc"))
    local ci2 = "(" + strtrim(string(T2[5,2], "%9.3fc")) + " to " + strtrim(string(T2[6,2], "%9.3fc")) + ")"
    frame _ctc1: assert strtrim(c1[4]) == "`e1'" & strtrim(c2[4]) == "`ci1'"
    frame _ctc1: assert strtrim(c5[5]) == "`ci2'" & strtrim(c4[5]) == "`e2'"
    * p-values untouched: same text as the source frame
    frame _ctf1: local p_src = strtrim(c3[4])
    frame _ctc1: assert strtrim(c3[4]) == "`p_src'"
    foreach f in c m {
        _ct_has "``f''" "`ci1'"
        assert r(found)
        _ct_has "``f''" "`ci2'"
        assert r(found)
    }
    _ct_xlsx "`x'" "C1" "$CT_OUT/ct_c1.txt"
    _ct_has "$CT_OUT/ct_c1.txt" "value D4 `ci1'"
    assert r(found)
    _ct_has "$CT_OUT/ct_c1.txt" "value C4 `e1'"
    assert r(found)
}
if _rc == 0 {
    display as result "  PASS: C1 vertical cformat()/cisep() equal r(table) in frame, CSV, Markdown, Excel; p unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 vertical cformat/cisep (rc=`=_rc')"
    local ++fail_count
}

**# C2: thousands separators beside factor rows; reference rows keep their text
capture noisily {
    _ct_auto_frames
    sysuse auto, clear
    quietly regress price i.rep78 mpg
    matrix T = r(table)
    comptab _ctf2, rows(1/6) cformat(%12.0fc) frame(_ctc2, replace) compact
    * row 4 = rep78 level 3 (data row: 1 heading, 2 level 1, 3 level 2, 4 level 3)
    local want = strtrim(string(T[1,3], "%12.0fc")) + " (" + strtrim(string(T[5,3], "%12.0fc")) + ", " + strtrim(string(T[6,3], "%12.0fc")) + ")"
    frame _ctc2: list A c1 c3 in 4/9, noobs
    frame _ctc2: assert strtrim(c1[7]) == "`want'"
    frame _ctc2: assert strpos(c1[7], ",") & regexm(c1[7], "[0-9],[0-9][0-9][0-9]")
    frame _ctc2: assert strtrim(c1[5]) == "Reference"
}
if _rc == 0 {
    display as result "  PASS: C2 cformat(%12.0fc) on factor rows; compact merge; Reference kept"
    local ++pass_count
}
else {
    display as error "  FAIL: C2 cformat on factor rows (rc=`=_rc')"
    local ++fail_count
}

**# C3: cisep() alone rewrites (a, b) exactly; other forms and bad formats refused
capture noisily {
    _ct_auto_frames
    frame _ctf1: local ci_src = strtrim(c2[4])
    comptab _ctf1, rows(1) cisep(" to ") frame(_ctc3, replace)
    local want = subinstr("`ci_src'", ", ", " to ", 1)
    frame _ctc3: assert strtrim(c2[4]) == "`want'"
    frame _ctf1: replace c2 = "(1 - 2)" in 4
    capture comptab _ctf1, rows(1) cisep(" to ")
    assert _rc == 198
    _ct_auto_frames
    foreach f in %td %s %9s {
        capture comptab _ctf1, rows(1) cformat(`f')
        assert _rc == 198
    }
    * a source without a numeric companion cannot be re-rendered
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    quietly regtab, frame(_ctnoc, replace) noint
    capture comptab _ctnoc, rows(1) cformat(%9.2f)
    assert _rc == 459
    * text mode does not need one
    comptab _ctnoc, rows(1) cisep(" to ")
}
if _rc == 0 {
    display as result "  PASS: C3 cisep() text rewrite exact; non-(a, b) text, bad formats and missing companions refused"
    local ++pass_count
}
else {
    display as error "  FAIL: C3 cisep/cformat refusals (rc=`=_rc')"
    local ++fail_count
}

**# C4: vertical frame(name, flat): labels, body, no helper rows; puttab round trip
capture noisily {
    _ct_auto_frames
    comptab _ctf1 _ctf2, rows(1 2 \ 1/4) section("Continuous" \ "Repair record") frame(_ctfull, replace)
    comptab _ctf1 _ctf2, rows(1 2 \ 1/4) section("Continuous" \ "Repair record") frame(_ctflat, replace flat)
    frame _ctflat {
        describe, varlist
        assert "`r(varlist)'" == "rowlabel c1 c2 c3 c4 c5 c6"
        assert "`: variable label c1'" == "Base, Coef."
        assert "`: variable label c2'" == "Base, 95% CI"
        assert "`: variable label c6'" == "Adjusted, p-value"
        assert _N == 8
        local nf = _N
    }
    frame _ctfull: assert _N == 3 + `nf'
    forvalues i = 1/`nf' {
        frame _ctfull: local a = A[`i' + 3]
        frame _ctflat: assert rowlabel[`i'] == `"`a'"'
        forvalues j = 1/6 {
            frame _ctfull: local v = c`j'[`i' + 3]
            frame _ctflat: assert c`j'[`i'] == `"`v'"'
        }
    }
    * puttab takes it as is: header row = the labels, body = the frame
    local c "$CT_OUT/ct_c4_puttab.csv"
    capture erase "`c'"
    local c "$CT_OUT/ct_c4_puttab.md"
    capture erase "`c'"
    puttab rowlabel c*, frame(_ctflat) varlabels markdown("`c'")
    _ct_has "`c'" "Base, Coef."
    assert r(found)
    _ct_has "`c'" "Repair record"
    assert r(found)
    * a flat frame is not a composition source; bad suboptions refused
    capture comptab _ctflat, rows(1)
    assert _rc == 198
    capture comptab _ctf1, rows(1) frame(_ctx, bogus)
    assert _rc == 198
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    local long = 80 * "M"
    quietly regtab, frame(_ctlong, replace) noint models("`long'")
    * a header beyond 80 characters: label truncated, full text in a char
    comptab _ctlong, rows(1) frame(_ctlf, replace flat)
    frame _ctlf {
        local full : char c1[tabtools_header]
        assert "`full'" == "`long', Coef."
        assert "`: variable label c1'" == substr("`long', Coef.", 1, 80)
    }
}
if _rc == 0 {
    display as result "  PASS: C4 frame(, flat) equals the table body with header labels; puttab round trip; refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: C4 vertical flat frame (rc=`=_rc')"
    local ++fail_count
}

**# Rate-mode fixtures
capture program drop _ct_rate_fixture
program define _ct_rate_fixture
    version 17.0
    _ct_surv
    quietly ratetab agegrp drug, outlabels("Death") explabels("Age band" \ "Treatment") ///
        level(95) frame(_ctrates, replace)
    collect clear
    quietly collect: stcox i.agegrp i.drug
    quietly collect: stcox i.agegrp i.drug age
    quietly regtab, frame(_ctm, replace) eplotframe(_ctme, replace) noint compact ///
        models("M1 \ M2") addrow("Events" "31" "31" \ "Spline P" "0.10" "0.20")
end

**# C5: allmodels: K effect columns equal each model's own cells; headers
capture noisily {
    _ct_rate_fixture
    comptab _ctm, rateframe(_ctrates) rows(3/4 7) allmodels effect("aHR") frame(_ctc5, replace)
    assert r(N_models_per_outcome) == 2
    frame _ctc5 {
        assert c5[3] == "M1, aHR (95% CI)" & c6[3] == "M1, p-value"
        assert c7[3] == "M2, aHR (95% CI)" & c8[3] == "M2, p-value"
    }
    * 55-59 row of the rate frame (row 6) gets row "  55-59" of the model frame
    frame _ctm: local m1 = strtrim(c1[6])
    frame _ctm: local p1 = strtrim(c2[6])
    frame _ctm: local m2 = strtrim(c3[6])
    frame _ctc5: assert strtrim(c1[6]) == "55-59" | strtrim(c1[6]) == "55-59"
    frame _ctc5: assert c5[6] == "`m1'" & c6[6] == "`p1'" & c7[6] == "`m2'"
    frame _ctc5: assert c5[5] == "Reference" & c7[5] == "Reference"
    * order by outcomemap() groups, reversed
    comptab _ctm, rateframe(_ctrates) rows(3/4 7) outcomemap("M2 | M1") frame(_ctc5b, replace)
    frame _ctc5b: assert c5[6] == "`m2'" & c7[6] == "`m1'"
    * old contract kept: K>1 needs allmodels or a group
    capture comptab _ctm, rateframe(_ctrates) rows(3/4 7)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: C5 allmodels and outcomemap(a | b) give one effect column per model, in order"
    local ++pass_count
}
else {
    display as error "  FAIL: C5 several models per outcome (rc=`=_rc')"
    local ++fail_count
}

**# C6: keyed placement, rates-only section, modelonly rows (Dose_IgG Table 2 shape)
capture noisily {
    _ct_surv
    * the IgG-like third section carries rates only
    gen byte grp3 = 1 + (age > 57)
    label define _ctg3 1 "Lower" 2 "Higher", replace
    label values grp3 _ctg3
    label variable grp3 "Rates only"
    quietly ratetab agegrp drug grp3, outlabels("Death") level(95) frame(_ctr6, replace)
    collect clear
    quietly collect: stcox i.agegrp i.drug age
    quietly collect: stcox i.agegrp i.drug age
    quietly regtab, frame(_ctm6, replace) noint compact nopvalue models("M1 \ M2") ///
        addrow("Events" "31" "31")
    comptab _ctm6, rateframe(_ctr6) rows(all) allmodels modelonly effect("Rate ratio") ///
        frame(_ctc6, replace)
    assert r(N_modelonly) == 2
    frame _ctc6 {
        * scaffold: 3 header rows, 3 sections (3 + 2 + 2 categories) = 13 rows,
        * then the two model-only rows
        assert _N == 15
        assert strtrim(c1[14]) == "Patient's age at start of exp." & strtrim(c1[15]) == "Events"
        assert c2[14] == "" & c3[14] == "" & c4[14] == ""
        assert c6[15] == "31"
        * rates-only rows: the rate is there, no effect and no Reference
        assert strtrim(c1[11]) == "Rates only"
        assert c4[12] != "" & c5[12] == "" & c6[12] == "" & c5[13] == ""
        * nopvalue frames: one column per model
        assert c5[3] == "M1, Rate ratio (95% CI)" & c6[3] == "M2, Rate ratio (95% CI)"
        capture confirm variable c7
        assert _rc
    }
    frame _ctm6: local d1 = strtrim(c1[10])
    frame _ctc6: assert c5[10] == "`d1'"
    * the rates-only section is the R1 contract, not a placement default:
    * without keyed the old positional rule refuses this frame
    capture comptab _ctm6, rateframe(_ctr6) rows(3/4 7) allmodels
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: C6 keyed + modelonly + rates-only section reproduce the Dose_IgG Table 2 shape"
    local ++pass_count
}
else {
    display as error "  FAIL: C6 keyed/modelonly (rc=`=_rc')"
    local ++fail_count
}

**# C7: R1 refusals, each beside a control call that succeeds
* model data rows: 1 Age band, 2 <55 (ref), 3 55-59, 4 60+, 5 Treatment,
* 6 Placebo (ref), 7 Drug, 8 age, 9 Events, 10 Spline P
capture noisily {
    _ct_rate_fixture
    comptab _ctm, rateframe(_ctrates) rows(3/4 7) allmodels keyed
    * explicit reference rows are allowed and placed as reflabel()
    comptab _ctm, rateframe(_ctrates) rows(2/4 6/7) allmodels keyed reflabel("1.00") frame(_ct7r, replace)
    frame _ct7r: assert c5[5] == "1.00" & c5[9] == "1.00"
    * a model row without a rate row needs modelonly
    capture comptab _ctm, rateframe(_ctrates) rows(3/4 7/8) allmodels keyed
    assert _rc == 198
    comptab _ctm, rateframe(_ctrates) rows(3/4 7/8) allmodels modelonly
    * an explicit reference with a category left unfilled
    capture comptab _ctm, rateframe(_ctrates) rows(2 4 7) allmodels keyed
    assert _rc == 198
    * a section left with two unfilled categories
    capture comptab _ctm, rateframe(_ctrates) rows(4 7) allmodels keyed
    assert _rc == 198
    * two selected rows with the same key (one block from two frames)
    frame copy _ctm _ctm_b, replace
    comptab _ctm _ctm_b, rateframe(_ctrates) rows(3/4 \ 7) allmodels keyed
    capture comptab _ctm _ctm_b, rateframe(_ctrates) rows(3/4 \ 3/4) allmodels keyed
    assert _rc == 198
    * a level the rate section lacks
    frame _ctm: replace A = "  55-60" in 6
    capture comptab _ctm, rateframe(_ctrates) rows(3/4 7) allmodels keyed
    assert _rc == 198
    * a rate frame with two sections of one label
    _ct_rate_fixture
    _ct_surv
    quietly ratetab agegrp agegrp, outlabels("Death") explabels("Age band" \ "Age band") frame(_ctdup, replace)
    capture comptab _ctm, rateframe(_ctdup) rows(3/4) allmodels keyed
    assert _rc == 198
    * eplotframe() is not available with keyed; slot count; allmodels + outcomemap
    capture comptab _ctm, rateframe(_ctrates) rows(3/4 7) allmodels keyed eplotframe(_cte, replace)
    assert _rc == 198
    capture comptab _ctm, rateframe(_ctrates) rows(3/4 7) outcomemap("M1 | M2 \ M1")
    assert _rc == 198
    capture comptab _ctm, rateframe(_ctrates) rows(3/4 7) allmodels outcomemap("M1")
    assert _rc == 198
    * keyed and its siblings belong to rate mode
    capture comptab _ctm, rows(1) keyed
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: C7 R1: unmatched levels, missing modelonly, duplicate keys and gaps are errors; controls run"
    local ++pass_count
}
else {
    display as error "  FAIL: C7 keyed refusals (rc=`=_rc')"
    local ++fail_count
}

**# C8: rate-ratio (IRR) models; effect() must describe the scale; no mixing
capture noisily {
    _ct_surv
    gen double pt = _t - _t0
    quietly ratetab agegrp, outlabels("Death") explabels("Age band") frame(_ctr8, replace)
    collect clear
    quietly collect: poisson died i.agegrp, exposure(pt) irr
    quietly regtab, frame(_ctp8, replace) eplotframe(_ctp8e, replace) noint compact models("P1")
    quietly poisson died i.agegrp, exposure(pt) irr
    matrix T = r(table)
    local want = strtrim(string(T[1,2], "%5.3f")) + " (" + strtrim(string(T[5,2], "%5.3f")) + " to " + strtrim(string(T[6,2], "%5.3f")) + ")"
    comptab _ctp8, rateframe(_ctr8) rows(3/4) outcomemap("P1") effect("IRR") ///
        cformat(%5.3f) cisep(" to ") frame(_ctc8, replace)
    frame _ctc8: assert c5[6] == "`want'"
    capture comptab _ctp8, rateframe(_ctr8) rows(3/4) outcomemap("P1") effect("aHR")
    assert _rc == 198
    collect clear
    quietly collect: stcox i.agegrp
    quietly regtab, frame(_cth8, replace) noint compact models("P1")
    capture comptab _ctp8 _cth8, rateframe(_ctr8) rows(3 \ 4) outcomemap("P1") effect("IRR")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: C8 IRR models accepted with an IRR effect label; HR label and mixed scales refused"
    local ++pass_count
}
else {
    display as error "  FAIL: C8 IRR scale (rc=`=_rc')"
    local ++fail_count
}

**# C9: rate-mode cformat/cisep in every sink; flat frame; footnote paragraphs
capture noisily {
    _ct_rate_fixture
    _ct_surv
    quietly stcox i.agegrp i.drug
    matrix T = r(table)
    local want = strtrim(string(T[1,2], "%6.3f")) + " (" + strtrim(string(T[5,2], "%6.3f")) + " to " + strtrim(string(T[6,2], "%6.3f")) + ")"
    _ct_rate_fixture
    local x "$CT_OUT/ct_c9.xlsx"
    local c "$CT_OUT/ct_c9.csv"
    local m "$CT_OUT/ct_c9.md"
    capture erase "`x'"
    comptab _ctm, rateframe(_ctrates) rows(3/4 7) allmodels cformat(%6.3f) cisep(" to ") ///
        xlsx("`x'") sheet("C9") csv("`c'") markdown("`m'") frame(_ctc9, replace flat) ///
        footnote("First paragraph. \ Second paragraph.")
    frame _ctc9 {
        assert "`: variable label c1'" == "Death, Events"
        assert "`: variable label c4'" == "Death, M1, aHR (95% CI)"
        assert rowlabel[1] == "Age band"
        assert c4[3] == "`want'"
    }
    _ct_has "`c'" "`want'"
    assert r(found)
    _ct_has "`m'" "`want'"
    assert r(found)
    _ct_xlsx "`x'" "C9" "$CT_OUT/ct_c9.txt"
    _ct_has "$CT_OUT/ct_c9.txt" "`want'"
    assert r(found)
    * O4: the footnote reaches the sinks; in Excel one row per paragraph
    _ct_has "$CT_OUT/ct_c9.txt" "value B11 First paragraph."
    assert r(found)
    _ct_has "$CT_OUT/ct_c9.txt" "value B12 Second paragraph."
    assert r(found)
    _ct_has "`c'" "First paragraph."
    assert r(found)
    _ct_has "`m'" "Second paragraph."
    assert r(found)
}
if _rc == 0 {
    display as result "  PASS: C9 rate-mode cformat/cisep reach frame, CSV, Markdown, Excel; flat labels; footnote paragraphs"
    local ++pass_count
}
else {
    display as error "  FAIL: C9 rate-mode sinks (rc=`=_rc')"
    local ++fail_count
}

**# C10: vertical footnote is forwarded unchanged; Excel one row per paragraph
capture noisily {
    _ct_auto_frames
    local x "$CT_OUT/ct_c10.xlsx"
    local c "$CT_OUT/ct_c10.csv"
    capture erase "`x'"
    comptab _ctf1, rows(1 2) xlsx("`x'") sheet("C10") csv("`c'") footnote("Alpha note. \ Beta note.")
    _ct_xlsx "`x'" "C10" "$CT_OUT/ct_c10.txt"
    _ct_has "$CT_OUT/ct_c10.txt" "value B6 Alpha note."
    assert r(found)
    _ct_has "$CT_OUT/ct_c10.txt" "value B7 Beta note."
    assert r(found)
    _ct_has "`c'" "Alpha note."
    assert r(found)
}
if _rc == 0 {
    display as result "  PASS: C10 vertical footnote forwarded; Excel writes one row per paragraph"
    local ++pass_count
}
else {
    display as error "  FAIL: C10 vertical footnote (rc=`=_rc')"
    local ++fail_count
}

**# C11: hrcomptab forwards the new options
capture noisily {
    _ct_rate_fixture
    hrcomptab _ctrates, modelframes(_ctm) rows(all) allmodels modelonly frame(_ct11, replace flat)
    assert r(N_models_per_outcome) == 2 & r(N_modelonly) == 3
    frame _ct11 {
        assert "`: variable label c6'" == "Death, M2, aHR (95% CI)"
        assert rowlabel[_N] == "Spline P"
    }
}
if _rc == 0 {
    display as result "  PASS: C11 hrcomptab forwards allmodels, modelonly and frame(, flat)"
    local ++pass_count
}
else {
    display as error "  FAIL: C11 hrcomptab forwarding (rc=`=_rc')"
    local ++fail_count
}

local _tc = `pass_count' + `fail_count'
display "RESULT: test_comptab_v230 tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _ct230
if `fail_count' > 0 exit 1
