*! _iivw_reserve_names Version 3.0.0  2026/07/14
*! Validate a command's complete generated-name inventory before any data is
*! touched: names must be legal, mutually unique, must never collide with a
*! scientific input, and -- when the caller declares ownership tokens -- must
*! already be owned by this package in the same role before `replace' may
*! overwrite them. `replace' authorizes overwriting a prior package OUTPUT --
*! it never authorizes destroying an input, and it never authorizes destroying
*! a variable this package did not create.
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _iivw_reserve_names
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , GENerated(string) ///
        [PROTected(string) REPLACE CONTEXT(string) OWNTokens(string)]

    if "`context'" == "" local context "iivw"

    * owntokens(), when supplied, is a list parallel to generated(): the
    * ownership token each name is about to be stamped with. Its presence
    * switches rule 4 from name-based inference to a proven-ownership check.
    local n_own : word count `owntokens'
    local n_g   : word count `generated'
    if "`owntokens'" != "" & `n_own' != `n_g' {
        display as error "`context': owntokens() must be parallel to generated()"
        display as error "  `n_g' generated names but `n_own' ownership tokens"
        error 198
    }

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
    * 4. A generated name that already exists in the data needs `replace'.
    * ---------------------------------------------------------------------
    forvalues i = 1/`n_g' {
        local g : word `i' of `generated'
        capture confirm variable `g'
        if _rc != 0 continue

        if "`replace'" == "" {
            display as error "`context': variable `g' already exists; use the replace option"
            error 110
        }

        * -----------------------------------------------------------------
        * 5. `replace' overwrites a prior output of THIS package in THIS
        *    role. It does not overwrite a variable we cannot prove we made.
        *
        *    The old rule was "it exists, it is not an input, therefore it is
        *    ours" -- an inference from a name. A user column that happens to
        *    sit under the selected prefix satisfied it, and was destroyed.
        *    Ownership is now read off the variable itself.
        * -----------------------------------------------------------------
        if "`owntokens'" == "" continue

        local want : word `i' of `owntokens'
        local have : char `g'[_iivw_owner]

        if "`have'" == "`want'" continue

        display as error "`context': variable `g' already exists and was not created by iivw"
        display as error ""
        if "`have'" == "" {
            display as error "  It carries no iivw ownership mark, so replace will not touch it."
            display as error "  replace overwrites variables this package created. It does not"
            display as error "  authorize destroying a variable of unknown origin that happens to"
            display as error "  share a name with one of our outputs."
        }
        else {
            display as error "  It is owned by iivw, but under a different contract:"
            display as error "    it carries: `have'"
            display as error "    this call would write: `want'"
            display as error "  (owner|prefix|role|contract-version). A mismatch means the column"
            display as error "  means something other than what this call is about to write."
        }
        display as error ""
        display as error "  Drop or rename `g', or choose a different generate() prefix."
        error 110
    }

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
