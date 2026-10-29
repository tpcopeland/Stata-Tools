* test_v190_dashboard_summary.do -- binary dashboard Diagnostic Summary panel
* Author: Timothy P Copeland, Karolinska Institutet
*
* Change under test: in the binary psdash combined dashboard the bottom-right
* "Common Support" density (a near-copy of the "PS Overlap" density) is replaced
* by a Diagnostic Summary scorecard graph, psdash_c_summary: the overall verdict
* and one row per executed panel with its key metrics and an OK/Flag status.
* The support analysis still runs; only its graph is dropped. supportgraph
* restores the support density; with nooverlap the support density takes the
* overlap slot. Multi-group dashboards are unchanged.
*
* Fail-on-old (psdash 1.8.1): no psdash_c_summary graph exists, the combined
* graph lists psdash_c_support, and supportgraph is rejected (r(198)), so every
* binary-dashboard test below fails on the old code (observed: 11 of 13 fail).
* The zero-panel test (T12) and the longitudinal rejection (T13) are guards
* that pass on old and new: old rejects supportgraph as an unknown option.
*
* Assertions read real graph state: `graph describe` returns the stored
* command, which for psdash_combined lists the combined member graphs and for
* psdash_c_summary holds every text() placement of the scorecard.
*
* False greens named and defused:
*   FG1 the headline matches r(verdict) because both are constants -> a PASS
*       and a FAIL fixture each assert headline == r(verdict).
*   FG2 rows are present but their statuses are not tied to findings -> each
*       row's OK/Flag is located by its y coordinate and compared with
*       r(warning_panels) for a fixture where only some panels flag.
*   FG3 the scorecard prints numbers that drift from the returned results ->
*       the metric strings are rebuilt from r() and must appear verbatim.
*
* Usage: cd psdash/qa && stata-mp -b do test_v190_dashboard_summary.do
version 16.0
capture log close _all
log using test_v190_dashboard_summary.log, replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"
local pkg_dir = substr("`qa_dir'", 1, strlen("`qa_dir'") - 3)
local repo_dir = substr("`pkg_dir'", 1, strlen("`pkg_dir'") - strlen("/psdash"))
local tests = 0
local pass = 0
local fail = 0
local skip = 0
local failed ""

**# Helpers

* Binary fixture. kind = pass: mild confounding, every panel clean.
* kind = mixed: the demo DGP, only the weights panel flags (extreme weights).
capture program drop _v190_binary
program define _v190_binary
    args kind
    clear
    if "`kind'" == "pass" {
        set seed 4242
        set obs 1000
        generate double x1 = rnormal()
        generate double x2 = rnormal()
        generate double x3 = runiform()
        generate byte t = runiform() < invlogit(0.4*x1 - 0.3*x2)
        quietly logit t x1 x2 x3
    }
    else {
        set seed 20260226
        set obs 800
        generate double x1 = rnormal(55, 12)
        generate byte x2 = runiform() < 0.48
        generate double x3 = rnormal(27, 5)
        generate double x4 = rnormal(135, 22)
        generate byte t = runiform() < ///
            invlogit(-3.5 + 0.04*x1 + 0.6*x2 + 0.03*x3 + 0.008*x4)
        quietly logit t x1 x2 x3 x4
    }
    predict double ps, pr
    generate double w = cond(t, 1/ps, 1/(1-ps))
end

* Stored command of a graph in memory, returned in s(cmd); rc 111 if absent.
capture program drop _v190_cmd
program define _v190_cmd, sclass
    args gname
    sreturn clear
    quietly graph describe `gname'
    sreturn local cmd `"`r(command)'"'
end

* Member graphs of psdash_combined, in combine order, returned in s(members).
capture program drop _v190_members
program define _v190_members, sclass
    _v190_cmd psdash_combined
    local c `"`s(cmd)'"'
    gettoken word c : c
    assert "`word'" == "combine"
    local c = substr(`"`c'"', 1, strpos(`"`c'"', ",") - 1)
    local c : list retokenize c
    sreturn local members "`c'"
end

* Scorecard headline word, row status by row name, and the raw command.
capture program drop _v190_card
program define _v190_card, sclass
    _v190_cmd psdash_c_summary
    local c `"`s(cmd)'"'
    sreturn clear
    sreturn local cmd `"`c'"'
    local head ""
    if regexm(`"`c'"', `"text\([0-9.]+ 50 "(\{bf:)?(PASS|FAIL)\}?""') {
        local head = regexs(2)
    }
    sreturn local head "`head'"
    foreach p in Overlap Balance Weights Support {
        local st "absent"
        if regexm(`"`c'"', `"text\(([0-9.]+) 1 "(\{bf:)?`p'\}?""') {
            local y = regexs(1)
            local st "none"
            if strpos(`"`c'"', `"text(`y' 99 "OK""') | ///
                strpos(`"`c'"', `"text(`y' 99 "{bf:OK}""') local st "OK"
            if strpos(`"`c'"', `"text(`y' 99 "Flag""') | ///
                strpos(`"`c'"', `"text(`y' 99 "{bf:Flag}""') local st "Flag"
        }
        sreturn local st_`p' "`st'"
    }
end

capture program drop _v190_rec
program define _v190_rec
    args name rc
    if `rc' {
        display as error "FAIL: `name' (rc=`rc')"
        global V190_FAILED "$V190_FAILED `name'"
    }
    else display as result "PASS: `name'"
end
global V190_FAILED ""

**# T1 default binary dashboard: scorecard replaces the support density
capture noisily {
    _v190_binary mixed
    graph drop _all
    quietly psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w)
    assert r(n_panels) == 4
    _v190_members
    assert "`s(members)'" == "psdash_c_overlap psdash_c_balance psdash_c_weights psdash_c_summary"
    _v190_cmd psdash_combined
    assert strpos(`"`s(cmd)'"', "rows(2)") > 0
    * the support graph is not drawn at all (no orphan graph window)
    capture graph describe psdash_c_support
    assert _rc != 0
    capture graph describe psdash_c_summary
    assert _rc == 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec default_scorecard_replaces_support `rc'

**# T2 PASS fixture: headline equals r(verdict); every row OK; green headline
capture noisily {
    _v190_binary pass
    graph drop _all
    quietly psdash combined t ps, covariates(x1 x2 x3) wvar(w)
    local v "`r(verdict)'"
    local nw = r(n_warnings)
    local np = r(n_panels)
    assert "`v'" == "PASS" & `nw' == 0 & `np' == 4
    _v190_card
    assert "`s(head)'" == "`v'"
    assert strpos(`"`s(cmd)'"', `""0 findings across 4 panels""') > 0
    assert strpos(`"`s(cmd)'"', `"color("26 127 55")"') > 0
    assert strpos(`"`s(cmd)'"', `"color("180 35 24")"') == 0
    foreach p in Overlap Balance Weights Support {
        assert "`s(st_`p')'" == "OK"
    }
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec pass_headline_equals_verdict `rc'

**# T3 FAIL fixture: headline equals r(verdict); Flag rows == r(warning_panels)
capture noisily {
    _v190_binary mixed
    graph drop _all
    quietly psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w)
    local v "`r(verdict)'"
    local nw = r(n_warnings)
    local np = r(n_panels)
    local wp "`r(warning_panels)'"
    local wtxt `"`r(warnings)'"'
    assert "`v'" == "FAIL" & `nw' > 0
    * the fixture must flag some panels and leave others clean (FG2)
    local nwp : word count `wp'
    assert `nwp' >= 1 & `nwp' < 4
    _v190_card
    assert "`s(head)'" == "`v'"
    local fword = cond(`nw' == 1, "finding", "findings")
    assert strpos(`"`s(cmd)'"', `""`nw' `fword' across `np' panels""') > 0
    assert strpos(`"`s(cmd)'"', `"color("180 35 24")"') > 0
    foreach p in Overlap Balance Weights Support {
        local lp = lower("`p'")
        local flagged : list lp in wp
        if `flagged' assert "`s(st_`p')'" == "Flag"
        else assert "`s(st_`p')'" == "OK"
    }
    * the flagged weights row repeats its finding text from r(warnings)
    assert regexm(`"`wtxt'"', "\[weights\] ([^[]+)")
    * shown "; "-separated, as the console's " | " list is too wide for a row
    local wfind = subinstr(strtrim(regexs(1)), " | ", "; ", .)
    display as text `"  expect: `wfind'"'
    assert strpos(`"`s(cmd)'"', `""`wfind'""') > 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec fail_headline_and_flags_match_returns `rc'

**# T4 scorecard metrics equal the returned results verbatim
capture noisily {
    _v190_binary mixed
    graph drop _all
    quietly psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w)
    local e1 = strtrim(string(r(pct_outside), "%5.2f")) + "% outside common support"
    local e2 = "`r(n_outside)' of `r(N)' obs (overlapmax `r(overlapmax)'%)"
    local e3 = "max |SMD| " + strtrim(string(r(max_smd_raw), "%6.3f")) + ///
        " raw, " + strtrim(string(r(max_smd_adj), "%6.3f")) + " adjusted"
    local nv : word count `r(varlist)'
    * threshold printed with a leading zero and the user's decimals (0.1)
    local thr = strtrim(string(r(threshold), "%10.0g"))
    if substr("`thr'", 1, 1) == "." local thr "0`thr'"
    local e4 = "`r(n_imbalanced)' of `nv' covariates > `thr' (imbalmax `r(imbalmax)')"
    local e5 = "ESS " + strtrim(string(r(ess), "%12.1f")) + ", " + ///
        strtrim(string(r(ess_pct), "%6.1f")) + "% of N (essmin `r(essmin)'%)"
    local lo = min(r(ess_pct_treated), r(ess_pct_control))
    local arm = cond(r(ess_pct_control) < r(ess_pct_treated), "control", "treated")
    local e6 = "min arm ESS " + strtrim(string(`lo', "%6.1f")) + "% (`arm'); max weight " + ///
        strtrim(string(r(max_wt), "%12.3f"))
    local e7 = "`=r(N) - r(n_outside)' of `r(N)' inside support (" + ///
        strtrim(string(100 * (r(N) - r(n_outside)) / r(N), "%6.2f")) + "%)"
    local e8 = "bounds [" + strtrim(string(r(lower_bound), "%10.4f")) + ", " + ///
        strtrim(string(r(upper_bound), "%10.4f")) + "]"
    _v190_card
    forvalues i = 1/8 {
        display as text `"  expect: `e`i''"'
        assert strpos(`"`s(cmd)'"', `""`e`i''""') > 0
    }
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec scorecard_metrics_equal_returns `rc'

**# T5 suppressed panels are absent from the scorecard; rows(1) layout kept
capture noisily {
    _v190_binary mixed
    graph drop _all
    quietly psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w) nobalance noweights
    assert r(n_panels) == 2
    local v "`r(verdict)'"
    _v190_members
    assert "`s(members)'" == "psdash_c_overlap psdash_c_summary"
    _v190_cmd psdash_combined
    assert strpos(`"`s(cmd)'"', "rows(1)") > 0
    _v190_card
    assert "`s(head)'" == "`v'"
    assert "`s(st_Overlap)'" != "absent" & "`s(st_Support)'" != "absent"
    assert "`s(st_Balance)'" == "absent" & "`s(st_Weights)'" == "absent"
    assert strpos(`"`s(cmd)'"', "across 2 panels") > 0
    assert strpos(`"`s(cmd)'"', "max |SMD|") == 0 & strpos(`"`s(cmd)'"', "ESS") == 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec suppressed_panels_absent `rc'

**# T6 supportgraph (and its abbreviation supportg) restores the support density
capture noisily {
    _v190_binary mixed
    foreach spell in supportgraph supportg {
        graph drop _all
        quietly psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w) `spell'
        _v190_members
        assert "`s(members)'" == "psdash_c_overlap psdash_c_balance psdash_c_weights psdash_c_support"
        capture graph describe psdash_c_summary
        assert _rc != 0
    }
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec supportgraph_restores_support_panel `rc'

**# T7 every r() scalar and macro is identical with and without supportgraph
capture noisily {
    _v190_binary mixed
    foreach run in a b {
        local opt = cond("`run'" == "b", "supportgraph", "")
        graph drop _all
        quietly psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w) `opt'
        local sc_`run' : r(scalars)
        local mc_`run' : r(macros)
        foreach s of local sc_`run' {
            local S_`run'_`s' : display %21x r(`s')
        }
        foreach m of local mc_`run' {
            local M_`run'_`m' `"`r(`m')'"'
        }
    }
    assert `: list sc_a === sc_b'
    assert `: list mc_a === mc_b'
    local nsc : word count `sc_a'
    assert `nsc' > 40
    foreach s of local sc_a {
        assert "`S_a_`s''" == "`S_b_`s''"
    }
    foreach m of local mc_a {
        assert `"`M_a_`m''"' == `"`M_b_`m''"'
    }
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec returns_identical_across_layouts `rc'

**# T8 nooverlap: support density takes the overlap slot; scorecard kept
capture noisily {
    _v190_binary mixed
    graph drop _all
    quietly psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w) nooverlap
    assert r(n_panels) == 3
    _v190_members
    assert "`s(members)'" == "psdash_c_support psdash_c_balance psdash_c_weights psdash_c_summary"
    _v190_cmd psdash_c_support
    assert strpos(`"`s(cmd)'"', "Common Support") > 0
    _v190_card
    assert "`s(st_Overlap)'" == "absent" & "`s(st_Support)'" != "absent"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec nooverlap_support_takes_overlap_slot `rc'

**# T9 multi-group dashboard keeps its four panels (non-regression guard)
capture noisily {
    clear
    set seed 20260226
    set obs 900
    generate double x1 = rnormal()
    generate double x2 = rnormal()
    generate double l1 = -0.2 + 0.4*x1
    generate double l2 = -0.6 + 0.5*x2
    generate double p0 = 1/(1 + exp(l1) + exp(l2))
    generate double u = runiform()
    generate byte arm = cond(u < p0, 0, cond(u < p0 + exp(l1)*p0, 1, 2))
    quietly mlogit arm x1 x2
    predict double g0 g1 g2, pr
    generate double gw = cond(arm == 0, 1/g0, cond(arm == 1, 1/g1, 1/g2))
    foreach opt in "" "supportgraph" {
        graph drop _all
        quietly psdash combined arm, psvars(g0 g1 g2) covariates(x1 x2) wvar(gw) `opt'
        assert r(K) == 3 & r(n_panels) == 4
        _v190_members
        assert "`s(members)'" == "psdash_c_overlap psdash_c_balance psdash_c_weights psdash_c_support"
        capture graph describe psdash_c_summary
        assert _rc != 0
    }
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec multigroup_dashboard_unchanged `rc'

**# T10 option spellings: nos still suppresses support; nosupportgraph negates
* supportgraph (Stata syntax accepts no<option> for an on/off option), so it
* keeps the default layout and still runs the support panel
capture noisily {
    _v190_binary mixed
    graph drop _all
    quietly psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w) nos
    assert r(n_panels) == 3
    _v190_card
    assert "`s(st_Support)'" == "absent"
    graph drop _all
    quietly psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w) nosupportgraph
    assert r(n_panels) == 4
    _v190_members
    assert "`s(members)'" == "psdash_c_overlap psdash_c_balance psdash_c_weights psdash_c_summary"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec option_spellings `rc'

**# T11 scheme(), title() and saving() still apply with the scorecard
capture noisily {
    _v190_binary pass
    graph drop _all
    local png "`c(tmpdir)'/psdash_v190_saving_check.png"
    capture erase "`png'"
    quietly psdash combined t ps, covariates(x1 x2 x3) wvar(w) ///
        scheme(s2color) title("QA v190 title") saving("`png'")
    confirm file "`png'"
    _v190_cmd psdash_c_summary
    assert strpos(`"`s(cmd)'"', "scheme(s2color)") > 0
    _v190_cmd psdash_combined
    assert strpos(`"`s(cmd)'"', "QA v190 title") > 0
    assert strpos(`"`s(cmd)'"', "scheme(s2color)") > 0
    capture erase "`png'"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec scheme_title_saving_with_scorecard `rc'

**# T12 zero executed panels still errors before any verdict (guard)
capture noisily {
    _v190_binary pass
    graph drop _all
    capture psdash combined t ps, covariates(x1 x2 x3) wvar(w) ///
        nooverlap nobalance noweights nosupport
    assert _rc == 198
    capture graph describe psdash_c_summary
    assert _rc != 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec zero_panels_still_error `rc'

**# T13 longitudinal route rejects supportgraph like the other graph options
local ++tests
if fileexists("`repo_dir'/msm/msm.pkg") & fileexists("`repo_dir'/msm/msm_example.dta") {
    capture noisily {
        quietly net install msm, from("`repo_dir'/msm") replace
        use "`repo_dir'/msm/msm_example.dta", clear
        quietly msm_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) covariates(biomarker comorbidity age sex)
        quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
            treat_n_cov(age sex) nolog
        quietly psdash combined
        assert r(longitudinal) == 1
        capture noisily psdash combined, supportgraph
        assert _rc == 198
    }
    local rc = _rc
    if `rc' local ++fail
    else local ++pass
    _v190_rec longitudinal_rejects_supportgraph `rc'
    capture ado uninstall msm
}
else {
    local ++skip
    display as text "SKIP: msm producer fixture unavailable"
}

**# T14 supportgraph spelling: supportg is the minimum; support/sup are refused
**#     (1.8.x refused support); multi-group says supportgraph is ignored
capture noisily {
    _v190_binary mixed
    foreach bad in support sup {
        graph drop _all
        capture psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w) `bad'
        assert _rc == 198
    }
    graph drop _all
    quietly psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w) supportg
    _v190_members
    assert "`s(members)'" == "psdash_c_overlap psdash_c_balance psdash_c_weights psdash_c_support"
    graph drop _all
    quietly psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w) nos
    assert r(n_panels) == 3
    _v190_members
    assert "`s(members)'" == "psdash_c_overlap psdash_c_balance psdash_c_weights psdash_c_summary"

    clear
    set seed 3
    set obs 900
    generate double x1 = rnormal()
    generate byte arm = floor(3 * runiform())
    quietly mlogit arm x1
    quietly predict double q0 q1 q2, pr
    tempfile nlog
    graph drop _all
    log using "`nlog'", text replace name(v190n)
    psdash combined arm, psvars(q0 q1 q2) covariates(x1) supportgraph
    log close v190n
    mata: st_numscalar("v190_hit", sum(strpos(cat("`nlog'"), "note: supportgraph ignored") :> 0))
    assert scalar(v190_hit) == 1
    scalar drop v190_hit
}
local rc = _rc
capture log close v190n
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec supportgraph_min_abbrev_and_mg_note `rc'

**# T15 long findings wrap onto a second red line instead of being cut at 58
capture mata: mata drop _v190_red() _v190_pf()
mata:
// Red finding lines of the scorecard command: col 1 = y, col 2 = text.
string matrix _v190_red(string scalar c)
{
    string matrix out
    string scalar rest, piece
    real scalar p, q, a, b
    out = J(0, 2, "")
    rest = c
    while ((p = strpos(rest, "text(")) > 0) {
        rest = substr(rest, p + 5, .)
        q = strpos(rest, "text(")
        piece = (q > 0 ? substr(rest, 1, q - 1) : rest)
        if (strpos(piece, `"color("180 35 24") placement(e)"') & regexm(piece, "^([0-9.]+) 21 ")) {
            a = strpos(piece, char(96) + char(34))
            b = strpos(piece, char(34) + char(39))
            out = out \ (regexs(1), substr(piece, a + 2, b - a - 2))
        }
    }
    return(out)
}
// A panel's findings from r(warnings) ("[panel] text" segments), as the
// scorecard states them: segments and " | " parts joined by "; ".
string scalar _v190_pf(string scalar w, string scalar panel)
{
    string scalar tag, out, seg
    real scalar p, q
    tag = "[" + panel + "] "
    out = ""
    while ((p = strpos(w, tag)) > 0) {
        w = substr(w, p + strlen(tag), .)
        q = 0
        if (regexm(w, " \[(overlap|balance|weights|support)\] ")) q = strpos(w, regexs(0))
        seg = (q > 0 ? substr(w, 1, q - 1) : w)
        out = (out == "" ? seg : out + "; " + seg)
    }
    return(subinstr(strtrim(out), " | ", "; "))
}
end
capture noisily {
    clear
    set seed 11
    set obs 600
    generate double x1 = rnormal()
    generate double x2 = rnormal()
    generate double x3 = rnormal()
    generate byte t = runiform() < invlogit(-0.5 + 2.8*x1 + 1.5*x2)
    quietly logit t x1 x2
    predict double ps, pr
    generate double w = cond(t, 1/ps, 1/(1-ps))
    graph drop _all
    quietly psdash combined t ps, covariates(x1 x2 x3) wvar(w) overlapmax(1) essmin(90)
    local W `"`r(warnings)'"'
    _v190_card
    mata: R = _v190_red(st_global("s(cmd)"))
    mata: st_numscalar("v190_nred", rows(R))
    mata: st_numscalar("v190_maxlen", max(udstrlen(R[., 2])))
    * one line per row before; balance and weights now take two
    assert scalar(v190_nred) == 6
    assert scalar(v190_maxlen) <= 58
    * the balance finding fits two lines: complete, verbatim
    mata: st_local("bal_exp", _v190_pf(st_local("W"), "balance"))
    mata: st_local("bal_got", R[2, 2] + " " + R[3, 2])
    assert `"`bal_got'"' == `"`bal_exp'"'
    * the weights finding is longer: its two lines are its start, ending "..."
    mata: st_local("wt_exp", _v190_pf(st_local("W"), "weights"))
    mata: st_local("wt_got", R[4, 2] + " " + R[5, 2])
    assert usubstr(`"`wt_got'"', -3, 3) == "..."
    local wt_got = usubstr(`"`wt_got'"', 1, ustrlen(`"`wt_got'"') - 3)
    assert usubstr(`"`wt_exp'"', 1, ustrlen(`"`wt_got'"')) == `"`wt_got'"'
    assert ustrlen(`"`wt_got'"') > 58
    * row order: the two weights lines sit below the two balance lines
    mata: st_numscalar("v190_ord", strtoreal(R[3,1]) > strtoreal(R[4,1]) & strtoreal(R[4,1]) > strtoreal(R[5,1]))
    assert scalar(v190_ord) == 1
    scalar drop v190_nred v190_maxlen v190_ord
    mata: mata drop R
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec scorecard_findings_wrap `rc'

**# T16 dashboards under s2color and s1mono: panel text fixed at the
**#     white_tableau sizes, 3-key legends on two rows, horizontal y labels
capture noisily {
    foreach sc in s2color s1mono {
        _v190_binary mixed
        graph drop _all
        quietly psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w) scheme(`sc')
        _v190_cmd psdash_c_overlap
        assert strpos(`"`s(cmd)'"', "rows(2) position(6) size(small)") > 0
        assert strpos(`"`s(cmd)'"', "angle(horizontal)") > 0
        _v190_cmd psdash_c_balance
        assert strpos(`"`s(cmd)'"', "rows(2) position(6) size(small)") > 0
        assert strpos(`"`s(cmd)'"', "labsize(small)") > 0
        _v190_cmd psdash_c_weights
        assert strpos(`"`s(cmd)'"', "size(small)") > 0
        assert strpos(`"`s(cmd)'"', "angle(horizontal)") > 0

        clear
        set seed 3
        set obs 900
        generate double x1 = rnormal()
        generate double x2 = rnormal()
        generate byte arm = floor(3 * runiform())
        label define v190mg 0 "Placebo" 1 "Low dose" 2 "High dose", replace
        label values arm v190mg
        quietly mlogit arm x1 x2
        quietly predict double q0 q1 q2, pr
        generate double gw = cond(arm == 0, 1/q0, cond(arm == 1, 1/q1, 1/q2))
        graph drop _all
        quietly psdash combined arm, psvars(q0 q1 q2) covariates(x1 x2) wvar(gw) scheme(`sc')
        _v190_cmd psdash_c_overlap
        assert strpos(`"`s(cmd)'"', "labsize(small)") > 0
        _v190_cmd psdash_c_support
        assert regexm(`"`s(cmd)'"', "ylabel\(0 [0-9. ]+, angle\(horizontal\) labsize\(small\)")
        _v190_cmd psdash_c_weights
        assert strpos(`"`s(cmd)'"', "(Multi-Group)") == 0
        assert strpos(`"`s(cmd)'"', "size(small)") > 0
        _v190_cmd psdash_c_balance
        assert strpos(`"`s(cmd)'"', "size(small) symxsize(5)") > 0
        assert strpos(`"`s(cmd)'"', "Each key: arm vs Placebo (reference)") > 0
    }
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec scheme_robust_panels `rc'

**# T17 one threshold format: scorecard and band key both print 0.1 / 0.125
capture noisily {
    _v190_binary mixed
    graph drop _all
    quietly psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w)
    _v190_card
    assert strpos(`"`s(cmd)'"', "covariates > 0.1 (imbalmax 0)") > 0
    graph drop _all
    quietly psdash combined t ps, covariates(x1 x2 x3 x4) wvar(w) threshold(0.125)
    _v190_card
    assert strpos(`"`s(cmd)'"', "covariates > 0.125 (imbalmax 0)") > 0
    _v190_cmd psdash_c_balance
    assert strpos(`"`s(cmd)'"', "|SMD| < 0.125") > 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v190_rec threshold_text_consistent `rc'

graph drop _all
display "RESULT: test_v190_dashboard_summary tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
if `fail' display as error "Failed:$V190_FAILED"
global V190_FAILED
_psdash_qa_cleanup
log close
if `fail' exit 1
