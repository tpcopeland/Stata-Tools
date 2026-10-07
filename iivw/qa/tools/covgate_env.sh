#!/bin/bash
# Runs one run_coverage_gate.sh subcommand against a scratch layout and records
# its exit status. Used only by test_iivw_audit_2026_10_05_qadocs.do.
# usage: covgate_env.sh SCRATCH CMD SIMS REPS BLOCK [FAKEBIN]
sd=$1; cmd=$2; export SIMS=$3 REPS=$4 BLOCK=$5
export SRC="$sd/iivw" BASE="$sd/base" RESULTS="$sd/res" FAMILIES=iptw WORKERS=1
[ -n "${6:-}" ] && export PATH="$6:$PATH"
cd "$sd" || exit 99
bash "$SRC/qa/run_coverage_gate.sh" "$cmd" > "$sd/out.txt" 2>&1
echo $? > "$sd/rc.txt"
