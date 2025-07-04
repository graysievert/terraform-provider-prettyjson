# Terraform Provider PrettyJSON

[![Tests](https://github.com/graysievert/terraform-provider-prettyjson/actions/workflows/test.yml/badge.svg)](https://github.com/graysievert/terraform-provider-prettyjson/actions/workflows/test.yml)
[![Documentation](https://github.com/graysievert/terraform-provider-prettyjson/actions/workflows/docs.yml/badge.svg)](https://github.com/graysievert/terraform-provider-prettyjson/actions/workflows/docs.yml)
[![Go Report Card](https://goreportcard.com/badge/github.com/graysievert/terraform-provider-prettyjson)](https://goreportcard.com/report/github.com/graysievert/terraform-provider-prettyjson)

A Terraform provider for formatting JSON strings with configurable indentation. This function-only provider helps maintain readable JSON configuration files in your infrastructure as code workflows.

## Disclaimer

This is an experiment. Almost everything in this repo is generated via AI tools. 
Use at your own risk. Read the full [story](https://github.com/graysievert/terraform-provider-prettyjson/blob/main/story.md). 


## Features

- **Multiple Indentation Options**: Support for 2-space, 4-space, and tab indentation
- **JSON Validation**: Built-in validation ensures input is syntactically correct JSON
- **Performance Optimized**: Efficient processing with size limits and performance warnings
- **Error Handling**: Comprehensive error messages with troubleshooting guidance
- **Zero Configuration**: No provider configuration required

## Quick Start

### Installation

Add the provider to your Terraform configuration:

```terraform
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
  # No configuration required
}
```

### Basic Usage

```terraform
# Format JSON with default 2-space indentation
resource "local_file" "config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      app_name = "my-application"
      version  = "1.0.0"
      environment = "production"
    })
  )
  filename = "config.json"
}

# Format with custom indentation
resource "local_file" "config_tabbed" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      database = {
        host = "localhost"
        port = 5432
      }
    }),
    "tab"
  )
  filename = "database-config.json"
}
```

## Documentation

### Provider Documentation

- **[Provider Overview](docs/index.md)** - Complete provider documentation with examples and use cases
- **[Function Reference](docs/functions/jsonprettyprint.md)** - Detailed `jsonprettyprint` function documentation

### Examples

Comprehensive examples are available in the [`examples/`](examples/) directory:

- **[Basic Usage](examples/basic/)** - Simple JSON formatting examples
- **[Advanced Usage](examples/advanced/)** - Complex nested structures and dynamic configuration
- **[Integration Examples](examples/integration/)** - Using with other Terraform providers
- **[Performance Examples](examples/performance/)** - Large JSON handling and optimization

### Function Reference

#### `jsonprettyprint(json_string, indentation_type)`

Formats JSON strings with configurable indentation.

**Parameters:**
- `json_string` (string, required) - The JSON string to format
- `indentation_type` (string, optional) - Indentation style: `"2spaces"` (default), `"4spaces"`, or `"tab"`

**Returns:** Formatted JSON string

**Example:**
```terraform
provider::prettyjson::jsonprettyprint(
  jsonencode({key = "value"}),
  "4spaces"
)
```

## Use Cases

### Configuration File Generation

Generate properly formatted JSON configuration files:

```terraform
resource "local_file" "app_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      name = var.app_name
      environment = terraform.workspace
      database = {
        host = var.db_host
        port = var.db_port
      }
    })
  )
  filename = "config/application.json"
}
```

### Multi-Environment Deployments

Create environment-specific configurations:

```terraform
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
  
  filename = "configs/${each.key}.json"
}
```

### Template Processing

Format JSON output from Terraform templates:

```terraform
data "template_file" "service_config" {
  template = file("templates/service.json.tpl")
  vars = {
    service_name = var.service_name
    port         = var.service_port
  }
}

resource "local_file" "service_config" {
  content = provider::prettyjson::jsonprettyprint(
    data.template_file.service_config.rendered,
    "4spaces"
  )
  filename = "service-config.json"
}
```

## Requirements

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.8.0 (for provider functions support)
- [Go](https://golang.org/doc/install) >= 1.23 (for development)

## Installation

### Terraform Registry

The provider is available on the [Terraform Registry](https://registry.terraform.io/providers/graysievert/prettyjson):

```terraform
terraform {
  required_providers {
    prettyjson = {
      source = "graysievert/prettyjson"
    }
  }
}
```

### Local Development

For local development and testing:

1. Clone the repository:
```bash
git clone https://github.com/graysievert/terraform-provider-prettyjson
cd terraform-provider-prettyjson
```

2. Build the provider:
```bash
make build
```

3. Install locally:
```bash
make install
```

## Development

### Building the Provider

```bash
# Build the provider
make build

# Install the provider locally
make install

# Run tests
make test

# Run acceptance tests
make testacc
```

### Documentation Generation

This provider uses automated documentation generation:

```bash
# Generate documentation
make docs

# Generate and validate documentation
make docs-dev

# Clean and regenerate documentation
make docs-clean docs
```

Documentation is automatically generated using:
- [terraform-plugin-docs](https://github.com/hashicorp/terraform-plugin-docs) for base generation
- Custom enhancement scripts for examples and detailed descriptions
- GitHub Actions for automated updates

### Testing

```bash
# Run unit tests
make test

# Run acceptance tests (requires Terraform)
make testacc

# Run linting
make lint

# Format code
make fmt
```

### Development Workflow

1. **Documentation**: All changes to provider code automatically trigger documentation regeneration
2. **Testing**: PRs require passing tests and validation
3. **Examples**: Update examples in `examples/` directory when adding features
4. **Validation**: Documentation includes comprehensive validation and error handling examples

## Performance

- **Maximum Input Size**: 10MB per JSON input
- **Warning Threshold**: 1MB (logs performance warnings)
- **Optimized Processing**: Efficient JSON validation and formatting
- **Memory Safety**: Built-in size limits prevent excessive memory usage

## Error Handling

The provider includes comprehensive error handling:

- **JSON Validation Errors**: Clear messages for syntax issues with remediation suggestions
- **Parameter Validation**: Invalid indentation type validation with valid options
- **Size Limit Enforcement**: Protection against excessive memory usage
- **Processing Errors**: Detailed error messages for formatting failures

Common error patterns and solutions are documented in the [function reference](docs/functions/jsonprettyprint.md#troubleshooting).

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for your changes
5. Update documentation (`make docs`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Development Guidelines

- Follow Go best practices and formatting (`make fmt`)
- Add comprehensive tests for new functionality
- Update documentation and examples
- Ensure all CI checks pass
- Add appropriate logging for debugging

## Versioning

This project uses [Semantic Versioning](https://semver.org/). For available versions, see the [tags on this repository](https://github.com/graysievert/terraform-provider-prettyjson/tags).

## License

This project is licensed under the MPL-2.0 License - see the [LICENSE](LICENSE) file for details.

## Support

- **Documentation**: [Provider Docs](docs/) | [Examples](examples/)
- **Issues**: [GitHub Issues](https://github.com/graysievert/terraform-provider-prettyjson/issues)
- **Discussions**: [GitHub Discussions](https://github.com/graysievert/terraform-provider-prettyjson/discussions)
- **Security**: Report security vulnerabilities via [GitHub Security Advisories](https://github.com/graysievert/terraform-provider-prettyjson/security/advisories)

## Acknowledgments

- Built with [Terraform Plugin Framework](https://github.com/hashicorp/terraform-plugin-framework)
- Documentation generated with [terraform-plugin-docs](https://github.com/hashicorp/terraform-plugin-docs)
- Template based on [terraform-provider-scaffolding-framework](https://github.com/hashicorp/terraform-provider-scaffolding-framework)