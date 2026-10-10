#!/usr/bin/env python3
"""Validate R0.7 compiler outcomes and *reasons*, not just exit codes.

The ordinary-mode unsafe escapes are expected ACCEPTED observations, never
interpreted as proof of safety. callback_escape is deliberately not a
lifetime negative probe because its signature is incompatible.
"""
import argparse
import re
import sys
from pathlib import Path

# Outcome expectations are based on observed DMD 2.111.0 / LDC 1.41.0.
# Diagnostic patterns are deliberately narrow enough to reject a false
# negative caused by parser, import, or callback-type errors.
EXPECT = {
    "borrowed_escape": {
        "ordinary": ("accepted", None),
        "dip1000": ("rejected", r"scope parameter .+ may not be returned"),
    },
    "owned_return": {
        "ordinary": ("accepted", None),
        "dip1000": ("accepted", None),
    },
    "retained_malloc": {
        "ordinary": ("accepted", None),
        "dip1000": ("accepted", None),
    },
    "callback_escape": {
        "ordinary": ("rejected", r"not callable using argument types"),
        "dip1000": ("rejected", r"not callable using argument types"),
    },
    "callback_local": {
        "ordinary": ("accepted", None),
        "dip1000": ("accepted", None),
    },
    "callback_scope_positive": {
        "ordinary": ("accepted", None),
        "dip1000": ("accepted", None),
    },
    "callback_global_capture": {
        "ordinary": ("accepted", None),
        "dip1000": ("rejected", r"assigning scope variable .+ to global variable"),
    },
    "callback_closure_capture": {
        "ordinary": ("accepted", None),
        "dip1000": ("rejected", r"assigning scope variable .+ to global variable"),
    },
}
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["ordinary", "dip1000"])
    ap.add_argument("case", choices=sorted(EXPECT))
    ap.add_argument("outcome", choices=["accepted", "rejected"])
    ap.add_argument("log", type=Path)
    a = ap.parse_args()
    expected, pattern = EXPECT[a.case][a.mode]
    log = a.log.read_text(errors="replace")
    ok = a.outcome == expected and (
        pattern is None or bool(re.search(pattern, log, re.IGNORECASE))
    )
    # A successful compile must not hide error messages in the diagnostic log.
    if a.outcome == "accepted" and re.search(r"\bError:", log):
        ok = False
    status = "PASS" if ok else "FAIL"
    print(f"{status} diagnostic_gate,{a.mode},{a.case},"
          f"expected={expected},observed={a.outcome}", flush=True)
    if not ok:
        print("=== diagnostics ===", file=sys.stderr)
        print(log[:3500], file=sys.stderr)
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
