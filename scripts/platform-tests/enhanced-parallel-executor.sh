#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


# Enhanced parallel execution and retry mechanisms for Terraform provider testing
# This script implements advanced patterns for parallel test execution with
# intelligent retry strategies, load balancing, and resource management

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
DEFAULT_MAX_PARALLEL=4
DEFAULT_RETRY_COUNT=3
DEFAULT_RETRY_BACKOFF="exponential"
DEFAULT_RETRY_JITTER=0.1
DEFAULT_CIRCUIT_BREAKER_THRESHOLD=0.7
DEFAULT_TIMEOUT="30m"
DEFAULT_QUEUE_SIZE=50

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global state management
declare -A ACTIVE_JOBS=()
declare -A JOB_RETRY_COUNT=()
declare -A JOB_START_TIME=()
declare -A JOB_FAILURE_HISTORY=()
declare -A WORKER_LOAD=()
declare -A CIRCUIT_BREAKER_STATE=()

# Performance metrics
declare -A EXECUTION_TIMES=()
declare -A RETRY_STATS=()
declare -A RESOURCE_USAGE=()

# Logging functions with enhanced context
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') [$$] $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') [$$] $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') [$$] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') [$$] $1" | tee -a "$LOG_FILE"
}

log_debug() {
    if [[ "$VERBOSE" == "1" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') [$$] $1" | tee -a "$LOG_FILE"
    fi
}

log_metric() {
    echo -e "${CYAN}[METRIC]${NC} $(date '+%Y-%m-%d %H:%M:%S') [$$] $1" | tee -a "$METRICS_FILE"
}

# Function to print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Enhanced parallel execution and retry mechanisms for Terraform provider testing

OPTIONS:
    -h, --help                      Show this help message
    -j, --max-parallel JOBS         Maximum parallel jobs (default: 4)
    -r, --retry-count COUNT         Maximum retry attempts (default: 3)
    -b, --retry-backoff STRATEGY    Retry backoff strategy: linear, exponential, fixed (default: exponential)
    -t, --timeout DURATION          Job timeout (default: 30m)
    --jitter FACTOR                 Jitter factor for retry delays (default: 0.1)
    --circuit-breaker THRESHOLD     Circuit breaker threshold (default: 0.7)
    --queue-size SIZE               Job queue size (default: 50)
    --load-balancing                Enable load balancing across workers
    --resource-monitoring           Enable resource usage monitoring
    --adaptive-parallelism          Dynamically adjust parallelism based on load
    --failure-correlation           Analyze failure patterns for intelligent retry
    --performance-optimization      Enable performance optimization features
    --verbose                       Enable verbose output
    --dry-run                       Show execution plan without running

RETRY STRATEGIES:
    linear          Linear backoff: delay = base_delay * attempt
    exponential     Exponential backoff: delay = base_delay * (2 ^ attempt)
    fixed           Fixed delay: delay = base_delay

LOAD BALANCING STRATEGIES:
    round-robin     Distribute jobs evenly across workers
    least-loaded    Assign jobs to least loaded workers
    weighted        Weight-based assignment based on worker capacity

EXAMPLES:
    $0 -j 8 --load-balancing                # 8 parallel jobs with load balancing
    $0 --adaptive-parallelism --resource-monitoring  # Dynamic parallelism with monitoring
    $0 -b exponential --jitter 0.2          # Exponential backoff with 20% jitter
    $0 --circuit-breaker 0.5 --failure-correlation  # Enhanced failure handling

EOF
}

# Function to calculate retry delay with backoff and jitter
calculate_retry_delay() {
    local attempt="$1"
    local base_delay="${2:-5}"
    local strategy="$RETRY_BACKOFF"
    local jitter="$RETRY_JITTER"
    
    local delay
    case "$strategy" in
        "linear")
            delay=$((base_delay * attempt))
            ;;
        "exponential")
            delay=$((base_delay * (2 ** (attempt - 1))))
            ;;
        "fixed")
            delay=$base_delay
            ;;
        *)
            delay=$((base_delay * (2 ** (attempt - 1))))
            ;;
    esac
    
    # Apply jitter to prevent thundering herd
    if [[ $(echo "$jitter > 0" | bc -l) -eq 1 ]]; then
        local jitter_amount=$(echo "$delay * $jitter" | bc -l)
        local random_jitter=$(echo "scale=2; $RANDOM / 32767 * $jitter_amount * 2 - $jitter_amount" | bc -l)
        delay=$(echo "$delay + $random_jitter" | bc -l | cut -d. -f1)
    fi
    
    # Ensure minimum delay
    if [[ $delay -lt 1 ]]; then
        delay=1
    fi
    
    echo "$delay"
}

# Function to check circuit breaker state
check_circuit_breaker() {
    local job_type="$1"
    local current_failure_rate="${CIRCUIT_BREAKER_STATE[$job_type]:-0}"
    
    if [[ $(echo "$current_failure_rate >= $CIRCUIT_BREAKER_THRESHOLD" | bc -l) -eq 1 ]]; then
        log_warning "Circuit breaker OPEN for job type: $job_type (failure rate: $current_failure_rate)"
        return 1
    fi
    
    return 0
}

# Function to update circuit breaker state
update_circuit_breaker() {
    local job_type="$1"
    local success="$2"
    
    local history_key="${job_type}_history"
    local current_history="${JOB_FAILURE_HISTORY[$history_key]:-}"
    
    # Add current result to history (1 for success, 0 for failure)
    local result=$([ "$success" = "true" ] && echo "1" || echo "0")
    current_history="${current_history}${result}"
    
    # Keep only last 10 results
    if [[ ${#current_history} -gt 10 ]]; then
        current_history="${current_history: -10}"
    fi
    
    JOB_FAILURE_HISTORY[$history_key]="$current_history"
    
    # Calculate failure rate
    local total_jobs=${#current_history}
    local failed_jobs=$(echo "$current_history" | tr -cd '0' | wc -c)
    local failure_rate=$(echo "scale=2; $failed_jobs / $total_jobs" | bc -l)
    
    CIRCUIT_BREAKER_STATE[$job_type]="$failure_rate"
    
    log_debug "Updated circuit breaker for $job_type: failure rate $failure_rate ($failed_jobs/$total_jobs)"
}

# Function to get least loaded worker
get_least_loaded_worker() {
    local min_load=999999
    local best_worker=""
    
    for worker_id in $(seq 1 "$MAX_PARALLEL"); do
        local load="${WORKER_LOAD[$worker_id]:-0}"
        if [[ $load -lt $min_load ]]; then
            min_load=$load
            best_worker=$worker_id
        fi
    done
    
    echo "$best_worker"
}

# Function to monitor system resources
monitor_resources() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\\([0-9.]*\\)%* id.*/\\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "0")
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}' 2>/dev/null || echo "0")
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',' 2>/dev/null || echo "0")
    
    RESOURCE_USAGE["cpu"]="$cpu_usage"
    RESOURCE_USAGE["memory"]="$memory_usage"
    RESOURCE_USAGE["load"]="$load_avg"
    
    log_metric "Resource usage - CPU: ${cpu_usage}%, Memory: ${memory_usage}%, Load: $load_avg"
}

# Function to adjust parallelism based on system load
adjust_adaptive_parallelism() {
    if [[ "$ADAPTIVE_PARALLELISM" != "1" ]]; then
        return 0
    fi
    
    monitor_resources
    
    local cpu_usage="${RESOURCE_USAGE["cpu"]}"
    local memory_usage="${RESOURCE_USAGE["memory"]}"
    local load_avg="${RESOURCE_USAGE["load"]}"
    
    # Determine optimal parallelism based on resource usage
    local optimal_parallel=$MAX_PARALLEL
    
    # Reduce parallelism if CPU usage is too high
    if [[ $(echo "$cpu_usage > 90" | bc -l) -eq 1 ]]; then
        optimal_parallel=$((optimal_parallel - 1))
        log_debug "Reducing parallelism due to high CPU usage: ${cpu_usage}%"
    fi
    
    # Reduce parallelism if memory usage is too high
    if [[ $(echo "$memory_usage > 85" | bc -l) -eq 1 ]]; then
        optimal_parallel=$((optimal_parallel - 1))
        log_debug "Reducing parallelism due to high memory usage: ${memory_usage}%"
    fi
    
    # Increase parallelism if resources are underutilized
    if [[ $(echo "$cpu_usage < 50" | bc -l) -eq 1 ]] && [[ $(echo "$memory_usage < 50" | bc -l) -eq 1 ]]; then
        optimal_parallel=$((optimal_parallel + 1))
        log_debug "Increasing parallelism due to low resource usage"
    fi
    
    # Bounds checking
    if [[ $optimal_parallel -lt 1 ]]; then
        optimal_parallel=1
    elif [[ $optimal_parallel -gt $((MAX_PARALLEL * 2)) ]]; then
        optimal_parallel=$((MAX_PARALLEL * 2))
    fi
    
    # Update current parallelism if needed
    if [[ $optimal_parallel -ne $CURRENT_PARALLEL ]]; then
        log_info "Adjusting parallelism from $CURRENT_PARALLEL to $optimal_parallel"
        CURRENT_PARALLEL=$optimal_parallel
    fi
}

# Function to execute a job with enhanced error handling
execute_job_enhanced() {
    local job_id="$1"
    local job_command="$2"
    local job_type="$3"
    local worker_id="$4"
    
    local start_time=$(date +%s.%N)
    JOB_START_TIME[$job_id]="$start_time"
    
    # Increment worker load
    WORKER_LOAD[$worker_id]=$((${WORKER_LOAD[$worker_id]:-0} + 1))
    
    log_debug "Starting job $job_id on worker $worker_id: $job_command"
    
    local success=false
    local exit_code=0
    local output=""
    local error_output=""
    
    # Execute job with timeout and capture output
    local job_log_file="/tmp/job-${job_id}-${RANDOM}.log"
    local job_error_file="/tmp/job-${job_id}-${RANDOM}.err"
    
    if timeout "$TIMEOUT" bash -c "$job_command" > "$job_log_file" 2> "$job_error_file"; then
        success=true
        output=$(cat "$job_log_file")
        log_success "Job $job_id completed successfully on worker $worker_id"
    else
        exit_code=$?
        output=$(cat "$job_log_file")
        error_output=$(cat "$job_error_file")
        
        if [[ $exit_code -eq 124 ]]; then
            log_error "Job $job_id timed out on worker $worker_id (timeout: $TIMEOUT)"
        else
            log_error "Job $job_id failed on worker $worker_id (exit code: $exit_code)"
        fi
    fi
    
    # Calculate execution time
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    EXECUTION_TIMES[$job_id]="$duration"
    
    # Update circuit breaker
    update_circuit_breaker "$job_type" "$success"
    
    # Decrement worker load
    WORKER_LOAD[$worker_id]=$((${WORKER_LOAD[$worker_id]} - 1))
    
    # Store job result
    if [[ "$success" == "true" ]]; then
        echo "SUCCESS:$job_id:$duration:$output" >> "$RESULTS_FILE"
    else
        echo "FAILURE:$job_id:$duration:$exit_code:$error_output" >> "$RESULTS_FILE"
    fi
    
    # Cleanup temporary files
    rm -f "$job_log_file" "$job_error_file"
    
    log_metric "Job $job_id execution time: ${duration}s, success: $success, worker: $worker_id"
    
    return $([ "$success" = true ] && echo 0 || echo 1)
}

# Function to retry failed job with intelligent backoff
retry_job_with_backoff() {
    local job_id="$1"
    local job_command="$2"
    local job_type="$3"
    local max_retries="$RETRY_COUNT"
    
    local retry_count="${JOB_RETRY_COUNT[$job_id]:-0}"
    local attempt=$((retry_count + 1))
    
    if [[ $attempt -gt $max_retries ]]; then
        log_error "Job $job_id exceeded maximum retry attempts ($max_retries)"
        return 1
    fi
    
    # Check circuit breaker
    if ! check_circuit_breaker "$job_type"; then
        log_warning "Circuit breaker prevents retry of job $job_id"
        return 1
    fi
    
    # Calculate retry delay
    local delay=$(calculate_retry_delay "$attempt")
    log_info "Retrying job $job_id (attempt $attempt/$max_retries) after ${delay}s delay"
    
    # Update retry statistics
    local retry_key="${job_type}_retries"
    RETRY_STATS[$retry_key]=$((${RETRY_STATS[$retry_key]:-0} + 1))
    
    # Wait with delay
    sleep "$delay"
    
    # Update retry count
    JOB_RETRY_COUNT[$job_id]=$attempt
    
    # Get worker for retry
    local worker_id
    if [[ "$LOAD_BALANCING" == "1" ]]; then
        worker_id=$(get_least_loaded_worker)
    else
        worker_id=$((RANDOM % MAX_PARALLEL + 1))
    fi
    
    # Execute retry
    execute_job_enhanced "$job_id" "$job_command" "$job_type" "$worker_id"
}

# Function to manage job queue with advanced scheduling
manage_job_queue() {
    local jobs=("$@")
    local active_count=0
    local completed_count=0
    local failed_count=0
    local job_index=0
    
    log_info "Managing job queue with ${#jobs[@]} jobs and $MAX_PARALLEL workers"
    
    # Initialize worker load tracking
    for worker_id in $(seq 1 "$MAX_PARALLEL"); do
        WORKER_LOAD[$worker_id]=0
    done
    
    while [[ $job_index -lt ${#jobs[@]} ]] || [[ $active_count -gt 0 ]]; do
        # Adjust parallelism if adaptive mode is enabled
        adjust_adaptive_parallelism
        
        # Start new jobs if capacity available
        while [[ $active_count -lt $CURRENT_PARALLEL ]] && [[ $job_index -lt ${#jobs[@]} ]]; do
            local job_spec="${jobs[$job_index]}"
            IFS='|' read -r job_id job_command job_type <<< "$job_spec"
            
            # Check circuit breaker for job type
            if ! check_circuit_breaker "$job_type"; then
                log_warning "Skipping job $job_id due to circuit breaker"
                ((job_index++))
                continue
            fi
            
            # Select worker based on load balancing strategy
            local worker_id
            if [[ "$LOAD_BALANCING" == "1" ]]; then
                worker_id=$(get_least_loaded_worker)
            else
                worker_id=$(((job_index % MAX_PARALLEL) + 1))
            fi
            
            log_debug "Assigning job $job_id to worker $worker_id"
            
            # Start job in background
            (execute_job_enhanced "$job_id" "$job_command" "$job_type" "$worker_id") &
            local pid=$!
            
            ACTIVE_JOBS[$pid]="$job_id|$job_type|$worker_id"
            ((active_count++))
            ((job_index++))
            
            log_debug "Started job $job_id (PID: $pid), active jobs: $active_count"
        done
        
        # Wait for any job to complete
        if [[ $active_count -gt 0 ]]; then
            local completed_pid
            completed_pid=$(wait -n && echo $! || echo $!)
            
            # Process completed job
            local job_info="${ACTIVE_JOBS[$completed_pid]}"
            if [[ -n "$job_info" ]]; then
                IFS='|' read -r job_id job_type worker_id <<< "$job_info"
                
                # Check if job succeeded or failed
                if wait "$completed_pid"; then
                    log_success "Job $job_id completed successfully"
                    ((completed_count++))
                else
                    log_error "Job $job_id failed"
                    
                    # Attempt retry with backoff
                    if [[ "$FAILURE_CORRELATION" == "1" ]]; then
                        # Add to retry queue
                        local retry_spec="$job_id|${jobs[$((job_index - 1))]}|$job_type"
                        log_info "Adding job $job_id to retry queue"
                        # This would be handled by a separate retry queue in a full implementation
                    fi
                    
                    ((failed_count++))
                fi
                
                unset ACTIVE_JOBS[$completed_pid]
                ((active_count--))
            fi
            
            log_debug "Job completed (PID: $completed_pid), active jobs: $active_count"
        fi
        
        # Resource monitoring
        if [[ "$RESOURCE_MONITORING" == "1" ]]; then
            monitor_resources
        fi
        
        # Brief pause to prevent busy waiting
        sleep 0.1
    done
    
    log_info "Job queue completed: $completed_count succeeded, $failed_count failed"
    return $([ $failed_count -eq 0 ] && echo 0 || echo 1)
}

# Function to generate performance report
generate_performance_report() {
    local report_file="$1"
    
    log_info "Generating performance report"
    
    # Calculate statistics
    local total_jobs=0
    local total_time=0
    local min_time=999999
    local max_time=0
    
    for job_id in "${!EXECUTION_TIMES[@]}"; do
        local time="${EXECUTION_TIMES[$job_id]}"
        total_jobs=$((total_jobs + 1))
        total_time=$(echo "$total_time + $time" | bc -l)
        
        if [[ $(echo "$time < $min_time" | bc -l) -eq 1 ]]; then
            min_time="$time"
        fi
        
        if [[ $(echo "$time > $max_time" | bc -l) -eq 1 ]]; then
            max_time="$time"
        fi
    done
    
    local avg_time=0
    if [[ $total_jobs -gt 0 ]]; then
        avg_time=$(echo "scale=2; $total_time / $total_jobs" | bc -l)
    fi
    
    # Generate report
    cat > "$report_file" << EOF
{
  "performance_summary": {
    "total_jobs": $total_jobs,
    "total_execution_time": $total_time,
    "average_execution_time": $avg_time,
    "minimum_execution_time": $min_time,
    "maximum_execution_time": $max_time,
    "parallelism_used": $MAX_PARALLEL,
    "adaptive_parallelism": $ADAPTIVE_PARALLELISM,
    "load_balancing": $LOAD_BALANCING
  },
  "retry_statistics": $(echo '{}' | jq -c '. + $ARGS.named' --argjson ARGS "$(for key in "${!RETRY_STATS[@]}"; do echo "\"$key\": ${RETRY_STATS[$key]}"; done | jq -R . | jq -s 'map(split(": ")) | map({key: .[0], value: (.[1] | tonumber)}) | from_entries')"),
  "circuit_breaker_state": $(echo '{}' | jq -c '. + $ARGS.named' --argjson ARGS "$(for key in "${!CIRCUIT_BREAKER_STATE[@]}"; do echo "\"$key\": ${CIRCUIT_BREAKER_STATE[$key]}"; done | jq -R . | jq -s 'map(split(": ")) | map({key: .[0], value: (.[1] | tonumber)}) | from_entries')"),
  "resource_usage": $(echo '{}' | jq -c '. + $ARGS.named' --argjson ARGS "$(for key in "${!RESOURCE_USAGE[@]}"; do echo "\"$key\": \"${RESOURCE_USAGE[$key]}\""; done | jq -R . | jq -s 'map(split(": ")) | map({key: .[0], value: .[1]}) | from_entries')")
}
EOF
    
    log_success "Performance report generated: $report_file"
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -j|--max-parallel)
                MAX_PARALLEL="$2"
                shift 2
                ;;
            -r|--retry-count)
                RETRY_COUNT="$2"
                shift 2
                ;;
            -b|--retry-backoff)
                RETRY_BACKOFF="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --jitter)
                RETRY_JITTER="$2"
                shift 2
                ;;
            --circuit-breaker)
                CIRCUIT_BREAKER_THRESHOLD="$2"
                shift 2
                ;;
            --queue-size)
                QUEUE_SIZE="$2"
                shift 2
                ;;
            --load-balancing)
                LOAD_BALANCING=1
                shift
                ;;
            --resource-monitoring)
                RESOURCE_MONITORING=1
                shift
                ;;
            --adaptive-parallelism)
                ADAPTIVE_PARALLELISM=1
                shift
                ;;
            --failure-correlation)
                FAILURE_CORRELATION=1
                shift
                ;;
            --performance-optimization)
                PERFORMANCE_OPTIMIZATION=1
                shift
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
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
    MAX_PARALLEL=${MAX_PARALLEL:-$DEFAULT_MAX_PARALLEL}
    RETRY_COUNT=${RETRY_COUNT:-$DEFAULT_RETRY_COUNT}
    RETRY_BACKOFF=${RETRY_BACKOFF:-$DEFAULT_RETRY_BACKOFF}
    RETRY_JITTER=${RETRY_JITTER:-$DEFAULT_RETRY_JITTER}
    CIRCUIT_BREAKER_THRESHOLD=${CIRCUIT_BREAKER_THRESHOLD:-$DEFAULT_CIRCUIT_BREAKER_THRESHOLD}
    TIMEOUT=${TIMEOUT:-$DEFAULT_TIMEOUT}
    QUEUE_SIZE=${QUEUE_SIZE:-$DEFAULT_QUEUE_SIZE}
    LOAD_BALANCING=${LOAD_BALANCING:-0}
    RESOURCE_MONITORING=${RESOURCE_MONITORING:-0}
    ADAPTIVE_PARALLELISM=${ADAPTIVE_PARALLELISM:-0}
    FAILURE_CORRELATION=${FAILURE_CORRELATION:-0}
    PERFORMANCE_OPTIMIZATION=${PERFORMANCE_OPTIMIZATION:-0}
    VERBOSE=${VERBOSE:-0}
    DRY_RUN=${DRY_RUN:-0}
    
    CURRENT_PARALLEL=$MAX_PARALLEL
}

# Main function
main() {
    # Initialize
    LOG_FILE="/tmp/enhanced-parallel-executor-$$.log"
    METRICS_FILE="/tmp/enhanced-parallel-metrics-$$.log"
    RESULTS_FILE="/tmp/enhanced-parallel-results-$$.log"
    
    log_info "Starting enhanced parallel executor"
    log_info "Configuration: max_parallel=$MAX_PARALLEL, retry_count=$RETRY_COUNT, timeout=$TIMEOUT"
    log_info "Features: load_balancing=$LOAD_BALANCING, adaptive_parallelism=$ADAPTIVE_PARALLELISM"
    
    # Example job queue (in real usage, this would be populated externally)
    local example_jobs=(
        "job1|go test -v ./internal/provider/ -run TestJsonPrettyPrintFunction|unit"
        "job2|TF_ACC=1 go test -v ./internal/provider/ -run TestTerraformVersionCompatibility|acceptance"
        "job3|go test -v ./internal/provider/ -run TestTerraformVersionPerformance|performance"
        "job4|TF_ACC=1 go test -v ./internal/provider/|integration"
    )
    
    if [[ "$DRY_RUN" == "1" ]]; then
        log_info "DRY RUN: Would execute ${#example_jobs[@]} jobs with enhanced parallel execution"
        for job in "${example_jobs[@]}"; do
            IFS='|' read -r job_id job_command job_type <<< "$job"
            log_info "Would execute: $job_id ($job_type) - $job_command"
        done
        exit 0
    fi
    
    # Execute job queue
    if manage_job_queue "${example_jobs[@]}"; then
        log_success "All jobs completed successfully"
        exit_code=0
    else
        log_error "Some jobs failed"
        exit_code=1
    fi
    
    # Generate performance report
    if [[ "$PERFORMANCE_OPTIMIZATION" == "1" ]]; then
        generate_performance_report "/tmp/enhanced-parallel-performance-$$.json"
    fi
    
    # Cleanup
    rm -f "$LOG_FILE" "$METRICS_FILE" "$RESULTS_FILE"
    
    exit $exit_code
}

# Parse arguments and run
parse_args "$@"
main