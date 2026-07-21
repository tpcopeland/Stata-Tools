#!/usr/bin/env bash
# =============================================================================
# iivw SOL-04 coverage gate -- block-sharded runner
# =============================================================================
# Drives validation_iivw_inference.do in BLOCK mode across many single-threaded
# Stata processes, then applies the preregistered acceptance once per family via
# combine_<family>.
#
# WHY BLOCKS AND NOT THREADS
#   The 1000 outer replications are independent (the seed ledger derives both
#   seeds for replication s from (master, arm, s); nothing carries between
#   them), so they split and recombine exactly. Stata-MP threading, by
#   contrast, is a measured NET LOSS on fits this small -- see the header note
#   in validation_iivw_inference.do. Each block therefore runs with
#   processors=1 and parallelism comes from running many blocks at once.
#
# SUBCOMMANDS
#   prep      build one isolated tree per block under $BASE/work
#   run       execute all pending blocks through a work queue
#   status    how many blocks are done / pending / failed
#   combine   gather block rows and apply the gate once per family
#   all       prep + run + combine
#
# ENV OVERRIDES
#   BASE      scratch root          (default: $SCRATCH/covgate)
#   SRC       package source tree   (default: ~/Stata-Tools/iivw)
#   WORKERS   concurrent processes  (default: nproc - 2)
#   BLOCK     replications per block(default: 50)
#   SIMS      whole-study size      (default: 1000)  -- NOT the block size
#   REPS      inner bootstrap draws (default: 999)
#   SEED      master seed           (default: 20260715)
#   FAMILIES  families to run       (default: "iiw fiptiw iptw")
# =============================================================================
set -uo pipefail

SRC="${SRC:-$HOME/Stata-Tools/iivw}"
BASE="${BASE:-$(pwd)/covgate}"
WORKERS="${WORKERS:-$(( $(nproc) - 2 ))}"
BLOCK="${BLOCK:-50}"
SIMS="${SIMS:-1000}"
REPS="${REPS:-999}"
SEED="${SEED:-20260715}"
# Longest-pole first: iiw and fiptiw refit far more per draw than iptw, so
# starting them first minimises total wall-clock (LPT scheduling).
FAMILIES="${FAMILIES:-iiw fiptiw iptw}"

WORK="$BASE/work"
POOL="$BASE/blockpool"      # every block's .dta is collected here
COMBINE="$BASE/combine"
LOGS="$BASE/logs"

[ "$WORKERS" -lt 1 ] && WORKERS=1

# ---------------------------------------------------------------------------
blocklist() {
    # emits "<family> <from> <to>" per line
    for fam in $FAMILIES; do
        f=1
        while [ "$f" -le "$SIMS" ]; do
            t=$(( f + BLOCK - 1 ))
            [ "$t" -gt "$SIMS" ] && t=$SIMS
            echo "$fam $f $t"
            f=$(( t + 1 ))
        done
    done
}

blocktag() { printf '%s_%05d_%05d' "$1" "$2" "$3"; }

# ---------------------------------------------------------------------------
cmd_prep() {
    [ -d "$SRC/qa" ] || { echo "FATAL: no qa/ under SRC=$SRC" >&2; exit 2; }
    mkdir -p "$WORK" "$POOL" "$LOGS"

    # Record exactly which code is under test. A coverage gate that cannot say
    # which build produced its number is not evidence.
    ( cd "$SRC" && find . -type f \( -name '*.ado' -o -name '*.do' \) \
        -exec sha256sum {} + | sort -k2 ) > "$BASE/MANIFEST.txt"
    ( cd "$SRC/.." && git rev-parse HEAD 2>/dev/null ) > "$BASE/GIT_HEAD.txt" || true
    echo "manifest: $(wc -l < "$BASE/MANIFEST.txt") files, head $(cat "$BASE/GIT_HEAD.txt" 2>/dev/null)"

    # Existing work trees are kept so an interrupted run resumes -- but that
    # means they hold the code as it was when first copied. If SRC has changed
    # since, rows already in the pool came from a DIFFERENT build than the ones
    # still to run, and the union would not be one study. Refuse rather than
    # silently mix builds.
    if [ -f "$BASE/MANIFEST.PREV.txt" ] && \
       ! cmp -s "$BASE/MANIFEST.PREV.txt" "$BASE/MANIFEST.txt"; then
        echo "FATAL: SRC changed since the existing blocks were produced." >&2
        echo "  Mixing builds in one union is not a valid study." >&2
        echo "  Start clean:  rm -rf '$BASE'   (discards completed blocks)" >&2
        diff "$BASE/MANIFEST.PREV.txt" "$BASE/MANIFEST.txt" | grep '^[<>]' | head -5 >&2
        exit 3
    fi
    cp -f "$BASE/MANIFEST.txt" "$BASE/MANIFEST.PREV.txt"

    n=0
    while read -r fam f t; do
        tag=$(blocktag "$fam" "$f" "$t")
        d="$WORK/$tag"
        [ -d "$d/iivw/qa" ] && continue
        mkdir -p "$d"
        cp -a "$SRC" "$d/iivw"
        # Blocks must never inherit a previous run's rows.
        rm -rf "$d/iivw/qa/_inf_blocks"
        rm -f "$d/iivw/qa"/*.log
        n=$(( n + 1 ))
    done < <(blocklist)
    echo "prep: $n new block tree(s); $(blocklist | wc -l) total"
}

# ---------------------------------------------------------------------------
# Runs ONE block. Invoked by xargs. Idempotent: a block whose rows are already
# in the pool is skipped, so an interrupted run resumes without redoing work.
run_one() {
    fam="$1"; f="$2"; t="$3"
    tag=$(blocktag "$fam" "$f" "$t")
    # The do-file names its own output <fam>_<FROM>_<TO>.dta with %05.0f.
    out="${fam}_$(printf '%05d_%05d' "$f" "$t").dta"

    [ -f "$POOL/$out" ] && { echo "SKIP  $tag (already in pool)"; return 0; }

    d="$WORK/$tag/iivw/qa"
    [ -d "$d" ] || { echo "FAIL  $tag (no work tree -- run prep)"; return 1; }

    ( cd "$d" && stata-mp -b do validation_iivw_inference.do \
        "$fam" "$SIMS" "$REPS" "$SEED" "$f" "$t" ) >/dev/null 2>&1

    # stata-mp -b ALWAYS exits 0 -- the exit status is not a verdict. The real
    # artifact is the rows file; the RESULT line is the corroborating check.
    if [ -f "$d/_inf_blocks/$out" ]; then
        cp -f "$d/_inf_blocks/$out" "$POOL/$out"
        cp -f "$d/validation_iivw_inference.log" "$LOGS/$tag.log" 2>/dev/null
        echo "OK    $tag"
        return 0
    fi
    cp -f "$d/validation_iivw_inference.log" "$LOGS/$tag.FAILED.log" 2>/dev/null
    echo "FAIL  $tag (no rows file; see $LOGS/$tag.FAILED.log)"
    return 1
}
export -f run_one blocktag
export WORK POOL LOGS SIMS REPS SEED

cmd_run() {
    mkdir -p "$POOL" "$LOGS"
    total=$(blocklist | wc -l)
    echo "run: $total block(s), $WORKERS worker(s), processors=1 each"
    echo "run: started $(date -Is)"
    blocklist | xargs -P "$WORKERS" -n 3 bash -c 'run_one "$@"' _ \
        | tee -a "$BASE/run.log"
    echo "run: finished $(date -Is)"
    cmd_status
}

# ---------------------------------------------------------------------------
cmd_status() {
    total=$(blocklist | wc -l)
    done_n=$(ls "$POOL" 2>/dev/null | grep -c '\.dta$' || true)
    echo "blocks: $done_n / $total complete"
    for fam in $FAMILIES; do
        d=$(ls "$POOL" 2>/dev/null | grep -c "^${fam}_" || true)
        n=$(blocklist | grep -c "^$fam " || true)
        echo "  $fam: $d / $n"
    done
    fails=$(ls "$LOGS" 2>/dev/null | grep -c 'FAILED' || true)
    [ "$fails" -gt 0 ] && echo "FAILED blocks: $fails (see $LOGS/*.FAILED.log)"
    # -x (exact process name), never -f: a -f pattern would match this watcher.
    live=$(pgrep -x stata-mp 2>/dev/null | wc -l)
    echo "live stata-mp: $live"
}

# ---------------------------------------------------------------------------
cmd_combine() {
    # ALWAYS refresh from SRC. Combine holds no resumable state, and a cached
    # tree silently runs whatever code was current when it was first copied --
    # that masked a real fix during development.
    rm -rf "$COMBINE"
    mkdir -p "$COMBINE"
    cp -a "$SRC" "$COMBINE/iivw"
    d="$COMBINE/iivw/qa"
    rm -rf "$d/_inf_blocks"; mkdir -p "$d/_inf_blocks"
    cp -f "$POOL"/*.dta "$d/_inf_blocks/" 2>/dev/null

    rc_all=0
    for fam in $FAMILIES; do
        echo "--- combine_$fam ---"
        ( cd "$d" && stata-mp -b do validation_iivw_inference.do \
            "combine_$fam" "$SIMS" "$REPS" "$SEED" ) >/dev/null 2>&1
        cp -f "$d/validation_iivw_inference.log" "$LOGS/combine_$fam.log" 2>/dev/null
        # Exit status is meaningless in batch mode; read the RESULT line.
        line=$(grep -E "^RESULT: validation_iivw_inference $fam gate=" \
            "$LOGS/combine_$fam.log" | tail -1)
        if [ -z "$line" ]; then
            echo "  NO VERDICT -- combine did not reach the gate."
            grep -E "^(combine\(|r\([0-9]+\);)" "$LOGS/combine_$fam.log" | tail -5
            rc_all=1
        else
            echo "  $line"
            case "$line" in *gate=FAIL*) rc_all=1;; esac
        fi
    done
    echo
    [ "$rc_all" -eq 0 ] && echo "ALL FAMILIES gate=PASS" || echo "AT LEAST ONE FAMILY DID NOT PASS"
    return "$rc_all"
}

# ---------------------------------------------------------------------------
case "${1:-all}" in
    prep)    cmd_prep ;;
    run)     cmd_run ;;
    status)  cmd_status ;;
    combine) cmd_combine ;;
    all)     cmd_prep && cmd_run && cmd_combine ;;
    *) echo "usage: $0 {prep|run|status|combine|all}" >&2; exit 2 ;;
esac
