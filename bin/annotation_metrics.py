#!/usr/bin/env python3
"""
Compute annotation summary metrics from GTF and FASTA files.

Computes:
- Number of genes/transcripts/exons
- Transcript length distribution
- Exon length distribution
- Genes per contig (top N)
- Identifies suspicious models
"""

import argparse
import sys
import re
import json
from pathlib import Path
from collections import defaultdict
import statistics


def parse_args():
    parser = argparse.ArgumentParser(description='Compute annotation metrics')
    parser.add_argument('gtf', type=Path, help='Input GTF file')
    parser.add_argument('--fasta', type=Path, help='Input FASTA file (optional)')
    parser.add_argument('--output', '-o', type=Path, default='annotation_metrics.json',
                        help='Output metrics JSON')
    parser.add_argument('--top-contigs', type=int, default=10,
                        help='Number of top contigs to report')
    return parser.parse_args()


def parse_attributes(attr_string: str) -> dict:
    """Parse GTF attribute string into dictionary."""
    attributes = {}
    pattern = r'(\S+)\s+"([^"]*)"'
    for match in re.finditer(pattern, attr_string):
        key, value = match.groups()
        attributes[key] = value
    return attributes


def parse_fasta_lengths(fasta_path: Path) -> dict:
    """Parse FASTA file and return sequence lengths."""
    lengths = {}
    current_id = None
    current_length = 0

    with open(fasta_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('>'):
                if current_id:
                    lengths[current_id] = current_length
                current_id = line[1:].split()[0]
                current_length = 0
            else:
                current_length += len(line)

        if current_id:
            lengths[current_id] = current_length

    return lengths


def compute_distribution_stats(values: list) -> dict:
    """Compute distribution statistics for a list of values."""
    if not values:
        return {
            'count': 0,
            'min': None,
            'max': None,
            'mean': None,
            'median': None,
            'std': None,
            'q25': None,
            'q75': None
        }

    sorted_vals = sorted(values)
    n = len(sorted_vals)

    return {
        'count': n,
        'min': min(values),
        'max': max(values),
        'mean': round(statistics.mean(values), 2),
        'median': round(statistics.median(values), 2),
        'std': round(statistics.stdev(values), 2) if n > 1 else 0,
        'q25': sorted_vals[n // 4] if n >= 4 else sorted_vals[0],
        'q75': sorted_vals[3 * n // 4] if n >= 4 else sorted_vals[-1]
    }


def compute_metrics(gtf_path: Path, fasta_path: Path = None, top_n: int = 10) -> dict:
    """Compute annotation metrics from GTF file."""

    metrics = {
        'summary': {
            'num_genes': 0,
            'num_transcripts': 0,
            'num_exons': 0,
            'num_cds': 0,
            'num_contigs': 0
        },
        'transcript_lengths': {},
        'exon_lengths': {},
        'genes_per_contig': [],
        'biotypes': defaultdict(int),
        'suspicious_models': {
            'short_exons': [],  # exons < 3bp
            'transcripts_without_exons': [],
            'single_exon_transcripts': [],
            'very_long_introns': []  # > 500kb
        },
        'coverage': {}
    }

    # Data structures for computation
    genes = set()
    transcripts = defaultdict(lambda: {'exons': [], 'gene_id': None, 'contig': None, 'biotype': None})
    genes_by_contig = defaultdict(set)
    exon_lengths = []

    # Parse GTF
    with open(gtf_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue

            cols = line.split('\t')
            if len(cols) != 9:
                continue

            seqname, source, feature, start, end, score, strand, frame, attributes = cols
            attrs = parse_attributes(attributes)

            try:
                start_int = int(start)
                end_int = int(end)
                length = end_int - start_int + 1
            except ValueError:
                continue

            gene_id = attrs.get('gene_id', '')

            if feature == 'gene':
                genes.add(gene_id)
                genes_by_contig[seqname].add(gene_id)
                biotype = attrs.get('gene_biotype', attrs.get('biotype', 'unknown'))
                metrics['biotypes'][biotype] += 1

            elif feature == 'transcript':
                transcript_id = attrs.get('transcript_id', '')
                transcripts[transcript_id]['gene_id'] = gene_id
                transcripts[transcript_id]['contig'] = seqname
                transcripts[transcript_id]['biotype'] = attrs.get('transcript_biotype', 'unknown')
                if gene_id:
                    genes.add(gene_id)
                    genes_by_contig[seqname].add(gene_id)

            elif feature == 'exon':
                transcript_id = attrs.get('transcript_id', '')
                transcripts[transcript_id]['exons'].append({
                    'start': start_int,
                    'end': end_int,
                    'length': length
                })
                exon_lengths.append(length)

                # Check for suspicious short exons
                if length < 3:
                    metrics['suspicious_models']['short_exons'].append({
                        'transcript_id': transcript_id,
                        'exon_length': length,
                        'location': f"{seqname}:{start}-{end}"
                    })

            elif feature == 'CDS':
                metrics['summary']['num_cds'] += 1

    # Compute transcript lengths (sum of exon lengths)
    transcript_lengths = []
    for tid, tdata in transcripts.items():
        if tdata['exons']:
            total_length = sum(e['length'] for e in tdata['exons'])
            transcript_lengths.append(total_length)

            # Check for single-exon transcripts
            if len(tdata['exons']) == 1:
                metrics['suspicious_models']['single_exon_transcripts'].append(tid)

            # Check for very long introns
            if len(tdata['exons']) > 1:
                sorted_exons = sorted(tdata['exons'], key=lambda x: x['start'])
                for i in range(len(sorted_exons) - 1):
                    intron_length = sorted_exons[i + 1]['start'] - sorted_exons[i]['end'] - 1
                    if intron_length > 500000:  # 500kb
                        metrics['suspicious_models']['very_long_introns'].append({
                            'transcript_id': tid,
                            'intron_length': intron_length
                        })
        else:
            metrics['suspicious_models']['transcripts_without_exons'].append(tid)

    # Update summary
    metrics['summary']['num_genes'] = len(genes)
    metrics['summary']['num_transcripts'] = len(transcripts)
    metrics['summary']['num_exons'] = len(exon_lengths)
    metrics['summary']['num_contigs'] = len(genes_by_contig)

    # Compute distributions
    metrics['transcript_lengths'] = compute_distribution_stats(transcript_lengths)
    metrics['exon_lengths'] = compute_distribution_stats(exon_lengths)

    # Top N contigs by gene count
    sorted_contigs = sorted(
        genes_by_contig.items(),
        key=lambda x: len(x[1]),
        reverse=True
    )[:top_n]
    metrics['genes_per_contig'] = [
        {'contig': contig, 'num_genes': len(gene_set)}
        for contig, gene_set in sorted_contigs
    ]

    # Convert defaultdict to regular dict
    metrics['biotypes'] = dict(metrics['biotypes'])

    # Limit suspicious model lists
    for key in metrics['suspicious_models']:
        if len(metrics['suspicious_models'][key]) > 100:
            metrics['suspicious_models'][key] = metrics['suspicious_models'][key][:100]
            metrics['suspicious_models'][f'{key}_truncated'] = True

    # Add FASTA coverage if provided
    if fasta_path and fasta_path.exists():
        fasta_lengths = parse_fasta_lengths(fasta_path)
        metrics['coverage']['fasta_contigs'] = len(fasta_lengths)
        metrics['coverage']['fasta_total_length'] = sum(fasta_lengths.values())

        # Check which contigs have annotations
        annotated_contigs = set(genes_by_contig.keys())
        fasta_contigs = set(fasta_lengths.keys())

        metrics['coverage']['annotated_contigs'] = len(annotated_contigs)
        metrics['coverage']['unannotated_contigs'] = len(fasta_contigs - annotated_contigs)
        metrics['coverage']['annotation_not_in_fasta'] = list(annotated_contigs - fasta_contigs)[:10]

    return metrics


def main():
    args = parse_args()

    metrics = compute_metrics(args.gtf, args.fasta, args.top_contigs)

    # Write metrics to JSON
    with open(args.output, 'w') as f:
        json.dump(metrics, f, indent=2)

    # Print summary
    print(f"Annotation Metrics Summary for {args.gtf}")
    print(f"=" * 50)
    print(f"Genes:       {metrics['summary']['num_genes']:,}")
    print(f"Transcripts: {metrics['summary']['num_transcripts']:,}")
    print(f"Exons:       {metrics['summary']['num_exons']:,}")
    print(f"CDS:         {metrics['summary']['num_cds']:,}")
    print(f"Contigs:     {metrics['summary']['num_contigs']:,}")
    print()
    print("Transcript length distribution:")
    print(f"  Min: {metrics['transcript_lengths']['min']}, Max: {metrics['transcript_lengths']['max']}")
    print(f"  Mean: {metrics['transcript_lengths']['mean']}, Median: {metrics['transcript_lengths']['median']}")
    print()
    print("Exon length distribution:")
    print(f"  Min: {metrics['exon_lengths']['min']}, Max: {metrics['exon_lengths']['max']}")
    print(f"  Mean: {metrics['exon_lengths']['mean']}, Median: {metrics['exon_lengths']['median']}")
    print()
    print(f"Top {len(metrics['genes_per_contig'])} contigs by gene count:")
    for item in metrics['genes_per_contig']:
        print(f"  {item['contig']}: {item['num_genes']} genes")
    print()

    # Suspicious models summary
    suspicious = metrics['suspicious_models']
    print("Suspicious models detected:")
    print(f"  Short exons (<3bp): {len(suspicious['short_exons'])}")
    print(f"  Transcripts without exons: {len(suspicious['transcripts_without_exons'])}")
    print(f"  Single-exon transcripts: {len(suspicious['single_exon_transcripts'])}")
    print(f"  Very long introns (>500kb): {len(suspicious['very_long_introns'])}")

    print(f"\nMetrics written to: {args.output}")


if __name__ == '__main__':
    main()
