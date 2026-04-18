#!/usr/bin/env bash
# End-to-end demo: runs each request in tests/requests.jsonl against
# the OPA policy, prints a decision, and appends to tests/audit.jsonl.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

command -v opa >/dev/null 2>&1 || { echo "Install OPA first: https://www.openpolicyagent.org/docs/latest/#1-download-opa" >&2; exit 1; }
command -v jq  >/dev/null 2>&1 || { echo "Install jq first" >&2; exit 1; }

: > tests/audit.jsonl

LIMITS_CONTENT="$(cat agent/LIMITS.md)"

idx=0
while IFS= read -r request; do
    idx=$((idx + 1))
    tool=$(jq -r '.tool' <<<"$request")
    desc=$(jq -r '.description' <<<"$request")
    agent=$(jq -r '.agent_id' <<<"$request")

    # Build OPA input with the LIMITS.md content injected as data.
    input_json=$(jq -nc --arg content "$LIMITS_CONTENT" --argjson req "$request" \
        '{input: $req, data: {limits_markdown: $content}}')

    allow=$(opa eval --stdin-input --data policies/limits.rego \
        --data <(echo "$input_json" | jq '.data') \
        'data.agent.limits.allow' <<<"$request" | jq -r '.result[0].expressions[0].value')

    reason=$(opa eval --stdin-input --data policies/limits.rego \
        --data <(echo "$input_json" | jq '.data') \
        'data.agent.limits.reason' <<<"$request" | jq -r '.result[0].expressions[0].value')

    matched_rule=$(opa eval --stdin-input --data policies/limits.rego \
        --data <(echo "$input_json" | jq '.data') \
        'data.agent.limits.matched_rule' <<<"$request" | jq -r '.result[0].expressions[0].value')

    if [ "$allow" = "true" ]; then
        label="ALLOW"
    else
        label="DENY "
    fi

    printf "▶ Request %d: %s wants to call \`%s\`\n" "$idx" "$agent" "$tool"
    printf "  OPA decision: %s   (%s)\n" "$label" "$reason"

    # Audit entry (AUDITTRAIL.md-shaped)
    jq -nc \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg agent "$agent" \
      --arg tool "$tool" \
      --arg decision "$label" \
      --arg reason "$reason" \
      --arg rule "$matched_rule" \
      '{
        timestamp: $ts,
        agent_id: $agent,
        event: "tool_call_request",
        tool: $tool,
        decision: $decision | ascii_downcase | gsub(" "; ""),
        reason: $reason,
        matched_rule: $rule,
        spec_source: "agent/LIMITS.md"
      }' >> tests/audit.jsonl
    printf "  Audit entry appended.\n\n"
done < tests/requests.jsonl

denied=$(grep -c '"decision":"deny"' tests/audit.jsonl || true)
total=$(wc -l < tests/audit.jsonl | tr -d ' ')
echo "Done. $total requests processed, $denied denied. See tests/audit.jsonl for the record."
