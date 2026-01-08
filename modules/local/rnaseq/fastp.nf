/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FASTP MODULE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Quality control and preprocessing of FASTQ reads
    Updated for Nextflow 25.10+ with eval output and topic channels
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process FASTP {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::fastp=0.23.4"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastp:0.23.4--h5f740d0_0' :
        'quay.io/biocontainers/fastp:0.23.4--h5f740d0_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.fastp.fastq.gz"), emit: reads
    tuple val(meta), path("*.json")          , emit: json
    tuple val(meta), path("*.html")          , emit: html
    tuple val(meta), path("*.log")           , emit: log
    tuple val(meta), path("*.fail.fastq.gz") , optional: true, emit: reads_fail
    // Nextflow 24.02+ eval output for version capture
    tuple val("${task.process}"), eval('fastp --version 2>&1 | sed "s/fastp //g"'), topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    // Handle single-end and paired-end
    if (meta.single_end) {
        """
        fastp \\
            --in1 ${reads[0]} \\
            --out1 ${prefix}.fastp.fastq.gz \\
            --json ${prefix}.fastp.json \\
            --html ${prefix}.fastp.html \\
            --thread $task.cpus \\
            ${args} \\
            2> ${prefix}.fastp.log
        """
    } else {
        """
        fastp \\
            --in1 ${reads[0]} \\
            --in2 ${reads[1]} \\
            --out1 ${prefix}_1.fastp.fastq.gz \\
            --out2 ${prefix}_2.fastp.fastq.gz \\
            --json ${prefix}.fastp.json \\
            --html ${prefix}.fastp.html \\
            --thread $task.cpus \\
            ${args} \\
            2> ${prefix}.fastp.log
        """
    }

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (meta.single_end) {
        """
        echo "" | gzip > ${prefix}.fastp.fastq.gz
        touch ${prefix}.fastp.json
        touch ${prefix}.fastp.html
        touch ${prefix}.fastp.log
        """
    } else {
        """
        echo "" | gzip > ${prefix}_1.fastp.fastq.gz
        echo "" | gzip > ${prefix}_2.fastp.fastq.gz
        touch ${prefix}.fastp.json
        touch ${prefix}.fastp.html
        touch ${prefix}.fastp.log
        """
    }
}
