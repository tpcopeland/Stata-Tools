*! test_datamvp_fixture_groupgap.do -- finite graph spacing and missing-value refusal
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using test_datamvp_fixture_groupgap.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
python:
def _dm_gap_geometry():
    from sfi import Macro
    from xml.etree import ElementTree as ET
    rects = [e.attrib for e in ET.parse(Macro.getLocal("svg")).getroot().iter() if e.tag.endswith("rect")]
    colors = {"fill:#E37E00", "fill:#55752F", "fill:#90353B", "fill:#1A476F"}
    bars = [r for r in rects if r.get("style") in colors and float(r["width"]) > 1000 and float(r["height"]) < 200]
    assert len(bars) == 8, bars
    assert max(float(r["width"]) for r in bars) - min(float(r["width"]) for r in bars) < .02
    bars.sort(key=lambda r: float(r["y"]))
    ratios = [(float(bars[i+1]["y"]) - float(bars[i]["y"]) - float(bars[i]["height"])) / float(bars[i]["height"]) for i in (0,1,2,4,5,6)]
    gap = int(Macro.getLocal("gap"))
    assert all(abs(r - gap/100) < .003 for r in ratios), (gap, ratios)
    print("GRAPH_GEOMETRY gap="+str(gap)+" ratios="+str(ratios))
end
local tests 0
local pass 0
local fail 0
foreach invalid in . .a {
    local ++tests
    capture noisily {
        * expect: REFUSED
        qa_fx_a7_labelled, clear seed(37)
        tempfile cause
        qa_state_snapshot, tag(gap_refusal)
        log using "`cause'", name(gapcause) text replace
        capture noisily datamvp x all_missing extended, nodrop graph(bar) over(group) groupgap(`invalid') gname(gap_refusal) nodraw
        local original_rc=_rc
        log close gapcause
        assert `original_rc'==198
        qa_state_compare, tag(gap_refusal)
        python: assert "groupgap() must be non-negative" in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("cause")).read_text()
    }
    local outcome=_rc
    capture log close gapcause
    capture restore
    if `outcome' {
        local ++fail
        display as error "FAIL: groupgap(`invalid') refusal rc=" `outcome'
    }
    else {
        local ++pass
        display as result "PASS: groupgap(`invalid') refusal"
    }
}
foreach gap in 0 20 100 {
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_fx_a7_labelled, clear seed(37)
        tempfile svg
        qa_state_snapshot, tag(gap_success)
        quietly datamvp x all_missing extended, nodrop graph(bar) over(group) groupgap(`gap') gname(gap_test) nodraw
        assert r(N)==40 & r(N_mv_total)==80 & r(mean_miss)==2
        qa_state_compare, tag(gap_success)
        * The retained analytic graph series must show three variables in each
        * of four groups: x observed, two columns wholly missing.
        preserve
        serset use, clear
        assert _N==12
        isid varname overid
        assert inrange(overid,1,4)
        assert pctmiss==0 if varname==3
        assert pctmiss==100 if inlist(varname,1,2)
        restore
        graph display gap_test
        graph export "`svg'", name(gap_test) as(svg) replace
        * Independently inspect rendered bar geometry. The ratio between the
        * inter-bar empty space and bar thickness is 20%/100% as requested.
        * Select only data bars, excluding legend swatches/background/strokes.
        python: _dm_gap_geometry()
        graph drop gap_test
    }
    local outcome=_rc
    capture restore
    capture graph drop gap_test
    if `outcome' {
        local ++fail
        display as error "FAIL: groupgap(`gap') graph contents rc=" `outcome'
    }
    else {
        local ++pass
        display as result "PASS: groupgap(`gap') graph contents"
    }
}
display "RESULT: test_datamvp_fixture_groupgap tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
