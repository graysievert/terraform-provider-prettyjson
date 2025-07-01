#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


# HashiCorp-style test result aggregation and reporting system
# This script aggregates test results from multiple sources and generates
# comprehensive reports following HashiCorp patterns for CI/CD integration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
DEFAULT_REPORT_DIR="test-reports"
DEFAULT_OUTPUT_DIR="aggregated-reports"
DEFAULT_FORMATS=("json" "markdown" "junit" "github")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

# Function to print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

HashiCorp-style test result aggregation and reporting system

OPTIONS:
    -h, --help              Show this help message
    -i, --input-dir DIR     Input directory containing test reports (default: test-reports)
    -o, --output-dir DIR    Output directory for aggregated reports (default: aggregated-reports)
    -f, --formats FORMATS   Comma-separated output formats (default: json,markdown,junit,github)
    --include-logs          Include detailed test logs in reports
    --merge-coverage        Merge coverage reports if available
    --webhook-url URL       Webhook URL for notifications
    --slack-channel CHANNEL Slack channel for notifications
    --teams-webhook URL     Microsoft Teams webhook URL
    --email-recipients LIST Comma-separated email addresses for reports
    --threshold PERCENT     Success rate threshold for pass/fail (default: 80)
    --trend-analysis        Include trend analysis from historical data
    --performance-metrics   Include performance metrics analysis
    --verbose               Enable verbose output

SUPPORTED INPUT FORMATS:
    - Go test JSON output
    - JUnit XML reports
    - TAP (Test Anything Protocol)
    - Custom JSON test reports
    - Coverage reports (go cover format)
    - Benchmark results

OUTPUT FORMATS:
    json        Structured JSON report with full details
    markdown    Human-readable Markdown report
    junit       JUnit XML format for CI/CD integration
    github      GitHub Actions summary format
    slack       Slack-formatted message
    teams       Microsoft Teams card format
    html        Interactive HTML dashboard
    csv         CSV format for spreadsheet analysis

EXAMPLES:
    $0                                           # Aggregate with defaults
    $0 -f json,markdown --include-logs          # Generate specific formats with logs
    $0 --trend-analysis --performance-metrics   # Include advanced analytics
    $0 --webhook-url https://hooks.slack.com/... # Send to Slack
    $0 --threshold 95 --verbose                 # High threshold with verbose output

EOF
}

# Function to discover and parse test reports
discover_test_reports() {
    local input_dir="$1"
    local reports=()
    
    log_step "Discovering test reports in $input_dir"
    
    # Find JSON test reports
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            reports+=("$file")
            log_info "Found test report: $(basename "$file")"
        fi
    done < <(find "$input_dir" -name "*.json" -type f -print0 2>/dev/null)
    
    # Find JUnit XML reports
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            reports+=("$file")
            log_info "Found JUnit report: $(basename "$file")"
        fi
    done < <(find "$input_dir" -name "*.xml" -type f -print0 2>/dev/null)
    
    # Find log files
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            reports+=("$file")
            log_info "Found log file: $(basename "$file")"
        fi
    done < <(find "$input_dir" -name "*.log" -type f -print0 2>/dev/null)
    
    log_info "Discovered ${#reports[@]} test reports"
    printf '%s\n' "${reports[@]}"
}

# Function to parse individual test report
parse_test_report() {
    local report_file="$1"
    local file_extension="${report_file##*.}"
    local basename=$(basename "$report_file" ".$file_extension")
    
    case "$file_extension" in
        "json")
            parse_json_report "$report_file"
            ;;
        "xml")
            parse_junit_report "$report_file"
            ;;
        "log")
            parse_log_file "$report_file"
            ;;
        *)
            log_warning "Unknown report format: $file_extension for $report_file"
            ;;
    esac
}

# Function to parse JSON test report
parse_json_report() {
    local report_file="$1"
    
    if ! jq . "$report_file" >/dev/null 2>&1; then
        log_warning "Invalid JSON in $report_file, skipping"
        return 1
    fi
    
    # Extract key metrics
    local suite_name=$(jq -r '.test_suite // .name // "unknown"' "$report_file" 2>/dev/null)
    local status=$(jq -r '.status // "unknown"' "$report_file" 2>/dev/null)
    local total_tests=$(jq -r '.statistics.total_tests // .tests // 0' "$report_file" 2>/dev/null)
    local passed_tests=$(jq -r '.statistics.passed_tests // .passed // 0' "$report_file" 2>/dev/null)
    local failed_tests=$(jq -r '.statistics.failed_tests // .failed // 0' "$report_file" 2>/dev/null)
    local duration=$(jq -r '.execution.duration_seconds // .duration // 0' "$report_file" 2>/dev/null)
    
    # Store parsed data
    cat << EOF >> "$PARSED_DATA_FILE"
{
  "source_file": "$report_file",
  "suite_name": "$suite_name",
  "status": "$status",
  "total_tests": $total_tests,
  "passed_tests": $passed_tests,
  "failed_tests": $failed_tests,
  "skipped_tests": $(jq -r '.statistics.skipped_tests // .skipped // 0' "$report_file" 2>/dev/null),
  "duration_seconds": $duration,
  "success_rate": $(( total_tests > 0 ? (passed_tests * 100) / total_tests : 0 )),
  "environment": $(jq -c '.environment // {}' "$report_file" 2>/dev/null),
  "timestamp": "$(date -Iseconds)"
},
EOF
}

# Function to parse JUnit XML report
parse_junit_report() {
    local report_file="$1"
    
    # Extract data using xmllint or basic parsing
    if command -v xmllint >/dev/null 2>&1; then
        local total_tests=$(xmllint --xpath "string(/testsuites/@tests)" "$report_file" 2>/dev/null || echo "0")
        local failures=$(xmllint --xpath "string(/testsuites/@failures)" "$report_file" 2>/dev/null || echo "0")
        local errors=$(xmllint --xpath "string(/testsuites/@errors)" "$report_file" 2>/dev/null || echo "0")
        local time=$(xmllint --xpath "string(/testsuites/@time)" "$report_file" 2>/dev/null || echo "0")
    else
        # Fallback to grep/sed parsing
        local total_tests=$(grep -o 'tests="[0-9]*"' "$report_file" | head -1 | sed 's/tests="\([0-9]*\)"/\1/' || echo "0")
        local failures=$(grep -o 'failures="[0-9]*"' "$report_file" | head -1 | sed 's/failures="\([0-9]*\)"/\1/' || echo "0")
        local errors=$(grep -o 'errors="[0-9]*"' "$report_file" | head -1 | sed 's/errors="\([0-9]*\)"/\1/' || echo "0")
        local time=$(grep -o 'time="[0-9.]*"' "$report_file" | head -1 | sed 's/time="\([0-9.]*\)"/\1/' || echo "0")
    fi
    
    local passed_tests=$((total_tests - failures - errors))
    local suite_name=$(basename "$report_file" .xml)
    
    cat << EOF >> "$PARSED_DATA_FILE"
{
  "source_file": "$report_file",
  "suite_name": "$suite_name",
  "status": "$([ $((failures + errors)) -eq 0 ] && echo "success" || echo "failure")",
  "total_tests": $total_tests,
  "passed_tests": $passed_tests,
  "failed_tests": $((failures + errors)),
  "skipped_tests": 0,
  "duration_seconds": ${time%.*},
  "success_rate": $(( total_tests > 0 ? (passed_tests * 100) / total_tests : 0 )),
  "environment": {},
  "timestamp": "$(date -Iseconds)"
},
EOF
}

# Function to parse log file for basic metrics
parse_log_file() {
    local log_file="$1"
    local suite_name=$(basename "$log_file" .log)
    
    # Extract basic test counts from Go test output
    local pass_count=$(grep -c "^PASS" "$log_file" 2>/dev/null || echo "0")
    local fail_count=$(grep -c "^FAIL" "$log_file" 2>/dev/null || echo "0")
    local skip_count=$(grep -c "^SKIP" "$log_file" 2>/dev/null || echo "0")
    local total_tests=$((pass_count + fail_count + skip_count))
    
    # Try to extract duration from output
    local duration=0
    if grep -q "PASS.*in.*s" "$log_file"; then
        duration=$(grep "PASS.*in.*s" "$log_file" | tail -1 | grep -oE '[0-9]+\.?[0-9]*s' | sed 's/s$//' || echo "0")
    fi
    
    cat << EOF >> "$PARSED_DATA_FILE"
{
  "source_file": "$log_file",
  "suite_name": "$suite_name",
  "status": "$([ $fail_count -eq 0 ] && echo "success" || echo "failure")",
  "total_tests": $total_tests,
  "passed_tests": $pass_count,
  "failed_tests": $fail_count,
  "skipped_tests": $skip_count,
  "duration_seconds": ${duration%.*},
  "success_rate": $(( total_tests > 0 ? (pass_count * 100) / total_tests : 0 )),
  "environment": {},
  "timestamp": "$(date -Iseconds)"
},
EOF
}

# Function to aggregate parsed test data
aggregate_test_data() {
    local parsed_file="$1"
    local output_file="$2"
    
    log_step "Aggregating test data from parsed reports"
    
    # Remove trailing comma and create valid JSON array
    sed '$ s/,$//' "$parsed_file" > "${parsed_file}.tmp"
    
    # Create aggregated summary
    local total_suites=0
    local total_tests=0
    local total_passed=0
    local total_failed=0
    local total_skipped=0
    local total_duration=0
    local successful_suites=0
    
    # Calculate totals
    while IFS= read -r line; do
        if [[ "$line" =~ ^\{.*\}$ ]]; then
            ((total_suites++))
            
            local suite_total=$(echo "$line" | jq -r '.total_tests')
            local suite_passed=$(echo "$line" | jq -r '.passed_tests')
            local suite_failed=$(echo "$line" | jq -r '.failed_tests')
            local suite_skipped=$(echo "$line" | jq -r '.skipped_tests')
            local suite_duration=$(echo "$line" | jq -r '.duration_seconds')
            local suite_status=$(echo "$line" | jq -r '.status')
            
            total_tests=$((total_tests + suite_total))
            total_passed=$((total_passed + suite_passed))
            total_failed=$((total_failed + suite_failed))
            total_skipped=$((total_skipped + suite_skipped))
            total_duration=$((total_duration + suite_duration))
            
            if [[ "$suite_status" == "success" ]]; then
                ((successful_suites++))
            fi
        fi
    done < "${parsed_file}.tmp"
    
    local overall_success_rate=$(( total_tests > 0 ? (total_passed * 100) / total_tests : 0 ))
    local suite_success_rate=$(( total_suites > 0 ? (successful_suites * 100) / total_suites : 0 ))
    
    # Create aggregated report
    cat > "$output_file" << EOF
{
  "summary": {
    "generation_time": "$(date -Iseconds)",
    "total_suites": $total_suites,
    "successful_suites": $successful_suites,
    "failed_suites": $((total_suites - successful_suites)),
    "suite_success_rate": $suite_success_rate,
    "total_tests": $total_tests,
    "passed_tests": $total_passed,
    "failed_tests": $total_failed,
    "skipped_tests": $total_skipped,
    "overall_success_rate": $overall_success_rate,
    "total_duration_seconds": $total_duration,
    "total_duration_human": "$(printf '%dm %ds' $((total_duration/60)) $((total_duration%60)))",
    "threshold_met": $([ $overall_success_rate -ge $SUCCESS_THRESHOLD ] && echo "true" || echo "false")
  },
  "suite_details": [
$(cat "${parsed_file}.tmp")
  ],
  "environment": {
    "hostname": "$(hostname)",
    "user": "$(whoami)",
    "platform": "$(uname -s | tr '[:upper:]' '[:lower:]')",
    "architecture": "$(uname -m)",
    "go_version": "$(go version 2>/dev/null || echo 'unknown')",
    "terraform_version": "$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo 'unknown')"
  },
  "metadata": {
    "aggregator_version": "1.0.0",
    "report_format": "hashicorp-standard",
    "data_sources": $(find "$REPORT_DIR" -type f \( -name "*.json" -o -name "*.xml" -o -name "*.log" \) | jq -R . | jq -s .),
    "configuration": {
      "include_logs": $INCLUDE_LOGS,
      "success_threshold": $SUCCESS_THRESHOLD,
      "trend_analysis": $TREND_ANALYSIS,
      "performance_metrics": $PERFORMANCE_METRICS
    }
  }
}
EOF
    
    rm -f "${parsed_file}.tmp"
    log_success "Test data aggregated successfully"
}

# Function to generate Markdown report
generate_markdown_report() {
    local aggregated_file="$1"
    local output_file="$2"
    
    log_step "Generating Markdown report"
    
    local total_suites=$(jq -r '.summary.total_suites' "$aggregated_file")
    local successful_suites=$(jq -r '.summary.successful_suites' "$aggregated_file")
    local failed_suites=$(jq -r '.summary.failed_suites' "$aggregated_file")
    local suite_success_rate=$(jq -r '.summary.suite_success_rate' "$aggregated_file")
    local total_tests=$(jq -r '.summary.total_tests' "$aggregated_file")
    local passed_tests=$(jq -r '.summary.passed_tests' "$aggregated_file")
    local failed_tests=$(jq -r '.summary.failed_tests' "$aggregated_file")
    local overall_success_rate=$(jq -r '.summary.overall_success_rate' "$aggregated_file")
    local duration=$(jq -r '.summary.total_duration_human' "$aggregated_file")
    local threshold_met=$(jq -r '.summary.threshold_met' "$aggregated_file")
    
    cat > "$output_file" << EOF
# Terraform Provider Test Results

## Executive Summary

$([ "$threshold_met" = "true" ] && echo "✅ **PASS** - All quality thresholds met" || echo "❌ **FAIL** - Quality thresholds not met")

- **Overall Success Rate**: ${overall_success_rate}% (threshold: ${SUCCESS_THRESHOLD}%)
- **Suite Success Rate**: ${suite_success_rate}%
- **Total Execution Time**: $duration
- **Generated**: $(date '+%Y-%m-%d %H:%M:%S %Z')

## Test Suite Summary

| Metric | Count | Percentage |
|--------|-------|------------|
| **Total Suites** | $total_suites | 100% |
| **Successful Suites** | $successful_suites | ${suite_success_rate}% |
| **Failed Suites** | $failed_suites | $((100 - suite_success_rate))% |
| **Total Tests** | $total_tests | 100% |
| **Passed Tests** | $passed_tests | ${overall_success_rate}% |
| **Failed Tests** | $failed_tests | $((100 - overall_success_rate))% |

## Detailed Results

| Suite | Status | Tests | Pass Rate | Duration | Details |
|-------|--------|-------|-----------|----------|---------|
EOF
    
    # Add individual suite results
    jq -r '.suite_details[] | "\(.suite_name)|\(.status)|\(.total_tests)|\(.success_rate)%|\(.duration_seconds)s|"' "$aggregated_file" | \
    while IFS='|' read -r suite status tests rate duration; do
        local status_icon=$([ "$status" = "success" ] && echo "✅" || echo "❌")
        echo "| $suite | $status_icon $status | $tests | $rate | $duration | [View Details](#suite-$suite) |" >> "$output_file"
    done
    
    # Add failed suites section if any failures
    if [[ $failed_suites -gt 0 ]]; then
        cat >> "$output_file" << EOF

## Failed Suites Analysis

The following test suites failed and require attention:

EOF
        jq -r '.suite_details[] | select(.status != "success") | "- **\(.suite_name)**: \(.failed_tests) failed out of \(.total_tests) tests (\(.success_rate)% pass rate)"' "$aggregated_file" >> "$output_file"
        
        cat >> "$output_file" << EOF

### Recommended Actions

1. **Review Failed Tests**: Examine individual test failures for root causes
2. **Environment Check**: Verify test environment setup and dependencies
3. **Code Review**: Check recent changes that might have introduced regressions
4. **Retry Analysis**: Determine if failures are intermittent or consistent

EOF
    fi
    
    # Add environment information
    cat >> "$output_file" << EOF

## Environment Information

- **Platform**: $(jq -r '.environment.platform' "$aggregated_file") ($(jq -r '.environment.architecture' "$aggregated_file"))
- **Go Version**: $(jq -r '.environment.go_version' "$aggregated_file")
- **Terraform Version**: $(jq -r '.environment.terraform_version' "$aggregated_file")
- **Hostname**: $(jq -r '.environment.hostname' "$aggregated_file")

## Configuration

- **Success Threshold**: ${SUCCESS_THRESHOLD}%
- **Include Logs**: $([ "$INCLUDE_LOGS" = "1" ] && echo "Yes" || echo "No")
- **Trend Analysis**: $([ "$TREND_ANALYSIS" = "1" ] && echo "Enabled" || echo "Disabled")
- **Performance Metrics**: $([ "$PERFORMANCE_METRICS" = "1" ] && echo "Enabled" || echo "Disabled")

---

*Report generated by HashiCorp-style Test Result Aggregator*  
*Project: Terraform Provider prettyjson*  
*Generated at: $(date -Iseconds)*
EOF
    
    log_success "Markdown report generated: $output_file"
}

# Function to generate GitHub Actions summary
generate_github_summary() {
    local aggregated_file="$1"
    local output_file="$2"
    
    log_step "Generating GitHub Actions summary"
    
    local overall_success_rate=$(jq -r '.summary.overall_success_rate' "$aggregated_file")
    local threshold_met=$(jq -r '.summary.threshold_met' "$aggregated_file")
    local status_icon=$([ "$threshold_met" = "true" ] && echo "✅" || echo "❌")
    
    cat > "$output_file" << EOF
## $status_icon Test Results Summary

**Overall Success Rate**: ${overall_success_rate}% (threshold: ${SUCCESS_THRESHOLD}%)

### Quick Stats
- **Suites**: $(jq -r '.summary.successful_suites' "$aggregated_file")/$(jq -r '.summary.total_suites' "$aggregated_file") passed
- **Tests**: $(jq -r '.summary.passed_tests' "$aggregated_file")/$(jq -r '.summary.total_tests' "$aggregated_file") passed  
- **Duration**: $(jq -r '.summary.total_duration_human' "$aggregated_file")

### Suite Results
EOF
    
    jq -r '.suite_details[] | "\(.suite_name)|\(.status)|\(.success_rate)"' "$aggregated_file" | \
    while IFS='|' read -r suite status rate; do
        local icon=$([ "$status" = "success" ] && echo "✅" || echo "❌")
        echo "- $icon **$suite**: ${rate}%" >> "$output_file"
    done
    
    # Add to GitHub step summary if available
    if [[ -n "$GITHUB_STEP_SUMMARY" ]]; then
        cat "$output_file" >> "$GITHUB_STEP_SUMMARY"
    fi
    
    log_success "GitHub summary generated: $output_file"
}

# Function to generate JUnit XML aggregate report
generate_junit_report() {
    local aggregated_file="$1"
    local output_file="$2"
    
    log_step "Generating JUnit XML report"
    
    local total_tests=$(jq -r '.summary.total_tests' "$aggregated_file")
    local failed_tests=$(jq -r '.summary.failed_tests' "$aggregated_file")
    local total_duration=$(jq -r '.summary.total_duration_seconds' "$aggregated_file")
    
    cat > "$output_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="terraform-provider-prettyjson-aggregated" tests="$total_tests" failures="$failed_tests" time="$total_duration" timestamp="$(date -Iseconds)">
EOF
    
    # Add individual test suites
    jq -c '.suite_details[]' "$aggregated_file" | while read -r suite; do
        local suite_name=$(echo "$suite" | jq -r '.suite_name')
        local suite_tests=$(echo "$suite" | jq -r '.total_tests')
        local suite_failed=$(echo "$suite" | jq -r '.failed_tests')
        local suite_duration=$(echo "$suite" | jq -r '.duration_seconds')
        local suite_status=$(echo "$suite" | jq -r '.status')
        
        cat >> "$output_file" << EOF
  <testsuite name="$suite_name" tests="$suite_tests" failures="$suite_failed" time="$suite_duration">
EOF
        
        if [[ "$suite_status" != "success" ]]; then
            cat >> "$output_file" << EOF
    <testcase name="$suite_name" time="$suite_duration">
      <failure message="Test suite failed">$suite_failed tests failed in suite $suite_name</failure>
    </testcase>
EOF
        else
            cat >> "$output_file" << EOF
    <testcase name="$suite_name" time="$suite_duration"/>
EOF
        fi
        
        cat >> "$output_file" << EOF
  </testsuite>
EOF
    done
    
    cat >> "$output_file" << EOF
</testsuites>
EOF
    
    log_success "JUnit XML report generated: $output_file"
}

# Function to send webhook notifications
send_webhook_notifications() {
    local aggregated_file="$1"
    
    if [[ -n "$WEBHOOK_URL" ]]; then
        log_step "Sending webhook notification"
        
        local success_rate=$(jq -r '.summary.overall_success_rate' "$aggregated_file")
        local threshold_met=$(jq -r '.summary.threshold_met' "$aggregated_file")
        local color=$([ "$threshold_met" = "true" ] && echo "good" || echo "danger")
        local icon=$([ "$threshold_met" = "true" ] && echo ":white_check_mark:" || echo ":x:")
        
        local payload=$(cat << EOF
{
  "text": "$icon Terraform Provider Test Results",
  "attachments": [
    {
      "color": "$color",
      "fields": [
        {
          "title": "Success Rate",
          "value": "${success_rate}%",
          "short": true
        },
        {
          "title": "Threshold",
          "value": "${SUCCESS_THRESHOLD}%",
          "short": true
        },
        {
          "title": "Total Tests",
          "value": "$(jq -r '.summary.total_tests' "$aggregated_file")",
          "short": true
        },
        {
          "title": "Duration",
          "value": "$(jq -r '.summary.total_duration_human' "$aggregated_file")",
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
        
        if curl -X POST -H 'Content-type: application/json' --data "$payload" "$WEBHOOK_URL" &>/dev/null; then
            log_success "Webhook notification sent successfully"
        else
            log_warning "Failed to send webhook notification"
        fi
    fi
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -i|--input-dir)
                REPORT_DIR="$2"
                shift 2
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -f|--formats)
                IFS=',' read -ra OUTPUT_FORMATS <<< "$2"
                shift 2
                ;;
            --include-logs)
                INCLUDE_LOGS=1
                shift
                ;;
            --merge-coverage)
                MERGE_COVERAGE=1
                shift
                ;;
            --webhook-url)
                WEBHOOK_URL="$2"
                shift 2
                ;;
            --slack-channel)
                SLACK_CHANNEL="$2"
                shift 2
                ;;
            --teams-webhook)
                TEAMS_WEBHOOK="$2"
                shift 2
                ;;
            --email-recipients)
                EMAIL_RECIPIENTS="$2"
                shift 2
                ;;
            --threshold)
                SUCCESS_THRESHOLD="$2"
                shift 2
                ;;
            --trend-analysis)
                TREND_ANALYSIS=1
                shift
                ;;
            --performance-metrics)
                PERFORMANCE_METRICS=1
                shift
                ;;
            --verbose)
                VERBOSE=1
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
    REPORT_DIR=${REPORT_DIR:-$DEFAULT_REPORT_DIR}
    OUTPUT_DIR=${OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}
    OUTPUT_FORMATS=(${OUTPUT_FORMATS[@]:-"${DEFAULT_FORMATS[@]}"})
    INCLUDE_LOGS=${INCLUDE_LOGS:-0}
    MERGE_COVERAGE=${MERGE_COVERAGE:-0}
    SUCCESS_THRESHOLD=${SUCCESS_THRESHOLD:-80}
    TREND_ANALYSIS=${TREND_ANALYSIS:-0}
    PERFORMANCE_METRICS=${PERFORMANCE_METRICS:-0}
    VERBOSE=${VERBOSE:-0}
}

# Main function
main() {
    cd "$PROJECT_ROOT"
    
    log_info "Starting HashiCorp-style test result aggregation"
    log_info "Input directory: $REPORT_DIR"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Output formats: ${OUTPUT_FORMATS[*]}"
    
    # Validate input directory
    if [[ ! -d "$REPORT_DIR" ]]; then
        log_error "Input directory does not exist: $REPORT_DIR"
        exit 1
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Initialize temporary files
    PARSED_DATA_FILE="$OUTPUT_DIR/parsed-data.jsonl"
    echo "" > "$PARSED_DATA_FILE"
    
    # Discover and parse test reports
    local reports=($(discover_test_reports "$REPORT_DIR"))
    
    if [[ ${#reports[@]} -eq 0 ]]; then
        log_warning "No test reports found in $REPORT_DIR"
        exit 0
    fi
    
    # Parse individual reports
    for report in "${reports[@]}"; do
        parse_test_report "$report"
    done
    
    # Aggregate test data
    local aggregated_file="$OUTPUT_DIR/aggregated-results.json"
    aggregate_test_data "$PARSED_DATA_FILE" "$aggregated_file"
    
    # Generate output formats
    for format in "${OUTPUT_FORMATS[@]}"; do
        case "$format" in
            "json")
                log_info "JSON report already generated: $aggregated_file"
                ;;
            "markdown")
                generate_markdown_report "$aggregated_file" "$OUTPUT_DIR/test-results.md"
                ;;
            "github")
                generate_github_summary "$aggregated_file" "$OUTPUT_DIR/github-summary.md"
                ;;
            "junit")
                generate_junit_report "$aggregated_file" "$OUTPUT_DIR/junit-aggregated.xml"
                ;;
            *)
                log_warning "Unknown output format: $format"
                ;;
        esac
    done
    
    # Send notifications
    send_webhook_notifications "$aggregated_file"
    
    # Cleanup temporary files
    rm -f "$PARSED_DATA_FILE"
    
    # Final summary
    local success_rate=$(jq -r '.summary.overall_success_rate' "$aggregated_file")
    local threshold_met=$(jq -r '.summary.threshold_met' "$aggregated_file")
    
    log_info "=========================================="
    log_info "Test Result Aggregation Summary"
    log_info "=========================================="
    log_info "Success Rate: ${success_rate}% (threshold: ${SUCCESS_THRESHOLD}%)"
    log_info "Reports Generated: ${#OUTPUT_FORMATS[@]}"
    log_info "Output Directory: $OUTPUT_DIR"
    
    if [[ "$threshold_met" == "true" ]]; then
        log_success "All quality thresholds met!"
        exit 0
    else
        log_error "Quality threshold not met (${success_rate}% < ${SUCCESS_THRESHOLD}%)"
        exit 1
    fi
}

# Parse arguments and run
parse_args "$@"
main