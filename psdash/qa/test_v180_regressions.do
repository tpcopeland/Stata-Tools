* test_v180_regressions.do -- scheme-driven series colours, Love-plot labels,
* balance nograph, support reference-line legend, multi-group legend text
* Author: Timothy P Copeland, Karolinska Institutet
*
* Every graph assertion reads the exported SVG. Fail-on-old (psdash 1.7.5):
*   colours  - series were drawn in literal navy/cranberry/forest_green/...,
*              so a monochrome scheme still produced coloured series
*   labels   - Love-plot rows showed variable names, never labels
*   nograph  - psdash balance rejected nograph with r(198)
*   support  - the trimming and support lines had no legend entry
*   mg text  - the compact overlap legend was drawn at size(tiny), and an
*              unlabelled multi-group weights legend printed literal quotes
version 16.0
clear all
capture log close _all
log using test_v180_regressions.log, replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"
local tests = 0
local pass = 0
local fail = 0
local failed ""

* graph export needs a .svg suffix; tempfile names carry their own suffix.
tempfile svgbase
* Rewrite dots in the file name only: graph export reads the suffix from the
* first dot of the name, while dots in the TMPDIR path (e.g. ~/.cache) must stay.
local svg_cut = strrpos("`svgbase'", "/")
local svg = substr("`svgbase'", 1, `svg_cut') + ///
    subinstr(substr("`svgbase'", `svg_cut' + 1, .), ".", "_", .) + ".svg"

capture mata: mata drop _v180_nongrey() _v180_lines() _v180_nsizes() ///
    _v180_lab() _v180_series_de() _v180_text_maxlen()
mata:
// Number of fill/stroke colours in an SVG that are not grey (R=G=B),
// ignoring pure red, which psdash keeps for reference lines.
real scalar _v180_nongrey(string scalar f)
{
    string colvector L
    string scalar s, hex
    real scalar i, p, n
    L = cat(f)
    n = 0
    for (i = 1; i <= rows(L); i++) {
        s = L[i]
        while ((p = strpos(s, ":#")) > 0) {
            hex = strupper(substr(s, p + 2, 6))
            s = substr(s, p + 8, .)
            if (strlen(hex) < 6) continue
            if (hex == "FF0000") continue
            if (substr(hex, 1, 2) == substr(hex, 3, 2) & ///
                substr(hex, 3, 2) == substr(hex, 5, 2)) continue
            n++
        }
    }
    return(n)
}
// CIELAB (D65) of a 6-digit hex colour.
real rowvector _v180_lab(string scalar hex)
{
    real rowvector c
    real scalar i, X, Y, Z
    c = J(1, 3, .)
    for (i = 1; i <= 3; i++) {
        c[i] = strtoreal("0x" + substr(hex, 2*i - 1, 2))
        if (c[i] >= .) {
            // strtoreal does not parse hex; do it by hand
            c[i] = 16 * (strpos("0123456789ABCDEF", substr(hex, 2*i - 1, 1)) - 1) + ///
                (strpos("0123456789ABCDEF", substr(hex, 2*i, 1)) - 1)
        }
        c[i] = c[i] / 255
        c[i] = (c[i] > .04045 ? ((c[i] + .055) / 1.055)^2.4 : c[i] / 12.92)
    }
    X = (c[1]*.4124 + c[2]*.3576 + c[3]*.1805) / .95047
    Y =  c[1]*.2126 + c[2]*.7152 + c[3]*.0722
    Z = (c[1]*.0193 + c[2]*.1192 + c[3]*.9505) / 1.08883
    X = (X > .008856 ? X^(1/3) : 7.787*X + 16/116)
    Y = (Y > .008856 ? Y^(1/3) : 7.787*Y + 16/116)
    Z = (Z > .008856 ? Z^(1/3) : 7.787*Z + 16/116)
    return((116*Y - 16, 500*(X - Y), 200*(Y - Z)))
}
// The kdensity series are the SVG's <path> elements: their non-grey,
// non-red stroke colours must be exactly two (the two arms). Returns their
// CIE76 distance, or -k when k != 2 were found.
real scalar _v180_series_de(string scalar f)
{
    string colvector L, cols
    string scalar s, hex
    real scalar i, p
    L = cat(f)
    cols = J(0, 1, "")
    for (i = 1; i <= rows(L); i++) {
        if (!strpos(substr(L[i], 1, 12), "<path")) continue   // lines start with a tab
        s = L[i]
        while ((p = strpos(s, "stroke:#")) > 0) {
            hex = strupper(substr(s, p + 8, 6))
            s = substr(s, p + 14, .)
            if (hex == "FF0000") continue
            if (substr(hex, 1, 2) == substr(hex, 3, 2) & ///
                substr(hex, 3, 2) == substr(hex, 5, 2)) continue
            cols = cols \ hex
        }
    }
    cols = uniqrows(cols)
    if (rows(cols) != 2) return(-rows(cols))
    return(sqrt(sum((_v180_lab(cols[1]) - _v180_lab(cols[2])):^2)))
}
// Longest <text> content in an SVG that starts with prefix.
real scalar _v180_text_maxlen(string scalar f, string scalar prefix)
{
    string colvector L
    real scalar i, m
    string scalar t
    L = cat(f)
    m = 0
    for (i = 1; i <= rows(L); i++) {
        if (regexm(L[i], ">([^<]*)</text>")) {
            t = regexs(1)
            if (substr(t, 1, strlen(prefix)) == prefix) m = max((m, ustrlen(t)))
        }
    }
    return(m)
}
// Number of lines containing pat.
real scalar _v180_lines(string scalar f, string scalar pat)
{
    string colvector L
    real scalar i, n
    L = cat(f)
    n = 0
    for (i = 1; i <= rows(L); i++) n = n + (strpos(L[i], pat) > 0)
    return(n)
}
// Number of distinct font sizes used by <text> elements whose content is txt.
real scalar _v180_nsizes(string scalar f, string scalar txt)
{
    string colvector L, sz
    real scalar i
    L = cat(f)
    sz = J(0, 1, "")
    for (i = 1; i <= rows(L); i++) {
        if (strpos(L[i], ">" + txt + "</text>")) {
            if (regexm(L[i], "font-size:([0-9.]+)px")) sz = sz \ regexs(1)
        }
    }
    if (rows(sz) == 0) return(0)
    return(rows(uniqrows(sz)))
}
end

capture program drop _v180_binary
program define _v180_binary
    clear
    set seed 180
    set obs 600
    generate double age = rnormal(50, 10)
    label variable age "Age in years"
    generate byte female = runiform() < .5
    label variable female "Female sex"
    generate double bmi = rnormal(27, 4)
    generate byte race = 1 + floor(runiform() * 3)
    label define v180race 1 "White" 2 "Black" 3 "Other"
    label values race v180race
    label variable race "Race group"
    generate double ps = invlogit(-3 + .05 * age + .3 * female)
    generate byte t = runiform() < ps
    generate double w = cond(t, 1 / ps, 1 / (1 - ps))
end

capture program drop _v180_multigroup
program define _v180_multigroup
    args labelled
    clear
    set seed 181
    set obs 900
    generate double age = rnormal(50, 10)
    generate byte female = runiform() < .5
    * near-equal arms so no weight is extreme (keeps panel warnings, which
    * print even under quietly, out of this suite's log)
    generate double u = runiform() + .002 * (age - 50)
    generate byte arm = 1 + (u > 1/3) + (u > 2/3)
    drop u
    if `labelled' {
        label define v180arm 1 "Placebo" 2 "Low dose" 3 "High dose"
        label values arm v180arm
    }
    quietly mlogit arm age female
    quietly predict double p1 p2 p3, pr
end

**# Series colours follow the scheme (s1mono: every series is grey)
local graphs ""
local graphs `"`graphs' "bal_love|_v180_binary|psdash balance t ps, covariates(age female bmi) wvar(w) loveplot""'
local graphs `"`graphs' "bal_strat|_v180_binary|psdash balance t ps, covariates(age female bmi) strategies(raw ate att)""'
local graphs `"`graphs' "bal_dist|_v180_binary|psdash balance t ps, covariates(age female bmi) wvar(w) distribution(age)""'
local graphs `"`graphs' "overlap_kd|_v180_binary|psdash overlap t ps,""'
local graphs `"`graphs' "overlap_hist|_v180_binary|psdash overlap t ps, histogram""'
local graphs `"`graphs' "weights|_v180_binary|psdash weights t ps, wvar(w) graph""'
local graphs `"`graphs' "support|_v180_binary|psdash support t ps, crump""'
local graphs `"`graphs' "mg_love|_v180_multigroup 1|psdash balance arm, psvars(p1 p2 p3) covariates(age female) loveplot""'
local graphs `"`graphs' "mg_weights|_v180_multigroup 1|psdash weights arm, psvars(p1 p2 p3) graph""'
local graphs `"`graphs' "mg_overlap_kd|_v180_multigroup 1|psdash overlap arm, psvars(p1 p2 p3)""'
local graphs `"`graphs' "mg_overlap_hist|_v180_multigroup 1|psdash overlap arm, psvars(p1 p2 p3) histogram""'
foreach spec of local graphs {
    gettoken id rest : spec, parse("|")
    gettoken bar rest : rest, parse("|")
    gettoken setup rest : rest, parse("|")
    gettoken bar cmd : rest, parse("|")
    capture noisily {
        `setup'
        graph drop _all
        * quietly: panel WARNING text is not under test here
        quietly `cmd' scheme(s1mono)
        quietly graph export "`svg'", replace
        mata: st_local("nongrey", strofreal(_v180_nongrey("`svg'")))
        display "`id': non-grey colours under s1mono = `nongrey'"
        assert `nongrey' == 0
    }
    local rc = _rc
    local ++tests
    if `rc' {
        local ++fail
        local failed "`failed' colour_`id'"
    }
    else local ++pass
}

**# The default scheme still draws treated and control in different colours
capture noisily {
    _v180_binary
    graph drop _all
    psdash support t ps, scheme(s2color)
    quietly graph export "`svg'", replace
    mata: st_local("nongrey", strofreal(_v180_nongrey("`svg'")))
    assert `nongrey' > 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' colour_default_scheme"
}
else local ++pass

**# Love plot rows use variable and value labels; varnames restores names
capture noisily {
    _v180_binary
    graph drop _all
    psdash balance t ps, covariates(age female i.race) wvar(w) loveplot
    quietly graph export "`svg'", replace
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">Age in years</text>")))
    assert `a' == 1
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">Race group: Black</text>")))
    assert `a' == 1
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">age</text>")))
    assert `a' == 0
    * the console table keeps names
    matrix B = r(balance)
    local rn : rownames B
    assert "`: word 1 of `rn''" == "age"

    graph drop _all
    psdash balance t ps, covariates(age female i.race) wvar(w) loveplot varnames
    quietly graph export "`svg'", replace
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">age</text>")))
    assert `a' == 1
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">2.race</text>")))
    assert `a' == 1
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">Age in years</text>")))
    assert `a' == 0

    * unlabelled covariate falls back to its name
    graph drop _all
    psdash balance t ps, covariates(age bmi) wvar(w) loveplot
    quietly graph export "`svg'", replace
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">bmi</text>")))
    assert `a' == 1

    * distribution panels use the label too
    graph drop _all
    psdash balance t ps, covariates(age bmi) wvar(w) distribution(age)
    quietly graph export "`svg'", replace
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">Age in years</text>")))
    assert `a' >= 1
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' loveplot_labels"
}
else local ++pass

**# Labels with SMCL/macro characters stay inert in the plot
capture noisily {
    _v180_binary
    label variable age `"Age "yrs" {it} `=char(96)'x"'
    graph drop _all
    psdash balance t ps, covariates(age female) wvar(w) loveplot
    quietly graph export "`svg'", replace
    mata: st_local("a", strofreal(_v180_lines("`svg'", "{it}")))
    assert `a' == 1
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' loveplot_label_inert"
}
else local ++pass

**# psdash balance accepts nograph: same results, no graph drawn
capture noisily {
    _v180_binary
    graph drop _all
    psdash balance t ps, covariates(age female bmi) wvar(w)
    matrix B0 = r(balance)
    local m0 = r(max_smd_adj)
    psdash balance t ps, covariates(age female bmi) wvar(w) loveplot ///
        strategies(raw ate) distribution(age) nograph
    matrix B1 = r(balance)
    * repeated identical calls differ at ~1e-16 in KS_Adj (tie order), so compare
    * to a tolerance rather than bit for bit
    assert mreldif(B0, B1) < 1e-12
    assert r(max_smd_adj) == `m0'
    capture graph describe psdash_balance
    assert _rc != 0
    capture graph describe psdash_balance_dist1
    assert _rc != 0
    * abbreviation
    psdash balance t ps, covariates(age female bmi) wvar(w) nogr
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' balance_nograph"
}
else local ++pass

**# Support graph labels its reference lines in the legend
capture noisily {
    _v180_binary
    graph drop _all
    psdash support t ps, crump
    quietly graph export "`svg'", replace
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">Crump trimming bounds</text>")))
    assert `a' == 1
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">Common support bounds</text>")))
    assert `a' == 1
    graph drop _all
    psdash support t ps, threshold(.1)
    quietly graph export "`svg'", replace
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">Trimming bounds</text>")))
    assert `a' == 1
    graph drop _all
    psdash support t ps
    quietly graph export "`svg'", replace
    mata: st_local("a", strofreal(_v180_lines("`svg'", "rimming bounds</text>")))
    assert `a' == 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' support_legend"
}
else local ++pass

**# Compact multi-group overlap legend uses the axis-label size
capture noisily {
    _v180_multigroup 1
    graph drop _all
    psdash overlap arm, psvars(p1 p2 p3) compact
    quietly graph export "`svg'", replace
    * "Placebo" is both an axis group label and a legend key
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">Placebo</text>")))
    assert `a' == 2
    mata: st_local("a", strofreal(_v180_nsizes("`svg'", "Placebo")))
    assert `a' == 1
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_compact_legend_size"
}
else local ++pass

**# Unlabelled multi-group weights legend has no literal quotes
capture noisily {
    _v180_multigroup 0
    graph drop _all
    quietly psdash weights arm, psvars(p1 p2 p3) graph
    quietly graph export "`svg'", replace
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">Group 1</text>")))
    assert `a' == 1
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' mg_weights_group_label"
}
else local ++pass

**# Two arms stay distinguishable in sequential schemes (p1 vs p6)
* p1 and p2 are near-identical in viridis, cividis, ukraine and piyg
* (CIE76 7.5-20.9); p1 vs p6 is 38-90 there. Threshold 30.
local repo_dir = substr("`pkg_dir'", 1, strlen("`pkg_dir'") - strlen("/psdash"))
capture noisily {
    quietly net install tc_schemes, from("`repo_dir'/tc_schemes") replace
    foreach sch in white_viridis white_cividis ukraine white_piyg {
        foreach g in overlap support {
            _v180_binary
            graph drop _all
            if "`g'" == "overlap" psdash overlap t ps, scheme(`sch')
            else psdash support t ps, scheme(`sch')
            quietly graph export "`svg'", replace
            mata: st_local("de", strofreal(_v180_series_de("`svg'")))
            display "`sch' `g': arm colour distance (CIE76) = `de'"
            assert `de' >= 30
        }
    }
    capture ado uninstall tc_schemes
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' two_arm_colour_distance"
}
else local ++pass

**# Long labels are shortened; duplicate labels are disambiguated
capture noisily {
    _v180_binary
    label variable age "Age at the index date in completed years, from the national population register"
    label variable bmi "Female sex"
    graph drop _all
    psdash balance t ps, covariates(age female bmi) wvar(w) loveplot
    quietly graph export "`svg'", replace
    mata: st_local("a", strofreal(_v180_text_maxlen("`svg'", "Age at the index")))
    assert `a' == 40
    mata: st_local("a", strofreal(_v180_lines("`svg'", "...</text>")))
    assert `a' == 1
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">Female sex (female)</text>")))
    assert `a' == 1
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">Female sex (bmi)</text>")))
    assert `a' == 1
    * the title is still drawn in full
    mata: st_local("a", strofreal(_v180_lines("`svg'", ">Covariate Balance Assessment</text>")))
    assert `a' == 1
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' long_and_duplicate_labels"
}
else local ++pass

capture erase "`svg'"
graph drop _all
display "RESULT: test_v180_regressions tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' display as error "Failed:`failed'"
_psdash_qa_cleanup
log close
if `fail' exit 1
