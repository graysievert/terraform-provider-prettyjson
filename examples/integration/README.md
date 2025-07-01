# Multi-Resource Integration Examples

This directory demonstrates comprehensive integration patterns for the prettyjson provider with other Terraform resources and providers.

## Overview

This example showcases real-world usage patterns including:

- **Multi-provider integration**: prettyjson, local, and random providers
- **Dynamic configuration generation**: Using resource outputs in JSON content
- **Multiple output formats**: Same data in different indentation styles
- **Dependency management**: Proper resource ordering and dependencies
- **Environment-specific configurations**: Different settings for dev/prod
- **Kubernetes integration**: ConfigMap-style JSON generation

## Resources Created

### Configuration Files
- `configs/microservices-dev.json` - Development environment config (2-space indentation)
- `configs/microservices-prod.json` - Production environment config (4-space indentation)
- `configs/dynamic-config.json` - Dynamic config with timestamps (tab indentation)

### Kubernetes Files
- `k8s/configmap.json` - Kubernetes ConfigMap JSON format

### Format Examples
- `formats/config-2spaces.json` - 2-space indentation example
- `formats/config-4spaces.json` - 4-space indentation example
- `formats/config-tabs.json` - Tab indentation example

### Metadata
- `metadata/deployment-metadata.json` - Deployment metadata with checksums

## Key Integration Patterns

### 1. Multi-Provider Resource Dependencies
```hcl
resource "random_string" "app_suffix" {
  length = 6
}

resource "local_file" "config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      app_name = "webapp-${random_string.app_suffix.result}"
    }),
    "2spaces"
  )
}
```

### 2. Environment-Specific Configuration
```hcl
content = provider::prettyjson::jsonprettyprint(
  jsonencode(merge(local.base_config, {
    environment = var.environment
    debug_mode = var.environment == "development"
  })),
  var.indentation_format
)
```

### 3. Computed Values Integration
```hcl
content = provider::prettyjson::jsonprettyprint(
  jsonencode({
    generated_at = timestamp()
    checksums = {
      config_md5 = local_file.other_config.content_md5
    }
  }),
  "2spaces"
)
```

### 4. Kubernetes-Style Configurations
```hcl
k8s_config = {
  apiVersion = "v1"
  kind       = "ConfigMap"
  metadata = {
    name = "app-config-${random_string.suffix.result}"
  }
  data = {
    "config.json" = jsonencode(local.app_settings)
  }
}
```

## Usage

### Basic Deployment
```bash
terraform init
terraform plan
terraform apply
```

### Custom Configuration
```bash
terraform apply \
  -var="environment=production" \
  -var="app_name=myapp" \
  -var="replica_count=5" \
  -var="indentation_format=4spaces"
```

### With Custom Labels
```bash
terraform apply \
  -var='custom_labels={"team":"platform","project":"webapp","cost_center":"engineering"}'
```

## Validation

After applying, verify the generated files:

```bash
# Check file structure
find . -name "*.json" -type f

# Validate JSON formatting
for file in $(find . -name "*.json"); do
  echo "Validating $file"
  jq . "$file" > /dev/null && echo "✓ Valid JSON" || echo "✗ Invalid JSON"
done

# Compare indentation formats
ls -la formats/
cat formats/config-2spaces.json | head -10
cat formats/config-4spaces.json | head -10
cat formats/config-tabs.json | head -10
```

## Advanced Use Cases

### 1. CI/CD Pipeline Configuration
This pattern can generate configuration files for different deployment stages in CI/CD pipelines.

### 2. Microservices Configuration Management
Generate consistent configuration files across multiple microservices with environment-specific overrides.

### 3. Kubernetes Configuration Generation
Create JSON configurations that can be converted to YAML or used directly with Kubernetes APIs.

### 4. Multi-Cloud Deployment Configuration
Generate cloud-provider-specific configuration files with consistent formatting.

## Dependencies

- **prettyjson provider**: For JSON formatting functionality
- **local provider**: For file generation
- **random provider**: For unique identifiers and demonstration

## Notes

- Files are generated with appropriate permissions (0644)
- Dependencies are properly managed with explicit `depends_on` where needed
- All JSON output is validated through Terraform's `jsonencode()` function
- Multiple indentation formats demonstrate provider flexibility
- Resource references show dynamic configuration generation capabilities