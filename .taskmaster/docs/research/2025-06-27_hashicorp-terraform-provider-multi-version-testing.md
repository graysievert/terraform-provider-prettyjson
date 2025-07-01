---
title: Research Session
query: "HashiCorp Terraform provider multi-version testing patterns, compatibility matrix testing, best practices for testing provider functions across Terraform versions 1.8+ in GitHub Actions, version-specific test configurations"
date: 6/27/2025
time: 2:52:01 PM
timestamp: 2025-06-27T12:52:01.893Z
exchanges: 1
---

# Research Session

## Initial Query

**Question:** HashiCorp Terraform provider multi-version testing patterns, compatibility matrix testing, best practices for testing provider functions across Terraform versions 1.8+ in GitHub Actions, version-specific test configurations

**Response:**

# HashiCorp Terraform Provider Multi-Version Testing Patterns & Compatibility Matrix

## Overview of Terraform Provider Testing Architecture

HashiCorp's approach to provider testing has evolved significantly with the introduction of the terraform-plugin-testing framework and the shift toward comprehensive compatibility matrices. For providers targeting Terraform 1.8+, the testing architecture must account for breaking changes in the plugin protocol, new function capabilities, and enhanced state management features. The testing patterns follow a layered approach: unit tests for core logic, acceptance tests for integration scenarios, and compatibility tests for version-specific behaviors.

The terraform-plugin-testing framework provides sophisticated tooling for multi-version testing, including test runners that can automatically provision different Terraform versions, validate provider behavior across versions, and generate compatibility reports. This framework integrates seamlessly with GitHub Actions through predefined workflows that can execute tests across multiple Terraform versions simultaneously while maintaining isolation between test environments.

## Compatibility Matrix Testing Implementation

### Multi-Version Test Configuration Structure

The most effective pattern for compatibility matrix testing involves creating a structured test configuration that defines supported Terraform versions, target platforms, and test scenarios. This configuration should be maintained as a YAML file in your repository's `.github/workflows/` directory:

```yaml
name: Compatibility Matrix Testing
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  compatibility-matrix:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        terraform-version: 
          - "1.8.0"
          - "1.8.1" 
          - "1.9.0"
          - "1.9.1"
          - "1.10.0"
          - "latest"
        os: [ubuntu-latest, windows-latest, macos-latest]
        go-version: ["1.21", "1.22"]
    steps:
      - uses: actions/checkout@v4
      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: ${{ matrix.go-version }}
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ matrix.terraform-version }}
      - name: Run Compatibility Tests
        run: |
          go test -v ./... -timeout 30m -parallel 4
          TF_ACC=1 go test -v ./internal/provider -timeout 30m
```

### Version-Specific Test Configurations

Different Terraform versions require tailored test configurations due to protocol changes and feature additions. For your prettyjson provider, version-specific configurations should account for function protocol changes introduced in Terraform 1.8+ and enhanced error handling in newer versions:

```go
// internal/provider/compatibility_test.go
func TestProviderCompatibility(t *testing.T) {
    terraformVersions := []string{
        "1.8.0", "1.8.1", "1.9.0", "1.9.1", "1.10.0",
    }
    
    for _, version := range terraformVersions {
        t.Run(fmt.Sprintf("terraform-%s", version), func(t *testing.T) {
            resource.Test(t, resource.TestCase{
                TerraformVersionChecks: []tfversion.TerraformVersionCheck{
                    tfversion.SkipBelow(tfversion.Version1_8_0),
                },
                ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
                Steps: []resource.TestStep{
                    {
                        Config: testAccProviderConfig(version),
                        Check: resource.ComposeAggregateTestCheckFunc(
                            testAccCheckFunctionCompatibility(version),
                        ),
                    },
                },
            })
        })
    }
}
```

## Advanced GitHub Actions Workflow Patterns

### Comprehensive Testing Pipeline

The most robust GitHub Actions workflow for provider testing implements a multi-stage pipeline that separates concerns while maintaining efficient resource utilization. This pattern allows for early failure detection while ensuring comprehensive coverage:

```yaml
name: Provider Testing Pipeline
on:
  push:
  pull_request:
  schedule:
    - cron: '0 2 * * *'  # Daily compatibility checks

jobs:
  # Stage 1: Fast feedback loop
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: "1.22"
      - name: Run Unit Tests
        run: go test -v ./internal/... -short

  # Stage 2: Acceptance testing
  acceptance-tests:
    needs: unit-tests
    runs-on: ubuntu-latest
    strategy:
      matrix:
        terraform-version: ["1.8.0", "1.9.0", "1.10.0", "latest"]
    steps:
      - uses: actions/checkout@v4
      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: "1.22"
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ matrix.terraform-version }}
      - name: Run Acceptance Tests
        env:
          TF_ACC: "1"
          TF_LOG: "DEBUG"
        run: go test -v ./internal/provider -timeout 30m

  # Stage 3: Cross-platform validation
  cross-platform:
    needs: acceptance-tests
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        terraform-version: ["1.8.0", "1.10.0"]
    steps:
      - uses: actions/checkout@v4
      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: "1.22"
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ matrix.terraform-version }}
      - name: Cross-Platform Tests
        env:
          TF_ACC: "1"
        run: go test -v ./internal/provider -run TestAccProvider
```

### Conditional Testing Based on Changes

Implementing intelligent test execution based on file changes can significantly reduce CI runtime while maintaining coverage. This pattern is particularly effective for providers with multiple functions or complex dependency trees:

```yaml
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      provider-changed: ${{ steps.changes.outputs.provider }}
      tests-changed: ${{ steps.changes.outputs.tests }}
      docs-changed: ${{ steps.changes.outputs.docs }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v2
        id: changes
        with:
          filters: |
            provider:
              - 'internal/provider/**'
              - 'go.mod'
              - 'go.sum'
            tests:
              - '**/*_test.go'
            docs:
              - 'docs/**'
              - 'examples/**'
```

## Provider Function Testing Patterns for Terraform 1.8+

### Function Protocol Testing

Terraform 1.8+ introduced significant changes to the function protocol, requiring specialized testing patterns. The terraform-plugin-testing framework provides specific utilities for testing function implementations across different protocol versions:

```go
// internal/provider/jsonprettyprint_function_test.go
func TestJsonPrettyPrintFunction_ProtocolVersions(t *testing.T) {
    testCases := []struct {
        name           string
        input          string
        expected       string
        terraformVersion string
    }{
        {
            name:           "basic_object_v1_8",
            input:          `{"key":"value"}`,
            expected:       "{\n  \"key\": \"value\"\n}",
            terraformVersion: "1.8.0",
        },
        {
            name:           "basic_object_v1_9",
            input:          `{"key":"value"}`,
            expected:       "{\n  \"key\": \"value\"\n}",
            terraformVersion: "1.9.0",
        },
    }

    for _, tc := range testCases {
        t.Run(tc.name, func(t *testing.T) {
            resource.UnitTest(t, resource.TestCase{
                TerraformVersionChecks: []tfversion.TerraformVersionCheck{
                    tfversion.RequireAbove(tfversion.Version1_8_0),
                },
                ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
                Steps: []resource.TestStep{
                    {
                        Config: fmt.Sprintf(`
                            output "result" {
                              value = provider::prettyjson::jsonprettyprint(%q)
                            }
                        `, tc.input),
                        Check: resource.ComposeTestCheckFunc(
                            resource.TestCheckOutput("result", tc.expected),
                        ),
                    },
                },
            })
        })
    }
}
```

### Error Handling Validation Across Versions

Different Terraform versions handle function errors differently, particularly regarding error message formatting and error propagation. Comprehensive testing should validate error handling consistency:

```go
func TestJsonPrettyPrintFunction_ErrorHandling(t *testing.T) {
    errorTestCases := []struct {
        name     string
        input    string
        errorMsg string
        skipVersions []string
    }{
        {
            name:     "invalid_json",
            input:    `{"invalid": json}`,
            errorMsg: "invalid JSON",
        },
        {
            name:     "empty_string",
            input:    ``,
            errorMsg: "empty input",
        },
    }

    for _, tc := range errorTestCases {
        t.Run(tc.name, func(t *testing.T) {
            resource.UnitTest(t, resource.TestCase{
                ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
                Steps: []resource.TestStep{
                    {
                        Config: fmt.Sprintf(`
                            output "result" {
                              value = provider::prettyjson::jsonprettyprint(%q)
                            }
                        `, tc.input),
                        ExpectError: regexp.MustCompile(tc.errorMsg),
                    },
                },
            })
        })
    }
}
```

## Performance Testing and Benchmarking

### Multi-Version Performance Benchmarks

Performance characteristics can vary significantly between Terraform versions due to protocol optimizations and runtime improvements. Implementing version-specific benchmarks helps identify performance regressions:

```go
func BenchmarkJsonPrettyPrintFunction(b *testing.B) {
    testInputs := []struct {
        name string
        json string
    }{
        {"small", `{"key": "value"}`},
        {"medium", generateMediumJSON()},
        {"large", generateLargeJSON()},
    }

    for _, input := range testInputs {
        b.Run(input.name, func(b *testing.B) {
            ctx := context.Background()
            req := function.RunRequest{
                Arguments: function.NewArgumentsData([]attr.Value{
                    types.StringValue(input.json),
                }),
            }
            
            fn := NewJsonPrettyPrintFunction()
            b.ResetTimer()
            
            for i := 0; i < b.N; i++ {
                _, err := fn.Run(ctx, req)
                if err != nil {
                    b.Fatal(err)
                }
            }
        })
    }
}
```

### Memory Usage Validation

Large JSON processing can reveal memory usage patterns that vary between Terraform versions. Implementing memory-aware tests helps ensure consistent performance:

```go
func TestJsonPrettyPrintFunction_MemoryUsage(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping memory usage test in short mode")
    }

    largeJSON := generateLargeJSON() // 10MB+ JSON
    
    var m1, m2 runtime.MemStats
    runtime.GC()
    runtime.ReadMemStats(&m1)
    
    // Execute function multiple times
    for i := 0; i < 100; i++ {
        result, err := executeFunction(largeJSON)
        require.NoError(t, err)
        require.NotEmpty(t, result)
    }
    
    runtime.GC()
    runtime.ReadMemStats(&m2)
    
    memoryIncrease := m2.Alloc - m1.Alloc
    if memoryIncrease > 50*1024*1024 { // 50MB threshold
        t.Errorf("Memory usage increased by %d bytes, exceeding threshold", memoryIncrease)
    }
}
```

## Integration Testing with Real Terraform Configurations

### Version-Specific Configuration Testing

Real-world usage patterns often reveal compatibility issues not caught by unit tests. Creating comprehensive integration tests with actual Terraform configurations provides the most reliable compatibility validation:

```hcl
# test-fixtures/terraform-1.8/main.tf
terraform {
  required_version = ">= 1.8.0"
  required_providers {
    prettyjson = {
      source = "local/prettyjson"
      version = "~> 1.0"
    }
  }
}

locals {
  test_data = {
    simple = {"key": "value"}
    complex = {
      nested = {
        array = [1, 2, 3]
        object = {
          bool = true
          null = null
        }
      }
    }
  }
}

output "simple_output" {
  value = provider::prettyjson::jsonprettyprint(jsonencode(local.test_data.simple))
}

output "complex_output" {
  value = provider::prettyjson::jsonprettyprint(jsonencode(local.test_data.complex))
}
```

### Terraform Plan and Apply Testing

Beyond function execution, testing the complete Terraform lifecycle ensures compatibility across all provider interactions:

```go
func TestAccProvider_TerraformLifecycle(t *testing.T) {
    resource.Test(t, resource.TestCase{
        TerraformVersionChecks: []tfversion.TerraformVersionCheck{
            tfversion.SkipBelow(tfversion.Version1_8_0),
        },
        ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
        Steps: []resource.TestStep{
            {
                Config: testAccProviderConfig_basic(),
                Check: resource.ComposeTestCheckFunc(
                    resource.TestCheckOutput("simple_output", "{\n  \"key\": \"value\"\n}"),
                ),
            },
            {
                Config: testAccProviderConfig_updated(),
                Check: resource.ComposeTestCheckFunc(
                    resource.TestCheckOutput("updated_output", "{\n  \"updated\": \"value\"\n}"),
                ),
            },
        },
    })
}
```

## Best Practices for Multi-Version Testing

### Test Organization and Maintenance

Organizing tests for multi-version compatibility requires careful consideration of test structure and maintenance overhead. The most effective approach separates version-agnostic logic from version-specific behavior:

```go
// testdata/compatibility_matrix.json
{
  "terraform_versions": ["1.8.0", "1.8.1", "1.9.0", "1.9.1", "1.10.0"],
  "test_scenarios": [
    {
      "name": "basic_functionality",
      "applicable_versions": ["1.8.0", "1.8.1", "1.9.0", "1.9.1", "1.10.0"],
      "test_config": "basic_test.tf"
    },
    {
      "name": "enhanced_error_handling",
      "applicable_versions": ["1.9.0", "1.9.1", "1.10.0"],
      "test_config": "enhanced_error_test.tf"
    }
  ]
}
```

### Continuous Integration Optimization

Balancing comprehensive testing with CI resource constraints requires strategic test execution. Implementing intelligent test selection and parallel execution patterns can significantly reduce testing time while maintaining coverage:

```yaml
# .github/workflows/smart-testing.yml
jobs:
  test-strategy:
    runs-on: ubuntu-latest
    outputs:
      test-matrix: ${{ steps.generate-matrix.outputs.matrix }}
    steps:
      - name: Generate Test Matrix
        id: generate-matrix
        run: |
          # Generate dynamic test matrix based on changes
          if [[ "${{ github.event_name }}" == "push" ]] && [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "matrix=$(cat .github/full-test-matrix.json)" >> $GITHUB_OUTPUT
          else
            echo "matrix=$(cat .github/quick-test-matrix.json)" >> $GITHUB_OUTPUT
          fi

  compatibility-testing:
    needs: test-strategy
    runs-on: ubuntu-latest
    strategy:
      matrix: ${{ fromJson(needs.test-strategy.outputs.test-matrix) }}
    steps:
      - name: Run Compatibility Tests
        run: |
          make test-terraform-version VERSION=${{ matrix.terraform-version }}
```

### Documentation and Reporting

Comprehensive compatibility testing generates substantial data that must be effectively communicated to maintainers and users. Implementing automated reporting and documentation generation ensures testing insights are actionable:

```go
// tools/compatibility-report/main.go
func generateCompatibilityReport(results []TestResult) {
    report := CompatibilityReport{
        GeneratedAt: time.Now(),
        TestedVersions: extractVersions(results),
        Summary: generateSummary(results),
        DetailedResults: results,
    }
    
    // Generate markdown report
    markdownReport := renderMarkdownReport(report)
    writeFile("compatibility-report.md", markdownReport)
    
    // Generate JSON for programmatic consumption
    jsonReport, _ := json.MarshalIndent(report, "", "  ")
    writeFile("compatibility-report.json", jsonReport)
}
```

This comprehensive testing approach ensures your prettyjson provider maintains compatibility across Terraform versions while providing confidence in deployments and clear feedback on version-specific behaviors. The patterns outlined here integrate seamlessly with your existing GitHub Actions workflows and can be adapted based on your specific compatibility requirements and resource constraints.


---

*Generated by Task Master Research Command*  
*Timestamp: 2025-06-27T12:52:01.893Z*
