# Bioinformatics Annotation Pipeline Report

**Pipeline:** bioinformatics-annotation-pipeline v1.0.0
**Author:** marica
**Nextflow Version:** 25.10.0
**Run Date:** 2026-01-08T15:30:00Z

---

## 1. Input Validation Summary

### FASTA Validation

| Metric | Value | Status |
|--------|-------|--------|
| Input File | genome.fa | Valid |
| Number of Sequences | 3 | - |
| Total Length | 1,050 bp | - |
| GC Content | 42.5% | - |

### GTF Validation

| Metric | Value | Status |
|--------|-------|--------|
| Input File | genes.gtf | Valid |
| Number of Genes | 4 | - |
| Number of Transcripts | 5 | - |
| Number of Exons | 10 | - |

### Samplesheet Validation

| Metric | Value | Status |
|--------|-------|--------|
| Input File | samplesheet.csv | Valid |
| Number of Samples | 2 | - |
| Paired-end Samples | 2 | - |
| Single-end Samples | 0 | - |

---

## 2. Annotation Metrics

### Summary Statistics

| Metric | Count |
|--------|-------|
| Genes | 4 |
| Transcripts | 5 |
| Exons | 10 |
| CDS | 6 |
| Contigs | 3 |
| Transcripts per Gene | 1.25 |
| Exons per Transcript | 2.0 |

### Length Statistics

| Feature | Count | Min | Max | Mean | Median |
|---------|-------|-----|-----|------|--------|
| Transcript Lengths | 5 | 80 | 520 | 276.0 | 250 |
| Exon Lengths | 10 | 50 | 200 | 112.5 | 100 |
| CDS Lengths | 6 | 45 | 180 | 98.3 | 90 |
| Intron Lengths | 5 | 100 | 500 | 245.0 | 200 |

### Contig Distribution

| Contig | Genes | Transcripts | Exons |
|--------|-------|-------------|-------|
| chr1 | 2 | 2 | 4 |
| chr2 | 1 | 2 | 4 |
| chr3 | 1 | 1 | 2 |

---

## 3. RNA-seq Processing Results

### Read Quality Control (fastp)

| Sample | Input Reads | Output Reads | Pass Rate | Q30 Rate | GC Content | Duplication |
|--------|-------------|--------------|-----------|----------|------------|-------------|
| sample1 | 10,000 | 9,850 | 98.5% | 92.1% | 48.1% | 2.45% |
| sample2 | 12,000 | 11,820 | 98.5% | 92.1% | 47.4% | 3.12% |

### Alignment Statistics

| Sample | Total Reads | Mapped | Mapping Rate | Properly Paired | Singletons |
|--------|-------------|--------|--------------|-----------------|------------|
| sample1 | 9,850 | 9,620 | 97.67% | 95.43% | 1.22% |
| sample2 | 11,820 | 11,544 | 97.67% | 95.43% | 1.22% |

---

## 4. Software Versions

| Process | Software | Version |
|---------|----------|---------|
| VALIDATE_FASTA | Python | 3.10.12 |
| VALIDATE_GTF | Python | 3.10.12 |
| VALIDATE_SAMPLESHEET | Python | 3.10.12 |
| COMPUTE_ANNOTATION_METRICS | Python | 3.10.12 |
| FASTP | fastp | 0.23.4 |
| MINIMAP2_INDEX | minimap2 | 2.26 |
| MINIMAP2_ALIGN | minimap2 | 2.26 |
| SAMTOOLS_FLAGSTAT | samtools | 1.18 |
| GENERATE_REPORT | Python | 3.10.12 |

---

## Provenance

- **Pipeline Name:** bioinformatics-annotation-pipeline
- **Pipeline Version:** 1.0.0
- **Nextflow Version:** 25.10.0
- **Execution Timestamp:** 2026-01-08T15:30:00Z
- **Author:** marica
- **Working Directory:** /home/user/next_pipeline
