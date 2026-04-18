# agent-md-opa-demo

> Reference integration showing how `agent-md-specs` files are enforced
> at runtime by an Open Policy Agent (OPA) / Rego policy.
>
> **Companion repo to [totalmarkdown/agent-md-specs](https://github.com/totalmarkdown/agent-md-specs).**
> CC0 public domain.

---

## Why this exists

One of the most common objections to `agent-md-specs` is *"these are
just Markdown files — where's the actual enforcement?"* This repo
answers that objection with a working demo.

```
agent/LIMITS.md (Markdown+YAML)   policies/limits.rego (OPA policy)
          │                                 │
          │  ←── reads frontmatter ───      │
          │                                 │
          ▼                                 ▼
          tool-call request  ─────►  OPA decision (allow/deny)
                                            │
                                            ▼
                               AUDITTRAIL entry (JSONL)
```

The policy reads the agent's `LIMITS.md` file directly (via OPA's
built-in YAML parser), consults the `never_actions` and
`forbidden_tools` frontmatter fields, and allows or denies each
incoming tool-call request. Deny decisions are written to an
`AUDITTRAIL.md`-shaped JSONL log for post-hoc review.

No custom compilation. No format translation. The policy a compliance
officer reads in the Markdown body is the same data the policy engine
evaluates.

## Prerequisites

- [OPA](https://www.openpolicyagent.org/docs/latest/#1-download-opa) ≥ 0.60.0
- `jq` (for the demo script)
- `yq` (for the frontmatter extraction)

On macOS: `brew install opa jq yq`

## Quick start

```bash
git clone https://github.com/totalmarkdown/agent-md-opa-demo.git
cd agent-md-opa-demo
./run-demo.sh
```

Expected output:

```
▶ Request 1: agent-001 wants to call `web_search`
  OPA decision: ALLOW   (no match against forbidden_tools)
  Audit entry appended.

▶ Request 2: agent-001 wants to call `execute_trade`
  OPA decision: DENY    (execute_trade is in forbidden_tools)
  Audit entry appended.

▶ Request 3: agent-001 wants to call `send_funds` with amount=10000
  OPA decision: DENY    (matches never_actions: "transfer funds without human approval")
  Audit entry appended.

Done. 3 requests processed, 2 denied. See tests/audit.jsonl for the record.
```

## Repository layout

```
agent/LIMITS.md            # Sample agent-md-specs file (governs this demo)
policies/limits.rego       # OPA policy that reads the Markdown frontmatter
policies/limits_test.rego  # Rego unit tests
run-demo.sh                # End-to-end driver — runs OPA, generates audit log
tests/requests.jsonl       # 3 synthetic tool-call requests
tests/audit.jsonl          # Output — AUDITTRAIL-shaped log entries
LICENSE                    # CC0 1.0 Universal
```

## How the policy reads the Markdown

OPA's `yaml.unmarshal` parses YAML. Rego's `regex.find` extracts the
frontmatter block from the Markdown wrapper:

```rego
package agent.limits

import rego.v1

limits_markdown := file.read("agent/LIMITS.md")

frontmatter_match := regex.find_n(`(?s)^---\n(.*?)\n---`, limits_markdown, 1)[0]
frontmatter := yaml.unmarshal(trim(frontmatter_match, "-"))

default allow := false

allow if {
    not denied
}

denied if {
    some forbidden in frontmatter.forbidden_tools
    input.tool == forbidden
}

denied if {
    some never in frontmatter.never_actions
    contains(lower(input.description), lower(never))
}
```

This is *literal* — no model-context layer, no translation step. If the
compliance officer signs off `LIMITS.md`, the runtime enforces that
signed artifact.

## Integration pattern in your own stack

1. Agent author writes `LIMITS.md` (and other agent-md-specs files)
   alongside their agent code. Commits to repo. Compliance officer
   approves the PR.
2. Runtime (API gateway, agent orchestrator, or sidecar) loads the
   `LIMITS.md` file at startup.
3. Every tool-call request is sent to OPA with the file path in its
   input.
4. OPA returns `allow`/`deny` and a structured reason.
5. The reason is written to an `AUDITTRAIL.md`-shaped log for
   non-repudiation.

This is a minimal demo. Production integrations will layer in
`ATTESTATION.md` (who is the requester), `INTENT.md` (what are they
trying to do), `PROVENANCE.md` (where did the data come from), and
`LEASTPRIVILEGE.md` (what are they allowed *right now*).

## Limitations

- Single-file demo. Production deployments would load a whole bundle
  (`SOUL.md`, `WHOAMI.md`, `LIMITS.md`, `DELEGATION.md`,
  `ESCALATION.md`, at minimum).
- No cryptographic signing of the Markdown file. Real deployments
  should pair this with SCITT or in-toto statements to prove the file
  hasn't been tampered with post-approval.
- `never_actions` matching is a naive substring check. Real policies
  should combine this with structured intent matching via
  `INTENT.md`.

## Related repos

- [agent-md-specs](https://github.com/totalmarkdown/agent-md-specs) — the 179 spec types
- [agent-md-validator](https://github.com/totalmarkdown/agent-md-validator) — the CLI that validates spec files
- [limits.md](https://github.com/totalmarkdown/limits.md) — canonical standalone `LIMITS.md` spec

---

*CC0 1.0 Universal — public domain. Maintained by [TotalMarkdown.ai](https://totalmarkdown.ai).*
