/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE SAMPLESHEET MODULE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Validates sample sheet CSV and emits sample channel
    Updated for Nextflow 25.10+ with eval output and topic channels
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process VALIDATE_SAMPLESHEET {
    tag "$samplesheet"
    label 'process_single'

    conda "conda-forge::python=3.10"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.10' :
        'quay.io/biocontainers/python:3.10' }"

    input:
    path samplesheet

    output:
    path "validated_samplesheet.csv", emit: validated_csv
    path "samplesheet_validation.json", emit: validation_report
    // Nextflow 24.02+ eval output for version capture via topic channel
    tuple val("${task.process}"), eval('python --version | sed "s/Python //g"'), topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    validate_samplesheet.py \\
        ${samplesheet} \\
        --output samplesheet_validation.json \\
        --output-csv validated_samplesheet.csv \\
        ${args}
    """

    stub:
    """
    echo 'sample,fastq_1,fastq_2,strandedness,single_end' > validated_samplesheet.csv
    echo 'sample1,reads_1.fq.gz,reads_2.fq.gz,reverse,False' >> validated_samplesheet.csv
    echo '{"valid": true, "stats": {"num_samples": 1}}' > samplesheet_validation.json
    """
}
