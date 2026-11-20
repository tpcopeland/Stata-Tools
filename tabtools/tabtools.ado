*! tabtools Version 1.2.1  2026/11/20
*! Suite of table export commands for publication-ready Excel and Markdown output
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tabtools [subcommand] [, list detail category(string)]

Subcommands:
  (none)           - Display available commands (default)
  set key value    - Set persistent formatting default (font, fontsize, borderstyle)
  set key value, permanent
                   - Save current defaults to a disk profile after setting
  set clear        - Clear all persistent defaults
  get              - Display current persistent defaults
  use [using file] - Load defaults from a saved tabtools profile

Optional options (display mode):
  list             - Display commands as a simple list
  detail           - Show detailed information with descriptions
  category(string) - Filter by category: descriptive, models, rates,
                     survival, diagnostics, composite, general, all

Returns:
  r(commands)     - List of all command names
  r(n_commands)   - Number of commands
  r(version)      - Package version

See help tabtools for complete documentation
*/

program define tabtools, rclass
    version 17.0
    * SUBCOMMAND: fitcount (fit-time counts for regtab). Its options are its
    * own, so it is dispatched before the display-mode syntax; the helper
    * carries its own varabbrev wrapper and error codes.
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    gettoken _fc_word _fc_rest : 0, parse(" ,")
    if lower(`"`_fc_word'"') == "fitcount" {
        * _tabtools_fitcount calls _regtab_bnotes, which _tabtools_common.ado
        * defines. The load runs in a captured block so that varabbrev is
        * restored before a failed load exits.
        capture noisily {
            capture _tabtools_helpers_ready
            if !_rc capture mata: assert(findexternal("_tt_sep_parse()") != NULL)
            if !_rc capture mata: assert(_tt_bundle_build() == "1.2.1")
            if _rc {
                capture findfile _tabtools_common.ado
                if _rc == 0 {
                    run "`r(fn)'"
                    capture _tabtools_helpers_ready
                    if !_rc capture mata: assert(_tt_bundle_build() == "1.2.1")
                    if _rc {
                        display as error "_tabtools_common.ado failed to load fully; reinstall tabtools"
                        exit 111
                    }
                }
                else {
                    display as error "_tabtools_common.ado not found; reinstall tabtools"
                    exit 111
                }
            }
        }
        local _rc = _rc
        if `_rc' {
            set varabbrev `_orig_varabbrev'
            exit `_rc'
        }
        capture noisily _tabtools_fitcount `_fc_rest'
        local _rc = _rc
        if !`_rc' return add
        set varabbrev `_orig_varabbrev'
        exit `_rc'
    }
    capture noisily {
        * Derive the package version from this file's *! header so it can never
        * drift from the header on a version bump (previously a hardcoded literal
        * that silently went stale).
        local _package_version "unknown"
        capture findfile tabtools.ado
        if !_rc {
            tempname _vfh
            capture file open `_vfh' using "`r(fn)'", read text
            if !_rc {
                file read `_vfh' _vheader
                file close `_vfh'
                if regexm(`"`_vheader'"', "Version ([0-9.]+)") ///
                    local _package_version = regexs(1)
            }
        }

    * Parse anything (subcommand) separately from options
    syntax [anything(everything)] [, List Detail Category(string) ///
        PERManent PROFile(string)]

    local _has_display_opts = ("`list'" != "" | "`detail'" != "" | "`category'" != "")
    local _has_profile_opts = ("`permanent'" != "" | `"`profile'"' != "")

    capture findfile _tabtools_common.ado
    if _rc {
        display as error "_tabtools_common.ado not found; reinstall tabtools"
        exit 111
    }
    run "`r(fn)'"
    capture _tabtools_require_helpers, ///
        required("_tabtools_validate_color _tabtools_resolve_format") ///
        failmessage("_tabtools_common.ado failed to load; reinstall tabtools")
    if _rc {
        display as error "_tabtools_common.ado failed to load; reinstall tabtools"
        exit 111
    }

    * Extract first token to check for subcommands
    local subcmd ""
    if `"`anything'"' != "" {
        gettoken subcmd rest : anything
        local subcmd = lower("`subcmd'")
    }

    * =========================================================================
    * SUBCOMMAND: set
    * =========================================================================
    if "`subcmd'" == "set" {
        gettoken setkey setrest : rest, quotes
        local setkey = lower(strtrim("`setkey'"))
        * macval: a texopts value may hold a dollar sign or a backtick the
        * user escaped on the command line; expanding it again would lose it.
        local setval = strtrim(`"`macval(setrest)'"')

        if "`setkey'" == "" {
            display as error "tabtools set requires a setting key"
            exit 198
        }
        if `_has_display_opts' {
            display as error "list, detail, and category() are only allowed in display mode"
            exit 198
        }
        if `"`profile'"' != "" & "`permanent'" == "" {
            display as error "profile() is only allowed with tabtools set ..., permanent"
            exit 198
        }

        * Allow quoted multiword values in user-facing examples such as:
        * tabtools set font "Times New Roman"
        if inlist("`setkey'", "font", "headercolor", "zebracolor") {
            local setval = subinstr(`"`setval'"', `"""', "", .)
            local setval = strtrim(`"`setval'"')
        }

        if "`setkey'" == "clear" {
            if "`setval'" != "" {
                display as error "tabtools set clear does not accept additional arguments"
                exit 198
            }
            global TABTOOLS_FONT
            global TABTOOLS_FONTSIZE
            global TABTOOLS_BORDER
            global TABTOOLS_HEADERCOLOR
            global TABTOOLS_ZEBRACOLOR
            global TABTOOLS_DIGITS
            global TABTOOLS_BOLDP
            display as text "tabtools: all persistent defaults cleared"
            * 2.3.0: session settings (workbook, markdown, latex,
            * headershade, smallcells) are cleared with them.
            _tabtools_set clear, quiet
            return local action "cleared"
        }
        * 2.3.0 session settings (U1, W1): logic in _tabtools_set.ado.
        else if inlist("`setkey'", "workbook", "markdown", "latex", "texopts", "headershade", "smallcells") {
            if "`permanent'" != "" {
                display as error "tabtools set `setkey' is a session setting and is not saved to a profile"
                exit 198
            }
            _tabtools_set set `setkey' `macval(setval)'
            return add
        }
        else if "`setkey'" == "font" {
            if "`setval'" == "" {
                display as error "tabtools set font requires a value (e.g., tabtools set font Calibri)"
                exit 198
            }
            global TABTOOLS_FONT "`setval'"
            display as text "tabtools: default font set to " as result "`setval'"
            return local font "`setval'"
        }
        else if "`setkey'" == "fontsize" {
            if "`setval'" == "" {
                display as error "tabtools set fontsize requires a value (e.g., tabtools set fontsize 11)"
                exit 198
            }
            capture confirm integer number `setval'
            if _rc {
                display as error "fontsize must be an integer"
                exit 198
            }
            if `setval' < 6 | `setval' > 72 {
                display as error "fontsize must be between 6 and 72"
                exit 198
            }
            * Stored as the number, not as typed (+9 or 09 reads 9).
            local setval = real("`setval'")
            global TABTOOLS_FONTSIZE `setval'
            display as text "tabtools: default font size set to " as result "`setval'"
            return scalar fontsize = `setval'
        }
        else if "`setkey'" == "borderstyle" {
            * Also a session key: tabtools query reports it and
            * "tabtools set borderstyle clear" removes it. An explicit
            * borderstyle() in a call wins (_tabtools_resolve_format).
            if "`setval'" == "clear" {
                if "`permanent'" != "" {
                    display as error "tabtools set borderstyle clear cannot be combined with permanent"
                    exit 198
                }
                global TABTOOLS_BORDER
                display as text "tabtools: session borderstyle cleared"
                return local action "cleared"
                return local key "borderstyle"
            }
            else {
                if !inlist("`setval'", "default", "thin", "medium", "academic") {
                    display as error "borderstyle must be: default, thin, medium, or academic"
                    exit 198
                }
                global TABTOOLS_BORDER "`setval'"
                display as text "tabtools: default border style set to " as result "`setval'"
                return local borderstyle "`setval'"
            }
        }
        else if "`setkey'" == "headercolor" | "`setkey'" == "zebracolor" {
            if "`setval'" == "" {
                display as error "tabtools set `setkey' requires an RGB triplet"
                exit 198
            }
            _tabtools_validate_color "`setval'" "`setkey'"
            if "`setkey'" == "headercolor" global TABTOOLS_HEADERCOLOR "`setval'"
            else global TABTOOLS_ZEBRACOLOR "`setval'"
            return local `setkey' "`setval'"
        }
        else if "`setkey'" == "digits" {
            if "`setval'" == "" {
                display as error "tabtools set digits requires a value (e.g., tabtools set digits 3)"
                exit 198
            }
            capture confirm integer number `setval'
            if _rc {
                display as error "digits must be an integer"
                exit 198
            }
            if `setval' < 0 | `setval' > 6 {
                display as error "digits must be between 0 and 6"
                exit 198
            }
            * Stored as the number, not as typed (+9 or 09 reads 9).
            local setval = real("`setval'")
            global TABTOOLS_DIGITS `setval'
            display as text "tabtools: default digits set to " as result "`setval'"
            return scalar digits = `setval'
        }
        else if "`setkey'" == "boldp" {
            if "`setval'" == "" {
                display as error "tabtools set boldp requires a value (e.g., tabtools set boldp 0.05)"
                exit 198
            }
            capture confirm number `setval'
            if _rc {
                display as error "boldp must be a number"
                exit 198
            }
            if `setval' <= 0 | `setval' >= 1 {
                display as error "boldp must be between 0 and 1 (exclusive)"
                exit 198
            }
            global TABTOOLS_BOLDP `setval'
            display as text "tabtools: default boldp set to " as result "`setval'"
            return scalar boldp = `setval'
        }
        else {
            display as error `"Unknown setting "`setkey'". Valid: font, fontsize, borderstyle, headercolor, zebracolor, digits, boldp, workbook, markdown, latex, texopts, headershade, smallcells, clear"'
            exit 198
        }

        if "`permanent'" != "" {
            local _profile_path `"`profile'"'
            if `"`_profile_path'"' == "" {
                local _profile_path `"`c(sysdir_personal)'tabtools_profile.do"'
            }
            local _profile_path : subinstr local _profile_path `"""' "", all
            local _profile_path = strtrim(`"`_profile_path'"')
            if `"`_profile_path'"' == "" {
                display as error "profile() must name a writable .do file"
                exit 198
            }
            _tabtools_write_profile, profile(`"`_profile_path'"') version(`"`_package_version'"')
            display as text "tabtools: defaults saved to " as result `"`_profile_path'"'
            return local permanent "permanent"
            return local profile `"`_profile_path'"'
        }
    }

    * =========================================================================
    * SUBCOMMAND: get
    * =========================================================================
    else if "`subcmd'" == "get" {
        if "`rest'" != "" {
            display as error "tabtools get does not accept additional arguments"
            exit 198
        }
        if `_has_profile_opts' {
            display as error "permanent and profile() are only allowed with tabtools set ..., permanent"
            exit 198
        }
        if `_has_display_opts' {
            display as error "list, detail, and category() are only allowed in display mode"
            exit 198
        }
        _tabtools_resolve_format
        local _eff_font `"`_font'"'
        local _eff_fontsize `"`_fontsize'"'
        local _eff_border `"`borderstyle'"'
        local _eff_headercolor "$TABTOOLS_HEADERCOLOR"
        local _eff_zebracolor "$TABTOOLS_ZEBRACOLOR"

        display as text ""
        display as text "{hline 50}"
        display as result "tabtools" as text " - Persistent Formatting Defaults"
        display as text "{hline 50}"
        display as text ""

        display as text "  Font:        " as result "`_eff_font'"
        display as text "  Font size:   " as result "`_eff_fontsize'"
        display as text "  Border:      " as result "`_eff_border'"
        if "`_eff_headercolor'" != "" {
            display as text "  Header color:" as result " `_eff_headercolor'"
        }
        if "`_eff_zebracolor'" != "" {
            display as text "  Zebra color: " as result " `_eff_zebracolor'"
        }
        if "$TABTOOLS_DIGITS" != "" {
            display as text "  Digits:      " as result "$TABTOOLS_DIGITS"
        }
        if "$TABTOOLS_BOLDP" != "" {
            display as text "  Bold p:      " as result "$TABTOOLS_BOLDP"
        }

        display as text ""
        display as text "  Set with: " as result "tabtools set font Calibri"
        display as text "            " as result "tabtools set fontsize 11"
        display as text "            " as result "tabtools set borderstyle thin"
        display as text "            " as result "tabtools set digits 3"
        display as text "            " as result "tabtools set boldp 0.05"
        display as text "  Clear:    " as result "tabtools set clear"
        display as text ""

        return local font "`_eff_font'"
        return local fontsize "`_eff_fontsize'"
        return local borderstyle "`_eff_border'"
        return local headercolor "`_eff_headercolor'"
        return local zebracolor "`_eff_zebracolor'"
        return local digits "$TABTOOLS_DIGITS"
        return local boldp "$TABTOOLS_BOLDP"
    }

    * =========================================================================
    * SUBCOMMAND: query (2.3.0 session settings; logic in _tabtools_set.ado)
    * =========================================================================
    else if "`subcmd'" == "query" {
        if `_has_display_opts' | `_has_profile_opts' {
            display as error "tabtools query does not accept options"
            exit 198
        }
        _tabtools_set query `rest'
        return add
    }

    * =========================================================================
    * SUBCOMMAND: use
    * =========================================================================
    else if "`subcmd'" == "use" {
        if `_has_display_opts' {
            display as error "list, detail, and category() are only allowed in display mode"
            exit 198
        }
        if "`permanent'" != "" {
            display as error "permanent is only allowed with tabtools set"
            exit 198
        }

        local _profile_path `"`profile'"'
        if `"`rest'"' != "" {
            gettoken _use_word _use_rest : rest, quotes
            local _use_word = lower(strtrim(`"`_use_word'"'))
            local _use_rest = strtrim(`"`_use_rest'"')
            if "`_use_word'" != "using" | `"`_use_rest'"' == "" {
                display as error `"tabtools use syntax is: tabtools use [using "profile.do"]"'
                exit 198
            }
            if `"`_profile_path'"' != "" {
                display as error "specify the profile path with using or profile(), not both"
                exit 198
            }
            * Unquote once here: removing " characters below would turn a
            * compound-quoted `"path"' into a macro reference `path'.
            local _profile_path `_use_rest'
        }
        if `"`_profile_path'"' == "" {
            local _profile_path `"`c(sysdir_personal)'tabtools_profile.do"'
        }
        local _profile_path : subinstr local _profile_path `"""' "", all
        local _profile_path = strtrim(`"`_profile_path'"')
        if `"`_profile_path'"' == "" {
            display as error "profile() must name a tabtools profile .do file"
            exit 198
        }

        _tabtools_use_profile, profile(`"`_profile_path'"')
        display as text "tabtools: defaults loaded from " as result `"`_profile_path'"'
        return local action "loaded"
        return local profile `"`_profile_path'"'
    }

    * =========================================================================
    * DEFAULT: Display commands (original behavior)
    * =========================================================================
    else {
        if `_has_profile_opts' {
            display as error "permanent and profile() are only allowed with tabtools set ..., permanent"
            exit 198
        }
        * If anything was passed that isn't a subcommand, error
        if "`subcmd'" != "" {
            display as error `"Unknown subcommand "`subcmd'". Use: tabtools [set|get|query|use] or tabtools [, list detail]"'
            exit 198
        }

        // Default category is all
        if "`category'" == "" local category "all"

        // Validate category option
        local category = lower("`category'")
        local _valid_category = ///
            inlist("`category'", "all", "descriptive", "models", "rates", "general") | ///
            inlist("`category'", "survival", "composite", "export")
        if !`_valid_category' {
            display as error "category() must be: all, descriptive, models, rates, survival, composite, export, or general"
            exit 198
        }

        // Define commands by category
        local cmd_descriptive "table1_tc desctab crosstab"
        local cmd_models "regtab effecttab tabcell outtab"
        local cmd_rates "stratetab ratetab"
        local cmd_survival "survtab"
        local cmd_composite "comptab hrcomptab"
        local cmd_export "puttab stacktab"
        local cmd_general "tabtools tabtools_tips"

        // Build selected list based on category
        if "`category'" == "descriptive" {
            local selected_cmds `"`cmd_descriptive'"'
        }
        else if "`category'" == "models" {
            local selected_cmds `"`cmd_models'"'
        }
        else if "`category'" == "rates" {
            local selected_cmds `"`cmd_rates'"'
        }
        else if "`category'" == "survival" {
            local selected_cmds `"`cmd_survival'"'
        }
        else if "`category'" == "composite" {
            local selected_cmds `"`cmd_composite'"'
        }
        else if "`category'" == "export" {
            local selected_cmds `"`cmd_export'"'
        }
        else if "`category'" == "general" {
            local selected_cmds `"`cmd_general'"'
        }
        else {
            local selected_cmds `"`cmd_descriptive' `cmd_models' `cmd_rates' `cmd_survival' `cmd_composite' `cmd_export' `cmd_general'"'
        }

        // Count commands
        local n_commands: word count `selected_cmds'

        // Display header
        display as text ""
        display as text "{hline 70}"
        display as result "tabtools" as text " - Publication-Ready Table Export Suite"
        display as text "{hline 70}"
        display as text ""

        // Display based on options
        if "`detail'" != "" {
            // Detailed view with descriptions
            _tabtools_detail, category(`category')
        }
        else if "`list'" != "" {
            // Simple list view
            display as text "Available commands (`category'):"
            display as text ""
            foreach cmd of local selected_cmds {
                display as result "  `cmd'"
            }
        }
        else {
            // Default: organized view
            if inlist("`category'", "all", "descriptive") {
                display as text "{bf:Descriptive Statistics}"
                display as result "  table1_tc    " as text "- Table 1 with automatic statistical tests"
                display as result "  desctab      " as text "- Consolidated descriptive Table 1 engine"
                display as result "  crosstab     " as text "- Cross-tabulation with association measures"
                display as text ""
            }

            if inlist("`category'", "all", "models") {
                display as text "{bf:Model Results}"
                display as result "  regtab       " as text "- Regression results from any estimation command"
                display as result "  effecttab    " as text "- Treatment-effect style tables from supported results"
                display as result "  tabcell      " as text "- One publication cell from a fit, lincom, matrix, or numbers"
                display as result "  outtab       " as text "- Binary outcomes by exposure: counts plus model ratios"
                display as text ""
            }

            if inlist("`category'", "all", "rates") {
                display as text "{bf:Incidence Rates}"
                display as result "  stratetab    " as text "- Incidence rates from strate output"
                display as result "  ratetab      " as text "- Events, person-time, and rates with exact/robust CIs"
                display as text ""
            }

            if inlist("`category'", "all", "survival") {
                display as text "{bf:Survival Analysis}"
                display as result "  survtab      " as text "- Kaplan-Meier estimates, medians, and RMST"
                display as text ""
            }

            if inlist("`category'", "all", "composite") {
                display as text "{bf:Composite}"
                display as result "  comptab      " as text "- Combine regtab/effecttab frames into one table"
                display as result "  hrcomptab    " as text "- Attach regtab frames to a stratetab scaffold"
                display as text ""
            }

            if inlist("`category'", "all", "export") {
                display as text "{bf:Styled Export}"
                display as result "  puttab       " as text "- Style an in-memory dataset, frame, or matrix as one sheet"
                display as result "  stacktab     " as text "- Assemble multi-sheet composite Excel tables from blocks"
                display as text ""
            }


            if inlist("`category'", "all", "general") {
                display as text "{bf:General Purpose}"
                display as result "  tabtools     " as text "- Suite controller and persistent defaults"
                display as result "  tabtools_tips " as text "- Quick reference and worked recipes"
                display as text ""
            }

            display as text "{hline 70}"
            display as text "Total commands: " as result "`n_commands'"
            display as text ""
            display as text "Help:     " as result "help tabtools" as text " for overview"
            display as text "          " as result "tabtools_tips" as text " for quick reference and recipes"
            display as text "          " as result "help <command>" as text " for individual command help"
            display as text "Settings: " as result "tabtools set font Calibri" as text " (persistent defaults)"
            display as text "          " as result "tabtools get" as text " (view current defaults)"
        }

        // Return results
        return local commands "`selected_cmds'"
        return scalar n_commands = `n_commands'
        return local version "`_package_version'"
        return local categories "descriptive models rates survival composite export general"
    }

    } // end capture noisily
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end

* Write current tabtools defaults as a runnable Stata profile.
capture program drop _tabtools_write_profile
program define _tabtools_write_profile, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _fh_open = 0
    capture noisily {
        syntax , PROFile(string) Version(string)
        local profile : subinstr local profile `"""' "", all
        local profile = strtrim(`"`profile'"')
        if `"`profile'"' == "" {
            display as error "profile() must name a writable .do file"
            exit 198
        }

        tempname fh
        quietly file open `fh' using `"`profile'"', write text replace
        local _fh_open = 1
        file write `fh' "* tabtools profile" _n
        file write `fh' "* Generated by tabtools `version' on `c(current_date)' `c(current_time)'" _n
        file write `fh' "tabtools set clear" _n

        if "$TABTOOLS_FONT" != "" {
            file write `fh' "tabtools set font " `"""' "$TABTOOLS_FONT" `"""' _n
        }
        if "$TABTOOLS_FONTSIZE" != "" {
            file write `fh' "tabtools set fontsize $TABTOOLS_FONTSIZE" _n
        }
        if "$TABTOOLS_BORDER" != "" {
            file write `fh' "tabtools set borderstyle $TABTOOLS_BORDER" _n
        }
        if "$TABTOOLS_HEADERCOLOR" != "" {
            file write `fh' "tabtools set headercolor " `"""' "$TABTOOLS_HEADERCOLOR" `"""' _n
        }
        if "$TABTOOLS_ZEBRACOLOR" != "" {
            file write `fh' "tabtools set zebracolor " `"""' "$TABTOOLS_ZEBRACOLOR" `"""' _n
        }

        if "$TABTOOLS_DIGITS" != "" {
            file write `fh' "tabtools set digits $TABTOOLS_DIGITS" _n
        }
        if "$TABTOOLS_BOLDP" != "" {
            file write `fh' "tabtools set boldp $TABTOOLS_BOLDP" _n
        }

        file close `fh'
        local _fh_open = 0
    }
    local _rc = _rc
    if `_fh_open' capture file close `fh'
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end

* Load a saved tabtools profile into the current session.
capture program drop _tabtools_use_profile
program define _tabtools_use_profile, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , PROFile(string)
        local profile : subinstr local profile `"""' "", all
        local profile = strtrim(`"`profile'"')
        if `"`profile'"' == "" {
            display as error "profile() must name a tabtools profile .do file"
            exit 198
        }
        confirm file `"`profile'"'
        * A profile holds formatting defaults only. Its first line is
        * "tabtools set clear", which also clears the session settings
        * (destinations, texopts, headershade, smallcells). Keep them: a key
        * the profile left empty gets its earlier value back, with its
        * _fresh or _mode companion. Copied in Mata so a texopts value
        * holding $ or a backtick is not expanded.
        local _sess "workbook markdown latex texopts headershade smallcells"
        foreach _k of local _sess {
            foreach _s in "" _fresh _mode {
                mata: _tt_use_`_k'`_s' = st_global("TABTOOLS_set_`_k'`_s'")
            }
        }
        capture noisily quietly do `"`profile'"'
        local _do_rc = _rc
        foreach _k of local _sess {
            mata: st_local("_lost", strofreal(st_global("TABTOOLS_set_`_k'") == "" & _tt_use_`_k' != ""))
            if `_lost' {
                foreach _s in "" _fresh _mode {
                    mata: st_global("TABTOOLS_set_`_k'`_s'", _tt_use_`_k'`_s')
                }
            }
        }
        capture mata: mata drop _tt_use_*
        if `_do_rc' exit `_do_rc'
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end

* Subroutine for detailed display
capture program drop _tabtools_detail
program define _tabtools_detail, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , Category(string)

        if inlist("`category'", "all", "descriptive") {
            display as text "{bf:Descriptive Statistics}"
            display as text "  {hline 60}"
            display as result "  table1_tc" as text "    Create publication-ready Table 1 with descriptive"
            display as text "               statistics. Automatically selects appropriate"
            display as text "               tests (t-test, Wilcoxon, chi-square, Fisher's"
            display as text "               exact) based on variable type and distribution."
            display as text "               Supports continuous, categorical, and binary"
            display as text "               variables with customizable formatting."
            display as text ""
            display as result "  desctab" as text "      Direct access to the consolidated Table 1 engine,"
            display as text "               with number formats and optional composite cells"
            display as text "               such as events / N (%)."
            display as text ""
            display as result "  crosstab" as text "     Cross-tabulation with row/column percentages"
            display as text "               and association measures. Supports chi-square,"
            display as text "               Fisher's exact, odds ratios, and risk ratios."
            display as text ""
        }

        if inlist("`category'", "all", "models") {
            display as text "{bf:Model Results}"
            display as text "  {hline 60}"
            display as result "  regtab" as text "       Export regression results from any estimation"
            display as text "               command to Excel. Supports logistic, Cox, Poisson,"
            display as text "               linear, and other models. Configurable columns"
            display as text "               for coefficients, confidence intervals, p-values,"
            display as text "               and model statistics."
            display as text ""
            display as result "  effecttab" as text "    Export treatment-effect style tables from"
            display as text "               supported estimation results and matrix inputs."
            display as text "               Formats effect estimates, confidence intervals,"
            display as text "               and p-values for publication output."
            display as text ""
            display as result "  tabcell" as text "      Format one estimate (CI), p-value, n (%),"
            display as text "               e/n (%), or median (Q1, Q3) cell from a fit,"
            display as text "               lincom/nlcom, a matrix row, or numbers."
            display as text ""
            display as result "  outtab" as text "       Tabulate binary outcomes by exposure with"
            display as text "               events/N (%) and one ratio column per model."
            display as text ""
        }

        if inlist("`category'", "all", "rates") {
            display as text "{bf:Incidence Rates}"
            display as text "  {hline 60}"
            display as result "  stratetab" as text "    Export stratified incidence rates from strate"
            display as text "               command output. Formats person-time, events,"
            display as text "               rates, and confidence intervals. Supports"
            display as text "               rate ratios and stratified analyses."
            display as text ""
            display as result "  ratetab" as text "      Compute events, person-time, and rates by group"
            display as text "               from stset or event/exposure data, with exact,"
            display as text "               Poisson, or cluster-robust intervals."
            display as text ""
        }

        if inlist("`category'", "all", "survival") {
            display as text "{bf:Survival Analysis}"
            display as text "  {hline 60}"
            display as result "  survtab" as text "      Export Kaplan-Meier estimates, median survival,"
            display as text "               and restricted mean survival time (RMST) to"
            display as text "               Excel. Supports multiple groups and time points."
            display as text ""
        }

        if inlist("`category'", "all", "composite") {
            display as text "{bf:Composite}"
            display as text "  {hline 60}"
            display as result "  comptab" as text "      Combine multiple regtab or effecttab frames"
            display as text "               into a single publication-ready table. Supports"
            display as text "               side-by-side and stacked layouts."
            display as text ""
            display as result "  hrcomptab" as text "    Build a final Table 2-style sheet by using"
            display as text "               a stratetab frame as the scaffold and injecting"
            display as text "               selected rows from one or more regtab frames."
            display as text ""
        }

        if inlist("`category'", "all", "export") {
            display as text "{bf:Styled Export}"
            display as text "  {hline 60}"
            display as result "  puttab" as text "       Style a table already in memory -- the current"
            display as text "               dataset, a named frame, or a Stata matrix"
            display as text "               (e(b), r(table), collapse output) -- as one"
            display as text "               house-styled Excel sheet. Feeds stacktab."
            display as text ""
            display as result "  stacktab" as text "     Assemble multi-sheet composite Excel tables from"
            display as text "               source blocks (vstack or hstack), with column"
            display as text "               merges, titles, and notes."
            display as text ""
        }

        if inlist("`category'", "all", "general") {
            display as text "{bf:General Purpose}"
            display as text "  {hline 60}"
            display as result "  tabtools" as text "     Suite controller for listing commands and"
            display as text "               managing persistent formatting defaults with"
            display as text "               set and get."
            display as text ""
            display as result "  tabtools_tips " as text "Quick reference and worked recipes."
            display as text ""
        }

    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end

* Folded from _tabtools_fitcount.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _tabtools_fitcount Version 1.2.0  2026/11/19
* Fit-time event, people, and person-time counts for regtab (tabtools fitcount)
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: rclass

/*
SYNTAX:
	tabtools fitcount, events(varname) [people(varname) exposure(varname) terms
	    name(collection)]

Runs right after an estimation command whose results were collected with the
collect: prefix (or collect get e()). On the fit's own e(sample) it counts

	events     the sum of events() (a 0/1 failure indicator such as _d, or a
	           nonnegative integer event count)
	people     the number of distinct values of people() (clusters)
	exposure   the sum of exposure() (person-time)
	terms      for every factor-level coefficient of e(b), and every 0/1
	           indicator entered as a plain variable, the events in that level
	           (all factor parts of an interaction must match; an indicator's
	           level is 1) and whether the fit estimated a positive, finite
	           variance for it

and stores them with collect get in the active collection, tagged with the
fit's own cmdset, as results tt_events, tt_people, tt_people_ev (people
with an event, when people() is given), tt_exposure, and tt_terms.
regtab reads them for stats(events people exposure) and mincount(). The
collection does not keep e(sample), which is why the counts are taken here.
It also stores tt_cns, the fit's own notes for its base, empty, omitted, and
constrained coefficients (_regtab_bnotes), which regtab reads to label them
when the collection's own class cannot be trusted, and, with terms,
tt_levels, the level combinations each factor term holds in e(sample), which
tells a level a model leaves out (no observation) from one it holds.

The fit is identified exactly: the collection's latest cmdset must carry the
same command line and number of observations as the active e(), and every
e(b) coefficient the collection also holds must equal its collected _r_b (or
its exponent, for an eform collection) to reldif < 1e-12; anything else is
refused rather than attached to the wrong model. name() names the collection
of a collect, name(): fit, which nothing in e() records.
*/

capture program drop _tabtools_fitcount
program define _tabtools_fitcount, rclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	local _restore_needed = 0
	local _coll0 `"`c(collect_current)'"'
	local _coll_switched = 0
	capture noisily {
		syntax , EVents(varname numeric) [PEOple(varname) EXPosure(varname numeric) TERMS NAMe(name)]

		* name(): the collection the fit was collected into (collect, name():
		* does not change the current collection, and nothing in e() records
		* it). It is made current for the duration of fitcount only.
		if "`name'" != "" & "`name'" != `"`_coll0'"' {
			capture quietly collect set `name'
			if _rc {
				noisily display as error "tabtools fitcount: collection `name' not found"
				exit 111
			}
			local _coll_switched = 1
		}
		local _coll `"`c(collect_current)'"'
		local _hint "run tabtools fitcount right after collect: <estimation command>, and add name() for collect, name(): fits"

		* Live estimation results with an estimation sample are required.
		if `"`e(cmd)'"' == "" {
			noisily display as error "tabtools fitcount: no estimation results; run it right after the fit"
			exit 301
		}
		if `"`e(cmd_mi)'"' != "" | `"`e(cmd)'"' == "mi estimate" {
			noisily display as error "tabtools fitcount: mi estimate results carry no single estimation sample"
			exit 198
		}
		* An fweight row stands for several people and an iweight has no
		* count meaning, so a count of rows would be wrong: refused. pweights
		* and aweights leave each row one observation, which is what is counted.
		if inlist(`"`e(wtype)'"', "fweight", "iweight") {
			noisily display as error "tabtools fitcount: `e(wtype)'s are not allowed;" ///
				" the counts are of observations (pweights and aweights are ignored)"
			exit 101
		}
		* svy, subpop(): e(sample) holds the whole design sample, not the
		* subpopulation the estimates describe.
		if `"`e(subpop)'"' != "" {
			noisily display as error "tabtools fitcount: svy, subpop() results are refused;" ///
				" e(sample) spans the whole design, not the subpopulation"
			exit 459
		}
		tempvar touse
		capture quietly generate byte `touse' = e(sample)
		if _rc {
			noisily display as error "tabtools fitcount: the active estimation results have no e(sample)"
			exit 459
		}
		quietly count if `touse'
		local _n_sample = r(N)
		if `_n_sample' == 0 {
			noisily display as error "tabtools fitcount: e(sample) is empty in the data in memory;" ///
				" run it right after the fit, on the data the model was fitted to"
			exit 459
		}
		local _e_n = e(N)
		if !missing(`_e_n') & `_e_n' != `_n_sample' {
			noisily display as error "tabtools fitcount: e(sample) holds `_n_sample' observations but e(N) is `_e_n'"
			exit 459
		}

		* The fit must be the collection's latest cmdset: same command line,
		* same number of observations.
		capture quietly collect levelsof cmdset
		if _rc | `"`s(levels)'"' == "" {
			noisily display as error "tabtools fitcount: collection `_coll' holds no collected model"
			noisily display as error "  `_hint'"
			exit 119
		}
		local _k = 0
		foreach _lv in `s(levels)' {
			capture confirm integer number `_lv'
			if !_rc {
				if `_lv' > `_k' local _k = `_lv'
			}
		}
		if `_k' == 0 {
			noisily display as error "tabtools fitcount: the collection has no numbered cmdset"
			exit 459
		}
		local _ecmdline `"`e(cmdline)'"'
		preserve
		local _restore_needed = 1
		capture _tabtools_collect_render, type(meta) rowdim(cmdset) results(cmdline N)
		local _render_rc = _rc
		local _c_cmdline ""
		local _c_N = .
		if !`_render_rc' {
			quietly count
			forvalues _r = 2/`=_N' {
				if strtrim(A[`_r']) == "`_k'" {
					mata: st_local("_c_cmdline", strtrim(st_sdata(`_r', "B")))
					capture confirm variable C
					if !_rc local _c_N = real(subinstr(strtrim(C[`_r']), ",", "", .))
				}
			}
		}
		restore
		local _restore_needed = 0
		if `_render_rc' {
			noisily display as error "tabtools fitcount: could not read the collected models"
			exit `_render_rc'
		}
		mata: st_local("_same_cmd", strofreal(strtrim(st_local("_c_cmdline")) == strtrim(st_local("_ecmdline"))))
		if !`_same_cmd' | `"`_ecmdline'"' == "" {
			noisily display as error "tabtools fitcount: the active estimation results are not the latest model (cmdset `_k') of collection `_coll'"
			noisily display as error "  `_hint'"
			exit 459
		}
		if !missing(`_c_N') & !missing(`_e_n') & `_c_N' != `_e_n' {
			noisily display as error "tabtools fitcount: the collected model (cmdset `_k') has N = `_c_N', the active fit N = `_e_n'"
			exit 459
		}

		* Same coefficients: every e(b) column whose name the collection also
		* holds for cmdset `_k' must carry the collected _r_b (as is, or
		* exponentiated for an eform display) to reldif < 1e-12. A refit of the
		* same command line on changed data passes the checks above but not this.
		capture confirm matrix e(b)
		if _rc {
			noisily display as error "tabtools fitcount: the active estimation results have no e(b)"
			exit 459
		}
		tempfile _cjf
		local _cjs `"`_cjf'.stjson"'
		* The .stjson sibling of a tempfile is not removed by Stata at exit:
		* erase it on every path.
		capture noisily quietly collect save `"`_cjs'"', replace
		if _rc {
			local _b_rc = _rc
			capture erase `"`_cjs'"'
			exit `_b_rc'
		}
		capture noisily {
			mata: _tt_fc_L = cat(st_local("_cjs"))
			mata: _tt_fc_h = selectindex(ustrregexm(_tt_fc_L, `"[#"]cmdset\[`_k'\][#"]"') :& ustrregexm(_tt_fc_L, `"[#"]result\[_r_b\][#"]"'))
			mata: _tt_fc_k = _tt_fc_L[_tt_fc_h]
			mata: _tt_fc_d = rows(_tt_fc_h) ? strtoreal(ustrregexra(_tt_fc_L[_tt_fc_h :+ 1], `"^\s*"d":\s*([^,]*),?\s*$"', "$1")) : J(0, 1, .)
			mata: _tt_fc_ce = ustrregexra(_tt_fc_k, `"^.*[#"]coleq\[([^\]]*)\][#"].*$"', "$1") :* ustrregexm(_tt_fc_k, `"[#"]coleq\["')
			mata: _tt_fc_cn = ustrregexra(_tt_fc_k, `"^.*?[#"]colname\[(.+?)\][#"].*$"', "$1")
			mata: _tt_fc_s = st_matrixcolstripe("e(b)")
			mata: _tt_fc_b = st_matrix("e(b)")'
			* names as the collection keys them: 1b.x -> 1.x, c.z -> z
			mata: _tt_fc_bn = ustrregexra(ustrregexra(_tt_fc_s[., 2], "(^|#)([0-9]+)[a-z]+\.", "$1$2."), "(^|#)co?\.", "$1")
			mata: _tt_fc_q = all((_tt_fc_s[., 1] :== "") :| (_tt_fc_s[., 1] :== "_"))
			mata: _tt_fc_bk = _tt_fc_q ? _tt_fc_bn : (_tt_fc_s[., 1] :+ ":" :+ _tt_fc_bn)
			mata: _tt_fc_ck = _tt_fc_q ? _tt_fc_cn : (_tt_fc_ce :+ ":" :+ _tt_fc_cn)
			mata: _tt_fc_m = 0; _tt_fc_x = 0
			mata: for (_tt_fc_j = 1; _tt_fc_j <= rows(_tt_fc_bk); _tt_fc_j++) { _tt_fc_i = selectindex(_tt_fc_ck :== _tt_fc_bk[_tt_fc_j]); if (rows(_tt_fc_i) != 1) continue; if (missing(_tt_fc_d[_tt_fc_i])) continue; _tt_fc_m++; if (!(reldif(_tt_fc_d[_tt_fc_i], _tt_fc_b[_tt_fc_j]) < 1e-12 | reldif(_tt_fc_d[_tt_fc_i], exp(_tt_fc_b[_tt_fc_j])) < 1e-12)) _tt_fc_x++; }
			mata: st_local("_b_matched", strofreal(_tt_fc_m)); st_local("_b_differ", strofreal(_tt_fc_x))
		}
		local _b_rc = _rc
		capture erase `"`_cjs'"'
		capture mata: mata drop _tt_fc_*
		if `_b_rc' {
			noisily display as error "tabtools fitcount: could not read the coefficients of collected model `_k'"
			exit `_b_rc'
		}
		if `_b_matched' == 0 {
			noisily display as error "tabtools fitcount: no coefficient of the active fit was found in collected model `_k'; its identity cannot be checked"
			exit 459
		}
		if `_b_differ' > 0 {
			noisily display as error "tabtools fitcount: `_b_differ' of `_b_matched' coefficients of the active fit differ from collected model `_k' (same command line, different estimates)"
			noisily display as error "  `_hint'"
			exit 459
		}

		* events(): nonmissing, nonnegative integers in the estimation sample
		quietly count if `touse' & missing(`events')
		if r(N) > 0 {
			noisily display as error "tabtools fitcount: events() is missing in `r(N)' observations of e(sample)"
			exit 459
		}
		quietly count if `touse' & (`events' < 0 | `events' != floor(`events'))
		if r(N) > 0 {
			noisily display as error "tabtools fitcount: events() must be a nonnegative integer count (0/1 for a failure indicator)"
			exit 459
		}
		tempname _ev _pp _ppe _px
		quietly summarize `events' if `touse', meanonly
		scalar `_ev' = r(sum)

		scalar `_pp' = .
		scalar `_ppe' = .
		if "`people'" != "" {
			capture confirm string variable `people'
			if _rc quietly count if `touse' & missing(`people')
			else quietly count if `touse' & `people' == ""
			if r(N) > 0 {
				noisily display as error "tabtools fitcount: people() is missing in `r(N)' observations of e(sample)"
				exit 459
			}
			* distinct clusters counted on a copy: the caller's sort order stays
			preserve
			local _restore_needed = 1
			quietly keep if `touse'
			quietly keep `people' `events'
			* people with an event: distinct people() with events() > 0 on
			* any of their e(sample) rows
			tempvar _anyev
			quietly bysort `people': egen byte `_anyev' = max(`events' > 0)
			quietly by `people': keep if _n == 1
			scalar `_pp' = _N
			quietly count if `_anyev'
			scalar `_ppe' = r(N)
			restore
			local _restore_needed = 0
		}

		scalar `_px' = .
		if "`exposure'" != "" {
			quietly count if `touse' & (missing(`exposure') | `exposure' < 0)
			if r(N) > 0 {
				noisily display as error "tabtools fitcount: exposure() must be nonmissing and nonnegative in e(sample) (`r(N)' observations are not)"
				exit 459
			}
			quietly summarize `exposure' if `touse', meanonly
			scalar `_px' = r(sum)
		}

		* Per-term events: every factor-level coefficient of e(b), keyed as the
		* collection keys it (1b.x -> 1.x, 1b.g#co.z -> 1.g#z).
		local _terms_str ""
		local _n_terms = 0
		local _names : colnames e(b)
		if "`terms'" != "" {
			tempname _V
			capture matrix `_V' = e(V)
			local _has_V = (_rc == 0)
			local _ncol : word count `_names'
			* In a multi-equation model, an equation whose every coefficient
			* is constrained (mlogit's base outcome) estimates nothing and no
			* table shows it; its copies of a term must not decide the term's
			* variance flag. _eqskip holds a 0/1 per column of e(b).
			local _eqskip ""
			if `_has_V' {
				local _eqs : coleq e(b)
				local _ueqs : list uniq _eqs
				if `: word count `_ueqs'' > 1 {
					local _eqok ""
					forvalues _j = 1/`_ncol' {
						local _vjj = `_V'[`_j', `_j']
						if `_vjj' > 0 & `_vjj' < . {
							local _eqj : word `_j' of `_eqs'
							local _eqok : list _eqok | _eqj
						}
					}
					forvalues _j = 1/`_ncol' {
						local _eqj : word `_j' of `_eqs'
						local _eqin : list _eqj in _eqok
						local _eqskip "`_eqskip' `=!`_eqin''"
					}
				}
			}
			local _seen ""
			forvalues _j = 1/`_ncol' {
				if "`_eqskip'" != "" {
					if `: word `_j' of `_eqskip'' continue
				}
				local _nm : word `_j' of `_names'
				local _key ""
				local _cond ""
				local _hasfv = 0
				local _bad = 0
				local _parts = subinstr("`_nm'", "#", " ", .)
				foreach _p of local _parts {
					if regexm("`_p'", "^([0-9]+)[a-z]*\.(.+)$") {
						local _lev = regexs(1)
						local _var = regexs(2)
						capture confirm numeric variable `_var', exact
						if _rc local _bad = 1
						local _kp "`_lev'.`_var'"
						local _cond `"`_cond' & `_var' == `_lev'"'
						local _hasfv = 1
					}
					else if regexm("`_p'", "^[a-z]*\.(.+)$") {
						local _kp = regexs(1)
					}
					else local _kp "`_p'"
					if "`_key'" == "" local _key "`_kp'"
					else local _key "`_key'#`_kp'"
				}
				* a plain 0/1 indicator counts as the level 1 of itself
				if !`_hasfv' & !`_bad' & strpos("`_nm'", "#") == 0 & ///
					strpos("`_nm'", ".") == 0 & "`_nm'" != "_cons" {
					capture confirm numeric variable `_nm', exact
					if !_rc {
						capture assert inlist(`_nm', 0, 1) if `touse'
						if !_rc {
							local _key "`_nm'"
							local _cond `"& `_nm' == 1"'
							local _hasfv = 1
						}
					}
				}
				if !`_hasfv' | `_bad' continue
				local _vok = 0
				if `_has_V' {
					local _vjj = `_V'[`_j', `_j']
					if `_vjj' > 0 & `_vjj' < . local _vok = 1
				}
				local _ti : list posof "`_key'" in _seen
				if `_ti' > 0 {
					* the same term in another equation: one count, and the
					* variance is acceptable only if every copy has one
					if !`_vok' local _tvok_`_ti' = 0
					continue
				}
				local _seen "`_seen' `_key'"
				local ++_n_terms
				quietly summarize `events' if `touse' `_cond', meanonly
				local _tev = r(sum)
				if missing(`_tev') local _tev = 0
				local _tev_`_n_terms' = ustrregexra(strofreal(`_tev', "%21.0f"), "-(?=[0.,]+\z)", "")
				local _tvok_`_n_terms' = `_vok'
			}
			forvalues _ti = 1/`_n_terms' {
				local _key : word `_ti' of `_seen'
				if `_ti' > 1 local _terms_str "`_terms_str';"
				local _terms_str "`_terms_str'`_key'=`_tev_`_ti''|`_tvok_`_ti''"
			}
			if `_n_terms' == 0 {
				noisily display as text "(tabtools fitcount: the model has no factor-level coefficients; no per-term counts stored)"
			}
		}

		* The fit's own notes for its constrained coefficients (base, empty,
		* omitted, constrained by e(Cns)), from the e(b) stripe: the
		* collection keeps no b./o. markers, and its "omit-type" is "empty"
		* for every constrained cell of some fits (stintreg, streg, nbreg).
		_regtab_bnotes
		local _cns_str `"`_bn_notes'"'
		if `"`_cns_str'"' == "" local _cns_str "-"

		* With terms, the levels every factor term of e(b) holds in e(sample):
		* ";sig=key key ...;" per term, sig the key with each level written *
		* (*.x, *.a#*.b, *.g#z), each key a level combination with at least one
		* observation. A level of a term that is missing from e(b) and from
		* this list has no observation in the estimation sample.
		local _lev_str ""
		if "`terms'" != "" {
			local _sigs ""
			foreach _nm of local _names {
				local _key = ustrregexra(ustrregexra("`_nm'", ///
					"(^|#)([0-9]+)[a-z]*\.", "$1$2."), "(^|#)[a-z]+\.", "$1")
				if !ustrregexm("`_key'", "(^|#)[0-9]+\.") continue
				local _sig = ustrregexra("`_key'", "(^|#)[0-9]+\.", "$1*.")
				local _sigs : list _sigs | _sig
			}
			foreach _sig of local _sigs {
				local _fvl ""
				local _sok = 1
				foreach _p in `=subinstr("`_sig'", "#", " ", .)' {
					if substr("`_p'", 1, 2) != "*." continue
					local _v = substr("`_p'", 3, .)
					capture confirm numeric variable `_v', exact
					if _rc local _sok = 0
					local _fvl "`_fvl' `_v'"
				}
				if !`_sok' continue
				mata: _tt_fc_U = uniqrows(st_data(., tokens(st_local("_fvl")), st_local("touse")))
				mata: _tt_fc_P = tokens(subinstr(st_local("_sig"), "#", " ")); _tt_fc_o = ""; _tt_fc_M = rowmissing(_tt_fc_U)
				mata: for (_tt_fc_i = 1; _tt_fc_i <= rows(_tt_fc_U); _tt_fc_i++) { if (_tt_fc_M[_tt_fc_i] > 0) continue; _tt_fc_q = 0; _tt_fc_k = ""; for (_tt_fc_j = 1; _tt_fc_j <= cols(_tt_fc_P); _tt_fc_j++) { _tt_fc_t = _tt_fc_P[_tt_fc_j]; if (substr(_tt_fc_t, 1, 2) == "*.") { _tt_fc_q++; _tt_fc_t = ustrregexra(strofreal(_tt_fc_U[_tt_fc_i, _tt_fc_q], "%21.0g"), "-(?=[0.,]+\z)", "") + substr(_tt_fc_t, 2, strlen(_tt_fc_t)); }; _tt_fc_k = _tt_fc_k + (_tt_fc_j > 1 ? "#" : "") + _tt_fc_t; }; _tt_fc_o = _tt_fc_o + " " + _tt_fc_k; }
				mata: st_local("_sigk", strtrim(_tt_fc_o))
				capture mata: mata drop _tt_fc_*
				local _lev_str `"`_lev_str';`_sig'=`_sigk'"'
			}
			if `"`_lev_str'"' != "" local _lev_str `"`_lev_str';"'
			else local _lev_str "-"
		}

		* Attach to the fit's own cmdset in the active collection. The counts
		* first; then the string records, as r() macros of a helper, because
		* collect get name = ("...") refuses a string longer than 2,045 bytes
		* (a strL expression) and a large factorial's record is longer.
		quietly collect get tt_events = (scalar(`_ev')), tags(cmdset[`_k'])
		if !missing(`_pp') quietly collect get tt_people = (scalar(`_pp')), tags(cmdset[`_k'])
		if !missing(`_ppe') quietly collect get tt_people_ev = (scalar(`_ppe')), tags(cmdset[`_k'])
		if !missing(`_px') quietly collect get tt_exposure = (scalar(`_px')), tags(cmdset[`_k'])
		if "`terms'" != "" {
			if `"`_terms_str'"' == "" local _terms_str "-"
			_tabtools_fitcount_rec tt_terms `"`_terms_str'"'
			quietly collect get r(), tags(cmdset[`_k'])
		}
		* The notes and sample levels are optional: a record that cannot be
		* stored is left out with a note, never at the cost of the counts;
		* regtab then reads the model as one without the record.
		local _rec_args `"tt_cns `"`_cns_str'"'"'
		if "`terms'" != "" local _rec_args `"`_rec_args' tt_levels `"`_lev_str'"'"'
		capture _tabtools_fitcount_rec `_rec_args'
		local _rec_rc = _rc
		if `_rec_rc' == 0 {
			capture quietly collect get r(), tags(cmdset[`_k'])
			local _rec_rc = _rc
		}
		if `_rec_rc' {
			noisily display as text "(tabtools fitcount: the record of the fit's notes and sample levels could not be stored (error `_rec_rc'); regtab reads model `_k' without it)"
		}

		noisily display as text "tabtools fitcount (model `_k', " as result "`_n_sample'" as text " obs): events " ///
			as result strtrim(ustrregexra(string(`_ev', "%21.0fc"), "-(?=[0.,]+\z)", "")) ///
			as text cond(missing(`_pp'), "", ", people ") as result cond(missing(`_pp'), "", strtrim(ustrregexra(string(`_pp', "%21.0fc"), "-(?=[0.,]+\z)", ""))) ///
			as text cond(missing(`_ppe'), "", ", people with an event ") as result cond(missing(`_ppe'), "", strtrim(ustrregexra(string(`_ppe', "%21.0fc"), "-(?=[0.,]+\z)", ""))) ///
			as text cond(missing(`_px'), "", ", exposure ") as result cond(missing(`_px'), "", strtrim(ustrregexra(string(`_px', "%21.2fc"), "-(?=[0.,]+\z)", "")))

		return scalar events = `_ev'
		if !missing(`_pp') return scalar people = `_pp'
		if !missing(`_ppe') return scalar people_ev = `_ppe'
		if !missing(`_px') return scalar exposure = `_px'
		return scalar N = `_n_sample'
		return scalar cmdset = `_k'
		return local collection `"`_coll'"'
		if "`terms'" != "" {
			return scalar n_terms = `_n_terms'
			return local terms `"`_terms_str'"'
		}
	}
	local rc = _rc
	if `_restore_needed' capture restore
	capture mata: mata drop _tt_fc_*
	* stata-dev-ignore: capture-rc, capture_rc — cleanup zone; the fit's rc is already saved in rc, and the caller's current collection is restored best-effort
	if `_coll_switched' capture quietly collect set `_coll0'
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end

* =============================================================================
* _tabtools_fitcount_rec: string records of tabtools fitcount, as r() macros
* =============================================================================
* Usage: _tabtools_fitcount_rec <name> `"<text>"' [<name> `"<text>"' ...]
* Returns each text as r(<name>), so collect get r() stores it whatever its
* length (collect get name = ("...") is limited to 2,045 bytes).
capture program drop _tabtools_fitcount_rec
program define _tabtools_fitcount_rec, rclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		while `"`0'"' != "" {
			gettoken _nm 0 : 0
			gettoken _tx 0 : 0
			return local `_nm' `"`_tx'"'
		}
	}
	local rc = _rc
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end

* Folded from _tabtools_set.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _tabtools_set Version 1.2.0  2026/11/19
* Session destinations and defaults behind tabtools set / tabtools query
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: rclass

/*
    _tabtools_set set <key> <value>     key: workbook, markdown, latex,
                                             texopts, headershade, smallcells
    _tabtools_set set <key> clear       remove one session setting
    _tabtools_set clear [, quiet]       remove every session setting
    _tabtools_set query                 list them; r(workbook) etc.

    State lives in globals for the life of the Stata session:
        TABTOOLS_set_workbook          path of the session workbook
        TABTOOLS_set_workbook_fresh    1 until the first write to it
        TABTOOLS_set_markdown          path of the session Markdown file
        TABTOOLS_set_markdown_fresh    1 until the first write to it
        TABTOOLS_set_latex             path of the session LaTeX file
        TABTOOLS_set_latex_fresh       1 until the first write to it
        TABTOOLS_set_texopts           LaTeX layout sub-options (texopts())
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

    A _fresh flag is set by -tabtools set workbook|markdown|latex- and
    cleared by the first command that writes to that session target. That
    first write replaces the file (a workbook is erased and started again, a
    Markdown or LaTeX file is overwritten); every later write adds a sheet to
    the workbook or appends to the Markdown or LaTeX file. Setting a different target re-arms the
    flag; setting the current one again is a no-op; a file this session has
    already written is never replaced. Paths are stored absolute.
*/

capture program drop _tabtools_set
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
            local _val = strtrim(`"`macval(_val)'"')
            * One layer of quotes around a path is the user's, not the path's.
            if inlist("`_key'", "workbook", "markdown", "latex") {
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
                if !inlist("`_key'", "workbook", "markdown", "latex", "texopts", "headershade", "smallcells") {
                    display as error `"Unknown session setting "`_key'". Valid: workbook, markdown, latex, texopts, headershade, smallcells"'
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
            else if "`_key'" == "latex" {
                if !strmatch(lower(`"`_val'"'), "*.tex") {
                    display as error "tabtools set latex: the file must have a .tex extension"
                    exit 198
                }
                _tabtools_validate_path `"`_val'"' "tabtools set latex"
                * Stored absolute and normalised, so a later cd does not move
                * the target. The same target again is a no-op; a different
                * one re-arms "first write replaces" unless this session has
                * already written that file, which is never replaced.
                _tabtools_set_sinks normalize, path(`"`_val'"')
                local _val `"`_ss_abs'"'
                if `"`_val'"' == `"$TABTOOLS_set_latex"' {
                    display as text "tabtools: " as result `""`_val'""' ///
                        as text " is already the session LaTeX file; later writes append"
                }
                else if `_ss_written' {
                    global TABTOOLS_set_latex `"`_val'"'
                    global TABTOOLS_set_latex_fresh 0
                    display as text "tabtools: session LaTeX file " as result `""`_val'""' ///
                        as text " (already written in this session; later writes append)"
                }
                else {
                    global TABTOOLS_set_latex `"`_val'"'
                    global TABTOOLS_set_latex_fresh 1
                    display as text "tabtools: session LaTeX file " as result `""`_val'""' ///
                        as text " (the first write replaces it; later writes append)"
                }
                return local latex `"`_val'"'
            }
            else if "`_key'" == "texopts" {
                * Validated now (label() refused: one key on every table),
                * applied by the LaTeX writer when a command gives none.
                _tabtools_texopts `"`macval(_val)'"', session
                global TABTOOLS_set_texopts `"`macval(_val)'"'
                display as text "tabtools: session LaTeX layout " as result `"`macval(_val)'"' ///
                    as text " (a command's own texopts() replaces it)"
                return local texopts `"`macval(_val)'"'
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
                * Stored as the number, not as typed: the table writers print
                * it in the masks and the footnote (+5 or 05 would read <+5).
                local _k = real("`_k'")
                if `"`_mode'"' == "" local _mode "full"
                global TABTOOLS_set_smallcells `_k'
                global TABTOOLS_set_smallcells_mode "`_mode'"
                display as text "tabtools: session smallcells " as result "`_k'" ///
                    as text " (`_mode'; table commands with smallcells(); nosmallcells skips it)"
                return scalar smallcells = `_k'
                return local smallcells_mode "`_mode'"
            }
            else {
                display as error `"Unknown session setting "`_key'". Valid: workbook, markdown, latex, texopts, headershade, smallcells"'
                exit 198
            }
        }
        else if "`_action'" == "clear" {
            syntax [, QUIET]
            foreach _k in workbook markdown latex texopts headershade smallcells {
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
            local _tx `"$TABTOOLS_set_latex"'
            mata: st_local("_to", st_global("TABTOOLS_set_texopts"))
            local _hs `"$TABTOOLS_set_headershade"'
            local _sc `"$TABTOOLS_set_smallcells"'
            local _scm `"$TABTOOLS_set_smallcells_mode"'
            local _bs `"$TABTOOLS_BORDER"'
            if `"`_sc'"' != "" & `"`_scm'"' == "" local _scm "full"
            display as text ""
            display as text "tabtools session settings"
            foreach _k in workbook markdown latex {
                if "`_k'" == "workbook" {
                    local _v `"`_wb'"'
                    local _lab "  Workbook:    "
                }
                else if "`_k'" == "markdown" {
                    local _v `"`_md'"'
                    local _lab "  Markdown:    "
                }
                else {
                    local _v `"`_tx'"'
                    local _lab "  LaTeX:       "
                }
                if `"`_v'"' == "" display as text "`_lab'" as text "(not set)"
                else {
                    local _st "later writes append"
                    if "`_k'" == "workbook" local _st "later writes add sheets"
                    if "${TABTOOLS_set_`_k'_fresh}" == "1" local _st "next write replaces it"
                    display as text "`_lab'" as result `""`_v'""' as text " (`_st')"
                }
            }
            if `"`macval(_to)'"' == "" display as text "  LaTeX layout: (not set)"
            else display as text "  LaTeX layout: " as result `"`macval(_to)'"'
            if `"`_hs'"' == "" display as text "  Headershade: (not set)"
            else display as text "  Headershade: " as result "`_hs'"
            if `"`_sc'"' == "" display as text "  Smallcells:  (not set)"
            else display as text "  Smallcells:  " as result "`_sc'" as text " (`_scm')"
            if `"`_bs'"' == "" display as text "  Borderstyle: (not set)"
            else display as text "  Borderstyle: " as result `"`_bs'"'
            return local workbook `"`_wb'"'
            return local markdown `"`_md'"'
            return local latex `"`_tx'"'
            return local texopts `"`macval(_to)'"'
            return local headershade `"`_hs'"'
            return local smallcells `"`_sc'"'
            return local smallcells_mode `"`_scm'"'
            return local borderstyle `"`_bs'"'
            return local workbook_fresh = cond(`"`_wb'"' != "", cond("$TABTOOLS_set_workbook_fresh" == "1", "1", "0"), "")
            return local markdown_fresh = cond(`"`_md'"' != "", cond("$TABTOOLS_set_markdown_fresh" == "1", "1", "0"), "")
            return local latex_fresh = cond(`"`_tx'"' != "", cond("$TABTOOLS_set_latex_fresh" == "1", "1", "0"), "")
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
