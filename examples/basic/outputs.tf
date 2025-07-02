# Outputs for Basic Integration Examples
# These outputs demonstrate how to reference generated files and expose
# configuration data for use in other Terraform configurations.

output "generated_files" {
  description = "List of all generated configuration files"
  value = {
    basic_config       = local_file.basic_config.filename
    config_4spaces     = local_file.config_4spaces.filename
    config_tabs        = local_file.config_tabs.filename
    service_config     = local_file.service_config.filename
    dynamic_config     = local_file.dynamic_config.filename
    conditional_config = local_file.conditional_config.filename
    environment_configs = {
      for env, file in local_file.environment_configs : env => file.filename
    }
  }
}

output "file_contents_preview" {
  description = "Preview of generated file contents (first 200 characters)"
  value = {
    basic_config   = substr(local_file.basic_config.content, 0, 200)
    service_config = substr(local_file.service_config.content, 0, 200)
  }
}

output "configuration_summary" {
  description = "Summary of configuration parameters used in generation"
  value = {
    app_name                = var.app_name
    environment             = var.environment
    total_files             = 6 + length(local_file.environment_configs)
    indentation_styles_used = ["2spaces", "4spaces", "tab"]
    features_enabled = [
      for feature, enabled in local.app_config.features : feature if enabled
    ]
  }
}

output "database_config_formatted" {
  description = "Formatted database configuration for verification"
  value = provider::prettyjson::jsonprettyprint(
    jsonencode(var.database_config),
    "2spaces"
  )
  sensitive = false
}

output "environment_specific_files" {
  description = "Map of environment-specific configuration files"
  value = {
    for env, file in local_file.environment_configs : env => {
      filename     = file.filename
      size_bytes   = length(file.content)
      content_hash = sha256(file.content)
    }
  }
}

output "terraform_integration_info" {
  description = "Information about Terraform integration and provider usage"
  value = {
    terraform_version   = "1.8.0+"
    prettyjson_provider = "graysievert/prettyjson"
    local_provider      = "hashicorp/local"
    workspace           = terraform.workspace
    timestamp           = timestamp()
    example_type        = "basic_integration"
  }
}

# Output demonstrating the prettyjson function directly
output "sample_formatted_json" {
  description = "Sample JSON formatted with different indentation options"
  value = {
    two_spaces = provider::prettyjson::jsonprettyprint(
      jsonencode({
        message = "Hello World"
        data    = { key = "value", number = 42 }
      }),
      "2spaces"
    )
    four_spaces = provider::prettyjson::jsonprettyprint(
      jsonencode({
        message = "Hello World"
        data    = { key = "value", number = 42 }
      }),
      "4spaces"
    )
    tabs = provider::prettyjson::jsonprettyprint(
      jsonencode({
        message = "Hello World"
        data    = { key = "value", number = 42 }
      }),
      "tab"
    )
  }
}