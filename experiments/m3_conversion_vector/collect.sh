#!/usr/bin/env bash
set -euo pipefail
EXPERIMENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
EVIDENCE_ROOT="$(mktemp -d /tmp/raster-vector-xps-XXXXXX)"
python3 "$EXPERIMENT_DIR/audit.py" "$EVIDENCE_ROOT/evidence"
(cd "$EVIDENCE_ROOT/evidence" && sha256sum -c SHA256SUMS)
tar -czf "$EVIDENCE_ROOT.tar.gz" -C "$EVIDENCE_ROOT" evidence
sha256sum "$EVIDENCE_ROOT.tar.gz"
printf 'Evidence: %s\n' "$EVIDENCE_ROOT.tar.gz"
