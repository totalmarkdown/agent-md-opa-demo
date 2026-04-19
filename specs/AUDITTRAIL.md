---
spec_name: AUDITTRAIL.md
spec_version: 0.1.0
category: Compliance
domain: audittrailmd.dev
priority: Very High
tier: core
spec_type: runtime_schema
log_format: jsonl
tamper_resistance: hash_chain
hash_algorithm: sha256
retention_policy: "regulatory_max (7 years, SOC 2 CC7.3)"
storage_backend: "append_only_file"
last_integrity_check: "2026-04-19T00:00:00Z"
entry_schema:
  required:
    - timestamp
    - agent_id
    - delegation_id
    - action
    - decision
    - decision_reasons
    - input_hash
    - previous_entry_hash
  optional:
    - output_hash
    - policy_version
    - evaluator
maintained_by: TotalMarkdown.ai
license: CC0 1.0 Universal
---

# atlas-trading-assistant — AUDITTRAIL

## Audit Event Schema

Every policy evaluation produces exactly one audit entry. The entry is
appended as a single line to `audit/AUDITTRAIL.jsonl`.

Each entry is a JSON object with the following fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `timestamp` | ISO 8601 string | yes | Decision time, UTC. |
| `agent_id` | string | yes | The SPIFFE ID (or equivalent) from `ATTESTATION.md`. |
| `delegation_id` | string | yes | The `id` field from `DELEGATION.md`. |
| `action` | string | yes | The tool or action requested. |
| `decision` | `allow` \| `deny` | yes | Policy outcome. |
| `decision_reasons` | list of strings | yes | Rule IDs that fired (e.g. `limits.forbidden_tools`, `delegation.scope_mismatch`). |
| `input_hash` | `sha256:<hex>` | yes | SHA-256 of the canonical input JSON. |
| `output_hash` | `sha256:<hex>` or null | optional | SHA-256 of the action's output payload; `null` on deny. |
| `previous_entry_hash` | `sha256:<hex>` | yes | SHA-256 of the previous entry's canonical JSON; `sha256:GENESIS` for the first entry. |
| `policy_version` | string | optional | Policy bundle version for reproducibility. |
| `evaluator` | string | optional | OPA instance identifier. |

## Tamper Resistance

`tamper_resistance: hash_chain` — each entry's `previous_entry_hash`
points at the SHA-256 of the preceding entry's entire canonical JSON
(fields sorted, no whitespace). Verifying the chain end-to-end proves
no entries have been inserted, removed, or modified since the chain
was started.

The first entry uses the sentinel `sha256:GENESIS`.

Verification:

```bash
./test/verify_chain.sh audit/AUDITTRAIL.jsonl
# → CHAIN INTACT (N entries verified)
```

## Retention

`retention_policy: regulatory_max (7 years, SOC 2 CC7.3)` — the audit
log must be retained for at least 7 years in append-only storage.

## Storage Backend

`storage_backend: append_only_file` — for this demo, entries are
written to `audit/AUDITTRAIL.jsonl`. Production deployments would use
WORM (write-once, read-many) storage — e.g. AWS S3 Object Lock in
compliance mode, or a purpose-built immutable ledger.

## Example Entry

```json
{
  "timestamp": "2026-04-19T10:15:23Z",
  "agent_id": "spiffe://acme.corp/finance/agents/atlas",
  "delegation_id": "del-2026-04-a1b2c3d4",
  "action": "read_financial_data",
  "decision": "allow",
  "decision_reasons": ["limits.clear", "delegation.in_scope", "attestation.verified"],
  "input_hash": "sha256:4a7b2c9d...",
  "output_hash": "sha256:8f3e1d5a...",
  "previous_entry_hash": "sha256:GENESIS",
  "policy_version": "v0.2.0",
  "evaluator": "opa-1.15.2"
}
```

## Related Specs

- DELEGATION.md — source of `delegation_id`
- ATTESTATION.md — source of `agent_id`
- LIMITS.md — rule source for `decision_reasons` starting with `limits.`
- ENFORCEMENT.md — verification procedure for the audit log

---

*Part of [agent-md-specs](https://github.com/totalmarkdown/agent-md-specs)*
*Maintained by TotalMarkdown.ai · License: CC0 1.0 Universal*
