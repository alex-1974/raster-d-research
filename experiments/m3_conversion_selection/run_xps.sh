#!/usr/bin/env bash
# Pinned qualification in detached sibling worktrees; never switch work branches.
set -euo pipefail

PREPARE_ONLY=false
WORKSPACE_LIBS="${1:-$HOME/Programmiersprachen/dlang/d-geospatial-workspace/libs}"
if [[ "${2:-}" == '--prepare-only' ]]; then PREPARE_ONLY=true; fi
if (( $# > 2 )) || [[ -n "${2:-}" && "${2:-}" != '--prepare-only' ]]; then
    printf 'Usage: bash run_xps.sh [workspace/libs] [--prepare-only]\n' >&2
    exit 2
fi
PRODUCTION_REPO="$WORKSPACE_LIBS/raster-d"
RESEARCH_REPO="$WORKSPACE_LIBS/raster-d-research"
PRODUCTION_PIN=7dcdf01babf87e9a80af2864fbad75efe8e7d0ef
RESEARCH_PIN=0e32179e32e3670ba28a89c24b2f44e7ced3d21c

[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || {
    printf 'This qualification requires Linux x86-64.\n' >&2; exit 1;
}
for command in git python3 dmd ldc2 dub g++ objdump sha256sum tar tee cmp cp; do
    command -v "$command" >/dev/null || { printf 'Missing tool: %s\n' "$command" >&2; exit 1; }
done
DMD_VERSION="$(dmd --version)"
LDC_VERSION="$(ldc2 --version)"
DUB_VERSION="$(dub --version)"
[[ "$DMD_VERSION" == *'v2.111.0'* ]] || { printf 'Required DMD: 2.111.0\n' >&2; exit 1; }
[[ "$LDC_VERSION" == *'compiler (1.41.0)'* && "$LDC_VERSION" == *'DMD v2.111.0'* ]] || {
    printf 'Required LDC: 1.41.0, frontend 2.111.0\n' >&2; exit 1;
}
[[ "$DUB_VERSION" == *'DUB version 1.40.0,'* ]] || { printf 'Required DUB: 1.40.0\n' >&2; exit 1; }
# Assert-based collector checks must be active, including when the shell has
# inherited PYTHONOPTIMIZE. This setting is local to the launched processes.
export PYTHONOPTIMIZE=0
python3 -c 'import os,sys; sys.exit(0 if __debug__ and hasattr(os, "sched_setaffinity") else 1)'
for repository in "$PRODUCTION_REPO" "$RESEARCH_REPO"; do
    git -C "$repository" rev-parse --git-dir >/dev/null
done

ensure_commit() {
    local repository="$1" pin="$2"
    if ! git -C "$repository" cat-file -e "$pin^{commit}" 2>/dev/null; then
        git -C "$repository" fetch --no-tags origin "$pin"
    fi
    [[ "$(git -C "$repository" rev-parse "$pin^{commit}")" == "$pin" ]]
}
ensure_commit "$PRODUCTION_REPO" "$PRODUCTION_PIN"
ensure_commit "$RESEARCH_REPO" "$RESEARCH_PIN"
RUN_ROOT="$(mktemp -d /tmp/raster-selection-xps-run-XXXXXX)"
printf 'Qualification directory: %s\n' "$RUN_ROOT"
# Retain owned worktrees and partial evidence on failure. No force-removal of
# files, branch movement, cleaning or auto-merge occurs.
trap 'status=$?; if (( status != 0 )); then printf "Run failed (%s); retained directory: %s\n" "$status" "$RUN_ROOT" >&2; fi' EXIT

git -C "$PRODUCTION_REPO" worktree add --detach "$RUN_ROOT/raster-d" "$PRODUCTION_PIN"
git -C "$RESEARCH_REPO" worktree add --detach "$RUN_ROOT/raster-d-research" "$RESEARCH_PIN"
[[ "$(git -C "$RUN_ROOT/raster-d" rev-parse HEAD)" == "$PRODUCTION_PIN" ]]
[[ "$(git -C "$RUN_ROOT/raster-d-research" rev-parse HEAD)" == "$RESEARCH_PIN" ]]
EVIDENCE_DIR="$RUN_ROOT/evidence"
EXPERIMENT_DIR="$RUN_ROOT/raster-d-research/experiments/m3_conversion_selection"
if "$PREPARE_ONLY"; then
    printf 'PASS pinned worktree preparation; benchmark not executed.\n'
    exit 0
fi

# collect.py requires a new output directory, so write supplementary provenance
# outside it first; move it in only after successful collection.
{
    printf 'Production commit: %s\nResearch source commit: %s\n' "$PRODUCTION_PIN" "$RESEARCH_PIN"
    printf '%s\n%s\n%s\n' "$DMD_VERSION" "$LDC_VERSION" "$DUB_VERSION"
    g++ --version
    python3 --version
    git --version
    objdump --version
    printf 'Frequency/thermal controls: unchanged, unmonitored\n'
    printf 'Python assertions: enabled\n'
} > "$RUN_ROOT/launcher-toolchain.txt"
(
    cd "$RUN_ROOT/raster-d"
    dub describe --compiler=dmd > "$RUN_ROOT/dmd-dependencies.json"
    dub describe --compiler=ldc2 > "$RUN_ROOT/ldc2-dependencies.json"
)
# Full default collector: both compilers, six processes each. Pipefail preserves
# collector errors; this is a hardware run, not a prepare-only smoke check.
python3 "$EXPERIMENT_DIR/collect.py" "$EVIDENCE_DIR" 2>&1 | tee "$RUN_ROOT/launcher-run.txt"
(cd "$EVIDENCE_DIR" && sha256sum -c SHA256SUMS)
# Preserve the original collector manifest and every original file unchanged.
cp "$EVIDENCE_DIR/SHA256SUMS" "$EVIDENCE_DIR/audit-SHA256SUMS"
cp "$RUN_ROOT/launcher-toolchain.txt" "$RUN_ROOT/launcher-run.txt" \
    "$RUN_ROOT/dmd-dependencies.json" "$RUN_ROOT/ldc2-dependencies.json" "$EVIDENCE_DIR/"
python3 "$EXPERIMENT_DIR/collect.py" "$EVIDENCE_DIR" --replay > "$RUN_ROOT/summary-replayed.csv"
cmp "$RUN_ROOT/summary-replayed.csv" "$EVIDENCE_DIR/summary.csv"
python3 - "$EVIDENCE_DIR" <<'PY'
import hashlib
import sys
from pathlib import Path
root=Path(sys.argv[1])
(root/'SHA256SUMS').write_text(''.join(
    hashlib.sha256(path.read_bytes()).hexdigest()+'  '+str(path.relative_to(root))+'\n'
    for path in sorted(root.rglob('*')) if path.is_file() and path!=root/'SHA256SUMS'))
PY
(cd "$EVIDENCE_DIR" && sha256sum -c SHA256SUMS)
ARCHIVE="$RUN_ROOT.tar.gz"
tar -czf "$ARCHIVE" -C "$RUN_ROOT" evidence
sha256sum "$ARCHIVE"
printf 'UPLOAD: %s\n' "$ARCHIVE"
