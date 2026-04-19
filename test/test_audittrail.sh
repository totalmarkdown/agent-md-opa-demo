#!/usr/bin/env bash
# Focused test: validates AUDITTRAIL entry shape and hash-chain integrity.
#
# Runs the full-flow script first (which writes 3 entries), then:
#   1. Checks every entry has all required fields per AUDITTRAIL.md schema.
#   2. Verifies the hash chain end-to-end.

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

FAILURES=0
log_scenario "Prerequisite: run full flow"

# Suppress full-flow output; we only need the log file it produces.
"$(dirname "$0")/test_full_flow.sh" >/dev/null

REQUIRED_FIELDS=(timestamp agent_id delegation_id action decision \
                 decision_reasons input_hash previous_entry_hash)

log_scenario "AUDITTRAIL — entry schema"

n=0
while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    n=$((n + 1))
    for f in "${REQUIRED_FIELDS[@]}"; do
        if ! jq -e --arg f "$f" 'has($f)' <<<"$entry" >/dev/null; then
            log_fail "entry $n missing required field: $f"
        fi
    done
    # decision must be allow|deny
    dec=$(jq -r '.decision' <<<"$entry")
    if [[ "$dec" != "allow" && "$dec" != "deny" ]]; then
        log_fail "entry $n has invalid decision: $dec"
    fi
    # decision_reasons must be an array
    if ! jq -e '.decision_reasons | type == "array"' <<<"$entry" >/dev/null; then
        log_fail "entry $n decision_reasons is not an array"
    fi
    # input_hash must be sha256:<hex>
    if ! jq -e '.input_hash | test("^sha256:[0-9a-f]+$")' <<<"$entry" >/dev/null; then
        log_fail "entry $n input_hash malformed"
    fi
    # previous_entry_hash must be sha256:GENESIS or sha256:<hex>
    if ! jq -e '.previous_entry_hash | test("^sha256:(GENESIS|[0-9a-f]+)$")' <<<"$entry" >/dev/null; then
        log_fail "entry $n previous_entry_hash malformed"
    fi
done < "$AUDIT_LOG"

if [[ $n -eq 0 ]]; then
    log_fail "audit log is empty"
else
    log_pass "$n entries have all required fields and valid shapes"
fi

log_scenario "AUDITTRAIL — hash chain"
verify_chain || FAILURES=$((FAILURES + 1))

[[ $FAILURES -eq 0 ]] || exit 1
log_pass "test_audittrail.sh OK"
