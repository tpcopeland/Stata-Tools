* _qa_md.do -- readers for datamap's Markdown documents (shared QA helper)
* Timothy P Copeland, Karolinska Institutet
*
* Why this exists: every datamap 2.0.0 document has lines that end in a
* backtick (the "- Source:" and "- Data signature:" lines, code-span cells).
* A Stata local that holds such a line, then wrapped as `"`line'"', reads the
* trailing backtick plus the closing "' as the start of a new compound quote
* and stops with "too few quotes" (r(132)) or r(198).  The 1.x datadict
* documents ended those lines with two spaces, so older readers got away
* with it.  These helpers read the file in Mata and never hold a line in a
* macro.
*
* qa_md_contains using file, needle(text) [exact]
*   r(found) 1 if any line contains needle (plain substring, case sensitive),
*   r(n) the number of such lines.  With exact, a line must EQUAL needle.
*   needle may hold | < > and a double-quote character; write a backtick as
*   `bt' after  local bt = char(96)  (the expansion is not rescanned).
* All readers use fget(); see _qa_md_cat for its 32,768-byte chunking.
* qa_md_nlines using file
*   r(n) the number of lines in the file (0 for an empty file).
* qa_md_regex using file, RE(regex)
*   r(n) the number of lines that match the ICU regular expression (ustrregexm).
* qa_md_rows using file [, VAR(name) CELL(text) MISS(text)]
*   Rows of the Variables table.  With no option r(n) counts the table rows
*   that start with a code span (a backtick right after "| "), i.e. one per documented variable of
*   every dataset section.  With var() it counts the rows of that variable
*   (the name in a code span, then " | "); with cell() as well, only those whose LAST cell
*   (Values/Statistics under the default columns) equals text exactly.
*   miss(text) further requires the row to hold " | text | " (the Missing cell
*   sits between two other cells under the default columns).
*   text is a plain string, "..." or compound-quoted, as for qa_md_contains.
* qa_md_levels using file, VAR(name) EXPECT(value:count ...)
*   The level list in the variable's last cell ("value[ label]: n (p%)" entries
*   joined by <br>).  r(ok) is 1 when the entries are exactly the expected
*   value:count pairs, in any order, no more and no fewer; r(n) is the number of
*   entries found.  A numeric value, a label of any text and a suppressed cell
*   (no count) are told apart: a "suppressed" entry counts as found but never
*   matches an expected pair.

mata:
// every line of a file as a column vector, read with fget().  A line over 32,768
// bytes comes back as consecutive chunks (a 20,000-level cell is several), so
// a needle that spans a chunk boundary is not found and a row longer than that
// is several elements: size-sensitive checks belong to short rows.
string colvector _qa_md_cat(string scalar f)
{
    real scalar fh
    string scalar line
    string colvector out
    fh = fopen(f, "r")
    out = J(0, 1, "")
    while ((line = fget(fh)) != J(0, 0, "")) out = out \ line
    fclose(fh)
    return(out)
}

string scalar _qa_md_unquote(string scalar s)
{
    // the needle arrives as typed: a plain string, "..." or compound `"..."'
    if (strlen(s) >= 4 & substr(s, 1, 2) == char(96) + char(34) & substr(s, -2, 2) == char(34) + "'") {
        return(substr(s, 3, strlen(s) - 4))
    }
    if (strlen(s) >= 2 & substr(s, 1, 1) == char(34) & substr(s, -1, 1) == char(34)) {
        return(substr(s, 2, strlen(s) - 2))
    }
    return(s)
}

real scalar _qa_md_count(string scalar f, string scalar nd, real scalar exact)
{
    string colvector L
    real scalar i, n
    L = _qa_md_cat(f)
    n = 0
    for (i = 1; i <= rows(L); i++) {
        if (exact) n = n + (L[i] == nd)
        else n = n + (strpos(L[i], nd) > 0)
    }
    return(n)
}

real scalar _qa_md_rows(string scalar f, string scalar v, string scalar cell, real scalar hascell, string scalar miss)
{
    string colvector L
    string scalar pre, suf
    real scalar i, n, lk
    L = _qa_md_cat(f)
    n = 0
    pre = (v == "" ? "| " + char(96) : "| " + char(96) + v + char(96) + " | ")
    suf = " | " + cell + " |"
    // 2026-11-10 (2.0.0 Phase 3, F1): the variable tables only; the rows of
    // the Linkage table (two or more datasets) start with the same prefix
    lk = 0
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, 3) == "## ") lk = (L[i] == "## Linkage")
        if (lk) continue
        if (substr(L[i], 1, strlen(pre)) != pre) continue
        if (hascell) {
            if (strlen(L[i]) < strlen(suf)) continue
            if (substr(L[i], strlen(L[i]) - strlen(suf) + 1, strlen(suf)) != suf) continue
        }
        if (miss != "" & strpos(L[i], " | " + miss + " | ") == 0) continue
        n++
    }
    return(n)
}

void _qa_md_levels(string scalar f, string scalar v, string scalar expect)
{
    string colvector L
    string rowvector ex, ent
    string scalar pre, cell, key, re
    real scalar i, k, ok, p, hit
    re = "^(-?[0-9][^ :]*)( .*)?: ([0-9]+) \([^)]*\)$"
    L = _qa_md_cat(f)
    pre = "| " + char(96) + v + char(96) + " | "
    cell = ""
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, strlen(pre)) == pre) {
            p = strlen(L[i]) - 1
            while (p > 1 & substr(L[i], p - 2, 3) != " | ") p--
            cell = substr(L[i], p + 1, strlen(L[i]) - p - 2)
        }
    }
    ex = tokens(expect)
    // split the cell on <br> into whole entries
    ent = J(1, 0, "")
    if (cell != "") {
        p = 1
        while (1) {
            k = strpos(substr(cell, p, .), "<br>")
            if (k == 0) {
                ent = ent, substr(cell, p, .)
                break
            }
            ent = ent, substr(cell, p, k - 1)
            p = p + k + 3
        }
    }
    ok = (cols(ent) == cols(ex))
    // every entry must parse and be an expected pair
    for (i = 1; i <= cols(ent); i++) {
        if (!regexm(ent[i], re)) {
            ok = 0
            continue
        }
        if (!anyof(ex, regexs(1) + ":" + regexs(3))) ok = 0
    }
    // every expected pair must occur exactly once
    for (k = 1; k <= cols(ex); k++) {
        hit = 0
        for (i = 1; i <= cols(ent); i++) {
            if (regexm(ent[i], re)) hit = hit + (regexs(1) + ":" + regexs(3) == ex[k])
        }
        if (hit != 1) ok = 0
    }
    st_numscalar("__qa_md_ok", ok)
    st_numscalar("__qa_md_n", cols(ent))
}
end

capture program drop qa_md_contains
program define qa_md_contains, rclass
    version 16.0
    syntax using/ , NEEDLE(string asis) [EXACT]
    confirm file `"`using'"'
    local ex = ("`exact'" != "")
    mata: st_numscalar("__qa_md_n", _qa_md_count(st_local("using"), _qa_md_unquote(st_local("needle")), `ex'))
    local n = scalar(__qa_md_n)
    scalar drop __qa_md_n
    return scalar n = `n'
    return scalar found = (`n' > 0)
end

capture program drop qa_md_nlines
program define qa_md_nlines, rclass
    version 16.0
    syntax using/
    confirm file `"`using'"'
    mata: st_numscalar("__qa_md_n", rows(_qa_md_cat(st_local("using"))))
    local n = scalar(__qa_md_n)
    scalar drop __qa_md_n
    return scalar n = `n'
end

capture program drop qa_md_rows
program define qa_md_rows, rclass
    version 16.0
    syntax using/ [, VAR(string) CELL(string asis) MISS(string)]
    confirm file `"`using'"'
    local hascell = (`"`cell'"' != "")
    mata: st_numscalar("__qa_md_n", _qa_md_rows(st_local("using"), st_local("var"), _qa_md_unquote(st_local("cell")), `hascell', st_local("miss")))
    local n = scalar(__qa_md_n)
    scalar drop __qa_md_n
    return scalar n = `n'
end

capture program drop qa_md_levels
program define qa_md_levels, rclass
    version 16.0
    syntax using/ , VAR(string) EXPECT(string)
    confirm file `"`using'"'
    mata: _qa_md_levels(st_local("using"), st_local("var"), st_local("expect"))
    return scalar ok = scalar(__qa_md_ok)
    return scalar n = scalar(__qa_md_n)
    scalar drop __qa_md_ok __qa_md_n
end

capture program drop qa_md_regex
program define qa_md_regex, rclass
    version 16.0
    syntax using/ , RE(string)
    confirm file `"`using'"'
    mata: st_numscalar("__qa_md_n", sum(ustrregexm(_qa_md_cat(st_local("using")), st_local("re"))))
    local n = scalar(__qa_md_n)
    scalar drop __qa_md_n
    return scalar n = `n'
end
