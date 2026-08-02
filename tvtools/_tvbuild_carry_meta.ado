*! _tvbuild_carry_meta Version 1.12.1  2026/08/02
*! Carry display format, labels, value labels, and characteristics between frames
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

* Metadata is not a by-product of copying values, and tvtools QA asserts it as
* its own parity category (Section 5.4 of the single-pass plan). A frame copy,
* an frget, a Mata store, and the merge engine each preserve a DIFFERENT subset
* of storage type, display format, variable label, value-label assignment,
* value-label definition, and variable characteristics. tvbuild therefore
* records what each normalised source declared and re-asserts it on the
* finished result rather than trusting any one of those mechanisms.
*
* The characteristic matters most: tvtools_quantity is what the merge and event
* engines read to decide whether a value is carried, apportioned, or held at
* the row start. A result whose values are right but whose characteristic was
* lost hands the next command in the chain the wrong algebra at rc=0.
*
* Value labels are copied by DEFINITION, not by reference. Each frame has its
* own value-label space, so a label that exists in a source frame does not
* exist in the destination merely because the variable arrived. Two sources may
* also use the same label NAME for different definitions; the second one gets a
* collision-safe name from the shared helper rather than silently overwriting
* the first, which would relabel the earlier source's values.
*
* Returns:
*   r(n_vars)     variables whose metadata was carried
*   r(n_labels)   value-label definitions written into the destination
*   r(n_renamed)  value labels that had to be renamed to avoid a collision

version 16.0

capture mata: mata drop _tvp_vlabel_copy()
capture mata: mata drop _tvp_vlabel_same()
capture mata: mata drop _tvp_vlabel_exists()

mata:
mata set matastrict on

// Copy one value-label DEFINITION from srcframe to dstframe under dstlab.
// st_vlload()/st_vlmodify() act on the current frame's label space, so the
// frame has to be switched around each half and restored afterwards.
void _tvp_vlabel_copy(string scalar srcframe, string scalar dstframe,
                      string scalar srclab,   string scalar dstlab)
{
    real colvector    v
    string colvector  t
    string scalar     cur
    real scalar       i

    cur = st_framecurrent()
    st_framecurrent(srcframe)
    st_vlload(srclab, v, t)
    st_framecurrent(dstframe)
    for (i = 1; i <= rows(v); i++) st_vlmodify(dstlab, v[i], t[i])
    st_framecurrent(cur)
}

// 1 when dstframe already defines `lab' with exactly the definition srcframe
// gives it. Order is not compared: st_vlload() returns the codes sorted, and
// two identical labels built in different orders are the same label.
real scalar _tvp_vlabel_same(string scalar srcframe, string scalar dstframe,
                             string scalar lab)
{
    real colvector    v1, v2
    string colvector  t1, t2
    string scalar     cur
    real scalar       same

    cur = st_framecurrent()
    st_framecurrent(srcframe)
    st_vlload(lab, v1, t1)
    st_framecurrent(dstframe)
    if (!st_vlexists(lab)) {
        st_framecurrent(cur)
        return(0)
    }
    st_vlload(lab, v2, t2)
    st_framecurrent(cur)

    same = 0
    if (rows(v1) == rows(v2)) {
        if (rows(v1) == 0) same = 1
        else same = (v1 == v2) & (t1 == t2)
    }
    return(same)
}

real scalar _tvp_vlabel_exists(string scalar frame, string scalar lab)
{
    string scalar cur
    real scalar   e

    cur = st_framecurrent()
    st_framecurrent(frame)
    e = st_vlexists(lab)
    st_framecurrent(cur)
    return(e)
}
end


capture program drop _tvbuild_carry_meta
program define _tvbuild_carry_meta, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _caller_frame "`c(frame)'"
    set varabbrev off

    capture noisily {

    syntax , SRCframe(name) DSTframe(name) VARS(string) [SRCVars(string)]

    if "`srcvars'" == "" local srcvars "`vars'"
    local _nd : word count `vars'
    local _ns : word count `srcvars'
    if `_nd' != `_ns' {
        noisily display as error ///
            "_tvbuild_carry_meta: vars() has `_nd' name(s) and srcvars() has `_ns'"
        exit 198
    }

    local _n_lab = 0
    local _n_ren = 0

    forvalues i = 1/`_nd' {
        local _dv : word `i' of `vars'
        local _sv : word `i' of `srcvars'

        * Read everything the source declares in one visit to that frame.
        frame change `srcframe'
        capture confirm variable `_sv', exact
        if _rc {
            frame change `_caller_frame'
            noisily display as error ///
                "_tvbuild_carry_meta: '`_sv'' not found in `srcframe'"
            exit 111
        }
        local _fmt : format `_sv'
        local _vlb : variable label `_sv'
        local _vll : value label `_sv'
        mata: st_local("_chars", invtokens(st_dir("char", "`_sv'", "*")'))
        foreach _c of local _chars {
            local _charval_`_c' : char `_sv'[`_c']
        }
        frame change `_caller_frame'

        frame change `dstframe'
        capture confirm variable `_dv', exact
        if _rc {
            frame change `_caller_frame'
            noisily display as error ///
                "_tvbuild_carry_meta: '`_dv'' not found in `dstframe'"
            exit 111
        }
        format `_dv' `_fmt'
        label variable `_dv' `"`_vlb'"'
        foreach _c of local _chars {
            char `_dv'[`_c'] `"`_charval_`_c''"'
        }
        frame change `_caller_frame'

        if "`_vll'" != "" {
            * Same name, same definition: nothing to do. Same name, different
            * definition: a new name, because overwriting would silently
            * relabel whichever source got there first.
            mata: st_local("_same", strofreal(_tvp_vlabel_same("`srcframe'", "`dstframe'", "`_vll'")))
            mata: st_local("_exists", strofreal(_tvp_vlabel_exists("`dstframe'", "`_vll'")))
            local _target "`_vll'"
            if `_exists' & !`_same' {
                frame change `dstframe'
                _tvtools_new_vallabel, base(`_vll')
                local _target "`r(name)'"
                frame change `_caller_frame'
                local ++_n_ren
            }
            if !(`_exists' & `_same') {
                mata: _tvp_vlabel_copy("`srcframe'", "`dstframe'", "`_vll'", "`_target'")
                local ++_n_lab
            }
            frame change `dstframe'
            label values `_dv' `_target'
            frame change `_caller_frame'
        }
        * Clear the per-variable char macros so a variable with fewer
        * characteristics than its predecessor cannot inherit a stale one.
        foreach _c of local _chars {
            local _charval_`_c' ""
        }
    }

    return scalar n_renamed = `_n_ren'
    return scalar n_labels = `_n_lab'
    return scalar n_vars = `_nd'

    }
    local rc = _rc

    capture frame change `_caller_frame'
    local _crc = _rc
    set varabbrev `_orig_varabbrev'
    if !`rc' & `_crc' local rc = `_crc'
    if `rc' exit `rc'
end
