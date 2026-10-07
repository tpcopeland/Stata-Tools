#!/usr/bin/env bash
# Source from run_all.sh; caller checks each function's return status.
fg_capture_inputs() {
    local repository="$1" package="$2" executed="$3" rel within digest n=0
    local paths actual ignore_rc
    local has_git=0
    git -C "$repository" rev-parse --git-dir >/dev/null 2>&1 && has_git=1
    FG_CAPTURE_MISSING=0
    paths=$(mktemp "${TMPDIR:-/tmp}/fg-input-paths.XXXXXX") || return 1
    actual=$(mktemp "${TMPDIR:-/tmp}/fg-executed-paths.XXXXXX") || return 1
    : > "$paths"
    if (( has_git )); then
        git -C "$repository" ls-files --cached --others --exclude-standard -z -- "$package" > "$paths" || return 1
    fi
    find "$executed" -type f ! -path "$executed/qa/receipts/*" -printf '%P\0' > "$actual" || return 1
    # Include nonignored executed-copy inputs absent from the originating tree.
    while IFS= read -r -d '' within; do
        if (( has_git )) && git -C "$repository" check-ignore -q -- "$package/$within"; then
            continue
        else
            ignore_rc=$?
            (( has_git == 0 || ignore_rc == 1 )) || return 1
        fi
        printf '%s\0' "$package/$within" >> "$paths"
    done < "$actual"
    while IFS= read -r -d '' rel; do
        within="${rel#"$package"/}"
        if [[ "$within" == qa/* && "${within#qa/}" != */* ]]; then
            case "${within#qa/}" in
                *.csv|*.dta|*.xlsx|*.gph|*.png|*.log|*.smcl) continue ;;
            esac
        fi
        case "$within" in
            qa/data/*|qa/gates_transfer/*.log|qa/.*.pointer.*|qa/run_all_status.txt|qa/run_all_inputs.sha256|qa/run_status_*.txt|qa/run_status_*.pointer|qa/receipts/*|qa/gates_transfer/PROVENANCE.txt) continue ;;
        esac
        if [[ ! -f "$executed/$within" ]]; then
            printf 'missing input: %s\n' "$within" >&2
            FG_CAPTURE_MISSING=$((FG_CAPTURE_MISSING + 1))
            continue
        fi
        n=$((n + 1))
        digest=$(sha256sum -- "$executed/$within") || return 1
        digest="${digest%% *}"
        printf '%s  %s\n' "$digest" "$within"
    done < <(LC_ALL=C sort -zu "$paths")
    rm -f -- "$paths" "$actual"
    (( n > 0 ))
}
fg_receipt_begin() {
    local repository="$1" package="$2" executed="$3" lane="$4" qa="$5"
    local stamp
    stamp="${lane}-$(date -u +%Y%m%dT%H%M%SZ)-$$"
    mkdir -p "$qa/receipts" || return 1
    FG_RECEIPT_STAGE=$(mktemp -d "$qa/receipts/.${stamp}.XXXXXX") || return 1
    FG_RECEIPT_ID="${FG_RECEIPT_STAGE##*/}"; FG_RECEIPT_ID="${FG_RECEIPT_ID#.}"
    FG_RECEIPT_REPOSITORY="$repository"; FG_RECEIPT_PACKAGE="$package"
    FG_RECEIPT_EXECUTED="$executed"; FG_RECEIPT_QA="$qa"; FG_RECEIPT_LANE="$lane"
    fg_capture_inputs "$repository" "$package" "$executed" > "$FG_RECEIPT_STAGE/inputs.before.sha256" || return 1
    FG_RECEIPT_INPUTS_MISSING="$FG_CAPTURE_MISSING"
    mkdir -p "$FG_RECEIPT_STAGE/inputs" || return 1
    local input_line input_rel
    while IFS= read -r input_line; do
        input_rel="${input_line:66}"
        mkdir -p "$FG_RECEIPT_STAGE/inputs/$(dirname "$input_rel")" || return 1
        cp -p -- "$executed/$input_rel" "$FG_RECEIPT_STAGE/inputs/$input_rel" || return 1
    done < "$FG_RECEIPT_STAGE/inputs.before.sha256"
    (cd "$FG_RECEIPT_STAGE/inputs" && sha256sum -c --strict ../inputs.before.sha256 >/dev/null) || return 1
    if git -C "$repository" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$repository" rev-parse HEAD > "$FG_RECEIPT_STAGE/head.txt" || return 1
        git -C "$repository" status --porcelain -- "$package" > "$FG_RECEIPT_STAGE/status.txt" || return 1
        git -C "$repository" diff --binary HEAD -- "$package" > "$FG_RECEIPT_STAGE/working-tree.diff" || return 1
        printf 'origin: git; scope: package code and frozen fixtures; sibling/runtime inputs not archived\n' > "$FG_RECEIPT_STAGE/scope.txt"
    else
        printf 'unknown (no git provenance)\n' > "$FG_RECEIPT_STAGE/head.txt"
        printf 'unknown (no git provenance)\n' > "$FG_RECEIPT_STAGE/status.txt"
        printf 'no originating git diff available\n' > "$FG_RECEIPT_STAGE/working-tree.diff"
        printf 'origin: no-git; scope: executed package code and frozen fixtures; generated qa/data and sibling/runtime inputs not archived\n' > "$FG_RECEIPT_STAGE/scope.txt"
    fi
}
fg_receipt_verify() {
    local qa="$1" pointer="$2" id digest extra observed
    IFS=' ' read -r id digest extra < "$pointer" || return 1
    [[ -z "${extra:-}" && "$id" =~ ^[[:alnum:]_.-]+$ && "$digest" =~ ^[[:xdigit:]]{64}$ ]] || return 1
    [[ "$id" != .* && -d "$qa/receipts/$id" ]] || return 1
    observed=$(sha256sum -- "$qa/receipts/$id/SHA256SUMS") || return 1
    [[ "${observed%% *}" == "$digest" ]] || return 1
    (cd "$qa/receipts/$id" && sha256sum -c --strict SHA256SUMS >/dev/null) || return 1
}
fg_receipt_finish() {
    local qa="$FG_RECEIPT_QA" stage="$FG_RECEIPT_STAGE" base final digest pointer
    (( FG_RECEIPT_INPUTS_MISSING == 0 )) || { echo "missing inputs: FAIL receipt only, no verified bundle" >&2; return 1; }
    fg_capture_inputs "$FG_RECEIPT_REPOSITORY" "$FG_RECEIPT_PACKAGE" "$FG_RECEIPT_EXECUTED" > "$stage/inputs.after.sha256" || return 1
    cmp -s "$stage/inputs.before.sha256" "$stage/inputs.after.sha256" || { echo 'input files changed during QA' >&2; return 1; }
    cp -- "$qa/run_all_status.txt" "$stage/receipt.txt" || return 1
    cp -- "$qa/run_all.log" "$stage/run_all.log" || return 1
    while IFS= read -r base; do
        [[ "$base" =~ ^[[:alnum:]_]+$ ]] || return 1
        cp -- "$qa/$base.log" "$stage/$base.log" || return 1
    done < <(sed -n 's/^=== Running: \([[:alnum:]_]\{1,\}\)\.do ===$/\1/p' "$qa/run_all.log")
    if [[ "$FG_RECEIPT_LANE" == full ]]; then
        if [[ -d "$qa/gates_transfer" ]]; then
            cp -a -- "$qa/gates_transfer" "$stage/" || return 1
        else
            if grep -Eq '^verdict:[[:space:]]+PASS$' "$qa/run_all_status.txt"; then
                echo 'required proof absent from a PASS run' >&2; return 1
            fi
            printf 'proof absent; verified evidence is a FAIL receipt only\n' > "$stage/gates_transfer.not-run.txt"
        fi
    fi
    printf '%s\n' "${fg02_output:-not-applicable}" > "$stage/fg02.txt" || return 1
    printf '%s\n' "${wrapper_output:-not-applicable}" > "$stage/wrapper.txt" || return 1
    (cd "$stage" && find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS && sha256sum -c --strict SHA256SUMS >/dev/null) || return 1
    final="$qa/receipts/$FG_RECEIPT_ID"
    [[ ! -e "$final" ]] || return 1
    mv -- "$stage" "$final" || return 1
    digest=$(sha256sum -- "$final/SHA256SUMS") || return 1
    pointer=$(mktemp "$qa/.${FG_RECEIPT_LANE}.pointer.XXXXXX") || return 1
    printf '%s %s\n' "$FG_RECEIPT_ID" "${digest%% *}" > "$pointer" || return 1
    fg_receipt_verify "$qa" "$pointer" || return 1
    mv -- "$pointer" "$qa/run_status_${FG_RECEIPT_LANE}.pointer" || return 1
}
