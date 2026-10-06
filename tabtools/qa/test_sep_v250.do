* test_sep_v250.do - the interval separator contract (help tabtools##sep)
* in every command that takes sep() or cisep(), in every sink it writes
*
* Contract: the separator is read as Stata reads a string option, printed
* byte for byte (never expanded, never handed to collect), the default ", "
* when omitted or empty; the limits are never read back from the printed text.
*
* Separators: the default, ", ", " to ", "-", ";", an en dash, " - " with en
* dash, "", a long text, $name (a global that is set), a lone backquote, a
* backquote pair, `name' (a local that is set), a double quote, " ~|~ "
* (holding regtab's and effecttab's private delimiter), "%", "(", ",", " (".
*
* Oracles, none of them the code under test:
*   S1-S9   each sink of a run with separator S equals the same sink of the
*           default run with every "(lo, hi)" rewritten to "(lo" S "hi)" in
*           Mata (frames and workbooks cell by cell, CSV parsed here, the
*           Markdown text with S escaped by the Markdown rules, the console
*           log by search); numeric sinks (eplotframe) are unchanged
*   K1-K4   known answers: the limits from e(b)/e(V), a from() matrix, the
*           strate file, or a hand-computed binomial/Poisson limit, joined by
*           the separator as typed
*   D1-D7   the review defects: regtab's private delimiter in sep(), a $ with
*           every frame() form, backquotes, a double quote, the quote rule
*           (Stata's string-option rule in every command), the decimal-comma
*           refusal, a long separator
*   L1      a session holding an older tabtools's helpers reloads them
*   W1      default-separator storage widths, as read from 2.4.0
*   O1      outtab's console equals 2.4.0's string(40) list unless a data
*           cell is longer
*   C1      a decimal-comma format beside a comma separator: one warning,
*           rc 0, outside regtab and effecttab
* Comparisons run in Mata on st_local()/st_sdata() values, so the test never
* re-expands the text it checks.

clear all
set more off
set varabbrev off
version 17.0

capture log close _sp250
log using "test_sep_v250.log", replace text name(_sp250)

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
local facts_tool "`qa_dir'/tools/xlsx_facts.py"
local _sp_ls0 = c(linesize)
set linesize 255

* The global and local a separator names. Neither may ever reach a table.
global SP250_X "LEAKG"
local Y "LEAKL"

**# Mata: separators and oracles
mata:
mata set matastrict off
// the separators, built from character codes so nothing here is expanded
_SP_C = J(19, 1, "")
_SP_C[1] = ""
_SP_C[2] = ", "
_SP_C[3] = " to "
_SP_C[4] = "-"
_SP_C[5] = ";"
_SP_C[6] = uchar(8211)
_SP_C[7] = " " + uchar(8211) + " "
_SP_C[8] = ""
_SP_C[9] = " ... up to and including ... "
_SP_C[10] = char(36) + "SP250_X"
_SP_C[11] = char(96)
_SP_C[12] = char(96) + char(96)
_SP_C[13] = char(96) + "Y" + char(39)
_SP_C[14] = char(34)
_SP_C[15] = " ~|~ "
_SP_C[16] = "%"
_SP_C[17] = "("
_SP_C[18] = ","
_SP_C[19] = " ("
// D5: option forms as typed (after the name) and the text each prints
_SP_QF = ("( " + char(34) + " to " + char(34) + " )") \ ("( - )") \
    ("(" + char(34) + "a" + char(34) + " " + char(34) + "b" + char(34) + ")") \ ("(  a  b  )") \
    ("( " + char(96) + char(34) + "a" + char(34) + "b" + char(34) + char(39) + " )") \
    ("(" + char(34) + " a" + char(34) + " " + char(34) + "b " + char(34) + ")") \
    ("(" + char(96) + char(34) + char(34) + "to" + char(34) + char(34) + char(39) + ")") \
    ("( " + char(34) + char(34) + " )")
_SP_QS = (" to ") \ ("-") \ ("a b") \ ("a b") \ ("a" + char(34) + "b") \
    (" a b ") \ (char(34) + "to" + char(34)) \ (", ")
_SP_N = ("default", "comma", "to", "dash", "semicolon", "en dash", "spaced en dash",
    "empty", "long", "global", "backquote", "backquote pair", "local", "double quote",
    "private delimiter", "percent", "paren", "bare comma", "spaced paren")

// the separator a case prints: case 1 omits the option, case 8 is empty
string scalar _sp_sep(real scalar k)
{
    external string colvector _SP_C
    return(k == 1 | k == 8 ? ", " : _SP_C[k])
}

// name(text) as a user types it: simple quotes, compound quotes around a
// double quote; case 1 is the option left out
string scalar _sp_opt(string scalar name, real scalar k)
{
    external string colvector _SP_C
    if (k == 1) return("")
    if (strpos(_SP_C[k], char(34))) return(name + "(" + char(96) + char(34) + _SP_C[k] + char(34) + char(39) + ")")
    return(name + "(" + char(34) + _SP_C[k] + char(34) + ")")
}

// the command for case k: @SEP@ is the option, @D@ the case's file stem
string scalar _sp_cmd(string scalar tmpl, string scalar name, real scalar k, string scalar stem)
{
    return(subinstr(subinstr(tmpl, "@SEP@", _sp_opt(name, k)), "@D@", stem))
}

// every string cell of the current frame
string colvector _sp_strcells()
{
    real scalar j
    string colvector out
    out = J(0, 1, "")
    for (j = 1; j <= st_nvar(); j++) if (st_isstrvar(j)) out = out \ st_sdata(., j)
    return(out)
}

// column nw equals column od with its intervals joined by sep, and at least
// one interval was rewritten (or none, when sep is the default)
real scalar _sp_col(string colvector od, string colvector nw, string scalar sep, | real scalar dec)
{
    real scalar i, n
    if (args() < 4) dec = 0
    if (rows(od) != rows(nw)) return(0)
    n = 0
    for (i = 1; i <= rows(od); i++) {
        if (nw[i] != _sp_tr(od[i], sep, dec)) {
            printf("{err}got [%s], want [%s]\n", nw[i], _sp_tr(od[i], sep, dec))
            return(0)
        }
        n = n + (nw[i] != od[i])
    }
    return(sep == ", " ? 1 : n > 0)
}

// every default interval "(lo, hi)" (or "; lo, hi)") in s, its limits joined
// by sep instead; dec > 0 rewrites only limits with exactly dec decimals
string scalar _sp_tr(string scalar s, string scalar sep, | real scalar dec)
{
    string scalar out, rest, m, rx, num
    real scalar p
    if (args() < 3) dec = 0
    // a limit is a number, or "." where collect holds none
    num = dec ? "-?[0-9][0-9,]*[.][0-9]{" + strofreal(dec) + "}" : "(?:-?[0-9][0-9.,]*(?:e[+-][0-9]+)?|[.])"
    rx = "[(; ](" + num + "), (" + num + ")" + char(92) + ")"
    out = ""
    rest = s
    while (ustrregexm(rest, rx)) {
        m = ustrregexs(0)
        p = strpos(rest, m)
        out = out + substr(rest, 1, p - 1) + substr(m, 1, 1) + ustrregexs(1) + sep + ustrregexs(2) + ")"
        rest = substr(rest, p + strlen(m), .)
    }
    return(out + rest)
}

// the intervals of s rewritten with sep, as the console must show them
string colvector _sp_ivals(string scalar s, string scalar sep, | real scalar dec)
{
    string colvector out
    string scalar rest, m, rx, num
    real scalar p
    if (args() < 3) dec = 0
    num = dec ? "-?[0-9][0-9,]*[.][0-9]{" + strofreal(dec) + "}" : "(?:-?[0-9][0-9.,]*(?:e[+-][0-9]+)?|[.])"
    rx = "[(; ](" + num + "), (" + num + ")" + char(92) + ")"
    out = J(0, 1, "")
    rest = s
    while (ustrregexm(rest, rx)) {
        m = ustrregexs(0)
        p = strpos(rest, m)
        out = out \ (ustrregexs(1) + sep + ustrregexs(2) + ")")
        rest = substr(rest, p + strlen(m), .)
    }
    return(out)
}

// the Markdown writer's escapes, written out here
string scalar _sp_mdesc(string scalar x)
{
    real scalar i
    string rowvector c
    c = (char(92), "|", "*", "_", char(96), "<", ">", "&", "[", "]", "~")
    for (i = 1; i <= cols(c); i++) x = subinstr(x, c[i], char(92) + c[i])
    return(x)
}

// a CSV file as fields in reading order, char(30) closing each record
string colvector _sp_csv(string scalar path)
{
    string colvector out, L
    string scalar t, c, f
    real scalar i, n, q
    L = cat(path)
    t = invtokens(L', char(10))
    out = J(0, 1, "")
    f = ""
    q = 0
    n = strlen(t)
    for (i = 1; i <= n; i++) {
        c = substr(t, i, 1)
        if (q) {
            if (c == char(34)) {
                if (substr(t, i + 1, 1) == char(34)) {
                    f = f + c
                    i++
                }
                else q = 0
            }
            else f = f + c
        }
        else if (c == char(34)) q = 1
        else if (c == ",") {
            out = out \ f
            f = ""
        }
        else if (c == char(10)) {
            out = out \ f \ char(30)
            f = ""
        }
        else if (c != char(13)) f = f + c
    }
    return(out \ f \ char(30))
}

// all cells of frame fr: string cells as is, numbers as %21x
string matrix _sp_cells(string scalar fr)
{
    string scalar cur
    string matrix out
    real scalar i, j
    cur = st_framecurrent()
    st_framecurrent(fr)
    out = J(st_nobs(), st_nvar(), "")
    for (j = 1; j <= st_nvar(); j++) {
        if (st_isstrvar(j)) out[., j] = st_sdata(., j)
        else for (i = 1; i <= st_nobs(); i++) out[i, j] = strofreal(_st_data(i, j), "%21x")
    }
    out = st_varname(1..st_nvar()) \ out
    st_framecurrent(cur)
    return(out)
}

// new == old with every interval joined by sep; reports the first mismatch
// and returns the number of cells whose interval was rewritten
real scalar _sp_same(string matrix od, string matrix nw, string scalar sep, string scalar what, | real scalar dec)
{
    real scalar i, j, n
    string scalar want
    if (args() < 5) dec = 0
    if (rows(od) != rows(nw) | cols(od) != cols(nw)) {
        printf("{err}%s: %g x %g cells, the default run has %g x %g\n", what, rows(nw), cols(nw), rows(od), cols(od))
        return(-1)
    }
    n = 0
    for (i = 1; i <= rows(od); i++) {
        for (j = 1; j <= cols(od); j++) {
            want = _sp_tr(od[i, j], sep, dec)
            if (nw[i, j] != want) {
                printf("{err}%s [%g,%g]: got  [%s]\n", what, i, j, nw[i, j])
                printf("{err}%s [%g,%g]: want [%s]\n", what, i, j, want)
                return(-1)
            }
            n = n + (want != od[i, j])
        }
    }
    return(n)
}

// every interval of the default cells, joined by sep, appears in the log
real scalar _sp_console(string matrix od, string scalar logf, string scalar sep, | real scalar dec)
{
    string scalar t
    string colvector iv
    real scalar i, j, k, n
    if (args() < 4) dec = 0
    t = invtokens(cat(logf)', char(10))
    n = 0
    for (i = 2; i <= rows(od); i++) {
        for (j = 1; j <= cols(od); j++) {
            iv = _sp_ivals(od[i, j], sep, dec)
            for (k = 1; k <= rows(iv); k++) {
                if (!strpos(t, iv[k])) {
                    printf("{err}console: [%s] not printed\n", iv[k])
                    return(-1)
                }
                n++
            }
        }
    }
    return(n)
}
end

**# Helpers
* _sp_loop runs one command over every separator and compares each sink
* with the default run's. tmpl() holds the command, @SEP@ where the option
* goes and @D@ for the case's file stem. sinks(): frame (frame _sp_fr),
* flat (_sp_fl), eplot (_sp_ep), csv, md, xlsx (sheet S), console. dec() as
* in _sp_tr(). r(n_<sink>) counts the rewritten intervals (all cases).
capture program drop _sp_loop
program define _sp_loop, rclass
    version 17.0
    syntax , TAG(name) OPT(name) SINKS(string) TMPL(string) ///
        OUT(string) TOOL(string) [DEC(integer 0) CASES(numlist)]
    if "`cases'" == "" local cases "1/19"
    numlist "`cases'"
    local cases "`r(numlist)'"
    foreach s of local sinks {
        local n_`s' 0
    }
    foreach k of local cases {
        local stem "`out'/sp250_`tag'_`k'"
        mata: st_local("cmd", _sp_cmd(st_local("tmpl"), st_local("opt"), `k', st_local("stem")))
        foreach f in _sp_fr _sp_fl _sp_ep {
            capture frame drop `f'
        }
        foreach x in csv md xlsx log {
            capture erase "`stem'.`x'"
        }
        capture log close _spc
        quietly log using "`stem'.log", text replace name(_spc)
        capture noisily `macval(cmd)'
        local rc = _rc
        quietly log close _spc
        mata: st_local("cname", _SP_N[`k'])
        if `rc' {
            display as error "`tag': separator `k' (`cname') failed with r(`rc')"
            exit 9
        }
        if `k' == 1 {
            * the default run is the reference
            foreach s of local sinks {
                if inlist("`s'", "frame", "flat", "eplot") {
                    local f = cond("`s'" == "frame", "_sp_fr", cond("`s'" == "flat", "_sp_fl", "_sp_ep"))
                    confirm frame `f'
                    mata: _SP_REF_`s' = _sp_cells("`f'")
                }
                if "`s'" == "csv" mata: _SP_REF_csv = _sp_csv("`stem'.csv")
                if "`s'" == "md" mata: _SP_REF_md = cat("`stem'.md")
                if "`s'" == "xlsx" {
                    capture erase "`stem'.facts"
                    shell python3 "`tool'" "`stem'.xlsx" "S" "`stem'.facts"
                    mata: _SP_REF_xlsx = select(cat("`stem'.facts"), substr(cat("`stem'.facts"), 1, 6) :== "value ")
                }
            }
            continue
        }
        mata: st_local("sep", _sp_sep(`k'))
        foreach s of local sinks {
            local what "`tag' `s', separator `k' (`cname')"
            if inlist("`s'", "frame", "flat", "eplot") {
                local f = cond("`s'" == "frame", "_sp_fr", cond("`s'" == "flat", "_sp_fl", "_sp_ep"))
                confirm frame `f'
                mata: st_local("m", strofreal(_sp_same(_SP_REF_`s', _sp_cells("`f'"), st_local("sep"), st_local("what"), `dec')))
            }
            else if "`s'" == "csv" {
                mata: st_local("m", strofreal(_sp_same(_SP_REF_csv, _sp_csv("`stem'.csv"), st_local("sep"), st_local("what"), `dec')))
            }
            else if "`s'" == "md" {
                mata: st_local("m", strofreal(_sp_same(_SP_REF_md, cat("`stem'.md"), _sp_mdesc(st_local("sep")), st_local("what"), `dec')))
            }
            else if "`s'" == "xlsx" {
                capture erase "`stem'.facts"
                shell python3 "`tool'" "`stem'.xlsx" "S" "`stem'.facts"
                mata: st_local("m", strofreal(_sp_same(_SP_REF_xlsx, select(cat("`stem'.facts"), substr(cat("`stem'.facts"), 1, 6) :== "value "), st_local("sep"), st_local("what"), `dec')))
            }
            else if "`s'" == "console" {
                * the intervals of the default frame (or flat frame), joined
                * by the separator, are printed
                local src = cond(strpos(" `sinks' ", " frame "), "frame", "flat")
                mata: st_local("m", strofreal(_sp_console(_SP_REF_`src', "`stem'.log", st_local("sep"), `dec')))
            }
            if `m' < 0 exit 9
            * a case that prints a separator other than ", " rewrites cells;
            * eplotframe() holds numbers and must not change at all
            if "`s'" == "eplot" & `m' != 0 {
                display as error "`what': `m' eplotframe() cells changed"
                exit 9
            }
            local n_`s' = `n_`s'' + `m'
        }
    }
    foreach s of local sinks {
        display as text "  `tag' `s': `n_`s'' intervals rewritten"
        return scalar n_`s' = `n_`s''
    }
    foreach s in frame flat eplot csv md xlsx {
        capture mata: mata drop _SP_REF_`s'
    }
end

* the global the separators name is never changed or substituted
capture program drop _sp_noleak
program define _sp_noleak
    version 17.0
    if `"$SP250_X"' != "LEAKG" {
        display as error "global SP250_X was changed"
        exit 9
    }
end

**# S1 regtab: frame, eplotframe, CSV, Markdown, Excel, console
* A linear model (negative limits, so "-" sits next to a minus sign) and a
* logit (odds ratios); every separator against the default run.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress mpg weight i.foreign
    quietly collect: logit foreign mpg weight
    _sp_loop, tag(rA) opt(sep) out("`output_dir'") tool("`facts_tool'") ///
        sinks(frame eplot csv md xlsx console) ///
        tmpl(`"regtab, @SEP@ frame(_sp_fr, replace) eplotframe(_sp_ep, replace) csv("@D@.csv") markdown("@D@.md") xlsx("@D@.xlsx") sheet(S)"')
    * 16 separators print other than ", " (not cases 1, 2, 8): 6 intervals
    * in the frame, CSV and Excel, 4 Markdown lines; the console shows all
    * 18 cases' 6 intervals
    assert r(n_frame) == 16 * 6 & r(n_csv) == 16 * 6 & r(n_xlsx) == 16 * 6
    assert r(n_md) == 16 * 4 & r(n_console) == 18 * 6
    _sp_noleak
}
if _rc == 0 {
    display as result "  PASS: S1 regtab sep() byte for byte in frame, CSV, Markdown, Excel, console; eplotframe() unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: S1 regtab sep() sinks (rc=`=_rc')"
    local ++fail_count
}

**# S2 regtab: compact, stars, nopvalue, flat frame; transpose; cformat()
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress mpg weight i.foreign
    quietly collect: logit foreign mpg weight
    _sp_loop, tag(rB) opt(sep) out("`output_dir'") tool("`facts_tool'") sinks(flat console) ///
        tmpl(`"regtab, @SEP@ compact stars nopvalue frame(_sp_fl, replace flat)"')
    assert r(n_flat) == 16 * 6 & r(n_console) == 18 * 6
    _sp_loop, tag(rC) opt(sep) out("`output_dir'") tool("`facts_tool'") sinks(frame console) ///
        tmpl(`"regtab, @SEP@ transpose frame(_sp_fr, replace)"')
    assert r(n_frame) == 16 * 6 & r(n_console) == 18 * 6
    _sp_loop, tag(rD) opt(sep) out("`output_dir'") tool("`facts_tool'") sinks(frame eplot console) ///
        tmpl(`"regtab, @SEP@ cformat(%9.3f) frame(_sp_fr, replace) eplotframe(_sp_ep, replace)"')
    assert r(n_frame) == 16 * 6 & r(n_console) == 18 * 6
    _sp_noleak
}
if _rc == 0 {
    display as result "  PASS: S2 regtab sep() with compact/stars/nopvalue/flat, transpose, cformat()"
    local ++pass_count
}
else {
    display as error "  FAIL: S2 regtab sep() options (rc=`=_rc')"
    local ++fail_count
}

**# S3 effecttab: collected margins and a from() matrix
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress mpg weight foreign
    collect clear
    quietly collect: margins, dydx(weight foreign)
    _sp_loop, tag(eA) opt(sep) out("`output_dir'") tool("`facts_tool'") ///
        sinks(frame eplot csv md xlsx console) ///
        tmpl(`"effecttab, @SEP@ digits(3) frame(_sp_fr, replace) eplotframe(_sp_ep, replace) csv("@D@.csv") markdown("@D@.md") xlsx("@D@.xlsx") sheet(S)"')
    assert r(n_frame) == 16 * 2 & r(n_csv) == 16 * 2 & r(n_xlsx) == 16 * 2
    assert r(n_md) == 16 * 2 & r(n_console) == 18 * 2
    _sp_loop, tag(eB) opt(sep) out("`output_dir'") tool("`facts_tool'") sinks(flat) ///
        tmpl(`"effecttab, @SEP@ cformat(%9.4f) frame(_sp_fl, replace flat)"')
    assert r(n_flat) == 16 * 2
    matrix _SPE = (-1.5, -2.25, -0.75, 0.01 \ 0.5, -0.1, 1.1, 0.2 \ 1234.5, 1000.25, 1500.75, 0.03)
    matrix rownames _SPE = Neg Cross Big
    _sp_loop, tag(eC) opt(sep) out("`output_dir'") tool("`facts_tool'") sinks(frame console) ///
        tmpl(`"effecttab, from(_SPE) @SEP@ frame(_sp_fr, replace)"')
    assert r(n_frame) == 16 * 3 & r(n_console) == 18 * 3
    _sp_loop, tag(eD) opt(sep) out("`output_dir'") tool("`facts_tool'") sinks(flat) ///
        tmpl(`"effecttab, from(_SPE) cformat(%12.2fc) @SEP@ frame(_sp_fl, replace flat)"')
    assert r(n_flat) == 16 * 3
    matrix drop _SPE
    * a coefficient a constraint fixes: margins holds no limits for it, and
    * collect writes "." for both; the interval is "(., .)" as in 2.4.0, its
    * limits joined by sep(), never by the private delimiter
    sysuse auto, clear
    constraint 81 weight = -0.006
    quietly cnsreg mpg weight foreign, constraints(81)
    constraint drop 81
    collect clear
    quietly collect: margins, dydx(weight foreign)
    _sp_loop, tag(eF) opt(sep) out("`output_dir'") tool("`facts_tool'") sinks(frame console) ///
        tmpl(`"effecttab, @SEP@ frame(_sp_fr, replace)"')
    assert r(n_frame) == 16 * 2 & r(n_console) == 18 * 2
    _sp_noleak
}
if _rc == 0 {
    display as result "  PASS: S3 effecttab sep() byte for byte in every sink, margins and from()"
    local ++pass_count
}
else {
    display as error "  FAIL: S3 effecttab sep() sinks (rc=`=_rc')"
    local ++fail_count
}
capture matrix drop _SPE
capture constraint drop 81

**# S4 comptab: cisep() in the vertical layout, with cformat(), compact
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress mpg weight i.foreign
    quietly regtab, frame(_sp_m1, replace) eplotframe(_sp_m1e, replace)
    collect clear
    quietly collect: regress mpg weight length i.foreign
    quietly regtab, frame(_sp_m2, replace) eplotframe(_sp_m2e, replace)
    _sp_loop, tag(cA) opt(cisep) out("`output_dir'") tool("`facts_tool'") ///
        sinks(frame csv md xlsx console) ///
        tmpl(`"comptab _sp_m1 _sp_m2, rows(1 2 \ 1 2) @SEP@ frame(_sp_fr, replace) csv("@D@.csv") markdown("@D@.md") xlsx("@D@.xlsx") sheet(S)"')
    assert r(n_frame) == 16 * 3 & r(n_csv) == 16 * 3 & r(n_xlsx) == 16 * 3
    assert r(n_md) == 16 * 3 & r(n_console) == 18 * 3
    _sp_loop, tag(cB) opt(cisep) out("`output_dir'") tool("`facts_tool'") sinks(flat) ///
        tmpl(`"comptab _sp_m1 _sp_m2, rows(1 2 \ 1 2) cformat(%9.3f) @SEP@ frame(_sp_fl, replace flat)"')
    assert r(n_flat) == 16 * 3
    _sp_loop, tag(cC) opt(cisep) out("`output_dir'") tool("`facts_tool'") sinks(frame console) ///
        tmpl(`"comptab _sp_m1 _sp_m2, rows(1 2 \ 1 2) compact @SEP@ frame(_sp_fr, replace)"')
    assert r(n_frame) == 16 * 3 & r(n_console) == 18 * 3
    _sp_noleak
}
if _rc == 0 {
    display as result "  PASS: S4 comptab cisep() byte for byte (text rewrite, cformat(), compact)"
    local ++pass_count
}
else {
    display as error "  FAIL: S4 comptab cisep() (rc=`=_rc')"
    local ++fail_count
}

**# S5 comptab and hrcomptab keep the separator their sources hold
* regtab frames made with each sep() composed without cisep(); a rate frame
* made with ratetab sep() under hrcomptab; and hrcomptab cisep().
capture program drop _sp_cdcomp
program define _sp_cdcomp
    version 17.0
    syntax [, compact *]
    collect clear
    quietly collect: regress mpg weight i.foreign
    quietly regtab, `macval(options)' `compact' frame(_sp_s1, replace)
    collect clear
    quietly collect: regress mpg weight length i.foreign
    quietly regtab, `macval(options)' `compact' frame(_sp_s2, replace)
    comptab _sp_s1 _sp_s2, rows(1 2 \ 1 2) frame(_sp_fr, replace)
end
capture program drop _sp_hr
program define _sp_hr
    version 17.0
    syntax [, regsep(string asis) ratesep(string asis) compact *]
    preserve
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    generate byte agegrp = 1 + (age >= 55) + (age >= 60)
    label define agegrp 1 "<55" 2 "55-59" 3 "60+"
    label values agegrp agegrp
    quietly ratetab agegrp, outlabels("Death") frame(_sp_rates, replace) `macval(ratesep)'
    collect clear
    quietly collect: stcox i.agegrp drug
    quietly collect: stcox i.agegrp drug age
    quietly regtab, frame(_sp_models, replace) noint `compact' models("M1 \ M2") `macval(regsep)'
    restore
    hrcomptab _sp_rates, modelframes(_sp_models) rows(all) allmodels modelonly ///
        effect("Rate ratio") frame(_sp_fr, replace) `macval(options)'
end
local ++test_count
capture noisily {
    sysuse auto, clear
    _sp_loop, tag(cD) opt(sep) out("`output_dir'") tool("`facts_tool'") sinks(frame console) ///
        tmpl(`"_sp_cdcomp, @SEP@"')
    assert r(n_frame) == 16 * 3
    _sp_loop, tag(cE) opt(sep) out("`output_dir'") tool("`facts_tool'") sinks(frame console) ///
        tmpl(`"_sp_cdcomp, compact @SEP@"')
    assert r(n_frame) == 16 * 3
    * model intervals carry two decimals, rate intervals one
    _sp_loop, tag(hA) opt(sep) out("`output_dir'") tool("`facts_tool'") sinks(frame console) dec(2) ///
        tmpl(`"_sp_hr, compact regsep(@SEP@)"')
    assert r(n_frame) == 16 * 7
    _sp_loop, tag(hC) opt(sep) out("`output_dir'") tool("`facts_tool'") sinks(frame console) dec(2) ///
        tmpl(`"_sp_hr, regsep(@SEP@)"')
    assert r(n_frame) == 16 * 7
    _sp_loop, tag(hB) opt(cisep) out("`output_dir'") tool("`facts_tool'") sinks(frame console) dec(2) ///
        tmpl(`"_sp_hr, compact @SEP@"')
    assert r(n_frame) == 16 * 7
    _sp_loop, tag(hD) opt(sep) out("`output_dir'") tool("`facts_tool'") sinks(frame console) dec(1) ///
        tmpl(`"_sp_hr, compact ratesep(@SEP@)"')
    assert r(n_frame) == 16 * 3
    _sp_noleak
}
if _rc == 0 {
    display as result "  PASS: S5 comptab/hrcomptab pass a source sep() through; hrcomptab cisep()"
    local ++pass_count
}
else {
    display as error "  FAIL: S5 composed separators (rc=`=_rc')"
    local ++fail_count
}

**# S6 ratetab and stratetab
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    _sp_loop, tag(tA) opt(sep) out("`output_dir'") tool("`facts_tool'") ///
        sinks(frame csv md xlsx console) ///
        tmpl(`"ratetab drug, @SEP@ frame(_sp_fr, replace) csv("@D@.csv") markdown("@D@.md") xlsx("@D@.xlsx") sheet(S)"')
    assert r(n_frame) == 16 * 3 & r(n_csv) == 16 * 3 & r(n_xlsx) == 16 * 3
    assert r(n_md) == 16 * 3 & r(n_console) == 18 * 3
    _sp_loop, tag(tB) opt(sep) out("`output_dir'") tool("`facts_tool'") sinks(frame console) ///
        tmpl(`"ratetab drug, cformat(%9.3f) ci(poisson) @SEP@ frame(_sp_fr, replace)"')
    assert r(n_frame) == 16 * 3
    * stratetab on two strate files: rate and rate-ratio intervals
    local here "`c(pwd)'"
    * stratetab reads its files from the working directory; every path back
    * to the qa directory runs, the error path included
    quietly cd "`output_dir'"
    capture noisily {
        preserve
        quietly strate drug, per(1000) output(sp250_st_a, replace)
        restore
        preserve
        quietly strate drug if age >= 55, per(1000) output(sp250_st_b, replace)
        restore
        _sp_loop, tag(sA) opt(sep) out("`output_dir'") tool("`facts_tool'") ///
            sinks(frame csv md xlsx console) ///
            tmpl(`"stratetab, using(sp250_st_a sp250_st_b) outcomes(1) rateratio @SEP@ frame(_sp_fr, replace) csv("@D@.csv") markdown("@D@.md") xlsx("@D@.xlsx") sheet(S)"')
    }
    local src = _rc
    local n_sA = r(n_frame)
    quietly cd "`here'"
    if `src' exit `src'
    * six rates and four rate ratios
    assert `n_sA' == 16 * 9
    _sp_noleak
}
if _rc == 0 {
    display as result "  PASS: S6 ratetab and stratetab sep() byte for byte in every sink"
    local ++pass_count
}
else {
    display as error "  FAIL: S6 ratetab/stratetab sep() (rc=`=_rc')"
    local ++fail_count
}

**# S7 outtab
local ++test_count
capture noisily {
    sysuse auto, clear
    generate byte heavy = weight > 3000
    generate byte longc = length > 190
    _sp_loop, tag(oA) opt(sep) out("`output_dir'") tool("`facts_tool'") ///
        sinks(frame csv md xlsx console) ///
        tmpl(`"outtab foreign longc, exposure(heavy) estimator(regress) models("" \ mpg) @SEP@ frame(_sp_fr, replace) csv("@D@.csv") markdown("@D@.md") xlsx("@D@.xlsx") sheet(S)"')
    * 4 intervals on 2 Markdown lines
    assert r(n_frame) == 16 * 4 & r(n_csv) == 16 * 4 & r(n_xlsx) == 16 * 4
    assert r(n_md) == 16 * 2 & r(n_console) == 18 * 4
    _sp_noleak
}
if _rc == 0 {
    display as result "  PASS: S7 outtab sep() byte for byte in every sink (risk differences below zero)"
    local ++pass_count
}
else {
    display as error "  FAIL: S7 outtab sep() (rc=`=_rc')"
    local ++fail_count
}

**# S8 tabcell: r(cell), local(), global(), generate(), every form
capture program drop _sp_tc
program define _sp_tc
    version 17.0
    syntax anything(name=form) [, *]
    capture frame drop _sp_fr
    if "`form'" == "gen" {
        preserve
        clear
        quietly set obs 3
        generate double b = -1.5 + _n
        generate double l = b - 0.75
        generate double u = b + 0.75
        tabcell est, b(b) ll(l) ul(u) generate(g) `macval(options)'
        frame put g, into(_sp_fr)
        restore
        exit
    }
    * block if: a one-line if re-expands its command, macval() or not
    if "`form'" == "est" {
        tabcell est weight, format(%9.4f) local(_sp_L) global(SP250_G) `macval(options)'
    }
    if "`form'" == "np" {
        tabcell np, n(2) d(20) ci(exact) `macval(options)'
    }
    if "`form'" == "rate" {
        tabcell rate, e(12) pt(975.6) per(1000) `macval(options)'
    }
    if "`form'" == "iqr" {
        tabcell iqr, median(-2) q1(-5) q3(-1) `macval(options)'
    }
    if "`form'" == "num" {
        tabcell est, b(-1.5) ll(-2.25) ul(-0.75) `macval(options)'
    }
    * the stored cell as a one-row frame: r(cell), and for est the local()
    * and global() copies
    mata: _SP_CELL = st_global("r(cell)")
    if "`form'" == "est" {
        mata: _SP_CELL = _SP_CELL, st_local("_sp_L"), st_global("SP250_G")
        mata: assert(_SP_CELL[1] == _SP_CELL[2] & _SP_CELL[1] == _SP_CELL[3])
    }
    frame create _sp_fr strL(c1 c2 c3)
    frame _sp_fr {
        quietly set obs 1
        mata: st_sstore(1, (1..cols(_SP_CELL)), _SP_CELL)
    }
end
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress mpg weight foreign
    foreach f in est np rate iqr num gen {
        * generate() prints nothing; the others display the cell
        local sk = cond("`f'" == "gen", "frame", "frame console")
        _sp_loop, tag(k`f') opt(sep) out("`output_dir'") tool("`facts_tool'") sinks(`sk') ///
            tmpl(`"_sp_tc `f', @SEP@"')
        * est: r(cell), local() and global(); generate(): three rows
        local ni = cond(inlist("`f'", "est", "gen"), 3, 1)
        assert r(n_frame) == 16 * `ni'
        if "`f'" != "gen" assert r(n_console) == 18 * `ni'
    }
    capture macro drop SP250_G
    _sp_noleak
}
if _rc == 0 {
    display as result "  PASS: S8 tabcell sep() in r(cell), local(), global(), generate(); est, np, rate, iqr"
    local ++pass_count
}
else {
    display as error "  FAIL: S8 tabcell sep() (rc=`=_rc')"
    local ++fail_count
}
capture macro drop SP250_G
capture mata: mata drop _SP_CELL

**# K1 regtab known answer: limits from e(b)/e(V), sep("-") and sep(" ~|~ ")
* The logit's log-odds limits are both negative (an odds ratio below 1):
* regtab reads them below zero before it exponentiates. 2.4.0 left such
* intervals blank under sep("-").
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress mpg weight
    local lo1 = _b[weight] - invttail(e(df_r), 0.025) * _se[weight]
    local hi1 = _b[weight] + invttail(e(df_r), 0.025) * _se[weight]
    quietly logit foreign weight
    assert _b[weight] + invnormal(0.975) * _se[weight] < 0
    local lo2 = exp(_b[weight] - invnormal(0.975) * _se[weight])
    local hi2 = exp(_b[weight] + invnormal(0.975) * _se[weight])
    collect clear
    quietly collect: regress mpg weight
    quietly collect: logit foreign weight
    foreach k in 4 15 {
        mata: st_local("o", _sp_opt("sep", `k')); st_local("s", _SP_C[`k'])
        regtab, `macval(o)' cformat(%9.4f) frame(_sp_fr, replace) eplotframe(_sp_ep, replace)
        frame _sp_fr {
            quietly count if strtrim(A) == "Weight (lbs.)"
            assert r(N) == 1
            mata: _r = selectindex(strtrim(st_sdata(., "A")) :== "Weight (lbs.)")
            mata: assert(st_sdata(_r, "c2") == "(" + strtrim(strofreal(`lo1', "%9.4f")) + st_local("s") + strtrim(strofreal(`hi1', "%9.4f")) + ")")
            mata: assert(st_sdata(_r, "c5") == "(" + strtrim(strofreal(`lo2', "%9.4f")) + st_local("s") + strtrim(strofreal(`hi2', "%9.4f")) + ")")
        }
        * eplotframe() holds the limits as numbers
        frame _sp_ep {
            quietly count if abs(ll - `lo1') < 1e-9 & abs(ul - `hi1') < 1e-9
            assert r(N) == 1
            quietly count if abs(ll - `lo2') < 1e-9 & abs(ul - `hi2') < 1e-9
            assert r(N) == 1
        }
    }
    capture mata: mata drop _r
}
if _rc == 0 {
    display as result `"  PASS: K1 regtab sep("-") and sep(" ~|~ ") join the e(b)/e(V) limits as typed"'
    local ++pass_count
}
else {
    display as error "  FAIL: K1 regtab known-answer limits (rc=`=_rc')"
    local ++fail_count
}

**# K2 effecttab known answer: margins and from() limits under sep("-")
* 2.4.0 split "(-0.0079--0.0053)" at the first minus sign: an empty lower
* limit, so the interval kept its unformatted text and eplotframe() its
* limits went missing or wrong.
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress mpg weight foreign
    collect clear
    quietly collect: margins, dydx(weight foreign)
    tempname T
    matrix `T' = r(table)
    effecttab, sep("-") digits(4) frame(_sp_fr, replace) eplotframe(_sp_ep, replace)
    local j 0
    foreach lab in "Weight (lbs.)" "Car origin" {
        local ++j
        local lo = strtrim(string(`T'[rownumb(`T', "ll"), `j'], "%9.4f"))
        local hi = strtrim(string(`T'[rownumb(`T', "ul"), `j'], "%9.4f"))
        frame _sp_fr: mata: _r = selectindex(strtrim(st_sdata(., "A")) :== "`lab'")
        frame _sp_fr: mata: assert(rows(_r) == 1 & st_sdata(_r, "c2") == "(" + st_local("lo") + "-" + st_local("hi") + ")")
        frame _sp_ep {
            quietly count if label == "`lab'" & reldif(ll, `T'[rownumb(`T', "ll"), `j']) < 1e-6 ///
                & reldif(ul, `T'[rownumb(`T', "ul"), `j']) < 1e-6
            assert r(N) == 1
        }
    }
    matrix _SPE = (-1.5, -2.25, -0.75, 0.01 \ 0.5, -0.1, 1.1, 0.2)
    matrix rownames _SPE = Neg Cross
    effecttab, from(_SPE) sep("-") cformat(%9.3f) frame(_sp_fr, replace) eplotframe(_sp_ep, replace)
    frame _sp_fr {
        mata: _r = selectindex(strtrim(st_sdata(., "A")) :== "Neg")
        mata: assert(rows(_r) == 1 & st_sdata(_r, "c2") == "(-2.250--0.750)")
        mata: _r = selectindex(strtrim(st_sdata(., "A")) :== "Cross")
        mata: assert(rows(_r) == 1 & st_sdata(_r, "c2") == "(-0.100-1.100)")
    }
    frame _sp_ep {
        quietly count if ll == -2.25 & ul == -0.75
        assert r(N) == 1
        quietly count if abs(ll - (-0.1)) < 1e-12 & abs(ul - 1.1) < 1e-12
        assert r(N) == 1
    }
    matrix drop _SPE
    capture mata: mata drop _r
}
if _rc == 0 {
    display as result `"  PASS: K2 effecttab sep("-") with negative limits: margins and from(), text and eplotframe()"'
    local ++pass_count
}
else {
    display as error "  FAIL: K2 effecttab negative limits (rc=`=_rc')"
    local ++fail_count
}
capture matrix drop _SPE

**# K3 stratetab/ratetab known answer: the strate file's limits as typed
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    local here "`c(pwd)'"
    mata: st_local("s", char(36) + "SP250_X" + char(96))
    quietly cd "`output_dir'"
    capture noisily {
        preserve
        quietly strate drug, per(1000) output(sp250_k3, replace)
        use sp250_k3, clear
        sort drug
        local lo = _Lower[1] * 1000
        local hi = _Upper[1] * 1000
        restore
        stratetab, using(sp250_k3) outcomes(1) sep("`macval(s)'") frame(_sp_fr, replace)
    }
    local src = _rc
    quietly cd "`here'"
    if `src' exit `src'
    frame _sp_fr {
        mata: _c = st_sdata(., "c4")
        mata: assert(sum(strpos(_c, "(" + strtrim(strofreal(round(`lo', 0.1), "%24.1f")) + st_local("s") + strtrim(strofreal(round(`hi', 0.1), "%24.1f")) + ")") :> 0) == 1)
    }
    capture mata: mata drop _c
    _sp_noleak
}
if _rc == 0 {
    display as result "  PASS: K3 stratetab joins the strate file's limits with a \$name and backquote as typed"
    local ++pass_count
}
else {
    display as error "  FAIL: K3 stratetab known answer (rc=`=_rc')"
    local ++fail_count
}

**# K4 tabcell known answer: exact binomial and Poisson limits, joined as typed
local ++test_count
capture noisily {
    quietly cii proportions 20 2, exact
    local plo = 100 * r(lb)
    local phi = 100 * r(ub)
    quietly cii means 975.6 12, poisson
    local rlo = 1000 * r(lb)
    local rhi = 1000 * r(ub)
    * a double quote, a backquote and a space
    mata: st_local("s", char(34) + char(96) + " ")
    tabcell np, n(2) d(20) ci(exact) sep(`"`macval(s)'"')
    mata: assert(st_global("r(cell)") == "2 (10.0; " + strtrim(strofreal(`plo', "%4.1f")) + st_local("s") + strtrim(strofreal(`phi', "%4.1f")) + ")")
    tabcell rate, e(12) pt(975.6) per(1000) sep(`"`macval(s)'"')
    mata: assert(st_global("r(cell)") == strtrim(strofreal(12 / 975.6 * 1000, "%9.1f")) + " (" + strtrim(strofreal(`rlo', "%9.1f")) + st_local("s") + strtrim(strofreal(`rhi', "%9.1f")) + ")")
    assert !missing(r(lb), `rlo', r(ub), `rhi')
    assert reldif(r(lb), `rlo') < 1e-7 & reldif(r(ub), `rhi') < 1e-7
}
if _rc == 0 {
    display as result "  PASS: K4 tabcell np/rate limits from cii, joined by a double quote and backquote"
    local ++pass_count
}
else {
    display as error "  FAIL: K4 tabcell known answer (rc=`=_rc')"
    local ++fail_count
}

* _sp_pair runs tmpl() twice, first with @SEP@ empty, then with the option
* held in Mata _SP_O; every string cell of frame _sp_fr must match, the
* intervals joined by _SP_S. tabcell() compares r(cell) instead.
capture program drop _sp_pair
program define _sp_pair
    version 17.0
    syntax , TMPL(string) [TABCELL DEC(integer 0)]
    capture frame drop _sp_fr
    mata: st_local("cmd", subinstr(st_local("tmpl"), "@SEP@", ""))
    quietly `macval(cmd)'
    if "`tabcell'" != "" mata: _SP_D = st_global("r(cell)")
    else frame _sp_fr: mata: _SP_D = _sp_strcells()
    capture frame drop _sp_fr
    mata: st_local("cmd", subinstr(st_local("tmpl"), "@SEP@", _SP_O))
    quietly `macval(cmd)'
    if "`tabcell'" != "" mata: st_local("ok", strofreal(_sp_col(_SP_D, st_global("r(cell)"), _SP_S, `dec')))
    else frame _sp_fr: mata: st_local("ok", strofreal(_sp_col(_SP_D, _sp_strcells(), _SP_S, `dec')))
    if !`ok' {
        display as error `"_sp_pair: `macval(cmd)'"'
        exit 9
    }
    mata: assert(!sum(strpos(_SP_D, "LEAK")))
end
mata:
// the option as typed: name(text) in simple or compound quotes
void _sp_set(string scalar name, string scalar text)
{
    external string scalar _SP_O, _SP_S
    _SP_S = text == "" ? ", " : text
    if (strpos(text, char(34))) _SP_O = name + "(" + char(96) + char(34) + text + char(34) + char(39) + ")"
    else _SP_O = name + "(" + char(34) + text + char(34) + ")"
}
end
* the commands, each on a fixture with intervals below zero where it can
capture program drop _sp_every
program define _sp_every
    version 17.0
    args out
    * regtab and effecttab take sep() in every frame form; comptab and
    * hrcomptab cisep(); stratetab, ratetab, outtab and tabcell sep()
    sysuse auto, clear
    collect clear
    quietly collect: regress mpg weight i.foreign
    foreach f in "_sp_fr" "_sp_fr, replace" "_sp_fr, flat replace" "_sp_fr, replace flat keys" {
        _sp_pair, tmpl(`"regtab, @SEP@ frame(`f') eplotframe(_sp_ep, replace)"')
    }
    matrix _SPE = (-1.5, -2.25, -0.75, 0.01 \ 0.5, -0.1, 1.1, 0.2)
    matrix rownames _SPE = Neg Cross
    foreach f in "_sp_fr" "_sp_fr, flat replace" {
        _sp_pair, tmpl(`"effecttab, from(_SPE) @SEP@ frame(`f')"')
    }
    matrix drop _SPE
    quietly regtab, frame(_sp_c1, replace) eplotframe(_sp_c1e, replace)
    mata: _SP_O = "cisep" + substr(_SP_O, 4, .)
    _sp_pair, tmpl(`"comptab _sp_c1, rows(1 3) @SEP@ frame(_sp_fr, replace)"')
    _sp_pair, tmpl(`"comptab _sp_c1, rows(1 3) cformat(%9.3f) @SEP@ frame(_sp_fr, replace flat)"')
    mata: _SP_O = "sep" + substr(_SP_O, 6, .)
    generate byte heavy = weight > 3000
    _sp_pair, tmpl(`"outtab foreign, exposure(heavy) estimator(regress) @SEP@ frame(_sp_fr, replace)"')
    _sp_pair, tmpl(`"tabcell est, b(-1.5) ll(-2.25) ul(-0.75) @SEP@"') tabcell
    _sp_pair, tmpl(`"tabcell np, n(2) d(20) ci(exact) @SEP@"') tabcell
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    _sp_pair, tmpl(`"ratetab drug, @SEP@ frame(_sp_fr, replace)"')
    preserve
    quietly strate drug, per(1000) output("`out'/sp250_ev", replace)
    restore
    _sp_pair, tmpl(`"stratetab, using("`out'/sp250_ev") outcomes(1) @SEP@ frame(_sp_fr, replace)"')
    * hrcomptab: the model intervals (two decimals) take cisep()
    mata: _SP_O = "cisep" + substr(_SP_O, 4, .)
    _sp_pair, tmpl(`"_sp_hr, compact @SEP@"') dec(2)
    mata: _SP_O = "sep" + substr(_SP_O, 6, .)
    frame drop _sp_c1 _sp_c1e
end

* _sp_or: the odds-ratio limits of logit foreign mpg, from e(b)/e(V), in
* format `1' (default %4.2f), into locals lo and hi of the caller
capture program drop _sp_or
program define _sp_or
    version 17.0
    args fmt
    if "`fmt'" == "" local fmt "%4.2f"
    preserve
    sysuse auto, clear
    quietly logit foreign mpg
    c_local lo = strtrim(string(exp(_b[mpg] - invnormal(0.975) * _se[mpg]), "`fmt'"))
    c_local hi = strtrim(string(exp(_b[mpg] + invnormal(0.975) * _se[mpg]), "`fmt'"))
    restore
end

**# D1 regtab: a sep() holding the private delimiter prints once, as typed
* The fix-in-progress printed "(0.62  ~|~  0.99)": its substitution ran
* again over cells that already held sep().
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg
    quietly regtab, frame(_sp_fr, replace)
    frame _sp_fr: mata: _r = selectindex(strtrim(st_sdata(., "A")) :== "Mileage (mpg)"); _d = st_sdata(_r, "c2")
    mata: assert(rows(_r) == 1 & ustrregexm(_d, "^[(]([0-9.]+), ([0-9.]+)[)]$"))
    mata: _lo = ustrregexs(1); _hi = ustrregexs(2)
    * the first fix's three-byte delimiter, and today's two-byte one
    foreach t in " ~|~ " "~|~" "a~|~b~|~c" "~|" " ~| " "~|~|" {
        regtab, sep("`t'") frame(_sp_fr, replace)
        frame _sp_fr: mata: assert(st_sdata(_r, "c2") == "(" + _lo + `"`t'"' + _hi + ")")
    }
    capture mata: mata drop _r _d _lo _hi
}
if _rc == 0 {
    display as result "  PASS: D1 regtab sep() containing ~|~ is printed once, as typed"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 regtab private delimiter in sep() (rc=`=_rc')"
    local ++fail_count
}

**# D2 a $ in sep() with every frame() form and eplotframe(), every command
local ++test_count
* stata-dev-ignore: rc-only-test — the content oracle is the _sp_every/_sp_noleak call(s) in this block: each compares the produced cell/line/fact with the expected text and exits 9 on mismatch (_sp_pair asserts the interval text per sink, _sp_noleak exits 9 if the global changed); the rule cannot see a helper whose name has no "assert" substring
capture noisily {
    foreach t in "\$SP250_X" "\$" "a\$" "\${SP250_X}" "\$ SP250_X" {
        mata: _sp_set("sep", st_local("t"))
        _sp_every "`output_dir'"
    }
    _sp_noleak
}
if _rc == 0 {
    display as result "  PASS: D2 a \$ in sep()/cisep() with frame(), frame(, flat [keys]) and eplotframe(), every command"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 \$ with frame() (rc=`=_rc')"
    local ++fail_count
}
capture matrix drop _SPE
capture frame drop _sp_c1
capture frame drop _sp_c1e

**# D3 a lone backquote, a pair, and `name' (2.4.0: r(199), r(132), or the local's value)
local ++test_count
capture noisily {
    foreach t in 1 2 3 {
        if `t' == 1 mata: _sp_set("sep", char(96))
        if `t' == 2 mata: _sp_set("sep", char(96) + char(96))
        if `t' == 3 mata: _sp_set("sep", char(96) + "Y" + char(39))
        _sp_every "`output_dir'"
    }
}
if _rc == 0 {
    display as result "  PASS: D3 backquotes in sep()/cisep() print as typed in every command"
    local ++pass_count
}
else {
    display as error "  FAIL: D3 backquote (rc=`=_rc')"
    local ++fail_count
}
capture matrix drop _SPE
capture frame drop _sp_c1
capture frame drop _sp_c1e

**# D4 a double quote is a separator like any other
* 2.4.0: regtab r(198) "may not contain a double quote", effecttab r(198)
* or r(132). The CSV doubles it inside a quoted field.
local ++test_count
* stata-dev-ignore: rc-only-test — the content oracles are the mata: assert(...) comparisons of the frame cell and CSV line against the expected text, plus _sp_every; the rule does not parse an assert behind a mata: prefix
capture noisily {
    mata: _sp_set("sep", char(34) + " " + char(34))
    _sp_every "`output_dir'"
    mata: _sp_set("sep", "a" + char(34) + "b")
    _sp_every "`output_dir'"
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg
    local csv "`output_dir'/sp250_d4.csv"
    capture erase "`csv'"
    _sp_or
    * `"" ""' is the text " " (a double quote, a space, a double quote)
    regtab, sep(`"" ""') frame(_sp_fr, replace) csv("`csv'")
    frame _sp_fr: mata: assert(sum(st_sdata(., "c2") :== "(" + st_local("lo") + char(34) + " " + char(34) + st_local("hi") + ")") == 1)
    mata: _f = cat(st_local("csv")); assert(sum(strpos(_f, char(34) + "(" + st_local("lo") + char(34) + char(34) + " " + char(34) + char(34) + st_local("hi") + ")" + char(34)) :> 0) == 1)
    capture mata: mata drop _f
}
if _rc == 0 {
    display as result "  PASS: D4 a double quote in sep()/cisep() prints in every command; the CSV doubles it"
    local ++pass_count
}
else {
    display as error "  FAIL: D4 double quote (rc=`=_rc')"
    local ++fail_count
}
capture matrix drop _SPE
capture frame drop _sp_c1
capture frame drop _sp_c1e

**# D5 the quote rule: every command reads sep() as Stata reads a string option
* A quoted piece is kept whole, blanks included, and loses its quotes;
* blanks outside quotes are dropped; pieces are joined by one blank; empty
* is ", ". 2.4.0 (and the first fix) kept the quotes of sep( " to " ) in
* regtab and effecttab, and printed sep( - ) as " - " there but "-"
* elsewhere.
local ++test_count
* stata-dev-ignore: rc-only-test — the content oracle is the _sp_every call(s) in this block: each compares the produced cell/line/fact with the expected text and exits 9 on mismatch (_sp_pair asserts the interval text per sink); the rule cannot see a helper whose name has no "assert" substring
capture noisily {
    forvalues j = 1/8 {
        mata: _SP_O = "sep" + _SP_QF[`j']; _SP_S = _SP_QS[`j']
        _sp_every "`output_dir'"
    }
}
if _rc == 0 {
    display as result `"  PASS: D5 sep( " to " ), sep( - ), sep("a" "b"), compound and empty forms read alike in every command"'
    local ++pass_count
}
else {
    display as error "  FAIL: D5 quote rule (rc=`=_rc')"
    local ++fail_count
}
capture matrix drop _SPE
capture frame drop _sp_c1
capture frame drop _sp_c1e

**# D6 refusals: a comma in sep() with a decimal-comma cformat()
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg
    foreach t in ", " "," "a,b" {
        capture regtab, sep("`t'") cformat(%9,2f)
        assert _rc == 198
    }
    _sp_or %9,2f
    regtab, sep(" to ") cformat(%9,2f) frame(_sp_fr, replace)
    frame _sp_fr: mata: assert(sum(st_sdata(., "c2") :== "(" + st_local("lo") + " to " + st_local("hi") + ")") == 1)
    matrix _SPE = (2, 1, 3, 0.01)
    matrix rownames _SPE = Effect
    capture effecttab, from(_SPE) sep(";,") cformat(%9,2f)
    assert _rc == 198
    matrix drop _SPE
    * the refusal reads the separator itself, not a re-expansion of it: a
    * global that holds a comma does not trigger it, and is printed by name
    global SP250_C ","
    regtab, sep("\$SP250_C") cformat(%9,2f) frame(_sp_fr, replace)
    frame _sp_fr: mata: assert(sum(st_sdata(., "c2") :== "(" + st_local("lo") + char(36) + "SP250_C" + st_local("hi") + ")") == 1)
    macro drop SP250_C
}
if _rc == 0 {
    display as result "  PASS: D6 a comma in sep() with a decimal-comma cformat() is refused (r(198)); nothing else is"
    local ++pass_count
}
else {
    display as error "  FAIL: D6 decimal-comma refusal (rc=`=_rc')"
    local ++fail_count
}
capture matrix drop _SPE
capture macro drop SP250_C

**# D7 a long separator is not cut
local ++test_count
capture noisily {
    mata: _sp_set("sep", " " + 300 * "x" + " ")
    _sp_every "`output_dir'"
    mata: st_local("s", " " + 300 * "x" + " ")
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg
    _sp_or
    regtab, sep("`s'") frame(_sp_fr, replace)
    frame _sp_fr: mata: assert(sum(st_sdata(., "c2") :== "(" + st_local("lo") + st_local("s") + st_local("hi") + ")") == 1)
}
if _rc == 0 {
    display as result "  PASS: D7 a 302-character sep() is printed whole in every command"
    local ++pass_count
}
else {
    display as error "  FAIL: D7 long separator (rc=`=_rc')"
    local ++fail_count
}
capture matrix drop _SPE
capture frame drop _sp_c1
capture frame drop _sp_c1e

* _sp_types: the storage types of frame `1', in order, are `2'
capture program drop _sp_types
program define _sp_types
    version 17.0
    args fr want
    frame `fr' {
        local got ""
        foreach v of varlist _all {
            local t : type `v'
            local got "`got' `t'"
        }
    }
    local got : list retokenize got
    if "`got'" != "`want'" {
        display as error "frame `fr' types: `got'"
        display as error "        want: `want'"
        exit 9
    }
end

* _sp_warn runs cmd() under a log and returns the number of decimal-comma
* warnings it printed, r(n)
capture program drop _sp_warn
program define _sp_warn, rclass
    version 17.0
    syntax , CMD(string asis) OUT(string)
    capture log close _spc
    quietly log using "`out'/sp250_warn.log", text replace name(_spc)
    capture noisily `cmd'
    local rc = _rc
    * a tabcell's r(cell) is handed on (read before log close)
    mata: st_local("cell", st_global("r(cell)"))
    quietly log close _spc
    if `rc' {
        display as error `"_sp_warn: `cmd' failed with r(`rc')"'
        exit `rc'
    }
    return local cell `"`macval(cell)'"'
    mata: st_local("n", strofreal(sum(strpos(cat(st_local("out") + "/sp250_warn.log"), "writes a decimal comma and the interval separator holds a comma") :> 0)))
    return scalar n = `n'
end

**# L1 a session that still holds an older tabtools's helpers
* After net install over 2.4.0 in an open session, the 2.4.0 helper programs
* stay in memory (they were run, so discard keeps them) and pass their own
* check, but this release's Mata is absent. Each command must load its
* helpers again. The merged first fix stopped with r(3499).
local ++test_count
capture noisily {
    tempname fh
    local stale "`output_dir'/sp250_stale.do"
    file open `fh' using "`stale'", write replace text
    file write `fh' "capture program drop _tabtools_helpers_ready" _n
    file write `fh' "program define _tabtools_helpers_ready" _n
    file write `fh' "    version 17.0" _n
    file write `fh' "    exit 0" _n
    file write `fh' "end" _n
    file write `fh' "capture mata: mata drop _tt_sep_parse()" _n
    file write `fh' "capture mata: mata drop _tt_sep_optarg()" _n
    file close `fh'
    * the sources, made with the helpers intact
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    generate byte agegrp = 1 + (age >= 55) + (age >= 60)
    quietly ratetab agegrp, outlabels("Death") frame(_sp_rates, replace)
    collect clear
    quietly collect: stcox i.agegrp drug
    quietly collect: stcox i.agegrp drug age
    quietly regtab, frame(_sp_models, replace) noint compact models("M1 \ M2")
    preserve
    quietly strate drug, per(1000) output("`output_dir'/sp250_l1", replace)
    restore
    sysuse auto, clear
    collect clear
    quietly collect: regress mpg weight i.foreign
    quietly regtab, frame(_sp_c1, replace) eplotframe(_sp_c1e, replace)
    matrix _SPE = (2, 1, 3, 0.01)
    matrix rownames _SPE = Effect
    local c1 `"regtab, sep(" to ") frame(_sp_fr, replace)"'
    local c2 `"effecttab, from(_SPE) sep(" to ") frame(_sp_fr, replace)"'
    local c3 `"comptab _sp_c1, rows(1) cisep(" to ") frame(_sp_fr, replace)"'
    local c4 `"comptab _sp_c1, rows(1) cformat(%9.3f) cisep(" to ") frame(_sp_fr, replace)"'
    local c5 `"hrcomptab _sp_rates, modelframes(_sp_models) rows(all) allmodels modelonly effect("Rate ratio") cisep(" to ") frame(_sp_fr, replace)"'
    local c6 `"stratetab, using("`output_dir'/sp250_l1") outcomes(1) sep(" to ") frame(_sp_fr, replace)"'
    forvalues i = 1/6 {
        quietly do "`stale'"
        mata: assert(findexternal("_tt_sep_parse()") == NULL)
        capture noisily `c`i''
        if _rc {
            display as error `"L1: `c`i'' failed with r(`=_rc') in the stale session"'
            exit 9
        }
        mata: assert(findexternal("_tt_sep_parse()") != NULL)
        frame _sp_fr: mata: assert(sum(strpos(_sp_strcells(), " to ") :> 0) >= 1)
    }
    matrix drop _SPE
}
local l1_rc = _rc
* whatever happened, leave this release's helpers loaded
capture findfile _tabtools_common.ado
if !_rc capture run "`r(fn)'"
if `l1_rc' == 0 {
    display as result "  PASS: L1 regtab, effecttab, comptab, hrcomptab, stratetab reload stale helpers"
    local ++pass_count
}
else {
    display as error "  FAIL: L1 stale helpers (rc=`l1_rc')"
    local ++fail_count
}
capture matrix drop _SPE
foreach f in _sp_rates _sp_models _sp_c1 _sp_c1e {
    capture frame drop `f'
}

**# W1 the default separator keeps 2.4.0's storage widths
* Every type below was read from 2.4.0 on the same fixture. The private
* delimiter is as long as ", ", so the columns the renderer makes keep the
* widths they had (the first fix's three-byte delimiter widened them by one).
local ++test_count
* stata-dev-ignore: rc-only-test — the content oracle is the _sp_types call(s) in this block: each compares the produced cell/line/fact with the expected text and exits 9 on mismatch (helper defined in this file: compares the frame variable types with the expected list); the rule cannot see a helper whose name has no "assert" substring
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress mpg weight i.foreign
    quietly collect: logit foreign mpg weight
    quietly regtab, frame(_sp_fr, replace)
    _sp_types _sp_fr "str1 str13 str21 float str44 str21 str21 float str47 str22"
    sysuse auto, clear
    quietly regress mpg weight foreign
    collect clear
    quietly collect: margins, dydx(weight foreign)
    quietly effecttab, digits(3) frame(_sp_fr, replace)
    _sp_types _sp_fr "str1 str13 str22 str46 str21"
    quietly effecttab, cformat(%9.4f) frame(_sp_fl, replace flat)
    _sp_types _sp_fl "str13 str22 str46 str21"
    sysuse auto, clear
    collect clear
    quietly collect: regress mpg weight i.foreign
    quietly regtab, frame(_sp_m1, replace)
    collect clear
    quietly collect: regress mpg weight length i.foreign
    quietly regtab, frame(_sp_m2, replace)
    quietly comptab _sp_m1 _sp_m2, rows(1 2 \ 1 2) frame(_sp_fr, replace)
    _sp_types _sp_fr "str244 str13 str21 str45 str22"
}
if _rc == 0 {
    display as result "  PASS: W1 regtab, effecttab, comptab default-separator storage widths equal 2.4.0's"
    local ++pass_count
}
else {
    display as error "  FAIL: W1 storage widths (rc=`=_rc')"
    local ++fail_count
}

**# O1 outtab's console: 2.4.0's string(40) layout unless a data cell is longer
* The expected preview is listed here from the frame, as 2.4.0 listed it: a
* header row of the column labels, then the rows, at string(40). Header
* labels longer than 40 characters must not widen it (the first fix did).
local ++test_count
capture noisily {
    sysuse auto, clear
    generate byte hi_mpg = mpg > 21
    label variable hi_mpg "Mileage above twenty-one miles per gallon in the EPA test cycle"
    generate byte heavy = weight > 3000
    label define _sp_heavy 0 "Light cars (curb weight at most 3,000 pounds)" 1 "Heavy cars (curb weight above 3,000 pounds, US)"
    label values heavy _sp_heavy
    local L "`output_dir'/sp250_o1.log"
    local E "`output_dir'/sp250_o1e.log"
    capture log close _spc
    quietly log using "`L'", text replace name(_spc)
    outtab hi_mpg foreign, exposure(heavy) models("" \ "length") frame(_sp_fr, replace)
    quietly log close _spc
    frame _sp_fr {
        preserve
        quietly set obs `=_N + 1'
        quietly generate long _o = cond(_n == _N, 0, _n)
        sort _o
        quietly generate byte _h = _n == 1
        foreach v of varlist c* {
            local vl : variable label `v'
            quietly replace `v' = `"`macval(vl)'"' in 1
        }
        quietly log using "`E'", text replace name(_spc)
        noisily list rowlabel c*, noobs noheader table sepby(_h) string(40)
        quietly log close _spc
        restore
    }
    * the table lines of both logs (box rules and rows)
    mata: _a = cat(st_local("L")); _a = select(_a, ustrregexm(_a, "^  [+|]"))
    mata: _b = cat(st_local("E")); _b = select(_b, ustrregexm(_b, "^  [+|]"))
    mata: assert(rows(_a) > 4 & rows(_a) == rows(_b)); assert(_a == _b)
    * header labels over 40 characters are cut, as in 2.4.0
    mata: assert(any(strpos(_a, "..")))
    * a data cell over 40 characters (a long sep()) widens the preview: shown whole
    mata: st_local("s", " -- a separator long enough to need more than forty -- ")
    quietly log using "`L'", text replace name(_spc)
    outtab hi_mpg, exposure(heavy) sep("`s'") frame(_sp_fr, replace)
    quietly log close _spc
    frame _sp_fr: mata: _c = select(st_sdata(., "c3"), strpos(st_sdata(., "c3"), st_local("s")))
    * the log's own line continuations ("> ") are not part of the table
    mata: assert(rows(_c) == 1); _l = cat(st_local("L"))
    mata: for (_i = 1; _i <= rows(_l); _i++) _l[_i] = substr(_l[_i], 1, 2) == "> " ? substr(_l[_i], 3, .) : _l[_i]
    mata: assert(strpos(invtokens(_l', ""), _c[1]) > 0)
    capture mata: mata drop _a _b _c _l _i
}
if _rc == 0 {
    display as result "  PASS: O1 outtab console equals 2.4.0's string(40) list; a long data cell is shown whole"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 outtab console (rc=`=_rc')"
    local ++fail_count
}
capture label drop _sp_heavy

**# C1 a decimal-comma format beside a comma separator: a warning, the table as before
* regtab and effecttab refuse it (D6); the others printed it in 2.4.0 and
* still do, with one line of warning, and none for a separator without a comma.
local ++test_count
capture noisily {
    _sp_warn, out("`output_dir'") cmd(tabcell est, b(1) ll(0.5) ul(1.5) format(%9,2f))
    assert r(n) == 1
    mata: assert(st_global("r(cell)") == "1,00 (0,50, 1,50)")
    _sp_warn, out("`output_dir'") cmd(tabcell est, b(1) ll(0.5) ul(1.5) format(%9,2f) sep(" to "))
    assert r(n) == 0
    _sp_warn, out("`output_dir'") cmd(tabcell np, n(2) d(20) ci(exact) pformat(%9,1f))
    assert r(n) == 1
    _sp_warn, out("`output_dir'") cmd(tabcell est, b(1) ll(0.5) ul(1.5) format(%9.2f))
    assert r(n) == 0
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    _sp_warn, out("`output_dir'") cmd(ratetab drug, cformat(%9,2f) frame(_sp_fr, replace))
    assert r(n) == 1
    frame _sp_fr: mata: assert(sum(ustrregexm(st_sdata(., "c4"), "^[0-9]+,[0-9]{2} [(][0-9]+,[0-9]{2}, [0-9]+,[0-9]{2}[)]$")) == 3)
    _sp_warn, out("`output_dir'") cmd(ratetab drug, cformat(%9,2f) sep("; ") frame(_sp_fr, replace))
    assert r(n) == 0
    preserve
    quietly strate drug, per(1000) output("`output_dir'/sp250_c1", replace)
    restore
    _sp_warn, out("`output_dir'") cmd(stratetab, using("`output_dir'/sp250_c1") outcomes(1) cformat(%9,2f) frame(_sp_fr, replace))
    assert r(n) == 1
    sysuse auto, clear
    generate byte heavy = weight > 3000
    _sp_warn, out("`output_dir'") cmd(outtab foreign, exposure(heavy) estimator(regress) format(%9,2f) frame(_sp_fr, replace))
    assert r(n) == 1
    collect clear
    quietly collect: regress mpg weight
    quietly regtab, frame(_sp_c1, replace) eplotframe(_sp_c1e, replace)
    _sp_warn, out("`output_dir'") cmd(comptab _sp_c1, rows(1) cformat(%9,3f) frame(_sp_fr, replace))
    assert r(n) == 1
    frame _sp_fr: mata: assert(sum(st_sdata(., "c2") :== "(-0,007, -0,005)") == 1)
    _sp_warn, out("`output_dir'") cmd(comptab _sp_c1, rows(1) cformat(%9,3f) cisep(" to ") frame(_sp_fr, replace))
    assert r(n) == 0
    frame drop _sp_c1 _sp_c1e
}
if _rc == 0 {
    display as result "  PASS: C1 tabcell, ratetab, stratetab, outtab, comptab warn once (rc 0) on a decimal comma beside a comma"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 decimal-comma warnings (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _sp_c1
capture frame drop _sp_c1e

**# Summary
display "RESULT: test_sep_v250 tests=`test_count' pass=`pass_count' fail=`fail_count'"
foreach f in _sp_fr _sp_fl _sp_ep _sp_m1 _sp_m1e _sp_m2 _sp_m2e _sp_s1 _sp_s2 _sp_rates _sp_models _sp_c1 _sp_c1e {
    capture frame drop `f'
}
capture macro drop SP250_X
capture macro drop SP250_G
capture macro drop SP250_C
capture mata: mata drop _SP_QF _SP_QS _SP_O _SP_S _SP_D _sp_set() _sp_strcells() _sp_col()
capture program drop _sp_pair
capture program drop _sp_every
capture program drop _sp_or
capture program drop _sp_types
capture program drop _sp_warn
capture mata: mata drop _SP_C _SP_N _sp_sep() _sp_opt() _sp_cmd() _sp_tr() _sp_ivals() _sp_mdesc() _sp_csv() _sp_cells() _sp_same() _sp_console()
capture program drop _sp_loop
capture program drop _sp_noleak
capture program drop _sp_cdcomp
capture program drop _sp_hr
capture program drop _sp_tc
collect clear
set linesize `_sp_ls0'
capture tabtools set clear
log close _sp250
if `fail_count' > 0 exit 1
