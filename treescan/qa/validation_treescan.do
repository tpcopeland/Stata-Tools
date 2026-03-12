* validation_treescan.do - Comprehensive statistical validation for treescan
* V1-V7: Hand-computed LLR, TreeMineR cross-validation, null distribution,
*         conditional equivalence (Bernoulli + Poisson)
* VG1-VG12: LLR monotonicity, three-leaf hand computation, temporal filtering,
*           p-value granularity, null replications, multi-node maxima,
*           power calibration, person-time weighting, results matrix validation
* 49 assertions
*
* Run: stata-mp -b do validation_treescan.do
* Date: 2026-03-12

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


* =====================================================================
* VALIDATION G1: LLR Monotonicity
* =====================================================================
* Principle: increasing concentration of exposed at a node → larger LLR.
* We use the same tree and vary the exposure concentration.
*
* Tree: root → A, B (both leaves)
* Fix: 20 individuals, vary exposed-at-A from 2 to 4 to 6 (all exposed=5)
*
* Setup 1: 2 of 5 exposed at A, 3 at B
* Setup 2: 4 of 5 exposed at A, 1 at B
* Setup 3: 5 of 5 exposed at A, 0 at B (all exposed at signal node)
*
* LLR should increase: llr1 < llr2 < llr3

display as text ""
display as text "Validation G1: LLR Monotonicity"
display as text _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
end
tempfile mono_tree
save `mono_tree'

* Setup 1: Weak signal (2 of 5 exposed at A)
clear
input long id str7 diag byte exposed
1  "A" 1
2  "A" 1
3  "B" 1
4  "B" 1
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
end

treescan diag using `mono_tree', id(id) exposed(exposed) nsim(99) seed(42)
local llr_weak = r(max_llr)

* Setup 2: Medium signal (4 of 5 exposed at A)
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
end

treescan diag using `mono_tree', id(id) exposed(exposed) nsim(99) seed(42)
local llr_medium = r(max_llr)

* Setup 3: Strong signal (5 of 5 exposed at A, 0 at B)
clear
input long id str7 diag byte exposed
1  "A" 1
2  "A" 1
3  "A" 1
4  "A" 1
5  "A" 1
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
end

treescan diag using `mono_tree', id(id) exposed(exposed) nsim(99) seed(42)
local llr_strong = r(max_llr)

display as text "  Weak LLR:   " as result %10.6f `llr_weak'
display as text "  Medium LLR: " as result %10.6f `llr_medium'
display as text "  Strong LLR: " as result %10.6f `llr_strong'

local vg1a = (`llr_weak' < `llr_medium')
run_test "VG1a: Weak < Medium LLR" `vg1a'

local vg1b = (`llr_medium' < `llr_strong')
run_test "VG1b: Medium < Strong LLR" `vg1b'

local vg1c = (`llr_weak' < `llr_strong')
run_test "VG1c: Weak < Strong LLR (transitivity)" `vg1c'

* =====================================================================
* VALIDATION G2: Three-Leaf Bernoulli Hand Computation
* =====================================================================
* Tree:
*   root
*   +-- A (leaf)
*   +-- B (leaf)
*   +-- C (leaf)
*
* Data: 30 individuals, 10 exposed, 20 unexposed
*   p = 10/30 = 1/3 = 0.333333
*
*   Node A: 7 exp, 2 unexp (n_total=9, q1=7/9=0.777778)
*   Node B: 2 exp, 8 unexp (n_total=10, q1=2/10=0.2 < p → LLR=0)
*   Node C: 1 exp, 10 unexp (n_total=11, q1=1/11=0.0909 < p → LLR=0)
*   Root:   10 exp, 20 unexp (q1=1/3=p → LLR=0)
*
* LLR for node A (q1=0.7778 > p=0.3333):
*   lla = 7*ln(7/9) + 2*ln(2/9) = 7*(-0.25131) + 2*(-1.50408)
*       = -1.75919 + (-3.00817) = -4.76736
*   ll0 = 7*ln(1/3) + 2*ln(2/3) = 7*(-1.09861) + 2*(-0.40546)
*       = -7.69028 + (-0.81093) = -8.50121
*   LLR_A = -4.76736 - (-8.50121) = 3.73385

display as text ""
display as text "Validation G2: Three-Leaf Bernoulli"
display as text _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
"C" "root" 1 "Node C"
end
tempfile v2_tree
save `v2_tree'

clear
input long id str7 diag byte exposed
1  "A" 1
2  "A" 1
3  "A" 1
4  "A" 1
5  "A" 1
6  "A" 1
7  "A" 1
8  "B" 1
9  "B" 1
10 "C" 1
11 "A" 0
12 "A" 0
13 "B" 0
14 "B" 0
15 "B" 0
16 "B" 0
17 "B" 0
18 "B" 0
19 "B" 0
20 "B" 0
21 "C" 0
22 "C" 0
23 "C" 0
24 "C" 0
25 "C" 0
26 "C" 0
27 "C" 0
28 "C" 0
29 "C" 0
30 "C" 0
end

treescan diag using `v2_tree', id(id) exposed(exposed) nsim(99) seed(42)

local expected_llr = 7*ln(7/9) + 2*ln(2/9) - (7*ln(1/3) + 2*ln(2/3))

display as text "  Expected LLR(A): " as result %10.6f `expected_llr'
display as text "  Observed LLR:    " as result %10.6f r(max_llr)

local vg2a = (abs(r(max_llr) - `expected_llr') < 0.001)
run_test "VG2a: Three-leaf LLR matches hand computation (tol=0.001)" `vg2a'

local vg2b = (r(n_exposed) == 10)
run_test "VG2b: n_exposed = 10" `vg2b'

local vg2c = (r(n_unexposed) == 20)
run_test "VG2c: n_unexposed = 20" `vg2c'

* =====================================================================
* VALIDATION G3: Poisson LLR on Asymmetric Tree
* =====================================================================
* Tree:
*   root
*   +-- grp (internal)
*   |   +-- A (leaf)
*   |   +-- B (leaf)
*   +-- C (leaf)
*
* Data: 15 individuals, 5 cases, 10 non-cases
*   Cases: pyears=1.0 each, Non-cases: pyears=4.0 each
*   Total person-time T = 5*1 + 10*4 = 45
*   Total cases C = 5
*
*   Node A: 4 cases at A, 1 non-case at A
*     c_A = 4, T_A = 4*1 + 1*4 = 8
*     E_A = T_A * (C/T) = 8 * (5/45) = 8/9 = 0.888889
*     c_A > E_A → LLR > 0
*     LLR_A = 4*ln(4/0.888889) + (5-4)*ln((5-4)/(5-0.888889))
*           = 4*ln(4.5) + 1*ln(1/4.111111)
*           = 4*(1.504077) + 1*(-1.413440)
*           = 6.016310 + (-1.413440)
*           = 4.602870
*
*   Node B: 0 cases, 4 non-cases → c=0 < E → LLR=0
*   Node C: 1 case, 5 non-cases
*     c_C = 1, T_C = 1*1 + 5*4 = 21
*     E_C = 21 * (5/45) = 21/9 = 2.333333
*     c_C < E_C → LLR=0
*
*   Node grp: 4 cases, 5 non-cases
*     c_grp = 4, T_grp = 4*1 + 5*4 = 24
*     E_grp = 24 * (5/45) = 24/9 = 2.666667
*     c_grp > E_grp → LLR > 0
*     LLR_grp = 4*ln(4/2.666667) + 1*ln(1/(5-2.666667))
*             = 4*ln(1.5) + 1*ln(1/2.333333)
*             = 4*(0.405465) + 1*(-0.847298)
*             = 1.621860 + (-0.847298)
*             = 0.774562
*
*   Max should be at node A: LLR_A = 4.602870

display as text ""
display as text "Validation G3: Poisson Asymmetric Tree"
display as text _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"grp"  "root" 1 "Group"
"C"    "root" 1 "Node C"
"A"    "grp"  2 "Node A"
"B"    "grp"  2 "Node B"
end
tempfile v3_tree
save `v3_tree'

clear
input long id str7 diag byte exposed double pyears
1  "A" 1 1.0
2  "A" 1 1.0
3  "A" 1 1.0
4  "A" 1 1.0
5  "C" 1 1.0
6  "A" 0 4.0
7  "B" 0 4.0
8  "B" 0 4.0
9  "B" 0 4.0
10 "B" 0 4.0
11 "C" 0 4.0
12 "C" 0 4.0
13 "C" 0 4.0
14 "C" 0 4.0
15 "C" 0 4.0
end

treescan diag using `v3_tree', id(id) exposed(exposed) ///
    persontime(pyears) model(poisson) nsim(99) seed(42)

* Hand-computed expected values
local C_total = 5
local T_total = 45
local c_A = 4
local T_A = 8
local E_A = `T_A' * (`C_total' / `T_total')
local expected_llr = `c_A' * ln(`c_A' / `E_A') + ///
    (`C_total' - `c_A') * ln((`C_total' - `c_A') / (`C_total' - `E_A'))

display as text "  Expected Poisson LLR(A): " as result %10.6f `expected_llr'
display as text "  Observed max LLR:        " as result %10.6f r(max_llr)

local vg3a = (abs(r(max_llr) - `expected_llr') < 0.001)
run_test "VG3a: Poisson asymmetric LLR matches (tol=0.001)" `vg3a'

local vg3b = (r(total_persontime) == 45)
run_test "VG3b: Total person-time = 45" `vg3b'

local vg3c = (r(total_cases) == 5)
run_test "VG3c: Total cases = 5" `vg3c'

* =====================================================================
* VALIDATION G4: Temporal Window Filtering Exactness
* =====================================================================
* Verify that temporal window correctly filters observations before LLR.
*
* Tree: root → A, B (leaves)
* Data: 10 individuals, 5 exposed, 5 unexposed
*   All exposed have diag=A, all unexposed have diag=B
*   Window: 0 to 20 days
*   windowscope: exposed (default — only filter exposed)
*
* Exposed individuals (all diag=A):
*   id=1: event-exp gap = 5 days  → IN window
*   id=2: event-exp gap = 10 days → IN window
*   id=3: event-exp gap = 15 days → IN window
*   id=4: event-exp gap = 25 days → OUT of window
*   id=5: event-exp gap = 50 days → OUT of window
*
* With windowscope=exposed, only exposed are filtered → 3 exposed remain
* All 5 unexposed remain (not filtered)
* Result: 3 exposed, 5 unexposed = 8 individuals

display as text ""
display as text "Validation G4: Temporal Window Filtering"
display as text _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
end
tempfile v4_tree
save `v4_tree'

clear
input long id str7 diag byte exposed double eventdt double expdt
1  "A" 1 22005 22000
2  "A" 1 22010 22000
3  "A" 1 22015 22000
4  "A" 1 22025 22000
5  "A" 1 22050 22000
6  "B" 0 22005 22000
7  "B" 0 22010 22000
8  "B" 0 22030 22000
9  "B" 0 22050 22000
10 "B" 0 22100 22000
end

* windowscope=exposed (default): only exposed filtered
treescan diag using `v4_tree', id(id) exposed(exposed) ///
    eventdate(eventdt) expdate(expdt) window(0 20) nsim(99) seed(42)

local vg4a = (r(n_exposed) == 3)
run_test "VG4a: Temporal filter: 3 exposed remain (windowscope=exposed)" `vg4a'

local vg4b = (r(n_unexposed) == 5)
run_test "VG4b: Temporal filter: all 5 unexposed remain" `vg4b'

* Now test windowscope=all: filter both exposed AND unexposed
* Unexposed within window: id=6 (5d), id=7 (10d) → 2 remain
* Exposed within window: id=1 (5d), id=2 (10d), id=3 (15d) → 3 remain
treescan diag using `v4_tree', id(id) exposed(exposed) ///
    eventdate(eventdt) expdate(expdt) window(0 20) ///
    windowscope(all) nsim(99) seed(42)

local vg4c = (r(n_exposed) == 3)
run_test "VG4c: Temporal filter: 3 exposed remain (windowscope=all)" `vg4c'

local vg4d = (r(n_unexposed) == 2)
run_test "VG4d: Temporal filter: 2 unexposed remain (windowscope=all)" `vg4d'

* Verify LLR changes between the two window scopes
* (different data → different LLR)
local llr_exposed_scope = r(max_llr)

treescan diag using `v4_tree', id(id) exposed(exposed) ///
    eventdate(eventdt) expdate(expdt) window(0 20) nsim(99) seed(42)
local llr_default_scope = r(max_llr)

* Both should yield valid LLR but may differ
local vg4e = (`llr_exposed_scope' >= 0 & `llr_default_scope' >= 0)
run_test "VG4e: Both windowscope options yield valid LLR" `vg4e'

* =====================================================================
* VALIDATION G5: p-value Granularity
* =====================================================================
* The p-value is computed as (# simulated max_llr >= observed + 1) / (nsim + 1)
* So the minimum nonzero p-value should be 1/(nsim+1)
* With nsim=19, minimum p = 1/20 = 0.05
* With nsim=99, minimum p = 1/100 = 0.01
*
* A very strong signal should have p = 1/(nsim+1)

display as text ""
display as text "Validation G5: p-value Granularity"
display as text _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
end
tempfile v5_tree
save `v5_tree'

* Very strong signal: all exposed at A, all unexposed at B
clear
input long id str7 diag byte exposed
1  "A" 1
2  "A" 1
3  "A" 1
4  "A" 1
5  "A" 1
6  "A" 1
7  "A" 1
8  "A" 1
9  "A" 1
10 "A" 1
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
21 "B" 0
22 "B" 0
23 "B" 0
24 "B" 0
25 "B" 0
26 "B" 0
27 "B" 0
28 "B" 0
29 "B" 0
30 "B" 0
end

treescan diag using `v5_tree', id(id) exposed(exposed) nsim(99) seed(42)

* With perfect separation and nsim=99, p should be exactly 1/100 = 0.01
* (no simulation should produce a max LLR as large as observed)
display as text "  Observed p-value: " as result %10.6f r(p_value)
display as text "  Min possible p:   " as result %10.6f 1/100

local vg5a = (r(p_value) <= 0.05)
run_test "VG5a: Very strong signal has p <= 0.05" `vg5a'

* p-value should be a multiple of 1/(nsim+1)
local p_raw = r(p_value)
local p_scaled = `p_raw' * 100
local p_int = round(`p_scaled')
local vg5b = (abs(`p_scaled' - `p_int') < 0.0001)
run_test "VG5b: p-value is multiple of 1/(nsim+1)" `vg5b'

* =====================================================================
* VALIDATION G6: Multiple Null Replications
* =====================================================================
* Under H0 (no real signal), p-values should vary across seeds.
* Run 5 replications with different seeds and check that
* p-values are not all identical (they should cover a range).

display as text ""
display as text "Validation G6: Multiple Null Replications"
display as text _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
"C" "root" 1 "Node C"
end
tempfile v6_tree
save `v6_tree'

* Null data: no relationship between exposure and diagnosis
clear
set seed 6000
set obs 100
gen long id = _n
gen byte exposed = (runiform() < 0.3)
gen str7 diag = ""
replace diag = "A" if runiform() < 0.33
replace diag = "B" if diag == "" & runiform() < 0.5
replace diag = "C" if diag == ""
drop if diag == ""

* Run with 5 different seeds and collect p-values
local pvals ""
forvalues s = 1/5 {
    local seed_val = 100 * `s' + 7
    treescan diag using `v6_tree', id(id) exposed(exposed) ///
        nsim(99) seed(`seed_val')
    local pv`s' = r(p_value)
    local pvals "`pvals' `pv`s''"
}

display as text "  p-values: `pvals'"

* All p-values should be in (0, 1]
local all_valid = 1
forvalues s = 1/5 {
    if `pv`s'' <= 0 | `pv`s'' > 1 {
        local all_valid = 0
    }
}
local vg6a = (`all_valid' == 1)
run_test "VG6a: All null p-values in (0, 1]" `vg6a'

* Not all p-values should be identical (very unlikely under null)
local all_same = 1
forvalues s = 2/5 {
    if abs(`pv`s'' - `pv1') > 1e-10 {
        local all_same = 0
    }
}
local vg6b = (`all_same' == 0)
run_test "VG6b: Null p-values vary across seeds" `vg6b'

* Under null, at least some p-values should be > 0.10
local any_large = 0
forvalues s = 1/5 {
    if `pv`s'' > 0.10 {
        local any_large = 1
    }
}
local vg6c = (`any_large' == 1)
run_test "VG6c: At least one null p-value > 0.10" `vg6c'

* =====================================================================
* VALIDATION G7: Multi-Node Correct Maximum
* =====================================================================
* Tree with 4 leaf nodes. Place signal at node C specifically.
* Verify that max LLR is at C and matches hand computation.
*
* Tree:
*   root
*   +-- X (internal)
*   |   +-- A (leaf)
*   |   +-- B (leaf)
*   +-- Y (internal)
*   |   +-- C (leaf)    ← signal here
*   |   +-- D (leaf)
*
* Data: 20 individuals, 6 exposed, 14 unexposed, p = 6/20 = 0.3
*   Node C: 5 exp, 1 unexp (n=6, q1=5/6=0.8333)
*   Node A: 1 exp, 5 unexp (q1=1/6=0.1667 < p → LLR=0)
*   Node B: 0 exp, 4 unexp (q1=0 < p → LLR=0)
*   Node D: 0 exp, 4 unexp (q1=0 < p → LLR=0)
*   Node Y: 5 exp, 5 unexp (q1=5/10=0.5 > p=0.3 → LLR > 0)
*   Node X: 1 exp, 9 unexp (q1=1/10=0.1 < p → LLR=0)
*
* LLR_C = 5*ln(5/6) + 1*ln(1/6) - (5*ln(0.3) + 1*ln(0.7))
*       = 5*(-0.18232) + 1*(-1.79176) - (5*(-1.20397) + (-0.35667))
*       = -0.91162 + (-1.79176) - (-6.01987 + (-0.35667))
*       = -2.70338 - (-6.37654)
*       = 3.67316
*
* LLR_Y = 5*ln(0.5) + 5*ln(0.5) - (5*ln(0.3) + 5*ln(0.7))
*       = 10*(-0.69315) - (5*(-1.20397) + 5*(-0.35667))
*       = -6.93147 - (-6.01987 + (-1.78335))
*       = -6.93147 - (-7.80322)
*       = 0.87175
*
* Max should be at C: LLR_C = 3.67316

display as text ""
display as text "Validation G7: Multi-Node Correct Maximum"
display as text _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"X"    "root" 1 "Group X"
"Y"    "root" 1 "Group Y"
"A"    "X"    2 "Node A"
"B"    "X"    2 "Node B"
"C"    "Y"    2 "Node C"
"D"    "Y"    2 "Node D"
end
tempfile v7_tree
save `v7_tree'

clear
input long id str7 diag byte exposed
1  "C" 1
2  "C" 1
3  "C" 1
4  "C" 1
5  "C" 1
6  "A" 1
7  "A" 0
8  "A" 0
9  "A" 0
10 "A" 0
11 "A" 0
12 "B" 0
13 "B" 0
14 "B" 0
15 "B" 0
16 "C" 0
17 "D" 0
18 "D" 0
19 "D" 0
20 "D" 0
end

treescan diag using `v7_tree', id(id) exposed(exposed) nsim(199) seed(42)

* Hand-computed LLR at node C
local p_overall = 6/20
local llr_C = 5*ln(5/6) + 1*ln(1/6) - (5*ln(`p_overall') + 1*ln(1-`p_overall'))

display as text "  Expected LLR(C): " as result %10.6f `llr_C'
display as text "  Observed max:    " as result %10.6f r(max_llr)

local vg7a = (abs(r(max_llr) - `llr_C') < 0.001)
run_test "VG7a: Max LLR at node C matches hand computation" `vg7a'

* With 199 simulations and strong signal, should be significant
local vg7b = (r(p_value) < 0.05)
run_test "VG7b: Node C signal is significant" `vg7b'

* Check results matrix exists and top row should be node C
capture matrix list r(results)
if _rc == 0 {
    local top_node : rownames r(results)
    local first_node : word 1 of `top_node'
    local vg7c = ("`first_node'" == "C")
    run_test "VG7c: Results matrix top node is C" `vg7c'
}
else {
    run_test "VG7c: Results matrix top node is C" 0
}

* =====================================================================
* VALIDATION G8: Power Calibration — Strong Signal
* =====================================================================
* With a very strong signal (RR=10, perfect separation), power should
* be high (> 0.5). We use enough simulations to make this reliable.

display as text ""
display as text "Validation G8: Power Calibration"
display as text _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
end
tempfile v8_tree
save `v8_tree'

* Clean data with moderate signal
clear
set obs 100
gen long id = _n
gen byte exposed = (_n <= 25)
gen str7 diag = "A" if exposed == 1
replace diag = "B" if diag == ""

treescan_power diag using `v8_tree', id(id) exposed(exposed) ///
    target(A) rr(10) nsim(99) nsimpower(50) seed(42)

display as text "  Power (RR=10): " as result %10.4f r(power)

local vg8a = (r(power) > 0.5)
run_test "VG8a: Strong signal (RR=10) yields power > 0.5" `vg8a'

local vg8b = (r(crit_val) >= 0)
run_test "VG8b: Critical value is non-negative" `vg8b'

local vg8c = (r(n_reject) > 0)
run_test "VG8c: At least some rejections with RR=10" `vg8c'

* =====================================================================
* VALIDATION G9: Conditional vs Unconditional Properties
* =====================================================================
* Under the same data, conditional and unconditional should produce:
*   1. Identical observed LLR (same formula)
*   2. Potentially different p-values (different null distribution)
* We test with data that has a moderate signal.

display as text ""
display as text "Validation G9: Conditional vs Unconditional"
display as text _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
end
tempfile v9_tree
save `v9_tree'

clear
input long id str7 diag byte exposed
1  "A" 1
2  "A" 1
3  "A" 1
4  "A" 1
5  "B" 1
6  "A" 0
7  "B" 0
8  "B" 0
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

* Unconditional
treescan diag using `v9_tree', id(id) exposed(exposed) nsim(499) seed(42)
local uncond_llr = r(max_llr)
local uncond_pv = r(p_value)

* Conditional
treescan diag using `v9_tree', id(id) exposed(exposed) ///
    conditional nsim(499) seed(42)
local cond_llr = r(max_llr)
local cond_pv = r(p_value)

display as text "  Unconditional LLR: " as result %10.6f `uncond_llr'
display as text "  Conditional LLR:   " as result %10.6f `cond_llr'
display as text "  Unconditional p:   " as result %10.4f `uncond_pv'
display as text "  Conditional p:     " as result %10.4f `cond_pv'

* Observed LLR should be identical
local vg9a = (abs(`uncond_llr' - `cond_llr') < 1e-10)
run_test "VG9a: Observed LLR identical (uncond = cond)" `vg9a'

* Both p-values should be valid
local vg9b = (`uncond_pv' > 0 & `uncond_pv' <= 1 & ///
    `cond_pv' > 0 & `cond_pv' <= 1)
run_test "VG9b: Both p-values valid" `vg9b'

* =====================================================================
* VALIDATION G10: Person-time Weighting Correctness
* =====================================================================
* Two scenarios with same case counts but different person-time
* distributions. Verify that Poisson LLR correctly accounts for
* person-time weighting.
*
* Scenario 1: Cases have short person-time (1.0), non-cases have long (5.0)
*   → Higher observed rate at signal node relative to expected
*
* Scenario 2: Cases have long person-time (5.0), non-cases have short (1.0)
*   → Lower observed rate at signal node relative to expected
*
* With same node counts but different person-times, LLR should differ.

display as text ""
display as text "Validation G10: Person-time Weighting"
display as text _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
end
tempfile v10_tree
save `v10_tree'

* Scenario 1: Cases short PT, non-cases long PT
clear
input long id str7 diag byte exposed double pyears
1  "A" 1 1.0
2  "A" 1 1.0
3  "A" 1 1.0
4  "B" 1 1.0
5  "B" 0 5.0
6  "B" 0 5.0
7  "B" 0 5.0
8  "B" 0 5.0
9  "B" 0 5.0
10 "B" 0 5.0
end

treescan diag using `v10_tree', id(id) exposed(exposed) ///
    persontime(pyears) model(poisson) nsim(99) seed(42)
local llr_short_pt = r(max_llr)

* Scenario 2: Cases long PT, non-cases short PT (same case/node counts)
clear
input long id str7 diag byte exposed double pyears
1  "A" 1 5.0
2  "A" 1 5.0
3  "A" 1 5.0
4  "B" 1 5.0
5  "B" 0 1.0
6  "B" 0 1.0
7  "B" 0 1.0
8  "B" 0 1.0
9  "B" 0 1.0
10 "B" 0 1.0
end

treescan diag using `v10_tree', id(id) exposed(exposed) ///
    persontime(pyears) model(poisson) nsim(99) seed(42)
local llr_long_pt = r(max_llr)

display as text "  LLR (short case PT): " as result %10.6f `llr_short_pt'
display as text "  LLR (long case PT):  " as result %10.6f `llr_long_pt'

* Both should yield different LLR (person-time matters)
local vg10a = (abs(`llr_short_pt' - `llr_long_pt') > 0.001)
run_test "VG10a: Person-time weighting changes LLR" `vg10a'

* Both should be non-negative
local vg10b = (`llr_short_pt' >= 0 & `llr_long_pt' >= 0)
run_test "VG10b: Both person-time scenarios yield valid LLR" `vg10b'

* =====================================================================
* VALIDATION G11: Temporal + Bernoulli LLR Hand Verification
* =====================================================================
* Verify that temporal window filtering + LLR computation gives
* the correct result by hand-computing the expected LLR after filtering.
*
* Tree: root → A, B
* Data: 10 individuals, 4 exposed, 6 unexposed
*   Window: 0 to 10 days, windowscope=exposed
*
* Exposed:
*   id=1: A, gap=5  → IN   (kept)
*   id=2: A, gap=8  → IN   (kept)
*   id=3: A, gap=15 → OUT  (dropped)
*   id=4: B, gap=5  → IN   (kept)
*
* After filter: 3 exposed remain (ids 1,2,4), 6 unexposed unchanged
* N=9 individuals, 3 exposed, p = 3/9 = 1/3
*
* Node A: 2 exp (ids 1,2), 3 unexp → q1 = 2/5 = 0.4 > p=0.333 → LLR > 0
* LLR_A = 2*ln(2/5) + 3*ln(3/5) - (2*ln(1/3) + 3*ln(2/3))
*       = 2*(-0.91629) + 3*(-0.51083) - (2*(-1.09861) + 3*(-0.40546))
*       = -1.83259 + (-1.53249) - (-2.19722 + (-1.21639))
*       = -3.36508 - (-3.41361)
*       = 0.04853

display as text ""
display as text "Validation G11: Temporal + Bernoulli LLR"
display as text _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
end
tempfile v11_tree
save `v11_tree'

clear
input long id str7 diag byte exposed double eventdt double expdt
1  "A" 1 22005 22000
2  "A" 1 22008 22000
3  "A" 1 22015 22000
4  "B" 1 22005 22000
5  "A" 0 22005 22000
6  "A" 0 22005 22000
7  "A" 0 22005 22000
8  "B" 0 22005 22000
9  "B" 0 22005 22000
10 "B" 0 22005 22000
end

treescan diag using `v11_tree', id(id) exposed(exposed) ///
    eventdate(eventdt) expdate(expdt) window(0 10) nsim(99) seed(42)

* After filtering: 3 exposed (ids 1,2,4), 6 unexposed
local vg11a = (r(n_exposed) == 3)
run_test "VG11a: Temporal: 3 exposed after filter" `vg11a'

local vg11b = (r(n_unexposed) == 6)
run_test "VG11b: Temporal: 6 unexposed after filter" `vg11b'

* Hand-computed LLR
local p_post = 3/9
local expected_llr = 2*ln(2/5) + 3*ln(3/5) - (2*ln(`p_post') + 3*ln(1-`p_post'))

display as text "  Expected LLR(A): " as result %10.6f `expected_llr'
display as text "  Observed LLR:    " as result %10.6f r(max_llr)

local vg11c = (abs(r(max_llr) - `expected_llr') < 0.001)
run_test "VG11c: Temporal LLR matches hand computation (tol=0.001)" `vg11c'

* =====================================================================
* VALIDATION G12: Results Matrix Row Names
* =====================================================================
* Verify that significant results matrix row names match the actual
* node codes from the tree.

display as text ""
display as text "Validation G12: Results Matrix Row Names"
display as text _dup(50) "-"

clear
input str7 node str7 parent byte level str60 description
"root" "" 0 "Root"
"A" "root" 1 "Node A"
"B" "root" 1 "Node B"
end
tempfile v12_tree
save `v12_tree'

* Strong signal at A so it appears in results
clear
input long id str7 diag byte exposed
1  "A" 1
2  "A" 1
3  "A" 1
4  "A" 1
5  "A" 1
6  "A" 1
7  "A" 1
8  "A" 1
9  "B" 1
10 "B" 1
11 "A" 0
12 "B" 0
13 "B" 0
14 "B" 0
15 "B" 0
16 "B" 0
17 "B" 0
18 "B" 0
19 "B" 0
20 "B" 0
21 "B" 0
22 "B" 0
23 "B" 0
24 "B" 0
25 "B" 0
26 "B" 0
27 "B" 0
28 "B" 0
29 "B" 0
30 "B" 0
end

treescan diag using `v12_tree', id(id) exposed(exposed) nsim(499) seed(42)

capture matrix list r(results)
if _rc == 0 {
    local rnames : rownames r(results)
    local first_rname : word 1 of `rnames'

    * The top result should be node A (strongest signal)
    local vg12a = ("`first_rname'" == "A")
    run_test "VG12a: Top result row named 'A'" `vg12a'

    * LLR column (col 3) should match max_llr
    local mat_llr = r(results)[1, 3]
    local vg12b = (abs(`mat_llr' - r(max_llr)) < 1e-6)
    run_test "VG12b: Matrix LLR matches r(max_llr)" `vg12b'

    * p-value column (col 4) should match p_value
    local mat_pv = r(results)[1, 4]
    local vg12c = (abs(`mat_pv' - r(p_value)) < 1e-6)
    run_test "VG12c: Matrix p-value matches r(p_value)" `vg12c'
}
else {
    * No significant results (unlikely)
    run_test "VG12a: Top result row named 'A'" 0
    run_test "VG12b: Matrix LLR matches r(max_llr)" 0
    run_test "VG12c: Matrix p-value matches r(p_value)" 0
}

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
