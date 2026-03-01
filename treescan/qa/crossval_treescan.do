* crossval_treescan.do — Cross-validation of treescan LLR computation
*
* Validates treescan against:
*   1. Hand-computed Bernoulli LLR on minimal tree
*   2. Hand-computed Bernoulli LLR on asymmetric tree with internal nodes
*   3. R TreeMineR cross-validation on ICD-10-SE data
*   4. Null distribution sanity check
*   5. Hand-computed Poisson LLR
*   6. Conditional Bernoulli permutation (observed LLR = unconditional)
*   7. Conditional Poisson permutation (observed LLR = unconditional)
*
* Produces: crossval_treescan.xlsx with the validation table
*
* Prerequisites: Run the companion R script first to generate benchmarks:
*   cd treescan/qa && Rscript 01_r_treeminer.R
*
* Run: stata-mp -b do crossval_treescan.do

version 16.0
set more off
set varabbrev off
clear all

* --- Paths ---
* All files are self-contained within treescan/qa/
local pkg_dir "/home/tpcopeland/Stata-Tools/treescan"
local qa_dir "`pkg_dir'/qa"
local outfile "`qa_dir'/crossval_treescan.xlsx"

* --- Setup adopath ---
capture ado uninstall treescan
adopath ++ "`pkg_dir'"
quietly mata: mata mlib index

* --- Results storage ---
* Accumulate results in numbered locals; build dataset at end
local n = 0

display _newline
display _dup(70) "="
display "Cross-Validation: treescan LLR computation"
display _dup(70) "="

* =====================================================================
* VALIDATION 1: Hand-computed Bernoulli LLR on minimal tree
* =====================================================================
* Tree: root -> A, B.  20 individuals, 5 exposed, 15 unexposed (p=0.25)
* Node A: 4 exposed, 3 unexposed. q1=4/7=0.571 > p=0.25 -> LLR > 0
* Hand-computed: LLR_A = 4*ln(4/7) + 3*ln(3/7) - (4*ln(0.25) + 3*ln(0.75))
*             = 1.627867

display _newline "Validation 1: Bernoulli LLR — minimal tree"
display _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
end
tempfile v1_tree
save `v1_tree'

clear
input long id str7 diag byte exposed
1  "A" 1
2  "A" 1
3  "A" 1
4  "A" 1
5  "B" 1
6  "A" 0
7  "A" 0
8  "A" 0
9  "B" 0
10 "B" 0
11 "B" 0
12 "B" 0
13 "B" 0
14 "B" 0
15 "B" 0
16 "B" 0
17 "B" 0
18 "B" 0
19 "B" 0
20 "B" 0
end

treescan diag using `v1_tree', id(id) exposed(exposed) nsim(99) seed(42)

local expected_llr = 4*ln(4/7) + 3*ln(3/7) - (4*ln(0.25) + 3*ln(0.75))
local observed_llr = r(max_llr)
local match = (abs(`observed_llr' - `expected_llr') < 0.001)

display "  Expected: " %10.6f `expected_llr'
display "  Observed: " %10.6f `observed_llr'

local s1 = cond(`match', "PASS", "FAIL")
local n = `n' + 1
local t`n'_test "V1: Bernoulli LLR (minimal tree)"
local t`n'_expected `: display %10.6f `expected_llr''
local t`n'_observed `: display %10.6f `observed_llr''
local t`n'_status "`s1'"

* Also check counts
local s1b = cond(r(n_exposed) == 5 & r(n_unexposed) == 15, "PASS", "FAIL")
local n = `n' + 1
local t`n'_test "V1b: Sample counts (5 exp, 15 unexp)"
local t`n'_expected "5 / 15"
local t`n'_observed "`: display r(n_exposed)' / `: display r(n_unexposed)'"
local t`n'_status "`s1b'"

* =====================================================================
* VALIDATION 2: Asymmetric tree with internal nodes
* =====================================================================
* Tree: root -> grp(->A,B), C.  10 individuals, 3 exposed (p=0.3)
* Node A: 3 exp, 1 unexp. q1=0.75 > p=0.3. Max LLR at A.
* LLR_A = 3*ln(0.75) + 1*ln(0.25) - (3*ln(0.3) + 1*ln(0.7)) = 1.719253

display _newline "Validation 2: Bernoulli LLR — asymmetric tree"
display _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"grp"  "root" 1 "Group"
"C"    "root" 1 "Node C"
"A"    "grp"  2 "Node A"
"B"    "grp"  2 "Node B"
end
tempfile v2_tree
save `v2_tree'

clear
input long id str7 diag byte exposed
1  "A" 1
2  "A" 1
3  "A" 1
4  "A" 0
5  "B" 0
6  "B" 0
7  "B" 0
8  "C" 0
9  "C" 0
10 "C" 0
end

treescan diag using `v2_tree', id(id) exposed(exposed) nsim(99) seed(42)

local expected_llr_A = 3*ln(0.75) + 1*ln(0.25) - (3*ln(0.3) + 1*ln(0.7))
local observed_llr = r(max_llr)
local match = (abs(`observed_llr' - `expected_llr_A') < 0.001)

display "  Expected: " %10.6f `expected_llr_A'
display "  Observed: " %10.6f `observed_llr'

local s2 = cond(`match', "PASS", "FAIL")
local n = `n' + 1
local t`n'_test "V2: Bernoulli LLR (asymmetric tree)"
local t`n'_expected `: display %10.6f `expected_llr_A''
local t`n'_observed `: display %10.6f `observed_llr''
local t`n'_status "`s2'"

* =====================================================================
* VALIDATION 3: Cross-validation with R TreeMineR
* =====================================================================

display _newline "Validation 3: Cross-validation with TreeMineR"
display _dup(50) "-"

local treeminer_diag "`qa_dir'/data/treeminer_diagnoses.csv"
local treeminer_res  "`qa_dir'/data/treeminer_results.csv"

capture confirm file "`treeminer_diag'"
if _rc {
    display as text "  Skipping: TreeMineR data not found"

    local n = `n' + 1
    local t`n'_test "V3a: Both tools find signal (LLR > 5)"
    local t`n'_expected "LLR > 5"
    local t`n'_observed "SKIPPED"
    local t`n'_status "SKIP"

    local n = `n' + 1
    local t`n'_test "V3b: Treescan signal significant"
    local t`n'_expected "p < 0.05"
    local t`n'_observed "SKIPPED"
    local t`n'_status "SKIP"
}
else {
    quietly import delimited using "`treeminer_diag'", clear varnames(1) stringcols(2)
    rename leaf diag

    display "  Observations: " _N
    quietly count if exposed == 1
    display "  Exposed: " r(N)

    treescan diag, id(id) exposed(exposed) icdversion(se) nsim(999) seed(42)
    local ts_max_llr = r(max_llr)
    local ts_p_value = r(p_value)

    quietly {
        preserve
        import delimited using "`treeminer_res'", clear varnames(1) stringcols(1)
        sort llr
        local tm_top_llr = llr[_N]
        restore
    }

    display "  Treescan max LLR:  " %10.4f `ts_max_llr'
    display "  TreeMineR max LLR: " %10.4f `tm_top_llr'

    local s3a = cond(`ts_max_llr' > 5 & `tm_top_llr' > 5, "PASS", "FAIL")
    local n = `n' + 1
    local t`n'_test "V3a: Both tools find signal (LLR > 5)"
    local t`n'_expected `: display %8.1f `tm_top_llr''
    local t`n'_observed `: display %8.1f `ts_max_llr''
    local t`n'_status "`s3a'"

    local s3b = cond(`ts_p_value' < 0.05, "PASS", "FAIL")
    local n = `n' + 1
    local t`n'_test "V3b: Treescan signal significant"
    local t`n'_expected "p < 0.05"
    local t`n'_observed "p = `: display %6.4f `ts_p_value''"
    local t`n'_status "`s3b'"
}

* =====================================================================
* VALIDATION 4: Null distribution sanity check
* =====================================================================

display _newline "Validation 4: Null distribution check"
display _dup(50) "-"

clear
set seed 999
set obs 200
gen long id = _n
gen byte exposed = (runiform() < 0.3)
gen str7 diag = ""
replace diag = "A000" if runiform() < 0.2
replace diag = "I21"  if diag == "" & runiform() < 0.2
replace diag = "J44"  if diag == "" & runiform() < 0.3
replace diag = "E1010" if diag == ""
drop if diag == ""

treescan diag, id(id) exposed(exposed) icdversion(cm) nsim(199) seed(42)

local null_p = r(p_value)
local null_llr = r(max_llr)
display "  Null p-value: " %6.4f `null_p'
display "  Null max LLR: " %6.4f `null_llr'

local s4 = cond(`null_p' > 0.01, "PASS", "FAIL")
local n = `n' + 1
local t`n'_test "V4: Null data non-extreme (p > 0.01)"
local t`n'_expected "p > 0.01"
local t`n'_observed "p = `: display %6.4f `null_p''"
local t`n'_status "`s4'"

* =====================================================================
* VALIDATION 5: Poisson LLR hand computation
* =====================================================================
* 20 individuals, 5 cases, person-time: cases=2.0yr, non-cases=3.0yr
* Total T=55, C=5, lambda=5/55
* Node A: c_A=4, T_A=17, E_A=17*(5/55)=1.5455
* LLR_A = 4*ln(4/1.5455) + 1*ln(1/3.4545) = 2.564214

display _newline "Validation 5: Poisson LLR — hand computation"
display _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
end
tempfile v5_tree
save `v5_tree'

clear
input long id str7 diag byte exposed double pyears
1  "A" 1 2.0
2  "A" 1 2.0
3  "A" 1 2.0
4  "A" 1 2.0
5  "B" 1 2.0
6  "A" 0 3.0
7  "A" 0 3.0
8  "A" 0 3.0
9  "B" 0 3.0
10 "B" 0 3.0
11 "B" 0 3.0
12 "B" 0 3.0
13 "B" 0 3.0
14 "B" 0 3.0
15 "B" 0 3.0
16 "B" 0 3.0
17 "B" 0 3.0
18 "B" 0 3.0
19 "B" 0 3.0
20 "B" 0 3.0
end

treescan diag using `v5_tree', id(id) exposed(exposed) ///
    persontime(pyears) model(poisson) nsim(99) seed(42)

local C = 5
local T = 55
local c_A = 4
local T_A = 4*2 + 3*3
local E_A = `T_A' * (`C' / `T')
local expected_pois = `c_A' * ln(`c_A' / `E_A') + ///
    (`C' - `c_A') * ln((`C' - `c_A') / (`C' - `E_A'))
local observed_pois = r(max_llr)
local match = (abs(`observed_pois' - `expected_pois') < 0.001)

display "  Expected: " %10.6f `expected_pois'
display "  Observed: " %10.6f `observed_pois'

local s5 = cond(`match', "PASS", "FAIL")
local n = `n' + 1
local t`n'_test "V5: Poisson LLR (hand-computed)"
local t`n'_expected `: display %10.6f `expected_pois''
local t`n'_observed `: display %10.6f `observed_pois''
local t`n'_status "`s5'"

local s5b = cond(r(total_persontime) == 55, "PASS", "FAIL")
local n = `n' + 1
local t`n'_test "V5b: Total person-time = 55"
local t`n'_expected "55"
local t`n'_observed "`: display r(total_persontime)'"
local t`n'_status "`s5b'"

local s5c = cond(r(total_cases) == 5, "PASS", "FAIL")
local n = `n' + 1
local t`n'_test "V5c: Total cases = 5"
local t`n'_expected "5"
local t`n'_observed "`: display r(total_cases)'"
local t`n'_status "`s5c'"

* =====================================================================
* VALIDATION 6: Conditional Bernoulli = unconditional observed LLR
* =====================================================================

display _newline "Validation 6: Conditional Bernoulli"
display _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
end
tempfile v6_tree
save `v6_tree'

clear
input long id str7 diag byte exposed
1  "A" 1
2  "A" 1
3  "A" 1
4  "A" 1
5  "B" 1
6  "A" 0
7  "A" 0
8  "A" 0
9  "B" 0
10 "B" 0
11 "B" 0
12 "B" 0
13 "B" 0
14 "B" 0
15 "B" 0
16 "B" 0
17 "B" 0
18 "B" 0
19 "B" 0
20 "B" 0
end

treescan diag using `v6_tree', id(id) exposed(exposed) nsim(99) seed(42)
local uncond_llr = r(max_llr)

treescan diag using `v6_tree', id(id) exposed(exposed) conditional nsim(99) seed(42)
local cond_llr = r(max_llr)

display "  Unconditional: " %10.6f `uncond_llr'
display "  Conditional:   " %10.6f `cond_llr'

local s6 = cond(abs(`uncond_llr' - `cond_llr') < 1e-10, "PASS", "FAIL")
local n = `n' + 1
local t`n'_test "V6: Cond. Bernoulli LLR = uncond."
local t`n'_expected `: display %10.6f `uncond_llr''
local t`n'_observed `: display %10.6f `cond_llr''
local t`n'_status "`s6'"

* =====================================================================
* VALIDATION 7: Conditional Poisson = unconditional observed LLR
* =====================================================================

display _newline "Validation 7: Conditional Poisson"
display _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
end
tempfile v7_tree
save `v7_tree'

clear
input long id str7 diag byte exposed double pyears
1  "A" 1 2.0
2  "A" 1 2.0
3  "A" 1 2.0
4  "A" 1 2.0
5  "B" 1 2.0
6  "A" 0 3.0
7  "A" 0 3.0
8  "A" 0 3.0
9  "B" 0 3.0
10 "B" 0 3.0
11 "B" 0 3.0
12 "B" 0 3.0
13 "B" 0 3.0
14 "B" 0 3.0
15 "B" 0 3.0
16 "B" 0 3.0
17 "B" 0 3.0
18 "B" 0 3.0
19 "B" 0 3.0
20 "B" 0 3.0
end

treescan diag using `v7_tree', id(id) exposed(exposed) ///
    persontime(pyears) model(poisson) nsim(99) seed(42)
local uncond_pois = r(max_llr)

treescan diag using `v7_tree', id(id) exposed(exposed) ///
    persontime(pyears) model(poisson) conditional nsim(99) seed(42)
local cond_pois = r(max_llr)

display "  Unconditional: " %10.6f `uncond_pois'
display "  Conditional:   " %10.6f `cond_pois'

local s7 = cond(abs(`uncond_pois' - `cond_pois') < 1e-10, "PASS", "FAIL")
local n = `n' + 1
local t`n'_test "V7: Cond. Poisson LLR = uncond."
local t`n'_expected `: display %10.6f `uncond_pois''
local t`n'_observed `: display %10.6f `cond_pois''
local t`n'_status "`s7'"

* =====================================================================
* BUILD RESULTS DATASET AND EXPORT
* =====================================================================

clear
set obs `n'

gen str50 test = ""
gen str20 expected = ""
gen str20 observed = ""
gen str6 status = ""

forvalues i = 1/`n' {
    quietly replace test = "`t`i'_test'" in `i'
    quietly replace expected = "`t`i'_expected'" in `i'
    quietly replace observed = "`t`i'_observed'" in `i'
    quietly replace status = "`t`i'_status'" in `i'
}

* Display summary table
display _newline
display _dup(70) "="
display "VALIDATION SUMMARY"
display _dup(70) "="
display %40s "Test" "  " %16s "Expected" "  " %16s "Observed" "  " %6s "Status"
display _dup(82) "-"

forvalues i = 1/`n' {
    display %40s test[`i'] "  " %16s expected[`i'] "  " %16s observed[`i'] "  " %6s status[`i']
}

quietly count if status == "PASS"
local n_pass = r(N)
quietly count if status == "FAIL"
local n_fail = r(N)
quietly count if status == "SKIP"
local n_skip = r(N)

display _dup(82) "-"
display "Results: `n_pass'/`n' passed, `n_fail' failed, `n_skip' skipped"

if `n_fail' == 0 {
    display as result "ALL VALIDATIONS PASSED"
}
else {
    display as error "`n_fail' VALIDATION(S) FAILED"
}

* Export to xlsx
capture erase "`outfile'"
quietly {
    putexcel set "`outfile'", sheet("Cross-Validation") replace

    putexcel A1 = "Cross-Validation: treescan LLR Computation"
    putexcel A2 = "Validated against hand-computed values and R TreeMineR"
    putexcel A3 = "Date: `c(current_date)'"

    putexcel A5 = "Test" B5 = "Expected" C5 = "Observed" D5 = "Status"

    forvalues i = 1/`n' {
        local r = `i' + 5
        putexcel A`r' = test[`i']
        putexcel B`r' = expected[`i']
        putexcel C`r' = observed[`i']
        putexcel D`r' = status[`i']
    }

    local sr = `n' + 7
    putexcel A`sr' = "Summary"
    putexcel B`sr' = "Passed: `n_pass' / `n'"
    if `n_skip' > 0 {
        putexcel C`sr' = "Skipped: `n_skip' (TreeMineR data not found)"
    }

    putexcel save
}

display _newline "Results exported to `outfile'"
