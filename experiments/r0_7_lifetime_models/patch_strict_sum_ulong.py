#!/usr/bin/env python3
"""Patch only the checked ulong accumulator site in a copied frozen source.

Never run this against the production checkout. The input source belongs to a
detached clone of raster-d release/0.2 at the pinned SHA.
"""
from pathlib import Path
import argparse
import hashlib

PIN = "cca63a9b2821cd26a98792d322207c8f07bd734f"
TARGET = Path("source/raster/internal/strict_sum.d")
OLD = """                if (
                    !tryAddChecked(
                        total,
                        value,
                        next
                    )
                )
                {
                    result.status =
                        StrictSumStatus.accumulatorOverflow;

                    result.value =
                        cast(Accumulator) 0;

                    return result;
                }

                total =
                    next;"""
NEW = """                static if (is(Accumulator == ulong))
                {
                    // Research-only candidate: no helper call.
                    // The unsigned pre-add predicate is unchanged.
                    if (value > ulong.max - total)
                    {
                        result.status =
                            StrictSumStatus.accumulatorOverflow;
                        result.value =
                            cast(Accumulator) 0;
                        return result;
                    }
                    total += value;
                }
                else
                {
""" + OLD + """
                }"""
def main():
    p = argparse.ArgumentParser()
    p.add_argument("candidate_tree", type=Path)
    args = p.parse_args()
    root = args.candidate_tree.resolve()
    if not (root / ".git").exists():
        raise SystemExit("Expected a detached cloned raster-d checkout")
    import subprocess
    sha = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    if sha != PIN:
        raise SystemExit(f"Wrong raster-d SHA: {sha} != {PIN}")
    if subprocess.check_output(["git", "-C", str(root), "status", "--porcelain"], text=True).strip():
        raise SystemExit("Candidate source must be clean before patching")
    file = root / TARGET
    data = file.read_text()
    if data.count(OLD) != 1:
        raise SystemExit(f"Patch precondition failed: {data.count(OLD)} matches")
    file.write_text(data.replace(OLD, NEW))
    delta = subprocess.check_output(["git", "-C", str(root), "diff", "--", str(TARGET)], text=True)
    changed = subprocess.check_output(["git", "-C", str(root), "diff", "--name-only"], text=True).splitlines()
    if changed != [str(TARGET)] or not delta.startswith("diff --git a/" + str(TARGET)):
        raise SystemExit(f"Unexpected changed files: {changed}")
    if file.read_text() != data.replace(OLD, NEW):
        raise SystemExit("Candidate no longer matches the single anchored replacement")
    print("source_sha256_before=" + hashlib.sha256(data.encode()).hexdigest())
    print("source_sha256_after=" + hashlib.sha256(file.read_bytes()).hexdigest())
    print("frozen_revision=" + sha)
    print(delta)
if __name__ == "__main__":
    main()
