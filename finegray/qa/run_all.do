* run_all.do - curated QA runner for finegray
* Usage: cd finegray/qa && stata-mp -b do run_all.do [quick|core|python|full|gates]
*
* The `gates' lane is the three ZZF Monte Carlo gates (recovery, coverage, and
* factorization).  They are HOURS, not minutes (known-truth recovery: 100 reps x
* n=100,000 x 4 arms; LT variance coverage: 1000 reps x 7 arms x 2 fits;
* factorization positivity ladder), so they are deliberately NOT in `full' -- a lane nobody
* can afford to run is a lane nobody runs, and it would take the ordinary suites
* down with it.  They are gates, run on demand, not regression tests.

version 16.0
set more off
set varabbrev off

args lane extra

local lane = lower(strtrim("`lane'"))
if "`lane'" == "" local lane "full"

if "`extra'" != "" {
    display as error "run_all.do accepts at most one lane argument."
    exit 198
}

if !inlist("`lane'", "quick", "core", "python", "full", "gates") {
    display as error "Unknown QA lane: `lane'"
    display as error "Supported lanes: quick, core, python, full, gates"
    exit 198
}

local qa_dir "`c(pwd)'"
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

local orig_plus "`r(orig_plus)'"
local orig_personal "`r(orig_personal)'"
local plus_dir "`r(plus_dir)'"
local personal_dir "`r(personal_dir)'"
local skip_file "`qa_dir'/_skip.txt"

* Explicit lane membership. Do not auto-discover files here; new suites should
* be reviewed and added deliberately so release coverage cannot drift silently.
local quick_files test_finegray.do test_finegray_v110.do test_finegray_v120.do ///
    test_finegray_ties.do test_finegray_optimizer.do ///
    test_finegray_variance.do test_finegray_bootstrap.do ///
    test_finegray_postest.do test_finegray_zzf.do ///
    test_finegray_fvgrammar.do test_finegray_fg03_diagnostic.do ///
    test_finegray_fg06_vce.do test_finegray_fg07_options.do ///
    test_finegray_nuisance.do ///
    test_documentation_examples.do
local core_files `quick_files' ///
    validation_finegray.do validation_finegray_recovery.do ///
    validation_finegray_recovery_paths.do validation_finegray_cif_recovery.do ///
    validation_finegray_cif_se.do validation_finegray_lt_se.do ///
    crossval_predict_stcrreg.do
local python_files crossval_cif.do crossval_predict_phtest.do crossval_finegray.do ///
    crossval_finegray_zzf.do crossval_nuisance.do

* The ZZF Monte Carlo GATES.  Hours, not minutes -- see the header.  They live in
* their own lane so that (a) they are wired in and runnable by name rather than
* being folk knowledge, and (b) they cannot silently blow up `full'.
*
*   validation_finegray_zzf_recovery.do   Gate Z2-green: known-truth recovery of the
*                                         ZZF Weight-1 estimator under delayed entry
*                                         (100 reps x n=100,000 x 4 arms, ~4h)
*   validation_finegray_zzf_coverage.do   Gate Z-inference: which LT variance covers
*                                         (1000 reps x 7 arms x 2 fits, ~1h)
*                                         Passed 2026-07-15 on the equation-7
*                                         stratified-weight correction.
*   validation_finegray_zzf_factorization.do
*                                         Factorization sensitivity: what the
*                                         product weight A=G*H costs when L and C
*                                         share a dependence that does not split
*                                         across strata()/truncstrata(), and why
*                                         the fully-joint alternative is a
*                                         positivity/variance (Z23) choice
*                                         (100 reps x n=100,000 x 5 fits + a
*                                         positivity ladder, ~2h)
local gates_files validation_finegray_zzf_recovery.do ///
    validation_finegray_zzf_coverage.do ///
    validation_finegray_zzf_factorization.do

local full_files `core_files' `python_files'

local all_files ``lane'_files'

* Read optional skip list: one "file.do | reason" per line.
local skip_names ""
capture confirm file "`skip_file'"
if _rc == 0 {
    tempname skipfh
    file open `skipfh' using "`skip_file'", read text
    file read `skipfh' line
    while r(eof) == 0 {
        local raw = strtrim(`"`line'"')
        if "`raw'" != "" & substr("`raw'", 1, 1) != "#" {
            gettoken skip_name skip_reason : raw, parse("|")
            local skip_name = strtrim("`skip_name'")
            local skip_reason = subinstr(`"`skip_reason'"', "|", "", 1)
            local skip_reason = strtrim(`"`skip_reason'"')
            if "`skip_name'" != "" {
                local skip_names : list skip_names | skip_name
                if "`skip_reason'" == "" {
                    local skip_reason "listed in _skip.txt"
                }
                * Index the reason by POSITION, not by a name derived from the
                * filename.  `skip_reason_' + "test_finegray_ties_do" is 33
                * characters and Stata's macro-name limit is 31, so the old
                * name-keyed local died with r(198) on any realistically named
                * suite -- the skip mechanism could not parse the very files it
                * exists to skip.
                local _si : list sizeof skip_names
                local skip_reason_`_si' `"`skip_reason'"'
            }
        }
        file read `skipfh' line
    }
    file close `skipfh'
}

local n_discovered = 0
foreach f of local all_files {
    local ++n_discovered
}

local n_run = 0
local n_pass = 0
local n_fail = 0
local n_skip = 0
local failed_files ""

display as text "finegray QA lane: `lane'"
display as text "Curated QA files: `n_discovered'"

foreach f of local all_files {
    local in_skip : list f in skip_names
    if `in_skip' {
        local ++n_skip
        local _pos : list posof "`f'" in skip_names
        display _newline as error "=== Skipping: `f' ==="
        display as error "  Reason: `skip_reason_`_pos''"
        display as error "  A skipped suite does NOT pass; this run cannot be green."
        continue
    }

    capture confirm file "`qa_dir'/`f'"
    if _rc {
        local ++n_fail
        local failed_files "`failed_files' `f'"
        display _newline as error "=== Missing: `f' ==="
        continue
    }

    local ++n_run
    local _base = subinstr("`f'", ".do", "", .)
    * A suite that exits 0 before opening its log must not inherit a green
    * RESULT from an earlier run.  Remove the expected log before execution;
    * absence afterward is then evidence that the suite never published its
    * checks, not an invitation to read stale state.
    capture erase "`qa_dir'/`_base'.log"
    display _newline as text "=== Running: `f' ==="
    clear all
    set more off
    set varabbrev off
    capture noisily do "`qa_dir'/`f'"
    local _file_rc = _rc

    * rc 0 is NOT the same as "everything was checked".  Require a machine-readable
    * evaluated RESULT sentinel and verify tests = pass + fail, fail = 0, and no
    * smoke/skip marker.  This catches suites that print FAIL but forget to exit,
    * truncated external oracles, and smoke gate runs that are not gate evidence.
    local _sk = 0
    local _result_ok = 0
    local _result_reason "missing evaluated RESULT sentinel"
    if `_file_rc' == 0 {
        capture confirm file "`qa_dir'/`_base'.log"
        if _rc == 0 {
            * Read the log as DATA, not through macros.  A QA log echoes its own
            * source, so its lines are full of quotes and backticks; passing one
            * back through a macro reference dies with r(132) "too few quotes".
            * As a string variable the text is inert -- strpos()/substr() cannot
            * be confused by it.  char(1) as the delimiter keeps each line whole.
            quietly capture import delimited using "`qa_dir'/`_base'.log", ///
                delimiter(`"`=char(1)'"') varnames(nonames) ///
                stringcols(_all) bindquote(nobind) clear
            if _rc == 0 {
                * The line appears twice: echoed source macros parse as missing;
                * only the evaluated output supplies numeric fields.
                quietly capture gen double _tv = ///
                    real(word(substr(v1, strpos(v1, "tests=") + 6, .), 1)) ///
                    if strpos(v1, "RESULT:") > 0 & strpos(v1, "tests=") > 0
                quietly capture gen double _pv = ///
                    real(word(substr(v1, strpos(v1, "pass=") + 5, .), 1)) ///
                    if strpos(v1, "RESULT:") > 0 & strpos(v1, "pass=") > 0
                quietly capture gen double _fv = ///
                    real(word(substr(v1, strpos(v1, "fail=") + 5, .), 1)) ///
                    if strpos(v1, "RESULT:") > 0 & strpos(v1, "fail=") > 0
                quietly count if !missing(_tv, _pv, _fv)
                if _rc == 0 & r(N) == 1 {
                    quietly summarize _tv if !missing(_tv, _pv, _fv), meanonly
                    local _rt = r(mean)
                    quietly summarize _pv if !missing(_tv, _pv, _fv), meanonly
                    local _rp = r(mean)
                    quietly summarize _fv if !missing(_tv, _pv, _fv), meanonly
                    local _rf = r(mean)
                    local _smoke = 0
                    quietly capture gen double _smv = ///
                        real(word(substr(v1, strpos(v1, "smoke=") + 6, .), 1)) ///
                        if strpos(v1, "RESULT:") > 0 & strpos(v1, "smoke=") > 0
                    if _rc == 0 {
                        quietly summarize _smv, meanonly
                        if r(N) > 0 & r(max) < . local _smoke = r(max)
                    }
                    if `_rt' > 0 & `_rt' == `_rp' + `_rf' & `_rf' == 0 & `_smoke' == 0 {
                        local _result_ok = 1
                        local _result_reason ""
                    }
                    else {
                        local _result_reason "RESULT tests=`_rt' pass=`_rp' fail=`_rf' smoke=`_smoke'"
                    }
                }
                else if _rc == 0 & r(N) > 1 {
                    local _result_reason "multiple evaluated RESULT sentinels"
                }
                quietly capture gen double _skv = ///
                    real(word(substr(v1, strpos(v1, "skip=") + 5, .), 1)) ///
                    if strpos(v1, "RESULT:") > 0 & strpos(v1, "skip=") > 0
                if _rc == 0 {
                    quietly summarize _skv
                    if r(N) > 0 & r(max) < . local _sk = r(max)
                }
            }
            clear
        }
    }

    if `_file_rc' == 0 & `_sk' == 0 & `_result_ok' {
        local ++n_pass
        display as result "  PASSED: `f'"
    }
    else if `_file_rc' == 0 & `_sk' > 0 {
        local ++n_fail
        local failed_files "`failed_files' `f'(skipped `_sk')"
        display as error "  FAILED: `f' -- exited 0 but SKIPPED `_sk' check(s)"
        display as error "  A skipped external oracle is an unrun check, not a pass."
        display as error "  Install the missing dependency and re-run."
    }
    else if `_file_rc' == 0 {
        local ++n_fail
        local failed_files "`failed_files' `f'(invalid RESULT)"
        display as error "  FAILED: `f' -- `_result_reason'"
        display as error "  rc=0 without a zero-failure evaluated RESULT is not a pass."
    }
    else {
        local ++n_fail
        local failed_files "`failed_files' `f'"
        display as error "  FAILED: `f' (rc=`_file_rc')"
    }
}

display _newline as result ///
    "=== QA Summary (`lane'): `n_pass'/`n_run' passed, `n_fail' failed, `n_skip' skipped ==="
display as text "RESULT: run_all tests=`n_run' pass=`n_pass' fail=`n_fail' skip=`n_skip'"

local suite_rc = 0
if `n_fail' > 0 {
    display as error "Failed files:`failed_files'"
    local suite_rc = 1
}

* A file listed in _skip.txt was NOT run, so the suite did not prove what it
* claims to prove.  This runner used to increment n_skip and then ignore it:
* suite_rc was 1 only when n_fail > 0, so dropping a suite into _skip.txt made
* the release gate print ALL CURATED QA FILES PASSED while silently not running
* it.  That is the mechanism by which a 347/347 green suite coexisted with three
* release-blocking defects (QA-H01).  A gate that can be disabled by adding one
* file is not a gate: skipping is now a FAILURE, and _skip.txt can only ever
* document a known-red suite, never hide one.
if `n_skip' > 0 {
    display as error ///
        "`n_skip' curated file(s) were SKIPPED via _skip.txt and did not run:"
    foreach s of local skip_names {
        local _pos : list posof "`s'" in skip_names
        display as error "  `s' -- `skip_reason_`_pos''"
    }
    display as error "A skipped suite is an unrun suite. This run is NOT green."
    local suite_rc = 1
}

if `suite_rc' == 0 {
    display as result "ALL CURATED QA FILES PASSED"
}

capture ado uninstall finegray
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

if `suite_rc' > 0 exit `suite_rc'
