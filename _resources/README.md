# _resources

Repository-level resources. Nothing in this folder is part of any package's `net install` payload.

| Path | What it is |
| --- | --- |
| [`logo-hex.svg`](logo-hex.svg) | Stata-Tools logo (text outlined from Noto Sans ExtraBold, SIL OFL) |
| [`gallery/`](gallery) | The six figures at the top of the main README. Each `gallery_<name>.do` regenerates its `<name>.png`; the kmplot panel comes from `kmplot/demo/demo_kmplot.do` |
| [`quickstart/`](quickstart) | The README quickstart as a runnable `quickstart.do`, plus the figure it produces |
| [`stata-docs/`](stata-docs) | `stata_docs.py`, which turns your own Stata PDF manuals into an offline, searchable library for you or a coding assistant. See its [README](stata-docs/README.md) |

Run the gallery and quickstart scripts with the working directory at the repository root:

```stata
cd "/path/to/Stata-Tools"
do _resources/gallery/gallery_eplot_outcomes.do
```

The gallery scripts install the packages they use from the neighbouring folders of this checkout and read the synthetic data in [`_data/`](../_data). The quickstart installs from GitHub, exactly as a new user would.
