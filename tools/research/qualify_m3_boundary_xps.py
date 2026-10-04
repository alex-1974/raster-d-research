#!/usr/bin/env python3
"""Verify an extracted complete boundary collection and emit a compact record."""
import csv
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

REPO = Path(__file__).resolve().parents[2]
EXPERIMENT = REPO / 'experiments/m3_conversion_boundary'


def qualify(root):
    if not __debug__:
        raise RuntimeError('assertions must be enabled')
    manifests = {}
    for name in ('SHA256SUMS', 'audit-SHA256SUMS'):
        entries = (root / name).read_text().splitlines()
        for line in entries:
            digest, relative = line.split('  ', 1)
            path = (root / relative).resolve()
            if not path.is_relative_to(root.resolve()):
                raise ValueError('manifest path escapes evidence')
            if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                raise ValueError('manifest mismatch: ' + relative)
        manifests[name] = len(entries)
    metadata = json.loads((root / 'collection.json').read_text())
    if metadata['processes'] != 6 or metadata['compiler'] != 'both' or metadata['positions'] != ['native', '0', '8', '16', '24']:
        raise ValueError('expected complete six-process hardware collection')
    for group, folder in [('own_inputs', EXPERIMENT), ('parent_inputs', EXPERIMENT.with_name('m3_conversion_selection'))]:
        for name, digest in metadata[group].items():
            if hashlib.sha256((folder / name).read_bytes()).hexdigest() != digest:
                raise ValueError('source input mismatch: ' + name)
    spec = importlib.util.spec_from_file_location('boundary', EXPERIMENT / 'collect.py')
    boundary = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(boundary)
    summary = boundary.replay(root)
    if summary != (root / 'summary.csv').read_text():
        raise ValueError('exact summary replay mismatch')
    rows = list(csv.DictReader(summary.splitlines()))
    records, bodies = [], set()
    for item in metadata['cohorts']:
        for mode in boundary.MODES:
            child = root / item['cohort'] / mode
            selected = [r for r in rows if r['cohort'] == item['cohort'] and r['mode'] == mode and r['form'] == 'selected64']
            low = [r for r in selected if int(r['width']) < 64 and r['layout'] != 'universal']
            anchor = next(r for r in selected if (r['width'], r['height'], r['layout']) == ('31', '17', 'contiguous'))
            large = next(r for r in selected if (r['width'], r['height'], r['layout']) == ('2048', '512', 'contiguous'))
            record = {'cohort': item['cohort'], 'mode': mode,
                      'anchor': anchor, 'large': large,
                      'small_approved_cases': len(low),
                      'small_approved_median_losses': sum(float(r['original_over_form_median']) < 1 for r in low),
                      'small_approved_ratio_min': min(float(r['original_over_form_median']) for r in low),
                      'small_approved_ratio_max': max(float(r['original_over_form_median']) for r in low),
                      'small_approved_all_process_ratio_min': min(float(r['original_over_form_min']) for r in low)}
            if item['compiler'] == 'dmd':
                placement = json.loads((child / 'placement.json').read_text())
                full = gzip.decompress((child / 'full-linked-assembly.txt.gz').read_bytes()).decode()
                blocks = re.split(r'(?=^[0-9a-f]+ <)', full, flags=re.M)
                block = next(b for b in blocks if f'<{boundary.SCALAR}>:' in b.splitlines()[0])
                instructions = []
                for line in block.splitlines()[1:]:
                    match = re.match(r'\s*([0-9a-f]+):\s*((?:[0-9a-f]{2} )+)\s*(.+)', line)
                    if match:
                        instructions.append((int(match[1], 16), bytes.fromhex(match[2]), match[3].strip()))
                        if match[3].strip() == 'ret':
                            break
                if not instructions or instructions[-1][2] != 'ret':
                    raise ValueError('scalar return not found')
                body_digest = hashlib.sha256(b''.join(i[1] for i in instructions)).hexdigest()
                bodies.add(body_digest)
                pairs = []
                for lhs, rhs in zip(instructions, instructions[1:]):
                    if lhs[2].startswith('cmp') and rhs[2].split()[0] in ('jae', 'jb'):
                        end = rhs[0] + len(rhs[1])
                        pairs.append({'compare': lhs[2], 'branch': rhs[2].split()[0],
                                      'start': hex(lhs[0]), 'end_exclusive': hex(end),
                                      'crosses_or_ends_32_byte_boundary': lhs[0] // 32 != end // 32})
                entries = placement.pop('other_function_entries')
                placement['other_entries_sha256'] = hashlib.sha256(json.dumps(entries, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
                placement['other_function_count'] = len(entries)
                record.update(placement=placement, scalar_body_sha256=body_digest, compare_branch_pairs=pairs)
            records.append(record)
    if len(bodies) != 1:
        raise ValueError('scalar bytes differ between placements or modes')
    processes, blocks, calls = 0, 0, 0
    for path in root.glob('*/*/*-timing-*.tsv'):
        processes += 1
        for line in path.read_text().splitlines():
            blocks += 1
            calls += int(line.split('\t')[8])
    if processes != 144:
        raise ValueError('missing process evidence')
    return {'source_commit': 'cd293ff6443ebce0fdbeec1d2962eb85a4e13ec9',
            'manifests': manifests, 'processes': processes, 'timed_blocks': blocks,
            'timed_calls': calls, 'summary_rows': len(rows),
            'summary_sha256': hashlib.sha256(summary.encode()).hexdigest(),
            'checks': 'exact full replay, input hashes, fixed other entries, actual calls, exact offsets, 72 backing fingerprints, identical scalar bytes through first return',
            'records': records}


if __name__ == '__main__':
    result = qualify(Path(sys.argv[1]))
    if len(sys.argv) > 2:
        archive = Path(sys.argv[2])
        result['raw_archive'] = {'name': archive.name, 'bytes': archive.stat().st_size,
                                 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}
    print(json.dumps(result, indent=2, sort_keys=True))
