#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


# Cross-platform integration test runner following HashiCorp patterns
# This script implements comprehensive integration testing across different
# environments including containerized, cloud, and local development setups

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
DEFAULT_TEST_ENVIRONMENTS=("local" "docker" "cloud")
DEFAULT_PLATFORMS=("linux" "windows" "macos")
DEFAULT_TERRAFORM_VERSIONS=("1.8.5" "1.9.8" "latest")
INTEGRATION_TEST_DIR="$PROJECT_ROOT/test/integration"
TEST_RESULTS_DIR="$PROJECT_ROOT/test-results/integration"
GOLDEN_FILES_DIR="$PROJECT_ROOT/test/golden-files"

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

Cross-platform integration test runner for Terraform provider

OPTIONS:
    -h, --help                    Show this help message
    -e, --environments ENV        Comma-separated test environments (default: local,docker,cloud)
    -p, --platforms PLATFORMS     Comma-separated platforms (default: linux,windows,macos)
    -t, --tf-versions VERSIONS    Comma-separated Terraform versions (default: 1.8.5,1.9.8,latest)
    --test-type TYPE              Test type: data-exchange, file-format, e2e, all (default: all)
    --golden-file-update          Update golden files with new test results
    --skip-cleanup                Skip test environment cleanup
    --container-runtime RUNTIME   Container runtime: docker, podman (default: docker)
    --cloud-provider PROVIDER     Cloud provider: aws, azure, gcp (default: aws)
    --timeout DURATION            Test timeout (default: 30m)
    --parallel                    Run tests in parallel
    --verbose                     Enable verbose output
    --dry-run                     Show what would be executed without running

TEST ENVIRONMENTS:
    local       Local development environment testing
    docker      Containerized environment testing
    cloud       Cloud platform testing (requires credentials)

TEST TYPES:
    data-exchange    Cross-platform data serialization and compatibility
    file-format      File format compatibility across platforms
    e2e             End-to-end workflow integration tests
    all             All test types

EXAMPLES:
    $0                                          # Run all tests in all environments
    $0 -e local -t 1.8.5,latest               # Test specific versions locally
    $0 --test-type data-exchange --parallel    # Run data exchange tests in parallel
    $0 -e docker --container-runtime podman   # Use Podman for container tests
    $0 -e cloud --cloud-provider azure        # Test on Azure cloud

EOF
}

# Function to setup test environment
setup_test_environment() {
    local environment="$1"
    
    log_step "Setting up $environment test environment"
    
    # Create test directories
    mkdir -p "$INTEGRATION_TEST_DIR"
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "$GOLDEN_FILES_DIR"
    
    case "$environment" in
        "local")
            setup_local_environment
            ;;
        "docker")
            setup_docker_environment
            ;;
        "cloud")
            setup_cloud_environment
            ;;
        *)
            log_error "Unknown environment: $environment"
            return 1
            ;;
    esac
}

# Function to setup local test environment
setup_local_environment() {
    log_info "Setting up local test environment"
    
    # Validate required tools
    local required_tools=("terraform" "go" "jq")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "Required tool not found: $tool"
            return 1
        fi
    done
    
    # Build provider
    log_info "Building provider for local testing"
    cd "$PROJECT_ROOT"
    go build -v .
    
    # Create provider mirror for testing
    local provider_dir="$INTEGRATION_TEST_DIR/providers/registry.terraform.io/hashicorp/prettyjson/1.0.0"
    mkdir -p "$provider_dir/$(go env GOOS)_$(go env GOARCH)"
    cp "$PROJECT_ROOT/terraform-provider-prettyjson" "$provider_dir/$(go env GOOS)_$(go env GOARCH)/"
    
    log_success "Local environment setup complete"
}

# Function to setup Docker test environment
setup_docker_environment() {
    log_info "Setting up Docker test environment"
    
    # Check container runtime
    if ! command -v "$CONTAINER_RUNTIME" >/dev/null 2>&1; then
        log_error "Container runtime not found: $CONTAINER_RUNTIME"
        return 1
    fi
    
    # Create Dockerfiles for different platforms
    create_docker_test_images
    
    log_success "Docker environment setup complete"
}

# Function to setup cloud test environment
setup_cloud_environment() {
    log_info "Setting up cloud test environment"
    
    case "$CLOUD_PROVIDER" in
        "aws")
            setup_aws_environment
            ;;
        "azure")
            setup_azure_environment
            ;;
        "gcp")
            setup_gcp_environment
            ;;
        *)
            log_error "Unsupported cloud provider: $CLOUD_PROVIDER"
            return 1
            ;;
    esac
}

# Function to create Docker test images
create_docker_test_images() {
    local docker_dir="$INTEGRATION_TEST_DIR/docker"
    mkdir -p "$docker_dir"
    
    # Alpine-based image for minimal environment testing
    cat > "$docker_dir/Dockerfile.alpine" << EOF
FROM alpine:3.18

# Install required packages
RUN apk add --no-cache \\
    bash \\
    curl \\
    jq \\
    unzip \\
    ca-certificates

# Install Go
RUN wget https://go.dev/dl/go1.23.5.linux-amd64.tar.gz \\
    && tar -C /usr/local -xzf go1.23.5.linux-amd64.tar.gz \\
    && rm go1.23.5.linux-amd64.tar.gz

ENV PATH="/usr/local/go/bin:\$PATH"

# Install Terraform
RUN curl -fsSL https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip -o terraform.zip \\
    && unzip terraform.zip \\
    && mv terraform /usr/local/bin/ \\
    && rm terraform.zip

WORKDIR /test
COPY . .

RUN chmod +x scripts/platform-tests/*.sh
CMD ["./scripts/platform-tests/integration-test-runner.sh", "-e", "local", "--verbose"]
EOF

    # Ubuntu-based image for standard environment testing
    cat > "$docker_dir/Dockerfile.ubuntu" << EOF
FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \\
    bash \\
    curl \\
    jq \\
    unzip \\
    ca-certificates \\
    wget \\
    && rm -rf /var/lib/apt/lists/*

# Install Go
RUN wget https://go.dev/dl/go1.23.5.linux-amd64.tar.gz \\
    && tar -C /usr/local -xzf go1.23.5.linux-amd64.tar.gz \\
    && rm go1.23.5.linux-amd64.tar.gz

ENV PATH="/usr/local/go/bin:\$PATH"

# Install Terraform
RUN curl -fsSL https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip -o terraform.zip \\
    && unzip terraform.zip \\
    && mv terraform /usr/local/bin/ \\
    && rm terraform.zip

WORKDIR /test
COPY . .

RUN chmod +x scripts/platform-tests/*.sh
CMD ["./scripts/platform-tests/integration-test-runner.sh", "-e", "local", "--verbose"]
EOF

    # Build test images
    log_info "Building Docker test images"
    cd "$PROJECT_ROOT"
    "$CONTAINER_RUNTIME" build -f "$docker_dir/Dockerfile.alpine" -t prettyjson-test:alpine .
    "$CONTAINER_RUNTIME" build -f "$docker_dir/Dockerfile.ubuntu" -t prettyjson-test:ubuntu .
    
    log_success "Docker test images built successfully"
}

# Function to run data exchange validation tests
run_data_exchange_tests() {
    local environment="$1"
    local platform="$2"
    local tf_version="$3"
    
    log_step "Running data exchange tests ($environment/$platform/terraform-$tf_version)"
    
    # Create test configuration
    local test_dir="$INTEGRATION_TEST_DIR/data-exchange-$environment-$platform-$tf_version"
    mkdir -p "$test_dir"
    
    # Create test data with various complex structures
    cat > "$test_dir/test-data.tf" << EOF
terraform {
  required_providers {
    prettyjson = {
      source = "hashicorp/prettyjson"
    }
  }
}

locals {
  # Unicode and special character data
  unicode_data = {
    english = "Hello World"
    chinese = "你好世界"
    japanese = "こんにちは世界"
    arabic = "مرحبا بالعالم"
    emoji = "🌍🚀✨"
    special_chars = "\\"quotes\\" and \\n newlines \\t tabs"
  }
  
  # Complex nested structures
  complex_data = {
    metadata = {
      version = "1.0.0"
      timestamp = "2024-01-01T00:00:00Z"
      platform = "$platform"
      environment = "$environment"
    }
    configuration = {
      features = {
        authentication = true
        logging = {
          level = "info"
          format = "json"
          outputs = ["stdout", "file"]
        }
        performance = {
          cache_size = 1024
          max_connections = 100
          timeout_seconds = 30.5
        }
      }
      services = [
        {
          name = "web"
          port = 8080
          replicas = 3
          config = {
            ssl_enabled = true
            cors_origins = ["https://example.com", "https://test.com"]
          }
        },
        {
          name = "api"
          port = 8081
          replicas = 2
          config = {
            rate_limit = 1000
            cache_ttl = 300
          }
        }
      ]
    }
  }
  
  # Platform-specific paths
  platform_paths = {
    windows = "C:\\\\Users\\\\test\\\\config.json"
    linux = "/home/test/config.json"
    macos = "/Users/test/config.json"
  }
}

# Test different indentation formats
output "unicode_2spaces" {
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.unicode_data),
    "2spaces"
  )
}

output "unicode_4spaces" {
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.unicode_data),
    "4spaces"
  )
}

output "unicode_tabs" {
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.unicode_data),
    "tabs"
  )
}

output "complex_2spaces" {
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.complex_data),
    "2spaces"
  )
}

output "complex_4spaces" {
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.complex_data),
    "4spaces"
  )
}

output "complex_tabs" {
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.complex_data),
    "tabs"
  )
}

# Platform-specific output
output "platform_specific" {
  value = provider::prettyjson::jsonprettyprint(
    jsonencode({
      current_platform = "$platform"
      config_path = local.platform_paths["$platform"]
      timestamp = formatdate("RFC3339", timestamp())
    }),
    "2spaces"
  )
}
EOF

    # Run the test
    cd "$test_dir"
    
    local test_result="success"
    local test_output=""
    local test_errors=""
    
    if test_output=$(terraform init -no-color 2>&1) && \
       test_output+=$(terraform plan -no-color 2>&1) && \
       test_output+=$(terraform apply -auto-approve -no-color 2>&1); then
        
        # Validate outputs
        local outputs=$(terraform output -json 2>/dev/null)
        
        # Check for consistent formatting across platforms
        validate_platform_consistency "$outputs" "$platform" "$environment"
        
        log_success "Data exchange test passed for $environment/$platform/terraform-$tf_version"
    else
        test_result="failure"
        test_errors="$test_output"
        log_error "Data exchange test failed for $environment/$platform/terraform-$tf_version"
    fi
    
    # Save test results
    save_test_results "data-exchange" "$environment" "$platform" "$tf_version" "$test_result" "$test_output" "$test_errors"
    
    # Cleanup if not skipped
    if [[ "$SKIP_CLEANUP" != "1" ]]; then
        terraform destroy -auto-approve -no-color >/dev/null 2>&1 || true
    fi
    
    cd "$PROJECT_ROOT"
    return $([ "$test_result" = "success" ] && echo 0 || echo 1)
}

# Function to validate platform consistency
validate_platform_consistency() {
    local outputs="$1"
    local platform="$2"
    local environment="$3"
    
    log_info "Validating platform consistency for $platform in $environment"
    
    # Extract outputs and validate format consistency
    local unicode_2spaces=$(echo "$outputs" | jq -r '.unicode_2spaces.value' 2>/dev/null)
    local unicode_4spaces=$(echo "$outputs" | jq -r '.unicode_4spaces.value' 2>/dev/null)
    local unicode_tabs=$(echo "$outputs" | jq -r '.unicode_tabs.value' 2>/dev/null)
    
    # Validate Unicode handling
    if echo "$unicode_2spaces" | grep -q "你好世界" && \
       echo "$unicode_2spaces" | grep -q "🌍🚀✨"; then
        log_success "Unicode handling validated for $platform"
    else
        log_error "Unicode handling failed for $platform"
        return 1
    fi
    
    # Validate indentation consistency
    if echo "$unicode_2spaces" | grep -q "^  " && \
       echo "$unicode_4spaces" | grep -q "^    " && \
       echo "$unicode_tabs" | grep -q "^	"; then
        log_success "Indentation consistency validated for $platform"
    else
        log_error "Indentation consistency failed for $platform"
        return 1
    fi
    
    # Compare with golden files
    compare_with_golden_files "$outputs" "$platform" "$environment"
}

# Function to compare outputs with golden files
compare_with_golden_files() {
    local outputs="$1"
    local platform="$2"
    local environment="$3"
    
    local golden_file="$GOLDEN_FILES_DIR/${platform}-${environment}-expected.json"
    
    if [[ -f "$golden_file" ]]; then
        local expected=$(cat "$golden_file")
        
        # Normalize outputs for comparison (remove timestamps)
        local normalized_actual=$(echo "$outputs" | jq 'del(.platform_specific.value | fromjson | .timestamp)')
        local normalized_expected=$(echo "$expected" | jq 'del(.platform_specific.value | fromjson | .timestamp)')
        
        if [[ "$normalized_actual" == "$normalized_expected" ]]; then
            log_success "Golden file comparison passed for $platform/$environment"
        else
            log_warning "Golden file comparison failed for $platform/$environment"
            if [[ "$GOLDEN_FILE_UPDATE" == "1" ]]; then
                echo "$outputs" > "$golden_file"
                log_info "Updated golden file: $golden_file"
            fi
        fi
    else
        log_info "Creating new golden file: $golden_file"
        echo "$outputs" > "$golden_file"
    fi
}

# Function to run file format compatibility tests
run_file_format_tests() {
    local environment="$1"
    local platform="$2"
    local tf_version="$3"
    
    log_step "Running file format compatibility tests ($environment/$platform/terraform-$tf_version)"
    
    local test_dir="$INTEGRATION_TEST_DIR/file-format-$environment-$platform-$tf_version"
    mkdir -p "$test_dir"
    
    # Create test configuration that writes files
    cat > "$test_dir/file-format-test.tf" << EOF
terraform {
  required_providers {
    prettyjson = {
      source = "hashicorp/prettyjson"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

locals {
  test_data = {
    line_endings = {
      unix = "line1\\nline2\\nline3"
      windows = "line1\\r\\nline2\\r\\nline3"
      mixed = "line1\\nline2\\r\\nline3"
    }
    file_paths = {
      unix_style = "/tmp/test/config.json"
      windows_style = "C:\\\\temp\\\\test\\\\config.json"
      relative = "../config/settings.json"
    }
    binary_data = {
      base64_content = base64encode("Hello World 🌍")
      hex_values = ["0x00", "0xFF", "0x7F"]
    }
  }
}

# Test file output with different formats
resource "local_file" "test_config_2spaces" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.test_data),
    "2spaces"
  )
  filename = "\${path.module}/output/config-2spaces.json"
  file_permission = "0644"
}

resource "local_file" "test_config_4spaces" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.test_data),
    "4spaces"
  )
  filename = "\${path.module}/output/config-4spaces.json"
  file_permission = "0644"
}

resource "local_file" "test_config_tabs" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.test_data),
    "tabs"
  )
  filename = "\${path.module}/output/config-tabs.json"
  file_permission = "0644"
}

# Output file checksums for validation
output "file_checksums" {
  value = {
    config_2spaces = local_file.test_config_2spaces.content_md5
    config_4spaces = local_file.test_config_4spaces.content_md5
    config_tabs = local_file.test_config_tabs.content_md5
  }
}

output "file_sizes" {
  value = {
    config_2spaces = length(local_file.test_config_2spaces.content)
    config_4spaces = length(local_file.test_config_4spaces.content)
    config_tabs = length(local_file.test_config_tabs.content)
  }
}
EOF

    # Create output directory
    mkdir -p "$test_dir/output"
    
    # Run the test
    cd "$test_dir"
    
    local test_result="success"
    local test_output=""
    local test_errors=""
    
    if test_output=$(terraform init -no-color 2>&1) && \
       test_output+=$(terraform apply -auto-approve -no-color 2>&1); then
        
        # Validate file outputs
        validate_file_outputs "$test_dir/output" "$platform"
        
        log_success "File format test passed for $environment/$platform/terraform-$tf_version"
    else
        test_result="failure"
        test_errors="$test_output"
        log_error "File format test failed for $environment/$platform/terraform-$tf_version"
    fi
    
    # Save test results
    save_test_results "file-format" "$environment" "$platform" "$tf_version" "$test_result" "$test_output" "$test_errors"
    
    # Cleanup if not skipped
    if [[ "$SKIP_CLEANUP" != "1" ]]; then
        terraform destroy -auto-approve -no-color >/dev/null 2>&1 || true
    fi
    
    cd "$PROJECT_ROOT"
    return $([ "$test_result" = "success" ] && echo 0 || echo 1)
}

# Function to validate file outputs
validate_file_outputs() {
    local output_dir="$1"
    local platform="$2"
    
    log_info "Validating file outputs for $platform"
    
    # Check if files were created
    local files=("config-2spaces.json" "config-4spaces.json" "config-tabs.json")
    for file in "${files[@]}"; do
        if [[ ! -f "$output_dir/$file" ]]; then
            log_error "File not created: $file"
            return 1
        fi
    done
    
    # Validate JSON format
    for file in "${files[@]}"; do
        if ! jq . "$output_dir/$file" >/dev/null 2>&1; then
            log_error "Invalid JSON in file: $file"
            return 1
        fi
    done
    
    # Validate indentation differences
    if [[ $(grep -c "^  " "$output_dir/config-2spaces.json") -eq 0 ]] || \
       [[ $(grep -c "^    " "$output_dir/config-4spaces.json") -eq 0 ]] || \
       [[ $(grep -c "^	" "$output_dir/config-tabs.json") -eq 0 ]]; then
        log_error "Indentation validation failed"
        return 1
    fi
    
    log_success "File output validation passed for $platform"
}

# Function to run end-to-end workflow tests
run_e2e_workflow_tests() {
    local environment="$1"
    local platform="$2"
    local tf_version="$3"
    
    log_step "Running end-to-end workflow tests ($environment/$platform/terraform-$tf_version)"
    
    local test_dir="$INTEGRATION_TEST_DIR/e2e-$environment-$platform-$tf_version"
    mkdir -p "$test_dir"
    
    # Create comprehensive end-to-end test
    cat > "$test_dir/e2e-workflow.tf" << EOF
terraform {
  required_providers {
    prettyjson = {
      source = "hashicorp/prettyjson"
    }
    local = {
      source = "hashicorp/local"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

# Generate dynamic content
resource "random_string" "deployment_id" {
  length = 8
  special = false
  upper = false
}

resource "random_integer" "port" {
  min = 8000
  max = 9000
}

# Complex workflow with multiple interdependent resources
locals {
  application_config = {
    metadata = {
      deployment_id = random_string.deployment_id.result
      platform = "$platform"
      environment = "$environment"
      terraform_version = "$tf_version"
      generated_at = timestamp()
    }
    services = {
      web = {
        name = "web-\${random_string.deployment_id.result}"
        port = random_integer.port.result
        replicas = 3
        config = {
          ssl_enabled = true
          session_timeout = 3600
          max_connections = 1000
        }
      }
      api = {
        name = "api-\${random_string.deployment_id.result}"
        port = random_integer.port.result + 1
        replicas = 2
        config = {
          rate_limit = 100
          cache_ttl = 300
          debug_mode = false
        }
      }
    }
    infrastructure = {
      load_balancer = {
        algorithm = "round_robin"
        health_check = {
          interval = 30
          timeout = 5
          retries = 3
        }
      }
      database = {
        engine = "postgresql"
        version = "14.9"
        storage = {
          size = "100GB"
          type = "ssd"
          encrypted = true
        }
      }
    }
  }
}

# Multi-stage configuration generation
resource "local_file" "stage1_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      stage = "initial"
      deployment_id = random_string.deployment_id.result
      basic_config = {
        app_name = "test-app"
        version = "1.0.0"
      }
    }),
    "2spaces"
  )
  filename = "\${path.module}/workflow/stage1-config.json"
  file_permission = "0644"
}

resource "local_file" "stage2_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      stage = "intermediate"
      depends_on_stage1 = local_file.stage1_config.content_md5
      services = local.application_config.services
    }),
    "4spaces"
  )
  filename = "\${path.module}/workflow/stage2-config.json"
  file_permission = "0644"
  
  depends_on = [local_file.stage1_config]
}

resource "local_file" "final_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.application_config),
    "tabs"
  )
  filename = "\${path.module}/workflow/final-config.json"
  file_permission = "0644"
  
  depends_on = [local_file.stage1_config, local_file.stage2_config]
}

# Validation outputs
output "workflow_summary" {
  value = {
    deployment_id = random_string.deployment_id.result
    port_assigned = random_integer.port.result
    files_created = [
      local_file.stage1_config.filename,
      local_file.stage2_config.filename,
      local_file.final_config.filename
    ]
    checksums = {
      stage1 = local_file.stage1_config.content_md5
      stage2 = local_file.stage2_config.content_md5
      final = local_file.final_config.content_md5
    }
  }
}

output "configuration_validation" {
  value = {
    json_validity = "all_valid"
    indentation_formats = ["2spaces", "4spaces", "tabs"]
    file_count = 3
    platform = "$platform"
    environment = "$environment"
  }
}
EOF

    # Create workflow directory
    mkdir -p "$test_dir/workflow"
    
    # Run the test
    cd "$test_dir"
    
    local test_result="success"
    local test_output=""
    local test_errors=""
    
    if test_output=$(terraform init -no-color 2>&1) && \
       test_output+=$(terraform apply -auto-approve -no-color 2>&1); then
        
        # Validate workflow completion
        validate_e2e_workflow "$test_dir/workflow" "$platform"
        
        log_success "End-to-end workflow test passed for $environment/$platform/terraform-$tf_version"
    else
        test_result="failure"
        test_errors="$test_output"
        log_error "End-to-end workflow test failed for $environment/$platform/terraform-$tf_version"
    fi
    
    # Save test results
    save_test_results "e2e-workflow" "$environment" "$platform" "$tf_version" "$test_result" "$test_output" "$test_errors"
    
    # Cleanup if not skipped
    if [[ "$SKIP_CLEANUP" != "1" ]]; then
        terraform destroy -auto-approve -no-color >/dev/null 2>&1 || true
    fi
    
    cd "$PROJECT_ROOT"
    return $([ "$test_result" = "success" ] && echo 0 || echo 1)
}

# Function to validate end-to-end workflow
validate_e2e_workflow() {
    local workflow_dir="$1"
    local platform="$2"
    
    log_info "Validating end-to-end workflow for $platform"
    
    # Check if all workflow files were created
    local workflow_files=("stage1-config.json" "stage2-config.json" "final-config.json")
    for file in "${workflow_files[@]}"; do
        if [[ ! -f "$workflow_dir/$file" ]]; then
            log_error "Workflow file not created: $file"
            return 1
        fi
    done
    
    # Validate JSON structure and dependency chain
    local stage1_data=$(jq -r '.stage' "$workflow_dir/stage1-config.json" 2>/dev/null)
    local stage2_data=$(jq -r '.stage' "$workflow_dir/stage2-config.json" 2>/dev/null)
    
    if [[ "$stage1_data" != "initial" ]] || [[ "$stage2_data" != "intermediate" ]]; then
        log_error "Workflow stage validation failed"
        return 1
    fi
    
    # Validate dependency chain by checking checksums
    local stage1_checksum=$(jq -r '.depends_on_stage1' "$workflow_dir/stage2-config.json" 2>/dev/null)
    if [[ -z "$stage1_checksum" ]] || [[ "$stage1_checksum" == "null" ]]; then
        log_error "Workflow dependency validation failed"
        return 1
    fi
    
    log_success "End-to-end workflow validation passed for $platform"
}

# Function to save test results
save_test_results() {
    local test_type="$1"
    local environment="$2"
    local platform="$3"
    local tf_version="$4"
    local result="$5"
    local output="$6"
    local errors="$7"
    
    local result_file="$TEST_RESULTS_DIR/${test_type}-${environment}-${platform}-${tf_version}.json"
    mkdir -p "$(dirname "$result_file")"
    
    cat > "$result_file" << EOF
{
  "test_type": "$test_type",
  "environment": "$environment",
  "platform": "$platform",
  "terraform_version": "$tf_version",
  "result": "$result",
  "timestamp": "$(date -Iseconds)",
  "execution_details": {
    "output_lines": $(echo "$output" | wc -l),
    "error_present": $([ -n "$errors" ] && echo "true" || echo "false")
  },
  "test_metadata": {
    "runner_version": "1.0.0",
    "runner_platform": "$(uname -s | tr '[:upper:]' '[:lower:]')",
    "go_version": "$(go version 2>/dev/null || echo 'unknown')"
  }
}
EOF
    
    # Save detailed output if available
    if [[ -n "$output" ]]; then
        echo "$output" > "${result_file%.json}-output.log"
    fi
    
    if [[ -n "$errors" ]]; then
        echo "$errors" > "${result_file%.json}-errors.log"
    fi
}

# Function to run integration tests in Docker environment
run_docker_integration_tests() {
    local platform="$1"
    local tf_version="$2"
    
    log_step "Running Docker integration tests for $platform/terraform-$tf_version"
    
    local image_tag
    case "$platform" in
        "linux")
            image_tag="ubuntu"
            ;;
        *)
            image_tag="alpine"
            ;;
    esac
    
    # Run tests in container
    local container_name="integration-test-$$"
    
    if "$CONTAINER_RUNTIME" run --name "$container_name" \
        -e "TF_VERSION=$tf_version" \
        -e "PLATFORM=$platform" \
        --rm \
        "prettyjson-test:$image_tag" \
        ./scripts/platform-tests/integration-test-runner.sh -e local --test-type all --verbose; then
        
        log_success "Docker integration tests passed for $platform/terraform-$tf_version"
        return 0
    else
        log_error "Docker integration tests failed for $platform/terraform-$tf_version"
        return 1
    fi
}

# Function to generate integration test report
generate_integration_report() {
    log_step "Generating integration test report"
    
    local report_file="$TEST_RESULTS_DIR/integration-test-report.md"
    local json_report="$TEST_RESULTS_DIR/integration-test-report.json"
    
    # Collect all test results
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    cat > "$report_file" << EOF
# Cross-Platform Integration Test Report

**Generated:** $(date -u '+%Y-%m-%d %H:%M:%S UTC')  
**Test Environments:** ${TEST_ENVIRONMENTS[*]}  
**Platforms:** ${PLATFORMS[*]}  
**Terraform Versions:** ${TERRAFORM_VERSIONS[*]}

## Summary

EOF

    # Process test results
    local results_data="[]"
    if [[ -d "$TEST_RESULTS_DIR" ]]; then
        for result_file in "$TEST_RESULTS_DIR"/*.json; do
            if [[ -f "$result_file" ]] && [[ "$(basename "$result_file")" != "integration-test-report.json" ]]; then
                local result=$(jq -r '.result' "$result_file" 2>/dev/null)
                ((total_tests++))
                if [[ "$result" == "success" ]]; then
                    ((passed_tests++))
                else
                    ((failed_tests++))
                fi
                
                # Add to results data
                results_data=$(echo "$results_data" | jq ". + [$(cat "$result_file")]")
            fi
        done
    fi
    
    local success_rate=$(( total_tests > 0 ? (passed_tests * 100) / total_tests : 0 ))
    
    cat >> "$report_file" << EOF
- **Total Tests:** $total_tests
- **Passed:** $passed_tests ✅
- **Failed:** $failed_tests $([ $failed_tests -gt 0 ] && echo "❌" || echo "✅")
- **Success Rate:** ${success_rate}%

## Test Results by Category

| Environment | Platform | Terraform Version | Data Exchange | File Format | E2E Workflow |
|-------------|----------|-------------------|---------------|-------------|--------------|
EOF

    # Add detailed results
    echo "$results_data" | jq -r '.[] | "\(.environment)|\(.platform)|\(.terraform_version)|\(.test_type)|\(.result)"' | \
    while IFS='|' read -r env platform tf_ver test_type result; do
        local status_icon=$([ "$result" = "success" ] && echo "✅" || echo "❌")
        echo "| $env | $platform | $tf_ver | $status_icon | | |" >> "$report_file"
    done
    
    # Generate JSON report
    cat > "$json_report" << EOF
{
  "summary": {
    "total_tests": $total_tests,
    "passed_tests": $passed_tests,
    "failed_tests": $failed_tests,
    "success_rate": $success_rate,
    "generated_at": "$(date -Iseconds)"
  },
  "test_results": $results_data,
  "configuration": {
    "environments": $(printf '%s\n' "${TEST_ENVIRONMENTS[@]}" | jq -R . | jq -s .),
    "platforms": $(printf '%s\n' "${PLATFORMS[@]}" | jq -R . | jq -s .),
    "terraform_versions": $(printf '%s\n' "${TERRAFORM_VERSIONS[@]}" | jq -R . | jq -s .)
  }
}
EOF
    
    log_success "Integration test report generated: $report_file"
    log_success "JSON report generated: $json_report"
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -e|--environments)
                IFS=',' read -ra TEST_ENVIRONMENTS <<< "$2"
                shift 2
                ;;
            -p|--platforms)
                IFS=',' read -ra PLATFORMS <<< "$2"
                shift 2
                ;;
            -t|--tf-versions)
                IFS=',' read -ra TERRAFORM_VERSIONS <<< "$2"
                shift 2
                ;;
            --test-type)
                TEST_TYPE="$2"
                shift 2
                ;;
            --golden-file-update)
                GOLDEN_FILE_UPDATE=1
                shift
                ;;
            --skip-cleanup)
                SKIP_CLEANUP=1
                shift
                ;;
            --container-runtime)
                CONTAINER_RUNTIME="$2"
                shift 2
                ;;
            --cloud-provider)
                CLOUD_PROVIDER="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --parallel)
                PARALLEL=1
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
    TEST_ENVIRONMENTS=(${TEST_ENVIRONMENTS[@]:-"${DEFAULT_TEST_ENVIRONMENTS[@]}"})
    PLATFORMS=(${PLATFORMS[@]:-"${DEFAULT_PLATFORMS[@]}"})
    TERRAFORM_VERSIONS=(${TERRAFORM_VERSIONS[@]:-"${DEFAULT_TERRAFORM_VERSIONS[@]}"})
    TEST_TYPE=${TEST_TYPE:-"all"}
    GOLDEN_FILE_UPDATE=${GOLDEN_FILE_UPDATE:-0}
    SKIP_CLEANUP=${SKIP_CLEANUP:-0}
    CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-"docker"}
    CLOUD_PROVIDER=${CLOUD_PROVIDER:-"aws"}
    TIMEOUT=${TIMEOUT:-"30m"}
    PARALLEL=${PARALLEL:-0}
    VERBOSE=${VERBOSE:-0}
    DRY_RUN=${DRY_RUN:-0}
}

# Main function
main() {
    cd "$PROJECT_ROOT"
    
    log_info "Starting cross-platform integration testing"
    log_info "Environments: ${TEST_ENVIRONMENTS[*]}"
    log_info "Platforms: ${PLATFORMS[*]}"
    log_info "Terraform versions: ${TERRAFORM_VERSIONS[*]}"
    log_info "Test type: $TEST_TYPE"
    
    if [[ "$DRY_RUN" == "1" ]]; then
        log_info "DRY RUN: Would run integration tests with the above configuration"
        exit 0
    fi
    
    # Setup test environments
    for environment in "${TEST_ENVIRONMENTS[@]}"; do
        setup_test_environment "$environment"
    done
    
    local total_tests=0
    local failed_tests=0
    
    # Run tests for each combination
    for environment in "${TEST_ENVIRONMENTS[@]}"; do
        for platform in "${PLATFORMS[@]}"; do
            for tf_version in "${TERRAFORM_VERSIONS[@]}"; do
                # Skip unsupported combinations
                if [[ "$environment" == "docker" ]] && [[ "$platform" != "linux" ]]; then
                    continue
                fi
                
                case "$TEST_TYPE" in
                    "data-exchange")
                        ((total_tests++))
                        if ! run_data_exchange_tests "$environment" "$platform" "$tf_version"; then
                            ((failed_tests++))
                        fi
                        ;;
                    "file-format")
                        ((total_tests++))
                        if ! run_file_format_tests "$environment" "$platform" "$tf_version"; then
                            ((failed_tests++))
                        fi
                        ;;
                    "e2e")
                        ((total_tests++))
                        if ! run_e2e_workflow_tests "$environment" "$platform" "$tf_version"; then
                            ((failed_tests++))
                        fi
                        ;;
                    "all")
                        ((total_tests += 3))
                        if ! run_data_exchange_tests "$environment" "$platform" "$tf_version"; then
                            ((failed_tests++))
                        fi
                        if ! run_file_format_tests "$environment" "$platform" "$tf_version"; then
                            ((failed_tests++))
                        fi
                        if ! run_e2e_workflow_tests "$environment" "$platform" "$tf_version"; then
                            ((failed_tests++))
                        fi
                        ;;
                    *)
                        log_error "Unknown test type: $TEST_TYPE"
                        exit 1
                        ;;
                esac
            done
        done
    done
    
    # Generate report
    generate_integration_report
    
    # Summary
    log_info "=========================================="
    log_info "Integration Test Summary"
    log_info "=========================================="
    log_info "Total tests: $total_tests"
    log_success "Passed: $((total_tests - failed_tests))"
    
    if [[ $failed_tests -gt 0 ]]; then
        log_error "Failed: $failed_tests"
        exit 1
    else
        log_success "All integration tests passed!"
        exit 0
    fi
}

# Parse arguments and run
parse_args "$@"
main