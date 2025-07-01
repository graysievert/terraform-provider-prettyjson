# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# Test data structure
locals {
  app_config = {
    application = {
      name        = "integration-test"
      version     = "1.0.0"
      environment = "testing"
      features = {
        auth_enabled     = true
        logging_level    = "info"
        cache_enabled    = true
        metrics_enabled  = false
      }
    }
    database = {
      host     = "localhost"
      port     = 5432
      name     = "testdb"
      ssl_mode = "require"
    }
    services = [
      {
        name = "api"
        port = 8080
        replicas = 3
      },
      {
        name = "worker"
        port = 8081
        replicas = 2
      }
    ]
  }
}

# Test with jsonencode() - this shows the pattern without prettyjson
resource "local_file" "raw_config" {
  content = jsonencode(local.app_config)
  filename        = "${path.module}/raw-config.json"
  file_permission = "0644"
}

# Output to show the pattern
output "json_structure" {
  description = "The JSON structure that would be formatted by prettyjson"
  value = jsonencode(local.app_config)
}