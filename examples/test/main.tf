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

# Simple test of the prettyjson function
resource "local_file" "test_basic" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      message = "Hello World"
      data = {
        key    = "value"
        number = 42
        array  = [1, 2, 3]
      }
    })
  )
  filename = "${path.module}/test-output.json"
}

output "formatted_json" {
  value = provider::prettyjson::jsonprettyprint(
    jsonencode({
      test    = "simple"
      working = true
    })
  )
}