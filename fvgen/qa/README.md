# fvgen — QA suite

Tests for the `fvgen` command (flatten factor-variable interactions into
labeled main-effect and product variables).

## How to run

From this directory:

```bash
stata-mp -b do run_all.do          # full release gate (default)
stata-mp -b do run_all.do quick    # fastest functional smoke
stata-mp -b do run_all.do core     # functional + errors + validation
```

Each suite is independently runnable (`stata-mp -b do test_fvgen.do`) and
self-contained: it sandboxes `PLUS`/`PERSONAL` under `c(tmpdir)` and installs the
local package source before testing, so an installed or SSC copy cannot shadow
it. Paths are derived from `c(pwd)` — no machine paths are hardcoded.

## Conventions

- Counters + `RESULT: <name> tests=N pass=N fail=N` sentinel per file.
- `exit 1` on any failure.
- Fresh data per test via `_fvgen_make_data` (no tracked `.dta` fixtures).

## File index

| File | Purpose |
|------|---------|
| `_fvgen_qa_common.do` | Sandboxed-install bootstrap + seeded data builder |
| `test_fvgen.do` | Functional: surface, returns, naming, labels, options, missing, if/in, squared self-interaction, `ibn.` all-levels, weight-aware centering |
| `test_ref.do` | `ref()` per-factor reference levels: re-reference, equivalence to native `ibN.`, multi-var, quoted value-label strings, alllevels, no fvset mutation |
| `test_simple.do` | `simple()` per-group slopes: surface + labels, equivalence to native main+interaction, multi-level moderator, non-moderated main retained, `simple()`+`center` combined |
| `test_provenance.do` | Provenance chars (`fvgen_role`/`fvgen_term`) on main/interaction/centered vars; `fvgen, drop` teardown, returns, idempotence, absorbed-copy clearing, strict drop-only syntax, edge paths |
| `test_errors.do` | Failure paths: 3-way→198, >32-char name→198, collision→110, empty sample→2000, ref() 198/111, ref() bad label→198, simple() 198, omit operator `o.`→198, varabbrev restore on error and success |
| `validation_fvgen.do` | Known-answer: hand-computed values + exact equivalence to native `##` + centering invariance |
| `test_package_release.do` | Install smoke, autoload + second in-session call, documented examples |
| `run_all.do` | Curated lane runner |

## Coverage map

| Surface | Covered by |
|---------|-----------|
| cat×cont / cat×cat / cont×cont | `test_fvgen`, `validation_fvgen` |
| Value label → variable label (incl. `&`, `×`, embedded `"`) | `test_fvgen` (#2, #3) |
| Empty interaction-cell skipping; base dropped | `test_fvgen` (#4) |
| Missing propagation (dummies + products) | `test_fvgen` (#5), `validation_fvgen` (#1) |
| `alllevels`, `center`, `prefix()`, `xsymbol()`, `replace`, `if`/`in` | `test_fvgen` (#3,#6,#7,#8,#9,#10) |
| `ref()` per-factor reference + native `ibN.` equivalence; quoted value-label strings | `test_ref` |
| `simple()` per-group slopes + native main+interaction equivalence | `test_simple` |
| `simple()` + `center` combined (slope-invariance, absorbed centered copy) | `test_simple` (#5) |
| Squared self-interaction (`c.x##c.x`) label + values | `test_fvgen` (#11) |
| `ibn.` no-base materializes every level | `test_fvgen` (#12) |
| Weight-aware centering (aweight/pweight); weighted-mean known answer | `test_fvgen` (#13) |
| Provenance chars `fvgen_role`/`fvgen_term` (main/interaction/centered) | `test_provenance` (#1,#2) |
| `fvgen, drop` teardown: returns, idempotence, pass-through survival, strict syntax, edges | `test_provenance` (#3–#7) |
| `r(allvars/mainvars/intvars/genvars/k_all/k_main/k_int/spec)` | `test_fvgen` (#1) |
| `r(dropped)`/`r(k_dropped)` | `test_provenance` (#3,#4) |
| Exact reparameterization (coef + R² + N) vs native `##` | `validation_fvgen` (#2–#4) |
| Centering leaves interaction coef + fit unchanged | `validation_fvgen` (#5) |
| Error codes 198 / 110 / 2000; ref() bad label; omit operator `o.`; varabbrev restore | `test_errors`, `test_provenance` (#7) |
| Install / autoload / crash-on-rerun / doc examples | `test_package_release` |

## Lane membership

| Suite | quick | core | full |
|-------|:-----:|:----:|:----:|
| `test_fvgen` | ✓ | ✓ | ✓ |
| `test_ref` | | ✓ | ✓ |
| `test_simple` | | ✓ | ✓ |
| `test_errors` | | ✓ | ✓ |
| `test_provenance` | | ✓ | ✓ |
| `validation_fvgen` | | ✓ | ✓ |
| `test_package_release` | | | ✓ |
