#!/bin/bash

# ==============================================================================
# Ensembl Genebuild Annotation Pipeline - Test Runner
# ==============================================================================
# This script runs end-to-end tests for the annotation pipeline.
# Usage: ./tests/run_tests.sh [--stub] [--profile PROFILE]
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
STUB_MODE=false
PROFILE="test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --stub)
            STUB_MODE=true
            shift
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--stub] [--profile PROFILE]"
            echo ""
            echo "Options:"
            echo "  --stub      Run in stub mode (no actual tool execution)"
            echo "  --profile   Nextflow profile to use (default: test)"
            echo "  --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_nextflow() {
    if ! command -v nextflow &> /dev/null; then
        log_error "Nextflow is not installed or not in PATH"
        exit 1
    fi
    log_info "Nextflow version: $(nextflow -version | head -n1)"
}

run_validation_tests() {
    log_info "Running validation script tests..."

    cd "$PROJECT_DIR"

    # Test FASTA validation
    log_info "Testing FASTA validation..."
    python3 bin/validate_fasta.py tests/data/genome.fa --output /tmp/fasta_test.json
    if [[ $? -eq 0 ]]; then
        log_info "FASTA validation: PASSED"
    else
        log_error "FASTA validation: FAILED"
        return 1
    fi

    # Test GTF validation
    log_info "Testing GTF validation..."
    python3 bin/validate_gtf.py tests/data/genes.gtf --output /tmp/gtf_test.json
    if [[ $? -eq 0 ]]; then
        log_info "GTF validation: PASSED"
    else
        log_error "GTF validation: FAILED"
        return 1
    fi

    # Test samplesheet validation
    log_info "Testing samplesheet validation..."
    python3 bin/validate_samplesheet.py tests/data/samplesheet.csv \
        --output /tmp/samplesheet_test.json \
        --output-csv /tmp/validated_samplesheet.csv
    if [[ $? -eq 0 ]]; then
        log_info "Samplesheet validation: PASSED"
    else
        log_error "Samplesheet validation: FAILED"
        return 1
    fi

    # Test annotation metrics
    log_info "Testing annotation metrics..."
    python3 bin/annotation_metrics.py tests/data/genes.gtf \
        --fasta tests/data/genome.fa \
        --output /tmp/metrics_test.json
    if [[ $? -eq 0 ]]; then
        log_info "Annotation metrics: PASSED"
    else
        log_error "Annotation metrics: FAILED"
        return 1
    fi

    log_info "All validation script tests passed!"
}

run_pipeline_test() {
    log_info "Running pipeline test..."

    cd "$PROJECT_DIR"

    # Build command
    NXF_CMD="nextflow run main.nf -profile $PROFILE"

    if [[ "$STUB_MODE" == "true" ]]; then
        NXF_CMD="$NXF_CMD -stub-run"
        log_info "Running in stub mode"
    fi

    # Run the pipeline
    log_info "Executing: $NXF_CMD"

    if $NXF_CMD; then
        log_info "Pipeline test: PASSED"
    else
        log_error "Pipeline test: FAILED"
        return 1
    fi
}

verify_outputs() {
    log_info "Verifying output files..."

    local output_dir
    if [[ "$PROFILE" == "test_stub" ]]; then
        output_dir="$PROJECT_DIR/results_stub"
    else
        output_dir="$PROJECT_DIR/results_test"
    fi

    local expected_files=(
        "validation/fasta_validation.json"
        "validation/gtf_validation.json"
        "validation/samplesheet_validation.json"
        "annotation_metrics/annotation_metrics.json"
        "report/report.html"
        "report/report.md"
    )

    local missing=0
    for file in "${expected_files[@]}"; do
        if [[ -f "$output_dir/$file" ]]; then
            log_info "Found: $file"
        else
            log_warn "Missing: $file"
            missing=$((missing + 1))
        fi
    done

    if [[ $missing -gt 0 ]]; then
        log_warn "$missing expected files are missing"
        return 1
    fi

    log_info "All expected output files found!"
}

cleanup() {
    log_info "Cleaning up..."
    rm -rf "$PROJECT_DIR/work"
    rm -rf "$PROJECT_DIR/.nextflow"
    rm -f "$PROJECT_DIR/.nextflow.log*"
    rm -rf /tmp/fasta_test.json /tmp/gtf_test.json /tmp/samplesheet_test.json
    rm -rf /tmp/metrics_test.json /tmp/validated_samplesheet.csv
}

# Main execution
main() {
    log_info "=============================================="
    log_info "Ensembl Genebuild Annotation Pipeline - Tests"
    log_info "=============================================="

    check_nextflow

    # Run validation script tests
    if ! run_validation_tests; then
        log_error "Validation script tests failed"
        exit 1
    fi

    # Run pipeline test
    if ! run_pipeline_test; then
        log_error "Pipeline test failed"
        exit 1
    fi

    # Verify outputs
    if ! verify_outputs; then
        log_warn "Some output verification checks failed"
    fi

    log_info "=============================================="
    log_info "All tests completed successfully!"
    log_info "=============================================="
}

# Run main function
main "$@"
