*! _gcomp_apply_rule Version 1.4.5  2026/07/13
*! Execute validated intervention/derived assignment rules without false success
*! Author: Timothy P Copeland, Karolinska Institutet

capture program drop _gcomp_apply_rule
program define _gcomp_apply_rule
    version 16.0
    syntax, RULE(string) [CONDITION(string) CONTEXT(string)]

    local _gc_rule `"`rule'"'
    local _gc_condition `"`condition'"'
    capture quietly replace `_gc_rule' `_gc_condition'
    local _gc_rule_rc = _rc

    * Combine an embedded if qualifier with the engine's additional qualifier.
    if `_gc_rule_rc' & `"`_gc_condition'"'!="" & ///
            strpos(lower(`" `_gc_rule' "'), " if ") {
        local _gc_extra = strtrim(subinstr(`"`_gc_condition'"', "if ", "", 1))
        local _gc_combined = subinword(`"`_gc_rule'"', "if", "if (", 1) + ///
            `" ) & (`_gc_extra')"'
        capture quietly replace `_gc_combined'
        local _gc_rule_rc = _rc
    }

    if `_gc_rule_rc' {
        if `"`context'"'=="" local context "assignment rule"
        noisily display as error `"`context' failed: `_gc_rule'"'
        exit `_gc_rule_rc'
    }
end
