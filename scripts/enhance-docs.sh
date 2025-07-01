#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


# Documentation Enhancement Script
# This script enhances the generated documentation with additional examples and content

set -e

echo "🔧 Enhancing generated documentation..."

# Enhance function documentation
FUNCTION_DOC="docs/functions/jsonprettyprint.md"

if [[ -f "$FUNCTION_DOC" ]]; then
    echo "📝 Enhancing function documentation..."
    
    # Simply append examples to the end of the function documentation
    cat >> "$FUNCTION_DOC" << 'EOF'

## Examples

### Basic Usage

```terraform
# Simple JSON formatting with default 2-space indentation
resource "local_file" "config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      app_name = "my-application"
      version  = "1.0.0"
      enabled  = true
    })
  )
  filename = "config.json"
}
```

### Custom Indentation

```terraform
# Using 4-space indentation
resource "local_file" "config_4spaces" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      database = {
        host = "localhost"
        port = 5432
      }
    }),
    "4spaces"
  )
  filename = "database-config.json"
}

# Using tab indentation
resource "local_file" "config_tabs" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      services = ["web", "api", "worker"]
    }),
    "tab"
  )
  filename = "services-config.json"
}
```

### Complex Nested Structures

```terraform
locals {
  app_config = {
    application = {
      name = "web-service"
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
  }
}

resource "local_file" "complex_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.app_config),
    "2spaces"
  )
  filename = "application-config.json"
}
```

### Dynamic Configuration

```terraform
# Generate environment-specific configurations
resource "local_file" "env_configs" {
  for_each = toset(["dev", "staging", "prod"])
  
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      environment = each.key
      debug_mode  = each.key != "prod"
      log_level   = each.key == "prod" ? "warn" : "debug"
    }),
    "2spaces"
  )
  
  filename = "${each.key}-config.json"
}
```

## Error Handling

The function provides comprehensive error handling:

- **Invalid JSON**: Clear error messages for syntax issues
- **Invalid Indentation**: Validation of indentation type parameter  
- **Size Limits**: Protection against excessive memory usage (10MB max)
- **Empty Input**: Validation against empty JSON strings

## Performance Notes

- Maximum input size: 10MB
- Warning threshold: 1MB (logs performance warning)
- Optimized for typical configuration file sizes
- Efficient JSON validation and formatting

## Best Practices

1. **Validate JSON**: Ensure your JSON is valid before formatting
2. **Choose Consistent Indentation**: Use the same indentation style across your project
3. **Consider File Size**: Split very large JSON into smaller files
4. **Use with Local Files**: Pairs well with `local_file` resource

## Troubleshooting

**Error: "Invalid JSON syntax detected"**
- Verify JSON syntax with a validator
- Check for missing quotes, trailing commas, or unescaped characters

**Error: "Invalid indentation type"**  
- Valid options: `"2spaces"`, `"4spaces"`, `"tab"`
- Check spelling and quotes

**Error: "JSON input cannot be empty"**
- Ensure input string is not empty
- Verify `jsonencode()` produces valid output
EOF
    
    echo "✅ Enhanced function documentation with examples"
else
    echo "⚠️  Function documentation not found"
fi

# Enhance provider documentation
PROVIDER_DOC="docs/index.md"

if [[ -f "$PROVIDER_DOC" ]]; then
    echo "📝 Enhancing provider documentation..."
    
    # Append comprehensive provider information
    cat >> "$PROVIDER_DOC" << 'EOF'

## Available Functions

- [`jsonprettyprint`](functions/jsonprettyprint.md) - Format JSON strings with configurable indentation

## Use Cases

- **Configuration File Generation**: Create properly formatted JSON configuration files
- **Template Processing**: Format JSON output from Terraform templates  
- **Multi-Environment Deployments**: Generate consistent configuration across environments
- **Development Workflows**: Maintain readable JSON files in infrastructure as code

## Quick Examples

### Basic Configuration File

```terraform
resource "local_file" "app_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      name = "my-app"
      version = "1.0.0"
      environment = terraform.workspace
    })
  )
  filename = "config/app.json"
}
```

### Multiple Environment Configs

```terraform
resource "local_file" "env_configs" {
  for_each = toset(["dev", "staging", "prod"])
  
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      environment = each.key
      debug = each.key != "prod"
    }),
    "4spaces"
  )
  
  filename = "configs/${each.key}.json"
}
```

## Performance Guidelines

- **Input Size**: Maximum 10MB per JSON input
- **Large File Warning**: Warnings for inputs > 1MB
- **Best Practice**: Split very large configurations into multiple files

## Error Handling

The provider includes comprehensive error handling with clear messages:

- **Validation Errors**: Invalid JSON syntax detection
- **Parameter Errors**: Invalid indentation type validation
- **Size Limits**: Input size limit enforcement
- **Processing Errors**: JSON formatting failure handling
EOF
    
    echo "✅ Enhanced provider documentation"
else
    echo "⚠️  Provider documentation not found"
fi

echo "🎉 Documentation enhancement completed!"