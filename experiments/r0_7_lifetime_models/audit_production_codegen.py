#!/usr/bin/env python3
"""Audit linked frozen-source A/B binaries; read-only, research-only.

Input: run_production_checked_add_ab.sh output directory (or CI-equivalent).
Report real call sites scoped to named strict-sum instantiations, rather than
searching the entire disassembly for a helper name.
"""
import argparse
import csv
import json
import re
from pathlib import Path

def symbols(path):
    found = []
    for line in path.read_text().splitlines():
        parts = line.split(maxsplit=2)
        if len(parts) == 3 and re.search(r"executeStrictSum|tryAddChecked", parts[2], re.I):
            found.append(dict(address=parts[0], type=parts[1], name=parts[2]))
    return found

def sections(path):
    # objdump -drwC uses '<demangled name>:' for each function entry.
    result = []
    current = None
    for line in path.read_text().splitlines():
        match = re.match(r"^([0-9a-f]+) <(.+)>:$", line)
        if match:
            current = {"address": match.group(1), "symbol": match.group(2), "calls": []}
            if re.search(r"executeStrictSum|tryAddChecked", current["symbol"], re.I):
                result.append(current)
            continue
        if current is not None and current in result and re.search(r"\bcall(q)?\b", line):
            current["calls"].append(line.strip())
    return result

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("evidence_directory", type=Path)
    args = ap.parse_args()
    root = args.evidence_directory
    report = {}
    for compiler in ("dmd", "ldc2"):
        for arm in ("baseline", "candidate"):
            prefix = f"{compiler}-{arm}"
            sym = root / (prefix + ".symbols")
            dis = root / (prefix + ".disasm")
            if not sym.is_file() or not dis.is_file():
                raise SystemExit(f"Missing linked codegen artifact: {prefix}")
            matches = sections(dis)
            report[prefix] = {
                "relevant_symbols": symbols(sym),
                "strict_sum_functions": [s for s in matches if "executeStrictSum" in s["symbol"]],
                "helper_functions": [s for s in matches if "tryAddChecked" in s["symbol"]],
                "visibility_note": "No named strict sum: possible inlining/internalization" if
                  not any("executeStrictSum" in s["symbol"] for s in matches) else "named function visible"
            }
    out = root / "production-codegen-audit.json"
    out.write_text(json.dumps(report, indent=2) + "\n")
    for name, details in report.items():
        kernels = details["strict_sum_functions"]
        print(f"{name}: {len(kernels)} named strict-sum kernels")
        for k in kernels:
            helper_calls = [c for c in k["calls"] if "tryAddChecked" in c]
            print(f"  {k['address']} {k['symbol'][:140]} call_count={len(k['calls'])} helper_calls={len(helper_calls)}")
            for call in helper_calls:
                print(f"    {call[:220]}")
    print(f"audit_json={out}")

if __name__ == "__main__":
    main()
