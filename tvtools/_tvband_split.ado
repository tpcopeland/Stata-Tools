*! _tvband_split Version 1.4.0  2026/06/29
*! Shared single-axis interval splitter for tvband / tvsplit / tvage
*! Author: Timothy P Copeland, Karolinska Institutet
*! Part of the tvtools package
*!
*! Description:
*!   Splits the [start, stop] intervals of the data in memory along ONE
*!   date-derived axis (age, calendar period, or elapsed time since a
*!   reference date), adding a band variable and overwriting start/stop with
*!   the per-band sub-interval boundaries. All other variables ride along on
*!   each split row, so covariates and previously-added bands are preserved.
*!   Calling the engine once per axis composes to a full Lexis grid (interval
*!   splitting is commutative over the union of cut points), which is how
*!   tvsplit performs multi-timescale splitting.
*!
*!   Interval convention: inclusive integer Stata dates, abutting as
*!   stop + 1 == next start (the convention used throughout tvtools).
*!
*! Note: pure-Stata implementation. A Mata sweep-line acceleration is tracked
*!   separately (tvtools concept Rec 4) and is intentionally not built here.

program define _tvband_split, rclass
    version 16.0

    syntax , START(varname numeric) STOP(varname numeric) TYPE(string) ///
        GENerate(name) [ ORIGIN(varname numeric) WIDTH(real 1) ///
        MIN(string) MAX(string) UNIT(string) ANCHOR(string) LABel ]

    * Optional numeric bounds: empty string means "not set"
    foreach o in min max anchor {
        if "``o''" != "" {
            confirm number ``o''
            local `o'val = real("``o''")
        }
    }

    * --- Validate axis specification -------------------------------------
    if !inlist("`type'", "age", "calendar", "elapsed") {
        display as error "_tvband_split: type() must be age, calendar, or elapsed"
        exit 198
    }
    if `width' <= 0 {
        display as error "_tvband_split: width() must be positive"
        exit 198
    }
    if inlist("`type'", "age", "elapsed") & "`origin'" == "" {
        display as error "_tvband_split: type(`type') requires origin()"
        exit 198
    }
    if "`type'" == "calendar" & "`origin'" != "" {
        display as error "_tvband_split: type(calendar) does not take origin()"
        exit 198
    }
    if "`unit'" == "" local unit "day"
    if "`type'" == "elapsed" & !inlist("`unit'", "day", "year") {
        display as error "_tvband_split: unit() must be day or year"
        exit 198
    }

    * --- Validate target name is free ------------------------------------
    capture confirm new variable `generate'
    if _rc {
        display as error "_tvband_split: variable '`generate'' already exists"
        exit 110
    }

    * --- Intervals must be ordered (stop >= start) -----------------------
    quietly count if `stop' < `start' & !missing(`start', `stop')
    if r(N) > 0 {
        display as error "_tvband_split: `r(N)' interval(s) have stop < start"
        exit 459
    }
    quietly count if missing(`start') | missing(`stop')
    if r(N) > 0 {
        display as error "_tvband_split: `r(N)' interval(s) have missing start/stop"
        exit 416
    }
    if "`origin'" != "" {
        quietly count if missing(`origin')
        if r(N) > 0 {
            display as error "_tvband_split: `r(N)' interval(s) have missing origin"
            exit 416
        }
    }

    * --- Resolve calendar anchor (default = earliest start year) ---------
    if "`type'" == "calendar" & "`anchor'" == "" {
        quietly summarize `start', meanonly
        local anchorval = year(r(min))
    }

    * --- Band index at start and stop ------------------------------------
    * Band b covers axis values [b*width, (b+1)*width); boundary date bd(b)
    * is the first calendar day of band b.  Compute the index by the closed
    * form, then nudge by at most one band to absorb 365.25 rounding.
    tempvar b0 b1
    if "`type'" == "age" | ("`type'" == "elapsed" & "`unit'" == "year") {
        quietly gen double `b0' = floor((`start' - `origin') / (`width' * 365.25))
        quietly gen double `b1' = floor((`stop'  - `origin') / (`width' * 365.25))
        quietly replace `b0' = `b0' + 1 if round(`origin' + (`b0' + 1) * `width' * 365.25) <= `start'
        quietly replace `b1' = `b1' + 1 if round(`origin' + (`b1' + 1) * `width' * 365.25) <= `stop'
        quietly replace `b0' = `b0' - 1 if round(`origin' + `b0' * `width' * 365.25) > `start'
        quietly replace `b1' = `b1' - 1 if round(`origin' + `b1' * `width' * 365.25) > `stop'
    }
    else if "`type'" == "elapsed" {
        quietly gen double `b0' = floor((`start' - `origin') / `width')
        quietly gen double `b1' = floor((`stop'  - `origin') / `width')
    }
    else {
        quietly gen double `b0' = floor((year(`start') - `anchorval') / `width')
        quietly gen double `b1' = floor((year(`stop')  - `anchorval') / `width')
    }

    * --- Expand each interval into one row per band it traverses ----------
    tempvar row k bidx
    quietly gen long `row' = _n
    quietly expand `b1' - `b0' + 1
    quietly bysort `row': gen double `k' = _n - 1
    quietly gen double `bidx' = `b0' + `k'

    * --- Per-band boundary dates -----------------------------------------
    tempvar bs be
    if "`type'" == "age" | ("`type'" == "elapsed" & "`unit'" == "year") {
        quietly gen double `bs' = round(`origin' + `bidx' * `width' * 365.25)
        quietly gen double `be' = round(`origin' + (`bidx' + 1) * `width' * 365.25) - 1
    }
    else if "`type'" == "elapsed" {
        quietly gen double `bs' = `origin' + `bidx' * `width'
        quietly gen double `be' = `origin' + (`bidx' + 1) * `width' - 1
    }
    else {
        quietly gen double `bs' = mdy(1, 1, `anchorval' + `bidx' * `width')
        quietly gen double `be' = mdy(1, 1, `anchorval' + (`bidx' + 1) * `width') - 1
    }

    * --- Clamp the sub-interval to the original interval -----------------
    quietly replace `start' = max(`start', `bs')
    quietly replace `stop'  = min(`stop',  `be')

    * --- Band value: axis lower edge (age/elapsed) or calendar year ------
    if "`type'" == "calendar" {
        quietly gen double `generate' = `anchorval' + `bidx' * `width'
    }
    else {
        quietly gen double `generate' = `bidx' * `width'
    }

    * --- Apply axis-value bounds (inclusive on the band lower edge) ------
    if "`min'" != "" quietly drop if `generate' < `minval'
    if "`max'" != "" quietly drop if `generate' > `maxval'

    * --- Drop degenerate sub-intervals -----------------------------------
    quietly drop if `stop' < `start'

    quietly count
    if r(N) == 0 {
        display as error "_tvband_split: no intervals remain after splitting/bounds"
        exit 2000
    }

    * --- Optional value labels (integer width only) ----------------------
    if "`label'" != "" & `width' == int(`width') {
        local lblname "`generate'_lbl"
        if length("`lblname'") > 32 local lblname = substr("`generate'", 1, 28) + "_lbl"
        capture label drop `lblname'
        levelsof `generate', local(_levs)
        foreach lo of local _levs {
            local hi = `lo' + `width' - 1
            if `width' == 1  label define `lblname' `lo' "`lo'", add
            else             label define `lblname' `lo' "`lo'-`hi'", add
        }
        label values `generate' `lblname'
    }

    * --- Cosmetic labels and date formatting -----------------------------
    if "`type'" == "age"      label variable `generate' "Age band (time-varying)"
    if "`type'" == "calendar" label variable `generate' "Calendar period"
    if "`type'" == "elapsed"  label variable `generate' "Elapsed time band"
    format `start' `stop' %tdCCYY/NN/DD

    quietly drop `row'
    quietly count
    return scalar n_obs = r(N)
    return local genvar  "`generate'"
    return local axistype "`type'"
end
