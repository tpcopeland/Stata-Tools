# tabtools QA layout

`qa/` is organized by command where the suite is command-scoped:

- `comptab/`
- `corrtab/`
- `crosstab/`
- `diagtab/`
- `effecttab/`
- `hrcomptab/`
- `regtab/`
- `stratetab/`
- `tabtools/`

`_package/` holds QA that is genuinely cross-command or package-wide:

- feature/version sweeps
- release gates
- mixed validation suites
- package-wide regressions
- cross-validation utilities

Run the full suite from the `qa/` root so existing path assumptions stay valid:

```bash
cd /home/tpcopeland/Stata-Tools/tabtools/qa
stata-mp -b do run_all.do
```

Logs and generated outputs remain at the `qa/` root and under the existing
`output*`, `baseline/`, and `data/` directories.
