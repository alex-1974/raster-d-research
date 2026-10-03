#!/usr/bin/env python3
"""Compile full pinned public consumers; qualify exact packed forms and measure full public calls."""
import argparse
import hashlib
import json
import os
import platform
import re
import subprocess
import tempfile
from summarize import summarize
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
        assert re.search(rb'(pointer|index|slice|cast|\.ptr)', result.stdout, re.I) and b'@safe' in result.stdout
    return result.stdout.decode()


def generate(directory, sources):
    (directory / 'raster').mkdir()
    public = sources['source/raster/conversion.d']
    dispatch = sources['source/raster/internal/conversion_dispatch.d']
    for form in ['vector16safe', 'vector16store']:
        internal = dispatch.replace('module raster.internal.conversion_dispatch;',
                                    f'module raster.variant_{form}_dispatch;', 1)
        old = 'foreach (x, value; row)\n                destination[x] = cast(float)value;'
        assert internal.count(old) == 1
        internal = internal.replace(old, 'convertApprovedRow(row, destination);', 1)
        internal += '\n' + (ROOT / f'{form}.d').read_text()
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

    for form in ['original', 'vector16safe', 'vector16store']:
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
import raster.variant_vector16safe : vector16safeConvert = tryConvertUbyteToFloatPlane;
import raster.variant_vector16store : vector16storeConvert = tryConvertUbyteToFloatPlane;''')
    fixture = fixture.replace('ok=tryConvertUbyteToFloatPlane(s,si,d,di,e);', '''switch(path){
            case 0:ok=tryConvertUbyteToFloatPlane(s,si,d,di,e);break;
            case 1:ok=vector16safeConvert(s,si,d,di,e);break;
            case 2:ok=vector16storeConvert(s,si,d,di,e);break;
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
    timing=(ROOT/'timing.d').read_text()
    assert timing.startswith((ROOT/'cpp_bridge.d').read_text())
    benchmark = fixture[:fixture.index('void run()')] + timing
    (directory / 'timing.d').write_text(benchmark)
    shared = fixture[:fixture.index('void run()')] + (ROOT / 'shared_controls.d').read_text()
    (directory / 'shared.d').write_text(shared)


def excerpts(assembly, form):
    blocks = re.split(r'(?=^Disassembly of section )', assembly, flags=re.M)
    module = 'conversion_dispatch' if form == 'original' else f'variant_{form}_dispatch'
    selected = []
    for block in blocks:
        header = block.splitlines()[0] if block.splitlines() else ''
        if 'conversionPublic' in header or (
                module in header and any(name in header for name in [
                    'tryConvertUbyteToFloat', 'convertApprovedUbyteToFloatAffine2D',
                    'executeApprovedRows', 'convertApprovedRow', 'readVectorBlock', 'writeVectorBlock'])) or (
                form == 'original' and '6raster10conversion' in header):
            selected.append(block)
    result = '\n'.join(selected)
    assert '<conversionPublic>:' in result and module in result
    return result


def main():
    if not __debug__:
        raise RuntimeError('qualification requires Python assertions')
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=Path)
    parser.add_argument('--processes', type=int, default=6)
    parser.add_argument('--compiler', choices=['dmd', 'ldc2', 'both'], default='both')
    args = parser.parse_args()
    assert 1 <= args.processes <= 6
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=PRODUCTION, text=True).strip() == PIN
    assert subprocess.run(['git', 'diff', '--quiet', 'HEAD'], cwd=PRODUCTION).returncode == 0
    affinity = sorted(os.sched_getaffinity(0))
    os.sched_setaffinity(0, {affinity[0]})
    (output / 'host.json').write_text(json.dumps(dict(platform=platform.platform(),
        cpu=Path('/proc/cpuinfo').read_text(), affinity_before=affinity,
        affinity_used=[affinity[0]], processes=args.processes,
        frequency_thermal_controls='unchanged; not sampled'), indent=2) + '\n')
    sources = {}
    for path, digest in PINS.items():
        raw = (PRODUCTION / path).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == digest, path
        sources[path] = raw.decode()
    (output / 'pins.json').write_text(json.dumps(PINS, indent=2) + '\n')
    (output/'matrix.json').write_bytes((ROOT/'matrix.json').read_bytes())
    source_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(ROOT.iterdir()) if p.suffix in {'.py','.d','.cpp','.json'}}
    (output/'experiment-sources.json').write_text(json.dumps(source_hashes,indent=2)+'\n')
    compilers = ['dmd', 'ldc2'] if args.compiler == 'both' else [args.compiler]
    with tempfile.TemporaryDirectory(prefix='raster-public-crossover-') as scratch:
        directory = Path(scratch)
        generate(directory, sources)
        generated = {str(p.relative_to(directory)): hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in sorted(directory.rglob('*.d'))}
        (output / 'generated.json').write_text(json.dumps(generated, indent=2) + '\n')
        cpp_obj=directory/'reference.o'
        cpp_command=['g++','-std=c++17','-O3','-fno-fast-math','-march=x86-64','-mtune=generic','-c',str(ROOT/'reference.cpp'),'-o',str(cpp_obj)]
        run(['g++','--version'],output/'cpp-version.txt')
        run(cpp_command,output/'cpp-build.txt')
        (output/'cpp-commands.json').write_text(json.dumps(cpp_command,indent=2)+'\n')
        (output/'cpp-assembly.txt').write_bytes(subprocess.check_output(['objdump','-dr',str(cpp_obj)]))
        (output/'cpp-object.sha256').write_text(hashlib.sha256(cpp_obj.read_bytes()).hexdigest()+'  reference-object\n')
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
            portable = '-version=RasterForcePortable' if compiler == 'dmd' else '--d-version=RasterForcePortable'
            commands = []
            for form in ['original', 'vector16safe', 'vector16store']:
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
                if form != 'original':
                    narrow = helpers[helpers.index('/++ Vector kernel:'):]
                    probe = directory / 'narrow.d'
                    attributes = '@safe pure nothrow @nogc void attributes(scope const(ubyte)[] a, scope float[] b){convertApprovedRow(a,b);}'
                    if compiler == 'dmd':
                        probe.write_text('module narrow;\n' + narrow.replace('@trusted', '@safe') + attributes)
                        command = [compiler, '-preview=dip1000', '-c', '-of=' + str(directory / 'narrow.o'), str(probe)]
                        commands.append(command)
                        run(command, output / f'{compiler}-{form}-narrow-negative.txt', succeeds=False)

                    if compiler == 'dmd':
                        for helper in ['readVectorBlock'] + (['writeVectorBlock'] if form == 'vector16store' else []):
                            # Restrict start to this helper, not preceding comments/functions.
                            pattern = r'(private (?:ubyte16|void) ' + helper + r'\([^)]*\)[^@]*?)@trusted'
                            changed,count=re.subn(pattern,r'\1@safe',narrow,count=1,flags=re.S)
                            assert count==1
                            probe.write_text('module narrow;\n' + changed + attributes)
                            command=[compiler,'-preview=dip1000','-c','-of='+str(directory/'narrow.o'),str(probe)]
                            commands.append(command)
                            run(command,output/f'{compiler}-{form}-{helper}-negative.txt',succeeds=False)
                    checks = (ROOT / 'row_controls.d').read_text()
                    probe.write_text('module narrow;\n' + narrow + attributes + checks)
                    command = [compiler, '-preview=dip1000', '-of=' + str(directory / 'narrow'), str(probe)]
                    commands.append(command)
                    run(command, output / f'{compiler}-{form}-narrow-build.txt')
                    result = run([str(directory / 'narrow')], output / f'{compiler}-{form}-narrow-run.txt')
                    assert ('enabled=true' if compiler == 'dmd' else 'enabled=false') in result
                    command = [compiler, '-preview=dip1000', portable,
                               '-of=' + str(directory / 'narrow-portable'), str(probe)]
                    commands.append(command)
                    run(command, output / f'{compiler}-{form}-narrow-portable-build.txt')
                    result = run([str(directory / 'narrow-portable')], output / f'{compiler}-{form}-narrow-portable-run.txt')
                    assert 'enabled=false' in result

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
            command = [*common, portable,
                       '-of=' + str(binary), str(directory / 'fixtures.d')]
            commands.append(command)
            run(command, output / f'{compiler}-portable-fixtures-build.txt')
            result = run([str(binary)], output / f'{compiler}-portable-fixtures-run.txt')
            assert '72 full-public conversion backing cases + 96 unchanged Copy controls' in result
            for fallback in [False, True]:
                shared_binary=directory/f'{compiler}-shared-{fallback}'
                command=[*common,*([portable] if fallback else []),
                         '-of='+str(shared_binary),str(directory/'shared.d')]
                commands.append(command)
                run(command,output/f'{compiler}-shared-{fallback}-build.txt')
                result=run([str(shared_binary)],output/f'{compiler}-shared-{fallback}-run.txt')
                assert 'PASS 9 vector-active shared-backing cases' in result
            cpp_probe=directory/'cpp-control.d'
            cpp_helper=(ROOT/'cpp_bridge.d').read_text()+"enum vectorEnabled=false;\nprivate void convertApprovedRow(scope const(ubyte)[] a,scope float[] b) @safe nothrow @nogc {assert(a.length==b.length);cppFixture(a,b,0,0,cast(ptrdiff_t)a.length,1,cast(ptrdiff_t)b.length,1,a.length,1);}\n"
            cpp_probe.write_text('module cpp_control;\n'+cpp_helper+(ROOT/'row_controls.d').read_text())
            command=[compiler,'-preview=dip1000','-of='+str(directory/'cpp-control'),str(cpp_probe),str(cpp_obj)]
            commands.append(command)
            run(command,output/f'{compiler}-cpp-controls-build.txt')
            run([str(directory/'cpp-control')],output/f'{compiler}-cpp-controls-run.txt')
            cpp_probe.write_text('module cpp_control;\n'+cpp_helper.replace('@trusted','@safe'))
            command=[compiler,'-preview=dip1000','-c','-of='+str(directory/'cpp-control.o'),str(cpp_probe)]
            commands.append(command)
            run(command,output/f'{compiler}-cpp-trust-negative.txt',succeeds=False)
            binary = directory / f'{compiler}-timing'
            command = [*common, '-of=' + str(binary), str(directory / 'timing.d'),str(cpp_obj)]
            commands.append(command)
            run(command, output / f'{compiler}-timing-build.txt')
            (output / f'{compiler}-timing-binary.sha256').write_text(
                hashlib.sha256(binary.read_bytes()).hexdigest() + '  fixed-timing-binary\n')
            assembly = subprocess.check_output(['objdump', '-dr', str(binary)], text=True)
            # Linked ELF usually has one .text section: retain function blocks instead.
            selected = [b for b in re.split(r'(?=^[0-9a-f]+ <)', assembly, flags=re.M)
                        if b.splitlines() and any(n in b.splitlines()[0] for n in
                            ['timedCase', 'variant_vector', 'conversion_dispatch'])]
            (output / f'{compiler}-linked-assembly.txt').write_text(''.join(selected))
            for process in range(args.processes):
                result = run([str(binary), str(process)], output / f'{compiler}-timing-{process}.tsv')
                assert result.count('TIME\t') == len(json.loads((ROOT/'matrix.json').read_text()))*4*9, 'incomplete timing process'
            (output / f'{compiler}-commands.json').write_text(json.dumps(commands, indent=2) + '\n')
            print(compiler, 'PASS full public codegen / inherited tests / backing and trust controls')
    assert source_hashes=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(ROOT.iterdir()) if p.suffix in {'.py','.d','.cpp','.json'}}, 'experiment inputs changed during collection'
    (output / 'summary.csv').write_text(summarize(output))
    (output / 'SHA256SUMS').write_text(''.join(
        hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.name + '\n'
        for p in sorted(output.iterdir()) if p.is_file() and p.name != 'SHA256SUMS'))


if __name__ == '__main__':
    main()
