package agent.limits

# This policy reads agent/LIMITS.md directly, extracts the YAML
# frontmatter, and decides whether to allow or deny a tool-call request.
#
# input format (JSON):
#   {
#     "agent_id": "agent-001",
#     "tool": "web_search",
#     "description": "Search for AAPL recent filings"
#   }
#
# output:
#   {
#     "allow": <bool>,
#     "reason": <string>,
#     "matched_rule": <string>
#   }

import rego.v1

default allow := false
default reason := ""
default matched_rule := ""

# ---------- frontmatter parsing ----------

limits_raw := data.limits_markdown

# Extract everything between the first `---` and the next `---`.
# Rego's regex.find_n doesn't support (?s); we split manually instead.
_parts := split(limits_raw, "---\n")

frontmatter_text := _parts[1]

frontmatter := yaml.unmarshal(frontmatter_text)

# ---------- allow rule ----------

allow if {
    not denied
}

# ---------- deny rules ----------

denied if {
    some forbidden in frontmatter.forbidden_tools
    input.tool == forbidden
}

denied if {
    some never in frontmatter.never_actions
    contains(lower(input.description), lower(never))
}

# ---------- reason / matched_rule (for audit trail) ----------

reason := msg if {
    some forbidden in frontmatter.forbidden_tools
    input.tool == forbidden
    msg := sprintf("tool '%s' is in forbidden_tools", [input.tool])
}

reason := msg if {
    some never in frontmatter.never_actions
    contains(lower(input.description), lower(never))
    msg := sprintf("request matches never_actions rule: '%s'", [never])
}

reason := "no matching rule; allow" if {
    not denied
}

matched_rule := "forbidden_tools" if {
    some forbidden in frontmatter.forbidden_tools
    input.tool == forbidden
}

matched_rule := "never_actions" if {
    some never in frontmatter.never_actions
    contains(lower(input.description), lower(never))
    not input.tool in frontmatter.forbidden_tools
}

matched_rule := "" if {
    not denied
}
