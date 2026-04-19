package agent.delegation

# Evaluates whether the requesting agent is authorized under the
# delegation declared in `specs/DELEGATION.md`.
#
# Inputs:
#   input.agent_id       — SPIFFE ID (or equivalent) from ATTESTATION
#   input.delegation_id  — expected delegation id
#   input.action         — requested action
#   input.timestamp      — RFC3339 timestamp of the request
#
# Data:
#   data.specs.delegation.id
#   data.specs.delegation.delegatee
#   data.specs.delegation.scope[]
#   data.specs.delegation.valid_from
#   data.specs.delegation.valid_until
#   data.specs.delegation.sub_delegation_allowed
#
# Exposes:
#   data.agent.delegation.authorized       — bool
#   data.agent.delegation.denied_by[]      — rule IDs that fired
#   data.agent.delegation.denial_reasons[] — human-readable reasons

import rego.v1

default authorized := false

authorized if {
	count(denied_by) == 0
}

# Delegation must match the one referenced in the request
denied_by contains "delegation.id_mismatch" if {
	input.delegation_id != data.specs.delegation.id
}

# Delegatee identity must match the attesting agent
denied_by contains "delegation.delegatee_mismatch" if {
	input.agent_id != data.specs.delegation.delegatee
}

# Action must be in the delegated scope
denied_by contains "delegation.scope_mismatch" if {
	not input.action in data.specs.delegation.scope
}

# Request must be within the delegation's time bounds
denied_by contains "delegation.expired" if {
	now_ns := time.parse_rfc3339_ns(input.timestamp)
	valid_until_ns := time.parse_rfc3339_ns(data.specs.delegation.valid_until)
	now_ns > valid_until_ns
}

denied_by contains "delegation.not_yet_valid" if {
	now_ns := time.parse_rfc3339_ns(input.timestamp)
	valid_from_ns := time.parse_rfc3339_ns(data.specs.delegation.valid_from)
	now_ns < valid_from_ns
}

# Sub-delegation must not be attempted when disallowed
denied_by contains "delegation.sub_delegation_forbidden" if {
	data.specs.delegation.sub_delegation_allowed == false
	input.action == "delegate_to_other_agent"
}

denial_reasons contains msg if {
	"delegation.id_mismatch" in denied_by
	msg := sprintf(
		"delegation_id '%v' does not match declared delegation '%v'",
		[input.delegation_id, data.specs.delegation.id],
	)
}

denial_reasons contains msg if {
	"delegation.delegatee_mismatch" in denied_by
	msg := sprintf(
		"agent_id '%v' does not match delegatee '%v'",
		[input.agent_id, data.specs.delegation.delegatee],
	)
}

denial_reasons contains msg if {
	"delegation.scope_mismatch" in denied_by
	msg := sprintf(
		"action '%v' is not in the delegated scope %v",
		[input.action, data.specs.delegation.scope],
	)
}

denial_reasons contains "delegation is expired (past valid_until)" if {
	"delegation.expired" in denied_by
}

denial_reasons contains "delegation not yet valid (before valid_from)" if {
	"delegation.not_yet_valid" in denied_by
}

denial_reasons contains "sub-delegation forbidden by this delegation" if {
	"delegation.sub_delegation_forbidden" in denied_by
}
