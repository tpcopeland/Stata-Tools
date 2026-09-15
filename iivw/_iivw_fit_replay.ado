*! _iivw_fit_replay Version 4.2.0  2026/09/15
*! Replay a stored iivw_fit result, including asymmetric bootstrap intervals
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass (displays only; touches neither r() nor e())

/*
Basic syntax:
  _iivw_fit_replay [, level(#)]

Description:
  The display half of `iivw_fit' replay, and of `iivw_bspool'. Stata's generic
  `ereturn display' reconstructs limits as b +/- z*SE, which is correct only
  for a Wald interval; a stored percentile, basic or BCa interval is asymmetric
  and its endpoints were computed from the replicate distribution at estimation
  time. Replaying those through ereturn display would silently substitute
  symmetric limits for the ones the command reported.

  This lived inside iivw_fit.ado until 4.2.0. It moved to its own file so
  Stata's autoloader can resolve it for iivw_bspool, which reposts a pooled
  variance onto an iivw_fit result and then replays it -- in a process where
  iivw_fit itself may never have been called and iivw_fit.ado therefore never
  loaded.

See help iivw_fit and help iivw_bspool.
*/

capture program drop _iivw_fit_replay
program define _iivw_fit_replay, nclass
    version 16.0
    local __iivw_replay_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    * Level(string), NOT Level(cilevel). syntax fills a cilevel option with
    * c(level) whenever it is omitted, so `level' is never empty and the guard
    * below compared c(level) against e(level) on every replay. A percentile,
    * basic or BCa fit made at any level other than the session default then
    * refused its own bare replay with "level() cannot be changed" -- an error
    * about an option the user had not typed. Present in 4.1.3 and earlier;
    * regression coverage is test_iivw_v420_shard.do case T21.
    syntax [, Level(string) TItle(string)]

    if "`level'" != "" {
        capture confirm integer number `level'
        if _rc | `level' < 10 | `level' > 99 {
            display as error "level() must be an integer between 10 and 99"
            display as error "  got: `level'"
            error 198
        }
    }

    local citype "`e(iivw_ci_type)'"
    local interval_available = e(iivw_interval_available)

    * The banner names the command that produced the table. iivw_bspool reposts
    * a pooled variance onto an iivw_fit result and replays it here; labelling
    * that "iivw_fit replay" would attribute a pooled interval to a single run.
    if `"`title'"' == "" local title "iivw_fit replay -- `citype' interval"

    * Coefficient-only results have no e(V), and ereturn display respects
    * e(properties)="b". Wald results can likewise use Stata's generic display.
    if !`interval_available' | "`citype'" == "wald-normal" {
        if "`level'" != "" ereturn display, level(`level')
        else                ereturn display
    }
    else {
        * Asymmetric endpoints were computed at estimation time. The stored
        * replicate distribution is not available to reconstruct another level,
        * so never accept a replay option that would relabel frozen limits.
        * Nested, not `&'. Stata evaluates both sides of & regardless, so with
        * level() genuinely omitted the second operand expanded to `!= e(level)'
        * and died with "unknown function =e()".
        if "`level'" != "" {
            if `level' != e(level) {
                display as error ///
                    "level() cannot be changed when replaying a stored `citype' interval"
                display as error "  the stored endpoints came from the replicate"
                display as error "  distribution at `=e(level)'%; refit with level(`level')"
                error 198
            }
        }
        local level = e(level)

        tempname B V C
        matrix `B' = e(b)
        matrix `V' = e(V)
        matrix `C' = e(iivw_ci)
        local names : colnames `B'
        local k = colsof(`B')
        local __iivw_smcl_lb = char(123)
        local __iivw_smcl_rb = char(125)

        display as text ""
        display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
        display as text `"`title'"'
        display as text ""
        display as text _col(4) ///
            "`__iivw_smcl_lb'ralign 18:Variable`__iivw_smcl_rb'" ///
            _col(24) "`__iivw_smcl_lb'ralign 10:Coef.`__iivw_smcl_rb'" ///
            _col(36) "`__iivw_smcl_lb'ralign 9:SE`__iivw_smcl_rb'" ///
            _col(47) "`__iivw_smcl_lb'ralign 16:`level'% CI`__iivw_smcl_rb'" ///
            _col(65) "`__iivw_smcl_lb'ralign 6:P(z)`__iivw_smcl_rb'"
        display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"

        forvalues j = 1/`k' {
            local term : word `j' of `names'
            local vlab "`term'"
            if "`term'" == "_cons" local vlab "Intercept"
            if strlen(`"`vlab'"') > 18 {
                local vlab = substr(`"`vlab'"', 1, 16) + ".."
            }

            local b = el(`B', 1, `j')
            local se = sqrt(el(`V', `j', `j'))
            local lo = el(`C', 1, `j')
            local hi = el(`C', 2, `j')
            if `b' < . & `se' > 0 & `se' < . & `lo' < . & `hi' < . {
                local p = 2 * normal(-abs(`b'/`se'))
                if `p' < 0.001 {
                    local p_fmt "<0.001"
                }
                else {
                    local p_fmt : display %6.3f `p'
                    local p_fmt = strtrim("`p_fmt'")
                }
                display as text _col(4) ///
                    "`__iivw_smcl_lb'ralign 18:`vlab'`__iivw_smcl_rb'" ///
                    as result _col(24) %10.4f `b' ///
                    _col(36) %9.4f `se' ///
                    _col(47) %7.4f `lo' as text "," ///
                    as result %7.4f `hi' ///
                    as text _col(65) ///
                    "`__iivw_smcl_lb'ralign 6:`p_fmt'`__iivw_smcl_rb'"
            }
            else {
                display as text _col(4) ///
                    "`__iivw_smcl_lb'ralign 18:`vlab'`__iivw_smcl_rb'" ///
                    _col(24) "`__iivw_smcl_lb'ralign 41:(omitted)`__iivw_smcl_rb'"
            }
        }
        display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    }

    }
    local rc = _rc
    set varabbrev `__iivw_replay_old_varabbrev'
    if `rc' exit `rc'
end
