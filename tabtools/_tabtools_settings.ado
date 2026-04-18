*! _tabtools_settings Version 1.0.7  2026/04/18
*! Central settings resolution for tabtools
*! Author: Timothy P Copeland

capture program drop _tabtools_settings
program define _tabtools_settings, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken _tt_subcmd _tt_rest : 0, parse(",")
        local _tt_subcmd = lower(strtrim(subinstr("`_tt_subcmd'", ",", "", .)))

        if "`_tt_subcmd'" == "" | "`_tt_subcmd'" == "resolve" {
            if "`_tt_subcmd'" == "" {
                _tabtools_settings_resolve `0'
            }
            else {
                _tabtools_settings_resolve `_tt_rest'
            }
        }
        else {
            display as error "_tabtools_settings supports resolve"
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _tabtools_settings_resolve
program define _tabtools_settings_resolve, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [, FONT(string) FONTSIZE(integer -1) THEme(string) ///
            BORDERstyle(string) HEADERColor(string) ZEBRAColor(string) ///
            HEADERShade ZEBra DIGits(integer -1) BOLDP(real -1) ///
            HIGHLIGHT(real -1) PDP(integer -1) HIGHPDP(integer -1) ]

        local _font "Arial"
        local _fontsize = 10
        local _borderstyle "thin"
        local _headercolor "219 229 241"
        local _zebracolor "237 242 249"
        local _headershade ""
        local _zebra ""
        local _digits = 2
        local _boldp = .
        local _highlight = .
        local _pdp = 3
        local _highpdp = 2

        if "$TABTOOLS_FONT" != "" local _font "$TABTOOLS_FONT"
        if "$TABTOOLS_FONTSIZE" != "" local _fontsize = $TABTOOLS_FONTSIZE
        if "$TABTOOLS_BORDER" != "" local _borderstyle "$TABTOOLS_BORDER"
        if "$TABTOOLS_HEADERCOLOR" != "" local _headercolor "$TABTOOLS_HEADERCOLOR"
        if "$TABTOOLS_ZEBRACOLOR" != "" local _zebracolor "$TABTOOLS_ZEBRACOLOR"
        if "$TABTOOLS_DIGITS" != "" local _digits = $TABTOOLS_DIGITS
        if "$TABTOOLS_BOLDP" != "" local _boldp = $TABTOOLS_BOLDP

        if "`theme'" == "" & "$TABTOOLS_THEME" != "" {
            local theme "$TABTOOLS_THEME"
        }

        if "`theme'" != "" {
            _tabtools_settings_theme "`theme'"
            local _font "`_tt_theme_font'"
            local _fontsize = `_tt_theme_fontsize'
            local _borderstyle "`_tt_theme_border'"
            local _headershade = cond("`_tt_theme_headershade'" == "1", "headershade", "")
            local _zebra = cond("`_tt_theme_zebra'" == "1", "zebra", "")
            if "`_tt_theme_headercolor'" != "" local _headercolor "`_tt_theme_headercolor'"
            if "`_tt_theme_zebracolor'" != "" local _zebracolor "`_tt_theme_zebracolor'"
        }

        if "`font'" != "" local _font "`font'"
        if `fontsize' != -1 local _fontsize = `fontsize'
        if "`borderstyle'" != "" local _borderstyle "`borderstyle'"
        if "`headercolor'" != "" local _headercolor "`headercolor'"
        if "`zebracolor'" != "" local _zebracolor "`zebracolor'"
        if "`headershade'" != "" local _headershade "headershade"
        if "`zebra'" != "" local _zebra "zebra"
        if `digits' != -1 local _digits = `digits'
        if `boldp' != -1 local _boldp = `boldp'
        if `highlight' != -1 local _highlight = `highlight'
        if `pdp' != -1 local _pdp = `pdp'
        if `highpdp' != -1 local _highpdp = `highpdp'

        local _borderstyle = lower(strtrim("`_borderstyle'"))
        if "`_borderstyle'" == "default" local _borderstyle "thin"

        if !inlist("`_borderstyle'", "thin", "medium", "academic") {
            display as error "borderstyle() must be thin, medium, or academic"
            exit 198
        }
        if `_fontsize' < 6 | `_fontsize' > 72 {
            display as error "fontsize() must be between 6 and 72"
            exit 198
        }
        if `_digits' < 0 | `_digits' > 10 {
            display as error "digits() must be between 0 and 10"
            exit 198
        }
        if !missing(`_boldp') & (`_boldp' <= 0 | `_boldp' >= 1) {
            display as error "boldp() must be between 0 and 1"
            exit 198
        }
        if !missing(`_highlight') & (`_highlight' <= 0 | `_highlight' >= 1) {
            display as error "highlight() must be between 0 and 1"
            exit 198
        }
        if `_pdp' < 0 | `_pdp' > 10 {
            display as error "pdp() must be between 0 and 10"
            exit 198
        }
        if `_highpdp' < 0 | `_highpdp' > 10 {
            display as error "highpdp() must be between 0 and 10"
            exit 198
        }

        _ttset_normcolor `"`_headercolor'"'
        local _headercolor "`_tt_color'"
        _ttset_normcolor `"`_zebracolor'"'
        local _zebracolor "`_tt_color'"

        local _hborder = cond("`_borderstyle'" == "academic", "medium", "`_borderstyle'")

        c_local _font "`_font'"
        c_local _fontsize `_fontsize'
        c_local _borderstyle "`_borderstyle'"
        c_local _hborder "`_hborder'"
        c_local _headercolor "`_headercolor'"
        c_local _zebracolor "`_zebracolor'"
        c_local _headershade "`_headershade'"
        c_local _zebra "`_zebra'"
        c_local _digits `_digits'
        c_local _boldp "`_boldp'"
        c_local _highlight "`_highlight'"
        c_local _pdp `_pdp'
        c_local _highpdp `_highpdp'

        global TABTOOLS_RS_FONT "`_font'"
        global TABTOOLS_RS_FONTSIZE `_fontsize'
        global TABTOOLS_RS_BORDERSTYLE "`_borderstyle'"
        global TABTOOLS_RS_HBORDER "`_hborder'"
        global TABTOOLS_RS_HEADERCOLOR "`_headercolor'"
        global TABTOOLS_RS_ZEBRACOLOR "`_zebracolor'"
        global TABTOOLS_RS_HEADERSHADE "`_headershade'"
        global TABTOOLS_RS_ZEBRA "`_zebra'"
        global TABTOOLS_RS_DIGITS `_digits'
        global TABTOOLS_RS_BOLDP "`_boldp'"
        global TABTOOLS_RS_HIGHLIGHT "`_highlight'"
        global TABTOOLS_RS_PDP `_pdp'
        global TABTOOLS_RS_HIGHPDP `_highpdp'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _tabtools_settings_theme
program define _tabtools_settings_theme, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args _tt_theme

        local _tt_theme = lower(strtrim("`_tt_theme'"))
        local _tt_theme_font "Arial"
        local _tt_theme_fontsize 10
        local _tt_theme_border "thin"
        local _tt_theme_headershade 0
        local _tt_theme_headercolor ""
        local _tt_theme_zebra 0
        local _tt_theme_zebracolor ""

        if "`_tt_theme'" == "lancet" {
            local _tt_theme_fontsize 9
            local _tt_theme_border "academic"
        }
        else if "`_tt_theme'" == "nejm" {
            local _tt_theme_border "academic"
            local _tt_theme_zebra 1
        }
        else if "`_tt_theme'" == "bmj" {
            local _tt_theme_border "academic"
        }
        else if "`_tt_theme'" == "apa" {
            local _tt_theme_font "Times New Roman"
            local _tt_theme_fontsize 12
            local _tt_theme_border "academic"
        }
        else if "`_tt_theme'" == "jama" {
            local _tt_theme_border "academic"
        }
        else if inlist("`_tt_theme'", "plos") {
            local _tt_theme_border "thin"
        }
        else if inlist("`_tt_theme'", "nature") {
            local _tt_theme_fontsize 9
            local _tt_theme_border "academic"
        }
        else if inlist("`_tt_theme'", "cell", "annals") {
            local _tt_theme_border "academic"
        }
        else if "`_tt_theme'" == "custom" {
            if "$TABTOOLS_FONT" != "" local _tt_theme_font "$TABTOOLS_FONT"
            if "$TABTOOLS_FONTSIZE" != "" local _tt_theme_fontsize = $TABTOOLS_FONTSIZE
            if "$TABTOOLS_BORDER" != "" local _tt_theme_border "$TABTOOLS_BORDER"
            if "$TABTOOLS_HEADERCOLOR" != "" {
                local _tt_theme_headershade 1
                local _tt_theme_headercolor "$TABTOOLS_HEADERCOLOR"
            }
            if "$TABTOOLS_ZEBRACOLOR" != "" {
                local _tt_theme_zebra 1
                local _tt_theme_zebracolor "$TABTOOLS_ZEBRACOLOR"
            }
        }
        else {
            display as error "Unknown theme: `_tt_theme'"
            exit 198
        }

        c_local _tt_theme_font "`_tt_theme_font'"
        c_local _tt_theme_fontsize `_tt_theme_fontsize'
        c_local _tt_theme_border "`_tt_theme_border'"
        c_local _tt_theme_headershade `_tt_theme_headershade'
        c_local _tt_theme_headercolor "`_tt_theme_headercolor'"
        c_local _tt_theme_zebra `_tt_theme_zebra'
        c_local _tt_theme_zebracolor "`_tt_theme_zebracolor'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _ttset_normcolor
program define _ttset_normcolor, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args _tt_color

        local _tt_color = subinstr(`"`_tt_color'"', char(34), "", .)
        local _tt_color = strtrim(itrim(`"`_tt_color'"'))
        c_local _tt_color "`_tt_color'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
