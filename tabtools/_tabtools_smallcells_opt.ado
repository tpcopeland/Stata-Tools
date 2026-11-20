*! _tabtools_smallcells_opt Version 1.2.0  2026/11/19
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

    _tabtools_smallcells_opt __empty <the caller's own `0'>

    A string option cannot tell smallcells() from an absent option, so an
    empty smallcells() (for example smallcells(`k') with k undefined) would
    fall through to the session default or to no masking at rc 0. A caller
    whose smallcells is empty after -syntax- passes its own command line
    here; an option token smallc[ells]() holding only blanks is refused with
    r(198). Tokens are read with gettoken bind, so text inside another
    option (title("... smallcells() ...")) is never matched. This mode sets
    nothing in the caller.
*/

program define _tabtools_smallcells_opt, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _k ""
    local _mode ""
    local _chkmode 0
    gettoken _first _chkrest : 0, parse(" ,")
    mata: st_local("_chkmode", strofreal(st_local("_first") == "__empty"))
    capture noisily {
      if `_chkmode' {
        * The caller's line may hold any text (a backquote before a double
        * quote opens a compound quote), so it is never expanded inside
        * quotes here: the loop tests its length and Mata reads the token.
        while `: length local _chkrest' {
            gettoken _tok _chkrest : _chkrest, parse(" ,") bind quotes
            local _onm ""
            mata: st_local("_onm", regexm(st_local("_tok"), "^([a-z]+)[(][ ]*[)]$") ? regexs(1) : "")
            if "`_onm'" != "" {
                if strlen("`_onm'") >= 6 & strpos("smallcells", "`_onm'") == 1 {
                    display as error "smallcells() is empty; it must hold an integer of 3 or more (smallcells(#) or smallcells(#, primary)); use nosmallcells for no masking"
                    exit 198
                }
            }
        }
      }
      else {
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
            * the number, not its spelling: a global written directly as +5
            * or 05 still prints <5
            local _k = `_k'
            local _mode = cond(`"$TABTOOLS_set_smallcells_mode"' == "primary", "primary", "full")
            local _echo "smallcells(`_k')"
            if "`_mode'" == "primary" local _echo "smallcells(`_k', primary)"
            display as text "(tabtools: using session `_echo')"
        }
      }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_chkmode' {
        if `rc' exit `rc'
        exit
    }
    if `rc' {
        c_local _sc_k ""
        c_local _sc_mode ""
        exit `rc'
    }
    c_local _sc_k `"`_k'"'
    c_local _sc_mode `"`_mode'"'
end
