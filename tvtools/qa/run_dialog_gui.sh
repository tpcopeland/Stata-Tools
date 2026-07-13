#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: run_dialog_gui.sh RESULT_FILE PLUS_DIR" >&2
    exit 198
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
result_file=$1
plus_dir=$2
run_dir=$(mktemp -d)

cleanup() {
    rm -rf "$run_dir"
}
trap cleanup EXIT

mkdir "$run_dir/personal"
ln -s "$script_dir/test_dialogs_gui.do" "$run_dir/profile.do"
export TVTOOLS_GUI_PLUS="$plus_dir"
export TVTOOLS_GUI_PERSONAL="$run_dir/personal"
export TVTOOLS_GUI_RESULT="$result_file"

rm -f "$result_file"
cd "$run_dir"
set +e
timeout --signal=TERM --kill-after=5s 20s xvfb-run -a xstata-mp -f0 -q
stata_rc=$?
set -e

if [[ ! -f "$result_file" ]]; then
    printf 'RESULT: dialog_gui tests=1 pass=0 fail=1 skip=0\nFAILED: harness_rc=%s\n' "$stata_rc" > "$result_file"
fi

expected="RESULT: dialog_gui tests=17 pass=17 fail=0 skip=0"
if [[ $stata_rc -ne 0 ]] || ! grep -Fqx "$expected" "$result_file"; then
    if [[ -f "$result_file" ]]; then
        cat "$result_file" >&2
    fi
    exit 9
fi
