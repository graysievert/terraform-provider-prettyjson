# Advanced Complex Data Structure Examples

This directory contains advanced integration examples demonstrating complex data structure formatting with the `prettyjson` provider, including real-world microservices configurations, infrastructure as code, and monitoring setups.

## Overview

These examples showcase advanced usage patterns including:

- Complex microservices configuration with Kubernetes manifests
- AWS infrastructure configuration with VPC, security groups, and databases
- Monitoring configuration for Prometheus and Grafana
- Multi-environment deployment matrices
- Advanced data transformation with nested locals
- Integration with multiple Terraform providers
- Real-world JSON structures and configuration patterns

## Prerequisites

- Terraform >= 1.8.0
- PrettyJSON provider
- Local provider (built-in)
- Random provider (built-in)

## Architecture Overview

The examples demonstrate a complete microservices application stack including:

### Microservices Configuration
- API service with load balancing and health checks
- Worker service with background processing
- Resource allocation and scaling policies
- Environment-specific configurations

### Infrastructure Components
- VPC with public and private subnets
- Security groups with ingress/egress rules
- RDS databases with backup configurations
- Multi-availability zone deployment

### Monitoring Stack
- Prometheus scraping configuration
- Grafana dashboard definitions
- Alerting and notification setup

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

The examples will create numerous JSON configuration files in the `generated/` directory:

#### Microservices Configurations
- `microservices-2spaces.json` - Complete microservices config (2-space indentation)
- `microservices-4spaces.json` - Same config with 4-space indentation
- `microservices-tabs.json` - Same config with tab indentation
- `k8s-api-deployment.json` - Kubernetes deployment for API service
- `k8s-worker-deployment.json` - Kubernetes deployment for Worker service
- `service-api-processed.json` - Processed API service configuration
- `service-worker-processed.json` - Processed Worker service configuration

#### Infrastructure Configurations
- `aws-infrastructure.json` - Complete AWS infrastructure configuration
- `deployment-matrix.json` - Multi-environment deployment matrix

#### Monitoring Configurations
- `prometheus-config.json` - Prometheus scraping configuration
- `grafana-dashboards.json` - Grafana dashboard definitions

#### Application Stack
- `application-stack.json` - Complete application stack configuration

## Advanced Features Demonstrated

### 1. Complex Data Transformation

```hcl
locals {
  processed_microservices = {
    for service_name, config in var.microservices : service_name => {
      metadata = {
        name         = service_name
        image        = config.image
        replicas     = config.replicas
        total_ports  = length(config.ports)
        has_https    = contains(config.ports, 443) || contains(config.ports, 8443)
      }
      # ... complex nested processing
    }
  }
}
```

### 2. Kubernetes Manifest Generation

```hcl
resource "local_file" "kubernetes_manifests" {
  for_each = local.processed_microservices

  content = provider::prettyjson::jsonprettyprint(
    jsonencode(each.value.kubernetes.deployment),
    "2spaces"
  )
  filename = "${path.module}/generated/k8s-${each.key}-deployment.json"
}
```

### 3. Multi-Environment Deployment Matrix

```hcl
deployment_strategy = "rolling"
environments = {
  for env in ["dev", "staging", "prod"] : env => {
    services = {
      for service_name, config in var.microservices : service_name => {
        replicas = env == "prod" ? config.replicas * 2 : (env == "staging" ? config.replicas : 1)
        # ... environment-specific configuration
      }
    }
  }
}
```

### 4. Nested Data Processing with jsonencode()

```hcl
content = provider::prettyjson::jsonprettyprint(
  jsonencode({
    original_config = each.value
    processed_config = local.processed_microservices[each.key]
    terraform_metadata = {
      workspace = terraform.workspace
      timestamp = timestamp()
      service_key = each.key
    }
    computed_values = {
      resource_ratio = "${each.value.resources.requests.cpu}:${each.value.resources.limits.cpu}"
      health_url = "http://localhost:${each.value.health_check.port}${each.value.health_check.path}"
    }
  }),
  "tab"
)
```

## Configuration Variables

### Microservices Configuration

Customize the microservices setup:

```bash
terraform apply -var='microservices={
  api = {
    image = "my-api:v2.0.0"
    replicas = 5
    ports = [8080, 8443]
    # ... additional configuration
  }
}'
```

### Infrastructure Configuration

Modify the AWS infrastructure:

```bash
terraform apply -var='infrastructure_config={
  vpc = {
    cidr_block = "172.16.0.0/16"
    # ... VPC configuration
  }
  # ... additional infrastructure
}'
```

### Deployment Environments

Specify custom environments:

```bash
terraform apply -var='deployment_environments=["dev","test","staging","prod"]'
```

## Real-World Integration Patterns

### 1. CI/CD Pipeline Integration

The generated Kubernetes manifests can be used directly in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Deploy to Kubernetes
  run: |
    kubectl apply -f generated/k8s-api-deployment.json
    kubectl apply -f generated/k8s-worker-deployment.json
```

### 2. Infrastructure as Code

The AWS infrastructure configuration can be imported into CloudFormation or used with other tools:

```bash
# Convert to CloudFormation template
aws cloudformation package --template-body file://generated/aws-infrastructure.json
```

### 3. Monitoring Stack Deployment

Deploy monitoring tools using the generated configurations:

```bash
# Deploy Prometheus configuration
kubectl create configmap prometheus-config --from-file=generated/prometheus-config.json

# Import Grafana dashboards
curl -X POST http://grafana:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @generated/grafana-dashboards.json
```

## Performance Considerations

### File Size Management

The examples generate large configuration files. Monitor file sizes:

```bash
# Check generated file sizes
du -h generated/
```

### Memory Usage

For very large configurations, consider:

1. Breaking configurations into smaller files
2. Using Terraform's `jsonencode()` function efficiently
3. Optimizing data transformations in locals

### Processing Time

Complex data transformations may increase plan/apply time:

- Use `terraform plan -target` for specific resources during development
- Consider breaking large configurations into modules

## Best Practices Demonstrated

### 1. Data Validation

```hcl
validation {
  condition = can(cidrhost(var.infrastructure_config.vpc.cidr_block, 0))
  error_message = "VPC CIDR block must be a valid CIDR notation."
}
```

### 2. Resource Organization

- Logical grouping of related resources
- Consistent naming conventions
- Proper file permissions and structure

### 3. Output Management

- Comprehensive metadata in outputs
- Size and complexity metrics
- Integration-ready file references

### 4. Error Handling

- Input validation for complex objects
- Graceful handling of optional fields
- Meaningful error messages

## Troubleshooting

### Common Issues

1. **Large file generation errors**
   - Check available disk space
   - Verify file permissions in the output directory

2. **Complex data transformation errors**
   - Validate input data structure
   - Check for null or undefined values
   - Use `terraform console` to test expressions

3. **Performance issues**
   - Reduce data complexity for testing
   - Use `terraform plan -parallelism=1` for debugging
   - Consider breaking into smaller modules

### Debugging Tips

1. **Use terraform console**
   ```bash
   terraform console
   > local.processed_microservices
   ```

2. **Validate JSON output**
   ```bash
   jq . generated/microservices-2spaces.json
   ```

3. **Check file generation**
   ```bash
   ls -la generated/
   ```

## Next Steps

- Explore the `integration/` examples for multi-provider scenarios
- Review the `performance/` examples for large-scale configurations
- Check the `troubleshooting/` examples for error handling patterns

For production usage, consider:
- Implementing proper secret management
- Adding comprehensive validation
- Setting up automated testing
- Integrating with monitoring and alerting systems