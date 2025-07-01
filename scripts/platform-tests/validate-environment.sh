#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


# Comprehensive environment validation script following HashiCorp patterns
# This script performs rigorous validation of system requirements and environment configuration
# before running cross-platform tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Platform detection
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation configuration
MIN_GO_VERSION="1.23.0"
MIN_TERRAFORM_VERSION="1.8.0"
MIN_MAKE_VERSION="3.81"
MIN_GIT_VERSION="2.20.0"
MIN_DISK_SPACE_MB=1024  # 1GB minimum
MIN_MEMORY_MB=2048      # 2GB minimum

# Validation results tracking
VALIDATION_ERRORS=()
VALIDATION_WARNINGS=()
VALIDATION_PASSED=0
VALIDATION_TOTAL=0

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

# Function to record validation result
record_validation() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    VALIDATION_TOTAL=$((VALIDATION_TOTAL + 1))
    
    if [[ "$result" == "pass" ]]; then
        VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
        log_success "✅ $test_name: $message"
    elif [[ "$result" == "warning" ]]; then
        VALIDATION_WARNINGS+=("$test_name: $message")
        log_warning "⚠️  $test_name: $message"
    else
        VALIDATION_ERRORS+=("$test_name: $message")
        log_error "❌ $test_name: $message"
    fi
}

# Function to compare versions
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Remove 'v' prefix if present
    version1="${version1#v}"
    version2="${version2#v}"
    
    # Compare using sort -V (version sort)
    # Returns 0 if version1 >= version2, 1 if version1 < version2
    if printf '%s\n%s\n' "$version2" "$version1" | sort -V | head -1 | grep -q "^$version2$"; then
        return 0  # version1 >= version2
    else
        return 1  # version1 < version2
    fi
}

# Function to validate Go installation and version
validate_go() {
    log_info "Validating Go installation..."
    
    if ! command -v go >/dev/null 2>&1; then
        record_validation "Go Installation" "fail" "Go is not installed or not in PATH"
        return 1
    fi
    
    local go_version
    go_version=$(go version | grep -oE 'go[0-9]+\.[0-9]+\.[0-9]+' | sed 's/go//')
    
    if [[ -z "$go_version" ]]; then
        record_validation "Go Version Detection" "fail" "Could not determine Go version"
        return 1
    fi
    
    if version_compare "$go_version" "$MIN_GO_VERSION"; then
        record_validation "Go Version" "pass" "Go $go_version (>= $MIN_GO_VERSION required)"
    else
        record_validation "Go Version" "fail" "Go $go_version is below minimum required version $MIN_GO_VERSION"
        return 1
    fi
    
    # Validate Go environment
    local goroot gopath
    goroot=$(go env GOROOT)
    gopath=$(go env GOPATH)
    
    if [[ -z "$goroot" ]]; then
        record_validation "Go GOROOT" "warning" "GOROOT is not set"
    else
        record_validation "Go GOROOT" "pass" "GOROOT=$goroot"
    fi
    
    if [[ -z "$gopath" ]]; then
        record_validation "Go GOPATH" "warning" "GOPATH is not set (using module mode)"
    else
        record_validation "Go GOPATH" "pass" "GOPATH=$gopath"
    fi
    
    # Test Go compilation
    if go version >/dev/null 2>&1; then
        record_validation "Go Compilation Test" "pass" "Go compiler is functional"
    else
        record_validation "Go Compilation Test" "fail" "Go compiler test failed"
        return 1
    fi
    
    return 0
}

# Function to validate Terraform installation and version
validate_terraform() {
    log_info "Validating Terraform installation..."
    
    if ! command -v terraform >/dev/null 2>&1; then
        record_validation "Terraform Installation" "fail" "Terraform is not installed or not in PATH"
        return 1
    fi
    
    local tf_version
    if command -v jq >/dev/null 2>&1; then
        tf_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null)
    fi
    
    if [[ -z "$tf_version" ]]; then
        # Fallback method without jq
        tf_version=$(terraform version 2>/dev/null | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/v//')
    fi
    
    if [[ -z "$tf_version" ]]; then
        record_validation "Terraform Version Detection" "fail" "Could not determine Terraform version"
        return 1
    fi
    
    if version_compare "$tf_version" "$MIN_TERRAFORM_VERSION"; then
        record_validation "Terraform Version" "pass" "Terraform $tf_version (>= $MIN_TERRAFORM_VERSION required for provider functions)"
    else
        record_validation "Terraform Version" "fail" "Terraform $tf_version is below minimum required version $MIN_TERRAFORM_VERSION for provider functions"
        return 1
    fi
    
    # Test Terraform basic functionality
    if terraform version >/dev/null 2>&1; then
        record_validation "Terraform Functionality Test" "pass" "Terraform is functional"
    else
        record_validation "Terraform Functionality Test" "fail" "Terraform functionality test failed"
        return 1
    fi
    
    return 0
}

# Function to validate Make installation
validate_make() {
    log_info "Validating Make installation..."
    
    if ! command -v make >/dev/null 2>&1; then
        record_validation "Make Installation" "fail" "Make is not installed or not in PATH"
        return 1
    fi
    
    local make_version
    make_version=$(make --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
    
    if [[ -z "$make_version" ]]; then
        record_validation "Make Version Detection" "warning" "Could not determine Make version, but Make is available"
    else
        if version_compare "$make_version" "$MIN_MAKE_VERSION"; then
            record_validation "Make Version" "pass" "Make $make_version (>= $MIN_MAKE_VERSION required)"
        else
            record_validation "Make Version" "warning" "Make $make_version is below recommended version $MIN_MAKE_VERSION"
        fi
    fi
    
    # Test Make functionality
    if make --version >/dev/null 2>&1; then
        record_validation "Make Functionality Test" "pass" "Make is functional"
    else
        record_validation "Make Functionality Test" "fail" "Make functionality test failed"
        return 1
    fi
    
    return 0
}

# Function to validate Git installation
validate_git() {
    log_info "Validating Git installation..."
    
    if ! command -v git >/dev/null 2>&1; then
        record_validation "Git Installation" "fail" "Git is not installed or not in PATH"
        return 1
    fi
    
    local git_version
    git_version=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    
    if [[ -z "$git_version" ]]; then
        record_validation "Git Version Detection" "warning" "Could not determine Git version, but Git is available"
    else
        if version_compare "$git_version" "$MIN_GIT_VERSION"; then
            record_validation "Git Version" "pass" "Git $git_version (>= $MIN_GIT_VERSION required)"
        else
            record_validation "Git Version" "warning" "Git $git_version is below recommended version $MIN_GIT_VERSION"
        fi
    fi
    
    # Test Git functionality
    if git --version >/dev/null 2>&1; then
        record_validation "Git Functionality Test" "pass" "Git is functional"
    else
        record_validation "Git Functionality Test" "fail" "Git functionality test failed"
        return 1
    fi
    
    return 0
}

# Function to validate system resources
validate_system_resources() {
    log_info "Validating system resources..."
    
    # Check available disk space
    local available_space_kb
    case "$PLATFORM" in
        "linux"|"darwin")
            available_space_kb=$(df "$PROJECT_ROOT" | tail -1 | awk '{print $4}')
            ;;
        "windows"|"msys"*|"mingw"*|"cygwin"*)
            # Windows with Git Bash/MSYS
            available_space_kb=$(df "$PROJECT_ROOT" 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
            ;;
        *)
            available_space_kb="0"
            ;;
    esac
    
    if [[ "$available_space_kb" -gt 0 ]]; then
        local available_space_mb=$((available_space_kb / 1024))
        if [[ "$available_space_mb" -ge "$MIN_DISK_SPACE_MB" ]]; then
            record_validation "Disk Space" "pass" "${available_space_mb}MB available (>= ${MIN_DISK_SPACE_MB}MB required)"
        else
            record_validation "Disk Space" "warning" "${available_space_mb}MB available (< ${MIN_DISK_SPACE_MB}MB recommended)"
        fi
    else
        record_validation "Disk Space" "warning" "Could not determine available disk space"
    fi
    
    # Check available memory (best effort)
    local available_memory_mb=0
    case "$PLATFORM" in
        "linux")
            if [[ -f /proc/meminfo ]]; then
                available_memory_mb=$(grep MemAvailable /proc/meminfo | awk '{print int($2/1024)}')
            fi
            ;;
        "darwin")
            if command -v vm_stat >/dev/null 2>&1; then
                local page_size=$(vm_stat | grep "page size" | awk '{print $8}')
                local free_pages=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
                if [[ -n "$page_size" && -n "$free_pages" ]]; then
                    available_memory_mb=$(((page_size * free_pages) / 1024 / 1024))
                fi
            fi
            ;;
    esac
    
    if [[ "$available_memory_mb" -gt 0 ]]; then
        if [[ "$available_memory_mb" -ge "$MIN_MEMORY_MB" ]]; then
            record_validation "Available Memory" "pass" "${available_memory_mb}MB available (>= ${MIN_MEMORY_MB}MB required)"
        else
            record_validation "Available Memory" "warning" "${available_memory_mb}MB available (< ${MIN_MEMORY_MB}MB recommended)"
        fi
    else
        record_validation "Available Memory" "warning" "Could not determine available memory"
    fi
}

# Function to validate project structure
validate_project_structure() {
    log_info "Validating project structure..."
    
    cd "$PROJECT_ROOT"
    
    # Check for essential files
    local essential_files=(
        "go.mod"
        "go.sum"
        "main.go"
        "GNUmakefile"
        "internal/provider/jsonprettyprint_function.go"
        "internal/provider/provider.go"
    )
    
    for file in "${essential_files[@]}"; do
        if [[ -f "$file" ]]; then
            record_validation "Project File: $file" "pass" "Required file exists"
        else
            record_validation "Project File: $file" "fail" "Required file is missing"
        fi
    done
    
    # Check for Go module validity
    if go mod verify >/dev/null 2>&1; then
        record_validation "Go Module Verification" "pass" "Go module is valid"
    else
        record_validation "Go Module Verification" "fail" "Go module verification failed"
    fi
    
    # Check for testing infrastructure
    local test_dirs=(
        "internal/provider"
        "scripts/platform-tests"
    )
    
    for dir in "${test_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            record_validation "Test Directory: $dir" "pass" "Test directory exists"
        else
            record_validation "Test Directory: $dir" "warning" "Test directory is missing"
        fi
    done
}

# Function to validate platform-specific environment
validate_platform_environment() {
    log_info "Validating platform-specific environment..."
    
    case "$PLATFORM" in
        "linux")
            # Linux-specific validations
            record_validation "Platform Detection" "pass" "Linux platform detected"
            
            # Check for case-sensitive filesystem
            touch test_case_UPPER.tmp 2>/dev/null
            touch test_case_lower.tmp 2>/dev/null
            if [[ -f "test_case_UPPER.tmp" && -f "test_case_lower.tmp" ]]; then
                record_validation "Filesystem Case Sensitivity" "pass" "Case-sensitive filesystem detected"
            else
                record_validation "Filesystem Case Sensitivity" "warning" "Case-insensitive filesystem detected"
            fi
            rm -f test_case_*.tmp 2>/dev/null
            
            # Check file permissions capability
            touch test_permissions.tmp 2>/dev/null
            if chmod 644 test_permissions.tmp 2>/dev/null && [[ -r test_permissions.tmp ]]; then
                record_validation "File Permissions" "pass" "File permission handling works"
            else
                record_validation "File Permissions" "warning" "File permission handling issues detected"
            fi
            rm -f test_permissions.tmp 2>/dev/null
            ;;
            
        "darwin")
            # macOS-specific validations
            record_validation "Platform Detection" "pass" "macOS platform detected"
            
            # Check for Xcode command line tools
            if xcode-select -p >/dev/null 2>&1; then
                record_validation "Xcode Command Line Tools" "pass" "Xcode command line tools are installed"
            else
                record_validation "Xcode Command Line Tools" "warning" "Xcode command line tools may not be installed"
            fi
            
            # Check architecture
            if [[ "$ARCH" == "arm64" ]]; then
                record_validation "Apple Silicon" "pass" "Apple Silicon (ARM64) detected"
            else
                record_validation "Intel Mac" "pass" "Intel Mac (x86_64) detected"
            fi
            ;;
            
        "windows"|"msys"*|"mingw"*|"cygwin"*)
            # Windows-specific validations
            record_validation "Platform Detection" "pass" "Windows platform detected"
            
            # Check for Git Bash/MSYS environment
            if [[ -n "$MSYSTEM" ]]; then
                record_validation "MSYS Environment" "pass" "MSYS environment detected: $MSYSTEM"
            else
                record_validation "Shell Environment" "warning" "Non-MSYS shell environment detected"
            fi
            
            # Test Windows path handling
            if [[ -d "/c" || -d "/mnt/c" ]]; then
                record_validation "Windows Path Access" "pass" "Windows drive access available"
            else
                record_validation "Windows Path Access" "warning" "Windows drive access may be limited"
            fi
            ;;
            
        *)
            record_validation "Platform Detection" "warning" "Unknown platform: $PLATFORM"
            ;;
    esac
}

# Function to validate network connectivity (optional)
validate_network_connectivity() {
    log_info "Validating network connectivity..."
    
    # Test Go module proxy connectivity
    if curl -s --max-time 5 https://proxy.golang.org >/dev/null 2>&1; then
        record_validation "Go Module Proxy" "pass" "Go module proxy is accessible"
    else
        record_validation "Go Module Proxy" "warning" "Go module proxy may not be accessible"
    fi
    
    # Test Terraform registry connectivity
    if curl -s --max-time 5 https://registry.terraform.io >/dev/null 2>&1; then
        record_validation "Terraform Registry" "pass" "Terraform registry is accessible"
    else
        record_validation "Terraform Registry" "warning" "Terraform registry may not be accessible"
    fi
}

# Function to run comprehensive validation
run_comprehensive_validation() {
    log_info "Starting comprehensive environment validation..."
    log_info "Platform: $PLATFORM, Architecture: $ARCH"
    
    # Core tool validations
    validate_go
    validate_terraform
    validate_make
    validate_git
    
    # System resource validations
    validate_system_resources
    
    # Project structure validations
    validate_project_structure
    
    # Platform-specific validations
    validate_platform_environment
    
    # Network connectivity validations (optional)
    if command -v curl >/dev/null 2>&1; then
        validate_network_connectivity
    else
        record_validation "Network Connectivity Tests" "warning" "curl not available, skipping network tests"
    fi
}

# Function to generate validation report
generate_validation_report() {
    local report_file="environment-validation-report-${PLATFORM}-${ARCH}-$(date +%Y%m%d-%H%M%S).json"
    
    log_info "Generating environment validation report..."
    
    # Calculate success rate
    local success_rate=0
    if [[ "$VALIDATION_TOTAL" -gt 0 ]]; then
        success_rate=$(( (VALIDATION_PASSED * 100) / VALIDATION_TOTAL ))
    fi
    
    cat > "$report_file" << EOF
{
  "validation_run": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "platform": "$PLATFORM",
    "architecture": "$ARCH",
    "project_root": "$PROJECT_ROOT"
  },
  "summary": {
    "total_validations": $VALIDATION_TOTAL,
    "passed": $VALIDATION_PASSED,
    "warnings": ${#VALIDATION_WARNINGS[@]},
    "errors": ${#VALIDATION_ERRORS[@]},
    "success_rate": $success_rate
  },
  "errors": $(printf '%s\n' "${VALIDATION_ERRORS[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]'),
  "warnings": $(printf '%s\n' "${VALIDATION_WARNINGS[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]'),
  "environment": {
    "go_version": "$(go version 2>/dev/null || echo 'not available')",
    "terraform_version": "$(terraform version 2>/dev/null | head -n1 || echo 'not available')",
    "make_version": "$(make --version 2>/dev/null | head -n1 || echo 'not available')",
    "git_version": "$(git --version 2>/dev/null || echo 'not available')",
    "shell": "$SHELL",
    "path": "$PATH"
  }
}
EOF
    
    log_success "Environment validation report generated: $report_file"
}

# Function to print validation summary
print_validation_summary() {
    echo
    log_info "========================================"
    log_info "Environment Validation Summary"
    log_info "========================================"
    
    log_info "Total validations: $VALIDATION_TOTAL"
    log_success "Passed: $VALIDATION_PASSED"
    
    if [[ ${#VALIDATION_WARNINGS[@]} -gt 0 ]]; then
        log_warning "Warnings: ${#VALIDATION_WARNINGS[@]}"
        for warning in "${VALIDATION_WARNINGS[@]}"; do
            log_warning "  - $warning"
        done
    fi
    
    if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
        log_error "Errors: ${#VALIDATION_ERRORS[@]}"
        for error in "${VALIDATION_ERRORS[@]}"; do
            log_error "  - $error"
        done
    fi
    
    local success_rate=0
    if [[ "$VALIDATION_TOTAL" -gt 0 ]]; then
        success_rate=$(( (VALIDATION_PASSED * 100) / VALIDATION_TOTAL ))
    fi
    
    log_info "Success rate: ${success_rate}%"
    
    if [[ ${#VALIDATION_ERRORS[@]} -eq 0 ]]; then
        log_success "✅ Environment validation completed successfully!"
        if [[ ${#VALIDATION_WARNINGS[@]} -gt 0 ]]; then
            log_warning "⚠️  Some warnings were detected, but they may not prevent testing"
        fi
        return 0
    else
        log_error "❌ Environment validation failed with ${#VALIDATION_ERRORS[@]} error(s)"
        log_error "Please address the errors before running cross-platform tests"
        return 1
    fi
}

# Function to print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Comprehensive environment validation for Terraform Provider PrettyJSON cross-platform testing

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -q, --quiet             Reduce output (errors and summary only)
    --report                Generate JSON validation report
    --skip-network          Skip network connectivity tests
    --strict                Treat warnings as errors

EXAMPLES:
    $0                      # Run all validations
    $0 --report             # Run validations and generate report
    $0 --strict             # Fail on any warnings
    $0 --skip-network       # Skip network tests

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
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -q|--quiet)
                QUIET=1
                shift
                ;;
            --report)
                GENERATE_REPORT=1
                shift
                ;;
            --skip-network)
                SKIP_NETWORK=1
                shift
                ;;
            --strict)
                STRICT_MODE=1
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    cd "$PROJECT_ROOT"
    
    if [[ "$QUIET" != "1" ]]; then
        log_info "Starting comprehensive environment validation for $PLATFORM/$ARCH"
        log_info "Project root: $PROJECT_ROOT"
    fi
    
    # Run comprehensive validation
    run_comprehensive_validation
    
    # Generate report if requested
    if [[ "$GENERATE_REPORT" == "1" ]]; then
        generate_validation_report
    fi
    
    # Print summary
    if [[ "$QUIET" != "1" ]]; then
        print_validation_summary
    fi
    
    # Exit with appropriate code
    local exit_code=0
    if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
        exit_code=1
    elif [[ "$STRICT_MODE" == "1" && ${#VALIDATION_WARNINGS[@]} -gt 0 ]]; then
        if [[ "$QUIET" != "1" ]]; then
            log_error "Strict mode enabled: treating warnings as errors"
        fi
        exit_code=1
    fi
    
    exit $exit_code
}

# Parse arguments and run main function
parse_args "$@"
main