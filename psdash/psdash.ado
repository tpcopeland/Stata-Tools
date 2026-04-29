*! psdash Version 1.0.0  2026/04/29
*! Propensity score diagnostics dashboard
*! Author: Timothy P Copeland
*! Program class: rclass

/*
Router for psdash package.

Syntax:
  psdash                                              - Show overview
  psdash overlap [treatment] [psvar] [, options]      - PS overlap density plots
  psdash balance [treatment] [psvar] [, options]      - SMD balance table + Love plot
  psdash weights [treatment] [psvar] [, options]      - Weight diagnostics (ESS, CV)
  psdash support [treatment] [psvar] [, options]      - Common support assessment
  psdash combined [treatment] [psvar] [, options]     - All diagnostics combined
*/

program define psdash, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {

        gettoken subcmd 0 : 0, parse(" ,")

        if "`subcmd'" == "" | "`subcmd'" == "," {
            _psdash_overview
            exit
        }

        local known_subcmds "overlap balance weights support combined"

        local is_subcmd = 0
        foreach s of local known_subcmds {
            if "`subcmd'" == "`s'" local is_subcmd = 1
        }

        if `is_subcmd' {
            psdash_`subcmd' `0'
        }
        else {
            display as error "unknown psdash subcommand: `subcmd'"
            display as error "valid subcommands: `known_subcmds'"
            exit 198
        }

        return add
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end


capture program drop _psdash_overview
program define _psdash_overview
    version 16.0

    display as result "psdash" as text " - Propensity Score Diagnostics Dashboard"
    display as text ""
    display as text "Usage:"
    display as text "  {cmd:psdash} {it:subcmd} [{it:treatment}] [{it:psvar}] [{cmd:,} {it:options}]"
    display as text "  After {cmd:teffects}, treatment and PS are auto-detected."
    display as text ""
    display as text "Subcommands:"
    display as text "  {cmd:psdash overlap}    PS density/histogram by treatment group"
    display as text "  {cmd:psdash balance}    SMD balance table with Love plot"
    display as text "  {cmd:psdash weights}    Weight distribution, ESS, extreme weights"
    display as text "  {cmd:psdash support}    Common support assessment and trimming"
    display as text "  {cmd:psdash combined}   All diagnostics in a combined dashboard"
    display as text ""
    display as text "Examples:"
    display as text "  {cmd:teffects ipw (y) (treat x1 x2 x3)}"
    display as text "  {cmd:psdash combined}"
    display as text ""
    display as text "  {cmd:logit treat x1 x2 x3}"
    display as text "  {cmd:predict ps, pr}"
    display as text "  {cmd:psdash overlap treat ps}"
    display as text ""
    display as text "Type {cmd:help psdash} for full documentation."
end
