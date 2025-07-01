# Terraform Version Compatibility Testing

This document describes the comprehensive Terraform version compatibility testing infrastructure for the prettyjson provider.

## Overview

The prettyjson provider implements multi-version testing to ensure compatibility across different Terraform versions, particularly focusing on Terraform 1.8+ which introduced provider function support.

## Testing Infrastructure

### GitHub Actions Workflow

The `terraform-version-compatibility.yml` workflow provides automated testing across multiple Terraform versions:

- **Dynamic Matrix Generation**: Automatically selects appropriate Terraform versions based on context
- **Comprehensive Version Coverage**: Tests versions from 1.8.0 through latest releases
- **Intelligent Test Selection**: Different test modes (minimal, standard, extended) for various scenarios
- **Automated Reporting**: Generates compatibility reports and comments on pull requests

#### Test Triggers

- **Pull Requests**: Minimal version testing (1.8.0, 1.9.8, latest)
- **Main Branch**: Standard version testing (comprehensive set)
- **Scheduled Runs**: Extended version testing (all supported versions)
- **Manual Dispatch**: Customizable version testing with user-defined parameters

### Test Script

The `scripts/platform-tests/terraform-version-tests.sh` script provides command-line testing capabilities:

```bash
# Basic usage
make test-terraform-versions

# Test specific versions
make test-terraform-version VERSION=1.8.5

# Minimal testing for CI
make test-terraform-versions-minimal

# Extended testing with report
make test-terraform-versions-extended
```

#### Available Test Modes

- **minimal**: Tests key versions (1.8.0, 1.9.8, latest)
- **standard**: Comprehensive testing of major and minor releases
- **extended**: Full testing including patch releases and edge cases

## Supported Terraform Versions

### Minimum Requirements

- **Terraform 1.8.0**: Required for provider function support
- **Go 1.23+**: Provider development and testing
- **terraform-plugin-framework**: Latest compatible version

### Tested Version Matrix

| Version Range | Support Level | Test Coverage |
|---------------|---------------|---------------|
| 1.8.0 - 1.8.x | Full Support | Complete |
| 1.9.0 - 1.9.x | Full Support | Complete |
| 1.10.0 - 1.10.x | Full Support | Complete |
| Latest | Full Support | Complete |

## Version-Specific Testing

### Protocol Compatibility

Tests verify that the provider function protocol works correctly across versions:

- Function metadata consistency
- Parameter definition validation
- Result handling compatibility
- Error propagation behavior

### Error Handling

Version-specific error handling tests ensure consistent behavior:

- Invalid JSON input handling
- Empty input validation
- Null value processing
- Error message formatting

### Performance Testing

Performance characteristics are validated across versions:

- Large JSON processing
- Memory usage patterns
- Processing time consistency
- Resource cleanup

### Feature Compatibility

Feature-specific tests verify functionality:

- Indentation options (2spaces, 4spaces, tabs)
- Unicode character handling
- Complex nested structures
- Edge case processing

## Integration with Existing Workflows

### Test Workflow Integration

The version compatibility tests integrate with existing test infrastructure:

```yaml
# Existing test.yml
- Terraform versions: ['1.8.*', '1.9.*', 'latest']

# Enhanced cross-platform-test.yml  
- Terraform versions: ['1.8.5', '1.9.8', 'latest']
- Compatibility validation step added

# New terraform-version-compatibility.yml
- Comprehensive version matrix
- Automated reporting
- Dynamic test selection
```

### Makefile Integration

New Makefile targets provide easy access to version testing:

```makefile
# Validation and testing targets
validate-terraform-versions     # Validate version compatibility
test-terraform-versions         # Standard version testing  
test-terraform-versions-minimal # Quick CI testing
test-terraform-versions-extended # Comprehensive testing
test-terraform-version VERSION=X # Test specific version
```

## Test Configuration

### Environment Variables

The testing system uses environment variables for configuration:

- `TF_VERSION`: Current Terraform version being tested
- `TF_ACC`: Enable acceptance testing mode
- `TF_LOG`: Terraform logging level for debugging

### Test Files

Version-specific test files provide targeted validation:

- `terraform_version_compatibility_test.go`: Core compatibility tests
- `jsonprettyprint_function_test.go`: Existing function tests
- `*_test.go`: Additional test suites with version constraints

## Continuous Integration

### Automated Testing

The CI system automatically:

1. **Validates** minimum version requirements
2. **Tests** across version matrix based on trigger
3. **Reports** compatibility status
4. **Artifacts** test results and reports
5. **Comments** on pull requests with results

### Performance Monitoring

Performance tests track:

- Execution time trends across versions
- Memory usage patterns
- Error rate consistency
- Resource utilization

## Troubleshooting

### Common Issues

1. **Version Download Failures**: Check network connectivity and version availability
2. **Test Timeouts**: Increase timeout for complex tests or slow environments
3. **Memory Issues**: Monitor resource usage with large JSON inputs
4. **Protocol Changes**: Review Terraform changelogs for breaking changes

### Debug Mode

Enable detailed logging for troubleshooting:

```bash
# Enable verbose output and debug logging
make test-terraform-version VERSION=1.8.0 VERBOSE=1
TF_LOG=DEBUG make test-terraform-versions-minimal
```

### Report Analysis

Compatibility reports provide detailed information:

- Test execution times
- Success/failure rates
- Version-specific issues
- Environment details

## Best Practices

### Development Workflow

1. **Test Early**: Run version compatibility tests during development
2. **Monitor Changes**: Watch for deprecation warnings in newer versions
3. **Update Regularly**: Keep test matrix current with new Terraform releases
4. **Document Issues**: Record version-specific quirks and workarounds

### Release Process

1. **Comprehensive Testing**: Run extended version tests before releases
2. **Compatibility Matrix**: Update supported version documentation
3. **Changelogs**: Document version compatibility changes
4. **User Communication**: Inform users of version requirements

## Future Enhancements

### Planned Improvements

- **Automated Version Detection**: Dynamic version matrix updates
- **Performance Benchmarking**: Automated performance regression detection
- **Cross-Provider Testing**: Compatibility with other provider functions
- **User Metrics**: Real-world usage pattern analysis

### Version Support Policy

- **LTS Support**: Long-term support for major Terraform versions
- **Deprecation Timeline**: Clear communication of version support lifecycle
- **Migration Guides**: Assistance for version upgrades
- **Compatibility Guarantees**: SLA for supported version combinations

## References

- [Terraform Provider Functions Documentation](https://developer.hashicorp.com/terraform/language/functions)
- [terraform-plugin-framework Documentation](https://developer.hashicorp.com/terraform/plugin/framework)
- [terraform-plugin-testing Documentation](https://developer.hashicorp.com/terraform/plugin/testing)
- [HashiCorp Provider Development Guidelines](https://developer.hashicorp.com/terraform/plugin/best-practices)