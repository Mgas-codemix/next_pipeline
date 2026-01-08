/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    INPUT VALIDATION SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Validates all input files (FASTA, GTF, samplesheet)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { VALIDATE_FASTA       } from '../../modules/local/input_validation/validate_fasta'
include { VALIDATE_GTF         } from '../../modules/local/input_validation/validate_gtf'
include { VALIDATE_SAMPLESHEET } from '../../modules/local/input_validation/validate_samplesheet'

workflow INPUT_VALIDATION {
    take:
    fasta        // path: genome fasta
    gtf          // path: gene annotation gtf
    samplesheet  // path: samplesheet csv

    main:
    ch_versions = Channel.empty()

    // Validate FASTA
    VALIDATE_FASTA(fasta)
    ch_versions = ch_versions.mix(VALIDATE_FASTA.out.versions)

    // Validate GTF
    VALIDATE_GTF(gtf)
    ch_versions = ch_versions.mix(VALIDATE_GTF.out.versions)

    // Validate samplesheet
    VALIDATE_SAMPLESHEET(samplesheet)
    ch_versions = ch_versions.mix(VALIDATE_SAMPLESHEET.out.versions)

    // Parse validated samplesheet into channel of samples
    ch_samples = VALIDATE_SAMPLESHEET.out.validated_csv
        .splitCsv(header: true, sep: ',')
        .map { row ->
            def meta = [
                id: row.sample,
                single_end: row.single_end.toBoolean(),
                strandedness: row.strandedness
            ]

            // Create reads list
            def reads = []
            if (row.fastq_1) {
                reads.add(file(row.fastq_1, checkIfExists: true))
            }
            if (row.fastq_2 && !row.single_end.toBoolean()) {
                reads.add(file(row.fastq_2, checkIfExists: true))
            }

            return [meta, reads]
        }

    emit:
    samples                   = ch_samples                            // channel: [ val(meta), [ reads ] ]
    fasta_validation          = VALIDATE_FASTA.out.validation_report  // path: fasta_validation.json
    gtf_validation            = VALIDATE_GTF.out.validation_report    // path: gtf_validation.json
    samplesheet_validation    = VALIDATE_SAMPLESHEET.out.validation_report // path: samplesheet_validation.json
    validated_samplesheet     = VALIDATE_SAMPLESHEET.out.validated_csv     // path: validated_samplesheet.csv
    versions                  = ch_versions                           // channel: [ versions.yml ]
}
