#!/usr/bin/env bash
# End-to-end demonstration of the 4-spec accountability chain:
#   ATTESTATION → DELEGATION → LIMITS → AUDITTRAIL
#
# Runs three scenarios:
#   1. HAPPY PATH       — valid attestation, in-scope action, no limits hit
#   2. SCOPE VIOLATION  — valid attestation, action OUTSIDE delegation.scope
#   3. IDENTITY FAILURE — attestation token malformed
#
# After every scenario, the generated AUDITTRAIL entry is shown. At the
# end, the hash chain is verified.

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

FAILURES=0

# Fresh audit log for each run of this script.
rm -f "$AUDIT_LOG"
mkdir -p "$AUDIT_DIR"

# ---------- scenario 1: HAPPY PATH ----------

log_scenario "Scenario 1: HAPPY PATH"
log_info "Agent: atlas | delegation: del-2026-04-a1b2c3d4 | action: read_financial_data"

happy_input=$(cat <<'JSON'
{
  "agent_id": "spiffe://acme.corp/finance/agents/atlas",
  "delegation_id": "del-2026-04-a1b2c3d4",
  "action": "read_financial_data",
  "description": "Fetch Q1 AAPL income statement",
  "payload": "filing_id=AAPL-10Q-2026-03",
  "timestamp": "2026-04-19T10:15:23Z",
  "attestation_token": "eyJhbGciOiJSUzI1NiJ9.fixture.fixture",
  "output_payload": "revenue=94.8B operating_income=27.8B"
}
JSON
)
input_file=$(mktemp -t agent-md-input.XXXXXX).json
echo "$happy_input" > "$input_file"

entry=$(evaluate_request "$input_file")
decision=$(jq -r '.decision' <<<"$entry")

if [[ "$decision" == "allow" ]]; then
    log_pass "decision = allow"
else
    log_fail "decision = $decision (expected allow)"
fi

log_dim "entry:"
jq . <<<"$entry" | sed 's/^/    /'

rm -f "$input_file"

# ---------- scenario 2: SCOPE VIOLATION ----------

log_scenario "Scenario 2: SCOPE VIOLATION"
log_info "Agent: atlas | action: send_email (NOT in delegation.scope)"

scope_input=$(cat <<'JSON'
{
  "agent_id": "spiffe://acme.corp/finance/agents/atlas",
  "delegation_id": "del-2026-04-a1b2c3d4",
  "action": "send_email",
  "description": "Send Q1 recap to client",
  "payload": "to=client@example.com&body=Q1_recap",
  "timestamp": "2026-04-19T10:16:45Z",
  "attestation_token": "eyJhbGciOiJSUzI1NiJ9.fixture.fixture"
}
JSON
)
input_file=$(mktemp -t agent-md-input.XXXXXX).json
echo "$scope_input" > "$input_file"

entry=$(evaluate_request "$input_file")
decision=$(jq -r '.decision' <<<"$entry")
reasons=$(jq -c '.decision_reasons' <<<"$entry")

if [[ "$decision" == "deny" ]]; then
    log_pass "decision = deny"
else
    log_fail "decision = $decision (expected deny)"
fi

if jq -e '.decision_reasons | index("delegation.scope_mismatch")' <<<"$entry" >/dev/null; then
    log_pass "delegation.scope_mismatch fired"
else
    log_fail "expected 'delegation.scope_mismatch' in $reasons"
fi

log_dim "entry:"
jq . <<<"$entry" | sed 's/^/    /'

rm -f "$input_file"

# ---------- scenario 3: IDENTITY FAILURE ----------

log_scenario "Scenario 3: IDENTITY FAILURE"
log_info "Agent: atlas | attestation_token: malformed (not a JWT / X.509)"

identity_input=$(cat <<'JSON'
{
  "agent_id": "spiffe://acme.corp/finance/agents/atlas",
  "delegation_id": "del-2026-04-a1b2c3d4",
  "action": "read_financial_data",
  "description": "Fetch Q1 AAPL income statement",
  "payload": "filing_id=AAPL-10Q-2026-03",
  "timestamp": "2026-04-19T10:18:07Z",
  "attestation_token": "not-a-real-credential"
}
JSON
)
input_file=$(mktemp -t agent-md-input.XXXXXX).json
echo "$identity_input" > "$input_file"

entry=$(evaluate_request "$input_file")
decision=$(jq -r '.decision' <<<"$entry")

if [[ "$decision" == "deny" ]]; then
    log_pass "decision = deny"
else
    log_fail "decision = $decision (expected deny)"
fi

if jq -e '.decision_reasons | index("attestation.token_malformed")' <<<"$entry" >/dev/null; then
    log_pass "attestation.token_malformed fired"
else
    log_fail "expected 'attestation.token_malformed' in decision_reasons"
fi

log_dim "entry:"
jq . <<<"$entry" | sed 's/^/    /'

rm -f "$input_file"

# ---------- chain verification ----------

log_scenario "Chain verification"
verify_chain || FAILURES=$((FAILURES + 1))

# ---------- summary ----------

echo
echo "${C_BOLD}Summary${C_RESET}"
echo "  Entries written: $(wc -l < "$AUDIT_LOG" | tr -d ' ')"
echo "  Audit log:       $AUDIT_LOG"

if [[ $FAILURES -gt 0 ]]; then
    echo "  Result:          ${C_RED}FAILED ($FAILURES assertion(s))${C_RESET}"
    exit 1
else
    echo "  Result:          ${C_GREEN}OK — all scenarios passed, chain verified${C_RESET}"
fi
