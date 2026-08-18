*! _tabtools_xlsx_compact_styles Version 1.16.2  2026/08/19
*! Collapse duplicate style records in a closed xlsx workbook
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

* Stata's xl() class never reuses a style record.  A ranged set_font() appends
* two <font> entries for every cell it touches, and every other cell-level
* operation (bold, italic, wrap, align, fill, border) appends one, so the
* pools grow with the number of styled cells rather than with the number of
* distinct formats.  A workbook crosses the 65,536-record font ceiling after a
* few dozen styled sheets, and the next set_font() then fails with the
* misleading "<name>: invalid font name" r(16147).  The cell format pool
* (cellXfs) reaches its own 65,490 ceiling just behind it.
*
* Collapsing those pools once the book is closed is format-preserving: only
* the indices change, so every cell keeps the identical resolved font, fill,
* border and alignment.  Compacting after each sheet write keeps the pools
* proportional to the number of distinct formats for the life of the workbook.
*
* Scope: fonts, fills, borders and cellXfs.  numFmts is deliberately NOT
* handled, because nothing in tabtools calls set_number_format() and that pool
* is empty in every workbook the package writes -- every cell ships as a
* string.  If a number-format call is ever added, this helper must learn to
* dedupe numFmts and remap numFmtId as well: left alone that pool would grow
* per styled cell exactly like the others, and worse, a distinct numFmtId on
* every <xf> would make the cellXfs records all differ and defeat the cellXfs
* dedupe below entirely.

program define _tabtools_xlsx_compact_styles, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax using/ [, noWARNing]

        confirm file `"`using'"'

        * Best effort from here down.  This is an optimization applied to a
        * workbook that has already been written, so anything that goes wrong
        * leaves the file exactly as xl() wrote it instead of failing an
        * export that has otherwise succeeded.
        * Quiet on purpose: a failed rebuild is reported by the note below
        * and by r(compacted), not by dumping a Mata traceback into the
        * middle of a table export.
        capture _tabtools_xlsx_compact_engine using `"`using'"'
        local _engine_rc = _rc

        if `_engine_rc' == 0 {
            return scalar compacted = 1
            return scalar fonts_before = r(fonts_before)
            return scalar fonts_after = r(fonts_after)
            return scalar fills_before = r(fills_before)
            return scalar fills_after = r(fills_after)
            return scalar borders_before = r(borders_before)
            return scalar borders_after = r(borders_after)
            return scalar formats_before = r(formats_before)
            return scalar formats_after = r(formats_after)
        }
        else {
            return scalar compacted = 0
            if "`warning'" == "" {
                noisily display as text "note: could not compact Excel style records (rc `_engine_rc'); the workbook is unchanged but may reach Stata's style-record limit as sheets are added"
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _tabtools_xlsx_compact_engine
program define _tabtools_xlsx_compact_engine, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    syntax using/

    * unzipfile always extracts into the current directory, so the workbook
    * has to round-trip through a scratch directory of its own.
    tempfile _stub
    local work "`_stub'_xlsxdir"
    capture mkdir "`work'"
    if _rc exit 693

    * Copy first, while the caller's relative path is still resolvable.
    quietly copy `"`using'"' "`work'/_tt_src.xlsx"

    foreach _p in fonts fills borders formats {
        local _tt_`_p'_before 0
        local _tt_`_p'_after 0
    }

    * Conservative default: anything that stops before the pools are examined
    * is treated as "the workbook changed", so the rebuild-and-verify path
    * still runs rather than being skipped on an unknown state.
    local _tt_changed 1

    local _home "`c(pwd)'"
    capture noisily {
        quietly cd "`work'"
        quietly unzipfile "_tt_src.xlsx"
        erase "_tt_src.xlsx"
        confirm file "xl/styles.xml"
        * The sheet names the rebuilt archive is checked against are read from
        * this part rather than by reopening the original with xl(), so its
        * absence has to stop the run before anything is rewritten.
        confirm file "xl/workbook.xml"

        mata: _tt_xlsx_compact_dir(".")

        * Every pool already holds nothing but distinct records, so rebuilding
        * the archive would write the same workbook back byte for byte.  The
        * zip, the unpack, and the xl() reopen below are the expensive part of
        * this helper -- skipping them when there is nothing to collapse is
        * what keeps a per-sheet compaction affordable across a long workbook.
        if `_tt_changed' {
            mata: st_local("_flist", _tt_xlsx_quoted_files("."))
            if `"`_flist'"' == "" exit 601
            quietly zipfile `_flist', saving("_tt_out.xlsx")
            confirm file "_tt_out.xlsx"

            * zipfile reports success while silently omitting entries it could
            * not add, so the rebuilt archive is unpacked again and matched
            * against what went in, name for name and byte count for byte
            * count.
            capture mkdir "_tt_verify"
            if _rc exit 693
            quietly cd "_tt_verify"
            quietly unzipfile "../_tt_out.xlsx"
            quietly cd ".."
            mata: _tt_xlsx_check_manifest(".", "_tt_verify", "_tt_out.xlsx")
        }
    }
    local _rc_inner = _rc
    quietly cd "`_home'"

    * Reject the rebuilt archive unless xl() still opens it and reports the
    * same sheets; a silently truncated zip must never replace a good
    * workbook.  The names it is compared against come from the workbook.xml
    * already unpacked above: reopening the original with xl() only to list
    * its sheets costs a full parse of the very style pools this helper
    * exists to shrink, and it grows with every sheet added.
    if `_rc_inner' == 0 & `_tt_changed' {
        capture mata: _tt_xlsx_verify("`work'/_tt_out.xlsx", "`work'")
        local _rc_inner = _rc
    }

    if `_rc_inner' == 0 {
        if `_tt_changed' quietly copy "`work'/_tt_out.xlsx" `"`using'"', replace
        return scalar fonts_before = `_tt_fonts_before'
        return scalar fonts_after = `_tt_fonts_after'
        return scalar fills_before = `_tt_fills_before'
        return scalar fills_after = `_tt_fills_after'
        return scalar borders_before = `_tt_borders_before'
        return scalar borders_after = `_tt_borders_after'
        return scalar formats_before = `_tt_formats_before'
        return scalar formats_after = `_tt_formats_after'
    }

    capture mata: _tt_xlsx_rmtree("`work'")
    if `_rc_inner' exit `_rc_inner'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 16.0
capture mata: mata drop _tt_xlsx_compact_dir()
capture mata: mata drop _tt_xlsx_compact_styles_xml()
capture mata: mata drop _tt_xlsx_slurp()
capture mata: mata drop _tt_xlsx_spit()
capture mata: mata drop _tt_xlsx_pool_items()
capture mata: mata drop _tt_xlsx_dedupe()
capture mata: mata drop _tt_xlsx_block()
capture mata: mata drop _tt_xlsx_remap_attr()
capture mata: mata drop _tt_xlsx_remap_sheet()
capture mata: mata drop _tt_xlsx_files()
capture mata: mata drop _tt_xlsx_slash()
capture mata: mata drop _tt_xlsx_quoted_files()
capture mata: mata drop _tt_xlsx_rmtree()
capture mata: mata drop _tt_xlsx_verify()
capture mata: mata drop _tt_xlsx_sheetnames_xml()
capture mata: mata drop _tt_xlsx_unescape()
capture mata: mata drop _tt_xlsx_check_manifest()
capture mata: mata drop _tt_xlsx_filesize()

mata:
mata set matastrict on

// Rewrite xl/styles.xml, and every worksheet whose cell format indices move,
// inside an unzipped workbook rooted at `root'.
void _tt_xlsx_compact_dir(string scalar root)
{
    string scalar styles, path
    string colvector sheets
    real colvector xfmap
    real scalar i, identity

    xfmap = J(0, 1, .)
    styles = _tt_xlsx_slurp(root + "/xl/styles.xml")
    styles = _tt_xlsx_compact_styles_xml(styles, xfmap)

    // _tt_xlsx_compact_styles_xml reports whether any pool actually lost a
    // record.  When none did, styles.xml is left untouched so the caller can
    // skip rebuilding the archive around an identical set of parts.
    if (st_local("_tt_changed") == "0") return

    _tt_xlsx_spit(root + "/xl/styles.xml", styles)

    if (rows(xfmap) == 0) return
    identity = 1
    for (i = 1; i <= rows(xfmap); i++) {
        if (xfmap[i] != i - 1) {
            identity = 0
            break
        }
    }
    // An identity map leaves every s="" reference in the sheets valid as written.
    if (identity) return

    sheets = _tt_xlsx_files(root + "/xl/worksheets")
    for (i = 1; i <= rows(sheets); i++) {
        path = sheets[i]
        if (substr(path, strlen(path) - 3, 4) != ".xml") continue
        _tt_xlsx_spit(path, _tt_xlsx_remap_sheet(_tt_xlsx_slurp(path), xfmap))
    }
}

string scalar _tt_xlsx_compact_styles_xml(string scalar styles,
    real colvector xfmap)
{
    string scalar out, body
    string colvector items, uniq, xfs, xfuniq
    real colvector fontmap, fillmap, bordermap, thismap
    real rowvector span
    real scalar i, changed
    string matrix pools

    out = styles
    fontmap = J(0, 1, .)
    fillmap = J(0, 1, .)
    bordermap = J(0, 1, .)
    // Counts how many records the four pools shed in total.  Zero means the
    // workbook is already compact and does not need to be rewritten.
    changed = 0
    st_local("_tt_changed", "1")

    pools = ("fonts", "<font", "fonts") \ ("fills", "<fill", "fills") \
        ("borders", "<border", "borders")

    for (i = 1; i <= rows(pools); i++) {
        span = _tt_xlsx_block(out, pools[i, 1])
        if (span[1] == 0) continue
        body = substr(out, span[2], span[3] - span[2])
        items = _tt_xlsx_pool_items(body, pools[i, 2])
        if (rows(items) == 0) continue

        thismap = J(0, 1, .)
        uniq = _tt_xlsx_dedupe(items, thismap)
        if (i == 1) fontmap = thismap
        else if (i == 2) fillmap = thismap
        else bordermap = thismap

        st_local("_tt_" + pools[i, 3] + "_before", strofreal(rows(items), "%18.0f"))
        st_local("_tt_" + pools[i, 3] + "_after", strofreal(rows(uniq), "%18.0f"))
        changed = changed + (rows(items) - rows(uniq))

        out = substr(out, 1, span[1] - 1) +
            "<" + pools[i, 1] + " count=" + char(34) +
            strofreal(rows(uniq), "%18.0f") + char(34) + ">" +
            invtokens(uniq', "") +
            "</" + pools[i, 1] + ">" +
            substr(out, span[4], .)
    }

    // cellStyleXfs and cellXfs both index the pools just collapsed.
    span = _tt_xlsx_block(out, "cellStyleXfs")
    if (span[1] != 0) {
        body = substr(out, span[2], span[3] - span[2])
        items = _tt_xlsx_pool_items(body, "<xf")
        if (rows(items) > 0) {
            for (i = 1; i <= rows(items); i++) {
                items[i] = _tt_xlsx_remap_attr(items[i], "fontId", fontmap)
                items[i] = _tt_xlsx_remap_attr(items[i], "fillId", fillmap)
                items[i] = _tt_xlsx_remap_attr(items[i], "borderId", bordermap)
            }
            out = substr(out, 1, span[1] - 1) +
                "<cellStyleXfs count=" + char(34) +
                strofreal(rows(items), "%18.0f") + char(34) + ">" +
                invtokens(items', "") + "</cellStyleXfs>" +
                substr(out, span[4], .)
        }
    }

    span = _tt_xlsx_block(out, "cellXfs")
    if (span[1] == 0) {
        st_local("_tt_changed", changed > 0 ? "1" : "0")
        return(out)
    }
    body = substr(out, span[2], span[3] - span[2])
    xfs = _tt_xlsx_pool_items(body, "<xf")
    if (rows(xfs) == 0) {
        st_local("_tt_changed", changed > 0 ? "1" : "0")
        return(out)
    }
    for (i = 1; i <= rows(xfs); i++) {
        xfs[i] = _tt_xlsx_remap_attr(xfs[i], "fontId", fontmap)
        xfs[i] = _tt_xlsx_remap_attr(xfs[i], "fillId", fillmap)
        xfs[i] = _tt_xlsx_remap_attr(xfs[i], "borderId", bordermap)
    }
    xfuniq = _tt_xlsx_dedupe(xfs, xfmap)
    st_local("_tt_formats_before", strofreal(rows(xfs), "%18.0f"))
    st_local("_tt_formats_after", strofreal(rows(xfuniq), "%18.0f"))
    changed = changed + (rows(xfs) - rows(xfuniq))
    st_local("_tt_changed", changed > 0 ? "1" : "0")

    out = substr(out, 1, span[1] - 1) +
        "<cellXfs count=" + char(34) + strofreal(rows(xfuniq), "%18.0f") +
        char(34) + ">" + invtokens(xfuniq', "") + "</cellXfs>" +
        substr(out, span[4], .)

    return(out)
}

// Locate <tag ...> ... </tag>.  Returns (open_start, body_start, close_start,
// after_close) as 1-based byte positions, or all zeros when absent.
real rowvector _tt_xlsx_block(string scalar s, string scalar tag)
{
    real scalar p, bodystart, closepos
    string scalar close

    p = strpos(s, "<" + tag + " ")
    if (p == 0) p = strpos(s, "<" + tag + ">")
    if (p == 0) return((0, 0, 0, 0))

    bodystart = strpos(substr(s, p, .), ">")
    if (bodystart == 0) return((0, 0, 0, 0))
    bodystart = p + bodystart

    close = "</" + tag + ">"
    closepos = strpos(substr(s, bodystart, .), close)
    if (closepos == 0) return((0, 0, 0, 0))
    closepos = bodystart + closepos - 1

    return((p, bodystart, closepos, closepos + strlen(close)))
}

// Split a style pool body into its records.  Splitting on the opening tag
// handles both the <xf .../> and <xf ...>...</xf> forms that xl() emits.
string colvector _tt_xlsx_pool_items(string scalar body, string scalar opentag)
{
    string rowvector parts
    string colvector out
    real scalar i, n

    if (body == "") return(J(0, 1, ""))
    parts = ustrsplit(body, opentag)
    n = cols(parts)
    if (n < 2) return(J(0, 1, ""))
    out = J(n - 1, 1, "")
    for (i = 2; i <= n; i++) out[i - 1] = opentag + parts[i]
    return(out)
}

// Collapse duplicates, preserving first-seen order.  `map' comes back as the
// old-index to new-index translation, both 0 based as OOXML numbers them.
string colvector _tt_xlsx_dedupe(string colvector items, real colvector map)
{
    transmorphic scalar seen
    string colvector uniq
    real scalar i, n, k

    n = rows(items)
    map = J(n, 1, .)
    uniq = J(n, 1, "")
    seen = asarray_create("string", 1)
    k = 0
    for (i = 1; i <= n; i++) {
        if (asarray_contains(seen, items[i])) {
            map[i] = asarray(seen, items[i])
        }
        else {
            k = k + 1
            uniq[k] = items[i]
            asarray(seen, items[i], k - 1)
            map[i] = k - 1
        }
    }
    if (k == 0) return(J(0, 1, ""))
    return(uniq[(1::k)])
}

// Rewrite one numeric attribute of a single record through `map'.
string scalar _tt_xlsx_remap_attr(string scalar item, string scalar attr,
    real colvector map)
{
    real scalar p, q, v
    string scalar key

    if (rows(map) == 0) return(item)
    key = " " + attr + "=" + char(34)
    p = strpos(item, key)
    if (p == 0) return(item)
    p = p + strlen(key)
    q = strpos(substr(item, p, .), char(34))
    if (q == 0) return(item)
    q = p + q - 1
    v = strtoreal(substr(item, p, q - p))
    if (v >= . | v < 0 | v != floor(v) | v + 1 > rows(map)) return(item)

    return(substr(item, 1, p - 1) + strofreal(map[v + 1], "%18.0f") +
        substr(item, q, .))
}

// Rewrite every cell format reference in one worksheet part.  Splitting on
// "<" isolates each element's attributes in its own piece, so a value that
// happens to contain s=" is never touched.
string scalar _tt_xlsx_remap_sheet(string scalar sheet, real colvector xfmap)
{
    string rowvector parts
    real scalar i

    parts = ustrsplit(sheet, "<")
    for (i = 1; i <= cols(parts); i++) {
        if (substr(parts[i], 1, 2) == "c ") {
            parts[i] = _tt_xlsx_remap_attr(parts[i], "s", xfmap)
        }
        else if (substr(parts[i], 1, 4) == "row ") {
            parts[i] = _tt_xlsx_remap_attr(parts[i], "s", xfmap)
        }
        else if (substr(parts[i], 1, 4) == "col ") {
            parts[i] = _tt_xlsx_remap_attr(parts[i], "style", xfmap)
        }
    }
    return(invtokens(parts, "<"))
}

string scalar _tt_xlsx_slurp(string scalar path)
{
    real scalar fh, n
    string scalar s

    fh = fopen(path, "r")
    fseek(fh, 0, 1)
    n = ftell(fh)
    fseek(fh, 0, -1)
    s = n > 0 ? fread(fh, n) : ""
    fclose(fh)
    return(s)
}

void _tt_xlsx_spit(string scalar path, string scalar s)
{
    real scalar fh

    // Mata's fopen() refuses to open an existing file for writing.
    unlink(path)
    fh = fopen(path, "w")
    fwrite(fh, s)
    fclose(fh)
}

// Every file below `base', depth first, as paths relative to `base'.
//
// dir() prefixes each entry with the platform separator, so on Windows the
// results come back as ".\xl\styles.xml" while every caller below builds its
// comparison strings with "/".  Left alone, _tt_xlsx_check_manifest() then
// matches neither its `prefix' nor its `skip' guard, counts the verify tree
// and the rebuilt archive as original parts, and rejects a perfectly good
// rebuild with r(459) -- which silently disables compaction on Windows and
// lets the style pools grow to the 65,536-record ceiling.  Normalizing here
// covers every caller at once and is a no-op on Unix.  It also keeps the file
// list handed to zipfile free of backslash entry names, which Excel and
// xl() both refuse to read back.
string colvector _tt_xlsx_files(string scalar base)
{
    string colvector out, subdirs
    real scalar i

    out = _tt_xlsx_slash(dir(base, "files", "*", 1))
    subdirs = _tt_xlsx_slash(dir(base, "dirs", "*", 1))
    for (i = 1; i <= rows(subdirs); i++) {
        out = out \ _tt_xlsx_files(subdirs[i])
    }
    return(out)
}

// subinstr() raises r(3200) on the J(0,1,"") that dir() returns for an empty
// match, and a leaf directory produces one on every recursion, so the empty
// case has to short-circuit rather than fall through to the replacement.
string colvector _tt_xlsx_slash(string colvector paths)
{
    if (rows(paths) == 0) return(paths)
    return(subinstr(paths, "\", "/", .))
}

string scalar _tt_xlsx_quoted_files(string scalar base)
{
    string colvector files

    files = _tt_xlsx_files(base)
    if (rows(files) == 0) return("")
    return(char(34) + invtokens(files', char(34) + " " + char(34)) + char(34))
}

void _tt_xlsx_rmtree(string scalar base)
{
    string colvector files, subdirs
    real scalar i

    files = dir(base, "files", "*", 1)
    for (i = 1; i <= rows(files); i++) unlink(files[i])
    subdirs = dir(base, "dirs", "*", 1)
    for (i = 1; i <= rows(subdirs); i++) _tt_xlsx_rmtree(subdirs[i])
    rmdir(base)
}

real scalar _tt_xlsx_filesize(string scalar path)
{
    real scalar fh, n

    fh = fopen(path, "r")
    fseek(fh, 0, 1)
    n = ftell(fh)
    fclose(fh)
    return(n)
}

// Compare what was handed to zipfile against what comes back out of the
// archive it wrote.  `sub' holds the unpacked rebuild and is excluded from
// the input side along with the archive itself.
void _tt_xlsx_check_manifest(string scalar root, string scalar sub,
    string scalar archive)
{
    string colvector orig, copy, oname, cname
    string scalar prefix, skip
    real scalar i, k

    prefix = root + "/" + sub + "/"
    skip = root + "/" + archive

    orig = _tt_xlsx_files(root)
    oname = J(0, 1, "")
    for (i = 1; i <= rows(orig); i++) {
        if (orig[i] == skip) continue
        if (substr(orig[i], 1, strlen(prefix)) == prefix) continue
        oname = oname \ substr(orig[i], strlen(root) + 2, .)
    }

    copy = _tt_xlsx_files(root + "/" + sub)
    cname = J(0, 1, "")
    for (i = 1; i <= rows(copy); i++) {
        cname = cname \ substr(copy[i], strlen(prefix) + 1, .)
    }

    if (rows(oname) != rows(cname)) {
        errprintf("rebuilt archive holds %f of %f parts\n", rows(cname),
            rows(oname))
        _error(459)
    }

    oname = sort(oname, 1)
    cname = sort(cname, 1)
    for (i = 1; i <= rows(oname); i++) {
        if (oname[i] != cname[i]) {
            errprintf("rebuilt archive is missing %s\n", oname[i])
            _error(459)
        }
        k = _tt_xlsx_filesize(root + "/" + oname[i])
        if (k != _tt_xlsx_filesize(prefix + cname[i])) {
            errprintf("rebuilt archive truncated %s\n", oname[i])
            _error(459)
        }
    }
}

// Sheet names, in tab order, read from an unpacked workbook.xml.  These are
// the names the original book would report, obtained without paying for an
// xl() load_book() of a workbook whose style pools are still uncollapsed.
//
// Returned as a COLUMN vector, because that is the shape get_sheets() hands
// back and the two are compared directly; a row vector compares unequal
// against every multi-sheet book and would silently disable compaction.
string colvector _tt_xlsx_sheetnames_xml(string scalar root)
{
    string scalar wb
    string rowvector parts
    string colvector out
    string scalar key
    real scalar i, p, q

    wb = _tt_xlsx_slurp(root + "/xl/workbook.xml")
    // ustrsplit() takes a regular expression; this literal has no
    // metacharacters in it, so it splits on the tag as written.
    parts = ustrsplit(wb, "<sheet ")
    out = J(0, 1, "")
    key = "name=" + char(34)
    for (i = 2; i <= cols(parts); i++) {
        p = strpos(parts[i], key)
        if (p == 0) continue
        p = p + strlen(key)
        q = strpos(substr(parts[i], p, .), char(34))
        if (q == 0) continue
        out = out \ _tt_xlsx_unescape(substr(parts[i], p, q - 1))
    }
    return(out)
}

// workbook.xml stores the sheet name XML-escaped while get_sheets() hands
// back the decoded name, so a book with a sheet called "A&B" compares unequal
// unless the five predefined entities are resolved first.  &amp; is resolved
// last: doing it first would turn a literal "&amp;lt;" into "<".
string scalar _tt_xlsx_unescape(string scalar s)
{
    string scalar out

    out = subinstr(s, "&lt;", "<", .)
    out = subinstr(out, "&gt;", ">", .)
    out = subinstr(out, "&quot;", char(34), .)
    out = subinstr(out, "&apos;", char(39), .)
    out = subinstr(out, "&amp;", "&", .)
    return(out)
}

// A rebuilt archive is accepted only if xl() still opens it and reports the
// same sheets, in the same order, as the workbook it would replace.  Only the
// rebuilt file is opened with xl(): that is the check that matters, since it
// proves Stata can still read what zipfile produced.  `root' is the unpacked
// tree the archive was built from, and supplies the expected names.
void _tt_xlsx_verify(string scalar rebuilt, string scalar root)
{
    class xl scalar b
    string colvector sa, sb

    sa = _tt_xlsx_sheetnames_xml(root)

    b = xl()
    b.load_book(rebuilt)
    sb = b.get_sheets()
    b.close_book()

    // get_sheets() returns an N x 1 column vector, so the count lives in
    // rows(); cols() is 1 for every workbook and compares equal always.
    if (rows(sa) != rows(sb)) {
        errprintf("compacted workbook lost a sheet\n")
        _error(459)
    }
    if (rows(sa) > 0) {
        if (sa != sb) {
            errprintf("compacted workbook does not match the original sheets\n")
            _error(459)
        }
    }
}

end
