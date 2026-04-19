#!/usr/bin/env bash
# Focused test: exercises only the LIMITS guard.
# Runs one request against a forbidden tool and asserts the decision.

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

FAILURES=0
log_scenario "LIMITS — forbidden_tools"

tmp_log="$(mktemp -t audit.XXXXXX).jsonl"
AUDIT_LOG="$tmp_log"

input=$(mktemp -t input.XXXXXX).json
cat > "$input" <<'JSON'
{
  "agent_id": "spiffe://acme.corp/finance/agents/atlas",
  "delegation_id": "del-2026-04-a1b2c3d4",
  "action": "execute_trade",
  "description": "Buy 100 AAPL at market",
  "payload": "ticker=AAPL&qty=100",
  "timestamp": "2026-04-19T10:15:23Z",
  "attestation_token": "eyJhbGciOiJSUzI1NiJ9.fixture.fixture"
}
JSON

entry=$(evaluate_request "$input")

jq -e '.decision == "deny"' <<<"$entry" >/dev/null \
    && log_pass "decision = deny" \
    || log_fail "expected deny"

jq -e '.decision_reasons | index("limits.forbidden_tools")' <<<"$entry" >/dev/null \
    && log_pass "limits.forbidden_tools fired" \
    || log_fail "expected limits.forbidden_tools"

rm -f "$input" "$tmp_log"
[[ $FAILURES -eq 0 ]] || exit 1
log_pass "test_limits.sh OK"
