*! _iivw_own Version 2.0.0  2026/07/14
*! Stamp variable-level ownership on a package output, and read it back.
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

* Why this exists
* ---------------
* Before this, `replace' decided what it was allowed to destroy by looking at a
* NAME: _iivw_reserve_names reasoned that a variable called `_iivw_weight' which
* is not a current input must be a prior package output, so overwriting it is
* what the user asked for. Nothing established that. A user variable that
* happens to sit under the selected prefix -- a hand-built `_iivw_weight' from a
* previous project, an imported column, a merge artefact -- was backed up and
* silently discarded on success.
*
* Ownership is now a fact carried BY THE VARIABLE, not inferred from its name.
* A single characteristic holds the whole claim:
*
*     char v[_iivw_owner] = "iivw|<prefix>|<role>|<contract>"
*
* and `replace' overwrites v only when that token equals the token the current
* call intends to write. Owner, prefix, role, and contract version must all
* match; anything else -- an unstamped variable, a different role, an older
* contract -- errors before any data is touched.
*
* The prefix field is deliberately EMPTY for lagged covariates. Their names come
* from the source variable (`edss_lag1'), not from generate(), and both
* iivw_weight and iivw_exogtest legitimately build the same column. Keying them
* on prefix would make one command refuse to reuse the other's lag.

program define _iivw_own, rclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    * parse(" ,") is required. gettoken's default parse set is blanks ONLY, so
    * `_iivw_own token, role(iw)' would hand back the subcommand as `token,'
    * -- comma attached -- and every dispatch below would miss.
    gettoken __iivw_sub 0 : 0, parse(" ,")

    if !inlist("`__iivw_sub'", "stamp", "token", "read") {
        display as error "_iivw_own: subcommand must be stamp, token, or read"
        error 198
    }

    * ---------------------------------------------------------------------
    * token: build the ownership token for a role, without touching data.
    * Callers use this to tell _iivw_reserve_names what they INTEND to write,
    * so the check and the stamp cannot drift apart.
    * ---------------------------------------------------------------------
    if "`__iivw_sub'" == "token" {
        syntax , ROLE(string) [PREFix(string)]
        if "`role'" == "lag" local prefix ""
        return local token "iivw|`prefix'|`role'|2"
        exit
    }

    * ---------------------------------------------------------------------
    * read: return the token a variable currently carries (empty if unowned).
    * ---------------------------------------------------------------------
    if "`__iivw_sub'" == "read" {
        syntax varname
        local __iivw_tok : char `varlist'[_iivw_owner]
        return local token "`__iivw_tok'"
        exit
    }

    * ---------------------------------------------------------------------
    * stamp: claim ownership of every variable in varlist for one role.
    * ---------------------------------------------------------------------
    syntax varlist , ROLE(string) [PREFix(string)]
    if "`role'" == "lag" local prefix ""

    foreach __iivw_v of local varlist {
        char `__iivw_v'[_iivw_owner] "iivw|`prefix'|`role'|2"
    }
    return local token "iivw|`prefix'|`role'|2"

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
