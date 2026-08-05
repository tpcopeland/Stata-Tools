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
#   unclaim   release stale in-flight claims after a killed run (no workers live)
#   all       prep + run + combine
#
# CONCURRENT QUEUES
#   Blocks are claimed atomically (mkdir), so a second queue -- a resume started
#   while the first is live, or extra workers added to use freed cores -- skips
#   in-flight blocks instead of duplicating them. Before this, the only guard
#   was "is the .dta already pooled", which an in-flight block does not satisfy.
#   If a run is killed, its claims survive; clear them with `unclaim'.
#
# WHERE OUTPUT GOES
#   Two roots, deliberately separate, because they have opposite lifetimes.
#
#   RESULTS -- the EVIDENCE. Block rows, per-block logs, the build manifest, the
#     git head, and the combine logs. Lives inside the package at
#     qa/coverage_results/runs/<config>/ so a gate result is reproducible from
#     the repository rather than from a scratch directory nobody kept. This was
#     a real gap: the 2026-07-22 pool is un-recombinable and the 2026-08-05 pool
#     existed only under a scratch root, so every distributional claim about it
#     rested on files not in the tree.
#
#   BASE -- pure SCRATCH. One isolated work tree per block, the combine tree,
#     and the in-flight claim directory. Must NOT sit inside the package: prep
#     copies SRC into each work tree, so a scratch root under SRC would copy
#     itself. RESULTS lives under SRC precisely because copy_tree excludes it.
#
#   Everything under RESULTS is keyed by (REPS, SEED, PSCALE) so a pilot's rows
#   and a release run's rows can never share a directory.
#
# ENV OVERRIDES
#   BASE      scratch root          (default: $TMPDIR/iivw-covgate-<uid>)
#   RESULTS   retained evidence     (default: SRC/qa/coverage_results/runs/<cfg>)
#   SRC       package source tree   (default: the package this script lives in)
#   WORKERS   concurrent processes  (default: nproc - 2)
#   BLOCK     replications per block(default: 50)
#   SIMS      whole-study size      (default: 1000)  -- NOT the block size
#   REPS      inner bootstrap draws (default: 999)
#   SEED      master seed           (default: 20260715)
#   PSCALE    FIPTIW propensity-slope multiplier (default: 1)
#   FAMILIES  families to run       (default: "iiw fiptiw iptw")
# =============================================================================
set -uo pipefail

# Default to the package this script lives in, not a hardcoded ~/Stata-Tools
# path: the documented isolation practice runs from a scratch COPY, and an
# absolute default silently tests the ORIGINAL tree while every log and receipt
# says the copy. Deriving from BASH_SOURCE makes "the tree under test" mean the
# tree the script came from. Still overridable by exporting SRC.
SRC="${SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# Scratch, and never inside the repo. The former default was $(pwd)/covgate,
# which put the work trees INSIDE the package whenever the script was run from
# qa/ -- which is exactly what COVERAGE_GATE_RUNBOOK.md tells you to do. prep
# then copied SRC (containing covgate) into each of ~120 work trees. Deriving
# from TMPDIR removes the footgun instead of documenting around it. Stable, not
# mktemp: concurrent queues coordinate through the claim directory under BASE,
# so a fresh random root per invocation would silently disable that guard.
BASE="${BASE:-${TMPDIR:-/tmp}/iivw-covgate-$(id -u)}"
WORKERS="${WORKERS:-$(( $(nproc) - 2 ))}"
BLOCK="${BLOCK:-50}"
SIMS="${SIMS:-1000}"
REPS="${REPS:-999}"
SEED="${SEED:-20260715}"
PSCALE="${PSCALE:-1}"
# Longest-pole first: iiw and fiptiw refit far more per draw than iptw, so
# starting them first minimises total wall-clock (LPT scheduling).
FAMILIES="${FAMILIES:-iiw fiptiw iptw}"

WORK="$BASE/work"
COMBINE="$BASE/combine"

# Retained evidence, keyed by the configuration that produced it. A block .dta
# is named <family>_<from>_<to>.dta and carries REPS/SEED nowhere in its name,
# so a single flat pool lets a REPS=10 pilot's files satisfy the REPS=999 run's
# skip-if-present test -- the real run would then skip every block and combine
# would certify pilot rows. The do-file refuses such a union outright (it stamps
# and verifies provenance per row); this keeps the two from ever meeting.
CFGKEY="r${REPS}_s${SEED}_p${PSCALE}"
RESULTS="${RESULTS:-$SRC/qa/coverage_results/runs/$CFGKEY}"
POOL="$RESULTS/blocks"
LOGS="$RESULTS/logs"
# In-flight block claims (see run_one). Runtime state, not evidence, so it stays
# in scratch -- but it is keyed the same way, so a pilot run's claims can never
# block a release run's blocks. Losing BASE to a reboot is harmless: the pool
# test in run_one is the primary guard and the pool is now in the repo.
CLAIMS="$BASE/claims/$CFGKEY"

[ "$WORKERS" -lt 1 ] && WORKERS=1

# ---------------------------------------------------------------------------
# Copy the package into a scratch tree, WITHOUT the retained-evidence directory.
# RESULTS defaults to a path under SRC, so a plain `cp -a $SRC' would copy the
# accumulating block pool and every per-block log into all ~120 work trees --
# growing with the run, and pointless because no work tree reads them.
copy_tree() {
    local src="$1" dst="$2"
    mkdir -p "$dst"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --exclude='qa/coverage_results/' "$src/" "$dst/"
    else
        cp -a "$src/." "$dst/"
        rm -rf "$dst/qa/coverage_results"
    fi
}

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
    case "$BASE" in
        "$SRC"|"$SRC"/*)
            echo "FATAL: BASE=$BASE is inside the package tree ($SRC)." >&2
            echo "  prep copies SRC into every work tree, so a scratch root under" >&2
            echo "  SRC copies itself. Retained evidence goes to RESULTS, not BASE." >&2
            exit 2 ;;
    esac
    mkdir -p "$WORK" "$POOL" "$LOGS"
    echo "results: $RESULTS"
    echo "scratch: $BASE"

    # Record exactly which code is under test. A coverage gate that cannot say
    # which build produced its number is not evidence. The manifest is filed
    # with the rows it describes, not in scratch -- a manifest that outlives its
    # pool, or a pool that outlives its manifest, certifies nothing.
    ( cd "$SRC" && find . -type f \( -name '*.ado' -o -name '*.do' \) \
        -not -path './qa/coverage_results/*' \
        -exec sha256sum {} + | sort -k2 ) > "$RESULTS/MANIFEST.txt"
    ( cd "$SRC/.." && git rev-parse HEAD 2>/dev/null ) > "$RESULTS/GIT_HEAD.txt" || true
    echo "manifest: $(wc -l < "$RESULTS/MANIFEST.txt") files, head $(cat "$RESULTS/GIT_HEAD.txt" 2>/dev/null)"

    # Existing work trees are kept so an interrupted run resumes -- but that
    # means they hold the code as it was when first copied. If SRC has changed
    # since, rows already in the pool came from a DIFFERENT build than the ones
    # still to run, and the union would not be one study. Refuse rather than
    # silently mix builds.
    if [ -f "$RESULTS/MANIFEST.PREV.txt" ] && \
       ! cmp -s "$RESULTS/MANIFEST.PREV.txt" "$RESULTS/MANIFEST.txt"; then
        echo "FATAL: SRC changed since the existing blocks were produced." >&2
        echo "  Mixing builds in one union is not a valid study." >&2
        echo "  Start clean:  rm -rf '$RESULTS' '$BASE'   (discards completed blocks)" >&2
        diff "$RESULTS/MANIFEST.PREV.txt" "$RESULTS/MANIFEST.txt" | grep '^[<>]' | head -5 >&2
        exit 3
    fi
    cp -f "$RESULTS/MANIFEST.txt" "$RESULTS/MANIFEST.PREV.txt"

    n=0
    while read -r fam f t; do
        tag=$(blocktag "$fam" "$f" "$t")
        d="$WORK/$tag"
        [ -d "$d/iivw/qa" ] && continue
        copy_tree "$SRC" "$d/iivw"
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

    # ATOMIC CLAIM.  The pool test above only sees FINISHED blocks, so it cannot
    # exclude a block another process started but has not yet pooled.  A second
    # queue -- a resume launched while the first is live, or extra workers added
    # to use freed cores -- therefore re-ran in-flight blocks.  Observed
    # 2026-08-05: iptw_00951_00975 ran in two processes at once, burning a core
    # for 17 minutes.  It cost only wasted CPU (combine de-duplicates on
    # (arm,sim) and refuses overlapping ranges), but on a ~90 CPU-h gate the
    # waste is the point.
    #
    # mkdir is atomic on POSIX: exactly one racer creates the directory, every
    # other gets EEXIST and steps aside.  A plain -e test would not be atomic.
    # Claims live outside POOL so `ls $POOL' stays a clean block listing.
    mkdir -p "$CLAIMS" 2>/dev/null
    if ! mkdir "$CLAIMS/$tag" 2>/dev/null; then
        echo "CLAIM $tag (held by another worker; skipping)"
        return 0
    fi

    d="$WORK/$tag/iivw/qa"
    [ -d "$d" ] || { rmdir "$CLAIMS/$tag" 2>/dev/null; echo "FAIL  $tag (no work tree -- run prep)"; return 1; }

    ( cd "$d" && stata-mp -b do validation_iivw_inference.do \
        "$fam" "$SIMS" "$REPS" "$SEED" "$f" "$t" 0 "$PSCALE" ) >/dev/null 2>&1

    # stata-mp -b ALWAYS exits 0 -- the exit status is not a verdict. The real
    # artifact is the rows file; the RESULT line is the corroborating check.
    if [ -f "$d/_inf_blocks/$out" ]; then
        cp -f "$d/_inf_blocks/$out" "$POOL/$out"
        cp -f "$d/validation_iivw_inference.log" "$LOGS/$tag.log" 2>/dev/null
        echo "OK    $tag"
        return 0
    fi
    # Release the claim on failure so a later resume can retry this block; a
    # successful block needs no release because its .dta now guards it.
    rmdir "$CLAIMS/$tag" 2>/dev/null
    cp -f "$d/validation_iivw_inference.log" "$LOGS/$tag.FAILED.log" 2>/dev/null
    echo "FAIL  $tag (no rows file; see $LOGS/$tag.FAILED.log)"
    return 1
}
export -f run_one blocktag
export WORK POOL LOGS CLAIMS SIMS REPS SEED PSCALE

cmd_run() {
    mkdir -p "$POOL" "$LOGS"
    total=$(blocklist | wc -l)
    echo "run: $total block(s), $WORKERS worker(s), processors=1 each"
    echo "run: started $(date -Is)"
    blocklist | xargs -P "$WORKERS" -n 3 bash -c 'run_one "$@"' _ \
        | tee -a "$RESULTS/run.log"
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
    mkdir -p "$COMBINE" "$LOGS"
    copy_tree "$SRC" "$COMBINE/iivw"
    d="$COMBINE/iivw/qa"
    rm -rf "$d/_inf_blocks"; mkdir -p "$d/_inf_blocks"
    cp -f "$POOL"/*.dta "$d/_inf_blocks/" 2>/dev/null

    rc_all=0
    for fam in $FAMILIES; do
        echo "--- combine_$fam ---"
        ( cd "$d" && stata-mp -b do validation_iivw_inference.do \
            "combine_$fam" "$SIMS" "$REPS" "$SEED" 0 0 0 "$PSCALE" ) >/dev/null 2>&1
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
# Drop claims for blocks that are not in the pool. A killed worker leaves its
# claim behind, and nothing else would ever release it, so a resume would skip
# that block forever and combine would refuse the union for a missing interior
# block. Run this ONLY when no workers are live -- it cannot distinguish a stale
# claim from a legitimately in-flight one.
cmd_unclaim() {
    live=$(pgrep -x stata-mp 2>/dev/null | wc -l)
    if [ "$live" -gt 0 ]; then
        echo "REFUSING: $live stata-mp process(es) live; a claim held by a running" >&2
        echo "  worker is not stale. Stop the run first." >&2
        exit 2
    fi
    [ -d "$CLAIMS" ] || { echo "no claims directory"; return 0; }
    n=0
    for c in "$CLAIMS"/*; do
        [ -d "$c" ] || continue
        tag=$(basename "$c")
        fam=${tag%%_*}; rest=${tag#*_}
        if [ ! -f "$POOL/${fam}_${rest}.dta" ]; then
            rmdir "$c" 2>/dev/null && n=$(( n + 1 ))
        fi
    done
    echo "released $n stale claim(s)"
}

case "${1:-all}" in
    prep)    cmd_prep ;;
    run)     cmd_run ;;
    status)  cmd_status ;;
    combine) cmd_combine ;;
    unclaim) cmd_unclaim ;;
    all)     cmd_prep && cmd_run && cmd_combine ;;
    *) echo "usage: $0 {prep|run|status|combine|unclaim|all}" >&2; exit 2 ;;
esac
