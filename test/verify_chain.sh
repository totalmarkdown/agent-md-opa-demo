#!/usr/bin/env bash
# Standalone hash-chain verifier.
# Usage: ./test/verify_chain.sh [path/to/AUDITTRAIL.jsonl]
#
# Reads each entry, checks that entry[N].previous_entry_hash matches
# sha256(canonical_json(entry[N-1])), prints CHAIN INTACT or CHAIN BROKEN.

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

FAILURES=0
verify_chain "${1:-}"
[[ $FAILURES -eq 0 ]] || exit 1
