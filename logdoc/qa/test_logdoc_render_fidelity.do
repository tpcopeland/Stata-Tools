* test_logdoc_render_fidelity.do - rendered text matches Stata's own SMCL rendering
* Written against logdoc 1.1.9 (renderer review, 2026-10-12):
*   RF1  default HTML of real estimation output (regress with a factor
*        variable, logit, margins, mean, tabulate, summarize, table,
*        estimates table) equals Stata's translate smcl2log text line for
*        line; {col N} used to add a space at or past column N, align
*        widths counted HTML entities, and separators were padded
*   RF2  the same log as Markdown: the output fences equal the oracle
*   RF3  inline directives keep their text ({cmd:} {hi:} {ul:} {err:}
*        {browse "url":} {stata "cmd":} {dup N:}) in HTML and Markdown, and
*        the echoed command keeps its braces; fences carry no ** markers
*   RF4  user output "name: John Smith" / "log: x" is kept while the real
*        log open/close banner is still dropped
*   RF5  a plain-text .log keeps literal braces ("keep {braces} here",
*        JSON-like lines)
*   RF6  a failed graph export naming a non-image file is never embedded
*        (it used to base64 the text file into the page)
*   RF7  guard: a real PNG graph export is still embedded
*   RF8  a {c TT} line with no {c BT} does not swallow the next command
* Round 2 (independent review of the round-1 renderer):
*   RF9  {rm} is consumed, so Stata's "(file ... not found)" note matches
*        the oracle; RF10 {bf}/{sf} inside {err} keep the error colour;
*   RF11 a BOM, a missing {smcl} header or leading blank lines still mean
*        SMCL; RF12 log off/on banners are dropped; RF13 hostile {dup}/
*        {hline}/{space} counts are bounded; RF14 {p2colset} does not leak
*        across combined sources; RF15 a new paragraph directive starts a
*        new paragraph; RF16 ``` / \end{lstlisting} / "> " output stays
*        content and spaced graph paths use <...> links; RF17 gr export,
*        as() without an extension and loop-body exports are embedded;
*        RF18 tables escapes P>|t| once; RF19 {help "a b"} keeps its text
* Round 3: RF20 a text log's command echo wrapped at linesize 60 or 120
*        keeps its "> " lines with the command (width from the log itself)
* Oracle: Stata's translate, translator(smcl2log) linesize(255), never the
* renderer's output.  Comparison drops blank lines and trailing blanks and
* maps box-drawing characters to the ASCII Stata writes in text logs.
* Run: stata-mp -b do test_logdoc_render_fidelity.do

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
local outdir "`c(tmpdir)'/logdoc_fidelity_tests"
capture mkdir "`outdir'"

mata:
string colvector _ldf_split(string scalar s)
{
    real scalar p
    string colvector out

    out = J(0, 1, "")
    s = subinstr(s, char(13), "")
    while ((p = strpos(s, char(10))) > 0) {
        out = out \ substr(s, 1, p - 1)
        s = substr(s, p + 1, .)
    }
    if (s != "") out = out \ s
    return(out)
}

string colvector _ldf_lines(string scalar path)
{
    real scalar i
    string colvector v

    v = cat(path)
    for (i = 1; i <= rows(v); i++) v[i] = subinstr(v[i], char(13), "")
    return(v)
}

string scalar _ldf_text(string scalar path)
{
    real scalar i
    string colvector v
    string scalar s

    v = cat(path)
    s = ""
    for (i = 1; i <= rows(v); i++) s = s + v[i] + char(10)
    return(s)
}

// Box-drawing characters as Stata's text log writes them; trailing blanks
// dropped.
string scalar _ldf_norm(string scalar s)
{
    s = subinstr(s, "─", "-")
    s = subinstr(s, "│", "|")
    s = subinstr(s, "┼", "+")
    s = subinstr(s, "┬", "-")
    s = subinstr(s, "┴", "-")
    s = subinstr(s, "├", "|")
    s = subinstr(s, "┤", "|")
    s = subinstr(s, "┌", "+")
    s = subinstr(s, "┐", "+")
    s = subinstr(s, "└", "+")
    s = subinstr(s, "┘", "+")
    return(strrtrim(s))
}

string colvector _ldf_nonblank(string colvector v)
{
    real scalar i
    string colvector out

    out = J(0, 1, "")
    for (i = 1; i <= rows(v); i++) {
        if (strtrim(v[i]) != "") out = out \ v[i]
    }
    return(out)
}

// Oracle text: nonblank lines, minus the ". log close" echo the renderer
// drops by design; dropcmd also removes ". " command echoes (Markdown puts
// commands in their own fences).
string colvector _ldf_oracle(string scalar path, real scalar dropcmd)
{
    real scalar i
    string colvector v, out
    string scalar l

    v = _ldf_lines(path)
    out = J(0, 1, "")
    for (i = 1; i <= rows(v); i++) {
        l = _ldf_norm(v[i])
        if (l == "") continue
        if (substr(l, 1, 11) == ". log close") continue
        if (dropcmd & substr(l, 1, 2) == ". ") continue
        out = out \ l
    }
    return(out)
}

// Text of every <pre class="stata-log"> in a default HTML page, tags
// removed and entities decoded.
string colvector _ldf_html(string scalar path)
{
    string scalar s, body, open
    real scalar p, q
    string colvector v
    real scalar i

    s = _ldf_text(path)
    open = `"<pre class="stata-log">"'
    body = ""
    while ((p = strpos(s, open)) > 0) {
        s = substr(s, p + strlen(open), .)
        q = strpos(s, "</pre>")
        body = body + substr(s, 1, q - 1) + char(10)
        s = substr(s, q + 6, .)
    }
    body = ustrregexra(body, "<[^>]+>", "")
    body = subinstr(body, "&lt;", "<")
    body = subinstr(body, "&gt;", ">")
    body = subinstr(body, "&quot;", `"""')
    body = subinstr(body, "&#x27;", "'")
    body = subinstr(body, "&amp;", "&")
    v = _ldf_split(body)
    for (i = 1; i <= rows(v); i++) v[i] = _ldf_norm(v[i])
    return(_ldf_nonblank(v))
}

// Lines inside plain fences of a Markdown file (stata fences skipped when
// want_cmd is 0; only stata fence lines when it is 1), plus the text of
// "> **Error:** " lines.  A fence closes only on the same backtick run that
// opened it, so a ``` output line inside a ```` fence stays content.
string colvector _ldf_mdpart(string scalar path, real scalar want_cmd)
{
    string colvector v, out
    string scalar fence
    real scalar i, inf, cmd, k

    v = _ldf_lines(path)
    out = J(0, 1, "")
    inf = 0
    cmd = 0
    fence = ""
    for (i = 1; i <= rows(v); i++) {
        if (!inf & substr(v[i], 1, 3) == "```") {
            k = 1
            while (substr(v[i], k + 1, 1) == "`") k++
            fence = substr(v[i], 1, k)
            cmd = (strtrim(substr(v[i], k + 1, .)) == "stata")
            inf = 1
            continue
        }
        if (inf & strtrim(v[i]) == fence) {
            inf = 0
            continue
        }
        if (inf & cmd == want_cmd) out = out \ _ldf_norm(v[i])
        else if (!inf & !want_cmd & substr(v[i], 1, 13) == "> **Error:** ") {
            out = out \ _ldf_norm(substr(v[i], 14, .))
        }
    }
    return(_ldf_nonblank(out))
}

string colvector _ldf_md(string scalar path)
{
    return(_ldf_mdpart(path, 0))
}

// Number of positions where a and b differ (plus any length difference);
// shows the first few differences.
real scalar _ldf_diff(string colvector a, string colvector b)
{
    real scalar i, n, shown

    n = abs(rows(a) - rows(b))
    shown = 0
    for (i = 1; i <= min((rows(a), rows(b))); i++) {
        if (a[i] != b[i]) {
            n++
            if (shown < 6) {
                printf("    line %g oracle  : [%s]\n", i, a[i])
                printf("    line %g rendered: [%s]\n", i, b[i])
                shown++
            }
        }
    }
    printf("    oracle lines %g, rendered lines %g, differing %g\n",
        rows(a), rows(b), n)
    return(n)
}

real scalar _ldf_has(string colvector v, string scalar s)
{
    real scalar i
    for (i = 1; i <= rows(v); i++) if (v[i] == s) return(1)
    return(0)
}

real scalar _ldf_count(string scalar path, string scalar s)
{
    string scalar t
    real scalar n, p

    t = _ldf_text(path)
    n = 0
    while ((p = strpos(t, s)) > 0) {
        n++
        t = substr(t, p + strlen(s), .)
    }
    return(n)
}
end

quietly cd "`outdir'"

**# Fixture 1: real estimation output, oracle by translate
local est "`outdir'/rf_est"
capture erase "`est'.smcl"
capture erase "`est'_oracle.txt"
local ls = c(linesize)
set linesize 255
sysuse auto, clear
log using "`est'.smcl", smcl replace nomsg name(_ldf)
regress price mpg weight i.foreign
logit foreign mpg weight
margins, dydx(mpg)
mean price mpg
tabulate rep78 foreign
summarize price mpg weight
version 17: table foreign rep78, statistic(mean price)
quietly regress price mpg
estimates store rf_m1
quietly regress price mpg weight
estimates store rf_m2
estimates table rf_m1 rf_m2, se
display as text "ABCDEFGHIJ{col 5}X|"
display as text "ABC{col 5}X|"
display as text "{lalign 6:a>b}|{ralign 6:a&b}|"
capture noisily regress price rf_nosuchvar
log close _ldf
set linesize `ls'
estimates drop rf_m1 rf_m2
translate "`est'.smcl" "`est'_oracle.txt", translator(smcl2log) linesize(255) replace
quietly logdoc using "`est'.smcl", output("`est'.html") replace
quietly logdoc using "`est'.smcl", output("`est'.md") format(md) replace

* RF1: HTML transcript equals the oracle.
local ++test_total
capture noisily {
    mata: o = _ldf_oracle(st_local("est") + "_oracle.txt", 0); ///
        st_local("no", strofreal(rows(o))); ///
        st_local("coef", strofreal(_ldf_has(o, "       price | Coefficient  Std. err.      t    P>|t|     [95% conf. interval]"))); ///
        st_local("nd", strofreal(_ldf_diff(o, _ldf_html(st_local("est") + ".html"))))
    * the oracle really holds the estimation tables
    assert `no' > 80
    assert `coef' == 1
    assert `nd' == 0
}
if _rc == 0 {
    display as result "  PASS: RF1 HTML of estimation output equals translate smcl2log"
    local ++test_pass
}
else {
    display as error "  FAIL: RF1 HTML vs translate oracle (rc=`=_rc')"
    local ++test_fail
}

* RF2: Markdown output fences equal the oracle.
local ++test_total
capture noisily {
    mata: o = _ldf_oracle(st_local("est") + "_oracle.txt", 1); ///
        st_local("nd", strofreal(_ldf_diff(o, _ldf_md(st_local("est") + ".md"))))
    assert `nd' == 0
}
if _rc == 0 {
    display as result "  PASS: RF2 Markdown output fences equal translate smcl2log"
    local ++test_pass
}
else {
    display as error "  FAIL: RF2 Markdown vs translate oracle (rc=`=_rc')"
    local ++test_fail
}

**# Fixture 2: inline directives, metadata-looking output, TT without BT
local tag "`outdir'/rf_tags"
capture erase "`tag'.smcl"
set linesize 255
log using "`tag'.smcl", smcl replace name(_ldf)
display `"{cmd:CMDTEXT} and {hi:HITEXT} and {ul:ULTEXT} {err:ERRTEXT} {browse "http://x.org":BROWSETEXT} {stata "di 1":STATATEXT} {dup 3:x} {bf:BFTEXT}"'
display "name: John Smith"
display "log: x"
display as text "{hline 3}{c TT}{hline 3}"
display "AFTER_TT"
log close _ldf
set linesize `ls'
translate "`tag'.smcl" "`tag'_oracle.txt", translator(smcl2log) linesize(255) replace
quietly logdoc using "`tag'.smcl", output("`tag'.html") replace
quietly logdoc using "`tag'.smcl", output("`tag'.md") format(md) replace
local tagline "CMDTEXT and HITEXT and ULTEXT ERRTEXT BROWSETEXT STATATEXT xxx BFTEXT"

* RF3: directive text survives in both formats; echo keeps its braces.
local ++test_total
capture noisily {
    mata: st_local("o", strofreal(_ldf_has(_ldf_oracle(st_local("tag") + "_oracle.txt", 0), st_local("tagline")))); ///
        st_local("h", strofreal(_ldf_has(_ldf_html(st_local("tag") + ".html"), st_local("tagline")))); ///
        st_local("m", strofreal(_ldf_has(_ldf_md(st_local("tag") + ".md"), st_local("tagline")))); ///
        st_local("err", strofreal(_ldf_count(st_local("tag") + ".html", `"<span class="err">ERRTEXT</span>"'))); ///
        st_local("echo", strofreal(_ldf_count(st_local("tag") + ".md", "{cmd:CMDTEXT} and {hi:HITEXT}"))); ///
        st_local("stars", strofreal(_ldf_count(st_local("tag") + ".md", "**")))
    assert `o' == 1
    assert `h' == 1
    assert `m' == 1
    assert `err' == 1
    assert `echo' == 1
    assert `stars' == 0
}
if _rc == 0 {
    display as result "  PASS: RF3 inline directive text and echoed braces survive"
    local ++test_pass
}
else {
    display as error "  FAIL: RF3 inline directive text (rc=`=_rc')"
    local ++test_fail
}

* RF4: "name:"/"log:" output kept; the real log banner dropped.
local ++test_total
capture noisily {
    mata: md = _ldf_md(st_local("tag") + ".md"); ///
        st_local("name", strofreal(_ldf_has(md, "name: John Smith"))); ///
        st_local("logx", strofreal(_ldf_has(md, "log: x"))); ///
        st_local("hname", strofreal(_ldf_has(_ldf_html(st_local("tag") + ".html"), "name: John Smith"))); ///
        st_local("banner", strofreal(_ldf_count(st_local("tag") + ".md", "log type:") + _ldf_count(st_local("tag") + ".html", "log type:")))
    assert `name' == 1
    assert `logx' == 1
    assert `hname' == 1
    assert `banner' == 0
}
if _rc == 0 {
    display as result "  PASS: RF4 metadata-looking output kept, log banner dropped"
    local ++test_pass
}
else {
    display as error "  FAIL: RF4 metadata-looking output (rc=`=_rc')"
    local ++test_fail
}

* RF8: the next command after an unclosed {c TT} keeps its own fence.
local ++test_total
capture noisily {
    mata: v = _ldf_lines(st_local("tag") + ".md"); ///
        k = 0; for (i = 2; i <= rows(v); i++) if (v[i] == `"display "AFTER_TT""' & v[i - 1] == "```stata") k = i; ///
        st_local("k", strofreal(k)); ///
        st_local("out", strofreal(_ldf_has(_ldf_md(st_local("tag") + ".md"), "AFTER_TT"))); ///
        st_local("rule", strofreal(_ldf_has(_ldf_md(st_local("tag") + ".md"), "-------")))
    assert `k' > 0
    assert `out' == 1
    assert `rule' == 1
}
if _rc == 0 {
    display as result "  PASS: RF8 an unclosed table top does not swallow the next command"
    local ++test_pass
}
else {
    display as error "  FAIL: RF8 unclosed table top (rc=`=_rc')"
    local ++test_fail
}

**# Fixture 3: plain-text log with literal braces
local plain "`outdir'/rf_plain"
capture erase "`plain'.log"
log using "`plain'.log", text replace name(_ldf)
display "keep {braces} here"
display `"{"a": 1}"'
display "name: John Smith"
log close _ldf
quietly logdoc using "`plain'.log", output("`plain'.md") format(md) replace
quietly logdoc using "`plain'.log", output("`plain'.html") replace

* RF5: literal braces survive a .log input.
local ++test_total
capture noisily {
    mata: md = _ldf_md(st_local("plain") + ".md"); ///
        st_local("b", strofreal(_ldf_has(md, "keep {braces} here"))); ///
        st_local("j", strofreal(_ldf_has(md, `"{"a": 1}"'))); ///
        st_local("n", strofreal(_ldf_has(md, "name: John Smith"))); ///
        st_local("hb", strofreal(_ldf_has(_ldf_html(st_local("plain") + ".html"), "keep {braces} here"))); ///
        st_local("banner", strofreal(_ldf_count(st_local("plain") + ".md", "log type:")))
    assert `b' == 1
    assert `j' == 1
    assert `n' == 1
    assert `hb' == 1
    assert `banner' == 0
}
if _rc == 0 {
    display as result "  PASS: RF5 plain-text log keeps literal braces"
    local ++test_pass
}
else {
    display as error "  FAIL: RF5 plain-text log braces (rc=`=_rc')"
    local ++test_fail
}

**# Fixture 4: graph exports
local secret "`outdir'/rf_secret.txt"
tempname fh
file open `fh' using "`secret'", write text replace
file write `fh' "RF_TOPSECRET_PAYLOAD" _n
file close `fh'
local gx "`outdir'/rf_graph_bad"
capture erase "`gx'.smcl"
sysuse auto, clear
quietly scatter price mpg
log using "`gx'.smcl", smcl replace nomsg name(_ldf)
capture noisily graph export "rf_secret.txt"
display "AFTER_BAD_EXPORT"
log close _ldf
quietly logdoc using "`gx'.smcl", output("`gx'.html") replace
local bad_ngraphs = r(ngraphs)
quietly logdoc using "`gx'.smcl", output("`gx'.md") format(md) replace

* RF6: the failed non-image export is not embedded or linked.
local ++test_total
capture noisily {
    mata: st_local("b64", strofreal(_ldf_count(st_local("gx") + ".html", ";base64,"))); ///
        st_local("missing", strofreal(_ldf_count(st_local("gx") + ".html", `"class="graph-missing""'))); ///
        st_local("mdlink", strofreal(_ldf_count(st_local("gx") + ".md", "](")))
    * the fixture is live: the text file exists beside the log
    confirm file "`secret'"
    assert `b64' == 0
    assert `missing' == 0
    assert `mdlink' == 0
    assert `bad_ngraphs' == 0
}
if _rc == 0 {
    display as result "  PASS: RF6 failed non-image graph export not embedded"
    local ++test_pass
}
else {
    display as error "  FAIL: RF6 non-image graph export (rc=`=_rc')"
    local ++test_fail
}

* RF7: guard: a real PNG export is embedded once.
local gp "`outdir'/rf_graph_png"
capture erase "`gp'.smcl"
capture erase "`outdir'/rf_graph.png"
log using "`gp'.smcl", smcl replace nomsg name(_ldf)
graph export "rf_graph.png", replace
log close _ldf
graph drop _all
quietly logdoc using "`gp'.smcl", output("`gp'.html") replace
local png_ngraphs = r(ngraphs)
local ++test_total
capture noisily {
    confirm file "`outdir'/rf_graph.png"
    mata: st_local("png", strofreal(_ldf_count(st_local("gp") + ".html", "data:image/png;base64,")))
    assert `png' == 1
    assert `png_ngraphs' == 1
}
if _rc == 0 {
    display as result "  PASS: RF7 real PNG graph export embedded"
    local ++test_pass
}
else {
    display as error "  FAIL: RF7 PNG graph export (rc=`=_rc')"
    local ++test_fail
}

**# Fixture 5: round-2 regressions from real Stata output
* {rm} in Stata's own notes, {bf}...{sf} inside an error, log off/on
* banners, Markdown/LaTeX delimiters in output, "> " output, {help "a b"},
* gr export with as() and no extension, a file name with a space, and
* exports inside a loop body.
local r2 "`outdir'/rf_r2"
capture erase "`r2'.smcl"
foreach f in "rf2 inner.log" rf2a "rf2 b.png" rf2l1.png rf2l2.png {
    capture erase "`outdir'/`f'"
}
set linesize 255
sysuse auto, clear
quietly scatter price mpg
log using "`r2'.smcl", smcl replace name(_ldf)
log using "rf2 inner.log", text replace name(_ldf_in)
log close _ldf_in
capture noisily regress price rf_nosuchvar
log off _ldf
display "RF_HIDDEN_WHILE_OFF"
log on _ldf
display "```"
display "\end{lstlisting}"
display "> quoted output"
display `"{help "a b"}"'
gr export rf2a, as(png) replace
graph export "rf2 b.png", replace
forvalues rf_i = 1/2 {
    graph export rf2l`rf_i'.png, replace
}
log close _ldf
set linesize `ls'
graph drop _all
translate "`r2'.smcl" "`r2'_oracle.txt", translator(smcl2log) linesize(255) replace
quietly logdoc using "`r2'.smcl", output("`r2'.html") replace
local r2_ngraphs = r(ngraphs)
quietly logdoc using "`r2'.smcl", output("`r2'.md") format(md) replace
quietly logdoc using "`r2'.smcl", output("`r2'.tex") format(tex) replace

* RF9: {rm} is a directive, not text: Stata's "(file ... not found)" note
* renders as the oracle prints it.
local ++test_total
capture noisily {
    mata: o = _ldf_oracle(st_local("r2") + "_oracle.txt", 0); ///
        k = 0; for (i = 1; i <= rows(o); i++) if (substr(o[i], 1, 6) == "(file " & strpos(o[i], "rf2 inner.log not found)")) k = i; ///
        st_local("k", strofreal(k)); ///
        st_local("h", strofreal(k ? _ldf_has(_ldf_html(st_local("r2") + ".html"), o[k]) : 0)); ///
        st_local("m", strofreal(k ? _ldf_has(_ldf_md(st_local("r2") + ".md"), o[k]) : 0)); ///
        st_local("rm", strofreal(_ldf_count(st_local("r2") + ".html", "{rm}") + _ldf_count(st_local("r2") + ".md", "{rm}")))
    assert `k' > 0
    assert `h' == 1
    assert `m' == 1
    assert `rm' == 0
}
if _rc == 0 {
    display as result "  PASS: RF9 rm directive consumed; Stata's file note matches the oracle"
    local ++test_pass
}
else {
    display as error "  FAIL: RF9 rm directive (rc=`=_rc')"
    local ++test_fail
}

* RF10: {bf}/{sf} font switches inside an error keep the error colour.
local ++test_total
capture noisily {
    mata: st_local("e", strofreal(_ldf_count(st_local("r2") + ".html", `"<span class="err">variable rf_nosuchvar not found</span>"')))
    assert `e' == 1
}
if _rc == 0 {
    display as result "  PASS: RF10 font switches do not end the error colour"
    local ++test_pass
}
else {
    display as error "  FAIL: RF10 sf inside err (rc=`=_rc')"
    local ++test_fail
}

* RF12: log off/log on banners (paused on/resumed on) are dropped.
local ++test_total
capture noisily {
    mata: t = _ldf_text(st_local("r2") + ".md") + _ldf_text(st_local("r2") + ".html"); ///
        st_local("n", strofreal((strpos(t, "paused on:") > 0) + (strpos(t, "resumed on:") > 0) + (strpos(t, "log type:") > 0) + (strpos(t, "name:  ") > 0))); ///
        st_local("after", strofreal(_ldf_has(_ldf_md(st_local("r2") + ".md"), "> quoted output")))
    assert `n' == 0
    assert `after' == 1
}
if _rc == 0 {
    display as result "  PASS: RF12 log off/on banners dropped"
    local ++test_pass
}
else {
    display as error "  FAIL: RF12 log off/on banners (rc=`=_rc')"
    local ++test_fail
}

* RF16: output that looks like a delimiter stays content.  A ``` output line
* sits in a longer fence; \end{lstlisting} output does not end the LaTeX
* listing; "> " output after a short command stays output; a graph path
* with a space uses the <...> link form.
local ++test_total
capture noisily {
    mata: md = _ldf_md(st_local("r2") + ".md"); ///
        st_local("tick", strofreal(_ldf_has(md, "```"))); ///
        st_local("endl", strofreal(_ldf_has(md, "\end{lstlisting}"))); ///
        st_local("gt", strofreal(_ldf_has(md, "> quoted output"))); ///
        st_local("gtcmd", strofreal(_ldf_has(_ldf_mdpart(st_local("r2") + ".md", 1), "> quoted output"))); ///
        st_local("link", strofreal(_ldf_count(st_local("r2") + ".md", "(<rf2 b.png>)"))); ///
        st_local("verb", strofreal(_ldf_has(_ldf_lines(st_local("r2") + ".tex"), "\noindent\verb|\end{lstlisting}|\par")))
    assert `tick' == 1
    assert `endl' == 1
    assert `gt' == 1
    assert `gtcmd' == 0
    assert `link' == 1
    assert `verb' == 1
}
if _rc == 0 {
    display as result "  PASS: RF16 delimiter-like output stays content in md/tex"
    local ++test_pass
}
else {
    display as error "  FAIL: RF16 delimiter-like output (rc=`=_rc')"
    local ++test_fail
}

* RF17: gr export, as(png) without an extension, a spaced name, and loop
* exports are all embedded (four PNGs).
local ++test_total
capture noisily {
    foreach f in rf2a "rf2 b.png" rf2l1.png rf2l2.png {
        confirm file "`outdir'/`f'"
    }
    mata: st_local("png", strofreal(_ldf_count(st_local("r2") + ".html", "data:image/png;base64,")))
    assert `png' == 4
    assert `r2_ngraphs' == 4
}
if _rc == 0 {
    display as result "  PASS: RF17 gr export, as(), spaced and loop exports embedded"
    local ++test_pass
}
else {
    display as error "  FAIL: RF17 graph export detection (rc=`=_rc')"
    local ++test_fail
}

* RF19: {help "a b"} renders its text.
local ++test_total
capture noisily {
    mata: st_local("h", strofreal(_ldf_has(_ldf_html(st_local("r2") + ".html"), "a b"))); ///
        st_local("o", strofreal(_ldf_has(_ldf_oracle(st_local("r2") + "_oracle.txt", 0), "a b")))
    assert `o' == 1
    assert `h' == 1
}
if _rc == 0 {
    display as result "  PASS: RF19 quoted help topic text rendered"
    local ++test_pass
}
else {
    display as error "  FAIL: RF19 quoted help topic (rc=`=_rc')"
    local ++test_fail
}

* RF18: tables option escapes P>|t| once.
quietly logdoc using "`est'.smcl", output("`est'_tables.html") tables replace
local ++test_total
capture noisily {
    mata: st_local("ok", strofreal(_ldf_count(st_local("est") + "_tables.html", "P&gt;|t|"))); ///
        st_local("bad", strofreal(_ldf_count(st_local("est") + "_tables.html", "&amp;gt;")))
    assert `ok' >= 1
    assert `bad' == 0
}
if _rc == 0 {
    display as result "  PASS: RF18 tables option escapes P>|t| once"
    local ++test_pass
}
else {
    display as error "  FAIL: RF18 tables double escaping (rc=`=_rc')"
    local ++test_fail
}

**# Fixture 6: SMCL without a first-line {smcl} header
* The estimation log with a UTF-8 BOM, without its header line, and with
* blank lines before the header must render exactly like the original.
mata:
void _ldf_variant(string scalar src, string scalar dst, string scalar kind)
{
    string colvector v
    real scalar fh, i, first

    v = _ldf_lines(src)
    if (fileexists(dst)) unlink(dst)
    fh = fopen(dst, "w")
    first = 1
    if (kind == "bom") fwrite(fh, char((239, 187, 191)))
    if (kind == "lead") {
        fput(fh, "")
        fput(fh, "")
    }
    if (kind == "nohdr") first = 2
    for (i = first; i <= rows(v); i++) fput(fh, v[i])
    fclose(fh)
}
end
local ++test_total
capture noisily {
    foreach kind in bom nohdr lead {
        mata: _ldf_variant(st_local("est") + ".smcl", st_local("est") + "_`kind'.smcl", "`kind'")
        quietly logdoc using "`est'_`kind'.smcl", output("`est'_`kind'.md") format(md) replace
        mata: st_local("nd", strofreal(_ldf_diff(_ldf_md(st_local("est") + ".md"), _ldf_md(st_local("est") + "_`kind'.md")))); ///
            st_local("tags", strofreal(_ldf_count(st_local("est") + "_`kind'.md", "{txt}") + _ldf_count(st_local("est") + "_`kind'.md", "{res}")))
        assert `nd' == 0
        assert `tags' == 0
    }
}
if _rc == 0 {
    display as result "  PASS: RF11 BOM, headerless and blank-led SMCL render as SMCL"
    local ++test_pass
}
else {
    display as error "  FAIL: RF11 SMCL detection (rc=`=_rc')"
    local ++test_fail
}

**# Fixture 7: hand-written SMCL for bounds, paragraphs and combine state
local bomb "`outdir'/rf_bomb"
file open `fh' using "`bomb'.smcl", write text replace
file write `fh' "{smcl}" _n "{com}. rf_bomb" _n
file write `fh' "{txt}{dup 20000000:ab}" _n "{txt}{hline 20000000}" _n
file write `fh' "{txt}{space 20000000}X" _n "{txt}AFTER_BOMB" _n
file close `fh'

* RF13: hostile repeat counts are bounded.
local ++test_total
capture noisily {
    quietly logdoc using "`bomb'.smcl", output("`bomb'.md") format(md) replace
    checksum "`bomb'.md"
    local len = r(filelen)
    display as text "    bomb Markdown bytes: `len'"
    assert `len' < 1000000
    mata: st_local("after", strofreal(_ldf_has(_ldf_md(st_local("bomb") + ".md"), "AFTER_BOMB"))); ///
        st_local("ab", strofreal(_ldf_count(st_local("bomb") + ".md", "abababababababababab")))
    assert `after' == 1
    assert `ab' >= 1
}
if _rc == 0 {
    display as result "  PASS: RF13 dup/hline/space counts are bounded"
    local ++test_pass
}
else {
    display as error "  FAIL: RF13 repeat bounds (rc=`=_rc')"
    local ++test_fail
}

* RF15: a new paragraph directive starts a new paragraph.
local para "`outdir'/rf_para"
file open `fh' using "`para'.smcl", write text replace
file write `fh' "{smcl}" _n "{com}. rf_para" _n
file write `fh' "{txt}{phang}aa" _n "{phang}bb{p_end}" _n
file write `fh' "{txt}{pstd}cc" _n "dd{p_end}" _n
file close `fh'
quietly logdoc using "`para'.smcl", output("`para'.md") format(md) replace
local ++test_total
capture noisily {
    mata: md = _ldf_md(st_local("para") + ".md"); ///
        st_local("a", strofreal(_ldf_has(md, "    aa"))); ///
        st_local("b", strofreal(_ldf_has(md, "    bb"))); ///
        st_local("cd", strofreal(_ldf_has(md, "    cc dd")))
    assert `a' == 1
    assert `b' == 1
    assert `cd' == 1
}
if _rc == 0 {
    display as result "  PASS: RF15 consecutive paragraph directives stay separate"
    local ++test_pass
}
else {
    display as error "  FAIL: RF15 paragraph separation (rc=`=_rc')"
    local ++test_fail
}

* RF14: {p2colset} in one combined source does not leak into the next.
local ca "`outdir'/rf_comb_a"
local cb "`outdir'/rf_comb_b"
file open `fh' using "`ca'.smcl", write text replace
file write `fh' "{smcl}" _n "{com}. rf_a" _n "{txt}{p2colset 1 5 5 2}{p2col:K}VA{p_end}" _n
file close `fh'
file open `fh' using "`cb'.smcl", write text replace
file write `fh' "{smcl}" _n "{com}. rf_b" _n "{txt}{p2col:K}VB{p_end}" _n
file close `fh'
quietly logdoc combine using "`ca'.smcl" "`cb'.smcl", output("`outdir'/rf_comb.md") format(md) replace
local ++test_total
capture noisily {
    mata: md = _ldf_md(st_local("outdir") + "/rf_comb.md"); ///
        st_local("a", strofreal(_ldf_has(md, "K   VA"))); ///
        st_local("b", strofreal(_ldf_has(md, "K" + 29 * " " + "VB")))
    assert `a' == 1
    assert `b' == 1
}
if _rc == 0 {
    display as result "  PASS: RF14 p2col layout resets for each combined source"
    local ++test_pass
}
else {
    display as error "  FAIL: RF14 p2col state across sources (rc=`=_rc')"
    local ++test_fail
}

**# Fixture 8: text logs whose command echo wraps at the linesize
* Stata cuts a long command at exactly the linesize and continues it on
* "> " lines; the renderer derives the width from the log itself.  Logs at
* linesize 60, 120 and 255 (the command fits on one line at 255); each
* also has literal "> " output, which must stay output.
mata:
// The "> " lines that continue the first echo starting with `start'.
string colvector _ldf_cont(string scalar path, string scalar start)
{
    string colvector v, out
    real scalar i, k

    v = _ldf_lines(path)
    out = J(0, 1, "")
    k = 0
    for (i = 1; i <= rows(v); i++) {
        if (substr(v[i], 1, strlen(start)) == start) {
            k = i
            break
        }
    }
    if (k == 0) return(out)
    for (i = k + 1; i <= rows(v); i++) {
        if (substr(v[i], 1, 2) != "> ") break
        out = out \ _ldf_norm(v[i])
    }
    return(out)
}

real scalar _ldf_all_in(string colvector a, string colvector b)
{
    real scalar i
    for (i = 1; i <= rows(a); i++) if (!_ldf_has(b, a[i])) return(0)
    return(1)
}
end
sysuse auto, clear
foreach rf_ls in 60 120 255 {
    capture erase "`outdir'/rf_wrap`rf_ls'.log"
}
set linesize 60
log using "`outdir'/rf_wrap60.log", text replace nomsg name(_ldf)
regress price mpg weight length headroom trunk gear_ratio turn displacement foreign rep78 mpg weight length headroom trunk, noheader
display "> quoted output"
log close _ldf
set linesize 120
log using "`outdir'/rf_wrap120.log", text replace nomsg name(_ldf)
regress price mpg weight length headroom trunk gear_ratio turn displacement foreign rep78 mpg weight length headroom trunk gear_ratio turn displacement foreign rep78, noheader
display "> quoted output"
log close _ldf
set linesize 255
log using "`outdir'/rf_wrap255.log", text replace nomsg name(_ldf)
regress price mpg weight length headroom trunk gear_ratio turn displacement foreign rep78 mpg weight length headroom trunk gear_ratio turn displacement foreign rep78, noheader
display "> quoted output"
log close _ldf
set linesize `ls'

* RF20: wrapped command echoes keep every "> " line in the stata fence at
* linesize 60 and 120; at 255 there is none; "> " output stays output.
local ++test_total
capture noisily {
    foreach rf_ls in 60 120 255 {
        local wf "`outdir'/rf_wrap`rf_ls'"
        quietly logdoc using "`wf'.log", output("`wf'.md") format(md) replace
        mata: c = _ldf_cont(st_local("wf") + ".log", ". regress price"); ///
            cmd = _ldf_mdpart(st_local("wf") + ".md", 1); ///
            st_local("ncont", strofreal(rows(c))); ///
            st_local("allin", strofreal(_ldf_all_in(c, cmd))); ///
            st_local("qout", strofreal(_ldf_has(_ldf_md(st_local("wf") + ".md"), "> quoted output"))); ///
            st_local("qcmd", strofreal(_ldf_has(cmd, "> quoted output")))
        display as text "    linesize `rf_ls': continuation lines `ncont'"
        if `rf_ls' < 255 assert `ncont' >= 1
        else assert `ncont' == 0
        assert `allin' == 1
        assert `qout' == 1
        assert `qcmd' == 0
    }
}
if _rc == 0 {
    display as result "  PASS: RF20 text-log command wraps at linesize 60/120/255"
    local ++test_pass
}
else {
    display as error "  FAIL: RF20 text-log command wraps (rc=`=_rc')"
    local ++test_fail
}

quietly cd "`oldpwd'"
display as text ""
display as text "RESULT: test_logdoc_render_fidelity tests=`test_total' pass=`test_pass' fail=`test_fail'"
if `test_fail' > 0 exit 9
