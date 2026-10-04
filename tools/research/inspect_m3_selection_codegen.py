#!/usr/bin/env python3
"""Inspect retained linked DMD loops; static evidence, never a timing verdict."""
import argparse
import csv
import gzip
import hashlib
import json
import re
from pathlib import Path

MODES = ('prior-short', 'prior-long', 'sweep-short', 'sweep-long')
FUNCTIONS = {
    'flat': 'convertUbyteToFloatRasterPlane',
    'affine': 'convertApprovedUbyteToFloatAffine2D',
}
INSTRUCTION = re.compile(r'\s*([0-9a-f]+):\s*((?:[0-9a-f]{2}\s)+)\s*(\S.*)')


def instructions(block):
    result = []
    for line in block.splitlines()[1:]:
        match = INSTRUCTION.fullmatch(line)
        if match:
            result.append((int(match[1], 16), bytes.fromhex(match[2]), match[3]))
    return result


def span(start, end):
    return {
        'start': hex(start), 'end_exclusive': hex(end),
        'start_mod32': start % 32, 'end_mod32': end % 32,
        'crosses_32': start // 32 != (end - 1) // 32,
        'ends_on_32': end % 32 == 0,
    }


def inspect(root):
    manifest = dict((name, digest) for digest, name in
                    (line.split('  ', 1) for line in (root / 'SHA256SUMS').read_text().splitlines()))
    summary_file = root / 'summary.csv'
    if hashlib.sha256(summary_file.read_bytes()).hexdigest() != manifest['summary.csv']:
        raise ValueError('summary checksum mismatch')
    summary = list(csv.DictReader(summary_file.open()))
    output = {'scope': 'retained DMD linked code; no new compilation or measurement',
              'modes': {}}
    common_loop = None
    for mode in MODES:
        path = root / mode / 'dmd-linked-assembly.txt.gz'
        relative = str(path.relative_to(root))
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != manifest[relative]:
            raise ValueError('assembly checksum mismatch: ' + relative)
        blocks = [b for b in re.split(r'(?=^[0-9a-f]+ <)',
                  gzip.decompress(path.read_bytes()).decode(), flags=re.M) if b]
        data = {'linked_assembly_sha256': digest, 'paths': {}}
        for route, name in FUNCTIONS.items():
            forms = {}
            for form, module in [('original', '8internal19conversion_dispatch'),
                                 ('selected64', '27variant_selected64_dispatch')]:
                matches = [b for b in blocks if name in b.splitlines()[0]
                           and module in b.splitlines()[0]]
                if len(matches) != 1:
                    raise ValueError('ambiguous/missing function: ' + mode + route + form)
                block = matches[0]
                code = instructions(block)
                # First scalar conversion belongs to the approved unit-stride path;
                # later conversions can belong to the Universal fallback.
                conversion = next(i for i, v in enumerate(code) if 'cvtsi2ss' in v[2])
                first = max(i for i in range(conversion) if 'movzbl (' in code[i][2])
                last = next(i for i in range(conversion, len(code)) if code[i][2].startswith('jb '))
                loop = code[first:last + 1]
                normalized = [re.sub(r'^(j\w+)\s+.*', r'\1 <target>', v[2]) for v in loop]
                if common_loop is None:
                    common_loop = normalized
                if normalized != common_loop:
                    raise ValueError('scalar loop instructions differ: ' + mode + route + form)
                check = next(v for v in loop if v[2].startswith('jae '))
                if not loop[-2][2].startswith('cmp ') or not loop[-1][2].startswith('jb '):
                    raise ValueError('unexpected tail shape')
                forms[form] = {
                    'symbol': block.splitlines()[0],
                    'instruction_count': len(loop),
                    'normalized_loop_sha256': hashlib.sha256('\n'.join(normalized).encode()).hexdigest(),
                    'loop_start': hex(loop[0][0]),
                    'bounds_jump': span(check[0], check[0] + len(check[1])),
                    'tail_compare_branch_span': span(loop[-2][0], loop[-1][0] + len(loop[-1][1])),
                    'loop_listing': [{'address': hex(v[0]), 'bytes': v[1].hex(), 'assembly': v[2]} for v in loop],
                }
            data['paths'][route] = forms
        consumer, block_length = mode.split('-')
        data['31x17_selected_ratios'] = {
            row['layout']: {'median': row['original_over_form_median'],
                            'min': row['original_over_form_min'], 'max': row['original_over_form_max']}
            for row in summary if row['compiler'] == 'dmd' and row['form'] == 'selected64'
            and row['consumer'] == consumer and row['block'] == block_length
            and row['width'] == '31' and row['height'] == '17'
        }
        output['modes'][mode] = data
    output['normalized_scalar_loop'] = common_loop
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    args = parser.parse_args()
    print(json.dumps(inspect(args.evidence), indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
