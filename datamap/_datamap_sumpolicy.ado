*! _datamap_sumpolicy Version 1.10.6  2026/10/21
*! Which summaries of one variable a datamap/datadict output may print
*! Author: Timothy P Copeland, Karolinska Institutet

// One decision, read by every writer (text, JSON, sample rows, saving()):
//   r(datehide)  1 under datesafe for a date-class variable or any variable
//                with a date display format (%t..., %d...): its summaries
//                are exact dates.
//   r(cathide)   1 for a categorical variable while mincell() is above 0:
//                its mean is the share in a frequency cell that may be
//                suppressed.
//   r(momhide)   1 for a continuous variable with two or three distinct
//                values while mincell() is above 0: the mean and SD (and
//                skewness) give the count of each value back, as
//                dataprobe's rule for an sd.
//   r(datefmt)   1 when the display format is a date format.
program define _datamap_sumpolicy, rclass
    version 16.0
    syntax, CLASS(string) [VFMT(string) DATESAFE MINCell(real 0) NUNIQ(real -1)]
    local f = subinstr(`"`vfmt'"', "%-", "%", 1)
    local isdf = (substr(`"`f'"', 1, 2) == "%t" | substr(`"`f'"', 1, 2) == "%d")
    return scalar datefmt = `isdf'
    return scalar datehide = ("`datesafe'" != "" & (`"`class'"' == "date" | `isdf'))
    return scalar cathide = (`mincell' > 0 & `"`class'"' == "categorical")
    return scalar momhide = (`mincell' > 0 & `"`class'"' == "continuous" & inlist(`nuniq', 2, 3))
end
