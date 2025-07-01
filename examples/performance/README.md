# Performance Considerations and Best Practices

This directory demonstrates performance optimization strategies when using the prettyjson provider for large-scale configuration management.

## Overview

This example showcases performance optimization techniques including:

- **Selective data inclusion**: Only include necessary data for specific use cases
- **Environment-specific optimization**: Different configurations for different environments
- **Configuration chunking**: Split large configurations into manageable pieces
- **Conditional resource creation**: Create expensive resources only when needed
- **Indentation optimization**: Choose the right indentation for file size and usage
- **Lazy loading patterns**: Load configurations on demand

## Performance Strategies Demonstrated

### 1. File Size Optimization

#### Small Files (< 10KB)
- **Indentation**: 2 spaces
- **Usage**: Frequent access, development environments
- **Example**: `dev-minimal-config.json`

#### Medium Files (10KB - 100KB)
- **Indentation**: 2 or 4 spaces
- **Usage**: Moderate access, staging environments
- **Example**: `optimized-services-config.json`

#### Large Files (> 100KB)
- **Indentation**: 4 spaces or tabs
- **Usage**: Infrequent access, production environments
- **Example**: `large-services-config.json`

### 2. Environment-Specific Optimization

```hcl
# Development: Minimal configuration
services = {
  for k, v in local.large_service_config.services : k => {
    # Reduced configuration for faster loading
  } if tonumber(split("-", k)[1]) < 5  # Only first 5 services
}

# Production: Full configuration with conditional creation
resource "local_file" "conditional_large_config" {
  count = var.environment == "production" ? 1 : 0
  # Full configuration only in production
}
```

### 3. Configuration Chunking

Large datasets are split into smaller, manageable chunks:

```hcl
resource "local_file" "service_chunks" {
  for_each = {
    for i in range(5) : "chunk-${i}" => {
      start = i * 10
      end   = min((i + 1) * 10, 50)
    }
  }
  # Each chunk contains 10 services
}
```

### 4. Selective Data Inclusion

Different configurations for different use cases:

- **Full Configuration**: All service details for deployment
- **Monitoring Configuration**: Only monitoring-relevant data
- **Development Configuration**: Minimal service configuration

### 5. Lazy Loading Pattern

An index file provides metadata about available configurations:

```json
{
  "configurations": {
    "large_config": {
      "file": "large-services-config.json",
      "size": "large",
      "use_case": "complete service configuration"
    }
  }
}
```

## Performance Benchmarks

| Configuration Type | Typical Size | Recommended Indentation | Use Case |
|-------------------|--------------|------------------------|----------|
| Development | < 5KB | 2 spaces | Fast loading, frequent changes |
| Optimized | 10-30KB | 2 spaces | Critical services only |
| Monitoring | 15-40KB | 2 spaces | Observability tools |
| Production Full | 100KB+ | 4 spaces/tabs | Complete configuration |
| Chunked | 20KB each | 2 spaces | Parallel processing |

## Usage Examples

### Basic Performance-Optimized Deployment

```bash
# Development environment (minimal configuration)
terraform apply -var="environment=development"

# Production environment (full configuration with chunking)
terraform apply -var="environment=production" -var="enable_chunking=true"
```

### Performance Mode Selection

```bash
# Minimal mode (fastest, smallest files)
terraform apply -var="performance_mode=minimal"

# Balanced mode (good performance, reasonable completeness)
terraform apply -var="performance_mode=balanced"

# Comprehensive mode (complete data, optimized for large scale)
terraform apply -var="performance_mode=comprehensive"
```

### Custom Chunking Configuration

```bash
terraform apply \
  -var="max_services_per_chunk=20" \
  -var="enable_chunking=true" \
  -var="optimize_for_frequency=true"
```

## Best Practices

### 1. Choose the Right Indentation

```hcl
# For small, frequently accessed files
indentation = "2spaces"

# For large, comprehensive files
indentation = "4spaces"

# For very large files where size matters most
indentation = "tabs"
```

### 2. Use Conditional Creation

```hcl
# Only create expensive resources when needed
resource "local_file" "large_config" {
  count = var.environment == "production" ? 1 : 0
  # Expensive configuration only in production
}
```

### 3. Implement Configuration Chunking

```hcl
# Split large datasets into chunks
resource "local_file" "service_chunks" {
  for_each = var.enable_chunking ? local.chunk_config : {}
  # Create chunks only when enabled
}
```

### 4. Optimize for Use Case

```hcl
# Monitoring-specific optimization
monitoring_config = {
  # Include only monitoring-relevant fields
  service_endpoints = {
    for k, v in local.services : k => {
      name = v.name
      port = v.port
      # Exclude heavy configuration details
    }
  }
}
```

## Performance Monitoring

### File Size Analysis

After applying the configuration, analyze file sizes:

```bash
# Check generated file sizes
ls -lh configs/
ls -lh chunks/

# Compare different formats
wc -c configs/*.json

# Validate JSON parsing performance
time jq . configs/large-services-config.json > /dev/null
time jq . configs/optimized-services-config.json > /dev/null
```

### Terraform Performance

Monitor Terraform performance impact:

```bash
# Time the plan operation
time terraform plan

# Monitor memory usage during apply
terraform apply

# Check state file size
ls -lh terraform.tfstate
```

## Integration with CI/CD

### Performance-Optimized Pipeline

```yaml
# Example GitHub Actions optimization
- name: Generate configs by environment
  run: |
    if [ "${{ github.ref }}" == "refs/heads/main" ]; then
      terraform apply -var="environment=production" -auto-approve
    else
      terraform apply -var="environment=development" -auto-approve
    fi
```

### Parallel Processing

```yaml
# Process chunks in parallel
- name: Process configuration chunks
  strategy:
    matrix:
      chunk: [0, 1, 2, 3, 4]
  run: |
    terraform apply -target="local_file.service_chunks[\"chunk-${{ matrix.chunk }}\"]"
```

## Troubleshooting Performance Issues

### Common Issues and Solutions

1. **Large File Generation Too Slow**
   - Enable chunking: `enable_chunking = true`
   - Use conditional creation for large files
   - Optimize indentation choice

2. **High Memory Usage During Apply**
   - Reduce services per chunk: `max_services_per_chunk = 5`
   - Use performance mode: `performance_mode = "minimal"`

3. **Slow JSON Parsing in Applications**
   - Use 2-space indentation for frequently parsed files
   - Consider tab indentation for very large files
   - Implement lazy loading patterns

4. **Long Terraform Plan/Apply Times**
   - Use conditional resource creation
   - Enable chunking for parallel processing
   - Optimize for specific environments

## Advanced Optimization Techniques

### 1. Dynamic Chunking Based on Data Size

```hcl
locals {
  chunk_size = length(local.services) > 100 ? 20 : 10
  chunk_count = ceil(length(local.services) / local.chunk_size)
}
```

### 2. Memory-Efficient Data Processing

```hcl
# Process data in smaller batches
locals {
  service_batches = {
    for i in range(local.batch_count) : "batch-${i}" => 
    slice(local.services, i * local.batch_size, min((i + 1) * local.batch_size, length(local.services)))
  }
}
```

### 3. Intelligent Caching Strategy

```hcl
# Use file checksums for change detection
output "config_checksums" {
  value = {
    for k, v in local_file.service_chunks : k => v.content_md5
  }
}
```

This example provides comprehensive performance optimization strategies that can be applied to real-world Terraform configurations using the prettyjson provider.