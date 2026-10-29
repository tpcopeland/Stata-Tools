* test_v190_balance_graphs.do -- psdash balance graph aesthetics (love plot,
* strategies overlay, multi-group love plot, distribution panels)
* Author: Timothy P Copeland, Karolinska Institutet
*
* Fail-on-old (psdash 1.8.1): the love-plot x range was symmetric with a floor
* of +/-0.5 (all-positive SMDs left the left half empty), the threshold was two
* red dashed xlines, rows were spread by the default 4-inch height, the
* distribution figure titled itself "<title> -- covariate distributions" and
* repeated a 4-key legend in every panel (raw vs weighted differing only by dash
* pattern), and multi-group comparisons shared one y position with no connector.
* The assertions read the saved .gph (axis directives, plot types, sersets,
* header size) and graph describe, not the .ado source.
version 16.0
capture log close _all
log using test_v190_balance_graphs.log, replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"
local tests = 0
local pass = 0
local fail = 0
local failed ""

tempfile gph
capture mata: mata drop _v190_ext()
capture mata: mata drop _v190_xlines()
capture mata: mata drop _v190_types()
capture mata: mata drop _v190_ser()
capture mata: mata drop _v190_hdr()
capture mata: mata drop _v190_line()
mata:
// Axis extent from a saved graph: (lo, hi, first tick, last tick, n ticks,
// most decimals in any tick label). Extent = ticks plus any addmin/addmax.
real rowvector _v190_ext(string scalar f)
{
    string colvector L
    string rowvector w
    real scalar i, j, lo, hi, tmin, tmax, nt, dec, v, p
    L = cat(f)
    lo = hi = tmin = tmax = .
    nt = 0
    dec = 0
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, 15) == ".xaxis1.addmin ") {
            v = strtoreal(substr(L[i], 16, .))
            if (lo >= . | v < lo) lo = v
        }
        else if (substr(L[i], 1, 15) == ".xaxis1.addmax ") {
            v = strtoreal(substr(L[i], 16, .))
            if (hi >= . | v > hi) hi = v
        }
        else if (substr(L[i], 1, 26) == ".xaxis1.major.range_ticks ") {
            w = tokens(substr(L[i], 27, .))
            tmin = strtoreal(w[1])
            tmax = strtoreal(w[2])
            nt = floor((tmax - tmin) / strtoreal(w[3])) + 1
        }
        else if (substr(L[i], 1, 24) == ".xaxis1.major.add_ticks ") {
            w = tokens(subinstr(substr(L[i], 25, .), ",", " "))
            nt = 0
            tmin = tmax = .
            for (j = 1; j <= cols(w); j++) {
                v = strtoreal(w[j])
                if (v < .) {
                    nt++
                    if (tmin >= . | v < tmin) tmin = v
                    if (tmax >= . | v > tmax) tmax = v
                    p = strpos(w[j], ".")
                    if (p > 0 & strlen(w[j]) - p > dec) dec = strlen(w[j]) - p
                }
            }
        }
    }
    if (tmin < . & (lo >= . | tmin < lo)) lo = tmin
    if (tmax < . & (hi >= . | tmax > hi)) hi = tmax
    return((lo, hi, tmin, tmax, nt, dec))
}

// Reference lines on the x axis: (count, value1, value2, ...)
real rowvector _v190_xlines(string scalar f)
{
    string colvector L
    string rowvector w
    real rowvector out
    real scalar i, k
    L = cat(f)
    out = 0
    for (i = 1; i <= rows(L); i++) {
        if (strpos(L[i], ".xaxis1.plotregion.declare_xyline") == 1) {
            w = tokens(L[i])
            k = 1
            while (k <= cols(w) & w[k] != ".gridline_g.new") k++
            out[1] = out[1] + 1
            out = out, strtoreal(w[k + 1])
        }
    }
    return(out)
}

// Plot types in declaration order
string rowvector _v190_types(string scalar f)
{
    string colvector L
    string rowvector out
    real scalar i, a, b
    L = cat(f)
    out = J(1, 0, "")
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, 24) == ".plotregion1.Declare plo") {
            a = strpos(L[i], "type(")
            if (a > 0) {
                b = strpos(substr(L[i], a, .), ")")
                out = out, substr(L[i], a + 5, b - 6)
            }
        }
    }
    return(out)
}

// (min, max) of the first serset series with this name
real rowvector _v190_ser(string scalar f, string scalar nm)
{
    string colvector L
    real scalar i, on, mn, mx
    L = cat(f)
    on = 0
    mn = mx = .
    for (i = 1; i <= rows(L); i++) {
        if (L[i] == ".name = " + char(96) + char(34) + nm + char(34) + char(39)) on = 1
        else if (on & substr(L[i], 1, 6) == ".min =") mn = strtoreal(substr(L[i], 7, .))
        else if (on & substr(L[i], 1, 6) == ".max =") {
            mx = strtoreal(substr(L[i], 7, .))
            break
        }
    }
    return((mn, mx))
}

real scalar _v190_hdr(string scalar f, string scalar key)
{
    string colvector L
    real scalar i
    L = cat(f)
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, strlen(key) + 5) == "*! " + key + ": ") {
            return(strtoreal(substr(L[i], strlen(key) + 6, .)))
        }
    }
    return(.)
}

string scalar _v190_line(string scalar f, string scalar prefix)
{
    string colvector L
    real scalar i
    L = cat(f)
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, strlen(prefix)) == prefix) return(substr(L[i], strlen(prefix) + 1, .))
    }
    return("")
}
end

* Binary fixtures: independent covariates (tiny SMDs) and a confounded set
clear
set seed 20261029
set obs 3000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double x3 = rnormal()
gen byte t = runiform() < 0.5
gen double ps = 0.5
gen double w = 1 + runiform()
label variable x1 "First covariate"
tempfile small
save `small'

clear
set seed 20261030
set obs 3000
gen byte t = runiform() < 0.5
gen double x1 = rnormal() + 0.8 * t
gen double x2 = rnormal() + 0.5 * t
gen double x3 = rnormal() + 0.2 * t
gen double ps = 0.3 + 0.4 * t
gen double w = 1 + runiform()
tempfile big
save `big'

**# Love plot x range fits the data (no +/-0.5 floor)
capture noisily {
    use `small', clear
    graph drop _all
    psdash balance t ps, covariates(x1 x2 x3) wvar(w) loveplot name(v190_a)
    matrix B = r(balance)
    local smin = min(B[1,3], B[2,3], B[3,3], B[1,8], B[2,8], B[3,8])
    local smax = max(B[1,3], B[2,3], B[3,3], B[1,8], B[2,8], B[3,8])
    local thr = r(threshold)
    assert abs(`smax') < 0.3
    graph save v190_a "`gph'", replace
    mata: st_matrix("ext", _v190_ext("`gph'"))
    assert !missing(ext[1,1], ext[1,2])
    * contains every raw and adjusted SMD and +/- threshold
    assert ext[1,1] <= min(`smin', -`thr') & ext[1,2] >= max(`smax', `thr')
    * ... but is no longer padded out to the old +/-0.5 floor
    assert ext[1,2] < 0.4 & ext[1,1] > -0.4
    * the plotted series are the returned SMDs
    mata: st_matrix("sr", _v190_ser("`gph'", "smd_raw"))
    mata: st_matrix("sa", _v190_ser("`gph'", "smd_adj"))
    assert !missing(sr[1,1], min(B[1,3], B[2,3], B[3,3]))
    assert reldif(sr[1,1], min(B[1,3], B[2,3], B[3,3])) < 1e-9
    assert !missing(sr[1,2], max(B[1,3], B[2,3], B[3,3]))
    assert reldif(sr[1,2], max(B[1,3], B[2,3], B[3,3])) < 1e-9
    assert !missing(sa[1,1], min(B[1,8], B[2,8], B[3,8]))
    assert reldif(sa[1,1], min(B[1,8], B[2,8], B[3,8])) < 1e-9
    assert !missing(sa[1,2], max(B[1,8], B[2,8], B[3,8]))
    assert reldif(sa[1,2], max(B[1,8], B[2,8], B[3,8])) < 1e-9
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' love_range_small"
}
else local ++pass

* all-positive SMDs: the left half is not left empty
capture noisily {
    use `big', clear
    graph drop _all
    psdash balance t ps, covariates(x1 x2 x3) wvar(w) loveplot name(v190_b)
    matrix B = r(balance)
    local smax = max(B[1,3], B[2,3], B[3,3], B[1,8], B[2,8], B[3,8])
    local smin = min(B[1,3], B[2,3], B[3,3], B[1,8], B[2,8], B[3,8])
    assert `smin' > 0 | abs(`smin') < 0.1
    assert `smax' > 0.6
    graph save v190_b "`gph'", replace
    mata: st_matrix("ext", _v190_ext("`gph'"))
    assert ext[1,2] >= `smax'
    * left edge reaches only just past -threshold, not -smax
    assert ext[1,1] <= -0.1 & ext[1,1] > -0.25
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' love_range_positive"
}
else local ++pass

* ticks are on a round step with no floating-point residue
capture noisily {
    use `big', clear
    graph drop _all
    psdash balance t ps, covariates(x1 x2 x3) wvar(w) loveplot name(v190_c)
    graph save v190_c "`gph'", replace
    mata: st_matrix("ext", _v190_ext("`gph'"))
    assert ext[1,5] >= 3 & ext[1,5] <= 10
    assert ext[1,6] <= 3
    assert ext[1,3] <= -0.1 & ext[1,4] >= 0.8
    * fitted: the first tick is not the old symmetric mirror of the last
    assert ext[1,3] > -0.3
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' love_round_ticks"
}
else local ++pass

* the two red dashed threshold xlines are replaced by a shaded band behind the markers
capture noisily {
    use `small', clear
    graph drop _all
    psdash balance t ps, covariates(x1 x2 x3) wvar(w) loveplot name(v190_d) threshold(0.25)
    graph save v190_d "`gph'", replace
    * only the zero line remains
    mata: st_matrix("xl", _v190_xlines("`gph'"))
    assert xl[1,1] == 1
    assert xl[1,2] == 0
    * band is the first (rearmost) plot, an area from -threshold to +threshold
    mata: st_local("types", invtokens(_v190_types("`gph'")))
    assert word("`types'", 1) == "rarea"
    assert wordcount("`types'") == 3
    mata: st_matrix("bl", _v190_ser("`gph'", "band_lo"))
    mata: st_matrix("bh", _v190_ser("`gph'", "band_hi"))
    assert bl[1,1] == -0.25 & bh[1,2] == 0.25
    * the axis still contains +/- threshold when every SMD is tiny
    mata: st_matrix("ext", _v190_ext("`gph'"))
    assert ext[1,1] <= -0.25 & ext[1,2] >= 0.25
    * the band is explained by a legend key
    mata: st_local("lg", _v190_line("`gph'", ".legend.parse_order "))
    assert strpos(`"`lg'"', "|SMD| < 0.25") > 0
    graph describe v190_d
    assert strpos(`"`r(command)'"', "lcolor(red)") == 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' love_band_not_lines"
}
else local ++pass

* raw-only (nowvar) love plot gets the same range, band and a legend key
capture noisily {
    use `big', clear
    graph drop _all
    psdash balance t ps, covariates(x1 x2 x3) nowvar loveplot name(v190_e)
    matrix B = r(balance)
    local smax = max(B[1,3], B[2,3], B[3,3])
    graph save v190_e "`gph'", replace
    mata: st_matrix("xl", _v190_xlines("`gph'"))
    assert xl[1,1] == 1
    mata: st_local("types", invtokens(_v190_types("`gph'")))
    assert "`types'" == "rarea scatter"
    mata: st_matrix("ext", _v190_ext("`gph'"))
    assert ext[1,2] >= `smax' & ext[1,1] > -0.25
    mata: st_local("lg", _v190_line("`gph'", ".legend.parse_order "))
    assert strpos(`"`lg'"', "|SMD| < 0.1") > 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' love_raw_only"
}
else local ++pass

**# Strategies overlay: same fitted range and band
capture noisily {
    use `big', clear
    graph drop _all
    psdash balance t ps, covariates(x1 x2 x3) strategies(raw ate att) name(v190_f)
    graph save v190_f "`gph'", replace
    mata: st_matrix("xl", _v190_xlines("`gph'"))
    assert xl[1,1] == 1 & xl[1,2] == 0
    mata: st_local("types", invtokens(_v190_types("`gph'")))
    assert word("`types'", 1) == "rarea" & wordcount("`types'") == 4
    local hi = .
    local lo = .
    forvalues s = 1/3 {
        mata: st_matrix("s`s'", _v190_ser("`gph'", "smd_`s'"))
        local hi = max(cond(missing(`hi'), s`s'[1,2], `hi'), s`s'[1,2])
        local lo = min(cond(missing(`lo'), s`s'[1,1], `lo'), s`s'[1,1])
    }
    mata: st_matrix("ext", _v190_ext("`gph'"))
    assert ext[1,2] >= `hi' & ext[1,1] <= min(`lo', -0.1)
    assert ext[1,1] > -0.25
    * legend keys name the strategies and the band, and none is shifted
    mata: st_local("lg", _v190_line("`gph'", ".legend.parse_order "))
    assert strpos(`"`lg'"', `"2 "Unadjusted" 3 "ATE" 4 "ATT""') > 0
    assert strpos(`"`lg'"', "|SMD| < 0.1") > 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' strategies_range_band"
}
else local ++pass

**# Row spacing is proportional to the number of covariates
capture noisily {
    clear
    set seed 20261031
    set obs 1500
    gen byte t = runiform() < 0.5
    gen double ps = 0.5
    gen double w = 1 + runiform()
    forvalues k = 1/40 {
        gen double z`k' = rnormal() + 0.2 * t
    }
    local prev = .
    foreach n in 3 5 15 40 {
        graph drop _all
        psdash balance t ps, covariates(z1-z`n') wvar(w) loveplot name(v190_n`n')
        graph save v190_n`n' "`gph'", replace
        mata: st_numscalar("hy", _v190_hdr("`gph'", "ysize"))
        local ys`n' = scalar(hy)
        assert !missing(`ys`n'')
        if !missing(`prev') assert `ys`n'' > `prev'
        local prev = `ys`n''
    }
    * a small plot is compact (default height is 4 in), a large one grows,
    * and the per-covariate height is about constant between 5 and 15
    assert `ys5' < 4
    * ... but never so short that a default-width export drops under ~300 px
    assert `ys3' >= 3.2
    assert `ys40' > 8 & `ys40' <= 12
    assert abs((`ys15' - `ys5') / 10 - (`ys40' - `ys15') / 25) < 0.15 | `ys40' == 12
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' row_spacing_proportional"
}
else local ++pass

* a user ysize() in graphoptions() still wins and is not duplicated
capture noisily {
    use `big', clear
    graph drop _all
    psdash balance t ps, covariates(x1 x2 x3) wvar(w) loveplot name(v190_g) ///
        graphoptions(ysize(5))
    graph save v190_g "`gph'", replace
    mata: st_numscalar("hy", _v190_hdr("`gph'", "ysize"))
    assert scalar(hy) == 5
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' user_ysize_wins"
}
else local ++pass

* inside psdash combined the balance panel keeps scale 1 and the dashboard draws
capture noisily {
    use `big', clear
    graph drop _all
    quietly psdash combined t ps, covariates(x1 x2 x3) wvar(w)
    graph describe psdash_c_balance
    assert strpos(`"`r(command)'"', "scale(1)") > 0
    assert strpos(`"`r(command)'"', "scale(1.") == 0
    graph describe psdash_combined
    graph save psdash_c_balance "`gph'", replace
    mata: st_matrix("xl", _v190_xlines("`gph'"))
    assert xl[1,1] == 1
    mata: st_local("lg", _v190_line("`gph'", ".legend.parse_order "))
    assert strpos(`"`lg'"', "|SMD| < 0.1") > 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' combined_panel"
}
else local ++pass

**# Multi-group love plot: dodged comparisons, connectors, larger hollow markers
clear
set seed 20261101
set obs 2400
gen byte arm = floor(runiform() * 3)
gen double x1 = rnormal() + 0.6 * (arm == 1) + 0.3 * (arm == 2)
gen double x2 = rnormal() - 0.5 * (arm == 2)
gen double x3 = rnormal() + 0.2 * (arm == 1)
gen double ps0 = 1/3
gen double ps1 = 1/3
gen double ps2 = 1/3
gen double w = 1 + runiform()
tempfile mg
save `mg'

capture noisily {
    use `mg', clear
    graph drop _all
    psdash balance arm, psvars(ps0 ps1 ps2) covariates(x1 x2 x3) wvar(w) loveplot name(v190_m)
    matrix S = r(smd)
    graph save v190_m "`gph'", replace
    * band first, then per comparison connector + hollow raw + solid adjusted
    mata: st_local("types", invtokens(_v190_types("`gph'")))
    assert "`types'" == "rarea pcspike scatter scatter pcspike scatter scatter"
    * y positions are dodged: comparison 1 sits above comparison 2 by 0.25
    mata: st_matrix("y1", _v190_ser("`gph'", "ypos_1"))
    mata: st_matrix("y2", _v190_ser("`gph'", "ypos_2"))
    assert abs((y1[1,1] - y2[1,1]) - 0.25) < 1e-9
    assert abs((y1[1,2] - y2[1,2]) - 0.25) < 1e-9
    assert y1[1,1] > 0.5 & y1[1,2] < 3.5 & y2[1,1] > 0.5 & y2[1,2] < 3.5
    assert mod(y1[1,1], 1) != 0
    * x data equal the returned SMDs
    mata: st_matrix("r1", _v190_ser("`gph'", "smd_1"))
    mata: st_matrix("a1", _v190_ser("`gph'", "smda_1"))
    assert !missing(r1[1,1], min(S[1,1], S[2,1], S[3,1]))
    assert reldif(r1[1,1], min(S[1,1], S[2,1], S[3,1])) < 1e-9
    assert !missing(r1[1,2], max(S[1,1], S[2,1], S[3,1]))
    assert reldif(r1[1,2], max(S[1,1], S[2,1], S[3,1])) < 1e-9
    assert !missing(a1[1,1], min(S[1,3], S[2,3], S[3,3]))
    assert reldif(a1[1,1], min(S[1,3], S[2,3], S[3,3])) < 1e-9
    * hollow markers are enlarged, encoding and note retained
    graph describe v190_m
    local cmd `"`r(command)'"'
    assert strpos(`"`cmd'"', "msymbol(Oh) msize(medlarge)") > 0
    assert strpos(`"`cmd'"', "Hollow markers: unadjusted; solid markers: adjusted") > 0
    * the threshold lines are gone; band key is in the legend
    mata: st_matrix("xl", _v190_xlines("`gph'"))
    assert xl[1,1] == 1
    mata: st_local("lg", _v190_line("`gph'", ".legend.parse_order "))
    assert strpos(`"`lg'"', "|SMD| < 0.1") > 0
    assert strpos(`"`lg'"', "1 vs 0") > 0 & strpos(`"`lg'"', "2 vs 0") > 0
    * range fitted, not forced to the old +/-0.5 floor, contains the data
    mata: st_matrix("ext", _v190_ext("`gph'"))
    local smax = max(S[1,1], S[2,1], S[3,1], S[1,2], S[2,2], S[3,2], S[1,3], S[2,3], S[3,3], S[1,4], S[2,4], S[3,4])
    local smin = min(S[1,1], S[2,1], S[3,1], S[1,2], S[2,2], S[3,2], S[1,3], S[2,3], S[3,3], S[1,4], S[2,4], S[3,4])
    assert ext[1,2] >= `smax' & ext[1,1] <= `smin' & ext[1,1] <= -0.1
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_love_dodge_connectors"
}
else local ++pass

* without weights: no connectors (nothing to join), still dodged, band keyed
capture noisily {
    use `mg', clear
    graph drop _all
    psdash balance arm, psvars(ps0 ps1 ps2) covariates(x1 x2 x3) nowvar loveplot name(v190_m2)
    graph save v190_m2 "`gph'", replace
    mata: st_local("types", invtokens(_v190_types("`gph'")))
    assert "`types'" == "rarea scatter scatter"
    mata: st_matrix("y1", _v190_ser("`gph'", "ypos_1"))
    mata: st_matrix("y2", _v190_ser("`gph'", "ypos_2"))
    assert abs((y1[1,1] - y2[1,1]) - 0.25) < 1e-9
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_love_raw_only"
}
else local ++pass

* the multi-group dashboard panel keeps its legend on one narrow row at scale 1
capture noisily {
    use `mg', clear
    graph drop _all
    quietly psdash combined arm, psvars(ps0 ps1 ps2) covariates(x1 x2 x3) wvar(w)
    graph describe psdash_c_balance
    local cmd `"`r(command)'"'
    assert strpos(`"`cmd'"', "scale(1)") > 0
    * panel legend: small type, keys name the arm, the note names the reference
    assert strpos(`"`cmd'"', "size(small) symxsize(5)") > 0
    assert strpos(`"`cmd'"', `""1 vs 0""') == 0 & strpos(`"`cmd'"', `""2 vs 0""') == 0
    assert strpos(`"`cmd'"', "Each key: arm vs 0 (reference)") > 0
    graph describe psdash_combined
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_combined_panel"
}
else local ++pass

**# Distribution panels: shared legend, retitled figure, solid weighted vs light dashed raw
capture noisily {
    use `big', clear
    graph drop _all
    psdash balance t ps, covariates(x1 x2 x3) wvar(w) distribution(x1 x2 x3) name(v190_h)
    * panels carry no legend; one legend-only graph follows them
    foreach g in v190_h_dist1 v190_h_dist2 v190_h_dist3 {
        graph describe `g'
        assert strpos(`"`r(command)'"', "legend(off)") > 0
    }
    * the legend-only cell is a temporary graph: inside the combined figure,
    * not left in memory
    capture graph describe v190_h_distlegend
    assert _rc != 0
    quietly graph dir
    local gl `"`r(list)'"'
    local gl : list sort gl
    assert "`gl'" == "v190_h_dist v190_h_dist1 v190_h_dist2 v190_h_dist3"
    graph save v190_h_dist "`gph'", replace
    mata: st_numscalar("v190_hit", sum(strpos(cat("`gph'"), `"order(1 "Treated (weighted)" 2 "Control (weighted)" 3 "Treated (raw)" 4 "Control (raw)""') :> 0))
    assert scalar(v190_hit) >= 1
    scalar drop v190_hit
    * title: no repeated "Covariate Balance Assessment -- covariate distributions"
    graph describe v190_h_dist
    local ccmd `"`r(command)'"'
    assert strpos(`"`ccmd'"', "Covariate Distributions: Raw vs Weighted") > 0
    assert strpos(`"`ccmd'"', "Covariate Balance Assessment") == 0
    assert strpos(`"`ccmd'"', "covariate distributions") == 0
    * weighted: solid, thick, full colour; raw: dashed, lighter (opacity), same hue (pstyle)
    _psdash_pstyles
    local p2 : word 2 of `s(order)'
    graph describe v190_h_dist1
    local pcmd `"`r(command)'"'
    assert strpos(`"`pcmd'"', "pstyle(p1) lpattern(dash) lwidth(medium) lcolor(%60)") > 0
    assert strpos(`"`pcmd'"', "pstyle(p`p2') lpattern(dash) lwidth(medium) lcolor(%60)") > 0
    assert strpos(`"`pcmd'"', "pstyle(p1) lpattern(solid) lwidth(medthick)") > 0
    assert strpos(`"`pcmd'"', "pstyle(p`p2') lpattern(solid) lwidth(medthick)") > 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' dist_shared_legend"
}
else local ++pass

* an explicit title() wins verbatim; the unweighted figure is titled for treated vs control
capture noisily {
    use `big', clear
    graph drop _all
    psdash balance t ps, covariates(x1 x2) wvar(w) distribution(x1 x2) ///
        name(v190_i) title("My own title")
    graph describe v190_i_dist
    assert strpos(`"`r(command)'"', "My own title") > 0
    assert strpos(`"`r(command)'"', "Raw vs Weighted") == 0
    assert strpos(`"`r(command)'"', "covariate distributions") == 0
    graph drop _all
    psdash balance t ps, covariates(x1 x2) nowvar distribution(x1 x2) name(v190_j)
    graph describe v190_j_dist
    assert strpos(`"`r(command)'"', "Covariate Distributions: Treated vs Control") > 0
    graph save v190_j_dist "`gph'", replace
    mata: st_numscalar("v190_hit", sum(strpos(cat("`gph'"), `"order(1 "Treated" 2 "Control")"') :> 0))
    assert scalar(v190_hit) >= 1
    scalar drop v190_hit
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' dist_titles"
}
else local ++pass

* a single distribution panel keeps its own legend (nothing to share)
capture noisily {
    use `big', clear
    graph drop _all
    psdash balance t ps, covariates(x1 x2) wvar(w) distribution(x1) name(v190_k)
    graph describe v190_k_dist1
    assert strpos(`"`r(command)'"', "legend(off)") == 0
    assert strpos(`"`r(command)'"', `"3 "Treated (weighted)""') > 0
    capture graph describe v190_k_distlegend
    assert _rc != 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' dist_single_panel"
}
else local ++pass

**# Returned SMDs are not touched by the graph changes
capture noisily {
    use `big', clear
    quietly psdash balance t ps, covariates(x1 x2 x3) wvar(w) nograph
    matrix B0 = r(balance)
    local m0 = r(max_smd_adj)
    graph drop _all
    quietly psdash balance t ps, covariates(x1 x2 x3) wvar(w) loveplot ///
        strategies(raw ate) distribution(x1 x2) name(v190_l)
    matrix B1 = r(balance)
    assert mreldif(B0, B1) < 1e-12
    assert !missing(r(max_smd_adj), `m0')
    assert reldif(r(max_smd_adj), `m0') < 1e-12
    * independent raw SMD for x1: (m1 - m0) / sqrt((v1 + v0) / 2)
    quietly summarize x1 if t == 1
    local m1 = r(mean)
    local v1 = r(Var)
    quietly summarize x1 if t == 0
    local d = (`m1' - r(mean)) / sqrt((`v1' + r(Var)) / 2)
    assert !missing(abs(B1[1,3]), abs(`d'))
    assert reldif(abs(B1[1,3]), abs(`d')) < 1e-9
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' returns_unchanged"
}
else local ++pass

**# fix 3: distribution() with a 26-character name() (legend name was 37 chars)
capture noisily {
    use `big', clear
    graph drop _all
    local nm "abcdefghijklmnopqrstuvwxyz"
    assert strlen("`nm'") == 26
    psdash balance t ps, covariates(x1 x2 x3) wvar(w) distribution(x1 x2) name(`nm')
    quietly graph dir
    local gl `"`r(list)'"'
    local gl : list sort gl
    assert "`gl'" == "`nm'_dist `nm'_dist1 `nm'_dist2"
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' dist_long_name"
}
else local ++pass

**# fix 5: |SMD| in the thousands keeps a short tick ladder (was r(198))
capture noisily {
    use `big', clear
    set seed 77
    gen double nearconst = 5 + t + 1e-7 * rnormal()
    graph drop _all
    psdash balance t ps, covariates(nearconst x1) wvar(w) loveplot name(v190_huge)
    matrix B = r(balance)
    assert abs(B[1,3]) > 1000
    graph describe v190_huge
    assert regexm(`"`r(command)'"', "xlabel\(([-0-9. ]+)\)")
    local nlab : word count `=regexs(1)'
    assert `nlab' >= 2 & `nlab' <= 10
    graph save v190_huge "`gph'", replace
    mata: st_matrix("ext", _v190_ext("`gph'"))
    assert ext[1,2] >= abs(B[1,3]) | ext[1,1] <= -abs(B[1,3])
    * the dashboard reaches a verdict instead of failing on the panel
    graph drop _all
    quietly psdash combined t ps, covariates(nearconst x1) wvar(w)
    assert "`r(verdict)'" == "FAIL"
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' huge_smd_ticks"
}
else local ++pass

**# fix 6: ysiz()/aspect() abbreviations keep the user's shape (no auto ysize/scale)
capture noisily {
    use `big', clear
    graph drop _all
    psdash balance t ps, covariates(x1 x2 x3) wvar(w) loveplot name(v190_ys) ///
        graphoptions(ysiz(5))
    graph describe v190_ys
    assert strpos(`"`r(command)'"', " scale(") == 0
    graph save v190_ys "`gph'", replace
    mata: st_numscalar("hy", _v190_hdr("`gph'", "ysize"))
    assert abs(scalar(hy) - 5) < 1e-9
    graph drop _all
    psdash balance t ps, covariates(x1 x2 x3) wvar(w) loveplot name(v190_as) ///
        graphoptions(aspect(1))
    graph describe v190_as
    assert strpos(`"`r(command)'"', " scale(") == 0
    assert strpos(`"`r(command)'"', " ysize(") == 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' shape_option_abbrev"
}
else local ++pass

**# nits: band key keeps a leading zero and the user's decimals; panel mode
**#       is set by psdash combined, not by the graph's name
capture noisily {
    use `big', clear
    graph drop _all
    psdash balance t ps, covariates(x1 x2 x3) wvar(w) loveplot threshold(0.125) name(v190_k1)
    graph save v190_k1 "`gph'", replace
    mata: st_local("lg", _v190_line("`gph'", ".legend.parse_order "))
    assert strpos(`"`lg'"', "|SMD| < 0.125") > 0
    * a user graph that happens to be named psdash_c_balance is a full graph
    graph drop _all
    psdash balance t ps, covariates(x1 x2 x3) wvar(w) loveplot name(psdash_c_balance)
    graph describe psdash_c_balance
    assert strpos(`"`r(command)'"', "scale(1)") == 0
    assert strpos(`"`r(command)'"', "size(small) symxsize(5)") == 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' band_key_and_panel_flag"
}
else local ++pass

capture erase "`gph'"
graph drop _all
display "RESULT: test_v190_balance_graphs tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' display as error "Failed:`failed'"
_psdash_qa_cleanup
log close
if `fail' exit 1
