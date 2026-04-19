package agent.limits_test

import data.agent.limits
import rego.v1

# Synthetic LIMITS.md for tests — same shape as agent/LIMITS.md.
test_limits_markdown := `---
spec_name: LIMITS.md
forbidden_tools:
  - execute_trade
  - transfer_funds
never_actions:
  - transfer funds without human approval
  - execute trades above $10000 without escalation
---

# Body does not matter for policy eval.
`

test_allow_web_search if {
    result := limits.allow with data.limits_markdown as test_limits_markdown
        with input as {"agent_id": "agent-001", "tool": "web_search", "description": "Search AAPL filings"}
    result == true
}

test_deny_execute_trade if {
    result := limits.allow with data.limits_markdown as test_limits_markdown
        with input as {"agent_id": "agent-001", "tool": "execute_trade", "description": "Buy 100 AAPL"}
    result == false
}

test_deny_large_unauthorized_transfer if {
    result := limits.allow with data.limits_markdown as test_limits_markdown
        with input as {"agent_id": "agent-001", "tool": "send_funds", "description": "Execute trades above $10000 without escalation"}
    result == false
}

test_matched_rule_forbidden_tools if {
    rule := limits.matched_rule with data.limits_markdown as test_limits_markdown
        with input as {"agent_id": "agent-001", "tool": "transfer_funds", "description": "move money"}
    rule == "forbidden_tools"
}
