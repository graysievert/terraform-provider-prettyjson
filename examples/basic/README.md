# Basic Integration Examples

This directory contains basic integration examples demonstrating how to use the `prettyjson` provider with Terraform's `local_file` resource for configuration file generation.

## Overview

These examples showcase fundamental usage patterns including:

- Basic file generation with different indentation options (2 spaces, 4 spaces, tabs)
- Working with variables and local values
- Dynamic configuration generation
- Conditional logic in configurations
- Using `for_each` to generate multiple files
- Integration with Terraform's built-in functions

## Prerequisites

- Terraform >= 1.8.0
- PrettyJSON provider
- Local provider (usually built-in)

## Usage

### Initialize and Apply

```bash
# Initialize the configuration
terraform init

# Review the planned changes
terraform plan

# Apply the configuration
terraform apply
```

### Generated Files

The examples will create a `generated/` directory with the following files:

- `basic-config.json` - Basic application configuration (2-space indentation)
- `config-4spaces.json` - Same configuration with 4-space indentation
- `config-tabs.json` - Same configuration with tab indentation
- `service-config.json` - Service configuration with nested structures
- `dynamic-config.json` - Configuration with dynamic values and Terraform metadata
- `conditional-config.json` - Configuration with environment-specific conditional logic
- `development-config.json` - Environment-specific configuration for development
- `staging-config.json` - Environment-specific configuration for staging
- `production-config.json` - Environment-specific configuration for production

## Configuration Variables

You can customize the examples by setting variables:

```bash
# Use custom application name and environment
terraform apply -var="app_name=my-custom-app" -var="environment=production"

# Use custom database configuration
terraform apply -var='database_config={
  host="prod-db.example.com"
  port=5432
  database="production_db"
  ssl=true
}'
```

## Example Outputs

The configuration includes several outputs to demonstrate different aspects:

- `generated_files` - List of all generated files
- `file_contents_preview` - Preview of file contents
- `configuration_summary` - Summary of configuration parameters
- `sample_formatted_json` - Direct examples of JSON formatting

## Key Features Demonstrated

### 1. Basic File Generation

```hcl
resource "local_file" "basic_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.app_config)
  )
  filename        = "${path.module}/generated/basic-config.json"
  file_permission = "0644"
}
```

### 2. Different Indentation Options

```hcl
# 2 spaces (default)
provider::prettyjson::jsonprettyprint(jsonencode(data))

# 4 spaces
provider::prettyjson::jsonprettyprint(jsonencode(data), "4spaces")

# Tabs
provider::prettyjson::jsonprettyprint(jsonencode(data), "tab")
```

### 3. Dynamic Configuration

```hcl
content = provider::prettyjson::jsonprettyprint(
  jsonencode({
    application = {
      name    = var.app_name
      env     = var.environment
      debug   = var.environment == "development"
    }
    timestamp = timestamp()
    terraform = {
      workspace = terraform.workspace
    }
  })
)
```

### 4. Conditional Logic

```hcl
environment_specific = var.environment == "production" ? {
  logging_level = "info"
  debug_mode    = false
} : {
  logging_level = "debug"
  debug_mode    = true
}
```

### 5. Multiple File Generation

```hcl
resource "local_file" "environment_configs" {
  for_each = toset(["development", "staging", "production"])
  
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      environment = each.key
      # ... environment-specific configuration
    })
  )
  filename = "${path.module}/generated/${each.key}-config.json"
}
```

## Best Practices Demonstrated

1. **File Permissions**: Setting appropriate file permissions (0644)
2. **Variable Validation**: Input validation for configuration parameters
3. **Output Organization**: Well-structured outputs for downstream consumption
4. **Documentation**: Comprehensive comments explaining each example
5. **Error Handling**: Proper validation and conditional logic
6. **Modular Design**: Using locals and variables for reusable configuration

## Next Steps

- See the `advanced/` examples for more complex scenarios
- Check the `integration/` examples for multi-provider usage
- Review the `performance/` examples for large-scale configurations

## Troubleshooting

If you encounter issues:

1. Ensure Terraform version is >= 1.8.0
2. Verify the prettyjson provider is properly installed
3. Check that the output directory is writable
4. Review variable validation messages for input errors

For more help, see the provider documentation and advanced examples.