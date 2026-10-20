*! _datamap_memshell Version 1.10.4  2026/10/21
*! Write a zero-observation copy of the data in memory to a file
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

// datamap and datadict document the data in memory through the same file
// routes as single(): the precheck and the report read variable names,
// labels, formats, characteristics, and value labels with -describe using-.
// Saving the loaded data for that (the old -save- of the whole dataset) reset
// c(changed) to 0 and pointed c(filename) at the temporary file, so a later
// -use- without -clear- discarded unsaved edits and -save, replace- wrote to
// the temporary file.  It also wrote a full on-disk copy of the data.
//
// The shell is written from a separate frame holding at most one row, which
// is then dropped: the active frame is never saved, so c(changed),
// c(filename), and the sort order are untouched, and peak memory grows by one
// row.  Callers read N, k, and the sort order from the data in memory, never
// from this file.
program define _datamap_memshell, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname _fr
    local _fr_made = 0
    capture noisily {
        args fn
        if c(N) > 0 frame put _all in 1, into(`_fr')
        else frame copy `c(frame)' `_fr'
        local _fr_made = 1
        frame `_fr' {
            if c(N) > 0 quietly drop in 1/l
            quietly save `"`fn'"', replace
        }
    }
    local rc = _rc
    if `_fr_made' capture frame drop `_fr'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
