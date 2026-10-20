* _kmplot_qa_cifsupport.do
* Shared oracles and SVG readers for the competing-risk, weighting, masking and
* layout suites (crossval_kmplot_cif.do, validation_kmplot_cif_oracle.do,
* test_kmplot_compete_errors.do, test_kmplot_riskweight_mask.do,
* test_kmplot_axis_layout.do)
* Author: Timothy P Copeland, Karolinska Institutet
*
* _kmqa_aj       hand-coded Aalen-Johansen estimator, the logic of the Table 2
*                bookmark of the Female_Cancers_DMT study do-file (collapse to
*                one row per arm and time, reverse cumulative sum for the
*                number at risk, all-cause survival, then the cumulative
*                incidence).  Needs variables arm, t, w (weight), cause (0/1/2).
* _kmqa_step     right-continuous step lookup of a reference curve at times
* _kmqa_cmp      compare a kmplot saving() curve with a reference curve at every
*                reference time
* _kmqa_svgtext  read the <text> elements of an SVG into a dataset
* _kmqa_svgcanvas  fills of the graph-region rectangles that cover the whole SVG canvas
* _kmqa_curvediff  largest estimate difference of two saving() files
* _kmqa_run, _kmqa_expect  run a command with captured output; assert rc, message and data unchanged
* _kmqa_init, _kmqa_record, _kmqa_finish  test counters and the RESULT sentinel

version 16.0

capture program drop _kmqa_aj
program define _kmqa_aj
    version 16.0
    * In memory: arm t w cause (no delayed entry).  Leaves: arm time cif.
    syntax , [KEEPS]
    quietly {
        gen double w1 = w * (cause == 1)
        gen double w2 = w * (cause == 2)
        collapse (sum) d1=w1 d2=w2 nout=w, by(arm t)
        gsort arm -t
        by arm: gen double n = sum(nout)
        sort arm t
        by arm: gen double s = 1 - (d1 + d2) / n
        by arm: replace s = s * s[_n-1] if _n > 1
        by arm: gen double cif = sum(cond(_n == 1, 1, s[_n-1]) * d1 / n)
        rename t time
        keep arm time cif
    }
end

capture program drop _kmqa_step
program define _kmqa_step, rclass
    version 16.0
    * In memory: reference curve with arm time cif.  Value of arm `g' at `tm'
    * (0 before the first row).
    syntax , GRoup(real) TIME(real)
    quietly summarize time if arm == `group' & time <= `time', meanonly
    if r(N) == 0 {
        return scalar value = 0
        exit
    }
    local tl = r(max)
    quietly summarize cif if arm == `group' & time == `tl', meanonly
    return scalar value = r(max)
end

capture program drop _kmqa_cmp
program define _kmqa_cmp, rclass
    version 16.0
    * Compare the kmplot saving() file `km' with the reference dataset `ref'
    * (variables group time est, optional lo hi) at every reference time:
    * the kmplot value is the last saved row at or before that time.
    syntax , KM(string) REF(string) [BOUNDS]
    preserve
    quietly {
        use `"`km'"', clear
        keep group time estimate lower upper
        gen byte src = 0
        gen long ord = _n
        gen double ref_est = .
        gen double ref_lo = .
        gen double ref_hi = .
        tempfile kmrows
        save `"`kmrows'"'
        use `"`ref'"', clear
        capture confirm variable lo
        if _rc gen double lo = .
        capture confirm variable hi
        if _rc gen double hi = .
        rename (est lo hi) (ref_est ref_lo ref_hi)
        * Reference times come through a CSV round trip that can move a double
        * by an ulp; nudging them forward by 1e-9 (far below the spacing of any
        * fixture's distinct times) keeps the post-jump value at a jump time.
        replace time = time + 1e-9
        gen byte src = 1
        gen long ord = _N + _n
        append using `"`kmrows'"'
        sort group time src ord
        * carry the kmplot row values onto the reference rows that follow them
        gen double kmv = estimate if src == 0
        gen double kml = lower if src == 0
        gen double kmu = upper if src == 0
        by group: replace kmv = kmv[_n-1] if src == 1 & _n > 1
        by group: replace kml = kml[_n-1] if src == 1 & _n > 1
        by group: replace kmu = kmu[_n-1] if src == 1 & _n > 1
        keep if src == 1
        count
        local nref = r(N)
        count if missing(kmv)
        local nmiss = r(N)
        gen double ad = abs(kmv - ref_est)
        summarize ad, meanonly
        local maxd = r(max)
        local maxb = 0
        local nb = 0
        if "`bounds'" != "" {
            gen double adl = abs(kml - ref_lo) if !missing(ref_lo)
            gen double adu = abs(kmu - ref_hi) if !missing(ref_hi)
            * a reference bound that kmplot leaves missing is a failure
            count if (!missing(ref_lo) & missing(kml)) | (!missing(ref_hi) & missing(kmu))
            local nbmiss = r(N)
            summarize adl, meanonly
            local nb = r(N)
            local m1 = r(max)
            summarize adu, meanonly
            local m2 = r(max)
            local maxb = max(`m1', `m2')
            if `nbmiss' > 0 local maxb = 99
        }
    }
    restore
    return scalar nref = `nref'
    return scalar nmiss = `nmiss'
    return scalar maxdiff = `maxd'
    return scalar maxbound = `maxb'
    return scalar nbounds = `nb'
end

capture program drop _kmqa_svgtext
program define _kmqa_svgtext
    version 16.0
    * Leaves a dataset, one row per <text> element, in file order:
    * x y fs vis rot endanc midanc txt (txt with &lt; decoded)
    syntax using/
    clear
    tempname fh
    local n = 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "<text ") & regexm(`"`line'"', ">([^<]*)</text>") {
            local txt = regexs(1)
            local x = .
            local y = .
            local fs = .
            if regexm(`"`line'"', `"<text x="([0-9.-]+)" y="([0-9.-]+)""') {
                local x = real(regexs(1))
                local y = real(regexs(2))
            }
            if regexm(`"`line'"', "font-size:([0-9.]+)px") local fs = real(regexs(1))
            local vis = (strpos(`"`line'"', "opacity:0.00") == 0)
            local rot = (strpos(`"`line'"', "rotate") > 0)
            local endanc = (strpos(`"`line'"', `"text-anchor="end""') > 0)
            local midanc = (strpos(`"`line'"', `"text-anchor="middle""') > 0)
            local ++n
            local X_`n' = `x'
            local Y_`n' = `y'
            local F_`n' = `fs'
            local V_`n' = `vis'
            local R_`n' = `rot'
            local E_`n' = `endanc'
            local M_`n' = `midanc'
            local T_`n' = subinstr(`"`txt'"', "&lt;", "<", .)
            local T_`n' = subinstr(`"`T_`n''"', "&gt;", ">", .)
            local T_`n' = subinstr(`"`T_`n''"', "&amp;", "&", .)
        }
        file read `fh' line
    }
    file close `fh'
    quietly set obs `n'
    quietly {
        gen double x = .
        gen double y = .
        gen double fs = .
        gen byte vis = .
        gen byte rot = .
        gen byte endanc = .
        gen byte midanc = .
        gen strL txt = ""
        forvalues i = 1/`n' {
            replace x = `X_`i'' in `i'
            replace y = `Y_`i'' in `i'
            replace fs = `F_`i'' in `i'
            replace vis = `V_`i'' in `i'
            replace rot = `R_`i'' in `i'
            replace endanc = `E_`i'' in `i'
            replace midanc = `M_`i'' in `i'
            replace txt = `"`T_`i''"' in `i'
        }
        gen long ord = _n
    }
end

capture program drop _kmqa_svgcanvas
program define _kmqa_svgcanvas, rclass
    version 16.0
    * Fill colours of every rectangle that spans the whole canvas.
    syntax using/
    local w = .
    local h = .
    local fills ""
    local n = 0
    tempname fh
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "viewBox=") & ///
            regexm(`"`line'"', `"viewBox="0 0 ([0-9.]+) ([0-9.]+)""') {
            local w = real(regexs(1))
            local h = real(regexs(2))
        }
        * the bare page rectangle (stroke:none) sits behind the graph region and
        * keeps the scheme colour even for a plain Stata graph; skip it
        if strpos(`"`line'"', "<rect ") & strpos(`"`line'"', "stroke:none") == 0 & ///
            regexm(`"`line'"', `"x="([0-9.]+)" y="([0-9.]+)" width="([0-9.]+)" height="([0-9.]+)" style="fill:(#[0-9A-Fa-f]+|none)"') {
            local rx = real(regexs(1))
            local ry = real(regexs(2))
            local rw = real(regexs(3))
            local rh = real(regexs(4))
            if `rx' < 1 & `ry' < 1 & `rw' > `w' - 2 & `rh' > `h' - 2 {
                local ++n
                local fills "`fills' `=upper(regexs(5))'"
            }
        }
        file read `fh' line
    }
    file close `fh'
    return scalar width = `w'
    return scalar height = `h'
    return scalar n = `n'
    return local fills = strtrim("`fills'")
end

capture program drop _kmqa_init
program define _kmqa_init
    version 16.0
    global KMQA_T 0
    global KMQA_P 0
    global KMQA_F 0
end

capture program drop _kmqa_record
program define _kmqa_record
    version 16.0
    * Call right after a capture noisily { ... } block:
    *   _kmqa_record, name("x") rc(`=_rc')
    syntax , NAME(string) RC(integer)
    capture restore
    global KMQA_T = $KMQA_T + 1
    if `rc' == 0 {
        global KMQA_P = $KMQA_P + 1
        display as result "PASS: `name'"
    }
    else {
        global KMQA_F = $KMQA_F + 1
        display as error "FAIL: `name' (rc=`rc')"
    }
end

capture program drop _kmqa_finish
program define _kmqa_finish
    version 16.0
    syntax , SUITE(string)
    if $KMQA_T != $KMQA_P + $KMQA_F {
        display as error "RESULT: `suite' counters do not reconcile"
        exit 9
    }
    if $KMQA_F == 0 {
        display as result "RESULT: `suite' tests=$KMQA_T pass=$KMQA_P fail=0"
    }
    else {
        display as error "RESULT: `suite' tests=$KMQA_T pass=$KMQA_P fail=$KMQA_F"
        exit 1
    }
end

capture program drop _kmqa_run
program define _kmqa_run, rclass
    version 16.0
    * Run one command with its console output captured in a named text log.
    * Returns r(rc) and r(text) (all captured lines joined by " | ").
    syntax , CMD(string asis)
    tempfile lf
    capture log close kmqa_run
    quietly log using `"`lf'"', text replace name(kmqa_run)
    capture noisily `cmd'
    local rc = _rc
    quietly log close kmqa_run
    local all ""
    tempname fh
    file open `fh' using `"`lf'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local all `"`all' | `line'"'
        file read `fh' line
    }
    file close `fh'
    return scalar rc = `rc'
    return local text `"`all'"'
end

capture program drop _kmqa_expect
program define _kmqa_expect
    version 16.0
    * Assert that a kmplot call exits with RC, prints every TEXT fragment, and
    * leaves the data in memory unchanged.
    syntax , RC(integer) CMD(string asis) [TEXT(string asis)]
    quietly datasignature
    local sig "`r(datasignature)'"
    _kmqa_run, cmd(`cmd')
    local got = r(rc)
    local msg `"`r(text)'"'
    if `got' != `rc' {
        display as error "expected rc `rc', got `got' for: `cmd'"
        display as error `"output:`msg'"'
        exit 9
    }
    foreach frag of local text {
        if strpos(`"`msg'"', `"`frag'"') == 0 {
            display as error `"message lacks "`frag'": `msg'"'
            exit 9
        }
    }
    quietly datasignature
    if "`r(datasignature)'" != "`sig'" {
        display as error "data changed by a refused call"
        exit 9
    }
end

capture program drop _kmqa_curvediff
program define _kmqa_curvediff, rclass
    version 16.0
    * Largest absolute difference of the estimate column of two saving() files
    * over their (group, time) rows.  Rows that share a (group, time) must agree
    * with each other (tied times print several rows); the two files must carry
    * the same set of (group, time).
    syntax , A(string) B(string)
    preserve
    quietly {
        use `"`a'"', clear
        collapse (min) lo_a=estimate (max) hi_a=estimate, by(group time)
        count if abs(hi_a - lo_a) > 0
        local tied_a = r(N)
        tempfile fa
        save `"`fa'"'
        use `"`b'"', clear
        collapse (min) lo_b=estimate (max) hi_b=estimate, by(group time)
        count if abs(hi_b - lo_b) > 0
        local tied_b = r(N)
        merge 1:1 group time using `"`fa'"', gen(_m)
        count if _m != 3
        local unmatched = r(N)
        keep if _m == 3
        gen double ad = abs(lo_a - lo_b)
        summarize ad, meanonly
        local maxd = r(max)
        local n = r(N)
    }
    restore
    return scalar maxdiff = `maxd'
    return scalar n = `n'
    return scalar unmatched = `unmatched'
    return scalar tied = `tied_a' + `tied_b'
end
