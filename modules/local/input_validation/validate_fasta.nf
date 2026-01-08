/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE FASTA MODULE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Validates genome FASTA file for basic sanity checks
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
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    validate_fasta.py \\
        ${fasta} \\
        --output fasta_validation.json \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        validate_fasta: 1.0.0
    END_VERSIONS
    """

    stub:
    """
    echo '{"valid": true, "stats": {"num_sequences": 3, "total_length": 1000, "gc_content": 50.0}}' > fasta_validation.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: 3.10.0
        validate_fasta: 1.0.0
    END_VERSIONS
    """
}
