clear all
set more off
version 16.0
set varabbrev off

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_audit_2026_10_05_qadocs.do must be run from iivw/qa"
    log close _all
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"

* QDR01-QDR03 drive qa/run_coverage_gate.sh against a scratch copy of the
* package. Native stata-mp refuses SIMS < 1000, so a SIMS=1 queue is a genuine
* native failure; a stub stata-mp on PATH supplies the positive controls only.
* No coverage gate is run here.

global QD_TOOLS "`qa_dir'/tools"
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

tempfile wdbase
local wd "`wdbase'_qd"
capture mkdir "`wd'"

* Read a text file into a local; contains() test via Mata.
capture program drop _qd_grep
program define _qd_grep, rclass
    version 16.0
    args file pattern
    mata: st_numscalar("__qd_n", (fileexists(st_local("file")) ? sum(regexm(cat(st_local("file")), st_local("pattern"))) : 0))
    return scalar n = scalar(__qd_n)
end

* Fresh scratch package copy at `wd'/`name'/iivw
capture program drop _qd_copy
program define _qd_copy
    version 16.0
    args pkg wd name
    shell rm -rf "`wd'/`name'"
    shell mkdir -p "`wd'/`name'"
    shell cp -a "`pkg'" "`wd'/`name'/iivw"
    shell rm -rf "`wd'/`name'/iivw/qa/_inf_blocks" "`wd'/`name'/iivw/qa/coverage_results"
    shell rm -f "`wd'/`name'/iivw/qa/"*.log
end

* Runs one runner subcommand through tools/covgate_env.sh; leaves its exit
* status in r(rc) and its output at `wd'/`name'/out.txt.
capture program drop _qd_run
program define _qd_run, rclass
    version 16.0
    syntax , WD(string) NAme(string) CMD(string) SIMS(string) REPS(string) ///
        [BLOCK(string) FAKEbin(string)]
    if "`block'" == "" local block 1
    local sd "`wd'/`name'"
    shell rm -f "`sd'/rc.txt"
    shell bash "$QD_TOOLS/covgate_env.sh" "`sd'" `cmd' `sims' `reps' `block' "`fakebin'"
    tempname fh
    file open `fh' using "`sd'/rc.txt", read text
    file read `fh' line
    file close `fh'
    return scalar rc = real(strtrim(`"`line'"'))
end

* Stub stata-mp (tools/stub_stata_mp.sh) in `dir', in mode ok|norow|nosentinel.
capture program drop _qd_stub
program define _qd_stub
    version 16.0
    args dir mode
    shell mkdir -p "`dir'"
    shell cp "$QD_TOOLS/stub_stata_mp.sh" "`dir'/stata-mp"
    shell chmod +x "`dir'/stata-mp"
    tempname fh
    file open `fh' using "`dir'/mode", write text replace
    file write `fh' "`mode'" _n
    file close `fh'
end

**# QDR01 - a failed work queue must not return success

local ++test_count
capture noisily {
    _qd_copy "`pkg_dir'" "`wd'" q1
    * No prep: no retained manifest and no work tree.
    _qd_run, wd("`wd'") name(q1) cmd(run) sims(1) reps(2)
    assert r(rc) != 0
    _qd_grep "`wd'/q1/out.txt" "no retained source manifest"
    assert r(n) >= 1
    * Prep, then a genuine native refusal (SIMS=1 is below the engine floor).
    _qd_run, wd("`wd'") name(q1) cmd(prep) sims(1) reps(2)
    assert r(rc) == 0
    _qd_run, wd("`wd'") name(q1) cmd(run) sims(1) reps(2)
    assert r(rc) != 0
    _qd_grep "`wd'/q1/out.txt" "^FAIL "
    assert r(n) >= 1
    _qd_grep "`wd'/q1/out.txt" "blocks: 0 / 1 complete"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: QDR01 - failed queue returns nonzero (missing tree and native refusal)"
    local ++pass_count
}
else {
    display as error "  FAIL: QDR01 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' QDR01"
}

**# QDR01 positive control - successful stub queue returns 0

local ++test_count
capture noisily {
    _qd_copy "`pkg_dir'" "`wd'" q1p
    _qd_stub "`wd'/bin_ok" ok
    _qd_run, wd("`wd'") name(q1p) cmd(prep) sims(2) reps(2)
    assert r(rc) == 0
    _qd_run, wd("`wd'") name(q1p) cmd(run) sims(2) reps(2) block(1) fakebin("`wd'/bin_ok")
    assert r(rc) == 0
    _qd_grep "`wd'/q1p/out.txt" "blocks: 2 / 2 complete"
    assert r(n) == 1
    _qd_grep "`wd'/q1p/out.txt" "^OK "
    assert r(n) == 2
}
if _rc == 0 {
    display as result "  PASS: QDR01p - a successful queue still returns 0 and pools every block"
    local ++pass_count
}
else {
    display as error "  FAIL: QDR01p (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' QDR01p"
}

**# QDR02 - rejected prep keeps the manifest; run and combine refuse a changed SRC

local ++test_count
capture noisily {
    _qd_copy "`pkg_dir'" "`wd'" q2
    _qd_run, wd("`wd'") name(q2) cmd(prep) sims(1) reps(2)
    assert r(rc) == 0
    shell cp "`wd'/q2/res/MANIFEST.txt" "`wd'/q2/manifest0.txt"
    shell cp "`wd'/q2/res/MANIFEST.PREV.txt" "`wd'/q2/prev0.txt"
    shell printf '* qdr02 probe\n' >> "`wd'/q2/iivw/iivw.ado"
    _qd_run, wd("`wd'") name(q2) cmd(prep) sims(1) reps(2)
    assert r(rc) == 3
    shell cmp -s "`wd'/q2/res/MANIFEST.txt" "`wd'/q2/manifest0.txt"; echo $? > "`wd'/q2/cmp1.txt"
    shell cmp -s "`wd'/q2/res/MANIFEST.PREV.txt" "`wd'/q2/prev0.txt"; echo $? > "`wd'/q2/cmp2.txt"
    foreach f in cmp1 cmp2 {
        tempname fh
        file open `fh' using "`wd'/q2/`f'.txt", read text
        file read `fh' line
        file close `fh'
        assert strtrim(`"`line'"') == "0"
    }
    * No leftover candidate manifest.
    shell ls -a "`wd'/q2/res" | grep -c manifest.X > "`wd'/q2/cand.txt"
    tempname fh
    file open `fh' using "`wd'/q2/cand.txt", read text
    file read `fh' line
    file close `fh'
    assert strtrim(`"`line'"') == "0"
    * Direct run and combine must refuse before any native launch.
    shell rm -rf "`wd'/q2/res/logs"
    _qd_run, wd("`wd'") name(q2) cmd(run) sims(1) reps(2)
    assert r(rc) == 3
    _qd_grep "`wd'/q2/out.txt" "SRC differs"
    assert r(n) >= 1
    _qd_grep "`wd'/q2/out.txt" "no rows file"
    assert r(n) == 0
    _qd_run, wd("`wd'") name(q2) cmd(combine) sims(1) reps(2)
    assert r(rc) == 3
    _qd_grep "`wd'/q2/out.txt" "SRC differs"
    assert r(n) >= 1
    _qd_grep "`wd'/q2/out.txt" "combine_iptw"
    assert r(n) == 0
    * No manifest at all (prep never ran): run refuses too.
    _qd_copy "`pkg_dir'" "`wd'" q2b
    _qd_run, wd("`wd'") name(q2b) cmd(run) sims(1) reps(2)
    assert r(rc) == 3
}
if _rc == 0 {
    display as result "  PASS: QDR02 - rejected prep keeps the manifest; run/combine refuse a changed SRC"
    local ++pass_count
}
else {
    display as error "  FAIL: QDR02 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' QDR02"
}

**# QDR02 - a cached work tree that differs from the manifest is not run

local ++test_count
capture noisily {
    _qd_copy "`pkg_dir'" "`wd'" q2c
    _qd_stub "`wd'/bin_ok" ok
    _qd_run, wd("`wd'") name(q2c) cmd(prep) sims(1) reps(2)
    assert r(rc) == 0
    shell printf '* tamper\n' >> "`wd'/q2c/base/work/iptw_00001_00001/iivw/iivw.ado"
    _qd_run, wd("`wd'") name(q2c) cmd(run) sims(1) reps(2) fakebin("`wd'/bin_ok")
    assert r(rc) != 0
    _qd_grep "`wd'/q2c/out.txt" "work tree differs"
    assert r(n) == 1
    shell ls "`wd'/q2c/res/blocks" | wc -l > "`wd'/q2c/n.txt"
    tempname fh
    file open `fh' using "`wd'/q2c/n.txt", read text
    file read `fh' line
    file close `fh'
    assert strtrim(`"`line'"') == "0"
}
if _rc == 0 {
    display as result "  PASS: QDR02b - a tampered cached work tree is refused"
    local ++pass_count
}
else {
    display as error "  FAIL: QDR02b (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' QDR02b"
}

**# QDR03 - a failed native rerun must not pool a stale row

local ++test_count
capture noisily {
    _qd_copy "`pkg_dir'" "`wd'" q3
    _qd_run, wd("`wd'") name(q3) cmd(prep) sims(1) reps(2)
    assert r(rc) == 0
    * Plant a genuine native row from an earlier, different configuration.
    local blkqa "`wd'/q3/base/work/iptw_00001_00001/iivw/qa"
    tempname fh
    file open `fh' using "`wd'/q3/plant.sh", write text replace
    file write `fh' `"cd "`blkqa'" && stata-mp -b do validation_iivw_inference.do iptw 1000 2 20260715 1 1 0 1 >/dev/null 2>&1"' _n
    file close `fh'
    shell bash "`wd'/q3/plant.sh"
    confirm file "`blkqa'/_inf_blocks/iptw_00001_00001.dta"
    _qd_run, wd("`wd'") name(q3) cmd(run) sims(1) reps(2)
    assert r(rc) != 0
    _qd_grep "`wd'/q3/out.txt" "^OK "
    assert r(n) == 0
    capture confirm file "`wd'/q3/res/blocks/iptw_00001_00001.dta"
    assert _rc != 0
    capture confirm file "`blkqa'/_inf_blocks/iptw_00001_00001.dta"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: QDR03 - failed native rerun purges the stale row and pools nothing"
    local ++pass_count
}
else {
    display as error "  FAIL: QDR03 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' QDR03"
}

**# QDR03 - the block sentinel and the row are both required

local ++test_count
capture noisily {
    foreach mode in norow nosentinel {
        _qd_copy "`pkg_dir'" "`wd'" q3`mode'
        _qd_stub "`wd'/bin_`mode'" `mode'
        _qd_run, wd("`wd'") name(q3`mode') cmd(prep) sims(1) reps(2)
        assert r(rc) == 0
        _qd_run, wd("`wd'") name(q3`mode') cmd(run) sims(1) reps(2) fakebin("`wd'/bin_`mode'")
        assert r(rc) != 0
        capture confirm file "`wd'/q3`mode'/res/blocks/iptw_00001_00001.dta"
        assert _rc != 0
    }
    * A later success clears the earlier FAILED log for the same block.
    _qd_stub "`wd'/bin_ok" ok
    _qd_run, wd("`wd'") name(q3nosentinel) cmd(run) sims(1) reps(2) fakebin("`wd'/bin_ok")
    assert r(rc) == 0
    capture confirm file "`wd'/q3nosentinel/res/blocks/iptw_00001_00001.dta"
    assert _rc == 0
    capture confirm file "`wd'/q3nosentinel/res/logs/iptw_00001_00001.FAILED.log"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: QDR03b - pooling needs the fresh row and the sentinel; success clears the FAILED log"
    local ++pass_count
}
else {
    display as error "  FAIL: QDR03b (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' QDR03b"
}

**# QDR04 - the README dependency table lists executed requirements

local ++test_count
capture noisily {
    _qd_grep "`qa_dir'/README.md" "^[|] .quick. [|].*Rscript"
    assert r(n) == 1
    _qd_grep "`qa_dir'/README.md" "^[|] .core. [|].*NumPy.*clubSandwich"
    assert r(n) == 1
    _qd_grep "`qa_dir'/README.md" "^[|] .full. [|].*IrregLong"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: QDR04 - quick/core/full dependency rows name Rscript, NumPy, clubSandwich"
    local ++pass_count
}
else {
    display as error "  FAIL: QDR04 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' QDR04"
}

**# QDR05 - missing values cannot satisfy the comparisons that were blind

local ++test_count
capture noisily {
    * Native counterfactual: the unguarded forms pass on all-missing input.
    matrix __qd_m = (., .)
    matrix __qd_n = (., .)
    assert mreldif(__qd_m, __qd_n) == 0
    assert reldif(., .) == 0
    assert max(., 0) == 0
    * The guards now in the suites reject the same input.
    capture assert !matmissing(__qd_m) & !matmissing(__qd_n)
    assert _rc == 9
    capture assert !missing(., 1, 2)
    assert _rc == 9
    * The guard lines are present at each named site.
    _qd_grep "`qa_dir'/validation_fixture_domains.do" "assert !matmissing[(].B.[)] & !matmissing[(].W.[)]"
    assert r(n) == 1
    _qd_grep "`qa_dir'/validation_fixture_domains.do" "assert !matmissing[(]e[(]b[)][)] & !matmissing[(].W.[)]"
    assert r(n) == 1
    _qd_grep "`qa_dir'/validation_fixture_domains.do" "assert !missing[(]r[(]lb[)],r[(]ub[)],r[(]estimate[)],r[(]se[)][)]"
    assert r(n) == 1
    _qd_grep "`qa_dir'/test_iivw_v413_regressions.do" "assert !missing[(].stored_ll., .stored_ul., .replay_ll., .replay_ul.[)]"
    assert r(n) == 1
    _qd_grep "`qa_dir'/test_iivw_cr_ladder.do" "assert !missing[(]value[)]"
    assert r(n) == 1
    _qd_grep "`qa_dir'/test_iivw_cr_ladder.do" "^ +isid type"
    assert r(n) == 1
    _qd_grep "`qa_dir'/test_iivw_cr_ladder.do" "assert !missing[(].s_b., .s_cr0."
    assert r(n) == 1
    _qd_grep "`qa_dir'/test_iivw_cr_ladder.do" "assert !missing[(].r_b., .r_cr0."
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: QDR05 - missing-blind comparisons are guarded"
    local ++pass_count
}
else {
    display as error "  FAIL: QDR05 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' QDR05"
}

**# QDR06-08, QDR11, SS03 - help wording matches the implemented behaviour

local ++test_count
capture noisily {
    * QDR06: entry-only IIW component is exactly 1, not rescaled.
    _qd_grep "`pkg_dir'/iivw_weight.sthlp" "rescaled with the rest"
    assert r(n) == 0
    _qd_grep "`pkg_dir'/iivw_weight.sthlp" "component is exactly 1 after modeled-event weights"
    assert r(n) == 1
    * QDR08: IPTW-only final weights do not vary by visit.
    _qd_grep "`pkg_dir'/iivw_weight.sthlp" "genuinely vary from visit to visit"
    assert r(n) == 0
    _qd_grep "`pkg_dir'/iivw_weight.sthlp" "subject-constant IPTW-only final weights"
    assert r(n) == 1
    * QDR07: scalar diagnostic cells are not merged.
    _qd_grep "`pkg_dir'/iivw_diagnose.sthlp" "merged across the estimate columns. The"
    assert r(n) == 0
    _qd_grep "`pkg_dir'/iivw_diagnose.sthlp" "scalar rows are not merged"
    assert r(n) == 1
    * QDR11: convergence is enforced in the bootstrap wrappers.
    _qd_grep "`pkg_dir'/iivw_fit.sthlp" "check is skipped when using"
    assert r(n) == 0
    _qd_grep "`pkg_dir'/iivw_fit.sthlp" "does not override that outcome gate"
    assert r(n) == 1
    * SS03: sheet() limit is bytes, in every help file documenting sheet().
    foreach h in balance diagnose exogtest {
        _qd_grep "`pkg_dir'/iivw_`h'.sthlp" "limits worksheet names to 31 UTF-8 bytes"
        assert r(n) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: QDR06/07/08/11 and SS03 - help text states the implemented contract"
    local ++pass_count
}
else {
    display as error "  FAIL: help wording (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' helpwording"
}

**# QDR07 behaviour - the workbook really leaves scalar diagnostic cells unmerged

* Source pin only: the writer's comment that scalar rows stay in column C with
* no merge, which the help now matches. No workbook is built here.
local ++test_count
capture noisily {
    _qd_grep "`pkg_dir'/_iivw_export_table.ado" "stay plainly in column"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: QDR07b - writer keeps scalar rows unmerged (source pin)"
    local ++pass_count
}
else {
    display as error "  FAIL: QDR07b (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' QDR07b"
}

**# QDR09 - runbook names the measured timings and the current build

local ++test_count
capture noisily {
    _qd_grep "`qa_dir'/COVERAGE_GATE_RUNBOOK.md" "has [*][*]not[*][*] been measured end to end"
    assert r(n) == 0
    _qd_grep "`qa_dir'/COVERAGE_GATE_RUNBOOK.md" "8h55m"
    assert r(n) >= 1
    _qd_grep "`qa_dir'/COVERAGE_GATE_RUNBOOK.md" "5h34m"
    assert r(n) >= 1
    _qd_grep "`qa_dir'/COVERAGE_GATE_RUNBOOK.md" "against the 4.1.2 source manifest"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: QDR09 - runbook no longer states a stale runtime/build claim"
    local ++pass_count
}
else {
    display as error "  FAIL: QDR09 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' QDR09"
}

**# QDR10 - verify_headline.py is relocatable and its gate checks tiling/finite/binary

local ++test_count
capture noisily {
    _qd_grep "`qa_dir'/coverage_results/verify_headline.py" "/t[m]p/c[l]aude"
    assert r(n) == 0
    local py "`qa_dir'/coverage_results/verify_headline.py"
    tempname fh
    file open `fh' using "`wd'/vh.py", write text replace
    file write `fh' "import sys, os, numpy as np, pandas as pd" _n
    file write `fh' "root = sys.argv[1]; case = sys.argv[2]" _n
    file write `fh' "d = os.path.join(root, case); os.makedirs(d, exist_ok=True)" _n
    file write `fh' "for fam in ('iiw','iptw','fiptiw'):" _n
    file write `fh' "    n = 1000" _n
    file write `fh' "    sim = np.arange(1, n+1)" _n
    file write `fh' "    cov = np.where(sim % 20 == 0, 0.0, 1.0)" _n
    file write `fh' "    b = np.linspace(-1, 1, n) * 0.1 + {'iiw':0.5,'iptw':1.5,'fiptiw':1.0}[fam]" _n
    file write `fh' "    df = pd.DataFrame({'sim': sim, 'cov_refit': cov, 'b_refit': b, 'se_refit': 0.1, 'se_fwb': 0.1, 'se_fix': 0.1})" _n
    file write `fh' "    if case == 'gap' and fam == 'iptw': df = df[df.sim != 500]" _n
    file write `fh' "    if case == 'nan' and fam == 'iptw': df.loc[3, 'b_refit'] = np.nan" _n
    file write `fh' "    if case == 'missingfam' and fam == 'iptw': continue" _n
    file write `fh' "    df.to_stata(os.path.join(d, fam + '_00001_01000.dta'), write_index=False)" _n
    file close `fh'
    shell python3 "`wd'/vh.py" "`wd'" good
    shell python3 "`wd'/vh.py" "`wd'" gap
    shell python3 "`wd'/vh.py" "`wd'" nan
    shell python3 "`wd'/vh.py" "`wd'" missingfam
    shell python3 "`py'" "`wd'/good" > "`wd'/vh_good.txt" 2>&1; echo $? > "`wd'/vh_good.rc"
    shell python3 "`py'" "`wd'/gap" > "`wd'/vh_gap.txt" 2>&1; echo $? > "`wd'/vh_gap.rc"
    shell python3 "`py'" "`wd'/nan" > "`wd'/vh_nan.txt" 2>&1; echo $? > "`wd'/vh_nan.rc"
    shell python3 "`py'" "`wd'/missingfam" > "`wd'/vh_mf.txt" 2>&1; echo $? > "`wd'/vh_mf.rc"
    shell python3 "`py'" > "`wd'/vh_none.txt" 2>&1; echo $? > "`wd'/vh_none.rc"
    shell python3 "`py'" "`wd'/does_not_exist" > "`wd'/vh_nod.txt" 2>&1; echo $? > "`wd'/vh_nod.rc"
    foreach f in good gap nan mf none nod {
        file open `fh' using "`wd'/vh_`f'.rc", read text
        file read `fh' line
        file close `fh'
        local rc_`f' = real(strtrim(`"`line'"'))
    }
    assert `rc_good' == 0
    assert `rc_gap' == 0 & `rc_nan' == 0
    assert `rc_mf' != 0 & `rc_none' != 0 & `rc_nod' != 0
    _qd_grep "`wd'/vh_mf.txt" "iptw blocks are absent"
    assert r(n) == 1
    * Gate column per family: good passes everywhere; gap/nan fail iptw only.
    _qd_grep "`wd'/vh_good.txt" "iptw .* PASS +tiles1..1000=True"
    assert r(n) == 1
    _qd_grep "`wd'/vh_gap.txt" "iptw .* FAIL +tiles1..1000=False"
    assert r(n) == 1
    _qd_grep "`wd'/vh_gap.txt" "iiw .* PASS"
    assert r(n) == 1
    _qd_grep "`wd'/vh_nan.txt" "iptw .* FAIL"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: QDR10 - verifier needs a pool path, rejects absent families, gates on tiling/finiteness"
    local ++pass_count
}
else {
    display as error "  FAIL: QDR10 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' QDR10"
}

**# Summary

shell rm -rf "`wd'"
iivw_qa_summary, name("test_iivw_audit_2026_10_05_qadocs") tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed_tests'")
