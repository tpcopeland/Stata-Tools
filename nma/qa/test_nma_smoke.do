* Quick smoke test for nma_setup
clear all
set more off
adopath + "/home/tpcopeland/Stata-Dev/nma"

* Create minimal test data
clear
input str12 study str15 treatment events total
"S1" "A" 10 100
"S1" "B" 15 100
"S2" "A" 12 110
"S2" "C" 20 105
"S3" "B" 18 95
"S3" "C" 22 100
end

display "Data loaded, N = " _N
list

nma_setup events total, studyvar(study) trtvar(treatment)
