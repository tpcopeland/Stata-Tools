* test_issue_review_1_11_0.do - Regression suite for the 1.11.0 issue review
*
* Every check here fails on 1.10.1. Each block names the defect it pins so a
* future edit that reintroduces it is caught by the assertion, not by a reader.

clear all
version 17.0
set more off
set varabbrev off

capture log close _all
log using "test_issue_review_1_11_0.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir = c(pwd)
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
which regtab

* A fixed name under c(tmpdir) is shared by every concurrent run of this file,
* so two runs silently overwrite each other's artifacts. tempfile names are
* process-unique in Stata 16/17 (c(pid) is not defined there).
local outdir "$TABTOOLS_QA_OUTPUT_DIR"
if `"`outdir'"' == "" {
    tempfile _ir_token
    local outdir "`_ir_token'_issue_review"
    capture mkdir `"`outdir'"'
}

**# 1. regtab: a model that never contained the factor leaves its levels blank
* 1.10.1 labelled every factor level "Reference" in every model, including a
* model with no such variable, then merged the estimate/CI/p triplet on the
* UNION of reference rows across models -- destroying the confidence interval
* and p-value of the model that did have a result on that row.

local ++test_count
capture noisily {
    local xlsx "`outdir'/_ir_regtab_multimodel.xlsx"
    capture erase "`xlsx'"
    sysuse auto, clear
    collect clear
    quietly collect: logistic foreign mpg
    quietly collect: logistic foreign mpg i.rep78
    regtab, models("NoFactor \ WithFactor") xlsx("`xlsx'") sheet("MM") ///
        csv("`outdir'/_ir_regtab_multimodel.csv")

    quietly import excel using "`xlsx'", sheet("MM") allstring clear
    * Layout: col A spacer, B labels, C-E model 1, F-H model 2.
    * Rows 4.. are data; the rep78 block starts after the mpg row.
    quietly gen long _ir_row = _n
    quietly count if strtrim(B) == "3"
    assert r(N) == 1
    quietly summarize _ir_row if strtrim(B) == "3", meanonly
    local _row3 = r(min)
    quietly summarize _ir_row if strtrim(B) == "1", meanonly
    local _rowbase = r(min)

    * Model 1 has no rep78 at all: every one of its cells on those rows is blank.
    foreach _r in `_row3' `_rowbase' {
        assert strtrim(C[`_r']) == ""
        assert strtrim(D[`_r']) == ""
        assert strtrim(E[`_r']) == ""
    }
    * Model 2 has a real estimate on the 3.rep78 row: estimate, CI and p all survive.
    assert strtrim(F[`_row3']) != "" & strtrim(F[`_row3']) != "Reference"
    assert strpos(G[`_row3'], "(") > 0 & strpos(G[`_row3'], ",") > 0
    assert strtrim(H[`_row3']) != ""
    * Model 2's own constrained level still carries the reference label.
    assert strtrim(F[`_rowbase']) == "Reference"
}
if _rc == 0 {
    display as result "  PASS 1: regtab absent factor levels stay blank and estimable rows keep CI/p"
    local ++pass_count
}
else {
    display as error "  FAIL 1: regtab multi-model factor levels (rc=`=_rc')"
    local ++fail_count
}

**# 2. regtab: large confidence limits keep fixed-point precision
* 1.10.1 built the CI field as %(digits+3).(digits)fc -- %5.2fc by default.
* Stata silently falls back to low-precision scientific notation on overflow,
* so two distinct bounds rendered as one indistinguishable "(1.0e+09, 1.0e+09)".

local ++test_count
capture noisily {
    clear
    set obs 500
    set seed 42
    gen double x = rnormal()
    gen double y = 1e9 * x + rnormal() * 1e6
    collect clear
    quietly collect: regress y x
    tempname frbig
    regtab, frame(`frbig')

    frame `frbig' {
        quietly count if strpos(c2, "e+") > 0 | strpos(c2, "e-") > 0
        assert r(N) == 0
        * The two bounds of the slope interval must not render identically.
        quietly count if strtrim(A) == "x"
        assert r(N) == 1
        quietly gen long _ir_row = _n
        quietly summarize _ir_row if strtrim(A) == "x", meanonly
        local _xr = r(min)
        local _ci = c2[`_xr']
        local _inner = subinstr(subinstr("`_ci'", "(", "", 1), ")", "", 1)
        local _lo = strtrim(substr("`_inner'", 1, strpos("`_inner'", ",") - 1))
        local _hi = strtrim(substr("`_inner'", strpos("`_inner'", ",") + 1, .))
        assert "`_lo'" != "`_hi'"
        assert real("`_lo'") < real("`_hi'")
    }
    capture frame drop `frbig'
}
if _rc == 0 {
    display as result "  PASS 2: regtab large CI bounds stay fixed-point and distinct"
    local ++pass_count
}
else {
    display as error "  FAIL 2: regtab large CI precision (rc=`=_rc')"
    local ++fail_count
}

**# 3. table1_tc: one header descriptor, and the same one, in every sink
* 1.10.1 rebuilt the descriptor inside the Excel branch with a different join,
* a hardcoded "Mean (SD)" that ignored sdleft()/sdright(), and a binary branch
* that never incremented part_count -- producing "No. (Column %)Mean (SD)".
* Because CSV and Markdown ran after the Excel branch, adding xlsx() also
* changed those files.

local ++test_count
capture noisily {
    local t1x "`outdir'/_ir_t1.xlsx"
    local csv_nox "`outdir'/_ir_t1_nox.csv"
    local csv_x "`outdir'/_ir_t1_x.csv"
    local md_nox "`outdir'/_ir_t1_nox.md"
    local md_x "`outdir'/_ir_t1_x.md"
    foreach f in "`t1x'" "`csv_nox'" "`csv_x'" "`md_nox'" "`md_x'" {
        capture erase "`f'"
    }

    sysuse auto, clear
    keep if inlist(rep78, 1, 2)
    gen byte hi = mpg > 20
    table1_tc, by(rep78) vars(hi bin \ price contn) ///
        csv("`csv_nox'") markdown("`md_nox'") clear

    sysuse auto, clear
    keep if inlist(rep78, 1, 2)
    gen byte hi = mpg > 20
    table1_tc, by(rep78) vars(hi bin \ price contn) ///
        xlsx("`t1x'") sheet("T1") csv("`csv_x'") markdown("`md_x'") clear

    * ---- sink parity: xlsx() must not reshape the CSV or the Markdown ----
    tempfile csvdiff
    shell diff "`csv_nox'" "`csv_x'" > "`csvdiff'"
    tempname dfh
    file open `dfh' using "`csvdiff'", read text
    file read `dfh' _dline
    assert r(eof) == 1
    file close `dfh'

    tempfile mddiff
    shell diff "`md_nox'" "`md_x'" > "`mddiff'"
    tempname mfh
    file open `mfh' using "`mddiff'", read text
    file read `mfh' _mline
    assert r(eof) == 1
    file close `mfh'

    * ---- one descriptor, matching the ACTIVE +/- notation ----
    quietly import excel using "`t1x'", sheet("T1") allstring clear
    local _desc = strtrim(B[2])
    assert strpos("`_desc'", "Mean (SD)") == 0
    assert strpos("`_desc'", "No. (Column %)Mean") == 0
    assert strpos("`_desc'", "No. (Column %)") > 0
    * The descriptor must not also occupy row 3 (it did in 1.10.1).
    assert strtrim(B[3]) == ""
}
if _rc == 0 {
    display as result "  PASS 3: table1_tc descriptor is built once and every sink agrees"
    local ++pass_count
}
else {
    display as error "  FAIL 3: table1_tc header descriptor / sink parity (rc=`=_rc')"
    local ++fail_count
}

**# 4. Markdown: a heading comes from title(), never from table data
* 1.10.1 scanned row 1 for the first non-empty cell when no title() was given.
* In table1_tc row 1 holds the group labels, so a by(foreign) table with no
* title was headed "### Domestic".

local ++test_count
capture noisily {
    local md_notitle "`outdir'/_ir_md_notitle.md"
    local md_title "`outdir'/_ir_md_title.md"
    capture erase "`md_notitle'"
    capture erase "`md_title'"

    sysuse auto, clear
    table1_tc price mpg, by(foreign) markdown("`md_notitle'") clear
    sysuse auto, clear
    table1_tc price mpg, by(foreign) title("Table 1. Baseline") ///
        markdown("`md_title'") clear

    * No heading without title().
    tempname nfh
    file open `nfh' using "`md_notitle'", read text
    local _found_heading = 0
    file read `nfh' _line
    while r(eof) == 0 {
        if substr(`"`macval(_line)'"', 1, 4) == "### " local _found_heading = 1
        file read `nfh' _line
    }
    file close `nfh'
    assert `_found_heading' == 0

    * The explicit title still produces exactly that heading.
    tempname tfh
    file open `tfh' using "`md_title'", read text
    file read `tfh' _line
    assert `"`macval(_line)'"' == "### Table 1. Baseline"
    file close `tfh'
}
if _rc == 0 {
    display as result "  PASS 4: Markdown headings come only from title()"
    local ++pass_count
}
else {
    display as error "  FAIL 4: Markdown title inference (rc=`=_rc')"
    local ++fail_count
}

**# 5. Markdown: two-level headers flatten into the single GFM header row
* 1.10.1 wrote only the model-name row as the header and dropped the statistic
* labels into the body; effecttab without models() emitted a blank header row.
* table1_tc lost the group labels entirely.

capture program drop _ir_first_line
program define _ir_first_line, rclass
    args path
    tempname fh
    file open `fh' using "`path'", read text
    file read `fh' _l
    file close `fh'
    return local line `"`macval(_l)'"'
end

local ++test_count
capture noisily {
    * ---- regtab: header names the model AND the statistic ----
    local md_reg "`outdir'/_ir_md_regtab.md"
    capture erase "`md_reg'"
    sysuse auto, clear
    collect clear
    quietly collect: logistic foreign mpg
    quietly collect: logistic foreign mpg turn
    regtab, models("Model A \ Model B") markdown("`md_reg'")
    _ir_first_line "`md_reg'"
    local _h `"`r(line)'"'
    assert strpos(`"`_h'"', "Model A: OR") > 0
    assert strpos(`"`_h'"', "Model A: 95% CI") > 0
    assert strpos(`"`_h'"', "Model B: p-value") > 0

    * ---- effecttab with no models(): statistic labels ARE the header ----
    local md_eff "`outdir'/_ir_md_effecttab.md"
    capture erase "`md_eff'"
    webuse cattaneo2, clear
    collect clear
    quietly collect: teffects ra (bweight mage medu) (mbsmoke)
    effecttab, markdown("`md_eff'")
    _ir_first_line "`md_eff'"
    local _h `"`r(line)'"'
    assert strpos(`"`_h'"', "Effect") > 0
    assert strpos(`"`_h'"', "95% CI") > 0
    assert strpos(`"`_h'"', "p-value") > 0

    * ---- table1_tc: every group column names its group ----
    local md_t1 "`outdir'/_ir_md_t1hdr.md"
    capture erase "`md_t1'"
    sysuse auto, clear
    table1_tc price mpg, by(foreign) markdown("`md_t1'") clear
    _ir_first_line "`md_t1'"
    local _h `"`r(line)'"'
    assert strpos(`"`_h'"', "Domestic") > 0
    assert strpos(`"`_h'"', "Foreign") > 0
    assert strpos(`"`_h'"', "N=") > 0
    * A duplicated stat header ("p-value (p-value)") is a flatten bug.
    assert strpos(`"`_h'"', "p-value (p-value)") == 0
}
if _rc == 0 {
    display as result "  PASS 5: two-level headers flatten into one reader-facing Markdown row"
    local ++pass_count
}
else {
    display as error "  FAIL 5: Markdown multi-row header flattening (rc=`=_rc')"
    local ++fail_count
}

**# 6. regtab/effecttab: the Markdown flatten must not leak into frame()
* The flatten mutates the header row in place; without a snapshot it would
* reach frame() and any later consumer (comptab, hrcomptab).

local ++test_count
capture noisily {
    local md_leak "`outdir'/_ir_md_leak.md"
    capture erase "`md_leak'"
    tempname frleak
    sysuse auto, clear
    collect clear
    quietly collect: logistic foreign mpg
    quietly collect: logistic foreign mpg turn
    regtab, models("Model A \ Model B") markdown("`md_leak'") frame(`frleak')
    frame `frleak' {
        * Row 2 is the model-name row, row 3 the statistic labels: unprefixed.
        assert strtrim(c1[2]) == "Model A"
        assert strtrim(c1[3]) == "OR"
        assert strpos(c1[3], "Model A:") == 0
    }
    capture frame drop `frleak'
}
if _rc == 0 {
    display as result "  PASS 6: the Markdown header flatten does not reach frame()"
    local ++pass_count
}
else {
    display as error "  FAIL 6: Markdown flatten leaked into frame() (rc=`=_rc')"
    local ++fail_count
}

**# 7. Test-summary grammar: an operator-carrying p-value is not glued to "="
* 1.10.1 emitted "Fisher's exact test: p = <0.001".

local ++test_count
capture noisily {
    tempname frx
    sysuse auto, clear
    crosstab foreign rep78, exact frame(`frx')
    frame `frx' {
        quietly count if strpos(c1, "p = <") > 0 | strpos(c1, "p = >") > 0
        assert r(N) == 0
        quietly count if strpos(c1, "exact test: p < ") > 0
        assert r(N) == 1
    }
    capture frame drop `frx'

    tempname frs
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    survtab, times(10 20) by(drug) frame(`frs')
    frame `frs' {
        quietly count if strpos(c1, "p = <") > 0 | strpos(c1, "p = >") > 0
        assert r(N) == 0
        quietly count if strpos(c1, "Log-rank test") > 0 & strpos(c1, "p < ") > 0
        assert r(N) == 1
    }
    capture frame drop `frs'
}
if _rc == 0 {
    display as result "  PASS 7: test summaries phrase truncated p-values with the right operator"
    local ++pass_count
}
else {
    display as error "  FAIL 7: p-value phrase grammar (rc=`=_rc')"
    local ++fail_count
}

**# 8. Generated legends reach every sink
* corrtab printed its star legend to the console and the workbook but passed
* only the user footnote to Markdown, so a Markdown file could contain
* "0.54***" with nothing explaining the mark.

local ++test_count
capture noisily {
    local md_corr "`outdir'/_ir_md_corr.md"
    capture erase "`md_corr'"
    sysuse auto, clear
    corrtab price mpg weight turn, markdown("`md_corr'")

    * The rendered table uses stars, so the file must carry the legend.
    local _has_star = 0
    local _has_legend = 0
    tempname cfh
    file open `cfh' using "`md_corr'", read text
    file read `cfh' _line
    while r(eof) == 0 {
        if strpos(`"`macval(_line)'"', "*") > 0 & strpos(`"`macval(_line)'"', "|") > 0 ///
            local _has_star = 1
        if strpos(`"`macval(_line)'"', "p<") > 0 local _has_legend = 1
        file read `cfh' _line
    }
    file close `cfh'
    assert `_has_star' == 1
    assert `_has_legend' == 1

    * A user footnote ending in a period must not gain ".;".
    local md_corr2 "`outdir'/_ir_md_corr2.md"
    capture erase "`md_corr2'"
    corrtab price mpg weight turn, footnote("Pairwise complete observations.") ///
        markdown("`md_corr2'")
    local _bad_punct = 0
    tempname c2fh
    file open `c2fh' using "`md_corr2'", read text
    file read `c2fh' _line
    while r(eof) == 0 {
        if strpos(`"`macval(_line)'"', ".;") > 0 local _bad_punct = 1
        file read `c2fh' _line
    }
    file close `c2fh'
    assert `_bad_punct' == 0
}
if _rc == 0 {
    display as result "  PASS 8: corrtab star legend reaches Markdown and joins punctuation-safely"
    local ++pass_count
}
else {
    display as error "  FAIL 8: generated-annotation parity (rc=`=_rc')"
    local ++fail_count
}

**# 9. Footnote joining never produces ".;"
* regtab glued "; <stars legend>" straight onto a user footnote.

local ++test_count
capture noisily {
    tempname frfn
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    local xlsx_fn "`outdir'/_ir_regtab_footnote.xlsx"
    capture erase "`xlsx_fn'"
    regtab, stars footnote("Adjusted for age.") xlsx("`xlsx_fn'") sheet("Fn")

    quietly import excel using "`xlsx_fn'", sheet("Fn") allstring clear
    local _bad = 0
    quietly ds
    foreach v of varlist `r(varlist)' {
        quietly count if strpos(`v', ".;") > 0
        if r(N) > 0 local _bad = 1
    }
    assert `_bad' == 0
}
if _rc == 0 {
    display as result "  PASS 9: regtab footnote + stars legend join without '.;'"
    local ++pass_count
}
else {
    display as error "  FAIL 9: footnote punctuation join (rc=`=_rc')"
    local ++fail_count
}

**# 10. diagtab cutoff labels use one precision and a leading zero
* 1.10.1 formatted each cutoff independently with %9.0g, giving ".3", ".32".

local ++test_count
capture noisily {
    tempname frd
    webuse cattaneo2, clear
    gen byte gold = lbweight
    diagtab bweight gold, cutoffs(.3 .32 .34) frame(`frd')
    frame `frd' {
        quietly count if strtrim(c1) == "Cutoff >= 0.30"
        assert r(N) == 1
        quietly count if strtrim(c1) == "Cutoff >= 0.32"
        assert r(N) == 1
        quietly count if strpos(c1, "Cutoff >= .") > 0
        assert r(N) == 0
    }
    capture frame drop `frd'
}
if _rc == 0 {
    display as result "  PASS 10: diagtab cutoff labels carry a leading zero at uniform precision"
    local ++pass_count
}
else {
    display as error "  FAIL 10: diagtab cutoff labels (rc=`=_rc')"
    local ++fail_count
}

**# 11. corrtab never renders a formatted negative zero

local ++test_count
capture noisily {
    * Deterministic fixture: b is symmetric about a's midpoint (which gives an
    * exactly zero cross-product) with the last value nudged down by 0.005, so
    * corr(a,b) is about -0.00085 -- negative, and zero at two decimals.
    clear
    input double a double b
    1 4
    2 5
    3 6
    4 7
    5 7
    6 6
    7 5
    8 3.995
    end
    quietly pwcorr a b
    assert r(C)[2,1] < 0
    assert abs(r(C)[2,1]) < 0.005
    tempname frnz
    corrtab a b, digits(2) frame(`frnz')
    frame `frnz' {
        quietly ds
        foreach v of varlist `r(varlist)' {
            capture confirm string variable `v'
            if !_rc {
                quietly count if regexm(strtrim(`v'), "^-0\.0+($|[^1-9])")
                assert r(N) == 0
            }
        }
    }
    capture frame drop `frnz'
}
if _rc == 0 {
    display as result "  PASS 11: corrtab normalizes formatted negative zero"
    local ++pass_count
}
else {
    display as error "  FAIL 11: negative zero normalization (rc=`=_rc')"
    local ++fail_count
}

**# 12. stratetab uses the suite-wide ", " CI separator
* hrcomptab places these rate CIs beside comma-separated model CIs.

local ++test_count
capture noisily {
    * stratetab takes the output() stem; outcomes(1) means one <stem>.dta file.
    local strate_stem "`outdir'/_ir_strate"
    capture erase "`strate_stem'.dta"
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    quietly strate drug, output("`strate_stem'", replace)
    tempname frst
    stratetab, using("`strate_stem'") outcomes(1) frame(`frst')
    frame `frst' {
        local _hyphen = 0
        local _comma = 0
        quietly ds
        foreach v of varlist `r(varlist)' {
            capture confirm string variable `v'
            if !_rc {
                quietly count if regexm(`v', "\([0-9.]+-[0-9.]+\)")
                if r(N) > 0 local _hyphen = 1
                quietly count if regexm(`v', "\([0-9.]+, [0-9.]+\)")
                if r(N) > 0 local _comma = 1
            }
        }
        assert `_hyphen' == 0
        assert `_comma' == 1
    }
    capture frame drop `frst'
}
if _rc == 0 {
    display as result "  PASS 12: stratetab rate CIs use the suite-wide ', ' separator"
    local ++pass_count
}
else {
    display as error "  FAIL 12: stratetab CI separator (rc=`=_rc')"
    local ++fail_count
}

**# 13. table1_tc emits no internal data-transformation chatter
* 1.10.1 printed "(1 real change made)", "variable pvalue was str5 now str7"
* and missing-value notes above the table.

local ++test_count
capture noisily {
    tempfile chatterlog
    capture log close _irchat
    log using "`chatterlog'", replace text name(_irchat) nomsg
    sysuse auto, clear
    table1_tc price mpg, by(foreign) clear
    log close _irchat

    local _chatter = 0
    tempname lfh
    file open `lfh' using "`chatterlog'", read text
    file read `lfh' _line
    while r(eof) == 0 {
        if strpos(`"`macval(_line)'"', "real change") > 0 local _chatter = 1
        if strpos(`"`macval(_line)'"', "real changes") > 0 local _chatter = 1
        if regexm(`"`macval(_line)'"', "^variable .* was str[0-9]+ now str[0-9]+") ///
            local _chatter = 1
        if strpos(`"`macval(_line)'"', "missing values generated") > 0 local _chatter = 1
        file read `lfh' _line
    }
    file close `lfh'
    assert `_chatter' == 0
}
if _rc == 0 {
    display as result "  PASS 13: table1_tc produces no internal data-transformation chatter"
    local ++pass_count
}
else {
    display as error "  FAIL 13: console chatter (rc=`=_rc')"
    local ++fail_count
}

**# 14. table1_tc percent-only weighted cells carry no trailing space
* The cell was always built as "<a> " + "<b>", so an empty second component
* left a literal trailing blank ("60 ") in every flat sink.

local ++test_count
capture noisily {
    tempname frpc
    sysuse auto, clear
    table1_tc rep78 foreign, by(foreign) percent frame(`frpc') clear
    frame `frpc' {
        local _trail = 0
        quietly ds
        foreach v of varlist `r(varlist)' {
            capture confirm string variable `v'
            if !_rc {
                * strtrim(`v') != "": the label column's header cell is a single
                * deliberate space placeholder, not a padded data cell.
                quietly count if strtrim(`v') != "" & substr(`v', -1, 1) == " "
                if r(N) > 0 local _trail = 1
            }
        }
        assert `_trail' == 0
    }
    capture frame drop `frpc'
}
if _rc == 0 {
    display as result "  PASS 14: percent-only cells carry no trailing space"
    local ++pass_count
}
else {
    display as error "  FAIL 14: trailing whitespace in rendered cells (rc=`=_rc')"
    local ++fail_count
}

**# 15. regtab compact header carries no trailing space

local ++test_count
capture noisily {
    tempname frcp
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    regtab, compact frame(`frcp')
    frame `frcp' {
        local _trail = 0
        quietly ds
        foreach v of varlist `r(varlist)' {
            capture confirm string variable `v'
            if !_rc {
                quietly count if strtrim(`v') != "" & substr(`v', -1, 1) == " "
                if r(N) > 0 local _trail = 1
            }
        }
        assert `_trail' == 0
    }
    capture frame drop `frcp'
}
if _rc == 0 {
    display as result "  PASS 15: regtab compact header carries no trailing space"
    local ++pass_count
}
else {
    display as error "  FAIL 15: regtab compact header whitespace (rc=`=_rc')"
    local ++fail_count
}

**# Summary
local test_count = `pass_count' + `fail_count'
display as text ""
display "RESULT: test_issue_review_1_11_0 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _irchat
log close
if `fail_count' > 0 exit 9
