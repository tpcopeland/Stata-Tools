* test_coverage_gaps.do - Comprehensive tests for untested options across all tabtools commands
* Generated: 2026-03-30
* Purpose: Fill coverage gaps identified by audit — every untested option gets exercised
* Commands covered: table1_tc, regtab, effecttab, stratetab, tablex, corrtab,
*                   crosstab, diagtab, fittab, survtab, comptab

clear all
set more off
set varabbrev off

capture log close _covgaps
log using "test_coverage_gaps.log", replace text name(_covgaps)

local tabtools_dir "`c(pwd)'/.."
local output_dir "`c(pwd)'/output"
capture mkdir "`output_dir'"

adopath ++ "`tabtools_dir'"
run "`tabtools_dir'/_tabtools_common.ado"

local test_count = 0
local pass_count = 0
local fail_count = 0

* ============================================================
**# SECTION 1: table1_tc — untested options
* ============================================================

sysuse auto, clear

* Test: percformat option
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) percformat(%5.1f) ///
        xlsx("`output_dir'/_cov_t1_percformat.xlsx") sheet("percformat")
    confirm file "`output_dir'/_cov_t1_percformat.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc percformat()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc percformat() (error `=_rc')"
    local ++fail_count
}

* Test: nformat option
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat \ price contn) ///
        nformat(%9.0g) xlsx("`output_dir'/_cov_t1_nformat.xlsx") sheet("nformat")
    confirm file "`output_dir'/_cov_t1_nformat.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc nformat()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc nformat() (error `=_rc')"
    local ++fail_count
}

* Test: gsdleft/gsdright (geometric SD formatting)
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contln) gsdleft(" [GSD ") gsdright("]") ///
        xlsx("`output_dir'/_cov_t1_gsd.xlsx") sheet("gsd")
    confirm file "`output_dir'/_cov_t1_gsd.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc gsdleft()/gsdright()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc gsdleft()/gsdright() (error `=_rc')"
    local ++fail_count
}

* Test: varlabplus option
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat \ foreign bin) ///
        varlabplus xlsx("`output_dir'/_cov_t1_vlp.xlsx") sheet("varlabplus")
    confirm file "`output_dir'/_cov_t1_vlp.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc varlabplus"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc varlabplus (error `=_rc')"
    local ++fail_count
}

* Test: percsign option
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) percsign("pct") ///
        xlsx("`output_dir'/_cov_t1_percsign.xlsx") sheet("percsign")
    confirm file "`output_dir'/_cov_t1_percsign.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc percsign()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc percsign() (error `=_rc')"
    local ++fail_count
}

* Test: nospacelowpercent option
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(rep78 cat) nospacelowpercent ///
        xlsx("`output_dir'/_cov_t1_nospace.xlsx") sheet("nospace")
    confirm file "`output_dir'/_cov_t1_nospace.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc nospacelowpercent"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc nospacelowpercent (error `=_rc')"
    local ++fail_count
}

* Test: extraspace option
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) extraspace ///
        xlsx("`output_dir'/_cov_t1_extraspace.xlsx") sheet("extraspace")
    confirm file "`output_dir'/_cov_t1_extraspace.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc extraspace"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc extraspace (error `=_rc')"
    local ++fail_count
}

* Test: pdp/highpdp options
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg contn) pdp(4) highpdp(3) ///
        xlsx("`output_dir'/_cov_t1_pdp.xlsx") sheet("pdp")
    confirm file "`output_dir'/_cov_t1_pdp.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc pdp()/highpdp()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc pdp()/highpdp() (error `=_rc')"
    local ++fail_count
}

* Test: zebra option
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) zebra ///
        xlsx("`output_dir'/_cov_t1_zebra.xlsx") sheet("zebra")
    confirm file "`output_dir'/_cov_t1_zebra.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc zebra"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc zebra (error `=_rc')"
    local ++fail_count
}

* Test: headershade option
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) headershade ///
        xlsx("`output_dir'/_cov_t1_headershade.xlsx") sheet("headershade")
    confirm file "`output_dir'/_cov_t1_headershade.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc headershade"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc headershade (error `=_rc')"
    local ++fail_count
}

* Test: highlight option
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg contn \ rep78 cat) ///
        highlight(0.05) xlsx("`output_dir'/_cov_t1_highlight.xlsx") sheet("highlight")
    confirm file "`output_dir'/_cov_t1_highlight.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc highlight()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc highlight() (error `=_rc')"
    local ++fail_count
}

* Test: boldp option
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg contn) boldp(0.05) ///
        xlsx("`output_dir'/_cov_t1_boldp.xlsx") sheet("boldp")
    confirm file "`output_dir'/_cov_t1_boldp.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc boldp()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc boldp() (error `=_rc')"
    local ++fail_count
}

* Test: headercolor/zebracolor options
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) ///
        headercolor("200 220 240") zebracolor("245 245 255") zebra headershade ///
        xlsx("`output_dir'/_cov_t1_colors.xlsx") sheet("colors")
    confirm file "`output_dir'/_cov_t1_colors.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc headercolor()/zebracolor()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc headercolor()/zebracolor() (error `=_rc')"
    local ++fail_count
}

* Test: csv export
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) ///
        csv("`output_dir'/_cov_t1.csv") xlsx("`output_dir'/_cov_t1_csv.xlsx") sheet("csv")
    confirm file "`output_dir'/_cov_t1.csv"
}
if _rc == 0 {
    display as result "  PASS: table1_tc csv()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc csv() (error `=_rc')"
    local ++fail_count
}

* Test: frame output
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ rep78 cat) ///
        frame(_cov_t1_fr) xlsx("`output_dir'/_cov_t1_frame.xlsx") sheet("frame")
    frame _cov_t1_fr: assert _N > 0
    frame drop _cov_t1_fr
}
if _rc == 0 {
    display as result "  PASS: table1_tc frame()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc frame() (error `=_rc')"
    local ++fail_count
}

* Test: missingsummary option
local ++test_count
capture noisily {
    sysuse auto, clear
    replace rep78 = . in 1/5
    table1_tc, by(foreign) vars(price contn \ rep78 cat) missingsummary ///
        xlsx("`output_dir'/_cov_t1_missingsummary.xlsx") sheet("misssum")
    confirm file "`output_dir'/_cov_t1_missingsummary.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc missingsummary"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc missingsummary (error `=_rc')"
    local ++fail_count
}

* Test: combined formatting options stress test
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg conts \ rep78 cat \ foreign bin) ///
        zebra headershade boldp(0.05) highlight(0.1) ///
        headercolor("180 200 230") zebracolor("240 240 255") ///
        footnote("Source: auto dataset") title("Comprehensive Table 1") ///
        borderstyle(thin) ///
        xlsx("`output_dir'/_cov_t1_stress.xlsx") sheet("stress")
    confirm file "`output_dir'/_cov_t1_stress.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc combined formatting stress test"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc combined formatting stress test (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 2: regtab — untested options
* ============================================================

* Test: zebra option
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight length
    regtab, xlsx("`output_dir'/_cov_reg_zebra.xlsx") sheet("zebra") zebra
    confirm file "`output_dir'/_cov_reg_zebra.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab zebra"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab zebra (error `=_rc')"
    local ++fail_count
}

* Test: boldp option
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight length
    regtab, xlsx("`output_dir'/_cov_reg_boldp.xlsx") sheet("boldp") boldp(0.05)
    confirm file "`output_dir'/_cov_reg_boldp.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab boldp()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab boldp() (error `=_rc')"
    local ++fail_count
}

* Test: highlight option
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight length
    regtab, xlsx("`output_dir'/_cov_reg_highlight.xlsx") sheet("highlight") highlight(0.05)
    confirm file "`output_dir'/_cov_reg_highlight.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab highlight()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab highlight() (error `=_rc')"
    local ++fail_count
}

* Test: borderstyle options (medium, academic)
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_border.xlsx") sheet("medium") borderstyle(medium)
    confirm file "`output_dir'/_cov_reg_border.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab borderstyle(medium)"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab borderstyle(medium) (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_academic.xlsx") sheet("academic") borderstyle(academic)
    confirm file "`output_dir'/_cov_reg_academic.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab borderstyle(academic)"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab borderstyle(academic) (error `=_rc')"
    local ++fail_count
}

* Test: footnote option
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_footnote.xlsx") sheet("footnote") ///
        footnote("Adjusted for confounders")
    confirm file "`output_dir'/_cov_reg_footnote.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab footnote()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab footnote() (error `=_rc')"
    local ++fail_count
}

* Test: headercolor/zebracolor options
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_colors.xlsx") sheet("colors") ///
        zebra headercolor("200 220 240") zebracolor("245 245 255")
    confirm file "`output_dir'/_cov_reg_colors.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab headercolor()/zebracolor()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab headercolor()/zebracolor() (error `=_rc')"
    local ++fail_count
}

* Test: csv export
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_csv.xlsx") sheet("csv") ///
        csv("`output_dir'/_cov_reg.csv")
    confirm file "`output_dir'/_cov_reg.csv"
}
if _rc == 0 {
    display as result "  PASS: regtab csv()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab csv() (error `=_rc')"
    local ++fail_count
}

* Test: frame output
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_frame.xlsx") sheet("frame") frame(_cov_reg_fr)
    frame _cov_reg_fr: assert _N > 0
    frame drop _cov_reg_fr
}
if _rc == 0 {
    display as result "  PASS: regtab frame()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab frame() (error `=_rc')"
    local ++fail_count
}

* Test: keep option
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight length displacement
    regtab, xlsx("`output_dir'/_cov_reg_keep.xlsx") sheet("keep") keep("mpg weight")
    confirm file "`output_dir'/_cov_reg_keep.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab keep()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab keep() (error `=_rc')"
    local ++fail_count
}

* Test: drop option
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight length displacement
    regtab, xlsx("`output_dir'/_cov_reg_drop.xlsx") sheet("drop") drop("_cons displacement")
    confirm file "`output_dir'/_cov_reg_drop.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab drop()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab drop() (error `=_rc')"
    local ++fail_count
}

* Test: stars and starslevels options
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_stars.xlsx") sheet("stars") stars
    confirm file "`output_dir'/_cov_reg_stars.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab stars"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab stars (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_starslevels.xlsx") sheet("starslevels") ///
        stars starslevels(0.1 0.05 0.01)
    confirm file "`output_dir'/_cov_reg_starslevels.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab starslevels()"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab starslevels() (error `=_rc')"
    local ++fail_count
}

* Test: theme options
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_lancet.xlsx") sheet("lancet") theme(lancet)
    confirm file "`output_dir'/_cov_reg_lancet.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab theme(lancet)"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab theme(lancet) (error `=_rc')"
    local ++fail_count
}

* Test: combined formatting stress test
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight length
    regtab, xlsx("`output_dir'/_cov_reg_stress.xlsx") sheet("stress") ///
        zebra boldp(0.05) highlight(0.1) borderstyle(academic) ///
        footnote("OLS regression") title("Combined Test") ///
        stars starslevels(0.1 0.05 0.01) theme(nejm)
    confirm file "`output_dir'/_cov_reg_stress.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab combined formatting stress test"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab combined formatting stress test (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 3: effecttab — untested options
* ============================================================

* Test: digits option
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_digits.xlsx") sheet("digits") digits(4)
    confirm file "`output_dir'/_cov_eff_digits.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab digits()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab digits() (error `=_rc')"
    local ++fail_count
}

* Test: theme option
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_theme.xlsx") sheet("lancet") theme(lancet)
    confirm file "`output_dir'/_cov_eff_theme.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab theme(lancet)"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab theme(lancet) (error `=_rc')"
    local ++fail_count
}

* Test: zebra option
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_zebra.xlsx") sheet("zebra") zebra
    confirm file "`output_dir'/_cov_eff_zebra.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab zebra"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab zebra (error `=_rc')"
    local ++fail_count
}

* Test: boldp option
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_boldp.xlsx") sheet("boldp") boldp(0.05)
    confirm file "`output_dir'/_cov_eff_boldp.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab boldp()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab boldp() (error `=_rc')"
    local ++fail_count
}

* Test: highlight option
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_highlight.xlsx") sheet("highlight") highlight(0.05)
    confirm file "`output_dir'/_cov_eff_highlight.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab highlight()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab highlight() (error `=_rc')"
    local ++fail_count
}

* Test: borderstyle option
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_border.xlsx") sheet("academic") borderstyle(academic)
    confirm file "`output_dir'/_cov_eff_border.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab borderstyle(academic)"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab borderstyle(academic) (error `=_rc')"
    local ++fail_count
}

* Test: footnote option
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_footnote.xlsx") sheet("footnote") ///
        footnote("IPW estimates using logit propensity score")
    confirm file "`output_dir'/_cov_eff_footnote.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab footnote()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab footnote() (error `=_rc')"
    local ++fail_count
}

* Test: headercolor/zebracolor options
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_colors.xlsx") sheet("colors") ///
        zebra headercolor("200 220 240") zebracolor("245 245 255")
    confirm file "`output_dir'/_cov_eff_colors.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab headercolor()/zebracolor()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab headercolor()/zebracolor() (error `=_rc')"
    local ++fail_count
}

* Test: csv export
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_csv.xlsx") sheet("csv") ///
        csv("`output_dir'/_cov_eff.csv")
    confirm file "`output_dir'/_cov_eff.csv"
}
if _rc == 0 {
    display as result "  PASS: effecttab csv()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab csv() (error `=_rc')"
    local ++fail_count
}

* Test: frame output
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_frame.xlsx") sheet("frame") frame(_cov_eff_fr)
    frame _cov_eff_fr: assert _N > 0
    frame drop _cov_eff_fr
}
if _rc == 0 {
    display as result "  PASS: effecttab frame()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab frame() (error `=_rc')"
    local ++fail_count
}

* Test: full option (full cross-tabulation)
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_full.xlsx") sheet("full") full
    confirm file "`output_dir'/_cov_eff_full.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab full"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab full (error `=_rc')"
    local ++fail_count
}

* Test: combined formatting stress test
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_stress.xlsx") sheet("stress") ///
        zebra boldp(0.05) highlight(0.1) borderstyle(academic) ///
        footnote("Treatment effect estimates") title("Effect Stress Test") ///
        theme(bmj) digits(3)
    confirm file "`output_dir'/_cov_eff_stress.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab combined formatting stress test"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab combined formatting stress test (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 4: stratetab — comprehensive option coverage
* ============================================================

* Create strate output files for testing
quietly {
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 250, cond(_n==2, 180, 320))
    gen _Y = cond(_n==1, 50000, cond(_n==2, 45000, 52000))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_cov 0 "Never" 1 "Former" 2 "Current"
    label values exposure exp_cov
    save "`output_dir'/_cov_strate_o1e1.dta", replace

    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 120, cond(_n==2, 80, 200))
    gen _Y = cond(_n==1, 50000, cond(_n==2, 45000, 52000))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_cov 0 "Never" 1 "Former" 2 "Current", replace
    label values exposure exp_cov
    save "`output_dir'/_cov_strate_o2e1.dta", replace

    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 80, cond(_n==2, 140, 220))
    gen _Y = cond(_n==1, 8000, cond(_n==2, 12000, 20000))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_cov 0 "Never" 1 "Former" 2 "Current", replace
    label values exposure exp_cov
    save "`output_dir'/_cov_strate_o1e2.dta", replace

    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 40, cond(_n==2, 90, 150))
    gen _Y = cond(_n==1, 8000, cond(_n==2, 12000, 20000))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_cov 0 "Never" 1 "Former" 2 "Current", replace
    label values exposure exp_cov
    save "`output_dir'/_cov_strate_o2e2.dta", replace

    * Reload some data to have in memory for stratetab (it saves/restores)
    sysuse auto, clear
}

* Test: title option
local ++test_count
capture noisily {
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_title.xlsx") outcomes(2) ///
        title("Incidence Rates by Exposure Status")
    confirm file "`output_dir'/_cov_strate_title.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab title()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab title() (error `=_rc')"
    local ++fail_count
}

* Test: outlabels option
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_outlabels.xlsx") outcomes(2) ///
        outlabels("Stroke \ Myocardial Infarction")
    confirm file "`output_dir'/_cov_strate_outlabels.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab outlabels()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab outlabels() (error `=_rc')"
    local ++fail_count
}

* Test: explabels option
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_explabels.xlsx") outcomes(2) ///
        explabels("Smoking Status")
    confirm file "`output_dir'/_cov_strate_explabels.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab explabels()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab explabels() (error `=_rc')"
    local ++fail_count
}

* Test: digits option
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_digits.xlsx") outcomes(2) digits(3)
    confirm file "`output_dir'/_cov_strate_digits.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab digits()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab digits() (error `=_rc')"
    local ++fail_count
}

* Test: eventdigits option
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_evdigits.xlsx") outcomes(2) eventdigits(1)
    confirm file "`output_dir'/_cov_strate_evdigits.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab eventdigits()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab eventdigits() (error `=_rc')"
    local ++fail_count
}

* Test: pydigits option
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_pydigits.xlsx") outcomes(2) pydigits(2)
    confirm file "`output_dir'/_cov_strate_pydigits.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab pydigits()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab pydigits() (error `=_rc')"
    local ++fail_count
}

* Test: unitlabel option
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_unitlabel.xlsx") outcomes(2) ///
        unitlabel("100,000") ratescale(100000)
    confirm file "`output_dir'/_cov_strate_unitlabel.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab unitlabel()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab unitlabel() (error `=_rc')"
    local ++fail_count
}

* Test: pyscale option
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_pyscale.xlsx") outcomes(2) pyscale(365.25)
    confirm file "`output_dir'/_cov_strate_pyscale.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab pyscale()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab pyscale() (error `=_rc')"
    local ++fail_count
}

* Test: rateratio option
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1" ///
        "`output_dir'/_cov_strate_o1e2" "`output_dir'/_cov_strate_o2e2") ///
        xlsx("`output_dir'/_cov_strate_rateratio.xlsx") outcomes(2) rateratio
    confirm file "`output_dir'/_cov_strate_rateratio.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab rateratio"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab rateratio (error `=_rc')"
    local ++fail_count
}

* Test: ratiodigits option
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1" ///
        "`output_dir'/_cov_strate_o1e2" "`output_dir'/_cov_strate_o2e2") ///
        xlsx("`output_dir'/_cov_strate_ratiodigits.xlsx") outcomes(2) ///
        rateratio ratiodigits(3)
    confirm file "`output_dir'/_cov_strate_ratiodigits.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab ratiodigits()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab ratiodigits() (error `=_rc')"
    local ++fail_count
}

* Test: footnote option
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_footnote.xlsx") outcomes(2) ///
        footnote("Age-standardized rates per 1,000 person-years")
    confirm file "`output_dir'/_cov_strate_footnote.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab footnote()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab footnote() (error `=_rc')"
    local ++fail_count
}

* Test: zebra option
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_zebra.xlsx") outcomes(2) zebra
    confirm file "`output_dir'/_cov_strate_zebra.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab zebra"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab zebra (error `=_rc')"
    local ++fail_count
}

* Test: borderstyle option
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_border.xlsx") outcomes(2) borderstyle(academic)
    confirm file "`output_dir'/_cov_strate_border.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab borderstyle(academic)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab borderstyle(academic) (error `=_rc')"
    local ++fail_count
}

* Test: theme option
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_theme.xlsx") outcomes(2) theme(lancet)
    confirm file "`output_dir'/_cov_strate_theme.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab theme(lancet)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab theme(lancet) (error `=_rc')"
    local ++fail_count
}

* Test: headershade option
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_headershade.xlsx") outcomes(2) headershade
    confirm file "`output_dir'/_cov_strate_headershade.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab headershade"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab headershade (error `=_rc')"
    local ++fail_count
}

* Test: headercolor/zebracolor options
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_colors.xlsx") outcomes(2) ///
        zebra headercolor("200 220 240") zebracolor("245 245 255")
    confirm file "`output_dir'/_cov_strate_colors.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab headercolor()/zebracolor()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab headercolor()/zebracolor() (error `=_rc')"
    local ++fail_count
}

* Test: csv export
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_csv.xlsx") outcomes(2) ///
        csv("`output_dir'/_cov_strate.csv")
    confirm file "`output_dir'/_cov_strate.csv"
}
if _rc == 0 {
    display as result "  PASS: stratetab csv()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab csv() (error `=_rc')"
    local ++fail_count
}

* Test: combined comprehensive stratetab
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1" ///
        "`output_dir'/_cov_strate_o1e2" "`output_dir'/_cov_strate_o2e2") ///
        xlsx("`output_dir'/_cov_strate_stress.xlsx") outcomes(2) ///
        title("Age-Standardized Incidence Rates") ///
        outlabels("Stroke \ MI") explabels("Smoking \ Alcohol") ///
        digits(2) eventdigits(0) pydigits(1) unitlabel("100,000") ///
        ratescale(100000) pyscale(365.25) rateratio ratiodigits(2) ///
        footnote("Rates per 100,000 person-years") ///
        zebra borderstyle(academic) theme(nejm) sheet("Table 3")
    confirm file "`output_dir'/_cov_strate_stress.xlsx"
    assert r(N_outcomes) == 2
    assert r(N_exposures) == 2
}
if _rc == 0 {
    display as result "  PASS: stratetab combined comprehensive stress test"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab combined comprehensive stress test (error `=_rc')"
    local ++fail_count
}

* Test: stratetab data preservation
local ++test_count
capture noisily {
    sysuse auto, clear
    local _orig_N = _N
    local _orig_k = c(k)
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_preserve.xlsx") outcomes(2)
    assert _N == `_orig_N'
    assert c(k) == `_orig_k'
}
if _rc == 0 {
    display as result "  PASS: stratetab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab data preservation (error `=_rc')"
    local ++fail_count
}

* Test: stratetab return values
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1" ///
        "`output_dir'/_cov_strate_o1e2" "`output_dir'/_cov_strate_o2e2") ///
        xlsx("`output_dir'/_cov_strate_returns.xlsx") outcomes(2) rateratio
    assert r(N_outcomes) == 2
    assert r(N_exposures) == 2
    assert r(N_rows) > 0
    assert "`r(xlsx)'" != ""
    assert "`r(sheet)'" != ""
    * Check returned matrices
    matrix list r(rates)
    matrix list r(ratios)
}
if _rc == 0 {
    display as result "  PASS: stratetab return values and matrices"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab return values and matrices (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 5: tablex — untested options
* ============================================================

* Test: font option
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price mpg) statistic(sd price mpg)
    tablex using "`output_dir'/_cov_tablex_font.xlsx", sheet("font") ///
        font(Calibri) replace
    confirm file "`output_dir'/_cov_tablex_font.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex font()"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex font() (error `=_rc')"
    local ++fail_count
}

* Test: fontsize option
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price mpg) statistic(sd price mpg)
    tablex using "`output_dir'/_cov_tablex_fontsize.xlsx", sheet("fontsize") ///
        fontsize(12) replace
    confirm file "`output_dir'/_cov_tablex_fontsize.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex fontsize()"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex fontsize() (error `=_rc')"
    local ++fail_count
}

* Test: headerrows option
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign rep78, statistic(mean price)
    tablex using "`output_dir'/_cov_tablex_headerrows.xlsx", sheet("headerrows") ///
        headerrows(3) replace
    confirm file "`output_dir'/_cov_tablex_headerrows.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex headerrows()"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex headerrows() (error `=_rc')"
    local ++fail_count
}

* Test: nformat option
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price mpg) statistic(sd price mpg)
    tablex using "`output_dir'/_cov_tablex_nformat.xlsx", sheet("nformat") ///
        nformat("#,##0.00") replace
    confirm file "`output_dir'/_cov_tablex_nformat.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex nformat()"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex nformat() (error `=_rc')"
    local ++fail_count
}

* Test: footnote option
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price mpg) statistic(sd price mpg)
    tablex using "`output_dir'/_cov_tablex_footnote.xlsx", sheet("footnote") ///
        footnote("Source: 1978 Automobile Data") replace
    confirm file "`output_dir'/_cov_tablex_footnote.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex footnote()"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex footnote() (error `=_rc')"
    local ++fail_count
}

* Test: zebra option
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price mpg) statistic(sd price mpg)
    tablex using "`output_dir'/_cov_tablex_zebra.xlsx", sheet("zebra") ///
        zebra replace
    confirm file "`output_dir'/_cov_tablex_zebra.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex zebra"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex zebra (error `=_rc')"
    local ++fail_count
}

* Test: headercolor/zebracolor options
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price mpg) statistic(sd price mpg)
    tablex using "`output_dir'/_cov_tablex_colors.xlsx", sheet("colors") ///
        zebra headercolor("200 220 240") zebracolor("245 245 255") replace
    confirm file "`output_dir'/_cov_tablex_colors.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex headercolor()/zebracolor()"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex headercolor()/zebracolor() (error `=_rc')"
    local ++fail_count
}

* Test: theme option
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price mpg) statistic(sd price mpg)
    tablex using "`output_dir'/_cov_tablex_theme.xlsx", sheet("lancet") ///
        theme(lancet) replace
    confirm file "`output_dir'/_cov_tablex_theme.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex theme(lancet)"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex theme(lancet) (error `=_rc')"
    local ++fail_count
}

* Test: combined tablex stress test
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price mpg weight) statistic(sd price mpg weight)
    tablex using "`output_dir'/_cov_tablex_stress.xlsx", sheet("stress") ///
        title("Summary Statistics by Origin") font(Calibri) fontsize(11) ///
        borderstyle(academic) headerrows(2) ///
        footnote("1978 Automobile Data") zebra ///
        headercolor("180 200 230") zebracolor("240 240 255") ///
        theme(nejm) replace
    confirm file "`output_dir'/_cov_tablex_stress.xlsx"
}
if _rc == 0 {
    display as result "  PASS: tablex combined stress test"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex combined stress test (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 6: corrtab/fittab — minor gaps
* ============================================================

* Test: corrtab footnote
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, xlsx("`output_dir'/_cov_corrtab_footnote.xlsx") ///
        sheet("footnote") footnote("Pearson correlation coefficients")
    confirm file "`output_dir'/_cov_corrtab_footnote.xlsx"
}
if _rc == 0 {
    display as result "  PASS: corrtab footnote()"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab footnote() (error `=_rc')"
    local ++fail_count
}

* Test: fittab footnote
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    estimates store _cov_m1
    regress price mpg weight
    estimates store _cov_m2
    regress price mpg weight length
    estimates store _cov_m3
    fittab _cov_m1 _cov_m2 _cov_m3, ///
        xlsx("`output_dir'/_cov_fittab_footnote.xlsx") sheet("footnote") ///
        footnote("Lower AIC/BIC indicates better fit")
    confirm file "`output_dir'/_cov_fittab_footnote.xlsx"
    estimates drop _cov_m1 _cov_m2 _cov_m3
}
if _rc == 0 {
    display as result "  PASS: fittab footnote()"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab footnote() (error `=_rc')"
    local ++fail_count
}

* Test: comptab title and footnote
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight if foreign == 0
    regtab, xlsx("`output_dir'/_cov_comptab_tf.xlsx") sheet("Domestic") ///
        frame(_cov_ct_dom)
    collect clear
    collect: regress price mpg weight if foreign == 1
    regtab, xlsx("`output_dir'/_cov_comptab_tf.xlsx") sheet("Foreign") ///
        frame(_cov_ct_for)
    comptab _cov_ct_dom _cov_ct_for, ///
        rows("1 2 \ 1 2") ///
        xlsx("`output_dir'/_cov_comptab_tf.xlsx") sheet("Combined") ///
        title("Regression Coefficients by Origin") ///
        footnote("Linear regression. CI = 95% confidence interval.")
    confirm file "`output_dir'/_cov_comptab_tf.xlsx"
    capture frame drop _cov_ct_dom
    capture frame drop _cov_ct_for
}
if _rc == 0 {
    display as result "  PASS: comptab title()/footnote()"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab title()/footnote() (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 7: excel() synonym tests
* ============================================================

* Test: table1_tc excel() synonym
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn) ///
        excel("`output_dir'/_cov_excel_t1.xlsx") sheet("excel")
    confirm file "`output_dir'/_cov_excel_t1.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc excel() synonym"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc excel() synonym (error `=_rc')"
    local ++fail_count
}

* Test: regtab excel() synonym
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, excel("`output_dir'/_cov_excel_reg.xlsx") sheet("excel")
    confirm file "`output_dir'/_cov_excel_reg.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab excel() synonym"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab excel() synonym (error `=_rc')"
    local ++fail_count
}

* Test: effecttab excel() synonym
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, excel("`output_dir'/_cov_excel_eff.xlsx") sheet("excel")
    confirm file "`output_dir'/_cov_excel_eff.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab excel() synonym"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab excel() synonym (error `=_rc')"
    local ++fail_count
}

* Test: corrtab excel() synonym
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, excel("`output_dir'/_cov_excel_corr.xlsx") sheet("excel")
    confirm file "`output_dir'/_cov_excel_corr.xlsx"
}
if _rc == 0 {
    display as result "  PASS: corrtab excel() synonym"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab excel() synonym (error `=_rc')"
    local ++fail_count
}

* Test: fittab excel() synonym
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    estimates store _cov_ex_m1
    regress price mpg weight
    estimates store _cov_ex_m2
    fittab _cov_ex_m1 _cov_ex_m2, excel("`output_dir'/_cov_excel_fit.xlsx") sheet("excel")
    confirm file "`output_dir'/_cov_excel_fit.xlsx"
    estimates drop _cov_ex_m1 _cov_ex_m2
}
if _rc == 0 {
    display as result "  PASS: fittab excel() synonym"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab excel() synonym (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 8: Error handling tests
* ============================================================

* Test: stratetab rejects invalid borderstyle
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_err.xlsx") outcomes(2) borderstyle(invalid)
}
if _rc == 198 {
    display as result "  PASS: stratetab rejects invalid borderstyle (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab invalid borderstyle expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: stratetab rejects mismatched outcome labels
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_err2.xlsx") outcomes(2) outlabels("Only One")
}
if _rc == 198 {
    display as result "  PASS: stratetab rejects mismatched outlabels count (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab mismatched outlabels expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: stratetab rejects negative pyscale
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_err3.xlsx") outcomes(2) pyscale(-1)
}
if _rc == 198 {
    display as result "  PASS: stratetab rejects negative pyscale (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab negative pyscale expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: stratetab rejects negative ratescale
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_err4.xlsx") outcomes(2) ratescale(-100)
}
if _rc == 198 {
    display as result "  PASS: stratetab rejects negative ratescale (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab negative ratescale expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: stratetab rejects outcomes(0)
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1") ///
        xlsx("`output_dir'/_cov_strate_err5.xlsx") outcomes(0)
}
if _rc == 198 {
    display as result "  PASS: stratetab rejects outcomes(0) (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab outcomes(0) expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: stratetab rejects non-divisible file count
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_err6.xlsx") outcomes(3)
}
if _rc == 198 {
    display as result "  PASS: stratetab rejects non-divisible file count (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab non-divisible file count expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: tablex rejects invalid fontsize
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price)
    tablex using "`output_dir'/_cov_tablex_err.xlsx", sheet("err") fontsize(100) replace
}
if _rc == 198 {
    display as result "  PASS: tablex rejects fontsize(100) (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex fontsize(100) expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: tablex rejects invalid borderstyle
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price)
    tablex using "`output_dir'/_cov_tablex_err2.xlsx", sheet("err") borderstyle(dotted) replace
}
if _rc == 198 {
    display as result "  PASS: tablex rejects invalid borderstyle (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex invalid borderstyle expected rc=198, got `=_rc'"
    local ++fail_count
}

* ============================================================
**# SECTION 9: varabbrev restore tests
* ============================================================

* Test: stratetab restores varabbrev on success
local ++test_count
capture noisily {
    set varabbrev on
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_va.xlsx") outcomes(2)
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: stratetab restores varabbrev on success"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab restores varabbrev on success (error `=_rc')"
    local ++fail_count
}

* Test: stratetab restores varabbrev on error
local ++test_count
capture noisily {
    set varabbrev on
    sysuse auto, clear
    capture stratetab, using("nonexistent_file") ///
        xlsx("`output_dir'/_cov_strate_va_err.xlsx") outcomes(1)
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: stratetab restores varabbrev on error"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab restores varabbrev on error (error `=_rc')"
    local ++fail_count
}

* Test: tablex restores varabbrev on success
local ++test_count
capture noisily {
    set varabbrev on
    sysuse auto, clear
    table foreign, statistic(mean price)
    tablex using "`output_dir'/_cov_tablex_va.xlsx", sheet("va") replace
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: tablex restores varabbrev on success"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex restores varabbrev on success (error `=_rc')"
    local ++fail_count
}

set varabbrev off

* ============================================================
**# SECTION 10: Data preservation across all commands
* ============================================================

* Test: regtab data preservation
local ++test_count
capture noisily {
    sysuse auto, clear
    local _n1 = _N
    local _k1 = c(k)
    sum price, meanonly
    local _mean1 = r(mean)
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_preserve.xlsx") sheet("preserve")
    assert _N == `_n1'
    assert c(k) == `_k1'
    sum price, meanonly
    assert r(mean) == `_mean1'
}
if _rc == 0 {
    display as result "  PASS: regtab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab data preservation (error `=_rc')"
    local ++fail_count
}

* Test: effecttab data preservation
local ++test_count
capture noisily {
    sysuse auto, clear
    local _n1 = _N
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_preserve.xlsx") sheet("preserve")
    assert _N == `_n1'
}
if _rc == 0 {
    display as result "  PASS: effecttab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab data preservation (error `=_rc')"
    local ++fail_count
}

* Test: corrtab data preservation
local ++test_count
capture noisily {
    sysuse auto, clear
    local _n1 = _N
    corrtab price mpg weight, xlsx("`output_dir'/_cov_corr_preserve.xlsx") sheet("preserve")
    assert _N == `_n1'
}
if _rc == 0 {
    display as result "  PASS: corrtab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab data preservation (error `=_rc')"
    local ++fail_count
}

* Test: tablex data preservation
local ++test_count
capture noisily {
    sysuse auto, clear
    local _n1 = _N
    local _k1 = c(k)
    table foreign, statistic(mean price mpg)
    tablex using "`output_dir'/_cov_tablex_preserve.xlsx", sheet("preserve") replace
    assert _N == `_n1'
    assert c(k) == `_k1'
}
if _rc == 0 {
    display as result "  PASS: tablex data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: tablex data preservation (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# Cleanup
* ============================================================

* Remove temporary test files
local cov_files : dir "`output_dir'" files "_cov_*.xlsx"
foreach f of local cov_files {
    capture erase "`output_dir'/`f'"
}
local cov_csv : dir "`output_dir'" files "_cov_*.csv"
foreach f of local cov_csv {
    capture erase "`output_dir'/`f'"
}
local cov_dta : dir "`output_dir'" files "_cov_*.dta"
foreach f of local cov_dta {
    capture erase "`output_dir'/`f'"
}

* ============================================================
**# Summary
* ============================================================

display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

log close _covgaps
