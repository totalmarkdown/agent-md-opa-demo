# Shared helpers for the agent-md-opa-demo test scripts.
# Sourced, not executed.
#
# Requires: opa (>= 1.0), yq (v4), jq, shasum.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPECS_DIR="$ROOT/specs"
POLICY_DIR="$ROOT/policy"
AUDIT_DIR="$ROOT/audit"
AUDIT_LOG="$AUDIT_DIR/AUDITTRAIL.jsonl"

# ---------- color output ----------

if [[ -t 1 ]]; then
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RESET=$'\033[0m'
else
    C_RED=; C_GREEN=; C_YELLOW=; C_BLUE=; C_BOLD=; C_DIM=; C_RESET=
fi

log_scenario() { printf "\n${C_BOLD}▶ %s${C_RESET}\n" "$*"; }
log_info()     { printf "  %s\n" "$*"; }
log_pass()     { printf "  ${C_GREEN}✓ PASS${C_RESET}  %s\n" "$*"; }
log_fail()     { printf "  ${C_RED}✗ FAIL${C_RESET}  %s\n" "$*"; FAILURES=$((FAILURES + 1)); }
log_dim()      { printf "  ${C_DIM}%s${C_RESET}\n" "$*"; }

# ---------- dependency checks ----------

require_tool() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "${C_RED}error:${C_RESET} '$1' not installed. Install with:" >&2
        case "$1" in
            opa)  echo "  brew install opa  # or https://www.openpolicyagent.org/docs/latest/#1-download-opa" >&2 ;;
            yq)   echo "  brew install yq" >&2 ;;
            jq)   echo "  brew install jq" >&2 ;;
        esac
        exit 2
    }
}

require_tool opa
require_tool yq
require_tool jq

# ---------- shasum helper ----------

_sha256() {
    # Portable SHA-256 → hex, stdin → stdout (no filename).
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
    else
        sha256sum | awk '{print $1}'
    fi
}

# ---------- spec → data bundling ----------

# Extract YAML frontmatter from a Markdown file as JSON.
# Usage: spec_frontmatter_json specs/LIMITS.md
spec_frontmatter_json() {
    local md="$1"
    # Strip everything between the first '---' and the second '---',
    # then convert YAML → JSON via yq.
    awk '/^---$/{n++; next} n==1{print}' "$md" | yq -o=json eval -
}

# Build the combined data bundle (as a JSON file) for an OPA evaluation.
# Usage: build_data_bundle OUTPUT_PATH PREVIOUS_HASH [POLICY_VERSION] [EVALUATOR]
build_data_bundle() {
    local out="$1"
    local prev_hash="${2:-sha256:GENESIS}"
    local policy_version="${3:-v0.2.0}"
    local evaluator="${4:-opa-$(opa version | awk '/^Version:/{print $2; exit}')}"

    local limits
    local delegation
    local attestation
    local audittrail
    limits=$(spec_frontmatter_json "$SPECS_DIR/LIMITS.md")
    delegation=$(spec_frontmatter_json "$SPECS_DIR/DELEGATION.md")
    attestation=$(spec_frontmatter_json "$SPECS_DIR/ATTESTATION.md")
    audittrail=$(spec_frontmatter_json "$SPECS_DIR/AUDITTRAIL.md")

    jq -n \
      --argjson limits "$limits" \
      --argjson delegation "$delegation" \
      --argjson attestation "$attestation" \
      --argjson audittrail "$audittrail" \
      --arg prev_hash "$prev_hash" \
      --arg policy_version "$policy_version" \
      --arg evaluator "$evaluator" \
      '{
        specs: {
          limits: $limits,
          delegation: $delegation,
          attestation: $attestation,
          audittrail: $audittrail
        },
        state: {
          previous_entry_hash: $prev_hash,
          policy_version: $policy_version,
          evaluator: $evaluator
        }
      }' > "$out"
}

# ---------- OPA evaluation ----------

# Evaluate one request through the main orchestrator and write the
# generated AUDITTRAIL entry to $AUDIT_LOG, updating the chain state.
#
# Usage: evaluate_request INPUT_JSON_FILE
# Echoes the generated audit entry to stdout.
evaluate_request() {
    local input_file="$1"

    mkdir -p "$AUDIT_DIR"
    touch "$AUDIT_LOG"

    # Chain state: hash of the last stored entry, or GENESIS.
    local prev_hash="sha256:GENESIS"
    if [[ -s "$AUDIT_LOG" ]]; then
        prev_hash="sha256:$(tail -n 1 "$AUDIT_LOG" | jq -cS . | _sha256)"
    fi

    local data_file
    data_file="$(mktemp -t agent-md-opa-data.XXXXXX).json"
    build_data_bundle "$data_file" "$prev_hash"

    local entry
    entry=$(opa eval \
        --data "$POLICY_DIR" \
        --data "$data_file" \
        --input "$input_file" \
        --format json \
        'data.agent.audittrail.entry' \
        | jq -c '.result[0].expressions[0].value')

    rm -f "$data_file"

    # Append to audit log.
    echo "$entry" >> "$AUDIT_LOG"
    echo "$entry"
}

# ---------- chain verification ----------

verify_chain() {
    local log="${1:-$AUDIT_LOG}"
    [[ -f "$log" ]] || { log_fail "audit log not found: $log"; return 1; }

    local expected="sha256:GENESIS"
    local n=0
    local ok=1
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        n=$((n + 1))
        local actual
        actual=$(jq -r '.previous_entry_hash' <<<"$entry")
        if [[ "$actual" != "$expected" ]]; then
            log_fail "entry $n: previous_entry_hash = $actual ; expected $expected"
            ok=0
        fi
        expected="sha256:$(jq -cS . <<<"$entry" | _sha256)"
    done < "$log"

    if [[ $ok -eq 1 ]]; then
        log_pass "chain intact — $n entries verified"
    else
        return 1
    fi
}
