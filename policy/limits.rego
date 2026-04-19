package agent.limits

# Evaluates a tool-call request against the constraints declared in
# `specs/LIMITS.md` (provided via data.specs.limits).
#
# Inputs:
#   input.action       — the tool or action being requested
#   input.description  — natural-language description of the request
#
# Data:
#   data.specs.limits.forbidden_tools[]  — exact-match deny list
#   data.specs.limits.never_actions[]    — substring-match deny list
#
# Exposes:
#   data.agent.limits.allowed            — bool
#   data.agent.limits.denied_by[]        — rule IDs that fired
#   data.agent.limits.denial_reasons[]   — human-readable reasons

import rego.v1

default allowed := false

allowed if {
	count(denied_by) == 0
}

denied_by contains rule_id if {
	some forbidden in data.specs.limits.forbidden_tools
	input.action == forbidden
	rule_id := "limits.forbidden_tools"
}

denied_by contains rule_id if {
	some never in data.specs.limits.never_actions
	contains(lower(input.description), lower(never))
	rule_id := "limits.never_actions"
}

denial_reasons contains reason if {
	some forbidden in data.specs.limits.forbidden_tools
	input.action == forbidden
	reason := sprintf("action '%s' is in forbidden_tools", [input.action])
}

denial_reasons contains reason if {
	some never in data.specs.limits.never_actions
	contains(lower(input.description), lower(never))
	reason := sprintf("request matches never_actions rule: '%s'", [never])
}
