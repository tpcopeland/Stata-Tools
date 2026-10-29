*! asof Version 0.1.2  2026/10/29
*! Attach measurement values selected relative to a reference date
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Requires: Stata 16.0+

program define asof, rclass sortpreserve
    version 16.0

    local _orig_matastrict = c(matastrict)
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _event_made = 0
    local _key_made = 0
    local _master_link_made = 0
    local _return_ready = 0
    local _labels_snapped = 0
    local _labels_before ""
    local _frget_vars ""
    local _lang_restore ""

    tempname eventframe keyframe
    tempvar keyok eventorder eventkey pick keylink masterlink

    capture noisily {
        **# Syntax parsing
        syntax anything(name=carry id="variables to carry") [if] [in] using/ , ///
            ID(varname) DATE(name) ANCHOR(varname) ///
            DIRection(string) SELect(string) ///
            [WINdow(string) ///
             RANGE(varlist min=2 max=2) ///
             REQuire(string asis) ///
             SUFfix(string) PREfix(string) GENerate(namelist) ///
             DATEName(name) GAPName(name) MATCHName(name) ///
             TIES(string) FRAME(name) replace NOWARN NOIsily]

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
            * Keep literal endpoints: numlist normalization rounds decimals.
            local window = subinstr("`window'", ",", " ", .)
            if `: word count `window'' != 2 {
                display as error "window() requires two numeric endpoints"
                exit 198
            }
            local winlow : word 1 of `window'
            local winhigh : word 2 of `window'
            foreach endpoint in winlow winhigh {
                if !regexm("``endpoint''", "^[.][a-z]?$") {
                    capture confirm number ``endpoint''
                    if _rc {
                        display as error "window() requires numeric endpoints"
                        exit 198
                    }
                }
            }
            if !missing(`winlow') & !missing(`winhigh') {
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

        * Reserved words (_N, _b, in, _all) pass confirm new variable but fail
        * at creation; probe every output name before any user data changes.
        tempname nameframe
        frame create `nameframe'
        local badname ""
        foreach out of local allout {
            capture frame `nameframe': generate byte `out' = .
            if _rc {
                local badname "`out'"
                continue, break
            }
        }
        frame drop `nameframe'
        if "`badname'" != "" {
            display as error "`badname' is not a valid output variable name"
            exit 198
        }

        _asof_load_using, frame(`eventframe') id(`id') date(`date') ///
            carry(`carry') require(`require') ///
            order(`eventorder') eventkey(`eventkey')
        local N_using = r(N_using)
        local N_events = r(N_events)
        local using_idtype "`r(idtype)'"
        * Units are classified without the justification flag: %-tc and %~tc are %tc.
        local datefmt = regexr("`r(date_format)'", "^%[-~]", "%")

        if "`master_idtype'" != "`using_idtype'" {
            display as error "id() must have the same numeric or string type in master and using data"
            exit 109
        }

        local anchorfmt : format `anchor'
        local anchorfmt = regexr("`anchorfmt'", "^%[-~]", "%")
        local date_tc = (substr("`datefmt'", 1, 3) == "%tc")
        local anchor_tc = (substr("`anchorfmt'", 1, 3) == "%tc")
        local date_td = (substr("`datefmt'", 1, 3) == "%td")
        local anchor_td = (substr("`anchorfmt'", 1, 3) == "%td")

        if (substr("`datefmt'", 1, 2) == "%t" & !`date_tc' & !`date_td') | ///
           (substr("`anchorfmt'", 1, 2) == "%t" & !`anchor_tc' & !`anchor_td') {
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
            local boundfmt = regexr("`boundfmt'", "^%[-~]", "%")
            local bound_tc = (substr("`boundfmt'", 1, 3) == "%tc")
            local bound_td = (substr("`boundfmt'", 1, 3) == "%td")
            if substr("`boundfmt'", 1, 2) == "%t" & !`bound_tc' & !`bound_td' {
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

        * frget copies value-label sets into the master; note the existing
        * ones so cleanup can drop any this call adds but does not use.
        quietly label dir
        local _labels_before "`r(names)'"
        local _labels_snapped = 1
        local gotvars ""
        foreach keysource of local key_sources {
            tempvar got
            local _frget_vars `_frget_vars' `got'
            quietly frget `got' = `keysource', from(`masterlink')
            local gotvars `gotvars' `got'
        }
        tempvar gotdate gotgap gotmatch
        local _frget_vars `_frget_vars' `gotdate' `gotgap' `gotmatch'
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

        * A replaced output takes the carried value and variable labels in
        * every label language, as clonevar gives a new output. Refuse when
        * rows outside the update keep values (extended missing codes
        * included) whose value label in some language differs in contents
        * from the carried one: no one label fits both sets of rows.
        * Read the languages from the chars label language keeps: querying
        * or switching with label language writes those chars even when the
        * data have only the default language.
        local lang_now : char _dta[_lang_c]
        if "`lang_now'" == "" local lang_now "default"
        local langs : char _dta[_lang_list]
        local langs : list langs - lang_now
        local langs `lang_now' `langs'
        local nlangs : word count `langs'
        if `nlangs' > 1 local _lang_restore "`lang_now'"
        local labouts `outvars' `datename'
        local labgots `gotvars'
        if "`datename'" != "" local labgots `labgots' `gotdate'
        local i = 0
        foreach out of local labouts {
            local ++i
            local got : word `i' of `labgots'
            capture confirm numeric variable `out'
            if _rc continue
            quietly count if !`keyok' & (!missing(`out') | `out' > .)
            local nkeep = r(N)
            if `nkeep' == 0 continue
            local conflict ""
            foreach lang of local langs {
                if `nlangs' > 1 quietly label language `lang'
                local oldlab : value label `out'
                local newlab : value label `got'
                local same = ("`oldlab'" == "`newlab'")
                if !`same' & "`oldlab'" != "" & "`newlab'" != "" {
                    mata: st_local("same", ///
                        strofreal(_asof_vlabel_same("`oldlab'", "`newlab'")))
                }
                if !`same' {
                    local conflict "`oldlab'"
                    if "`conflict'" == "" local conflict "(none)"
                    if "`newlab'" == "" local newlab "(none)"
                    if `nlangs' > 1 {
                        local conflict "`conflict' in label language `lang'"
                    }
                    continue, break
                }
            }
            if `nlangs' > 1 quietly label language `lang_now'
            if "`conflict'" != "" {
                local obs = cond(`nkeep' == 1, "observation", "observations")
                display as error "existing variable `out' has value label" ///
                    " `conflict' but the carried values use `newlab'"
                display as error "`nkeep' `obs' outside the update would keep" ///
                    " values coded under the old label; drop or rename `out' first"
                exit 109
            }
        }

        * Summaries come first: summarize, detail needs a free variable slot.
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

        * Every output must fit before the first one is created.
        local nnew = 0
        foreach out in `outvars' `datename' `gapname' `matchname' {
            capture confirm variable `out'
            if _rc local ++nnew
        }
        if c(k) + `nnew' > c(maxvar) {
            display as error "no room for `nnew' new variables;" ///
                " increase set maxvar or drop variables"
            exit 900
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
                _asof_copy_labels `out' `got' `"`langs'"'
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
                _asof_copy_labels `datename' `gotdate' `"`langs'"'
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

        _asof_report, master(`N_master') keys(`N_keys') ///
            matched(`N_matched') unmatched(`N_unmatched') nokey(`N_nokey') ///
            using(`N_using') eligible(`N_eligible') ties(`N_ties') ///
            direction(`direction') select(`select') tierule(`ties') ///
            `nowarn' `noisily'

        local _return_ready = 1
    }
    local rc = _rc
    if `_master_link_made' capture drop `masterlink'
    if "`_lang_restore'" != "" capture label language `_lang_restore'
    if `_labels_snapped' {
        * Drop label sets this call added that no remaining variable uses:
        * all of them after a failure, an unrequested date label on success.
        foreach v of local _frget_vars {
            capture drop `v'
        }
        capture quietly label dir
        if _rc == 0 {
            local _labels_new "`r(names)'"
            local _labels_new : list _labels_new - _labels_before
            local _labels_used ""
            capture unab _allvars : _all
            if _rc local _allvars ""
            foreach v of local _allvars {
                local _labels_used `_labels_used' `: value label `v''
            }
            local _labels_drop : list _labels_new - _labels_used
            if "`_labels_drop'" != "" capture label drop `_labels_drop'
        }
    }
    if `_key_made' capture frame drop `keyframe'
    if `_event_made' capture frame drop `eventframe'
    set matastrict `_orig_matastrict'
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

* Give a replaced output the source's variable and value labels in every
* label language, then return to the first (current) language.
capture program drop _asof_copy_labels
program define _asof_copy_labels
    version 16.0
    args out src langs
    local lang_now : word 1 of `langs'
    local nlangs : word count `langs'
    capture confirm numeric variable `out'
    local numeric = (_rc == 0)
    foreach lang of local langs {
        if `nlangs' > 1 quietly label language `lang'
        if `numeric' {
            local vl : value label `src'
            label values `out' `vl'
        }
        local varlab : variable label `src'
        label variable `out' `"`varlab'"'
    }
    if `nlangs' > 1 quietly label language `lang_now'
end
