*! _tabtools_markdown_write Version 1.9.8  2026/07/13
*! Write the current dataset as a GitHub-Flavored Markdown table
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _tabtools_markdown_write, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _fh_open = 0
    capture noisily {
        syntax using/ , [APPEND LABELVar(name) HEADERStart(integer 2) ///
            DATAStart(integer 3) DATAEnd(integer -1) TITLE(string) FOOTnote(string) ///
            NOVARNAMES STRICTHeaders]

        capture _tabtools_helpers_ready
        if _rc {
            capture findfile _tabtools_common.ado
            if _rc == 0 {
                run "`r(fn)'"
            }
            else {
                noisily display as error "_tabtools_common.ado not found; reinstall tabtools"
                exit 111
            }
        }

        quietly ds
        local _allvars `r(varlist)'
        if "`_allvars'" == "" {
            noisily display as error "No variables available for Markdown export"
            exit 111
        }
        quietly count
        if r(N) == 0 {
            noisily display as error "No observations available for Markdown export"
            exit 2000
        }

        local _path_lower = lower(`"`using'"')
        if !(strmatch(`"`_path_lower'"', "*.md") | ///
             strmatch(`"`_path_lower'"', "*.markdown") | ///
             strmatch(`"`_path_lower'"', "*.qmd") | ///
             strmatch(`"`_path_lower'"', "*.rmd")) {
            noisily display as error "markdown() must specify a .md, .markdown, .qmd, or .rmd file"
            exit 198
        }

        capture _tabtools_validate_path `"`using'"' "markdown()"
        if _rc exit _rc

        local _visible_opts ""
        if `"`labelvar'"' != "" local _visible_opts "labelvar(`labelvar')"
        _tabtools_visible_vars, `_visible_opts'
        local _vars "`_tabtools_visible_vars'"
        local _k : word count `_vars'
        if `_k' == 0 {
            noisily display as error "No output columns available for Markdown export"
            exit 111
        }

        if `headerstart' < 1 local headerstart = 1
        if `datastart' < 1 local datastart = 1

        local _title `"`title'"'
        if `"`_title'"' == "" & `headerstart' > 1 & _N >= 1 {
            foreach _v of local _allvars {
                mata: st_local("_cell", _tt_md_cell("`_v'", 1))
                if `"`_cell'"' != "" {
                    local _title `"`_cell'"'
                    continue, break
                }
            }
        }

        forvalues _j = 1/`_k' {
            local _v : word `_j' of `_vars'
            local _h`_j' ""
            if "`novarnames'" == "" & inrange(`headerstart', 1, _N) {
                mata: st_local("_h`_j'", _tt_md_cell("`_v'", `headerstart'))
            }
            if `"`_h`_j''"' == "" & "`strictheaders'" == "" & "`novarnames'" == "" {
                local _vl : variable label `_v'
                if `"`_vl'"' != "" local _h`_j' `"`_vl'"'
            }
            if `"`_h`_j''"' == "" & "`strictheaders'" == "" & "`novarnames'" == "" local _h`_j' "`_v'"
            if `"`_h`_j''"' == "" & "`strictheaders'" == "" & "`novarnames'" == "" local _h`_j' "Column `_j'"
            mata: st_local("_h`_j'", _tt_md_escape(st_local("_h`_j'")))
        }

        local _mode "write"
        local _append_existing = 0
        if "`append'" != "" {
            capture confirm file `"`using'"'
            if !_rc local _append_existing = 1
            local _mode "write append"
        }
        tempname _fh
        file open `_fh' using `"`using'"', `_mode' text
        local _fh_open = 1

        if `_append_existing' file write `_fh' _n
        if `"`_title'"' != "" {
            mata: st_local("_title", _tt_md_escape(st_local("_title")))
            file write `_fh' `"### `_title'"' _n _n
        }

        file write `_fh' "|"
        forvalues _j = 1/`_k' {
            file write `_fh' `" `_h`_j'' |"'
        }
        file write `_fh' _n "|"
        forvalues _j = 1/`_k' {
            file write `_fh' " --- |"
        }
        file write `_fh' _n

        local _n_body = 0
        local _N = _N
        local _body_end = cond(`dataend' < 0, `_N', min(`dataend', `_N'))
        if `_body_end' >= `datastart' {
            forvalues _i = `datastart'/`_body_end' {
                local _row_has_text = 0
                forvalues _j = 1/`_k' {
                    local _v : word `_j' of `_vars'
                    mata: st_local("_cell`_j'", _tt_md_cell("`_v'", `_i'))
                    if `"`_cell`_j''"' != "" local _row_has_text = 1
                    mata: st_local("_cell`_j'", _tt_md_escape(st_local("_cell`_j'")))
                }
                if `_row_has_text' {
                    file write `_fh' "|"
                    forvalues _j = 1/`_k' {
                        file write `_fh' `" `_cell`_j'' |"'
                    }
                    file write `_fh' _n
                    local ++_n_body
                }
            }
        }

        if `"`footnote'"' != "" {
            mata: st_local("footnote", _tt_md_escape(st_local("footnote")))
            file write `_fh' _n `"*`footnote'*"' _n
        }

        file close `_fh'
        local _fh_open = 0

        return scalar n_rows = `_n_body'
        return scalar n_cols = `_k'
        return local markdown `"`using'"'
    }
    local rc = _rc
    if `_fh_open' capture file close `_fh'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 16.0
capture mata: mata drop _tt_md_escape()
capture mata: mata drop _tt_md_cell()

mata:
mata set matastrict on

string scalar _tt_md_escape(string scalar x)
{
    x = strtrim(x)
    x = subinstr(x, "\", "\\")
    x = subinstr(x, "|", "\|")
    x = subinstr(x, char(13) + char(10), "<br>")
    x = subinstr(x, char(13), "<br>")
    x = subinstr(x, char(10), "<br>")
    return(x)
}

string scalar _tt_md_cell(string scalar v, real scalar i)
{
    real scalar j
    real scalar x

    j = st_varindex(v)
    if (st_isstrvar(j)) {
        return(strtrim(st_sdata(i, j)))
    }
    x = st_data(i, j)
    if (x >= .) return("")
    return(strtrim(strofreal(x, st_varformat(j))))
}

end
