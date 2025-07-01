terraform {
  required_providers {
    prettyjson = {
      source = "local/prettyjson"
    }
  }
}

# Performance test configuration
locals {
  # Generate large dataset for performance testing
  large_service_config = {
    metadata = {
      generated_at   = timestamp()
      config_version = "v2.1.0"
      total_services = 20 # Reduced for testing
      test_id        = substr(uuid(), 0, 8)
    }

    # Generate 20 simulated microservices for performance testing
    services = {
      for i in range(20) : "service-${format("%02d", i)}" => {
        name     = "microservice-${format("%02d", i)}"
        port     = 8000 + i
        replicas = i < 5 ? 3 : (i < 10 ? 2 : 1)
        resources = {
          cpu_limit    = "${i < 5 ? 1000 : 500}m"
          memory_limit = "${i < 5 ? 1024 : 512}Mi"
          storage      = "${(i + 1) * 100}Mi"
        }
        environment = {
          NODE_ENV     = "production"
          LOG_LEVEL    = i < 5 ? "debug" : "info"
          SERVICE_ID   = format("%02d", i)
          DATABASE_URL = "postgres://db-cluster:5432/service_${format("%02d", i)}"
        }
        health_check = {
          path                = "/health"
          interval_seconds    = 30
          timeout_seconds     = 5
          healthy_threshold   = 2
          unhealthy_threshold = 3
        }
        dependencies = i > 0 ? ["service-${format("%02d", i - 1)}"] : []
      }
    }

    # Monitoring configuration
    monitoring = {
      metrics = {
        for i in range(10) : "metric-${i}" => {
          name        = "custom_metric_${i}"
          type        = i % 3 == 0 ? "counter" : (i % 3 == 1 ? "gauge" : "histogram")
          description = "Performance metric ${i} for monitoring"
          labels      = ["environment", "service", "instance"]
          buckets     = i % 3 == 2 ? [0.1, 0.5, 1, 2.5, 5, 10] : null
        }
      }
      alerts = {
        for i in range(5) : "alert-${i}" => {
          name        = "alert_${i}"
          condition   = "metric_${i} > ${(i + 1) * 100}"
          severity    = i < 2 ? "critical" : (i < 4 ? "warning" : "info")
          description = "Alert ${i} for performance monitoring"
          runbook_url = "https://runbooks.company.com/alert-${i}"
        }
      }
    }
  }

  # Optimized smaller configuration
  optimized_config = {
    metadata = local.large_service_config.metadata
    critical_services = {
      # Only include critical services
      for k, v in local.large_service_config.services : k => {
        name     = v.name
        port     = v.port
        replicas = v.replicas
      } if v.replicas >= 2
    }
  }

  # Development minimal configuration
  dev_config = {
    metadata = local.large_service_config.metadata
    services = {
      # Only first 3 services for development
      for k, v in local.large_service_config.services : k => {
        name     = v.name
        port     = v.port
        replicas = 1
        resources = {
          cpu_limit    = "250m"
          memory_limit = "256Mi"
        }
        environment = {
          NODE_ENV   = "development"
          LOG_LEVEL  = "debug"
          SERVICE_ID = v.environment.SERVICE_ID
        }
      } if tonumber(split("-", k)[1]) < 3
    }
  }

  # Format configurations with performance considerations
  large_config_formatted = provider::prettyjson::jsonprettyprint(
    jsonencode(local.large_service_config),
    "4spaces" # 4spaces for large files
  )

  optimized_config_formatted = provider::prettyjson::jsonprettyprint(
    jsonencode(local.optimized_config),
    "2spaces" # 2spaces for smaller files
  )

  dev_config_formatted = provider::prettyjson::jsonprettyprint(
    jsonencode(local.dev_config),
    "2spaces" # 2spaces for dev
  )

  monitoring_config_formatted = provider::prettyjson::jsonprettyprint(
    jsonencode({
      metadata      = local.large_service_config.metadata
      monitoring    = local.large_service_config.monitoring
      service_count = length(local.large_service_config.services)
      service_endpoints = {
        for k, v in local.large_service_config.services : k => {
          name = v.name
          port = v.port
        }
      }
    }),
    "2spaces"
  )

  # Performance test with tabs for largest config
  tabs_config_formatted = provider::prettyjson::jsonprettyprint(
    jsonencode(local.large_service_config),
    "tab" # Tab for most compact format
  )
}

# Create directory structure
resource "terraform_data" "create_performance_dirs" {
  provisioner "local-exec" {
    command = "mkdir -p configs chunks performance-test"
  }
}

# Performance test 1: Large configuration with timing
resource "terraform_data" "write_large_config" {
  triggers_replace = [local.large_config_formatted]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Performance Test: Large Configuration ==="
      echo "Starting large config generation at $(date)"
      start_time=$(date +%s%N)
      
      cat > configs/large-services-config.json << 'EOF'
${local.large_config_formatted}
EOF
      
      end_time=$(date +%s%N)
      duration=$((($end_time - $start_time) / 1000000))
      echo "Large config written in $duration ms"
      echo "File size: $(wc -c < configs/large-services-config.json) bytes"
    EOT
  }

  depends_on = [terraform_data.create_performance_dirs]
}

# Performance test 2: Optimized configuration
resource "terraform_data" "write_optimized_config" {
  triggers_replace = [local.optimized_config_formatted]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Performance Test: Optimized Configuration ==="
      start_time=$(date +%s%N)
      
      cat > configs/optimized-services-config.json << 'EOF'
${local.optimized_config_formatted}
EOF
      
      end_time=$(date +%s%N)
      duration=$((($end_time - $start_time) / 1000000))
      echo "Optimized config written in $duration ms"
      echo "File size: $(wc -c < configs/optimized-services-config.json) bytes"
    EOT
  }

  depends_on = [terraform_data.create_performance_dirs]
}

# Performance test 3: Development configuration
resource "terraform_data" "write_dev_config" {
  triggers_replace = [local.dev_config_formatted]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Performance Test: Development Configuration ==="
      start_time=$(date +%s%N)
      
      cat > configs/dev-minimal-config.json << 'EOF'
${local.dev_config_formatted}
EOF
      
      end_time=$(date +%s%N)
      duration=$((($end_time - $start_time) / 1000000))
      echo "Dev config written in $duration ms"
      echo "File size: $(wc -c < configs/dev-minimal-config.json) bytes"
    EOT
  }

  depends_on = [terraform_data.create_performance_dirs]
}

# Performance test 4: Monitoring-only configuration
resource "terraform_data" "write_monitoring_config" {
  triggers_replace = [local.monitoring_config_formatted]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Performance Test: Monitoring Configuration ==="
      start_time=$(date +%s%N)
      
      cat > configs/monitoring-config.json << 'EOF'
${local.monitoring_config_formatted}
EOF
      
      end_time=$(date +%s%N)
      duration=$((($end_time - $start_time) / 1000000))
      echo "Monitoring config written in $duration ms"
      echo "File size: $(wc -c < configs/monitoring-config.json) bytes"
    EOT
  }

  depends_on = [terraform_data.create_performance_dirs]
}

# Performance test 5: Tabs format comparison
resource "terraform_data" "write_tabs_config" {
  triggers_replace = [local.tabs_config_formatted]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Performance Test: Tabs Format ==="
      start_time=$(date +%s%N)
      
      cat > configs/large-services-tabs.json << 'EOF'
${local.tabs_config_formatted}
EOF
      
      end_time=$(date +%s%N)
      duration=$((($end_time - $start_time) / 1000000))
      echo "Tabs config written in $duration ms"
      echo "File size: $(wc -c < configs/large-services-tabs.json) bytes"
    EOT
  }

  depends_on = [terraform_data.create_performance_dirs]
}

# Chunked configuration for performance
resource "terraform_data" "write_service_chunks" {
  count = 4 # Split 20 services into 4 chunks of 5

  triggers_replace = [
    provider::prettyjson::jsonprettyprint(
      jsonencode({
        metadata = {
          chunk_id       = "chunk-${count.index}"
          services_range = "${count.index * 5}-${min((count.index + 1) * 5, 20) - 1}"
          total_services = min(5, 20 - count.index * 5)
          generated_at   = timestamp()
        }
        services = {
          for i in range(count.index * 5, min((count.index + 1) * 5, 20)) :
          "service-${format("%02d", i)}" => local.large_service_config.services["service-${format("%02d", i)}"]
        }
      }),
      "2spaces"
    )
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Performance Test: Chunk ${count.index} ==="
      start_time=$(date +%s%N)
      
      cat > chunks/services-chunk-${count.index}.json << 'EOF'
${provider::prettyjson::jsonprettyprint(
    jsonencode({
      metadata = {
        chunk_id       = "chunk-${count.index}"
        services_range = "${count.index * 5}-${min((count.index + 1) * 5, 20) - 1}"
        total_services = min(5, 20 - count.index * 5)
        generated_at   = timestamp()
      }
      services = {
        for i in range(count.index * 5, min((count.index + 1) * 5, 20)) :
        "service-${format("%02d", i)}" => local.large_service_config.services["service-${format("%02d", i)}"]
      }
    }),
    "2spaces"
)}
EOF
      
      end_time=$(date +%s%N)
      duration=$((($end_time - $start_time) / 1000000))
      echo "Chunk ${count.index} written in $duration ms"
      echo "Chunk ${count.index} file size: $(wc -c < chunks/services-chunk-${count.index}.json) bytes"
    EOT
}

depends_on = [terraform_data.create_performance_dirs]
}

# Performance summary and analysis
resource "terraform_data" "performance_analysis" {
  triggers_replace = [
    terraform_data.write_large_config.id,
    terraform_data.write_optimized_config.id,
    terraform_data.write_dev_config.id,
    terraform_data.write_monitoring_config.id,
    terraform_data.write_tabs_config.id,
    join(",", terraform_data.write_service_chunks[*].id)
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Performance Analysis Summary ==="
      echo "Configuration files created:"
      find configs chunks -name "*.json" -type f | sort
      echo ""
      echo "File size comparison:"
      echo "Large (4spaces): $(wc -c < configs/large-services-config.json) bytes"
      echo "Large (tabs):    $(wc -c < configs/large-services-tabs.json) bytes" 
      echo "Optimized:       $(wc -c < configs/optimized-services-config.json) bytes"
      echo "Development:     $(wc -c < configs/dev-minimal-config.json) bytes"
      echo "Monitoring:      $(wc -c < configs/monitoring-config.json) bytes"
      echo ""
      echo "Chunk sizes:"
      for chunk in chunks/services-chunk-*.json; do
        if [ -f "$chunk" ]; then
          echo "$(basename "$chunk"): $(wc -c < "$chunk") bytes"
        fi
      done
      echo ""
      echo "Size reduction analysis:"
      large_size=$(wc -c < configs/large-services-config.json)
      optimized_size=$(wc -c < configs/optimized-services-config.json)
      dev_size=$(wc -c < configs/dev-minimal-config.json)
      tabs_size=$(wc -c < configs/large-services-tabs.json)
      
      if [ "$large_size" -gt 0 ]; then
        opt_reduction=$(awk "BEGIN {printf \"%.1f\", (1 - $optimized_size/$large_size) * 100}")
        dev_reduction=$(awk "BEGIN {printf \"%.1f\", (1 - $dev_size/$large_size) * 100}")
        tabs_reduction=$(awk "BEGIN {printf \"%.1f\", (1 - $tabs_size/$large_size) * 100}")
        
        echo "Optimized vs Large: $opt_reduction% size reduction"
        echo "Dev vs Large: $dev_reduction% size reduction"
        echo "Tabs vs 4spaces: $tabs_reduction% size reduction"
      fi
      echo ""
      echo "JSON validation:"
      if command -v jq >/dev/null 2>&1; then
        for file in configs/*.json chunks/*.json; do
          if [ -f "$file" ]; then
            if jq empty "$file" 2>/dev/null; then
              echo "$(basename "$file"): VALID"
            else
              echo "$(basename "$file"): INVALID"
            fi
          fi
        done
      else
        echo "jq not available for JSON validation"
      fi
    EOT
  }

  depends_on = [
    terraform_data.write_large_config,
    terraform_data.write_optimized_config,
    terraform_data.write_dev_config,
    terraform_data.write_monitoring_config,
    terraform_data.write_tabs_config,
    terraform_data.write_service_chunks
  ]
}

# Outputs
output "performance_results" {
  description = "Performance test results and metrics"
  value = {
    configurations_tested = [
      "large configuration (4spaces)",
      "large configuration (tabs)",
      "optimized configuration",
      "development configuration",
      "monitoring configuration",
      "chunked configurations"
    ]
    optimization_strategies = [
      "selective data inclusion",
      "environment-specific sizing",
      "indentation optimization",
      "configuration chunking"
    ]
    files_generated = [
      "configs/large-services-config.json",
      "configs/large-services-tabs.json",
      "configs/optimized-services-config.json",
      "configs/dev-minimal-config.json",
      "configs/monitoring-config.json",
      "chunks/services-chunk-0.json",
      "chunks/services-chunk-1.json",
      "chunks/services-chunk-2.json",
      "chunks/services-chunk-3.json"
    ]
  }
}