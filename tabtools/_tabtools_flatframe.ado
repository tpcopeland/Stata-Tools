*! _tabtools_flatframe Version 2.4.0  2026/10/05
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
* name, and the block name is kept in char c#[tabtools_block]. The full
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

