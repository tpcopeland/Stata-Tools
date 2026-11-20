*! _tabtools_xlsx_compact_styles Version 1.2.1  2026/11/20
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
    version 17.0
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

        * The workbook is replaced only after the rebuilt archive verifies, so
        * a failed engine leaves it exactly as xl() closed it -- without the
        * queued cell styles.  Apply those through xl() instead, so a failure
        * costs speed, never formatting.
        _tabtools_xlsx_deferred_styles count using `"`using'"', local(_tt_pend)
        if `_engine_rc' & `_tt_pend' > 0 {
            if "`warning'" == "" {
                noisily display as text "note: fast style pass failed (rc `_engine_rc'); applying cell styles through xl()"
            }
            _tabtools_xlsx_deferred_styles legacy using `"`using'"'
            _tabtools_xlsx_deferred_styles clear
            capture _tabtools_xlsx_compact_engine using `"`using'"'
            local _engine_rc = _rc
        }
        _tabtools_xlsx_deferred_styles clear

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
    version 17.0
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

        * Cell styles queued by _tabtools_xlsx_apply_styles, defer are
        * written into the unpacked XML first; the dedupe below then folds
        * them into the pools like any other record.
        _tabtools_xlsx_deferred_styles count using `"`using'"', local(_tt_pend)
        if `_tt_pend' > 0 {
            _tabtools_xlsx_deferred_styles apply using `"`using'"', root(".")
        }

        mata: _tt_xlsx_compact_dir(".")
        if `_tt_pend' > 0 local _tt_changed 1

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

version 17.0
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

* matastrict is a session setting: save the caller's value here and
* restore it after the block, so loading this file never leaks it.
local _tt_ms0 = c(matastrict)
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

        st_local("_tt_" + pools[i, 3] + "_before", ustrregexra(strofreal(rows(items), "%18.0f"), "-(?=[0.,]+\z)", ""))
        st_local("_tt_" + pools[i, 3] + "_after", ustrregexra(strofreal(rows(uniq), "%18.0f"), "-(?=[0.,]+\z)", ""))
        changed = changed + (rows(items) - rows(uniq))

        out = substr(out, 1, span[1] - 1) +
            "<" + pools[i, 1] + " count=" + char(34) +
            ustrregexra(strofreal(rows(uniq), "%18.0f"), "-(?=[0.,]+\z)", "") + char(34) + ">" +
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
                ustrregexra(strofreal(rows(items), "%18.0f"), "-(?=[0.,]+\z)", "") + char(34) + ">" +
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
    st_local("_tt_formats_before", ustrregexra(strofreal(rows(xfs), "%18.0f"), "-(?=[0.,]+\z)", ""))
    st_local("_tt_formats_after", ustrregexra(strofreal(rows(xfuniq), "%18.0f"), "-(?=[0.,]+\z)", ""))
    changed = changed + (rows(xfs) - rows(xfuniq))
    st_local("_tt_changed", changed > 0 ? "1" : "0")

    out = substr(out, 1, span[1] - 1) +
        "<cellXfs count=" + char(34) + ustrregexra(strofreal(rows(xfuniq), "%18.0f"), "-(?=[0.,]+\z)", "") +
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

    return(substr(item, 1, p - 1) + ustrregexra(strofreal(map[v + 1], "%18.0f"), "-(?=[0.,]+\z)", "") +
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
mata: mata set matastrict `_tt_ms0'

* Folded from _tabtools_xlsx_deferred_styles.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _tabtools_xlsx_deferred_styles Version 1.2.0  2026/11/19
* Apply queued cell style rules directly to a closed xlsx workbook's XML
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* Stata's xl() never reuses a style record: every ranged set_font(),
* set_font_bold(), set_fill_pattern(), set_*_border() or alignment call appends
* records for each cell it touches.  Styling a large table therefore costs time
* in proportion to the number of cells and, past a few thousand rows, overflows
* the workbook's style pools, which xl() reports as a misleading
* "invalid alignment format" / "invalid font name" error.
*
* _tabtools_xlsx_apply_styles, defer queues the cell-level rules here instead.
* After close_book(), _tabtools_xlsx_compact_styles unpacks the workbook and
* calls _tt_xlsx_pend_apply(): each cell's final style is composed from the
* queued rules in order (later rules win per attribute, as successive xl()
* calls do), each DISTINCT style is written to styles.xml once, and each styled
* cell gets its s= index.  Row heights, column widths and merges never enter
* the queue; they are still applied through xl() at rule time.
*
*
* Mata compiled while an ado-file autoloads is private to that file, so every
* other file reaches this code through the subcommands below:
*   count  using file, local(name)   queued rule count for file -> c_local
*   apply  using file, root(dir)     write the queue into the unzipped workbook
*   legacy using file                apply the queue through xl() (fallback)
*   clear                            drop the queue

capture program drop _tabtools_xlsx_deferred_styles
program define _tabtools_xlsx_deferred_styles, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken sub 0 : 0, parse(" ,")
        if "`sub'" == "count" {
            syntax using/ , Local(name)
            mata: st_local("_n", strofreal(_tt_xlsx_pend_count(`"`using'"')))
            c_local `local' `_n'
        }
        else if "`sub'" == "apply" {
            syntax using/ , ROOT(string)
            mata: _tt_xlsx_pend_apply(`"`root'"', `"`using'"')
        }
        else if "`sub'" == "legacy" {
            syntax using/
            mata: st_local("_n", strofreal(_tt_xlsx_pend_count(`"`using'"')))
            if `_n' > 0 {
                tempname bk mrules
                mata: _tt_xlsx_pend_groups(`"`using'"', "`mrules'")
                mata: `bk' = xl()
                capture noisily {
                    mata: `bk'.load_book(`"`using'"')
                    mata: `bk'.set_mode("open")
                    forvalues g = 1/`_ngroups' {
                        mata: `bk'.set_sheet(`"`_gsheet`g''"')
                        _tabtools_xlsx_apply_styles, book(`bk') sheet(`"`_gsheet`g''"') ///
                            rules(`mrules'`g') font(`"`_gfont`g''"') altfont(`"`_galt`g''"') ///
                            color1(`"`_gc1`g''"') color2(`"`_gc2`g''"') ///
                            color3(`"`_gc3`g''"') color4(`"`_gc4`g''"')
                    }
                }
                local rc = _rc
                * stata-dev-ignore: capture-rc — best-effort cleanup after local rc = _rc saved the apply-styles status; a failed close must not replace it, and the next line exits with rc
                capture mata: `bk'.close_book()
                capture mata: mata drop `bk'
                forvalues g = 1/`_ngroups' {
                    capture matrix drop `mrules'`g'
                }
                if `rc' exit `rc'
            }
        }
        else if "`sub'" == "clear" {
            mata: (void) rmexternal("_tt_xp_rules")
            mata: (void) rmexternal("_tt_xp_meta")
        }
        else {
            display as error "_tabtools_xlsx_deferred_styles: unknown subcommand `sub'"
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 17.0
capture mata: mata drop _tt_xlsx_pend_count()
capture mata: mata drop _tt_xlsx_pend_groups()
capture mata: mata drop _tt_xlsx_pend_apply()
capture mata: mata drop _tt_xlsx_pend_sheet()
capture mata: mata drop _tt_xlsx_pend_part()
capture mata: mata drop _tt_xlsx_pend_attr()
capture mata: mata drop _tt_xlsx_pend_setattr()
capture mata: mata drop _tt_xlsx_pend_colnum()
capture mata: mata drop _tt_xlsx_pend_colname()
capture mata: mata drop _tt_xlsx_pend_hex()
capture mata: mata drop _tt_xlsx_pend_named()
capture mata: mata drop _tt_xlsx_pend_esc()
capture mata: mata drop _tt_xlsx_pend_unesc()
capture mata: mata drop _tt_xlsx_pend_tagend()
capture mata: mata drop _tt_xlsx_pend_id()
capture mata: mata drop _tt_xlsx_pend_pool()
capture mata: mata drop _tt_xlsx_pend_setpool()
capture mata: mata drop _tt_xlsx_pend_read()
capture mata: mata drop _tt_xlsx_pend_write()

local _tt_ms0 = c(matastrict)
mata:
mata set matastrict on

real scalar _tt_xlsx_pend_count(string scalar file)
{
    pointer(string matrix) scalar mp
    if ((mp = findexternal("_tt_xp_meta")) == NULL) return(0)
    if (rows(*mp) == 0) return(0)
    return(sum((*mp)[., 1] :== file))
}

// Group the queue for `file' into runs that share sheet, font and colors, and
// hand each run to Stata as a rules matrix for the xl() fallback.
void _tt_xlsx_pend_groups(string scalar file, string scalar mprefix)
{
    real matrix R
    string matrix M
    real scalar i, g, start
    string scalar gs

    R = *findexternal("_tt_xp_rules")
    M = *findexternal("_tt_xp_meta")
    R = select(R, M[., 1] :== file)
    M = select(M, M[., 1] :== file)
    g = 0
    start = 1
    for (i = 1; i <= rows(R); i++) {
        if (i < rows(R)) {
            if (M[i + 1, (2..8)] == M[i, (2..8)]) continue
        }
        g = g + 1
        gs = strofreal(g)
        st_matrix(mprefix + gs, R[(start::i), .])
        st_local("_gsheet" + gs, M[i, 2])
        st_local("_gfont" + gs, M[i, 3])
        st_local("_galt" + gs, M[i, 4])
        st_local("_gc1" + gs, M[i, 5])
        st_local("_gc2" + gs, M[i, 6])
        st_local("_gc3" + gs, M[i, 7])
        st_local("_gc4" + gs, M[i, 8])
        start = i + 1
    }
    st_local("_ngroups", strofreal(g))
}

// ---- direct XML application ---------------------------------------------

// Apply every queued rule for the file to the workbook unpacked under root.
void _tt_xlsx_pend_apply(string scalar root, string scalar file)
{
    real matrix R
    string matrix M
    string colvector sheets
    string scalar styles
    real scalar i

    if (_tt_xlsx_pend_count(file) == 0) return
    // QA hook: lets the suite prove the xl() fallback keeps the formatting.
    if (st_global("TABTOOLS_QA_FORCE_FASTSTYLE_FAIL") == "1") {
        errprintf("deferred styles: forced failure (QA)\n")
        _error(498)
    }
    R = *findexternal("_tt_xp_rules")
    M = *findexternal("_tt_xp_meta")
    R = select(R, M[., 1] :== file)
    M = select(M, M[., 1] :== file)

    styles =_tt_xlsx_pend_read(root + "/xl/styles.xml")
    sheets = uniqrows(M[., 2])
    for (i = 1; i <= rows(sheets); i++) {
        styles = _tt_xlsx_pend_sheet(root, sheets[i],
            select(R, M[., 2] :== sheets[i]),
            select(M, M[., 2] :== sheets[i]), styles)
    }
    _tt_xlsx_pend_write(root + "/xl/styles.xml", styles)
}

// Compose, register and assign the styles of one sheet; returns styles.xml.
string scalar _tt_xlsx_pend_sheet(string scalar root, string scalar sheet,
    real matrix R, string matrix M, string scalar styles)
{
    transmorphic scalar fontids, colorids
    string colvector fontnames, colorhex
    real matrix A, K, U
    real colvector idx, touched, T, o, gid, style_of, rnum, keep
    real rowvector rv, cv
    real scalar nR, nC, i, j, g, G, op, k, nfont, nfill, nborder, nxf, v
    real scalar fid, flid, bid, p, q, r, c, cnum, rowtouched, maxr, maxc, nrow
    string scalar path, sh, head, tail, body, fonts, fills, borders, xfs, x
    string scalar ha, va, cellxml, opentag, content, newrow, ref, dim
    string rowvector rparts, cparts
    string colvector rxml, cells
    real colvector ccol
    real rowvector span

    path = _tt_xlsx_pend_part(root, sheet)
    if (path == "") {
        errprintf("deferred styles: sheet %s not found in workbook\n", sheet)
        _error(198)
    }

    // --- 1. overlay the rules on an attribute grid ---
    // columns: 1 font name id, 2 size, 3 bold, 4 italic, 5 wrap, 6 halign,
    // 7 valign, 8 fill color id, 9 top, 10 bottom, 11 left, 12 right border,
    // 13 font color id.  Missing = never set by any rule.
    nR = max(R[., 3])
    nC = max(R[., 5])
    A = J(nR * nC, 13, .)
    fontids = asarray_create("string", 1)
    colorids = asarray_create("string", 1)
    fontnames = J(0, 1, "")
    colorhex = J(0, 1, "")
    for (i = 1; i <= rows(R); i++) {
        op = R[i, 1]
        rv = (R[i, 2]::R[i, 3])'
        cv = (R[i, 4]..R[i, 5])
        // cell index (r - 1) * nC + c over the rectangle, as an outer sum
        idx = vec(((rv' :- 1) * nC) * J(1, cols(cv), 1) + J(cols(rv), 1, 1) * cv)
        if (op == 1 | op == 15) {
            x = M[i, 9]
            A[idx, 1] = J(rows(idx), 1, _tt_xlsx_pend_id(fontids, fontnames, x))
            A[idx, 2] = J(rows(idx), 1, R[i, 6])
            if (op == 15) {
                x = _tt_xlsx_pend_hex(M[i, 10])
                A[idx, 13] = J(rows(idx), 1, _tt_xlsx_pend_id(colorids, colorhex, x))
            }
        }
        else if (op >= 2 & op <= 6) {
            A[idx, op + 1] = J(rows(idx), 1, R[i, 7])
        }
        else if (op == 7) {
            x = _tt_xlsx_pend_hex(M[i, 10])
            A[idx, 8] = J(rows(idx), 1, _tt_xlsx_pend_id(colorids, colorhex, x))
        }
        else if (op >= 8 & op <= 11) {
            A[idx, op + 1] = J(rows(idx), 1, R[i, 7])
        }
    }
    touched = rowmissing(A) :< 13
    T = selectindex(touched)
    if (rows(T) == 0) return(styles)

    // --- 2. distinct styles ---
    K = editmissing(A[T, .], -1)
    o = order(K, (1..13))
    gid = J(rows(T), 1, .)
    G = 0
    for (i = 1; i <= rows(o); i++) {
        if (i == 1) G = 1
        else if (K[o[i], .] != K[o[i - 1], .]) G = G + 1
        gid[o[i]] = G
    }
    U = J(G, 13, .)
    for (i = 1; i <= rows(T); i++) U[gid[i], .] = K[i, .]

    // --- 3. register one font/fill/border/xf per distinct style ---
    nfont = _tt_xlsx_pend_pool(styles, "fonts")
    nfill = _tt_xlsx_pend_pool(styles, "fills")
    nborder = _tt_xlsx_pend_pool(styles, "borders")
    nxf = _tt_xlsx_pend_pool(styles, "cellXfs")
    if (nfont < 1 | nfill < 1 | nborder < 1 | nxf < 1) {
        errprintf("deferred styles: styles.xml has no base style pools\n")
        _error(198)
    }
    fonts = fills = borders = xfs = ""
    flid = nfill
    for (g = 1; g <= G; g++) {
        // font: schema order b, i, sz, color, name
        x = "<font>"
        if (U[g, 3] == 1) x = x + "<b/>"
        if (U[g, 4] == 1) x = x + "<i/>"
        x = x + `"<sz val=""' + ustrregexra(strofreal(U[g, 2] < 0 ? 11 : U[g, 2], "%9.0g"), "-(?=[0.,]+\z)", "") + `""/>"'
        if (U[g, 13] >= 1) x = x + `"<color rgb="FF"' + colorhex[U[g, 13]] + `""/>"'
        x = x + `"<name val=""' + _tt_xlsx_pend_esc(U[g, 1] < 1 ? "Calibri" : fontnames[U[g, 1]]) + `""/></font>"'
        fonts = fonts + x
        fid = nfont + g - 1

        if (U[g, 8] >= 1) {
            fills = fills + `"<fill><patternFill patternType="solid"><fgColor rgb="FF"' +
                colorhex[U[g, 8]] + `""/><bgColor indexed="64"/></patternFill></fill>"'
            v = flid
            flid = flid + 1
        }
        else v = 0

        x = "<border>"
        for (k = 1; k <= 4; k++) {
            // xml order left, right, top, bottom; grid columns 11, 12, 9, 10
            j = (11, 12, 9, 10)[k]
            ref = ("left", "right", "top", "bottom")[k]
            if (U[g, j] >= 1 & U[g, j] <= 3) {
                x = x + "<" + ref + `" style=""' + ("thin", "medium", "thick")[U[g, j]] + `""/>"'
            }
            else x = x + "<" + ref + "/>"
        }
        borders = borders + x + "<diagonal/></border>"
        bid = nborder + g - 1

        ha = U[g, 6] >= 1 ? ("left", "center", "right")[U[g, 6]] : "general"
        va = U[g, 7] >= 1 ? ("bottom", "center", "top")[U[g, 7]] : "bottom"
        xfs = xfs + `"<xf numFmtId="0" fontId=""' + strofreal(fid) +
            `"" fillId=""' + strofreal(v) + `"" borderId=""' + strofreal(bid) +
            `"" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal=""' +
            ha + `"" vertical=""' + va + `"" wrapText=""' + (U[g, 5] == 1 ? "1" : "0") +
            `""/></xf>"'
    }
    styles = _tt_xlsx_pend_setpool(styles, "fonts", nfont + G, fonts)
    if (flid > nfill) styles = _tt_xlsx_pend_setpool(styles, "fills", flid, fills)
    styles = _tt_xlsx_pend_setpool(styles, "borders", nborder + G, borders)
    styles = _tt_xlsx_pend_setpool(styles, "cellXfs", nxf + G, xfs)

    // style index for every grid cell (missing = untouched)
    style_of = J(nR * nC, 1, .)
    style_of[T] = nxf :+ gid :- 1

    // --- 4. rewrite sheetData ---
    sh = _tt_xlsx_pend_read(path)
    p = strpos(sh, "<sheetData>")
    if (p == 0) {
        p = strpos(sh, "<sheetData/>")
        if (p == 0) {
            errprintf("deferred styles: sheet %s has no sheetData\n", sheet)
            _error(198)
        }
        head = substr(sh, 1, p - 1)
        tail = substr(sh, p + strlen("<sheetData/>"), .)
        body = ""
    }
    else {
        head = substr(sh, 1, p - 1)
        q = strpos(sh, "</sheetData>")
        body = substr(sh, p + strlen("<sheetData>"), q - p - strlen("<sheetData>"))
        tail = substr(sh, q + strlen("</sheetData>"), .)
    }

    rparts = ustrsplit(body, "<row ")
    rnum = J(cols(rparts) + nR, 1, .)
    rxml = J(cols(rparts) + nR, 1, "")
    nrow = 0
    keep = J(nR, 1, 0)
    for (i = 2; i <= cols(rparts); i++) {
        x = "<row " + rparts[i]
        r = strtoreal(_tt_xlsx_pend_attr(x, "r"))
        rowtouched = (r >= 1 & r <= nR)
        if (rowtouched) rowtouched = any(style_of[((r - 1) * nC + 1)::(r * nC)] :< .)
        if (!rowtouched) {
            nrow = nrow + 1
            rnum[nrow] = r
            rxml[nrow] = x
            continue
        }
        keep[r] = 1
        q = strpos(x, ">")
        if (substr(x, q - 1, 1) == "/") {
            opentag = substr(x, 1, q - 2) + ">"
            content = ""
        }
        else {
            opentag = substr(x, 1, q)
            content = substr(x, q + 1, strlen(x) - q - strlen("</row>"))
        }
        cparts = ustrsplit(content, "<c ")
        cells = J(0, 1, "")
        ccol = J(0, 1, .)
        for (j = 2; j <= cols(cparts); j++) {
            cellxml = "<c " + cparts[j]
            ref = _tt_xlsx_pend_attr(cellxml, "r")
            cnum = _tt_xlsx_pend_colnum(ref)
            if (cnum >= 1 & cnum <= nC) {
                v = style_of[(r - 1) * nC + cnum]
                if (v < .) cellxml = _tt_xlsx_pend_setattr(cellxml, "s", strofreal(v))
            }
            cells = cells \ cellxml
            ccol = ccol \ cnum
        }
        // styled cells that xl() never wrote get an empty styled cell
        for (c = 1; c <= nC; c++) {
            v = style_of[(r - 1) * nC + c]
            if (v >= .) continue
            if (any(ccol :== c)) continue
            cells = cells \ (`"<c r=""' + _tt_xlsx_pend_colname(c) + strofreal(r) + `"" s=""' + strofreal(v) + `""/>"')
            ccol = ccol \ c
        }
        o = order(ccol, 1)
        newrow = opentag + invtokens(cells[o]', "") + "</row>"
        nrow = nrow + 1
        rnum[nrow] = r
        rxml[nrow] = newrow
    }
    // styled rows that xl() never wrote
    for (r = 1; r <= nR; r++) {
        if (keep[r]) continue
        idx = style_of[((r - 1) * nC + 1)::(r * nC)]
        if (!any(idx :< .)) continue
        newrow = `"<row r=""' + strofreal(r) + `"">"'
        for (c = 1; c <= nC; c++) {
            if (idx[c] >= .) continue
            newrow = newrow + `"<c r=""' + _tt_xlsx_pend_colname(c) + strofreal(r) + `"" s=""' + strofreal(idx[c]) + `""/>"'
        }
        nrow = nrow + 1
        rnum[nrow] = r
        rxml[nrow] = newrow + "</row>"
    }
    if (nrow > 0) {
        rnum = rnum[(1::nrow)]
        rxml = rxml[(1::nrow)]
        o = order(rnum, 1)
        body = invtokens(rxml[o]', "")
    }
    else body = ""

    // keep <dimension> covering every styled cell
    maxr = nrow > 0 ? max(rnum) : 1
    maxc = nC
    span = (strpos(head, "<dimension ref="), 0)
    if (span[1] > 0) {
        dim = _tt_xlsx_pend_attr(substr(head, span[1], .), "ref")
        p = strpos(dim, ":")
        if (p > 0) {
            x = substr(dim, p + 1, .)
            c = _tt_xlsx_pend_colnum(x)
            r = strtoreal(substr(x, strlen(_tt_xlsx_pend_colname(c)) + 1, .))
            if (c > maxc) maxc = c
            if (r > maxr) maxr = r
            head = subinstr(head, `"<dimension ref=""' + dim + `"""',
                `"<dimension ref="A1:"' + _tt_xlsx_pend_colname(maxc) + strofreal(maxr) + `"""', 1)
        }
    }
    _tt_xlsx_pend_write(path, head + "<sheetData>" + body + "</sheetData>" + tail)
    return(styles)
}

// worksheet part path for a sheet name, via workbook.xml and its rels
string scalar _tt_xlsx_pend_part(string scalar root, string scalar sheet)
{
    string scalar wb, rels, rid, target
    string rowvector parts
    real scalar i

    wb = _tt_xlsx_pend_read(root + "/xl/workbook.xml")
    rels = _tt_xlsx_pend_read(root + "/xl/_rels/workbook.xml.rels")
    rid = ""
    parts = ustrsplit(wb, "<sheet ")
    for (i = 2; i <= cols(parts); i++) {
        if (strlower(_tt_xlsx_pend_unesc(_tt_xlsx_pend_attr("<sheet " + parts[i], "name"))) == strlower(sheet)) {
            rid = _tt_xlsx_pend_attr("<sheet " + parts[i], "r:id")
            break
        }
    }
    if (rid == "") return("")
    parts = ustrsplit(rels, "<Relationship ")
    for (i = 2; i <= cols(parts); i++) {
        if (_tt_xlsx_pend_attr("<Relationship " + parts[i], "Id") == rid) {
            target = _tt_xlsx_pend_attr("<Relationship " + parts[i], "Target")
            if (substr(target, 1, 1) == "/") return(root + target)
            return(root + "/xl/" + target)
        }
    }
    return("")
}

// Position of the ">" that closes the first tag of x (0 when absent). A ">"
// inside a quoted attribute value is skipped: xl() escapes "<" in a sheet
// name as &lt; but writes ">" raw, so <sheet name="Age >65" r:id="rId3"/>
// ended at the first ">" and lost r:id, and the fast style pass failed.
real scalar _tt_xlsx_pend_tagend(string scalar x)
{
    real scalar pos, gt, q1, q2, qt, qend
    string scalar seg, qc

    pos = 1
    while (pos <= strlen(x)) {
        gt = strpos(substr(x, pos, .), ">")
        if (gt == 0) return(0)
        seg = substr(x, pos, gt - 1)
        q1 = strpos(seg, char(34))
        q2 = strpos(seg, char(39))
        if (q1 == 0 & q2 == 0) return(pos + gt - 1)
        // skip the attribute value opened by the earlier quote
        if (q1 == 0 | (q2 > 0 & q2 < q1)) {
            qt = q2
            qc = char(39)
        }
        else {
            qt = q1
            qc = char(34)
        }
        qend = strpos(substr(x, pos + qt, .), qc)
        if (qend == 0) return(0)
        pos = pos + qt + qend
    }
    return(0)
}

// value of attribute a in the first element of x ("" when absent)
string scalar _tt_xlsx_pend_attr(string scalar x, string scalar a)
{
    real scalar p, q, e
    string scalar key

    e = _tt_xlsx_pend_tagend(x)
    if (e == 0) e = strlen(x)
    key = " " + a + "=" + char(34)
    p = strpos(substr(x, 1, e), key)
    if (p == 0) return("")
    p = p + strlen(key)
    q = strpos(substr(x, p, .), char(34))
    if (q == 0) return("")
    return(substr(x, p, q - 1))
}

// set (or add) attribute a on a cell's opening tag
string scalar _tt_xlsx_pend_setattr(string scalar x, string scalar a, string scalar v)
{
    real scalar e, p, q
    string scalar key, tagpart

    e = _tt_xlsx_pend_tagend(x)
    tagpart = substr(x, 1, e)
    key = " " + a + "=" + char(34)
    p = strpos(tagpart, key)
    if (p > 0) {
        q = strpos(substr(x, p + strlen(key), .), char(34))
        return(substr(x, 1, p - 1) + key + v + char(34) + substr(x, p + strlen(key) + q, .))
    }
    // insert right after r="..."
    p = strpos(tagpart, " r=" + char(34))
    if (p == 0) return(substr(x, 1, 2) + key + v + char(34) + substr(x, 3, .))
    q = strpos(substr(x, p + 4, .), char(34))
    p = p + 4 + q
    return(substr(x, 1, p - 1) + key + v + char(34) + substr(x, p, .))
}

real scalar _tt_xlsx_pend_colnum(string scalar ref)
{
    real scalar i, n, ch

    n = 0
    for (i = 1; i <= strlen(ref); i++) {
        ch = ascii(substr(ref, i, 1))
        if (ch < 65 | ch > 90) break
        n = n * 26 + (ch - 64)
    }
    return(n)
}

string scalar _tt_xlsx_pend_colname(real scalar cin)
{
    real scalar c
    string scalar s

    c = cin
    s = ""
    while (c > 0) {
        s = char(65 + mod(c - 1, 26)) + s
        c = floor((c - 1) / 26)
    }
    return(s)
}

// "R G B" or a Stata color name -> "RRGGBB"
string scalar _tt_xlsx_pend_hex(string scalar color)
{
    string rowvector t
    real scalar i, v
    string scalar out, h

    t = tokens(color)
    if (cols(t) == 1) t = tokens(_tt_xlsx_pend_named(t[1]))
    // stata-dev-ignore: shape-dispatch — t holds the whitespace tokens of one color string; three tokens (R G B) is the validity test of that string, not a matrix layout dispatch
    if (cols(t) != 3) {
        errprintf("deferred styles: cannot resolve color %s\n", color)
        _error(198)
    }
    out = ""
    for (i = 1; i <= 3; i++) {
        v = strtoreal(t[i])
        if (v >= . | v < 0 | v > 255 | v != floor(v)) {
            errprintf("deferred styles: invalid color %s\n", color)
            _error(198)
        }
        h = inbase(16, v)
        if (strlen(h) == 1) h = "0" + h
        out = out + h
    }
    return(strupper(out))
}

// Color name -> "R G B".  xl() understands the CSS/HTML color names, so the
// names it accepts map to exactly the RGB xl() writes (probed 2026-09-29).
// The remaining Stata color names that tabtools' validator accepts are
// rejected by xl() with r(16136); they resolve through Stata's own
// color-<name>.style definitions instead of failing the export.
string scalar _tt_xlsx_pend_named(string scalar name)
{
    string matrix css
    string scalar fn, line, n
    real scalar fh, p, i

    css = J(23, 2, "")
    css[1, .]  = ("black", "0 0 0")
    css[2, .]  = ("blue", "0 0 255")
    css[3, .]  = ("brown", "165 42 42")
    css[4, .]  = ("cyan", "0 255 255")
    css[5, .]  = ("dimgray", "105 105 105")
    css[6, .]  = ("gold", "255 215 0")
    css[7, .]  = ("gray", "128 128 128")
    css[8, .]  = ("green", "0 128 0")
    css[9, .]  = ("khaki", "240 230 140")
    css[10, .] = ("lavender", "230 230 250")
    css[11, .] = ("lime", "0 255 0")
    css[12, .] = ("magenta", "255 0 255")
    css[13, .] = ("maroon", "128 0 0")
    css[14, .] = ("navy", "0 0 128")
    css[15, .] = ("olive", "128 128 0")
    css[16, .] = ("orange", "255 165 0")
    css[17, .] = ("pink", "255 192 203")
    css[18, .] = ("purple", "128 0 128")
    css[19, .] = ("red", "255 0 0")
    css[20, .] = ("sienna", "160 82 45")
    css[21, .] = ("teal", "0 128 128")
    css[22, .] = ("white", "255 255 255")
    css[23, .] = ("yellow", "255 255 0")
    n = strlower(name)
    for (i = 1; i <= rows(css); i++) {
        if (css[i, 1] == n) return(css[i, 2])
    }

    fn = findfile("color-" + n + ".style")
    if (fn == "") return("")
    fh = fopen(fn, "r")
    while ((line = fget(fh)) != J(0, 0, "")) {
        line = strtrim(line)
        if (substr(line, 1, 7) == "set rgb") {
            fclose(fh)
            p = strpos(line, char(34))
            line = substr(line, p + 1, .)
            return(substr(line, 1, strpos(line, char(34)) - 1))
        }
    }
    fclose(fh)
    return("")
}

string scalar _tt_xlsx_pend_esc(string scalar s)
{
    string scalar out
    out = subinstr(s, "&", "&amp;", .)
    out = subinstr(out, "<", "&lt;", .)
    out = subinstr(out, ">", "&gt;", .)
    out = subinstr(out, char(34), "&quot;", .)
    return(out)
}

string scalar _tt_xlsx_pend_unesc(string scalar s)
{
    string scalar out
    out = subinstr(s, "&quot;", char(34), .)
    out = subinstr(out, "&apos;", "'", .)
    out = subinstr(out, "&lt;", "<", .)
    out = subinstr(out, "&gt;", ">", .)
    out = subinstr(out, "&amp;", "&", .)
    return(out)
}

real scalar _tt_xlsx_pend_id(transmorphic scalar ids, string colvector names,
    string scalar key)
{
    if (asarray_contains(ids, key)) return(asarray(ids, key))
    names = names \ key
    asarray(ids, key, rows(names))
    return(rows(names))
}

// count= of a style pool (0 when absent)
real scalar _tt_xlsx_pend_pool(string scalar styles, string scalar tag)
{
    real scalar p
    string scalar x

    p = strpos(styles, "<" + tag + " ")
    if (p == 0) return(0)
    x = substr(styles, p, strpos(substr(styles, p, .), ">"))
    return(strtoreal(_tt_xlsx_pend_attr(x, "count")))
}

string scalar _tt_xlsx_pend_setpool(string scalar styles, string scalar tag,
    real scalar n, string scalar add)
{
    real scalar p, e, q
    string scalar open, close

    p = strpos(styles, "<" + tag + " ")
    e = p + strpos(substr(styles, p, .), ">") - 1
    open = substr(styles, p, e - p + 1)
    close = "</" + tag + ">"
    q = strpos(styles, close)
    if (p == 0 | q == 0 | substr(open, strlen(open) - 1, 1) == "/") {
        errprintf("deferred styles: cannot extend %s pool\n", tag)
        _error(198)
    }
    open = subinstr(open, `" count=""' + _tt_xlsx_pend_attr(open, "count") + `"""',
        `" count=""' + ustrregexra(strofreal(n, "%18.0f"), "-(?=[0.,]+\z)", "") + `"""', 1)
    return(substr(styles, 1, p - 1) + open + substr(styles, e + 1, q - e - 1) +
        add + substr(styles, q, .))
}

string scalar _tt_xlsx_pend_read(string scalar path)
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

void _tt_xlsx_pend_write(string scalar path, string scalar s)
{
    real scalar fh

    unlink(path)
    fh = fopen(path, "w")
    fwrite(fh, s)
    fclose(fh)
}

end
mata: mata set matastrict `_tt_ms0'
