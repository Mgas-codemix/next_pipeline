/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    GENERATE REPORT MODULE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Generates comprehensive HTML and Markdown report
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process GENERATE_REPORT {
    tag "report"
    label 'process_single'

    conda "conda-forge::python=3.10"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.10' :
        'quay.io/biocontainers/python:3.10' }"

    input:
    path fasta_validation
    path gtf_validation
    path samplesheet_validation
    path annotation_metrics
    path fastp_reports
    path alignment_stats
    path params_json

    output:
    path "report.html", emit: html
    path "report.md"  , emit: markdown
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def fasta_arg = fasta_validation ? "--fasta-validation ${fasta_validation}" : ''
    def gtf_arg = gtf_validation ? "--gtf-validation ${gtf_validation}" : ''
    def ss_arg = samplesheet_validation ? "--samplesheet-validation ${samplesheet_validation}" : ''
    def metrics_arg = annotation_metrics ? "--annotation-metrics ${annotation_metrics}" : ''
    def params_arg = params_json ? "--params-json ${params_json}" : ''

    // Handle multiple fastp reports
    def fastp_arg = ''
    if (fastp_reports) {
        def reports = fastp_reports instanceof List ? fastp_reports.join(' ') : fastp_reports
        fastp_arg = "--fastp-reports ${reports}"
    }

    // Handle multiple alignment stats
    def align_arg = ''
    if (alignment_stats) {
        def stats = alignment_stats instanceof List ? alignment_stats.join(' ') : alignment_stats
        align_arg = "--alignment-stats ${stats}"
    }

    """
    generate_report.py \\
        ${fasta_arg} \\
        ${gtf_arg} \\
        ${ss_arg} \\
        ${metrics_arg} \\
        ${fastp_arg} \\
        ${align_arg} \\
        ${params_arg} \\
        --pipeline-version ${workflow.manifest.version ?: '1.0.0'} \\
        --nextflow-version ${workflow.nextflow.version} \\
        --output-html report.html \\
        --output-md report.md \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        generate_report: 1.0.0
    END_VERSIONS
    """

    stub:
    """
    echo "<html><body><h1>Report</h1></body></html>" > report.html
    echo "# Report" > report.md

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: 3.10.0
        generate_report: 1.0.0
    END_VERSIONS
    """
}
