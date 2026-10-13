* mean() plots are deterministic and never join two different ids.
version 16.0
clear all
set varabbrev off
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall spaghetti
quietly net install spaghetti, from("`pkg_dir'") replace
local tests = 0
local pass = 0
local fail = 0

* Parses the individual-trajectory paths (fill:none with stroke-opacity) of an
* exported SVG. Pixel y is mapped back to data y from the known data range, and
* each subpath must stay inside one id band (ids sit 100 y-units apart; a
* trajectory varies by < 10). Returns r(nsub), r(ncross), r(nback).
capture mata: mata drop _sp_scan_svg()
mata:
void _sp_scan_svg(string scalar file, real scalar ymin, real scalar ymax)
{
    real scalar fh, i, j, k, ay, pxmin, pxmax, ncross, nback, nsub, lo, hi, dy
    string scalar line, d
    string rowvector toks
    real matrix pts
    pointer(real matrix) rowvector subs
    transmorphic t

    subs = J(1, 0, NULL)
    fh = fopen(file, "r")
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (!regexm(line, "<path d=" + char(34) + "([^" + char(34) + "]*)" + char(34))) continue
        d = regexs(1)
        if (!strpos(line, "stroke-opacity") | !strpos(line, "fill:none")) continue
        toks = tokens(d)
        pts = J(0, 3, .)
        for (i = 1; i <= cols(toks); i++) {
            if (substr(toks[i], 1, 1) == "M" | substr(toks[i], 1, 1) == "L") {
                pts = pts \ (substr(toks[i], 1, 1) == "M", strtoreal(substr(toks[i], 2, .)), strtoreal(toks[i+1]))
                i++
            }
        }
        if (rows(pts) == 0) continue
        start = 1
        for (i = 1; i <= rows(pts); i++) {
            if (pts[i, 1] == 1 & i > start) {
                subs = subs, &(pts[|start, 1 \ i-1, 3|])
                start = i
            }
        }
        subs = subs, &(pts[|start, 1 \ rows(pts), 3|])
    }
    fclose(fh)
    pxmin = pxmax = .
    for (k = 1; k <= cols(subs); k++) {
        pxmin = min((pxmin, min((*subs[k])[., 3])))
        pxmax = max((pxmax, max((*subs[k])[., 3])))
    }
    ay = (pxmax - pxmin) / (ymax - ymin)
    ncross = nback = 0
    nsub = cols(subs)
    for (k = 1; k <= nsub; k++) {
        dy = (*subs[k])[., 3]
        lo = (pxmax - max(dy)) / ay
        hi = (pxmax - min(dy)) / ay
        if (hi - lo > 50) ncross++
        for (j = 2; j <= rows(*subs[k]); j++) {
            if ((*subs[k])[j, 2] < (*subs[k])[j-1, 2] - 1e-6) nback++
        }
    }
    st_numscalar("r_nsub", nsub)
    st_numscalar("r_ncross", ncross)
    st_numscalar("r_nback", nback)
}
end

capture program drop _sp_scan
program define _sp_scan, rclass
    args file ymin ymax
    mata: _sp_scan_svg(`"`file'"', `ymin', `ymax')
    return scalar nsub = scalar(r_nsub)
    return scalar ncross = scalar(r_ncross)
    return scalar nback = scalar(r_nback)
end

* Unbalanced panel: 2-6 irregular visits per id, ids 100 y-units apart, and
* ties: visits come in runs of three rows sharing one time (y differs by 1).
capture program drop _sp_make
program define _sp_make
    clear
    quietly set obs 300
    generate int id = _n
    set seed 4242
    generate byte nv = 3 + mod(id * 7, 6)
    quietly expand nv
    bysort id: generate byte visit = _n
    generate double time = ceil(visit / 3) * 2 + mod(id, 3) * 0.5
    generate double y = id * 100 + visit
    generate byte g = mod(id, 2)
    drop nv
    * shuffled input order (same shuffle on every call), so tied rows are
    * not already in id order when the command sorts them
    set seed 777
    generate double u = runiform()
    sort u
    drop u
end

**# 1. identical SVG across different seeds and sort seeds
local ++tests
capture noisily {
    local svgs ""
    forvalues r = 1/4 {
        _sp_make
        quietly summarize y
        local ymin = r(min)
        local ymax = r(max)
        set seed `=100*`r''
        set sortseed `=7*`r''
        local f "`c(tmpdir)'/sp_det_`r'.svg"
        capture erase "`f'"
        quietly spaghetti y, id(id) time(time) by(g) mean(bold) export(`"`f'"', replace)
        local svgs `"`svgs' "`f'""'
    }
    tempname h1
    forvalues r = 2/4 {
        quietly checksum "`c(tmpdir)'/sp_det_1.svg"
        local c1 = r(checksum)
        quietly checksum "`c(tmpdir)'/sp_det_`r'.svg"
        assert r(checksum) == `c1'
    }
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: mean() SVG differs between runs"
    local ++fail
}

**# 2. no path segment connects two ids
local ++tests
capture noisily {
    _sp_scan "`c(tmpdir)'/sp_det_1.svg" `ymin' `ymax'
    assert r(nsub) == 300
    assert r(nback) == 0
    * one subpath per id, and none spans two id bands
    assert r(ncross) == 0
    forvalues r = 1/4 {
        capture erase "`c(tmpdir)'/sp_det_`r'.svg"
    }
}
if _rc == 0 local ++pass
else {
    display as error "FAIL: path segment joins two ids"
    local ++fail
}

display "RESULT: test_spaghetti_determinism tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
