*! _datamap_md_anchor Version 2.0.0  2026/11/10
*! The Markdown link anchor of a datamap dataset heading
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// _datamap_md_anchor, frame(f) row(#) index(#)
// r(anchor): the anchor GitHub gives the heading "<index>. <name>", where
// name is the heading name of row `row' of the datasets frame `f'
// (_datamap_collect_dataset): "Data in memory" for the data in memory, else
// the dataset column.  The name is read from the frame in Mata, so a file
// name holding a quote, backtick or dollar sign never passes through a macro.
// The anchor: lower case; every character that is not a letter, digit, mark,
// space, hyphen or underscore dropped; each space a hyphen.  Letters of any
// script survive: an ASCII-only class turned "Örebro" into a dead link.
capture mata: mata drop _dmanc_get()
mata:
void _dmanc_get(real scalar r, real scalar idx)
{
	string scalar nm, a
	if (r < 1 | r > st_nobs()) {
		errprintf("_datamap_md_anchor: row %g is not in the datasets frame\n", r)
		exit(198)
	}
	nm = _st_sdata(r, st_varindex("dataset"))
	if (_st_sdata(r, st_varindex("source")) == "memory") nm = "Data in memory"
	a = ustrlower(strofreal(idx, "%20.0f") + ". " + nm)
	a = ustrregexra(a, "[^\p{L}\p{N}\p{M} _-]", "")
	a = subinstr(a, " ", "-")
	st_local("_anchor", a)
}
end

program define _datamap_md_anchor, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, FRame(name) ROW(integer) INDex(integer)
        local _anchor ""
        frame `frame': mata: _dmanc_get(`row', `index')
        return local anchor "`_anchor'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
