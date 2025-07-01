# Prettyjson Provider Examples

This directory contains comprehensive examples demonstrating the prettyjson Terraform provider's functionality and integration patterns.

## Directory Structure

### Registry-Based Examples (Original)
- `basic/` - Basic examples using local_file provider from registry
- `advanced/` - Advanced examples with complex data structures
- `integration/` - Multi-resource integration examples
- `performance/` - Performance optimization examples

### Built-in Provider Examples (Automated Testing)
- `basic-builtin/` - Basic functionality using terraform_data + local-exec
- `integration-builtin/` - Integration examples without external dependencies
- `performance-builtin/` - Performance testing with built-in providers

## Quick Start

### Automated Testing (Recommended)

Use the automated test script to run all examples without registry dependencies:

```bash
# Run all tests and preserve generated files for review
./test-provider.sh test

# Clean up all generated files and reset environment
./test-provider.sh clean

# View help and usage information
./test-provider.sh
```

### Manual Testing

For manual testing of individual examples:

```bash
# Set up local provider development
cat > ~/.terraformrc << 'EOF'
provider_installation {
  dev_overrides {
    "local/prettyjson" = "/home/user/go/bin"
  }
  direct {}
}
EOF

# Build and install provider
make build && make install

# Test a specific example
cd examples/basic-builtin
terraform plan
terraform apply
```

## Example Categories

### 1. Basic Examples (`basic-builtin/`)

**Purpose**: Demonstrate core provider functionality with different indentation options.

**Generated Files**:
- `config-2spaces.json` - Standard 2-space indentation (381 bytes)
- `config-4spaces.json` - 4-space indentation for readability (473 bytes)  
- `config-tabs.json` - Tab indentation for compact files (335 bytes)

**Use Cases**:
- Simple JSON configuration generation
- Indentation format comparison
- Basic provider function validation

### 2. Integration Examples (`integration-builtin/`)

**Purpose**: Show multi-resource integration patterns with microservices and Kubernetes.

**Generated Files**:
- `configs/microservices-dev.json` - Development environment configuration
- `configs/microservices-prod.json` - Production environment configuration
- `configs/dynamic-config.json` - Dynamic configuration with timestamps
- `k8s/configmap.json` - Kubernetes ConfigMap format
- `formats/config-{2spaces,4spaces,tabs}.json` - Multi-format examples

**Use Cases**:
- Microservices deployment configuration
- Kubernetes resource generation
- Environment-specific configurations
- Multi-format output for different tools

### 3. Performance Examples (`performance-builtin/`)

**Purpose**: Demonstrate performance optimization strategies for large-scale deployments.

**Generated Files**:
- `configs/large-services-config.json` - Large configuration (20 services)
- `configs/optimized-services-config.json` - Size-optimized configuration
- `configs/dev-minimal-config.json` - Minimal development configuration
- `configs/monitoring-config.json` - Monitoring-specific configuration
- `chunks/services-chunk-{0,1,2,3}.json` - Chunked configurations

**Use Cases**:
- Large-scale configuration management
- Performance optimization strategies
- Memory-efficient configuration patterns
- Configuration chunking for parallel processing

## Key Features Demonstrated

### Indentation Options

```hcl
# 2-space indentation (most common)
provider::prettyjson::jsonprettyprint(jsonencode(data), "2spaces")

# 4-space indentation (high readability)
provider::prettyjson::jsonprettyprint(jsonencode(data), "4spaces")

# Tab indentation (most compact)
provider::prettyjson::jsonprettyprint(jsonencode(data), "tab")
```

### Built-in Provider Integration

All `*-builtin` examples use only Terraform built-in functionality:

```hcl
resource "terraform_data" "write_config" {
  triggers_replace = [local.formatted_json]

  provisioner "local-exec" {
    command = <<-EOT
      cat > config.json << 'EOF'
${local.formatted_json}
EOF
    EOT
  }
}
```

### Performance Optimization Patterns

- **Selective Data Inclusion**: Include only necessary fields for specific use cases
- **Environment-Specific Sizing**: Different configurations for dev/prod environments  
- **Configuration Chunking**: Split large datasets into manageable pieces
- **Conditional Creation**: Create expensive resources only when needed
- **Indentation Optimization**: Choose format based on file size and usage

## File Size Comparison

| Example Type | 2spaces | 4spaces | tabs | Optimization |
|--------------|---------|---------|------|--------------|
| Basic Config | 381 bytes | 473 bytes | 335 bytes | 12% smaller with tabs |
| Integration Config | ~1KB | ~1.3KB | ~900 bytes | 25% smaller with tabs |
| Performance Config | ~15KB | ~18KB | ~13KB | 30% smaller with tabs |

## Testing and Validation

### Automated Testing Features

- **JSON Validation**: All generated files validated with `jq`
- **Indentation Verification**: Visual verification using `cat -A`
- **File Size Analysis**: Performance metrics and size comparisons
- **Cross-Platform Compatibility**: POSIX-compliant shell scripting
- **Error Handling**: Comprehensive error detection and reporting

### Manual Validation

```bash
# Check JSON validity
jq . examples/basic-builtin/config-2spaces.json

# Compare indentation visually
head -5 examples/basic-builtin/config-tabs.json | cat -A

# Analyze file sizes
ls -la examples/*/configs/*.json

# Performance timing
time terraform apply
```

## Integration Patterns

### With Local File Provider (Registry Required)

```hcl
resource "local_file" "config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.config_data),
    "2spaces"
  )
  filename = "config.json"
}
```

### With Built-in Providers (No Registry)

```hcl
resource "terraform_data" "config" {
  triggers_replace = [local.formatted_json]
  
  provisioner "local-exec" {
    command = "echo '${local.formatted_json}' > config.json"
  }
}
```

## Best Practices

### Development Workflow

1. **Use automated testing** for CI/CD and development validation
2. **Test locally** with dev_overrides before registry publication
3. **Validate JSON output** using standard tools like `jq`
4. **Choose appropriate indentation** based on file size and usage
5. **Implement chunking** for large configuration datasets

### Production Considerations

- Use **2spaces** for small, frequently accessed files
- Use **4spaces** for large files requiring high readability  
- Use **tabs** for very large files where size matters most
- Implement **conditional creation** for environment-specific resources
- Use **chunking strategies** for configurations with 50+ items

### CI/CD Integration

```yaml
# GitHub Actions example
- name: Test Prettyjson Provider
  run: |
    ./test-provider.sh test
    # Generated files preserved for artifact upload
    
- name: Upload Test Results
  uses: actions/upload-artifact@v3
  with:
    name: prettyjson-test-outputs
    path: examples/*-builtin/**/*.json
```

## Troubleshooting

### Common Issues

1. **Provider not found**: Ensure dev_overrides points to correct binary location
2. **Permission denied**: Check that provider binary is executable
3. **JSON validation fails**: Verify input data is valid before formatting
4. **File generation fails**: Check directory permissions and disk space

### Debug Commands

```bash
# Check provider installation
ls -la $(go env GOPATH)/bin/terraform-provider-prettyjson

# Verify .terraformrc configuration
cat ~/.terraformrc

# Test provider function directly
terraform console
> provider::prettyjson::jsonprettyprint("{\"test\":\"value\"}", "2spaces")

# Check generated file contents
find examples -name "*.json" -exec sh -c 'echo "{}:"; head -3 "{}"' \;
```

## Contributing

When adding new examples:

1. Follow existing naming conventions (`*-builtin` for automated testing)
2. Include comprehensive variable validation
3. Add detailed outputs showing usage patterns
4. Document all features in README files
5. Test with the automated testing script
6. Ensure cross-platform compatibility

## Documentation Tool Integration

This directory also supports automated documentation generation:

* **provider/provider.tf** - Example file for the provider index page
* **data-sources/`full data source name`/data-source.tf** - Example file for named data source page
* **resources/`full resource name`/resource.tf** - Example file for named resource page

The documentation generation tool looks for files in the above locations by default. All other *.tf files are ignored by the documentation tool, making them useful for creating runnable/testable examples even if some parts aren't relevant for documentation.

## Resources

- **Provider Documentation**: See main README.md for provider details
- **Terraform Functions**: [Provider Functions Documentation](https://developer.hashicorp.com/terraform/language/functions)
- **Local Development**: [Provider Development Overrides](https://developer.hashicorp.com/terraform/cli/config/config-file#development-overrides-for-provider-developers)
- **Testing**: Use `./test-provider.sh` for comprehensive validation

This examples directory provides a complete testing and validation framework for the prettyjson provider, demonstrating both registry-based usage and registry-independent testing patterns suitable for development and CI/CD environments.