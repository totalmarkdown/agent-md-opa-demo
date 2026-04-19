#!/usr/bin/env bash
# Focused test: exercises only DELEGATION checks (scope and time-bounds).

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

FAILURES=0
log_scenario "DELEGATION — scope_mismatch"

tmp_log="$(mktemp -t audit.XXXXXX).jsonl"
AUDIT_LOG="$tmp_log"

input=$(mktemp -t input.XXXXXX).json
cat > "$input" <<'JSON'
{
  "agent_id": "spiffe://acme.corp/finance/agents/atlas",
  "delegation_id": "del-2026-04-a1b2c3d4",
  "action": "send_email",
  "description": "Send monthly newsletter to clients",
  "payload": "to=clients&body=newsletter",
  "timestamp": "2026-04-19T10:15:23Z",
  "attestation_token": "eyJhbGciOiJSUzI1NiJ9.fixture.fixture"
}
JSON

entry=$(evaluate_request "$input")

jq -e '.decision == "deny"' <<<"$entry" >/dev/null \
    && log_pass "decision = deny (action outside scope)" \
    || log_fail "expected deny"

jq -e '.decision_reasons | index("delegation.scope_mismatch")' <<<"$entry" >/dev/null \
    && log_pass "delegation.scope_mismatch fired" \
    || log_fail "expected delegation.scope_mismatch"

log_scenario "DELEGATION — expired"

input2=$(mktemp -t input.XXXXXX).json
cat > "$input2" <<'JSON'
{
  "agent_id": "spiffe://acme.corp/finance/agents/atlas",
  "delegation_id": "del-2026-04-a1b2c3d4",
  "action": "read_financial_data",
  "description": "Fetch Q1 AAPL",
  "payload": "filing_id=AAPL-10Q-2026-03",
  "timestamp": "2027-01-01T00:00:00Z",
  "attestation_token": "eyJhbGciOiJSUzI1NiJ9.fixture.fixture"
}
JSON

entry=$(evaluate_request "$input2")

jq -e '.decision == "deny"' <<<"$entry" >/dev/null \
    && log_pass "decision = deny (delegation expired)" \
    || log_fail "expected deny"

jq -e '.decision_reasons | index("delegation.expired")' <<<"$entry" >/dev/null \
    && log_pass "delegation.expired fired" \
    || log_fail "expected delegation.expired"

rm -f "$input" "$input2" "$tmp_log"
[[ $FAILURES -eq 0 ]] || exit 1
log_pass "test_delegation.sh OK"
