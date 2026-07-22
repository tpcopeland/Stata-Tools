# iivw SOL-04 coverage gate — runbook

Operating instructions for running the block-sharded coverage gate. Written for
an agent picking this up cold. Follow it in order; do not improvise the launch.

## 0. What this is

`validation_iivw_inference.do` asks whether the iivw bootstrap CI actually
covers the truth at 95%. It is a **nested bootstrap coverage study**:

```
1000 simulated datasets            (outer: measures coverage)
  └─ 999 bootstrap draws each      (inner: the thing under test)
       └─ each draw refits weights (Cox on ~10k panel rows, + a GLM)
```

≈999,000 model fits per family, three families (`iiw`, `fiptiw`, `iptw`). It is
genuinely expensive; that is why the interval originally shipped without
coverage evidence. It is not pathological and does not need "optimising."

**The acceptance rule is preregistered** (`TOLERANCE_FRAMEWORK.md` §3:
`COVERAGE_R=1000`, `COVERAGE_FLOOR=0.92`, `MCSE_K=3`). Do not tune it, do not
reinterpret a FAIL, do not re-run with a different seed hoping for green.

## 1. Machine prerequisites

This workload is **many single-threaded processes**, not one parallel one.
Stata-MP threading is a measured net loss here (see the header note in
`validation_iivw_inference.do`); the do-file now forces `processors=1`.

Before launching, confirm with the user that the VM has been sized. Host is a
5950X (16 cores / 32 threads). Recommended guest allocation is **24 vCPU** —
not 32, which starves the hypervisor and host. Changing vCPU count requires a
guest shutdown, so do it *before* starting a multi-hour run.

```bash
nproc                      # confirm the guest sees what you expect
uptime                     # load should be near 0 before you start
pgrep -x stata-mp | wc -l  # must be 0
```

**Do not run any other Stata work while the gate runs.** A concurrent
`run_all.do` will both distort timings and contend for cores.

## 2. Launch

```bash
cd /home/tpcopeland/Stata-Tools/iivw/qa

export BASE=/tmp/claude-1000/covgate     # scratch root; must NOT be inside the repo
export WORKERS=22                        # leave ~2 vCPU for the OS
export BLOCK=50                          # replications per block

./run_coverage_gate.sh prep
```

`prep` copies one isolated tree per block and writes `MANIFEST.txt` (sha256 of
every `.ado`/`.do`) plus `GIT_HEAD.txt`. That manifest is the record of *which
build produced the number* — keep it with the result.

### Calibrate before committing to the full run

Runtime at `REPS=999` has **not** been measured end to end. The plumbing was
verified at `REPS=10` (8 blocks, 1000 replications, 2m40s on 8 workers). Time
one real block first rather than trusting an extrapolation:

```bash
s=$(date +%s)
( cd "$BASE/work/iiw_00001_00050/iivw/qa" && \
  stata-mp -b do validation_iivw_inference.do iiw 1000 999 20260715 1 50 )
echo "one 50-rep iiw block: $(( $(date +%s) - s )) s"
```

Multiply by 60 blocks / `WORKERS` for a wall-clock estimate. Rough expectation
is **single-digit hours**, versus ~2.5 days for the old un-sharded run — but
report the measured number, not this sentence.

> **A pilot at a smaller `REPS` used to poison the real run** (found and fixed
> 2026-07-22). `run` skips any block whose `.dta` is already in the pool, and a
> block filename encodes only family and range — so a `REPS=10` pilot left 20
> files named exactly what the `REPS=999` run wanted. The real run skipped all
> of them and `combine` certified pilot rows as the release gate, printing
> `reps=999`. Measured: one pool combined to `gate=PASS sims=1000 reps=999`
> *and* `gate=PASS sims=1000 reps=10`, byte-identical coverage.
>
> Two changes make that unreachable. Pools are now segregated by configuration
> (`$BASE/blockpool/r<REPS>_s<SEED>`), so a pilot and the real run never share
> files; and every block row carries a `(reps, sims, seed)` stamp that
> `combine` verifies is constant across the union **and** equal to its own
> arguments, refusing at `r(459)` otherwise. Pilot freely — it can no longer
> contaminate the gate. Blocks produced before this change carry no stamp and
> are refused rather than assumed; re-run them.

### Run

```bash
nohup ./run_coverage_gate.sh run > "$BASE/run.out" 2>&1 &
```

`run` is a work queue (`xargs -P`), longest-family-first. It is **idempotent**:
a block whose rows are already in `$BASE/blockpool` is skipped, so an
interrupted run resumes by re-issuing the same command. No pinning is used —
single-threaded processes plus a queue load-balance better than static
`taskset` affinity, because block runtimes are uneven.

## 3. Monitor

```bash
./run_coverage_gate.sh status
```

Reports blocks complete per family, failed blocks, and live `stata-mp` count.
Check occasionally — every 20–30 minutes is plenty. Do not poll in a tight
loop.

Sanity checks while running:
- `uptime` load should sit near `WORKERS`, **not** far above it. Load ≫ workers
  means something is spawning threads and `processors=1` is not taking effect.
- `pgrep -x stata-mp | wc -l` should be ≤ `WORKERS`.
- Never `pgrep -f` a pattern matching your own command line — it matches itself.

## 4. Verdict

```bash
./run_coverage_gate.sh combine
```

This gathers every block's rows, proves the union **tiles 1..1000 exactly**, and
applies the acceptance **once per family**. It runs in under a second.

Expected output per family:

```
combine(iiw): 20 block(s), 1000 of 1000 replications (0 failed draw(s))
RESULT: validation_iivw_inference iiw gate=PASS sims=1000 reps=999 cov_refit=0.9xx
```

### Reading the result honestly

- **`stata-mp -b` always exits 0.** The exit status is not a verdict. Read the
  `RESULT:` line. The script already does this; don't "simplify" it to `$?`.
- A **block** never produces a verdict and exits 1 by design. That is not a
  failure. Only `combine_<family>` applies the gate.
- `NO VERDICT` means combine refused. Do not work around it. The two refusals
  are structural:
  - *"N replication(s) covered by NO block"* — a block never ran. Re-run
    `./run_coverage_gate.sh run` to fill the gap, then combine again.
  - *"covered by MORE THAN ONE block"* / *"duplicate (arm,sim) keys"* — the
    pool has overlapping ranges. Inspect the pool directory; do not delete
    files at random.
  - *"blocks were produced at blk_reps=N, but this combine was invoked with M"*
    / *"blocks disagree on blk_reps"* / *"block rows carry no blk_reps stamp"* —
    the pool was not produced by one configuration, or predates the provenance
    stamp. Do not "fix" this by re-invoking combine with the other number: that
    is precisely the mislabelling the check exists to stop. Re-run the blocks.
- `failed draw(s)` > 0 is legitimate (a replication that errored) and is
  distinct from a missing block. A large count is worth reporting, not hiding.
- A `gate=FAIL` is a **result**, not a problem to be fixed. Report it with
  `cov_refit` and the manifest. It is the finding the study exists to produce.

## 5. Reporting

Report: the `RESULT:` line per family, `GIT_HEAD.txt`, block count, failed-draw
count, wall-clock, and `WORKERS`. State plainly whether each family passed.
Do not write "complete" or "validated" — this run has had no independent review.

## Known-good invariants (verified 2026-07-21)

Verified by direct test, not inspection:

| Check | Evidence |
|---|---|
| 8 blocks × 125 reps tile and combine | 8/8 `OK`, verdict produced |
| Combine skips the simulation loop | >10 min → <1 s after the fix |
| Missing interior block refuses | deleted 376–500 → `first gap at sim 376` |
| Overlapping block refuses | duplicated a block → `r(459)` |
| Concurrent `net install` is safe | `iivw_qa_sandbox` sets a per-process `PLUS` |

### Added 2026-07-22 — permanent regression coverage

`qa/test_iivw_coverage_gate.do` now covers the aggregation machinery, which is
where a wrong coverage number gets manufactured at `rc=0`. Every arm fabricates
a block pool rather than simulating one — the contract is about which rows are
present and what they claim about themselves, not their values — so the whole
suite runs in **~1.3 s** and shells out to a real `combine_iiw` per arm.

| Arm | Asserts |
|---|---|
| G1 | a missing **interior** block refuses; no verdict |
| G2 | overlapping blocks refuse; no verdict |
| G3 | a complete consistent pool **reaches** the acceptance rule (positive control) |
| G4 | unstamped (pre-2026-07-22) blocks refuse |
| G5 | a `reps=10` pilot pool cannot be certified as `reps=999` |
| G6 | a pool mixing two configurations refuses |
| G7 | a mismatched master seed refuses |
| G8 | combine aggregates without re-running the study |
| G9 | a diagnostic run at a non-default `nsub` cannot reach a gate verdict |

Scored **4/8 against the pre-fix build, 9/9 after** — G4–G7 are the new
provenance defect. G1/G2/G3/G8 pass on both builds by design: they are the
regression coverage this section previously listed as missing, not evidence for
the 2026-07-22 change. Their teeth were shown separately with surgical mutants:
reverting the tiling proof to the old min/max check fails **G1 and only G1**;
removing the `rowsin()` loop guard leaves combine still running after **120 s**
against 0.07 s for the fixed build, and produces no verdict.

G3 asserts a verdict is *produced*, not that it is PASS-on-real-data — the rows
are fabricated. Only the real release run says anything about the estimator.

## Open items — not done

- The fixes to `validation_iivw_inference.do` have **not been through
  `/reviewer`** — the 2026-07-21 pair, and the 2026-07-22 provenance stamp.
  Per the mandatory chain they are "implemented, not reviewed".
- **The gate itself has never been run.** SOL-04 is untouched; no coverage
  number exists for any family.
- Full-`REPS` runtime is unmeasured (see §2).
- `run_coverage_gate.sh` is untested at `WORKERS=22`; it was exercised at
  `WORKERS=8`, and the pool-path change of 2026-07-22 has not been exercised by
  a real multi-block run at all.
