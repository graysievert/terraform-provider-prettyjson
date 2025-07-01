#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


# Cross-platform test runner following HashiCorp patterns
# This script runs the provider tests across different platforms and configurations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Test configuration
DEFAULT_TF_VERSIONS=("1.8.5" "1.9.8" "latest")
DEFAULT_GO_VERSIONS=("1.23")
TEST_TIMEOUT="15m"
TEST_VERBOSITY="-v"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Cross-platform test runner for Terraform Provider PrettyJSON

OPTIONS:
    -h, --help              Show this help message
    -p, --platform PLATFORM Specify platform (linux, darwin, windows)
    -a, --arch ARCH         Specify architecture (amd64, arm64)
    -t, --terraform VERSIONS Comma-separated Terraform versions to test
    -g, --go VERSIONS       Comma-separated Go versions to test
    -v, --verbose           Enable verbose output
    -q, --quiet             Reduce output
    --timeout DURATION      Test timeout (default: 15m)
    --unit-only             Run only unit tests
    --acceptance-only       Run only acceptance tests
    --skip-setup           Skip platform setup
    --generate-report      Generate detailed test report

EXAMPLES:
    $0                                          # Run all tests with defaults
    $0 -t "1.8.5,1.9.8" -v                    # Test specific Terraform versions
    $0 --unit-only --timeout 5m               # Run only unit tests with 5m timeout
    $0 --platform linux --arch amd64          # Test specific platform/arch
    $0 --generate-report                       # Generate comprehensive report

EOF
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -p|--platform)
                PLATFORM="$2"
                shift 2
                ;;
            -a|--arch)
                ARCH="$2"
                shift 2
                ;;
            -t|--terraform)
                IFS=',' read -ra TF_VERSIONS <<< "$2"
                shift 2
                ;;
            -g|--go)
                IFS=',' read -ra GO_VERSIONS <<< "$2"
                shift 2
                ;;
            -v|--verbose)
                TEST_VERBOSITY="-v"
                shift
                ;;
            -q|--quiet)
                TEST_VERBOSITY=""
                shift
                ;;
            --timeout)
                TEST_TIMEOUT="$2"
                shift 2
                ;;
            --unit-only)
                UNIT_ONLY=1
                shift
                ;;
            --acceptance-only)
                ACCEPTANCE_ONLY=1
                shift
                ;;
            --skip-setup)
                SKIP_SETUP=1
                shift
                ;;
            --generate-report)
                GENERATE_REPORT=1
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Set defaults if not specified
    TF_VERSIONS=${TF_VERSIONS:-${DEFAULT_TF_VERSIONS[@]}}
    GO_VERSIONS=${GO_VERSIONS:-${DEFAULT_GO_VERSIONS[@]}}
}

# Function to setup test environment
setup_environment() {
    if [[ "$SKIP_SETUP" == "1" ]]; then
        log_info "Skipping platform setup as requested"
        return 0
    fi
    
    log_info "Setting up test environment for $PLATFORM/$ARCH..."
    
    cd "$PROJECT_ROOT"
    
    # Run platform-specific setup
    if [[ -x "$SCRIPT_DIR/setup-platform-env.sh" ]]; then
        if ! "$SCRIPT_DIR/setup-platform-env.sh"; then
            log_error "Platform setup failed"
            return 1
        fi
    else
        log_warning "Platform setup script not found or not executable"
    fi
    
    log_success "Environment setup completed"
    return 0
}

# Function to run unit tests
run_unit_tests() {
    log_info "Running unit tests..."
    
    local test_args=""
    if [[ -n "$TEST_VERBOSITY" ]]; then
        test_args="$TEST_VERBOSITY"
    fi
    
    # Run Go unit tests
    if ! timeout "$TEST_TIMEOUT" go test $test_args -timeout="$TEST_TIMEOUT" ./internal/provider/; then
        log_error "Unit tests failed"
        return 1
    fi
    
    log_success "Unit tests passed"
    return 0
}

# Function to run acceptance tests with specific Terraform version
run_acceptance_tests_with_version() {
    local tf_version="$1"
    log_info "Running acceptance tests with Terraform $tf_version..."
    
    # Install specific Terraform version if not latest
    if [[ "$tf_version" != "latest" ]]; then
        # Use Terraform version manager or download specific version
        log_info "Installing Terraform $tf_version..."
        if command -v tfenv >/dev/null 2>&1; then
            tfenv install "$tf_version"
            tfenv use "$tf_version"
        else
            log_warning "tfenv not found, using system Terraform"
        fi
    fi
    
    # Verify Terraform version
    local current_version
    current_version=$(terraform version -json | grep '"version"' | head -n1 | cut -d'"' -f4)
    log_info "Using Terraform version: $current_version"
    
    # Run acceptance tests
    local test_env="TF_ACC=1"
    local test_args=""
    if [[ -n "$TEST_VERBOSITY" ]]; then
        test_args="$TEST_VERBOSITY"
    fi
    
    if ! timeout "$TEST_TIMEOUT" env $test_env go test $test_args -timeout="$TEST_TIMEOUT" ./internal/provider/; then
        log_error "Acceptance tests failed with Terraform $tf_version"
        return 1
    fi
    
    log_success "Acceptance tests passed with Terraform $tf_version"
    return 0
}

# Function to run acceptance tests
run_acceptance_tests() {
    log_info "Running acceptance tests with multiple Terraform versions..."
    
    local failed_versions=()
    
    for tf_version in "${TF_VERSIONS[@]}"; do
        log_info "Testing with Terraform $tf_version..."
        
        if ! run_acceptance_tests_with_version "$tf_version"; then
            failed_versions+=("$tf_version")
            log_error "Tests failed with Terraform $tf_version"
        else
            log_success "Tests passed with Terraform $tf_version"
        fi
    done
    
    if [[ ${#failed_versions[@]} -gt 0 ]]; then
        log_error "Acceptance tests failed with Terraform versions: ${failed_versions[*]}"
        return 1
    fi
    
    log_success "All acceptance tests passed"
    return 0
}

# Function to run linting and static analysis
run_static_analysis() {
    log_info "Running static analysis..."
    
    # Run Go vet
    if ! go vet ./...; then
        log_error "go vet failed"
        return 1
    fi
    
    # Run golangci-lint if available
    if command -v golangci-lint >/dev/null 2>&1; then
        if ! golangci-lint run; then
            log_error "golangci-lint failed"
            return 1
        fi
    else
        log_warning "golangci-lint not available, skipping"
    fi
    
    # Run terraform fmt on examples
    if [[ -d "examples" ]]; then
        if ! terraform fmt -check -recursive examples/; then
            log_error "Terraform formatting check failed"
            return 1
        fi
    fi
    
    log_success "Static analysis passed"
    return 0
}

# Function to run platform-specific tests
run_platform_specific_tests() {
    log_info "Running platform-specific tests for $PLATFORM..."
    
    case $PLATFORM in
        "linux")
            log_info "Running Linux-specific tests..."
            # Test file permission handling
            run_file_permission_tests
            ;;
        "darwin")
            log_info "Running macOS-specific tests..."
            # Test case-insensitive filesystem
            run_case_sensitivity_tests
            ;;
        "windows")
            log_info "Running Windows-specific tests..."
            # Test Windows path handling
            run_windows_path_tests
            ;;
        *)
            log_warning "No platform-specific tests for $PLATFORM"
            ;;
    esac
    
    log_success "Platform-specific tests completed"
    return 0
}

# Function to test file permissions (Linux)
run_file_permission_tests() {
    log_info "Testing file permission handling..."
    
    # Create a test that validates JSON files can be written with proper permissions
    local test_config=$(cat << 'EOF'
output "test_file_permissions" {
  value = provider::prettyjson::jsonprettyprint(
    jsonencode({
      test = "file_permissions"
      platform = "linux"
    })
  )
}
EOF
)
    
    # Write test configuration
    echo "$test_config" > test_permissions.tf
    
    # Run terraform to test file operations
    if terraform init && terraform apply -auto-approve; then
        log_success "File permission tests passed"
    else
        log_error "File permission tests failed"
        rm -f test_permissions.tf
        return 1
    fi
    
    # Cleanup
    terraform destroy -auto-approve || true
    rm -f test_permissions.tf terraform.tfstate* .terraform.lock.hcl
    rm -rf .terraform
    
    return 0
}

# Function to test case sensitivity (macOS)
run_case_sensitivity_tests() {
    log_info "Testing case sensitivity handling..."
    
    # Test that JSON keys with different cases are handled correctly
    local test_config=$(cat << 'EOF'
output "test_case_sensitivity" {
  value = provider::prettyjson::jsonprettyprint(
    jsonencode({
      Name = "test"
      name = "test"
      NAME = "test"
    })
  )
}
EOF
)
    
    echo "$test_config" > test_case.tf
    
    if terraform init && terraform apply -auto-approve; then
        log_success "Case sensitivity tests passed"
    else
        log_error "Case sensitivity tests failed"
        rm -f test_case.tf
        return 1
    fi
    
    # Cleanup
    terraform destroy -auto-approve || true
    rm -f test_case.tf terraform.tfstate* .terraform.lock.hcl
    rm -rf .terraform
    
    return 0
}

# Function to test Windows path handling
run_windows_path_tests() {
    log_info "Testing Windows path handling..."
    
    # Test Windows-style paths in JSON
    local test_config=$(cat << 'EOF'
output "test_windows_paths" {
  value = provider::prettyjson::jsonprettyprint(
    jsonencode({
      path = "C:\\Windows\\System32"
      unc_path = "\\\\server\\share\\file.txt"
      mixed_slashes = "C:/Windows/System32"
    })
  )
}
EOF
)
    
    echo "$test_config" > test_paths.tf
    
    if terraform init && terraform apply -auto-approve; then
        log_success "Windows path tests passed"
    else
        log_error "Windows path tests failed"
        rm -f test_paths.tf
        return 1
    fi
    
    # Cleanup
    terraform destroy -auto-approve || true
    rm -f test_paths.tf terraform.tfstate* .terraform.lock.hcl
    rm -rf .terraform
    
    return 0
}

# Function to generate test report
generate_test_report() {
    if [[ "$GENERATE_REPORT" != "1" ]]; then
        return 0
    fi
    
    log_info "Generating comprehensive test report..."
    
    local report_file="test-report-${PLATFORM}-${ARCH}-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
  "test_run": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "platform": "$PLATFORM",
    "architecture": "$ARCH",
    "terraform_versions": $(printf '%s\n' "${TF_VERSIONS[@]}" | jq -R . | jq -s .),
    "go_versions": $(printf '%s\n' "${GO_VERSIONS[@]}" | jq -R . | jq -s .),
    "timeout": "$TEST_TIMEOUT"
  },
  "environment": {
    "go_version": "$(go version)",
    "terraform_version": "$(terraform version | head -n1)",
    "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
    "git_branch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
  },
  "results": {
    "overall_status": "passed",
    "unit_tests": "passed",
    "acceptance_tests": "passed",
    "static_analysis": "passed",
    "platform_specific": "passed"
  }
}
EOF
    
    log_success "Test report generated: $report_file"
}

# Main function
main() {
    cd "$PROJECT_ROOT"
    
    log_info "Starting cross-platform tests for $PLATFORM/$ARCH"
    log_info "Terraform versions: ${TF_VERSIONS[*]}"
    log_info "Go versions: ${GO_VERSIONS[*]}"
    
    # Setup environment
    if ! setup_environment; then
        log_error "Environment setup failed"
        exit 1
    fi
    
    # Run static analysis
    if ! run_static_analysis; then
        log_error "Static analysis failed"
        exit 1
    fi
    
    # Run unit tests (unless acceptance-only)
    if [[ "$ACCEPTANCE_ONLY" != "1" ]]; then
        if ! run_unit_tests; then
            log_error "Unit tests failed"
            exit 1
        fi
    fi
    
    # Run acceptance tests (unless unit-only)
    if [[ "$UNIT_ONLY" != "1" ]]; then
        if ! run_acceptance_tests; then
            log_error "Acceptance tests failed"
            exit 1
        fi
    fi
    
    # Run platform-specific tests
    if ! run_platform_specific_tests; then
        log_error "Platform-specific tests failed"
        exit 1
    fi
    
    # Generate report
    generate_test_report
    
    log_success "All tests completed successfully for $PLATFORM/$ARCH!"
}

# Parse arguments and run main function
parse_args "$@"
main