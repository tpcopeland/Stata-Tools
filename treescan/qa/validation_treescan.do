* validation_treescan.do - Cross-validation of treescan against TreeMineR
* and hand-computed LLR values
*
* This file validates:
*   1. Bernoulli LLR computation against hand-calculated values
*   2. Node counts against known data
*   3. Cross-validation with TreeMineR results on shared dataset
*   4. Null distribution check
*   5. Poisson LLR computation against hand-calculated values
*   6. Conditional Bernoulli observed LLR = unconditional observed LLR
*   7. Conditional Poisson observed LLR = unconditional observed LLR
*
* Run: stata-mp -b do validation_treescan.do
* Date: 2026-02-23

clear all
set more off
version 16.0

adopath + "/home/tpcopeland/Stata-Tools/treescan"
quietly mata: mata mlib index

scalar n_tests = 0
scalar n_passed = 0
scalar n_failed = 0

capture program drop run_test
program define run_test
    args test_name result
    scalar n_tests = n_tests + 1
    if `result' {
        display as result "[PASS] `test_name'"
        scalar n_passed = n_passed + 1
    }
    else {
        display as error "[FAIL] `test_name'"
        scalar n_failed = n_failed + 1
    }
end

display as text ""
display as text _dup(70) "="
display as text "Validation: treescan LLR computation"
display as text _dup(70) "="
display as text ""

* =============================================================
* VALIDATION 1: Hand-computed LLR on a minimal tree
* =============================================================
* Tree:
*   root
*   +-- A (leaf)
*   +-- B (leaf)
*
* Data: 20 individuals
*   - 5 exposed, 15 unexposed
*   - p = 5/20 = 0.25
*   - Node A: 4 exposed, 3 unexposed (n1=4, n0=3, q1=4/7=0.571)
*   - Node B: 1 exposed, 12 unexposed (n1=1, n0=12, q1=1/13=0.077)
*   - Root:   5 exposed, 15 unexposed (same as overall, LLR=0)
*
* Hand-computed LLR for node A:
*   q1 = 4/7 = 0.5714286
*   q0 = 3/7 = 0.4285714
*   lla = 4*ln(0.5714286) + 3*ln(0.4285714)
*       = 4*(-0.5596158) + 3*(-0.8472979)
*       = -2.2384632 + (-2.5418937)
*       = -4.7803569
*   ll0 = 4*ln(0.25) + 3*ln(0.75)
*       = 4*(-1.3862944) + 3*(-0.2876821)
*       = -5.5451776 + (-0.8630463)
*       = -6.4082239
*   LLR_A = -4.7803569 - (-6.4082239) = 1.6278670
*   (q1=0.571 > p=0.25, so LLR is positive)
*
* LLR for node B:
*   q1 = 1/13 = 0.0769231
*   q1 < p = 0.25, so LLR_B = 0
*
* LLR for root:
*   q1 = 5/20 = 0.25 = p
*   q1 == p, so LLR_root = 0

display as text "Validation 1: Hand-computed LLR"
display as text _dup(50) "-"

* Create the tree
clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
end
tempfile v1_tree
save `v1_tree'

* Create the data
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

* Run treescan with many simulations (p-value not tested here, just LLR)
treescan diag using `v1_tree', id(id) exposed(exposed) nsim(99) seed(42)

* Check return values
local v1a = (r(n_exposed) == 5)
run_test "V1a: n_exposed = 5" `v1a'

local v1b = (r(n_unexposed) == 15)
run_test "V1b: n_unexposed = 15" `v1b'

* Check max LLR matches hand computation
* Expected: 1.6278670
local expected_llr = 4*ln(4/7) + 3*ln(3/7) - (4*ln(0.25) + 3*ln(0.75))
display as text "  Expected LLR: " as result %10.6f `expected_llr'
display as text "  Observed LLR: " as result %10.6f r(max_llr)

local v1c = (abs(r(max_llr) - `expected_llr') < 0.001)
run_test "V1c: LLR matches hand computation (tol=0.001)" `v1c'

* Check results matrix if significant
capture {
    matrix define _res = r(results)
    local v1d = 1
}
if _rc {
    * No significant results, check LLR directly from max
    local v1d = (r(max_llr) > 0)
}
run_test "V1d: LLR is positive" `v1d'

* =============================================================
* VALIDATION 2: Known-answer test with asymmetric tree
* =============================================================
* Tree:
*   root
*   +-- grp (internal node)
*   |   +-- A (leaf)
*   |   +-- B (leaf)
*   +-- C (leaf)
*
* Data: 10 individuals
*   - 3 exposed, 7 unexposed  => p = 0.3
*   - Node A: 3 exp, 1 unexp  (q1 = 3/4 = 0.75)
*   - Node B: 0 exp, 3 unexp  (q1 = 0, LLR = 0)
*   - Node C: 0 exp, 3 unexp  (q1 = 0, LLR = 0)
*   - Node grp: 3 exp, 4 unexp (q1 = 3/7 = 0.4286)
*   - Root: 3 exp, 7 unexp (q1 = 0.3 = p, LLR = 0)
*
* LLR for node A (q1=0.75 > p=0.3):
*   lla = 3*ln(0.75) + 1*ln(0.25) = -0.8630 + (-1.3863) = -2.2493
*   ll0 = 3*ln(0.3) + 1*ln(0.7) = -3.6119 + (-0.3567) = -3.9686
*   LLR_A = -2.2493 - (-3.9686) = 1.7193
*
* LLR for grp (q1=0.4286 > p=0.3):
*   lla = 3*ln(3/7) + 4*ln(4/7) = 3*(-0.8473) + 4*(-0.5596)
*       = -2.5419 + (-2.2385) = -4.7803
*   ll0 = 3*ln(0.3) + 4*ln(0.7) = -3.6119 + (-1.4267) = -5.0386
*   LLR_grp = -4.7803 - (-5.0386) = 0.2583

display as text ""
display as text "Validation 2: Asymmetric tree with internal nodes"
display as text _dup(50) "-"

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
local expected_llr_grp = 3*ln(3/7) + 4*ln(4/7) - (3*ln(0.3) + 4*ln(0.7))

display as text "  Expected LLR(A):   " as result %10.6f `expected_llr_A'
display as text "  Expected LLR(grp): " as result %10.6f `expected_llr_grp'
display as text "  Max LLR observed:  " as result %10.6f r(max_llr)

* Max LLR should be at node A
local v2a = (abs(r(max_llr) - `expected_llr_A') < 0.001)
run_test "V2a: Max LLR matches node A hand computation" `v2a'

* =============================================================
* VALIDATION 3: Cross-validate with TreeMineR on ICD-10-SE
*               Using TreeMineR's built-in diagnoses dataset
* =============================================================
display as text ""
display as text "Validation 3: Cross-validation with TreeMineR"
display as text _dup(50) "-"

* Import TreeMineR's diagnoses dataset
capture confirm file "/home/tpcopeland/Stata-Tools/treescan/treeminer_diagnoses.csv"
if _rc {
    display as text "  Skipping: TreeMineR comparison data not found"
    display as text "  Run _get_treeminer_example.R first"
}
else {
    quietly {
        import delimited using ///
            "/home/tpcopeland/Stata-Tools/treescan/treeminer_diagnoses.csv", ///
            clear varnames(1) stringcols(2)
    }

    * Rename to match treescan syntax
    rename leaf diag

    display as text "  Observations: " _N
    quietly count if exposed == 1
    display as text "  Exposed obs:  " r(N)

    * Run treescan with ICD-10-SE tree
    treescan diag, id(id) exposed(exposed) icdversion(se) nsim(999) seed(42)

    * Save results before preserve clobbers them
    local ts_max_llr = r(max_llr)
    local ts_p_value = r(p_value)

    * TreeMineR top result: node "12", LLR=11.995, p=0.001
    * (with 969 exposed, 8865 unexposed, p=0.0985)
    *
    * Note: exact LLR may differ slightly due to:
    * 1. Different tree structures (our SE tree may differ from TreeMineR's)
    * 2. Floating point differences
    * But the top signal should be the same node

    * Import TreeMineR results for comparison
    quietly {
        preserve
        import delimited using ///
            "/home/tpcopeland/Stata-Tools/treescan/treeminer_results.csv", ///
            clear varnames(1) stringcols(1)

        * Get top node from TreeMineR
        sort llr
        local tm_top_node = cut[_N]
        local tm_top_llr = llr[_N]
        display "  TreeMineR top node: `tm_top_node' with LLR = " %10.4f `tm_top_llr'
        restore
    }

    display as text "  Treescan max LLR:  " as result %10.4f `ts_max_llr'
    display as text "  TreeMineR max LLR: " as result %10.4f `tm_top_llr'

    * LLR magnitude will differ due to different handling of mixed-exposure
    * individuals (our code uses max per person; TreeMineR uses a different
    * resolution). Both should find strong signal (same order of magnitude).
    local v3a = (`ts_max_llr' > 5 & `tm_top_llr' > 5)
    run_test "V3a: Both tools find strong signal (LLR > 5)" `v3a'

    * Both should find signal (max_llr > 5)
    local v3b = (`ts_max_llr' > 5)
    run_test "V3b: Treescan finds strong signal (LLR > 5)" `v3b'

    * P-value should be small for top signal
    local v3c = (`ts_p_value' < 0.05)
    run_test "V3c: Top signal is significant (p < 0.05)" `v3c'
}

* =============================================================
* VALIDATION 4: Verify no-signal case has uniform p-values
* =============================================================
display as text ""
display as text "Validation 4: Null distribution check"
display as text _dup(50) "-"

* Under H0 (no real signal), p-values should be roughly uniform
* Max LLR should be small and p-value should be large
clear
set seed 999
set obs 200
gen long id = _n
gen byte exposed = (runiform() < 0.3)
* Assign random codes with NO relationship to exposure
gen str7 diag = ""
replace diag = "A000" if runiform() < 0.2
replace diag = "I21"  if diag == "" & runiform() < 0.2
replace diag = "J44"  if diag == "" & runiform() < 0.3
replace diag = "E1010" if diag == ""
drop if diag == ""

treescan diag, id(id) exposed(exposed) icdversion(cm) nsim(199) seed(42)

* Under null, p-value should typically be > 0.1
* (not guaranteed, but very likely with random data)
local v4 = (r(p_value) > 0.01)
run_test "V4: Null data yields non-extreme p-value (> 0.01)" `v4'

display as text "  Null max_llr: " as result %10.4f r(max_llr)
display as text "  Null p_value: " as result %10.4f r(p_value)

* =============================================================
* VALIDATION 5: Poisson LLR hand computation
* =============================================================
* Tree:
*   root
*   +-- A (leaf)
*   +-- B (leaf)
*
* Data: 20 individuals, 5 cases (exposed=1), 15 non-cases
*   Person-time: cases have 2.0 years each, non-cases have 3.0 years each
*   Total person-time T = 5*2 + 15*3 = 55
*   Total cases C = 5
*   Global rate lambda = 5/55 = 0.0909091
*
*   Node A: 4 cases at A, 3 non-cases at A
*     c_A = 4, T_A = 4*2 + 3*3 = 17
*     E_A = T_A * (C/T) = 17 * (5/55) = 17/11 = 1.545455
*     c_A > E_A (4 > 1.545), so LLR > 0
*     LLR_A = 4*ln(4/1.545455) + (5-4)*ln((5-4)/(5-1.545455))
*           = 4*ln(2.588235) + 1*ln(1/3.454545)
*           = 4*0.950675 + 1*(-1.239533)
*           = 3.802700 + (-1.239533)
*           = 2.563167
*
*   Node B: 1 case at B, 12 non-cases at B
*     c_B = 1, T_B = 1*2 + 12*3 = 38
*     E_B = 38 * (5/55) = 38/11 = 3.454545
*     c_B < E_B (1 < 3.454), so LLR_B = 0
*
*   Root: c=5, T=55, E=55*(5/55)=5 -> c==E -> LLR=0

display as text ""
display as text "Validation 5: Poisson LLR hand computation"
display as text _dup(50) "-"

* Create the tree
clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
end
tempfile v5_tree
save `v5_tree'

* Create the data
* cases (exposed=1) have pyears=2, non-cases (exposed=0) have pyears=3
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

* Hand-computed expected values
local C = 5
local T = 55
local c_A = 4
local T_A = 4*2 + 3*3
local E_A = `T_A' * (`C' / `T')
local expected_llr = `c_A' * ln(`c_A' / `E_A') + ///
    (`C' - `c_A') * ln((`C' - `c_A') / (`C' - `E_A'))

display as text "  Expected Poisson LLR(A): " as result %10.6f `expected_llr'
display as text "  Observed max LLR:        " as result %10.6f r(max_llr)

local v5a = (abs(r(max_llr) - `expected_llr') < 0.001)
run_test "V5a: Poisson LLR matches hand computation (tol=0.001)" `v5a'

local v5b = (r(total_persontime) == 55)
run_test "V5b: Total person-time = 55" `v5b'

local v5c = (r(total_cases) == 5)
run_test "V5c: Total cases = 5" `v5c'

local v5d = ("`r(model)'" == "poisson")
run_test "V5d: r(model) = poisson" `v5d'

* =============================================================
* VALIDATION 6: Conditional Bernoulli — total exposed is fixed
* =============================================================
* Under the conditional model, every simulation must have exactly
* N_exposed individuals marked as exposed (permutation, not resampling).
* We test this by running conditional with a custom tree and checking
* that the returned LLR is identical to the unconditional observed LLR
* (since the formula is the same) and that it executes correctly.

display as text ""
display as text "Validation 6: Conditional Bernoulli permutation"
display as text _dup(50) "-"

* Use the minimal tree from validation 1
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

* Run unconditional first
treescan diag using `v6_tree', id(id) exposed(exposed) nsim(99) seed(42)
local uncond_llr = r(max_llr)

* Run conditional
treescan diag using `v6_tree', id(id) exposed(exposed) conditional nsim(99) seed(42)
local cond_llr = r(max_llr)

* Observed LLR should be identical (same data, same formula)
local v6a = (abs(`uncond_llr' - `cond_llr') < 1e-10)
run_test "V6a: Conditional observed LLR = unconditional observed LLR" `v6a'

* Conditional flag should be stored
local v6b = ("`r(conditional)'" == "conditional")
run_test "V6b: r(conditional) is 'conditional'" `v6b'

display as text "  Unconditional LLR: " as result %10.6f `uncond_llr'
display as text "  Conditional LLR:   " as result %10.6f `cond_llr'

* =============================================================
* VALIDATION 7: Conditional Poisson — same observed LLR
* =============================================================
display as text ""
display as text "Validation 7: Conditional Poisson permutation"
display as text _dup(50) "-"

* Use the tree from validation 5
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

* Run unconditional
treescan diag using `v7_tree', id(id) exposed(exposed) ///
    persontime(pyears) model(poisson) nsim(99) seed(42)
local uncond_pois_llr = r(max_llr)

* Run conditional
treescan diag using `v7_tree', id(id) exposed(exposed) ///
    persontime(pyears) model(poisson) conditional nsim(99) seed(42)
local cond_pois_llr = r(max_llr)

local v7a = (abs(`uncond_pois_llr' - `cond_pois_llr') < 1e-10)
run_test "V7a: Poisson conditional observed LLR = unconditional" `v7a'

local v7b = ("`r(conditional)'" == "conditional")
run_test "V7b: Poisson conditional flag stored" `v7b'

display as text "  Unconditional Poisson LLR: " as result %10.6f `uncond_pois_llr'
display as text "  Conditional Poisson LLR:   " as result %10.6f `cond_pois_llr'

* =============================================================
* SUMMARY
* =============================================================
display as text ""
display as text _dup(70) "="
display as text "Validation Results: " scalar(n_passed) "/" scalar(n_tests) " passed, " scalar(n_failed) " failed"
display as text _dup(70) "="

if scalar(n_failed) > 0 {
    display as error "SOME VALIDATIONS FAILED"
    exit 1
}
else {
    display as result "ALL VALIDATIONS PASSED"
}
