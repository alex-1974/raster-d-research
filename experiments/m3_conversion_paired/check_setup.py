#!/usr/bin/env python3
"""Check both previous actual-code negatives and inherited source/linker gates."""
import importlib.util
from pathlib import Path
import sys
import collect as paired


def main():
    # Reuse the exact indexed source-isolation checks with the new adapter.
    sys.modules['collect'] = paired
    spec = importlib.util.spec_from_file_location('indexed_setup', paired.INDEXED / 'check_setup.py')
    setup = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(setup)
    setup.main()
    boundary = paired.load_boundary()
    old = (Path(__file__).resolve().parent / 'old-indexed-negative.txt').read_text()
    try:
        boundary.linked_control(old, 'native')
    except ValueError as error:
        if 'unchanged indexed scalar code' not in str(error):
            raise
    else:
        raise ValueError('old indexed scalar machine code accepted')
    print('PASS unchanged indexed machine code rejected')
    print('PASS safe paired-slice source isolation; actual D semantics require compiler CI')


if __name__ == '__main__':
    main()
