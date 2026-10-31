* test_latex_texopts.do - tabtools: texopts(), the LaTeX layout sub-options
*   T1  each sub-option alone (captionleft captionbelow nocentering placement
*       size fit landscape label, preamble/docclass ignored without texdocument):
*       exact lines, check_latex.py --layout, compiled
*   T2  combined layout in a created document: exact preamble, compiled
*   T3  landscape + captionbelow + nocentering + placement(H) appended into it:
*       float and pdflscape added once each, compiled
*   T4  user paper: texappend adds only the missing packages, compiled directly
*   T5  fragment note names the packages; none when nothing is needed
*   T6  every invalid input is r(198) with its message and writes no file
*   T7  every command and form: texopts(captionleft fit) compiles, r() unchanged,
*       texopts() without latex() is r(198)
*   T8  session default: set, query, replace-not-merge, refusals, clear
*   T9  fit never enlarges a narrow table and shrinks a wide one
* Expected lines are hand-built strings; check_latex.py compiles every file with
* pdflatex and verifies the layout; pdftotext/pdflatex logs decide T9.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _tx
log using "test_latex_texopts.log", replace text name(_tx)

global TX_PASS = 0
global TX_FAIL = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global TX_OUT "`output_dir'/tx"
capture mkdir "$TX_OUT"
global TX_CHECKER "`qa_dir'/tools/check_latex.py"
global TX_ND "$TX_OUT/tx_needles.txt"
global TX_WB "$TX_OUT/tx_stack_src.xlsx"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

**# Helpers
* CRC and length of a file, as one string ("absent" when there is none).
capture program drop _tx_sum
program define _tx_sum, rclass
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
capture program drop _tx_seed_text
program define _tx_seed_text
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
capture program drop _tx_paper
program define _tx_paper
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

* Needle file for check_latex.py: _tx_nd reset | _tx_nd kind text.
capture program drop _tx_nd
program define _tx_nd
    version 17.0
    gettoken kind 0 : 0
    if "`kind'" == "reset" {
        capture erase "$TX_ND"
        exit
    }
    local text `0'
    mata: _tx_fh = fopen(st_global("TX_ND"), "a"); ///
        fput(_tx_fh, st_local("kind") + char(9) + st_local("text")); ///
        fclose(_tx_fh)
end

* check_latex.py on a .tex file with the options that follow it; queued
* needles are passed and cleared. The verdict must start with PASS.
capture program drop _tx_check
program define _tx_check
    version 17.0
    gettoken tex 0 : 0
    tempfile res
    capture erase "`res'"
    local nd ""
    capture confirm file "$TX_ND"
    if !_rc local nd `"--needles "$TX_ND""'
    shell python3 "$TX_CHECKER" "`tex'" `0' `nd' --result "`res'"
    capture erase "$TX_ND"
    confirm file "`res'"
    mata: printf("{txt}  check_latex: %s\n", cat(st_local("res"))[1])
    mata: st_local("_tx_ok", strofreal(substr(cat(st_local("res"))[1], 1, 4) == "PASS"))
    assert `_tx_ok' == 1
end

* Lines of a text file containing a literal substring, in r(n).
capture program drop _tx_count
program define _tx_count, rclass
    version 17.0
    args file needle
    mata: st_local("_tx_n", strofreal(sum(strpos(cat(st_local("file")), st_local("needle")) :> 0)))
    return scalar n = `_tx_n'
end

* Console text of a command (nested log) in r(text), its rc in r(rc). The rc
* is hoisted right after the capture.
capture program drop _tx_console
program define _tx_console, rclass
    version 17.0
    tempfile lg
    quietly log using "`lg'", text replace name(_tx_capture)
    capture noisily `0'
    local crc = _rc
    quietly log close _tx_capture
    mata: st_local("_tx_txt", invtokens(cat(st_local("lg"))', " "))
    return local text `"`macval(_tx_txt)'"'
    return scalar rc = `crc'
end

* Structure of a text file: line count, first lines, last lines, counts.
capture program drop _tx_info
program define _tx_info, rclass
    version 17.0
    args path
    confirm file "`path'"
    mata: _tx_info(st_local("path"))
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
capture program drop _tx_pos
program define _tx_pos, rclass
    version 17.0
    args path needle exact
    if "`exact'" == "" local exact 0
    mata: _tx_pos(st_local("path"), st_local("needle"), `exact')
    return scalar first = `_first'
    return scalar last = `_last'
end

* Whether the pdftotext output (whitespace collapsed) contains needle, r(found).
capture program drop _tx_txthas
program define _tx_txthas, rclass
    version 17.0
    args txt needle
    mata: st_local("_tx_f", strofreal(strpos(stritrim(invtokens(cat(st_local("txt"))')), stritrim(st_local("needle"))) > 0))
    return scalar found = `_tx_f'
end

* pdflatex on a hand-written file in dir (no harness): PDF made, no "!" error
* line in the log; pdftotext output in dir/stem.txt.
capture program drop _tx_pdf
program define _tx_pdf
    version 17.0
    args dir stem
    foreach e in pdf log txt aux {
        capture erase "`dir'/`stem'.`e'"
    }
    shell cd "`dir'" && pdflatex -interaction=nonstopmode -halt-on-error "`stem'.tex" > /dev/null 2>&1
    confirm file "`dir'/`stem'.pdf"
    confirm file "`dir'/`stem'.log"
    mata: st_local("_tx_bad", strofreal(sum(substr(cat(st_local("dir") + "/" + st_local("stem") + ".log"), 1, 2) :== "! ")))
    mata: st_local("_tx_out", strofreal(sum(strpos(cat(st_local("dir") + "/" + st_local("stem") + ".log"), "Output written on") :> 0)))
    assert `_tx_bad' == 0 & `_tx_out' == 1
    shell pdftotext "`dir'/`stem'.pdf" "`dir'/`stem'.txt"
    confirm file "`dir'/`stem'.txt"
end

mata:
mata set matastrict off

void _tx_info(string scalar path)
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

void _tx_pos(string scalar path, string scalar needle, real scalar exact)
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
capture program drop _tx_comp_frames
program define _tx_comp_frames
    version 17.0
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight foreign
    quietly regtab, frame(_lcf1, replace) noint models("Base \ Adjusted")
end

capture program drop _tx_rate_frames
program define _tx_rate_frames
    version 17.0
    args out
    sysuse cancer, clear
    generate byte early = died & studytime < 15
    quietly stset studytime, failure(died)
    quietly strate drug, output("`out'/tx_r1", replace)
    collect clear
    quietly collect: stcox i.drug, nolog
    quietly collect: stcox i.drug age, nolog
    quietly regtab, models("Unadjusted \ Adjusted") frame(_lchr1, replace) noint
    collect clear
    quietly collect: stcox i.drug, nolog
    quietly stset studytime, failure(early)
    quietly strate drug, output("`out'/tx_r2", replace)
    quietly collect: stcox i.drug, nolog
    quietly regtab, models("Death \ Early death") frame(_lchr2, replace) noint
    quietly stratetab, using("`out'/tx_r1") outcomes(1) outlabels("Death") ///
        explabels("Drug") frame(_lcrt1, replace)
    quietly stratetab, using("`out'/tx_r1" "`out'/tx_r2") outcomes(2) ///
        outlabels("Death \ Early death") explabels("Drug") frame(_lcrt2, replace)
end

* Source workbook and two frames for stacktab blocks() and frames().
capture program drop _tx_stack_src
program define _tx_stack_src
    version 17.0
    capture erase "$TX_WB"
    clear
    quietly set obs 4
    quietly gen str20 label = word("Category BinaryHRT Active Recent", _n)
    quietly replace label = "Binary HRT" in 2
    quietly gen str10 est = word("HR 1.23 1.45 0.98", _n)
    quietly gen str16 ci = "95% CI" in 1
    quietly replace ci = "(1.05, 1.44)" in 2
    quietly replace ci = "(1.20, 1.75)" in 3
    quietly replace ci = "(0.82, 1.17)" in 4
    quietly export excel "$TX_WB", sheet("SrcA") sheetreplace
    capture frame drop _tx_fa
    capture frame drop _tx_fb
    frame create _tx_fa
    frame _tx_fa {
        quietly set obs 3
        quietly gen str12 lab = word("Mean Median Range", _n)
        quietly gen str8 v1 = word("1.5 2.0 1-3", _n)
        quietly gen str8 v2 = word("2.5 3.0 2-4", _n)
        label variable lab "Statistic"
        label variable v1 "Group 1"
        label variable v2 "Group 2"
    }
    frame create _tx_fb
    frame _tx_fb {
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
capture program drop _tx_prep
program define _tx_prep
    version 17.0
    args id
    local out "$TX_OUT"
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
        _tx_comp_frames
    }
    else if inlist("`id'", "comptab_r", "hrcomptab", "stratetab") {
        _tx_rate_frames "`out'"
    }
    else if "`id'" == "ratetab" {
        sysuse cancer, clear
        generate byte early = died & studytime < 15
        generate double pt = studytime
        generate double pt2 = studytime
    }
    else if inlist("`id'", "desctab", "table1_tc") {
        sysuse auto, clear
        label define tx_fl 0 "Domestic" 1 "Foreign", replace
        label values foreign tx_fl
    }
    else if "`id'" == "crosstab" {
        sysuse auto, clear
        generate byte hi = mpg > 20
        label define tx_fl 0 "Domestic" 1 "Foreign", replace
        label values foreign tx_fl
    }
    else if "`id'" == "survtab" {
        sysuse cancer, clear
        generate byte arm = drug > 1
        label define tx_arm 0 "Placebo" 1 "Active", replace
        label values arm tx_arm
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
        label define _txn 1 "Narcolepsy" 0 "Comparator", replace
        label values narc _txn
        gen double age = rnormal(30, 5)
        gen byte cs = runiform() < invlogit(-1.5 + 0.5 * narc + 0.03 * (age - 30))
        gen byte ptb = runiform() < 0.05 + 0.02 * narc
        label variable cs "Caesarean section"
        label variable ptb "Preterm birth"
    }
    else if inlist("`id'", "stacktab_b", "stacktab_f") {
        _tx_stack_src
    }
    else {
        display as error "_tx_prep: unknown command id `id'"
        exit 198
    }
end

* The command `id' with the option text that follows (latex(), texdocument...).
capture program drop _tx_cmd
program define _tx_cmd
    version 17.0
    gettoken id 0 : 0
    local out "$TX_OUT"
    if "$TX_NOTITLE" == "1" local ttl ""
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
        stratetab, using("`out'/tx_r1" "`out'/tx_r2") outcomes(2) ///
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
        stacktab using "$TX_WB", blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
            sheet("TDB") sheetreplace `ttl' `0'
    }
    else if "`id'" == "stacktab_f" {
        stacktab using "$TX_WB", frames(_tx_fa "All cars" \ _tx_fb "Expensive cars") ///
            sheet("TDF") `ttl' `0'
    }
    else {
        display as error "_tx_cmd: unknown command id `id'"
        exit 198
    }
end


**# Extra helpers

* Lines of a file equal to \newcommand{\pv}{$p$} (dollar signs built with
* char(36), so no macro layer here can touch them), in r(n).
capture program drop _tx_pvline
program define _tx_pvline, rclass
    version 17.0
    args path
    mata: st_local("_tx_n", strofreal(sum(cat(st_local("path")) :== char(92) + "newcommand{" + char(92) + "pv}{" + char(36) + "p" + char(36) + "}")))
    return scalar n = `_tx_n'
end

* A paper with the given preamble lines (one string each, in order), then
* \begin{document} text \end{document}. args: path, then the body line
* after the preamble, then the lines.
capture program drop _tx_mkpaper
program define _tx_mkpaper
    version 17.0
    gettoken path 0 : 0
    gettoken lastline 0 : 0
    capture erase "`path'"
    tempname fh
    file open `fh' using "`path'", write text
    file write `fh' "\documentclass{article}" _n
    while `"`0'"' != "" {
        gettoken ln 0 : 0
        file write `fh' `"`ln'"' _n
    }
    file write `fh' "\begin{document}" _n
    file write `fh' "Paper prose." _n
    if `"`lastline'"' == "plain" file write `fh' "\end{document}" _n
    else file write `fh' `"`lastline'"' _n
    file close `fh'
end

mata:
mata set matastrict off
void _tx_line(string scalar path, real scalar n)
{
    string colvector L
    L = cat(path)
    st_local("_tx_t", (n >= 1 & n <= rows(L)) ? L[n] : "<<no line>>")
}
end

* The text of line n of a file, in r(t).
capture program drop _tx_line
program define _tx_line, rclass
    version 17.0
    args path n
    mata: _tx_line(st_local("path"), `n')
    return local t `"`macval(_tx_t)'"'
end

* Line n of path equals the text exactly.
capture program drop _tx_expect
program define _tx_expect
    version 17.0
    args path n text
    _tx_line "`path'" `n'
    if `"`r(t)'"' != `"`text'"' {
        display as error `"  line `n': got `"`r(t)'"' expected `"`text'"'"'
        exit 9
    }
end

* A test result: name, rc.
capture program drop _tx_rec
program define _tx_rec
    version 17.0
    args name trc
    if `trc' == 0 {
        display as result "  PASS: `name'"
        global TX_PASS = $TX_PASS + 1
    }
    else {
        display as error "  FAIL: `name' (rc=`trc')"
        global TX_FAIL = $TX_FAIL + 1
    }
end

* Table of the first three cars with title "Alpha" and the options that follow
* path (latex() is added); without a title when TX_NOTITLE is 1.
capture program drop _tx_pt
program define _tx_pt
    version 17.0
    gettoken f 0 : 0
    sysuse auto, clear
    if "$TX_NOTITLE" == "1" puttab make price in 1/3, latex("`f'") `0'
    else puttab make price in 1/3, title("Alpha") latex("`f'") `0'
end

* Number of lines of a file that equal text exactly (trimmed).
capture program drop _tx_exact
program define _tx_exact, rclass
    version 17.0
    args path text
    mata: st_local("_tx_n", strofreal(sum(strtrim(cat(st_local("path"))) :== st_local("text"))))
    return scalar n = `_tx_n'
end

* A refused texopts(): rc 198, the message fragment shown, and none of the four
* sinks written. Arguments: message fragment, then the texopts() contents.
capture program drop _tx_refuse
program define _tx_refuse
    version 17.0
    gettoken msg 0 : 0
    local base "$TX_OUT/refuse"
    foreach e in xlsx csv md tex {
        capture erase "`base'.`e'"
    }
    _tx_prep regtab
    _tx_console regtab, noint title("R") xlsx("`base'.xlsx") sheet("R") ///
        csv("`base'.csv") markdown("`base'.md") latex("`base'.tex") texopts(`0')
    local crc = r(rc)
    local txt `"`r(text)'"'
    local hit = strpos(`"`macval(txt)'"', `"`msg'"') > 0
    display as text `"  texopts(`0') rc=`crc'"'
    if !`hit' display as error `"  message lacks: `msg'"'
    assert `crc' == 198
    assert `hit'
    foreach e in xlsx csv md tex {
        capture confirm file "`base'.`e'"
        local frc = _rc
        if !`frc' display as error "  `base'.`e' was written"
        assert `frc' == 601
    }
end

* Wide table (seven 45-character string columns) with texdocument.
capture program drop _tx_wide
program define _tx_wide
    version 17.0
    gettoken f 0 : 0
    clear
    quietly set obs 3
    forvalues j = 1/7 {
        quietly gen str60 c`j' = "Long column text number `j' xxxxxxxxxxxxxxxxxxxx"
    }
    puttab c1-c7, latex("`f'") texdocument title("Wide") `0'
end

* Number of log lines starting with a prefix.
capture program drop _tx_logn
program define _tx_logn, rclass
    version 17.0
    args path prefix
    mata: st_local("_tx_n", strofreal(sum(substr(cat(st_local("path")), 1, strlen(st_local("prefix"))) :== st_local("prefix"))))
    return scalar n = `_tx_n'
end

* pdflatex on a hand-written file in dir, without the pass/fail asserts of
* _tx_pdf: log and pdf only.
capture program drop _tx_pdf2
program define _tx_pdf2
    version 17.0
    args dir stem
    foreach e in pdf log txt aux bbox {
        capture erase "`dir'/`stem'.`e'"
    }
    shell cd "`dir'" && pdflatex -interaction=nonstopmode -halt-on-error "`stem'.tex" > /dev/null 2>&1
    confirm file "`dir'/`stem'.pdf"
    shell pdftotext -bbox "`dir'/`stem'.pdf" "`dir'/`stem'.bbox"
    confirm file "`dir'/`stem'.bbox"
end


* Lines before \begin{document} (the preamble) containing a substring, r(n).
capture program drop _tx_pre
program define _tx_pre, rclass
    version 17.0
    args path needle
    mata: _tx_pre(st_local("path"), st_local("needle"))
    return scalar n = `_tx_n'
end

* One T6 case: number, message fragment, texopts() contents.
capture program drop _tx_t6
program define _tx_t6
    version 17.0
    gettoken k 0 : 0
    gettoken msg 0 : 0
    capture noisily _tx_refuse `"`msg'"' `0'
    local trc = _rc
    _tx_rec "T6 refused #`k'" `trc'
end

mata:
mata set matastrict off
void _tx_pre(string scalar path, string scalar needle)
{
    string colvector L
    real scalar i, n
    L = cat(path)
    n = 0
    for (i = 1; i <= rows(L); i++) {
        if (strpos(L[i], char(92) + "begin{document}") > 0) break
        if (strpos(L[i], needle) > 0) n++
    }
    st_local("_tx_n", strofreal(n))
}
end

**# T1. each sub-option alone (fragment, puttab)
local tbl "\begin{tabular}{lc}"
local hdr "% tabtools LaTeX table; requires \usepackage{booktabs}"

* captionleft
capture noisily {
    local f "$TX_OUT/t1_cl.tex"
    capture erase "`f'"
    _tx_pt "`f'" texopts(captionleft)
    assert r(latex_rows) == 3 & r(latex_cols) == 2
    _tx_expect "`f'" 1 "`hdr'"
    _tx_expect "`f'" 2 "% texopts() also requires \usepackage{caption}"
    _tx_expect "`f'" 3 "\begin{table}[htbp]"
    _tx_expect "`f'" 4 "\centering"
    _tx_expect "`f'" 5 "\captionsetup{justification=raggedright,singlelinecheck=false}"
    _tx_expect "`f'" 6 "\caption{Alpha}"
    _tx_expect "`f'" 7 "\label{tab:t1_cl}"
    _tx_expect "`f'" 8 "`tbl'"
    _tx_check "`f'" --document no --compile --tables 1 --layout captionleft=yes
}
local trc = _rc
_tx_rec "T1 captionleft: captionsetup line right before \caption, caption package named" `trc'

* captionbelow
capture noisily {
    local f "$TX_OUT/t1_cb.tex"
    capture erase "`f'"
    _tx_pt "`f'" texopts(captionbelow)
    _tx_expect "`f'" 1 "`hdr'"
    _tx_expect "`f'" 2 "\begin{table}[htbp]"
    _tx_expect "`f'" 3 "\centering"
    _tx_expect "`f'" 4 "`tbl'"
    _tx_pos "`f'" "\end{table}" 1
    local pe = r(first)
    _tx_expect "`f'" `=`pe'-1' "\label{tab:t1_cb}"
    _tx_expect "`f'" `=`pe'-2' "\caption{Alpha}"
    _tx_expect "`f'" `=`pe'-3' "\end{tabular}"
    _tx_count "`f'" "\caption"
    assert r(n) == 1
    _tx_check "`f'" --document no --compile --tables 1 --layout captionpos=below
}
local trc = _rc
_tx_rec "T1 captionbelow: caption and label after the tabular, before \end{table}" `trc'

* captionbelow with a table note: caption after the note too
capture noisily {
    local f "$TX_OUT/t1_cbn.tex"
    capture erase "`f'"
    sysuse auto, clear
    puttab make price in 1/3, title("Alpha") latex("`f'") footnote("A note.") texopts(captionbelow)
    _tx_pos "`f'" "A note."
    local pn = r(first)
    _tx_pos "`f'" "\caption{Alpha}"
    local pc = r(first)
    _tx_pos "`f'" "\end{tabular}" 1
    local pt = r(first)
    _tx_pos "`f'" "\end{table}" 1
    local pe = r(first)
    assert `pt' > 0 & `pn' > `pt' & `pc' > `pn' & `pe' == `pc' + 2
    _tx_check "`f'" --document no --compile --tables 1 --layout captionpos=below
}
local trc = _rc
_tx_rec "T1 captionbelow with a table note: caption after the note" `trc'

* nocentering
capture noisily {
    local f "$TX_OUT/t1_nc.tex"
    capture erase "`f'"
    _tx_pt "`f'" texopts(nocentering)
    _tx_expect "`f'" 2 "\begin{table}[htbp]"
    _tx_expect "`f'" 3 "\caption{Alpha}"
    _tx_count "`f'" "\centering"
    assert r(n) == 0
    _tx_check "`f'" --document no --compile --tables 1 --layout centering=no
    * and the default does centre
    _tx_pt "`f'"
    _tx_count "`f'" "\centering"
    assert r(n) == 1
}
local trc = _rc
_tx_rec "T1 nocentering: no \centering line (default has one)" `trc'

* placement: valid specs, each exact; no package line except for H
capture noisily {
    local f "$TX_OUT/t1_pl.tex"
    foreach spec in !t h! tb p htbp !htb {
        capture erase "`f'"
        _tx_pt "`f'" texopts(placement(`spec'))
        _tx_expect "`f'" 2 "\begin{table}[`spec']"
        _tx_count "`f'" "texopts() also"
        assert r(n) == 0
        _tx_check "`f'" --document no --compile --tables 1 --layout placement=`spec'
    }
    capture erase "`f'"
    _tx_pt "`f'" texopts(placement(H))
    _tx_expect "`f'" 2 "% texopts() also requires \usepackage{float}"
    _tx_expect "`f'" 3 "\begin{table}[H]"
    _tx_check "`f'" --document no --compile --tables 1 --layout placement=H
    * default placement is htbp
    _tx_pt "`f'"
    _tx_expect "`f'" 2 "\begin{table}[htbp]"
}
local trc = _rc
_tx_rec "T1 placement: !t h! tb p htbp !htb exact, H needs float, default htbp" `trc'

* size: all six names, line right before the tabular and after the caption
capture noisily {
    local f "$TX_OUT/t1_sz.tex"
    foreach sz in tiny scriptsize footnotesize small normalsize large {
        capture erase "`f'"
        _tx_pt "`f'" texopts(size(`sz'))
        _tx_pos "`f'" "\begin{tabular}{lc}" 1
        local pb = r(first)
        local ln = char(92) + "`sz'"
        _tx_expect "`f'" `=`pb'-1' "`ln'"
        _tx_expect "`f'" `=`pb'-2' "\label{tab:t1_sz}"
        _tx_count "`f'" "texopts() also"
        assert r(n) == 0
        local comp ""
        if "`sz'" == "small" local comp "--compile"
        _tx_check "`f'" --document no `comp' --tables 1 --layout size=`sz'
    }
}
local trc = _rc
_tx_rec "T1 size: six type sizes, line between label and tabular, no package" `trc'

* fit
capture noisily {
    local f "$TX_OUT/t1_fit.tex"
    capture erase "`f'"
    _tx_pt "`f'" texopts(fit)
    _tx_expect "`f'" 2 "% texopts() also requires \usepackage{graphicx}"
    _tx_pos "`f'" "\begin{tabular}{lc}" 1
    local pb = r(first)
    _tx_expect "`f'" `=`pb'-1' "\resizebox{\ifdim\width>\linewidth\linewidth\else\width\fi}{!}{%"
    _tx_pos "`f'" "\end{tabular}}" 1
    assert !missing(r(first)) & r(first) > `pb'
    _tx_count "`f'" "\end{tabular}"
    assert r(n) == 1
    _tx_nd pdftext AMC Concord
    _tx_check "`f'" --document no --compile --tables 1 --layout fit=yes
}
local trc = _rc
_tx_rec "T1 fit: \resizebox before the tabular, closed after it, graphicx named" `trc'

* landscape
capture noisily {
    local f "$TX_OUT/t1_ls.tex"
    capture erase "`f'"
    _tx_pt "`f'" texopts(landscape)
    _tx_expect "`f'" 2 "% texopts() also requires \usepackage{pdflscape}"
    _tx_expect "`f'" 3 "\begin{landscape}"
    _tx_expect "`f'" 4 "\begin{table}[htbp]"
    _tx_pos "`f'" "\end{table}" 1
    local pe = r(first)
    _tx_expect "`f'" `=`pe'+1' "\end{landscape}"
    _tx_info "`f'"
    assert `"`r(lnb)'"' == "\end{landscape}"
    _tx_check "`f'" --document no --compile --tables 1 --layout landscape=yes
}
local trc = _rc
_tx_rec "T1 landscape: \begin{landscape} around the float, pdflscape named" `trc'

* label
capture noisily {
    local f "$TX_OUT/t1_lb.tex"
    capture erase "`f'"
    _tx_pt "`f'" texopts(label(tab:mine-1.a_b))
    _tx_expect "`f'" 4 "\caption{Alpha}"
    _tx_expect "`f'" 5 "\label{tab:mine-1.a_b}"
    _tx_count "`f'" "\label"
    assert r(n) == 1
    _tx_count "`f'" "tab:t1_lb"
    assert r(n) == 0
    _tx_check "`f'" --document no --compile --tables 1 --layout label=tab:mine-1.a_b
    * label is only written with a title: no title, no caption, no label
    global TX_NOTITLE "1"
    _tx_pt "`f'" texopts(label(tab:mine))
    global TX_NOTITLE ""
    _tx_count "`f'" "\label"
    assert r(n) == 0
    _tx_count "`f'" "\caption"
    assert r(n) == 0
    _tx_count "`f'" "tab:mine"
    assert r(n) == 0
}
local trc = _rc
_tx_rec "T1 label(): replaces tab:<stem>; nothing without a title" `trc'

* preamble() and docclass() do nothing on a fragment
capture noisily {
    local f1 "$TX_OUT/t1_pa.tex"
    local f2 "$TX_OUT/t1_pb.tex"
    capture erase "`f1'"
    capture erase "`f2'"
    _tx_pt "`f1'" texopts(preamble("\usepackage{lmodern}") docclass(book 12pt))
    sysuse auto, clear
    puttab make price in 1/3, title("Alpha") latex("`f2'")
    * same table under another stem: compare with the label made equal
    _tx_count "`f1'" "lmodern"
    assert r(n) == 0
    _tx_count "`f1'" "\documentclass"
    assert r(n) == 0
    _tx_count "`f1'" "texopts() also"
    assert r(n) == 0
    _tx_info "`f1'"
    local n1 = r(n)
    _tx_info "`f2'"
    assert `n1' == r(n)
    _tx_check "`f1'" --document no --compile --tables 1
}
local trc = _rc
_tx_rec "T1 preamble() and docclass() leave a fragment unchanged" `trc'

**# T2. combined layout in a created document
capture noisily {
    local f "$TX_OUT/t2.tex"
    capture erase "`f'"
    _tx_pt "`f'" texdocument texopts(captionleft size(small) fit placement(!t) label(tab:x) preamble("\usepackage{lmodern}") docclass(article 11pt a4paper))
    assert r(latex_rows) == 3 & r(latex_cols) == 2
    _tx_expect "`f'" 1 "\documentclass[11pt,a4paper]{article}"
    _tx_expect "`f'" 2 "\usepackage{booktabs}"
    _tx_expect "`f'" 3 "\usepackage{caption}"
    _tx_expect "`f'" 4 "\usepackage{graphicx}"
    _tx_expect "`f'" 5 "\usepackage{lmodern}"
    _tx_expect "`f'" 6 "\begin{document}"
    _tx_expect "`f'" 7 ""
    _tx_expect "`f'" 8 "% tabtools LaTeX table; requires \usepackage{booktabs}"
    _tx_expect "`f'" 9 "% texopts() also requires \usepackage{caption} \usepackage{graphicx}"
    _tx_expect "`f'" 10 "\begin{table}[!t]"
    _tx_expect "`f'" 11 "\centering"
    _tx_expect "`f'" 12 "\captionsetup{justification=raggedright,singlelinecheck=false}"
    _tx_expect "`f'" 13 "\caption{Alpha}"
    _tx_expect "`f'" 14 "\label{tab:x}"
    _tx_expect "`f'" 15 "\small"
    _tx_expect "`f'" 16 "\resizebox{\ifdim\width>\linewidth\linewidth\else\width\fi}{!}{%"
    _tx_expect "`f'" 17 "\begin{tabular}{lc}"
    _tx_info "`f'"
    assert r(ncls) == 1 & r(nbeg) == 1 & r(nend) == 1 & r(dbl) == 0
    assert `"`r(lnb)'"' == "\end{document}"
    _tx_nd pdftext Alpha
    _tx_check "`f'" --document yes --compile --tables 1 --layout captionleft=yes --layout size=small --layout fit=yes --layout placement=!t --layout label=tab:x
}
local trc = _rc
_tx_rec "T2 combined layout: exact preamble (class options, packages, preamble line), compiles" `trc'

**# T3. a landscape table appended into that document
capture noisily {
    local f "$TX_OUT/t2.tex"
    sysuse auto, clear
    puttab make mpg in 1/3, title("Land") latex("`f'") texappend ///
        texopts(landscape captionbelow nocentering placement(H))
    assert r(latex_rows) == 3
    _tx_exact "`f'" "\usepackage{float}"
    assert r(n) == 1
    _tx_exact "`f'" "\usepackage{pdflscape}"
    assert r(n) == 1
    _tx_exact "`f'" "\usepackage{caption}"
    assert r(n) == 1
    _tx_exact "`f'" "\usepackage{graphicx}"
    assert r(n) == 1
    _tx_exact "`f'" "\usepackage{booktabs}"
    assert r(n) == 1
    * the new packages sit just before \begin{document}, in layout order
    _tx_expect "`f'" 5 "\usepackage{lmodern}"
    _tx_expect "`f'" 6 "\usepackage{float}"
    _tx_expect "`f'" 7 "\usepackage{pdflscape}"
    _tx_expect "`f'" 8 "\begin{document}"
    _tx_info "`f'"
    assert r(ncls) == 1 & r(nend) == 1 & r(dbl) == 0
    _tx_check "`f'" --document yes --compile --tables 2 --table 2 --layout landscape=yes --layout captionpos=below --layout centering=no --layout placement=H
    * a third table with the same layout adds no package again
    puttab make mpg in 1/2, title("Land 2") latex("`f'") texappend ///
        texopts(landscape captionbelow nocentering placement(H))
    _tx_exact "`f'" "\usepackage{float}"
    assert r(n) == 1
    _tx_exact "`f'" "\usepackage{pdflscape}"
    assert r(n) == 1
    _tx_check "`f'" --document yes --compile --tables 3 --table 3 --layout landscape=yes --layout captionpos=below --layout centering=no --layout placement=H
    * the first table still has its own layout
    _tx_check "`f'" --document yes --tables 3 --table 1 --layout captionleft=yes --layout size=small --layout fit=yes --layout placement=!t --layout landscape=no
}
local trc = _rc
_tx_rec "T3 landscape+captionbelow+nocentering+placement(H) appended: float and pdflscape added once, compiles" `trc'

**# T4. a user paper: only the missing packages are added
capture noisily {
    local d "$TX_OUT/t4"
    capture mkdir "`d'"
    local f "`d'/paper.tex"
    capture erase "`f'"
    tempname fh
    file open `fh' using "`f'", write text
    file write `fh' "\documentclass{article}" _n
    file write `fh' "\usepackage[utf8]{inputenc}" _n
    file write `fh' "\usepackage{graphicx,booktabs}" _n
    file write `fh' "\begin{document}" _n
    file write `fh' "User paper prose." _n
    file write `fh' "\end{document}" _n
    file close `fh'
    sysuse auto, clear
    puttab make price in 1/3, title("Paper tbl") latex("`f'") texappend texopts(fit captionleft landscape)
    assert r(latex_rows) == 3
    _tx_expect "`f'" 1 "\documentclass{article}"
    _tx_expect "`f'" 2 "\usepackage[utf8]{inputenc}"
    _tx_expect "`f'" 3 "\usepackage{graphicx,booktabs}"
    _tx_expect "`f'" 4 "\usepackage{caption}"
    _tx_expect "`f'" 5 "\usepackage{pdflscape}"
    _tx_expect "`f'" 6 "\begin{document}"
    _tx_expect "`f'" 7 "User paper prose."
    _tx_pre "`f'" "graphicx"
    assert r(n) == 1
    _tx_pre "`f'" "booktabs"
    assert r(n) == 1
    _tx_pre "`f'" "caption"
    assert r(n) == 1
    _tx_pre "`f'" "pdflscape"
    assert r(n) == 1
    _tx_info "`f'"
    assert r(ncls) == 1 & r(nend) == 1 & r(nbeg) == 1
    _tx_pdf "`d'" paper
    _tx_txthas "`d'/paper.txt" "User paper prose."
    assert r(found) == 1
    _tx_txthas "`d'/paper.txt" "Paper tbl"
    assert r(found) == 1
    _tx_txthas "`d'/paper.txt" "AMC Concord"
    assert r(found) == 1
    * packages loaded with options, with RequirePackage, or in a list are not repeated
    local g "`d'/paper2.tex"
    capture erase "`g'"
    file open `fh' using "`g'", write text
    file write `fh' "\documentclass{article}" _n
    file write `fh' "\usepackage[final]{graphicx}" _n
    file write `fh' "\RequirePackage{caption}" _n
    file write `fh' "\usepackage{pdflscape, booktabs}" _n
    file write `fh' "\begin{document}" _n
    file write `fh' "Second paper." _n
    file write `fh' "\end{document}" _n
    file close `fh'
    puttab make price in 1/3, title("Second tbl") latex("`g'") texappend texopts(fit captionleft landscape)
    _tx_expect "`g'" 5 "\begin{document}"
    _tx_pre "`g'" "graphicx"
    assert r(n) == 1
    _tx_pre "`g'" "caption"
    assert r(n) == 1
    _tx_pre "`g'" "pdflscape"
    assert r(n) == 1
    _tx_pre "`g'" "booktabs"
    assert r(n) == 1
    _tx_pdf "`d'" paper2
    _tx_txthas "`d'/paper2.txt" "Second tbl"
    assert r(found) == 1
}
local trc = _rc
_tx_rec "T4 user paper: caption and pdflscape added, graphicx/booktabs not repeated, compiles with pdflatex" `trc'

**# T5. the fragment note
capture noisily {
    local f "$TX_OUT/t5.tex"
    capture erase "`f'"
    _tx_console _tx_pt "`f'" texopts(fit landscape captionleft)
    local txt `"`r(text)'"'
    assert r(rc) == 0
    local want "note: this LaTeX table needs \usepackage{caption} \usepackage{graphicx} \usepackage{pdflscape} in the preamble of the document that inputs it"
    local hit = strpos(`"`macval(txt)'"', `"`want'"') > 0
    if !`hit' display as error `"  console: `macval(txt)'"'
    assert `hit'
    _tx_expect "`f'" 2 "% texopts() also requires \usepackage{caption} \usepackage{graphicx} \usepackage{pdflscape}"
    * the package order is caption, float, graphicx, pdflscape
    capture erase "`f'"
    _tx_console _tx_pt "`f'" texopts(landscape fit placement(H) captionleft)
    local txt `"`r(text)'"'
    local hit = strpos(`"`macval(txt)'"', "\usepackage{caption} \usepackage{float} \usepackage{graphicx} \usepackage{pdflscape}") > 0
    assert `hit'
    _tx_expect "`f'" 2 "% texopts() also requires \usepackage{caption} \usepackage{float} \usepackage{graphicx} \usepackage{pdflscape}"
    * no packages needed: no note, no second comment line
    capture erase "`f'"
    _tx_console _tx_pt "`f'" texopts(size(small) placement(!t) nocentering captionbelow)
    local txt `"`r(text)'"'
    assert strpos(`"`macval(txt)'"', "needs") == 0
    _tx_count "`f'" "texopts() also"
    assert r(n) == 0
    * default layout: no note
    _tx_console _tx_pt "`f'"
    local txt `"`r(text)'"'
    assert strpos(`"`macval(txt)'"', "needs") == 0
    * a created document or an existing document needs no note
    local g "$TX_OUT/t5_doc.tex"
    capture erase "`g'"
    _tx_console _tx_pt "`g'" texdocument texopts(fit)
    local txt `"`r(text)'"'
    assert strpos(`"`macval(txt)'"', "needs") == 0
    _tx_console _tx_pt "`g'" texappend texopts(fit landscape)
    local txt `"`r(text)'"'
    assert strpos(`"`macval(txt)'"', "needs") == 0
}
local trc = _rc
_tx_rec "T5 fragment note names the packages in order; none for a document or when nothing is needed" `trc'

**# T6. every invalid input is r(198) and writes nothing
_tx_t6 1 "unknown or malformed sub-option" bogus
_tx_t6 2 "unknown or malformed sub-option" fit(yes)
_tx_t6 3 "unknown or malformed sub-option" captionleft frobnicate
_tx_t6 4 "unknown or malformed sub-option" placement
_tx_t6 5 "not a float placement" placement(xyz)
_tx_t6 6 "not a float placement" placement(!!t)
_tx_t6 7 "not a float placement" placement(Ht)
_tx_t6 8 "not a float placement" placement(!)
_tx_t6 9 "not a float placement" placement(H!)
_tx_t6 10 "is not one of tiny, scriptsize" size(huge)
_tx_t6 11 "is not one of tiny, scriptsize" size(Small)
_tx_t6 12 "may contain only letters, digits" label(a b)
_tx_t6 13 "may contain only letters, digits" label(a{b})
_tx_t6 14 "may not contain \documentclass" preamble("\documentclass{x}")
_tx_t6 15 "may not contain \documentclass" preamble("\usepackage{a}" "\begin{document}")
_tx_t6 16 "may not contain \documentclass" preamble("\end{document}")
_tx_t6 17 "is not a document class name" docclass(1bad)
_tx_t6 18 "class option" docclass(article 11pt!)

* a refusal leaves an existing table file, and a texappend target, untouched
capture noisily {
    local f "$TX_OUT/t6_keep.tex"
    capture erase "`f'"
    _tx_pt "`f'"
    _tx_sum "`f'"
    local before "`r(sum)'"
    assert "`before'" != "absent"
    _tx_console _tx_pt "`f'" texappend texopts(size(huge))
    assert r(rc) == 198
    _tx_console _tx_pt "`f'" texdocument texopts(placement(zz))
    assert r(rc) == 198
    _tx_sum "`f'"
    assert "`r(sum)'" == "`before'"
}
local trc = _rc
_tx_rec "T6 a refusal leaves an existing .tex byte-identical" `trc'

* texopts() without latex() (and without a session file)
capture noisily {
    quietly tabtools set clear
    local base "$TX_OUT/t6_nolatex"
    foreach e in xlsx csv md {
        capture erase "`base'.`e'"
    }
    _tx_prep regtab
    _tx_console regtab, noint title("R") xlsx("`base'.xlsx") sheet("R") csv("`base'.csv") ///
        markdown("`base'.md") texopts(captionleft)
    local crc = r(rc)
    local txt `"`r(text)'"'
    assert `crc' == 198
    assert strpos(`"`macval(txt)'"', "texopts() requires latex()") > 0
    foreach e in xlsx csv md {
        capture confirm file "`base'.`e'"
        local frc = _rc
        assert `frc' == 601
    }
}
local trc = _rc
_tx_rec "T6 texopts() without latex(): r(198), message, no workbook/CSV/Markdown" `trc'


**# T7. every command and form
capture program drop _tx_percmd
program define _tx_percmd
    version 17.0
    args id
    local f1 "$TX_OUT/pc_`id'_opt.tex"
    local f2 "$TX_OUT/pc_`id'_base.tex"
    capture erase "`f1'"
    capture erase "`f2'"
    quietly tabtools set clear
    _tx_prep `id'
    _tx_cmd `id' latex("`f2'")
    local r2 = r(latex_rows)
    local c2 = r(latex_cols)
    local n2 = r(N_rows)
    * outtab forwards the table to puttab and posts no latex returns
    if "`id'" != "outtab" assert !missing(`r2') & !missing(`c2')
    _tx_prep `id'
    _tx_cmd `id' latex("`f1'") texopts(captionleft fit)
    assert r(latex_rows) == `r2' & r(latex_cols) == `c2' & r(N_rows) == `n2'
    _tx_check "`f1'" --document no --compile --tables 1 --layout captionleft=yes --layout fit=yes
    _tx_expect "`f1'" 2 "% texopts() also requires \usepackage{caption} \usepackage{graphicx}"
    _tx_count "`f1'" "\captionsetup{justification=raggedright,singlelinecheck=false}"
    assert r(n) == 1
    _tx_count "`f1'" "\resizebox"
    assert r(n) == 1
    * the base run carries no layout lines
    _tx_check "`f2'" --document no --tables 1 --layout captionleft=no --layout fit=no
    * texopts() without latex() and without a session file
    _tx_prep `id'
    global TX_NOTITLE "1"
    _tx_console _tx_cmd `id' texopts(fit)
    global TX_NOTITLE ""
    local crc = r(rc)
    local txt `"`r(text)'"'
    display as text "  `id': texopts() without latex() rc=`crc'"
    assert `crc' == 198
    local hit = strpos(`"`macval(txt)'"', "texopts() requires latex()") > 0
    if !`hit' display as error "  message lacks: texopts() requires latex()"
    assert `hit'
end

local ids "regtab effecttab comptab_f comptab_r hrcomptab stratetab ratetab desctab table1_tc crosstab survtab puttab outtab stacktab_b stacktab_f"
foreach id of local ids {
    capture noisily _tx_percmd `id'
    local trc = _rc
    global TX_NOTITLE ""
    quietly tabtools set clear
    _tx_rec "T7 `id': texopts(captionleft fit) compiles with its layout, r() unchanged, no latex() is r(198)" `trc'
}

**# T8. session default
capture noisily {
    quietly tabtools set clear
    tabtools query
    assert `"`r(texopts)'"' == ""
    assert `"$TABTOOLS_set_texopts"' == ""
    * set and query
    tabtools set texopts captionleft fit
    assert `"`r(texopts)'"' == "captionleft fit"
    assert `"$TABTOOLS_set_texopts"' == "captionleft fit"
    tabtools query
    assert `"`r(texopts)'"' == "captionleft fit"
    * it applies when a command gives no texopts()
    local f "$TX_OUT/t8.tex"
    capture erase "`f'"
    _tx_pt "`f'"
    _tx_expect "`f'" 2 "% texopts() also requires \usepackage{caption} \usepackage{graphicx}"
    _tx_check "`f'" --document no --compile --tables 1 --layout captionleft=yes --layout fit=yes
    * and it reaches a document, appended table and another command
    local g "$TX_OUT/t8_doc.tex"
    capture erase "`g'"
    _tx_pt "`g'" texdocument
    _tx_pre "`g'" "caption"
    assert r(n) == 1
    _tx_pre "`g'" "graphicx"
    assert r(n) == 1
    _tx_check "`g'" --document yes --compile --tables 1 --layout captionleft=yes --layout fit=yes
}
local trc = _rc
_tx_rec "T8 session texopts: set, query round trip, applied to tables and documents" `trc'

capture noisily {
    * a command's texopts() replaces the session value entirely: no merge
    tabtools set texopts captionleft fit
    local f "$TX_OUT/t8_rep.tex"
    capture erase "`f'"
    _tx_pt "`f'" texopts(size(small))
    _tx_check "`f'" --document no --compile --tables 1 --layout captionleft=no --layout fit=no --layout size=small
    _tx_count "`f'" "captionsetup"
    assert r(n) == 0
    _tx_count "`f'" "resizebox"
    assert r(n) == 0
    _tx_count "`f'" "texopts() also"
    assert r(n) == 0
    * the session value is untouched by the command's own texopts()
    tabtools query
    assert `"`r(texopts)'"' == "captionleft fit"
    * a command with a layout but one that is only a placement also replaces it
    capture erase "`f'"
    _tx_pt "`f'" texopts(placement(h))
    _tx_check "`f'" --document no --compile --tables 1 --layout captionleft=no --layout fit=no --layout placement=h
}
local trc = _rc
_tx_rec "T8 a command's texopts() replaces the session value entirely (no merge)" `trc'

capture noisily {
    * label() is refused in the session value; the previous value stays
    tabtools set texopts captionleft fit
    _tx_console tabtools set texopts label(x)
    local crc = r(rc)
    local txt `"`r(text)'"'
    assert `crc' == 198
    assert strpos(`"`macval(txt)'"', "tabtools set texopts: label()") > 0
    assert `"$TABTOOLS_set_texopts"' == "captionleft fit"
    * an invalid session value: 198 and the previous value is kept
    foreach bad in "size(huge)" "bogus" "placement(zz)" "preamble(" `"preamble("\documentclass{x}")"' {
        _tx_console tabtools set texopts `bad'
        local crc = r(rc)
        display as text `"  set texopts `bad': rc=`crc'"'
        assert `crc' == 198
        assert `"$TABTOOLS_set_texopts"' == "captionleft fit"
        tabtools query
        assert `"`r(texopts)'"' == "captionleft fit"
    }
}
local trc = _rc
_tx_rec "T8 session: label() and invalid values are r(198), previous value kept" `trc'

capture noisily {
    * a value with preamble quotes round-trips through query
    local want `"captionleft preamble("\usepackage{lmodern}" "\usepackage[T1]{fontenc}") docclass(article 11pt)"'
    tabtools set texopts `want'
    assert `"`r(texopts)'"' == `"`want'"'
    tabtools query
    assert `"`r(texopts)'"' == `"`want'"'
    assert `"$TABTOOLS_set_texopts"' == `"`want'"'
    * and it is used when a document is created
    local g "$TX_OUT/t8_pre.tex"
    capture erase "`g'"
    _tx_pt "`g'" texdocument
    _tx_expect "`g'" 1 "\documentclass[11pt]{article}"
    _tx_expect "`g'" 2 "\usepackage{booktabs}"
    _tx_expect "`g'" 3 "\usepackage{caption}"
    _tx_expect "`g'" 4 "\usepackage{lmodern}"
    _tx_expect "`g'" 5 "\usepackage[T1]{fontenc}"
    _tx_expect "`g'" 6 "\begin{document}"
    _tx_check "`g'" --document yes --compile --tables 1 --layout captionleft=yes
}
local trc = _rc
_tx_rec "T8 session preamble() with quotes round-trips through query and builds the document" `trc'

capture noisily {
    * the session layout does not break a command that writes no LaTeX
    tabtools set texopts captionleft fit
    _tx_prep regtab
    local x "$TX_OUT/t8_sess.xlsx"
    capture erase "`x'"
    regtab, noint xlsx("`x'") sheet("S")
    confirm file "`x'"
    * texopts() with the session LaTeX file in place needs no latex()
    local sess "$TX_OUT/t8_sessfile.tex"
    capture erase "`sess'"
    quietly tabtools set latex "`sess'"
    _tx_pt "`sess'" texopts(fit)
}
local trc = _rc
quietly tabtools set clear
_tx_rec "T8 session layout with an xlsx-only command; texopts() works with a session LaTeX file" `trc'
capture noisily {
    local sess "$TX_OUT/t8_sessfile.tex"
    confirm file "`sess'"
    _tx_check "`sess'" --document no --compile --tables 1 --layout fit=yes
}
local trc = _rc
_tx_rec "T8 the session file table carries the fit layout" `trc'

capture noisily {
    * clear: texopts clear and set clear both remove it
    tabtools set texopts captionleft fit
    tabtools set texopts clear
    assert `"$TABTOOLS_set_texopts"' == ""
    tabtools query
    assert `"`r(texopts)'"' == ""
    local f "$TX_OUT/t8_clr.tex"
    capture erase "`f'"
    _tx_pt "`f'"
    _tx_expect "`f'" 2 "\begin{table}[htbp]"
    _tx_count "`f'" "captionsetup"
    assert r(n) == 0
    tabtools set texopts size(small) fit
    tabtools set clear
    assert `"$TABTOOLS_set_texopts"' == ""
    tabtools query
    assert `"`r(texopts)'"' == ""
    capture erase "`f'"
    _tx_pt "`f'"
    _tx_count "`f'" "resizebox"
    assert r(n) == 0
    _tx_count "`f'" "texopts() also"
    assert r(n) == 0
}
local trc = _rc
quietly tabtools set clear
_tx_rec "T8 texopts clear and set clear remove the session layout" `trc'

**# T9. fit never enlarges a narrow table
capture noisily {
    local d "$TX_OUT/t9"
    capture mkdir "`d'"
    * graphicx sets the PDF page size (letter) where a bare article keeps the
    * engine default (A4), so the no-fit document loads graphicx too: the only
    * difference left between the two is \resizebox.
    foreach stem in nofit fit {
        local opt `"texopts(preamble("\usepackage{graphicx}"))"'
        if "`stem'" == "fit" local opt "texopts(fit)"
        capture erase "`d'/`stem'.tex"
        _tx_pt "`d'/`stem'.tex" texdocument `opt'
        _tx_pdf2 "`d'" `stem'
        _tx_pdf "`d'" `stem'
    }
    _tx_count "`d'/fit.tex" "\resizebox"
    assert r(n) == 1
    _tx_count "`d'/nofit.tex" "\resizebox"
    assert r(n) == 0
    * identical text, and identical word boxes (position and size)
    _tx_sum "`d'/nofit.txt"
    local s1 "`r(sum)'"
    _tx_sum "`d'/fit.txt"
    local s2 "`r(sum)'"
    display as text "  pdftotext nofit `s1', fit `s2'"
    assert "`s1'" != "absent" & "`s1'" == "`s2'"
    _tx_sum "`d'/nofit.bbox"
    local b1 "`r(sum)'"
    _tx_sum "`d'/fit.bbox"
    local b2 "`r(sum)'"
    display as text "  pdftotext -bbox nofit `b1', fit `b2'"
    assert "`b1'" != "absent" & "`b1'" == "`b2'"
}
local trc = _rc
_tx_rec "T9 fit leaves a narrow table identical: same pdftotext and same word boxes" `trc'

capture noisily {
    local d "$TX_OUT/t9"
    * a wide table overflows the page without fit and fits with it
    capture erase "`d'/wide0.tex"
    capture erase "`d'/wide1.tex"
    _tx_wide "`d'/wide0.tex"
    _tx_wide "`d'/wide1.tex" texopts(fit)
    _tx_pdf2 "`d'" wide0
    _tx_logn "`d'/wide0.log" "Overfull \hbox"
    local o0 = r(n)
    _tx_pdf2 "`d'" wide1
    _tx_logn "`d'/wide1.log" "Overfull \hbox"
    local o1 = r(n)
    display as text "  overfull boxes: without fit `o0', with fit `o1'"
    assert `o0' >= 1
    assert `o1' == 0
    _tx_nd pdftext number 7
    _tx_check "`d'/wide1.tex" --document yes --compile --tables 1 --layout fit=yes
    * the last column is still readable in the shrunken table
    shell pdftotext "`d'/wide1.pdf" "`d'/wide1.txt"
    _tx_txthas "`d'/wide1.txt" "number 7"
    assert r(found) == 1
}
local trc = _rc
_tx_rec "T9 fit shrinks a wide table to the line: overfull without it, none with it" `trc'

**# T10. regression pins from the independent review
* 1: a commented \usepackage does not count as loaded
capture noisily {
    local d "$TX_OUT/t10"
    capture mkdir "`d'"
    local f "`d'/p1.tex"
    _tx_mkpaper "`f'" plain "\usepackage{booktabs}" "% \usepackage{caption}"
    sysuse auto, clear
    puttab make price in 1/3, title("P1 tbl") latex("`f'") texappend texopts(captionleft)
    _tx_pre "`f'" "usepackage{caption}"
    assert r(n) == 2
    _tx_exact "`f'" "\usepackage{caption}"
    assert r(n) == 1
    _tx_pos "`f'" "\usepackage{caption}" 1
    local pc = r(first)
    _tx_pos "`f'" "\begin{document}" 1
    assert `pc' > 0 & !missing(r(first)) & `pc' < r(first)
    _tx_expect "`f'" `=r(first)-1' "\usepackage{caption}"
    _tx_pdf "`d'" p1
    _tx_txthas "`d'/p1.txt" "P1 tbl"
    assert r(found) == 1
}
local trc = _rc
_tx_rec "T10.1 a commented \usepackage{caption} is not loaded: the package is added, compiles" `trc'

* 2: text after \begin{document} on the same line
capture noisily {
    local d "$TX_OUT/t10"
    local f "`d'/p2.tex"
    capture erase "`f'"
    tempname fh
    file open `fh' using "`f'", write text
    file write `fh' "\documentclass{article}" _n
    file write `fh' "\usepackage{booktabs}" _n
    file write `fh' "\begin{document}\section{A}" _n
    file write `fh' "Section text." _n
    file write `fh' "\end{document}" _n
    file close `fh'
    sysuse auto, clear
    puttab make price in 1/3, title("P2 tbl") latex("`f'") texappend texopts(captionleft fit)
    _tx_pos "`f'" "\begin{document}\section{A}" 1
    local pb = r(first)
    assert `pb' > 0
    _tx_expect "`f'" `=`pb'-2' "\usepackage{caption}"
    _tx_expect "`f'" `=`pb'-1' "\usepackage{graphicx}"
    _tx_exact "`f'" "\begin{document}"
    assert r(n) == 0
    _tx_info "`f'"
    assert r(nend) == 1 & r(ncls) == 1
    _tx_pdf "`d'" p2
    _tx_txthas "`d'/p2.txt" "P2 tbl"
    assert r(found) == 1
}
local trc = _rc
_tx_rec "T10.2 \begin{document}\section{A} on one line: packages go before that line, compiles" `trc'

* 3: two packages on one line, a commented one after them
capture noisily {
    local d "$TX_OUT/t10"
    local f "`d'/p3.tex"
    _tx_mkpaper "`f'" plain "\usepackage{booktabs}\usepackage{float} % \usepackage{graphicx}"
    sysuse auto, clear
    puttab make price in 1/3, title("P3 tbl") latex("`f'") texappend texopts(fit placement(H))
    _tx_exact "`f'" "\usepackage{graphicx}"
    assert r(n) == 1
    _tx_exact "`f'" "\usepackage{float}"
    assert r(n) == 0
    _tx_exact "`f'" "\usepackage{booktabs}"
    assert r(n) == 0
    _tx_pre "`f'" "usepackage{float}"
    assert r(n) == 1
    _tx_pre "`f'" "usepackage{booktabs}"
    assert r(n) == 1
    _tx_pos "`f'" "\usepackage{graphicx}" 1
    local pg = r(first)
    _tx_pos "`f'" "\begin{document}" 1
    assert `pg' > 0 & !missing(r(first)) & `pg' < r(first)
    _tx_pdf "`d'" p3
    _tx_txthas "`d'/p3.txt" "P3 tbl"
    assert r(found) == 1
}
local trc = _rc
_tx_rec "T10.3 two packages on one line: float and booktabs seen, commented graphicx is added" `trc'

* 4: \end{document} followed by a comment
capture noisily {
    local d "$TX_OUT/t10"
    local f "`d'/p4.tex"
    _tx_mkpaper "`f'" "\end{document} % done" "\usepackage{booktabs}"
    sysuse auto, clear
    puttab make price in 1/3, title("P4 tbl one") latex("`f'") texappend
    _tx_count "`f'" "\end{document}"
    assert r(n) == 1
    _tx_info "`f'"
    assert `"`r(lnb)'"' == "\end{document} % done"
    _tx_pos "`f'" "\begin{table}"
    local pt = r(first)
    _tx_pos "`f'" "\end{document}"
    assert `pt' > 0 & !missing(r(first)) & `pt' < r(first)
    * texappend texdocument is accepted, not refused
    puttab make mpg in 1/3, title("P4 tbl two") latex("`f'") texappend texdocument
    local arc = _rc
    assert `arc' == 0
    _tx_count "`f'" "\end{document}"
    assert r(n) == 1
    _tx_info "`f'"
    assert `"`r(lnb)'"' == "\end{document} % done"
    _tx_count "`f'" "\begin{table}"
    assert r(n) == 2
    _tx_pdf "`d'" p4
    _tx_txthas "`d'/p4.txt" "P4 tbl two"
    assert r(found) == 1
}
local trc = _rc
_tx_rec "T10.4 \end{document} % done: table inserted before it, one end line, texappend texdocument accepted" `trc'

* 5: dollar signs and backticks in preamble() survive every route
capture noisily {
    global p "LEAK"
    local d "$TX_OUT/t10"
    * Each command is written out in full: a texopts() passed through a helper
    * program's macro would be expanded twice and the global would leak.
    foreach id in regtab puttab {
        local f "`d'/pv_`id'.tex"
        capture erase "`f'"
        quietly tabtools set clear
        _tx_prep `id'
        if "`id'" == "regtab" {
            regtab, noint title("Cmd") latex("`f'") texdocument texopts(preamble("\newcommand{\pv}{\$p\$}"))
        }
        else {
            puttab make price in 1/4, varlabels title("Cmd") latex("`f'") texdocument texopts(preamble("\newcommand{\pv}{\$p\$}"))
        }
        _tx_pvline "`f'"
        display as text "  `id': preamble lines equal to the exact text: " r(n)
        assert r(n) == 1
        _tx_count "`f'" "LEAK"
        assert r(n) == 0
        _tx_check "`f'" --document yes --compile --tables 1
    }
    * through the session value
    quietly tabtools set clear
    tabtools set texopts preamble("\newcommand{\pv}{\$p\$}")
    mata: st_local("_q", st_global("r(texopts)"))
    mata: st_local("_qh", strofreal(strpos(st_local("_q"), "{" + char(36) + "p" + char(36) + "}") > 0))
    assert `_qh' == 1
    mata: st_local("_ql", strofreal(strpos(st_local("_q"), "LEAK") > 0))
    assert `_ql' == 0
    tabtools query
    mata: st_local("_q", st_global("r(texopts)"))
    mata: st_local("_qh", strofreal(strpos(st_local("_q"), "{" + char(36) + "p" + char(36) + "}") > 0))
    assert `_qh' == 1
    foreach id in puttab regtab {
        local f "`d'/pvs_`id'.tex"
        capture erase "`f'"
        _tx_prep `id'
        _tx_cmd `id' latex("`f'") texdocument
        _tx_pvline "`f'"
        assert r(n) == 1
        _tx_count "`f'" "LEAK"
        assert r(n) == 0
    }
}
local trc = _rc
global p ""
quietly tabtools set clear
_tx_rec "T10.5 preamble() with dollar signs survives puttab, regtab and the session value" `trc'

capture noisily {
    global p "LEAK"
    local f "$TX_OUT/t10/pv_outtab.tex"
    capture erase "`f'"
    quietly tabtools set clear
    _tx_prep outtab
    outtab cs ptb, exposure(narc) title("Cmd") latex("`f'") texdocument texopts(preamble("\newcommand{\pv}{\$p\$}"))
    _tx_pvline "`f'"
    display as text "  outtab: preamble lines equal to the exact text: " r(n)
    assert r(n) == 1
    _tx_count "`f'" "LEAK"
    assert r(n) == 0
}
local trc = _rc
global p ""
_tx_rec "T10.5b preamble() with dollar signs survives outtab" `trc'

capture noisily {
    global p "LEAK"
    local f "$TX_OUT/t10/pv_stacktab_f.tex"
    capture erase "`f'"
    quietly tabtools set clear
    _tx_prep stacktab_f
    stacktab using "$TX_WB", frames(_tx_fa "All cars" \ _tx_fb "Expensive cars") sheet("TDF") title("Cmd") latex("`f'") texdocument texopts(preamble("\newcommand{\pv}{\$p\$}"))
    _tx_pvline "`f'"
    display as text "  stacktab frames(): preamble lines equal to the exact text: " r(n)
    assert r(n) == 1
    _tx_count "`f'" "LEAK"
    assert r(n) == 0
}
local trc = _rc
global p ""
_tx_rec "T10.5c preamble() with dollar signs survives stacktab frames()" `trc'

capture noisily {
    global p "LEAK"
    local f "$TX_OUT/t10/pv_stacktab_b.tex"
    capture erase "`f'"
    quietly tabtools set clear
    _tx_prep stacktab_b
    stacktab using "$TX_WB", blocks(sheet(SrcA) rows(1/4) cols(A-C)) sheet("TDB") sheetreplace title("Cmd") latex("`f'") texdocument texopts(preamble("\newcommand{\pv}{\$p\$}"))
    _tx_pvline "`f'"
    display as text "  stacktab blocks(): preamble lines equal to the exact text: " r(n)
    assert r(n) == 1
    _tx_count "`f'" "LEAK"
    assert r(n) == 0
}
local trc = _rc
global p ""
_tx_rec "T10.5d preamble() with dollar signs survives stacktab blocks()" `trc'

* 6: placement specs with a bang
capture noisily {
    local f "$TX_OUT/t10_pl.tex"
    * !h is in the checker's grammar; h!t is not (its regex allows the bang
    * only at either end), so h!t is pinned by exact line and a direct compile.
    capture erase "`f'"
    _tx_pt "`f'" texopts(placement(!h))
    _tx_expect "`f'" 2 "\begin{table}[!h]"
    _tx_check "`f'" --document no --compile --tables 1 --layout placement=!h
    local d "$TX_OUT/t10"
    capture mkdir "`d'"
    capture erase "`d'/pl.tex"
    _tx_pt "`d'/pl.tex" texdocument texopts(placement(h!t))
    _tx_exact "`d'/pl.tex" "\begin{table}[h!t]"
    assert r(n) == 1
    _tx_pdf "`d'" pl
    _tx_txthas "`d'/pl.txt" "AMC Concord"
    assert r(found) == 1
    _tx_refuse "not a float placement" placement(!h!)
    _tx_refuse "not a float placement" placement(H!)
}
local trc = _rc
_tx_rec "T10.6 placement(h!t) and placement(!h) accepted; placement(!h!) and placement(H!) refused" `trc'

* 7: centering is not a sub-option (nocentering is)
capture noisily {
    _tx_refuse "unknown or malformed sub-option" centering
}
local trc = _rc
_tx_rec "T10.7 texopts(centering) is r(198), no file written" `trc'

* 8: texopts(none) turns the session layout off for one command
capture noisily {
    quietly tabtools set clear
    tabtools set texopts fit captionleft
    local f "$TX_OUT/t10_none.tex"
    capture erase "`f'"
    _tx_pt "`f'" texopts(none)
    _tx_expect "`f'" 1 "% tabtools LaTeX table; requires \usepackage{booktabs}"
    _tx_expect "`f'" 2 "\begin{table}[htbp]"
    _tx_count "`f'" "resizebox"
    assert r(n) == 0
    _tx_count "`f'" "captionsetup"
    assert r(n) == 0
    _tx_count "`f'" "texopts() also"
    assert r(n) == 0
    _tx_check "`f'" --document no --compile --tables 1 --layout fit=no --layout captionleft=no
    * the session value is still there
    tabtools query
    assert `"`r(texopts)'"' == "fit captionleft"
    * none with anything else is refused, writing nothing
    capture erase "`f'"
    _tx_console _tx_pt "`f'" texopts(none fit)
    assert r(rc) == 198
    capture confirm file "`f'"
    local frc = _rc
    assert `frc' == 601
    _tx_refuse "none" none fit
    * and none is not a session value
    _tx_console tabtools set texopts none
    assert r(rc) == 198
    assert `"$TABTOOLS_set_texopts"' == "fit captionleft"
}
local trc = _rc
quietly tabtools set clear
_tx_rec "T10.8 texopts(none) writes the default layout under a session layout; none+fit and session none are r(198)" `trc'

* 9: captionleft without a title needs nothing
capture noisily {
    quietly tabtools set clear
    local f "$TX_OUT/t10_nt.tex"
    capture erase "`f'"
    global TX_NOTITLE "1"
    _tx_console _tx_pt "`f'" texopts(captionleft)
    global TX_NOTITLE ""
    assert r(rc) == 0
    local txt `"`r(text)'"'
    assert strpos(`"`macval(txt)'"', "needs") == 0
    _tx_count "`f'" "captionsetup"
    assert r(n) == 0
    _tx_count "`f'" "texopts() also"
    assert r(n) == 0
    _tx_count "`f'" "\caption"
    assert r(n) == 0
    _tx_check "`f'" --document no --compile --tables 1
}
local trc = _rc
global TX_NOTITLE ""
_tx_rec "T10.9 captionleft without a title: no captionsetup, no package line, no console note" `trc'


**# Summary
local test_count = $TX_PASS + $TX_FAIL
display ""
display as result "Results: $TX_PASS/`test_count' passed, $TX_FAIL failed"
if $TX_FAIL > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_latex_texopts tests=`test_count' pass=$TX_PASS fail=$TX_FAIL"
    log close _tx
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_latex_texopts tests=`test_count' pass=$TX_PASS fail=$TX_FAIL"
log close _tx
