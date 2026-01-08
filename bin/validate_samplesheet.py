#!/usr/bin/env python3
"""
Validate sample sheet for RNA-seq pipeline.

Checks:
- Required columns present
- Files exist and are non-empty
- No duplicate sample IDs
- Valid strandedness values
"""

import argparse
import sys
import csv
import json
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description='Validate sample sheet')
    parser.add_argument('samplesheet', type=Path, help='Input sample sheet CSV')
    parser.add_argument('--output', '-o', type=Path, default='samplesheet_validation.json',
                        help='Output validation report JSON')
    parser.add_argument('--output-csv', type=Path, default='validated_samplesheet.csv',
                        help='Output validated sample sheet with absolute paths')
    return parser.parse_args()


def validate_samplesheet(samplesheet_path: Path) -> tuple:
    """Validate sample sheet and return validation report and samples."""

    report = {
        'file': str(samplesheet_path),
        'valid': True,
        'errors': [],
        'warnings': [],
        'stats': {
            'num_samples': 0,
            'paired_end': 0,
            'single_end': 0
        }
    }
    samples = []

    required_columns = ['sample', 'fastq_1']
    optional_columns = ['fastq_2', 'strandedness']
    valid_strandedness = ['forward', 'reverse', 'unstranded', 'auto']

    # Check file exists
    if not samplesheet_path.exists():
        report['valid'] = False
        report['errors'].append(f"File does not exist: {samplesheet_path}")
        return report, samples

    # Check file is not empty
    if samplesheet_path.stat().st_size == 0:
        report['valid'] = False
        report['errors'].append("File is empty")
        return report, samples

    try:
        with open(samplesheet_path, 'r') as f:
            reader = csv.DictReader(f)

            # Check required columns
            if reader.fieldnames is None:
                report['valid'] = False
                report['errors'].append("Could not parse CSV header")
                return report, samples

            missing_cols = set(required_columns) - set(reader.fieldnames)
            if missing_cols:
                report['valid'] = False
                report['errors'].append(f"Missing required columns: {missing_cols}")
                return report, samples

            sample_ids = set()
            row_num = 1

            for row in reader:
                row_num += 1
                sample_id = row.get('sample', '').strip()

                # Check sample ID
                if not sample_id:
                    report['valid'] = False
                    report['errors'].append(f"Row {row_num}: Empty sample ID")
                    continue

                if sample_id in sample_ids:
                    report['valid'] = False
                    report['errors'].append(f"Row {row_num}: Duplicate sample ID '{sample_id}'")
                    continue

                sample_ids.add(sample_id)

                # Check FASTQ files
                fastq_1 = row.get('fastq_1', '').strip()
                fastq_2 = row.get('fastq_2', '').strip()

                if not fastq_1:
                    report['valid'] = False
                    report['errors'].append(f"Row {row_num}: Empty fastq_1 path")
                    continue

                # Convert to absolute path if relative
                fastq_1_path = Path(fastq_1)
                if not fastq_1_path.is_absolute():
                    fastq_1_path = samplesheet_path.parent / fastq_1_path

                if not fastq_1_path.exists():
                    report['valid'] = False
                    report['errors'].append(
                        f"Row {row_num}: fastq_1 file not found: {fastq_1_path}"
                    )
                elif fastq_1_path.stat().st_size == 0:
                    report['valid'] = False
                    report['errors'].append(
                        f"Row {row_num}: fastq_1 file is empty: {fastq_1_path}"
                    )

                # Check fastq_2 if provided (paired-end)
                is_paired = bool(fastq_2)
                if is_paired:
                    fastq_2_path = Path(fastq_2)
                    if not fastq_2_path.is_absolute():
                        fastq_2_path = samplesheet_path.parent / fastq_2_path

                    if not fastq_2_path.exists():
                        report['valid'] = False
                        report['errors'].append(
                            f"Row {row_num}: fastq_2 file not found: {fastq_2_path}"
                        )
                    elif fastq_2_path.stat().st_size == 0:
                        report['valid'] = False
                        report['errors'].append(
                            f"Row {row_num}: fastq_2 file is empty: {fastq_2_path}"
                        )
                else:
                    fastq_2_path = None

                # Check strandedness
                strandedness = row.get('strandedness', 'auto').strip().lower()
                if strandedness not in valid_strandedness:
                    report['warnings'].append(
                        f"Row {row_num}: Invalid strandedness '{strandedness}', using 'auto'"
                    )
                    strandedness = 'auto'

                # Add to samples list
                sample = {
                    'sample': sample_id,
                    'fastq_1': str(fastq_1_path.resolve()) if fastq_1_path.exists() else fastq_1,
                    'fastq_2': str(fastq_2_path.resolve()) if fastq_2_path and fastq_2_path.exists() else '',
                    'strandedness': strandedness,
                    'single_end': not is_paired
                }
                samples.append(sample)

                if is_paired:
                    report['stats']['paired_end'] += 1
                else:
                    report['stats']['single_end'] += 1

            report['stats']['num_samples'] = len(samples)

    except Exception as e:
        report['valid'] = False
        report['errors'].append(f"Error reading file: {str(e)}")

    return report, samples


def main():
    args = parse_args()

    report, samples = validate_samplesheet(args.samplesheet)

    # Write validation report
    with open(args.output, 'w') as f:
        json.dump(report, f, indent=2)

    # Write validated samplesheet with absolute paths
    if samples and report['valid']:
        with open(args.output_csv, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=['sample', 'fastq_1', 'fastq_2', 'strandedness', 'single_end'])
            writer.writeheader()
            writer.writerows(samples)

    # Print summary
    if report['valid']:
        print(f"✓ Sample sheet validation passed: {args.samplesheet}")
        print(f"  Samples: {report['stats']['num_samples']}")
        print(f"  Paired-end: {report['stats']['paired_end']}")
        print(f"  Single-end: {report['stats']['single_end']}")
    else:
        print(f"✗ Sample sheet validation failed: {args.samplesheet}", file=sys.stderr)
        for error in report['errors']:
            print(f"  ERROR: {error}", file=sys.stderr)

    for warning in report['warnings']:
        print(f"  WARNING: {warning}", file=sys.stderr)

    sys.exit(0 if report['valid'] else 1)


if __name__ == '__main__':
    main()
