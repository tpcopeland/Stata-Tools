#!/bin/bash
# Test double for stata-mp, used only by test_iivw_audit_2026_10_05_qadocs.do to
# give run_coverage_gate.sh a successful, a sentinel-less, or a row-less block.
# The mode is the first line of the file "mode" beside this script.
# Invoked as: stata-mp -b do FILE fam sims reps seed from to 0 pscale
mode=$(head -1 "$(dirname "$0")/mode")
fam=$4; f=$8; t=$9
mkdir -p _inf_blocks
out=$(printf '%s_%05d_%05d' "$fam" "$f" "$t")
[ "$mode" != norow ] && echo stub > "_inf_blocks/$out.dta"
if [ "$mode" != nosentinel ]; then
    echo "RESULT: validation_iivw_inference $fam BLOCK $f-$t non-gate" > validation_iivw_inference.log
else
    echo nothing > validation_iivw_inference.log
fi
exit 0
