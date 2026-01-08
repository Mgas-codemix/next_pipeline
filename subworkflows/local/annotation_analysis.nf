/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ANNOTATION ANALYSIS SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Computes annotation summary metrics
    Updated for Nextflow 25.10+ - versions collected via topic channels
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { COMPUTE_ANNOTATION_METRICS } from '../../modules/local/annotation_metrics/compute_metrics'

workflow ANNOTATION_ANALYSIS {
    take:
    gtf     // path: gene annotation gtf
    fasta   // path: genome fasta (optional)

    main:
    //
    // MODULE: Compute annotation metrics
    //
    COMPUTE_ANNOTATION_METRICS(gtf, fasta)

    emit:
    metrics   = COMPUTE_ANNOTATION_METRICS.out.metrics  // path: annotation_metrics.json
    // Note: versions now collected automatically via topic channels
}
