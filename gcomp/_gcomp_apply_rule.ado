*! _gcomp_apply_rule Version 2.0.3  2026/10/09
*! Execute validated intervention/derived assignment rules without false success
*! Author: Timothy P Copeland, Karolinska Institutet

capture program drop _gcomp_apply_rule
program define _gcomp_apply_rule
    version 16.0
    syntax, RULE(string) [CONDITION(string) CONTEXT(string)]

    local _gc_rule `"`macval(rule)'"'
    local _gc_condition `"`macval(condition)'"'
    capture quietly replace `macval(_gc_rule)' `macval(_gc_condition)'
    local _gc_rule_rc = _rc

    * Combine the actual top-level qualifier, skipping literal/function text.
    if `_gc_rule_rc' & `"`macval(_gc_condition)'"'!="" {
        _gcomp_split_interventions, text(`"`macval(_gc_rule)'"') prefix(_gc_qual)
        if `_gc_qualifpos'>0 {
            local _gc_extra = strtrim(subinstr(`"`macval(_gc_condition)'"', "if ", "", 1))
            mata: st_local("_gc_combined",substr(st_local("_gc_rule"),1,strtoreal(st_local("_gc_qualifpos"))-1)+"if ("+substr(st_local("_gc_rule"),strtoreal(st_local("_gc_qualifpos"))+2,.)+") & ("+st_local("_gc_extra")+")")
            capture quietly replace `macval(_gc_combined)'
            local _gc_rule_rc = _rc
        }
    }

    if `_gc_rule_rc' {
        if `"`context'"'=="" local context "assignment rule"
        noisily display as error `"`context' failed: `macval(_gc_rule)'"'
        exit `_gc_rule_rc'
    }
end
