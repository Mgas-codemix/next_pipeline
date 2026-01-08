#!/usr/bin/env python3
"""
Generate final HTML/Markdown report for the annotation pipeline.

Combines all metrics and validation results into a comprehensive report.
"""

import argparse
import sys
import json
from pathlib import Path
from datetime import datetime
import html


def parse_args():
    parser = argparse.ArgumentParser(description='Generate pipeline report')
    parser.add_argument('--fasta-validation', type=Path, help='FASTA validation JSON')
    parser.add_argument('--gtf-validation', type=Path, help='GTF validation JSON')
    parser.add_argument('--samplesheet-validation', type=Path, help='Samplesheet validation JSON')
    parser.add_argument('--annotation-metrics', type=Path, help='Annotation metrics JSON')
    parser.add_argument('--alignment-stats', type=Path, nargs='*', help='Alignment statistics files')
    parser.add_argument('--fastp-reports', type=Path, nargs='*', help='Fastp JSON reports')
    parser.add_argument('--pipeline-version', type=str, default='1.0.0', help='Pipeline version')
    parser.add_argument('--nextflow-version', type=str, default='unknown', help='Nextflow version')
    parser.add_argument('--params-json', type=Path, help='Pipeline parameters JSON')
    parser.add_argument('--output-html', type=Path, default='report.html', help='Output HTML report')
    parser.add_argument('--output-md', type=Path, default='report.md', help='Output Markdown report')
    return parser.parse_args()


def load_json(path: Path) -> dict:
    """Safely load JSON file."""
    if path and path.exists():
        with open(path, 'r') as f:
            return json.load(f)
    return {}


def generate_markdown_report(data: dict) -> str:
    """Generate Markdown report content."""
    md = []
    md.append("# Annotation Pipeline Report")
    md.append(f"\n**Generated:** {data['timestamp']}")
    md.append(f"\n**Pipeline Version:** {data['pipeline_version']}")
    md.append(f"\n**Nextflow Version:** {data['nextflow_version']}")
    md.append("\n---\n")

    # Input Validation Summary
    md.append("## Input Validation Summary\n")

    if data.get('fasta_validation'):
        fv = data['fasta_validation']
        status = "✓ PASSED" if fv.get('valid', False) else "✗ FAILED"
        md.append(f"### FASTA Validation: {status}\n")
        if fv.get('stats'):
            md.append(f"- **Sequences:** {fv['stats'].get('num_sequences', 'N/A')}")
            md.append(f"- **Total Length:** {fv['stats'].get('total_length', 'N/A'):,} bp")
            md.append(f"- **GC Content:** {fv['stats'].get('gc_content', 'N/A')}%\n")

    if data.get('gtf_validation'):
        gv = data['gtf_validation']
        status = "✓ PASSED" if gv.get('valid', False) else "✗ FAILED"
        md.append(f"### GTF Validation: {status}\n")
        if gv.get('stats'):
            md.append(f"- **Genes:** {gv['stats'].get('num_genes', 'N/A')}")
            md.append(f"- **Transcripts:** {gv['stats'].get('num_transcripts', 'N/A')}")
            md.append(f"- **Exons:** {gv['stats'].get('num_exons', 'N/A')}\n")

    if data.get('samplesheet_validation'):
        sv = data['samplesheet_validation']
        status = "✓ PASSED" if sv.get('valid', False) else "✗ FAILED"
        md.append(f"### Sample Sheet Validation: {status}\n")
        if sv.get('stats'):
            md.append(f"- **Total Samples:** {sv['stats'].get('num_samples', 'N/A')}")
            md.append(f"- **Paired-end:** {sv['stats'].get('paired_end', 'N/A')}")
            md.append(f"- **Single-end:** {sv['stats'].get('single_end', 'N/A')}\n")

    # Annotation Metrics
    if data.get('annotation_metrics'):
        am = data['annotation_metrics']
        md.append("## Annotation Metrics\n")

        if am.get('summary'):
            md.append("### Summary Statistics\n")
            md.append(f"| Metric | Count |")
            md.append(f"|--------|-------|")
            md.append(f"| Genes | {am['summary'].get('num_genes', 'N/A'):,} |")
            md.append(f"| Transcripts | {am['summary'].get('num_transcripts', 'N/A'):,} |")
            md.append(f"| Exons | {am['summary'].get('num_exons', 'N/A'):,} |")
            md.append(f"| CDS | {am['summary'].get('num_cds', 'N/A'):,} |")
            md.append(f"| Contigs | {am['summary'].get('num_contigs', 'N/A'):,} |\n")

        if am.get('transcript_lengths'):
            tl = am['transcript_lengths']
            md.append("### Transcript Length Distribution\n")
            md.append(f"| Statistic | Value (bp) |")
            md.append(f"|-----------|------------|")
            md.append(f"| Count | {tl.get('count', 'N/A'):,} |")
            md.append(f"| Min | {tl.get('min', 'N/A'):,} |")
            md.append(f"| Max | {tl.get('max', 'N/A'):,} |")
            md.append(f"| Mean | {tl.get('mean', 'N/A')} |")
            md.append(f"| Median | {tl.get('median', 'N/A')} |")
            md.append(f"| Std Dev | {tl.get('std', 'N/A')} |\n")

        if am.get('exon_lengths'):
            el = am['exon_lengths']
            md.append("### Exon Length Distribution\n")
            md.append(f"| Statistic | Value (bp) |")
            md.append(f"|-----------|------------|")
            md.append(f"| Count | {el.get('count', 'N/A'):,} |")
            md.append(f"| Min | {el.get('min', 'N/A'):,} |")
            md.append(f"| Max | {el.get('max', 'N/A'):,} |")
            md.append(f"| Mean | {el.get('mean', 'N/A')} |")
            md.append(f"| Median | {el.get('median', 'N/A')} |\n")

        if am.get('genes_per_contig'):
            md.append("### Genes per Contig (Top)\n")
            md.append(f"| Contig | Gene Count |")
            md.append(f"|--------|------------|")
            for item in am['genes_per_contig'][:10]:
                md.append(f"| {item['contig']} | {item['num_genes']:,} |")
            md.append("")

        if am.get('biotypes'):
            md.append("### Gene Biotypes\n")
            md.append(f"| Biotype | Count |")
            md.append(f"|---------|-------|")
            for biotype, count in sorted(am['biotypes'].items(), key=lambda x: -x[1]):
                md.append(f"| {biotype} | {count:,} |")
            md.append("")

        if am.get('suspicious_models'):
            sm = am['suspicious_models']
            md.append("### Suspicious Models\n")
            md.append(f"| Issue | Count |")
            md.append(f"|-------|-------|")
            md.append(f"| Short exons (<3bp) | {len(sm.get('short_exons', []))} |")
            md.append(f"| Transcripts without exons | {len(sm.get('transcripts_without_exons', []))} |")
            md.append(f"| Single-exon transcripts | {len(sm.get('single_exon_transcripts', []))} |")
            md.append(f"| Very long introns (>500kb) | {len(sm.get('very_long_introns', []))} |\n")

    # RNA-seq QC Summary
    if data.get('fastp_reports'):
        md.append("## RNA-seq QC Summary\n")
        md.append(f"| Sample | Total Reads | Q30 Rate | Duplication |")
        md.append(f"|--------|-------------|----------|-------------|")
        for sample, report in data['fastp_reports'].items():
            if report.get('summary'):
                before = report['summary'].get('before_filtering', {})
                after = report['summary'].get('after_filtering', {})
                total = before.get('total_reads', 'N/A')
                q30 = after.get('q30_rate', 'N/A')
                dup = report.get('duplication', {}).get('rate', 'N/A')
                md.append(f"| {sample} | {total:,} | {q30:.2%} | {dup:.2%} |")
        md.append("")

    # Alignment Statistics
    if data.get('alignment_stats'):
        md.append("## Alignment Statistics\n")
        for sample, stats in data['alignment_stats'].items():
            md.append(f"### {sample}\n")
            md.append("```")
            md.append(stats)
            md.append("```\n")

    # Pipeline Parameters
    if data.get('params'):
        md.append("## Pipeline Parameters\n")
        md.append("```json")
        md.append(json.dumps(data['params'], indent=2))
        md.append("```\n")

    # Provenance
    md.append("## Provenance\n")
    md.append(f"- **Pipeline Version:** {data['pipeline_version']}")
    md.append(f"- **Nextflow Version:** {data['nextflow_version']}")
    md.append(f"- **Report Generated:** {data['timestamp']}")
    if data.get('container_tags'):
        md.append(f"- **Containers:** {', '.join(data['container_tags'])}")

    return "\n".join(md)


def generate_html_report(data: dict) -> str:
    """Generate HTML report content."""
    md_content = generate_markdown_report(data)

    # Basic HTML template with inline styling
    html_template = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Annotation Pipeline Report</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
            color: #333;
        }}
        .container {{
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        h1 {{ color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }}
        h2 {{ color: #2980b9; margin-top: 30px; border-bottom: 1px solid #ddd; padding-bottom: 5px; }}
        h3 {{ color: #34495e; }}
        table {{
            border-collapse: collapse;
            width: 100%;
            margin: 15px 0;
        }}
        th, td {{
            border: 1px solid #ddd;
            padding: 10px;
            text-align: left;
        }}
        th {{
            background-color: #3498db;
            color: white;
        }}
        tr:nth-child(even) {{ background-color: #f2f2f2; }}
        tr:hover {{ background-color: #e8f4fc; }}
        .passed {{ color: #27ae60; font-weight: bold; }}
        .failed {{ color: #e74c3c; font-weight: bold; }}
        pre {{
            background-color: #2c3e50;
            color: #ecf0f1;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
        }}
        code {{ font-family: 'Courier New', Courier, monospace; }}
        .meta {{
            color: #7f8c8d;
            font-size: 0.9em;
            margin-bottom: 20px;
        }}
        hr {{ border: none; border-top: 1px solid #ddd; margin: 20px 0; }}
    </style>
</head>
<body>
    <div class="container">
        {content}
    </div>
</body>
</html>"""

    # Convert Markdown to basic HTML
    content = md_content
    # Headers
    content = content.replace("# Annotation Pipeline Report", "<h1>Annotation Pipeline Report</h1>")
    import re
    content = re.sub(r'^### (.+)$', r'<h3>\1</h3>', content, flags=re.MULTILINE)
    content = re.sub(r'^## (.+)$', r'<h2>\1</h2>', content, flags=re.MULTILINE)

    # Bold
    content = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', content)

    # Status indicators
    content = content.replace("✓ PASSED", '<span class="passed">✓ PASSED</span>')
    content = content.replace("✗ FAILED", '<span class="failed">✗ FAILED</span>')

    # Tables
    lines = content.split('\n')
    in_table = False
    result_lines = []
    for line in lines:
        if line.startswith('|') and '|' in line[1:]:
            if not in_table:
                result_lines.append('<table>')
                in_table = True
            if '---' in line:
                continue
            cells = [c.strip() for c in line.split('|')[1:-1]]
            if result_lines[-1] == '<table>':
                row = '<tr>' + ''.join(f'<th>{html.escape(c)}</th>' for c in cells) + '</tr>'
            else:
                row = '<tr>' + ''.join(f'<td>{c}</td>' for c in cells) + '</tr>'
            result_lines.append(row)
        else:
            if in_table:
                result_lines.append('</table>')
                in_table = False
            result_lines.append(line)
    if in_table:
        result_lines.append('</table>')
    content = '\n'.join(result_lines)

    # Code blocks
    content = re.sub(r'```(\w*)\n(.*?)```', r'<pre><code>\2</code></pre>', content, flags=re.DOTALL)

    # Lists
    content = re.sub(r'^- (.+)$', r'<li>\1</li>', content, flags=re.MULTILINE)
    content = re.sub(r'(<li>.*</li>\n)+', r'<ul>\g<0></ul>', content)

    # Paragraphs
    content = re.sub(r'\n\n+', '</p><p>', content)
    content = f'<p>{content}</p>'
    content = content.replace('<p></p>', '')

    # Horizontal rules
    content = content.replace('---', '<hr>')

    return html_template.format(content=content)


def main():
    args = parse_args()

    # Collect all data
    data = {
        'timestamp': datetime.now().isoformat(),
        'pipeline_version': args.pipeline_version,
        'nextflow_version': args.nextflow_version,
        'container_tags': [],
        'fasta_validation': load_json(args.fasta_validation),
        'gtf_validation': load_json(args.gtf_validation),
        'samplesheet_validation': load_json(args.samplesheet_validation),
        'annotation_metrics': load_json(args.annotation_metrics),
        'params': load_json(args.params_json),
        'fastp_reports': {},
        'alignment_stats': {}
    }

    # Load fastp reports
    if args.fastp_reports:
        for report_path in args.fastp_reports:
            if report_path and report_path.exists():
                sample = report_path.stem.replace('.fastp', '').replace('_fastp', '')
                data['fastp_reports'][sample] = load_json(report_path)

    # Load alignment stats
    if args.alignment_stats:
        for stats_path in args.alignment_stats:
            if stats_path and stats_path.exists():
                sample = stats_path.stem.replace('.flagstat', '').replace('_flagstat', '')
                with open(stats_path, 'r') as f:
                    data['alignment_stats'][sample] = f.read()

    # Generate reports
    md_report = generate_markdown_report(data)
    html_report = generate_html_report(data)

    # Write outputs
    with open(args.output_md, 'w') as f:
        f.write(md_report)

    with open(args.output_html, 'w') as f:
        f.write(html_report)

    print(f"Reports generated:")
    print(f"  HTML: {args.output_html}")
    print(f"  Markdown: {args.output_md}")


if __name__ == '__main__':
    main()
