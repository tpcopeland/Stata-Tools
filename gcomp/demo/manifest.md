# gcomp demo manifest

Canonical generator: `demo_gcomp.do`. `demo_gcomptab.do` is a compatibility wrapper that invokes the same generator.

| Artifact | Deterministic contract |
|----------|------------------------|
| `demo_gcomptab.xlsx` | Rebuilt from a clean file; sheets in order: `Normal CI`, `Percentile CI`, `Component models` |
| `component_models.md` | Component-model table with full term identities and two model columns |

The generator uses fixed seeds and can be launched from the Stata-Tools root, the package root, or the `demo/` directory. Semantic QA checks sheet names, widths, merged cells, borders, wrapping, and content; byte hashes are not used because XLSX container metadata can differ without a semantic change.
