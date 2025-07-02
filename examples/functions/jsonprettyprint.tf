# jsonprettyprint function examples

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

# Basic usage with default 2-space indentation
resource "local_file" "basic_example" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      app_name = "my-application"
      version  = "1.0.0"
      enabled  = true
    })
  )
  filename = "basic-config.json"
}

# Using 4-space indentation
resource "local_file" "four_spaces_example" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      database = {
        host = "localhost"
        port = 5432
        ssl  = true
      }
    }),
    "4spaces"
  )
  filename = "database-config.json"
}

# Using tab indentation
resource "local_file" "tab_example" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      services = [
        {
          name = "web"
          port = 8080
        },
        {
          name = "api"
          port = 8090
        }
      ]
    }),
    "tab"
  )
  filename = "services-config.json"
}

# Complex nested structure
locals {
  complex_config = {
    application = {
      name        = "web-service"
      environment = "production"
      features = {
        logging   = true
        metrics   = true
        debugging = false
      }
    }
    database = {
      host      = "db.example.com"
      port      = 5432
      ssl       = true
      pool_size = 20
    }
    cache = {
      enabled = true
      ttl     = 3600
      type    = "redis"
    }
  }
}

resource "local_file" "complex_example" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.complex_config),
    "2spaces"
  )
  filename = "complex-config.json"
}