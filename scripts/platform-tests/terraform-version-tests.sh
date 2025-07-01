#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


# Terraform version-specific testing script following HashiCorp patterns
# This script implements comprehensive testing across multiple Terraform versions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
DEFAULT_TERRAFORM_VERSIONS=("1.8.0" "1.8.5" "1.9.0" "1.9.8" "1.10.0" "latest")
MIN_TERRAFORM_VERSION="1.8.0"
TEST_TIMEOUT="15m"

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

Terraform version-specific testing script for prettyjson provider

OPTIONS:
    -h, --help              Show this help message
    -v, --versions VERSIONS Comma-separated Terraform versions to test
    -t, --timeout DURATION Test timeout (default: 15m)
    -m, --mode MODE         Test mode: minimal, standard, extended (default: standard)
    --unit-only             Run only unit tests
    --acceptance-only       Run only acceptance tests
    --function-only         Run only function-specific tests
    --verbose               Enable verbose output
    --generate-report       Generate detailed compatibility report
    --validate-only         Only validate Terraform versions without testing

EXAMPLES:
    $0                                          # Run standard tests with default versions
    $0 -v "1.8.0,1.9.8,latest"                # Test specific versions
    $0 -m extended --generate-report           # Extended testing with report
    $0 --function-only -v "1.8.0,latest"      # Function tests on specific versions
    $0 --validate-only                         # Just validate available versions

EOF
}

# Function to validate Terraform version
validate_terraform_version() {
    local version="$1"
    local installed_version
    
    log_info "Validating Terraform version $version..."
    
    if [[ "$version" == "latest" ]]; then
        log_success "Using latest Terraform version"
        return 0
    fi
    
    # Check if version meets minimum requirement
    if ! printf '%s\n%s\n' "$MIN_TERRAFORM_VERSION" "$version" | sort -V | head -1 | grep -q "^$MIN_TERRAFORM_VERSION$"; then
        log_error "Terraform version $version is below minimum required version $MIN_TERRAFORM_VERSION"
        return 1
    fi
    
    log_success "Terraform version $version meets minimum requirement"
    return 0
}

# Function to install specific Terraform version
install_terraform_version() {
    local version="$1"
    local install_dir="$HOME/.terraform-versions"
    local binary_path="$install_dir/terraform-$version"
    
    if [[ "$version" == "latest" ]]; then
        # Use system terraform for latest
        if command -v terraform >/dev/null 2>&1; then
            log_success "Using system Terraform (latest)"
            export TERRAFORM_BINARY="terraform"
            return 0
        else
            log_error "No system Terraform found for 'latest' version"
            return 1
        fi
    fi
    
    # Check if already installed
    if [[ -x "$binary_path" ]]; then
        log_info "Terraform $version already installed at $binary_path"
        export TERRAFORM_BINARY="$binary_path"
        return 0
    fi
    
    log_info "Installing Terraform $version..."
    
    # Create install directory
    mkdir -p "$install_dir"
    
    # Determine architecture
    local arch
    case "$(uname -m)" in
        "x86_64") arch="amd64" ;;
        "arm64"|"aarch64") arch="arm64" ;;
        "i386"|"i686") arch="386" ;;
        *) 
            log_error "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac
    
    # Determine OS
    local os
    case "$(uname -s)" in
        "Linux") os="linux" ;;
        "Darwin") os="darwin" ;;
        "MINGW"*|"MSYS"*|"CYGWIN"*) os="windows" ;;
        *)
            log_error "Unsupported operating system: $(uname -s)"
            return 1
            ;;
    esac
    
    # Download and install
    local download_url="https://releases.hashicorp.com/terraform/${version}/terraform_${version}_${os}_${arch}.zip"
    local temp_file="$(mktemp)"
    
    if curl -fsSL "$download_url" -o "$temp_file"; then
        # Extract terraform binary
        if command -v unzip >/dev/null 2>&1; then
            unzip -q -o "$temp_file" -d "$install_dir"
            mv "$install_dir/terraform" "$binary_path"
            chmod +x "$binary_path"
            rm -f "$temp_file"
            
            export TERRAFORM_BINARY="$binary_path"
            log_success "Terraform $version installed successfully"
            return 0
        else
            log_error "unzip command not available"
            rm -f "$temp_file"
            return 1
        fi
    else
        log_error "Failed to download Terraform $version from $download_url"
        rm -f "$temp_file"
        return 1
    fi
}

# Function to run unit tests with specific Terraform version
run_unit_tests() {
    local version="$1"
    local verbose="$2"
    
    log_info "Running unit tests with Terraform $version..."
    
    local test_args=""
    if [[ "$verbose" == "1" ]]; then
        test_args="-v"
    fi
    
    if go test $test_args -timeout="$TEST_TIMEOUT" ./internal/provider/; then
        log_success "Unit tests passed with Terraform $version"
        return 0
    else
        log_error "Unit tests failed with Terraform $version"
        return 1
    fi
}

# Function to run acceptance tests with specific Terraform version
run_acceptance_tests() {
    local version="$1"
    local verbose="$2"
    
    log_info "Running acceptance tests with Terraform $version..."
    
    local test_args=""
    if [[ "$verbose" == "1" ]]; then
        test_args="-v"
    fi
    
    export TF_ACC="1"
    export TF_TERRAFORM_BINARY="$TERRAFORM_BINARY"
    
    if go test $test_args -timeout="$TEST_TIMEOUT" ./internal/provider/; then
        log_success "Acceptance tests passed with Terraform $version"
        return 0
    else
        log_error "Acceptance tests failed with Terraform $version"
        return 1
    fi
}

# Function to run function-specific tests
run_function_tests() {
    local version="$1"
    local verbose="$2"
    
    log_info "Running function-specific tests with Terraform $version..."
    
    local test_args=""
    if [[ "$verbose" == "1" ]]; then
        test_args="-v"
    fi
    
    export TF_ACC="1"
    export TF_TERRAFORM_BINARY="$TERRAFORM_BINARY"
    
    if go test $test_args -timeout="$TEST_TIMEOUT" -run "TestJsonPrettyPrintFunction" ./internal/provider/; then
        log_success "Function tests passed with Terraform $version"
        return 0
    else
        log_error "Function tests failed with Terraform $version"
        return 1
    fi
}

# Function to run version-specific behavior tests
run_version_behavior_tests() {
    local version="$1"
    local verbose="$2"
    
    log_info "Running version-specific behavior tests with Terraform $version..."
    
    # Test error handling patterns
    log_info "Testing error handling with Terraform $version..."
    export TF_ACC="1"
    export TF_TERRAFORM_BINARY="$TERRAFORM_BINARY"
    
    local test_args=""
    if [[ "$verbose" == "1" ]]; then
        test_args="-v"
    fi
    
    # Run error handling tests
    if ! go test $test_args -timeout="$TEST_TIMEOUT" -run ".*Error.*" ./internal/provider/; then
        log_warning "Some error handling tests failed with Terraform $version"
    fi
    
    # Run protocol compatibility tests
    log_info "Testing protocol compatibility with Terraform $version..."
    if ! go test $test_args -timeout="$TEST_TIMEOUT" -run ".*Protocol.*" ./internal/provider/; then
        log_warning "Some protocol tests may not be available for Terraform $version"
    fi
    
    log_success "Version-specific behavior tests completed for Terraform $version"
}

# Function to generate test report for a version
generate_version_report() {
    local version="$1"
    local status="$2"
    local start_time="$3"
    local end_time="$4"
    
    local report_file="terraform-${version}-test-report.json"
    local actual_version
    
    if [[ -n "$TERRAFORM_BINARY" ]] && command -v "$TERRAFORM_BINARY" >/dev/null 2>&1; then
        actual_version=$("$TERRAFORM_BINARY" version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || "$TERRAFORM_BINARY" version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    else
        actual_version="unknown"
    fi
    
    cat > "$report_file" << EOF
{
  "terraform_version": "$version",
  "actual_version": "$actual_version",
  "test_status": "$status",
  "test_start": "$start_time",
  "test_end": "$end_time",
  "test_duration": "$((end_time - start_time)) seconds",
  "environment": {
    "go_version": "$(go version 2>/dev/null || echo 'unknown')",
    "platform": "$(uname -s | tr '[:upper:]' '[:lower:]')",
    "architecture": "$(uname -m)",
    "terraform_binary": "${TERRAFORM_BINARY:-unknown}"
  },
  "test_configuration": {
    "timeout": "$TEST_TIMEOUT",
    "test_mode": "$TEST_MODE",
    "verbose": "$VERBOSE"
  }
}
EOF
    
    log_info "Test report generated: $report_file"
}

# Function to run comprehensive tests for a version
test_terraform_version() {
    local version="$1"
    local start_time=$(date +%s)
    local status="success"
    
    log_info "=================================================="
    log_info "Testing Terraform version: $version"
    log_info "=================================================="
    
    # Validate version
    if ! validate_terraform_version "$version"; then
        status="validation_failed"
        generate_version_report "$version" "$status" "$start_time" "$(date +%s)"
        return 1
    fi
    
    # Install/setup Terraform version
    if ! install_terraform_version "$version"; then
        status="installation_failed"
        generate_version_report "$version" "$status" "$start_time" "$(date +%s)"
        return 1
    fi
    
    # Verify installation
    if [[ -n "$TERRAFORM_BINARY" ]]; then
        log_info "Using Terraform binary: $TERRAFORM_BINARY"
        if "$TERRAFORM_BINARY" version >/dev/null 2>&1; then
            log_info "Terraform version verification: $("$TERRAFORM_BINARY" version | head -1)"
        else
            log_error "Failed to verify Terraform installation"
            status="verification_failed"
            generate_version_report "$version" "$status" "$start_time" "$(date +%s)"
            return 1
        fi
    fi
    
    # Set TF_VERSION environment variable for version-specific tests
    if [[ "$version" == "latest" ]]; then
        export TF_VERSION=$("$TERRAFORM_BINARY" version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    else
        export TF_VERSION="$version"
    fi
    
    # Run tests based on mode
    if [[ "$UNIT_ONLY" == "1" ]] || [[ "$TEST_MODE" != "function-only" && "$TEST_MODE" != "acceptance-only" ]]; then
        if ! run_unit_tests "$version" "$VERBOSE"; then
            status="unit_tests_failed"
        fi
    fi
    
    if [[ "$ACCEPTANCE_ONLY" == "1" ]] || [[ "$TEST_MODE" != "function-only" && "$TEST_MODE" != "unit-only" ]]; then
        if ! run_acceptance_tests "$version" "$VERBOSE"; then
            status="acceptance_tests_failed"
        fi
    fi
    
    if [[ "$FUNCTION_ONLY" == "1" ]] || [[ "$TEST_MODE" == "extended" ]]; then
        if ! run_function_tests "$version" "$VERBOSE"; then
            status="function_tests_failed"
        fi
    fi
    
    # Run version-specific behavior tests for extended mode
    if [[ "$TEST_MODE" == "extended" ]]; then
        run_version_behavior_tests "$version" "$VERBOSE"
    fi
    
    local end_time=$(date +%s)
    generate_version_report "$version" "$status" "$start_time" "$end_time"
    
    if [[ "$status" == "success" ]]; then
        log_success "All tests passed for Terraform $version"
        return 0
    else
        log_error "Tests failed for Terraform $version (status: $status)"
        return 1
    fi
}

# Function to generate comprehensive compatibility report
generate_compatibility_report() {
    local report_file="terraform-compatibility-report.md"
    
    log_info "Generating comprehensive compatibility report..."
    
    cat > "$report_file" << EOF
# Terraform Version Compatibility Report

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
**Test Mode:** $TEST_MODE  
**Versions Tested:** ${TERRAFORM_VERSIONS[*]}

## Summary

This report contains compatibility test results for the prettyjson Terraform provider across multiple Terraform versions.

## Test Results

| Version | Status | Duration | Notes |
|---------|--------|----------|-------|
EOF

    # Process individual test reports
    for version in "${TERRAFORM_VERSIONS[@]}"; do
        local report_file_json="terraform-${version}-test-report.json"
        if [[ -f "$report_file_json" ]]; then
            local status=$(jq -r '.test_status' "$report_file_json" 2>/dev/null || echo "unknown")
            local duration=$(jq -r '.test_duration' "$report_file_json" 2>/dev/null || echo "unknown")
            local actual_version=$(jq -r '.actual_version' "$report_file_json" 2>/dev/null || echo "unknown")
            
            local status_icon
            case "$status" in
                "success") status_icon="✅" ;;
                *) status_icon="❌" ;;
            esac
            
            echo "| $version ($actual_version) | $status_icon $status | ${duration}s | - |" >> "$report_file"
        else
            echo "| $version | ❌ no_report | - | Report file not found |" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF

## Configuration

- **Minimum Terraform Version:** $MIN_TERRAFORM_VERSION
- **Test Timeout:** $TEST_TIMEOUT
- **Test Mode:** $TEST_MODE

## Recommendations

- Ensure Terraform version >= $MIN_TERRAFORM_VERSION for provider function support
- Regularly test against latest Terraform releases
- Monitor for deprecation warnings in provider function protocol

## Test Environment

- **Platform:** $(uname -s | tr '[:upper:]' '[:lower:]')
- **Architecture:** $(uname -m)
- **Go Version:** $(go version 2>/dev/null || echo 'unknown')
- **Project Root:** $PROJECT_ROOT

EOF

    log_success "Compatibility report generated: $report_file"
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--versions)
                IFS=',' read -ra TERRAFORM_VERSIONS <<< "$2"
                shift 2
                ;;
            -t|--timeout)
                TEST_TIMEOUT="$2"
                shift 2
                ;;
            -m|--mode)
                TEST_MODE="$2"
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
            --function-only)
                FUNCTION_ONLY=1
                shift
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --generate-report)
                GENERATE_REPORT=1
                shift
                ;;
            --validate-only)
                VALIDATE_ONLY=1
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Set defaults
    if [[ -z "${TERRAFORM_VERSIONS}" ]]; then
        TERRAFORM_VERSIONS=("${DEFAULT_TERRAFORM_VERSIONS[@]}")
    fi
    TEST_MODE=${TEST_MODE:-"standard"}
    VERBOSE=${VERBOSE:-0}
    GENERATE_REPORT=${GENERATE_REPORT:-0}
    VALIDATE_ONLY=${VALIDATE_ONLY:-0}
}

# Main function
main() {
    cd "$PROJECT_ROOT"
    
    log_info "Starting Terraform version compatibility testing"
    log_info "Project root: $PROJECT_ROOT"
    log_info "Test mode: $TEST_MODE"
    log_info "Versions to test: ${TERRAFORM_VERSIONS[*]}"
    
    # Validate Go is available
    if ! command -v go >/dev/null 2>&1; then
        log_error "Go is not installed or not in PATH"
        exit 1
    fi
    
    log_info "Go version: $(go version)"
    
    # Download Go modules
    log_info "Downloading Go modules..."
    go mod download
    
    # Verify Go modules
    log_info "Verifying Go modules..."
    go mod verify
    
    # Build provider
    log_info "Building provider..."
    if ! go build -v .; then
        log_error "Failed to build provider"
        exit 1
    fi
    
    local failed_versions=()
    local successful_versions=()
    
    # Test each version
    for version in "${TERRAFORM_VERSIONS[@]}"; do
        if [[ "$VALIDATE_ONLY" == "1" ]]; then
            if validate_terraform_version "$version"; then
                successful_versions+=("$version")
            else
                failed_versions+=("$version")
            fi
        else
            if test_terraform_version "$version"; then
                successful_versions+=("$version")
            else
                failed_versions+=("$version")
            fi
        fi
    done
    
    # Generate report if requested
    if [[ "$GENERATE_REPORT" == "1" && "$VALIDATE_ONLY" != "1" ]]; then
        generate_compatibility_report
    fi
    
    # Summary
    log_info "=================================================="
    log_info "Terraform Version Compatibility Test Summary"
    log_info "=================================================="
    log_info "Total versions tested: ${#TERRAFORM_VERSIONS[@]}"
    log_success "Successful: ${#successful_versions[@]} (${successful_versions[*]})"
    
    if [[ ${#failed_versions[@]} -gt 0 ]]; then
        log_error "Failed: ${#failed_versions[@]} (${failed_versions[*]})"
        exit 1
    else
        log_success "All Terraform version compatibility tests passed!"
        exit 0
    fi
}

# Parse arguments and run
parse_args "$@"
main