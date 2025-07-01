#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


# Automated test execution pipeline with HashiCorp-style reporting
# This script implements comprehensive test automation with retry mechanisms,
# parallel execution, and structured reporting following HashiCorp patterns

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
DEFAULT_TEST_SUITES=("unit" "acceptance" "function" "integration")
DEFAULT_PARALLEL_JOBS=4
DEFAULT_RETRY_COUNT=3
DEFAULT_RETRY_DELAY=5
DEFAULT_TIMEOUT="30m"
TEST_REPORT_DIR="test-reports"
ARTIFACT_DIR="test-artifacts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions with structured output
log_info() {
    local msg="${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "$msg"
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "$msg" >> "$LOG_FILE"
    fi
}

log_success() {
    local msg="${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "$msg"
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "$msg" >> "$LOG_FILE"
    fi
}

log_warning() {
    local msg="${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "$msg"
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "$msg" >> "$LOG_FILE"
    fi
}

log_error() {
    local msg="${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "$msg"
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "$msg" >> "$LOG_FILE"
    fi
}

log_debug() {
    if [[ "$VERBOSE" == "1" ]]; then
        local msg="${PURPLE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
        echo -e "$msg"
        if [[ -n "$LOG_FILE" ]]; then
            echo -e "$msg" >> "$LOG_FILE"
        fi
    fi
}

log_step() {
    local msg="${CYAN}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "$msg"
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "$msg" >> "$LOG_FILE"
    fi
}

# Function to print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Automated test execution pipeline with HashiCorp-style reporting

OPTIONS:
    -h, --help                Show this help message
    -s, --suites SUITES       Comma-separated test suites (default: unit,acceptance,function,integration)
    -j, --parallel JOBS       Number of parallel jobs (default: 4)
    -r, --retry COUNT         Retry count for failed tests (default: 3)
    -d, --retry-delay SECONDS Delay between retries (default: 5)
    -t, --timeout DURATION    Test timeout (default: 30m)
    --tf-versions VERSIONS    Terraform versions to test (default: auto-detect)
    --platforms PLATFORMS     Platforms to test (default: current)
    --fail-fast               Stop on first failure
    --no-parallel             Disable parallel execution
    --no-retry                Disable retry mechanisms
    --dry-run                 Show what would be executed without running
    --verbose                 Enable verbose output
    --generate-report         Generate comprehensive test report
    --output-format FORMAT    Report format: json, junit, github (default: all)
    --upload-artifacts        Upload test artifacts
    --slack-webhook URL       Slack webhook for notifications
    --performance-optimization Enable performance optimization features
    --no-fail-fast            Disable fail-fast behavior

TEST SUITES:
    unit            Unit tests using go test
    acceptance      Terraform acceptance tests (TF_ACC=1)
    function        Provider function specific tests
    integration     End-to-end integration tests
    version         Terraform version compatibility tests
    platform        Cross-platform compatibility tests
    performance     Performance and benchmark tests

EXAMPLES:
    $0                                           # Run all default test suites
    $0 -s "unit,acceptance" --parallel 2        # Run specific suites with 2 parallel jobs
    $0 --tf-versions "1.8.0,1.9.8,latest"     # Test specific Terraform versions
    $0 --platforms "linux,windows,macos"       # Test specific platforms
    $0 --fail-fast --generate-report           # Stop on failure and generate report
    $0 --dry-run --verbose                     # Preview execution plan

EOF
}

# Function to create structured test report
create_test_report() {
    local suite_name="$1"
    local status="$2"
    local start_time="$3"
    local end_time="$4"
    local test_output="$5"
    local error_details="$6"
    
    local duration=$((end_time - start_time))
    local report_file="${TEST_REPORT_DIR}/${suite_name}-test-report.json"
    
    # Ensure report directory exists
    mkdir -p "$TEST_REPORT_DIR"
    
    # Extract test statistics from output
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local skipped_tests=0
    
    if [[ -n "$test_output" ]]; then
        # Parse Go test output for statistics
        total_tests=$(echo "$test_output" | grep -E "^(PASS|FAIL|SKIP)" | wc -l 2>/dev/null)
        passed_tests=$(echo "$test_output" | grep -c "^PASS" 2>/dev/null)
        failed_tests=$(echo "$test_output" | grep -c "^FAIL" 2>/dev/null)
        skipped_tests=$(echo "$test_output" | grep -c "^SKIP" 2>/dev/null)
        
        # Ensure we have valid numbers
        total_tests=${total_tests:-0}
        passed_tests=${passed_tests:-0}
        failed_tests=${failed_tests:-0}
        skipped_tests=${skipped_tests:-0}
    fi
    
    # Create comprehensive test report
    cat > "$report_file" << EOF
{
  "test_suite": "$suite_name",
  "status": "$status",
  "execution": {
    "start_time": "$start_time",
    "end_time": "$end_time",
    "duration_seconds": $duration,
    "duration_human": "$(printf '%dm %ds' $((duration/60)) $((duration%60)))"
  },
  "statistics": {
    "total_tests": $total_tests,
    "passed_tests": $passed_tests,
    "failed_tests": $failed_tests,
    "skipped_tests": $skipped_tests,
    "success_rate": $(( total_tests > 0 ? (passed_tests * 100) / total_tests : 0 ))
  },
  "environment": {
    "go_version": "$(go version 2>/dev/null || echo 'unknown')",
    "terraform_version": "$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo 'unknown')",
    "platform": "$(uname -s | tr '[:upper:]' '[:lower:]')",
    "architecture": "$(uname -m)",
    "hostname": "$(hostname)",
    "user": "$(whoami)",
    "pwd": "$(pwd)"
  },
  "configuration": {
    "parallel_jobs": $PARALLEL_JOBS,
    "retry_count": $RETRY_COUNT,
    "retry_delay": $RETRY_DELAY,
    "timeout": "$TIMEOUT",
    "fail_fast": $FAIL_FAST,
    "verbose": $VERBOSE
  },
  "output": {
    "stdout_lines": $(echo "$test_output" | wc -l),
    "stderr_present": $([ -n "$error_details" ] && echo "true" || echo "false")
  }
}
EOF
    
    # Save detailed output if available
    if [[ -n "$test_output" ]]; then
        echo "$test_output" > "${TEST_REPORT_DIR}/${suite_name}-output.log"
    fi
    
    if [[ -n "$error_details" ]]; then
        echo "$error_details" > "${TEST_REPORT_DIR}/${suite_name}-errors.log"
    fi
    
    log_debug "Test report created: $report_file"
}

# Function to run a single test suite with retry logic
run_test_suite() {
    local suite_name="$1"
    local test_command="$2"
    local max_retries="$RETRY_COUNT"
    local retry_delay="$RETRY_DELAY"
    
    log_step "Running test suite: $suite_name"
    
    local attempt=1
    local success=false
    local start_time=$(date +%s)
    local test_output=""
    local error_details=""
    
    while [[ $attempt -le $((max_retries + 1)) ]]; do
        if [[ $attempt -gt 1 ]]; then
            log_info "Retry attempt $((attempt - 1))/$max_retries for $suite_name after ${retry_delay}s delay"
            sleep "$retry_delay"
        fi
        
        log_debug "Executing: $test_command"
        
        # Run test with timeout and capture output  
        local cmd_start=$(date +%s)
        # Use a shorter timeout for individual test attempts (max 10 minutes per attempt)
        local test_timeout="10m"
        if [[ "$TIMEOUT" =~ ^[0-9]+m$ ]] && [[ ${TIMEOUT%m} -lt 10 ]]; then
            test_timeout="$TIMEOUT"
        fi
        
        if timeout "$test_timeout" bash -c "$test_command" > "${TEST_REPORT_DIR}/${suite_name}-attempt-${attempt}.log" 2>&1; then
            success=true
            test_output=$(cat "${TEST_REPORT_DIR}/${suite_name}-attempt-${attempt}.log")
            log_success "Test suite $suite_name passed on attempt $attempt"
            break
        else
            local exit_code=$?
            error_details=$(cat "${TEST_REPORT_DIR}/${suite_name}-attempt-${attempt}.log")
            test_output="$error_details"
            
            if [[ $exit_code -eq 124 ]]; then
                log_error "Test suite $suite_name timed out on attempt $attempt (timeout: $test_timeout)"
            else
                log_error "Test suite $suite_name failed on attempt $attempt (exit code: $exit_code)"
            fi
            
            if [[ "$NO_RETRY" == "1" ]] || [[ $attempt -eq $((max_retries + 1)) ]]; then
                break
            fi
        fi
        
        ((attempt++))
    done
    
    local end_time=$(date +%s)
    local status=$([ "$success" = true ] && echo "success" || echo "failure")
    
    # Create test report
    create_test_report "$suite_name" "$status" "$start_time" "$end_time" "$test_output" "$error_details"
    
    # Update global counters
    if [[ "$success" == "true" ]]; then
        ((TOTAL_PASSED++))
    else
        ((TOTAL_FAILED++))
        FAILED_SUITES+=("$suite_name")
        
        if [[ "$FAIL_FAST" == "1" ]]; then
            log_error "Fail-fast enabled, stopping execution due to $suite_name failure"
            return 1
        fi
    fi
    
    return $([ "$success" = true ] && echo 0 || echo 1)
}

# Function to run test suites in parallel
run_parallel_tests() {
    local suites=("$@")
    local pids=()
    
    log_step "Running ${#suites[@]} test suites in parallel (max jobs: $PARALLEL_JOBS)"
    
    # Define test commands for each suite
    declare -A test_commands=(
        ["unit"]="cd '$PROJECT_ROOT' && go test -v -timeout=$TIMEOUT ./internal/provider/ -count=1"
        ["acceptance"]="cd '$PROJECT_ROOT' && TF_ACC=1 go test -v -timeout=$TIMEOUT ./internal/provider/ -count=1"
        ["function"]="cd '$PROJECT_ROOT' && TF_ACC=1 go test -v -timeout=$TIMEOUT -run 'TestJsonPrettyPrintFunction' ./internal/provider/ -count=1"
        ["integration"]="cd '$PROJECT_ROOT' && TF_ACC=1 go test -v -timeout=$TIMEOUT -run 'TestTerraform.*Compatibility' ./internal/provider/ -count=1"
        ["version"]="cd '$PROJECT_ROOT' && ./scripts/platform-tests/terraform-version-tests.sh -m standard"
        ["platform"]="cd '$PROJECT_ROOT' && ./scripts/platform-tests/run-platform-tests.sh --unit-only"
        ["performance"]="cd '$PROJECT_ROOT' && go test -v -timeout=$TIMEOUT -run 'TestTerraformVersionPerformance' ./internal/provider/ -count=1"
    )
    
    # Start all jobs
    for suite in "${suites[@]}"; do
        local command="${test_commands[$suite]}"
        
        if [[ -z "$command" ]]; then
            log_warning "Unknown test suite: $suite, skipping"
            continue
        fi
        
        log_debug "Starting parallel job for suite: $suite"
        
        # Run test suite in background
        (run_test_suite "$suite" "$command") &
        pids+=($!)
    done
    
    # Wait for all jobs to complete
    log_debug "Waiting for ${#pids[@]} background jobs to complete: PIDs=(${pids[*]})"
    
    local parallel_success_count=0
    local parallel_failed_count=0
    
    for pid in "${pids[@]}"; do
        if wait "$pid"; then
            log_debug "Job completed successfully (PID: $pid)"
            ((parallel_success_count++))
        else
            log_debug "Job completed with error (PID: $pid)"
            ((parallel_failed_count++))
        fi
    done
    
    # Update global counters (approximate since we can't get exact suite names from PIDs)
    TOTAL_PASSED=$((TOTAL_PASSED + parallel_success_count))
    TOTAL_FAILED=$((TOTAL_FAILED + parallel_failed_count))
    
    log_success "All parallel test suites completed: $parallel_success_count passed, $parallel_failed_count failed"
}

# Function to run test suites sequentially
run_sequential_tests() {
    local suites=("$@")
    
    log_step "Running ${#suites[@]} test suites sequentially"
    
    for suite in "${suites[@]}"; do
        case "$suite" in
            "unit")
                run_test_suite "$suite" "cd '$PROJECT_ROOT' && go test -v -timeout=$TIMEOUT ./internal/provider/ -count=1" || return 1
                ;;
            "acceptance")
                run_test_suite "$suite" "cd '$PROJECT_ROOT' && TF_ACC=1 go test -v -timeout=$TIMEOUT ./internal/provider/ -count=1" || return 1
                ;;
            "function")
                run_test_suite "$suite" "cd '$PROJECT_ROOT' && TF_ACC=1 go test -v -timeout=$TIMEOUT -run 'TestJsonPrettyPrintFunction' ./internal/provider/ -count=1" || return 1
                ;;
            "integration")
                run_test_suite "$suite" "cd '$PROJECT_ROOT' && TF_ACC=1 go test -v -timeout=$TIMEOUT -run 'TestTerraform.*Compatibility' ./internal/provider/ -count=1" || return 1
                ;;
            "version")
                run_test_suite "$suite" "cd '$PROJECT_ROOT' && ./scripts/platform-tests/terraform-version-tests.sh -m standard" || return 1
                ;;
            "platform")
                run_test_suite "$suite" "cd '$PROJECT_ROOT' && ./scripts/platform-tests/run-platform-tests.sh --unit-only" || return 1
                ;;
            "performance")
                run_test_suite "$suite" "cd '$PROJECT_ROOT' && go test -v -timeout=$TIMEOUT -run 'TestTerraformVersionPerformance' ./internal/provider/ -count=1" || return 1
                ;;
            *)
                log_warning "Unknown test suite: $suite, skipping"
                ;;
        esac
    done
}

# Function to generate comprehensive test report
generate_comprehensive_report() {
    local execution_end_time=$(date +%s)
    local total_duration=$((execution_end_time - EXECUTION_START_TIME))
    
    log_step "Generating comprehensive test report"
    
    # Create summary report
    local summary_file="${TEST_REPORT_DIR}/test-execution-summary.json"
    
    cat > "$summary_file" << EOF
{
  "execution_summary": {
    "start_time": "$EXECUTION_START_TIME",
    "end_time": "$execution_end_time",
    "total_duration_seconds": $total_duration,
    "total_duration_human": "$(printf '%dm %ds' $((total_duration/60)) $((total_duration%60)))"
  },
  "test_results": {
    "total_suites": ${#TEST_SUITES[@]},
    "passed_suites": $TOTAL_PASSED,
    "failed_suites": $TOTAL_FAILED,
    "success_rate": $(( ${#TEST_SUITES[@]} > 0 ? (TOTAL_PASSED * 100) / ${#TEST_SUITES[@]} : 0 )),
    "failed_suite_names": [$(printf '"%s",' "${FAILED_SUITES[@]}" | sed 's/,$//')]
  },
  "configuration": {
    "test_suites": [$(printf '"%s",' "${TEST_SUITES[@]}" | sed 's/,$//')]
  }
}
EOF
    
    # Generate output in requested formats
    if [[ "$OUTPUT_FORMAT" == *"github"* ]] || [[ "$OUTPUT_FORMAT" == "all" ]]; then
        generate_github_report
    fi
    
    if [[ "$OUTPUT_FORMAT" == *"junit"* ]] || [[ "$OUTPUT_FORMAT" == "all" ]]; then
        generate_junit_report
    fi
    
    log_success "Comprehensive test report generated in $TEST_REPORT_DIR"
}

# Function to generate GitHub Actions summary report
generate_github_report() {
    local github_report="${TEST_REPORT_DIR}/github-summary.md"
    
    cat > "$github_report" << EOF
# Automated Test Execution Report

## Summary

- **Total Suites**: ${#TEST_SUITES[@]}
- **Passed**: $TOTAL_PASSED ✅
- **Failed**: $TOTAL_FAILED $([ $TOTAL_FAILED -gt 0 ] && echo "❌" || echo "✅")
- **Success Rate**: $(( ${#TEST_SUITES[@]} > 0 ? (TOTAL_PASSED * 100) / ${#TEST_SUITES[@]} : 0 ))%
- **Total Duration**: $(printf '%dm %ds' $((($(date +%s) - EXECUTION_START_TIME)/60)) $((($(date +%s) - EXECUTION_START_TIME)%60)))

## Test Suite Results

| Suite | Status | Duration | Attempts |
|-------|--------|----------|----------|
EOF
    
    # Add individual suite results
    for suite in "${TEST_SUITES[@]}"; do
        local report_file="${TEST_REPORT_DIR}/${suite}-test-report.json"
        if [[ -f "$report_file" ]]; then
            local status=$(jq -r '.status' "$report_file" 2>/dev/null || echo "unknown")
            local duration=$(jq -r '.execution.duration_human' "$report_file" 2>/dev/null || echo "unknown")
            local attempts=$(ls "${TEST_REPORT_DIR}/${suite}-attempt-"*.log 2>/dev/null | wc -l || echo "1")
            local status_icon=$([ "$status" = "success" ] && echo "✅" || echo "❌")
            
            echo "| $suite | $status_icon $status | $duration | $attempts |" >> "$github_report"
        else
            echo "| $suite | ❓ no_report | - | - |" >> "$github_report"
        fi
    done
    
    if [[ $TOTAL_FAILED -gt 0 ]]; then
        cat >> "$github_report" << EOF

## Failed Suites

$(printf '- %s\n' "${FAILED_SUITES[@]}")

## Recommendations

- Review individual test logs in the test reports
- Check environment setup for failed test suites
- Consider running failed tests individually for debugging
EOF
    fi
    
    # Add to GitHub step summary if running in GitHub Actions
    if [[ -n "$GITHUB_STEP_SUMMARY" ]]; then
        cat "$github_report" >> "$GITHUB_STEP_SUMMARY"
    fi
}

# Function to generate JUnit XML report
generate_junit_report() {
    local junit_file="${TEST_REPORT_DIR}/junit-report.xml"
    local total_tests=0
    local total_failures=0
    local total_time=0
    
    # Calculate totals from individual reports
    for suite in "${TEST_SUITES[@]}"; do
        local report_file="${TEST_REPORT_DIR}/${suite}-test-report.json"
        if [[ -f "$report_file" ]]; then
            local suite_tests=$(jq -r '.statistics.total_tests' "$report_file" 2>/dev/null || echo "0")
            local suite_failures=$(jq -r '.statistics.failed_tests' "$report_file" 2>/dev/null || echo "0")
            local suite_time=$(jq -r '.execution.duration_seconds' "$report_file" 2>/dev/null || echo "0")
            
            total_tests=$((total_tests + suite_tests))
            total_failures=$((total_failures + suite_failures))
            total_time=$((total_time + suite_time))
        fi
    done
    
    cat > "$junit_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="terraform-provider-prettyjson" tests="$total_tests" failures="$total_failures" time="$total_time">
EOF
    
    # Add individual test suites
    for suite in "${TEST_SUITES[@]}"; do
        local report_file="${TEST_REPORT_DIR}/${suite}-test-report.json"
        if [[ -f "$report_file" ]]; then
            local suite_tests=$(jq -r '.statistics.total_tests' "$report_file" 2>/dev/null || echo "1")
            local suite_failures=$(jq -r '.statistics.failed_tests' "$report_file" 2>/dev/null || echo "0")
            local suite_time=$(jq -r '.execution.duration_seconds' "$report_file" 2>/dev/null || echo "0")
            local status=$(jq -r '.status' "$report_file" 2>/dev/null || echo "failure")
            
            cat >> "$junit_file" << EOF
  <testsuite name="$suite" tests="$suite_tests" failures="$suite_failures" time="$suite_time">
EOF
            
            if [[ "$status" == "failure" ]]; then
                cat >> "$junit_file" << EOF
    <testcase name="$suite" time="$suite_time">
      <failure message="Test suite failed">See detailed logs for failure information</failure>
    </testcase>
EOF
            else
                cat >> "$junit_file" << EOF
    <testcase name="$suite" time="$suite_time"/>
EOF
            fi
            
            cat >> "$junit_file" << EOF
  </testsuite>
EOF
        fi
    done
    
    cat >> "$junit_file" << EOF
</testsuites>
EOF
}

# Function to send Slack notification
send_slack_notification() {
    if [[ -z "$SLACK_WEBHOOK" ]]; then
        return 0
    fi
    
    local success_rate=$(( ${#TEST_SUITES[@]} > 0 ? (TOTAL_PASSED * 100) / ${#TEST_SUITES[@]} : 0 ))
    local color=$([ $TOTAL_FAILED -eq 0 ] && echo "good" || echo "danger")
    local icon=$([ $TOTAL_FAILED -eq 0 ] && echo ":white_check_mark:" || echo ":x:")
    
    local payload=$(cat << EOF
{
  "attachments": [
    {
      "color": "$color",
      "title": "$icon Terraform Provider Test Results",
      "fields": [
        {
          "title": "Success Rate",
          "value": "${success_rate}%",
          "short": true
        },
        {
          "title": "Total Suites",
          "value": "${#TEST_SUITES[@]}",
          "short": true
        },
        {
          "title": "Passed",
          "value": "$TOTAL_PASSED",
          "short": true
        },
        {
          "title": "Failed",
          "value": "$TOTAL_FAILED",
          "short": true
        }
      ],
      "footer": "Terraform Provider prettyjson",
      "ts": $(date +%s)
    }
  ]
}
EOF
)
    
    curl -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK" &>/dev/null || \
        log_warning "Failed to send Slack notification"
}

# Function to upload test artifacts
upload_artifacts() {
    if [[ "$UPLOAD_ARTIFACTS" != "1" ]]; then
        return 0
    fi
    
    log_step "Uploading test artifacts"
    
    # Create artifact archive
    local artifact_archive="${ARTIFACT_DIR}/test-results-$(date +%Y%m%d-%H%M%S).tar.gz"
    mkdir -p "$ARTIFACT_DIR"
    
    tar -czf "$artifact_archive" -C "$TEST_REPORT_DIR" . 2>/dev/null || \
        log_warning "Failed to create artifact archive"
    
    log_success "Test artifacts archived: $artifact_archive"
    
    # In a real CI environment, this would upload to cloud storage
    # For now, we just log the location
    log_info "Artifacts ready for upload at: $artifact_archive"
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -s|--suites)
                IFS=',' read -ra TEST_SUITES <<< "$2"
                shift 2
                ;;
            -j|--parallel)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            -r|--retry)
                RETRY_COUNT="$2"
                shift 2
                ;;
            -d|--retry-delay)
                RETRY_DELAY="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --tf-versions)
                TF_VERSIONS="$2"
                shift 2
                ;;
            --platforms)
                PLATFORMS="$2"
                shift 2
                ;;
            --fail-fast)
                FAIL_FAST=1
                shift
                ;;
            --no-parallel)
                NO_PARALLEL=1
                shift
                ;;
            --no-retry)
                NO_RETRY=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
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
            --output-format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --upload-artifacts)
                UPLOAD_ARTIFACTS=1
                shift
                ;;
            --slack-webhook)
                SLACK_WEBHOOK="$2"
                shift 2
                ;;
            --performance-optimization)
                PERFORMANCE_OPTIMIZATION=1
                shift
                ;;
            --no-fail-fast)
                FAIL_FAST=0
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
    TEST_SUITES=${TEST_SUITES:-"${DEFAULT_TEST_SUITES[@]}"}
    PARALLEL_JOBS=${PARALLEL_JOBS:-$DEFAULT_PARALLEL_JOBS}
    RETRY_COUNT=${RETRY_COUNT:-$DEFAULT_RETRY_COUNT}
    RETRY_DELAY=${RETRY_DELAY:-$DEFAULT_RETRY_DELAY}
    TIMEOUT=${TIMEOUT:-$DEFAULT_TIMEOUT}
    FAIL_FAST=${FAIL_FAST:-0}
    NO_PARALLEL=${NO_PARALLEL:-0}
    NO_RETRY=${NO_RETRY:-0}
    DRY_RUN=${DRY_RUN:-0}
    VERBOSE=${VERBOSE:-0}
    GENERATE_REPORT=${GENERATE_REPORT:-1}
    OUTPUT_FORMAT=${OUTPUT_FORMAT:-"all"}
    UPLOAD_ARTIFACTS=${UPLOAD_ARTIFACTS:-0}
    PERFORMANCE_OPTIMIZATION=${PERFORMANCE_OPTIMIZATION:-0}
}

# Function to validate environment
validate_environment() {
    log_step "Validating test environment"
    
    # Check required tools
    local required_tools=("go" "terraform" "jq")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "Required tool not found: $tool"
            return 1
        fi
    done
    
    # Check Go version
    local go_version=$(go version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    log_info "Go version: $go_version"
    
    # Check Terraform version
    local tf_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo 'unknown')
    log_info "Terraform version: $tf_version"
    
    # Validate project structure
    if [[ ! -f "$PROJECT_ROOT/go.mod" ]]; then
        log_error "go.mod not found in project root"
        return 1
    fi
    
    if [[ ! -d "$PROJECT_ROOT/internal/provider" ]]; then
        log_error "Provider source directory not found"
        return 1
    fi
    
    log_success "Environment validation passed"
}

# Function to show dry run information
show_dry_run() {
    log_info "DRY RUN MODE - Commands that would be executed:"
    echo
    echo "Configuration:"
    echo "  Test Suites: ${TEST_SUITES[*]}"
    echo "  Parallel Jobs: $PARALLEL_JOBS"
    echo "  Retry Count: $RETRY_COUNT"
    echo "  Retry Delay: ${RETRY_DELAY}s"
    echo "  Timeout: $TIMEOUT"
    echo "  Fail Fast: $([ $FAIL_FAST -eq 1 ] && echo 'enabled' || echo 'disabled')"
    echo "  Parallel: $([ $NO_PARALLEL -eq 1 ] && echo 'disabled' || echo 'enabled')"
    echo "  Retry: $([ $NO_RETRY -eq 1 ] && echo 'disabled' || echo 'enabled')"
    echo
    echo "Test Commands:"
    for suite in "${TEST_SUITES[@]}"; do
        case "$suite" in
            "unit")
                echo "  $suite: go test -v -timeout=$TIMEOUT ./internal/provider/ -count=1"
                ;;
            "acceptance")
                echo "  $suite: TF_ACC=1 go test -v -timeout=$TIMEOUT ./internal/provider/ -count=1"
                ;;
            "function")
                echo "  $suite: TF_ACC=1 go test -v -timeout=$TIMEOUT -run 'TestJsonPrettyPrintFunction' ./internal/provider/ -count=1"
                ;;
            "integration")
                echo "  $suite: TF_ACC=1 go test -v -timeout=$TIMEOUT -run 'TestTerraform.*Compatibility' ./internal/provider/ -count=1"
                ;;
            "version")
                echo "  $suite: ./scripts/platform-tests/terraform-version-tests.sh -m standard"
                ;;
            "platform")
                echo "  $suite: ./scripts/platform-tests/run-platform-tests.sh --unit-only"
                ;;
            "performance")
                echo "  $suite: go test -v -timeout=$TIMEOUT -run 'TestTerraformVersionPerformance' ./internal/provider/ -count=1"
                ;;
        esac
    done
    echo
}

# Main function
main() {
    # Initialize global variables
    EXECUTION_START_TIME=$(date +%s)
    TOTAL_PASSED=0
    TOTAL_FAILED=0
    FAILED_SUITES=()
    LOG_FILE="${TEST_REPORT_DIR}/execution.log"
    
    # Create directories
    mkdir -p "$TEST_REPORT_DIR" "$ARTIFACT_DIR"
    
    # Initialize log file
    echo "Automated Test Execution Started: $(date)" > "$LOG_FILE"
    
    cd "$PROJECT_ROOT"
    
    log_info "Starting automated test execution pipeline"
    log_info "Project root: $PROJECT_ROOT"
    log_info "Test suites: ${TEST_SUITES[*]}"
    log_info "Configuration: parallel=$PARALLEL_JOBS, retry=$RETRY_COUNT, timeout=$TIMEOUT"
    
    # Validate environment
    if ! validate_environment; then
        log_error "Environment validation failed"
        exit 1
    fi
    
    # Show dry run information if requested
    if [[ "$DRY_RUN" == "1" ]]; then
        show_dry_run
        exit 0
    fi
    
    # Prepare Go modules
    log_step "Preparing Go modules"
    go mod download || {
        log_error "Failed to download Go modules"
        exit 1
    }
    
    go mod verify || {
        log_error "Failed to verify Go modules"
        exit 1
    }
    
    # Build provider
    log_step "Building provider"
    go build -v . || {
        log_error "Failed to build provider"
        exit 1
    }
    
    # Run test suites
    if [[ "$NO_PARALLEL" == "1" ]]; then
        run_sequential_tests "${TEST_SUITES[@]}"
    else
        run_parallel_tests "${TEST_SUITES[@]}"
    fi
    
    # Generate comprehensive report
    if [[ "$GENERATE_REPORT" == "1" ]]; then
        generate_comprehensive_report
    fi
    
    # Upload artifacts
    upload_artifacts
    
    # Send notifications
    send_slack_notification
    
    # Final summary
    local execution_duration=$(( $(date +%s) - EXECUTION_START_TIME ))
    log_info "========================================================"
    log_info "Automated Test Execution Summary"
    log_info "========================================================"
    log_info "Total execution time: $(printf '%dm %ds' $((execution_duration/60)) $((execution_duration%60)))"
    log_info "Test suites run: ${#TEST_SUITES[@]}"
    log_success "Passed: $TOTAL_PASSED"
    
    if [[ $TOTAL_FAILED -gt 0 ]]; then
        log_error "Failed: $TOTAL_FAILED ($(printf '%s ' "${FAILED_SUITES[@]}"))"
        log_error "Check individual test reports in $TEST_REPORT_DIR for details"
        exit 1
    else
        log_success "All test suites passed successfully!"
        exit 0
    fi
}

# Initialize basic logging before parsing args
TEST_REPORT_DIR="test-reports"
ARTIFACT_DIR="test-artifacts"
mkdir -p "$TEST_REPORT_DIR" "$ARTIFACT_DIR"
LOG_FILE="${TEST_REPORT_DIR}/execution.log"

# Parse arguments and run
parse_args "$@"
main