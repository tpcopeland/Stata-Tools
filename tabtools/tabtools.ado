*! tabtools Version 1.9.8  2026/07/13
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
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
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
        font(string) fontsize(integer 0) HEADERColor(string) ///
        ZEBRAColor(string) BORDERstyle(string) PERManent PROFile(string)]

    local _has_display_opts = ("`list'" != "" | "`detail'" != "" | "`category'" != "")
    local _has_theme_builder_opts = ///
        (`"`font'"' != "" | `fontsize' > 0 | `"`headercolor'"' != "" | ///
        `"`zebracolor'"' != "" | `"`borderstyle'"' != "")
    local _has_profile_opts = ("`permanent'" != "" | `"`profile'"' != "")

    capture findfile _tabtools_common.ado
    if _rc {
        display as error "_tabtools_common.ado not found; reinstall tabtools"
        exit 111
    }
    run "`r(fn)'"
    capture _tabtools_require_helpers, ///
        required("_tabtools_validate_color _tabtools_resolve_format _tabtools_apply_theme") ///
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
        local setval = strtrim(`"`setrest'"')
        local _named_theme_active = ("$TABTOOLS_THEME" != "" & "$TABTOOLS_THEME" != "custom")

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
        if "`setkey'" == "font" {
            local setval = subinstr(`"`setval'"', `"""', "", .)
            local setval = strtrim(`"`setval'"')
        }

        if "`setkey'" != "theme" & `_has_theme_builder_opts' {
            display as error "font()/fontsize()/headercolor()/zebracolor()/borderstyle() are only allowed with tabtools set theme custom"
            exit 198
        }

        if "`setkey'" == "clear" {
            if "`setval'" != "" {
                display as error "tabtools set clear does not accept additional arguments"
                exit 198
            }
            global TABTOOLS_FONT
            global TABTOOLS_FONTSIZE
            global TABTOOLS_BORDER
            global TABTOOLS_THEME
            global TABTOOLS_HEADERCOLOR
            global TABTOOLS_ZEBRACOLOR
            global TABTOOLS_DIGITS
            global TABTOOLS_BOLDP
            display as text "tabtools: all persistent defaults cleared"
            return local action "cleared"
        }
        else if "`setkey'" == "font" {
            if `_named_theme_active' {
                _tabtools_apply_theme "$TABTOOLS_THEME"
                global TABTOOLS_FONT "`_theme_font'"
                global TABTOOLS_FONTSIZE `_theme_fontsize'
                global TABTOOLS_BORDER "`_theme_border'"
                global TABTOOLS_THEME "custom"
            }
            if "`setval'" == "" {
                display as error "tabtools set font requires a value (e.g., tabtools set font Calibri)"
                exit 198
            }
            global TABTOOLS_FONT "`setval'"
            display as text "tabtools: default font set to " as result "`setval'"
            return local font "`setval'"
        }
        else if "`setkey'" == "fontsize" {
            if `_named_theme_active' {
                _tabtools_apply_theme "$TABTOOLS_THEME"
                global TABTOOLS_FONT "`_theme_font'"
                global TABTOOLS_FONTSIZE `_theme_fontsize'
                global TABTOOLS_BORDER "`_theme_border'"
                global TABTOOLS_THEME "custom"
            }
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
            global TABTOOLS_FONTSIZE `setval'
            display as text "tabtools: default font size set to " as result "`setval'"
            return scalar fontsize = `setval'
        }
        else if "`setkey'" == "borderstyle" {
            if `_named_theme_active' {
                _tabtools_apply_theme "$TABTOOLS_THEME"
                global TABTOOLS_FONT "`_theme_font'"
                global TABTOOLS_FONTSIZE `_theme_fontsize'
                global TABTOOLS_BORDER "`_theme_border'"
                global TABTOOLS_THEME "custom"
            }
            if !inlist("`setval'", "default", "thin", "medium", "academic") {
                display as error "borderstyle must be: default, thin, medium, or academic"
                exit 198
            }
            global TABTOOLS_BORDER "`setval'"
            display as text "tabtools: default border style set to " as result "`setval'"
            return local borderstyle "`setval'"
        }
        else if "`setkey'" == "theme" {
            * Extract the theme name (first token before any comma).
            * Theme sub-options (font, fontsize, etc.) are parsed by the outer
            * syntax command, so we only need the theme name from setval.
            gettoken _theme_name : setval, parse(",")
            local _theme_name = lower(strtrim("`_theme_name'"))
            if "`_theme_name'" == "" {
                display as error "tabtools set theme requires a theme name"
                exit 198
            }
            if "`_theme_name'" == "custom" {
                * Custom theme: omitted sub-options reset to command defaults.
                if `fontsize' > 0 {
                    if `fontsize' < 6 | `fontsize' > 72 {
                        display as error "fontsize must be between 6 and 72"
                        exit 198
                    }
                }
                if "`borderstyle'" != "" & !inlist("`borderstyle'", "default", "thin", "medium", "academic") {
                    display as error "borderstyle must be: default, thin, medium, or academic"
                    exit 198
                }
                if "`headercolor'" != "" _tabtools_validate_color "`headercolor'" "headercolor()"
                if "`zebracolor'" != "" _tabtools_validate_color "`zebracolor'" "zebracolor()"

                global TABTOOLS_FONT
                global TABTOOLS_FONTSIZE
                global TABTOOLS_BORDER
                global TABTOOLS_HEADERCOLOR
                global TABTOOLS_ZEBRACOLOR
                if "`font'" != "" global TABTOOLS_FONT "`font'"
                if `fontsize' > 0 global TABTOOLS_FONTSIZE `fontsize'
                if "`headercolor'" != "" global TABTOOLS_HEADERCOLOR "`headercolor'"
                if "`zebracolor'" != "" global TABTOOLS_ZEBRACOLOR "`zebracolor'"
                if "`borderstyle'" != "" global TABTOOLS_BORDER "`borderstyle'"
                global TABTOOLS_THEME "custom"

                _tabtools_resolve_format, theme(custom)
                display as text "tabtools: custom theme configured"
                display as text "  font: " as result "`_font'"
                display as text "  fontsize: " as result "`_fontsize'"
                display as text "  borderstyle: " as result "`borderstyle'"
                if "$TABTOOLS_HEADERCOLOR" != "" display as text "  headercolor: " as result "$TABTOOLS_HEADERCOLOR"
                if "$TABTOOLS_ZEBRACOLOR" != "" display as text "  zebracolor: " as result "$TABTOOLS_ZEBRACOLOR"
                return local theme "custom"
            }
            else {
                if `_has_theme_builder_opts' {
                    display as error "font()/fontsize()/headercolor()/zebracolor()/borderstyle() are only allowed with tabtools set theme custom"
                    exit 198
                }
                if !inlist("`_theme_name'", "lancet", "nejm", "bmj", "apa", "jama", "plos", "nature", "cell", "annals") {
                    display as error "theme must be: lancet, nejm, bmj, apa, jama, plos, nature, cell, annals, or custom"
                    exit 198
                }
                global TABTOOLS_THEME "`_theme_name'"
                global TABTOOLS_HEADERCOLOR ""
                global TABTOOLS_ZEBRACOLOR ""
                display as text "tabtools: default theme set to " as result "`_theme_name'"
                return local theme "`_theme_name'"
            }
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
            display as error `"Unknown setting "`setkey'". Valid: font, fontsize, borderstyle, theme, digits, boldp, clear"'
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
        if `_has_theme_builder_opts' {
            display as error "font()/fontsize()/headercolor()/zebracolor()/borderstyle() are only allowed with tabtools set theme custom"
            exit 198
        }

        _tabtools_resolve_format
        local _eff_font "`_font'"
        local _eff_fontsize "`_fontsize'"
        local _eff_border "`borderstyle'"
        local _eff_headercolor "$TABTOOLS_HEADERCOLOR"
        local _eff_zebracolor "$TABTOOLS_ZEBRACOLOR"
        if "$TABTOOLS_THEME" != "" & "$TABTOOLS_THEME" != "custom" {
            local _eff_headercolor ""
            local _eff_zebracolor ""
        }

        display as text ""
        display as text "{hline 50}"
        display as result "tabtools" as text " - Persistent Formatting Defaults"
        display as text "{hline 50}"
        display as text ""

        display as text "  Font:        " as result "`_eff_font'"
        display as text "  Font size:   " as result "`_eff_fontsize'"
        display as text "  Border:      " as result "`_eff_border'"
        if "$TABTOOLS_THEME" != "" {
            display as text "  Theme:       " as result "$TABTOOLS_THEME"
        }
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
        if "$TABTOOLS_THEME" != "" & "$TABTOOLS_THEME" != "custom" {
            display as text "  Set with: " as result "tabtools set theme custom, font(Calibri) fontsize(11) borderstyle(thin)"
            display as text "            " as result "tabtools set theme lancet"
        }
        else {
            display as text "  Set with: " as result "tabtools set font Calibri"
            display as text "            " as result "tabtools set fontsize 11"
            display as text "            " as result "tabtools set borderstyle thin"
            display as text "            " as result "tabtools set theme lancet"
        }
        display as text "            " as result "tabtools set digits 3"
        display as text "            " as result "tabtools set boldp 0.05"
        display as text "  Clear:    " as result "tabtools set clear"
        display as text ""

        return local font "`_eff_font'"
        return local fontsize "`_eff_fontsize'"
        return local borderstyle "`_eff_border'"
        return local theme "$TABTOOLS_THEME"
        return local headercolor "`_eff_headercolor'"
        return local zebracolor "`_eff_zebracolor'"
        return local digits "$TABTOOLS_DIGITS"
        return local boldp "$TABTOOLS_BOLDP"
    }

    * =========================================================================
    * SUBCOMMAND: use
    * =========================================================================
    else if "`subcmd'" == "use" {
        if `_has_display_opts' {
            display as error "list, detail, and category() are only allowed in display mode"
            exit 198
        }
        if `_has_theme_builder_opts' {
            display as error "font()/fontsize()/headercolor()/zebracolor()/borderstyle() are only allowed with tabtools set theme custom"
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
            local _profile_path `"`_use_rest'"'
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
        if `_has_theme_builder_opts' {
            display as error "font()/fontsize()/headercolor()/zebracolor()/borderstyle() are only allowed with tabtools set theme custom"
            exit 198
        }
        if `_has_profile_opts' {
            display as error "permanent and profile() are only allowed with tabtools set ..., permanent"
            exit 198
        }
        * If anything was passed that isn't a subcommand, error
        if "`subcmd'" != "" {
            display as error `"Unknown subcommand "`subcmd'". Use: tabtools [set|get|use] or tabtools [, list detail]"'
            exit 198
        }

        // Default category is all
        if "`category'" == "" local category "all"

        // Validate category option
        local category = lower("`category'")
        local _valid_category = ///
            inlist("`category'", "all", "descriptive", "models", "rates", "general") | ///
            inlist("`category'", "survival", "diagnostics", "composite", "export", "simulation")
        if !`_valid_category' {
            display as error "category() must be: all, descriptive, models, rates, survival, diagnostics, composite, export, simulation, or general"
            exit 198
        }

        // Define commands by category
        local cmd_descriptive "table1_tc desctab crosstab corrtab"
        local cmd_models "regtab effecttab"
        local cmd_rates "stratetab"
        local cmd_survival "survtab"
        local cmd_diagnostics "diagtab"
        local cmd_composite "comptab hrcomptab"
        local cmd_export "puttab stacktab"
        local cmd_simulation "simtab"
        local cmd_general "tabtools tabtools_tips"

        // Build selected list based on category
        if "`category'" == "descriptive" {
            local selected_cmds "`cmd_descriptive'"
        }
        else if "`category'" == "models" {
            local selected_cmds "`cmd_models'"
        }
        else if "`category'" == "rates" {
            local selected_cmds "`cmd_rates'"
        }
        else if "`category'" == "survival" {
            local selected_cmds "`cmd_survival'"
        }
        else if "`category'" == "diagnostics" {
            local selected_cmds "`cmd_diagnostics'"
        }
        else if "`category'" == "composite" {
            local selected_cmds "`cmd_composite'"
        }
        else if "`category'" == "export" {
            local selected_cmds "`cmd_export'"
        }
        else if "`category'" == "simulation" {
            local selected_cmds "`cmd_simulation'"
        }
        else if "`category'" == "general" {
            local selected_cmds "`cmd_general'"
        }
        else {
            local selected_cmds "`cmd_descriptive' `cmd_models' `cmd_rates' `cmd_survival' `cmd_diagnostics' `cmd_composite' `cmd_export' `cmd_simulation' `cmd_general'"
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
                display as result "  desctab      " as text "- Format descriptive table collects"
                display as result "  crosstab     " as text "- Cross-tabulation with association measures"
                display as result "  corrtab      " as text "- Correlation matrix with significance"
                display as text ""
            }

            if inlist("`category'", "all", "models") {
                display as text "{bf:Model Results}"
                display as result "  regtab       " as text "- Regression results from any estimation command"
                display as result "  effecttab    " as text "- Treatment-effect style tables from supported results"
                display as text ""
            }

            if inlist("`category'", "all", "rates") {
                display as text "{bf:Incidence Rates}"
                display as result "  stratetab    " as text "- Incidence rates from strate output"
                display as text ""
            }

            if inlist("`category'", "all", "survival") {
                display as text "{bf:Survival Analysis}"
                display as result "  survtab      " as text "- Kaplan-Meier estimates, medians, and RMST"
                display as text ""
            }

            if inlist("`category'", "all", "diagnostics") {
                display as text "{bf:Diagnostic Accuracy}"
                display as result "  diagtab      " as text "- Sensitivity, specificity, PPV, NPV, ROC"
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

            if inlist("`category'", "all", "simulation") {
                display as text "{bf:Simulation Studies}"
                display as result "  simtab       " as text "- Monte Carlo performance table (pairs with simsum/siman)"
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
        return local categories "descriptive models rates survival diagnostics composite export simulation general"
    }

    } // end capture noisily
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end

* Write current tabtools defaults as a runnable Stata profile.
capture program drop _tabtools_write_profile
program define _tabtools_write_profile, nclass
    version 16.0
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

        if "$TABTOOLS_THEME" == "custom" {
            file write `fh' "tabtools set theme custom"
            local _has_custom_opts = ///
                ("$TABTOOLS_FONT" != "" | "$TABTOOLS_FONTSIZE" != "" | ///
                "$TABTOOLS_HEADERCOLOR" != "" | "$TABTOOLS_ZEBRACOLOR" != "" | ///
                "$TABTOOLS_BORDER" != "")
            if `_has_custom_opts' {
                file write `fh' ","
            }
            if "$TABTOOLS_FONT" != "" {
                file write `fh' " font(" `"""' "$TABTOOLS_FONT" `"""' ")"
            }
            if "$TABTOOLS_FONTSIZE" != "" {
                file write `fh' " fontsize($TABTOOLS_FONTSIZE)"
            }
            if "$TABTOOLS_HEADERCOLOR" != "" {
                file write `fh' " headercolor(" `"""' "$TABTOOLS_HEADERCOLOR" `"""' ")"
            }
            if "$TABTOOLS_ZEBRACOLOR" != "" {
                file write `fh' " zebracolor(" `"""' "$TABTOOLS_ZEBRACOLOR" `"""' ")"
            }
            if "$TABTOOLS_BORDER" != "" {
                file write `fh' " borderstyle($TABTOOLS_BORDER)"
            }
            file write `fh' _n
        }
        else if "$TABTOOLS_THEME" != "" {
            file write `fh' "tabtools set theme $TABTOOLS_THEME" _n
        }
        else {
            if "$TABTOOLS_FONT" != "" {
                file write `fh' "tabtools set font " `"""' "$TABTOOLS_FONT" `"""' _n
            }
            if "$TABTOOLS_FONTSIZE" != "" {
                file write `fh' "tabtools set fontsize $TABTOOLS_FONTSIZE" _n
            }
            if "$TABTOOLS_BORDER" != "" {
                file write `fh' "tabtools set borderstyle $TABTOOLS_BORDER" _n
            }
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
    version 16.0
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
        quietly do `"`profile'"'
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end

* Subroutine for detailed display
capture program drop _tabtools_detail
program define _tabtools_detail, nclass
    version 16.0
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
            display as result "  desctab" as text "      Format an active table collect with per-statistic"
            display as text "               number formats and optional composite cells such"
            display as text "               as events / N (%)."
            display as text ""
            display as result "  crosstab" as text "     Cross-tabulation with row/column percentages"
            display as text "               and association measures. Supports chi-square,"
            display as text "               Fisher's exact, odds ratios, and risk ratios."
            display as text ""
            display as result "  corrtab" as text "      Correlation matrix with significance stars or"
            display as text "               p-values. Supports Pearson and Spearman. Exports"
            display as text "               lower, upper, or full triangle to Excel."
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
        }

        if inlist("`category'", "all", "rates") {
            display as text "{bf:Incidence Rates}"
            display as text "  {hline 60}"
            display as result "  stratetab" as text "    Export stratified incidence rates from strate"
            display as text "               command output. Formats person-time, events,"
            display as text "               rates, and confidence intervals. Supports"
            display as text "               rate ratios and stratified analyses."
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

        if inlist("`category'", "all", "diagnostics") {
            display as text "{bf:Diagnostic Accuracy}"
            display as text "  {hline 60}"
            display as result "  diagtab" as text "      Export sensitivity, specificity, PPV, NPV, and"
            display as text "               ROC analysis results. Supports multiple cutpoints"
            display as text "               and diagnostic tests."
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

        if inlist("`category'", "all", "simulation") {
            display as text "{bf:Simulation Studies}"
            display as text "  {hline 60}"
            display as result "  simtab" as text "       Render and export a Monte Carlo simulation"
            display as text "               performance table (bias, empirical/model SE,"
            display as text "               coverage, ...) from replication-level results,"
            display as text "               or ingest a simsum/siman summary. Pairs with"
            display as text "               simsum and siman for full analysis and graphs."
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
