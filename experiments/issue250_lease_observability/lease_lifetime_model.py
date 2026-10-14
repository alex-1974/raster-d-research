#!/usr/bin/env python3
"""Issue #250 bounded abstract model, NOT a DMD/LDC/raster-d executable test.

Models only:
  copy/retain -> +1 owner
  drop        -> -1 owner
  final drop  -> physical backing release exactly once
Borrowed views do not count as owners.
"""
from itertools import combinations, permutations

class Backing:
    def __init__(self, payload_bytes=1088):
        self.bytes = payload_bytes
        self.owners = set()
        self.physical_live = True
        self.release_events = 0

    def retain(self, name):
        assert self.physical_live and name not in self.owners
        self.owners.add(name)

    def drop(self, name):
        assert name in self.owners
        self.owners.remove(name)
        if not self.owners:
            self.physical_live = False
            self.release_events += 1

    def borrow_view(self, name):
        assert name in self.owners
        return ("borrow", name)

def cache_history(subscriber_releases):
    b = Backing()
    b.retain("cache")
    cache_events = [("create", len(b.owners))]
    b.retain("subscriber")
    cache_events.append(("deliver", len(b.owners)))
    b.drop("cache")
    cache_events.append(("evict", len(b.owners)))
    assert b.physical_live
    if subscriber_releases:
        b.drop("subscriber")
    return cache_events, b.physical_live

def run():
    a = cache_history(False)
    b = cache_history(True)
    assert a[0] == b[0] and a[1] != b[1]
    cases = 0
    for n in range(4):
        for selected in combinations(("sub0", "sub1", "sub2"), n):
            for teardown in permutations(("cache",) + selected):
                backing = Backing()
                for owner in ("cache",) + selected:
                    backing.retain(owner)
                view = backing.borrow_view("cache")
                assert len(backing.owners) == n + 1
                assert view == ("borrow", "cache")
                for pos, owner in enumerate(teardown):
                    backing.drop(owner)
                    is_last = pos == len(teardown) - 1
                    assert backing.physical_live == (not is_last)
                    assert backing.release_events == int(is_last)
                cases += 1
    assert cases == 49
    print("PASS: identical cache history, different physical-live state")
    print(f"PASS: {cases} short legal teardown histories")
    print("LIMITATION: abstract model; no D compiler/runtime claim")

if __name__ == "__main__":
    run()
