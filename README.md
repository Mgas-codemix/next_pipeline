# Bioinformatics Annotation Pipeline

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.0-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg)](https://sylabs.io/docs/)

A modular, reproducible Nextflow DSL2 workflow for annotation validation, metrics computation, and RNA-seq evidence processing.

## Pipeline Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    BIOINFORMATICS ANNOTATION PIPELINE                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    1. INPUT VALIDATION                            │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────┐     │   │
│  │  │ FASTA Check │  │  GTF Check  │  │  Samplesheet Check   │     │   │
│  │  └─────────────┘  └─────────────┘  └──────────────────────┘     │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                              │                                           │
│                              ▼                                           │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                 2. ANNOTATION METRICS                             │   │
│  │  • Gene/transcript/exon counts                                    │   │
│  │  • Length distributions                                           │   │
│  │  • Suspicious model detection                                     │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                              │                                           │
│                              ▼                                           │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                3. RNA-SEQ PROCESSING (optional)                   │   │
│  │  ┌────────┐    ┌──────────────┐    ┌──────────────────────┐     │   │
│  │  │ FASTP  │───►│   MINIMAP2   │───►│  SAMTOOLS FLAGSTAT   │     │   │
│  │  │  (QC)  │    │  (Alignment) │    │    (Statistics)      │     │   │
│  │  └────────┘    └──────────────┘    └──────────────────────┘     │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                              │                                           │
│                              ▼                                           │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    4. REPORT GENERATION                           │   │
│  │           HTML & Markdown with full provenance                    │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Features

- **Input Validation**: Comprehensive checks for FASTA, GTF, and sample sheets
- **Annotation Metrics**: Summary statistics, distribution analysis, suspicious model detection
- **RNA-seq Evidence**: Quality control, alignment, and statistics
- **Reproducibility**: Container support (Docker, Singularity, Apptainer)
- **Comprehensive Reporting**: HTML and Markdown reports with full provenance

## Quick Start

### Prerequisites

- [Nextflow](https://www.nextflow.io/) (>= 22.10.0)
- [Docker](https://www.docker.com/), [Singularity](https://sylabs.io/docs/), or [Conda](https://docs.conda.io/)

### Installation

```bash
git clone https://github.com/Mgas-codemix/next_pipeline.git
cd next_pipeline
```

### Running the Pipeline

```bash
# Using Docker
nextflow run main.nf -profile docker \
    --input samplesheet.csv \
    --fasta genome.fa \
    --gtf genes.gtf \
    --outdir results

# Using Singularity
nextflow run main.nf -profile singularity \
    --input samplesheet.csv \
    --fasta genome.fa \
    --gtf genes.gtf \
    --outdir results

# Using Conda
nextflow run main.nf -profile conda \
    --input samplesheet.csv \
    --fasta genome.fa \
    --gtf genes.gtf \
    --outdir results
```

### Run Test Dataset

```bash
# Full test with actual tool execution
nextflow run main.nf -profile test,docker

# Quick stub test (validates pipeline structure)
nextflow run main.nf -profile test_stub -stub-run
```

## Input Files

### Sample Sheet (CSV)

The sample sheet must contain the following columns:

| Column | Description |
|--------|-------------|
| `sample` | Unique sample identifier |
| `fastq_1` | Path to R1 FASTQ file |
| `fastq_2` | Path to R2 FASTQ file (leave empty for single-end) |
| `strandedness` | Library strandedness: `forward`, `reverse`, `unstranded`, or `auto` |

Example:
```csv
sample,fastq_1,fastq_2,strandedness
sample1,reads/sample1_1.fq.gz,reads/sample1_2.fq.gz,reverse
sample2,reads/sample2_1.fq.gz,reads/sample2_2.fq.gz,reverse
```

### Genome FASTA

- Standard FASTA format
- Headers must start with `>`
- Sequence should contain only valid nucleotides (A, T, C, G, N)

### Gene Annotation GTF

- Standard GTF format (9 tab-separated columns)
- Required attributes: `gene_id`, `transcript_id` (for transcript-level features)
- Supported feature types: `gene`, `transcript`, `exon`, `CDS`, `UTR`, etc.

## Output Directory Structure

```
results/
├── validation/
│   ├── fasta_validation.json       # FASTA validation report
│   ├── gtf_validation.json         # GTF validation report
│   ├── samplesheet_validation.json # Sample sheet validation report
│   └── validated_samplesheet.csv   # Processed sample sheet
├── annotation_metrics/
│   └── annotation_metrics.json     # Comprehensive annotation metrics
├── rnaseq/
│   ├── fastp/
│   │   ├── *.fastp.json           # Per-sample QC metrics
│   │   ├── *.fastp.html           # Per-sample QC reports
│   │   └── trimmed/               # Trimmed reads
│   ├── index/
│   │   └── genome.mmi             # Minimap2 index
│   ├── alignments/
│   │   ├── *.sorted.bam           # Sorted alignments
│   │   └── *.sorted.bam.bai       # BAM indices
│   └── stats/
│       └── *.flagstat             # Alignment statistics
├── report/
│   ├── report.html                # Interactive HTML report
│   └── report.md                  # Markdown report
└── pipeline_info/
    ├── execution_timeline_*.html  # Timeline visualization
    ├── execution_report_*.html    # Resource usage report
    ├── execution_trace_*.txt      # Detailed trace log
    ├── pipeline_dag_*.svg         # Pipeline DAG visualization
    └── versions.yml               # Software versions
```

## Parameters

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `--input` | Path to sample sheet CSV |
| `--fasta` | Path to genome FASTA file |
| `--gtf` | Path to gene annotation GTF file |

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--outdir` | `./results` | Output directory |
| `--run_rnaseq` | `true` | Run RNA-seq processing |
| `--top_contigs` | `10` | Number of top contigs to report |

### Resource Limits

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--max_cpus` | `16` | Maximum CPUs per process |
| `--max_memory` | `128.GB` | Maximum memory per process |
| `--max_time` | `240.h` | Maximum time per process |

## Annotation Metrics Computed

### Summary Statistics
- Number of genes, transcripts, exons, CDS
- Number of annotated contigs

### Distribution Analysis
- Transcript length distribution (min, max, mean, median, std, quartiles)
- Exon length distribution

### Quality Metrics
- Genes per contig (top N)
- Gene biotype distribution
- Suspicious models detection:
  - Short exons (< 3bp)
  - Transcripts without exons
  - Single-exon transcripts
  - Very long introns (> 500kb)

## Profiles

| Profile | Description |
|---------|-------------|
| `docker` | Run with Docker containers |
| `singularity` | Run with Singularity containers |
| `apptainer` | Run with Apptainer containers |
| `conda` | Run with Conda environments |
| `mamba` | Run with Mamba environments |
| `test` | Run with minimal test dataset |
| `test_stub` | Run in stub mode (structure validation) |

## Error Handling

The pipeline includes comprehensive error handling:

- **Input validation failures**: Clear error messages with line numbers
- **Missing files**: Early detection with informative messages
- **Resource exhaustion**: Automatic retry with increased resources
- **Process failures**: Detailed error reports in pipeline logs

## Edge Cases Handled

- Empty input files
- Duplicate sequence/sample IDs
- Missing required attributes (gene_id, transcript_id)
- Invalid coordinates in GTF
- Contigs in GTF not present in FASTA
- Single-end and paired-end samples in same run

## Development

### Project Structure

```
.
├── main.nf                    # Main workflow
├── nextflow.config            # Pipeline configuration
├── nextflow_schema.json       # Parameter schema
├── modules/
│   └── local/
│       ├── input_validation/  # Validation modules
│       ├── annotation_metrics/# Metrics modules
│       ├── rnaseq/           # RNA-seq modules
│       └── report/           # Report modules
├── subworkflows/
│   └── local/
│       ├── input_validation.nf
│       ├── annotation_analysis.nf
│       └── rnaseq_processing.nf
├── bin/                       # Custom scripts
├── conf/                      # Configuration files
├── tests/
│   └── data/                  # Test datasets
└── README.md
```

### Running Tests

```bash
# End-to-end test
./tests/run_tests.sh

# Stub test (no tool execution)
nextflow run main.nf -profile test_stub -stub-run
```

## Assumptions

1. **FASTA format**: Standard nucleotide FASTA with unique sequence IDs
2. **GTF format**: Standard GTF with standard attributes
3. **FASTQ format**: Illumina-style paired-end or single-end reads (gzipped)
4. **Strandedness**: Known library prep strandedness for accurate processing

## Author

- marica
