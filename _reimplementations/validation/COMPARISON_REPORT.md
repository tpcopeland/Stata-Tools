# Cross-Language Validation Report: Stata vs Python vs R tvtools

**Generated:** 2025-12-26  
**Test Data:** cohort.dta (1,000 patients), hrt.dta (1,858 HRT prescriptions), dmt.dta (1,865 DMT prescriptions)

---

## Executive Summary

All three implementations (Stata, Python, R) produce **IDENTICAL** results across all tested functions and options.

### tvexpose Tests

| Test | Stata | Python | R | Status |
|------|-------|--------|---|--------|
| Basic tvexpose | 4,036 rows | 4,036 rows | 4,036 rows | ✓ EXACT |
| Evertreated | 1,998 rows | 1,998 rows | 1,998 rows | ✓ EXACT |
| Currentformer | 3,738 rows | 3,738 rows | 3,738 rows | ✓ EXACT* |
| Lag (30 days) | 4,087 rows | 4,087 rows | 4,087 rows | ✓ EXACT |
| Washout (30 days) | 3,952 rows | 3,952 rows | 3,952 rows | ✓ EXACT |

### tvmerge Tests

| Test | Stata | Python | R | Status |
|------|-------|--------|---|--------|
| 2-dataset merge | 6,887 rows | 6,887 rows | 6,887 rows | ✓ EXACT |
| Person-time | 1,925,591 days | 1,925,591 days | 1,925,591 days | ✓ EXACT |

### tvevent Tests

| Test | Stata | Python | R | Status |
|------|-------|--------|---|--------|
| Single event | 3,605 rows | 3,605 rows | 3,605 rows | ✓ EXACT |
| Person-time | 1,668,458 days | 1,668,458 days | 1,668,458 days | ✓ EXACT |
| Events flagged | 278 | 278 | 278 | ✓ EXACT* |

*Semantic match: implementations use different value representations (numeric vs text labels)

---

## Detailed Results

### 1. tvexpose - Basic

| Metric | Stata | Python | R |
|--------|-------|--------|---|
| Row count | 4,036 | 4,036 | 4,036 |
| Person-time | 1,925,591 days | 1,925,591 days | 1,925,591 days |
| Row-by-row match | — | 100% | 100% |

### 2. tvexpose - Currentformer

| Category | Stata | Python | R |
|----------|-------|--------|---|
| Never | 777,194 days | 777,194 days | 777,194 days |
| Current | 317,049 days | 317,049 days | 317,049 days |
| Former | 831,348 days | 831,348 days | 831,348 days |
| **Total** | 1,925,591 days | 1,925,591 days | 1,925,591 days |

Note: Python/R use numeric codes (0/1/2), Stata uses text labels (Never/Current/Former).

### 3. tvexpose - Lag/Washout

| Option | No modifier | With modifier | Effect |
|--------|-------------|---------------|--------|
| Lag (30 days) | 317,049 exposed days | 272,399 exposed days | Reduces by 44,650 days ✓ |
| Washout (30 days) | 317,049 exposed days | 354,054 exposed days | Extends by 37,005 days ✓ |

### 4. tvmerge

Merges HRT and DMT exposure datasets into combined time-varying intervals.

| Metric | Value | Match |
|--------|-------|-------|
| Rows | 6,887 | ✓ All match |
| Persons | 1,000 | ✓ All match |
| Person-time | 1,925,591 days | ✓ All match |
| Row-by-row (id, start, stop) | 100% | ✓ All match |

### 5. tvevent

Integrates EDSS 4.0 outcome events into HRT exposure intervals.

| Metric | Value | Match |
|--------|-------|-------|
| Rows | 3,605 | ✓ All match |
| Person-time | 1,668,458 days | ✓ All match |
| Events (EDSS 4.0 reached) | 278 | ✓ All match |
| Censored observations | 3,327 | ✓ All match |

Note: Python uses numeric (0=censored, 1=event), R/Stata use text labels.

---

## Value Representation Differences

The implementations use different representations for categorical values:

| Variable | Stata | Python | R |
|----------|-------|--------|---|
| Unexposed | "Unexposed" | 0 | 0 |
| Exposure types | Text labels | Numeric codes | Numeric codes |
| Never/Current/Former | Text labels | 0/1/2 | 0/1/2 |
| Event outcome | Text labels | 0/1 | Text labels |

**All representations are semantically equivalent and verified to match row-by-row.**

---

## Person-Time Conservation

All implementations preserve total person-time:

| Stage | Person-Time | Conservation |
|-------|-------------|--------------|
| Original cohort | 1,925,591 days | — |
| After tvexpose | 1,925,591 days | 100% ✓ |
| After tvmerge | 1,925,591 days | 100% ✓ |
| After tvevent | 1,668,458 days | Expected (censored at event) ✓ |

---

## Conclusion

The tvtools package has been **fully validated** across three programming languages:

| Implementation | Version | Status |
|----------------|---------|--------|
| Stata | tvexpose.ado v1.0.0 | ✓ Reference |
| Python | tvtools v0.2.0 | ✓ Validated |
| R | tvtools v0.1.0 | ✓ Validated |

**All functions produce identical results:**
- `tvexpose`: 5/5 option tests pass (basic, evertreated, currentformer, lag, washout)
- `tvmerge`: Row counts, person-time, and row-by-row values match exactly
- `tvevent`: Row counts, person-time, and event counts match exactly

The reimplementations are **production-ready** and can be used interchangeably with the Stata version.
