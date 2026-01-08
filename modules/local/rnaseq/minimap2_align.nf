/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MINIMAP2 ALIGN MODULE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Aligns reads to genome using minimap2
    Updated for Nextflow 25.10+ with eval output and topic channels
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process MINIMAP2_ALIGN {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::minimap2=2.26 bioconda::samtools=1.18"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-66534bcbb7031a148b13e2ad42583020b9cd25c4:3a70f8bc7e17d466f2e23488d9bd0f1a7b6e4c6a-0' :
        'quay.io/biocontainers/mulled-v2-66534bcbb7031a148b13e2ad42583020b9cd25c4:3a70f8bc7e17d466f2e23488d9bd0f1a7b6e4c6a-0' }"

    input:
    tuple val(meta), path(reads)
    path index

    output:
    tuple val(meta), path("*.sorted.bam"), emit: bam
    tuple val(meta), path("*.sorted.bam.bai"), emit: bai
    // Nextflow 24.02+ eval output for version capture via topic channel
    tuple val("${task.process}"), eval('minimap2 --version'), topic: versions
    tuple val("${task.process}"), eval('samtools --version | head -n1 | sed "s/samtools //g"'), topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: '-ax sr'  // Default to short-read mode
    def args2 = task.ext.args2 ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    // Handle single-end and paired-end
    def input_reads = meta.single_end ? reads[0] : "${reads[0]} ${reads[1]}"
    """
    minimap2 \\
        ${args} \\
        -t $task.cpus \\
        ${index} \\
        ${input_reads} \\
        | samtools view -@ ${task.cpus} -bS - \\
        | samtools sort -@ ${task.cpus} -o ${prefix}.sorted.bam -

    samtools index -@ ${task.cpus} ${prefix}.sorted.bam
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.sorted.bam
    touch ${prefix}.sorted.bam.bai
    """
}
