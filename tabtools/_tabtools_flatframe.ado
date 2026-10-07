*! _tabtools_flatframe Version 2.5.6  2026/10/07
*! Flatten a regtab/effecttab display dataset for frame(name, flat)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

* Usage: _tabtools_flatframe <n columns> <columns per block> [short]
* Works on regtab's (and effecttab's) display dataset: row 1 the title, row 2
* the block names (each block's first column), row 3 the statistic headers,
* rows 4+ the body. Leaves rowlabel plus c1..c<n>, each labelled with its
* printed header: "block name, statistic header", either part alone when the
* other is blank. With short, the label is the statistic header alone (the
* block name when that is blank), as the table prints it under the block
* name, and the block name is kept in char c#[tabtools_block], with an
* identifier of the block in char c#[tabtools_block_id]: a token unique to
* this call, a dot, and the block's number, so puttab, blockheader groups a
* block's columns by identity, never by equal names, even when columns of
* two flat frames sit side by side. The token comes from the package's
* per-call sequence (_tabtools_companion_id), never from a tempname, which
* Stata hands out again in a later call, and no block id of a live frame
* may begin with it (mata clear restarts the sequence). The full
* header is kept in char c#[tabtools_header] either way, since a variable
* label holds at most 80 characters (cut on a character, not a byte,
* boundary).
program define _tabtools_flatframe, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		args ncols cpb short
		local _short = ("`short'" == "short")
		local _ffid ""
		if `_short' {
			local _fftry 0
			while `"`_ffid'"' == "" {
				_tabtools_companion_id
				local _ffid : copy local _companion_id
				mata: st_local("_ffhit", strofreal(_tt_ff_used(st_local("_ffid"))))
				if `_ffhit' local _ffid ""
				local ++_fftry
				if `_fftry' > 1000 & `"`_ffid'"' == "" {
					noisily display as error "frame(, flat): no unique block identifier could be made"
					exit 459
				}
			}
		}
		capture drop title
		capture drop ref*
		local _long ""
		forvalues _j = 1/`ncols' {
			confirm string variable c`_j'
			local _b1 = floor((`_j' - 1) / `cpb') * `cpb' + 1
			mata: st_local("_hdr", strtrim(st_sdata(2, "c`_b1'")) + ///
				((strtrim(st_sdata(2, "c`_b1'")) != "" & strtrim(st_sdata(3, "c`_j'")) != "") ? ", " : "") + ///
				strtrim(st_sdata(3, "c`_j'")))
			mata: st_global("c`_j'[tabtools_header]", st_local("_hdr"))
			if `_short' {
				mata: st_global("c`_j'[tabtools_block]", strtrim(st_sdata(2, "c`_b1'")))
				char c`_j'[tabtools_block_id] "`_ffid'.`=floor((`_j' - 1) / `cpb') + 1'"
				mata: st_local("_hdr", strtrim(st_sdata(3, "c`_j'")) != "" ? ///
					strtrim(st_sdata(3, "c`_j'")) : strtrim(st_sdata(2, "c`_b1'")))
			}
			mata: st_varlabel("c`_j'", usubstr(st_local("_hdr"), 1, 80))
			mata: st_local("_toolong", strofreal(ustrlen(st_local("_hdr")) > 80))
			if `_toolong' local _long "`_long' c`_j'"
		}
		rename A rowlabel
		* a blank label (one space), so puttab, varlabels leaves the corner
		* cell blank as the table does, instead of printing the name
		mata: st_varlabel("rowlabel", " ")
		quietly drop in 1/3
		order rowlabel
		if "`_long'" != "" {
			noisily display as text "(frame flat: header of`_long' longer than 80 characters;" ///
				" the variable label is truncated and char c#[tabtools_header] holds it in full)"
		}
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

version 17.0
capture mata: mata drop _tt_ff_used()
* matastrict is a session setting: save the caller's value here and
* restore it after the block, so loading this file never leaks it.
local _tt_ms0 = c(matastrict)
mata:
mata set matastrict on

// 1 when a variable of any live frame carries a block id that begins with
// token followed by a dot (the id of a block of an earlier flat frame).
real scalar _tt_ff_used(string scalar token)
{
    string vector frames
    string scalar current, id
    real scalar f, j, hit

    current = st_framecurrent()
    // st_framedir() returns a column vector: count with length()
    frames = st_framedir()
    hit = 0
    for (f = 1; f <= length(frames) & !hit; f++) {
        st_framecurrent(frames[f])
        for (j = 1; j <= st_nvar() & !hit; j++) {
            id = st_global(st_varname(j) + "[tabtools_block_id]")
            if (id != "" & substr(id, 1, strlen(token) + 1) == token + ".") hit = 1
        }
    }
    st_framecurrent(current)
    return(hit)
}

end
mata: mata set matastrict `_tt_ms0'
