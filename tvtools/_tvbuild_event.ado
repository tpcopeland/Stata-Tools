*! _tvbuild_event Version 1.17.0  2026/08/28
*! Run tvbuild's optional event stage through the shared tvevent engine
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

* The event stage is the shared engine, driven from a scratch frame. Its
* contracts -- primary/competing precedence, same-day rules, first-event
* truncation, recurring wide-stub validation, splitting, and the quantity
* algebra applied across each split -- are the tvevent contracts exactly,
* because they ARE tvevent. tvbuild supplies the interval frame, the mapped
* quantity output names, and nothing else.
*
* The event data are copied into a scratch frame first, so the frame the user
* named -- or the master, when no separate event input was given -- is read but
* never written. Only the identifier, the event date or its wide stub, and the
* competing-risk dates are copied: a wide event file is not a licence to drag
* every column it happens to hold into the committed result.
*
* Event inputs are inputs. The date and competing-risk columns arrive in the
* engine's output because they described what to do, not what was built;
* r(dropvars) names them so the finalisation stage can take them out before the
* committed schema is checked.
*
* Returns:
*   r(N_in)       interval rows before the event stage
*   r(N_out)      interval rows after it
*   r(N_persons)  distinct persons after it
*   r(N_events)   rows flagged with the primary event, when the engine reports it
*   r(dropvars)   event input columns present in the output and owed a drop

capture program drop _tvbuild_event
program define _tvbuild_event, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _caller_frame "`c(frame)'"
    set varabbrev off

    capture noisily {

    syntax , ACCframe(name) EVSRCframe(name) OUTframe(name) ///
        ID(name) EVENTDate(name) STARTName(name) STOPName(name) ///
        [EVENTType(string) EVENTGenerate(name) EVENTLabel(string) ///
         COMpete(string) TIMEGen(name) TIMEUnit(string) ///
         ENUM(name) GAPTime GAPSTArt(name) GAPSTOp(name) ///
         RATEVars(string) TOTALVars(string) CUMVars(string)]

    if "`eventtype'" == "" local eventtype "single"

    frame change `accframe'
    local _n_in = _N
    frame change `_caller_frame'

    **# Resolve the event input columns and copy only those
    frame change `evsrcframe'
    if "`eventtype'" == "recurring" {
        quietly ds `eventdate'*
        local _datevars "`r(varlist)'"
    }
    else {
        local _datevars "`eventdate'"
    }
    local _evvars "`id' `_datevars' `compete'"
    local _evvars : list uniq _evvars
    frame change `_caller_frame'

    capture frame drop `outframe'
    frame `evsrcframe': frame put `_evvars', into(`outframe')

    **# The shared engine
    local _eopts ""
    if "`eventgenerate'" != "" local _eopts `"`_eopts' generate(`eventgenerate')"'
    if "`timegen'"  != "" local _eopts `"`_eopts' timegen(`timegen') timeunit(`timeunit')"'
    if "`compete'"  != "" local _eopts `"`_eopts' compete(`compete')"'
    if "`enum'"     != "" local _eopts `"`_eopts' enum(`enum')"'
    if "`gaptime'"  != "" local _eopts `"`_eopts' gaptime gapstart(`gapstart') gapstop(`gapstop')"'
    if "`ratevars'"  != "" local _eopts `"`_eopts' rate(`ratevars')"'
    if "`totalvars'" != "" local _eopts `"`_eopts' total(`totalvars')"'
    if "`cumvars'"   != "" local _eopts `"`_eopts' cumulative(`cumvars')"'
    * eventlabel() is forwarded UNWRAPPED, unlike every other option here.
    * tvevent declares it `string asis' and splices the value straight into
    * `label define <name> <eventlabel>, modify', so it must arrive as the
    * bare `value "Label"' pair grammar the user typed. Re-wrapping it in
    * compound quotes -- correct for a plain `string' destination -- makes
    * `asis' hand tvevent one quoted string instead of a pair, and every
    * eventlabel() value fails with r(198).
    if `"`eventlabel'"' != "" local _eopts `"`_eopts' eventlabel(`eventlabel')"'

    frame change `outframe'
    capture noisily quietly tvevent, frame(`accframe') id(`id') ///
        date(`eventdate') type(`eventtype') ///
        start(`startname') stop(`stopname') `_eopts'
    local _erc = _rc
    local _n_ev = r(N_events)
    frame change `_caller_frame'
    if `_erc' {
        noisily display as error ///
            "tvbuild: the event stage failed (rc=`_erc'); no destination frame was created or changed"
        exit `_erc'
    }

    frame change `outframe'
    local _n_out = _N
    tempvar _tag
    quietly egen byte `_tag' = tag(`id')
    quietly count if `_tag'
    local _n_pers = r(N)
    drop `_tag'

    * Which event input columns actually survived. Naming them by what is
    * present, rather than by what was requested, keeps the drop list honest if
    * the engine's carry-through behaviour ever changes.
    * The stub BASE name is on this list as well as the stub members. A
    * recurring run resolves each person's applicable event into a column named
    * after the stub itself, so eventdate(ev) with members ev1 ev2 leaves an
    * `ev' behind that neither member name matches. tvbuild already protects the
    * event-date name against every output name, so dropping it here cannot
    * take a payload with it.
    local _drop ""
    local _cands "`_datevars' `eventdate'"
    local _cands : list uniq _cands
    foreach v of local _cands {
        capture confirm variable `v', exact
        if _rc == 0 local _drop "`_drop' `v'"
    }
    foreach v of local compete {
        capture confirm variable `v', exact
        if _rc == 0 local _drop "`_drop' `v'"
    }
    frame change `_caller_frame'

    return local dropvars = strtrim(stritrim("`_drop'"))
    * `local x = r(name)' evaluates an absent r() to ".", so both spellings of
    * "the engine did not report it" are screened here.
    if "`_n_ev'" != "" & "`_n_ev'" != "." return scalar N_events = `_n_ev'
    return scalar N_persons = `_n_pers'
    return scalar N_out = `_n_out'
    return scalar N_in = `_n_in'

    }
    local rc = _rc

    capture frame change `_caller_frame'
    local _crc = _rc
    set varabbrev `_orig_varabbrev'
    if !`rc' & `_crc' local rc = `_crc'
    if `rc' exit `rc'
end
