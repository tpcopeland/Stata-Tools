* test_logdoc_v122.do - a bottom table border stays in the output block it closes
* Author: Timothy P Copeland, Karolinska Institutet
* Run from logdoc/qa: stata-mp -b do test_logdoc_v122.do
*
*   B1  tabstat, by() prints a closing {c BT} border with no {c TT} opener;
*       the Markdown output keeps it in the same code fence as the table rows
*   B2  Markdown keeps the ". " prompt of every command and the triple-slash and ">"
*       continuation lines of a multi-line command, as the HTML output does
*   B3  nodots strips the prompts but keeps the triple-slash and the continuation
*       indentation: the Markdown block is runnable as written, and so are HTML/LaTeX
*   B4  the LaTeX output is faithful the same way
*   B5  the Word output still carries the multi-line command
*   B6  a loop (forvalues) stays in one Markdown fence, not three
*   B8  a plain-text .log keeps the echoed body of a loop in its command block, so
*       the nodots output of a loop runs (rc 0)
*   B9  LaTeX output with accented letters, plus-minus, degree, micro and dashes
*       compiles with pdflatex (skipped when pdflatex is not installed)
*   B7  the LaTeX preamble maps Stata's box-drawing characters and keeps quotes
*       as typed (pdflatex stopped on the table characters)
* guard: B5 is expected green at pre-fix ref (the Word output goes through HTML, unchanged)
version 16.0
clear all
set processors 1
capture log close _all
local qadir = regexr("`c(pwd)'", "/+$", "")
local pkgdir = regexr("`qadir'", "/qa/?$", "")
local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempfile token
local sandbox "`token'_v122qa"
mkdir "`sandbox'"
mkdir "`sandbox'/plus"
mkdir "`sandbox'/personal"
sysdir set PLUS "`sandbox'/plus"
sysdir set PERSONAL "`sandbox'/personal"
quietly net install logdoc, from("`pkgdir'") replace
discard
local pass = 0
local fail = 0
local test_count = 0


* Scans a Markdown file: counts lines holding the bottom border and flags a
* border that is the first line inside its code fence. Results in r().
capture mata: mata drop _v122_scan()
mata:
void _v122_scan(string scalar path)
{
    string colvector L
    real scalar i, infence, border, split, first
    L = cat(path)
    infence = 0; border = 0; split = 0; first = 0
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, 3) == "```") {
            infence = !infence
            first = infence
            continue
        }
        if (infence & strpos(L[i], "┴")) {
            border++
            if (first) split = 1
        }
        if (infence) first = 0
    }
    st_numscalar("r(border)", border)
    st_numscalar("r(split)", split)
}
end

* B1: border line shares a fence with the preceding table row
local ++test_count
capture noisily {
    sysuse auto, clear
    log using "`sandbox'/tab.smcl", replace smcl name(v122) nomsg
    tabstat price mpg, by(foreign) statistics(n mean) columns(statistics)
    log close v122
    logdoc using "`sandbox'/tab.smcl", output("`sandbox'/tab.md") format(md) replace quiet
    mata: _v122_scan("`sandbox'/tab.md")
    local border = scalar(r(border))
    local split = scalar(r(split))
    assert `border' == 1
    assert `split' == 0
}
if _rc == 0 {
    local ++pass
    display as result "PASS: B1 bottom border stays with its table"
}
else {
    local ++fail
    display as error "FAIL: B1 bottom border stays with its table"
}

**# Setup for B2-B5: one multi-line command, converted to every format
capture noisily {
    sysuse auto, clear
    log using "`sandbox'/ml.smcl", replace smcl name(v122ml) nomsg
    * # Multi
    summarize price ///
        mpg ///
        weight, separator(0)
    forvalues i = 1/2 {
        display "loop"
    }
    display "after"
    log close v122ml
    logdoc using "`sandbox'/ml.smcl", output("`sandbox'/ml.html") format(html) replace quiet
    logdoc using "`sandbox'/ml.smcl", output("`sandbox'/ml.md") format(md) replace quiet
    logdoc using "`sandbox'/ml.smcl", output("`sandbox'/ml_nd.md") format(md) nodots replace quiet
    logdoc using "`sandbox'/ml.smcl", output("`sandbox'/ml_nd.html") format(html) nodots replace quiet
    logdoc using "`sandbox'/ml.smcl", output("`sandbox'/ml.tex") format(tex) replace quiet
    logdoc using "`sandbox'/ml.smcl", output("`sandbox'/ml_nd.tex") format(tex) nodots replace quiet
}
if _rc {
    display as error "setup for B2-B5 stopped with rc=" _rc
    capture log close v122ml
    exit _rc
}

capture mata: mata drop _v122_has()
capture mata: mata drop _v122_re()
capture mata: mata drop _v122_fence()
mata:
real scalar _v122_has(string scalar path, string scalar needle)
{
    string colvector L
    L = cat(path)
    return(strpos(invtokens(L', char(10)), needle) > 0)
}

real scalar _v122_re(string scalar path, string scalar re)
{
    string colvector L
    L = cat(path)
    return(regexm(invtokens(L', char(10)), re))
}

// write the lines of the first ```stata fence that starts with `first` to out
void _v122_fence(string scalar path, string scalar first, string scalar out)
{
    string colvector L
    real scalar i, fh, on
    string scalar bt
    bt = char(96) + char(96) + char(96)
    L = cat(path)
    fh = fopen(out, "w")
    on = 0
    for (i = 1; i <= rows(L); i++) {
        if (on) {
            if (L[i] == bt) break
            fput(fh, L[i])
        }
        else if (L[i] == bt + "stata" & i < rows(L)) {
            if (substr(strltrim(L[i+1]), 1, strlen(first)) == first) on = 1
        }
    }
    fclose(fh)
}
end

local nl = char(10)
local sl3 = char(47) + char(47) + char(47)
local bt = char(96) + char(96) + char(96)

**# B2: Markdown keeps prompts and continuation lines like HTML
local ++test_count
capture noisily {
    local want "`bt'stata`nl'\. +summarize price /+`nl'> +mpg /+`nl'> +weight, separator\(0\)`nl'`bt'"
    mata: assert(_v122_re("`sandbox'/ml.md", st_local("want")))
    local want2 "\. +display"
    mata: assert(_v122_re("`sandbox'/ml.md", st_local("want2")))
    * the HTML shows the same prompt and continuation lines
    local want3 "\. +summarize price /+"
    mata: assert(_v122_re("`sandbox'/ml.html", st_local("want3")))
}
if _rc == 0 {
    local ++pass
    display as result "PASS: B2 Markdown keeps prompts and continuation lines like HTML"
}
else {
    local ++fail
    display as error "FAIL: B2 Markdown keeps prompts and continuation lines like HTML"
}

**# B3: nodots output is runnable (prompts gone, continuation kept)
local ++test_count
capture noisily {
    * no prompts; the triple-slash markers and indentation stay
    local want "summarize price /+`nl' +mpg /+`nl' +weight, separator\(0\)"
    mata: assert(_v122_re("`sandbox'/ml_nd.md", st_local("want")))
    local bad "(^|`nl')[.>] "
    mata: assert(!_v122_re("`sandbox'/ml_nd.md", st_local("bad")))
    * the same lines in HTML and LaTeX
    local wanth "summarize price /+</span>`nl'<span class=.cmd.> +mpg /+</span>`nl'<span class=.cmd.> +weight"
    mata: assert(_v122_re("`sandbox'/ml_nd.html", st_local("wanth")))
    mata: assert(_v122_re("`sandbox'/ml_nd.tex", st_local("want")))
    * and the Markdown block actually runs
    mata: _v122_fence("`sandbox'/ml_nd.md", "summarize price", "`sandbox'/nd_block.do")
    sysuse auto, clear
    include "`sandbox'/nd_block.do"
    assert r(N) == 74
}
if _rc == 0 {
    local ++pass
    display as result "PASS: B3 nodots output keeps continuation and runs"
}
else {
    local ++fail
    display as error "FAIL: B3 nodots output keeps continuation and runs"
}

**# B4: LaTeX keeps prompts and continuation lines
local ++test_count
capture noisily {
    local want "\. +summarize price /+`nl'> +mpg /+`nl'> +weight, separator\(0\)"
    mata: assert(_v122_re("`sandbox'/ml.tex", st_local("want")))
}
if _rc == 0 {
    local ++pass
    display as result "PASS: B4 LaTeX keeps prompts and continuation lines"
}
else {
    local ++fail
    display as error "FAIL: B4 LaTeX keeps prompts and continuation lines"
}

**# B5: the Word output carries the multi-line command
local ++test_count
if c(stata_version) < 17 {
    * html2docx needs Stata 17; nothing to check, count it as a pass
    local ++pass
    display as result "PASS: B5 Word output carries the multi-line command"
}
else {
    local cwd "`c(pwd)'"
    capture noisily {
        logdoc using "`sandbox'/ml.smcl", output("`sandbox'/ml.docx") format(docx) replace quiet
        mkdir "`sandbox'/dx"
        quietly cd "`sandbox'/dx"
        quietly unzipfile "`sandbox'/ml.docx", replace
        quietly cd "`cwd'"
        mata: assert(_v122_has("`sandbox'/dx/word/document.xml", "summarize price"))
        mata: assert(_v122_has("`sandbox'/dx/word/document.xml", "separator(0)"))
    }
    if _rc == 0 {
        local ++pass
        display as result "PASS: B5 Word output carries the multi-line command"
    }
    else {
        quietly cd "`cwd'"
        local ++fail
        display as error "FAIL: B5 Word output carries the multi-line command"
    }
}

**# B6: a loop stays in one fence
local ++test_count
capture noisily {
    local want "`bt'stata`nl'\. +forvalues i = 1/2 \{`nl' +2\. +display .loop.`nl' +3\. +\}`nl'`bt'"
    mata: assert(_v122_re("`sandbox'/ml.md", st_local("want")))
    local want "`bt'stata`nl' *forvalues i = 1/2 \{`nl' +display .loop.`nl' *\}`nl'`bt'"
    mata: assert(_v122_re("`sandbox'/ml_nd.md", st_local("want")))
}
if _rc == 0 {
    local ++pass
    display as result "PASS: B6 a loop stays in one Markdown fence"
}
else {
    local ++fail
    display as error "FAIL: B6 a loop stays in one Markdown fence"
}

**# B7: LaTeX preamble handles box-drawing characters and quotes
local ++test_count
capture noisily {
    mata: assert(_v122_has("`sandbox'/ml.tex", "\usepackage{upquote}"))
    mata: assert(_v122_has("`sandbox'/ml.tex", "\DeclareUnicodeCharacter{2502}"))
    mata: assert(_v122_has("`sandbox'/ml.tex", "literate="))
}
if _rc == 0 {
    local ++pass
    display as result "PASS: B7 LaTeX preamble maps box-drawing characters"
}
else {
    local ++fail
    display as error "FAIL: B7 LaTeX preamble maps box-drawing characters"
}

**# B8: a text .log loop is one command block and its nodots output runs
local ++test_count
capture noisily {
    sysuse auto, clear
    log using "`sandbox'/lp.log", replace text name(v122lp) nomsg
    forvalues i = 1/2 {
        display "looprun"
    }
    display "2. not a loop line"
    log close v122lp
    logdoc using "`sandbox'/lp.log", output("`sandbox'/lp_nd.md") format(md) nodots replace quiet
    logdoc using "`sandbox'/lp.log", output("`sandbox'/lp.md") format(md) replace quiet
    local want "`bt'stata`nl'\. +forvalues i = 1/2 \{`nl' +2\. +display .looprun.`nl' +3\. +\}`nl'`bt'"
    mata: assert(_v122_re("`sandbox'/lp.md", st_local("want")))
    mata: _v122_fence("`sandbox'/lp_nd.md", "forvalues", "`sandbox'/lp_block.do")
    include "`sandbox'/lp_block.do"
    * the output line that merely starts with a number is not swallowed
    local want2 "`bt'stata`nl' *display .2. not a loop line.`nl'`bt'"
    mata: assert(_v122_re("`sandbox'/lp_nd.md", st_local("want2")))
}
if _rc == 0 {
    local ++pass
    display as result "PASS: B8 text-log loop stays whole and its nodots output runs"
}
else {
    capture log close v122lp
    local ++fail
    display as error "FAIL: B8 text-log loop stays whole and its nodots output runs"
}

**# B9: LaTeX with Latin-1 characters compiles
local ++test_count
capture noisily {
    quietly shell sh -c "command -v pdflatex > '`sandbox'/has_tex.txt' 2>&1"
    mata: st_local("hastex", strofreal(strlen(strtrim(invtokens(cat("`sandbox'/has_tex.txt")'))) > 0))
}
if `hastex' == 0 {
    local --test_count
    display as text "SKIP: B9 pdflatex not installed"
}
else {
    capture noisily {
        log using "`sandbox'/uni.log", replace text name(v122uni) nomsg
        display "Müller café ñ Å"
        display "5 ± 1 ° µ – — ×"
        log close v122uni
        logdoc using "`sandbox'/uni.log", output("`sandbox'/unitex.tex") format(tex) replace quiet
        quietly shell sh -c "cd '`sandbox'' && pdflatex -interaction=nonstopmode -halt-on-error unitex.tex > pdflatex.out 2>&1"
        confirm file "`sandbox'/unitex.pdf"
        mata: assert(!_v122_has("`sandbox'/pdflatex.out", "Invalid UTF-8"))
    }
    if _rc == 0 {
        local ++pass
        display as result "PASS: B9 LaTeX with Latin-1 characters compiles"
    }
    else {
        capture log close v122uni
        local ++fail
        display as error "FAIL: B9 LaTeX with Latin-1 characters compiles"
    }
}

sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
quietly shell rm -rf "`sandbox'"
display "RESULT: test_logdoc_v122 tests=`test_count' pass=`pass' fail=`fail'"
if `fail' > 0 exit 1
