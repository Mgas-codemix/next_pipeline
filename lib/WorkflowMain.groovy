/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    WORKFLOW HELPER FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Helper functions for the annotation pipeline
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

import groovy.json.JsonOutput

class WorkflowMain {

    //
    // Print help message
    //
    public static void helpMessage(workflow, params, log) {
        def help_string = """
        ╔═══════════════════════════════════════════════════════════════════════╗
        ║     BIOINFORMATICS ANNOTATION PIPELINE                                ║
        ╠═══════════════════════════════════════════════════════════════════════╣
        ║  Annotation validation, metrics computation, and RNA-seq evidence     ║
        ╚═══════════════════════════════════════════════════════════════════════╝

        Usage:
            nextflow run main.nf -profile <docker|singularity|conda> [options]

        Required:
            --input         Path to sample sheet CSV
            --fasta         Path to genome FASTA file
            --gtf           Path to gene annotation GTF file

        Optional:
            --outdir        Output directory (default: ./results)
            --run_rnaseq    Run RNA-seq processing (default: true)
            --top_contigs   Number of top contigs to report (default: 10)

        Profiles:
            docker          Run with Docker containers
            singularity     Run with Singularity containers
            conda           Run with Conda environments
            test            Run with minimal test dataset
            test_stub       Run in stub mode (validates structure)

        Examples:
            # Run with Docker
            nextflow run main.nf -profile docker \\
                --input samplesheet.csv \\
                --fasta genome.fa \\
                --gtf genes.gtf

            # Run test dataset
            nextflow run main.nf -profile test,docker

        Documentation: https://github.com/Mgas-codemix/next_pipeline
        """.stripIndent()

        log.info help_string
    }

    //
    // Validate parameters and print summary
    //
    public static void validateParams(workflow, params, log) {

        // Check required parameters
        def required = ['input', 'fasta', 'gtf']
        def missing = []

        required.each { param ->
            if (!params[param]) {
                missing << param
            }
        }

        if (missing) {
            log.error "Missing required parameters: ${missing.join(', ')}"
            log.error "Use --help for usage information"
            System.exit(1)
        }

        // Print parameter summary
        def summary = [
            'Pipeline': [
                'Name'      : workflow.manifest.name ?: 'bioinformatics-annotation-pipeline',
                'Version'   : workflow.manifest.version ?: '1.0.0',
                'Nextflow'  : workflow.nextflow.version,
                'Container' : workflow.containerEngine ?: 'None'
            ],
            'Input': [
                'Sample sheet' : params.input,
                'Genome FASTA' : params.fasta,
                'Annotation GTF': params.gtf
            ],
            'Options': [
                'Run RNA-seq'  : params.run_rnaseq,
                'Top contigs'  : params.top_contigs,
                'Output dir'   : params.outdir
            ]
        ]

        log.info summary_log(summary)
    }

    //
    // Format summary log
    //
    private static String summary_log(summary) {
        def output = []
        output << ""
        output << "Pipeline Parameters Summary"
        output << "═══════════════════════════════════════════════════"

        summary.each { section, values ->
            output << ""
            output << "[${section}]"
            values.each { key, value ->
                output << "  ${key.padRight(15)}: ${value}"
            }
        }

        output << ""
        output << "═══════════════════════════════════════════════════"
        output << ""

        return output.join('\n')
    }

    //
    // Get workflow summary for MultiQC
    //
    public static String getWorkflowSummary(workflow, params) {
        def summary = [:]

        summary['Pipeline Name']     = workflow.manifest.name ?: 'bioinformatics-annotation-pipeline'
        summary['Pipeline Version']  = workflow.manifest.version ?: '1.0.0'
        summary['Nextflow Version']  = workflow.nextflow.version
        summary['Container Engine']  = workflow.containerEngine ?: 'None'
        summary['Working Directory'] = workflow.workDir
        summary['Launch Directory']  = workflow.launchDir

        if (workflow.configFiles.size() > 0) {
            summary['Config Files'] = workflow.configFiles.join(', ')
        }

        summary['Sample Sheet']   = params.input
        summary['Genome FASTA']   = params.fasta
        summary['Annotation GTF'] = params.gtf
        summary['Output Dir']     = params.outdir
        summary['Run RNA-seq']    = params.run_rnaseq

        return JsonOutput.prettyPrint(JsonOutput.toJson(summary))
    }
}
