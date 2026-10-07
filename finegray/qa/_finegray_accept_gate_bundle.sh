#!/usr/bin/env bash
# Usage: bash qa/_finegray_accept_gate_bundle.sh qa/run_status_gates.pointer
# Run only after fresh gates are reviewed. Never call to silence failed gates.
set -euo pipefail
qa="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$qa/_finegray_receipt.sh"
pointer="${1:?supply the freshly reviewed gates pointer}"
fg_receipt_verify "$qa" "$pointer"
read -r id index < "$pointer"
bundle="$qa/receipts/$id"
grep -Eq '^lane:[[:space:]]+gates$' "$bundle/receipt.txt"
grep -Eq '^verdict:[[:space:]]+PASS$' "$bundle/receipt.txt"
[[ "$(grep -c '^RESULT: run_all tests=3 pass=3 fail=0 skip=0$' "$bundle/receipt.txt")" == 1 ]]
commit="$(cat "$bundle/head.txt")"
[[ "$commit" =~ ^[[:xdigit:]]{40}$ ]]
engine="$(awk '$2 == "_finegray_mata.ado" {print $1}' "$bundle/inputs.before.sha256")"
[[ "$engine" =~ ^[[:xdigit:]]{64}$ ]]
archived="$(sha256sum "$bundle/inputs/_finegray_mata.ado")"
current="$(sha256sum "$qa/../_finegray_mata.ado")"
[[ "${archived%% *}" == "$engine" && "${current%% *}" == "$engine" ]]
pin=$(mktemp "$qa/.gates-pin.XXXXXX")
printf 'gated_commit: %s\nengine_sha256: %s\ncalibration_bundle: %s\ncalibration_index_sha256: %s\n' "$commit" "$engine" "$id" "$index" > "$pin"
mv "$pin" "$qa/gates_transfer_pin.txt"
