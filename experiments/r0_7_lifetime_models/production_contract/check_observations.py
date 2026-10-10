#!/usr/bin/env python3
"""Pinned real RasterLease/View compiler observations, never a general proof."""
import re
import sys
from pathlib import Path
if len(sys.argv) != 5:
    sys.exit("usage: check_observations.py MODE CASE OUTCOME LOG")
mode, case, outcome, logfile = sys.argv[1:]
expected = {
    "positive": ("accepted", None),
    "escape_return": ("rejected", r"escaping a reference to parameter .+ by returning"),
    "escape_global": (("accepted", None) if mode == "ordinary" else
                      ("rejected", r"assigning address of variable .+ to .+ with longer lifetime")),
    "escape_closure": (("accepted", None) if mode == "ordinary" else
                       ("rejected", r"assigning reference to local .+ to non-scope")),
}
if mode not in ("ordinary", "dip1000") or case not in expected:
    sys.exit("unknown compiler mode/case")
want, reason = expected[case]
log = Path(logfile).read_text(errors="replace")
valid = (outcome == want and
         (reason is None or re.search(reason, log, re.I) is not None))
if outcome == "accepted" and "Error:" in log:
    valid = False
print(f'{"PASS" if valid else "FAIL"} production_lifetime,{mode},{case},'
      f'expected={want},observed={outcome}')
if not valid:
    print(log[:3000], file=sys.stderr)
sys.exit(0 if valid else 1)
