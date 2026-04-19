---
spec_name: ATTESTATION.md
spec_version: 0.1.0
category: Security
domain: attestationmd.dev
priority: Very High
tier: core
spec_type: runtime_schema
identity_method: spiffe
identity_value: "spiffe://acme.corp/finance/agents/atlas"
binding: "hardware:tpm"
binding_detail: "TPM 2.0, attested via Google Cloud Confidential VM Attestation Service"
issuer: "SPIRE server: spire.acme.corp"
issuer_fingerprint: "sha256:9f2c4e7b1a5d3f8c0e2a1b4d7e9f0a1b3c5e7f9a0c2e4f6b8d0a1c3e5f7b9d0e"
valid_from: "2026-04-15T00:00:00Z"
valid_until: "2026-04-22T00:00:00Z"
rotation_schedule: "weekly, automatic, rolling"
fallback_identity_methods:
  - x509
  - did
maintained_by: TotalMarkdown.ai
license: CC0 1.0 Universal
---

# atlas-trading-assistant — ATTESTATION

## Attestation Method

The agent's identity is attested via SPIFFE, with cryptographic binding
to a hardware TPM running inside a Google Cloud Confidential VM.

Primary identity:

    spiffe://acme.corp/finance/agents/atlas

The SPIFFE SVID (SPIFFE Verifiable Identity Document) is issued by
`spire.acme.corp` and carries the issuer fingerprint
`sha256:9f2c4e7b1a5d3f8c0e2a1b4d7e9f0a1b3c5e7f9a0c2e4f6b8d0a1c3e5f7b9d0e`.

## Credential Lifecycle

- **valid_from**: 2026-04-15T00:00:00Z
- **valid_until**: 2026-04-22T00:00:00Z (7-day credential)
- **rotation_schedule**: weekly, automatic, rolling — the SPIRE agent
  rotates the SVID before expiry without human intervention.

Any policy evaluation outside the `valid_from`–`valid_until` window
must treat the attestation as unverified and deny the request.

## Hardware Binding

`binding: hardware:tpm` — the SVID's private key is bound to the TPM
on the Confidential VM instance running this agent. Exfiltration of
the private key requires compromising the TPM, which is outside the
assumed threat model.

## Fallback Identity Methods

If the primary SPIFFE method is unavailable, the agent may fall back
to presenting:
- **X.509 certificate** with the same subject name
- **DID** resolving to an equivalent verification method

Fallback methods are informational only; the runtime enforcement layer
must ensure any fallback is cryptographically equivalent.

## Related Specs

- DELEGATION.md — authority chain referring to this identity
- AUDITTRAIL.md — every attestation check is logged

---

*Part of [agent-md-specs](https://github.com/totalmarkdown/agent-md-specs)*
*Maintained by TotalMarkdown.ai · License: CC0 1.0 Universal*
