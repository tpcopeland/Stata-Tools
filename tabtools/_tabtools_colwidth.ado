*! _tabtools_colwidth Version 2.1.4  2026/09/09
*! Size one exported table column from its own rendered cells
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*
* One place for the xlsx column-width heuristic every tabtools engine used to
* carry inline. A column is measured on its OWN cells, never on a maximum
* shared with sibling columns, so one wide column or one verbose header cannot
* pad the rest of the table out to match it.
*
*   _tabtools_colwidth varname [, options]
*     firstrow(#)     first data row measured (default 3: rows 1-2 are the
*                     title and merged/group header rows)
*     exclude(...)    quoted cell texts that never set the width, e.g. the
*                     reference-category label that may overflow safely
*     scale(#) pad(#) width = ceil(maxlen * scale) + pad   (0.85, 2)
*     minwidth(#) maxwidth(#)  bounds; 0 = unbounded
*     headerrow(#)    row holding this column's own wrapped label (0 = none)
*     headerfloor(#)  with headerrow(): raise the width to
*                     min(ceil(hlen / 2) + 1, headerfloor) so the label wraps
*                     to about two lines rather than many
*     headerscale(#)  label length damping before the wrap test (0.9)
*     maxlines(#)     cap on r(hlines) (5)
*
*   _tabtools_colwidth , hlength(#) blockwidth(#)
*     no variable: only r(hlines) for a header of display width hlength()
*     merged across a block of columns blockwidth() wide
*
* Lengths are Unicode display widths (udstrlen), not byte counts, so a
* "±" or "≥" in a cell counts as one character.
*
* Returns: r(width) r(maxlen) r(hlen) r(hlines)

program define _tabtools_colwidth, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [varname(default=none)] [, FIRSTrow(integer 3) ///
            EXCLude(string asis) SCALE(real 0.85) PAD(real 2) ///
            MINwidth(real 0) MAXwidth(real 0) ///
            HEADERrow(integer 0) HEADERscale(real 0.9) HEADERfloor(real 0) ///
            MAXLines(integer 5) HLENgth(real 0) BLOCKwidth(real 0)]

        if `maxlines' < 1 {
            noisily display as error "maxlines() must be at least 1"
            exit 198
        }

        local _maxlen = 0
        local _width = 0
        local _hlen = `hlength'
        if "`varlist'" != "" {
            local _var `varlist'
            capture confirm string variable `_var'
            if !_rc {
                local _cell `"`_var'"'
                local _hcell `"`_var'[`headerrow']"'
            }
            else {
                local _fmt : format `_var'
                local _cell `"string(`_var', "`_fmt'")"'
                local _hcell `"string(`_var'[`headerrow'], "`_fmt'")"'
            }

            local _cond "_n >= `firstrow'"
            local _ex `"`exclude'"'
            while `"`_ex'"' != "" {
                gettoken _tok _ex : _ex
                if `"`_tok'"' != "" local _cond `"`_cond' & `_cell' != `"`_tok'"'"'
            }
            tempvar _len
            quietly generate long `_len' = udstrlen(`_cell') if `_cond'
            quietly summarize `_len', meanonly
            local _maxlen = cond(r(N) > 0, r(max), 0)
            local _width = ceil(`_maxlen' * `scale') + `pad'

            if `headerrow' > 0 & `headerrow' <= _N {
                local _hlen = udstrlen(`_hcell')
            }
            if `headerfloor' > 0 & `_hlen' > 0 {
                local _floor = min(ceil(`_hlen' / 2) + 1, `headerfloor')
                if `_floor' > `_width' local _width = `_floor'
            }
            if `minwidth' > 0 & `_width' < `minwidth' local _width = `minwidth'
            if `maxwidth' > 0 & `_width' > `maxwidth' local _width = `maxwidth'
        }
        else if `blockwidth' <= 0 {
            noisily display as error "_tabtools_colwidth: a variable or blockwidth() is required"
            exit 198
        }

        * Lines the header needs once wrapped inside its own column, or inside
        * the merged block when blockwidth() is given.
        local _wrap = cond(`blockwidth' > 0, `blockwidth', `_width')
        local _hlines = 1
        if `_wrap' > 0 & `_hlen' * `headerscale' > `_wrap' {
            local _hlines = min(ceil(`_hlen' * `headerscale' / `_wrap'), `maxlines')
        }

        return scalar width = `_width'
        return scalar maxlen = `_maxlen'
        return scalar hlen = `_hlen'
        return scalar hlines = `_hlines'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
