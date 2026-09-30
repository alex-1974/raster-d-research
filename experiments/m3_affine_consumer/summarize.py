#!/usr/bin/env python3
"""Validate the pinned consumer logs and summarize three process executions.

Usage: python3 summarize.py evidence/2026-09-30-xps
Standard-library-only; writes Markdown to stdout, leaving raw evidence intact.
"""
import ast
from pathlib import Path
import re
from statistics import median
import sys

root = Path(sys.argv[1])
groups = {}
cases = operations = 0
for compiler in ("dmd", "ldc2"):
    if "3 modules passed unittests" not in (root / f"{compiler}-tests.txt").read_text():
        raise ValueError(f"{compiler}: unittest success missing")
    for run in (1, 2, 3):
        text = (root / f"{compiler}-run-{run}.txt").read_text()
        if text.count("m3_affine_consumer PASS") != 1:
            raise ValueError(f"{compiler}/{run}: completion missing")
        shared = re.findall(r"shared_backing neighbourhood=(false|true) genuine_overlap=(false|true) PASS", text)
        if set(shared) != {(n, o) for n in ("false", "true") for o in ("false", "true")} or len(shared) != 4:
            raise ValueError("shared-backing matrix incomplete")
        lines = [line for line in text.splitlines() if line.startswith("consumer=")]
        if len(lines) != 12:
            raise ValueError("consumer matrix incomplete")
        for line in lines:
            a = ast.literal_eval(re.search(r"public_raw_ns=(\[.*?\])", line)[1])
            b = ast.literal_eval(re.search(r"bounded_raw_ns=(\[.*?\])", line)[1])
            fields = dict(re.findall(r"(\w+)=(\S+)", re.sub(r"(public|bounded)_raw_ns=\[.*?\]", "", line)))
            if len(a) != 9 or len(b) != 9 or min(a + b) <= 0:
                raise ValueError("invalid raw samples")
            if median(a) != int(fields["public_median_ns"]) or median(b) != int(fields["bounded_median_ns"]):
                raise ValueError("reported median disagrees with raw samples")
            if abs(float(fields["speedup"]) - median(a) / median(b)) > 0.000501:
                raise ValueError("reported speedup disagrees with raw samples")
            key = (compiler,) + tuple(fields[k] for k in (
                "consumer", "source", "output", "source_pitch", "destination_pitch",
                "source_negative", "destination_negative", "sample_stride"))
            groups.setdefault(key, []).append((run, median(a), median(b), fields["fingerprint"]))
            cases += 1
            operations += len(a) + len(b)

print("| Compiler | Consumer | Source → output | Rows S/D | Sample stride | Public ms | Bounds ms | Median speedup | Speedup min–max | Bounds spread |")
print("|---|---|---|---|---:|---:|---:|---:|---:|---:|")
fingerprints = {}
for key, rows in groups.items():
    if len(rows) != 3 or {r[0] for r in rows} != {1, 2, 3} or len({r[3] for r in rows}) != 1:
        raise ValueError("duplicate/missing execution or inconsistent fingerprint")
    compiler, consumer, source, output, sp, dp, sr, dr, stride = key
    # Expected output/padding hash must also agree across compilers.
    logical_key = key[1:]
    if fingerprints.setdefault(logical_key, rows[0][3]) != rows[0][3]:
        raise ValueError("cross-compiler fingerprint mismatch")
    a = [r[1] for r in rows]
    b = [r[2] for r in rows]
    ratios = [x / y for x, y in zip(a, b)]
    directions = "/".join("−" if x == "true" else "+" for x in (sr, dr))
    spread = (max(b) - min(b)) / median(b) * 100
    print(f"| {compiler} | {consumer} | {source} → {output} | {directions} | {stride} | {median(a)/1e6:.4f} | {median(b)/1e6:.4f} | {median(ratios):.3f} | {min(ratios):.3f}–{max(ratios):.3f} | {spread:.2f}% |")
print(f"\nVerified: {cases} cases, {operations} timed operations, six completed process executions.")
print("\nTimes are medians of three per-process medians (nine samples each).")
print("Speedup is the median of three paired median ratios; its range spans those three ratios.")
print("Bounds spread = (maximum − minimum) / median of the three process medians.")
