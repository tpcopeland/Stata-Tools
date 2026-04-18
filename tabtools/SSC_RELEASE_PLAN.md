# tabtools SSC Release Plan

## Objective

Ship `tabtools` as an SSC-ready package with package metadata, documentation, install behavior, and QA all defensible at journal-review standard.

## Current Status

As of 2026-04-18, the package already has broad command-level QA and consistent versioning at `1.0.7`. The remaining work is mainly release-gate discipline: prove that the shipped manifest is complete, that a fresh `net install` exposes every public command, that bundled helpers autoload through real user workflows, and that visible README/help examples run exactly as presented.

## Must-Pass Release Gates

1. Package integrity
   - `stata.toc`, `tabtools.pkg`, and `README.md` are present and synchronized.
   - Every shipped `.ado` and `.sthlp` in the package root appears in `tabtools.pkg`.
   - `tabtools.pkg` does not point to missing files.

2. Fresh-install behavior
   - `capture ado uninstall tabtools`
   - `net install tabtools, from("<package-dir>") replace`
   - `which` resolves every public command:
     `tabtools`, `table1_tc`, `regtab`, `effecttab`, `stratetab`, `hrcomptab`, `comptab`, `survtab`, `crosstab`, `diagtab`, `corrtab`
   - `findfile` resolves every bundled helper `.ado`.

3. Documentation reality
   - At least one visible README example runs unchanged after fresh install.
   - At least one visible `.sthlp` example runs unchanged after fresh install.
   - Output files are created where the docs say they will be created.

4. Full QA sweep
   - Run the new SSC gate test first.
   - Then run the full `qa/run_all.do` suite from `tabtools/qa`.
   - Treat any failure in installability, docs examples, or manifest integrity as a release blocker.

5. Submission hygiene
   - Release from a clean commit snapshot.
   - Exclude transient root-level logs and other non-package artifacts from any SSC bundle.
   - Rebuild any demo artifacts only from the release tree that passed QA.

## Evidence Collected In This Pass

- `check-versions.sh tabtools`: passed
- Static `.ado` validation: warnings only, no hard failures
- Existing QA suite: broad feature and output coverage already present
- New gate added: `qa/test_ssc_release_gates.do`

## Remaining Cautions

1. Root-level worker logs are still present in the package directory:
   - `tabtools_worker1_guard_verify.log`
   - `tabtools_worker1_smoke.log`
   These are not shipped by `tabtools.pkg`, but they should not be part of an SSC submission snapshot.

2. Validator output still shows advisory warnings around internal helper structure and permissive `capture` usage. Nothing surfaced as a release-blocking defect in this pass, but the warnings should be kept in mind if additional refactors happen before submission.

## Release Command Sequence

From `tabtools/qa`:

```bash
stata-mp -b do test_ssc_release_gates.do
stata-mp -b do run_all.do
```

From the repo root:

```bash
bash /home/tpcopeland/Stata-Dev/.claude/scripts/check-versions.sh tabtools
```

## Definition Of Done

`tabtools` is ready for SSC when all of the following are true on the exact release tree:

- version check passes
- `test_ssc_release_gates.do` passes
- `qa/run_all.do` passes
- release snapshot is clean and free of transient logs
- the SSC bundle is built from that same passing tree
