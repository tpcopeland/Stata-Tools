*! _stacktab_frames Version 2.6.1  2026/10/09
*! stacktab, frames(): stack in-memory frames as labelled panels via puttab
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
    stacktab [using BOOK.xlsx], frames(name ["Panel label"] [\ name ["label"] ...])
        sheet("Sheet") [title() note()|footnote() csv() markdown() mdappend
        headershade borderstyle() font() fontsize() zebra digits() open]

    Each frame is one panel. Its columns are taken in frame order and stacked
    by position, so every frame must have the same number of columns; the
    header comes from the first frame's variable labels (names when a label
    is empty). A first observation that only repeats the variable labels
    (the header row desctab/table1_tc leave in a clear or frame() table) is
    dropped from each frame. The stacked table is written by puttab with
    panel(): each label becomes a bold heading row with a rule above, and the
    row labels under it are indented. A panel given no label ("" or omitted)
    gets no heading row. Numeric columns are written with their value labels
    or display formats. using may be omitted when tabtools set workbook is in
    effect (puttab resolves it).
*/

program define _stacktab_frames, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _restore_needed = 0
    capture noisily {
        syntax [using/] , FRAMES(string asis) SHeet(string) ///
            [TItle(string) NOte(string) FOOTnote(string) ///
             CSV(string) MARKdown(string) MDAPPend ///
             HEADERShade BORDERstyle(string) FONT(string) ///
             FONTSIZE(integer -1) ZEBra DIGits(integer -1) open]

        if `"`macval(note)'"' != "" & `"`macval(footnote)'"' != "" {
            display as error "note() and footnote() may not be combined"
            exit 198
        }
        if `"`macval(note)'"' == "" local note `"`macval(footnote)'"'

        * ----- parse frames(name ["label"] [\ ...]) -----
        local _spec : copy local frames
        local _nf 0
        while strtrim(`"`macval(_spec)'"') != "" {
            local _spec = strtrim(`"`macval(_spec)'"')
            gettoken _fname _spec : _spec, parse(" \")
            if `"`_fname'"' == "\" {
                display as error "frames(): empty entry; give name [\"label\"] between separators"
                exit 198
            }
            capture confirm name `_fname'
            if _rc {
                display as error `"frames(): `_fname' is not a frame name"'
                exit 198
            }
            capture confirm frame `_fname'
            if _rc {
                display as error "frames(): frame `_fname' not found"
                exit 111
            }
            local _flab ""
            local _spec = strtrim(`"`macval(_spec)'"')
            if substr(`"`macval(_spec)'"', 1, 1) == `"""' | ///
                substr(`"`macval(_spec)'"', 1, 2) == char(96) + `"""' {
                gettoken _flab _spec : _spec, quotes
                local _flab `_flab'
            }
            local _spec = strtrim(`"`macval(_spec)'"')
            if `"`macval(_spec)'"' != "" {
                if substr(`"`macval(_spec)'"', 1, 1) != "\" {
                    display as error `"frames(): separate entries with \ (after `_fname')"'
                    exit 198
                }
                local _spec = substr(`"`macval(_spec)'"', 2, .)
                if strtrim(`"`macval(_spec)'"') == "" {
                    display as error "frames(): trailing \ with no frame after it"
                    exit 198
                }
            }
            local ++_nf
            local _f`_nf' `_fname'
            local _l`_nf' `"`macval(_flab)'"'
            forvalues _j = 1/`=`_nf' - 1' {
                if "`_f`_j''" == "`_fname'" {
                    display as error "frames(): frame `_fname' is listed twice"
                    exit 198
                }
            }
        }
        if `_nf' == 0 {
            display as error "frames() requires at least one frame"
            exit 198
        }

        * ----- stack -----
        preserve
        local _restore_needed = 1
        tempfile _acc _one
        local _K 0
        forvalues _i = 1/`_nf' {
            quietly frame `_f`_i'': save `"`_one'"', replace
            quietly use `"`_one'"', clear
            quietly ds
            local _vars `r(varlist)'
            local _k : word count `_vars'
            if `_k' == 0 {
                display as error "frames(): frame `_f`_i'' has no variables"
                exit 111
            }
            if `_i' == 1 {
                local _K = `_k'
                forvalues _j = 1/`_K' {
                    local _v : word `_j' of `_vars'
                    local _hdr`_j' : variable label `_v'
                    if `"`macval(_hdr`_j')'"' == "" local _hdr`_j' "`_v'"
                }
            }
            else if `_k' != `_K' {
                display as error "frames(): frame `_f`_i'' has `_k' columns; frame `_f1' has `_K'"
                display as error "Hint: frames are stacked by column position, so every frame needs the same columns"
                exit 198
            }
            * Drop an embedded header row: observation 1 that only repeats
            * the variable labels (first column may be blank), all string.
            if _N >= 2 {
                local _ishdr 1
                local _matched 0
                local _j 0
                foreach _v of local _vars {
                    local ++_j
                    capture confirm string variable `_v'
                    if _rc {
                        local _ishdr 0
                        continue, break
                    }
                    local _lbl : variable label `_v'
                    mata: st_local("_cell", strtrim(st_sdata(1, "`_v'")))
                    mata: st_local("_lbl", strtrim(st_local("_lbl")))
                    if `"`macval(_cell)'"' == "" {
                        if `_j' == 1 continue
                        local _ishdr 0
                        continue, break
                    }
                    if `"`macval(_lbl)'"' == "" | `"`macval(_cell)'"' != `"`macval(_lbl)'"' {
                        local _ishdr 0
                        continue, break
                    }
                    local ++_matched
                }
                if `_ishdr' & `_matched' > 0 quietly drop in 1
            }
            if _N == 0 {
                display as error "frames(): frame `_f`_i'' has no observations"
                exit 2000
            }
            * Positional columns as strings: value labels, else display format.
            * Built in tempvars (a frame may hold any variable name), then
            * renamed once the frame's own variables are gone.
            local _j 0
            local _tcols ""
            foreach _v of local _vars {
                local ++_j
                tempvar _t`_j'
                local _tcols "`_tcols' `_t`_j''"
                capture confirm string variable `_v'
                if _rc {
                    local _vl : value label `_v'
                    local _fmt : format `_v'
                    quietly gen strL `_t`_j'' = ""
                    mata: _stacktab_frames_fmt("`_v'", "`_t`_j''", "`_vl'", "`_fmt'")
                }
                else quietly gen strL `_t`_j'' = `_v'
            }
            keep `_tcols'
            forvalues _j = 1/`_K' {
                rename `_t`_j'' _stk_c`_j'
            }
            * One panel per frame: a numeric panel id carrying the label as
            * its value label, so two frames with the same label stay two
            * panels; an unlabeled frame is missing (no heading).
            * stata-dev-ignore: hardcoded-tempname — only tempvars survive the keep above, so no user variable can collide; discarded by restore
            quietly gen long _stk_panel = cond(`"`macval(_l`_i')'"' != "", `_i', .)
            * stata-dev-ignore: hardcoded-tempname — only tempvars survive the keep above, so no user variable can collide; discarded by restore
            quietly gen long _stk_ord = `_i' * 1e7 + _n
            if `_i' > 1 quietly append using `"`_acc'"'
            quietly save `"`_acc'"', replace
        }
        sort _stk_ord
        drop _stk_ord
        tempname _stk_vl
        forvalues _i = 1/`_nf' {
            if `"`macval(_l`_i')'"' != "" label define `_stk_vl' `_i' `"`macval(_l`_i')'"', add
        }
        capture label list `_stk_vl'
        if !_rc label values _stk_panel `_stk_vl'
        forvalues _j = 1/`_K' {
            label variable _stk_c`_j' `"`macval(_hdr`_j')'"'
        }

        local _opts ""
        foreach _o in csv markdown borderstyle font {
            if `"``_o''"' != "" local _opts `"`_opts' `_o'(`"``_o''"')"'
        }
        if `fontsize' != -1 local _opts `"`_opts' fontsize(`fontsize')"'
        if `digits' != -1 local _opts `"`_opts' digits(`digits')"'
        foreach _o in mdappend headershade zebra open {
            if "``_o''" != "" local _opts `"`_opts' `_o'"'
        }
        local _using ""
        if `"`using'"' != "" local _using `"using `"`using'"'"'
        puttab _stk_c1-_stk_c`_K' `_using', panel(_stk_panel) varlabels ///
            noembedheader sheet(`"`macval(sheet)'"') title(`"`macval(title)'"') ///
            footnote(`"`macval(note)'"') `_opts'
        return add
        return scalar n_frames = `_nf'
        return local frames `"`frames'"'
    }
    local rc = _rc
    if `_restore_needed' capture restore
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 17.0
capture mata: mata drop _stacktab_frames_fmt()
local _tt_ms0 = c(matastrict)
mata:
mata set matastrict on

// A numeric column as text: its value label where one maps, else its
// display format; missing is blank.
void _stacktab_frames_fmt(string scalar src, string scalar dst,
    string scalar vl, string scalar fmt)
{
    real colvector v
    string colvector out, mapped
    real scalar i

    v = st_data(., src)
    out = J(rows(v), 1, "")
    mapped = J(rows(v), 1, "")
    if (vl != "") {
        if (st_vlexists(vl)) mapped = st_vlmap(vl, v)
    }
    for (i = 1; i <= rows(v); i++) {
        if (mapped[i] != "") out[i] = mapped[i]
        else if (v[i] < .) out[i] = strtrim(strofreal(v[i], fmt))
    }
    st_sstore(., dst, out)
}

end
mata: mata set matastrict `_tt_ms0'
