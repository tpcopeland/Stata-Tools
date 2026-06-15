*! _setools_cdp_thresh Version 1.4.0  2026/06/15
*! setools internal: EDSS progression threshold column from baseline EDSS
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* Single source of truth for the EDSS progression-threshold rule shared by
* cdp and pira (both the iterative engine and the roving baseline path). The
* `varname' argument is the per-row baseline EDSS column; generate() names the
* per-row threshold column to create.
*
* Two-tier (default, backward compatible): >=1.0 if baseline <=5.5, else >=0.5.
* Three-tier (Lublin 2014 / Kappos consensus): >=1.5 if baseline 0,
*   >=1.0 if baseline 1.0-5.5, >=0.5 if baseline >5.5.

program define _setools_cdp_thresh, nclass
    version 16.0
    syntax varname, GENerate(name) [THREEtier]

    if "`threetier'" != "" {
        qui gen double `generate' = cond(`varlist' == 0, 1.5, ///
            cond(`varlist' <= 5.5, 1.0, 0.5))
    }
    else {
        qui gen double `generate' = cond(`varlist' <= 5.5, 1.0, 0.5)
    }
end
