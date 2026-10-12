"""Sibling trees tabtools QA reads through `repo_dir'/<dep>.

A scratch copy of the package (an isolated or sharded lane) must stage these
next to tabtools/, or suites fail for reasons unrelated to tabtools:
_data (example datasets), eplot (test_package_integration's eplot bridge),
logdoc and tc_schemes (test_package_release's demo rebuild).

Scratch-copy builders read this tuple statically; nothing here is executed.
"""

SANDBOX_DEPENDENCIES = ("_data", "eplot", "logdoc", "tc_schemes")
