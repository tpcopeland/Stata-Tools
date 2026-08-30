*! _setools_pira_rebase Version 1.5.7  2026/08/30
*! setools internal: forward relapse-driven PIRA rebaselining
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _setools_pira_rebase, nclass
    version 16.0
    local _varabbrev `c(varabbrev)'
    set varabbrev off

    capture noisily {
        syntax varlist(min=2 max=2 numeric), NEWid(varname) ///
            ISVisit(varname) BASEedss(varname) BASEdate(varname)

        tokenize `varlist'
        local datevar `1'
        local edssvar `2'

        mata: _setools_pira_rebase_mata("`newid'", "`isvisit'", ///
            "`datevar'", "`edssvar'", "`baseedss'", "`basedate'")
    }
    local rc = _rc
    set varabbrev `_varabbrev'
    if `rc' exit `rc'
end

capture mata: mata drop _setools_pira_rebase_mata()

mata:
mata set matastrict on

void _setools_pira_rebase_mata(
    string scalar newid_var,
    string scalar isvisit_var,
    string scalar date_var,
    string scalar edss_var,
    string scalar baseedss_var,
    string scalar basedate_var)
{
    real matrix input, output
    real scalar i, n, current_edss, current_date, pending_relapse

    input = st_data(., tokens(newid_var + " " + isvisit_var + " " +
        date_var + " " + edss_var))
    output = st_data(., tokens(baseedss_var + " " + basedate_var))
    n = rows(input)

    current_edss = .
    current_date = .
    pending_relapse = .

    for (i = 1; i <= n; i++) {
        if (input[i, 1]) {
            current_edss = output[i, 1]
            current_date = output[i, 2]
            pending_relapse = .
        }

        if (input[i, 2] == 0) {
            if (!missing(input[i, 3]) & input[i, 3] > current_date) {
                pending_relapse = input[i, 3]
            }
        }
        else {
            if (!missing(pending_relapse) &
                input[i, 3] >= pending_relapse + 30) {
                current_edss = input[i, 4]
                current_date = input[i, 3]
                pending_relapse = .
            }
            output[i, 1] = current_edss
            output[i, 2] = current_date
        }
    }

    st_store(., tokens(baseedss_var + " " + basedate_var), output)
}

end
