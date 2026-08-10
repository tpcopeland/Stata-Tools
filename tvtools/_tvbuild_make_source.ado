*! _tvbuild_make_source Version 1.15.0  2026/08/10
*! Turn one tvbuild specification row into one normalised interval frame
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

* One specification row in, one normalised interval frame out. Every source --
* raw categorical episodes or an already-constructed interval table -- leaves
* this program in exactly the same shape:
*
*     <id>  <startname>  <stopname>  <mapped output payload ...>
*
* so the stage that follows (a merge over several of them, or a straight
* hand-off when there is only one) never has to know which kind it came from.
*
* An `episodes' row is built by the SHARED Phase 3 constructor,
* _tvexpose_fast_build, not by a private tiling written for tvbuild. That is the
* whole point of Section 12.6: tvbuild is a coordinator, and a second
* implementation of interval semantics inside it would be a second thing to
* keep correct. The surrounding work -- clipping, the reference value label,
* the output variable label -- mirrors tvexpose's own finalisation so that the
* frozen-tvexpose oracle in QA compares two spellings of one answer rather than
* two answers.
*
* An `intervals' row is copied, selected, and renamed. It is not clipped,
* re-tiled, or reinterpreted: the user constructed it deliberately, and the
* preflight has already refused it if it does not satisfy the contract.
*
* Returns:
*   r(N_out)      rows in the normalised frame
*   r(N_persons)  distinct persons in the normalised frame

capture program drop _tvbuild_make_source
program define _tvbuild_make_source, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _caller_frame "`c(frame)'"
    set varabbrev off

    capture noisily {

    syntax , PLANframe(name) INDEX(integer) OUTframe(name) ///
        XWALKframe(name) ID(name) ENTry(name) EXIt(name) ///
        STARTName(name) STOPName(name) ///
        IDISstr(integer) MASTERIDtype(string) ///
        [MASTERWindows(string)]

    frame change `planframe'
    local _name = source_name[`index']
    local _kind = source_kind[`index']
    local _fr   = source_frame[`index']
    local _sv   = start_var[`index']
    local _pv   = stop_var[`index']
    local _iv   = input_vars[`index']
    local _ov   = output_vars[`index']
    local _ref  = reference[`index']
    local _rlab = reference_label[`index']
    local _vlab = variable_label[`index']
    frame change `_caller_frame'
    local _where "source `index' (`_name')"

    _tvbuild_load_source, srcframe(`_fr') workframe(`outframe') ///
        xwalkframe(`xwalkframe') where("`_where'") ///
        id(`id') entry(`entry') exit(`exit') ///
        startvar(`_sv') stopvar(`_pv') payload(`_iv') ///
        idisstr(`idisstr') masteridtype(`masteridtype')

    frame change `outframe'

    if "`_kind'" == "episodes" {
        **# Raw categorical episodes -> the shared Phase 3 constructor

        * Restrict to the retained, clipped episodes. Both conditions match the
        * preflight exactly: a row whose person is not in the master, or which
        * lies wholly outside that person's window, was already counted and
        * reported and takes no part in the tiling.
        quietly keep if _tvp_matched == 1 & ///
            !(_tvp_stop < _tvp_entry | _tvp_start > _tvp_exit)
        quietly replace _tvp_start = max(_tvp_start, _tvp_entry)
        quietly replace _tvp_stop  = min(_tvp_stop,  _tvp_exit)

        keep `id' _tvp_start _tvp_stop _tvp_p1 _tvp_entry _tvp_exit

        * The constructor reads fixed names. Rename the identifier FIRST: a
        * caller whose id() happens to be named exp_start or study_entry would
        * otherwise collide with the name about to be created for a bound.
        if "`id'" != "id" quietly rename `id' id
        quietly rename _tvp_start exp_start
        quietly rename _tvp_stop  exp_stop
        quietly rename _tvp_p1    exp_value
        quietly rename _tvp_entry study_entry
        quietly rename _tvp_exit  study_exit

        * The exposure variable's own label is what tvexpose reports when
        * label() is not given; read it before the constructor promotes the
        * column to double.
        local _srclab : variable label exp_value
        local _srctype : type exp_value

        if `"`masterwindows'"' == "" {
            frame change `_caller_frame'
            noisily display as error ///
                "`_where': an episodes source needs masterwindows()"
            exit 198
        }
        _tvexpose_fast_build, reference(`_ref') masterfile(`"`masterwindows'"')
        local _n_out = r(N_rows)

        * ---- the reference value label ---------------------------------
        * This mirrors tvexpose's finalisation exactly, because QA compares the
        * two. When the source exposure already carries a value label, the
        * reference code is added to that label; when it does not, a new label
        * gives every observed code its own number as text and the reference
        * code the reference label.
        if `"`_rlab'"' == "" local _rlab "Unexposed"
        local _outvar : word 1 of `_ov'
        local _exp_vallabel : value label exp_value
        if "`_exp_vallabel'" != "" {
            capture label define `_exp_vallabel' `_ref' `"`_rlab'"', modify
            if _rc capture label define `_exp_vallabel' `_ref' `"`_rlab'"', add
        }
        else {
            local _short = substr("`_outvar'", 1, 25)
            local _newlbl "_tvlbl_`_short'"
            quietly levelsof exp_value, local(_allvals)
            label define `_newlbl' `_ref' `"`_rlab'"', replace
            foreach _v of local _allvals {
                if `_v' != `_ref' label define `_newlbl' `_v' "`_v'", add
            }
            label values exp_value `_newlbl'
        }

        * ---- the output variable label ---------------------------------
        if `"`_vlab'"' != "" local _outlab `"`_vlab'"'
        else if `"`_srclab'"' != "" local _outlab `"`_srclab'"'
        else local _outlab "Exposure variable"
        label variable exp_value `"`_outlab'"'

        * The constructor promotes the category column to double so a study
        * bound cannot overflow it. tvexpose restores the narrow type with its
        * closing compress; do the same, and only for the payload -- the bounds
        * stay double and get dateformat() at finalisation.
        quietly compress exp_value

        * Bounds and payload first, identifier last. The reverse order breaks
        * for a caller whose id() is named exp_start: renaming id to that name
        * while the column still exists is a collision, and the collision-free
        * bound stub the caller chose is what makes this order safe.
        keep id exp_start exp_stop exp_value
        quietly rename exp_start `startname'
        quietly rename exp_stop  `stopname'
        quietly rename exp_value `_outvar'
        if "`id'" != "id" quietly rename id `id'
    }
    else {
        **# Already-constructed intervals -> select and rename only

        quietly keep if _tvp_matched == 1
        local _keep "`id' _tvp_start _tvp_stop"
        local _p = 0
        foreach v of local _iv {
            local ++_p
            local _keep "`_keep' _tvp_p`_p'"
        }
        keep `_keep'
        quietly rename _tvp_start `startname'
        quietly rename _tvp_stop  `stopname'
        local _p = 0
        foreach v of local _iv {
            local ++_p
            local _o : word `_p' of `_ov'
            quietly rename _tvp_p`_p' `_o'
        }
        local _n_out = _N
    }

    * Bounds are doubles everywhere downstream: the merge engine, the event
    * engine, and the committed schema all read them as daily dates.
    quietly recast double `startname'
    quietly recast double `stopname'
    local _n_out = _N

    * Per-source coverage is NOT recomputed here. The preflight already
    * measured it on the validated source, and the exact interval union that
    * _tvbuild_combine runs on the accumulated frame verifies the whole
    * construction -- a gap or an overlap introduced by one source survives
    * into the aligned result, so a second per-source union costs a full sort
    * and several by-passes per source to re-prove what the next stage proves
    * anyway. It was measured at 0.56 s of a 2.9 s run before it was removed.
    tempvar _tag
    quietly egen byte `_tag' = tag(`id')
    quietly count if `_tag'
    local _n_pers = r(N)
    drop `_tag'

    frame change `_caller_frame'

    return scalar N_persons = `_n_pers'
    return scalar N_out = `_n_out'

    }
    local rc = _rc

    capture frame change `_caller_frame'
    local _crc = _rc
    set varabbrev `_orig_varabbrev'
    if !`rc' & `_crc' local rc = `_crc'
    if `rc' exit `rc'
end
