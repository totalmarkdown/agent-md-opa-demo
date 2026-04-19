package agent.audittrail

# Produces an AUDITTRAIL.md-shaped entry for a single policy evaluation.
#
# Inputs:
#   input (the original request)
#   input.payload             — serialized request payload for hashing
#   input.output_payload      — (optional) serialized output for hashing
#
# Data:
#   data.specs.attestation.identity_value — → agent_id
#   data.specs.delegation.id              — → delegation_id
#   data.state.previous_entry_hash        — → previous_entry_hash (chain)
#   data.state.policy_version             — → policy_version
#   data.state.evaluator                  — → evaluator
#
# This module does not decide allow/deny — it formats the audit record
# once `main.rego` has computed `decision` and `decision_reasons`.
#
# Exposes:
#   data.agent.audittrail.entry — the full JSON object

import rego.v1

entry := {
	"timestamp": input.timestamp,
	"agent_id": data.specs.attestation.identity_value,
	"delegation_id": data.specs.delegation.id,
	"action": input.action,
	"decision": data.agent.main.decision,
	"decision_reasons": sort(data.agent.main.decision_reasons),
	"input_hash": input_hash,
	"output_hash": output_hash,
	"previous_entry_hash": previous_hash,
	"policy_version": policy_version,
	"evaluator": evaluator,
}

input_hash := hash if {
	input.payload
	hash := sprintf("sha256:%s", [crypto.sha256(input.payload)])
}

input_hash := "sha256:empty" if {
	not input.payload
}

output_hash := hash if {
	data.agent.main.decision == "allow"
	input.output_payload
	hash := sprintf("sha256:%s", [crypto.sha256(input.output_payload)])
}

output_hash := null if {
	data.agent.main.decision == "deny"
}

output_hash := null if {
	data.agent.main.decision == "allow"
	not input.output_payload
}

previous_hash := data.state.previous_entry_hash

policy_version := data.state.policy_version

evaluator := data.state.evaluator
