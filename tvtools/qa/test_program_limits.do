*! test_program_limits.do
*! Statement-count headroom for every shipped tvtools program.
*!
*! A single Stata program may hold at most 3500 statements. A program that
*! holds more does not load: `run file.ado' exits with r(1000) and afterwards
*! the command simply does not exist. There is no partial load, no line number,
*! and no message naming the program or the limit -- an installed user sees
*! only "command tvexpose is unrecognized", r(199), from the next call.
*!
*! This is a live hazard for tvtools, not a theoretical one. At 1.9.1
*! tvexpose.ado sat TWO statements below the ceiling, so wrapping any span of
*! it in one further `if' made the whole command fail to load. That is how the
*! limit was found. Moving the report-only diagnostics block into
*! _tvexpose_diagnostics.ado restored roughly 247 statements of margin.
*!
*! Axes probed, and why each one is here:
*!   L1-L3  the ceiling itself, measured against synthetic programs. 3500 is
*!          StataCorp's constant, not ours; if a future release moves it these
*!          three tests say so instead of silently invalidating the margin
*!          arithmetic below.
*!   L4     the package directory was actually found. Without this, a bad path
*!          would make an empty file list read as "every program passed".
*!   L5+    every shipped .ado loads as distributed, and still loads with
*!          $LIMIT_MARGIN extra statements spliced into every program it
*!          defines. The second half is a MARGIN test, not a load test: it
*!          fails while there is still room to act rather than after a released
*!          package has stopped working. Splicing real statements in is exact
*!          -- it asks Stata the question directly and needs no
*!          reimplementation of Stata's statement counter.
*!   last   the measured margin for the largest shipped program, bisected and
*!          reported so the number lives in the log, not in a comment.
*!
*! This suite's test count is 4 + 2 x (shipped .ado files), so adding or
*! removing a shipped program changes it and the pinned count in
*! _tvtools_qa_manifest.do has to move with it. That coupling is deliberate:
*! a new .ado that nobody remembered to check for headroom is exactly the
*! thing this suite exists to catch.
*!
*! The file rewriting happens in Mata on purpose. Reading .ado source through
*! Stata locals re-expands the backticks and quotes in the code being read; the
*! scanner would be parsing its own macro expansion rather than the file.

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_program_limits.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

global TVL_PASS = 0
global TVL_FAIL = 0
global TVL_FAILED ""
local test_count = 0

* Statements of headroom every shipped program must still have. A file that
* fails here is not broken yet; it is one ordinary edit away from breaking.
global LIMIT_MARGIN = 100

display as result "tvtools QA: program statement limits -- $S_DATE $S_TIME"
display as text "package dir: `pkg_dir'"

capture program drop _tvl_check
program define _tvl_check
    args ok label detail
    if `ok' {
        global TVL_PASS = $TVL_PASS + 1
        display as result "  PASS `label'"
    }
    else {
        global TVL_FAIL = $TVL_FAIL + 1
        global TVL_FAILED "$TVL_FAILED `label'"
        display as error "  FAIL `label': `detail'"
    }
end

mata:
mata set matastrict on

// Write a program holding exactly nstmt body statements.
void _tvl_write_synth(string scalar path, real scalar nstmt)
{
    real scalar fh, i
    (void) _unlink(path)
    fh = fopen(path, "w")
    fput(fh, "program define _tvl_synth_probe")
    for (i = 1; i <= nstmt; i++) fput(fh, "di 1")
    fput(fh, "end")
    fclose(fh)
}

// Copy src to out, inserting pad statements immediately before the `end' that
// closes each program the file defines. mata sessions also close with a bare
// `end'; splicing Stata statements into one would be a syntax error rather
// than a limit test, so the scanner tracks which kind of block is open.
// Returns the number of programs padded, and leaves their names in the Stata
// local `tvl_prognames' so the caller can drop them: `run' on a file that
// redefines an existing program exits r(110), which would otherwise read as a
// headroom failure on every second call.
real scalar _tvl_splice_file(string scalar src, string scalar out,
                             real scalar pad)
{
    string colvector L
    string scalar t, names, nm
    real scalar fh, i, j, n, inprog, inmata, nprog

    L = cat(src)
    n = rows(L)
    inprog = inmata = nprog = 0
    names = ""
    (void) _unlink(out)
    fh = fopen(out, "w")
    for (i = 1; i <= n; i++) {
        t = strtrim(L[i])
        if (!inmata & !inprog) {
            if (substr(t, 1, 14) == "program define" |
                (substr(t, 1, 8) == "program " &
                 substr(t, 1, 12) != "program drop" &
                 substr(t, 1, 12) != "program list" &
                 substr(t, 1, 11) != "program dir")) {
                inprog = 1
                nprog++
                // "program define foo, rclass" -> "foo"
                nm = tokens(subinstr(t, ",", " "))[
                     (substr(t, 1, 14) == "program define" ? 3 : 2)]
                names = names + " " + nm
            }
        }
        if (!inmata & t == "mata:") inmata = 1
        if (t == "end") {
            if (inmata) inmata = 0
            else if (inprog) {
                for (j = 1; j <= pad; j++) fput(fh, "di 1")
                inprog = 0
            }
        }
        fput(fh, L[i])
    }
    fclose(fh)
    st_local("tvl_prognames", strtrim(names))
    return(nprog)
}
end

* _tvl_synth: build and load a synthetic program of `nstmt' statements.
capture program drop _tvl_synth
program define _tvl_synth, rclass
    version 16.0
    args nstmt
    local path "`c(tmpdir)'/tvl_synth.ado"
    mata: _tvl_write_synth("`path'", `nstmt')
    capture program drop _tvl_synth_probe
    capture run "`path'"
    local rc = _rc
    capture program drop _tvl_synth_probe
    capture erase "`path'"
    return scalar rc = `rc'
end

* _tvl_splice: pad every program in `src' by `pad' statements and load it.
capture program drop _tvl_splice
program define _tvl_splice, rclass
    version 16.0
    args src pad
    local out "`c(tmpdir)'/tvl_splice.ado"
    mata: st_local("nprog", strofreal(_tvl_splice_file("`src'", "`out'", `pad')))
    foreach p of local tvl_prognames {
        capture program drop `p'
    }
    capture run "`out'"
    local rc = _rc
    capture erase "`out'"
    * Leave nothing padded behind: a padded tvexpose would print "1" a hundred
    * times inside every later call in this process.
    foreach p of local tvl_prognames {
        capture program drop `p'
    }
    return scalar rc = `rc'
    return scalar nprog = `nprog'
    return local prognames "`tvl_prognames'"
end

**# L1-L3: the ceiling is where we think it is
local ++test_count
_tvl_synth 3400
local rc3400 = r(rc)
local ok = (`rc3400' == 0)
_tvl_check `ok' "L1 a 3400-statement program loads" "rc=`rc3400'"

local ++test_count
_tvl_synth 3500
local rc3500 = r(rc)
local ok = (`rc3500' == 0)
_tvl_check `ok' "L2 a 3500-statement program loads (the documented ceiling)" ///
    "rc=`rc3500'"

local ++test_count
_tvl_synth 3501
local rc3501 = r(rc)
local ok = (`rc3501' == 1000)
_tvl_check `ok' "L3 a 3501-statement program fails to load with r(1000)" ///
    "rc=`rc3501'"

if `rc3500' != 0 | `rc3501' != 1000 {
    display as error "  NOTE: this Stata's per-program statement ceiling is not 3500."
    display as error "  The $LIMIT_MARGIN margin below is calibrated to it; recalibrate."
}

**# L4: the package directory resolved
local ados : dir "`pkg_dir'" files "*.ado"
local ados : list sort ados
local n_ados : word count `ados'
local ++test_count
local ok = (`n_ados' > 0)
_tvl_check `ok' "L4 the package directory contains .ado files" ///
    "found `n_ados' in `pkg_dir'"

**# L5+: load as distributed, then load with margin
foreach ado of local ados {
    local ++test_count
    _tvl_splice "`pkg_dir'/`ado'" 0
    local rc_plain = r(rc)
    local nprog = r(nprog)
    local ok = (`rc_plain' == 0)
    _tvl_check `ok' "L`test_count' `ado' loads as distributed" "rc=`rc_plain'"

    local ++test_count
    _tvl_splice "`pkg_dir'/`ado'" $LIMIT_MARGIN
    local rc_pad = r(rc)
    local ok = (`rc_pad' == 0)
    _tvl_check `ok' ///
        "L`test_count' `ado' keeps $LIMIT_MARGIN statements of headroom (`nprog' program(s))" ///
        "rc=`rc_pad'; within $LIMIT_MARGIN statements of the 3500 ceiling -- move a span into a helper"
}

**# Reported margin for the largest shipped program
* Bisect rather than assert: the number belongs in the log so a reviewer can
* watch the trend across releases. L5+ is what gates the suite.
local biggest ""
local biggest_bytes = 0
foreach ado of local ados {
    quietly checksum "`pkg_dir'/`ado'"
    if r(filelen) > `biggest_bytes' {
        local biggest_bytes = r(filelen)
        local biggest "`ado'"
    }
}
if "`biggest'" != "" {
    local lo = 0
    local hi = 3600
    while `hi' - `lo' > 1 {
        local mid = int((`lo' + `hi') / 2)
        _tvl_splice "`pkg_dir'/`biggest'" `mid'
        if r(rc) == 0  local lo = `mid'
        else           local hi = `mid'
    }
    display as text "  measured headroom: `biggest' accepts `lo' extra statements"
}

* _tvl_splice drops each padded definition as it goes, so nothing padded is
* live here. discard clears the Mata state the splicer compiled and forces the
* installed package to reload from PLUS for any later suite in this process.
capture program drop _tvl_synth_probe
discard

**# Summary
local pass_count = $TVL_PASS
local fail_count = $TVL_FAIL
display "RESULT: test_program_limits tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "program statement-limit failures:$TVL_FAILED"
    exit 1
}
