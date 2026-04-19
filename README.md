# agent-md-opa-demo

> Reference runtime-enforcement integration for
> [agent-md-specs](https://github.com/totalmarkdown/agent-md-specs).
> Four CC0 Markdown specs become an Open Policy Agent (OPA) policy
> bundle that enforces the full accountability chain and produces a
> tamper-evident audit log.
>
> Companion repo to `totalmarkdown/agent-md-specs`. CC0 1.0 Universal.

---

## See it run

[![asciicast](https://asciinema.org/a/948586.svg)](https://asciinema.org/a/948586)

~2 seconds. 3 scenarios. Hash-chained audit log. Click to replay.

---

## What this demo proves

Two independent reviews of `agent-md-specs` flagged *"these are just
Markdown files — where is the actual enforcement?"* as the #1
credibility gap. This repo answers that with ~250 lines of Rego and
no custom compilation.

It walks through the full 4-spec **accountability chain** end-to-end:

```
┌───────────────────┐  ┌──────────────────┐  ┌─────────────┐
│ specs/ATTESTATION │  │ specs/DELEGATION │  │ specs/LIMITS │
│   .md             │  │   .md            │  │   .md        │
│ (who is this?)    │  │ (who authorized  │  │ (what must   │
│                   │  │  it, for what?)  │  │  it never    │
│                   │  │                  │  │  do?)        │
└────────┬──────────┘  └────────┬─────────┘  └─────┬────────┘
         │ YAML frontmatter     │                  │
         └──────────┬───────────┴──────────────────┘
                    ▼
           ┌───────────────────┐
           │  OPA / Rego       │
           │  policy bundle    │◄───── tool-call request
           │  (policy/*.rego)  │
           └─────────┬─────────┘
                     │ allow / deny + reasons
                     ▼
           ┌───────────────────┐
           │ audit/            │
           │   AUDITTRAIL.jsonl│ ◄── specs/AUDITTRAIL.md
           │ (hash-chained)    │     defines this shape
           └───────────────────┘
```

The same Markdown file a compliance officer signs off is the policy
the runtime enforces. There is no drift, no translation layer, no
bespoke DSL.

## Quick start

```bash
# prerequisites: opa (≥ 1.0), yq (v4), jq, bash
brew install opa yq jq

git clone https://github.com/totalmarkdown/agent-md-opa-demo.git
cd agent-md-opa-demo

opa test policy/            # 11 Rego unit tests — offline, self-contained
./test/test_full_flow.sh    # 3 end-to-end scenarios + chain verification
ls audit/                   # → AUDITTRAIL.jsonl (3 entries, hash-chained)
```

Expected final line: `Result: OK — all scenarios passed, chain verified`.

## What each file does

```
specs/
├── LIMITS.md          hard-stop vocabulary: forbidden_tools[], never_actions[]
├── DELEGATION.md      authority chain: delegator, scope[], time-bounds, revocation
├── ATTESTATION.md     identity: SPIFFE/X.509/DID binding, credential lifecycle
└── AUDITTRAIL.md      format of entries written to audit/AUDITTRAIL.jsonl

policy/
├── limits.rego        reads data.specs.limits    → denied_by[], denial_reasons[]
├── delegation.rego    reads data.specs.delegation → denied_by[], denial_reasons[]
├── attestation.rego   reads data.specs.attestation → denied_by[], denial_reasons[]
├── audittrail.rego    formats the AUDITTRAIL entry (adds hash-chain pointer)
├── main.rego          orchestrates the three guards + exposes data.agent.main.allow
└── main_test.rego     11 Rego unit tests (run via `opa test policy/`)

test/
├── lib.sh             shared helpers — frontmatter → data bundle, OPA eval, sha256
├── test_full_flow.sh  three scenarios end-to-end + chain verification (canonical demo)
├── test_limits.sh     focused guard — LIMITS-only
├── test_delegation.sh focused guard — DELEGATION-only (scope + expiry)
├── test_attestation.sh focused guard — ATTESTATION-only (malformed + expired)
├── test_audittrail.sh validates entry schema + hash chain
└── verify_chain.sh    standalone chain verifier

audit/
└── AUDITTRAIL.jsonl   one JSON entry per line, hash-chained (re-created per run)
```

## The three scenarios

`test/test_full_flow.sh` runs these three back-to-back, printing the
decision and the generated audit entry each time, then verifies the
chain:

### 1. HAPPY PATH

Valid attestation, in-scope action, no LIMITS hit.

```
action:  "read_financial_data"
decision: allow
decision_reasons: [attestation.verified, delegation.authorized, limits.clear]
output_hash: sha256:d0a1… (hash of the returned data)
previous_entry_hash: sha256:GENESIS
```

### 2. SCOPE VIOLATION

Valid attestation; action is **not** in `delegation.scope`.

```
action:  "send_email"    # not in scope [read_financial_data, generate_reports, ...]
decision: deny
decision_reasons: [delegation.scope_mismatch]
output_hash: null        # denies never produce output
previous_entry_hash: sha256:<hash of entry 1>
```

### 3. IDENTITY FAILURE

Attestation token is malformed (not a JWT or X.509 chain).

```
action:  "read_financial_data"
decision: deny
decision_reasons: [attestation.token_malformed]
output_hash: null
previous_entry_hash: sha256:<hash of entry 2>
```

## Example audit entry

```json
{
  "timestamp": "2026-04-19T10:15:23Z",
  "agent_id": "spiffe://acme.corp/finance/agents/atlas",
  "delegation_id": "del-2026-04-a1b2c3d4",
  "action": "read_financial_data",
  "decision": "allow",
  "decision_reasons": ["attestation.verified", "delegation.authorized", "limits.clear"],
  "input_hash": "sha256:e84d371f87a613739b071dac39cf6263c2aef62b7ce58fc1cee1d41b9469dcce",
  "output_hash": "sha256:d0a133de9d7c67efcc65e063ef24f7059a3c0f61f19b24fdc335bab4b20c8660",
  "previous_entry_hash": "sha256:GENESIS",
  "policy_version": "v0.2.0",
  "evaluator": "opa-1.15.2"
}
```

`previous_entry_hash` = `sha256(canonical_json_of(previous_entry))`.
First entry uses the sentinel `sha256:GENESIS`.

## How the policy reads the Markdown

The driver (`test/lib.sh`) does the frontmatter extraction once, at
load time:

```bash
spec_frontmatter_json() {
    local md="$1"
    awk '/^---$/{n++; next} n==1{print}' "$md" | yq -o=json eval -
}
```

…and feeds the result to OPA as a data bundle:

```json
{
  "specs": {
    "limits":       { "forbidden_tools": [...], "never_actions": [...] },
    "delegation":   { "id": "del-...", "scope": [...], "valid_until": "..." },
    "attestation":  { "identity_value": "spiffe://...", "valid_until": "..." },
    "audittrail":   { "entry_schema": {...} }
  },
  "state": { "previous_entry_hash": "sha256:GENESIS", "policy_version": "v0.2.0" }
}
```

The Rego policies are then pure: they read `data.specs.X` and
`input.Y`, and output `data.agent.main.allow` + an audit entry shape.
A production integration would cache the extracted JSON and reload it
only when the underlying Markdown changes.

This is the "one file, two audiences" pattern from agent-md-specs:

- The compliance officer reads `specs/LIMITS.md` as Markdown — the
  prose explains the rationale, the human-readable policy, and the
  history.
- The policy engine reads the same file's YAML frontmatter — the
  structured fields become runtime enforcement rules.

If the two disagree, the Markdown is wrong. There is no separate
"policy source of truth."

## Why this matters

From the agent-md-specs
[CRITICISM.md](https://github.com/totalmarkdown/agent-md-specs/blob/main/CRITICISM.md)
#4 — "Where's the runtime enforcement? These are just Markdown files.":

> **The honest gap:** no reference integration ships in this repo
> yet. We haven't proven the "YAML frontmatter is the bridge" claim
> with a working demo.

This repo closes that gap. It does not replace a production policy
engine — but it demonstrates, with code you can `git clone` and run
in under 60 seconds, that the bridge from declarative spec to runtime
enforcement exists and works.

## What this demo is NOT

- **Not production-ready.** Real deployments should sign specs
  cryptographically (e.g. sigstore / SCITT), pair OPA with a sidecar
  for revocation-endpoint polling, and push audit entries to WORM
  storage (S3 Object Lock, immutable ledger).
- **Not exhaustive.** `specs/` covers 4 of the 47 agent-md-specs Core
  tier. Adding `INTENT.md`, `LEASTPRIVILEGE.md`, `PROVENANCE.md`, or
  `CONSENT.md` follows the same pattern — one Rego file per spec, one
  fact per `data.specs.X`, feed into `main.rego`.
- **Not a replacement for a full policy engine.** OPA is the policy
  engine; Rego is the language. agent-md-specs is the *vocabulary*
  for what the policy must decide — it tells Rego what to check, not
  how.
- **Not a cryptographic attestation system.** The attestation-token
  shape check (`startswith("eyJ")` for JWT) is pedagogical. Real
  SPIFFE integration uses the workload API and validates the SVID
  against a trust bundle.

## How to extend

Add a new spec:

1. Drop your new file at `specs/MYSPEC.md` with YAML frontmatter
   declaring the fields the policy needs.
2. Write `policy/myspec.rego` that reads `data.specs.myspec` and
   exposes `data.agent.myspec.denied_by[]` and
   `data.agent.myspec.denial_reasons[]`.
3. Extend `policy/main.rego` to require
   `count(data.agent.myspec.denied_by) == 0` in the `allow` rule and
   to surface the rule IDs in `decision_reasons`.
4. Extend `test/lib.sh` → `build_data_bundle` to read the new
   frontmatter.
5. Add a `test/test_myspec.sh` that exercises a deny case.
6. Run `opa test policy/ && ./test/test_full_flow.sh`.

The current 4 specs are ~250 lines of Rego total; each new guard adds
roughly 40-60 lines.

## Related repos

- [agent-md-specs](https://github.com/totalmarkdown/agent-md-specs) —
  the 179 spec types (47 Core, 132 Extended)
- [agent-md-validator](https://github.com/totalmarkdown/agent-md-validator) —
  CLI that validates individual specs and bundles
- The four specs exercised here have canonical standalone repos:
  [limits.md](https://github.com/totalmarkdown/limits.md),
  [delegation.md](https://github.com/totalmarkdown/delegation.md),
  [audittrail.md](https://github.com/totalmarkdown/audittrail.md),
  [attestation (in agent-md-specs `specs/security/`)](https://github.com/totalmarkdown/agent-md-specs/blob/main/specs/security/ATTESTATION.md).

---

*CC0 1.0 Universal — public domain. Maintained by
[TotalMarkdown.ai](https://totalmarkdown.ai).*
