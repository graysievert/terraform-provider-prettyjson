// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package provider

import (
	"context"
	"fmt"
	"os"
	"regexp"
	"strings"
	"testing"

	"github.com/hashicorp/terraform-plugin-framework/function"
	"github.com/hashicorp/terraform-plugin-testing/helper/resource"
	"github.com/hashicorp/terraform-plugin-testing/terraform"
	"github.com/hashicorp/terraform-plugin-testing/tfversion"
)

// TestTerraformVersionCompatibility tests the provider across different Terraform versions.
func TestTerraformVersionCompatibility(t *testing.T) {
	// Get the current Terraform version from environment.
	tfVersion := os.Getenv("TF_VERSION")
	if tfVersion == "" {
		t.Skip("TF_VERSION environment variable not set, skipping version-specific tests")
	}

	t.Logf("Testing with Terraform version: %s", tfVersion)

	testCases := []struct {
		name          string
		input         string
		expected      string
		skipVersions  []string
		minVersion    string
		expectedError string
	}{
		{
			name:       "basic_object_compatibility",
			input:      `{"key": "value"}`,
			expected:   "{\n  \"key\": \"value\"\n}",
			minVersion: "1.8.0",
		},
		{
			name:       "complex_nested_compatibility",
			input:      `{"nested": {"array": [1, 2, 3], "bool": true}}`,
			expected:   "{\n  \"nested\": {\n    \"array\": [\n      1,\n      2,\n      3\n    ],\n    \"bool\": true\n  }\n}",
			minVersion: "1.8.0",
		},
		{
			name:          "error_handling_compatibility",
			input:         `{"invalid": json}`,
			expectedError: "Invalid JSON syntax",
			minVersion:    "1.8.0",
		},
		{
			name:       "unicode_compatibility",
			input:      `{"unicode": "Hello 世界 🌍"}`,
			expected:   "{\n  \"unicode\": \"Hello 世界 🌍\"\n}",
			minVersion: "1.8.0",
		},
	}

	for _, tc := range testCases {
		t.Run(fmt.Sprintf("%s_tf_%s", tc.name, tfVersion), func(t *testing.T) {
			// Skip test for specific versions if specified.
			for _, skipVersion := range tc.skipVersions {
				if tfVersion == skipVersion {
					t.Skipf("Skipping test for Terraform version %s", skipVersion)
				}
			}

			// Version check setup.
			var versionChecks []tfversion.TerraformVersionCheck
			if tc.minVersion != "" {
				switch tc.minVersion {
				case "1.8.0":
					versionChecks = append(versionChecks, tfversion.SkipBelow(tfversion.Version1_8_0))
				case "1.9.0":
					versionChecks = append(versionChecks, tfversion.SkipBelow(tfversion.Version1_9_0))
				}
			}

			if tc.expectedError != "" {
				// Test error cases.
				resource.UnitTest(t, resource.TestCase{
					TerraformVersionChecks:   versionChecks,
					ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
					Steps: []resource.TestStep{
						{
							Config: fmt.Sprintf(`
								output "result" {
								  value = provider::prettyjson::jsonprettyprint(%q)
								}
							`, tc.input),
							ExpectError: regexp.MustCompile(tc.expectedError),
						},
					},
				})
			} else {
				// Test success cases.
				resource.UnitTest(t, resource.TestCase{
					TerraformVersionChecks:   versionChecks,
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
			}
		})
	}
}

// TestTerraformVersionProtocolCompatibility tests protocol-specific behaviors.
func TestTerraformVersionProtocolCompatibility(t *testing.T) {
	tfVersion := os.Getenv("TF_VERSION")
	if tfVersion == "" {
		t.Skip("TF_VERSION environment variable not set, skipping protocol tests")
	}

	t.Logf("Testing protocol compatibility with Terraform version: %s", tfVersion)

	// Test function metadata consistency across versions.
	t.Run("function_metadata_consistency", func(t *testing.T) {
		fn := NewJSONPrettyPrintFunction()
		ctx := context.Background()

		// Test Metadata method.
		metadataReq := function.MetadataRequest{}
		metadataResp := &function.MetadataResponse{}
		fn.Metadata(ctx, metadataReq, metadataResp)

		if metadataResp.Name != "jsonprettyprint" {
			t.Errorf("Expected function name 'jsonprettyprint', got '%s'", metadataResp.Name)
		}

		// Test Definition method.
		definitionReq := function.DefinitionRequest{}
		definitionResp := &function.DefinitionResponse{}
		fn.Definition(ctx, definitionReq, definitionResp)

		if len(definitionResp.Definition.Parameters) == 0 {
			t.Error("Expected function to have parameters defined")
		}
	})

	// Test function execution through acceptance testing framework.
	t.Run("function_execution_consistency", func(t *testing.T) {
		// Use acceptance testing for function execution validation.
		resource.UnitTest(t, resource.TestCase{
			TerraformVersionChecks:   []tfversion.TerraformVersionCheck{tfversion.SkipBelow(tfversion.Version1_8_0)},
			ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
			Steps: []resource.TestStep{
				{
					Config: `
						output "simple_test" {
						  value = provider::prettyjson::jsonprettyprint("{\"test\": \"value\"}")
						}
						output "array_test" {
						  value = provider::prettyjson::jsonprettyprint("[1,2,3]")
						}
					`,
					Check: resource.ComposeTestCheckFunc(
						resource.TestCheckOutput("simple_test", "{\n  \"test\": \"value\"\n}"),
						resource.TestCheckOutput("array_test", "[\n  1,\n  2,\n  3\n]"),
					),
				},
			},
		})
	})
}

// TestTerraformVersionErrorHandling tests error handling across versions.
func TestTerraformVersionErrorHandling(t *testing.T) {
	tfVersion := os.Getenv("TF_VERSION")
	if tfVersion == "" {
		t.Skip("TF_VERSION environment variable not set, skipping error handling tests")
	}

	t.Logf("Testing error handling with Terraform version: %s", tfVersion)

	errorTestCases := []struct {
		name          string
		input         string
		expectedError string
		minVersion    string
	}{
		{
			name:          "invalid_json_error",
			input:         `{"invalid": json}`,
			expectedError: "invalid JSON",
			minVersion:    "1.8.0",
		},
		{
			name:          "empty_input_error",
			input:         ``,
			expectedError: "empty input",
			minVersion:    "1.8.0",
		},
		{
			name:          "null_input_error",
			input:         `null`,
			expectedError: "", // null should be handled gracefully
			minVersion:    "1.8.0",
		},
	}

	for _, tc := range errorTestCases {
		t.Run(fmt.Sprintf("%s_tf_%s", tc.name, tfVersion), func(t *testing.T) {
			var versionChecks []tfversion.TerraformVersionCheck
			if tc.minVersion != "" {
				switch tc.minVersion {
				case "1.8.0":
					versionChecks = append(versionChecks, tfversion.SkipBelow(tfversion.Version1_8_0))
				case "1.9.0":
					versionChecks = append(versionChecks, tfversion.SkipBelow(tfversion.Version1_9_0))
				}
			}

			if tc.expectedError != "" {
				resource.UnitTest(t, resource.TestCase{
					TerraformVersionChecks:   versionChecks,
					ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
					Steps: []resource.TestStep{
						{
							Config: fmt.Sprintf(`
								output "result" {
								  value = provider::prettyjson::jsonprettyprint(%q)
								}
							`, tc.input),
							ExpectError: regexp.MustCompile(tc.expectedError),
						},
					},
				})
			} else {
				// Test that null input is handled gracefully.
				resource.UnitTest(t, resource.TestCase{
					TerraformVersionChecks:   versionChecks,
					ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
					Steps: []resource.TestStep{
						{
							Config: fmt.Sprintf(`
								output "result" {
								  value = provider::prettyjson::jsonprettyprint(%q)
								}
							`, tc.input),
							Check: resource.ComposeTestCheckFunc(
								resource.TestCheckOutput("result", "null"),
							),
						},
					},
				})
			}
		})
	}
}

// TestTerraformVersionPerformance tests performance characteristics across versions.
func TestTerraformVersionPerformance(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping performance tests in short mode")
	}

	tfVersion := os.Getenv("TF_VERSION")
	if tfVersion == "" {
		t.Skip("TF_VERSION environment variable not set, skipping performance tests")
	}

	t.Logf("Testing performance with Terraform version: %s", tfVersion)

	// Generate test data of different sizes.
	smallJSON := `{"key": "value"}`
	mediumJSON := generateMediumJSON()
	largeJSON := generateLargeJSON()

	testCases := []struct {
		name string
		json string
	}{
		{"small_json_performance", smallJSON},
		{"medium_json_performance", mediumJSON},
		{"large_json_performance", largeJSON},
	}

	for _, tc := range testCases {
		t.Run(fmt.Sprintf("%s_tf_%s", tc.name, tfVersion), func(t *testing.T) {
			resource.UnitTest(t, resource.TestCase{
				TerraformVersionChecks:   []tfversion.TerraformVersionCheck{tfversion.SkipBelow(tfversion.Version1_8_0)},
				ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
				Steps: []resource.TestStep{
					{
						Config: fmt.Sprintf(`
							output "result" {
							  value = length(provider::prettyjson::jsonprettyprint(%q))
							}
						`, tc.json),
						Check: resource.ComposeTestCheckFunc(
							func(s *terraform.State) error {
								// Just verify the operation completes successfully.
								return nil
							},
						),
					},
				},
			})
		})
	}
}

// TestTerraformVersionIndentationOptions tests indentation across versions.
func TestTerraformVersionIndentationOptions(t *testing.T) {
	tfVersion := os.Getenv("TF_VERSION")
	if tfVersion == "" {
		t.Skip("TF_VERSION environment variable not set, skipping indentation tests")
	}

	t.Logf("Testing indentation options with Terraform version: %s", tfVersion)

	testJSON := `{"nested": {"array": [1, 2], "bool": true}}`

	indentationTestCases := []struct {
		name     string
		indent   string
		expected string
	}{
		{
			name:     "two_spaces",
			indent:   "2spaces",
			expected: "{\n  \"nested\": {\n    \"array\": [\n      1,\n      2\n    ],\n    \"bool\": true\n  }\n}",
		},
		{
			name:     "four_spaces",
			indent:   "4spaces",
			expected: "{\n    \"nested\": {\n        \"array\": [\n            1,\n            2\n        ],\n        \"bool\": true\n    }\n}",
		},
		{
			name:     "tab",
			indent:   "tab",
			expected: "{\n\t\"nested\": {\n\t\t\"array\": [\n\t\t\t1,\n\t\t\t2\n\t\t],\n\t\t\"bool\": true\n\t}\n}",
		},
	}

	for _, tc := range indentationTestCases {
		t.Run(fmt.Sprintf("%s_tf_%s", tc.name, tfVersion), func(t *testing.T) {
			resource.UnitTest(t, resource.TestCase{
				TerraformVersionChecks:   []tfversion.TerraformVersionCheck{tfversion.SkipBelow(tfversion.Version1_8_0)},
				ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
				Steps: []resource.TestStep{
					{
						Config: fmt.Sprintf(`
							output "result" {
							  value = provider::prettyjson::jsonprettyprint(%q, %q)
							}
						`, testJSON, tc.indent),
						Check: resource.ComposeTestCheckFunc(
							resource.TestCheckOutput("result", tc.expected),
						),
					},
				},
			})
		})
	}
}

// Helper functions for generating test data.
func generateMediumJSON() string {
	var builder strings.Builder
	builder.WriteString(`{"data": {`)
	for i := 0; i < 50; i++ {
		if i > 0 {
			builder.WriteString(`, `)
		}
		builder.WriteString(fmt.Sprintf(`"key%d": "value%d"`, i, i))
	}
	builder.WriteString(`}}`)
	return builder.String()
}

func generateLargeJSON() string {
	var builder strings.Builder
	builder.WriteString(`{"items": [`)
	for i := 0; i < 100; i++ {
		if i > 0 {
			builder.WriteString(`, `)
		}
		builder.WriteString(fmt.Sprintf(`{"id": %d, "name": "item%d", "active": %t}`, i, i, i%2 == 0))
	}
	builder.WriteString(`]}`)
	return builder.String()
}
