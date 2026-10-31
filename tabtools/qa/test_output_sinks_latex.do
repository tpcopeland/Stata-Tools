* test_output_sinks_latex.do - tabtools output layer: the LaTeX sink
* Writer and plumbing for latex()/texappend and tabtools set latex
* (_take_action/tabtools_latex_export_2026-10-31.md):
*   L0  the checker (qa/tools/check_latex.py) rejects known-bad files, so a
*       PASS from it is not vacuous
*   L1  layout: caption/label, header block, declared spanner + cmidrule,
*       \midrule, stub indentation, \addlinespace, note paragraphs
*   L2  every ASCII special, CR/LF, control characters, row-start guards,
*       caption and note escaping; L2b ligature breaks (data "--", "---",
*       "?`" and "!`" render as typed)
*   L3  the Unicode map and Latin-1 pass-through
*   L4  macro-shaped text (local-macro quotes, $HOME, an unbalanced
*       backtick) is written literally
*   L5  last-header-row fallback, strictheaders, novarnames, no header block
*   L6  blank rows: \addlinespace rules, keepblank, row count = Markdown's
*   L7  boldrows   L8 numeric cells   L9 caption/label/append numbering
*   L10 footnote paragraphs
*   L11 spans(): accepted layouts and every refusal (target unchanged)
*   L12 a failed write leaves the target and no staging file
*   L13 .tex extension and path refusals
*   L14 four-way same-file refusal in _tabtools_check_sinks
*   L15 tabtools set/query/clear latex and the session sink plumbing
*   L16 cell parity with the CSV writer
*   L18 the CSV writer quotes a cell with an embedded line break (RFC 4180)
*   L19 \caption drops one leading "Table <id>." prefix (LaTeX numbers it)
*   L20 a body row with text in column 1 only spans the row as
*       \multicolumn{k}{l}, so it does not widen the stub column
*   L21 spaces, primes, symbols, arrows and signs map to commands pdflatex
*       knows; zero-width characters are dropped
*   L22 ASCII double quotes and quote pairs render as typed
*   L23 labelvar() naming no variable, datastart() past the data and
*       headerstart() after datastart() are refused, nothing written
*   L17 the same contracts through puttab latex()
* Expected values are hand-built strings (Mata fixtures below, special
* characters spelled with char()/uchar()), checksums taken before a call,
* and the independent checker (pdflatex on the documented minimal preamble
* plus pdftotext), never the output under test.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _osl
log using "test_output_sinks_latex.log", replace text name(_osl)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global OSL_CHECKER "`qa_dir'/tools/check_latex.py"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

* CRC and length of a file, as one string ("absent" when there is none).
capture program drop _osl_sum
program define _osl_sum, rclass
    version 17.0
    args path
    capture confirm file "`path'"
    if _rc {
        return local sum "absent"
        exit
    }
    quietly checksum "`path'"
    return local sum "`r(checksum)':`r(filelen)'"
end

* Plain text file with a sentinel line.
capture program drop _osl_seed_text
program define _osl_seed_text
    version 17.0
    args path
    capture erase "`path'"
    tempname fh
    file open `fh' using "`path'", write text
    file write `fh' "KEEP THIS TEXT" _n
    file close `fh'
end

* Console text of a command, captured through a nested log into r(text).
capture program drop _osl_console
program define _osl_console, rclass
    version 17.0
    tempfile lg
    quietly log using "`lg'", text replace name(_osl_capture)
    capture noisily `0'
    local crc = _rc
    quietly log close _osl_capture
    mata: st_local("_osl_txt", invtokens(cat(st_local("lg"))', " "))
    return local text `"`macval(_osl_txt)'"'
    return scalar rc = `crc'
end

* Run check_latex.py on a .tex file with the options that follow it; the
* checker's verdict line must start with PASS (or FAIL with prefix fail).
capture program drop _osl_check
program define _osl_check
    version 17.0
    gettoken tex 0 : 0
    tempfile res
    capture erase "`res'"
    shell python3 "$OSL_CHECKER" "`tex'" `0' --result "`res'"
    confirm file "`res'"
    mata: printf("{txt}  check_latex: %s\n", cat(st_local("res"))[1])
    mata: st_local("_osl_ok", strofreal(substr(cat(st_local("res"))[1], 1, 4) == "PASS"))
    assert `_osl_ok' == 1
end

capture program drop _osl_check_fails
program define _osl_check_fails
    version 17.0
    gettoken tex 0 : 0
    tempfile res
    capture erase "`res'"
    shell python3 "$OSL_CHECKER" "`tex'" `0' --result "`res'"
    confirm file "`res'"
    mata: printf("{txt}  check_latex (must fail): %s\n", cat(st_local("res"))[1])
    mata: st_local("_osl_ok", strofreal(substr(cat(st_local("res"))[1], 1, 5) == "FAIL:"))
    assert `_osl_ok' == 1
end

* A command that must be refused with rc 198, print a message containing
* needle ("" = any), and leave target byte-identical (or absent).
capture program drop _osl_refused
program define _osl_refused
    version 17.0
    gettoken target 0 : 0
    gettoken needle 0 : 0
    _osl_sum "`target'"
    local before "`r(sum)'"
    _osl_console `0'
    local crc = r(rc)
    local txt `"`r(text)'"'
    _osl_sum "`target'"
    local after "`r(sum)'"
    display as text "  refused rc=`crc'; checksum before `before', after `after'"
    assert "`after'" == "`before'"
    assert `crc' == 198
    if `"`needle'"' != "" {
        local hit = strpos(`"`macval(txt)'"', `"`needle'"') > 0
        if !`hit' display as error `"  message lacks: `needle'"'
        assert `hit'
    }
end

* Files in dir, and this process's files in c(tmpdir), as sorted strings.
capture program drop _osl_ls
program define _osl_ls, rclass
    version 17.0
    args dir
    local f : dir "`dir'" files "*", respectcase
    local d : dir "`dir'" dirs "*", respectcase
    local f : list sort f
    local d : list sort d
    tempfile probe
    mata: st_local("pfx", pathbasename(st_local("probe")))
    local pfx = substr("`pfx'", 1, strpos("`pfx'", "."))
    local t : dir "`c(tmpdir)'" files "`pfx'*", respectcase
    local t : list sort t
    return local here `"`f' | `d'"'
    return local tmp `"`t'"'
end

* The write in `0' against target in dir must fail and leave the target
* byte-identical, and no file added to dir or to c(tmpdir).
capture program drop _osl_failwrite
program define _osl_failwrite
    version 17.0
    gettoken dir 0 : 0
    gettoken target 0 : 0
    _osl_sum "`target'"
    local s0 "`r(sum)'"
    _osl_ls "`dir'"
    local h0 `"`r(here)'"'
    local t0 `"`r(tmp)'"'
    capture noisily `0'
    local wrc = _rc
    _osl_sum "`target'"
    local s1 "`r(sum)'"
    _osl_ls "`dir'"
    display as text "  write rc=`wrc'; checksum `s0' -> `s1'"
    assert `wrc' != 0
    assert "`s1'" == "`s0'"
    assert `"`r(here)'"' == `"`h0'"'
    assert `"`r(tmp)'"' == `"`t0'"'
end

**# Mata fixtures: inputs and hand-built expected lines
* Lines of this do-file are macro-expanded, Mata included: the dollar sign
* and the backtick are spelled char(36) and char(96) (D, Q below).
mata:
mata set matastrict off

real scalar _osl_eq(string scalar path, string colvector want)
{
    string colvector got
    real scalar i, n
    got = cat(path)
    if (rows(got) != rows(want)) {
        printf("{err}line count: file %f, expected %f\n", rows(got), rows(want))
        for (i = 1; i <= rows(got); i++) display("  file " + strofreal(i) + ": [" + got[i] + "]", 1)
        return(0)
    }
    n = 0
    for (i = 1; i <= rows(want); i++) {
        if (got[i] != want[i]) {
            printf("{err}line %f differs\n", i)
            display("  file:     [" + got[i] + "]", 1)
            display("  expected: [" + want[i] + "]", 1)
            n++
        }
    }
    return(n == 0)
}

void _osl_put(string scalar path, string colvector lines)
{
    real scalar fh, i
    if (fileexists(path)) unlink(path)
    fh = fopen(path, "w")
    for (i = 1; i <= rows(lines); i++) fput(fh, lines[i])
    fclose(fh)
}

// Replace the dataset with string variables c1..ck holding X.
void _osl_load(string matrix X)
{
    real scalar j
    stata("clear")
    st_addobs(rows(X))
    for (j = 1; j <= cols(X); j++) {
        (void) st_addvar("strL", "c" + strofreal(j))
        st_sstore(., j, X[., j])
    }
}

string scalar _osl_top()
{
    return("% tabtools LaTeX table; requires \usepackage{booktabs}")
}

// L0: a minimal valid table and broken variants of it.
string colvector _osl_min(string colvector body)
{
    return(_osl_top() \ "\begin{table}[htbp]" \ "\centering" \
        "\begin{tabular}{lc}" \ "\toprule" \ "A & B \\" \ "\midrule" \
        body \ "\bottomrule" \ "\end{tabular}" \ "\end{table}")
}

// L1: the layout of the spec's example.
string matrix _osl_x_layout()
{
    return(("", "", "", "") \
        ("", "Model 1", "", "") \
        ("Variable", "HR", "95% CI", "p") \
        ("Age", "1.02", "1.01" + uchar(8211) + "1.03", "<0.001") \
        ("", "", "", "") \
        ("  Male", "1.10", "0.90" + uchar(8211) + "1.30", "0.35"))
}

string colvector _osl_e_layout()
{
    return(_osl_top() \
        "\begin{table}[htbp]" \
        "\centering" \
        "\caption{Hazard ratios}" \
        "\label{tab:osl_layout}" \
        "\begin{tabular}{lccc}" \
        "\toprule" \
        " & \multicolumn{3}{c}{Model 1} \\" \
        "\cmidrule(lr){2-4}" \
        "Variable & HR & 95\% CI & p \\" \
        "\midrule" \
        "Age & 1.02 & 1.01--1.03 & \textless{}0.001 \\" \
        "\addlinespace" \
        "\hspace*{1em}Male & 1.10 & 0.90--1.30 & 0.35 \\" \
        "\bottomrule" \
        "\end{tabular}" \
        "\par\smallskip" \
        "{\footnotesize\raggedright" \
        "Note one.\par" \
        "Note two.\par}" \
        "\end{table}")
}

// L2: ASCII specials, line breaks, controls, row-start guards.
string matrix _osl_x_ascii()
{
    string scalar B, D
    B = char(92)
    D = char(36)
    return(("Input", "V") \
        ("a" + B + "b", "v") \
        ("{x}", "v") \
        (D + "5", "v") \
        ("A&B", "v") \
        ("#1", "v") \
        ("50%", "v") \
        ("a_b", "v") \
        ("x^2", "v") \
        ("~5", "v") \
        ("<5", "v") \
        (">5", "v") \
        ("a|b", "v") \
        ("l1" + char(13) + char(10) + "l2" + char(10) + "l3" + char(13) + "l4", "v") \
        (B + "{}", "v") \
        ("[ref] x", "v") \
        ("* p<0.05", "v") \
        ("a" + char(9) + "b", "v") \
        (B + "{}" + D + "&#%_^~<>|", "all"))
}

string scalar _osl_t_ascii()
{
    return("T: a" + char(92) + "b {x} " + char(36) + "5 A&B #1 50% a_b x^2 ~5 <5 >5 a|b " +
        uchar(8805) + "5 " + uchar(177) + "1 [r] *s")
}

string scalar _osl_f_ascii()
{
    return("F: 50% " + char(92) + " " + char(36) + "x_1" + char(36) + " <0.05")
}

string colvector _osl_e_ascii()
{
    string scalar B, D
    B = char(92)
    D = char(36)
    return(_osl_top() \
        "\begin{table}[htbp]" \
        "\centering" \
        ("\caption{T: a\textbackslash{}b \{x\} " + B + D + "5 A\&B \#1 50\% a\_b " +
            "x\textasciicircum{}2 \textasciitilde{}5 \textless{}5 \textgreater{}5 " +
            "a\textbar{}b \ensuremath{\geq}5 \ensuremath{\pm}1 [r] *s}") \
        "\label{tab:osl_ascii}" \
        "\begin{tabular}{lc}" \
        "\toprule" \
        "Input & V \\" \
        "\midrule" \
        "a\textbackslash{}b & v \\" \
        "\{x\} & v \\" \
        (B + D + "5 & v \\") \
        "A\&B & v \\" \
        "\#1 & v \\" \
        "50\% & v \\" \
        "a\_b & v \\" \
        "x\textasciicircum{}2 & v \\" \
        "\textasciitilde{}5 & v \\" \
        "\textless{}5 & v \\" \
        "\textgreater{}5 & v \\" \
        "a\textbar{}b & v \\" \
        "l1 l2 l3 l4 & v \\" \
        "\textbackslash{}\{\} & v \\" \
        "{}[ref] x & v \\" \
        "{}* p\textless{}0.05 & v \\" \
        "a b & v \\" \
        ("\textbackslash{}\{\}" + B + D + "\&\#\%\_\textasciicircum{}" +
            "\textasciitilde{}\textless{}\textgreater{}\textbar{} & all \\") \
        "\bottomrule" \
        "\end{tabular}" \
        "\par\smallskip" \
        "{\footnotesize\raggedright" \
        "F: 50\%\par" \
        (B + D + "x\_1" + B + D + " \textless{}0.05\par}") \
        "\end{table}")
}

// L3: the Unicode map. Greek code points and command names are written
// out here by hand, independently of the writer's table.
string matrix _osl_x_unicode()
{
    real rowvector gl, gv, gu
    string scalar sl, sv, su
    real scalar i
    gl = (945, 946, 947, 948, 949, 950, 951, 952, 953, 954, 955, 956, 957, 958,
        960, 961, 962, 963, 964, 965, 966, 967, 968, 969)
    gv = (977, 981, 982, 1009, 1013)
    gu = (915, 916, 920, 923, 926, 928, 931, 933, 934, 936, 937)
    sl = sv = su = ""
    for (i = 1; i <= cols(gl); i++) sl = sl + uchar(gl[i])
    for (i = 1; i <= cols(gv); i++) sv = sv + uchar(gv[i])
    for (i = 1; i <= cols(gu); i++) su = su + uchar(gu[i])
    return(("Input", "U") \
        (uchar(177) + "1", "u") \
        ("2" + uchar(215) + "3", "u") \
        ("6" + uchar(247) + "2", "u") \
        ("m" + uchar(178) + "m" + uchar(179) + "x" + uchar(185), "u") \
        ("1" + uchar(8211) + "2 a" + uchar(8212) + "b", "u") \
        (uchar(8722) + "1", "u") \
        (uchar(8805) + "5 " + uchar(8804) + "5 " + uchar(8800) + "0 " + uchar(8776) + "1", "u") \
        ("a" + uchar(8594) + "b" + uchar(8592) + "c" + uchar(183) + "d", "u") \
        ("37" + uchar(176) + " 5" + uchar(181) + "g 5" + uchar(956) + "g", "u") \
        (sl, "u") \
        (sv, "u") \
        (su, "u") \
        ("wait" + uchar(8230), "u") \
        (uchar(8216) + "q" + uchar(8217) + " " + uchar(8220) + "qq" + uchar(8221), "u") \
        ("a" + uchar(160) + "b", "u") \
        (uchar(8224) + uchar(8225) + uchar(167) + "3" + uchar(8226), "u") \
        (uchar(229) + uchar(228) + uchar(246) + uchar(233) + " " + uchar(197) +
            uchar(196) + uchar(214) + " " + uchar(252) + uchar(241) + uchar(231), "u"))
}

string colvector _osl_e_unicode()
{
    string scalar Q, el, ev, eu
    string rowvector nl, nv, nu
    real scalar i
    Q = char(96)
    nl = ("alpha", "beta", "gamma", "delta", "varepsilon", "zeta", "eta",
        "theta", "iota", "kappa", "lambda", "mu", "nu", "xi", "pi", "rho",
        "varsigma", "sigma", "tau", "upsilon", "varphi", "chi", "psi", "omega")
    nv = ("vartheta", "phi", "varpi", "varrho", "epsilon")
    nu = ("Gamma", "Delta", "Theta", "Lambda", "Xi", "Pi", "Sigma", "Upsilon",
        "Phi", "Psi", "Omega")
    el = ev = eu = ""
    for (i = 1; i <= cols(nl); i++) el = el + "\ensuremath{\" + nl[i] + "}"
    for (i = 1; i <= cols(nv); i++) ev = ev + "\ensuremath{\" + nv[i] + "}"
    for (i = 1; i <= cols(nu); i++) eu = eu + "\ensuremath{\" + nu[i] + "}"
    return(_osl_top() \
        "\begin{table}[htbp]" \
        "\centering" \
        "\begin{tabular}{lc}" \
        "\toprule" \
        "Input & U \\" \
        "\midrule" \
        "\ensuremath{\pm}1 & u \\" \
        "2\ensuremath{\times}3 & u \\" \
        "6\ensuremath{\div}2 & u \\" \
        "m\textsuperscript{2}m\textsuperscript{3}x\textsuperscript{1} & u \\" \
        "1--2 a---b & u \\" \
        "\ensuremath{-}1 & u \\" \
        "\ensuremath{\geq}5 \ensuremath{\leq}5 \ensuremath{\neq}0 \ensuremath{\approx}1 & u \\" \
        "a\ensuremath{\rightarrow}b\ensuremath{\leftarrow}c\ensuremath{\cdot}d & u \\" \
        "37\ensuremath{^\circ} 5\ensuremath{\mu}g 5\ensuremath{\mu}g & u \\" \
        (el + " & u \\") \
        (ev + " & u \\") \
        (eu + " & u \\") \
        "wait\ldots{} & u \\" \
        (Q + "q' " + Q + Q + "qq'' & u \\") \
        "a\nobreakspace{}b & u \\" \
        "\dag{}\ddag{}\S{}3\textbullet{} & u \\" \
        (uchar(229) + uchar(228) + uchar(246) + uchar(233) + " " + uchar(197) +
            uchar(196) + uchar(214) + " " + uchar(252) + uchar(241) + uchar(231) + " & u \\") \
        "\bottomrule" \
        "\end{tabular}" \
        "\end{table}")
}

// L4: macro-shaped text.
string matrix _osl_x_macro()
{
    string scalar Q, S, D
    Q = char(96)
    S = char(39)
    D = char(36)
    return(("", "M") \
        (Q + "dosage" + S, "m") \
        (D + "HOME", "m") \
        (D + "{HOME}", "m") \
        (Q + "=1+1" + S, "m") \
        ("a" + Q + "b", "m") \
        (D + "OSL_SENTINEL", "m") \
        (Q + Q + "x" + S + S, "m"))
}

string colvector _osl_e_macro()
{
    string scalar Q, S, B, D
    Q = char(96)
    S = char(39)
    B = char(92)
    D = char(36)
    return(_osl_top() \
        "\begin{table}[htbp]" \
        "\centering" \
        ("\caption{" + Q + "T" + S + " " + B + D + "OSL\_SENTINEL}") \
        "\label{tab:osl_macro}" \
        "\begin{tabular}{lc}" \
        "\toprule" \
        (Q + "lab" + S + " & M \\") \
        "\midrule" \
        (Q + "dosage" + S + " & m \\") \
        (B + D + "HOME & m \\") \
        (B + D + "\{HOME\} & m \\") \
        (Q + "=1+1" + S + " & m \\") \
        ("a" + Q + "b & m \\") \
        (B + D + "OSL\_SENTINEL & m \\") \
        (Q + "{}" + Q + "x" + S + "{}" + S + " & m \\") \
        "\bottomrule" \
        "\end{tabular}" \
        "\par\smallskip" \
        "{\footnotesize\raggedright" \
        ("note " + Q + "n" + Q + " end " + B + D + "HOME\par}") \
        "\end{table}")
}

// L5: header fallback. Row 1 is the header row.
string matrix _osl_x_fallback()
{
    return(("", "", "Given") \ ("r1", "1", "2"))
}

string colvector _osl_e_fallback(string scalar head)
{
    string colvector E
    E = _osl_top() \ "\begin{table}[htbp]" \ "\centering" \
        "\begin{tabular}{lcc}" \ "\toprule"
    if (head != "") E = E \ head \ "\midrule"
    return(E \ "r1 & 1 & 2 \\" \ "\bottomrule" \ "\end{tabular}" \ "\end{table}")
}

// L11: spanners over a two-row header.
string matrix _osl_x_spans(real scalar lastspan)
{
    return(("", "Model 1", "", "Model 2", "Model 2") \
        (lastspan ? ("(ref)", "Both", "", "HR", "CI") : ("(ref)", "HR", "CI", "HR", "CI")) \
        ("Age", "1.1", "1.0-1.2", "1.2", "1.1-1.3"))
}

string colvector _osl_e_spans(real scalar lastspan)
{
    return(_osl_top() \
        "\begin{table}[htbp]" \
        "\centering" \
        "\begin{tabular}{lcccc}" \
        "\toprule" \
        " & \multicolumn{2}{c}{Model 1} & \multicolumn{2}{c}{Model 2} \\" \
        "\cmidrule(lr){2-3} \cmidrule(lr){4-5}" \
        (lastspan ? "(ref) & \multicolumn{2}{c}{Both} & HR & CI \\" :
            "(ref) & HR & CI & HR & CI \\") \
        "\midrule" \
        "Age & 1.1 & 1.0-1.2 & 1.2 & 1.1-1.3 \\" \
        "\bottomrule" \
        "\end{tabular}" \
        "\end{table}")
}

// L2b: TeX ligatures in data text are broken with an empty group.
string matrix _osl_x_lig()
{
    string scalar Q
    Q = char(96)
    return(("Input", "L") \
        ("1--2", "l") \
        ("a---b", "l") \
        ("x-y", "l") \
        ("?" + Q + "x", "l") \
        ("!" + Q + "y", "l") \
        ("?" + uchar(8216) + "z", "l") \
        (uchar(8211) + "-", "l") \
        ("-" + uchar(8212), "l") \
        ("1" + uchar(8211) + "2", "l") \
        ("! x ?", "l") \
        ("--", "-"))
}

string colvector _osl_e_lig()
{
    string scalar Q
    Q = char(96)
    return(_osl_top() \
        "\begin{table}[htbp]" \
        "\centering" \
        ("\caption{A-{}-B ?{}" + Q + "C}") \
        "\label{tab:osl_lig}" \
        "\begin{tabular}{lc}" \
        "\toprule" \
        "Input & L \\" \
        "\midrule" \
        "1-{}-2 & l \\" \
        "a-{}-{}-b & l \\" \
        "x-y & l \\" \
        ("?{}" + Q + "x & l \\") \
        ("!{}" + Q + "y & l \\") \
        ("?{}" + Q + "z & l \\") \
        "--{}- & l \\" \
        "-{}--- & l \\" \
        "1--2 & l \\" \
        "! x ? & l \\" \
        "-{}- & - \\" \
        "\bottomrule" \
        "\end{tabular}" \
        "\end{table}")
}

// L18: cells that need RFC 4180 quoting, and the exact CSV bytes.
string matrix _osl_x_csvbrk()
{
    string scalar DQ, CR, LF
    DQ = char(34)
    CR = char(13)
    LF = char(10)
    return(("plain", "v") \
        ("a,b", "v") \
        ("say " + DQ + "hi" + DQ, "v") \
        ("l1" + LF + "l2", "v") \
        ("l1" + CR + LF + "l2", "v") \
        ("l1" + CR + "l2", "v") \
        ("  lead", "v") \
        ("x," + LF + "y", "v") \
        (DQ + "q" + DQ + LF + "z", "v") \
        (LF, "only") \
        ("w", "p" + LF + "q"))
}

string scalar _osl_e_csvbrk()
{
    string scalar DQ, CR, LF
    DQ = char(34)
    CR = char(13)
    LF = char(10)
    return("plain,v" + LF +
        DQ + "a,b" + DQ + ",v" + LF +
        DQ + "say " + DQ + DQ + "hi" + DQ + DQ + DQ + ",v" + LF +
        DQ + "l1" + LF + "l2" + DQ + ",v" + LF +
        DQ + "l1" + CR + LF + "l2" + DQ + ",v" + LF +
        DQ + "l1" + CR + "l2" + DQ + ",v" + LF +
        "  lead,v" + LF +
        DQ + "x," + LF + "y" + DQ + ",v" + LF +
        DQ + DQ + DQ + "q" + DQ + DQ + LF + "z" + DQ + ",v" + LF +
        DQ + LF + DQ + ",only" + LF +
        "w," + DQ + "p" + LF + "q" + DQ + LF)
}

// Whole file as one string (every byte, line endings included).
string scalar _osl_bytes(string scalar path)
{
    real scalar fh, n
    string scalar s
    fh = fopen(path, "r")
    fseek(fh, 0, 1)
    n = ftell(fh)
    fseek(fh, 0, -1)
    s = (n > 0 ? fread(fh, n) : "")
    fclose(fh)
    return(s)
}

// Do v1, v2 (as read back by import delimited) equal X cell for cell?
real scalar _osl_cells_equal(string matrix X)
{
    string matrix G
    real scalar i, j, bad
    if (st_nobs() != rows(X)) {
        printf("{err}rows read back: %f, expected %f\n", st_nobs(), rows(X))
        return(0)
    }
    G = st_sdata(., ("v1", "v2"))
    bad = 0
    for (i = 1; i <= rows(X); i++) {
        for (j = 1; j <= 2; j++) {
            if (G[i, j] != X[i, j]) {
                printf("{err}cell (%f,%f) differs: bytes %s vs expected %s\n", i, j,
                    invtokens(strofreal(ascii(G[i, j]))), invtokens(strofreal(ascii(X[i, j]))))
                bad++
            }
        }
    }
    return(bad == 0)
}

// L19: title -> expected \caption text.
string matrix _osl_cap()
{
    string scalar EN, EM
    EN = uchar(8211)
    EM = uchar(8212)
    return(("Table 1. Baseline Characteristics", "Baseline Characteristics") \
        ("Table 2: price & weight", "price \& weight") \
        ("table S1 - Sensitivity", "Sensitivity") \
        ("TABLE A2 " + EN + " Appendix", "Appendix") \
        ("Table 2a " + EM + " Subgroups", "Subgroups") \
        ("Table 3.   Spaces", "Spaces") \
        ("Table 4:Tight", "Tight") \
        ("Table of outcomes", "Table of outcomes") \
        ("Tables 1 and 2", "Tables 1 and 2") \
        ("Table 1 shows", "Table 1 shows") \
        ("Table 1.2 Results", "Table 1.2 Results") \
        ("Table 1", "Table 1") \
        ("Table 1-x", "Table 1-x") \
        ("My Table 1. Data", "My Table 1. Data") \
        ("Table 1.", "Table 1.") \
        ("Table S2:", "Table S2:") \
        ("Table 1 -- Results", "Results") \
        ("Table 2 --- Results", "Results") \
        ("Table 3 - Results", "Results"))
}

// L20: stub-only rows.
string matrix _osl_x_stub()
{
    return(("Var", "A", "B") \
        ("Age", "1", "2") \
        ("Log-rank test: chi2(1) = 28.27, p < 0.001", "", "") \
        ("  Indented note", "", "") \
        ("Bold note", "", "") \
        ("  Bold indented", "", "") \
        ("", "x", "") \
        ("", "", "") \
        ("[ref] note", "", ""))
}

string colvector _osl_e_stub()
{
    return(_osl_top() \
        "\begin{table}[htbp]" \
        "\centering" \
        "\begin{tabular}{lcc}" \
        "\toprule" \
        "Var & A & B \\" \
        "\midrule" \
        "Age & 1 & 2 \\" \
        "\multicolumn{3}{l}{Log-rank test: chi2(1) = 28.27, p \textless{} 0.001} \\" \
        "\multicolumn{3}{l}{\hspace*{1em}Indented note} \\" \
        "\multicolumn{3}{l}{\textbf{Bold note}} \\" \
        "\multicolumn{3}{l}{\hspace*{1em}\textbf{Bold indented}} \\" \
        " & x &  \\" \
        "\addlinespace" \
        "\multicolumn{3}{l}{[ref] note} \\" \
        "\bottomrule" \
        "\end{tabular}" \
        "\end{table}")
}

// L21: newly mapped characters, one per row: (input, expected cell).
string matrix _osl_sym()
{
    string scalar S
    S = char(39)
    return(("a" + uchar(8194) + "b", "a\enspace{}b") \
        ("a" + uchar(8195) + "b", "a\quad{}b") \
        ("10" + uchar(8201) + "000", "10\,000") \
        ("10" + uchar(8202) + "000", "10\,000") \
        ("10" + uchar(8239) + "000", "10\,000") \
        ("x" + uchar(8242) + " y" + uchar(8243), "x\ensuremath{" + S + "} y\ensuremath{" + S + S + "}") \
        (uchar(8734) + " " + uchar(8727) + " " + uchar(8730) + "2", "\ensuremath{\infty} \ensuremath{\ast} \ensuremath{\surd}2") \
        ("5" + uchar(8240), "5\textperthousand{}") \
        (uchar(189) + uchar(188) + uchar(190), "\textonehalf{}\textonequarter{}\textthreequarters{}") \
        (uchar(174) + uchar(8482) + uchar(169), "\textregistered{}\texttrademark{}\textcopyright{}") \
        (uchar(172) + "p " + uchar(182) + "2", "\ensuremath{\neg}p \P{}2") \
        (uchar(8658) + uchar(8593) + uchar(8595) + uchar(8596), "\ensuremath{\Rightarrow}\ensuremath{\uparrow}\ensuremath{\downarrow}\ensuremath{\leftrightarrow}") \
        (uchar(8723) + "1 " + uchar(8801) + " " + uchar(8733), "\ensuremath{\mp}1 \ensuremath{\equiv} \ensuremath{\propto}") \
        ("z" + uchar(8203) + "w" + uchar(65279), "zw") \
        ("-" + uchar(8203) + "-", "-{}-"))
}

// "kind<TAB>text" needle lines for check_latex.py --needles.
string colvector _osl_needles(string scalar kind, string colvector texts)
{
    return(kind + char(9) :+ texts)
}

end

**# L0. The checker fails known-bad files

capture noisily {
    local f "`output_dir'/osl_checker_good.tex"
    mata: _osl_put(st_local("f"), _osl_min("x & 1 \\"))
    _osl_check "`f'" --compile --tables 1 --cols 2 --header-rows 1 --body-rows 1 --spans none

    local f "`output_dir'/osl_checker_bad1.tex"
    mata: _osl_put(st_local("f"), _osl_min("x & 50% \\"))
    _osl_check_fails "`f'"
    local f "`output_dir'/osl_checker_bad2.tex"
    mata: _osl_put(st_local("f"), _osl_min("x & 1 & 2 \\"))
    _osl_check_fails "`f'"
    local f "`output_dir'/osl_checker_bad3.tex"
    mata: _osl_put(st_local("f"), _osl_min("x & 1 \\" \ "\cmidrule(lr){2-2}"))
    _osl_check_fails "`f'"
    local f "`output_dir'/osl_checker_bad4.tex"
    mata: _osl_put(st_local("f"), _osl_min("x & a" + char(36) + "b \\"))
    _osl_check_fails "`f'"
    local f "`output_dir'/osl_checker_bad5.tex"
    mata: _osl_put(st_local("f"), _osl_min("x & 1 \\" \ "\addlinespace"))
    _osl_check_fails "`f'"
    * structurally clean but not compilable under pdflatex (Cyrillic)
    * a raw ~ or " never comes from the writer
    local f "`output_dir'/osl_checker_bad7.tex"
    mata: _osl_put(st_local("f"), _osl_min("x & a~b \\"))
    _osl_check_fails "`f'"
    local f "`output_dir'/osl_checker_bad8.tex"
    mata: _osl_put(st_local("f"), _osl_min("x & say " + char(34) + "hi" + char(34) + " \\"))
    _osl_check_fails "`f'"
    local f "`output_dir'/osl_checker_bad6.tex"
    mata: _osl_put(st_local("f"), _osl_min("x & " + uchar(1046) + " \\"))
    _osl_check "`f'"
    _osl_check_fails "`f'" --compile
    * the good file with a wrong expectation
    local f "`output_dir'/osl_checker_good.tex"
    _osl_check_fails "`f'" --cols 3
    _osl_check_fails "`f'" --spans 1:1-2
    _osl_check_fails "`f'" --pdftext "not in the table"
}
if _rc == 0 {
    display as result "  PASS: L0 check_latex.py rejects unescaped specials, bad counts, stray rules, uncompilable text"
    local ++pass_count
}
else {
    display as error "  FAIL: L0 checker self-test (rc=`=_rc')"
    local ++fail_count
}

**# L1. Layout: caption, header block, spanner, rules, indentation, notes

capture noisily {
    local f "`output_dir'/osl_layout.tex"
    _osl_seed_text "`f'"
    mata: _osl_load(_osl_x_layout())
    _tabtools_latex_write using "`f'", headerstart(2) datastart(4) spans(2 2 4) ///
        title("Hazard ratios") footnote("Note one. \ Note two.")
    assert r(n_rows) == 2
    assert r(n_cols) == 4
    assert `"`r(latex)'"' == "`f'"
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_e_layout())))
    assert `ok'
    local nf "`output_dir'/osl_layout.needles"
    mata: _osl_put(st_local("nf"), _osl_needles("pdftext", ("Table 1: Hazard ratios" \ ///
        "Model 1" \ "95% CI" \ "<0.001" \ "1.01" + uchar(8211) + "1.03" \ "Note two.")))
    _osl_check "`f'" --compile --tables 1 --cols 4 --header-rows 2 --body-rows 2 ///
        --spans 1:2-4 --needles "`nf'" --pdf-out "`output_dir'/osl_layout.pdf" ///
        --text-out "`output_dir'/osl_layout.txt"
}
if _rc == 0 {
    display as result "  PASS: L1 spec layout: caption/label, spanner+cmidrule, midrule, indent, addlinespace, notes; compiles"
    local ++pass_count
}
else {
    display as error "  FAIL: L1 layout (rc=`=_rc')"
    local ++fail_count
}

**# L2. ASCII specials, line breaks, row-start guards, caption and note

capture noisily {
    local f "`output_dir'/osl_ascii.tex"
    capture erase "`f'"
    mata: _osl_load(_osl_x_ascii())
    mata: st_local("t", _osl_t_ascii())
    mata: st_local("fn", _osl_f_ascii())
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) ///
        title(`"`macval(t)'"') footnote(`"`macval(fn)'"')
    assert r(n_rows) == 18
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_e_ascii())))
    assert `ok'
    local nf "`output_dir'/osl_ascii.needles"
    mata: _osl_put(st_local("nf"), _osl_needles("pdftext", ("a" + char(92) + "b" \ ///
        "{x}" \ char(36) + "5" \ "A&B" \ "#1" \ "50%" \ "<5" \ ">5" \ "a|b" \ ///
        "l1 l2 l3 l4" \ "[ref] x" \ "* p<0.05" \ uchar(8805) + "5" \ ///
        "F: 50%" \ char(36) + "x" \ "[r] *s")))
    _osl_check "`f'" --compile --cols 2 --header-rows 1 --body-rows 18 --spans none ///
        --needles "`nf'"

    * The row-start guard after \toprule (no header block) and after
    * \addlinespace: "[" and "*" must not be eaten as optional arguments.
    local f2 "`output_dir'/osl_guard.tex"
    mata: _osl_load(("[first]", "1") \ ("", "") \ ("*second", "2"))
    _tabtools_latex_write using "`f2'", novarnames datastart(1)
    mata: st_local("ok", strofreal(_osl_eq(st_local("f2"), _osl_top() \ ///
        "\begin{table}[htbp]" \ "\centering" \ "\begin{tabular}{lc}" \ "\toprule" \ ///
        "{}[first] & 1 \\" \ "\addlinespace" \ "{}*second & 2 \\" \ ///
        "\bottomrule" \ "\end{tabular}" \ "\end{table}")))
    assert `ok'
    _osl_check "`f2'" --compile --pdftext "[first]" --pdftext "*second"
}
if _rc == 0 {
    display as result "  PASS: L2 every ASCII special, CR/LF, tab, guards, caption and note escape and compile"
    local ++pass_count
}
else {
    display as error "  FAIL: L2 ASCII escaping (rc=`=_rc')"
    local ++fail_count
}

**# L2b. Ligatures in data text are broken: text renders as typed

capture noisily {
    local f "`output_dir'/osl_lig.tex"
    capture erase "`f'"
    mata: _osl_load(_osl_x_lig())
    local t = "A--B ?" + char(96) + "C"
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) title(`"`macval(t)'"')
    assert r(n_rows) == 11
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_e_lig())))
    assert `ok'
    * two hyphens stay two hyphens; an en dash from U+2013 stays an en dash;
    * no inverted question or exclamation mark appears
    local nf "`output_dir'/osl_lig.needles"
    mata: _osl_put(st_local("nf"), ///
        _osl_needles("pdftext", ("1--2" \ "a---b" \ "x-y" \ ///
            "?" + uchar(8216) + "x" \ "!" + uchar(8216) + "y" \ "?" + uchar(8216) + "z" \ ///
            uchar(8211) + "-" \ "-" + uchar(8212) \ "1" + uchar(8211) + "2" \ ///
            "A--B ?" + uchar(8216) + "C")) \ ///
        _osl_needles("pdftext-absent", (uchar(191) \ uchar(161))))
    _osl_check "`f'" --compile --body-rows 11 --needles "`nf'" ///
        --text-out "`output_dir'/osl_lig.txt"
}
if _rc == 0 {
    display as result "  PASS: L2b data --, ---, ?` and !` render as typed; U+2013/U+2014 keep their dashes"
    local ++pass_count
}
else {
    display as error "  FAIL: L2b ligature breaks (rc=`=_rc')"
    local ++fail_count
}

**# L3. Unicode map and Latin-1 pass-through

capture noisily {
    local f "`output_dir'/osl_unicode.tex"
    capture erase "`f'"
    mata: _osl_load(_osl_x_unicode())
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2)
    assert r(n_rows) == 17
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_e_unicode())))
    assert `ok'
    * Text that pdftotext extracts as the source character. The rest is
    * drawn from math/symbol fonts whose glyph names extract differently
    * (not-equal as a combining overlay, Delta as U+2206, degree as a ring
    * operator, the ellipsis as ". . .", dagger/bullet not at all); those
    * were inspected on a rendered page.
    local nf "`output_dir'/osl_unicode.needles"
    mata: _osl_put(st_local("nf"), _osl_needles("pdftext", ( ///
        uchar(177) + "1" \ "2" + uchar(215) + "3" \ "6" + uchar(247) + "2" \ ///
        "1" + uchar(8211) + "2" \ "a" + uchar(8212) + "b" \ ///
        uchar(8805) + "5" \ uchar(8804) + "5" \ uchar(8776) + "1" \ ///
        uchar(945) + uchar(946) + uchar(947) \ uchar(920) + uchar(923) \ ///
        uchar(8216) + "q" + uchar(8217) \ uchar(8220) + "qq" + uchar(8221) \ ///
        uchar(229) + uchar(228) + uchar(246) + uchar(233))))
    _osl_check "`f'" --compile --cols 2 --body-rows 17 --needles "`nf'" ///
        --pdf-out "`output_dir'/osl_unicode.pdf" --text-out "`output_dir'/osl_unicode.txt"
}
if _rc == 0 {
    display as result "  PASS: L3 Unicode map (math, super/subscripts, dashes, Greek, quotes, NBSP, symbols) and Latin-1 compile"
    local ++pass_count
}
else {
    display as error "  FAIL: L3 Unicode map (rc=`=_rc')"
    local ++fail_count
}

**# L4. Macro-shaped text is written literally

capture noisily {
    local f "`output_dir'/osl_macro.tex"
    capture erase "`f'"
    global OSL_SENTINEL "EXPANDED"
    mata: _osl_load(_osl_x_macro())
    mata: st_varlabel("c1", char(96) + "lab" + char(39))
    local t = char(96) + "T" + char(39) + " " + char(36) + "OSL_SENTINEL"
    local fn = "note " + char(96) + "n" + char(96) + " end " + char(36) + "HOME"
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) ///
        title(`"`macval(t)'"') footnote(`"`macval(fn)'"')
    local wrc = _rc
    global OSL_SENTINEL
    assert `wrc' == 0
    assert r(n_rows) == 7
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_e_macro())))
    assert `ok'
    local nf "`output_dir'/osl_macro.needles"
    mata: _osl_put(st_local("nf"), ///
        _osl_needles("pdftext", (char(36) + "HOME" \ char(36) + "{HOME}" \ ///
            "=1+1" \ "SENTINEL")) \ ///
        _osl_needles("pdftext-absent", "EXPANDED") \ ///
        _osl_needles("absent", "EXPANDED"))
    _osl_check "`f'" --compile --body-rows 7 --needles "`nf'" ///
        --text-out "`output_dir'/osl_macro.txt"
}
if _rc == 0 {
    display as result "  PASS: L4 local-macro quotes, dollar words, an unbalanced backtick are literal; no r(132)"
    local ++pass_count
}
else {
    display as error "  FAIL: L4 macro-shaped text (rc=`=_rc')"
    local ++fail_count
}

**# L5. Header fallback, strictheaders, novarnames, no header block

capture noisily {
    local f "`output_dir'/osl_fallback.tex"
    mata: _osl_load(_osl_x_fallback())
    label variable c1 "Stub label"
    label variable c3 "Third"
    * empty last-header cells: variable label, then variable name
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2)
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_e_fallback("Stub label & c2 & Given \\"))))
    assert `ok'
    _osl_check "`f'" --compile --header-rows 1
    * strictheaders: empty stays empty
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) strictheaders
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_e_fallback(" &  & Given \\"))))
    assert `ok'
    _osl_check "`f'" --compile --header-rows 1
    * novarnames: no header block, \toprule then the body
    _tabtools_latex_write using "`f'", datastart(2) novarnames
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_e_fallback(""))))
    assert `ok'
    _osl_check "`f'" --compile --header-rows 0
    * headerstart() >= datastart(): no header block either
    _tabtools_latex_write using "`f'", headerstart(2) datastart(2)
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_e_fallback(""))))
    assert `ok'
    * two header rows: the fallback applies to the last one only
    mata: _osl_load(("", "Top", "") \ ("", "", "Given") \ ("r1", "1", "2"))
    label variable c1 "Stub label"
    _tabtools_latex_write using "`f'", headerstart(1) datastart(3)
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_top() \ ///
        "\begin{table}[htbp]" \ "\centering" \ "\begin{tabular}{lcc}" \ "\toprule" \ ///
        " & Top &  \\" \ "Stub label & c2 & Given \\" \ "\midrule" \ ///
        "r1 & 1 & 2 \\" \ "\bottomrule" \ "\end{tabular}" \ "\end{table}")))
    assert `ok'
    _osl_check "`f'" --compile --header-rows 2 --spans none
}
if _rc == 0 {
    display as result "  PASS: L5 last-header fallback (label, then name), strictheaders, novarnames, hs>=ds"
    local ++pass_count
}
else {
    display as error "  FAIL: L5 header fallback (rc=`=_rc')"
    local ++fail_count
}

**# L6. Blank rows: \addlinespace, keepblank, and the Markdown row count

capture noisily {
    local f "`output_dir'/osl_blank.tex"
    local md "`output_dir'/osl_blank.md"
    clear
    quietly set obs 7
    generate strL c1 = ""
    generate double c2 = .
    label variable c2 "Val"
    quietly replace c1 = "Hdr" in 1
    quietly replace c1 = "A" in 3
    quietly replace c2 = 1 in 3
    quietly replace c1 = "B" in 6
    quietly replace c2 = 2 in 6
    * leading, interior (a run of two) and trailing blank rows
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2)
    local tex_rows = r(n_rows)
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_top() \ ///
        "\begin{table}[htbp]" \ "\centering" \ "\begin{tabular}{lc}" \ "\toprule" \ ///
        "Hdr & Val \\" \ "\midrule" \ "A & 1 \\" \ "\addlinespace" \ "B & 2 \\" \ ///
        "\bottomrule" \ "\end{tabular}" \ "\end{table}")))
    assert `ok'
    _osl_check "`f'" --compile --body-rows 2
    quietly _tabtools_markdown_write using "`md'", headerstart(1) datastart(2)
    assert `tex_rows' == 2 & r(n_rows) == 2

    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) keepblank
    local tex_rows = r(n_rows)
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_top() \ ///
        "\begin{table}[htbp]" \ "\centering" \ "\begin{tabular}{lc}" \ "\toprule" \ ///
        "Hdr & Val \\" \ "\midrule" \ "& \\" \ "A & 1 \\" \ "& \\" \ "& \\" \ ///
        "B & 2 \\" \ "& \\" \ "\bottomrule" \ "\end{tabular}" \ "\end{table}")))
    assert `ok'
    _osl_check "`f'" --compile --body-rows 6
    quietly _tabtools_markdown_write using "`md'", headerstart(1) datastart(2) keepblank
    assert `tex_rows' == 6 & r(n_rows) == 6

    * the L1 table: 2 body rows in both writers
    mata: _osl_load(_osl_x_layout())
    quietly _tabtools_latex_write using "`f'", headerstart(2) datastart(4) spans(2 2 4)
    local tex_rows = r(n_rows)
    quietly _tabtools_markdown_write using "`md'", headerstart(2) datastart(4)
    assert `tex_rows' == r(n_rows) & `tex_rows' == 2
}
if _rc == 0 {
    display as result "  PASS: L6 blank rows collapse to \addlinespace (edges dropped); keepblank rows; counts = Markdown's"
    local ++pass_count
}
else {
    display as error "  FAIL: L6 blank rows (rc=`=_rc')"
    local ++fail_count
}

**# L7. boldrows() and L8. numeric cells

capture noisily {
    local f "`output_dir'/osl_bold.tex"
    mata: _osl_load(("Var", "A", "B") \ ("Age", "1", "") \ ("  Male", "2", "3"))
    * row 1 is a header row: boldrows() applies to body rows only
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) boldrows(1 3)
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_top() \ ///
        "\begin{table}[htbp]" \ "\centering" \ "\begin{tabular}{lcc}" \ "\toprule" \ ///
        "Var & A & B \\" \ "\midrule" \ "Age & 1 &  \\" \ ///
        "\hspace*{1em}\textbf{Male} & \textbf{2} & \textbf{3} \\" \ ///
        "\bottomrule" \ "\end{tabular}" \ "\end{table}")))
    assert `ok'
    _osl_check "`f'" --compile --body-rows 2
}
if _rc == 0 {
    display as result "  PASS: L7 boldrows() bolds non-empty body cells, indent outside the bold"
    local ++pass_count
}
else {
    display as error "  FAIL: L7 boldrows (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    local f "`output_dir'/osl_numeric.tex"
    clear
    quietly set obs 5
    generate strL c1 = ""
    generate double c2 = .
    generate double c3 = .
    format c2 %6.2f
    format c3 %12.0fc
    label variable c2 "Est"
    label variable c3 "N"
    quietly replace c1 = "Row" in 1
    quietly replace c1 = "a" in 2
    quietly replace c2 = -0.001 in 2
    quietly replace c3 = 1234567 in 2
    quietly replace c1 = "b" in 3
    quietly replace c2 = 1.5 in 3
    quietly replace c3 = -0.4 in 3
    quietly replace c1 = "c" in 4
    quietly replace c1 = "d" in 5
    quietly replace c2 = -1.234 in 5
    quietly replace c3 = .a in 5
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2)
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_top() \ ///
        "\begin{table}[htbp]" \ "\centering" \ "\begin{tabular}{lcc}" \ "\toprule" \ ///
        "Row & Est & N \\" \ "\midrule" \ "a & 0.00 & 1,234,567 \\" \ ///
        "b & 1.50 & 0 \\" \ "\multicolumn{3}{l}{c} \\" \ "d & -1.23 &  \\" \ ///
        "\bottomrule" \ "\end{tabular}" \ "\end{table}")))
    assert `ok'
    _osl_check "`f'" --compile --body-rows 4
}
if _rc == 0 {
    display as result "  PASS: L8 numeric cells use the display format, -0 cleanup, missing (.a) blank"
    local ++pass_count
}
else {
    display as error "  FAIL: L8 numeric cells (rc=`=_rc')"
    local ++fail_count
}

**# L9. Caption, label and append numbering

capture noisily {
    local f "`output_dir'/osl lab+el.tex"
    capture erase "`f'"
    mata: _osl_load(("H", "V") \ ("r", "1"))
    * no title: neither \caption nor \label
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2)
    mata: st_local("l3", cat(st_local("f"))[4])
    assert `"`l3'"' == "\begin{tabular}{lc}"
    mata: st_local("n", strofreal(sum(strpos(cat(st_local("f")), "\caption") :> 0) + sum(strpos(cat(st_local("f")), "\label") :> 0)))
    assert `n' == 0
    * a blank title is no title
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) title("   ")
    mata: st_local("n", strofreal(sum(strpos(cat(st_local("f")), "\caption") :> 0)))
    assert `n' == 0
    * title: caption + label from the file stem (space and + become -)
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) title("First")
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) title("Second") append
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) append
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) title("Fourth") append
    * each caption is followed by its label; tables are separated by one
    * blank line
    mata: L = cat(st_local("f"))
    mata: C = ("\caption{First}", "\label{tab:osl-lab-el}") \ ///
        ("\caption{Second}", "\label{tab:osl-lab-el-2}") \ ///
        ("\caption{Fourth}", "\label{tab:osl-lab-el-4}")
    mata: st_local("ok", strofreal(sum((L[|1 \ rows(L) - 1|] :== C[1, 1]) :& (L[|2 \ rows(L)|] :== C[1, 2])) == 1 & ///
        sum((L[|1 \ rows(L) - 1|] :== C[2, 1]) :& (L[|2 \ rows(L)|] :== C[2, 2])) == 1 & ///
        sum((L[|1 \ rows(L) - 1|] :== C[3, 1]) :& (L[|2 \ rows(L)|] :== C[3, 2])) == 1 & ///
        sum(L :== "") == 3 & sum(strpos(L, "\label") :> 0) == 3))
    assert `ok'
    _osl_check "`f'" --compile --tables 4 --absent "tab:osl-lab-el-3" ///
        --absent "tab:osl-lab-el-1" --pdftext "Table 3: Fourth"
    mata: st_local("l1", cat(st_local("f"))[1])
    assert `"`l1'"' == "% tabtools LaTeX table; requires \usepackage{booktabs}"

    * append to a file that does not exist: created, bare label, no blank
    * first line; a non-ASCII stem character becomes -
    local g = "`output_dir'/osl_" + uchar(229) + "new.tex"
    capture erase "`g'"
    _tabtools_latex_write using "`g'", headerstart(1) datastart(2) title("New") append
    mata: st_local("ok", strofreal(cat(st_local("g"))[1] == _osl_top() & cat(st_local("g"))[5] == "\label{tab:osl_-new}"))
    assert `ok'
    _osl_check "`g'" --compile --tables 1
    * without append, an existing file is replaced
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) title("Only")
    _osl_check "`f'" --compile --tables 1 --contains "\label{tab:osl-lab-el}"
}
if _rc == 0 {
    display as result "  PASS: L9 caption only with title, label tab:<stem>, append numbering -n, replace by default"
    local ++pass_count
}
else {
    display as error "  FAIL: L9 caption/label/append (rc=`=_rc')"
    local ++fail_count
}

**# L10. Footnote paragraphs

capture noisily {
    local f "`output_dir'/osl_notes.tex"
    mata: _osl_load(("H", "V") \ ("r", "1"))
    local fn = "p<0.05; 50% \ " + char(36) + "x_1" + char(36) + " \  \ last"
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) ///
        title("A & B: 95% CI <0.05") footnote(`"`macval(fn)'"')
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_top() \ ///
        "\begin{table}[htbp]" \ "\centering" \ ///
        "\caption{A \& B: 95\% CI \textless{}0.05}" \ "\label{tab:osl_notes}" \ ///
        "\begin{tabular}{lc}" \ "\toprule" \ "H & V \\" \ "\midrule" \ "r & 1 \\" \ ///
        "\bottomrule" \ "\end{tabular}" \ "\par\smallskip" \ ///
        "{\footnotesize\raggedright" \ "p\textless{}0.05; 50\%\par" \ ///
        char(92) + char(36) + "x\_1" + char(92) + char(36) + "\par" \ "last\par}" \ ///
        "\end{table}")))
    assert `ok'
    _osl_check "`f'" --compile --pdftext "p<0.05; 50%" --pdftext "last"
    * one paragraph; an all-empty note is no note block
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) footnote("Only note.")
    mata: st_local("ok", strofreal(sum(cat(st_local("f")) :== "Only note.\par}") == 1))
    assert `ok'
    _osl_check "`f'" --compile
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) footnote(" \ ")
    mata: st_local("n", strofreal(sum(strpos(cat(st_local("f")), "footnotesize") :> 0)))
    assert `n' == 0
    _osl_check "`f'" --compile
}
if _rc == 0 {
    display as result `"  PASS: L10 footnote splits on " \ ", drops empty pieces, escapes each paragraph"'
    local ++pass_count
}
else {
    display as error "  FAIL: L10 footnote paragraphs (rc=`=_rc')"
    local ++fail_count
}

**# L11. spans(): declared spanners and every refusal

capture noisily {
    local f "`output_dir'/osl_spans.tex"
    mata: _osl_load(_osl_x_spans(0))
    * repeated text in a spanned cell ("Model 2" twice) is accepted
    _tabtools_latex_write using "`f'", headerstart(1) datastart(3) spans(1 2 3 1 4 5)
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_e_spans(0))))
    assert `ok'
    * "(ref)" opens the row under the \cmidrule line
    _osl_check "`f'" --compile --header-rows 2 --spans "1:2-3,1:4-5" ///
        --pdftext "Model 1" --pdftext "Model 2" --pdftext "(ref)" ///
        --pdf-out "`output_dir'/osl_spans.pdf"
    * a span in the last header row: \multicolumn without \cmidrule
    mata: _osl_load(_osl_x_spans(1))
    _tabtools_latex_write using "`f'", headerstart(1) datastart(3) spans(1 2 3 1 4 5 2 2 3)
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_e_spans(1))))
    assert `ok'
    _osl_check "`f'" --compile --spans "1:2-3,1:4-5,2:2-3" --pdftext "Both"
    * no spans(): blank upper cells stay blank, nothing is inferred
    mata: _osl_load(_osl_x_spans(0))
    _tabtools_latex_write using "`f'", headerstart(1) datastart(3)
    _osl_check "`f'" --compile --spans none ///
        --contains " & Model 1 &  & Model 2 & Model 2 \\"
}
if _rc == 0 {
    display as result "  PASS: L11 declared spans: multicolumn, cmidrule under non-final rows only, none inferred"
    local ++pass_count
}
else {
    display as error "  FAIL: L11 spans layouts (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    local f "`output_dir'/osl_spans_refused.tex"
    _osl_seed_text "`f'"
    mata: _osl_load(_osl_x_spans(0))
    local w _tabtools_latex_write using "`f'", headerstart(1) datastart(3)
    _osl_refused "`f'" "spans() takes triples (row c1 c2); 2 numbers were given" ///
        `w' spans(1 2)
    _osl_refused "`f'" "spans() triple (3 2 3): row 3 is not a header row (1 to 2)" ///
        `w' spans(3 2 3)
    _osl_refused "`f'" "spans() triple (1 4 6): columns must satisfy 1 <= c1 <= c2 <= 5" ///
        `w' spans(1 4 6)
    _osl_refused "`f'" "spans() triple (1 3 2): columns must satisfy" ///
        `w' spans(1 3 2)
    _osl_refused "`f'" "spans() triple (1 3 4) overlaps spans() triple (1 2 3) in row 1" ///
        `w' spans(1 2 3 1 3 4)
    _osl_refused "`f'" "spans() triple (1 2 3) overlaps spans() triple (1 2 3) in row 1" ///
        `w' spans(1 2 3 1 2 3)
    _osl_refused "`f'" "spans() triple (1 2 4): column 4 of row 1 is not blank and differs from the spanned text in column 2" ///
        `w' spans(1 2 4)
    _osl_refused "`f'" "spans() triple (1 1 2): column 2 of row 1 is not blank" ///
        `w' spans(1 1 2)
    _osl_refused "`f'" "spans() triple (2 2 3): column 3 of row 2 is not blank" ///
        `w' spans(2 2 3)
    _osl_refused "`f'" "spans() triple (1 2 3): the table has no header rows" ///
        _tabtools_latex_write using "`f'", datastart(3) novarnames spans(1 2 3)
    * a valid triple next to a bad one: still nothing written
    _osl_refused "`f'" "spans() triple (1 4 6)" `w' spans(1 2 3 1 4 6)
    * zero is outside the numlist range syntax accepts (rc 125)
    _osl_sum "`f'"
    local s0 "`r(sum)'"
    capture noisily `w' spans(0 2 3)
    assert _rc == 125
    _osl_sum "`f'"
    assert "`r(sum)'" == "`s0'"
    mata: st_local("ok", strofreal(cat(st_local("f")) == "KEEP THIS TEXT"))
    assert `ok'
}
if _rc == 0 {
    display as result "  PASS: L11 bad/overlapping/non-header/non-blank spans refused r(198) naming the triple; target intact"
    local ++pass_count
}
else {
    display as error "  FAIL: L11 spans refusals (rc=`=_rc')"
    local ++fail_count
}

**# L12. A failed write leaves the target and no staging file

capture noisily {
    local d "`output_dir'/osl_fail"
    shell chmod -R u+w "`d'" 2>/dev/null; rm -rf "`d'"
    mkdir "`d'"
    local t "`d'/target.tex"
    _osl_seed_text "`t'"
    mata: _osl_load(("A", "B") \ ("r1", "v1") \ ("r2", "v2"))
    local w _tabtools_latex_write using "`t'", headerstart(1) datastart(2)
    * a spans() refusal
    _osl_failwrite "`d'" "`t'" `w' spans(1 1 2) title("x")
    * read-only target: replace and append
    shell chmod 444 "`t'"
    _osl_failwrite "`d'" "`t'" `w' title("F")
    _osl_failwrite "`d'" "`t'" `w' title("F") append
    * read-only target in a read-only directory
    shell chmod 555 "`d'"
    _osl_failwrite "`d'" "`t'" `w'
    _osl_failwrite "`d'" "`t'" `w' append
    shell chmod 755 "`d'"
    shell chmod 644 "`t'"
    * the target is a directory
    mkdir "`d'/dir.tex"
    _osl_failwrite "`d'" "`t'" _tabtools_latex_write using "`d'/dir.tex", headerstart(1) datastart(2)
    local inside : dir "`d'/dir.tex" files "*"
    assert `"`inside'"' == ""
    * control: the same call on a writable target replaces it
    `w' title("F")
    mata: st_local("ok", strofreal(cat(st_local("t"))[4] == "\caption{F}"))
    assert `ok'
    _osl_check "`t'" --compile
}
local l12_rc = _rc
capture shell chmod -R u+w "`output_dir'/osl_fail"
if `l12_rc' == 0 {
    display as result "  PASS: L12 failed LaTeX writes leave the target and no staging file"
    local ++pass_count
}
else {
    display as error "  FAIL: L12 failed LaTeX write (rc=`l12_rc')"
    local ++fail_count
}

**# L13. Extension and path refusals

capture noisily {
    mata: _osl_load(("A", "B") \ ("r1", "v1"))
    foreach bad in "osl_ext.md" "osl_ext.tex.bak" "osl_ext.txt" {
        local f "`output_dir'/`bad'"
        _osl_seed_text "`f'"
        _osl_refused "`f'" "latex() must specify a .tex file" ///
            _tabtools_latex_write using "`f'", headerstart(1) datastart(2)
        mata: st_local("ok", strofreal(cat(st_local("f")) == "KEEP THIS TEXT"))
        assert `ok'
    }
    local f "`output_dir'/osl_ext_absent.md"
    capture erase "`f'"
    _osl_refused "`f'" "latex() must specify a .tex file" ///
        _tabtools_latex_write using "`f'", headerstart(1) datastart(2)
    confirm new file "`f'"
    * shell metacharacters in the path
    local f "`output_dir'/osl;bad.tex"
    _osl_refused "`f'" "latex() contains invalid characters" ///
        _tabtools_latex_write using "`f'", headerstart(1) datastart(2)
    confirm new file "`f'"
    * the extension is case-insensitive
    local f "`output_dir'/osl_ext_upper.TEX"
    capture erase "`f'"
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2)
    _osl_check "`f'" --compile
}
if _rc == 0 {
    display as result "  PASS: L13 non-.tex and metacharacter paths refused r(198) before writing; .TEX accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: L13 extension refusals (rc=`=_rc')"
    local ++fail_count
}

**# L14. Same-file refusal across xlsx/csv/markdown/latex

capture noisily {
    local s "`output_dir'/osl_same.tex"
    _osl_seed_text "`s'"
    _osl_refused "`s'" "markdown() and latex() name the same file" ///
        _tabtools_check_sinks, markdown("`s'") latex("`s'")
    _osl_refused "`s'" "csv() and latex() name the same file" ///
        _tabtools_check_sinks, csv("`s'") latex("`s'")
    _osl_refused "`s'" "xlsx() and latex() name the same file" ///
        _tabtools_check_sinks, xlsx("`s'") latex("`s'")
    _osl_refused "`s'" "using and latex() name the same file" ///
        _tabtools_check_sinks, xlsx("`s'") latex("`s'") xlsxname("using")
    * different spellings of one file
    quietly cd "`output_dir'"
    capture noisily {
        capture mkdir "osl_sub"
        _osl_refused "`s'" "markdown() and latex() name the same file" ///
            _tabtools_check_sinks, markdown("./osl_sub/../osl_same.tex") latex("`s'")
        _osl_refused "`s'" "csv() and latex() name the same file" ///
            _tabtools_check_sinks, csv("OSL_SAME.TEX") latex("osl_same.tex")
    }
    local inner = _rc
    quietly cd "`qa_dir'"
    assert `inner' == 0
    * latex() must name a .tex file, even with no other sink
    _osl_refused "" "latex() must specify a .tex file" ///
        _tabtools_check_sinks, latex("osl_x.md")
    * distinct files pass
    _tabtools_check_sinks, xlsx("a.xlsx") csv("a.csv") markdown("a.md") latex("a.tex")
    _tabtools_check_sinks, latex("A.TEX")
    _tabtools_check_sinks, xlsx("x/a.tex") latex("y/a.tex")
    mata: st_local("ok", strofreal(cat(st_local("s")) == "KEEP THIS TEXT"))
    assert `ok'
}
if _rc == 0 {
    display as result "  PASS: L14 latex() refused against xlsx()/using, csv(), markdown() spellings of one file"
    local ++pass_count
}
else {
    display as error "  FAIL: L14 same-file refusal (rc=`=_rc')"
    local ++fail_count
}

**# L15. tabtools set/query/clear latex and the session plumbing

capture noisily {
    quietly tabtools set clear
    local sess "`output_dir'/osl_sess.tex"
    local other "`output_dir'/osl_other.tex"
    _osl_seed_text "`sess'"
    capture erase "`other'"
    mata: _osl_load(("H", "V") \ ("r", "1"))

    * refusals: wrong extension, no value, permanent, two paths
    _osl_refused "" "the file must have a .tex extension" tabtools set latex "osl.md"
    _osl_refused "" "requires a value" tabtools set latex
    _osl_refused "" "is a session setting and is not saved to a profile" ///
        tabtools set latex "`sess'", permanent
    _osl_refused "" "takes one path" tabtools set latex "`sess'" "`other'"
    tabtools query
    assert `"`r(latex)'"' == "" & "`r(latex_fresh)'" == ""

    tabtools set latex "`sess'"
    assert `"`r(latex)'"' == "`sess'"
    tabtools query
    assert `"`r(latex)'"' == "`sess'" & "`r(latex_fresh)'" == "1"
    assert `"`r(markdown)'"' == "" & "`r(markdown_fresh)'" == ""
    _osl_console tabtools query
    assert strpos(`"`r(text)'"', "LaTeX:") > 0
    assert strpos(`"`r(text)'"', "next write replaces it") > 0

    * resolve: the session fills an empty latex(); an explicit one wins
    _tabtools_set_sinks resolve, latex("") noxlsx
    assert `"`_ss_tex'"' == "`sess'" & "`_ss_tex_sess'" == "1" & "`_ss_texappend'" == ""
    assert `"`_ss_md'"' == "" & "`_ss_md_sess'" == "0"
    _tabtools_set_sinks resolve, latex("`other'") noxlsx
    assert `"`_ss_tex'"' == "`other'" & "`_ss_tex_sess'" == "0" & "`_ss_texappend'" == ""
    _tabtools_set_sinks resolve, latex("`other'") texappend noxlsx
    assert "`_ss_texappend'" == "texappend"

    * a write to another file leaves the session flag armed
    _tabtools_latex_write using "`other'", headerstart(1) datastart(2)
    tabtools query
    assert "`r(latex_fresh)'" == "1"

    * first session write replaces the seeded file
    _tabtools_latex_write using "`sess'", headerstart(1) datastart(2) title("S1")
    tabtools query
    assert "`r(latex_fresh)'" == "0"
    _tabtools_set_sinks resolve, noxlsx
    assert `"`_ss_tex'"' == "`sess'" & "`_ss_texappend'" == "texappend"
    * a later session write appends
    _tabtools_latex_write using "`sess'", headerstart(1) datastart(2) title("S2") append
    _osl_check "`sess'" --compile --tables 2 --absent "KEEP THIS TEXT" ///
        --contains "\label{tab:osl_sess-2}"

    * setting the same file again is a no-op; clearing then re-setting a file
    * this session wrote never re-arms "replace"
    tabtools set latex "`sess'"
    tabtools query
    assert "`r(latex_fresh)'" == "0"
    tabtools set latex clear
    assert "`r(action)'" == "cleared" & "`r(key)'" == "latex"
    tabtools query
    assert `"`r(latex)'"' == "" & "`r(latex_fresh)'" == ""
    _tabtools_set_sinks resolve, noxlsx
    assert `"`_ss_tex'"' == "" & "`_ss_tex_sess'" == "0" & "`_ss_texappend'" == ""
    tabtools set latex "`sess'"
    tabtools query
    assert "`r(latex_fresh)'" == "0"

    * texappend with no latex() and no session target: resolve hands back an
    * empty path with texappend set, which each command refuses
    * ("texappend requires latex()"; tested per command in wave 2)
    tabtools set latex clear
    _tabtools_set_sinks resolve, texappend noxlsx
    assert `"`_ss_tex'"' == "" & "`_ss_texappend'" == "texappend"

    * the session LaTeX and Markdown targets are independent
    local smd "`output_dir'/osl_sess.md"
    capture erase "`smd'"
    tabtools set markdown "`smd'"
    tabtools set latex "`other'"
    tabtools query
    assert `"`r(markdown)'"' == "`smd'" & `"`r(latex)'"' == "`other'"
    _tabtools_latex_write using "`other'", headerstart(1) datastart(2)
    tabtools query
    assert "`r(markdown_fresh)'" == "1"

    * tabtools set clear removes the LaTeX target with the rest
    tabtools set clear
    tabtools query
    assert `"`r(latex)'"' == "" & `"`r(markdown)'"' == ""
    assert `"$TABTOOLS_set_latex"' == "" & `"$TABTOOLS_set_latex_fresh"' == ""

    * unknown keys list latex and texopts among the valid ones
    _osl_refused "" "workbook, markdown, latex, texopts, headershade, smallcells" ///
        tabtools set bogus x
    _osl_refused "" "Valid: workbook, markdown, latex, texopts, headershade, smallcells" ///
        _tabtools_set set bogus clear
}
local l15_rc = _rc
quietly tabtools set clear
if `l15_rc' == 0 {
    display as result "  PASS: L15 tabtools set/query/clear latex; resolve, texdone, first-write-replaces"
    local ++pass_count
}
else {
    display as error "  FAIL: L15 session LaTeX (rc=`l15_rc')"
    local ++fail_count
}

**# L16. Body cells agree with the CSV writer

capture noisily {
    foreach case in layout ascii unicode lig {
        local f "`output_dir'/osl_par_`case'.tex"
        local c "`output_dir'/osl_par_`case'.csv"
        mata: _osl_load(_osl_x_`case'())
        if "`case'" == "layout" {
            _tabtools_latex_write using "`f'", headerstart(2) datastart(4) spans(2 2 4)
            local rows "4:"
        }
        else {
            _tabtools_latex_write using "`f'", headerstart(1) datastart(2)
            local rows "2:"
        }
        _tabtools_csv_write using "`c'"
        _osl_check "`f'" --parity-csv "`c'" --csv-rows `rows'
    }
}
if _rc == 0 {
    display as result "  PASS: L16 de-escaped LaTeX body cells equal the CSV writer's, row for row"
    local ++pass_count
}
else {
    display as error "  FAIL: L16 CSV parity (rc=`=_rc')"
    local ++fail_count
}

**# L18. CSV writer: a cell with a line break is one RFC 4180 quoted field
* _tabtools_csv_write wrote CR and LF raw, so such a cell split its row.
* Cells with a comma or a double quote were already quoted; cells with none
* of these must keep their exact bytes.

capture noisily {
    local c "`output_dir'/osl_csv_breaks.csv"
    capture erase "`c'"
    mata: _osl_load(_osl_x_csvbrk())
    _tabtools_csv_write using "`c'"
    mata: st_local("ok", strofreal(_osl_bytes(st_local("c")) == _osl_e_csvbrk()))
    if !`ok' {
        mata: printf("{err}CSV bytes: %s\n", invtokens(strofreal(ascii(_osl_bytes(st_local("c"))))))
    }
    assert `ok'
    * an independent parser reads back 11 rows and every cell. Stata's
    * reader folds a CRLF inside a quoted field to CR (the file holds CR LF,
    * pinned by the byte check above), so the expectation does too.
    import delimited using "`c'", clear varnames(nonames) bindquote(strict) ///
        stringcols(_all) delimiters(",") encoding("utf-8")
    mata: st_local("ok", strofreal(_osl_cells_equal( ///
        subinstr(_osl_x_csvbrk(), char(13) + char(10), char(13)))))
    assert `ok'
    * no line break anywhere: byte-identical to export delimited itself
    local c2 "`output_dir'/osl_csv_plain.csv"
    local c3 "`output_dir'/osl_csv_plain_ref.csv"
    mata: _osl_load(_osl_x_csvbrk()[(1, 2, 3, 7), .])
    _tabtools_csv_write using "`c2'"
    quietly export delimited c1 c2 using "`c3'", replace novarnames
    mata: st_local("ok", strofreal(_osl_bytes(st_local("c2")) == _osl_bytes(st_local("c3"))))
    assert `ok'
}
if _rc == 0 {
    display as result "  PASS: L18 CSV cells with CR/LF are quoted fields that read back exactly; other cells unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: L18 CSV line-break quoting (rc=`=_rc')"
    local ++fail_count
}

**# L19. The caption drops one leading table-number prefix

capture noisily {
    local f "`output_dir'/osl_cap.tex"
    mata: _osl_load(("H", "V") \ ("r", "1"))
    mata: st_local("ncap", strofreal(rows(_osl_cap())))
    forvalues i = 1/`ncap' {
        mata: st_local("t", _osl_cap()[`i', 1])
        _tabtools_latex_write using "`f'", headerstart(1) datastart(2) title(`"`macval(t)'"')
        mata: st_local("ok", strofreal(cat(st_local("f"))[4] == "\caption{" + _osl_cap()[`i', 2] + "}" & ///
            cat(st_local("f"))[5] == "\label{tab:osl_cap}"))
        if !`ok' {
            mata: display("  title [" + _osl_cap()[`i', 1] + "] -> [" + cat(st_local("f"))[4] + "]", 1)
        }
        assert `ok'
        _osl_check "`f'" --compile
    }
    * LaTeX supplies the number: one "Table 1:" in the PDF, not two
    mata: st_local("t", _osl_cap()[1, 1])
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) title(`"`macval(t)'"')
    _osl_check "`f'" --compile --pdftext "Table 1: Baseline Characteristics" ///
        --pdftext-absent "Table 1: Table 1"
}
if _rc == 0 {
    display as result "  PASS: L19 caption strips one Table <id>. / : / dash prefix; other titles and a bare prefix unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: L19 caption table-number prefix (rc=`=_rc')"
    local ++fail_count
}

**# L20. A row with text in column 1 only spans the row

capture noisily {
    local f "`output_dir'/osl_stub.tex"
    local c "`output_dir'/osl_stub.csv"
    local md "`output_dir'/osl_stub.md"
    mata: _osl_load(_osl_x_stub())
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) boldrows(5 6)
    local tex_rows = r(n_rows)
    assert `tex_rows' == 7
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_e_stub())))
    assert `ok'
    quietly _tabtools_markdown_write using "`md'", headerstart(1) datastart(2)
    assert r(n_rows) == `tex_rows'
    _tabtools_csv_write using "`c'"
    _osl_check "`f'" --compile --cols 3 --body-rows 7 --parity-csv "`c'" --csv-rows 2: ///
        --pdftext "Log-rank test: chi2(1) = 28.27, p < 0.001" ///
        --pdf-out "`output_dir'/osl_stub.pdf"
    * one column: no \multicolumn
    mata: _osl_load(("H") \ ("only text") \ ("  indented"))
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2)
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_top() \ ///
        "\begin{table}[htbp]" \ "\centering" \ "\begin{tabular}{l}" \ "\toprule" \ ///
        "H \\" \ "\midrule" \ "only text \\" \ "\hspace*{1em}indented \\" \ ///
        "\bottomrule" \ "\end{tabular}" \ "\end{table}")))
    assert `ok'
    _osl_check "`f'" --compile --cols 1
}
if _rc == 0 {
    display as result "  PASS: L20 stub-only rows (plain, indented, bold) span as multicolumn{k}{l}; one-column table unchanged; parity"
    local ++pass_count
}
else {
    display as error "  FAIL: L20 stub-only rows (rc=`=_rc')"
    local ++fail_count
}

**# L21. Spaces, primes, symbols, arrows, signs; zero-width characters

capture noisily {
    local f "`output_dir'/osl_sym.tex"
    local c "`output_dir'/osl_sym.csv"
    mata: X = _osl_sym()
    mata: _osl_load(("Input", "S") \ (X[., 1], J(rows(X), 1, "s")))
    * in the caption too (a moving argument)
    local t = "Sym " + uchar(8734) + uchar(8201) + uchar(8482) + " x" + uchar(8242)
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) title(`"`macval(t)'"')
    assert r(n_rows) == 15
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_top() \ ///
        "\begin{table}[htbp]" \ "\centering" \ ///
        ("\caption{Sym \ensuremath{\infty}\,\texttrademark{} x\ensuremath{" + char(39) + "}}") \ ///
        "\label{tab:osl_sym}" \ "\begin{tabular}{lc}" \ "\toprule" \ "Input & S \\" \ ///
        "\midrule" \ (X[., 2] :+ " & s \\") \ "\bottomrule" \ "\end{tabular}" \ "\end{table}")))
    assert `ok'
    _tabtools_csv_write using "`c'"
    local nf "`output_dir'/osl_sym.needles"
    mata: _osl_put(st_local("nf"), _osl_needles("pdftext", ( ///
        "x" + uchar(8242) \ uchar(8734) \ uchar(8727) \ uchar(8730) \ ///
        uchar(189) + uchar(188) + uchar(190) \ uchar(174) \ uchar(169) \ ///
        uchar(172) + "p" \ uchar(182) + "2" \ ///
        uchar(8658) + uchar(8593) + uchar(8595) + uchar(8596) \ ///
        uchar(8723) + "1" \ uchar(8801) \ uchar(8733) \ "zw" \ "--")))
    _osl_check "`f'" --compile --body-rows 15 --needles "`nf'" ///
        --parity-csv "`c'" --csv-rows 2: --pdf-out "`output_dir'/osl_sym.pdf" ///
        --text-out "`output_dir'/osl_sym.txt"
}
if _rc == 0 {
    display as result "  PASS: L21 new spaces/primes/symbols/arrows/signs compile under the minimal preamble; zero-width dropped"
    local ++pass_count
}
else {
    display as error "  FAIL: L21 symbol map (rc=`=_rc')"
    local ++fail_count
}

**# L22. Double quotes and quote pairs render as typed

capture noisily {
    local f "`output_dir'/osl_quotes.tex"
    local c "`output_dir'/osl_quotes.csv"
    mata: _osl_load(("Input", "Q") \ ///
        ("say " + char(34) + "hi" + char(34), "q") \ ///
        ("it" + char(39) + char(39) + "s", "q") \ ///
        (char(96) + char(96) + "x", "q") \ ///
        (char(96) + "one" + char(39), "q") \ ///
        (uchar(8220) + "curly" + uchar(8221), "q"))
    local t = "Q " + char(34) + "x" + char(34)
    _tabtools_latex_write using "`f'", headerstart(1) datastart(2) title(`"`macval(t)'"')
    mata: st_local("ok", strofreal(_osl_eq(st_local("f"), _osl_top() \ ///
        "\begin{table}[htbp]" \ "\centering" \ ///
        ("\caption{Q \texttt{" + char(34) + "}x\texttt{" + char(34) + "}}") \ "\label{tab:osl_quotes}" \ ///
        "\begin{tabular}{lc}" \ "\toprule" \ "Input & Q \\" \ "\midrule" \ ///
        ("say \texttt{" + char(34) + "}hi\texttt{" + char(34) + "} & q \\") \ ///
        ("it" + char(39) + "{}" + char(39) + "s & q \\") \ ///
        (char(96) + "{}" + char(96) + "x & q \\") \ ///
        (char(96) + "one" + char(39) + " & q \\") \ ///
        (char(96) + char(96) + "curly" + char(39) + char(39) + " & q \\") \ ///
        "\bottomrule" \ "\end{tabular}" \ "\end{table}")))
    assert `ok'
    _tabtools_csv_write using "`c'"
    * straight double quotes; two apostrophes are two marks, not a curly
    * double quote; a curly quote typed as such stays one
    local nf "`output_dir'/osl_quotes.needles"
    mata: _osl_put(st_local("nf"), _osl_needles("pdftext", ( ///
        "say " + char(34) + "hi" + char(34) \ "Q " + char(34) + "x" + char(34) \ ///
        "it" + uchar(8217) + uchar(8217) + "s" \ uchar(8216) + uchar(8216) + "x" \ ///
        uchar(8216) + "one" + uchar(8217) \ uchar(8220) + "curly" + uchar(8221))))
    _osl_check "`f'" --compile --needles "`nf'" --parity-csv "`c'" --csv-rows 2: ///
        --text-out "`output_dir'/osl_quotes.txt"
}
if _rc == 0 {
    display as result "  PASS: L22 double quote is straight; quote pairs stay two marks; single quotes typographic"
    local ++pass_count
}
else {
    display as error "  FAIL: L22 quotes (rc=`=_rc')"
    local ++fail_count
}

**# L23. labelvar(), datastart() and headerstart() refusals

capture noisily {
    local f "`output_dir'/osl_bounds.tex"
    _osl_seed_text "`f'"
    mata: _osl_load(("H", "V", "W") \ ("r1", "1", "2") \ ("r2", "3", "4"))
    * labelvar() naming no variable: r(111), nothing written
    _osl_sum "`f'"
    local s0 "`r(sum)'"
    _osl_console _tabtools_latex_write using "`f'", labelvar(ZZ) headerstart(1) datastart(2) spans(1 2 3)
    assert r(rc) == 111
    assert strpos(`"`r(text)'"', "labelvar(): variable ZZ not found") > 0
    _osl_sum "`f'"
    assert "`r(sum)'" == "`s0'"
    * an existing labelvar() is accepted
    generate strL A = c1
    _tabtools_latex_write using "`f'", labelvar(A) headerstart(1) datastart(2)
    _osl_check "`f'" --compile --cols 4
    drop A
    _osl_seed_text "`f'"
    * datastart() past N + 1, headerstart() after datastart()
    _osl_refused "`f'" "datastart(5) is beyond the last observation (3)" ///
        _tabtools_latex_write using "`f'", headerstart(1) datastart(5)
    _osl_refused "`f'" "headerstart(3) is after datastart(2)" ///
        _tabtools_latex_write using "`f'", headerstart(3) datastart(2)
    * datastart(N + 1): a header-only table; novarnames ignores headerstart()
    _tabtools_latex_write using "`f'", headerstart(1) datastart(4)
    assert r(n_rows) == 0
    _osl_check "`f'" --compile --header-rows 3 --body-rows 0
    _tabtools_latex_write using "`f'", novarnames datastart(1)
    _osl_check "`f'" --compile --header-rows 0 --body-rows 3
}
if _rc == 0 {
    display as result "  PASS: L23 missing labelvar() r(111); datastart() > N+1 and headerstart() > datastart() r(198); target intact"
    local ++pass_count
}
else {
    display as error "  FAIL: L23 bounds refusals (rc=`=_rc')"
    local ++fail_count
}

**# L17. The same contracts through puttab latex()
* Pins, through a real command: texappend without latex() is r(198)
* "texappend requires latex()"; a .tex path given to another sink is refused
* with that file intact (the extension checks of using/csv()/markdown() come
* before the same-file comparison, so the pairwise collision itself is pinned
* in L14 on the helper); the session target is used, first write replaces,
* later writes append; r(latex), r(latex_rows) == r(markdown_rows),
* r(latex_cols). The full layout contract lives in test_latex_direct.do.
capture noisily {
    local f "`output_dir'/osl_puttab.tex"
    local m "`output_dir'/osl_puttab.md"
    local s "`output_dir'/osl_puttab_same.tex"
    sysuse auto, clear
    _osl_refused "" "texappend requires latex()" ///
        puttab make price in 1/3, markdown("`m'") texappend
    _osl_seed_text "`s'"
    _osl_refused "`s'" "markdown() must specify" ///
        puttab make price in 1/3, markdown("`s'") latex("`f'")
    _osl_refused "`s'" "csv() must have a .csv extension" ///
        puttab make price in 1/3, csv("`s'") latex("`f'")
    _osl_refused "`s'" "using file must have a .xlsx extension" ///
        puttab make price in 1/3 using "`s'", latex("`f'")
    quietly puttab make price in 1/3, latex("`f'") markdown("`m'")
    assert `"`r(latex)'"' == "`f'"
    assert r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == 2
    _osl_check "`f'" --compile
    tabtools set latex "`s'"
    quietly puttab make price in 1/3
    quietly puttab make price in 4/6
    _osl_check "`s'" --compile --tables 2 --absent "KEEP THIS TEXT"
    quietly tabtools set clear
}
local l17rc = _rc
quietly tabtools set clear
if `l17rc' == 0 {
    display as result "  PASS: L17 puttab latex(): refusals, returns, session sink"
    local ++pass_count
}
else {
    display as error "  FAIL: L17 puttab latex() (rc=`l17rc')"
    local ++fail_count
}

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_output_sinks_latex tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _osl
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_output_sinks_latex tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _osl
