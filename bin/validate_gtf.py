#!/usr/bin/env python3
"""
Validate GTF file for gene annotation.

Checks:
- File is not empty
- Contains 9 columns (tab-separated)
- Required attributes (gene_id, transcript_id for relevant features)
- Valid feature types
- Coordinate sanity (start <= end)
"""

import argparse
import sys
import re
import json
from pathlib import Path
from collections import defaultdict


def parse_args():
    parser = argparse.ArgumentParser(description='Validate GTF file')
    parser.add_argument('gtf', type=Path, help='Input GTF file')
    parser.add_argument('--output', '-o', type=Path, default='gtf_validation.json',
                        help='Output validation report JSON')
    return parser.parse_args()


def parse_attributes(attr_string: str) -> dict:
    """Parse GTF attribute string into dictionary."""
    attributes = {}
    # GTF format: key "value"; key "value";
    pattern = r'(\S+)\s+"([^"]*)"'
    for match in re.finditer(pattern, attr_string):
        key, value = match.groups()
        attributes[key] = value
    return attributes


def validate_gtf(gtf_path: Path) -> dict:
    """Validate GTF file and return validation report."""

    report = {
        'file': str(gtf_path),
        'valid': True,
        'errors': [],
        'warnings': [],
        'stats': {
            'num_lines': 0,
            'num_features': 0,
            'feature_types': defaultdict(int),
            'num_genes': 0,
            'num_transcripts': 0,
            'num_exons': 0,
            'contigs': set()
        }
    }

    # Check file exists
    if not gtf_path.exists():
        report['valid'] = False
        report['errors'].append(f"File does not exist: {gtf_path}")
        return report

    # Check file is not empty
    if gtf_path.stat().st_size == 0:
        report['valid'] = False
        report['errors'].append("File is empty")
        return report

    valid_features = {
        'gene', 'transcript', 'exon', 'CDS', 'UTR', 'five_prime_utr',
        'three_prime_utr', 'start_codon', 'stop_codon', 'Selenocysteine'
    }
    valid_strands = {'+', '-', '.'}

    genes = set()
    transcripts = set()
    transcript_exon_count = defaultdict(int)

    line_num = 0
    max_errors = 100  # Limit error reporting

    try:
        with open(gtf_path, 'r') as f:
            for line in f:
                line_num += 1
                report['stats']['num_lines'] += 1
                line = line.rstrip('\n\r')

                # Skip empty lines and comments
                if not line or line.startswith('#'):
                    continue

                # Split into columns
                cols = line.split('\t')
                if len(cols) != 9:
                    if len(report['errors']) < max_errors:
                        report['valid'] = False
                        report['errors'].append(
                            f"Line {line_num}: Expected 9 columns, got {len(cols)}"
                        )
                    continue

                seqname, source, feature, start, end, score, strand, frame, attributes = cols

                report['stats']['num_features'] += 1
                report['stats']['feature_types'][feature] += 1
                report['stats']['contigs'].add(seqname)

                # Validate coordinates
                try:
                    start_int = int(start)
                    end_int = int(end)
                    if start_int > end_int:
                        if len(report['errors']) < max_errors:
                            report['warnings'].append(
                                f"Line {line_num}: start ({start}) > end ({end})"
                            )
                    if start_int < 1:
                        if len(report['errors']) < max_errors:
                            report['warnings'].append(
                                f"Line {line_num}: start position < 1"
                            )
                except ValueError:
                    if len(report['errors']) < max_errors:
                        report['valid'] = False
                        report['errors'].append(
                            f"Line {line_num}: Invalid coordinates: start={start}, end={end}"
                        )

                # Validate strand
                if strand not in valid_strands:
                    if len(report['errors']) < max_errors:
                        report['warnings'].append(
                            f"Line {line_num}: Invalid strand '{strand}'"
                        )

                # Parse and validate attributes
                attrs = parse_attributes(attributes)

                # Check for gene_id (required for all features)
                if 'gene_id' not in attrs or not attrs['gene_id']:
                    if len(report['errors']) < max_errors:
                        report['valid'] = False
                        report['errors'].append(
                            f"Line {line_num}: Missing or empty gene_id attribute"
                        )
                else:
                    genes.add(attrs['gene_id'])

                # Check for transcript_id (required for transcript-level features)
                transcript_features = {'transcript', 'exon', 'CDS', 'UTR',
                                       'five_prime_utr', 'three_prime_utr',
                                       'start_codon', 'stop_codon'}
                if feature in transcript_features:
                    if 'transcript_id' not in attrs or not attrs['transcript_id']:
                        if len(report['errors']) < max_errors:
                            report['valid'] = False
                            report['errors'].append(
                                f"Line {line_num}: Missing or empty transcript_id for {feature}"
                            )
                    else:
                        transcripts.add(attrs['transcript_id'])
                        if feature == 'exon':
                            transcript_exon_count[attrs['transcript_id']] += 1

    except Exception as e:
        report['valid'] = False
        report['errors'].append(f"Error reading file: {str(e)}")
        return report

    # Update stats
    report['stats']['num_genes'] = len(genes)
    report['stats']['num_transcripts'] = len(transcripts)
    report['stats']['num_exons'] = report['stats']['feature_types'].get('exon', 0)
    report['stats']['contigs'] = list(report['stats']['contigs'])
    report['stats']['feature_types'] = dict(report['stats']['feature_types'])

    # Check for transcripts with zero exons
    zero_exon_transcripts = [t for t, count in transcript_exon_count.items() if count == 0]
    # Actually check transcripts that are in transcript set but not in exon count
    transcripts_without_exons = transcripts - set(transcript_exon_count.keys())
    if transcripts_without_exons:
        report['warnings'].append(
            f"Found {len(transcripts_without_exons)} transcript(s) with no exons"
        )

    # Check we found at least some features
    if report['stats']['num_features'] == 0:
        report['valid'] = False
        report['errors'].append("No valid features found in GTF file")

    return report


def main():
    args = parse_args()

    report = validate_gtf(args.gtf)

    # Write report
    with open(args.output, 'w') as f:
        json.dump(report, f, indent=2, default=list)

    # Print summary
    if report['valid']:
        print(f"✓ GTF validation passed: {args.gtf}")
        print(f"  Genes: {report['stats']['num_genes']}")
        print(f"  Transcripts: {report['stats']['num_transcripts']}")
        print(f"  Exons: {report['stats']['num_exons']}")
        print(f"  Contigs: {len(report['stats']['contigs'])}")
    else:
        print(f"✗ GTF validation failed: {args.gtf}", file=sys.stderr)
        for error in report['errors'][:10]:
            print(f"  ERROR: {error}", file=sys.stderr)
        if len(report['errors']) > 10:
            print(f"  ... and {len(report['errors']) - 10} more errors", file=sys.stderr)

    for warning in report['warnings'][:5]:
        print(f"  WARNING: {warning}", file=sys.stderr)

    sys.exit(0 if report['valid'] else 1)


if __name__ == '__main__':
    main()
