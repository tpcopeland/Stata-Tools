*! _regtab_relabel Version 2.5.6  2026/10/07
*! regtab block: relabel random-effects rows (relabel)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_relabel" from inside its quietly block and the body is quietly
* again, so only the block's own noisily lines print. Data in memory, frames,
* and the collection are shared state and need no transport.
program define _regtab_relabel, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
* Relabel random effects if requested
if "`relabel'" != "" {
    if "`re_groupvars'" != "" & "`re_groupvars'" != "." {

        * --- Per-level relabeling (bracket notation) ---
        * Handles multi-level mixed (flattened) and melogit/mepoisson (native)
        forvalues _lev = 1/`_n_re_levels' {
            local _gvar `"`re_groupvar_`_lev''"'
            local _glbl : copy local re_grouplbl_`_lev'

            * Random intercept: var(_cons[groupvar]) -> "Variance: GroupLabel (Intercept)"
            replace A = `"Variance: `macval(_glbl)' (Intercept)"' if A == "var(_cons[`_gvar'])"

            * Random slopes: var(varname[groupvar]) -> "Variance: GroupLabel (VarLabel)"
            foreach revar of local re_vars {
                if "`revar'" != "_cons" {
                    local slope_lbl : copy local lbl_`revar'
                    replace A = `"Variance: `macval(_glbl)' (`macval(slope_lbl)')"' if A == "var(`revar'[`_gvar'])"
                }
            }

            * Covariances: cov(var1,var2[groupvar]) -> "Covariance: GroupLabel (Label1, Label2)"
            count if strpos(A, "cov(") > 0 & strpos(A, "[`_gvar']") > 0
            if r(N) > 0 {
                gen _temp_row = _n
                levelsof _temp_row if strpos(A, "cov(") > 0 & strpos(A, "[`_gvar']") > 0, local(cov_rows)
                foreach row of local cov_rows {
                    local cov_str = A[`row']
                    * Extract the two components of cov(v1,v2[g]) (mixed),
                    * cov(v1[g],v2[g]) (me*), or the comma-less
                    * cov(v1[g]v2[g]): every [g] ends a component.
                    local cov_inner = substr(`"`cov_str'"', 5, .)
                    if substr(`"`cov_inner'"', -1, 1) == ")" {
                        local cov_inner = substr(`"`cov_inner'"', 1, strlen(`"`cov_inner'"') - 1)
                    }
                    local cov_inner = subinstr(`"`cov_inner'"', "[`_gvar'],", ",", .)
                    local cov_inner = subinstr(`"`cov_inner'"', "[`_gvar']", ",", .)
                    while substr(`"`cov_inner'"', -1, 1) == "," {
                        local cov_inner = substr(`"`cov_inner'"', 1, strlen(`"`cov_inner'"') - 1)
                    }
                    gettoken cov_v1 cov_v2 : cov_inner, parse(",")
                    local cov_v2 = subinstr("`cov_v2'", ",", "", 1)
                    local cov_v1 = strtrim("`cov_v1'")
                    local cov_v2 = strtrim("`cov_v2'")
                    * Only a key that splits into exactly two plain names is
                    * relabelled; anything else keeps its collect key.
                    if "`cov_v1'" == "" | "`cov_v2'" == "" | ///
                        strpos("`cov_v2'", ",") | strpos("`cov_v1'`cov_v2'", "[") continue
                    forvalues _cvk = 1/2 {
                        local cov_lbl`_cvk' "`cov_v`_cvk''"
                        if "`cov_v`_cvk''" == "_cons" local cov_lbl`_cvk' "Intercept"
                        forvalues _rli = 1/`_rel_n' {
                            if "`_rel_nm_`_rli''" == "`cov_v`_cvk''" {
                                local cov_lbl`_cvk' : copy local _rel_lb_`_rli'
                            }
                        }
                    }
                    replace A = `"Covariance: `macval(_glbl)' (`macval(cov_lbl1)', `macval(cov_lbl2)')"' in `row'
                }
                drop _temp_row
            }

            * Standard deviations with brackets
            replace A = `"`macval(_glbl)' SD (Intercept)"' if A == "sd(_cons[`_gvar'])"
            foreach revar of local re_vars {
                if "`revar'" != "_cons" {
                    local slope_lbl : copy local lbl_`revar'
                    replace A = `"`macval(_glbl)' SD (`macval(slope_lbl)')"' if A == "sd(`revar'[`_gvar'])"
                }
            }

            * Slope variances/SDs the metadata does not name. The me*
            * estimators record no e(revars) in the collection, so their
            * var(x[g]) rows stayed raw while mixed's were relabelled. Take the
            * slope name from the key itself.
            capture drop _temp_row
            gen long _temp_row = _n
            quietly levelsof _temp_row if _n > 2 & ///
                ustrregexm(A, "^(var|sd)\([^\[\]\(\),]+\[`_gvar'\]\)$"), local(_sl_rows)
            foreach row of local _sl_rows {
                local _sl_key = A[`row']
                if !ustrregexm(`"`_sl_key'"', "^(var|sd)\(([^\[\]\(\),]+)\[") continue
                local _sl_kind = ustrregexs(1)
                local _sl_var = ustrregexs(2)
                if "`_sl_var'" == "_cons" continue
                local _sl_lbl "`_sl_var'"
                forvalues _rli = 1/`_rel_n' {
                    if "`_rel_nm_`_rli''" == "`_sl_var'" local _sl_lbl : copy local _rel_lb_`_rli'
                }
                if "`_sl_kind'" == "var" {
                    replace A = `"Variance: `macval(_glbl)' (`macval(_sl_lbl)')"' in `row'
                }
                else {
                    replace A = `"`macval(_glbl)' SD (`macval(_sl_lbl)')"' in `row'
                }
            }
            drop _temp_row
        }

        * --- Single-level patterns (no brackets) for single-level mixed ---
        replace A = `"Variance: `macval(re_grouplbl)' (Intercept)"' if A == "var(_cons)"

        foreach revar of local re_vars {
            if "`revar'" != "_cons" {
                local slope_lbl : copy local lbl_`revar'
                replace A = `"Variance: `macval(re_grouplbl)' (`macval(slope_lbl)')"' if A == "var(`revar')"
            }
        }

        * Covariances without brackets (single-level mixed)
        count if strpos(A, "cov(") > 0
        if r(N) > 0 {
            gen _temp_row = _n
            levelsof _temp_row if strpos(A, "cov(") > 0, local(cov_rows)
            foreach row of local cov_rows {
                local cov_str = A[`row']
                local cov_inner = subinstr("`cov_str'", "cov(", "", 1)
                local cov_inner = subinstr("`cov_inner'", ")", "", 1)
                gettoken cov_v1 cov_v2 : cov_inner, parse(",")
                local cov_v2 = subinstr("`cov_v2'", ",", "", 1)
                local cov_v1 = strtrim("`cov_v1'")
                local cov_v2 = strtrim("`cov_v2'")
                local cov_lbl1 : copy local lbl_`cov_v1'
                if `"`macval(cov_lbl1)'"' == "" local cov_lbl1 "`cov_v1'"
                local cov_lbl2 : copy local lbl_`cov_v2'
                if `"`macval(cov_lbl2)'"' == "" local cov_lbl2 "`cov_v2'"
                replace A = `"Covariance: `macval(re_grouplbl)' (`macval(cov_lbl1)', `macval(cov_lbl2)')"' in `row'
            }
            drop _temp_row
        }

        * Residual variance: var(e) -> "Residual Variance"
        replace A = "Residual Variance" if A == "var(e)"

        * Standard deviations without brackets (single-level)
        replace A = `"`macval(re_grouplbl)' SD (Intercept)"' if A == "sd(_cons)"
        foreach revar of local re_vars {
            if "`revar'" != "_cons" {
                local slope_lbl : copy local lbl_`revar'
                replace A = `"`macval(re_grouplbl)' SD (`macval(slope_lbl)')"' if A == "sd(`revar')"
            }
        }
        replace A = "Residual SD" if A == "sd(e)"

        * Log-scale parameters (raw coefficient names: lns1_1_1, lns2_1_1, ...)
        forvalues _lev = 1/`_n_re_levels' {
            local _glbl : copy local re_grouplbl_`_lev'
            replace A = subinstr(A, "lns`_lev'_1_1", `"`macval(_glbl)' Log SD (Intercept)"', .)
        }
        replace A = subinstr(A, "lnsig_e", "Residual Log SD", .)
    }
    else {
        * Fallback: no random effects info, use generic labels
        replace A = subinstr(A, "var(_cons)", "Variance (Intercept)", .)
        replace A = subinstr(A, "var(e.", "Variance (Residual", .)
        replace A = subinstr(A, "var(e)", "Residual Variance", .)
        replace A = subinstr(A, "var(", "Variance (", .)
        replace A = subinstr(A, "cov(", "Covariance (", .)
        replace A = subinstr(A, "sd(_cons)", "SD (Intercept)", .)
        replace A = subinstr(A, "sd(e.", "SD (Residual", .)
        replace A = subinstr(A, "sd(", "SD (", .)
        * Log-scale parameters: handle all levels (lns1_1_1, lns2_1_1, ...)
        if `_n_re_levels' > 0 {
            forvalues _lev = 1/`_n_re_levels' {
                replace A = subinstr(A, "lns`_lev'_1_1", "Log SD (Level `_lev' Intercept)", .)
            }
        }
        else {
            replace A = subinstr(A, "lns1_1_1", "Log SD (Intercept)", .)
        }
        replace A = subinstr(A, "lnsig_e", "Log SD (Residual)", .)
    }

    * Clean up _cons in fixed effects (Intercept row)
    replace A = subinstr(A, "_cons", "Intercept", .)
}
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end
