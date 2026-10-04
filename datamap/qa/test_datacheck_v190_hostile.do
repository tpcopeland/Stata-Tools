*! test_datacheck_v190_hostile.do Version 1.0.0  2026/10/04
*! 1.9.0: a data value or value label spliced into a datacheck display line, or
*! into a datamap/datadict file or metadata row, prints as its literal text and
*! never runs as a directive.  Hostile values: double quote, lone backtick,
*! backtick-apostrophe, dollar-x, SMCL, parenthesis, backslash, leading dash,
*! the reported q="a(b)`, a quote-apostrophe pair, a 244-character value and an
*! embedded line feed.
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datacheck_v190_hostile.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local work "`base'_v190h"
capture mkdir "`work'"
capture mkdir "`work'/plus"
capture mkdir "`work'/personal"
mata: assert(direxists(st_local("work") + "/plus") & direxists(st_local("work") + "/personal"))
local oldplus : sysdir PLUS
local oldpersonal : sysdir PERSONAL
sysdir set PLUS "`work'/plus"
sysdir set PERSONAL "`work'/personal"
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard
macro drop DATAMAP_DQ
global TC 0
global PASS 0
global FAIL 0

capture program drop _u_tally
program define _u_tally
    args rc msg
    global TC = $TC + 1
    if `rc' == 0 {
        display as result "PASS: `msg'"
        global PASS = $PASS + 1
    }
    else {
        display as error "FAIL (rc=`rc'): `msg'"
        global FAIL = $FAIL + 1
    }
end

* The hostile values, in order; value k occurs k times so every level has its
* own count.  Mata is used so no value passes through macro expansion.
capture mata: mata drop _hl_vals()
capture mata: mata drop _hl_lit()
capture mata: mata drop _hl_lines()
capture mata: mata drop _hl_find()
capture mata: mata drop _hl_leak()
capture mata: mata drop _hl_count()
foreach f in _hl_fillb _hl_fill _hl_chk_all _hl_chk_groups _hl_chk_present _hl_counts _hl_chk_dmtext {
    capture mata: mata drop `f'()
}
mata:
string colvector _hl_vals()
{
    string colvector v
    v = char(34) \ char(96) \ (char(96) + char(39)) \ (char(36) + "x") \ ///
        "{bf:x}" \ "(" \ char(92) \ "-lead" \ ///
        ("q=" + char(34) + "a(b)" + char(96)) \ (invtokens(J(1, 243, "a"), "") + "Z") \ ///
        ("line1" + char(10) + "line2") \ ("a" + char(34) + char(39) + "b") \ ///
        "a)b(c"
    return(v)
}
// the text a level prints as: itself, with a line feed written as \n
string colvector _hl_lit()
{
    return(subinstr(_hl_vals(), char(10), char(92) + "n"))
}
// log file lines, a wrapped line (continuation "> ") joined to its parent
string colvector _hl_lines(string scalar path)
{
    string colvector t, o
    real scalar i, n
    t = cat(path)
    o = J(0, 1, "")
    for (i = 1; i <= rows(t); i++) {
        if (substr(t[i], 1, 2) == "> " & rows(o) > 0) o[rows(o)] = o[rows(o)] + substr(t[i], 3, .)
        else o = o \ t[i]
    }
    return(o)
}
// is there a line "<indent><literal>   <count>  (" ?  Padding between the
// literal and the count is spaces.  A literal of 200+ characters wraps.
real scalar _hl_find(string colvector L, string scalar indent, string scalar lit, ///
    real scalar cnt)
{
    real scalar i, k
    string scalar pre, rest
    pre = indent + lit
    k = strlen(pre)
    for (i = 1; i <= rows(L); i++) {
        if (strlen(L[i]) < k) continue
        if (substr(L[i], 1, k) != pre) continue
        rest = substr(L[i], k + 1, .)
        if (regexm(rest, "^ +" + strofreal(cnt) + "  \(")) return(1)
    }
    return(0)
}
// any directive text that leaked into a line
real scalar _hl_leak(string colvector L)
{
    return(any(strpos(L, "as result") :> 0) | any(strpos(L, "as text") :> 0) | ///
        any(strpos(L, "as error") :> 0) | any(strpos(L, "%9.0f") :> 0) | ///
        any(strpos(L, "%4.1f") :> 0))
}
real scalar _hl_count(string scalar var, string scalar v, | string scalar gv, real scalar g)
{
    real colvector m
    m = (st_sdata(., var) :== v)
    if (args() >= 4) m = m :& (st_data(., gv) :== g)
    return(sum(m))
}
// fill q and sl: level k of the hostile list in k rows
void _hl_fillb()
{
    real scalar r, k, j
    r = 0
    for (k = 1; k <= 13; k++) {
        for (j = 1; j <= k; j++) {
            r++
            st_sstore(r, "q", "L" + strofreal(k))
        }
    }
}
void _hl_fill()
{
    string colvector v
    real scalar r, k, j
    v = _hl_vals()
    r = 0
    for (k = 1; k <= rows(v); k++) {
        for (j = 1; j <= k; j++) {
            r++
            st_sstore(r, "q", v[k])
            st_sstore(r, "sl", v[k])
        }
    }
}
// every hostile level of q and sl shows in L at the indent with count k
real scalar _hl_chk_all(string colvector L, string scalar indent)
{
    string colvector lit, vv
    real scalar k, ok
    lit = _hl_lit()
    vv = _hl_vals()
    ok = 1
    for (k = 1; k <= rows(vv); k++) {
        if (_hl_count("q", vv[k]) != k | _hl_count("sl", vv[k]) != k) ok = 0
        if (!_hl_find(L, indent, lit[k], k)) {
            ok = 0
            printf("missing level %f\n", k)
        }
    }
    return(ok)
}
// by-group blocks: block gi starts after hdr[gi] and ends before hdr[gi+1]
real scalar _hl_chk_groups(string colvector L)
{
    real colvector hdr
    string colvector lit, vv, blk
    real scalar gi, k, c, ok
    hdr = selectindex(substr(L, 1, 13) :== "    by group ") \ rows(L) + 1
    lit = _hl_lit()
    vv = _hl_vals()
    ok = 1
    for (gi = 1; gi <= 3; gi++) {
        blk = L[|hdr[gi] + 1 \ hdr[gi + 1] - 1|]
        for (k = 1; k <= rows(vv); k++) {
            c = _hl_count("q", vv[k], "g", gi)
            if (c > 0) {
                if (!_hl_find(blk, "      ", lit[k], c)) {
                    ok = 0
                    printf("group %f level %f\n", gi, k)
                }
            }
        }
    }
    return(ok)
}
// each literal on a line of its own at the indent (the count is not checked)
real scalar _hl_chk_present(string colvector L, string scalar indent, string colvector lit)
{
    real scalar k, ok
    ok = 1
    for (k = 1; k <= rows(lit); k++) {
        if (!any(substr(L, 1, strlen(indent) + strlen(lit[k])) :== (indent + lit[k]))) ok = 0
    }
    return(ok)
}
// count-or-S per frequency line of a table, in output order
string colvector _hl_counts(string colvector L)
{
    string colvector o
    real scalar i
    o = J(0, 1, "")
    for (i = 1; i <= rows(L); i++) {
        if (strpos(L[i], "[suppressed]") > 0) o = o \ "S"
        else if (regexm(L[i], "^    .* +([0-9]+)  \(")) o = o \ regexs(1)
    }
    return(o)
}
// datamap text: "level": count (pct%) for each hostile level
real scalar _hl_chk_dmtext(string colvector T)
{
    string colvector vv
    string scalar lv, want
    real scalar k, ok
    vv = _hl_vals()
    ok = 1
    for (k = 1; k <= rows(vv); k++) {
        lv = subinstr(vv[k], char(10), " ")
        want = "    " + char(34) + lv + char(34) + ": " + strofreal(k) + " ("
        if (!any(substr(T, 1, strlen(want)) :== want)) {
            ok = 0
            printf("datamap text level %f\n", k)
        }
    }
    return(ok)
}
end

* Level k of the hostile list occurs k times, in both a str250 q and a strL sl;
* g takes values 1..3 by row so by() groups mix levels.
capture program drop _h_fix
program define _h_fix
    clear
    quietly set obs 91
    gen str250 q = ""
    gen strL sl = ""
    gen byte g = 1 + mod(_n, 3)
    gen long id = _n
    mata: _hl_fill()
    label define gl 1 `"a"b"' 2 "`" 3 "{bf:x}(\"
    label values g gl
end

* Run one command with its output captured in a text log; the log lines (parents
* joined to their wrapped continuation) are left in Mata as _hl_L.
capture program drop _h_cap
program define _h_cap
    local cmd `"`0'"'
    tempfile lg
    quietly log using "`lg'.log", replace text name(hcap)
    capture noisily `cmd'
    local rc = _rc
    quietly log close hcap
    mata: _hl_L = _hl_lines(st_local("lg") + ".log")
    c_local caprc `rc'
end

**# H1 STRING section: every hostile level of a str250 and a strL prints literally with its count
capture noisily {
    _h_fix
    _h_cap datacheck q sl, maxfreq(30)
    assert `caprc' == 0
    mata: _hl_ok = _hl_chk_all(_hl_L, "    ")
    mata: st_local("ok", strofreal(_hl_ok))
    assert `ok' == 1
    mata: st_local("leak", strofreal(_hl_leak(_hl_L)))
    assert `leak' == 0
    * both variables print the table: each literal appears twice
    mata: st_local("n244", strofreal(sum(substr(_hl_L, 1, 4 + 243) :== ("    " + invtokens(J(1, 243, "a"), "")))))
    assert `n244' == 2
}
local rc = _rc
_u_tally `rc' "H1 STRING: every hostile level prints literally with its count, no directive text"

**# H2 the reported value q="a(b)` prints as its own line
capture noisily {
    _h_fix
    _h_cap datacheck q, maxfreq(30)
    assert `caprc' == 0
    mata: rep = "    q=" + char(34) + "a(b)" + char(96)
    mata: st_local("hit", strofreal(_hl_find(_hl_L, "    ", substr(rep, 5, .), 9)))
    assert `hit' == 1
}
local rc = _rc
_u_tally `rc' "H2 reported q=""a(b)<backtick> value prints as a literal line"

**# H3 SMCL in a level is shown, not run
capture noisily {
    _h_fix
    _h_cap datacheck q, maxfreq(30)
    mata: st_local("hit", strofreal(sum(substr(_hl_L, 1, 10) :== "    {bf:x}")))
    assert `hit' == 1
    mata: st_local("hit", strofreal(sum(substr(_hl_L, 1, 7) :== ("    " + char(36) + "x "))))
    assert `hit' == 1
}
local rc = _rc
_u_tally `rc' "H3 {bf:x} and dollar-x levels print as their own text"

**# H4 an embedded line feed stays on one line
capture noisily {
    _h_fix
    _h_cap datacheck q, maxfreq(30)
    mata: st_local("hit", strofreal(sum(substr(_hl_L, 1, 16) :== "    line1\nline2")))
    assert `hit' == 1
    mata: st_local("split", strofreal(sum(_hl_L :== "line2")))
    assert `split' == 0
}
local rc = _rc
_u_tally `rc' "H4 line feed in a level is written \n, the row stays one line"

**# H5 CATEGORICAL numeric variable with hostile value labels
capture noisily {
    clear
    quietly set obs 10
    gen byte c = 1 + (_n > 1) + (_n > 3) + (_n > 6)
    * counts 1, 2, 3, 4
    mata: st_vlmodify("cl", (1 \ 2 \ 3 \ 4), (("a" + char(34) + "b") \ char(96) \ ("{bf:x}(" + char(92)) \ ("a" + char(34) + char(39) + "b")))
    label values c cl
    _h_cap datacheck c
    assert `caprc' == 0
    mata: lit = ("1 a" + char(34) + "b") \ ("2 " + char(96)) \ ("3 {bf:x}(" + char(92)) \ ("4 a" + char(34) + char(39) + "b")
    mata: st_local("ok", strofreal(_hl_find(_hl_L, "    ", lit[1], 1) & _hl_find(_hl_L, "    ", lit[2], 2) & _hl_find(_hl_L, "    ", lit[3], 3) & _hl_find(_hl_L, "    ", lit[4], 4)))
    assert `ok' == 1
    mata: st_local("leak", strofreal(_hl_leak(_hl_L)))
    assert `leak' == 0
    * oracle: the counts are those of count if
    forvalues k = 1/4 {
        quietly count if c == `k'
        assert r(N) == `k'
    }
}
local rc = _rc
_u_tally `rc' "H5 CATEGORICAL: hostile value labels print literally with oracle counts"

**# H6 GROUPWISE tables with hostile group labels: no leak, N per group matches count
capture noisily {
    _h_fix
    _h_cap datacheck q, by(g) maxfreq(30)
    assert `caprc' == 0
    mata: st_local("leak", strofreal(_hl_leak(_hl_L)))
    assert `leak' == 0
    forvalues k = 1/3 {
        quietly count if g == `k'
        local n`k' = r(N)
    }
    * the group rows: label text then N in the second column
    mata: g1 = (_hl_L :!= "")
    mata: st_local("r1", strofreal(sum(regexm(_hl_L, "^  a.x22b +" + st_local("n1") + " "))))
    mata: st_local("r2", strofreal(sum(regexm(_hl_L, "^  .x60 +" + st_local("n2") + " "))))
    mata: st_local("r3", strofreal(sum(regexm(_hl_L, "^  .x7bbf:x.x7d\(.x5c +" + st_local("n3") + " "))))
    assert `r1' == 1 & `r2' == 1 & `r3' == 1
}
local rc = _rc
_u_tally `rc' "H6 GROUPWISE: hostile group labels, N per group equals count if g == k"

**# H7 byfreq per-group tables: literal levels, per-group counts equal count if q == v & g == k
capture noisily {
    _h_fix
    _h_cap datacheck q, by(g) byfreq maxfreq(30)
    assert `caprc' == 0
    mata: st_local("leak", strofreal(_hl_leak(_hl_L)))
    assert `leak' == 0
    mata: i0 = selectindex(_hl_L :== "GROUPWISE FREQUENCIES"); st_local("i0", strofreal(i0))
    mata: st_local("nh", strofreal(sum(substr(_hl_L, 1, 13) :== "    by group ")))
    assert `nh' == 3
    * within each group's block, each level present in the group shows with its count
    mata: ok = _hl_chk_groups(_hl_L)
    mata: st_local("ok", strofreal(ok))
    assert `ok' == 1
}
local rc = _rc
_u_tally `rc' "H7 byfreq: hostile levels per group, counts equal count oracle"

**# H8 byfreq on a numeric variable with hostile value labels
capture noisily {
    _h_fix
    gen byte c = 1 + (id > 20) + (id > 50)
    mata: st_vlmodify("cl2", (1 \ 2 \ 3), (("a" + char(34) + "b") \ char(96) \ ("a" + char(34) + char(39) + "b")))
    label values c cl2
    _h_cap datacheck c, by(g) byfreq
    assert `caprc' == 0
    mata: st_local("leak", strofreal(_hl_leak(_hl_L)))
    assert `leak' == 0
    mata: blk = _hl_L; lit = ("1 a" + char(34) + "b") \ ("2 " + char(96)) \ ("3 a" + char(34) + char(39) + "b")
    mata: ok = _hl_chk_present(blk, "      ", lit)
    mata: st_local("ok", strofreal(ok))
    assert `ok' == 1
}
local rc = _rc
_u_tally `rc' "H8 byfreq numeric levels with hostile value labels print literally"

**# H9 gate messages that show levels: allowed, forbid, notvalues
capture noisily {
    _h_fix
    _h_cap datacheck q, gatesonly allowed(q "{bf:x}") forbid(q "{bf:x}" "a)b(c") notvalues(q ")(" "-lead")
    assert `caprc' == 9
    * allowed: 91 rows less the 5 {bf:x} rows
    quietly count if q != "{bf:x}"
    local nal = r(N)
    quietly count if q == "{bf:x}" | q == "a)b(c"
    local nfb = r(N)
    quietly count if q == ")(" | q == "-lead"
    local nnv = r(N)
    mata: m1 = "  allowed(q): " + st_local("nal") + " obs outside allowed values {{bf:x}}"
    mata: m2 = "  forbid(q): " + st_local("nfb") + " obs contain forbidden values {{bf:x} a)b(c}"
    mata: m3 = "  notvalues(q): " + st_local("nnv") + " obs contain sentinel values {)( -lead}"
    mata: st_local("ok", strofreal(any(_hl_L :== m1) & any(_hl_L :== m2) & any(_hl_L :== m3)))
    assert `ok' == 1
    mata: st_local("leak", strofreal(_hl_leak(_hl_L)))
    assert `leak' == 0
}
local rc = _rc
_u_tally `rc' "H9 gate messages: allowed/forbid/notvalues levels print literally with oracle counts"

**# H10 sets gate message and band/review lines carry no live text
capture noisily {
    _h_fix
    _h_cap datacheck q, gatesonly sets(id q)
    mata: st_local("leak", strofreal(_hl_leak(_hl_L)))
    assert `leak' == 0
    _h_cap datacheck q, gatesonly review(rule(q == "{bf:x}"))
    mata: st_local("leak", strofreal(_hl_leak(_hl_L)))
    assert `leak' == 0
}
local rc = _rc
_u_tally `rc' "H10 sets and review output carry no directive text"

**# H11 makespec: a hostile level gets no allowed row; a safe level list round-trips and a planted value fails
capture noisily {
    clear
    quietly set obs 6
    gen str40 r = ""
    mata: st_sstore(., "r", ("{bf:x}" \ "a(b" \ "-lead" \ "a b" \ "x;y" \ "p|q"))
    gen str40 q = ""
    mata: st_sstore(., "q", J(6, 1, char(96)))
    gen long id = _n
    capture frame drop hlspec
    quietly datacheck r q, makespec(hlspec)
    tempfile sf
    frame hlspec: quietly save "`sf'.dta", replace
    frame hlspec: quietly count if variable == "r" & gate == "allowed"
    assert r(N) == 1
    frame hlspec: quietly count if variable == "q" & gate == "allowed"
    assert r(N) == 0
    quietly datacheck r, checks("`sf'.dta") gatesonly
    * a value outside the observed set must fail the spec just written
    quietly replace r = "zzz" in 1
    capture quietly datacheck r, checks("`sf'.dta") gatesonly
    assert _rc == 9
}
local rc = _rc
_u_tally `rc' "H11 makespec: hostile level gets no row, safe levels round-trip, planted value fails (rc 9)"

**# H12 maskrare is unchanged: hostile levels mask exactly as benign ones with the same counts
capture noisily {
    _h_fix
    _h_cap datacheck q, maxfreq(30) maskrare mincell(5)
    assert `caprc' == 0
    mata: Lh = _hl_L
    * the same counts under benign level names
    _h_fix
    mata: _hl_fillb()
    _h_cap datacheck q, maxfreq(30) maskrare mincell(5)
    assert `caprc' == 0
    mata: Lb = _hl_L
    * freq lines: the part after the level text (count or suppression text)
    mata: nsh = sum(strpos(Lh, "[suppressed]") :> 0); nsb = sum(strpos(Lb, "[suppressed]") :> 0); st_local("nsh", strofreal(nsh)); st_local("nsb", strofreal(nsb))
    assert `nsh' == `nsb' & `nsh' > 0
    * the shown counts, in order, are identical
    mata: ch = _hl_counts(Lh); cb = _hl_counts(Lb)
    mata: st_local("same", strofreal(rows(ch) == rows(cb) & all(ch :== cb)))
    assert `same' == 1
    * no suppressed hostile level text leaks: a suppressed row names no level
    mata: st_local("leak", strofreal(_hl_leak(Lh)))
    assert `leak' == 0
}
local rc = _rc
_u_tally `rc' "H12 maskrare: hostile output has the same masked and shown counts as benign levels"

**# H13 datamap text and JSON: hostile levels, labels and data label
capture noisily {
    _h_fix
    mata: st_varlabel("id", "end" + char(96))
    mata: stata("label data " + char(34) + "ds" + char(96) + char(34))
    tempfile dmt dmj
    datamap, output("`dmt'.txt") categorical(q sl g) mincell(0) maxfreq(30) exclude(id)
    datamap, output("`dmj'.json") format(json) categorical(q sl g) mincell(0) maxfreq(30) exclude(id)
    mata: T = cat(st_local("dmt") + ".txt"); J = cat(st_local("dmj") + ".json")
    * text: "level": count (pct%), a line feed shown as a space
    mata: ok = _hl_chk_dmtext(T)
    mata: st_local("ok", strofreal(ok))
    assert `ok' == 1
    * the variable label and the value labels
    mata: st_local("a", strofreal(any(T :== ("    Label: end" + char(96)))))
    assert `a' == 1
    mata: st_local("a", strofreal(any(T :== ("  2 = " + char(96)))))
    assert `a' == 1
    * JSON: the backtick is the escape `, the quote-apostrophe pair stays apart
    mata: st_local("a", strofreal(sum(strpos(J, char(34) + "value" + char(34) + ": " + char(34) + char(92) + "u0060" + char(34) + ",") :> 0)))
    assert `a' == 2
    mata: st_local("a", strofreal(sum(strpos(J, "a" + char(92) + char(34) + char(92) + "u0027" + "b") :> 0)))
    assert `a' == 2
    mata: st_local("a", strofreal(sum(strpos(J, "q=" + char(92) + char(34) + "a(b)" + char(92) + "u0060") :> 0)))
    assert `a' == 2
    mata: st_local("a", strofreal(sum(strpos(J, char(34) + "label" + char(34) + ": " + char(34) + "end" + char(92) + "u0060" + char(34)) :> 0)))
    assert `a' == 1
    mata: st_local("a", strofreal(sum(strpos(J, char(34) + "label" + char(34) + ": " + char(34) + "ds" + char(92) + "u0060" + char(34)) :> 0)))
    assert `a' == 1
}
local rc = _rc
_u_tally `rc' "H13 datamap text and JSON: hostile levels, variable, value and data labels write literally"

**# H14 datadict markdown: hostile levels with oracle counts
capture noisily {
    _h_fix
    tempfile ddm
    datadict, output("`ddm'.md") categorical(q sl g) mincell(0) detail stats
    mata: M = cat(st_local("ddm") + ".md")
    * markdown writes a backtick and a dollar sign as entities, a line feed as a space
    mata: row = M[selectindex(strpos(M, "| `q` |") :> 0)]
    mata: st_local("hit", strofreal(strpos(row, "&#96; (2; ") > 0 & strpos(row, "&#36;x (4; ") > 0 & strpos(row, "{bf:x} (5; ") > 0 & strpos(row, "( (6; ") > 0 & strpos(row, "-lead (8; ") > 0 & strpos(row, "a" + char(34) + "&#39;b (12; ") > 0))
    assert `hit' == 1
}
local rc = _rc
_u_tally `rc' "H14 datadict: hostile levels counted exactly in the markdown row"

**# H15 datamap saving() and datacheck saving(): metadata rows keep a hostile label verbatim
capture noisily {
    clear
    quietly set obs 4
    gen byte x = mod(_n, 2)
    mata: st_varlabel("x", "v" + char(34) + "a" + char(96))
    mata: stata("label data " + char(34) + "d" + char(96) + char(34))
    mata: st_global("x[note0]", "1"); st_global("x[note1]", "n" + char(96) + "t" + char(34))
    tempfile mf mf2
    datamap, output("`mf'.txt") saving("`mf'.dta", replace)
    use "`mf'.dta", clear
    mata: want = "v" + char(34) + "a" + char(96)
    mata: assert(st_sdata(1, "variable_label") == want)
    mata: assert(st_sdata(1, "dataset_label") == "d" + char(96))
    mata: i = selectindex(st_sdata(., "variable") :== "x")[1]; names = st_sdata(., "variable"); st_local("hasnote", strofreal(1))
}
local rc = _rc
_u_tally `rc' "H15 datamap saving(): variable and dataset labels ending in a backtick are stored verbatim"

sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datacheck_v190_hostile tests=$TC pass=$PASS fail=$FAIL"
log close main
if $FAIL exit 1
