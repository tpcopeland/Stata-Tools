* test_v141_features.do — QA for psdash v1.4.1 usability/transparency fixes
* Covers:
*   SR  — _psdash_strip_replace helper: strips a redundant trailing ", replace"
*         (case-insensitive), leaves plain values and non-"replace" tails alone.
*   INT — name()/saving() accept a twoway-style ", replace" suboption end-to-end
*         (no cryptic r(198)); plain values still work; the right graph name/file
*         results (proving the ", replace" was stripped, not passed through).
*   ATC — multi-group estimand(atc): fires the once-per-command note, uses the
*         generalized ATE weights (unchanged behavior), never double-warns in
*         combined, does not warn for att/binary, and leaks no guard global.
*   DOC — the sthlp documents all three behavior notes.
* Usage: cd psdash/qa && stata-mp -b do test_v141_features.do

clear all
version 16.0
set more off

capture log close _all
log using "test_v141_features.log", replace nomsg

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

* Build a 3-group generalized-PS dataset (p0 p1 p2 are own-group GPS columns)
capture program drop _mg_data
program define _mg_data
    clear
    set seed 12345
    set obs 900
    gen g = mod(_n, 3)
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    quietly mlogit g x1 x2
    predict double p0 p1 p2, pr
end

* Count occurrences of the multi-group ATC note in an isolated log file
capture program drop _note_count
program define _note_count, rclass
    args logf
    local needle "with a multi-valued treatment"
    local content = fileread(`"`logf'"')
    local n0 = length(`"`content'"')
    local rest = subinstr(`"`content'"', `"`needle'"', "", .)
    return scalar cnt = (`n0' - length(`"`rest'"')) / length("`needle'")
end

**# SR0 — helper is shipped and autoloads after net install
display as text _n "--- SR0: _psdash_strip_replace autoloads ---"
capture which _psdash_strip_replace
_t "SR0_helper_autoloads" `=_rc'

**# SR1..SR7 — strip helper unit behavior
display as text _n "--- SR1-SR7: strip_replace unit behavior ---"
capture noisily {
    _psdash_strip_replace, option(name) value(`"g, replace"')
    assert r(stripped) == 1
    assert `"`r(value)'"' == "g"
}
_t "SR1_strip_basic" `=_rc'

capture noisily {
    _psdash_strip_replace, option(saving) value(`"myfile.png, replace"')
    assert r(stripped) == 1
    assert `"`r(value)'"' == "myfile.png"
}
_t "SR2_strip_filename" `=_rc'

capture noisily {
    * Case-insensitive: capitalized Replace must still strip
    _psdash_strip_replace, option(name) value(`"g, Replace"')
    assert r(stripped) == 1
    assert `"`r(value)'"' == "g"
}
_t "SR3_strip_caseinsensitive" `=_rc'

capture noisily {
    * Plain value is left untouched
    _psdash_strip_replace, option(name) value(`"plainname"')
    assert r(stripped) == 0
    assert `"`r(value)'"' == "plainname"
}
_t "SR4_plain_untouched" `=_rc'

capture noisily {
    * "replace" must be the whole trailing token — "replaced.dta" is not stripped
    _psdash_strip_replace, option(saving) value(`"out, replaced.dta"')
    assert r(stripped) == 0
    assert `"`r(value)'"' == "out, replaced.dta"
}
_t "SR5_replaced_not_stripped" `=_rc'

capture noisily {
    * Empty value is a clean no-op
    _psdash_strip_replace, option(name) value(`""')
    assert r(stripped) == 0
    assert `"`r(value)'"' == ""
}
_t "SR6_empty_noop" `=_rc'

capture noisily {
    * Extra whitespace around the comma still strips
    _psdash_strip_replace, option(name) value(`"g ,  replace"')
    assert r(stripped) == 1
    assert `"`r(value)'"' == "g"
}
_t "SR7_whitespace_tolerant" `=_rc'

**# INT1..INT3 — name()/saving() acceptance end-to-end
display as text _n "--- INT1-INT3: name()/saving() , replace acceptance ---"
sysuse auto, clear
quietly logit foreign price mpg weight
quietly predict ps_a, pr

capture noisily {
    * name(g1, replace) must not error and must produce a graph actually named g1
    psdash overlap foreign ps_a, name(g1, replace)
    assert _rc == 0
    graph describe g1
}
_t "INT1_name_replace_accepted" `=_rc'

capture noisily {
    * Clean single-extension filename (a real user's saving(plot.png, replace))
    local tf "`c(tmpdir)'/psdash_int2_v141.png"
    capture erase "`tf'"
    psdash overlap foreign ps_a, saving(`"`tf', replace"')
    confirm file "`tf'"
    capture erase "`tf'"
}
_t "INT2_saving_replace_accepted" `=_rc'

capture noisily {
    * Plain name still works (regression guard)
    psdash overlap foreign ps_a, name(g2)
    graph describe g2
}
_t "INT3_plain_name_regression" `=_rc'

**# ATC1 — multi-group atc uses generalized ATE weights (unchanged behavior)
display as text _n "--- ATC1: multi-group atc == ate weights ---"
capture noisily {
    _mg_data
    psdash weights g, psvars(p0 p1 p2) estimand(atc)
    local atc_mean = r(mean_wt)
    local atc_ess  = r(ess)
    _mg_data
    psdash weights g, psvars(p0 p1 p2) estimand(ate)
    local ate_mean = r(mean_wt)
    local ate_ess  = r(ess)
    assert reldif(`atc_mean', `ate_mean') < 1e-10
    assert reldif(`atc_ess',  `ate_ess')  < 1e-10
    * And att must genuinely differ (proves the scenario is discriminating)
    _mg_data
    psdash weights g, psvars(p0 p1 p2) estimand(att)
    assert reldif(r(mean_wt), `atc_mean') > 1e-4
}
_t "ATC1_atc_equals_ate_weights" `=_rc'

**# ATC2 — combined fires the note EXACTLY once despite 5 internal detect calls
display as text _n "--- ATC2: combined atc warns exactly once ---"
capture noisily {
    _mg_data
    tempfile atclog
    quietly log using "`atclog'.log", replace text name(atccap)
    capture noisily psdash combined g, covariates(x1 x2) psvars(p0 p1 p2) estimand(atc)
    local _crc = _rc
    capture log close atccap
    assert `_crc' == 0
    _note_count "`atclog'.log"
    assert r(cnt) == 1
}
_t "ATC2_combined_warns_once" `=_rc'

**# ATC3 — multi-group att does NOT warn
display as text _n "--- ATC3: att does not warn ---"
capture noisily {
    _mg_data
    tempfile attlog
    quietly log using "`attlog'.log", replace text name(attcap)
    capture noisily psdash weights g, psvars(p0 p1 p2) estimand(att)
    capture log close attcap
    _note_count "`attlog'.log"
    assert r(cnt) == 0
}
_t "ATC3_att_no_warn" `=_rc'

**# ATC4 — binary atc does NOT warn (unaffected, uses (1-e)/e)
display as text _n "--- ATC4: binary atc does not warn ---"
capture noisily {
    sysuse auto, clear
    quietly logit foreign price mpg
    quietly predict psb, pr
    tempfile binlog
    quietly log using "`binlog'.log", replace text name(bincap)
    capture noisily psdash weights foreign psb, estimand(atc)
    capture log close bincap
    _note_count "`binlog'.log"
    assert r(cnt) == 0
}
_t "ATC4_binary_atc_no_warn" `=_rc'

**# ATC5 — the once-guard global is cleared after the command (no leak)
display as text _n "--- ATC5: guard global does not leak ---"
capture noisily {
    _mg_data
    psdash weights g, psvars(p0 p1 p2) estimand(atc)
    assert "$PSDASH_atc_warned" == ""
}
_t "ATC5_no_global_leak" `=_rc'

**# DOC1 — sthlp documents the three v1.4.1 notes
display as text _n "--- DOC1: sthlp documents v1.4.1 notes ---"
capture noisily {
    local h = fileread("`pkg_dir'/psdash.sthlp")
    assert strpos(`"`h'"', "not uniquely defined") > 0
    assert strpos(`"`h'"', "ignored with a note") > 0
    assert strpos(`"`h'"', "last-run") > 0
}
_t "DOC1_sthlp_documents_notes" `=_rc'

**# Summary
display as text _n "=== v1.4.1 FEATURE TESTS: $N_PASS passed, $N_FAIL failed ==="
display "RESULT: test_v141_features tests=`=$N_PASS + $N_FAIL' pass=$N_PASS fail=$N_FAIL"
capture _psdash_qa_cleanup
capture log close _all
if $N_FAIL > 0 {
    display as error "FAILED:$FAILED"
    exit 9
}
