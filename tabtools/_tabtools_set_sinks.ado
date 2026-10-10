*! _tabtools_set_sinks Version 2.6.2  2026/10/10
*! Resolve and track the session workbook/Markdown targets (tabtools set)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

/*
    _tabtools_set_sinks resolve , [xlsx(path) markdown(path) mdappend
                                   cmd(name) noxlsx]
        Fills in a sink the caller left empty from the session settings of
        -tabtools set workbook/markdown-. An explicit option always wins.
        noxlsx: the caller has no workbook sink of its own to fill.
        Sets in the caller (every exit path assigns):
            _ss_xlsx       resolved workbook path ("" when none)
            _ss_md         resolved Markdown path ("" when none)
            _ss_mdappend   "mdappend" when the Markdown write must append
            _ss_xlsx_sess  1 when _ss_xlsx came from the session
            _ss_md_sess    1 when _ss_md came from the session
        Prints "(tabtools: using session workbook "...")" and the Markdown
        equivalent, so the hidden target is visible in the log.

    _tabtools_set_sinks xlsxstart [, path(file)]
        Call immediately before writing the session workbook (with path():
        before writing file, acting only when file is the session workbook;
        _tabtools_xlsx_write does this for every command). On the first
        write since -tabtools set workbook- the file is erased, so the run
        starts the workbook over; the flag is then cleared and later writes
        add sheets to it.

    _tabtools_set_sinks xlsxdone , path(file)
        After writing file in place (stacktab reads the workbook it writes):
        clears the first-write flag when file is the session workbook,
        without erasing it.

    _tabtools_set_sinks mddone [, path(file)]
        Call after the session Markdown file (or file) was written; clears
        its flag so later writes append. _tabtools_markdown_write does this
        for every command.
*/

program define _tabtools_set_sinks, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _x ""
    local _m ""
    local _a ""
    local _xs 0
    local _ms 0
    gettoken _action 0 : 0, parse(" ,")
    capture noisily {
        if "`_action'" == "resolve" {
            syntax , [XLSX(string) MARKdown(string) MDAPPend CMD(string) NOXLSX]
            local _x `"`xlsx'"'
            local _m `"`markdown'"'
            local _a "`mdappend'"
            if `"`_x'"' == "" & "`noxlsx'" == "" & `"$TABTOOLS_set_workbook"' != "" {
                local _x `"$TABTOOLS_set_workbook"'
                local _xs 1
                display as text `"(tabtools: using session workbook "`_x'")"'
            }
            if `"`_m'"' == "" & `"$TABTOOLS_set_markdown"' != "" {
                local _m `"$TABTOOLS_set_markdown"'
                local _ms 1
                * First write since tabtools set markdown replaces the file;
                * every later one appends. An explicit mdappend appends. A file
                * this session already wrote is never replaced.
                if "$TABTOOLS_set_markdown_fresh" != "1" local _a "mdappend"
                mata: st_local("_wr", strofreal(_tt_ss_iswritten(st_local("_m"))))
                if `_wr' local _a "mdappend"
                local _how = cond("`_a'" == "mdappend", "append", "replace")
                display as text `"(tabtools: using session Markdown "`_m'", `_how')"'
            }
        }
        else if inlist("`_action'", "xlsxstart", "xlsxdone") {
            * path(): act only when it names the session workbook. Every
            * workbook writer passes its target, so a table written with an
            * explicit xlsx()/using to the session workbook (by any tabtools
            * command) counts as its first write; otherwise a later session
            * write would erase the workbook holding that table. A write to
            * a session target is recorded (global TABTOOLS_written), and a
            * file recorded there is never erased by a later set of it.
            syntax [, PATH(string)]
            if `"`path'"' == "" local path `"$TABTOOLS_set_workbook"'
            if `"`path'"' != "" {
                local _hit = `"$TABTOOLS_set_workbook"' != ""
                if `_hit' {
                    mata: st_local("_hit", strofreal(_tt_ss_abs(st_local("path")) == ///
                        _tt_ss_abs(st_global("TABTOOLS_set_workbook"))))
                }
                mata: st_local("_wr", strofreal(_tt_ss_iswritten(st_local("path"))))
                if `_hit' & "$TABTOOLS_set_workbook_fresh" == "1" {
                    * xlsxdone: a writer that reads the workbook it writes
                    * (stacktab) clears the flag after writing, never erases.
                    if "`_action'" == "xlsxstart" & !`_wr' {
                        capture confirm file `"$TABTOOLS_set_workbook"'
                        if !_rc erase `"$TABTOOLS_set_workbook"'
                    }
                    global TABTOOLS_set_workbook_fresh 0
                }
                if `_hit' mata: _tt_ss_mark(st_local("path"))
            }
        }
        else if "`_action'" == "mddone" {
            syntax [, PATH(string)]
            if `"`path'"' == "" local path `"$TABTOOLS_set_markdown"'
            if `"`path'"' != "" {
                local _hit = `"$TABTOOLS_set_markdown"' != ""
                if `_hit' {
                    mata: st_local("_hit", strofreal(_tt_ss_abs(st_local("path")) == ///
                        _tt_ss_abs(st_global("TABTOOLS_set_markdown"))))
                }
                if `_hit' global TABTOOLS_set_markdown_fresh 0
                if `_hit' mata: _tt_ss_mark(st_local("path"))
            }
        }
        else if "`_action'" == "normalize" {
            * The absolute normalised spelling of path() in _ss_abs, and in
            * _ss_written whether this session already wrote that file.
            syntax , PATH(string)
            mata: st_local("_m", _tt_ss_abs(st_local("path")))
            mata: st_local("_ms", strofreal(_tt_ss_iswritten(st_local("path"))))
        }
        else {
            display as error "_tabtools_set_sinks: unknown action `_action'"
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if "`_action'" == "normalize" {
        c_local _ss_abs `"`_m'"'
        c_local _ss_written `_ms'
    }
    if "`_action'" == "resolve" {
        c_local _ss_xlsx `"`_x'"'
        c_local _ss_md `"`_m'"'
        c_local _ss_mdappend "`_a'"
        c_local _ss_xlsx_sess `_xs'
        c_local _ss_md_sess `_ms'
    }
    if `rc' exit `rc'
end

version 17.0
capture mata: mata drop _tt_ss_abs()
capture mata: mata drop _tt_ss_iswritten()
capture mata: mata drop _tt_ss_mark()
local _tt_ms0 = c(matastrict)
mata:
mata set matastrict on

// A path as an absolute, normalised string: relative paths are taken from
// the current working directory, "~/" is the home directory, "." segments,
// repeated separators and "dir/.." pairs are removed, and on Windows
// separators are written "/" and case is folded. Symbolic links are not
// resolved, nor is case folded on other systems. tabtools set stores this
// spelling and every same-file comparison uses it.
string scalar _tt_ss_abs(string scalar p)
{
    string scalar s, root, seg, out
    string colvector keep
    real scalar win, pos, i

    win = (c("os") == "Windows")
    s = strtrim(p)
    if (win) s = subinstr(s, char(92), "/")
    if (s == "~") s = c("homedir")
    else if (substr(s, 1, 2) == "~/") s = c("homedir") + substr(s, 2, .)
    if (!(substr(s, 1, 1) == "/" | (win & substr(s, 2, 1) == ":"))) {
        root = c("pwd")
        if (win) root = subinstr(root, char(92), "/")
        s = root + "/" + s
    }
    root = "/"
    if (win & substr(s, 2, 1) == ":") {
        root = substr(s, 1, 2) + "/"
        s = substr(s, 3, .)
    }
    keep = J(0, 1, "")
    s = s + "/"
    while ((pos = strpos(s, "/")) > 0) {
        seg = substr(s, 1, pos - 1)
        s = substr(s, pos + 1, .)
        if (seg == "" | seg == ".") continue
        if (seg == "..") {
            // stata-dev-ignore: shape-dispatch — keep is the stack of path segments and rows(keep) its depth, popped on a .. segment; not a layout dispatch
            if (rows(keep)) keep = (rows(keep) > 1 ? keep[(1..rows(keep) - 1)] : J(0, 1, ""))
            continue
        }
        keep = keep \ seg
    }
    out = root
    for (i = 1; i <= rows(keep); i++) out = out + (i > 1 ? "/" : "") + keep[i]
    if (win) out = strlower(out)
    return(out)
}

// Has this Stata session written path while it was a session target? The
// record lives in global TABTOOLS_written, unit-separator delimited; it is
// kept across tabtools set clear so a later set can never erase such a file.
real scalar _tt_ss_iswritten(string scalar path)
{
    string scalar sep
    sep = char(31)
    return(strpos(sep + st_global("TABTOOLS_written") + sep,
        sep + _tt_ss_abs(path) + sep) > 0)
}

void _tt_ss_mark(string scalar path)
{
    string scalar cur
    if (_tt_ss_iswritten(path)) return
    cur = st_global("TABTOOLS_written")
    st_global("TABTOOLS_written", (cur == "" ? "" : cur + char(31)) + _tt_ss_abs(path))
}

end
mata: mata set matastrict `_tt_ms0'
