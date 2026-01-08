#!/usr/bin/env python3
"""
Validate FASTA file for genome assembly.

Checks:
- File is not empty
- Contains valid FASTA headers
- Sequences contain only valid nucleotide characters
- No duplicate sequence IDs
"""

import argparse
import sys
import re
import json
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description='Validate FASTA file')
    parser.add_argument('fasta', type=Path, help='Input FASTA file')
    parser.add_argument('--output', '-o', type=Path, default='fasta_validation.json',
                        help='Output validation report JSON')
    return parser.parse_args()


def validate_fasta(fasta_path: Path) -> dict:
    """Validate FASTA file and return validation report."""

    report = {
        'file': str(fasta_path),
        'valid': True,
        'errors': [],
        'warnings': [],
        'stats': {
            'num_sequences': 0,
            'total_length': 0,
            'sequence_ids': [],
            'gc_content': 0.0
        }
    }

    # Check file exists
    if not fasta_path.exists():
        report['valid'] = False
        report['errors'].append(f"File does not exist: {fasta_path}")
        return report

    # Check file is not empty
    if fasta_path.stat().st_size == 0:
        report['valid'] = False
        report['errors'].append("File is empty")
        return report

    valid_nucleotides = set('ATCGNatcgn')
    valid_header_pattern = re.compile(r'^>(\S+)')
    sequence_ids = set()
    current_seq_id = None
    current_seq_length = 0
    total_gc = 0
    total_length = 0
    line_num = 0

    try:
        with open(fasta_path, 'r') as f:
            for line in f:
                line_num += 1
                line = line.rstrip('\n\r')

                if not line:  # Skip empty lines
                    continue

                if line.startswith('>'):
                    # Save previous sequence stats
                    if current_seq_id and current_seq_length == 0:
                        report['warnings'].append(
                            f"Sequence '{current_seq_id}' has no sequence data"
                        )

                    # Parse header
                    match = valid_header_pattern.match(line)
                    if not match:
                        report['valid'] = False
                        report['errors'].append(
                            f"Line {line_num}: Invalid header format '{line[:50]}...'"
                        )
                        continue

                    current_seq_id = match.group(1)

                    # Check for duplicate IDs
                    if current_seq_id in sequence_ids:
                        report['valid'] = False
                        report['errors'].append(
                            f"Duplicate sequence ID: {current_seq_id}"
                        )
                    else:
                        sequence_ids.add(current_seq_id)
                        report['stats']['sequence_ids'].append(current_seq_id)

                    report['stats']['num_sequences'] += 1
                    current_seq_length = 0

                else:
                    # Validate sequence line
                    if current_seq_id is None:
                        report['valid'] = False
                        report['errors'].append(
                            f"Line {line_num}: Sequence data before header"
                        )
                        continue

                    invalid_chars = set(line) - valid_nucleotides
                    if invalid_chars:
                        # Allow whitespace
                        invalid_chars -= set(' \t')
                        if invalid_chars:
                            report['valid'] = False
                            report['errors'].append(
                                f"Line {line_num}: Invalid characters: {invalid_chars}"
                            )

                    seq = line.upper().replace(' ', '').replace('\t', '')
                    current_seq_length += len(seq)
                    total_length += len(seq)
                    total_gc += seq.count('G') + seq.count('C')

    except Exception as e:
        report['valid'] = False
        report['errors'].append(f"Error reading file: {str(e)}")
        return report

    # Final sequence check
    if current_seq_id and current_seq_length == 0:
        report['warnings'].append(f"Sequence '{current_seq_id}' has no sequence data")

    # Check we found at least one sequence
    if report['stats']['num_sequences'] == 0:
        report['valid'] = False
        report['errors'].append("No valid sequences found in FASTA file")

    report['stats']['total_length'] = total_length
    if total_length > 0:
        report['stats']['gc_content'] = round(total_gc / total_length * 100, 2)

    return report


def main():
    args = parse_args()

    report = validate_fasta(args.fasta)

    # Write report
    with open(args.output, 'w') as f:
        json.dump(report, f, indent=2)

    # Print summary
    if report['valid']:
        print(f"✓ FASTA validation passed: {args.fasta}")
        print(f"  Sequences: {report['stats']['num_sequences']}")
        print(f"  Total length: {report['stats']['total_length']:,} bp")
        print(f"  GC content: {report['stats']['gc_content']}%")
    else:
        print(f"✗ FASTA validation failed: {args.fasta}", file=sys.stderr)
        for error in report['errors']:
            print(f"  ERROR: {error}", file=sys.stderr)

    for warning in report['warnings']:
        print(f"  WARNING: {warning}", file=sys.stderr)

    sys.exit(0 if report['valid'] else 1)


if __name__ == '__main__':
    main()
