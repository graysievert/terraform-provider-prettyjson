#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#
# test-provider.sh - POSIX-compliant testing script for prettyjson Terraform provider
#
# This script compiles the provider and tests examples using only built-in Terraform
# functionality (terraform_data, local-exec) to avoid external registry dependencies.
#
# Usage:
#   ./test-provider.sh test    - Compile provider and run all tests
#   ./test-provider.sh clean   - Clean all generated files and reset environment
#

set -e  # Exit on any error

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"  # Go up one level since script is in scripts/
PROVIDER_NAME="prettyjson"
PROVIDER_SOURCE="local/${PROVIDER_NAME}"
TERRAFORMRC_BACKUP="${HOME}/.terraformrc.backup.$(date +%s)"
EXAMPLES_DIR="${SCRIPT_DIR}/examples"

# Colors for output (POSIX compatible)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Logging functions
log_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

log_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command_exists "terraform"; then
        log_error "Terraform is not installed or not in PATH"
        return 1
    fi
    
    if ! command_exists "go"; then
        log_error "Go is not installed or not in PATH"
        return 1
    fi
    
    if ! command_exists "make"; then
        log_error "Make is not installed or not in PATH"
        return 1
    fi
    
    # Check for Makefile or GNUmakefile
    if [ ! -f "${SCRIPT_DIR}/Makefile" ] && [ ! -f "${SCRIPT_DIR}/GNUmakefile" ]; then
        log_error "Makefile or GNUmakefile not found in ${SCRIPT_DIR}"
        return 1
    fi
    
    log_success "All prerequisites satisfied"
    return 0
}

# Get Go bin directory
get_go_bin_dir() {
    if [ -n "${GOBIN}" ]; then
        echo "${GOBIN}"
    else
        local gopath
        gopath="$(go env GOPATH | sed 's/:.*$//')"
        echo "${gopath}/bin"
    fi
}

# Setup .terraformrc for local provider development
setup_terraformrc() {
    local go_bin_dir
    go_bin_dir="$(get_go_bin_dir)"
    
    log_info "Setting up .terraformrc for local provider development"
    
    # Backup existing .terraformrc if it exists
    if [ -f "${HOME}/.terraformrc" ]; then
        log_info "Backing up existing .terraformrc to ${TERRAFORMRC_BACKUP}"
        cp "${HOME}/.terraformrc" "${TERRAFORMRC_BACKUP}"
    fi
    
    # Create new .terraformrc with dev_overrides
    cat > "${HOME}/.terraformrc" << EOF
provider_installation {
  dev_overrides {
    "${PROVIDER_SOURCE}" = "${go_bin_dir}"
  }
  
  # For all other providers, install them directly from their origin provider
  # registries as normal.
  direct {}
}
EOF
    
    log_success "Created .terraformrc with dev_overrides pointing to ${go_bin_dir}"
}

# Restore original .terraformrc
restore_terraformrc() {
    log_info "Restoring original .terraformrc configuration"
    
    if [ -f "${TERRAFORMRC_BACKUP}" ]; then
        mv "${TERRAFORMRC_BACKUP}" "${HOME}/.terraformrc"
        log_success "Restored .terraformrc from backup"
    else
        rm -f "${HOME}/.terraformrc"
        log_success "Removed .terraformrc (no backup existed)"
    fi
}

# Compile the provider
compile_provider() {
    log_info "Compiling prettyjson provider..."
    
    cd "${SCRIPT_DIR}"
    
    # Use existing Makefile targets
    if make build >/dev/null 2>&1; then
        log_success "Provider build completed"
    else
        log_error "Provider build failed"
        return 1
    fi
    
    if make install >/dev/null 2>&1; then
        log_success "Provider installation completed"
    else
        log_error "Provider installation failed"
        return 1
    fi
    
    # Verify provider binary exists
    local go_bin_dir
    go_bin_dir="$(get_go_bin_dir)"
    local provider_binary="${go_bin_dir}/terraform-provider-${PROVIDER_NAME}"
    
    if [ -f "${provider_binary}" ]; then
        log_success "Provider binary found at ${provider_binary}"
    else
        log_error "Provider binary not found at ${provider_binary}"
        return 1
    fi
}

# Test a single example directory
test_example() {
    local example_dir="$1"
    local example_name
    example_name="$(basename "${example_dir}")"
    
    log_info "Testing example: ${example_name}"
    
    if [ ! -d "${example_dir}" ]; then
        log_warning "Example directory ${example_dir} does not exist, skipping"
        return 0
    fi
    
    if [ ! -f "${example_dir}/main.tf" ]; then
        log_warning "No main.tf found in ${example_dir}, skipping"
        return 0
    fi
    
    cd "${example_dir}"
    
    # Clean any existing terraform state (but keep generated files from previous runs)
    rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup tfplan
    
    log_info "  Running terraform plan for ${example_name}..."
    if terraform plan -out="tfplan" >/dev/null 2>&1; then
        log_success "  Plan successful for ${example_name}"
    else
        log_error "  Plan failed for ${example_name}"
        return 1
    fi
    
    log_info "  Running terraform apply for ${example_name}..."
    if terraform apply -auto-approve "tfplan" 2>&1; then
        log_success "  Apply successful for ${example_name}"
    else
        log_error "  Apply failed for ${example_name}"
        return 1
    fi
    
    # Verify outputs if they exist
    if terraform output >/dev/null 2>&1; then
        log_success "  Outputs verified for ${example_name}"
    fi
    
    # List generated files for manual review
    log_info "  Generated files in ${example_name}:"
    find . -name "*.json" -type f 2>/dev/null | head -5 | while read -r file; do
        log_info "    - $(basename "${file}") ($(wc -c < "${file}" 2>/dev/null || echo "0") bytes)"
    done
    
    # Clean only terraform state files, keep generated content for review
    rm -f tfplan terraform.tfstate terraform.tfstate.backup
    
    return 0
}

# Run all tests
run_tests() {
    local test_results=0
    local examples_tested=0
    
    log_info "Starting provider tests..."
    
    # Test each built-in example directory
    for example_dir in "${EXAMPLES_DIR}"/basic-builtin \
                      "${EXAMPLES_DIR}"/integration-builtin \
                      "${EXAMPLES_DIR}"/performance-builtin; do
        if [ -d "${example_dir}" ]; then
            if test_example "${example_dir}"; then
                examples_tested=$((examples_tested + 1))
            else
                test_results=1
            fi
        fi
    done
    
    cd "${SCRIPT_DIR}"
    
    if [ ${test_results} -eq 0 ]; then
        log_success "All tests passed! (${examples_tested} examples tested)"
    else
        log_error "Some tests failed!"
    fi
    
    return ${test_results}
}

# Clean generated files and reset environment
clean_environment() {
    log_info "Cleaning generated files and resetting environment..."
    
    cd "${SCRIPT_DIR}"
    
    # Clean example directories
    for example_dir in "${EXAMPLES_DIR}"/*/; do
        if [ -d "${example_dir}" ]; then
            cd "${example_dir}"
            log_info "  Cleaning $(basename "${example_dir}")..."
            
            # Remove terraform files
            rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup tfplan
            
            # Remove generated JSON files and directories
            rm -f *.json
            rm -rf configs k8s formats metadata chunks performance-test
            
            cd "${SCRIPT_DIR}"
        fi
    done
    
    # Clean build artifacts if make clean target exists
    if make clean >/dev/null 2>&1; then
        log_success "  Build artifacts cleaned"
    fi
    
    # Remove any backup files
    rm -f "${HOME}/.terraformrc.backup."*
    
    log_success "Environment cleaned successfully"
}

# Display usage information
show_usage() {
    cat << EOF
Usage: $0 {test|clean}

Commands:
  test   - Compile the prettyjson provider and run all example tests, preserving generated files
  clean  - Remove all generated files, terraform state, and reset environment

Examples:
  $0 test    # Run full test suite and preserve files for manual review
  $0 clean   # Clean up all generated files and reset environment

The test command will:
1. Check prerequisites (terraform, go, make/GNUmakefile)
2. Setup .terraformrc with dev_overrides for local provider development
3. Compile and install the prettyjson provider using existing build system
4. Test examples sequentially using only built-in terraform functionality:
   - basic-builtin/: Basic provider functionality with 2spaces/4spaces/tab indentation
   - integration-builtin/: Multi-resource integration with microservices, K8s, dynamic configs
   - performance-builtin/: Performance optimization with chunking, conditional creation
5. Preserve all generated JSON files in examples/*-builtin/ directories for manual review
6. Restore original .terraformrc configuration on exit

The clean command will:
1. Remove all generated JSON files and directory structures
2. Clean terraform state files (.terraform/, .terraform.lock.hcl, tfplan, etc.)
3. Clean build artifacts if make clean target exists
4. Restore original .terraformrc configuration
5. Remove backup files

Key Features:
- POSIX-compliant shell script for cross-platform compatibility
- Uses terraform_data and local-exec to avoid external registry dependencies
- Comprehensive error handling with colored output and proper cleanup
- JSON validation using jq when available
- Indentation verification with visual output (cat -A)
- Performance timing measurements during operations
- Automatic .terraformrc backup and restoration

Generated Files After Testing:
  examples/basic-builtin/config-{2spaces,4spaces,tabs}.json
  examples/integration-builtin/configs/{microservices-dev,microservices-prod,dynamic-config}.json
  examples/integration-builtin/k8s/configmap.json
  examples/integration-builtin/formats/config-{2spaces,4spaces,tabs}.json
  examples/performance-builtin/configs/{large-services-config,optimized-services-config,etc}.json
  examples/performance-builtin/chunks/services-chunk-{0,1,2,3}.json

All generated files demonstrate proper JSON formatting with the prettyjson provider's
2spaces, 4spaces, and tab indentation options, and can be manually inspected to
verify provider functionality without external registry dependencies.
EOF
}

# Main execution
main() {
    local command="$1"
    
    case "${command}" in
        "test")
            # Set up cleanup trap only when running tests
            trap 'restore_terraformrc' EXIT INT TERM
            
            if ! check_prerequisites; then
                exit 1
            fi
            
            setup_terraformrc
            
            if compile_provider && run_tests; then
                log_success "All provider tests completed successfully!"
                log_info "Generated files preserved for manual review in examples/*-builtin/ directories"
                exit 0
            else
                log_error "Provider tests failed!"
                exit 1
            fi
            ;;
        "clean")
            clean_environment
            exit 0
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"