*! fvgen Version 1.2.0  2026/06/30
*! Flatten factor-variable interactions into labeled main-effect and product variables
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Requires: Stata 16.0+

/*
Basic syntax:
  fvgen fvvarlist [if] [in] [weight] [, alllevels center prefix(name) ///
      ref(spec) simple(varname) replace xsymbol(string)]
  fvgen , margins [store(name) replace]
  fvgen , drop

Materializes the terms of a factor-variable interaction specification as
ordinary variables: indicator variables for categorical levels (base level
dropped), and product variables for interactions. Value labels become variable
labels so regression exports show one clean row per coefficient instead of the
extra factor-variable header rows produced by the i.a##c.b approach.

Generated variables carry provenance characteristics (fvgen_role,
fvgen_term) so downstream tools can recognize, group, and tear them down;
fvgen, drop removes every fvgen-generated variable in the dataset.
fvgen, margins rebuilds the active flattened estimation result with native
factor-variable syntax so Stata's margins can read the original factor
structure using the estimator's own postestimation metadata.

See help fvgen for complete documentation.
*/

program define fvgen, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _fvgen_est_held = 0
    local _fvgen_unhold_rc = 0
    local _fvgen_margins_active = 0
    local _fvgen_store_done ""
    tempname _fvgen_est_hold

    capture noisily {

        **# Peek: did the user type a leading fvvarlist?
        * An optional [varlist] defaults to every variable in the dataset when
        * omitted, so the parsed macro cannot tell "none typed" from "all". Detect
        * the leading token directly: a varlist, if present, precedes if/in/weight
        * and the option comma.
        local _peekline : copy local 0
        gettoken _peek : _peekline, parse(" ,[")
        local _has_vl = 1
        if inlist(`"`_peek'"', "", ",", "if", "in") local _has_vl = 0
        if substr(`"`_peek'"', 1, 1) == "[" local _has_vl = 0
        * Raw varlist text (everything before the option comma), kept before
        * syntax normalizes away the omit operator.
        local _rawvl : copy local 0
        gettoken _rawvl _junk : _rawvl, parse(",")

        **# Syntax parsing
        syntax [varlist(fv)] [if] [in] [aweight pweight fweight iweight] [, ///
            ALLlevels ///
            CENTER ///
            PREfix(name) ///
            REF(string asis) ///
            SIMPle(varname) ///
            MARGINS ///
            STORe(name) ///
            VSref(string) ///
            replace ///
            XSYMbol(string) ///
            DROP]

        local _drop_extras `"`if'`in'`weight'`alllevels'`center'`prefix'`ref'`simple'`margins'`store'`vsref'`replace'`xsymbol'"'
        local _margins_extras `"`if'`in'`weight'`alllevels'`center'`prefix'`ref'`simple'`vsref'`xsymbol'`drop'"'
        if "`prefix'" == "" local prefix "_"
        if "`xsymbol'" == "" local xsymbol "×"
        local alllev = ("`alllevels'" != "")
        if !`_has_vl' local varlist ""

        if "`margins'" != "" | "`store'" != "" {
            **# Post-estimation mode: rebuild native-factor estimates for margins
            * This leaves the generated variables themselves untouched.  The
            * optional store() path creates a margins-ready clone and restores
            * the active flattened estimates, keeping regtab output clean.
            if "`margins'" == "" {
                display as error "store() is only allowed with margins; use {cmd:fvgen, margins store(name)}"
                exit 198
            }
            if `_has_vl' | `"`_margins_extras'"' != "" {
                display as error ///
                    "margins does not take varlists, qualifiers, weights, or generation/drop options; use {cmd:fvgen, margins} or {cmd:fvgen, margins store(name)}"
                exit 198
            }
            if "`replace'" != "" & "`store'" == "" {
                display as error "replace with margins is only allowed when store(name) is specified"
                exit 198
            }

            if "`store'" != "" {
                capture _estimates hold `_fvgen_est_hold', restore copy nullok
                if _rc {
                    display as error "fvgen, margins store(): could not preserve the active estimates"
                    exit _rc
                }
                local _fvgen_est_held = 1
                _fvgen_margins_repost
                if "`replace'" != "" capture estimates drop `store'
                estimates store `store'
                return local stored "`store'"
                return local margins "stored"
                local _fvgen_store_done "`store'"
            }
            else {
                _fvgen_margins_repost
                return local margins "active"
                local _fvgen_margins_active = 1
            }
        }
        else if "`drop'" != "" {
            **# Teardown mode: drop every fvgen-generated variable
            * Generated variables are tagged with a fvgen_role characteristic;
            * remove exactly those, leaving pass-through originals untouched.
            if `_has_vl' | `"`_drop_extras'"' != "" {
                display as error ///
                    "drop does not take varlists, qualifiers, weights, or other options; use {cmd:fvgen, drop} alone to remove all fvgen-generated variables"
                exit 198
            }
            local _dropped ""
            if `=c(k)' > 0 {
                foreach v of varlist * {
                    local _role : char `v'[fvgen_role]
                    if "`_role'" != "" {
                        drop `v'
                        local _dropped "`_dropped' `v'"
                    }
                }
            }
            char _dta[fvgen_spec] ""
            char _dta[fvgen_terms] ""
            char _dta[fvgen_allvars] ""
            char _dta[fvgen_genvars] ""
            char _dta[fvgen_centered] ""
            local _dropped : list clean _dropped
            local _nd : word count `_dropped'
            return local dropped  "`_dropped'"
            return scalar k_dropped = `_nd'
            if `_nd' == 0 {
                display as text "fvgen: no fvgen-generated variables found to drop"
            }
            else {
                display as text "fvgen dropped " as result `_nd' ///
                    as text " variable(s): " as result "`_dropped'"
            }
        }
        else {

            **# Require a specification
            if !`_has_vl' {
                display as error "fvvarlist required"
                exit 100
            }

            char _dta[fvgen_spec] ""
            char _dta[fvgen_terms] ""
            char _dta[fvgen_allvars] ""
            char _dta[fvgen_genvars] ""
            char _dta[fvgen_centered] ""

            **# Validate the vsref() template up front
            * vsref() appends the reference (base) level to main-effect labels.
            * The argument is a template in which @ stands for the base label.
            if `"`vsref'"' != "" & strpos(`"`vsref'"', "@") == 0 {
                display as error ///
                    `"vsref() must contain @ as a placeholder for the reference label, e.g. vsref("(vs. @)")"'
                exit 198
            }

            **# Weighting expression (used only by center; pweight is mapped to
            * aweight for the centering mean, which is numerically identical).
            local wmean ""
            if "`weight'" != "" {
                local _wt "`weight'"
                if "`_wt'" == "pweight" local _wt "aweight"
                local wmean "[`_wt'`exp']"
            }

            **# Mark sample
            marksample touse
            quietly count if `touse'
            if r(N) == 0 {
                display as error "no observations"
                exit 2000
            }

            **# Reject the explicit omit operator (o.)
            * o. / Ndigit-o. / #o. mean "omit from estimation"; syntax silently
            * normalizes the o away, so fvgen would drop the term without
            * warning. Detect it in the raw varlist and tell the user how to
            * express the intent instead. The omit operator is digits-then-o
            * immediately before the dot, at the start of a term or after a space
            * or # (variable names never appear before the dot).
            if regexm(`"`_rawvl'"', "(^| |#)[0-9]*o\.") {
                display as error ///
                    "fvgen does not support the omit operator (o.); restrict the sample with if/in or choose a base with ref()"
                exit 198
            }

            **# Per-factor reference levels via ref()
            * Re-reference by rewriting each named factor's operator to ibLEVEL.
            * The normalized fv varlist always renders factors as i.VAR / ibN.VAR
            * (dotted, leading "i"); continuous terms are bare VAR or c.VAR. This
            * lets fvexpand handle base/empty-cell logic under the chosen bases
            * without touching dataset state (no fvset mutation). Levels may be
            * given as integer codes or as value-label strings, e.g.
            * ref(foreign "Domestic", rep78 3).
            local expandspec "`varlist'"
            if `"`ref'"' != "" {
                local refvars   ""
                local reflevels ""
                local refwork `"`ref'"'
                while `"`refwork'"' != "" {
                    gettoken rv refwork : refwork, parse(" ,")
                    if `"`rv'"' == "," continue
                    gettoken rl refwork : refwork, parse(" ,")
                    while `"`rl'"' == "," {
                        gettoken rl refwork : refwork, parse(" ,")
                    }
                    if `"`rv'"' == "" | `"`rl'"' == "" {
                        display as error ///
                            "ref() expects variable/level pairs, e.g. ref(sex 2, race 3)"
                        exit 198
                    }
                    capture confirm variable `rv'
                    if _rc {
                        display as error "ref(): variable '`rv'' not found"
                        exit 111
                    }
                    * Resolve the level: an integer code, else a value-label string.
                    capture confirm integer number `rl'
                    if _rc == 0 {
                        local _lvl `rl'
                    }
                    else {
                        local _vlbl : value label `rv'
                        if "`_vlbl'" == "" {
                            display as error ///
                                "ref(): level '`rl'' for `rv' is not an integer and `rv' has no value label to resolve it"
                            exit 198
                        }
                        quietly levelsof `rv' if `touse', local(_obslv)
                        local _lvl ""
                        foreach L of local _obslv {
                            local _thislab : label `_vlbl' `L'
                            if `"`_thislab'"' == `"`rl'"' local _lvl `L'
                        }
                        if "`_lvl'" == "" {
                            display as error ///
                                `"ref(): label "`rl'" not found among observed levels of `rv'"'
                            exit 198
                        }
                    }
                    quietly levelsof `rv' if `touse', local(_reflv)
                    if !`: list _lvl in _reflv' {
                        display as error ///
                            "ref(): `rv'==`_lvl' is not an observed level in the sample"
                        exit 198
                    }
                    local refvars   "`refvars' `rv'"
                    local reflevels "`reflevels' `_lvl'"
                }
                * Single rewrite pass over the normalized spec.
                local newspec ""
                local matched ""
                foreach term of local varlist {
                    local rest "`term'"
                    local newterm ""
                    while `"`rest'"' != "" {
                        gettoken comp rest : rest, parse("#")
                        if "`comp'" == "#" {
                            local newterm "`newterm'#"
                        }
                        else {
                            local dotpos = strpos("`comp'", ".")
                            if `dotpos' {
                                local op = substr("`comp'", 1, `dotpos' - 1)
                                local cv = substr("`comp'", `dotpos' + 1, .)
                                local idx : list posof "`cv'" in refvars
                                if `idx' & substr("`op'", 1, 1) == "i" {
                                    local rl : word `idx' of `reflevels'
                                    local comp "ib`rl'.`cv'"
                                    local matched "`matched' `cv'"
                                }
                            }
                            local newterm "`newterm'`comp'"
                        }
                    }
                    local newspec "`newspec' `newterm'"
                }
                local unmatched : list refvars - matched
                local unmatched : list uniq unmatched
                if "`unmatched'" != "" {
                    display as error ///
                        "ref(): variable(s) not used as a factor in the specification: `unmatched'"
                    exit 198
                }
                local expandspec : list clean newspec
            }

            **# Per-group simple effects via simple()
            * Report a continuous term's slope WITHIN each moderator level (combined
            * main + interaction) instead of a reference slope plus a difference.
            * Reparameterize to the nested form "i.mod i.mod#c.x": drop the
            * continuous main, keep the moderator main, and let fvexpand keep every
            * moderator level in the interaction (each becomes a standalone slope).
            local simplemod ""
            if "`simple'" != "" {
                local _modfactor 0
                local absorbed ""
                foreach term of local expandspec {
                    if strpos("`term'", "#") == 0 continue
                    local rest "`term'"
                    local has_mod 0
                    local other_cont ""
                    local other_cat ""
                    while `"`rest'"' != "" {
                        gettoken comp rest : rest, parse("#")
                        if "`comp'" == "#" continue
                        local dotpos = strpos("`comp'", ".")
                        if `dotpos' {
                            local op = substr("`comp'", 1, `dotpos' - 1)
                            local cv = substr("`comp'", `dotpos' + 1, .)
                        }
                        else {
                            local op ""
                            local cv "`comp'"
                        }
                        if "`cv'" == "`simple'" & substr("`op'", 1, 1) == "i" {
                            local has_mod 1
                        }
                        else if substr("`op'", 1, 1) == "i" {
                            local other_cat "`other_cat' `cv'"
                        }
                        else {
                            local other_cont "`other_cont' `cv'"
                        }
                    }
                    if `has_mod' {
                        local _modfactor 1
                        if "`other_cat'" != "" {
                            display as error ///
                                "simple() supports per-group slopes of continuous terms; '`simple'' interacts with a categorical term. Use margins or contrast for categorical-by-categorical simple effects."
                            exit 198
                        }
                        local absorbed "`absorbed' `other_cont'"
                    }
                }
                if !`_modfactor' {
                    display as error "simple(): '`simple'' is not a factor in the specification"
                    exit 198
                }
                local absorbed : list uniq absorbed
                if "`absorbed'" == "" {
                    display as error "simple(): '`simple'' does not interact with any continuous term"
                    exit 198
                }
                * Drop the absorbed continuous main terms (bare tokens).
                local newspec ""
                foreach term of local expandspec {
                    if strpos("`term'", "#") == 0 & strpos("`term'", ".") == 0 {
                        if `: list term in absorbed' continue
                    }
                    local newspec "`newspec' `term'"
                }
                local expandspec : list clean newspec
                local simplemod "`simple'"
            }

            **# Expand the factor-variable specification on the marked sample
            * Empty/base cells are flagged omitted by _ms_parse_parts (r(omit)).
            fvexpand `expandspec' if `touse'
            local terms `r(varlist)'

            **# First pass: reject higher-order interactions; capture base levels
            * The base level of each factor (the term flagged r(base)) is recorded
            * in parallel name/level lists (not name-keyed macros, which overflow
            * Stata's 31-char local-name limit for long variable names) so vsref()
            * can append "(vs. <base label>)" to main-effect labels.
            local _vsbasevars   ""
            local _vsbaselevels ""
            foreach t of local terms {
                _ms_parse_parts `t'
                if "`r(type)'" == "interaction" & r(k_names) > 2 {
                    display as error ///
                        "fvgen supports up to 2-way interactions; '`t'' is higher-order"
                    exit 198
                }
                if `"`vsref'"' != "" & "`r(type)'" == "factor" & r(base) {
                    local _vsbasevars   "`_vsbasevars' `r(name)'"
                    local _vsbaselevels "`_vsbaselevels' `=r(level)'"
                }
            }

            **# Optional pre-pass: center continuous variables once, up front
            * A centered copy is reused by both main effects and products so the
            * product is the product of centered terms. The centering mean honors
            * any supplied weight.
            if "`center'" != "" {
                local contvars ""
                * Parallel var/name lists map each centered original to its copy
                * (name-keyed macros would overflow the 31-char local-name limit).
                local cmapvars  ""
                local cmapnames ""
                foreach t of local terms {
                    _ms_parse_parts `t'
                    if "`r(type)'" == "variable" {
                        local contvars `contvars' `r(name)'
                    }
                    else if "`r(type)'" == "interaction" {
                        if strpos("`r(op1)'", "c") local contvars `contvars' `r(name1)'
                        if strpos("`r(op2)'", "c") local contvars `contvars' `r(name2)'
                    }
                }
                local contvars : list uniq contvars
                foreach cv of local contvars {
                    local cname "`prefix'`cv'_c"
                    _fvgen_newvar `cname' "`replace'"
                    quietly summarize `cv' `wmean' if `touse', meanonly
                    quietly generate double `cname' = `cv' - r(mean)
                    local clab : variable label `cv'
                    if "`clab'" == "" local clab "`cv'"
                    _fvgen_setlabel `cname' `"`clab' (centered)"'
                    char `cname'[fvgen_role] "centered"
                    char `cname'[fvgen_term] "c.`cv'"
                    local cmapvars  "`cmapvars' `cv'"
                    local cmapnames "`cmapnames' `cname'"
                    local genvars `genvars' `cname'
                }
            }

            **# Second pass: build the main-effect and interaction variables
            local mainvars ""
            local intvars ""
            local allvars ""

            foreach t of local terms {
                _ms_parse_parts `t'
                local ty "`r(type)'"

                if "`ty'" == "variable" {
                    * Continuous main effect.
                    local v "`r(name)'"
                    if "`center'" != "" {
                        local _ci : list posof "`v'" in cmapvars
                        local use : word `_ci' of `cmapnames'
                        local mainvars `mainvars' `use'
                        local allvars  `allvars'  `use'
                    }
                    else {
                        * Pass the original variable through untouched.
                        local mainvars `mainvars' `v'
                        local allvars  `allvars'  `v'
                    }
                }
                else if "`ty'" == "factor" {
                    local omit = r(omit)
                    local base = r(base)
                    * Skip omitted levels, except keep the base when alllevels asked.
                    if `omit' & !(`alllev' & `base') continue
                    local v  "`r(name)'"
                    local L  = r(level)
                    local newname "`prefix'`v'_`L'"
                    _fvgen_newvar `newname' "`replace'"
                    quietly generate double `newname' = (`v' == `L') if !missing(`v')
                    _fvgen_partlabel `v' `L' "`xsymbol'"
                    local _flab `"`r(label)'"'
                    * vsref(): append the base level (skip the base row itself).
                    if `"`vsref'"' != "" & !`base' {
                        local _vsidx : list posof "`v'" in _vsbasevars
                        if `_vsidx' {
                            local _bl : word `_vsidx' of `_vsbaselevels'
                            _fvgen_partlabel `v' `_bl' "`xsymbol'"
                            local _vstxt : subinstr local vsref "@" `"`r(label)'"', all
                            local _flab `"`_flab' `_vstxt'"'
                        }
                    }
                    _fvgen_setlabel `newname' `"`_flab'"'
                    char `newname'[fvgen_role] "main"
                    char `newname'[fvgen_term] "`t'"
                    local mainvars `mainvars' `newname'
                    local genvars  `genvars'  `newname'
                    local allvars  `allvars'  `newname'
                }
                else if "`ty'" == "interaction" {
                    if r(omit) continue
                    local n1 "`r(name1)'"
                    local o1 "`r(op1)'"
                    local l1 = r(level1)
                    local n2 "`r(name2)'"
                    local o2 "`r(op2)'"
                    local l2 = r(level2)
                    local f1 = (strpos("`o1'", "c") == 0)
                    local f2 = (strpos("`o2'", "c") == 0)

                    * Resolve the modeling expression and name suffix for each side.
                    local stem "`prefix'`n1'X`n2'"
                    local suff ""
                    if `f1' {
                        local e1 "(`n1' == `l1')"
                        local m1 "`n1'"
                        local suff "`suff'_`l1'"
                        _fvgen_partlabel `n1' `l1' "`xsymbol'"
                        local lab1 "`r(label)'"
                    }
                    else {
                        if "`center'" != "" {
                            local _ci : list posof "`n1'" in cmapvars
                            local use1 : word `_ci' of `cmapnames'
                        }
                        else local use1 "`n1'"
                        local e1 "`use1'"
                        local m1 "`n1'"
                        local lab1 : variable label `n1'
                        if "`lab1'" == "" local lab1 "`n1'"
                    }
                    if `f2' {
                        local e2 "(`n2' == `l2')"
                        local m2 "`n2'"
                        local suff "`suff'_`l2'"
                        _fvgen_partlabel `n2' `l2' "`xsymbol'"
                        local lab2 "`r(label)'"
                    }
                    else {
                        if "`center'" != "" {
                            local _ci : list posof "`n2'" in cmapvars
                            local use2 : word `_ci' of `cmapnames'
                        }
                        else local use2 "`n2'"
                        local e2 "`use2'"
                        local m2 "`n2'"
                        local lab2 : variable label `n2'
                        if "`lab2'" == "" local lab2 "`n2'"
                    }

                    local newname "`stem'`suff'"
                    _fvgen_newvar `newname' "`replace'"
                    quietly generate double `newname' = `e1' * `e2' if !missing(`m1', `m2')
                    * Label priority: a continuous self-interaction reads "<var>²";
                    * a simple() moderator interaction reads "<continuous> (<level>)";
                    * everything else joins the two sides with the x symbol.
                    if "`n1'" == "`n2'" & `f1' == 0 & `f2' == 0 {
                        local _ilab `"`lab1'²"'
                    }
                    else if "`simplemod'" != "" & ("`n1'" == "`simplemod'" | "`n2'" == "`simplemod'") {
                        if "`n1'" == "`simplemod'" local _ilab `"`lab2' (`lab1')"'
                        else                       local _ilab `"`lab1' (`lab2')"'
                    }
                    else local _ilab `"`lab1' `xsymbol' `lab2'"'
                    _fvgen_setlabel `newname' `"`_ilab'"'
                    char `newname'[fvgen_role] "interaction"
                    char `newname'[fvgen_term] "`t'"
                    local intvars `intvars' `newname'
                    local genvars `genvars' `newname'
                    local allvars `allvars' `newname'
                }
            }

            if "`allvars'" == "" {
                display as error "fvgen: no variables to materialize from '`varlist''"
                exit 198
            }

            **# Dataset-level provenance for post-estimation margins-ready clones
            char _dta[fvgen_spec] "`expandspec'"
            char _dta[fvgen_terms] "`terms'"
            char _dta[fvgen_allvars] "`allvars'"
            char _dta[fvgen_genvars] "`genvars'"
            char _dta[fvgen_centered] "`center'"

            **# Return results
            return local spec     "`expandspec'"
            return local allvars  "`allvars'"
            return local mainvars "`mainvars'"
            return local intvars  "`intvars'"
            return local genvars  "`genvars'"
            return scalar k_all  = `: word count `allvars''
            return scalar k_main = `: word count `mainvars''
            return scalar k_int  = `: word count `intvars''

            **# Display
            * Show the model varlist plus any generated helper (e.g. an absorbed
            * centered copy under center+simple) that is not itself a regressor.
            local _displayvars : list allvars | genvars
            display as text _n "fvgen created " as result `: word count `genvars'' ///
                as text " variable(s) from " as result "`expandspec'" as text ":"
            foreach v of local _displayvars {
                local lb : variable label `v'
                display as text "    " as result %-28s "`v'" as text `" `lb'"'
            }
        }
    }
    local rc = _rc
    if `_fvgen_est_held' {
        capture _estimates unhold `_fvgen_est_hold'
        local _fvgen_unhold_rc = _rc
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    if `_fvgen_unhold_rc' exit `_fvgen_unhold_rc'
    if `"`_fvgen_store_done'"' != "" {
        display as text "fvgen stored margins-ready estimates as " as result "`_fvgen_store_done'" ///
            as text "; the active flattened estimates were restored for table export"
    }
    if `_fvgen_margins_active' {
        display as text "fvgen rebuilt the active estimates with native factor-variable syntax for margins"
    }
end

**# Helper: validate a candidate variable name (length + collision)
capture program drop _fvgen_newvar
program define _fvgen_newvar
    args name replace
    if length("`name'") > 32 {
        display as error ///
            "fvgen: generated name '`name'' exceeds the 32-character limit; use a shorter prefix()"
        exit 198
    }
    capture confirm new variable `name'
    if _rc {
        if "`replace'" == "" {
            display as error "fvgen: variable '`name'' already exists; specify the replace option"
            exit 110
        }
        capture drop `name'
    }
end

**# Helper: build a friendly label for one factor level (returns r(label))
capture program drop _fvgen_partlabel
program define _fvgen_partlabel, rclass
    args var level xsymbol
    local vl : value label `var'
    if "`vl'" != "" {
        local lab : label `vl' `level'
    }
    else {
        local lab "`var'=`level'"
    }
    return local label `"`lab'"'
end

**# Helper: set a variable label, truncated to Stata's 80-character limit
capture program drop _fvgen_setlabel
program define _fvgen_setlabel
    gettoken name 0 : 0
    gettoken lab  0 : 0
    if ustrlen(`"`lab'"') > 80 {
        local lab = usubstr(`"`lab'"', 1, 80)
        display as text ///
            "note: variable label for `name' truncated to Stata's 80-character limit"
    }
    label variable `name' `"`lab'"'
end

**# Helper: rerun active flattened estimates with native factor-variable syntax
capture program drop _fvgen_margins_repost
program define _fvgen_margins_repost, eclass
    version 16.0

    if "`e(cmd)'" == "" {
        display as error "fvgen, margins requires active estimation results"
        exit 301
    }
    capture confirm matrix e(b)
    if _rc {
        display as error "fvgen, margins requires active estimation results with e(b)"
        exit 301
    }
    capture confirm matrix e(V)
    if _rc {
        display as error "fvgen, margins requires active estimation results with e(V)"
        exit 301
    }

    local allvars : char _dta[fvgen_allvars]
    local spec    : char _dta[fvgen_spec]
    if `"`allvars'"' == "" | `"`spec'"' == "" {
        display as error ///
            "fvgen, margins requires fvgen term provenance; rerun fvgen, estimate on r(allvars), then call fvgen, margins"
        exit 198
    }
    local centered : char _dta[fvgen_centered]
    if "`centered'" != "" {
        display as error ///
            "fvgen, margins does not support models generated with center; margins must see the same raw factor-variable scale used for estimation"
        exit 198
    }

    local cmdline `"`e(cmdline)'"'
    if `"`cmdline'"' == "" {
        display as error "fvgen, margins requires e(cmdline) so the estimator can be rerun with native factor-variable syntax"
        exit 301
    }

    local cmd_pad `" `cmdline' "'
    local varseq  `" `allvars'"'
    local pos = strpos(`"`cmd_pad'"', `"`varseq'"')
    local nextchar ""
    if `pos' {
        local nextchar = substr(`"`cmd_pad'"', `pos' + strlen(`"`varseq'"'), 1)
    }
    if `pos' == 0 | !inlist(`"`nextchar'"', " ", ",") {
        display as error ///
            "fvgen, margins could not locate r(allvars) in the active estimation command line"
        display as error ///
            "rerun the model using the exact varlist returned by fvgen before calling fvgen, margins"
        exit 198
    }

    local before = substr(`"`cmd_pad'"', 1, `pos' - 1)
    local after  = substr(`"`cmd_pad'"', `pos' + strlen(`"`varseq'"'), .)
    local native_cmdline `"`before' `spec' `after'"'

    capture quietly `native_cmdline'
    if _rc {
        local native_rc = _rc
        display as error ///
            "fvgen, margins could not rerun the estimator with native factor-variable syntax"
        display as error `"`native_cmdline'"'
        exit `native_rc'
    }

    ereturn local fvgen_margins "1"
    ereturn local fvgen_flat_cmdline `"`cmdline'"'
    ereturn local fvgen_native_cmdline `"`native_cmdline'"'
end
