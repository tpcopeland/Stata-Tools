*! test_review_2026_10_01_statistics.do  2026/10/01
*! Regression: stable Cochran scores and opaque stratetab text
*! Author: Timothy P Copeland, Karolinska Institutet
* Oracle: SAS PROC FREQ Cochran-Armitage formula, fetched 2026-10-01:
* https://support.sas.com/documentation/cdl/en/procstat/66703/HTML/default/procstat_freq_details68.htm
* For counts (9,5,1)/(1,5,9) at scores (0,2,4): T=16,
* variance=.5*.5*(10*4+10*0+10*4)=20, hence z=16/sqrt(20).
* The prior code gave z=4.5254833995939041 after adding 1e16,
* rather than 3.577708763999663. Literal $globals in labels also expanded.

version 17.0
clear all
set more off
capture log close _all
log using "test_review_2026_10_01_statistics.log", replace text name(_stats_review)
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
adopath ++ "`pkg_dir'"
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local od "`output_dir'/statistics_20261001"
capture mkdir "`od'"
do "`qa_dir'/_qa_hostile.do"
do "`qa_dir'/_qa_parity.do"
do "`qa_dir'/_qa_state.do"
local pass_count 0
local fail_count 0

**# S1 score translation, sign, scale, frequency weights and ordering
capture noisily {
    clear
    input byte y double x int w
    0 0 9
    1 0 1
    0 2 5
    1 2 5
    0 4 1
    1 4 9
    end
    tempname wantz wantp
    scalar `wantz' = 16/sqrt(20)
    scalar `wantp' = 2*normal(-scalar(`wantz'))
    crosstab y x [fw=w], cochran
    qa_assert_equal r(z_trend) scalar(`wantz'), property(CA known answer) tol(1e-12)
    crosstab y x [fw=w], cochran
    qa_assert_equal r(p_trend) scalar(`wantp'), property(CA known p) tol(1e-12)
    qa_shift_invariance x, command("crosstab y x [fw=w], cochran") ///
        returns(r(z_trend) r(chi2_trend) r(p_trend)) shift(1e16) tol(1e-12)
    qa_shift_invariance x, command("crosstab y x [fw=w], cochran") ///
        returns(r(z_trend) r(chi2_trend) r(p_trend)) shift(-1e16) tol(1e-12)
    foreach scale in 1e150 1e-150 -1e150 -1e-150 {
        tempvar scaled
        generate double `scaled' = x*`scale'
        crosstab y `scaled' [fw=w], cochran
        qa_assert_equal r(z_trend) (sign(`scale')*scalar(`wantz')), ///
            property(CA scale and direction) tol(1e-12)
        crosstab y `scaled' [fw=w], cochran
        qa_assert_equal r(p_trend) scalar(`wantp'), property(CA scale p) tol(1e-12)
        drop `scaled'
    }
    tempvar extreme
    generate double `extreme' = (x-2)*4e307
    assert !missing(`extreme')
    crosstab y `extreme' [fw=w], cochran
    qa_assert_equal r(z_trend) scalar(`wantz'), property(CA opposite extreme scores) tol(1e-12)
    generate float fractional = x/8 + .125
    crosstab y fractional [fw=w], cochran
    qa_assert_equal r(z_trend) scalar(`wantz'), property(CA fractional scores) tol(1e-12)
    expand w
    gsort -y -x
    crosstab y x, cochran
    qa_assert_equal r(z_trend) scalar(`wantz'), property(CA replication and ordering) tol(1e-12)
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS S1: Cochran translation/sign/scale/weights/order"
}
else {
    local ++fail_count
    display as error "FAIL S1: Cochran invariance (rc=`=_rc')"
}

**# Source fixture with independently specified incidence rates
clear
input byte category double(_D _Y _Rate _Lower _Upper)
1 10 100 .1 .05 .2
2 20 100 .2 .1 .3
end
label var _Lower "95% lower"
label var _Upper "95% upper"
save "`od'/rates.dta", replace
global TT_STATS_FIXTURE "`od'/rates"
global QA_HS_GLB "EXPANDED"
mata: st_local("literal", "Dollar " + char(36) + "QA_HS_GLB")

**# S2 literal outcome/exposure labels propagate to every file and frame
capture noisily {
    use "`od'/rates.dta", clear
    stratetab, using("`od'/rates") outcomes(1) ///
        outlabels(`"`macval(literal)'"') explabels(`"`macval(literal)'"') ///
        title("Statistics") frame(tt_stats_labels) ///
        csv("`od'/labels.csv") markdown("`od'/labels.md") xlsx("`od'/labels.xlsx")
    mata: st_local("gotid", st_global("r(outcome_ids)"))
    mata: assert(st_local("gotid") == st_local("literal"))
    frame tt_stats_labels {
        mata: assert(st_sdata(2,"c2") == st_local("literal"))
        mata: assert(st_sdata(4,"c1") == st_local("literal"))
        mata: assert(st_global("_dta[tabtools_outcome_id_1]") == st_local("literal"))
    }
    qa_surface_parity, expect(100) frame(tt_stats_labels c4 5) ///
        xlsx("`od'/labels.xlsx" Results E5) name(unaffected incidence rate)
    preserve
    import excel "`od'/labels.xlsx", sheet("Results") clear allstring
    mata: assert(st_sdata(2,"C") == st_local("literal"))
    mata: assert(st_sdata(4,"B") == st_local("literal"))
    restore
    foreach ext in csv md {
        tempname fh
        file open `fh' using "`od'/labels.`ext'", read text
        local found 0
        file read `fh' line
        while r(eof) == 0 {
            * Markdown escapes underscores; compare the rendered text axis.
            if "`ext'" == "md" {
                local line : subinstr local line "\_" "_", all
            }
            mata: st_local("hit", strofreal(strpos(st_local("line"), st_local("literal")) > 0))
            if `hit' local ++found
            file read `fh' line
        }
        file close `fh'
        assert `found' >= 2
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS S2: literal labels, identities and file/frame surfaces"
}
else {
    local ++fail_count
    display as error "FAIL S2: opaque labels (rc=`=_rc')"
}
capture frame drop tt_stats_labels

**# S3 hostile labels and explicit outcome identities, within delimiter domain
capture noisily {
    use "`od'/rates.dta", clear
    qa_hostile_strings
    foreach key in QA_HS_TICKPAIR QA_HS_TICK QA_HS_DOLLAR QA_HS_APOS QA_HS_DQ QA_HS_COMMA QA_HS_UNICODE {
        mata: st_local("s", st_global("`key'"))
        stratetab, using("$TT_STATS_FIXTURE") outcomes(1) ///
            outlabels(`"`macval(s)'"') explabels(`"`macval(s)'"') ///
            outcomeids(`"`macval(s)'"') frame(tt_stats_hostile)
        mata: assert(st_global("r(outcome_ids)") == st_local("s"))
        frame tt_stats_hostile {
            mata: assert(st_sdata(2,"c2") == st_local("s"))
            mata: assert(st_sdata(4,"c1") == st_local("s"))
            mata: assert(st_global("_dta[tabtools_outcome_id_1]") == st_local("s"))
        }
        frame drop tt_stats_hostile
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS S3: hostile label and identity corpus"
}
else {
    local ++fail_count
    display as error "FAIL S3: hostile labels (rc=`=_rc')"
}
capture frame drop tt_stats_hostile

**# S4 unitlabel has no delimiter domain restriction: exercise full corpus
capture program drop _tt_stats_unitlabel
program define _tt_stats_unitlabel, rclass
    version 17.0
    local _vao = c(varabbrev)
    local _made 0
    tempname uf
    set varabbrev off
    capture noisily {
        args key
        mata: st_local("s", st_global(st_local("key")))
        stratetab, using("$TT_STATS_FIXTURE") outcomes(1) ///
            unitlabel(`"`macval(s)'"') frame(`uf')
        local _made 1
        frame `uf' {
            mata: st_local("got", substr(st_sdata(3,"c4"),5,strlen(st_sdata(3,"c4"))-4-strlen(" PY (95% CI)")))
        }
        mata: st_local("exact_label", strofreal(st_local("got") == st_local("s")))
        assert `exact_label' == 1
        return local text `"`macval(got)'"'
    }
    local rc = _rc
    if `_made' capture frame drop `uf'
    set varabbrev `_vao'
    if `rc' exit `rc'
end
capture noisily {
    use "`od'/rates.dta", clear
    qa_hostile_strings, check(_tt_stats_unitlabel) result(r(text))
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS S4: full hostile unitlabel corpus"
}
else {
    local ++fail_count
    display as error "FAIL S4: hostile unitlabel (rc=`=_rc')"
}
capture frame drop tt_stats_unit

**# S5 unsafe literal file paths are refused before expansion or writing
capture noisily {
    use "`od'/rates.dta", clear
    tempfile guardstem
    global TT_STATS_PATH "`guardstem'"
    foreach sink in xlsx excel csv markdown {
        local extension = cond(inlist("`sink'", "xlsx", "excel"), "xlsx", cond("`sink'" == "csv", "csv", "md"))
        mata: st_local("badpath", char(36) + "TT_STATS_PATH." + st_local("extension"))
        capture noisily stratetab, using("$TT_STATS_FIXTURE") outcomes(1) `sink'(`"`macval(badpath)'"')
        local rc = _rc
        display "Path refusal `sink': rc=`rc'"
        assert `rc' == 198
        capture confirm file "`guardstem'.`extension'"
        assert _rc == 601
        mata: assert(!fileexists(st_local("badpath")))
    }
    mata: st_local("badsource", char(36) + "TT_STATS_FIXTURE")
    qa_state_snapshot, tag(stats_bad_source)
    capture stratetab, using(`"`macval(badsource)'"') outcomes(1)
    local rc = _rc
    assert `rc' == 198
    qa_state_compare, tag(stats_bad_source)
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS S5: literal unsafe path refusal"
}
else {
    local ++fail_count
    display as error "FAIL S5: literal path guard (rc=`=_rc')"
}

**# S6 caller-state fingerprints on the fixed routes and early errors
capture noisily {
    clear
    input byte y double x int w
    0 0 9
    1 0 1
    0 2 5
    1 2 5
    0 4 1
    1 4 9
    end
    expand w
    gsort -x -y
    quietly regress y x
    matrix _ca_scale = (101,102)
    scalar _ca_mean = 103
    global TT_STATS_USER "user state"
    set varabbrev on
    * Warm native tabulate's own legacy globals before a bytewise snapshot.
    quietly crosstab y x, cochran
    qa_state_snapshot, tag(stats_ca)
    quietly crosstab y x, cochran
    qa_state_compare, tag(stats_ca)
    qa_state_snapshot, tag(stats_ca_err) rreturn
    capture crosstab y x, cochran level(101)
    local badrc = _rc
    assert `badrc' == 198
    qa_state_compare, tag(stats_ca_err)

    use "`od'/rates.dta", clear
    gsort -category
    quietly regress _D category
    set varabbrev on
    quietly stratetab, using("`od'/rates") outcomes(1) ///
        outlabels(`"`macval(literal)'"') explabels(`"`macval(literal)'"')
    qa_state_snapshot, tag(stats_rates)
    quietly stratetab, using("`od'/rates") outcomes(1) ///
        outlabels(`"`macval(literal)'"') explabels(`"`macval(literal)'"')
    qa_state_compare, tag(stats_rates)
    qa_state_snapshot, tag(stats_rates_err)
    capture stratetab, using("`od'/rates") outcomes(0)
    local badrc = _rc
    assert `badrc' == 198
    qa_state_compare, tag(stats_rates_err)
    set varabbrev off
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS S6: caller state on success and early-error routes"
}
else {
    local ++fail_count
    display as error "FAIL S6: caller fingerprints (rc=`=_rc')"
}

local tests = `pass_count' + `fail_count'
display as result "RESULT: test_review_2026_10_01_statistics tests=`tests' pass=`pass_count' fail=`fail_count' skip=0"
log close _stats_review
if `fail_count' exit 1
