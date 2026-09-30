*! qa-lib _qa_state 1.0.1 sha256:a8dc13cf34f24991d29d42b77a675ac5bb32533e6a1d851578361884d2aab533
* _qa_state.do -- session fingerprint: did a command change what the caller owns?
*
* Load from a suite with: do "`qa_dir'/_qa_state.do"
*
* API
*   qa_state_snapshot, tag(name) [rreturn predict(statlist) charns(prefix)]
*       Record the caller's state under tag. tag is a Stata name of at most
*       21 characters. rreturn adds r() to the fingerprint; predict(xb stdp)
*       adds a predict round trip per statistic on the active estimates;
*       charns(prefix) exempts _dta[] characteristics whose name starts with
*       prefix (the package's own namespace).
*   qa_state_compare, tag(name) [allow(categories) keep]
*       Re-fingerprint with the snapshot's options and exit 9 if anything
*       differs, listing EVERY difference as "<category> <name>: <change>".
*       allow() exempts whole categories (below). The snapshot is dropped
*       unless keep is given. compare leaves r() and e() exactly as it found
*       them, so a suite can still inspect the command's own results.
*   qa_state_drop, tag(name)
*       Discard a snapshot without comparing.
*
* Categories (the first word of every difference line; the names allow() takes)
*   e        every e() macro, scalar and matrix, the e(sample) count and a
*            row digest of the marker, and predict() round trips
*   r        every r() macro, scalar and matrix (only with rreturn)
*   matrix   every matrix: dimensions, row/column stripes, %21x contents
*   scalar   every numeric and string scalar
*   global   every global macro
*   setting  c(varabbrev more matastrict level type dp trace maxiter
*            emptycells showbaselevels showomitted fvlabel cformat pformat
*            sformat)
*   rng      c(rngstate) and c(rng_current); allow(rng) for documented RNG use
*   sysdir   c(sysdir_*) and c(adopath)
*   data     N, variable order/types/formats/labels/value-label names, a
*            row-order-sensitive digest of every column, and datasignature
*   sort     : sortedby
*   label    every value label and its contents
*   char     _dta[] characteristics outside charns()
*   frame    the frame list and the current frame
*   file     files and directories in the working directory (names only)
*
* Errors
*   rc 9     compare found at least one difference (the violation)
*   rc 111   compare/drop: no snapshot under that tag
*   rc 198   bad tag or unknown allow() category
*
* Deliberately NOT checked
*   Mata objects; variable characteristics; notes on variables; the log and
*   graph lists; c(changed); file CONTENTS in the working directory (names
*   only); anything outside the working directory; Stata's own loop state
*   (foreach/forvalues globals whose names, such as !1fe, are not valid
*   names). e(sample) and predict are digested, not stored, so a difference
*   is reported without the rows.
*
* Implementation notes
*   The snapshot does not change caller state. It never uses preserve, so it
*   works inside the caller's own preserve block: temporary variables are
*   dropped and the data-changed flag is put back with st_updata(). r() is
*   held with _return hold and e() with _estimates hold ..., copy. The only
*   thing it persists is a Mata external in the reserved __qa_state_<tag>
*   namespace (plus __qa_statework while compare runs); Mata objects are not
*   part of the fingerprint, and compare removes its own.
*   Every double is recorded as %21x, so a difference in the last bit counts.

capture program drop qa_state_snapshot
program define qa_state_snapshot
    version 16.0
    syntax , TAG(name) [RRETURN PREDict(string) CHARns(string)]
    _qa_st_tagcheck `tag'
    local ext "__qa_state_`tag'"
    capture mata: rmexternal("`ext'")
    _qa_st_collect `ext' "`rreturn'" "`predict'" "`charns'"
end

capture program drop qa_state_compare
program define qa_state_compare
    version 16.0
    syntax , TAG(name) [ALLOW(string) KEEP]
    _qa_st_tagcheck `tag'
    local cats "e r matrix scalar global setting rng sysdir data sort label char frame file"
    foreach a of local allow {
        if !`: list a in cats' {
            display as error "qa_state_compare: unknown allow() category {bf:`a'}"
            display as error "  categories: `cats'"
            exit 198
        }
    }
    local ext "__qa_state_`tag'"
    mata: st_local("have", strofreal(findexternal("`ext'") != NULL))
    if !`have' {
        display as error "qa_state_compare: no snapshot under tag {bf:`tag'}"
        exit 111
    }
    mata: st_local("rreturn", _qa_st_meta("`ext'", "rreturn"))
    mata: st_local("predict", _qa_st_meta("`ext'", "predict"))
    mata: st_local("charns",  _qa_st_meta("`ext'", "charns"))
    capture mata: rmexternal("__qa_statework")
    _qa_st_collect __qa_statework "`rreturn'" "`predict'" "`charns'"
    mata: _qa_st_diff("`ext'", "__qa_statework", "`tag'", "`allow'")
    capture mata: rmexternal("__qa_statework")
    if "`keep'" == "" capture mata: rmexternal("`ext'")
    if `ndiff' > 0 exit 9
end

capture program drop qa_state_drop
program define qa_state_drop
    version 16.0
    syntax , TAG(name)
    _qa_st_tagcheck `tag'
    mata: st_local("have", strofreal(findexternal("__qa_state_`tag'") != NULL))
    if !`have' {
        display as error "qa_state_drop: no snapshot under tag {bf:`tag'}"
        exit 111
    }
    mata: rmexternal("__qa_state_`tag'")
end

capture program drop _qa_st_tagcheck
program define _qa_st_tagcheck
    args tag
    if strlen("`tag'") > 21 {
        display as error "qa_state: tag() must be at most 21 characters"
        exit 198
    }
end

* Fill Mata external `ext' with the fingerprint. Everything Mata can read
* without side effects is read first; then r() and e() are held for the
* steps that run Stata commands.
capture program drop _qa_st_collect
program define _qa_st_collect
    args ext rreturn predict charns
    mata: _qa_st_core("`ext'", "`rreturn'" != "", `"`charns'"')
    mata: _qa_st_put("`ext'", "_meta|rreturn", "`rreturn'")
    mata: _qa_st_put("`ext'", "_meta|predict", "`predict'")
    mata: _qa_st_put("`ext'", "_meta|charns", `"`charns'"')
    local sorted : sortedby
    mata: _qa_st_put("`ext'", "sort|sortedby", "`sorted'")

    tempname rhold ehold
    tempvar mark pv
    local changed = c(changed)
    _return hold `rhold'

    capture quietly _datasignature
    if _rc mata: _qa_st_put("`ext'", "data|datasignature", "rc `=_rc'")
    else mata: _qa_st_put("`ext'", "data|datasignature", st_global("r(datasignature)"))

    capture quietly label dir
    local labs "`r(names)'"
    foreach l of local labs {
        mata: _qa_st_label("`ext'", "`l'")
    }

    capture quietly generate byte `mark' = e(sample)
    if _rc mata: _qa_st_put("`ext'", "e|sample", "rc `=_rc'")
    else mata: _qa_st_coldigest("`ext'", "e|sample", "`mark'")
    capture drop `mark'

    if `"`predict'"' != "" {
        _estimates hold `ehold', copy nullok restore
        foreach s of local predict {
            capture quietly predict double `pv', `s'
            if _rc mata: _qa_st_put("`ext'", "e|predict(`s')", "rc `=_rc'")
            else mata: _qa_st_coldigest("`ext'", "e|predict(`s')", "`pv'")
            capture drop `pv'
        }
        _estimates unhold `ehold'
    }

    _return restore `rhold'
    mata: st_updata(`changed')
end

capture mata: mata drop _qa_st_put()
capture mata: mata drop _qa_st_meta()
capture mata: mata drop _qa_st_hx()
capture mata: mata drop _qa_st_mat()
capture mata: mata drop _qa_st_cval()
capture mata: mata drop _qa_st_dig()
capture mata: mata drop _qa_st_coldigest()
capture mata: mata drop _qa_st_label()
capture mata: mata drop _qa_st_results()
capture mata: mata drop _qa_st_core()
capture mata: mata drop _qa_st_esc()
capture mata: mata drop _qa_st_short()
capture mata: mata drop _qa_st_diff()

mata:
void _qa_st_put(string scalar ext, string scalar key, string scalar val)
{
    pointer(transmorphic scalar) scalar p

    if ((p = findexternal(ext)) == NULL) {
        p = crexternal(ext)
        *p = asarray_create()
    }
    asarray(*p, key, val)
}

string scalar _qa_st_meta(string scalar ext, string scalar what)
{
    pointer(transmorphic scalar) scalar p

    p = findexternal(ext)
    if (!asarray_contains(*p, "_meta|" + what)) return("")
    return(asarray(*p, "_meta|" + what))
}

string scalar _qa_st_hx(real matrix x)
{
    if (rows(x) * cols(x) == 0) return("")
    return(invtokens(strofreal(vec(x)', "%21x"), ","))
}

string scalar _qa_st_mat(string scalar name)
{
    real matrix m

    m = st_matrix(name)
    return(strofreal(rows(m)) + "x" + strofreal(cols(m))
        + " r=" + invtokens(st_matrixrowstripe(name)[., 2]', " ")
        + " c=" + invtokens(st_matrixcolstripe(name)[., 2]', " ")
        + " v=" + _qa_st_hx(m))
}

string scalar _qa_st_cval(string scalar name)
{
    transmorphic scalar v

    v = c(name)
    if (eltype(v) == "real") return(strofreal(v, "%21x"))
    return(v)
}

// Row-order-sensitive digest of one column: N, then a hash over the
// %21x (numeric) or length-prefixed (string) values in row order.
string scalar _qa_st_dig(string scalar var)
{
    real colvector x
    string colvector s
    string scalar body

    if (st_isstrvar(var)) {
        s = st_sdata(., var)
        if (rows(s) == 0) return("0")
        body = invtokens((strofreal(strlen(s)) :+ ":" :+ s)', char(31))
    }
    else {
        x = st_data(., var)
        if (rows(x) == 0) return("0")
        body = invtokens(strofreal(x', "%21x"), ",")
    }
    return(strofreal(st_nobs()) + ":" + strofreal(hash1(body), "%12.0f")
        + ":" + strofreal(hash1(strreverse(body)), "%12.0f"))
}

void _qa_st_coldigest(string scalar ext, string scalar key, string scalar var)
{
    _qa_st_put(ext, key, _qa_st_dig(var))
}

void _qa_st_label(string scalar ext, string scalar lab)
{
    real colvector v
    string colvector t

    st_vlload(lab, v, t)
    _qa_st_put(ext, "label|" + lab, _qa_st_hx(v') + " t="
        + invtokens(t', char(31)))
}

void _qa_st_results(string scalar ext, string scalar cat, string scalar src)
{
    string colvector n
    real scalar i

    n = st_dir(src, "macro", "*")
    for (i = 1; i <= rows(n); i++) {
        _qa_st_put(ext, cat + "|" + n[i], "macro " + st_global(cat + "(" + n[i] + ")"))
    }
    n = st_dir(src, "numscalar", "*")
    for (i = 1; i <= rows(n); i++) {
        _qa_st_put(ext, cat + "|" + n[i],
            "scalar " + _qa_st_hx(st_numscalar(cat + "(" + n[i] + ")")))
    }
    n = st_dir(src, "matrix", "*")
    for (i = 1; i <= rows(n); i++) {
        _qa_st_put(ext, cat + "|" + n[i], "matrix " + _qa_st_mat(cat + "(" + n[i] + ")"))
    }
}

void _qa_st_core(string scalar ext, real scalar rret, string scalar charns)
{
    string colvector n, settings, sysdirs
    string scalar vars
    real scalar i

    _qa_st_put(ext, "_meta|tag", ext)

    _qa_st_results(ext, "e", "e()")
    if (rret) _qa_st_results(ext, "r", "r()")

    n = st_dir("global", "matrix", "*")
    for (i = 1; i <= rows(n); i++) _qa_st_put(ext, "matrix|" + n[i], _qa_st_mat(n[i]))
    n = st_dir("global", "numscalar", "*")
    for (i = 1; i <= rows(n); i++) {
        _qa_st_put(ext, "scalar|" + n[i], _qa_st_hx(st_numscalar(n[i])))
    }
    n = st_dir("global", "strscalar", "*")
    for (i = 1; i <= rows(n); i++) _qa_st_put(ext, "scalar|" + n[i], "str " + st_strscalar(n[i]))
    n = st_dir("global", "macro", "*")
    for (i = 1; i <= rows(n); i++) {
        // foreach/forvalues keep their state in globals such as !1fe, which
        // st_global() rejects (rc 3300); they are Stata's, not the caller's
        if (!st_isname(n[i])) continue
        _qa_st_put(ext, "global|" + n[i], st_global(n[i]))
    }

    settings = ("varabbrev", "more", "matastrict", "level", "type", "dp",
        "trace", "maxiter", "emptycells", "showbaselevels", "showomitted",
        "fvlabel", "cformat", "pformat", "sformat")'
    for (i = 1; i <= rows(settings); i++) {
        _qa_st_put(ext, "setting|" + settings[i], _qa_st_cval(settings[i]))
    }
    _qa_st_put(ext, "rng|rngstate", _qa_st_cval("rngstate"))
    _qa_st_put(ext, "rng|rng_current", _qa_st_cval("rng_current"))
    sysdirs = ("sysdir_stata", "sysdir_base", "sysdir_site", "sysdir_plus",
        "sysdir_personal", "sysdir_oldplace", "adopath")'
    for (i = 1; i <= rows(sysdirs); i++) {
        _qa_st_put(ext, "sysdir|" + sysdirs[i], _qa_st_cval(sysdirs[i]))
    }

    _qa_st_put(ext, "data|N", strofreal(st_nobs()))
    vars = ""
    for (i = 1; i <= st_nvar(); i++) {
        vars = vars + " " + st_varname(i)
        _qa_st_put(ext, "data|" + st_varname(i), st_vartype(i) + " "
            + st_varformat(i) + " vl=" + st_varvaluelabel(i) + " lab="
            + st_varlabel(i) + " dig=" + _qa_st_dig(st_varname(i)))
    }
    _qa_st_put(ext, "data|varlist", strtrim(vars))

    n = st_dir("char", "_dta", "*")
    for (i = 1; i <= rows(n); i++) {
        if (charns != "" & substr(n[i], 1, strlen(charns)) == charns) continue
        _qa_st_put(ext, "char|_dta[" + n[i] + "]", st_global("_dta[" + n[i] + "]"))
    }

    n = sort(st_framedir(), 1)
    _qa_st_put(ext, "frame|list", invtokens(n', " "))
    _qa_st_put(ext, "frame|current", st_framecurrent())

    n = sort(dir(".", "files", "*"), 1)
    for (i = 1; i <= rows(n); i++) _qa_st_put(ext, "file|" + n[i], "file")
    n = sort(dir(".", "dirs", "*"), 1)
    for (i = 1; i <= rows(n); i++) _qa_st_put(ext, "file|" + n[i] + "/", "dir")
}

// SMCL-safe text: braces in user data must not be read as directives.
string scalar _qa_st_esc(string scalar s)
{
    string scalar t

    t = subinstr(subinstr(s, "{", char(1)), "}", char(2))
    return(subinstr(subinstr(t, char(1), "{c -(}"), char(2), "{c )-}"))
}

string scalar _qa_st_short(string scalar s)
{
    if (strlen(s) <= 60) return(s)
    return(substr(s, 1, 57) + "...")
}

void _qa_st_diff(string scalar was, string scalar now, string scalar tag,
    string scalar allow)
{
    pointer(transmorphic scalar) scalar pw, pn
    string colvector kw, kn, keys, lines
    string rowvector allowed
    string scalar k, cat, name, vw, vn
    real scalar i, j, hw, hn

    pw = findexternal(was)
    pn = findexternal(now)
    kw = asarray_keys(*pw)
    kn = asarray_keys(*pn)
    keys = uniqrows(kw \ kn)
    allowed = tokens(allow)
    lines = J(0, 1, "")
    for (i = 1; i <= rows(keys); i++) {
        k = keys[i]
        j = strpos(k, "|")
        cat = substr(k, 1, j - 1)
        name = substr(k, j + 1, .)
        if (cat == "_meta") continue
        if (anyof(allowed, cat)) continue
        hw = asarray_contains(*pw, k)
        hn = asarray_contains(*pn, k)
        if (hw & !hn) {
            lines = lines \ (cat + " " + name + ": removed (was "
                + _qa_st_short(asarray(*pw, k)) + ")")
        }
        else if (!hw & hn) {
            lines = lines \ (cat + " " + name + ": added ("
                + _qa_st_short(asarray(*pn, k)) + ")")
        }
        else {
            vw = asarray(*pw, k)
            vn = asarray(*pn, k)
            if (vw != vn) {
                lines = lines \ (cat + " " + name + ": changed from "
                    + _qa_st_short(vw) + " to " + _qa_st_short(vn))
            }
        }
    }
    st_local("ndiff", strofreal(rows(lines)))
    if (rows(lines) == 0) return
    displayas("error")
    printf("qa_state_compare: caller state changed [tag %s]: %f difference(s)\n",
        tag, rows(lines))
    for (i = 1; i <= rows(lines); i++) printf("  %s\n", _qa_st_esc(lines[i]))
}
end
