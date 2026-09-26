*! _tabtools_check_sinks Version 2.1.11  2026/09/26
*! Refuse output options that name the same file, before anything is written
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* Every command with more than one file sink calls this after its own path
* validation and before its first write. Two sinks naming one file used to
* destroy it: survtab, xlsx(book.xlsx) csv(book.xlsx) exported the CSV over
* the workbook and then failed to open it as one (r(16103)); regtab did the
* same at rc 0. Paths are compared after resolving them against the working
* directory, collapsing ./ and dir/.., unifying \ and /, expanding a leading
* ~/, and ignoring case (Windows and macOS file systems are case-insensitive,
* so a case-only difference is refused everywhere rather than only there).
* csv() must also name a .csv file, the contract corrtab, puttab and stacktab
* already enforced; that alone keeps csv() off the .xlsx and Markdown paths.
*
* Usage: _tabtools_check_sinks, [xlsx(path) csv(path) markdown(path)
*            xlsxname(string)]
* xlsxname() is the option name used in messages for the workbook ("using"
* for puttab/stacktab, "excel()" for desctab/table1_tc); default "xlsx()".

program define _tabtools_check_sinks, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [, XLSX(string) CSV(string) MARKdown(string) XLSXName(string)]
        if `"`xlsxname'"' == "" local xlsxname "xlsx()"
        local _home : environment HOME

        local _opts "xlsx csv markdown"
        local _label_xlsx `"`xlsxname'"'
        local _label_csv "csv()"
        local _label_markdown "markdown()"
        forvalues _i = 1/3 {
            local _oi : word `_i' of `_opts'
            if `"``_oi''"' == "" continue
            forvalues _j = `=`_i' + 1'/3 {
                local _oj : word `_j' of `_opts'
                if `"``_oj''"' == "" continue
                mata: st_local("_same", strofreal( ///
                    _tt_sink_key(st_local("`_oi'"), st_local("_home")) == ///
                    _tt_sink_key(st_local("`_oj'"), st_local("_home"))))
                if `_same' {
                    noisily display as error `"`_label_`_oi'' and `_label_`_oj'' name the same file: ``_oj''"'
                    noisily display as error "each output option needs its own file; nothing was written"
                    exit 198
                }
            }
        }

        if `"`csv'"' != "" {
            if !strmatch(lower(`"`csv'"'), "*.csv") {
                noisily display as error "csv() must have a .csv extension"
                exit 198
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 17.0
capture mata: mata drop _tt_sink_key()

mata:
mata set matastrict on

// Comparison key for an output path: absolute, / separated, without . and
// .. segments, lower case. Symbolic and hard links are not resolved.
string scalar _tt_sink_key(string scalar path, string scalar home)
{
    string scalar p, root, t
    string rowvector parts, stack
    real scalar i, n

    p = subinstr(strtrim(path), "\", "/")
    if ((p == "~" | substr(p, 1, 2) == "~/") & home != "") {
        p = subinstr(home, "\", "/") + substr(p, 2, .)
    }
    if (!(substr(p, 1, 1) == "/" | regexm(p, "^[A-Za-z]:/"))) {
        p = subinstr(pwd(), "\", "/") + "/" + p
    }
    root = (substr(p, 1, 1) == "/" ? "/" : "")
    parts = tokens(p, "/")
    stack = J(1, 0, "")
    n = 0
    for (i = 1; i <= cols(parts); i++) {
        t = parts[i]
        if (t == "/" | t == "" | t == ".") continue
        if (t == "..") {
            if (n > 0) {
                n--
                stack = (n ? stack[|1, 1 \ 1, n|] : J(1, 0, ""))
            }
            continue
        }
        stack = stack, t
        n++
    }
    return(ustrlower(root + invtokens(stack, "/")))
}

end
