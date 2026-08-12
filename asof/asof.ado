*! asof Version 0.1.0  2026/08/12
*! Attach measurement values selected relative to a reference date
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Requires: Stata 16.0+

program define asof, rclass sortpreserve
    version 16.0

    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _event_made = 0
    local _key_made = 0
    local _master_link_made = 0
    local _return_ready = 0

    tempname eventframe keyframe
    tempvar keyok eventorder eventkey pick keylink masterlink

    capture noisily {
        **# Syntax parsing
        syntax anything(name=carry id="variables to carry") [if] [in] using/ , ///
            ID(varname) DATE(name) ANCHOR(varname) ///
            DIRection(string) SELect(string) ///
            [WINdow(numlist min=2 max=2 missingokay) ///
             RANGE(varlist min=2 max=2) ///
             REQuire(string asis) ///
             SUFfix(string) PREfix(string) GENerate(namelist) ///
             DATEName(name) GAPName(name) MATCHName(name) ///
             TIES(string) FRAME(name) replace nowarn NOIsily]

        _asof_parse_rules, direction(`direction') select(`select') ties(`ties')
        local direction "`r(direction)'"
        local select "`r(select)'"
        local ties "`r(ties)'"

        local carry = strtrim(`"`carry'"')
        if `"`carry'"' == "" {
            display as error "at least one variable to carry is required"
            exit 198
        }

        if "`prefix'" != "" & "`suffix'" != "" {
            display as error "prefix() and suffix() may not be combined"
            exit 198
        }

        **# Master sample and type validation
        marksample touse, novarlist strok
        quietly count if `touse'
        local N_master = r(N)
        if `N_master' == 0 {
            display as error "no master observations selected"
            exit 2000
        }

        capture confirm numeric variable `anchor'
        if _rc {
            display as error "anchor() must name a numeric daily or %tc variable"
            exit 109
        }
        foreach bound of local range {
            capture confirm numeric variable `bound'
            if _rc {
                display as error "range() variables must be numeric"
                exit 109
            }
        }

        capture confirm numeric variable `id'
        if _rc == 0 local master_idtype "numeric"
        else {
            capture confirm string variable `id'
            if _rc {
                display as error "id() must be numeric or string"
                exit 109
            }
            local master_idtype "string"
        }

        quietly generate byte `keyok' = `touse'
        quietly markout `keyok' `id' `anchor', strok
        quietly count if `keyok'
        local N_keyrows = r(N)
        local N_nokey = `N_master' - `N_keyrows'
        if `N_keyrows' == 0 {
            display as error "no observations with nonmissing id() and anchor()"
            exit 2000
        }

        local winlow "."
        local winhigh "."
        if "`window'" != "" {
            local winlow : word 1 of `window'
            local winhigh : word 2 of `window'
            if "`winlow'" != "." & "`winhigh'" != "." {
                if `winlow' > `winhigh' {
                    display as error "window() lower bound may not exceed its upper bound"
                    exit 198
                }
            }
        }

        **# Load and prepare using data without unloading the master
        if "`frame'" != "" {
            capture confirm frame `frame'
            if _rc {
                display as error "frame `frame' not found"
                exit 111
            }
            quietly frame copy `frame' `eventframe'
            local _event_made = 1
        }
        else {
            frame create `eventframe'
            local _event_made = 1
            frame `eventframe': quietly use `"`using'"', clear
        }

        capture frame `eventframe': unab resolved_carry : `carry'
        if _rc {
            display as error "carried varlist did not identify variables in using data"
            exit 111
        }
        local carry `resolved_carry'
        local ncarry : word count `carry'
        local carry_unique : list uniq carry
        local ncarry_unique : word count `carry_unique'
        if `ncarry_unique' != `ncarry' {
            display as error "variables to carry may not be repeated"
            exit 198
        }

        if "`require'" == "" local require `carry'
        else {
            capture frame `eventframe': unab resolved_require : `require'
            if _rc {
                display as error "require() varlist did not identify variables in using data"
                exit 111
            }
            local require_unique : list uniq resolved_require
            local require `require_unique'
        }

        if "`generate'" != "" {
            local ngenerate : word count `generate'
            if `ngenerate' != `ncarry' {
                display as error "generate() must contain one name for each carried variable"
                exit 198
            }
            local outvars `generate'
        }
        else {
            if "`prefix'" == "" & "`suffix'" == "" local suffix "_asof"
            foreach var of local carry {
                local out "`prefix'`var'`suffix'"
                if strlen("`out'") > 32 {
                    display as error "generated variable name `out' exceeds 32 characters"
                    exit 198
                }
                capture confirm name `out'
                if _rc {
                    display as error "generated variable name `out' is invalid"
                    exit 198
                }
                local outvars `outvars' `out'
            }
        }

        local allout `outvars' `datename' `gapname' `matchname'
        local allout : list retokenize allout
        local allout_unique : list uniq allout
        local nall : word count `allout'
        local nall_unique : word count `allout_unique'
        if `nall' != `nall_unique' {
            display as error "output variable names must be distinct"
            exit 198
        }

        local structural `id' `anchor' `range'
        foreach out of local allout {
            if `: list out in structural' {
                display as error "output variable `out' conflicts with an id, anchor, or range variable"
                exit 198
            }
            if "`replace'" == "" {
                capture confirm new variable `out'
                if _rc {
                    display as error "variable `out' already exists; specify replace to overwrite it"
                    exit 110
                }
            }
        }

        _asof_load_using, frame(`eventframe') id(`id') date(`date') ///
            carry(`carry') require(`require') ///
            order(`eventorder') eventkey(`eventkey')
        local N_using = r(N_using)
        local N_events = r(N_events)
        local using_idtype "`r(idtype)'"
        local datefmt "`r(date_format)'"

        if "`master_idtype'" != "`using_idtype'" {
            display as error "id() must have the same numeric or string type in master and using data"
            exit 109
        }

        local anchorfmt : format `anchor'
        local datefmt_l = lower("`datefmt'")
        local anchorfmt_l = lower("`anchorfmt'")
        local date_tc = (substr("`datefmt_l'", 1, 3) == "%tc")
        local anchor_tc = (substr("`anchorfmt_l'", 1, 3) == "%tc")
        local date_td = (substr("`datefmt_l'", 1, 3) == "%td")
        local anchor_td = (substr("`anchorfmt_l'", 1, 3) == "%td")

        if (substr("`datefmt_l'", 1, 2) == "%t" & !`date_tc' & !`date_td') | ///
           (substr("`anchorfmt_l'", 1, 2) == "%t" & !`anchor_tc' & !`anchor_td') {
            display as error "date() and anchor() must use daily dates or %tc datetimes"
            exit 109
        }
        if `date_tc' != `anchor_tc' {
            display as error "date() and anchor() use incompatible daily-date and %tc units"
            exit 109
        }
        local scale = cond(`date_tc', 86400000, 1)

        foreach bound of local range {
            local boundfmt : format `bound'
            local boundfmt_l = lower("`boundfmt'")
            local bound_tc = (substr("`boundfmt_l'", 1, 3) == "%tc")
            local bound_td = (substr("`boundfmt_l'", 1, 3) == "%td")
            if substr("`boundfmt_l'", 1, 2) == "%t" & !`bound_tc' & !`bound_td' {
                display as error "range() variables must use daily dates or %tc datetimes"
                exit 109
            }
            if `bound_tc' != `date_tc' {
                display as error "range() and date() use incompatible daily-date and %tc units"
                exit 109
            }
        }

        **# Build one row per distinct master key
        quietly frame put `id' `anchor' `range' if `keyok', into(`keyframe')
        local _key_made = 1

        if "`range'" != "" {
            gettoken rangelow rangehigh : range
            tempvar rangeok
            frame `keyframe': quietly sort `id' `anchor'
            frame `keyframe': quietly by `id' `anchor': generate byte `rangeok' = ///
                (`rangelow' == `rangelow'[1] | ///
                 (missing(`rangelow') & missing(`rangelow'[1]))) & ///
                (`rangehigh' == `rangehigh'[1] | ///
                 (missing(`rangehigh') & missing(`rangehigh'[1])))
            frame `keyframe': quietly count if !`rangeok'
            if r(N) > 0 {
                display as error "range() bounds vary within an identical id/anchor key"
                exit 459
            }
            frame `keyframe': quietly count if !missing(`rangelow') & ///
                !missing(`rangehigh') & `rangelow' > `rangehigh'
            if r(N) > 0 {
                display as error "range() lower bound exceeds its upper bound"
                exit 459
            }
            frame `keyframe': quietly drop `rangeok'
        }
        else {
            local rangelow ""
            local rangehigh ""
        }

        frame `keyframe': quietly duplicates drop `id' `anchor', force
        frame `keyframe': quietly sort `id' `anchor'
        frame `keyframe': quietly count
        local N_keys = r(N)

        **# Mata scan and key-level result frame
        local range_opts ""
        if "`rangelow'" != "" {
            local range_opts "rangelow(`rangelow') rangehigh(`rangehigh')"
        }
        _asof_join, keyframe(`keyframe') eventframe(`eventframe') ///
            id(`id') anchor(`anchor') date(`date') order(`eventorder') ///
            pick(`pick') idtype(`master_idtype') direction(`direction') ///
            select(`select') ties(`ties') winlow(`winlow') ///
            winhigh(`winhigh') scale(`scale') ///
            `range_opts'
        local N_eligible = r(N_eligible)
        local N_ties = r(N_ties)

        frame `keyframe': quietly frlink m:1 `pick', ///
            frame(`eventframe' `eventkey') generate(`keylink')

        local evdate_base "asof_matchdate"
        local evdate "`evdate_base'"
        local evdate_index = 0
        while 1 {
            capture frame `eventframe': confirm new variable `evdate'
            if _rc == 0 continue, break
            local ++evdate_index
            if `evdate_index' > 999999 {
                display as error "could not allocate an internal event-date variable"
                exit 110
            }
            local evdate "`evdate_base'`evdate_index'"
        }
        frame `eventframe': quietly clonevar `evdate' = `date'

        local event_sources ""
        local key_sources ""
        local i = 0
        foreach source of local carry {
            local ++i
            local evsource "asof_event`i'"
            while 1 {
                capture frame `eventframe': confirm new variable `evsource'
                if _rc == 0 continue, break
                local evsource "`evsource'x"
                if strlen("`evsource'") > 32 {
                    display as error "could not allocate an internal event variable"
                    exit 110
                }
            }
            frame `eventframe': quietly rename `source' `evsource'

            local keysource "asof_result`i'"
            while 1 {
                capture frame `keyframe': confirm new variable `keysource'
                if _rc == 0 continue, break
                local keysource "`keysource'x"
                if strlen("`keysource'") > 32 {
                    display as error "could not allocate an internal result variable"
                    exit 110
                }
            }
            frame `keyframe': quietly frget `keysource' = `evsource', from(`keylink')
            local event_sources `event_sources' `evsource'
            local key_sources `key_sources' `keysource'
        }

        local keydate "asof_matchdate"
        while 1 {
            capture frame `keyframe': confirm new variable `keydate'
            if _rc == 0 continue, break
            local keydate "`keydate'x"
        }
        frame `keyframe': quietly frget `keydate' = `evdate', from(`keylink')

        local keygap "asof_gapdays"
        while 1 {
            capture frame `keyframe': confirm new variable `keygap'
            if _rc == 0 continue, break
            local keygap "`keygap'x"
        }
        frame `keyframe': quietly generate double `keygap' = (`keydate' - `anchor') / `scale'

        local keymatch "asof_matched"
        while 1 {
            capture frame `keyframe': confirm new variable `keymatch'
            if _rc == 0 continue, break
            local keymatch "`keymatch'x"
        }
        frame `keyframe': quietly generate byte `keymatch' = !missing(`pick')

        **# Attach key-level results while preserving if/in and missing-key rows
        quietly frlink m:1 `id' `anchor', frame(`keyframe' `id' `anchor') ///
            generate(`masterlink')
        local _master_link_made = 1

        local gotvars ""
        foreach keysource of local key_sources {
            tempvar got
            quietly frget `got' = `keysource', from(`masterlink')
            local gotvars `gotvars' `got'
        }
        tempvar gotdate gotgap gotmatch
        quietly frget `gotdate' = `keydate', from(`masterlink')
        quietly frget `gotgap' = `keygap', from(`masterlink')
        quietly frget `gotmatch' = `keymatch', from(`masterlink')

        * Validate every replacement type before mutating any user variable.
        local i = 0
        foreach out of local outvars {
            local ++i
            local got : word `i' of `gotvars'
            capture confirm variable `out'
            if _rc == 0 {
                capture confirm numeric variable `got'
                local got_numeric = (_rc == 0)
                capture confirm numeric variable `out'
                local out_numeric = (_rc == 0)
                if `got_numeric' != `out_numeric' {
                    display as error "existing variable `out' has an incompatible type"
                    exit 109
                }
            }
        }
        foreach out in `datename' `gapname' `matchname' {
            if "`out'" != "" {
                capture confirm variable `out'
                if _rc == 0 {
                    capture confirm numeric variable `out'
                    if _rc {
                        display as error "existing variable `out' must be numeric"
                        exit 109
                    }
                }
            }
        }

        local i = 0
        foreach out of local outvars {
            local ++i
            local got : word `i' of `gotvars'
            capture confirm variable `out'
            if _rc {
                quietly clonevar `out' = `got'
                capture confirm string variable `out'
                if _rc == 0 quietly replace `out' = "" if !`keyok'
                else quietly replace `out' = . if !`keyok'
            }
            else {
                capture confirm string variable `out'
                if _rc == 0 quietly recast strL `out'
                else quietly recast double `out'
                quietly replace `out' = `got' if `keyok'
            }
        }

        if "`datename'" != "" {
            capture confirm variable `datename'
            if _rc {
                quietly clonevar `datename' = `gotdate'
                quietly replace `datename' = . if !`keyok'
            }
            else {
                quietly recast double `datename'
                quietly replace `datename' = `gotdate' if `keyok'
            }
        }
        if "`gapname'" != "" {
            capture confirm variable `gapname'
            if _rc quietly generate double `gapname' = `gotgap' if `keyok'
            else {
                quietly recast double `gapname'
                quietly replace `gapname' = `gotgap' if `keyok'
            }
            label variable `gapname' "Signed days from anchor to as-of measurement"
        }
        if "`matchname'" != "" {
            capture confirm variable `matchname'
            if _rc quietly generate byte `matchname' = `gotmatch' if `keyok'
            else {
                quietly recast double `matchname'
                quietly replace `matchname' = `gotmatch' if `keyok'
            }
            label variable `matchname' "As-of record matched"
        }

        quietly count if `keyok' & `gotmatch' == 1
        local N_matched = r(N)
        local N_unmatched = `N_keyrows' - `N_matched'

        local gap_min = .
        local gap_max = .
        local gap_mean = .
        local gap_p50 = .
        if `N_matched' > 0 {
            quietly summarize `gotgap' if `keyok' & `gotmatch' == 1, detail
            local gap_min = r(min)
            local gap_max = r(max)
            local gap_mean = r(mean)
            local gap_p50 = r(p50)
        }

        _asof_report, master(`N_master') keys(`N_keys') ///
            matched(`N_matched') unmatched(`N_unmatched') nokey(`N_nokey') ///
            using(`N_using') eligible(`N_eligible') ties(`N_ties') ///
            direction(`direction') select(`select') tierule(`ties') ///
            `nowarn' `noisily'

        local _return_ready = 1
    }
    local rc = _rc
    if `_master_link_made' capture drop `masterlink'
    if `_key_made' capture frame drop `keyframe'
    if `_event_made' capture frame drop `eventframe'
    set varabbrev `_orig_varabbrev'

    if `rc' == 0 & `_return_ready' {
        return clear
        return scalar N_master = `N_master'
        return scalar N_keys = `N_keys'
        return scalar N_matched = `N_matched'
        return scalar N_unmatched = `N_unmatched'
        return scalar N_nokey = `N_nokey'
        return scalar N_using = `N_using'
        return scalar N_eligible = `N_eligible'
        return scalar N_ties = `N_ties'
        return scalar gap_min = `gap_min'
        return scalar gap_max = `gap_max'
        return scalar gap_mean = `gap_mean'
        return scalar gap_p50 = `gap_p50'
        return local varlist "`carry'"
        return local generate "`outvars'"
        return local direction "`direction'"
        return local select "`select'"
        return local ties "`ties'"
    }
    if `rc' exit `rc'
end
