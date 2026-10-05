*! _tabtools_smallcells_opt Version 2.3.0  2026/10/05
*! Resolve smallcells(# [, primary]), nosmallcells, and the session default
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

/*
    _tabtools_smallcells_opt , [smallcells(string) nosmallcells]

    Resolves the disclosure threshold for one call of desctab, table1_tc or
    crosstab. Precedence: an explicit smallcells() > nosmallcells (no
    masking) > the session default set by -tabtools set smallcells #
    [primary]- > none.

    Sets in the caller (every exit path assigns both):
        _sc_k      the threshold, or empty when no masking applies
        _sc_mode   "full" (complementary cells, the default) or "primary"

    When the session default is used, one line naming it is printed, so the
    hidden state is visible in the log.
*/

program define _tabtools_smallcells_opt, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _k ""
    local _mode ""
    capture noisily {
        syntax , [SMALLCells(string asis) NOSMALLCells]

        local _raw = strtrim(`"`smallcells'"')
        if `"`_raw'"' != "" & "`nosmallcells'" != "" {
            display as error "smallcells() and nosmallcells may not be combined"
            exit 198
        }
        if `"`_raw'"' != "" {
            * "#" or "#, primary": peel the number, then parse the suboption.
            gettoken _num _rest : _raw, parse(",")
            local _num = strtrim(`"`_num'"')
            local _rest = strtrim(`"`_rest'"')
            local _sub ""
            if `"`_rest'"' != "" {
                if substr(`"`_rest'"', 1, 1) != "," {
                    display as error "smallcells() must be # or #, primary"
                    exit 198
                }
                local _sub = strtrim(substr(`"`_rest'"', 2, .))
                if lower(`"`_sub'"') != "primary" {
                    display as error `"smallcells(): unknown suboption `_sub'; the only suboption is primary"'
                    exit 198
                }
            }
            capture confirm integer number `_num'
            if _rc {
                display as error "smallcells() must be an integer greater than or equal to 3"
                exit 198
            }
            if `_num' < 3 {
                display as error "smallcells() must be an integer greater than or equal to 3"
                exit 198
            }
            local _k = `_num'
            local _mode = cond(`"`_sub'"' != "", "primary", "full")
        }
        else if "`nosmallcells'" == "" & `"$TABTOOLS_set_smallcells"' != "" {
            local _k `"$TABTOOLS_set_smallcells"'
            capture confirm integer number `_k'
            if _rc | `"`_k'"' == "" {
                display as error "session smallcells default is not an integer; reset it with tabtools set smallcells #"
                exit 198
            }
            if `_k' < 3 {
                display as error "session smallcells default must be 3 or more; reset it with tabtools set smallcells #"
                exit 198
            }
            local _mode = cond(`"$TABTOOLS_set_smallcells_mode"' == "primary", "primary", "full")
            local _echo "smallcells(`_k')"
            if "`_mode'" == "primary" local _echo "smallcells(`_k', primary)"
            display as text "(tabtools: using session `_echo')"
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' {
        c_local _sc_k ""
        c_local _sc_mode ""
        exit `rc'
    }
    c_local _sc_k `"`_k'"'
    c_local _sc_mode `"`_mode'"'
end
