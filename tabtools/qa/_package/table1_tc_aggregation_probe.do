* table1_tc_aggregation_probe.do - scratch prototype for table1_tc aggregation hot path
* Run from tabtools/qa/_package or tabtools/qa:
*     stata-mp -b do _package/table1_tc_aggregation_probe.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _table1_tc_aggregation

local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/_package$") {
    local qa_dir = regexr("`_cwd'", "/_package$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local qa_dir "`_cwd'"
}
else {
    local qa_dir "`_cwd'/qa"
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

log using "`output_dir'/table1_tc_aggregation_probe.log", replace text name(_table1_tc_aggregation)

adopath ++ "`pkg_dir'"
ado dir
which table1_tc

local result_file "`output_dir'/table1_tc_aggregation_timing.tsv"
tempname benchfh
file open `benchfh' using "`result_file'", write replace text
file write `benchfh' "scenario" _tab "seconds" _tab "observations" _tab "status" _n

local format "%9.3f"
local percformat "%9.3f"
local nformat "%12.0f"
local nobs = 50000
local vars `"age contn \ bmi contn \ sbp contn \ female bin \ smoker bin \ stage cat"'
local group_levels "0 1 2"
local group_count : word count `group_levels'
local include_total = 1
local group_out = `group_count' + `include_total'

capture program drop _t1tcagg_dataset
program define _t1tcagg_dataset
    version 17.0
    syntax, OBS(integer)

    clear
    set obs `obs'
    set seed 20260523

    gen long id = _n
    gen byte group = mod(_n, 3)
    gen double age = 50 + 11 * rnormal() + 1.5 * group
    gen double bmi = 27 + 4.5 * rnormal() - .4 * group
    gen double sbp = 118 + 14 * rnormal() + 2 * group
    gen byte female = runiform() > (.47 + .04 * group)
    gen byte smoker = runiform() > (.69 - .03 * group)
    gen byte stage = floor(4 * runiform())

    replace age = . if mod(_n, 97) == 0
    replace bmi = . if mod(_n, 89) == 0
    replace sbp = . if mod(_n, 83) == 0
    replace female = . if mod(_n, 113) == 0
    replace smoker = . if mod(_n, 127) == 0
    replace stage = . if mod(_n, 131) == 0

    label define group_lbl 0 "Control" 1 "Dose A" 2 "Dose B"
    label values group group_lbl
    label define stage_lbl 0 "Stage 0" 1 "Stage 1" 2 "Stage 2" 3 "Stage 3"
    label values stage stage_lbl
end

capture program drop table1_tc_fast_aggregation
program define table1_tc_fast_aggregation, rclass
    version 17.0
    syntax [if] [in], BY(varname numeric) VARS(string asis) [TOTAL(string)]

    marksample touse, novarlist

    local contvars ""
    local binvars ""
    local catvars ""

    gettoken arg rest : vars, parse("\")
    while `"`arg'"' != "" {
        if `"`arg'"' != "\" {
            local varname : word 1 of `arg'
            local vartype : word 2 of `arg'
            if "`vartype'" == "contn" local contvars "`contvars' `varname'"
            else if "`vartype'" == "bin" local binvars "`binvars' `varname'"
            else if "`vartype'" == "cat" local catvars "`catvars' `varname'"
            else {
                noisily display as error "prototype supports contn, bin, and cat only; got `vartype'"
                exit 198
            }
        }
        gettoken arg rest : rest, parse("\")
    }

    local include_total = "`total'" != ""
    tempname sample continuous binary categorical
    mata: _table1_tc_fast_aggregation_mata("`touse'", "`by'", ///
        "`contvars'", "`binvars'", "`catvars'", `include_total', ///
        "`sample'", "`continuous'", "`binary'", "`categorical'")

    return matrix sample = `sample'
    return matrix continuous = `continuous'
    return matrix binary = `binary'
    return matrix categorical = `categorical'
    return local contvars "`=strtrim("`contvars'")'"
    return local binvars "`=strtrim("`binvars'")'"
    return local catvars "`=strtrim("`catvars'")'"
end

capture program drop _t1tcagg_cell
program define _t1tcagg_cell, rclass
    version 17.0
    syntax, FRAME(name) COLUMN(name) [FACTOR(string asis) ROW(integer 0)]

    frame `frame' {
        if `row' > 0 {
            local idx = `row'
        }
        else {
            tempvar _row
            quietly gen long `_row' = _n
            quietly summarize `_row' if factor == `"`factor'"', meanonly
            if r(N) != 1 {
                noisily display as error "expected one row for factor `factor', found " r(N)
                drop `_row'
                exit 459
            }
            local idx = r(min)
            drop `_row'
        }
        mata: st_local("_cell", st_sdata(`idx', "`column'"))
    }
    return local cell `"`_cell'"'
end

capture program drop _t1tcagg_assert_cell
program define _t1tcagg_assert_cell
    version 17.0
    syntax, FRAME(name) COLUMN(name) [FACTOR(string asis) ROW(integer 0)]

    if `row' > 0 {
        _t1tcagg_cell, frame(`frame') row(`row') column(`column')
    }
    else {
        _t1tcagg_cell, frame(`frame') factor(`"`factor'"') column(`column')
    }
    local got = strtrim(`"`r(cell)'"')
    local expected = strtrim(`"$T1TCAGG_EXPECTED"')
    if `"`got'"' != `"`expected'"' {
        if `row' > 0 noisily display as error "cell mismatch row=`row' column=`column'"
        else noisily display as error "cell mismatch factor=`factor' column=`column'"
        noisily display as error "  got:      `got'"
        noisily display as error "  expected: `expected'"
        exit 459
    }
end

capture mata: mata drop _table1_tc_fast_group_index()
capture mata: mata drop _table1_tc_fast_level_index()
capture mata: mata drop _table1_tc_fast_aggregation_mata()
mata:
real scalar _table1_tc_fast_group_index(real scalar value, real colvector levels)
{
    real scalar i

    for (i = 1; i <= rows(levels); i++) {
        if (value == levels[i]) return(i)
    }
    return(.)
}

real scalar _table1_tc_fast_level_index(real scalar value, real colvector levels)
{
    real scalar i

    for (i = 1; i <= rows(levels); i++) {
        if (value == levels[i]) return(i)
    }
    return(.)
}

void _table1_tc_fast_aggregation_mata(
    string scalar touse_name,
    string scalar group_name,
    string scalar contvars,
    string scalar binvars,
    string scalar catvars,
    real scalar include_total,
    string scalar sample_name,
    string scalar continuous_name,
    string scalar binary_name,
    string scalar categorical_name)
{
    real colvector touse, group, group_values, cat_levels, xcol
    real matrix X, B, C
    real matrix sample_out, cont_out, bin_out, cat_out
    real matrix cont_n, cont_sum, cont_sum2
    real matrix bin_pos, bin_den
    real matrix cat_counts, cat_den
    string rowvector cv, bv, kv
    real scalar i, j, k, n, g, gi, li, ncont, nbin, ncat, ng, ngout
    real scalar x, mean, sd, denom, pct

    st_view(touse, ., touse_name)
    st_view(group, ., group_name)
    cv = tokens(contvars)
    bv = tokens(binvars)
    kv = tokens(catvars)
    n = rows(group)

    group_values = J(0, 1, .)
    for (i = 1; i <= n; i++) {
        if (touse[i] != 0 & group[i] < .) group_values = group_values \ group[i]
    }
    group_values = uniqrows(sort(group_values, 1))
    ng = rows(group_values)
    ngout = ng + include_total

    sample_out = J(ngout, 3, .)
    for (g = 1; g <= ng; g++) {
        sample_out[g, 1] = g
        sample_out[g, 2] = group_values[g]
        sample_out[g, 3] = 0
    }
    if (include_total) {
        sample_out[ngout, 1] = ngout
        sample_out[ngout, 2] = .
        sample_out[ngout, 3] = 0
    }
    for (i = 1; i <= n; i++) {
        if (touse[i] == 0 | group[i] >= .) continue
        gi = _table1_tc_fast_group_index(group[i], group_values)
        if (gi >= .) continue
        sample_out[gi, 3] = sample_out[gi, 3] + 1
        if (include_total) sample_out[ngout, 3] = sample_out[ngout, 3] + 1
    }

    ncont = cols(cv)
    if (ncont > 0) {
        st_view(X, ., cv)
        cont_n = J(ncont, ngout, 0)
        cont_sum = J(ncont, ngout, 0)
        cont_sum2 = J(ncont, ngout, 0)
        for (i = 1; i <= n; i++) {
            if (touse[i] == 0 | group[i] >= .) continue
            gi = _table1_tc_fast_group_index(group[i], group_values)
            if (gi >= .) continue
            for (j = 1; j <= ncont; j++) {
                x = X[i, j]
                if (x >= .) continue
                cont_n[j, gi] = cont_n[j, gi] + 1
                cont_sum[j, gi] = cont_sum[j, gi] + x
                cont_sum2[j, gi] = cont_sum2[j, gi] + x * x
                if (include_total) {
                    cont_n[j, ngout] = cont_n[j, ngout] + 1
                    cont_sum[j, ngout] = cont_sum[j, ngout] + x
                    cont_sum2[j, ngout] = cont_sum2[j, ngout] + x * x
                }
            }
        }
        cont_out = J(ncont * ngout, 6, .)
        k = 0
        for (j = 1; j <= ncont; j++) {
            for (g = 1; g <= ngout; g++) {
                k++
                cont_out[k, 1] = j
                cont_out[k, 2] = g
                cont_out[k, 3] = sample_out[g, 2]
                cont_out[k, 4] = cont_n[j, g]
                if (cont_n[j, g] > 0) {
                    mean = cont_sum[j, g] / cont_n[j, g]
                    cont_out[k, 5] = mean
                    if (cont_n[j, g] > 1) {
                        sd = sqrt((cont_sum2[j, g] - (cont_sum[j, g] * cont_sum[j, g] / cont_n[j, g])) / (cont_n[j, g] - 1))
                        cont_out[k, 6] = sd
                    }
                }
            }
        }
    }
    else cont_out = J(1, 6, .)

    nbin = cols(bv)
    if (nbin > 0) {
        st_view(B, ., bv)
        bin_pos = J(nbin, ngout, 0)
        bin_den = J(nbin, ngout, 0)
        for (i = 1; i <= n; i++) {
            if (touse[i] == 0 | group[i] >= .) continue
            gi = _table1_tc_fast_group_index(group[i], group_values)
            if (gi >= .) continue
            for (j = 1; j <= nbin; j++) {
                x = B[i, j]
                if (x >= .) continue
                bin_den[j, gi] = bin_den[j, gi] + 1
                if (x == 1) bin_pos[j, gi] = bin_pos[j, gi] + 1
                if (include_total) {
                    bin_den[j, ngout] = bin_den[j, ngout] + 1
                    if (x == 1) bin_pos[j, ngout] = bin_pos[j, ngout] + 1
                }
            }
        }
        bin_out = J(nbin * ngout, 6, .)
        k = 0
        for (j = 1; j <= nbin; j++) {
            for (g = 1; g <= ngout; g++) {
                k++
                bin_out[k, 1] = j
                bin_out[k, 2] = g
                bin_out[k, 3] = sample_out[g, 2]
                bin_out[k, 4] = bin_pos[j, g]
                bin_out[k, 5] = bin_den[j, g]
                if (bin_den[j, g] > 0) bin_out[k, 6] = 100 * bin_pos[j, g] / bin_den[j, g]
            }
        }
    }
    else bin_out = J(1, 6, .)

    ncat = cols(kv)
    cat_out = J(0, 7, .)
    if (ncat > 0) {
        st_view(C, ., kv)
        for (j = 1; j <= ncat; j++) {
            xcol = C[., j]
            cat_levels = select(xcol, (touse :!= 0) :& (group :< .) :& (xcol :< .))
            cat_levels = uniqrows(sort(cat_levels, 1))
            cat_counts = J(rows(cat_levels), ngout, 0)
            cat_den = J(ngout, 1, 0)
            for (i = 1; i <= n; i++) {
                if (touse[i] == 0 | group[i] >= .) continue
                x = C[i, j]
                if (x >= .) continue
                gi = _table1_tc_fast_group_index(group[i], group_values)
                li = _table1_tc_fast_level_index(x, cat_levels)
                if (gi >= . | li >= .) continue
                cat_den[gi] = cat_den[gi] + 1
                cat_counts[li, gi] = cat_counts[li, gi] + 1
                if (include_total) {
                    cat_den[ngout] = cat_den[ngout] + 1
                    cat_counts[li, ngout] = cat_counts[li, ngout] + 1
                }
            }
            for (li = 1; li <= rows(cat_levels); li++) {
                for (g = 1; g <= ngout; g++) {
                    denom = cat_den[g]
                    pct = .
                    if (denom > 0) pct = 100 * cat_counts[li, g] / denom
                    cat_out = cat_out \ (j, cat_levels[li], g, sample_out[g, 2], cat_counts[li, g], denom, pct)
                }
            }
        }
    }
    if (rows(cat_out) == 0) cat_out = J(1, 7, .)

    st_matrix(sample_name, sample_out)
    st_matrix(continuous_name, cont_out)
    st_matrix(binary_name, bin_out)
    st_matrix(categorical_name, cat_out)
}
end

capture program drop _t1tcagg_expected_n
program define _t1tcagg_expected_n, rclass
    version 17.0
    args n nformat
    local value = "N=" + string(`n', "`nformat'")
    return local value `"`value'"'
end

capture program drop _t1tcagg_expected_pct
program define _t1tcagg_expected_pct, rclass
    version 17.0
    args count denom pct nformat percformat

    local pstr = string(`pct', "`percformat'")
    if `pct' < 10 & "`pstr'" != "10" & "`pstr'" != "10.0" & "`pstr'" != "10.00" {
        local pstr = " " + "`pstr'"
    }
    local cstr = string(`count', "`nformat'")
    local value "`cstr' (`pstr'%)"
    return local value `"`value'"'
end

**# Representative Data
_t1tcagg_dataset, obs(`nobs')

**# Current table1_tc lane
timer clear 1
timer clear 2
capture frame drop table1_tc_aggregation_current
timer on 1
capture noisily quietly table1_tc, by(group) vars(`vars') total(after) ///
    nopvalue frame(table1_tc_aggregation_current, replace) ///
    format(`format') percformat(`percformat') nformat(`nformat') ///
    sdleft(" (") sdright(")") percsign("%") spacelowpercent
local current_rc = _rc
timer off 1
capture quietly timer list 1
if _rc == 0 local current_seconds = r(t1)
else local current_seconds = .

**# Prototype Mata aggregation lane
timer on 2
capture noisily quietly table1_tc_fast_aggregation, by(group) vars(`vars') total(after)
local proto_rc = _rc
timer off 2
capture quietly timer list 2
if _rc == 0 local proto_seconds = r(t2)
else local proto_seconds = .

if `proto_rc' == 0 {
    matrix table1_tc_aggregation_sample = r(sample)
    matrix table1_tc_aggregation_cont = r(continuous)
    matrix table1_tc_aggregation_bin = r(binary)
    matrix table1_tc_aggregation_cat = r(categorical)
}

local current_status = cond(`current_rc' == 0, "PASS", "FAIL")
local proto_status = cond(`proto_rc' == 0, "PASS", "FAIL")
file write `benchfh' "table1_tc_current_frame_nopvalue" _tab %9.3f (`current_seconds') _tab %9.0f (`nobs') _tab "`current_status'" _n
file write `benchfh' "table1_tc_fast_aggregation_mata" _tab %9.3f (`proto_seconds') _tab %9.0f (`nobs') _tab "`proto_status'" _n

if `current_rc' != 0 | `proto_rc' != 0 {
    file close `benchfh'
    log close _table1_tc_aggregation
    exit 459
}

**# Equivalence Against Current table1_tc Display Frame
local eq_checks = 0
local eq_fail = 0

capture noisily {
    local gidx = 0
    foreach gle of local group_levels {
        local ++gidx
        local nval = table1_tc_aggregation_sample[`gidx', 3]
        local expected_cell = "N=" + string(`nval', "`nformat'")
        global T1TCAGG_EXPECTED `"`expected_cell'"'
        _t1tcagg_assert_cell, frame(table1_tc_aggregation_current) ///
            row(2) column(group_`gle')
        local ++eq_checks
    }
    local total_idx = `group_out'
    local nval = table1_tc_aggregation_sample[`total_idx', 3]
    local expected_cell = "N=" + string(`nval', "`nformat'")
    global T1TCAGG_EXPECTED `"`expected_cell'"'
    _t1tcagg_assert_cell, frame(table1_tc_aggregation_current) ///
        row(2) column(group_T)
    local ++eq_checks

    local contvars "age bmi sbp"
    local cont_j = 0
    foreach v of local contvars {
        local ++cont_j
        local outrow = 2 + `cont_j'
        local gidx = 0
        foreach gle of local group_levels {
            local ++gidx
            local row = (`cont_j' - 1) * `group_out' + `gidx'
            local mean = table1_tc_aggregation_cont[`row', 5]
            local sd = table1_tc_aggregation_cont[`row', 6]
            local expected = string(`mean', "`format'") + " (" + string(`sd', "`format'") + ")"
            global T1TCAGG_EXPECTED `"`expected'"'
            _t1tcagg_assert_cell, frame(table1_tc_aggregation_current) ///
                row(`outrow') column(group_`gle')
            local ++eq_checks
        }
        local row = (`cont_j' - 1) * `group_out' + `group_out'
        local mean = table1_tc_aggregation_cont[`row', 5]
        local sd = table1_tc_aggregation_cont[`row', 6]
        local expected = string(`mean', "`format'") + " (" + string(`sd', "`format'") + ")"
        global T1TCAGG_EXPECTED `"`expected'"'
        _t1tcagg_assert_cell, frame(table1_tc_aggregation_current) ///
            row(`outrow') column(group_T)
        local ++eq_checks
    }

    local binvars "female smoker"
    local bin_j = 0
    foreach v of local binvars {
        local ++bin_j
        local outrow = 5 + `bin_j'
        local gidx = 0
        foreach gle of local group_levels {
            local ++gidx
            local row = (`bin_j' - 1) * `group_out' + `gidx'
            local pos = table1_tc_aggregation_bin[`row', 4]
            local den = table1_tc_aggregation_bin[`row', 5]
            local pct = table1_tc_aggregation_bin[`row', 6]
            local pstr = string(`pct', "`percformat'")
            if `pct' < 10 & "`pstr'" != "10" & "`pstr'" != "10.0" & "`pstr'" != "10.00" {
                local pstr = " " + "`pstr'"
            }
            local cstr = string(`pos', "`nformat'")
            local expected_cell "`cstr' (`pstr'%)"
            global T1TCAGG_EXPECTED `"`expected_cell'"'
            _t1tcagg_assert_cell, frame(table1_tc_aggregation_current) ///
                row(`outrow') column(group_`gle')
            local ++eq_checks
        }
        local row = (`bin_j' - 1) * `group_out' + `group_out'
        local pos = table1_tc_aggregation_bin[`row', 4]
        local den = table1_tc_aggregation_bin[`row', 5]
        local pct = table1_tc_aggregation_bin[`row', 6]
        local pstr = string(`pct', "`percformat'")
        if `pct' < 10 & "`pstr'" != "10" & "`pstr'" != "10.0" & "`pstr'" != "10.00" {
            local pstr = " " + "`pstr'"
        }
        local cstr = string(`pos', "`nformat'")
        local expected_cell "`cstr' (`pstr'%)"
        global T1TCAGG_EXPECTED `"`expected_cell'"'
        _t1tcagg_assert_cell, frame(table1_tc_aggregation_current) ///
            row(`outrow') column(group_T)
        local ++eq_checks
    }

    local cat_levels "0 1 2 3"
    local lev_idx = 0
    foreach lev of local cat_levels {
        local ++lev_idx
        local levlab : label (stage) `lev'
        if `"`levlab'"' == "" local levlab "`lev'"
        local factor `"   `levlab'"'
        local outrow = 8 + `lev_idx'

        local gidx = 0
        foreach gle of local group_levels {
            local ++gidx
            local row = (`lev_idx' - 1) * `group_out' + `gidx'
            local count = table1_tc_aggregation_cat[`row', 5]
            local den = table1_tc_aggregation_cat[`row', 6]
            local pct = table1_tc_aggregation_cat[`row', 7]
            local pstr = string(`pct', "`percformat'")
            if `pct' < 10 & "`pstr'" != "10" & "`pstr'" != "10.0" & "`pstr'" != "10.00" {
                local pstr = " " + "`pstr'"
            }
            local cstr = string(`count', "`nformat'")
            local expected_cell "`cstr' (`pstr'%)"
            global T1TCAGG_EXPECTED `"`expected_cell'"'
            _t1tcagg_assert_cell, frame(table1_tc_aggregation_current) ///
                row(`outrow') column(group_`gle')
            local ++eq_checks
        }
        local row = (`lev_idx' - 1) * `group_out' + `group_out'
        local count = table1_tc_aggregation_cat[`row', 5]
        local den = table1_tc_aggregation_cat[`row', 6]
        local pct = table1_tc_aggregation_cat[`row', 7]
        local pstr = string(`pct', "`percformat'")
        if `pct' < 10 & "`pstr'" != "10" & "`pstr'" != "10.0" & "`pstr'" != "10.00" {
            local pstr = " " + "`pstr'"
        }
        local cstr = string(`count', "`nformat'")
        local expected_cell "`cstr' (`pstr'%)"
        global T1TCAGG_EXPECTED `"`expected_cell'"'
        _t1tcagg_assert_cell, frame(table1_tc_aggregation_current) ///
            row(`outrow') column(group_T)
        local ++eq_checks
    }
}
if _rc {
    local eq_fail = 1
}

local eq_status = cond(`eq_fail' == 0, "PASS", "FAIL")
file write `benchfh' "table1_tc_aggregation_equivalence" _tab "." _tab %9.0f (`nobs') _tab "`eq_status'" _n

if `proto_seconds' < . & `proto_seconds' > 0 & `current_seconds' < . {
    local speedup = `current_seconds' / `proto_seconds'
}
else {
    local speedup = .
}

display as result "Aggregation equivalence: `eq_status' (`eq_checks' display-cell checks)"
display as result "Current table1_tc: `: display %9.3f `current_seconds'' sec"
display as result "Prototype Mata aggregation: `: display %9.3f `proto_seconds'' sec"
display as result "Prototype aggregation speedup vs current frame lane: `: display %9.2f `speedup''x"
display as text "Timing results: `result_file'"

file close `benchfh'

if `eq_fail' {
    display as error "AGGREGATION PROTOTYPE EQUIVALENCE FAILED"
    capture macro drop T1TCAGG_EXPECTED
    log close _table1_tc_aggregation
    exit 459
}

display as result "AGGREGATION PROTOTYPE EQUIVALENCE PASSED"
capture macro drop T1TCAGG_EXPECTED
log close _table1_tc_aggregation
