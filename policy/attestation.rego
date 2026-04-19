package agent.attestation

# Evaluates whether the requesting agent's identity can be verified
# against the declaration in `specs/ATTESTATION.md`.
#
# Inputs:
#   input.agent_id        — the claimed agent identifier
#   input.attestation_token — the bearer claim presented at runtime
#   input.timestamp       — RFC3339 timestamp of the request
#
# Data:
#   data.specs.attestation.identity_method
#   data.specs.attestation.identity_value
#   data.specs.attestation.valid_from
#   data.specs.attestation.valid_until
#   data.specs.attestation.issuer_fingerprint
#
# Exposes:
#   data.agent.attestation.verified        — bool
#   data.agent.attestation.denied_by[]     — rule IDs that fired
#   data.agent.attestation.denial_reasons[]

import rego.v1

default verified := false

verified if {
	count(denied_by) == 0
}

# The claimed agent_id must match the attested identity_value
denied_by contains "attestation.identity_mismatch" if {
	input.agent_id != data.specs.attestation.identity_value
}

# The attestation must be within its valid window
denied_by contains "attestation.expired" if {
	now_ns := time.parse_rfc3339_ns(input.timestamp)
	valid_until_ns := time.parse_rfc3339_ns(data.specs.attestation.valid_until)
	now_ns > valid_until_ns
}

denied_by contains "attestation.not_yet_valid" if {
	now_ns := time.parse_rfc3339_ns(input.timestamp)
	valid_from_ns := time.parse_rfc3339_ns(data.specs.attestation.valid_from)
	now_ns < valid_from_ns
}

# The attestation token must be present and non-empty
denied_by contains "attestation.token_missing" if {
	not input.attestation_token
}

denied_by contains "attestation.token_missing" if {
	input.attestation_token == ""
}

# Token prefix check — real integrations would verify the SVID JWT or
# X.509 chain; this is a shape check to demonstrate the pattern.
denied_by contains "attestation.token_malformed" if {
	input.attestation_token
	not startswith(input.attestation_token, "eyJ") # JWT prefix
	not startswith(input.attestation_token, "-----BEGIN") # X.509 prefix
}

denial_reasons contains msg if {
	"attestation.identity_mismatch" in denied_by
	msg := sprintf(
		"claimed agent_id '%v' does not match attested identity_value '%v'",
		[input.agent_id, data.specs.attestation.identity_value],
	)
}

denial_reasons contains "attestation credential expired (past valid_until)" if {
	"attestation.expired" in denied_by
}

denial_reasons contains "attestation credential not yet valid (before valid_from)" if {
	"attestation.not_yet_valid" in denied_by
}

denial_reasons contains "attestation token was not presented" if {
	"attestation.token_missing" in denied_by
}

denial_reasons contains "attestation token does not look like a recognized credential format (JWT or X.509)" if {
	"attestation.token_malformed" in denied_by
}
