*! _tabtools_check_sinks Version 1.1.0  2026/10/31
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
* csv() must also name a .csv file, the contract puttab and stacktab
* already enforced; that alone keeps csv() off the .xlsx and Markdown paths.
* latex() must likewise name a .tex file, checked here before any write.
* texappend with texdocument needs an existing latex() file to be a complete
* document (an \end{document} line); the writer refuses otherwise, and that
* refusal used to come after the workbook had been written.
*
* Usage: _tabtools_check_sinks, [xlsx(path) csv(path) markdown(path)
*            latex(path) texappend texdocument texopts(string) xlsxname(string)]
* texopts() is parsed here too (_tabtools_texopts), so a bad sub-option is
* refused before the first write rather than by the LaTeX writer.
* xlsxname() is the option name used in messages for the workbook ("using"
* for puttab/stacktab, "excel()" for desctab/table1_tc); default "xlsx()".

program define _tabtools_check_sinks, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [, XLSX(string) CSV(string) MARKdown(string) LATEX(string) ///
            TEXAPPend texdocument texopts(string asis) XLSXName(string)]
        if `"`xlsxname'"' == "" local xlsxname "xlsx()"
        local _home : environment HOME

        local _opts "xlsx csv markdown latex"
        local _label_xlsx `"`xlsxname'"'
        local _label_csv "csv()"
        local _label_markdown "markdown()"
        local _label_latex "latex()"
        forvalues _i = 1/4 {
            local _oi : word `_i' of `_opts'
            if `"``_oi''"' == "" continue
            forvalues _j = `=`_i' + 1'/4 {
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

        if `"`latex'"' != "" {
            if !strmatch(lower(`"`latex'"'), "*.tex") {
                noisily display as error "latex() must specify a .tex file"
                exit 198
            }
            if `"`macval(texopts)'"' != "" {
                * nclass: the parser's r() must not replace the caller's
                tempname _rhold
                _return hold `_rhold'
                capture noisily _tabtools_texopts `"`macval(texopts)'"'
                local _trc = _rc
                _return restore `_rhold'
                if `_trc' exit `_trc'
            }
            if "`texappend'" != "" & "`texdocument'" != "" {
                capture confirm file `"`latex'"'
                if !_rc {
                    * the writer's test: a line that is \end{document},
                    * blanks and a trailing comment allowed
                    mata: st_local("_enddoc", strofreal(any(strtrim( ///
                        ustrregexra(cat(st_local("latex")), "(?<!" + ///
                        char(92) + char(92) + ")%.*$", "")) :== ///
                        char(92) + "end{document}")))
                    if !`_enddoc' {
                        noisily display as error `"texdocument: the existing LaTeX file has no \end{document} line, so it is not a complete document; drop texdocument to append the table to it"'
                        noisily display as error "nothing was written"
                        exit 198
                    }
                }
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 17.0
capture mata: mata drop _tt_sink_key()

* matastrict is a session setting: save the caller's value here and
* restore it after the block, so loading this file never leaks it.
local _tt_ms0 = c(matastrict)
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
mata: mata set matastrict `_tt_ms0'
