---
spec_name: DELEGATION.md
spec_version: 0.1.0
category: Governance
domain: delegationmd.dev
priority: Very High
tier: core
spec_type: static
id: del-2026-04-a1b2c3d4
delegator: "amelia.chen@acme.com"
delegator_role: "VP Finance, Atlas Capital"
delegatee: "spiffe://acme.corp/finance/agents/atlas"
scope:
  - read_financial_data
  - generate_reports
  - run_market_research
  - summarize_filings
valid_from: "2026-04-01T00:00:00Z"
valid_until: "2026-07-01T00:00:00Z"
revocation_endpoint: "https://iam.acme.corp/v1/delegations/del-2026-04-a1b2c3d4/revocation"
sub_delegation_allowed: false
max_transaction_value_usd: 0
authorization_ticket: "CAB-2026-Q2-117"
maintained_by: TotalMarkdown.ai
license: CC0 1.0 Universal
---

# atlas-trading-assistant — DELEGATION

## Delegating Principal

**Amelia Chen**, VP Finance, Atlas Capital, has delegated limited
read-only and reporting authority to the agent identified by
`spiffe://acme.corp/finance/agents/atlas` for the current quarter.

Authorization for this delegation comes from the Q2-2026 Change
Advisory Board under ticket CAB-2026-Q2-117 (internal IAM system).

## Delegation Scope

The agent is authorized to perform the following actions on behalf of
the delegator:

| Action | Scope notes |
|--------|-------------|
| `read_financial_data` | Non-PII financial data, US-region only. |
| `generate_reports` | Drafts only; human review required before send. |
| `run_market_research` | Public sources and Atlas Capital's research subscriptions. |
| `summarize_filings` | SEC filings via EDGAR API. |

All other actions — including any form of transaction execution,
customer communication, or PII access — are **outside scope** and must
be denied.

## Time Bounds

- Valid from: 2026-04-01T00:00:00Z
- Valid until: 2026-07-01T00:00:00Z (one quarter)
- Renewal: requires a new Change Advisory Board ticket.

## Revocation

Any party holding the delegator's credentials may revoke this
delegation at any time by posting to the revocation endpoint:

    POST https://iam.acme.corp/v1/delegations/del-2026-04-a1b2c3d4/revocation

Policy engines should check the revocation endpoint (or a signed
revocation list) at every evaluation. For this demo, we assume the
delegation has not been revoked.

## Sub-delegation

`sub_delegation_allowed: false` — this agent may **not** pass its
authority to another agent. Any attempt to do so must be denied and
logged in AUDITTRAIL.md.

## Transaction Limits

`max_transaction_value_usd: 0` — this delegation does not authorize
any value-bearing action. Any request that would move funds, regardless
of amount, is out of scope.

## Related Specs

- ATTESTATION.md — identity verification for the delegatee
- LIMITS.md — hard constraints that permissions cannot exceed
- AUDITTRAIL.md — every use of this delegation is logged

---

*Part of [agent-md-specs](https://github.com/totalmarkdown/agent-md-specs)*
*Maintained by TotalMarkdown.ai · License: CC0 1.0 Universal*
