/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MINIMAP2 INDEX MODULE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Creates minimap2 index for genome
    Updated for Nextflow 25.10+ with eval output and topic channels
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process MINIMAP2_INDEX {
    tag "$fasta"
    label 'process_medium'

    conda "bioconda::minimap2=2.26"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/minimap2:2.26--he4a0461_2' :
        'quay.io/biocontainers/minimap2:2.26--he4a0461_2' }"

    input:
    path fasta

    output:
    path "*.mmi", emit: index
    // Nextflow 24.02+ eval output for version capture
    tuple val("${task.process}"), eval('minimap2 --version'), topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: '-x sr'  // Default to short-read mode
    def prefix = fasta.baseName
    """
    minimap2 \\
        -t $task.cpus \\
        -d ${prefix}.mmi \\
        ${args} \\
        ${fasta}
    """

    stub:
    def prefix = fasta.baseName
    """
    touch ${prefix}.mmi
    """
}
