#!/usr/bin/env python3
"""Check inherited controls and challenge the isolated pointer helper's trust."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import collect as pointer


def main():
    sys.modules['collect'] = pointer
    original_load = pointer.load_boundary

    def inherited_load():
        boundary = original_load()
        boundary.preserve_boundary = boundary._base_preserve_boundary
        boundary.linked_control = boundary._base_linked_control
        return boundary

    pointer.load_boundary = inherited_load
    try:
        spec = importlib.util.spec_from_file_location('indexed_setup', pointer.INDEXED / 'check_setup.py')
        setup = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(setup)
        setup.main()
    finally:
        pointer.load_boundary = original_load
    boundary = pointer.load_boundary()
    helper = pointer.POINTER_HELPER
    compiler = os.environ.get('DC', 'dmd')
    with tempfile.TemporaryDirectory(prefix='pointer-trust-') as temp:
        directory = Path(temp)
        for safe in (False, True):
            code = helper.replace('@trusted', '@safe') if safe else helper
            source = directory / ('negative.d' if safe else 'positive.d')
            source.write_text('module pointer_probe;\n' + code + '\n')
            output = directory / ('negative.o' if safe else 'positive.o')
            run = subprocess.run([compiler, '-preview=dip1000', '-c', '-of=' + str(output), str(source)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            (directory / ('negative.txt' if safe else 'positive.txt')).write_text(run.stdout)
            if safe and run.returncode == 0:
                raise ValueError('pointer kernel unexpectedly compiles as @safe')
            if not safe and run.returncode != 0:
                raise ValueError('trusted pointer kernel fails to compile: ' + run.stdout)
    print('PASS isolated pointer trust challenge: @trusted compiles, @safe replacement fails')
    print('PASS DMD-only bounded pointer/count source isolation; actual D semantics require compiler CI')


if __name__ == '__main__':
    main()
