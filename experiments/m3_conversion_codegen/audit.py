#!/usr/bin/env python3
"""Compile full pinned public consumers; qualify safe forms without timing claims."""
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PRODUCTION = ROOT.parents[2] / 'raster-d'
PIN = '7dcdf01babf87e9a80af2864fbad75efe8e7d0ef'
PINS = {
    'source/raster/conversion.d': '837fe4ef749a059991311155acd7c3127022da636143782893e5d8c0077d8d00',
    'source/raster/internal/conversion_dispatch.d': '3c1cc242754c84e12e95d2372883845b452e7685fe56cbd407d99d48be655c93',
    'source/raster/internal/validated_affine_relation.d': '6b9170ccc3667b9298e2fde001a0c8d302d459d2f4b4985a0179cf120de06c39',
    'tests/integration/raster_copy_conversion/source/probe.d': '3e8b4be92699be466b6cf5d5698c9db15cbb5961bf6a8de4b344af7cd0a13328',
}


def run(args, log, cwd=None, succeeds=True):
    result = subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT)
    log.write_bytes(result.stdout)
    if succeeds:
        assert result.returncode == 0, (args, log)
    else:
        assert result.returncode != 0, ('safe challenge compiled', args)
        assert re.search(rb'(pointer|index|slice).*(@safe|safe function)', result.stdout, re.I)
    return result.stdout.decode()


def generate(directory, sources):
    (directory / 'raster').mkdir()
    public = sources['source/raster/conversion.d']
    dispatch = sources['source/raster/internal/conversion_dispatch.d']
    for form in ['signed', 'array']:
        internal = dispatch.replace('module raster.internal.conversion_dispatch;',
                                    f'module raster.variant_{form}_dispatch;', 1)
        if form == 'signed':
            old = 'destination[x] = cast(float)value;'
            new = 'destination[x] = cast(float)cast(int)value;'
        else:
            old = 'foreach (x, value; row)\n                destination[x] = cast(float)value;'
            new = 'destination[] = row[] + 0.0f;'
        assert internal.count(old) == 1
        internal = internal.replace(old, new, 1)
        (directory / 'raster' / f'variant_{form}_dispatch.d').write_text(internal)
        candidate = public.replace('module raster.conversion;',
                                   f'module raster.variant_{form};', 1)
        candidate = candidate.replace('import raster.internal.conversion_dispatch :',
                                      f'import raster.variant_{form}_dispatch :', 1)
        candidate, count = re.subn(
            r'enum UbyteToFloatConversionError : ubyte\n\{.*?\n\}',
            'import raster.conversion : UbyteToFloatConversionError;',
            candidate, count=1, flags=re.S)
        assert count == 1
        (directory / 'raster' / f'variant_{form}.d').write_text(candidate)

    for form in ['original', 'signed', 'array']:
        module = 'raster.conversion' if form == 'original' else f'raster.variant_{form}'
        wrapper = f'''module public_{form};
import {module} : tryConvertUbyteToFloatPlane;
import raster.conversion : UbyteToFloatConversionError;
import raster.view : RasterView;
import raster.writable_view : WritableRasterView;
extern(C) bool conversionPublic(scope RasterView!ubyte source,
    scope ref WritableRasterView!float target,
    out UbyteToFloatConversionError error) @safe nothrow @nogc
{{ return tryConvertUbyteToFloatPlane(source, 0, target, 0, error); }}
'''
        (directory / f'public_{form}.d').write_text(wrapper)

    fixture = sources['tests/integration/raster_copy_conversion/source/probe.d']
    fixture = fixture.replace('module raster.tests.copy_conversion_contract;',
                              'module raster.tests.conversion_codegen;')
    fixture = fixture.replace('import std.stdio : writeln;', '''import std.stdio : writeln;
import raster.variant_signed : signedConvert = tryConvertUbyteToFloatPlane;
import raster.variant_array : arrayConvert = tryConvertUbyteToFloatPlane;''')
    fixture = fixture.replace('ok=tryConvertUbyteToFloatPlane(s,si,d,di,e);', '''switch(path){
            case 0:ok=tryConvertUbyteToFloatPlane(s,si,d,di,e);break;
            case 1:ok=signedConvert(s,si,d,di,e);break;
            case 2:ok=arrayConvert(s,si,d,di,e);break;
            default:assert(0);
        }''')
    fixture = fixture.replace('string layout)', 'string layout,uint path=0)')
    fixture = fixture.replace('publicCall(0,source,0,target,0)', 'publicCall(path,source,0,target,0)', 1)
    fixture = fixture.replace('contracts!(ubyte,float)(0);sharedBacking(0);',
                              'foreach(path;0..3){contracts!(ubyte,float)(path);sharedBacking(path);sharedCanonicalConversion(path);}')
    fixture = fixture.replace('    sharedCanonicalConversion(0);\n', '')
    fixture = fixture.replace('verifyCase!(ubyte,float)(size[0],size[1],layout);',
                              'foreach(path;0..3)verifyCase!(ubyte,float)(size[0],size[1],layout,path);')
    fixture = fixture.replace('120 independent backing cases',
                              '72 full-public conversion backing cases + 96 unchanged Copy controls')
    fixture = fixture.replace('unittest{run();}', '')
    (directory / 'fixtures.d').write_text(fixture)


def excerpts(assembly, form):
    blocks = re.split(r'(?=^Disassembly of section )', assembly, flags=re.M)
    module = 'conversion_dispatch' if form == 'original' else f'variant_{form}_dispatch'
    selected = []
    for block in blocks:
        header = block.splitlines()[0] if block.splitlines() else ''
        if 'conversionPublic' in header or (
                module in header and any(name in header for name in [
                    'tryConvertUbyteToFloat', 'convertApprovedUbyteToFloatAffine2D',
                    'executeApprovedRows'])) or (
                form == 'original' and '6raster10conversion' in header):
            selected.append(block)
    result = '\n'.join(selected)
    assert '<conversionPublic>:' in result and module in result
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=Path)
    parser.add_argument('--compiler', choices=['dmd', 'ldc2', 'both'], default='both')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=PRODUCTION, text=True).strip() == PIN
    assert subprocess.run(['git', 'diff', '--quiet', 'HEAD'], cwd=PRODUCTION).returncode == 0
    sources = {}
    for path, digest in PINS.items():
        raw = (PRODUCTION / path).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == digest, path
        sources[path] = raw.decode()
    (output / 'pins.json').write_text(json.dumps(PINS, indent=2) + '\n')
    compilers = ['dmd', 'ldc2'] if args.compiler == 'both' else [args.compiler]
    with tempfile.TemporaryDirectory(prefix='raster-public-codegen-') as scratch:
        directory = Path(scratch)
        generate(directory, sources)
        generated = {str(p.relative_to(directory)): hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in sorted(directory.rglob('*.d'))}
        (output / 'generated.json').write_text(json.dumps(generated, indent=2) + '\n')
        for compiler in compilers:
            run([compiler, '--version'], output / f'{compiler}-version.txt')
            describe = run(['dub', 'describe', '--compiler=' + compiler],
                           directory / 'describe.json', cwd=PRODUCTION)
            packages = json.loads(describe)['packages']
            imports = ['-I' + str(Path(pkg['path']) / item)
                       for pkg in packages for item in pkg.get('importPaths', [])]
            imports += ['-I' + str(directory)]
            flags = ['-release', '-inline', '-O'] if compiler == 'dmd' else ['-release', '-enable-inlining', '-O3']
            common = [compiler, *flags, '-preview=dip1000', '-i', *imports]
            commands = []
            for form in ['original', 'signed', 'array']:
                obj = directory / f'{compiler}-{form}.o'
                command = [*common, '-c', '-of=' + str(obj), str(directory / f'public_{form}.d')]
                commands.append(command)
                run(command, output / f'{compiler}-{form}-build.txt')
                assembly = subprocess.check_output(['objdump', '-dr', str(obj)], text=True)
                (output / f'{compiler}-{form}-assembly.txt').write_text(excerpts(assembly, form))
                # Full objects and full disassembly are reproducible scratch outputs.
                (output / f'{compiler}-{form}-full.sha256').write_text(
                    hashlib.sha256(obj.read_bytes()).hexdigest() + '  full-object\n' +
                    hashlib.sha256(assembly.encode()).hexdigest() + '  full-assembly\n')
                source = sources['source/raster/internal/conversion_dispatch.d'] if form == 'original' else (
                    directory / 'raster' / f'variant_{form}_dispatch.d').read_text()
                helpers = source[source.index('/++\n    Safety: callers'):]
                prefix = 'module control;\nstruct Pod{uint a;ushort b;ubyte c;ubyte d;}\n'
                control = '''@safe pure nothrow @nogc void attributes(){
    ubyte[4] a,b; float[4] c,d; Pod[4] e,f; uint[2][4] g,h;
    executeApprovedRows(a.ptr,2,b.ptr,2,2,2);
    executeApprovedRows(c.ptr,2,d.ptr,2,2,2);
    executeApprovedRows(e.ptr,2,f.ptr,2,2,2);
    executeApprovedRows(g.ptr,2,h.ptr,2,2,2);
    executeApprovedRows(a.ptr,2,c.ptr,2,2,2);
}'''
                for safe in [False, True]:
                    probe = directory / 'control.d'
                    probe.write_text(prefix + (helpers.replace('@trusted', '@safe') if safe else helpers) + control)
                    command = [compiler, '-preview=dip1000', '-c', '-of=' + str(directory / 'control.o'), str(probe)]
                    commands.append(command)
                    run(command, output / f'{compiler}-{form}-trust-{safe}.txt', succeeds=not safe)
            binary = directory / f'{compiler}-unittests'
            command = [compiler, '-preview=dip1000', '-i', *imports, '-unittest',
                       '-of=' + str(binary), str(directory / 'fixtures.d')]
            commands.append(command)
            run(command, output / f'{compiler}-unittests-build.txt')
            result = run([str(binary)], output / f'{compiler}-unittests-run.txt')
            assert 'modules passed unittests' in result
            binary = directory / f'{compiler}-fixtures'
            command = [*common, '-of=' + str(binary), str(directory / 'fixtures.d')]
            commands.append(command)
            run(command, output / f'{compiler}-fixtures-build.txt')
            result = run([str(binary)], output / f'{compiler}-fixtures-run.txt')
            assert '72 full-public conversion backing cases + 96 unchanged Copy controls' in result
            (output / f'{compiler}-commands.json').write_text(json.dumps(commands, indent=2) + '\n')
            print(compiler, 'PASS full public codegen / inherited tests / backing and trust controls')
    (output / 'SHA256SUMS').write_text(''.join(
        hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.name + '\n'
        for p in sorted(output.iterdir()) if p.is_file() and p.name != 'SHA256SUMS'))


if __name__ == '__main__':
    main()
