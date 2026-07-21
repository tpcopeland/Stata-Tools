*! _iivw_check_passthru Version 2.0.1  2026/07/21
*! Reject variance/resampling tokens in a pass-through option string
*! (geeopts(), mixedopts()).  Part of iivw.
*! Author: Timothy P Copeland, Karolinska Institutet
*
* iivw selects the variance method deterministically (vce(fixed) or the refit
* bootstrap) and OWNS it. A pass-through option that reaches the inner glm/mixed
* and specifies its own vce()/robust/cluster() would either error or, worse,
* silently substitute a different covariance under the label iivw reports
* (IIVW-B08). This guard is the pre-call half of that defense; the post-fit
* variance lock in iivw_fit is the other half.
*
* It rejects, case-insensitively and across spaces/tabs/quotes/nested parens:
*   - any vce(...) specification
*   - a bare robust and every abbreviation r, ro, rob, robu, robus
*   - cluster(...) and every abbreviation cl(, clu(, clus(, clust(, cluste(
*
* Usage:
*   _iivw_check_passthru, optname(geeopts)  value(`"`geeopts'"')
*   _iivw_check_passthru, optname(mixedopts) value(`"`mixedopts'"')

program define _iivw_check_passthru
    version 16.0
    syntax , OPTname(string) [VALue(string)]

    if `"`value'"' == "" exit

    * Normalize: lowercase; tabs and quote characters -> spaces; collapse runs
    * of whitespace so token boundaries are single spaces; pad with spaces so a
    * leading/trailing token still has a boundary on both sides.
    local v = lower(`"`value'"')
    local v = subinstr(`"`v'"', char(9), " ", .)
    local v = subinstr(`"`v'"', char(34), " ", .)
    local v = subinstr(`"`v'"', char(96), " ", .)
    local v = subinstr(`"`v'"', "'", " ", .)
    while strpos(`"`v'"', "  ") {
        local v = subinstr(`"`v'"', "  ", " ", .)
    }
    local v = " " + strtrim(`"`v'"') + " "

    local bad ""
    * vce(...) in any spacing form
    if regexm(`"`v'"', "vce *\(")                          local bad "vce()"
    * cluster() and its abbreviations, followed by a paren
    else if regexm(`"`v'"', " cl(u(s(t(e(r)?)?)?)?)? *\(") local bad "cluster()"
    * bare robust and its abbreviations, as a standalone token
    else if regexm(`"`v'"', " r(o(b(u(s(t)?)?)?)?)? ")      local bad "robust"

    if "`bad'" != "" {
        display as error "`optname'() may not set the variance estimator"
        display as error "  found `bad' in `optname'(`value')"
        display as error "  iivw owns the variance: use vce(fixed) or the refit"
        display as error "  bootstrap, not an inner `optname'() override"
        error 198
    }
end
