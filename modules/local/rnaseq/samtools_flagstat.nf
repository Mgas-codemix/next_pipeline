/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SAMTOOLS FLAGSTAT MODULE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Generates alignment statistics using samtools flagstat
    Updated for Nextflow 25.10+ with eval output and topic channels
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process SAMTOOLS_FLAGSTAT {
    tag "$meta.id"
    label 'process_single'

    conda "bioconda::samtools=1.18"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.18--h50ea8bc_1' :
        'quay.io/biocontainers/samtools:1.18--h50ea8bc_1' }"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("*.flagstat"), emit: flagstat
    // Nextflow 24.02+ eval output for version capture via topic channel
    tuple val("${task.process}"), eval('samtools --version | head -n1 | sed "s/samtools //g"'), topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samtools \\
        flagstat \\
        $args \\
        --threads $task.cpus \\
        $bam \\
        > ${prefix}.flagstat
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    cat <<-END_FLAGSTAT > ${prefix}.flagstat
    100 + 0 in total (QC-passed reads + QC-failed reads)
    0 + 0 secondary
    0 + 0 supplementary
    0 + 0 duplicates
    90 + 0 mapped (90.00% : N/A)
    100 + 0 paired in sequencing
    50 + 0 read1
    50 + 0 read2
    80 + 0 properly paired (80.00% : N/A)
    85 + 0 with itself and mate mapped
    5 + 0 singletons (5.00% : N/A)
    0 + 0 with mate mapped to a different chr
    0 + 0 with mate mapped to a different chr (mapQ>=5)
    END_FLAGSTAT
    """
}
