package agent.main_test

import data.agent.main
import rego.v1

# Synthetic test fixtures approximating the 4 specs in specs/.
# The `fixture_*` names deliberately avoid the `test_` prefix so OPA
# does not treat them as test cases.

fixture_specs := {
	"limits": {
		"forbidden_tools": ["execute_trade", "transfer_funds"],
		"never_actions": ["transfer funds without human approval"],
	},
	"delegation": {
		"id": "del-2026-04-a1b2c3d4",
		"delegatee": "spiffe://acme.corp/finance/agents/atlas",
		"scope": ["read_financial_data", "generate_reports"],
		"valid_from": "2026-04-01T00:00:00Z",
		"valid_until": "2026-07-01T00:00:00Z",
		"sub_delegation_allowed": false,
	},
	"attestation": {
		"identity_method": "spiffe",
		"identity_value": "spiffe://acme.corp/finance/agents/atlas",
		"valid_from": "2026-04-15T00:00:00Z",
		"valid_until": "2026-04-22T00:00:00Z",
	},
}

fixture_state := {
	"previous_entry_hash": "sha256:GENESIS",
	"policy_version": "v0.2.0",
	"evaluator": "opa-test",
}

# -------- HAPPY PATH --------

happy_input := {
	"agent_id": "spiffe://acme.corp/finance/agents/atlas",
	"delegation_id": "del-2026-04-a1b2c3d4",
	"action": "read_financial_data",
	"description": "Fetch Q1 AAPL income statement",
	"payload": "filing_id=AAPL-10Q-2026-03",
	"timestamp": "2026-04-19T10:15:23Z",
	"attestation_token": "eyJhbGciOiJSUzI1NiJ9.fixture.fixture",
}

test_allow_happy_path if {
	main.allow with input as happy_input
		with data.specs as fixture_specs
		with data.state as fixture_state
}

test_decision_is_allow_happy_path if {
	main.decision == "allow" with input as happy_input
		with data.specs as fixture_specs
		with data.state as fixture_state
}

# -------- SCOPE VIOLATION --------

scope_violation_input := {
	"agent_id": "spiffe://acme.corp/finance/agents/atlas",
	"delegation_id": "del-2026-04-a1b2c3d4",
	"action": "send_email",
	"description": "Send Q1 recap to client",
	"payload": "to=client@example.com",
	"timestamp": "2026-04-19T10:15:23Z",
	"attestation_token": "eyJhbGciOiJSUzI1NiJ9.fixture.fixture",
}

test_deny_scope_violation if {
	not main.allow with input as scope_violation_input
		with data.specs as fixture_specs
		with data.state as fixture_state
}

test_decision_is_deny_scope_violation if {
	main.decision == "deny" with input as scope_violation_input
		with data.specs as fixture_specs
		with data.state as fixture_state
}

test_scope_violation_reason_fires if {
	reasons := main.decision_reasons with input as scope_violation_input
		with data.specs as fixture_specs
		with data.state as fixture_state
	"delegation.scope_mismatch" in reasons
}

# -------- IDENTITY FAILURE (attestation expired) --------

identity_failure_input := {
	"agent_id": "spiffe://acme.corp/finance/agents/atlas",
	"delegation_id": "del-2026-04-a1b2c3d4",
	"action": "read_financial_data",
	"description": "Fetch Q1 AAPL income statement",
	"payload": "filing_id=AAPL-10Q-2026-03",
	"timestamp": "2026-04-30T10:15:23Z", # AFTER attestation valid_until 2026-04-22
	"attestation_token": "eyJhbGciOiJSUzI1NiJ9.fixture.fixture",
}

test_deny_attestation_expired if {
	not main.allow with input as identity_failure_input
		with data.specs as fixture_specs
		with data.state as fixture_state
}

test_attestation_expired_reason_fires if {
	reasons := main.decision_reasons with input as identity_failure_input
		with data.specs as fixture_specs
		with data.state as fixture_state
	"attestation.expired" in reasons
}

# -------- LIMITS GUARD (forbidden tool) --------

forbidden_tool_input := {
	"agent_id": "spiffe://acme.corp/finance/agents/atlas",
	"delegation_id": "del-2026-04-a1b2c3d4",
	"action": "execute_trade",
	"description": "Buy 100 AAPL at market",
	"payload": "ticker=AAPL&qty=100",
	"timestamp": "2026-04-19T10:15:23Z",
	"attestation_token": "eyJhbGciOiJSUzI1NiJ9.fixture.fixture",
}

test_deny_forbidden_tool if {
	not main.allow with input as forbidden_tool_input
		with data.specs as fixture_specs
		with data.state as fixture_state
}

test_forbidden_tool_reason_fires if {
	reasons := main.decision_reasons with input as forbidden_tool_input
		with data.specs as fixture_specs
		with data.state as fixture_state
	"limits.forbidden_tools" in reasons
}

# -------- MALFORMED ATTESTATION TOKEN --------

malformed_token_input := {
	"agent_id": "spiffe://acme.corp/finance/agents/atlas",
	"delegation_id": "del-2026-04-a1b2c3d4",
	"action": "read_financial_data",
	"description": "Fetch Q1 AAPL income statement",
	"payload": "filing_id=AAPL-10Q-2026-03",
	"timestamp": "2026-04-19T10:15:23Z",
	"attestation_token": "not-a-real-jwt",
}

test_deny_malformed_token if {
	not main.allow with input as malformed_token_input
		with data.specs as fixture_specs
		with data.state as fixture_state
}

test_malformed_token_reason_fires if {
	reasons := main.decision_reasons with input as malformed_token_input
		with data.specs as fixture_specs
		with data.state as fixture_state
	"attestation.token_malformed" in reasons
}
