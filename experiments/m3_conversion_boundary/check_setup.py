#!/usr/bin/env python3
"""Check source adaptation and GNU linker controls without claiming D builds."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from collect import PARENT, linker_script, load_parent, preserve_boundary


def main():
    audit = load_parent()
    sources = {}
    for name, digest in audit.PINS.items():
        data = (audit.PRODUCTION / name).read_bytes()
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError('production source pin mismatch')
        sources[name] = data.decode()
    with tempfile.TemporaryDirectory(prefix='raster-boundary-setup-') as temp:
        root = Path(temp)
        for profile in ('prior', 'sweep'):
            for block in ('short', 'long'):
                directory = root / (profile + '-' + block)
                directory.mkdir()
                audit.generate(directory, sources, profile, block)
                path = directory / 'raster/variant_selected64_dispatch.d'
                before = path.read_text()
                after = preserve_boundary(before)
                if after.count('pragma(inline, false)') != 1:
                    raise ValueError('boundary annotation mismatch')
                if after.count('@trusted') != before.count('@trusted'):
                    raise ValueError('trust boundary changed')
                if 'static if (vectorEnabled) {\npragma(inline, false)' not in after:
                    raise ValueError('compiler/portable gate missing')
                # The unmodified baseline generator must never annotate Original.
                if 'pragma(inline, false)' in sources['source/raster/internal/conversion_dispatch.d']:
                    raise ValueError('original baseline annotated')
        c = root / 'linker-probe.c'
        c.write_text('''__attribute__((section(".text.m3_probe"),noinline))
int m3_probe(int x) { return x+1; }
int main(void) { return m3_probe(6) == 7 ? 0 : 1; }
''')
        obj = root / 'probe.o'
        subprocess.run(['gcc', '-O2', '-ffunction-sections', '-c', str(c), '-o', str(obj)], check=True)
        entries = None
        for offset in (0, 8, 16, 24):
            script = root / f'p{offset}.ld'
            script.write_text(linker_script(offset, 'm3_probe'))
            binary = root / f'p{offset}'
            subprocess.run(['gcc', str(obj), '-Wl,-T,' + str(script), '-o', str(binary)], check=True)
            subprocess.run([str(binary)], check=True)
            listing = subprocess.check_output(['nm', '-n', str(binary)], text=True)
            symbols = {m[3]: int(m[1], 16) for line in listing.splitlines()
                       if (m := re.fullmatch(r'([0-9a-f]+) ([tT]) (.*)', line))}
            if symbols['m3_probe'] % 32 != offset:
                raise ValueError('GNU linker offset control failed')
            other = {name: address for name, address in symbols.items() if name != 'm3_probe'}
            if entries is None:
                entries = other
            if other != entries:
                raise ValueError('other C function placement changed')
            print('PASS GNU linker offset', offset, 'other function addresses fixed')
    print('PASS source adaptation / existing trust markers / four GNU linker replicas')
    print('D compiler semantics and timings still require compiler qualification')


if __name__ == '__main__':
    main()
