/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RNA-SEQ PROCESSING SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Processes RNA-seq reads: QC, alignment, and statistics
    Updated for Nextflow 25.10+ - versions collected via topic channels
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FASTP            } from '../../modules/local/rnaseq/fastp'
include { MINIMAP2_INDEX   } from '../../modules/local/rnaseq/minimap2_index'
include { MINIMAP2_ALIGN   } from '../../modules/local/rnaseq/minimap2_align'
include { SAMTOOLS_FLAGSTAT } from '../../modules/local/rnaseq/samtools_flagstat'

workflow RNASEQ_PROCESSING {
    take:
    samples   // channel: [ val(meta), [ reads ] ]
    fasta     // path: genome fasta

    main:
    //
    // MODULE: Run fastp for QC
    //
    FASTP(samples)

    //
    // MODULE: Create minimap2 index
    //
    MINIMAP2_INDEX(fasta)

    //
    // MODULE: Align reads with minimap2
    //
    ch_reads_for_alignment = FASTP.out.reads
    ch_index = MINIMAP2_INDEX.out.index

    MINIMAP2_ALIGN(ch_reads_for_alignment, ch_index.collect())

    //
    // MODULE: Get alignment statistics
    //
    ch_bam_bai = MINIMAP2_ALIGN.out.bam.join(MINIMAP2_ALIGN.out.bai)
    SAMTOOLS_FLAGSTAT(ch_bam_bai)

    emit:
    trimmed_reads   = FASTP.out.reads           // channel: [ val(meta), [ reads ] ]
    fastp_json      = FASTP.out.json            // channel: [ val(meta), json ]
    fastp_html      = FASTP.out.html            // channel: [ val(meta), html ]
    index           = MINIMAP2_INDEX.out.index  // path: index
    bam             = MINIMAP2_ALIGN.out.bam    // channel: [ val(meta), bam ]
    bai             = MINIMAP2_ALIGN.out.bai    // channel: [ val(meta), bai ]
    flagstat        = SAMTOOLS_FLAGSTAT.out.flagstat  // channel: [ val(meta), flagstat ]
    // Note: versions now collected automatically via topic channels
}
