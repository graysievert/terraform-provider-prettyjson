# Basic Integration Examples: PrettyJSON Provider with local_file Resource
# This example demonstrates fundamental usage patterns for the prettyjson provider
# in combination with Terraform's local_file resource for configuration file generation.

terraform {
  required_providers {
    prettyjson = {
      source = "graysievert/prettyjson"
    }
    local = {
      source = "hashicorp/local"
    }
  }
  required_version = ">= 1.8.0"
}

provider "prettyjson" {
  # No configuration required for this function-only provider
}

# Variables are defined in variables.tf

# Local values for demonstration
locals {
  # Basic application configuration
  app_config = {
    name        = var.app_name
    environment = var.environment
    version     = "1.0.0"
    database    = var.database_config
    features = {
      logging   = true
      metrics   = true
      tracing   = false
      debugging = var.environment == "development"
    }
  }

  # Service configuration with multiple endpoints
  service_config = {
    services = [
      {
        name      = "api"
        port      = 8080
        endpoints = ["/health", "/metrics", "/api/v1"]
      },
      {
        name      = "worker"
        port      = 8090
        endpoints = ["/health", "/status"]
      }
    ]
    load_balancer = {
      algorithm = "round-robin"
      health_check = {
        interval = 30
        timeout  = 5
        retries  = 3
      }
    }
  }
}

# Example 1: Basic file generation with default indentation (2 spaces)
resource "local_file" "basic_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.app_config)
  )
  filename        = "${path.module}/generated/basic-config.json"
  file_permission = "0644"
}

# Example 2: File generation with 4-space indentation
resource "local_file" "config_4spaces" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.app_config),
    "4spaces"
  )
  filename        = "${path.module}/generated/config-4spaces.json"
  file_permission = "0644"
}

# Example 3: File generation with tab indentation
resource "local_file" "config_tabs" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.app_config),
    "tab"
  )
  filename        = "${path.module}/generated/config-tabs.json"
  file_permission = "0644"
}

# Example 4: Service configuration with complex nested structures
resource "local_file" "service_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.service_config),
    "2spaces"
  )
  filename        = "${path.module}/generated/service-config.json"
  file_permission = "0644"
}

# Example 5: Dynamic configuration based on variables
resource "local_file" "dynamic_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      application = {
        name    = var.app_name
        env     = var.environment
        debug   = var.environment == "development"
        version = "1.0.0"
      }
      database  = var.database_config
      timestamp = timestamp()
      terraform = {
        workspace = terraform.workspace
        version   = "1.8.0"
      }
    })
  )
  filename        = "${path.module}/generated/dynamic-config.json"
  file_permission = "0644"
}

# Example 6: Configuration with conditional logic
resource "local_file" "conditional_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      base_config = local.app_config
      environment_specific = var.environment == "production" ? {
        logging_level = "info"
        debug_mode    = false
        cache_size    = 1000
        } : {
        logging_level = "debug"
        debug_mode    = true
        cache_size    = 100
      }
      features = {
        monitoring = var.environment == "production"
        profiling  = var.environment != "production"
      }
    }),
    "4spaces"
  )
  filename        = "${path.module}/generated/conditional-config.json"
  file_permission = "0644"
}

# Example 7: Using for_each to generate multiple configuration files
resource "local_file" "environment_configs" {
  for_each = toset(["development", "staging", "production"])

  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      environment = each.key
      app_name    = var.app_name
      settings = {
        debug_mode    = each.key == "development"
        logging_level = each.key == "production" ? "warn" : "debug"
        cache_enabled = each.key != "development"
        metrics = {
          enabled = true
          level   = each.key == "production" ? "minimal" : "detailed"
        }
      }
      database = merge(var.database_config, {
        host = each.key == "production" ? "prod-db.example.com" : "dev-db.example.com"
      })
    })
  )
  filename        = "${path.module}/generated/${each.key}-config.json"
  file_permission = "0644"
}