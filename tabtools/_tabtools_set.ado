*! _tabtools_set Version 2.5.1  2026/10/06
*! Session destinations and defaults behind tabtools set / tabtools query
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
    _tabtools_set set <key> <value>     key: workbook, markdown, headershade,
                                             smallcells
    _tabtools_set set <key> clear       remove one session setting
    _tabtools_set clear [, quiet]       remove every session setting
    _tabtools_set query                 list them; r(workbook) etc.

    State lives in globals for the life of the Stata session:
        TABTOOLS_set_workbook          path of the session workbook
        TABTOOLS_set_workbook_fresh    1 until the first write to it
        TABTOOLS_set_markdown          path of the session Markdown file
        TABTOOLS_set_markdown_fresh    1 until the first write to it
        TABTOOLS_set_headershade       on | off
        TABTOOLS_set_smallcells        # (3 or more)
        TABTOOLS_set_smallcells_mode   full | primary
        TABTOOLS_BORDER                default | thin | medium | academic
                                       (set by -tabtools set borderstyle-,
                                       which can also save it to a profile;
                                       reported here, cleared by clear)
        TABTOOLS_written               every file a tabtools writer wrote in
                                       this session (absolute, normalised);
                                       kept by -tabtools set clear-

    A _fresh flag is set by -tabtools set workbook|markdown- and cleared by
    the first command that writes to that session target. That first write
    replaces the file (a workbook is erased and started again, a Markdown
    file is overwritten); every later write adds a sheet to the workbook or
    appends to the Markdown file. Setting a different target re-arms the
    flag; setting the current one again is a no-op; a file this session has
    already written is never replaced. Paths are stored absolute.
*/

program define _tabtools_set, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken _action 0 : 0, parse(" ,")
        local _action = lower(strtrim(`"`_action'"'))

        if "`_action'" == "set" {
            gettoken _key _val : 0
            local _key = lower(strtrim(`"`_key'"'))
            local _val = strtrim(`"`_val'"')
            * One layer of quotes around a path is the user's, not the path's.
            if inlist("`_key'", "workbook", "markdown") {
                gettoken _v1 _vrest : _val, quotes
                if `"`_vrest'"' != "" {
                    display as error `"tabtools set `_key' takes one path; quote a path that contains spaces"'
                    exit 198
                }
                local _val `_v1'
                if substr(`"`_val'"', 1, 1) == `"""' local _val = substr(`"`_val'"', 2, strlen(`"`_val'"') - 2)
            }
            if `"`_val'"' == "" {
                display as error "tabtools set `_key' requires a value, or clear to remove it"
                exit 198
            }
            if lower(`"`_val'"') == "clear" {
                if !inlist("`_key'", "workbook", "markdown", "headershade", "smallcells") {
                    display as error `"Unknown session setting "`_key'". Valid: workbook, markdown, headershade, smallcells"'
                    exit 198
                }
                global TABTOOLS_set_`_key'
                global TABTOOLS_set_`_key'_fresh
                global TABTOOLS_set_`_key'_mode
                display as text "tabtools: session `_key' cleared"
                return local action "cleared"
                return local key "`_key'"
            }
            else if "`_key'" == "workbook" {
                if !strmatch(lower(`"`_val'"'), "*.xlsx") {
                    display as error "tabtools set workbook: the file must have a .xlsx extension"
                    exit 198
                }
                _tabtools_validate_path `"`_val'"' "tabtools set workbook"
                * Stored absolute and normalised, so a later cd does not move
                * the target. The same target again is a no-op; a different
                * one re-arms "first write replaces" unless this session has
                * already written that file, which is never replaced.
                _tabtools_set_sinks normalize, path(`"`_val'"')
                local _val `"`_ss_abs'"'
                if `"`_val'"' == `"$TABTOOLS_set_workbook"' {
                    display as text "tabtools: " as result `""`_val'""' ///
                        as text " is already the session workbook; later writes add sheets"
                }
                else if `_ss_written' {
                    global TABTOOLS_set_workbook `"`_val'"'
                    global TABTOOLS_set_workbook_fresh 0
                    display as text "tabtools: session workbook " as result `""`_val'""' ///
                        as text " (already written in this session; later writes add sheets)"
                }
                else {
                    global TABTOOLS_set_workbook `"`_val'"'
                    global TABTOOLS_set_workbook_fresh 1
                    display as text "tabtools: session workbook " as result `""`_val'""' ///
                        as text " (the first write replaces it; later writes add sheets)"
                }
                return local workbook `"`_val'"'
            }
            else if "`_key'" == "markdown" {
                local _ml = lower(`"`_val'"')
                if !(strmatch(`"`_ml'"', "*.md") | strmatch(`"`_ml'"', "*.markdown") | ///
                     strmatch(`"`_ml'"', "*.qmd") | strmatch(`"`_ml'"', "*.rmd")) {
                    display as error "tabtools set markdown: the file must have a .md, .markdown, .qmd, or .rmd extension"
                    exit 198
                }
                _tabtools_validate_path `"`_val'"' "tabtools set markdown"
                * Stored absolute and normalised, so a later cd does not move
                * the target. The same target again is a no-op; a different
                * one re-arms "first write replaces" unless this session has
                * already written that file, which is never replaced.
                _tabtools_set_sinks normalize, path(`"`_val'"')
                local _val `"`_ss_abs'"'
                if `"`_val'"' == `"$TABTOOLS_set_markdown"' {
                    display as text "tabtools: " as result `""`_val'""' ///
                        as text " is already the session Markdown file; later writes append"
                }
                else if `_ss_written' {
                    global TABTOOLS_set_markdown `"`_val'"'
                    global TABTOOLS_set_markdown_fresh 0
                    display as text "tabtools: session Markdown file " as result `""`_val'""' ///
                        as text " (already written in this session; later writes append)"
                }
                else {
                    global TABTOOLS_set_markdown `"`_val'"'
                    global TABTOOLS_set_markdown_fresh 1
                    display as text "tabtools: session Markdown file " as result `""`_val'""' ///
                        as text " (the first write replaces it; later writes append)"
                }
                return local markdown `"`_val'"'
            }
            else if "`_key'" == "headershade" {
                local _val = lower(`"`_val'"')
                if !inlist("`_val'", "on", "off") {
                    display as error "tabtools set headershade must be on or off"
                    exit 198
                }
                global TABTOOLS_set_headershade "`_val'"
                display as text "tabtools: session headershade " as result "`_val'"
                return local headershade "`_val'"
            }
            else if "`_key'" == "smallcells" {
                gettoken _k _mode : _val
                local _mode = lower(strtrim(`"`_mode'"'))
                capture confirm integer number `_k'
                if _rc {
                    display as error "tabtools set smallcells must be an integer greater than or equal to 3"
                    exit 198
                }
                if `_k' < 3 {
                    display as error "tabtools set smallcells must be an integer greater than or equal to 3"
                    exit 198
                }
                if !inlist(`"`_mode'"', "", "primary", "full") {
                    display as error `"tabtools set smallcells # [primary]: unknown mode `_mode'"'
                    exit 198
                }
                if `"`_mode'"' == "" local _mode "full"
                global TABTOOLS_set_smallcells `_k'
                global TABTOOLS_set_smallcells_mode "`_mode'"
                display as text "tabtools: session smallcells " as result "`_k'" ///
                    as text " (`_mode'; desctab, table1_tc, crosstab; nosmallcells skips it)"
                return scalar smallcells = `_k'
                return local smallcells_mode "`_mode'"
            }
            else {
                display as error `"Unknown session setting "`_key'". Valid: workbook, markdown, headershade, smallcells"'
                exit 198
            }
        }
        else if "`_action'" == "clear" {
            syntax [, QUIET]
            foreach _k in workbook markdown headershade smallcells {
                global TABTOOLS_set_`_k'
                global TABTOOLS_set_`_k'_fresh
                global TABTOOLS_set_`_k'_mode
            }
            global TABTOOLS_BORDER
            if "`quiet'" == "" display as text "tabtools: all session settings cleared"
            return local action "cleared"
        }
        else if "`_action'" == "query" {
            if strtrim(`"`0'"') != "" {
                display as error "tabtools query does not accept additional arguments"
                exit 198
            }
            local _wb `"$TABTOOLS_set_workbook"'
            local _md `"$TABTOOLS_set_markdown"'
            local _hs `"$TABTOOLS_set_headershade"'
            local _sc `"$TABTOOLS_set_smallcells"'
            local _scm `"$TABTOOLS_set_smallcells_mode"'
            local _bs `"$TABTOOLS_BORDER"'
            if `"`_sc'"' != "" & `"`_scm'"' == "" local _scm "full"
            display as text ""
            display as text "tabtools session settings"
            foreach _k in workbook markdown {
                local _v = cond("`_k'" == "workbook", `"`_wb'"', `"`_md'"')
                local _lab = cond("`_k'" == "workbook", "  Workbook:    ", "  Markdown:    ")
                if `"`_v'"' == "" display as text "`_lab'" as text "(not set)"
                else {
                    local _st "later writes append"
                    if "`_k'" == "workbook" local _st "later writes add sheets"
                    if "${TABTOOLS_set_`_k'_fresh}" == "1" local _st "next write replaces it"
                    display as text "`_lab'" as result `""`_v'""' as text " (`_st')"
                }
            }
            if `"`_hs'"' == "" display as text "  Headershade: (not set)"
            else display as text "  Headershade: " as result "`_hs'"
            if `"`_sc'"' == "" display as text "  Smallcells:  (not set)"
            else display as text "  Smallcells:  " as result "`_sc'" as text " (`_scm')"
            if `"`_bs'"' == "" display as text "  Borderstyle: (not set)"
            else display as text "  Borderstyle: " as result `"`_bs'"'
            return local workbook `"`_wb'"'
            return local markdown `"`_md'"'
            return local headershade `"`_hs'"'
            return local smallcells `"`_sc'"'
            return local smallcells_mode `"`_scm'"'
            return local borderstyle `"`_bs'"'
            return local workbook_fresh = cond(`"`_wb'"' != "", cond("$TABTOOLS_set_workbook_fresh" == "1", "1", "0"), "")
            return local markdown_fresh = cond(`"`_md'"' != "", cond("$TABTOOLS_set_markdown_fresh" == "1", "1", "0"), "")
        }
        else {
            display as error "_tabtools_set: unknown action `_action'"
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
