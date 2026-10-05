#!/usr/bin/env python3
"""Validate and summarize the paired Pointer-vs-Hybrid XPS archive."""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import statistics
from pathlib import Path


RUNS = ("hybrid-1", "pointer-1", "pointer-2", "hybrid-2")
PAIRS = (("hybrid-1", "pointer-1"), ("hybrid-2", "pointer-2"))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_manifest(path: Path) -> int:
    checked = 0
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        if not raw_line.strip():
            continue
        expected, relative = raw_line.split(None, 1)
        target = path.parent / relative.lstrip("* ")
        if not target.is_file():
            raise ValueError(f"missing manifest target: {target}")
        actual = sha256(target)
        if actual != expected:
            raise ValueError(f"SHA256 mismatch: {target}: {actual} != {expected}")
        checked += 1
    return checked


def read_summary(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        rows = list(reader)
        if not reader.fieldnames:
            raise ValueError(f"missing CSV header: {path}")
        return reader.fieldnames, rows


def selected_table(rows: list[dict[str, str]]) -> dict[tuple[str, ...], float]:
    table: dict[tuple[str, ...], float] = {}
    for row in rows:
        if row["form"] != "selected64":
            continue
        key = tuple(row[name] for name in
                    ("cohort", "mode", "compiler", "width", "height", "layout"))
        if key in table:
            raise ValueError(f"duplicate selected64 case: {key}")
        table[key] = float(row["ns_per_call"])
    return table


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("evidence", type=Path, help="extracted archive evidence/ directory")
    parser.add_argument("archive", type=Path, help="uploaded .tar.gz for its hash/size")
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    evidence = args.evidence.resolve()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)

    root_manifest_count = verify_manifest(evidence / "SHA256SUMS")
    run_manifest_counts: dict[str, dict[str, int]] = {}
    summaries: dict[str, tuple[list[str], list[dict[str, str]]]] = {}
    for run in RUNS:
        directory = evidence / run
        run_manifest_counts[run] = {
            "SHA256SUMS": verify_manifest(directory / "SHA256SUMS"),
            "audit-SHA256SUMS": verify_manifest(directory / "audit-SHA256SUMS"),
        }
        original = (directory / "summary.csv").read_bytes()
        replayed = (directory / "summary-replayed.csv").read_bytes()
        if original != replayed:
            raise ValueError(f"summary replay differs for {run}")
        summaries[run] = read_summary(directory / "summary.csv")

    fieldnames = summaries[RUNS[0]][0]
    for run in RUNS:
        names, rows = summaries[run]
        if names != fieldnames:
            raise ValueError(f"summary columns differ for {run}")
        if len(rows) != 4104:
            raise ValueError(f"unexpected row count for {run}: {len(rows)}")

    summary_path = output / "xps-2026-10-04-summary.csv.gz"
    with summary_path.open("wb") as raw, gzip.GzipFile(
        filename="", mode="wb", fileobj=raw, mtime=0
    ) as compressed:
        import io

        text = io.TextIOWrapper(compressed, encoding="utf-8", newline="")
        writer = csv.DictWriter(text, fieldnames=("run", *fieldnames), lineterminator="\n")
        writer.writeheader()
        for run in RUNS:
            for row in summaries[run][1]:
                writer.writerow({"run": run, **row})
        text.flush()

    tables = {run: selected_table(summaries[run][1]) for run in RUNS}
    ratio_sets: dict[tuple[str, str], dict[tuple[str, ...], list[float]]] = {}
    for hybrid, pointer in PAIRS:
        if tables[hybrid].keys() != tables[pointer].keys():
            raise ValueError(f"selected64 cases do not match: {hybrid}/{pointer}")
        by_group: dict[tuple[str, ...], list[float]] = {}
        for key in tables[hybrid]:
            cohort, _mode, compiler, width, _height, _layout = key
            group = (compiler, cohort, width)
            by_group.setdefault(group, []).append(tables[hybrid][key] / tables[pointer][key])
        ratio_sets[(hybrid, pointer)] = by_group

    comparison_path = output / "xps-2026-10-04-comparison.csv"
    groups = sorted(set().union(*(set(values) for values in ratio_sets.values())),
                    key=lambda group: (group[0], group[1], int(group[2])))
    fields = (
        "compiler", "cohort", "width", "matched_cases_pair1",
        "median_hybrid_over_pointer_pair1", "matched_cases_pair2",
        "median_hybrid_over_pointer_pair2", "matched_cases_pooled",
        "median_hybrid_over_pointer_pooled", "min_pooled", "max_pooled",
    )
    with comparison_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for compiler, cohort, width in groups:
            group = (compiler, cohort, width)
            first = ratio_sets[PAIRS[0]].get(group, [])
            second = ratio_sets[PAIRS[1]].get(group, [])
            pooled = first + second
            writer.writerow({
                "compiler": compiler,
                "cohort": cohort,
                "width": width,
                "matched_cases_pair1": len(first),
                "median_hybrid_over_pointer_pair1": f"{statistics.median(first):.6f}",
                "matched_cases_pair2": len(second),
                "median_hybrid_over_pointer_pair2": f"{statistics.median(second):.6f}",
                "matched_cases_pooled": len(pooled),
                "median_hybrid_over_pointer_pooled": f"{statistics.median(pooled):.6f}",
                "min_pooled": f"{min(pooled):.6f}",
                "max_pooled": f"{max(pooled):.6f}",
            })

    dmd_wide = {}
    ldc_wide = {}
    position_wide = {}
    for hybrid, pointer in PAIRS:
        values = ratio_sets[(hybrid, pointer)]
        dmd = [value for (compiler, _cohort, width), ratios in values.items()
               if compiler == "dmd" and int(width) >= 64 for value in ratios]
        ldc = [value for (compiler, _cohort, width), ratios in values.items()
                if compiler == "ldc2" and int(width) >= 64 for value in ratios]
        dmd_wide[f"{hybrid}/{pointer}"] = {
            "median_hybrid_over_pointer": statistics.median(dmd), "matched_cases": len(dmd)
        }
        ldc_wide[f"{hybrid}/{pointer}"] = {
            "median_hybrid_over_pointer": statistics.median(ldc), "matched_cases": len(ldc)
        }
        for cohort in ("dmd-native", "dmd-0", "dmd-8", "dmd-16", "dmd-24"):
            ratios = [value for (compiler, group, width), items in values.items()
                      if compiler == "dmd" and group == cohort and int(width) >= 64
                      for value in items]
            position_wide.setdefault(f"{hybrid}/{pointer}", {})[cohort] = {
                "median_hybrid_over_pointer": statistics.median(ratios),
                "matched_cases": len(ratios),
                "min": min(ratios),
                "max": max(ratios),
            }

    pin_lines = (evidence / "hybrid-1" / "launcher-toolchain.txt").read_text(
        encoding="utf-8"
    ).splitlines()
    commit_prefixes = (
        "Production commit:", "Hybrid baseline commit:", "Pointer candidate commit:"
    )
    commits = {
        line.split(":", 1)[0].strip(): line.split(":", 1)[1].strip()
        for line in pin_lines if line.startswith(commit_prefixes)
    }

    record = {
        "checks": [
            "root and all four per-run SHA256 manifests verified",
            "all four summary-replayed.csv files byte-match summary.csv",
            "all four summaries contain exactly 4,104 data rows",
            "selected64 case keys match within both ABBA pairs",
        ],
        "raw_archive": {
            "name": args.archive.name,
            "bytes": args.archive.stat().st_size,
            "sha256": sha256(args.archive),
        },
        "manifests": {"root": root_manifest_count, "runs": run_manifest_counts},
        "rows_per_run": {run: len(summaries[run][1]) for run in RUNS},
        "run_order": list(RUNS),
        "commits": commits,
        "own_inputs": {
            run: json.loads((evidence / run / "collection.json").read_text(encoding="utf-8"))["own_inputs"]
            for run in RUNS
        },
        "scope": {
            run: json.loads((evidence / run / "collection.json").read_text(encoding="utf-8"))["scope"]
            for run in RUNS
        },
        "selected64_dmd_width_ge_64": dmd_wide,
        "selected64_ldc_width_ge_64_control": ldc_wide,
        "selected64_dmd_by_position_width_ge_64": position_wide,
        "summary_csv_gz_sha256": sha256(summary_path),
        "comparison_csv_sha256": sha256(comparison_path),
    }
    record_path = output / "xps-2026-10-04.json"
    record_path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(record, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
