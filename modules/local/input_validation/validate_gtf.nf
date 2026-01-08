/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE GTF MODULE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Validates gene annotation GTF file for basic sanity checks
    Updated for Nextflow 25.10+ with eval output and topic channels
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process VALIDATE_GTF {
    tag "$gtf"
    label 'process_single'

    conda "conda-forge::python=3.10"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.10' :
        'quay.io/biocontainers/python:3.10' }"

    input:
    path gtf

    output:
    path "gtf_validation.json", emit: validation_report
    // Nextflow 24.02+ eval output for version capture via topic channel
    tuple val("${task.process}"), eval('python --version | sed "s/Python //g"'), topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    validate_gtf.py \\
        ${gtf} \\
        --output gtf_validation.json \\
        ${args}
    """

    stub:
    """
    echo '{"valid": true, "stats": {"num_genes": 4, "num_transcripts": 5, "num_exons": 10}}' > gtf_validation.json
    """
}
