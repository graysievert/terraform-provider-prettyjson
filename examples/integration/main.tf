terraform {
  required_providers {
    prettyjson = {
      source = "graysievert/prettyjson"
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

# Generate unique identifiers for demonstration
resource "random_id" "deployment_id" {
  byte_length = 4
}

resource "random_string" "app_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Multi-resource integration examples with prettyjson provider
locals {
  # Configuration for microservices deployment
  microservices_config = {
    deployment_id = random_id.deployment_id.hex
    environment   = "production"
    services = {
      frontend = {
        name     = "webapp-${random_string.app_suffix.result}"
        replicas = 3
        ports    = [80, 443]
        config = {
          api_endpoint = "https://api-${random_string.app_suffix.result}.example.com"
          features = {
            auth_enabled      = true
            caching_enabled   = true
            analytics_enabled = true
          }
        }
      }
      backend = {
        name     = "api-${random_string.app_suffix.result}"
        replicas = 2
        ports    = [8080, 9090]
        config = {
          database_url = "postgresql://db-${random_string.app_suffix.result}:5432/main"
          redis_url    = "redis://cache-${random_string.app_suffix.result}:6379"
          limits = {
            max_connections = 100
            timeout_seconds = 30
            rate_limit_rpm  = 1000
          }
        }
      }
    }
    infrastructure = {
      aws_region     = "us-west-2"
      instance_types = ["t3.medium", "t3.large"]
      storage = {
        type = "gp3"
        size = "100"
        iops = 3000
      }
    }
  }

  # Kubernetes-style configuration
  k8s_config = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "app-config-${random_string.app_suffix.result}"
      namespace = "default"
      labels = {
        app        = "web-service"
        version    = "v1.0.0"
        managed_by = "terraform"
      }
    }
    data = {
      "config.json" = jsonencode({
        server = {
          port = 8080
          host = "0.0.0.0"
        }
        database = {
          host     = "postgres.default.svc.cluster.local"
          port     = 5432
          database = "webapp"
        }
        features = {
          auth_required = true
          logging_level = "info"
          metrics_port  = 9090
        }
      })
    }
  }
}

# Example 1: Multi-format configuration files for different environments
resource "local_file" "microservices_config_dev" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(merge(local.microservices_config, {
      environment = "development"
      services = {
        for service_name, service in local.microservices_config.services :
        service_name => merge(service, {
          replicas = 1 # Reduce replicas for dev
          config = merge(service.config, {
            debug_mode = true
          })
        })
      }
    })),
    "2spaces"
  )
  filename        = "${path.module}/configs/microservices-dev.json"
  file_permission = "0644"
}

resource "local_file" "microservices_config_prod" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.microservices_config),
    "4spaces"
  )
  filename        = "${path.module}/configs/microservices-prod.json"
  file_permission = "0644"
}

# Example 2: Kubernetes ConfigMap YAML generation
resource "local_file" "k8s_configmap" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.k8s_config),
    "2spaces"
  )
  filename        = "${path.module}/k8s/configmap.json"
  file_permission = "0644"
}

# Example 3: Dynamic configuration generation based on resource outputs
resource "local_file" "dynamic_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      generated_at = timestamp()
      deployment = {
        id     = random_id.deployment_id.hex
        suffix = random_string.app_suffix.result
      }
      endpoints = {
        frontend = "https://webapp-${random_string.app_suffix.result}.example.com"
        api      = "https://api-${random_string.app_suffix.result}.example.com"
        metrics  = "https://metrics-${random_string.app_suffix.result}.example.com"
      }
      resource_dependencies = {
        random_id_b64     = random_id.deployment_id.b64_url
        random_string_len = length(random_string.app_suffix.result)
      }
    }),
    "tabs"
  )
  filename        = "${path.module}/configs/dynamic-config.json"
  file_permission = "0644"
}

# Example 4: Multiple indentation formats for the same data
resource "local_file" "multi_format_2spaces" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.k8s_config),
    "2spaces"
  )
  filename        = "${path.module}/formats/config-2spaces.json"
  file_permission = "0644"
}

resource "local_file" "multi_format_4spaces" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.k8s_config),
    "4spaces"
  )
  filename        = "${path.module}/formats/config-4spaces.json"
  file_permission = "0644"
}

resource "local_file" "multi_format_tabs" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.k8s_config),
    "tabs"
  )
  filename        = "${path.module}/formats/config-tabs.json"
  file_permission = "0644"
}

# Example 5: Configuration with computed values from multiple resources
resource "local_file" "computed_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      deployment_metadata = {
        id        = random_id.deployment_id.hex
        timestamp = formatdate("RFC3339", timestamp())
        suffix    = random_string.app_suffix.result
      }
      file_outputs = {
        microservices_dev  = local_file.microservices_config_dev.filename
        microservices_prod = local_file.microservices_config_prod.filename
        k8s_configmap      = local_file.k8s_configmap.filename
        dynamic_config     = local_file.dynamic_config.filename
      }
      checksums = {
        dev_config  = local_file.microservices_config_dev.content_md5
        prod_config = local_file.microservices_config_prod.content_md5
        k8s_config  = local_file.k8s_configmap.content_md5
      }
    }),
    "2spaces"
  )
  filename        = "${path.module}/metadata/deployment-metadata.json"
  file_permission = "0644"

  # Explicit dependency to ensure other files are created first
  depends_on = [
    local_file.microservices_config_dev,
    local_file.microservices_config_prod,
    local_file.k8s_configmap,
    local_file.dynamic_config
  ]
}