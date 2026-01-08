/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE FASTA MODULE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Validates genome FASTA file for basic sanity checks
    Updated for Nextflow 25.10+ with eval output and topic channels
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process VALIDATE_FASTA {
    tag "$fasta"
    label 'process_single'

    conda "conda-forge::python=3.10"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.10' :
        'quay.io/biocontainers/python:3.10' }"

    input:
    path fasta

    output:
    path "fasta_validation.json", emit: validation_report
    // Nextflow 24.02+ eval output for version capture via topic channel
    tuple val("${task.process}"), eval('python --version | sed "s/Python //g"'), topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    validate_fasta.py \\
        ${fasta} \\
        --output fasta_validation.json \\
        ${args}
    """

    stub:
    """
    echo '{"valid": true, "stats": {"num_sequences": 3, "total_length": 1000, "gc_content": 50.0}}' > fasta_validation.json
    """
}
