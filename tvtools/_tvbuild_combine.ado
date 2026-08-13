*! _tvbuild_combine Version 1.16.0  2026/08/13
*! Align tvbuild's normalised source frames into one accumulated interval frame
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

* One source: there is nothing to align, so the normalised frame IS the
* accumulated frame and only its bound names change. Two or more: the shared
* tvmerge interval engine intersects them in specification order, which is the
* order the plan frame fixes and the order sequential total apportionment makes
* observable.
*
* The merge runs from an EMPTY scratch frame, and that is not cosmetic. The
* engine snapshots whatever data the calling frame holds so that a failure can
* put it back; called from the user's master it would write the master to a
* tempfile on every run. Called from a frame with no variables and no
* observations it writes nothing, which is what lets a tvbuild run stay free of
* .dta round trips for the data it is actually building.
*
* The engine's own output key is asserted, not assumed. tvmerge committed its
* key as the literal name `id' until idname() was added; a coordinator that
* took the name on faith would silently produce a differently-keyed result on
* an older build. See shared-02 Section 5.3a of the single-pass plan.
*
* Coverage is measured on the accumulated frame BEFORE the event stage, by
* interval union rather than by summing row lengths. Split output deliberately
* represents some days more than once, and summing counts those days twice --
* which would report full coverage for a person who has a real gap.
*
* Returns:
*   r(N_out)          rows in the accumulated frame
*   r(N_in)           rows read from the normalised sources
*   r(N_persons)      distinct persons in the accumulated frame
*   r(n_gap_ids)      persons with uncovered time
*   r(uncovered_days) inclusive uncovered person-days
*   r(merged)         1 when the merge engine ran, 0 for the one-source bypass

capture program drop _tvbuild_combine
program define _tvbuild_combine, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _caller_frame "`c(frame)'"
    set varabbrev off

    capture noisily {

    syntax , SRCframes(namelist) OUTframe(name) VOIDframe(name) ///
        XWALKframe(name) ID(name) ENTry(name) EXIt(name) ///
        STARTName(name) STOPName(name) DATEFormat(string) ///
        SNAMES(string) ENAMES(string) EXPVars(string) STUB(string) ///
        COVerage(string) ///
        [RATEVars(string) TOTALVars(string) CUMVars(string)]

    local _n : word count `srcframes'
    local _n_in = 0
    foreach _f of local srcframes {
        frame change `_f'
        local _n_in = `_n_in' + _N
        frame change `_caller_frame'
    }

    if `_n' == 1 {
        **# One source: no merge, no reordering, no engine
        local _sf : word 1 of `srcframes'
        local _sn : word 1 of `snames'
        local _en : word 1 of `enames'
        capture frame drop `outframe'
        frame copy `_sf' `outframe'
        frame change `outframe'
        if "`_sn'" != "`startname'" quietly rename `_sn' `startname'
        if "`_en'" != "`stopname'"  quietly rename `_en' `stopname'
        sort `id' `startname' `stopname'
        frame change `_caller_frame'
        local _merged = 0
    }
    else {
        **# Two or more: the shared merge engine, in specification order
        local _mopts ""
        if "`ratevars'"  != "" local _mopts `"`_mopts' rate(`ratevars')"'
        if "`totalvars'" != "" local _mopts `"`_mopts' total(`totalvars')"'
        if "`cumvars'"   != "" local _mopts `"`_mopts' cumulative(`cumvars')"'

        capture frame drop `outframe'
        frame change `voidframe'
        capture noisily quietly tvmerge, frames(`srcframes') id(`id') ///
            start(`snames') stop(`enames') exposure(`expvars') ///
            idname(`id') startname(`startname') stopname(`stopname') ///
            dateformat(`dateformat') frameout(`outframe') replace `_mopts'
        local _mrc = _rc
        local _idname "`r(idname)'"
        frame change `_caller_frame'
        if `_mrc' {
            noisily display as error ///
                "tvbuild: the interval merge failed (rc=`_mrc'); no destination frame was created or changed"
            exit `_mrc'
        }
        if "`_idname'" != "`id'" {
            noisily display as error ///
                "tvbuild: the merge engine committed its key as '`_idname'' but id(`id') was requested"
            noisily display as error ///
                "this build of tvmerge does not honour idname(); reinstall the package"
            exit 459
        }
        local _merged = 1
    }

    **# Coverage of the master window, before any event work
    frame change `outframe'
    quietly frlink m:1 `id', frame(`xwalkframe')
    quietly frget `stub'ent = `entry', from(`xwalkframe')
    quietly frget `stub'exi = `exit',  from(`xwalkframe')
    capture drop `xwalkframe'

    quietly count if missing(`stub'ent)
    local _orphans = r(N)
    if `_orphans' > 0 {
        frame change `_caller_frame'
        noisily display as error ///
            "tvbuild: `_orphans' constructed row(s) belong to a person who is not in the master"
        exit 459
    }

    * The exact interval union is the authority, and it is expensive: six
    * by-passes over the accumulated frame. Two cheap passes decide first
    * whether it is needed at all. When no row starts on or before its
    * predecessor's stop within person, the rows are disjoint and ordered; when
    * each person's summed row length also equals that person's window length,
    * disjoint rows that sum to the window can only be an exact tiling. Both
    * conditions together prove complete coverage without the union.
    *
    * NEITHER condition alone is enough, which is why both are here. Two
    * identical rows covering half a window sum to the window's length while
    * leaving half of it uncovered; that is the case the disjointness test
    * catches. When either test fails the union runs and supplies the exact
    * counts, so this is a shortcut on the answer's cost, never on the answer.
    sort `id' `startname' `stopname'
    tempvar _tag _ovl _rt
    quietly by `id': generate byte `_ovl' = ///
        (_n > 1) & (`startname' <= `stopname'[_n-1])
    quietly count if `_ovl' == 1
    local _n_ovl = r(N)
    quietly by `id': generate byte `_tag' = (_n == 1)
    local _exact = 0
    if `_n_ovl' == 0 {
        quietly by `id': egen double `_rt' = ///
            total(`stopname' - `startname' + 1)
        quietly count if `_tag' & ///
            `_rt' != (`stub'exi - `stub'ent + 1)
        if r(N) == 0 local _exact = 1
        drop `_rt'
    }

    if `_exact' {
        local _gap_ids = 0
        local _uncovered = 0
        quietly count if `_tag'
        local _n_pers = r(N)
        drop `_tag' `_ovl' `stub'ent `stub'exi
    }
    else {
        drop `_tag' `_ovl'
        _tvtools_interval_union, id(`id') start(`startname') stop(`stopname') ///
            cliplow(`stub'ent) cliphigh(`stub'exi) uniondays(`stub'uni)

        tempvar _tag2 _short
        quietly egen byte `_tag2' = tag(`id')
        quietly generate double `_short' = ///
            (`stub'exi - `stub'ent + 1) - `stub'uni if `_tag2'
        quietly count if `_tag2' & `_short' > 0 & !missing(`_short')
        local _gap_ids = r(N)
        quietly summarize `_short' if `_tag2' & `_short' > 0, meanonly
        local _uncovered = cond(r(N) == 0, 0, r(sum))
        quietly count if `_tag2'
        local _n_pers = r(N)
        drop `_tag2' `_short' `stub'uni `stub'ent `stub'exi
    }
    local _n_out = _N
    sort `id' `startname' `stopname'
    frame change `_caller_frame'

    if `_n_out' == 0 {
        noisily display as error ///
            "tvbuild: the construction produced no rows; nothing was committed"
        exit 2000
    }
    if `_gap_ids' > 0 & "`coverage'" == "strict" {
        noisily display as error ///
            "tvbuild: `_gap_ids' person(s) have uncovered time (`_uncovered' day(s)) after alignment"
        noisily display as error ///
            "cover the gap in the sources, or accept it explicitly with coverage(allow)"
        exit 459
    }

    return scalar merged = `_merged'
    return scalar uncovered_days = `_uncovered'
    return scalar n_gap_ids = `_gap_ids'
    return scalar N_persons = `_n_pers'
    return scalar N_in = `_n_in'
    return scalar N_out = `_n_out'

    }
    local rc = _rc

    capture frame change `_caller_frame'
    local _crc = _rc
    set varabbrev `_orig_varabbrev'
    if !`rc' & `_crc' local rc = `_crc'
    if `rc' exit `rc'
end
