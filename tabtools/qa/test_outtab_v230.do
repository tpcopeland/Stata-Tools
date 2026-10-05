* test_outtab_v230.do - outtab (F3), tabtools 2.3.0
* Oracles: hand counts with count, hand-run poisson ..., irr vce(cluster id)
* and logit fits (their own r(table)), hand-built strings, and the written
* files read back. Fixture: a synthetic births file in the Narcolepsy shape
* (mothers with two births, exposure, outcomes, sample flags).

clear all
set more off
set varabbrev off
version 17.0

capture log close _ot230
log using "test_outtab_v230.log", replace text name(_ot230)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global OT_OUT "`output_dir'"
global OT_TOOLS "`qa_dir'/tools"
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
global TABTOOLS_set_smallcells

local pass_count = 0
local fail_count = 0

capture program drop _ot_has
program define _ot_has, rclass
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

capture program drop _ot_births
program define _ot_births
    version 17.0
    clear
    set seed 20261005
    set obs 3000
    gen long id = ceil(_n / 2)
    gen byte narc = runiform() < 0.1
    label define _otn 1 "Narcolepsy" 0 "Comparator", replace
    label values narc _otn
    gen double age = rnormal(30, 5)
    gen byte cs = runiform() < invlogit(-1.5 + 0.5 * narc + 0.03 * (age - 30))
    gen byte ptb = runiform() < 0.05 + 0.02 * narc
    replace ptb = . in 1/40
    gen byte rare = runiform() < 0.002
    label variable cs "Caesarean section"
    label variable ptb "Preterm birth"
    label variable rare "Rare outcome"
    gen byte prim = 1
    gen byte sens = runiform() < 0.8
    label variable prim "Primary analysis"
    label variable sens "Sensitivity analysis"
    gen byte obs_cs = 1
    gen byte obs_ptb = runiform() < 0.9
    gen byte obs_rare = 1
end

**# O1: known answer: counts and ratios equal hand counts and hand fits
capture noisily {
    _ot_births
    outtab cs ptb, exposure(narc) models("" \ "age") modellabels("Crude" \ "Adjusted") ///
        estimator(poisson, irr vce(cluster id)) panels(prim sens) frame(_oto1, replace)
    matrix R = r(table)
    assert r(N_rows) == 6 & r(N_models) == 2 & r(N_panels) == 2
    local ri 0
    local row 0
    foreach p in prim sens {
        local ++row
        foreach y in cs ptb {
            local ++ri
            local ++row
            quietly count if `p' == 1 & !missing(`y') & narc == 1
            local n1 = r(N)
            quietly count if `p' == 1 & !missing(`y') & narc == 1 & `y' == 1
            local e1 = r(N)
            quietly count if `p' == 1 & !missing(`y') & narc == 0
            local n0 = r(N)
            quietly count if `p' == 1 & !missing(`y') & narc == 0 & `y' == 1
            local e0 = r(N)
            assert R[`ri', 1] == `n1' & R[`ri', 2] == `e1' & R[`ri', 3] == `n0' & R[`ri', 4] == `e0'
            local want1 = strtrim(string(`e1', "%12.0fc")) + "/" + strtrim(string(`n1', "%12.0fc")) + " (" + strtrim(string(100 * `e1' / `n1', "%4.1f")) + ")"
            frame _oto1: assert c1[`row'] == "`want1'"
            local k 0
            foreach cov in "" "age" {
                local ++k
                quietly poisson `y' narc `cov' if `p' == 1, irr vce(cluster id)
                matrix T = r(table)
                assert reldif(R[`ri', 4 + (`k' - 1) * 4 + 1], T[1,1]) < 1e-12
                assert reldif(R[`ri', 4 + (`k' - 1) * 4 + 2], T[5,1]) < 1e-12
                assert reldif(R[`ri', 4 + (`k' - 1) * 4 + 3], T[6,1]) < 1e-12
                assert R[`ri', 4 + `k' * 4] == 0
                local want = strtrim(string(T[1,1], "%4.2f")) + " (" + strtrim(string(T[5,1], "%4.2f")) + ", " + strtrim(string(T[6,1], "%4.2f")) + ")"
                frame _oto1: assert c`=2 + `k''[`row'] == "`want'"
            }
        }
    }
    frame _oto1 {
        assert rowlabel[1] == "Primary analysis" & c1[1] == "" & c3[1] == ""
        assert rowlabel[2] == "   Caesarean section"
        assert "`: variable label c1'" == "Narcolepsy, events/N (%)"
        assert "`: variable label c2'" == "Comparator, events/N (%)"
        assert "`: variable label c3'" == "Crude, RR (95% CI)"
        assert "`: variable label c4'" == "Adjusted, RR (95% CI)"
    }
}
if _rc == 0 {
    display as result "  PASS: O1 counts and ratios equal hand counts and hand-run poisson, irr vce(cluster id)"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 known answer (rc=`=_rc')"
    local ++fail_count
}

**# O2: fit-failure text: non-convergence, failure, non-estimable exposure
capture noisily {
    _ot_births
    gen double narc2 = narc
    outtab cs, exposure(narc) models("" \ "narc2" \ "age") ///
        estimator(logit, or iterate(1)) frame(_oto2, replace)
    matrix R = r(table)
    frame _oto2: assert c3[1] == "did not converge"
    assert R[1, 8] == 430
    * an outcome the exposure predicts perfectly: logit omits the exposure and
    * drops the exposed rows, so the fit sample is smaller than the counts
    gen byte perf = narc | cs
    outtab perf, exposure(narc) estimator(logit, or) frame(_oto2b, replace)
    matrix R = r(table)
    frame _oto2b: assert c3[1] == "not estimable (sample reduced)"
    assert R[1, 8] == -2
    outtab cs, exposure(narc) estimator(poisson, irr bogusopt) frame(_oto2c, replace) ///
        failtext("Fit failed (r(#))")
    frame _oto2c: assert c3[1] == "Fit failed (r(198))"
    outtab cs, exposure(narc) estimator(logit, or iterate(1)) nonconvtext("No convergence") frame(_oto2d, replace)
    frame _oto2d: assert c3[1] == "No convergence"
    * the converged logit OR equals logit, or
    outtab cs, exposure(narc) estimator(logit, or) ratiolabel("OR") format(%5.3f) sep(" to ") frame(_oto2e, replace)
    quietly logit cs narc, or
    matrix T = r(table)
    frame _oto2e: assert c3[1] == strtrim(string(T[1,1], "%5.3f")) + " (" + strtrim(string(T[5,1], "%5.3f")) + " to " + strtrim(string(T[6,1], "%5.3f")) + ")"
    frame _oto2e {
        assert "`: variable label c3'" == "Crude, OR (95% CI)"
    }
}
if _rc == 0 {
    display as result "  PASS: O2 non-converged, failed and non-estimable fits print text; logit OR known answer"
    local ++pass_count
}
else {
    display as error "  FAIL: O2 fit-failure text (rc=`=_rc')"
    local ++fail_count
}

**# O3: minevents() and smallcells (explicit and session); numbers kept in r(table)
capture noisily {
    _ot_births
    outtab cs rare, exposure(narc) minevents(5) frame(_oto3, replace)
    matrix R = r(table)
    assert R[2, 2] < 5 & R[2, 8] == -1
    frame _oto3: assert c3[2] == "–" & c3[1] != "–"
    outtab rare, exposure(narc) minevents(5) mintext("<5 exposed events") frame(_oto3b, replace)
    frame _oto3b: assert c3[1] == "<5 exposed events"
    outtab cs rare, exposure(narc) smallcells(5) frame(_oto3c, replace)
    assert r(smallcells) == 5
    matrix R = r(table)
    assert R[2, 4] >= 1 & R[2, 4] < 5
    frame _oto3c: assert c2[2] == "<5/" + strtrim(string(R[2,3], "%12.0fc")) & c3[2] == ""
    frame _oto3c: assert c3[1] != ""
    global TABTOOLS_set_smallcells 5
    outtab rare, exposure(narc) frame(_oto3d, replace)
    assert r(smallcells) == 5
    outtab rare, exposure(narc) nosmallcells frame(_oto3e, replace)
    assert r(smallcells) == 0
    frame _oto3e: assert substr(c1[1], 1, 1) != "<"
    global TABTOOLS_set_smallcells
}
global TABTOOLS_set_smallcells
if _rc == 0 {
    display as result "  PASS: O3 minevents() text; smallcells masks counts and withholds ratios; session default"
    local ++pass_count
}
else {
    display as error "  FAIL: O3 minevents/smallcells (rc=`=_rc')"
    local ++fail_count
}

**# O4: obsprefix(), missing outcomes, e() left as found
capture noisily {
    _ot_births
    quietly regress age cs
    local cmd0 "`e(cmd)'"
    local b0 = _b[cs]
    outtab ptb, exposure(narc) obsprefix(obs_) frame(_oto4, replace)
    matrix R = r(table)
    quietly count if obs_ptb == 1 & !missing(ptb) & narc == 1
    assert R[1, 1] == r(N)
    assert "`e(cmd)'" == "`cmd0'" & _b[cs] == `b0'
    capture outtab ptb, exposure(narc) obsprefix(nosuch_)
    assert _rc == 111
    assert "`e(cmd)'" == "`cmd0'"
}
if _rc == 0 {
    display as result "  PASS: O4 obsprefix() restricts the row; e() is restored on success and error"
    local ++pass_count
}
else {
    display as error "  FAIL: O4 obsprefix/e() (rc=`=_rc')"
    local ++fail_count
}

**# O5: sinks through puttab; footnote forwarded; frame replace
capture noisily {
    _ot_births
    local x "$OT_OUT/ot_o5.xlsx"
    local c "$OT_OUT/ot_o5.csv"
    local m "$OT_OUT/ot_o5.md"
    capture erase "`x'"
    outtab cs, exposure(narc) models("" \ "age") modellabels("Crude" \ "Adjusted") ///
        estimator(poisson, irr vce(cluster id)) xlsx("`x'") sheet("T2") csv("`c'") markdown("`m'") ///
        title("Table 2. Outcomes") footnote("Note one. \ Note two.") frame(_oto5, replace)
    frame _oto5: local cell = c3[1]
    foreach f in c m {
        _ot_has "``f''" "`cell'"
        assert r(found)
        _ot_has "``f''" "Note one."
        assert r(found)
        _ot_has "``f''" "Narcolepsy, events/N (%)"
        assert r(found)
    }
    capture erase "$OT_OUT/ot_o5.txt"
    shell python3 "$OT_TOOLS/xlsx_facts.py" "`x'" "T2" "$OT_OUT/ot_o5.txt"
    _ot_has "$OT_OUT/ot_o5.txt" "`cell'"
    assert r(found)
    _ot_has "$OT_OUT/ot_o5.txt" "Note one."
    assert r(found)
    capture outtab cs, exposure(narc) frame(_oto5)
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: O5 Excel, CSV and Markdown via puttab carry cells, headers and the footnote"
    local ++pass_count
}
else {
    display as error "  FAIL: O5 sinks (rc=`=_rc')"
    local ++fail_count
}

**# O6: refusals
capture noisily {
    _ot_births
    gen byte e3 = mod(_n, 3)
    capture outtab cs, exposure(e3)
    assert _rc == 459
    gen byte y3 = mod(_n, 3)
    capture outtab y3, exposure(narc)
    assert _rc == 459
    capture outtab cs, exposure(narc) models("nosuchvar")
    assert _rc == 111
    capture outtab cs, exposure(narc) models("" \ "age") modellabels("A")
    assert _rc == 198
    capture outtab cs, exposure(narc) grouplabels("A")
    assert _rc == 198
    capture outtab cs, exposure(narc) estimator(nosuchcmd)
    assert _rc == 199
    capture outtab cs, exposure(narc) format(%td)
    assert _rc == 198
    capture outtab cs if age > 1000, exposure(narc)
    assert _rc == 2000
    capture outtab cs, exposure(narc) smallcells(5) nosmallcells
    assert _rc == 198
    capture outtab cs, exposure(narc) panels(e3)
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: O6 refusals: non-binary exposure/outcome/panel, bad models, labels, estimator, format, empty sample"
    local ++pass_count
}
else {
    display as error "  FAIL: O6 refusals (rc=`=_rc')"
    local ++fail_count
}

local _tc = `pass_count' + `fail_count'
display "RESULT: test_outtab_v230 tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _ot230
if `fail_count' > 0 exit 1
