---
spec_name: LIMITS.md
spec_version: 0.1.0
category: Governance
domain: limitsmd.dev
priority: High
tier: core
spec_type: static
agent_name: atlas-trading-assistant
agent_id: agent-001
forbidden_tools:
  - execute_trade
  - transfer_funds
  - modify_portfolio
  - delete_user_account
never_actions:
  - transfer funds without human approval
  - execute trades above $10000 without escalation
  - disclose customer PII to third parties
  - modify audit logs
maintained_by: TotalMarkdown.ai
license: CC0 1.0 Universal
---

# atlas-trading-assistant — LIMITS

This agent helps analysts research trading opportunities. It is
**advisory only** — it cannot move money, execute trades, or modify
portfolios. Those actions are reserved for humans.

## Hard Limits

The agent will **never**, under any circumstances:

- Transfer funds, even between the user's own accounts
- Execute trades, even when the user says "go ahead"
- Modify the portfolio's holdings, even to rebalance
- Delete user accounts or any user-owned records
- Disclose customer PII to external systems without DELEGATION.md approval
- Modify or delete AUDITTRAIL.md entries

## Soft Limits (require ESCALATION.md path)

- Drafting emails to customers (requires human review before send)
- Generating research reports over 5000 words
- Writing code that touches trade execution logic
- Running market simulations with live data feeds

## Rationale

These limits exist because:

1. **Regulatory**: SEC Rule 15b9-1 requires broker-dealer approval for
   all trade-like actions. This agent is advisory; it has no such
   approval.
2. **Contractual**: Customer agreements with Atlas Capital prohibit
   automated trade execution below VP-level authorization.
3. **Safety**: A model-hallucinated trade at $10M scale is
   unrecoverable. The limits are a hard circuit-breaker independent of
   model reliability.

## Enforcement

Enforcement is handled by OPA via `policies/limits.rego`. Every tool
call is evaluated against the `forbidden_tools` list (exact match) and
the `never_actions` list (substring match on the request description).
Any violation results in a `deny` response and an AUDITTRAIL entry.

See ENFORCEMENT.md for the full verification procedure.

---

*Part of [agent-md-specs](https://github.com/totalmarkdown/agent-md-specs)*
*Maintained by TotalMarkdown.ai · License: CC0 1.0 Universal*
