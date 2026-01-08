/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ANNOTATION ANALYSIS SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Computes annotation summary metrics
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { COMPUTE_ANNOTATION_METRICS } from '../../modules/local/annotation_metrics/compute_metrics'

workflow ANNOTATION_ANALYSIS {
    take:
    gtf     // path: gene annotation gtf
    fasta   // path: genome fasta (optional)

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: Compute annotation metrics
    //
    COMPUTE_ANNOTATION_METRICS(gtf, fasta)
    ch_versions = ch_versions.mix(COMPUTE_ANNOTATION_METRICS.out.versions)

    emit:
    metrics   = COMPUTE_ANNOTATION_METRICS.out.metrics  // path: annotation_metrics.json
    versions  = ch_versions                             // channel: [ versions.yml ]
}
