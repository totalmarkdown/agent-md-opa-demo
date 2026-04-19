package agent.main

# Orchestrates the 4-spec accountability chain:
#   1. ATTESTATION — can the agent prove its identity?
#   2. DELEGATION  — was the agent authorized for this action?
#   3. LIMITS      — is the tool or action in the deny list?
#   (4. AUDITTRAIL — formatted by audittrail.rego; this module feeds it)
#
# Exposes:
#   data.agent.main.allow              — bool
#   data.agent.main.decision           — "allow" | "deny"
#   data.agent.main.decision_reasons[] — rule IDs from sub-policies
#   data.agent.main.denial_messages[]  — human-readable messages

import rego.v1

default allow := false

allow if {
	data.agent.attestation.verified
	data.agent.delegation.authorized
	data.agent.limits.allowed
}

decision := "allow" if {
	allow
}

decision := "deny" if {
	not allow
}

# A unified list of positive rule IDs when everything passes, or the
# fired denial rule IDs when something fails. Always sorted by audittrail.
decision_reasons contains reason if {
	allow
	reason := "attestation.verified"
}

decision_reasons contains reason if {
	allow
	reason := "delegation.authorized"
}

decision_reasons contains reason if {
	allow
	reason := "limits.clear"
}

decision_reasons contains reason if {
	not allow
	some reason in data.agent.attestation.denied_by
}

decision_reasons contains reason if {
	not allow
	some reason in data.agent.delegation.denied_by
}

decision_reasons contains reason if {
	not allow
	some reason in data.agent.limits.denied_by
}

# Human-readable denial messages (union of sub-policy messages).
denial_messages contains msg if {
	some msg in data.agent.attestation.denial_reasons
}

denial_messages contains msg if {
	some msg in data.agent.delegation.denial_reasons
}

denial_messages contains msg if {
	some msg in data.agent.limits.denial_reasons
}
