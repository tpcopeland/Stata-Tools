* test_logdoc_wrapped_output.do - wrapped output lines in text logs
* Found by the R tabtools demo parity check (2026-09-26/27). Written against
* logdoc 1.1.7 before any fix:
*   W1  an output line that the log wrapped at the linesize keeps its "> "
*       continuation in the same output fence, whether the continuation
*       starts with a letter ("> hheld ...") or not; it used to be moved to a
*       stray ```stata fence as if it continued a command
*   W2  the first part of a wrapped output line keeps its trailing blanks, so
*       the continuation lines up with it (a table row cut inside its padding
*       lost the blanks before "> |")
*   W3  guard: a wrapped command keeps its "> " continuation in its own
*       ```stata fence
*   W4  the closing log header is skipped whole when its path wraps
* Oracle: the text log Stata wrote (read back line by line), never the
* renderer's output.
* Run: stata-mp -b do test_logdoc_wrapped_output.do

version 16.0
clear all
capture log close _all

local qadir = regexr("`c(pwd)'", "/+$", "")
local pkgdir = regexr("`qadir'", "/qa/?$", "")
capture confirm file "`pkgdir'/logdoc.pkg"
if _rc {
    display as error "Could not locate logdoc package root from c(pwd)=`c(pwd)'"
    exit 601
}

capture ado uninstall logdoc
quietly net install logdoc, from("`pkgdir'") replace

local test_pass = 0
local test_fail = 0
local test_total = 0
local oldpwd "`c(pwd)'"
local outdir "`c(tmpdir)'/logdoc_wrap_tests"
capture mkdir "`outdir'"

mata:
string colvector _ldw_lines(string scalar path)
{
    real scalar fh
    string scalar line
    string colvector out

    out = J(0, 1, "")
    fh = fopen(path, "r")
    while ((line = fget(fh)) != J(0, 0, "")) {
        out = out \ subinstr(line, char(13), "")
    }
    fclose(fh)
    return(out)
}

// Index of the first line equal to s (0 when absent).
real scalar _ldw_find(string colvector v, string scalar s)
{
    real scalar i
    for (i = 1; i <= rows(v); i++) if (v[i] == s) return(i)
    return(0)
}

// Index of the first line starting with s (0 when absent).
real scalar _ldw_find_prefix(string colvector v, string scalar s)
{
    real scalar i
    for (i = 1; i <= rows(v); i++) {
        if (substr(v[i], 1, strlen(s)) == s) return(i)
    }
    return(0)
}

// Number of lines containing s.
real scalar _ldw_count(string colvector v, string scalar s)
{
    real scalar i, n
    n = 0
    for (i = 1; i <= rows(v); i++) if (strpos(v[i], s)) n++
    return(n)
}

// 1 when the log's wrapped line pair starting with `first' appears in the
// Markdown as the same two adjacent lines, byte for byte.
void _ldw_pair(string scalar logf, string scalar mdf, string scalar first,
    string scalar result)
{
    string colvector lg, md
    real scalar i, j

    lg = _ldw_lines(logf)
    md = _ldw_lines(mdf)
    i = _ldw_find_prefix(lg, first)
    st_local(result, "0")
    if (i == 0 | i == rows(lg)) return
    j = _ldw_find(md, lg[i])
    if (j == 0 | j == rows(md)) return
    if (md[j + 1] == lg[i + 1]) st_local(result, "1")
}
end

* The fixture log: linesize 80, text format. The file name is long so the
* log header's path wraps too.
local logname "wrap_output_regression_fixture_with_a_long_name_to_force_wrapping"
local logf "`outdir'/`logname'.log"
local mdf "`outdir'/`logname'.md"
quietly cd "`outdir'"
capture erase "`logf'"
capture erase "`mdf'"
local ls = c(linesize)
set linesize 80
log using "`logf'", replace text name(_ldw)
display "Note: counts below five are suppressed and a flag is shown; the rule is wit" "hheld for any variable carrying a suppressed count."
display "  | Observations" _dup(64) " " "|end"
display "path: /tmp/abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabc" "f/export/x.xlsx"
log close _ldw
set linesize `ls'
quietly logdoc using "`logf'", output("`mdf'") format(md) replace
quietly cd "`oldpwd'"

* W1: the letter-led continuation stays with its first part (and the log
* really has one, so the fixture exercises the defect).
local ++test_total
capture noisily {
    mata: st_local("n", strofreal(_ldw_count(_ldw_lines(st_local("logf")), ">  for any variable carrying")))
    assert `n' == 1
    mata: _ldw_pair(st_local("logf"), st_local("mdf"), "Note: counts below five", "ok")
    assert `ok' == 1
    mata: _ldw_pair(st_local("logf"), st_local("mdf"), "path: /tmp/abcdefghij", "ok2")
    assert `ok2' == 1
    * and no ```stata fence opens right before a wrapped output line
    mata: md = _ldw_lines(st_local("mdf")); ///
        k = _ldw_find_prefix(md, ">  for any variable"); ///
        st_local("stray", strofreal(k > 1 ? md[k - 1] == char(96) * 3 + "stata" : 1))
    assert `stray' == 0
}
if _rc == 0 {
    display as result "  PASS: W1 wrapped output continuations stay in the output fence"
    local ++test_pass
}
else {
    display as error "  FAIL: W1 wrapped output continuations (rc=`=_rc')"
    local ++test_fail
}

* W2: the padded first part keeps its trailing blanks.
local ++test_total
capture noisily {
    mata: lg = _ldw_lines(st_local("logf")); ///
        i = _ldw_find_prefix(lg, "  | Observations"); ///
        st_local("first", lg[i]); st_local("len", strofreal(strlen(lg[i])))
    assert `len' == 80
    mata: _ldw_pair(st_local("logf"), st_local("mdf"), "  | Observations", "ok")
    assert `ok' == 1
}
if _rc == 0 {
    display as result "  PASS: W2 wrapped output lines keep their trailing blanks"
    local ++test_pass
}
else {
    display as error "  FAIL: W2 trailing blanks before a continuation (rc=`=_rc')"
    local ++test_fail
}

* W3: guard: the wrapped command echo stays together in one stata fence.
local ++test_total
capture noisily {
    local needle `". display "Note: counts below five"'
    mata: md = _ldw_lines(st_local("mdf")); ///
        k = _ldw_find_prefix(md, st_local("needle")); ///
        st_local("k", strofreal(k)); ///
        st_local("fence", strofreal(k > 1 ? md[k - 1] == char(96) * 3 + "stata" : 0)); ///
        st_local("cont", strofreal(k > 0 & k < rows(md) ? substr(md[k + 1], 1, 2) == "> " : 0))
    assert `k' > 0
    assert `fence' == 1
    assert `cont' == 1
}
if _rc == 0 {
    display as result "  PASS: W3 wrapped commands keep their continuation in the stata fence"
    local ++test_pass
}
else {
    display as error "  FAIL: W3 wrapped command continuation (rc=`=_rc')"
    local ++test_fail
}

* W4: the closing header (log close) leaves nothing behind: after the last
* output line no line carries the wrapped log path.
local ++test_total
capture noisily {
    mata: md = _ldw_lines(st_local("mdf")); ///
        k = _ldw_find(md, "> rt/x.xlsx"); ///
        n = 0; ///
        for (i = k + 1; i <= rows(md); i++) n = n + (strpos(md[i], "force_wrapping") > 0); ///
        st_local("k", strofreal(k)); st_local("n", strofreal(n))
    display as text "  path lines after the last output: `n'"
    assert `k' > 0
    assert `n' == 0
}
if _rc == 0 {
    display as result "  PASS: W4 a wrapped closing log header is skipped whole"
    local ++test_pass
}
else {
    display as error "  FAIL: W4 closing log header (rc=`=_rc')"
    local ++test_fail
}

display as text ""
display as text "RESULT: test_logdoc_wrapped_output tests=`test_total' pass=`test_pass' fail=`test_fail'"
if `test_fail' > 0 exit 9
