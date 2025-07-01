terraform {
  required_providers {
    prettyjson = {
      source = "local/prettyjson"
    }
  }
}

# Test data for JSON formatting
locals {
  test_data = {
    application = {
      name        = "webapp"
      version     = "1.0.0"
      environment = "development"
      features = {
        auth_enabled  = true
        logging_level = "info"
      }
    }
    database = {
      host = "localhost"
      port = 5432
    }
    services = [
      {
        name = "api"
        port = 8080
      },
      {
        name = "worker"
        port = 8081
      }
    ]
  }

  # Test different indentation formats
  json_2spaces = provider::prettyjson::jsonprettyprint(
    jsonencode(local.test_data),
    "2spaces"
  )

  json_4spaces = provider::prettyjson::jsonprettyprint(
    jsonencode(local.test_data),
    "4spaces"
  )

  json_tabs = provider::prettyjson::jsonprettyprint(
    jsonencode(local.test_data),
    "tab"
  )
}

# Write formatted JSON files using terraform_data and local-exec
resource "terraform_data" "write_2spaces" {
  triggers_replace = [local.json_2spaces]

  provisioner "local-exec" {
    command = <<-EOT
      cat > config-2spaces.json << 'EOF'
${local.json_2spaces}
EOF
    EOT
  }
}

resource "terraform_data" "write_4spaces" {
  triggers_replace = [local.json_4spaces]

  provisioner "local-exec" {
    command = <<-EOT
      cat > config-4spaces.json << 'EOF'
${local.json_4spaces}
EOF
    EOT
  }

  depends_on = [terraform_data.write_2spaces]
}

resource "terraform_data" "write_tabs" {
  triggers_replace = [local.json_tabs]

  provisioner "local-exec" {
    command = <<-EOT
      cat > config-tabs.json << 'EOF'
${local.json_tabs}
EOF
    EOT
  }

  depends_on = [terraform_data.write_4spaces]
}

# Verification using built-in file function
resource "terraform_data" "verify_files" {
  triggers_replace = [
    terraform_data.write_2spaces.id,
    terraform_data.write_4spaces.id,
    terraform_data.write_tabs.id
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verification Results ==="
      echo "2spaces file exists: $(test -f config-2spaces.json && echo 'YES' || echo 'NO')"
      echo "4spaces file exists: $(test -f config-4spaces.json && echo 'YES' || echo 'NO')"
      echo "tabs file exists: $(test -f config-tabs.json && echo 'YES' || echo 'NO')"
      echo "2spaces file size: $(wc -c < config-2spaces.json 2>/dev/null || echo '0') bytes"
      echo "4spaces file size: $(wc -c < config-4spaces.json 2>/dev/null || echo '0') bytes"
      echo "tabs file size: $(wc -c < config-tabs.json 2>/dev/null || echo '0') bytes"
      echo "=== JSON Validation ==="
      if command -v jq >/dev/null 2>&1; then
        echo "2spaces JSON valid: $(jq empty config-2spaces.json 2>/dev/null && echo 'YES' || echo 'NO')"
        echo "4spaces JSON valid: $(jq empty config-4spaces.json 2>/dev/null && echo 'YES' || echo 'NO')"
        echo "tabs JSON valid: $(jq empty config-tabs.json 2>/dev/null && echo 'YES' || echo 'NO')"
      else
        echo "jq not available for JSON validation"
      fi
    EOT
  }

  depends_on = [
    terraform_data.write_2spaces,
    terraform_data.write_4spaces,
    terraform_data.write_tabs
  ]
}

# Output the formatted JSON for verification
output "formatted_json_2spaces" {
  description = "JSON formatted with 2-space indentation"
  value       = local.json_2spaces
}

output "formatted_json_4spaces" {
  description = "JSON formatted with 4-space indentation"
  value       = local.json_4spaces
}

output "formatted_json_tabs" {
  description = "JSON formatted with tab indentation"
  value       = local.json_tabs
}

output "test_summary" {
  description = "Summary of test execution"
  value = {
    test_data_size = length(jsonencode(local.test_data))
    formatted_sizes = {
      "2spaces" = length(local.json_2spaces)
      "4spaces" = length(local.json_4spaces)
      "tabs"    = length(local.json_tabs)
    }
    files_created = [
      "config-2spaces.json",
      "config-4spaces.json",
      "config-tabs.json"
    ]
  }
}