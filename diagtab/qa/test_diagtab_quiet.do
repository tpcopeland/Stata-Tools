*! test_diagtab_quiet.do - first call must not echo Mata source to the console
*! Author: Timothy P Copeland, Karolinska Institutet

* guard: Q2 is expected green at pre-fix ref (control: the leak scan can see an echoed block)

clear all
set more off
set varabbrev off
version 17.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

* Sandboxed PLUS/PERSONAL: never touch the caller's installed packages
local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempfile token
local sandbox "`token'_quiet"
mkdir "`sandbox'"
mkdir "`sandbox'/plus"
mkdir "`sandbox'/personal"
sysdir set PLUS "`sandbox'/plus"
sysdir set PERSONAL "`sandbox'/personal"
quietly net install diagtab, from("`pkg_dir'") replace
discard

capture mata: mata drop _qt_scan()
mata:
// count the log lines that look like echoed Mata source; keep the first
void _qt_scan(string scalar path)
{
    string colvector L
    real scalar i, n
    string scalar first
    L = cat(path)
    n = 0
    first = ""
    for (i = 1; i <= rows(L); i++) {
        if (regexm(L[i], "mata \(type end to exit\)|^> *(real|string|void|class) |^: *(real|string|void|class) |_dt_strip_outer_quotes|_diagtab_counts_at_cutoffs")) {
            n++
            if (first == "") first = L[i]
        }
    }
    st_numscalar("r_leaks", n)
    st_local("leak_first", first)
}
end

capture program drop _qt_leaks
program define _qt_leaks, rclass
    args file
    mata: _qt_scan("`file'")
    return scalar n = scalar(r_leaks)
    return local first "`leak_first'"
end

**# Q1: first diagtab call after a cold start prints no Mata source
local ++test_count
capture noisily {
    clear
    capture program drop diagtab
    capture program drop _diagtab_helpers_ready
    capture mata: mata drop _dt_*() _diagtab_*()
    foreach pr in _diagtab_csv_write _diagtab_markdown_write _diagtab_xlsx_write {
        capture program drop `pr'
    }
    input byte test gold
    1 1
    1 1
    1 1
    1 0
    0 1
    0 0
    0 0
    0 0
    end

    quietly log using "`sandbox'/q1.log", text replace name(dtq)
    diagtab test gold, xlsx("`sandbox'/q1.xlsx") csv("`sandbox'/q1.csv") markdown("`sandbox'/q1.md")
    quietly log close dtq
    _qt_leaks "`sandbox'/q1.log"
    display "leaked lines: " r(n)
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: Q1 no Mata source echo on first call"
}
else {
    capture log close dtq
    local ++fail_count
    display as error "FAIL: Q1 Mata source echoed on first call"
}

**# Q2: the leak scan can see a real leak (it flags a noisily-compiled block)
local ++test_count
capture noisily {
    clear

    quietly log using "`sandbox'/q2.log", text replace name(dtq2)
    capture noisily {
mata:
real scalar _qt_probe_leak(real scalar x)
{
    return(x)
}
end
    }
    quietly log close dtq2
    _qt_leaks "`sandbox'/q2.log"
    assert r(n) > 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: Q2 leak scan detects an echoed Mata block"
}
else {
    capture log close dtq2
    local ++fail_count
    display as error "FAIL: Q2 leak scan is blind"
}

sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
quietly shell rm -rf "`sandbox'"
display "RESULT: test_diagtab_quiet tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 9
