* Full pipeline smoke test
clear all
set more off
mata: mata clear
adopath + "/home/tpcopeland/Stata-Tools/nma"

* Create test data (3 treatments, 3 studies, fully connected)
clear
input str12 study str15 treatment events total
"S1" "A" 10 100
"S1" "B" 15 100
"S2" "A" 12 110
"S2" "C" 20 105
"S3" "B" 18 95
"S3" "C" 22 100
end

display "=== SETUP ==="
nma_setup events total, studyvar(study) trtvar(treatment) ref(A)

display _newline "=== FIT ==="
nma_fit, nolog

display _newline "=== RANK ==="
nma_rank, seed(42)

display _newline "=== COMPARE ==="
nma_compare

display _newline "=== INCONSISTENCY ==="
nma_inconsistency

display _newline "=== ALL PASSED ==="
