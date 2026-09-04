*! _iivw_assert_cardinality Version 4.1.2  2026/09/04
*! Refuse a destructive commit that would carry zero (or too few) usable values
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
The commit contract.

Before creating or replacing a user variable, writing a workbook sheet, posting
e(), or ranking a metric for selection, count the usable outputs and error when
there are none. The failure this guards is iivw audit finding IIVW-02: with
allowmissingweights specified, a run in which the nuisance models' complete-case
sets did not overlap produced an all-missing weight variable, and iivw_weight
committed its signed _iivw_ contract and returned ordinary success at rc 0.

Syntax:
  _iivw_assert_cardinality <varname> [<expected_n>] [, touse(varname)
      label(string) allowzero]

  <expected_n>  when given, the count must be at least this many.
  touse()       restrict the count to the marked estimation sample.
  label()       what to name in the error message (defaults to the varname,
                which is usually a tempvar and meaningless to a user).
  allowzero     permit an empty result. Only for a mode documented in the
                .sthlp as producing no output.

Errors 2000 on zero, 459 when short of expected_n. Returns r(N).
*/

program define _iivw_assert_cardinality, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax anything(name=spec id="variable") ///
            [, TOUSE(varname) LABel(string) ALLOWZERO]

        gettoken cvar expected : spec
        local expected = strtrim("`expected'")
        confirm numeric variable `cvar'
        if "`expected'" != "" {
            confirm integer number `expected'
        }
        if `"`label'"' == "" local label "`cvar'"

        if "`touse'" != "" {
            quietly count if !missing(`cvar') & `touse'
        }
        else {
            quietly count if !missing(`cvar')
        }
        local found = r(N)

        if `found' == 0 & "`allowzero'" == "" {
            display as error `"`label': zero usable values"'
            display as error "  refusing to commit a result with no content"
            exit 2000
        }
        if "`expected'" != "" {
            if `found' < `expected' {
                display as error `"`label': `found' usable values, expected `expected'"'
                exit 459
            }
        }

        return scalar N = `found'
        if "`expected'" != "" {
            return scalar expected = `expected'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
