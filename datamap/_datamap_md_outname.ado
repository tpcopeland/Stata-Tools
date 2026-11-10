*! _datamap_md_outname Version 2.0.0  2026/11/10
*! The file a dataset is written to under datamap's separate option
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// _datamap_md_outname, filepath(path) suffix(text) [outdir(dir) memory]
// r(output): <dataset path without .dta><suffix>.md, beside the dataset; with
// outdir(), <outdir>/<dataset file name without .dta><suffix>.md; the data in
// memory are named "memory".  (datadict's DeriveSeparateOutput.)
program define _datamap_md_outname, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, FILEPATH(string asis) SUFfix(string asis) [OUTDir(string asis) MEMory]

        foreach field in filepath suffix outdir {
            mata: st_local("`field'", _dmon_unquote(st_local("`field'")))
        }
        local basename = ustrregexra(`"`macval(filepath)'"', ".*[/\\]", "")
        local basename = ustrregexra(`"`basename'"', "(?i)\.dta$", "")
        if "`memory'" != "" local basename "memory"
        if `"`outdir'"' != "" {
            local outroot = subinstr(`"`outdir'"', "\", "/", .)
            if substr(`"`outroot'"', length(`"`outroot'"'), 1) == "/" {
                local outroot = substr(`"`outroot'"', 1, length(`"`outroot'"') - 1)
            }
            local outfile `"`outroot'/`basename'`suffix'.md"'
        }
        else {
            if "`memory'" != "" local outbase "memory"
            else local outbase = ustrregexra(`"`macval(filepath)'"', "(?i)\.dta$", "")
            local outfile `"`outbase'`suffix'.md"'
        }
        return local output `"`outfile'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture mata: mata drop _dmon_unquote()
mata:
string scalar _dmon_unquote(string scalar value)
{
	real scalar n
	n = strlen(value)
	while (n >= 4 & substr(value, 1, 2) == char(96) + char(34) &
		substr(value, n - 1, 2) == char(34) + char(39)) {
		value = substr(value, 3, n - 4)
		n = strlen(value)
	}
	return(value)
}
end
