*! _iivw_reserve_names Version 2.0.0  2026/07/13
*! Validate a command's complete generated-name inventory before any data is
*! touched: names must be legal, mutually unique, and must never collide with a
*! scientific input. `replace' authorizes overwriting a prior package OUTPUT --
*! it never authorizes destroying an input.
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _iivw_reserve_names
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , GENerated(string) [PROTected(string) REPLACE CONTEXT(string)]

    if "`context'" == "" local context "iivw"

    * ---------------------------------------------------------------------
    * 1. Every generated name must be a legal Stata variable name.
    * ---------------------------------------------------------------------
    foreach g of local generated {
        capture confirm name `g'
        if _rc {
            display as error "`context': generated variable name is not legal: `g'"
            display as error "  choose a shorter or different generate() prefix"
            error 198
        }
        if strlen("`g'") > 32 {
            display as error "`context': generated variable name exceeds 32 characters: `g'"
            display as error "  choose a shorter generate() prefix, or rename the source variable"
            error 198
        }
    }

    * ---------------------------------------------------------------------
    * 2. Generated names must be mutually unique. Two outputs sharing a name
    *    means one silently overwrites the other and the design matrix is
    *    wrong with rc 0 -- the C4 defect class.
    * ---------------------------------------------------------------------
    local n_gen : word count `generated'
    forvalues i = 1/`n_gen' {
        local gi : word `i' of `generated'
        local j = `i' + 1
        forvalues j = `j'/`n_gen' {
            local gj : word `j' of `generated'
            if "`gi'" == "`gj'" {
                display as error "`context': two generated variables would share the name `gi'"
                display as error "  this would silently overwrite one output with another"
                display as error "  choose a shorter generate() prefix"
                error 198
            }
        }
    }

    * ---------------------------------------------------------------------
    * 3. No generated name may collide with a scientific input. This is the
    *    hard rule: `replace' is permission to overwrite a variable this
    *    package previously created, not permission to destroy a predictor,
    *    outcome, identifier, or any other analysis input.
    * ---------------------------------------------------------------------
    foreach g of local generated {
        foreach p of local protected {
            if "`g'" == "`p'" {
                display as error "`context': the generated variable `g' would overwrite `p',"
                display as error "  which you supplied as an analysis input."
                display as error ""
                display as error "  replace does not authorize destroying a scientific input."
                display as error "  Rename `p', or choose a different generate() prefix."
                error 198
            }
        }
    }

    * ---------------------------------------------------------------------
    * 4. A generated name that already exists in the data, and is not an
    *    input, is a prior package output: overwriting it needs `replace'.
    * ---------------------------------------------------------------------
    foreach g of local generated {
        capture confirm variable `g'
        if _rc == 0 & "`replace'" == "" {
            display as error "`context': variable `g' already exists; use the replace option"
            error 110
        }
    }

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
