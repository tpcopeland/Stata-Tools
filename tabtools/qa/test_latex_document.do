* test_latex_document.do - tabtools: the texdocument option (complete LaTeX documents)
*   T1  default is a bare table fragment (booktabs comment first, no \documentclass)
*   T2  texdocument on a new file: the exact frame, compiled as it is
*   T3  three-table report: texdocument, texappend, texappend texdocument
*   T4  texappend texdocument onto a fragment: rc 198, file byte-identical
*   T5  texappend texdocument into a missing file creates a document
*   T6  hand-made user paper: texappend inserts before \end{document}; prose and
*       trailing comment kept in order; compiled with pdflatex directly
*   T7  replace semantics: texdocument over a fragment, then plain latex() back
*   T8  every command (15 forms): texdocument compiles, r() unchanged,
*       texdocument without latex() is r(198)
*   T9  session file (tabtools set latex): document created, later writes inserted
*   T10 stacktab refusal: texappend texdocument onto a fragment, nothing written
* Expected values are hand-built strings and the command's own r() with and
* without texdocument; check_latex.py compiles every file with pdflatex.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _td
log using "test_latex_document.log", replace text name(_td)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global TD_OUT "`output_dir'/td"
capture mkdir "$TD_OUT"
global TD_CHECKER "`qa_dir'/tools/check_latex.py"
global TD_ND "$TD_OUT/td_needles.txt"
global TD_WB "$TD_OUT/td_stack_src.xlsx"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

**# Helpers
* CRC and length of a file, as one string ("absent" when there is none).
capture program drop _td_sum
program define _td_sum, rclass
    version 17.0
    args path
    capture confirm file "`path'"
    if _rc {
        return local sum "absent"
        exit
    }
    quietly checksum "`path'"
    return local sum "`r(checksum)':`r(filelen)'"
end

* Plain text file with a sentinel line (no \end{document}).
capture program drop _td_seed_text
program define _td_seed_text
    version 17.0
    args path
    capture erase "`path'"
    tempname fh
    file open `fh' using "`path'", write text
    file write `fh' "KEEP THIS TEXT" _n
    file close `fh'
end

* A hand-made user paper: frame, one prose line, \end{document} (padded with
* spaces when spaced == 1), then a trailing comment.
capture program drop _td_paper
program define _td_paper
    version 17.0
    args path spaced
    capture erase "`path'"
    tempname fh
    file open `fh' using "`path'", write text
    file write `fh' "\documentclass{article}" _n
    file write `fh' "\usepackage{booktabs}" _n
    file write `fh' "\begin{document}" _n
    file write `fh' "Hello user prose line." _n
    if `spaced' file write `fh' "   \end{document}   " _n
    else file write `fh' "\end{document}" _n
    file write `fh' "% trailing comment" _n
    file close `fh'
end

* Needle file for check_latex.py: _td_nd reset | _td_nd kind text.
capture program drop _td_nd
program define _td_nd
    version 17.0
    gettoken kind 0 : 0
    if "`kind'" == "reset" {
        capture erase "$TD_ND"
        exit
    }
    local text `0'
    mata: _td_fh = fopen(st_global("TD_ND"), "a"); ///
        fput(_td_fh, st_local("kind") + char(9) + st_local("text")); ///
        fclose(_td_fh)
end

* check_latex.py on a .tex file with the options that follow it; queued
* needles are passed and cleared. The verdict must start with PASS.
capture program drop _td_check
program define _td_check
    version 17.0
    gettoken tex 0 : 0
    tempfile res
    capture erase "`res'"
    local nd ""
    capture confirm file "$TD_ND"
    if !_rc local nd `"--needles "$TD_ND""'
    shell python3 "$TD_CHECKER" "`tex'" `0' `nd' --result "`res'"
    capture erase "$TD_ND"
    confirm file "`res'"
    mata: printf("{txt}  check_latex: %s\n", cat(st_local("res"))[1])
    mata: st_local("_td_ok", strofreal(substr(cat(st_local("res"))[1], 1, 4) == "PASS"))
    assert `_td_ok' == 1
end

* Lines of a text file containing a literal substring, in r(n).
capture program drop _td_count
program define _td_count, rclass
    version 17.0
    args file needle
    mata: st_local("_td_n", strofreal(sum(strpos(cat(st_local("file")), st_local("needle")) :> 0)))
    return scalar n = `_td_n'
end

* Console text of a command (nested log) in r(text), its rc in r(rc). The rc
* is hoisted right after the capture.
capture program drop _td_console
program define _td_console, rclass
    version 17.0
    tempfile lg
    quietly log using "`lg'", text replace name(_td_capture)
    capture noisily `0'
    local crc = _rc
    quietly log close _td_capture
    mata: st_local("_td_txt", invtokens(cat(st_local("lg"))', " "))
    return local text `"`macval(_td_txt)'"'
    return scalar rc = `crc'
end

* Structure of a text file: line count, first lines, last lines, counts.
capture program drop _td_info
program define _td_info, rclass
    version 17.0
    args path
    confirm file "`path'"
    mata: _td_info(st_local("path"))
    return scalar n = `_n'
    return scalar ncls = `_ncls'
    return scalar nend = `_nend'
    return scalar nbeg = `_nbeg'
    return scalar dbl = `_dbl'
    return scalar lastnb = `_lastnb'
    return local l1 `"`macval(_l1)'"'
    return local l2 `"`macval(_l2)'"'
    return local l3 `"`macval(_l3)'"'
    return local l4 `"`macval(_l4)'"'
    return local l5 `"`macval(_l5)'"'
    return local lm1 `"`macval(_lm1)'"'
    return local ln `"`macval(_ln)'"'
    return local lnb `"`macval(_lnb)'"'
end

* First and last line number whose text contains needle (exact == 1: the
* trimmed line equals it), 0 when absent, in r(first) and r(last).
capture program drop _td_pos
program define _td_pos, rclass
    version 17.0
    args path needle exact
    if "`exact'" == "" local exact 0
    mata: _td_pos(st_local("path"), st_local("needle"), `exact')
    return scalar first = `_first'
    return scalar last = `_last'
end

* Whether the pdftotext output (whitespace collapsed) contains needle, r(found).
capture program drop _td_txthas
program define _td_txthas, rclass
    version 17.0
    args txt needle
    mata: st_local("_td_f", strofreal(strpos(stritrim(invtokens(cat(st_local("txt"))')), stritrim(st_local("needle"))) > 0))
    return scalar found = `_td_f'
end

* pdflatex on a hand-written file in dir (no harness): PDF made, no "!" error
* line in the log; pdftotext output in dir/stem.txt.
capture program drop _td_pdf
program define _td_pdf
    version 17.0
    args dir stem
    foreach e in pdf log txt aux {
        capture erase "`dir'/`stem'.`e'"
    }
    shell cd "`dir'" && pdflatex -interaction=nonstopmode -halt-on-error "`stem'.tex" > /dev/null 2>&1
    confirm file "`dir'/`stem'.pdf"
    confirm file "`dir'/`stem'.log"
    mata: st_local("_td_bad", strofreal(sum(substr(cat(st_local("dir") + "/" + st_local("stem") + ".log"), 1, 2) :== "! ")))
    mata: st_local("_td_out", strofreal(sum(strpos(cat(st_local("dir") + "/" + st_local("stem") + ".log"), "Output written on") :> 0)))
    assert `_td_bad' == 0 & `_td_out' == 1
    shell pdftotext "`dir'/`stem'.pdf" "`dir'/`stem'.txt"
    confirm file "`dir'/`stem'.txt"
end

mata:
mata set matastrict off

void _td_info(string scalar path)
{
    string colvector L, T
    real scalar n, i, lastnb, dbl

    L = cat(path)
    n = rows(L)
    T = strtrim(L)
    lastnb = 0
    for (i = 1; i <= n; i++) {
        if (T[i] != "") lastnb = i
    }
    dbl = 0
    if (n >= 2) dbl = sum((T[|1 \ n - 1|] :== "") :& (T[|2 \ n|] :== ""))
    st_local("_n", strofreal(n))
    st_local("_ncls", strofreal(sum(strpos(T, "\documentclass") :== 1)))
    st_local("_nend", strofreal(sum(T :== "\end{document}")))
    st_local("_nbeg", strofreal(sum(T :== "\begin{document}")))
    st_local("_dbl", strofreal(dbl))
    st_local("_lastnb", strofreal(lastnb))
    st_local("_l1", n >= 1 ? L[1] : "")
    st_local("_l2", n >= 2 ? L[2] : "")
    st_local("_l3", n >= 3 ? L[3] : "")
    st_local("_l4", n >= 4 ? L[4] : "")
    st_local("_l5", n >= 5 ? L[5] : "")
    st_local("_lm1", n >= 2 ? L[n - 1] : "")
    st_local("_ln", n >= 1 ? L[n] : "")
    st_local("_lnb", lastnb >= 1 ? L[lastnb] : "")
}

void _td_pos(string scalar path, string scalar needle, real scalar exact)
{
    string colvector L
    real scalar i, first, last, hit

    L = cat(path)
    first = 0
    last = 0
    for (i = 1; i <= rows(L); i++) {
        hit = exact ? (strtrim(L[i]) == needle) : (strpos(L[i], needle) > 0)
        if (hit) {
            if (first == 0) first = i
            last = i
        }
    }
    st_local("_first", strofreal(first))
    st_local("_last", strofreal(last))
}
end

**# Fixtures
capture program drop _td_comp_frames
program define _td_comp_frames
    version 17.0
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight foreign
    quietly regtab, frame(_lcf1, replace) noint models("Base \ Adjusted")
end

capture program drop _td_rate_frames
program define _td_rate_frames
    version 17.0
    args out
    sysuse cancer, clear
    generate byte early = died & studytime < 15
    quietly stset studytime, failure(died)
    quietly strate drug, output("`out'/td_r1", replace)
    collect clear
    quietly collect: stcox i.drug, nolog
    quietly collect: stcox i.drug age, nolog
    quietly regtab, models("Unadjusted \ Adjusted") frame(_lchr1, replace) noint
    collect clear
    quietly collect: stcox i.drug, nolog
    quietly stset studytime, failure(early)
    quietly strate drug, output("`out'/td_r2", replace)
    quietly collect: stcox i.drug, nolog
    quietly regtab, models("Death \ Early death") frame(_lchr2, replace) noint
    quietly stratetab, using("`out'/td_r1") outcomes(1) outlabels("Death") ///
        explabels("Drug") frame(_lcrt1, replace)
    quietly stratetab, using("`out'/td_r1" "`out'/td_r2") outcomes(2) ///
        outlabels("Death \ Early death") explabels("Drug") frame(_lcrt2, replace)
end

* Source workbook and two frames for stacktab blocks() and frames().
capture program drop _td_stack_src
program define _td_stack_src
    version 17.0
    capture erase "$TD_WB"
    clear
    quietly set obs 4
    quietly gen str20 label = word("Category BinaryHRT Active Recent", _n)
    quietly replace label = "Binary HRT" in 2
    quietly gen str10 est = word("HR 1.23 1.45 0.98", _n)
    quietly gen str16 ci = "95% CI" in 1
    quietly replace ci = "(1.05, 1.44)" in 2
    quietly replace ci = "(1.20, 1.75)" in 3
    quietly replace ci = "(0.82, 1.17)" in 4
    quietly export excel "$TD_WB", sheet("SrcA") sheetreplace
    capture frame drop _td_fa
    capture frame drop _td_fb
    frame create _td_fa
    frame _td_fa {
        quietly set obs 3
        quietly gen str12 lab = word("Mean Median Range", _n)
        quietly gen str8 v1 = word("1.5 2.0 1-3", _n)
        quietly gen str8 v2 = word("2.5 3.0 2-4", _n)
        label variable lab "Statistic"
        label variable v1 "Group 1"
        label variable v2 "Group 2"
    }
    frame create _td_fb
    frame _td_fb {
        quietly set obs 2
        quietly gen str12 lab = word("Mean Median", _n)
        quietly gen str8 v1 = word("7.5 8.0", _n)
        quietly gen str8 v2 = word("8.5 9.0", _n)
        label variable lab "Statistic"
        label variable v1 "Group 1"
        label variable v2 "Group 2"
    }
end

* Data and frames the command `id' needs.
capture program drop _td_prep
program define _td_prep
    version 17.0
    args id
    local out "$TD_OUT"
    if "`id'" == "regtab" {
        sysuse auto, clear
        collect clear
        quietly collect: regress price mpg weight
    }
    else if "`id'" == "effecttab" {
        sysuse auto, clear
        quietly regress price mpg i.foreign
        collect clear
        quietly collect: margins foreign
    }
    else if "`id'" == "comptab_f" {
        _td_comp_frames
    }
    else if inlist("`id'", "comptab_r", "hrcomptab", "stratetab") {
        _td_rate_frames "`out'"
    }
    else if "`id'" == "ratetab" {
        sysuse cancer, clear
        generate byte early = died & studytime < 15
        generate double pt = studytime
        generate double pt2 = studytime
    }
    else if inlist("`id'", "desctab", "table1_tc") {
        sysuse auto, clear
        label define td_fl 0 "Domestic" 1 "Foreign", replace
        label values foreign td_fl
    }
    else if "`id'" == "crosstab" {
        sysuse auto, clear
        generate byte hi = mpg > 20
        label define td_fl 0 "Domestic" 1 "Foreign", replace
        label values foreign td_fl
    }
    else if "`id'" == "survtab" {
        sysuse cancer, clear
        generate byte arm = drug > 1
        label define td_arm 0 "Placebo" 1 "Active", replace
        label values arm td_arm
        quietly stset studytime, failure(died)
    }
    else if "`id'" == "puttab" {
        sysuse auto, clear
    }
    else if "`id'" == "outtab" {
        clear
        set seed 20261031
        set obs 3000
        gen long id = ceil(_n / 2)
        gen byte narc = runiform() < 0.1
        label define _tdn 1 "Narcolepsy" 0 "Comparator", replace
        label values narc _tdn
        gen double age = rnormal(30, 5)
        gen byte cs = runiform() < invlogit(-1.5 + 0.5 * narc + 0.03 * (age - 30))
        gen byte ptb = runiform() < 0.05 + 0.02 * narc
        label variable cs "Caesarean section"
        label variable ptb "Preterm birth"
    }
    else if inlist("`id'", "stacktab_b", "stacktab_f") {
        _td_stack_src
    }
    else {
        display as error "_td_prep: unknown command id `id'"
        exit 198
    }
end

* The command `id' with the option text that follows (latex(), texdocument...).
capture program drop _td_cmd
program define _td_cmd
    version 17.0
    gettoken id 0 : 0
    local out "$TD_OUT"
    if "$TD_NOTITLE" == "1" local ttl ""
    else local ttl `"title("Cmd `id'")"'
    if "`id'" == "regtab" {
        regtab, noint `ttl' `0'
    }
    else if "`id'" == "effecttab" {
        effecttab, type(margins) `ttl' `0'
    }
    else if "`id'" == "comptab_f" {
        comptab _lcf1, rows(1 2) `ttl' `0'
    }
    else if "`id'" == "comptab_r" {
        comptab _lchr1, rateframe(_lcrt1) rows(3/4) allmodels `ttl' `0'
    }
    else if "`id'" == "hrcomptab" {
        hrcomptab _lcrt2, modelframes(_lchr2) rows(3/4) effect("HR") ///
            outcomemap(Death \ Early death) `ttl' `0'
    }
    else if "`id'" == "stratetab" {
        stratetab, using("`out'/td_r1" "`out'/td_r2") outcomes(2) ///
            outlabels("Death \ Early death") explabels("Drug") `ttl' `0'
    }
    else if "`id'" == "ratetab" {
        ratetab drug, events(died early) exposure(pt pt2) ///
            outlabels("Death \ Early death") `ttl' `0'
    }
    else if "`id'" == "desctab" {
        desctab price mpg, by(foreign) `ttl' `0'
    }
    else if "`id'" == "table1_tc" {
        table1_tc price mpg, vars(price contn \ mpg contn) `ttl' `0'
    }
    else if "`id'" == "crosstab" {
        crosstab foreign hi, `ttl' `0'
    }
    else if "`id'" == "survtab" {
        survtab, times(10 20) by(arm) `ttl' `0'
    }
    else if "`id'" == "puttab" {
        puttab make price mpg in 1/4, varlabels `ttl' `0'
    }
    else if "`id'" == "outtab" {
        outtab cs ptb, exposure(narc) `ttl' `0'
    }
    else if "`id'" == "stacktab_b" {
        stacktab using "$TD_WB", blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
            sheet("TDB") sheetreplace `ttl' `0'
    }
    else if "`id'" == "stacktab_f" {
        stacktab using "$TD_WB", frames(_td_fa "All cars" \ _td_fb "Expensive cars") ///
            sheet("TDF") `ttl' `0'
    }
    else {
        display as error "_td_cmd: unknown command id `id'"
        exit 198
    }
end

* One command: texdocument gives a compiled complete document, the fragment
* default stays a fragment, r() is the same, texdocument alone is r(198).
capture program drop _td_percmd
program define _td_percmd
    version 17.0
    args id
    local f1 "$TD_OUT/pc_`id'_doc.tex"
    local f2 "$TD_OUT/pc_`id'_frag.tex"
    capture erase "`f1'"
    capture erase "`f2'"
    quietly tabtools set clear
    _td_prep `id'
    _td_cmd `id' latex("`f2'")
    * outtab forwards the table to puttab and posts no latex returns
    if "`id'" != "outtab" assert `"`r(latex)'"' == "`f2'"
    local r2 = r(latex_rows)
    local c2 = r(latex_cols)
    local n2 = r(N_rows)
    * outtab posts no latex_rows/latex_cols; every other command does
    if "`id'" != "outtab" assert !missing(`r2') & !missing(`c2')
    _td_prep `id'
    _td_cmd `id' latex("`f1'") texdocument
    if "`id'" != "outtab" assert `"`r(latex)'"' == "`f1'"
    assert r(latex_rows) == `r2' & r(latex_cols) == `c2' & r(N_rows) == `n2'
    _td_check "`f1'" --document yes --compile --tables 1
    _td_check "`f2'" --document no --compile --tables 1
    _td_info "`f1'"
    assert `"`r(l1)'"' == "\documentclass{article}"
    assert `"`r(ln)'"' == "\end{document}" & r(ncls) == 1 & r(nend) == 1
    _td_info "`f2'"
    assert r(ncls) == 0 & r(nend) == 0 & r(nbeg) == 0
    * texdocument without latex() and without a session file
    _td_prep `id'
    global TD_NOTITLE "1"
    _td_console _td_cmd `id' texdocument
    global TD_NOTITLE ""
    local crc = r(rc)
    local txt `"`r(text)'"'
    display as text "  `id': texdocument without latex() rc=`crc'"
    assert `crc' == 198
    local hit = strpos(`"`macval(txt)'"', "texdocument requires latex()") > 0
    if !`hit' display as error "  message lacks: texdocument requires latex()"
    assert `hit'
end

**# T1. the default is a table fragment
capture noisily {
    local f "$TD_OUT/t1.tex"
    capture erase "`f'"
    _td_prep regtab
    regtab, noint title("Frag one") latex("`f'")
    assert r(latex_rows) == 2
    _td_check "`f'" --document no --compile --tables 1
    _td_info "`f'"
    assert `"`r(l1)'"' == "% tabtools LaTeX table; requires \usepackage{booktabs}"
    assert r(ncls) == 0 & r(nbeg) == 0 & r(nend) == 0
    * a plain texappend onto a fragment stays a fragment
    regtab, noint title("Frag two") latex("`f'") texappend
    _td_check "`f'" --document no --compile --tables 2
    _td_info "`f'"
    assert `"`r(l1)'"' == "% tabtools LaTeX table; requires \usepackage{booktabs}"
    assert r(ncls) == 0 & r(nend) == 0 & r(dbl) == 0
    _td_count "`f'" "% tabtools LaTeX table"
    assert r(n) == 2
}
local trc = _rc
if `trc' == 0 {
    display as result "  PASS: T1 default and texappend without texdocument stay fragments"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 fragment default (rc=`trc')"
    local ++fail_count
}

**# T2. new document: the exact frame, compiled as it is
capture noisily {
    local f "$TD_OUT/t2.tex"
    capture erase "`f'"
    _td_prep regtab
    regtab, noint title("Doc one") latex("`f'") texdocument
    assert r(latex_rows) == 2 & r(latex_cols) == 4
    _td_info "`f'"
    assert `"`r(l1)'"' == "\documentclass{article}"
    assert `"`r(l2)'"' == "\usepackage{booktabs}"
    assert `"`r(l3)'"' == "\begin{document}"
    assert trim(`"`r(l4)'"') == ""
    assert strpos(`"`r(l5)'"', "% tabtools LaTeX table") == 1
    assert trim(`"`r(lm1)'"') == ""
    assert `"`r(ln)'"' == "\end{document}"
    assert `"`r(lnb)'"' == "\end{document}"
    assert r(ncls) == 1 & r(nbeg) == 1 & r(nend) == 1 & r(dbl) == 0
    _td_nd pdftext Doc one
    _td_check "`f'" --document yes --compile --tables 1 --cols 4 --header-rows 2 --body-rows 2
}
local trc = _rc
if `trc' == 0 {
    display as result "  PASS: T2 texdocument writes the exact document frame; compiles as is"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 document frame (rc=`trc')"
    local ++fail_count
}

**# T3. three-table report
capture noisily {
    local f "$TD_OUT/td_t3.tex"
    capture erase "`f'"
    _td_prep regtab
    regtab, noint title("Alpha tbl") latex("`f'") texdocument
    sysuse auto, clear
    puttab make price in 1/3, latex("`f'") texappend title("Beta tbl")
    assert r(latex_rows) == 3
    puttab make mpg in 1/3, latex("`f'") texappend texdocument title("Gamma tbl")
    assert r(latex_rows) == 3
    _td_nd pdftext Alpha tbl
    _td_nd pdftext Beta tbl
    _td_nd pdftext Gamma tbl
    _td_nd contains \label{tab:td_t3}
    _td_nd contains \label{tab:td_t3-2}
    _td_nd contains \label{tab:td_t3-3}
    _td_check "`f'" --document yes --compile --tables 3
    _td_info "`f'"
    assert r(ncls) == 1 & r(nend) == 1 & r(nbeg) == 1
    assert `"`r(lnb)'"' == "\end{document}" & `"`r(ln)'"' == "\end{document}"
    assert r(dbl) == 0
    assert trim(`"`r(lm1)'"') == ""
    _td_count "`f'" "\begin{table}"
    assert r(n) == 3
    _td_count "`f'" "% tabtools LaTeX table"
    assert r(n) == 3
    * the tables are in append order, all before \end{document}
    _td_pos "`f'" "\caption{Alpha tbl}"
    local pa = r(first)
    _td_pos "`f'" "\caption{Beta tbl}"
    local pb = r(first)
    _td_pos "`f'" "\caption{Gamma tbl}"
    local pg = r(first)
    _td_pos "`f'" "\end{document}" 1
    local pe = r(first)
    assert `pa' > 0 & `pa' < `pb' & `pb' < `pg' & `pg' < `pe'
}
local trc = _rc
if `trc' == 0 {
    display as result "  PASS: T3 three-table report: one frame, labels -2/-3, compiles, no double blank line"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 three-table report (rc=`trc')"
    local ++fail_count
}

**# T4. refusal: texappend texdocument onto a fragment
capture noisily {
    local f "$TD_OUT/t4.tex"
    capture erase "`f'"
    _td_prep regtab
    regtab, noint title("Frag") latex("`f'")
    _td_sum "`f'"
    local before "`r(sum)'"
    assert "`before'" != "absent"
    _td_info "`f'"
    local nbefore = r(n)
    _td_console regtab, noint title("Refused") latex("`f'") texappend texdocument
    local crc = r(rc)
    local txt `"`r(text)'"'
    _td_sum "`f'"
    local after "`r(sum)'"
    display as text "  refused rc=`crc'; checksum before `before', after `after'"
    assert `crc' == 198
    local hit = strpos(`"`macval(txt)'"', "texdocument: the existing LaTeX file has no \end{document} line") > 0
    if !`hit' display as error "  message lacks the \end{document} text"
    assert `hit'
    assert "`after'" == "`before'"
    _td_info "`f'"
    assert r(n) == `nbefore'
    * a seeded text file with no \end{document} is refused the same way
    local g "$TD_OUT/t4_text.tex"
    _td_seed_text "`g'"
    _td_sum "`g'"
    local before "`r(sum)'"
    _td_console regtab, noint latex("`g'") texappend texdocument
    local crc = r(rc)
    local txt `"`r(text)'"'
    _td_sum "`g'"
    local after "`r(sum)'"
    assert `crc' == 198 & "`after'" == "`before'"
    assert strpos(`"`macval(txt)'"', "no \end{document} line") > 0
    * the refusal is specific to texdocument: plain texappend still appends
    regtab, noint title("Plain") latex("`f'") texappend
    _td_check "`f'" --document no --compile --tables 2
}
local trc = _rc
if `trc' == 0 {
    display as result "  PASS: T4 texappend texdocument onto a fragment: rc 198, message, file byte-identical"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 refusal (rc=`trc')"
    local ++fail_count
}

**# T5. texappend texdocument into a missing file creates a document
capture noisily {
    local f "$TD_OUT/t5.tex"
    capture erase "`f'"
    capture confirm file "`f'"
    assert _rc != 0
    _td_prep regtab
    regtab, noint title("Born doc") latex("`f'") texappend texdocument
    assert r(latex_rows) == 2
    _td_check "`f'" --document yes --compile --tables 1
    _td_info "`f'"
    assert `"`r(l1)'"' == "\documentclass{article}" & `"`r(ln)'"' == "\end{document}"
    assert r(ncls) == 1 & r(nend) == 1
    * a second texappend texdocument now succeeds: the file has \end{document}
    regtab, noint title("Second") latex("`f'") texappend texdocument
    _td_check "`f'" --document yes --compile --tables 2
}
local trc = _rc
if `trc' == 0 {
    display as result "  PASS: T5 texappend texdocument into a missing file creates a document"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 missing file (rc=`trc')"
    local ++fail_count
}

**# T6. hand-made user paper: texappend inserts before \end{document}
capture noisily {
    local d "$TD_OUT/t6"
    capture mkdir "`d'"
    foreach spaced in 0 1 {
        local f "`d'/paper`spaced'.tex"
        _td_paper "`f'" `spaced'
        sysuse auto, clear
        puttab make price in 1/3, latex("`f'") texappend title("In paper")
        assert r(latex_rows) == 3
        _td_info "`f'"
        assert r(nend) == 1 & r(ncls) == 1 & r(dbl) == 0
        assert `"`r(lnb)'"' == "% trailing comment"
        _td_pos "`f'" "Hello user prose line."
        local pp = r(first)
        _td_pos "`f'" "\begin{table}"
        local pt = r(first)
        _td_pos "`f'" "\end{document}" 1
        local pe = r(first)
        _td_pos "`f'" "% trailing comment"
        local pc = r(first)
        display as text "  spaced=`spaced': prose `pp', table `pt', end `pe', trailing `pc'"
        assert `pp' == 4
        assert `pp' < `pt' & `pt' < `pe' & `pe' < `pc'
        * a second table with texdocument goes before the same line
        puttab make mpg in 1/2, latex("`f'") texappend texdocument title("In paper 2")
        _td_info "`f'"
        assert r(nend) == 1 & r(ncls) == 1 & r(dbl) == 0
        assert `"`r(lnb)'"' == "% trailing comment"
        _td_count "`f'" "\begin{table}"
        assert r(n) == 2
        _td_pos "`f'" "\caption{In paper 2}"
        local p2 = r(first)
        _td_pos "`f'" "\end{document}" 1
        local pe2 = r(first)
        assert `pt' > 0 & `p2' > `pt' & `pe2' > `p2'
        _td_pdf "`d'" "paper`spaced'"
        _td_txthas "`d'/paper`spaced'.txt" "Hello user prose line."
        assert r(found) == 1
        _td_txthas "`d'/paper`spaced'.txt" "AMC Concord"
        assert r(found) == 1
        _td_txthas "`d'/paper`spaced'.txt" "In paper 2"
        assert r(found) == 1
    }
}
local trc = _rc
if `trc' == 0 {
    display as result "  PASS: T6 user paper (plain and space-padded \end{document}): tables inserted before it, prose and trailing comment kept, compiles"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 user paper (rc=`trc')"
    local ++fail_count
}

**# T7. replace semantics
capture noisily {
    local f "$TD_OUT/t7.tex"
    capture erase "`f'"
    _td_prep regtab
    regtab, noint title("Frag") latex("`f'")
    _td_check "`f'" --document no --tables 1
    regtab, noint title("Doc") latex("`f'") texdocument
    _td_check "`f'" --document yes --compile --tables 1 --contains "\caption{Doc}" --absent "\caption{Frag}"
    regtab, noint title("Again frag") latex("`f'")
    _td_check "`f'" --document no --compile --tables 1 --contains "\caption{Again frag}" --absent "\caption{Doc}"
    _td_info "`f'"
    assert r(ncls) == 0 & r(nend) == 0 & r(nbeg) == 0
    assert `"`r(l1)'"' == "% tabtools LaTeX table; requires \usepackage{booktabs}"
    * and a document replaced by a document is one document, not two
    regtab, noint title("Doc A") latex("`f'") texdocument
    regtab, noint title("Doc B") latex("`f'") texdocument
    _td_check "`f'" --document yes --compile --tables 1 --contains "\caption{Doc B}" --absent "\caption{Doc A}"
}
local trc = _rc
if `trc' == 0 {
    display as result "  PASS: T7 texdocument replaces a fragment; plain latex() replaces the document with a fragment"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 replace semantics (rc=`trc')"
    local ++fail_count
}

**# T8. every command and form
local ids "regtab effecttab comptab_f comptab_r hrcomptab stratetab ratetab desctab table1_tc crosstab survtab puttab outtab stacktab_b stacktab_f"
foreach id of local ids {
    capture noisily _td_percmd `id'
    local trc = _rc
    quietly tabtools set clear
    if `trc' == 0 {
        display as result "  PASS: T8 `id': texdocument compiles as a document, r() unchanged, bare texdocument is r(198)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T8 `id' (rc=`trc')"
        local ++fail_count
    }
}

**# T9. session file
capture noisily {
    local sess "$TD_OUT/td_t9.tex"
    _td_seed_text "`sess'"
    sysuse auto, clear
    quietly tabtools set latex "`sess'"
    * texdocument alone: the session file satisfies it, first write replaces
    capture noisily puttab make price in 1/3, texdocument title("S one")
    local rc1 = _rc
    assert `rc1' == 0
    assert `"`r(latex)'"' == "`sess'" & r(latex_rows) == 3
    _td_check "`sess'" --document yes --compile --tables 1 --absent "KEEP THIS TEXT"
    * a later plain session write is inserted before \end{document}
    puttab make mpg in 1/4, title("S two")
    assert `"`r(latex)'"' == "`sess'" & r(latex_rows) == 4
    _td_nd contains \label{tab:td_t9}
    _td_nd contains \label{tab:td_t9-2}
    _td_nd pdftext S one
    _td_nd pdftext S two
    _td_check "`sess'" --document yes --compile --tables 2
    _td_info "`sess'"
    assert r(ncls) == 1 & r(nend) == 1 & r(dbl) == 0
    assert `"`r(l1)'"' == "\documentclass{article}" & `"`r(lnb)'"' == "\end{document}"
    quietly tabtools set latex clear
    tabtools query
    assert `"`r(latex)'"' == ""
    * with the session cleared, texdocument alone is refused again
    _td_console puttab make price in 1/3, texdocument
    local crc = r(rc)
    local txt `"`r(text)'"'
    assert `crc' == 198
    assert strpos(`"`macval(txt)'"', "texdocument requires latex()") > 0
}
local trc = _rc
quietly tabtools set clear
if `trc' == 0 {
    display as result "  PASS: T9 session file: texdocument creates the document, later session writes insert before \end{document}"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 session file (rc=`trc')"
    local ++fail_count
}

**# T10. stacktab refusal path
capture noisily {
    local f "$TD_OUT/t10.tex"
    capture erase "`f'"
    _td_prep stacktab_b
    stacktab using "$TD_WB", blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("T10a") sheetreplace title("Frag") latex("`f'")
    _td_check "`f'" --document no --compile --tables 1
    _td_sum "`f'"
    local tsum "`r(sum)'"
    _td_sum "$TD_WB"
    local wsum "`r(sum)'"
    assert "`tsum'" != "absent" & "`wsum'" != "absent"
    _td_console stacktab using "$TD_WB", blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("T10b") sheetreplace title("Refused") latex("`f'") texappend texdocument
    local crc = r(rc)
    local txt `"`r(text)'"'
    _td_sum "`f'"
    local tafter "`r(sum)'"
    _td_sum "$TD_WB"
    local wafter "`r(sum)'"
    display as text "  stacktab refused rc=`crc'; tex `tsum' -> `tafter'; xlsx `wsum' -> `wafter'"
    assert `crc' != 0
    assert "`tafter'" == "`tsum'"
    assert strpos(`"`macval(txt)'"', "no \end{document} line") > 0
    assert "`wafter'" == "`wsum'"
    * frames() form: the same refusal
    _td_prep stacktab_f
    stacktab using "$TD_WB", frames(_td_fa "A") sheet("T10c") latex("`f'")
    _td_sum "`f'"
    local tsum "`r(sum)'"
    _td_console stacktab using "$TD_WB", frames(_td_fb "B") sheet("T10d") ///
        latex("`f'") texappend texdocument
    local crc = r(rc)
    _td_sum "`f'"
    local tafter "`r(sum)'"
    assert `crc' != 0 & "`tafter'" == "`tsum'"
}
local trc = _rc
quietly tabtools set clear
if `trc' == 0 {
    display as result "  PASS: T10 stacktab texappend texdocument onto a fragment: refused, tex and workbook untouched"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 stacktab refusal (rc=`trc')"
    local ++fail_count
}

**# T11. the refusal comes before any other output is written
* Review 2026-10-31: the refusal used to fire inside the LaTeX writer, after
* the workbook, CSV and Markdown had been written.
capture noisily {
    local f "$TD_OUT/t11.tex"
    local x "$TD_OUT/t11.xlsx"
    local c "$TD_OUT/t11.csv"
    local m "$TD_OUT/t11.md"
    foreach g in f x c m {
        capture erase "``g''"
    }
    _td_prep regtab
    regtab, noint title("Frag") latex("`f'")
    _td_sum "`f'"
    local before "`r(sum)'"
    _td_console regtab, noint xlsx("`x'") sheet("T11") csv("`c'") ///
        markdown("`m'") latex("`f'") texappend texdocument
    local crc = r(rc)
    local txt `"`r(text)'"'
    assert `crc' == 198
    assert strpos(`"`macval(txt)'"', "no \end{document} line") > 0
    _td_sum "`f'"
    assert "`r(sum)'" == "`before'"
    foreach g in x c m {
        capture confirm file "``g''"
        local frc = _rc
        if !`frc' display as error "  ``g'' was written before the refusal"
        assert `frc' == 601
    }
    * desctab names its workbook excel(); same refusal, same order
    sysuse auto, clear
    _td_console desctab price mpg, excel("`x'") sheet("T11d") ///
        latex("`f'") texappend texdocument
    local crc = r(rc)
    assert `crc' == 198
    capture confirm file "`x'"
    local frc = _rc
    assert `frc' == 601
}
local trc = _rc
if `trc' == 0 {
    display as result "  PASS: T11 texappend texdocument refusal precedes the workbook, CSV and Markdown writes"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 refusal before other sinks (rc=`trc')"
    local ++fail_count
}

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_latex_document tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _td
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_latex_document tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _td
