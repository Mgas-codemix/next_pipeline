/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MINIMAP2 INDEX MODULE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Creates minimap2 index for genome
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
    path "*.mmi"       , emit: index
    path "versions.yml", emit: versions

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

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minimap2: \$(minimap2 --version)
    END_VERSIONS
    """

    stub:
    def prefix = fasta.baseName
    """
    touch ${prefix}.mmi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minimap2: 2.26
    END_VERSIONS
    """
}
