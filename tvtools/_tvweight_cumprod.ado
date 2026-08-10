*! _tvweight_cumprod Version 1.15.0  2026/08/10
*! In-place within-person cumulative product of a per-period weight
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass (creates generate(); returns nothing)
*!
*! generate() = product of input over the marked sample rows of each id(),
*! taken in (id, time, original observation) order. Rows outside the marked
*! sample keep a missing value and never restart the product for the rows that
*! follow them, so one period dropped by markout does not silently discard a
*! person's accumulated treatment or censoring history.
*!
*! The product is built with repeated multiplication in double precision. Do
*! not substitute exp(sum(log(w))): that changes rounding, and the zero,
*! negative, and overflow behaviour the callers screen for.

program define _tvweight_cumprod, sortpreserve
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    tempvar _row _excl

    capture noisily {

        syntax varname(numeric) [if] [in], ID(varname) TIME(varname) ///
            GENerate(name)

        local input `varlist'

        * novarlist: the caller owns sample selection. A missing input value on
        * a selected row is a caller-side contract violation that its own
        * post-product screen reports; silently dropping the row here would
        * turn that error into a plausible-looking weight.
        marksample touse, novarlist

        confirm new variable `generate'
        capture confirm numeric variable `time'
        if _rc {
            display as error "time() must be a numeric variable"
            exit 109
        }

        quietly {
            * Sorting excluded rows to the end of each id() block keeps the
            * selected rows physically contiguous, so `[_n-1]' is always the
            * previous SELECTED row. `_row' is the original observation index
            * and is the final tie-break, reproducing the released
            * (id, time, original row) chaining order exactly.
            generate long `_row' = _n
            generate byte `_excl' = !`touse'
            sort `id' `_excl' `time' `_row'

            by `id': generate double `generate' = `input' ///
                if `touse' & _n == 1
            by `id': replace `generate' = `generate'[_n-1] * `input' ///
                if `touse' & _n > 1
        }
    }
    local rc = _rc

    * No sort restoration here: sortpreserve was confirmed under this runtime
    * to restore the exact entry observation order, tie order included, on the
    * error path as well as the normal one. Rolling back a partially created
    * output variable stays with the caller.
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
