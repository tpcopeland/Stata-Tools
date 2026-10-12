* test_logdoc_v121.do - relative graph paths fall back to the working directory
* Author: Timothy P Copeland, Karolinska Institutet
* Run from logdoc/qa: stata-mp -b do test_logdoc_v121.do
*
*   T1  a log in logs/ embeds a graph exported to figs/ from the project root
*       (HTML: data URI present, no graph-missing div, r(nwarnings) == 0)
*   T2  the input file's directory still wins when both locations hold the
*       same relative path: the embedded bytes are the input-relative file's
*   T3  a graph in neither location is still reported missing
*   T4  Markdown links the cwd-resolved graph relative to the output file
version 16.0
clear all
set processors 1
capture log close _all
local qadir = regexr("`c(pwd)'", "/+$", "")
local pkgdir = regexr("`qadir'", "/qa/?$", "")
local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempfile token
local sandbox "`token'_v121qa"
mkdir "`sandbox'"
mkdir "`sandbox'/plus"
mkdir "`sandbox'/personal"
sysdir set PLUS "`sandbox'/plus"
sysdir set PERSONAL "`sandbox'/personal"
quietly net install logdoc, from("`pkgdir'") replace
discard
quietly logdoc_py
local python "`r(python)'"
local pass = 0
local fail = 0
local test_count = 0

* Counts lines of a text file containing a literal needle.
capture mata: mata drop _v121_count()
mata:
real scalar _v121_count(string scalar path, string scalar needle)
{
    return(sum(strpos(cat(path), needle) :> 0))
}
end

* 1 if the base64 encoding of image `img' appears in text file `doc'.
capture program drop _v121_embeds
program define _v121_embeds, rclass
    args python img doc
    tempfile out
    quietly shell "`python'" -c "import base64,sys; b=base64.b64encode(open(sys.argv[1],'rb').read()).decode(); print(1 if b in open(sys.argv[2],encoding='utf-8').read() else 0)" "`img'" "`doc'" > "`out'" 2>&1
    tempname fh
    file open `fh' using "`out'", read text
    file read `fh' line
    file close `fh'
    return local found = strtrim("`line'")
end

* Project layout: <proj>/logs/analysis.smcl, graphs exported from <proj>.
local proj "`sandbox'/proj"
mkdir "`proj'"
mkdir "`proj'/logs"
mkdir "`proj'/figs"
mkdir "`proj'/logs/figs"
local orig_pwd "`c(pwd)'"
quietly cd "`proj'"
sysuse auto, clear
log using "logs/analysis.smcl", replace smcl name(v121) nomsg
scatter price mpg
graph export "figs/scatter.png", replace width(400)
scatter weight length
graph export "figs/nowhere.png", replace width(400)
log close v121
capture graph close _all
* A different image under the input directory for T2 only (made later), and
* remove nowhere.png so T3 has a graph in neither location.
erase "figs/nowhere.png"

**# T1: cwd fallback embeds a project-root-relative export
local ++test_count
capture noisily {
    logdoc using "logs/analysis.smcl", output("logs/analysis.html") replace quiet
    assert r(ngraphs) == 2
    local html "`proj'/logs/analysis.html"
    mata: st_local("n_img", strofreal(_v121_count(st_local("html"), "data:image/png")))
    assert `n_img' == 1
    _v121_embeds "`python'" "`proj'/figs/scatter.png" "`html'"
    assert "`r(found)'" == "1"
}
if _rc == 0 {
    display as result "V121-T1 PASS: logs/ input embeds figs/ export via working directory"
    local ++pass
}
else {
    display as error "V121-T1 FAIL: cwd-relative graph not embedded (rc=`=_rc')"
    local ++fail
}

**# T3: a graph in neither location is still reported missing
local ++test_count
capture noisily {
    local html "`proj'/logs/analysis.html"
    mata: st_local("n_miss", strofreal(_v121_count(st_local("html"), "Graph file not found: figs/nowhere.png")))
    assert `n_miss' == 1
    mata: st_local("n_miss_s", strofreal(_v121_count(st_local("html"), "Graph file not found: figs/scatter.png")))
    assert `n_miss_s' == 0
    logdoc using "logs/analysis.smcl", output("logs/analysis.html") replace quiet
    assert r(nwarnings) == 1
}
if _rc == 0 {
    display as result "V121-T3 PASS: unresolvable graph still reported missing"
    local ++pass
}
else {
    display as error "V121-T3 FAIL: missing-graph reporting changed (rc=`=_rc')"
    local ++fail
}

**# T4: Markdown links the cwd-resolved graph relative to the output file
local ++test_count
capture noisily {
    logdoc using "logs/analysis.smcl", output("logs/analysis.md") format(md) replace quiet
    local md "`proj'/logs/analysis.md"
    mata: st_local("n_link", strofreal(_v121_count(st_local("md"), "](../figs/scatter.png)")))
    assert `n_link' == 1
}
if _rc == 0 {
    display as result "V121-T4 PASS: Markdown link is ../figs/scatter.png"
    local ++pass
}
else {
    display as error "V121-T4 FAIL: Markdown graph link wrong (rc=`=_rc')"
    local ++fail
}

**# T2: the input file's directory takes precedence over the working directory
local ++test_count
capture noisily {
    sysuse auto, clear
    histogram mpg
    graph export "logs/figs/scatter.png", replace width(300)
    capture graph close _all
    logdoc using "logs/analysis.smcl", output("logs/analysis.html") replace quiet
    local html "`proj'/logs/analysis.html"
    _v121_embeds "`python'" "`proj'/logs/figs/scatter.png" "`html'"
    assert "`r(found)'" == "1"
    _v121_embeds "`python'" "`proj'/figs/scatter.png" "`html'"
    assert "`r(found)'" == "0"
}
if _rc == 0 {
    display as result "V121-T2 PASS: input-relative graph wins over working directory"
    local ++pass
}
else {
    display as error "V121-T2 FAIL: resolution order wrong (rc=`=_rc')"
    local ++fail
}

quietly cd "`orig_pwd'"
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
display as result "v1.2.1 Regression Test Results: `pass'/`test_count' passed, `fail' failed"
display "RESULT: test_logdoc_v121 tests=`test_count' pass=`pass' fail=`fail'"
if `fail' > 0 exit 1
