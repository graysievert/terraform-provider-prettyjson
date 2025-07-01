# Using existing terraform configuration from main.tf

# Test basic JSON formatting without external dependencies
locals {
  test_config = {
    application = {
      name        = "integration-test"
      version     = "1.0.0"
      environment = "testing"
      features = {
        auth_enabled    = true
        logging_level   = "info"
        cache_enabled   = true
        metrics_enabled = false
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
        name     = "api"
        port     = 8080
        replicas = 3
      },
      {
        name     = "worker"
        port     = 8081
        replicas = 2
      }
    ]
  }
}

# Test all indentation formats
output "json_2spaces" {
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.test_config),
    "2spaces"
  )
}

output "json_4spaces" {
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.test_config),
    "4spaces"
  )
}

output "json_tabs" {
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.test_config),
    "tabs"
  )
}

# Test with file output (using simple write to demonstrate integration)
output "config_file_content" {
  description = "Formatted JSON content ready for file output"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(local.test_config),
    "2spaces"
  )
}