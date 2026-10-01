*! test_review_2026_10_01_composition.do - Numeric composition identity regressions
*! Author: Timothy P Copeland, Karolinska Institutet
* Independent oracle: OLS estimates from the two collected models, plus exact
* row/model cardinality and literal string content (not rendered-cell inference).
* budget: under 30 seconds
version 17.0
clear all
set more off
capture log close _all
log using "test_review_2026_10_01_composition.log", text replace
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_hostile.do"
do "`qa_dir'/_qa_parity.do"
local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _c101_literal
program define _c101_literal, rclass
    version 17.0
    local old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args corpus_name
        frame c101_ea: mata: st_sstore(1, "label", st_global(st_local("corpus_name")))
        comptab c101_a, rows(1) eplotframe(c101_corpus, replace)
        frame c101_corpus: mata: st_local("payload", st_sdata(1, "label"))
        return local literal `"`macval(payload)'"'
    }
    local rc = _rc
    set varabbrev `old_varabbrev'
    if `rc' exit `rc'
end

**# Every regression runs on the original sources, even after a refusal
foreach scenario in reordered compact literal missing duplicate missingframe schema swapped framecase corpus compactsource twin nested ratepair heading {
    local ++test_count
    local fixture_preserved = 0
    capture noisily {
        foreach owned in c101_a c101_b c101_ea c101_eb c101_out c101_plot c101_factor c101_factor_ep c101_corpus c101_compact c101_compact_ep c101_rates F f P p {
            capture frame drop `owned'
        }
        sysuse auto, clear
        quietly regress price weight
        scalar oracle_small = _b[weight]
        quietly regress price weight mpg
        scalar oracle_large = _b[weight]
        scalar oracle_mpg = _b[mpg]
        collect clear
        collect: regress price weight
        collect: regress price weight mpg
        regtab, models("Small \ Large") frame(c101_a) eplotframe(c101_ea) noint
        collect clear
        collect: regress price weight mpg
        collect: regress price weight
        regtab, models("Large \ Small") frame(c101_b) eplotframe(c101_eb) noint
        if "`scenario'" == "reordered" | "`scenario'" == "compact" {
            local opt ""
            if "`scenario'" == "compact" local opt "compact"
            tempfile workbook csv_token
            local book "`workbook'.xlsx"
            local csv "`csv_token'.csv"
            qa_state_snapshot, tag(composition_ok) predict(xb)
            comptab c101_a c101_b, rows(1 \ 1) frame(c101_out) eplotframe(c101_plot) `opt' xlsx("`book'") csv("`csv'")
            qa_state_compare, tag(composition_ok) allow(r frame)
            qa_surface_parity, expect(oracle_small) name(aligned_small) ///
                frame(c101_plot estimate 3) xlsx("`book'" Composite C5) csv("`csv'" 4 2)
            if "`scenario'" == "reordered" {
                qa_surface_parity, expect(oracle_large) name(aligned_large) ///
                    frame(c101_plot estimate 4) xlsx("`book'" Composite F5) csv("`csv'" 4 5)
            }
            else {
                qa_surface_parity, expect(oracle_large) name(aligned_large) ///
                    frame(c101_plot estimate 4) xlsx("`book'" Composite E5) csv("`csv'" 4 4)
            }
            frame c101_plot {
                assert _N == 4
                assert !missing(estimate, scalar(oracle_small), scalar(oracle_large))
                assert reldif(estimate, scalar(oracle_small)) < 1e-14 if model == 1
                assert reldif(estimate, scalar(oracle_large)) < 1e-14 if model == 2
                assert model_label == "Small" if model == 1
                assert model_label == "Large" if model == 2
                isid source_frame source_row model
            }
            frame c101_out {
                assert substr(c1[4], 1, 4) == "2.04"
                assert c1[4] == c1[5]
            }
            frame c101_a: assert c1[2] == "Small" & c1[4] == "2.04"
            frame c101_b: assert c1[2] == "Large" & c1[4] == "1.75"
            frame c101_eb: assert model_label == "Large" if model == 1
            preserve
            local fixture_preserved = 1
            import excel "`book'", sheet("Composite") cellrange(B2) clear allstring
            assert C[3] == C[4]
            assert substr(C[3], 1, 4) == "2.04"
            if "`scenario'" == "reordered" assert F[3] == "1.75"
            else assert E[3] == E[4] & substr(E[3], 1, 4) == "1.75"
            restore
            local fixture_preserved = 0
            erase "`book'"
            erase "`csv'"
        }
        else if "`scenario'" == "literal" {
            frame c101_ea: replace label = char(96)+"literal"+char(39)+" $"+"dollar "+char(34)+"quoted"+char(34) in 1
            frame c101_ea: replace model_label = char(96)+"model"+char(39) in 1
            local section = char(96)+"section"+char(39)
            comptab c101_a, rows(1) eplotframe(c101_plot) section(`"`macval(section)'"')
            frame c101_plot {
                assert label[1] == char(96)+"section"+char(39)
                assert section[2] == char(96)+"section"+char(39)
                assert label[2] == char(96)+"literal"+char(39)+" $"+"dollar "+char(34)+"quoted"+char(34)
                assert model_label[2] == char(96)+"model"+char(39)
            }
        }
        else if inlist("`scenario'", "missing", "duplicate", "missingframe", "schema", "swapped") {
            if "`scenario'" == "missing" frame c101_ea: drop if source_row == 1 & model == 1
            else if "`scenario'" == "duplicate" frame c101_ea: expand 2 if source_row == 1 & model == 1
            else if "`scenario'" == "missingframe" frame drop c101_ea
            else if "`scenario'" == "schema" frame c101_ea: drop pvalue
            else frame c101_a: char _dta[tabtools_eplotframe] "c101_eb"
            qa_state_snapshot, tag(composition_bad) predict(xb)
            capture noisily comptab c101_a, rows(1) frame(c101_out) eplotframe(c101_plot)
            local refusal = _rc
            * A missing physical frame retains Stata's existing r(111) path;
            * malformed contents/provenance are explicitly refused with r(459).
            local expected_rc = cond("`scenario'" == "missingframe", 111, 459)
            assert `refusal' == `expected_rc'
            qa_state_compare, tag(composition_bad) allow(r)
            capture confirm frame c101_out
            assert _rc == 111
            capture confirm frame c101_plot
            assert _rc == 111
        }
        else if "`scenario'" == "framecase" {
            frame rename c101_a F
            frame rename c101_ea P
            frame F: char _dta[tabtools_eplotframe] "P"
            qa_state_snapshot, tag(composition_ok) predict(xb)
            comptab F, rows(1) frame(f) eplotframe(p)
            qa_state_compare, tag(composition_ok) allow(r frame)
            frame f: assert c1[4] == "2.04"
            frame p: assert _N == 2
            frame P: assert _N >= 2
            qa_state_snapshot, tag(composition_bad) predict(xb)
            capture noisily comptab F, rows(1) frame(F, replace)
            local refusal = _rc
            assert `refusal' == 198
            qa_state_compare, tag(composition_bad) allow(r)
        }
        else if "`scenario'" == "corpus" {
            qa_hostile_strings, check(_c101_literal) result(r(literal))
        }
        else if "`scenario'" == "compactsource" {
            collect clear
            collect: regress price weight
            regtab, compact frame(c101_compact) eplotframe(c101_compact_ep) noint
            frame c101_compact: replace c2 = "" in 4
            frame c101_compact_ep: drop if source_row == 1
            qa_state_snapshot, tag(composition_bad) predict(xb)
            capture noisily comptab c101_compact, rows(1) frame(c101_out) eplotframe(c101_plot)
            local refusal = _rc
            assert `refusal' == 459
            qa_state_compare, tag(composition_bad) allow(r)
            capture confirm frame c101_plot
            assert _rc == 111
        }
        else if "`scenario'" == "twin" {
            collect clear
            collect: regress price mpg
            regtab, frame(c101_a, replace) eplotframe(c101_ea, replace) noint
            scalar oracle_twin = _b[mpg]
            replace price = price * 2
            collect clear
            collect: regress price mpg
            regtab, frame(c101_b, replace) eplotframe(c101_eb, replace) noint
            frame c101_a: char _dta[tabtools_eplotframe] "c101_eb"
            qa_state_snapshot, tag(composition_bad) predict(xb)
            capture noisily comptab c101_a, rows(1) frame(c101_out) eplotframe(c101_plot)
            local refusal = _rc
            assert `refusal' == 459
            qa_state_compare, tag(composition_bad) allow(r)
            capture confirm frame c101_plot
            assert _rc == 111
            frame c101_a: char _dta[tabtools_eplotframe] "c101_ea"
            comptab c101_a, rows(1) frame(c101_out) eplotframe(c101_plot)
            frame c101_plot: assert !missing(estimate) & reldif(estimate, scalar(oracle_twin)) < 1e-14
            comptab c101_out, rows(1) frame(c101_b, replace) eplotframe(c101_eb, replace)
            frame c101_eb: assert !missing(estimate) & reldif(estimate, scalar(oracle_twin)) < 1e-14
            frame c101_out: char _dta[tabtools_companion_id] ""
            capture noisily comptab c101_out, rows(1) eplotframe(c101_corpus, replace)
            assert _rc == 459
        }
        else if "`scenario'" == "nested" {
            scalar oracle_second_row = scalar(oracle_mpg)
            comptab c101_a c101_a, rows(2 \ 1) frame(c101_out) eplotframe(c101_plot)
            frame c101_plot: assert source_row == 2 & table_row == 1 if model == 2 & table_row == 1
            frame c101_plot: assert source_row == 1 & table_row == 2 if table_row == 2
            comptab c101_out, rows(1) frame(c101_b, replace) eplotframe(c101_eb, replace)
            frame c101_eb: assert _N == 1 & model == 2 & source_row == 1 & table_row == 1
            frame c101_eb: assert !missing(estimate) & reldif(estimate, scalar(oracle_second_row)) < 1e-14
            frame c101_b: assert c1[4] == "" & substr(c4[4], 1, 1) == "-"
            frame c101_plot: drop table_row
            qa_state_snapshot, tag(composition_bad) predict(xb)
            capture noisily comptab c101_out, rows(1) eplotframe(c101_corpus)
            local refusal = _rc
            assert `refusal' == 459
            qa_state_compare, tag(composition_bad) allow(r)
            capture confirm frame c101_corpus
            assert _rc == 111
        }
        else if "`scenario'" == "ratepair" {
            tempfile ratefile
            clear
            set obs 2
            gen byte exposure = _n - 1
            gen double _D = 10 * _n
            gen double _Y = 1000
            gen double _Rate = _D / _Y
            gen double _Lower = _Rate * 0.8
            gen double _Upper = _Rate * 1.2
            label variable _Lower "Lower 95% confidence limit"
            label variable _Upper "Upper 95% confidence limit"
            label define c101_exp 0 "None" 1 "Current", replace
            label values exposure c101_exp
            save "`ratefile'.dta", replace
            stratetab, using(`ratefile') outcomes(1) frame(c101_rates) ///
                outlabels("Outcome 1") outcomeids("t1") explabels("Exposure")
            clear
            set obs 80
            gen byte treated = mod(_n, 2)
            gen double time = _n + 1 + 20 * treated
            gen byte failure = mod(_n, 3) != 0
            stset time, failure(failure)
            collect clear
            collect: stcox treated, nolog
            scalar oracle_rate_hr = exp(_b[treated])
            regtab, models("Outcome 1") frame(c101_a, replace) eplotframe(c101_ea, replace) noint
            replace time = time + 100 * treated
            stset time, failure(failure)
            collect clear
            collect: stcox treated, nolog
            regtab, models("Outcome 1") frame(c101_b, replace) eplotframe(c101_eb, replace) noint
            frame c101_a: char _dta[tabtools_eplotframe] "c101_eb"
            qa_state_snapshot, tag(composition_bad)
            capture noisily comptab, rateframe(c101_rates) modelframes(c101_a) ///
                rows(1) outcomemap("Outcome 1") frame(c101_out) eplotframe(c101_plot)
            local refusal = _rc
            assert `refusal' == 459
            qa_state_compare, tag(composition_bad) allow(r)
            capture confirm frame c101_plot
            assert _rc == 111
            frame c101_a: char _dta[tabtools_eplotframe] "c101_ea"
            comptab, rateframe(c101_rates) modelframes(c101_a) rows(1) ///
                outcomemap("Outcome 1") frame(c101_out) eplotframe(c101_plot)
            frame c101_plot: assert !missing(estimate) & reldif(estimate, scalar(oracle_rate_hr)) < 1e-14 if rowtype == "effect"
            frame c101_plot: count if rowtype == "effect"
            assert r(N) == 1
        }
        else if "`scenario'" == "heading" {
            collect clear
            collect: regress price i.foreign weight
            regtab, frame(c101_factor) eplotframe(c101_factor_ep) noint stats(n)
            frame c101_factor: local all_rows = _N - 3
            comptab c101_factor, rows(1/`all_rows') frame(c101_out) eplotframe(c101_plot)
            frame c101_plot: assert inlist(rowtype, "effect", "reference")
            frame c101_plot: isid source_row model
            frame c101_out: assert _N > 4
        }
    }
    local rc = _rc
    if `fixture_preserved' capture restore
    if inlist("`scenario'", "reordered", "compact") {
        capture erase "`book'"
        capture erase "`csv'"
    }
    if "`scenario'" == "ratepair" capture erase "`ratefile'.dta"
    if `rc' {
        local ++fail_count
        display as error "FAIL: `scenario' (rc=`rc')"
        capture qa_state_drop, tag(composition_ok)
        capture qa_state_drop, tag(composition_bad)
    }
    else {
        local ++pass_count
        display as result "PASS: `scenario'"
    }
}
display "RESULT: test_review_2026_10_01_composition tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
log close _all
if `fail_count' exit 1
