terraform {
  required_providers {
    prettyjson = {
      source = "hashicorp/prettyjson"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Generate test data for performance examples
resource "random_id" "large_dataset_id" {
  byte_length = 8
}

# Performance consideration examples and best practices

# Example 1: Large configuration file optimization
locals {
  # Simulate large configuration with many services
  large_service_config = {
    metadata = {
      generated_at   = timestamp()
      config_version = "v2.1.0"
      total_services = 50
      dataset_id     = random_id.large_dataset_id.hex
    }

    # Generate 50 simulated microservices configuration
    services = {
      for i in range(50) : "service-${format("%02d", i)}" => {
        name     = "microservice-${format("%02d", i)}"
        port     = 8000 + i
        replicas = i < 10 ? 3 : (i < 30 ? 2 : 1) # Higher replicas for first 10, medium for next 20
        resources = {
          cpu_limit    = "${i < 10 ? 1000 : 500}m"
          memory_limit = "${i < 10 ? 1024 : 512}Mi"
          storage      = "${(i + 1) * 100}Mi"
        }
        environment = {
          NODE_ENV     = "production"
          LOG_LEVEL    = i < 10 ? "debug" : "info"
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

    # Large monitoring configuration
    monitoring = {
      metrics = {
        for i in range(20) : "metric-${i}" => {
          name        = "custom_metric_${i}"
          type        = i % 3 == 0 ? "counter" : (i % 3 == 1 ? "gauge" : "histogram")
          description = "Performance metric ${i} for monitoring"
          labels      = ["environment", "service", "instance"]
          buckets     = i % 3 == 2 ? [0.1, 0.5, 1, 2.5, 5, 10] : null
        }
      }
      alerts = {
        for i in range(15) : "alert-${i}" => {
          name        = "alert_${i}"
          condition   = "metric_${i} > ${(i + 1) * 100}"
          severity    = i < 5 ? "critical" : (i < 10 ? "warning" : "info")
          description = "Alert ${i} for performance monitoring"
          runbook_url = "https://runbooks.company.com/alert-${i}"
        }
      }
    }
  }

  # Optimized smaller configuration for frequent updates
  optimized_config = {
    metadata = {
      generated_at = timestamp()
      config_type  = "optimized"
    }
    critical_services = {
      # Only include critical services for performance
      for k, v in local.large_service_config.services : k => {
        name     = v.name
        port     = v.port
        replicas = v.replicas
        # Exclude detailed environment and health_check for performance
      } if v.replicas >= 2 # Only services with 2+ replicas
    }
  }
}

# Performance Best Practice 1: Separate large and small configurations
resource "local_file" "large_config_optimized" {
  # Use 4-space indentation for large files (better readability, slightly larger size)
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.large_service_config),
    "4spaces"
  )
  filename        = "${path.module}/configs/large-services-config.json"
  file_permission = "0644"
}

resource "local_file" "optimized_config_compact" {
  # Use 2-space indentation for frequently accessed smaller files
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.optimized_config),
    "2spaces"
  )
  filename        = "${path.module}/configs/optimized-services-config.json"
  file_permission = "0644"
}

# Performance Best Practice 2: Environment-specific optimization
resource "local_file" "dev_config_minimal" {
  # Minimal development configuration for faster loading
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      metadata = local.large_service_config.metadata
      services = {
        # Only first 5 services for development
        for k, v in local.large_service_config.services : k => {
          name     = v.name
          port     = v.port
          replicas = 1 # Always 1 replica in dev
          resources = {
            cpu_limit    = "250m" # Reduced resources for dev
            memory_limit = "256Mi"
          }
          environment = {
            NODE_ENV   = "development"
            LOG_LEVEL  = "debug"
            SERVICE_ID = v.environment.SERVICE_ID
          }
        } if tonumber(split("-", k)[1]) < 5 # Only first 5 services
      }
    }),
    "2spaces"
  )
  filename        = "${path.module}/configs/dev-minimal-config.json"
  file_permission = "0644"
}

# Performance Best Practice 3: Selective data inclusion based on use case
resource "local_file" "monitoring_only_config" {
  # Separate monitoring configuration for performance monitoring tools
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      metadata      = local.large_service_config.metadata
      monitoring    = local.large_service_config.monitoring
      service_count = length(local.large_service_config.services)
      # Include only service names and ports for monitoring
      service_endpoints = {
        for k, v in local.large_service_config.services : k => {
          name = v.name
          port = v.port
        }
      }
    }),
    "2spaces"
  )
  filename        = "${path.module}/configs/monitoring-config.json"
  file_permission = "0644"
}

# Performance Best Practice 4: Conditional resource creation
resource "local_file" "conditional_large_config" {
  # Only create large configuration file in production
  count = var.environment == "production" ? 1 : 0

  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.large_service_config),
    "tabs" # Tabs can be more compact for very large files
  )
  filename        = "${path.module}/configs/production-full-config.json"
  file_permission = "0644"
}

# Performance Best Practice 5: Chunked configuration files
resource "local_file" "service_chunks" {
  # Split services into chunks of 10 for better performance
  for_each = {
    for i in range(5) : "chunk-${i}" => {
      start = i * 10
      end   = min((i + 1) * 10, 50)
    }
  }

  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      metadata = {
        chunk_id       = each.key
        services_range = "${each.value.start}-${each.value.end - 1}"
        total_services = each.value.end - each.value.start
        generated_at   = timestamp()
      }
      services = {
        for i in range(each.value.start, each.value.end) :
        "service-${format("%02d", i)}" => local.large_service_config.services["service-${format("%02d", i)}"]
      }
    }),
    "2spaces"
  )
  filename        = "${path.module}/chunks/services-${each.key}.json"
  file_permission = "0644"
}

# Performance Best Practice 6: Lazy loading configuration
resource "local_file" "lazy_loading_index" {
  # Create an index file for lazy loading of configurations
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      metadata = {
        index_version = "1.0"
        generated_at  = timestamp()
        total_configs = 8 # Total number of config files
      }
      configurations = {
        large_config = {
          file            = "large-services-config.json"
          size            = "large"
          use_case        = "complete service configuration"
          recommended_for = ["production", "staging"]
        }
        optimized_config = {
          file            = "optimized-services-config.json"
          size            = "medium"
          use_case        = "critical services only"
          recommended_for = ["frequent updates", "monitoring"]
        }
        dev_config = {
          file            = "dev-minimal-config.json"
          size            = "small"
          use_case        = "development environment"
          recommended_for = ["development", "testing"]
        }
        monitoring_config = {
          file            = "monitoring-config.json"
          size            = "medium"
          use_case        = "monitoring and alerting"
          recommended_for = ["observability tools"]
        }
      }
      chunks = {
        for i in range(5) : "chunk-${i}" => {
          file           = "chunks/services-chunk-${i}.json"
          services_range = "${i * 10}-${min((i + 1) * 10, 50) - 1}"
          use_case       = "partial service configuration"
        }
      }
      performance_notes = {
        file_size_optimization = "Use 2spaces for small files, 4spaces for large files, tabs for very large files"
        conditional_creation   = "Create large files only when needed (e.g., production environment)"
        chunking_strategy      = "Split large configurations into smaller chunks for better performance"
        lazy_loading           = "Use index files to load configurations on demand"
        selective_inclusion    = "Include only necessary data for specific use cases"
      }
    }),
    "2spaces"
  )
  filename        = "${path.module}/index.json"
  file_permission = "0644"
}