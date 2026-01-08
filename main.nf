#!/usr/bin/env nextflow

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    BIOINFORMATICS ANNOTATION PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    A modular, reproducible Nextflow DSL2 workflow for:
    - Input validation (FASTA, GTF, RNA-seq reads)
    - Annotation metrics computation
    - RNA-seq evidence processing
    - Comprehensive reporting

    Author: marica
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { INPUT_VALIDATION   } from './subworkflows/local/input_validation'
include { ANNOTATION_ANALYSIS } from './subworkflows/local/annotation_analysis'
include { RNASEQ_PROCESSING  } from './subworkflows/local/rnaseq_processing'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GENERATE_REPORT } from './modules/local/report/generate_report'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOW FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow GENEBUILD_ANNOTATION {

    main:

    ch_versions = Channel.empty()

    //
    // STEP 1: Validate inputs
    //
    log.info """
    ╔═══════════════════════════════════════════════════════════════════════╗
    ║     BIOINFORMATICS ANNOTATION PIPELINE v${workflow.manifest.version ?: '1.0.0'}                      ║
    ╠═══════════════════════════════════════════════════════════════════════╣
    ║  Genome FASTA  : ${params.fasta}
    ║  Annotation GTF: ${params.gtf}
    ║  Sample Sheet  : ${params.input}
    ║  Output Dir    : ${params.outdir}
    ╚═══════════════════════════════════════════════════════════════════════╝
    """.stripIndent()

    // Create input channels
    ch_fasta       = Channel.fromPath(params.fasta, checkIfExists: true)
    ch_gtf         = Channel.fromPath(params.gtf, checkIfExists: true)
    ch_samplesheet = Channel.fromPath(params.input, checkIfExists: true)

    //
    // SUBWORKFLOW: Input validation
    //
    INPUT_VALIDATION(
        ch_fasta,
        ch_gtf,
        ch_samplesheet
    )
    ch_versions = ch_versions.mix(INPUT_VALIDATION.out.versions)

    //
    // STEP 2: Compute annotation metrics
    //
    // SUBWORKFLOW: Annotation analysis
    //
    ANNOTATION_ANALYSIS(
        ch_gtf,
        ch_fasta
    )
    ch_versions = ch_versions.mix(ANNOTATION_ANALYSIS.out.versions)

    //
    // STEP 3: RNA-seq evidence processing (optional)
    //
    if (params.run_rnaseq) {
        RNASEQ_PROCESSING(
            INPUT_VALIDATION.out.samples,
            ch_fasta.collect()
        )
        ch_versions = ch_versions.mix(RNASEQ_PROCESSING.out.versions)

        // Collect fastp JSONs for report
        ch_fastp_jsons = RNASEQ_PROCESSING.out.fastp_json
            .map { meta, json -> json }
            .collect()

        // Collect flagstat files for report
        ch_flagstat_files = RNASEQ_PROCESSING.out.flagstat
            .map { meta, flagstat -> flagstat }
            .collect()
    } else {
        ch_fastp_jsons = Channel.empty().collect()
        ch_flagstat_files = Channel.empty().collect()
    }

    //
    // STEP 4: Generate final report
    //
    // Create params JSON for report provenance
    ch_params_json = Channel.of(params)
        .map { p ->
            def params_file = file("${workDir}/params.json")
            params_file.text = groovy.json.JsonOutput.prettyPrint(
                groovy.json.JsonOutput.toJson(p)
            )
            return params_file
        }

    GENERATE_REPORT(
        INPUT_VALIDATION.out.fasta_validation,
        INPUT_VALIDATION.out.gtf_validation,
        INPUT_VALIDATION.out.samplesheet_validation,
        ANNOTATION_ANALYSIS.out.metrics,
        ch_fastp_jsons.ifEmpty([]),
        ch_flagstat_files.ifEmpty([]),
        ch_params_json
    )
    ch_versions = ch_versions.mix(GENERATE_REPORT.out.versions)

    //
    // Collect versions
    //
    ch_versions
        .unique()
        .collectFile(name: 'versions.yml', storeDir: "${params.outdir}/pipeline_info")

    emit:
    report_html = GENERATE_REPORT.out.html
    report_md   = GENERATE_REPORT.out.markdown
    versions    = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
    GENEBUILD_ANNOTATION()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION HANDLER
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (workflow.success) {
        log.info """
        ╔═══════════════════════════════════════════════════════════════════════╗
        ║                     PIPELINE COMPLETED SUCCESSFULLY                   ║
        ╠═══════════════════════════════════════════════════════════════════════╣
        ║  Duration    : ${workflow.duration}
        ║  CPU hours   : ${workflow.stats.computeTimeFmt ?: '-'}
        ║  Output dir  : ${params.outdir}
        ╚═══════════════════════════════════════════════════════════════════════╝
        """.stripIndent()
    } else {
        log.error """
        ╔═══════════════════════════════════════════════════════════════════════╗
        ║                        PIPELINE FAILED                                ║
        ╠═══════════════════════════════════════════════════════════════════════╣
        ║  Exit status : ${workflow.exitStatus}
        ║  Error message: ${workflow.errorMessage ?: 'Unknown error'}
        ╚═══════════════════════════════════════════════════════════════════════╝
        """.stripIndent()
    }
}

workflow.onError {
    log.error "Pipeline execution stopped with the following error: ${workflow.errorMessage}"
}
