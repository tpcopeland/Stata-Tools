*! _codescan_hierarchy Version 1.1.1  2026/05/28
*! Private hierarchy helpers for codescan
*! Author: Timothy P Copeland

program define _codescan_check_hierarchy_syntax
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , [HIERarchy(string asis) COLLapse MERge]
    local hierarchy = subinstr(`"`macval(hierarchy)'"', char(5), char(92), .)

    if `"`hierarchy'"' != "" {
        if "`collapse'" == "" & "`merge'" == "" {
            display as error "hierarchy() requires collapse or merge"
            exit 198
        }
        * Check each pair has a > separator
        local _hcheck_str `"`hierarchy'"'
        while `"`_hcheck_str'"' != "" {
            local _hbs = strpos(`"`_hcheck_str'"', char(92))
            if `_hbs' > 0 {
                local _hchk_pair = substr(`"`_hcheck_str'"', 1, `_hbs' - 1)
                local _hcheck_str = substr(`"`_hcheck_str'"', `_hbs' + 1, .)
            }
            else {
                local _hchk_pair `"`_hcheck_str'"'
                local _hcheck_str ""
            }
            local _hchk_pair = strtrim(`"`_hchk_pair'"')
            if `"`_hchk_pair'"' == "" continue
            if !strpos(`"`_hchk_pair'"', ">") {
                display as error "hierarchy(): each pair must use {bf:>} syntax: superior_name {bf:>} inferior_name"
                exit 198
            }
        }
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _codescan_parse_hierarchy, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , HIERarchy(string asis) NCONDITIONS(integer) NAMES(string asis) [GENerate(string)]
    local hierarchy = subinstr(`"`macval(hierarchy)'"', char(5), char(92), .)

    local _names `"`names'"'
    if strlen(`"`_names'"') >= 2 {
        if substr(`"`_names'"', 1, 1) == char(34) & ///
            substr(`"`_names'"', strlen(`"`_names'"'), 1) == char(34) {
            local _names = substr(`"`_names'"', 2, strlen(`"`_names'"') - 2)
        }
    }

    local _n_hier_pairs = 0
    local _hier_str `"`hierarchy'"'
    while `"`_hier_str'"' != "" {
        local _hbs = strpos(`"`_hier_str'"', char(92))
        if `_hbs' > 0 {
            local _hpair = substr(`"`_hier_str'"', 1, `_hbs' - 1)
            local _hier_str = substr(`"`_hier_str'"', `_hbs' + 1, .)
        }
        else {
            local _hpair `"`_hier_str'"'
            local _hier_str ""
        }
        local _hpair = strtrim(`"`_hpair'"')
        if `"`_hpair'"' == "" continue
        local _n_hier_pairs = `_n_hier_pairs' + 1

        * Split on >
        gettoken _hsup _hinf : _hpair, parse(">")
        local _hsup = strtrim(`"`_hsup'"')
        local _hinf = strtrim(subinstr(`"`_hinf'"', ">", "", 1))

        * Resolve hierarchy names by membership: exact match first, then
        * generated-prefix fallback for bare names.
        local _hsup_full "`_hsup'"
        local _hinf_full "`_hinf'"
        local _hfound_sup = 0
        local _hfound_inf = 0
        forvalues i = 1/`nconditions' {
            local _hname : word `i' of `_names'
            if "`_hname'" == "`_hsup_full'" local _hfound_sup = 1
            if "`_hname'" == "`_hinf_full'" local _hfound_inf = 1
        }
        if "`generate'" != "" {
            if !`_hfound_sup' {
                local _hsup_pref "`generate'`_hsup'"
                forvalues i = 1/`nconditions' {
                    local _hname : word `i' of `_names'
                    if "`_hname'" == "`_hsup_pref'" {
                        local _hfound_sup = 1
                        local _hsup_full "`_hsup_pref'"
                    }
                }
            }
            if !`_hfound_inf' {
                local _hinf_pref "`generate'`_hinf'"
                forvalues i = 1/`nconditions' {
                    local _hname : word `i' of `_names'
                    if "`_hname'" == "`_hinf_pref'" {
                        local _hfound_inf = 1
                        local _hinf_full "`_hinf_pref'"
                    }
                }
            }
        }
        if !`_hfound_sup' {
            display as error "hierarchy(): `_hsup' is not a defined condition name"
            exit 198
        }
        if !`_hfound_inf' {
            display as error "hierarchy(): `_hinf' is not a defined condition name"
            exit 198
        }

        local _hier_sup_`_n_hier_pairs' "`_hsup_full'"
        local _hier_inf_`_n_hier_pairs' "`_hinf_full'"
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar n_hier_pairs = `_n_hier_pairs'
    forvalues i = 1/`_n_hier_pairs' {
        return local hier_sup_`i' "`_hier_sup_`i''"
        return local hier_inf_`i' "`_hier_inf_`i''"
    }
end

program define _codescan_apply_hierarchy
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , NHIERPAIRS(integer) SUPS(string asis) INFS(string asis) [COUNTMode NOIsily]

    local _sups `"`sups'"'
    if strlen(`"`_sups'"') >= 2 {
        if substr(`"`_sups'"', 1, 1) == char(34) & ///
            substr(`"`_sups'"', strlen(`"`_sups'"'), 1) == char(34) {
            local _sups = substr(`"`_sups'"', 2, strlen(`"`_sups'"') - 2)
        }
    }
    local _infs `"`infs'"'
    if strlen(`"`_infs'"') >= 2 {
        if substr(`"`_infs'"', 1, 1) == char(34) & ///
            substr(`"`_infs'"', strlen(`"`_infs'"'), 1) == char(34) {
            local _infs = substr(`"`_infs'"', 2, strlen(`"`_infs'"') - 2)
        }
    }
    local _n_sups : word count `_sups'
    local _n_infs : word count `_infs'
    if `nhierpairs' != `_n_sups' | `nhierpairs' != `_n_infs' {
        display as error "_codescan_apply_hierarchy: pair count does not match supplied names"
        exit 198
    }

    quietly {
        forvalues _hp = 1/`nhierpairs' {
            local _h_sup : word `_hp' of `_sups'
            local _h_inf : word `_hp' of `_infs'
            if "`countmode'" != "" {
                replace `_h_inf' = 0 if `_h_sup' > 0 & !missing(`_h_sup')
            }
            else {
                replace `_h_inf' = 0 if `_h_sup' == 1
            }
        }
    }
    if "`noisily'" != "" {
        noisily display as text "  (hierarchy: `nhierpairs' rule(s) applied)"
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
