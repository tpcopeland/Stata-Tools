#!/usr/bin/env bash
set -euo pipefail

qa_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
pkg_dir=$(dirname "$qa_dir")

# qa/output is explicitly disposable and gitignored. Keep tracked data,
# baseline, demo, and fixture directories outside this target.
if [[ -d "$qa_dir/output" ]]; then
    find "$qa_dir/output" -mindepth 1 -delete
fi

# Remove only ignored runtime artifacts from the QA and package roots.
for root in "$qa_dir" "$pkg_dir"; do
    while IFS= read -r -d '' candidate; do
        if git -C "$pkg_dir" check-ignore -q "$candidate"; then
            rm -f -- "$candidate"
        fi
    done < <(
        find "$root" -maxdepth 1 -type f \
            \( -name '*.log' -o -name '*.smcl' -o -name '*.xlsx' \
               -o -name '*.dta' -o -name '*.csv' -o -name '*.xml' \) -print0
    )
done

printf 'Removed ignored tabtools QA artifacts.\n'
