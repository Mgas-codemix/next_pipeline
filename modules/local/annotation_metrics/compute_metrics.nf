/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPUTE ANNOTATION METRICS MODULE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Computes comprehensive annotation metrics from GTF and optionally FASTA
    Updated for Nextflow 25.10+ with eval output and topic channels
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process COMPUTE_ANNOTATION_METRICS {
    tag "$gtf"
    label 'process_single'

    conda "conda-forge::python=3.10"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.10' :
        'quay.io/biocontainers/python:3.10' }"

    input:
    path gtf
    path fasta

    output:
    path "annotation_metrics.json", emit: metrics
    // Nextflow 24.02+ eval output for version capture via topic channel
    tuple val("${task.process}"), eval('python --version | sed "s/Python //g"'), topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def fasta_arg = fasta ? "--fasta ${fasta}" : ''
    """
    annotation_metrics.py \\
        ${gtf} \\
        ${fasta_arg} \\
        --output annotation_metrics.json \\
        --top-contigs ${params.top_contigs ?: 10} \\
        ${args}
    """

    stub:
    """
    cat <<-END_JSON > annotation_metrics.json
    {
        "summary": {
            "num_genes": 4,
            "num_transcripts": 5,
            "num_exons": 10,
            "num_cds": 6,
            "num_contigs": 3
        },
        "transcript_lengths": {"count": 5, "min": 80, "max": 500, "mean": 250, "median": 220},
        "exon_lengths": {"count": 10, "min": 50, "max": 151, "mean": 100, "median": 100}
    }
    END_JSON
    """
}
