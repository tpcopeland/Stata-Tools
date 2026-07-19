* test_v130_features.do — QA for psdash v1.3.0 enhancements
* Covers: detect/dryrun (U1), verdict returns (I2), configurable thresholds (U2),
*         xlsx parity (O1), trimming comparison (F3), SMD matrix (I1),
*         strategy overlay (F2), distribution plot (F1), report workbook (O2),
*         detection-sources help table (DOC1).
* Usage: cd psdash/qa && stata-mp -b do test_v130_features.do

clear all
version 16.0
set more off

capture log close _all
log using "test_v130_features.log", replace nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

* Isolated install of the local copy
capture do "`qa_dir'/_psdash_bootstrap.do"

global N_PASS = 0
global N_FAIL = 0
global FAILED ""

capture program drop _t
program define _t
    args id rc
    if `rc' == 0 {
        display as result "  PASS: `id'"
        global N_PASS = $N_PASS + 1
    }
    else {
        display as error "  FAIL: `id' (rc=`rc')"
        global N_FAIL = $N_FAIL + 1
        global FAILED "$FAILED `id'"
    }
end

* ---- Fixture: binary PS scenario ----
set seed 20260614
set obs 1000
gen x1 = rnormal()
gen x2 = rnormal()
gen x3 = runiform()
gen u = invlogit(0.9*x1 - 0.6*x2 + 0.3*x3)
gen treat = rbinomial(1, u)
qui logit treat x1 x2 x3
predict ps, pr

tempfile reportfile
local repx "`reportfile'.xlsx"

**# U1 — psdash detect
display as text _n "--- U1: psdash detect reports and returns detection ---"
capture noisily {
    psdash detect treat ps, covariates(x1 x2 x3)
    assert "`r(source)'" != ""
    assert "`r(treatment)'" == "treat"
    assert r(n_covariates) == 3
    assert r(multigroup) == 0
    assert r(longitudinal) == 0
    assert "`r(psvar)'" == "ps"
}
_t "U1_detect" `=_rc'

**# U1 — combined dryrun exits without running panels
display as text _n "--- U1: combined dryrun ---"
capture noisily {
    psdash combined treat ps, covariates(x1 x2 x3) dryrun
    assert "`r(source)'" != ""
    * dryrun should not produce a verdict
    assert "`r(verdict)'" == ""
}
_t "U1_dryrun" `=_rc'

**# I2 + U2 — verdict returns and configurable thresholds
display as text _n "--- I2: combined returns verdict/warnings ---"
capture noisily {
    psdash combined treat ps, covariates(x1 x2 x3)
    assert inlist("`r(verdict)'", "PASS", "FAIL")
    assert r(n_warnings) >= 0
    assert r(overlapmax) == 10
    assert r(essmin) == 50
    assert r(imbalmax) == 0
}
_t "I2_verdict" `=_rc'

display as text _n "--- U2: tightening overlapmax flips verdict to FAIL ---"
capture noisily {
    psdash combined treat ps, covariates(x1 x2 x3) overlapmax(0)
    assert "`r(verdict)'" == "FAIL"
    assert r(n_warnings) >= 1
    assert strpos("`r(warnings)'", "overlap") > 0
    assert r(overlapmax) == 0
}
_t "U2_thresholds" `=_rc'

display as text _n "--- U2: invalid threshold rejected ---"
capture psdash combined treat ps, covariates(x1 x2 x3) essmin(150)
_t "U2_reject_bad" `=(_rc!=198)'

**# I1 — SMD matrix
display as text _n "--- I1: balance r(smd) and smdmatrix() ---"
capture noisily {
    psdash balance treat ps, covariates(x1 x2 x3) nowvar smdmatrix(SMDtest)
    matrix S = r(smd)
    assert rowsof(S) == 3
    assert colsof(S) == 1
    assert rowsof(SMDtest) == 3
    * with weights, adjusted column present
    psdash balance treat ps, covariates(x1 x2 x3)
    matrix S2 = r(smd)
    assert colsof(S2) == 2
    local cn : colnames S2
    assert strpos("`cn'", "SMD_unadj") > 0
    assert strpos("`cn'", "SMD_adj") > 0
}
_t "I1_smdmatrix" `=_rc'

**# F2 — multi-strategy Love plot overlay
display as text _n "--- F2: strategies overlay ---"
capture noisily {
    psdash balance treat ps, covariates(x1 x2 x3) strategies(raw ate att) name(t_strat)
    capture graph describe t_strat
    assert _rc == 0
}
_t "F2_overlay" `=_rc'

display as text _n "--- F2: invalid strategy rejected ---"
capture psdash balance treat ps, covariates(x1 x2 x3) strategies(raw bogus)
_t "F2_reject_bad" `=(_rc!=198)'

**# F1 — distributional balance plot
display as text _n "--- F1: distribution plot ---"
capture noisily {
    psdash balance treat ps, covariates(x1 x2 x3) distribution(x1 x2) name(t_dist)
    capture graph describe t_dist_dist
    assert _rc == 0
}
_t "F1_distribution" `=_rc'

**# O1 — xlsx export parity
display as text _n "--- O1: overlap/weights/support xlsx export ---"
capture noisily {
    capture erase "`repx'"
    psdash overlap treat ps, xlsx("`repx'") sheet(Overlap) nograph
    psdash weights treat ps, xlsx("`repx'") sheet(Weights)
    psdash support treat ps, crump xlsx("`repx'") sheet(Support) nograph
    preserve
    import excel using "`repx'", describe
    assert r(N_worksheet) == 3
    restore
}
_t "O1_xlsx_parity" `=_rc'

**# F3 — pre/post-trimming comparison
display as text _n "--- F3: support compare returns ---"
capture noisily {
    psdash support treat ps, crump compare covariates(x1 x2 x3) nograph
    assert r(n_post) > 0
    assert r(n_post) <= 1000
    assert !missing(r(pct_outside_pre))
    assert !missing(r(pct_outside_post))
    assert !missing(r(ess_pct_pre))
    assert !missing(r(ess_pct_post))
    assert !missing(r(max_smd_pre))
    assert !missing(r(max_smd_post))
}
_t "F3_compare" `=_rc'

display as text _n "--- F3: compare without trimming is skipped (no error) ---"
capture noisily psdash support treat ps, compare nograph
_t "F3_skip_no_trim" `=_rc'

**# O2 — report workbook
display as text _n "--- O2: combined report workbook ---"
capture noisily {
    capture erase "`repx'"
    psdash combined treat ps, covariates(x1 x2 x3) report("`repx'")
    assert "`r(report)'" == "`repx'"
    preserve
    import excel using "`repx'", describe
    * Overlap, Balance, Weights, Support, Summary
    assert r(N_worksheet) == 5
    restore
}
_t "O2_report" `=_rc'

display as text _n "--- O2: bad report path rejected ---"
capture psdash combined treat ps, covariates(x1 x2 x3) report("bad;path.xlsx")
_t "O2_reject_metachar" `=(_rc!=198)'

capture psdash combined treat ps, covariates(x1 x2 x3) report("noext.csv")
_t "O2_reject_ext" `=(_rc!=198)'

**# varabbrev preservation across the dryrun early-exit path
display as text _n "--- combined dryrun preserves c(varabbrev) ---"
capture noisily {
    set varabbrev on
    psdash combined treat ps, covariates(x1 x2 x3) dryrun
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
    psdash combined treat ps, covariates(x1 x2 x3) dryrun
    assert "`c(varabbrev)'" == "off"
}
_t "varabbrev_dryrun" `=_rc'

**# DOC1 — detection-sources table in help
display as text _n "--- DOC1: sthlp has detection-sources table + new options ---"
capture noisily {
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "Detection sources") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "marker detection") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "smdm:atrix") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "strat:egies") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "overlap:max") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "rep:ort") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "r(verdict)") > 0
}
_t "DOC1_help" `=_rc'

**# Summary
display as text _n "=== v1.3.0 FEATURE TESTS: $N_PASS passed, $N_FAIL failed ==="
capture erase "`repx'"
capture _psdash_qa_cleanup
capture log close _all
if $N_FAIL > 0 {
    display as error "FAILED:$FAILED"
    exit 9
}
