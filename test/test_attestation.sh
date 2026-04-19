#!/usr/bin/env bash
# Focused test: exercises only ATTESTATION checks.

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

FAILURES=0
log_scenario "ATTESTATION — token_malformed"

tmp_log="$(mktemp -t audit.XXXXXX).jsonl"
AUDIT_LOG="$tmp_log"

input=$(mktemp -t input.XXXXXX).json
cat > "$input" <<'JSON'
{
  "agent_id": "spiffe://acme.corp/finance/agents/atlas",
  "delegation_id": "del-2026-04-a1b2c3d4",
  "action": "read_financial_data",
  "description": "Fetch AAPL 10-Q",
  "payload": "filing_id=AAPL-10Q-2026-03",
  "timestamp": "2026-04-19T10:15:23Z",
  "attestation_token": "not-a-real-credential"
}
JSON

entry=$(evaluate_request "$input")
jq -e '.decision == "deny"' <<<"$entry" >/dev/null && log_pass "malformed → deny" || log_fail "expected deny"
jq -e '.decision_reasons | index("attestation.token_malformed")' <<<"$entry" >/dev/null \
    && log_pass "attestation.token_malformed fired" \
    || log_fail "expected attestation.token_malformed"

log_scenario "ATTESTATION — expired"

input2=$(mktemp -t input.XXXXXX).json
cat > "$input2" <<'JSON'
{
  "agent_id": "spiffe://acme.corp/finance/agents/atlas",
  "delegation_id": "del-2026-04-a1b2c3d4",
  "action": "read_financial_data",
  "description": "Fetch AAPL 10-Q",
  "payload": "filing_id=AAPL-10Q-2026-03",
  "timestamp": "2026-05-01T00:00:00Z",
  "attestation_token": "eyJhbGciOiJSUzI1NiJ9.fixture.fixture"
}
JSON

entry=$(evaluate_request "$input2")
jq -e '.decision == "deny"' <<<"$entry" >/dev/null && log_pass "expired → deny" || log_fail "expected deny"
jq -e '.decision_reasons | index("attestation.expired")' <<<"$entry" >/dev/null \
    && log_pass "attestation.expired fired" \
    || log_fail "expected attestation.expired"

rm -f "$input" "$input2" "$tmp_log"
[[ $FAILURES -eq 0 ]] || exit 1
log_pass "test_attestation.sh OK"
