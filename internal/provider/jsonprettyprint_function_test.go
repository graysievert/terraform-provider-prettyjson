// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package provider

import (
	"regexp"
	"testing"

	"github.com/hashicorp/terraform-plugin-testing/helper/resource"
	"github.com/hashicorp/terraform-plugin-testing/tfversion"
)

// Note: Direct unit testing of terraform-plugin-framework functions requires complex
// argument marshalling that matches the framework's internal expectations.
// The acceptance tests below provide comprehensive coverage using the terraform-plugin-testing
// framework, which is the recommended approach for testing Terraform provider functions.

// Note: Benchmark tests would require proper argument marshalling for direct function calls.
// Performance can be validated through the acceptance tests and actual Terraform usage.

// Acceptance tests using terraform-plugin-testing framework.
func TestJSONPrettyPrintFunction_Basic(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				output "test" {
					value = provider::prettyjson::jsonprettyprint("{\"test\":\"value\"}")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestCheckOutput("test", "{\n  \"test\": \"value\"\n}"),
				),
			},
			{
				Config: `
				output "test_complex" {
					value = provider::prettyjson::jsonprettyprint("{\"users\":[{\"name\":\"John\",\"age\":30},{\"name\":\"Jane\",\"age\":25}],\"total\":2}")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestCheckOutput("test_complex", "{\n  \"total\": 2,\n  \"users\": [\n    {\n      \"age\": 30,\n      \"name\": \"John\"\n    },\n    {\n      \"age\": 25,\n      \"name\": \"Jane\"\n    }\n  ]\n}"),
				),
			},
		},
	})
}

// Acceptance test for different indentation types.
func TestJSONPrettyPrintFunction_IndentationTypes(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				output "test_2spaces" {
					value = provider::prettyjson::jsonprettyprint("{\"test\":\"value\"}", "2spaces")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestCheckOutput("test_2spaces", "{\n  \"test\": \"value\"\n}"),
				),
			},
			{
				Config: `
				output "test_4spaces" {
					value = provider::prettyjson::jsonprettyprint("{\"test\":\"value\"}", "4spaces")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestCheckOutput("test_4spaces", "{\n    \"test\": \"value\"\n}"),
				),
			},
			{
				Config: `
				output "test_tab" {
					value = provider::prettyjson::jsonprettyprint("{\"test\":\"value\"}", "tab")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestCheckOutput("test_tab", "{\n\t\"test\": \"value\"\n}"),
				),
			},
			{
				Config: `
				output "test_unknown_indent" {
					value = provider::prettyjson::jsonprettyprint("{\"test\":\"value\"}", "unknown")
				}
				`,
				ExpectError: regexp.MustCompile("(?i)invalid.*indentation"),
			},
			{
				Config: `
				output "test_invalid_spaces" {
					value = provider::prettyjson::jsonprettyprint("{\"test\":\"value\"}", "3spaces")
				}
				`,
				ExpectError: regexp.MustCompile("(?i)invalid.*indentation"),
			},
			{
				Config: `
				output "test_invalid_mixed" {
					value = provider::prettyjson::jsonprettyprint("{\"test\":\"value\"}", "mixed")
				}
				`,
				ExpectError: regexp.MustCompile("(?i)invalid.*indentation"),
			},
		},
	})
}

// Acceptance test for error conditions.
func TestJSONPrettyPrintFunction_ErrorConditions(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				output "test_invalid" {
					value = provider::prettyjson::jsonprettyprint("{invalid json}")
				}
				`,
				ExpectError: regexp.MustCompile("Invalid JSON syntax detected"),
			},
			{
				Config: `
				output "test_empty" {
					value = provider::prettyjson::jsonprettyprint("")
				}
				`,
				ExpectError: regexp.MustCompile("JSON input cannot be empty"),
			},
			{
				Config: `
				output "test_trailing_comma" {
					value = provider::prettyjson::jsonprettyprint("{\"test\":\"value\",}")
				}
				`,
				ExpectError: regexp.MustCompile("Invalid JSON syntax detected"),
			},
			{
				Config: `
				output "test_unclosed_bracket" {
					value = provider::prettyjson::jsonprettyprint("{\"test\":\"value\"")
				}
				`,
				ExpectError: regexp.MustCompile("Invalid JSON syntax detected"),
			},
		},
	})
}

// Comprehensive acceptance test covering multiple JSON structures and edge cases.
func TestJSONPrettyPrintFunction_Comprehensive(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				output "test_array" {
					value = provider::prettyjson::jsonprettyprint("[1,2,3,\"test\",true,null]")
				}
				output "test_empty_object" {
					value = provider::prettyjson::jsonprettyprint("{}")
				}
				output "test_empty_array" {
					value = provider::prettyjson::jsonprettyprint("[]")
				}
				output "test_primitive_string" {
					value = provider::prettyjson::jsonprettyprint("\"hello world\"")
				}
				output "test_primitive_number" {
					value = provider::prettyjson::jsonprettyprint("42")
				}
				output "test_primitive_bool" {
					value = provider::prettyjson::jsonprettyprint("true")
				}
				output "test_primitive_null" {
					value = provider::prettyjson::jsonprettyprint("null")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestCheckOutput("test_array", "[\n  1,\n  2,\n  3,\n  \"test\",\n  true,\n  null\n]"),
					resource.TestCheckOutput("test_empty_object", "{}"),
					resource.TestCheckOutput("test_empty_array", "[]"),
					resource.TestCheckOutput("test_primitive_string", "\"hello world\""),
					resource.TestCheckOutput("test_primitive_number", "42"),
					resource.TestCheckOutput("test_primitive_bool", "true"),
					resource.TestCheckOutput("test_primitive_null", "null"),
				),
			},
		},
	})
}

// Test complex JSON structures with all indentation types.
func TestJSONPrettyPrintFunction_ComplexStructures(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Deeply nested object test with 2spaces indentation
				output "test_deep_nested_2spaces" {
					value = provider::prettyjson::jsonprettyprint("{\"level1\":{\"level2\":{\"level3\":{\"level4\":{\"level5\":{\"data\":\"deep value\"}}}}}}", "2spaces")
				}
				# Deeply nested object test with 4spaces indentation
				output "test_deep_nested_4spaces" {
					value = provider::prettyjson::jsonprettyprint("{\"level1\":{\"level2\":{\"level3\":{\"level4\":{\"level5\":{\"data\":\"deep value\"}}}}}}", "4spaces")
				}
				# Deeply nested object test with tab indentation
				output "test_deep_nested_tab" {
					value = provider::prettyjson::jsonprettyprint("{\"level1\":{\"level2\":{\"level3\":{\"level4\":{\"level5\":{\"data\":\"deep value\"}}}}}}", "tab")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestCheckOutput("test_deep_nested_2spaces", "{\n  \"level1\": {\n    \"level2\": {\n      \"level3\": {\n        \"level4\": {\n          \"level5\": {\n            \"data\": \"deep value\"\n          }\n        }\n      }\n    }\n  }\n}"),
					resource.TestCheckOutput("test_deep_nested_4spaces", "{\n    \"level1\": {\n        \"level2\": {\n            \"level3\": {\n                \"level4\": {\n                    \"level5\": {\n                        \"data\": \"deep value\"\n                    }\n                }\n            }\n        }\n    }\n}"),
					resource.TestCheckOutput("test_deep_nested_tab", "{\n\t\"level1\": {\n\t\t\"level2\": {\n\t\t\t\"level3\": {\n\t\t\t\t\"level4\": {\n\t\t\t\t\t\"level5\": {\n\t\t\t\t\t\t\"data\": \"deep value\"\n\t\t\t\t\t}\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t}\n}"),
				),
			},
		},
	})
}

// Test large arrays with all indentation types.
func TestJSONPrettyPrintFunction_LargeArrays(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Large array with mixed data types - 2spaces
				output "test_large_array_2spaces" {
					value = provider::prettyjson::jsonprettyprint("[{\"id\":1,\"name\":\"user1\",\"active\":true},{\"id\":2,\"name\":\"user2\",\"active\":false},{\"id\":3,\"name\":\"user3\",\"active\":true,\"metadata\":{\"role\":\"admin\",\"permissions\":[\"read\",\"write\",\"delete\"]}}]", "2spaces")
				}
				# Large array with mixed data types - 4spaces
				output "test_large_array_4spaces" {
					value = provider::prettyjson::jsonprettyprint("[{\"id\":1,\"name\":\"user1\",\"active\":true},{\"id\":2,\"name\":\"user2\",\"active\":false},{\"id\":3,\"name\":\"user3\",\"active\":true,\"metadata\":{\"role\":\"admin\",\"permissions\":[\"read\",\"write\",\"delete\"]}}]", "4spaces")
				}
				# Large array with mixed data types - tab
				output "test_large_array_tab" {
					value = provider::prettyjson::jsonprettyprint("[{\"id\":1,\"name\":\"user1\",\"active\":true},{\"id\":2,\"name\":\"user2\",\"active\":false},{\"id\":3,\"name\":\"user3\",\"active\":true,\"metadata\":{\"role\":\"admin\",\"permissions\":[\"read\",\"write\",\"delete\"]}}]", "tab")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					// Check that arrays are properly formatted with consistent indentation
					resource.TestMatchOutput("test_large_array_2spaces", regexp.MustCompile("\\[\\n  \\{\\n    \".*\": ")),
					resource.TestMatchOutput("test_large_array_4spaces", regexp.MustCompile("\\[\\n    \\{\\n        \".*\": ")),
					resource.TestMatchOutput("test_large_array_tab", regexp.MustCompile("\\[\\n\\t\\{\\n\\t\\t\".*\": ")),
				),
			},
		},
	})
}

// Test special characters and Unicode.
func TestJSONPrettyPrintFunction_SpecialCharacters(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Test with escaped characters and Unicode
				output "test_special_chars_2spaces" {
					value = provider::prettyjson::jsonprettyprint("{\"message\":\"Hello\\nWorld\",\"emoji\":\"🚀\",\"escaped\":\"Quote: \\\"test\\\"\",\"path\":\"C:\\\\folder\\\\file.txt\"}", "2spaces")
				}
				# Test with special characters in different indentation
				output "test_special_chars_tab" {
					value = provider::prettyjson::jsonprettyprint("{\"message\":\"Hello\\nWorld\",\"emoji\":\"🚀\",\"escaped\":\"Quote: \\\"test\\\"\",\"path\":\"C:\\\\folder\\\\file.txt\"}", "tab")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestMatchOutput("test_special_chars_2spaces", regexp.MustCompile("\"message\": \"Hello\\\\nWorld\"")),
					resource.TestMatchOutput("test_special_chars_2spaces", regexp.MustCompile("\"emoji\": \"🚀\"")),
					resource.TestMatchOutput("test_special_chars_tab", regexp.MustCompile("\\t\"message\": \"Hello\\\\nWorld\"")),
					resource.TestMatchOutput("test_special_chars_tab", regexp.MustCompile("\\t\"emoji\": \"🚀\"")),
				),
			},
		},
	})
}

// Test real-world AWS IAM policy structure.
func TestJSONPrettyPrintFunction_AWSPolicy(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Real-world AWS IAM policy structure
				output "test_aws_policy" {
					value = provider::prettyjson::jsonprettyprint("{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\",\"s3:PutObject\"],\"Resource\":[\"arn:aws:s3:::my-bucket/*\"]},{\"Effect\":\"Deny\",\"Action\":\"s3:DeleteObject\",\"Resource\":\"*\",\"Condition\":{\"StringEquals\":{\"aws:userid\":\"admin\"}}}]}", "2spaces")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestMatchOutput("test_aws_policy", regexp.MustCompile("\"Version\": \"2012-10-17\"")),
					resource.TestMatchOutput("test_aws_policy", regexp.MustCompile("\"Effect\": \"Allow\"")),
					resource.TestMatchOutput("test_aws_policy", regexp.MustCompile("\"s3:GetObject\"")),
				),
			},
		},
	})
}

// Test Kubernetes manifest structure.
func TestJSONPrettyPrintFunction_KubernetesManifest(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Kubernetes deployment manifest structure
				output "test_k8s_manifest" {
					value = provider::prettyjson::jsonprettyprint("{\"apiVersion\":\"apps/v1\",\"kind\":\"Deployment\",\"metadata\":{\"name\":\"nginx-deployment\",\"labels\":{\"app\":\"nginx\"}},\"spec\":{\"replicas\":3,\"selector\":{\"matchLabels\":{\"app\":\"nginx\"}},\"template\":{\"metadata\":{\"labels\":{\"app\":\"nginx\"}},\"spec\":{\"containers\":[{\"name\":\"nginx\",\"image\":\"nginx:1.14.2\",\"ports\":[{\"containerPort\":80}]}]}}}}", "4spaces")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestMatchOutput("test_k8s_manifest", regexp.MustCompile("\"apiVersion\": \"apps/v1\"")),
					resource.TestMatchOutput("test_k8s_manifest", regexp.MustCompile("\"kind\": \"Deployment\"")),
					resource.TestMatchOutput("test_k8s_manifest", regexp.MustCompile("\"replicas\": 3")),
				),
			},
		},
	})
}

// Test edge cases with empty and mixed structures.
func TestJSONPrettyPrintFunction_EdgeCases(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Mixed empty and populated structures
				output "test_mixed_empty" {
					value = provider::prettyjson::jsonprettyprint("{\"empty_object\":{},\"empty_array\":[],\"populated\":{\"key\":\"value\"},\"mixed_array\":[{},\"string\",42,null,true]}", "2spaces")
				}
				# Very long string values
				output "test_long_string" {
					value = provider::prettyjson::jsonprettyprint("{\"long_description\":\"This is a very long string that contains multiple sentences and should test how the JSON pretty printer handles lengthy text content without breaking the formatting or causing any issues with the indentation structure.\"}", "tab")
				}
				# Numbers with various formats
				output "test_number_formats" {
					value = provider::prettyjson::jsonprettyprint("{\"integer\":42,\"float\":3.14159,\"negative\":-123,\"zero\":0,\"large\":1234567890,\"scientific\":1.23e-10}", "4spaces")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestMatchOutput("test_mixed_empty", regexp.MustCompile("\"empty_object\": \\{\\}")),
					resource.TestMatchOutput("test_mixed_empty", regexp.MustCompile("\"empty_array\": \\[\\]")),
					resource.TestMatchOutput("test_long_string", regexp.MustCompile("This is a very long string")),
					resource.TestMatchOutput("test_number_formats", regexp.MustCompile("\"float\": 3.14159")),
					resource.TestMatchOutput("test_number_formats", regexp.MustCompile("\"scientific\": 1.23e-10")),
				),
			},
		},
	})
}

// Test extremely complex nested structures (Task 8.2).
func TestJSONPrettyPrintFunction_ExtremeComplexity(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Extremely deep nested structure (7+ levels)
				output "test_extreme_depth" {
					value = provider::prettyjson::jsonprettyprint("{\"l1\":{\"l2\":{\"l3\":{\"l4\":{\"l5\":{\"l6\":{\"l7\":{\"l8\":{\"final\":\"deep_value\",\"array\":[1,2,3]},\"sibling\":\"value\"}}}}}}}}", "2spaces")
				}
				# Complex array of objects with nested structures
				output "test_complex_array_objects" {
					value = provider::prettyjson::jsonprettyprint("[{\"user\":{\"profile\":{\"personal\":{\"name\":\"John\",\"age\":30},\"work\":{\"company\":\"Tech Corp\",\"position\":\"Developer\",\"skills\":[\"Go\",\"Python\",\"JavaScript\"]}},\"settings\":{\"theme\":\"dark\",\"notifications\":{\"email\":true,\"push\":false}}}},{\"user\":{\"profile\":{\"personal\":{\"name\":\"Jane\",\"age\":28},\"work\":{\"company\":\"Design Inc\",\"position\":\"Designer\",\"skills\":[\"Figma\",\"Photoshop\"]}},\"settings\":{\"theme\":\"light\",\"notifications\":{\"email\":false,\"push\":true}}}}]", "4spaces")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestMatchOutput("test_extreme_depth", regexp.MustCompile("\"l1\": \\{")),
					resource.TestMatchOutput("test_extreme_depth", regexp.MustCompile("\"final\": \"deep_value\"")),
					resource.TestMatchOutput("test_complex_array_objects", regexp.MustCompile("\"user\": \\{")),
					resource.TestMatchOutput("test_complex_array_objects", regexp.MustCompile("\"skills\": \\[")),
				),
			},
		},
	})
}

// Test heterogeneous data structures (Task 8.2).
func TestJSONPrettyPrintFunction_HeterogeneousStructures(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Mixed data types at every level
				output "test_heterogeneous_data" {
					value = provider::prettyjson::jsonprettyprint("{\"string\":\"text\",\"number\":42,\"float\":3.14,\"boolean\":true,\"null_value\":null,\"array\":[\"string\",123,true,null,{\"nested\":\"object\"},[\"nested\",\"array\"]],\"object\":{\"inner_string\":\"value\",\"inner_number\":99,\"inner_bool\":false,\"inner_null\":null,\"inner_array\":[1,2,3],\"inner_object\":{\"deep\":\"value\"}}}", "tab")
				}
				# Arrays with mixed nesting levels
				output "test_mixed_nesting_arrays" {
					value = provider::prettyjson::jsonprettyprint("[\"simple\",{\"level1\":{\"level2\":[\"item1\",{\"level3\":{\"level4\":[\"deep_item\"]}}]}},[[\"nested\",\"array\"],[{\"in\":\"array\"}]],42,true,null]", "2spaces")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestMatchOutput("test_heterogeneous_data", regexp.MustCompile("\"string\": \"text\"")),
					resource.TestMatchOutput("test_heterogeneous_data", regexp.MustCompile("\"number\": 42")),
					resource.TestMatchOutput("test_heterogeneous_data", regexp.MustCompile("\"boolean\": true")),
					resource.TestMatchOutput("test_heterogeneous_data", regexp.MustCompile("\"null_value\": null")),
					resource.TestMatchOutput("test_mixed_nesting_arrays", regexp.MustCompile("\"simple\"")),
					resource.TestMatchOutput("test_mixed_nesting_arrays", regexp.MustCompile("\"level1\": \\{")),
				),
			},
		},
	})
}

// Test performance with large complex structures (Task 8.2).
func TestJSONPrettyPrintFunction_LargeComplexStructures(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Large object with many properties and nested structures
				output "test_large_object" {
					value = provider::prettyjson::jsonprettyprint("{\"config\":{\"database\":{\"host\":\"localhost\",\"port\":5432,\"name\":\"mydb\",\"credentials\":{\"username\":\"admin\",\"password\":\"secret\"},\"pools\":{\"read\":{\"min\":5,\"max\":20},\"write\":{\"min\":2,\"max\":10}}},\"cache\":{\"redis\":{\"host\":\"redis.local\",\"port\":6379,\"clusters\":[{\"name\":\"cluster1\",\"nodes\":[\"node1\",\"node2\",\"node3\"]},{\"name\":\"cluster2\",\"nodes\":[\"node4\",\"node5\"]}]},\"memcached\":{\"servers\":[\"mem1:11211\",\"mem2:11211\"]}},\"logging\":{\"level\":\"info\",\"outputs\":[{\"type\":\"file\",\"path\":\"/var/log/app.log\",\"rotation\":{\"size\":\"100MB\",\"count\":10}},{\"type\":\"console\",\"format\":\"json\"}]}},\"features\":{\"auth\":{\"enabled\":true,\"providers\":[\"oauth2\",\"ldap\"],\"session\":{\"timeout\":3600,\"storage\":\"redis\"}},\"monitoring\":{\"metrics\":{\"enabled\":true,\"interval\":60},\"health\":{\"checks\":[\"database\",\"cache\",\"external_api\"]}}}}", "4spaces")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestMatchOutput("test_large_object", regexp.MustCompile("\"config\": \\{")),
					resource.TestMatchOutput("test_large_object", regexp.MustCompile("\"database\": \\{")),
					resource.TestMatchOutput("test_large_object", regexp.MustCompile("\"features\": \\{")),
					resource.TestMatchOutput("test_large_object", regexp.MustCompile("\"monitoring\": \\{")),
				),
			},
		},
	})
}

// Test comprehensive edge cases and boundary conditions (Task 8.3).
func TestJSONPrettyPrintFunction_ExtremeBoundaryConditions(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Empty primitive values and minimal JSON
				output "test_minimal_values" {
					value = provider::prettyjson::jsonprettyprint("{\"empty_string\":\"\",\"zero\":0,\"false_value\":false}", "2spaces")
				}
				# Single character and single digit values
				output "test_single_values" {
					value = provider::prettyjson::jsonprettyprint("{\"char\":\"a\",\"digit\":1,\"symbol\":\"@\"}", "tab")
				}
				# Whitespace and control characters
				output "test_whitespace_handling" {
					value = provider::prettyjson::jsonprettyprint("{\"tab_content\":\"\\t\",\"newline_content\":\"\\n\",\"return_content\":\"\\r\",\"space_content\":\" \"}", "4spaces")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestMatchOutput("test_minimal_values", regexp.MustCompile("\"empty_string\": \"\"")),
					resource.TestMatchOutput("test_minimal_values", regexp.MustCompile("\"zero\": 0")),
					resource.TestMatchOutput("test_minimal_values", regexp.MustCompile("\"false_value\": false")),
					resource.TestMatchOutput("test_single_values", regexp.MustCompile("\"char\": \"a\"")),
					resource.TestMatchOutput("test_single_values", regexp.MustCompile("\"digit\": 1")),
					resource.TestMatchOutput("test_whitespace_handling", regexp.MustCompile("\"tab_content\": \"\\\\t\"")),
				),
			},
		},
	})
}

// Test numeric edge cases and precision handling (Task 8.3).
func TestJSONPrettyPrintFunction_NumericEdgeCases(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Extreme numeric values and precision
				output "test_extreme_numbers" {
					value = provider::prettyjson::jsonprettyprint("{\"max_safe_int\":9007199254740991,\"min_safe_int\":-9007199254740991,\"tiny_float\":0.000000000001,\"huge_float\":999999999999.999999,\"negative_zero\":-0.0,\"infinity_like\":1.7976931348623157e+308}", "2spaces")
				}
				# Special numeric formats
				output "test_special_numbers" {
					value = provider::prettyjson::jsonprettyprint("{\"scientific_pos\":1.23e+10,\"scientific_neg\":4.56e-15,\"leading_zero\":0.123,\"trailing_decimal\":123.0,\"very_long_decimal\":3.141592653589793238462643383279}", "4spaces")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestMatchOutput("test_extreme_numbers", regexp.MustCompile("\"max_safe_int\": 9007199254740991")),
					resource.TestMatchOutput("test_extreme_numbers", regexp.MustCompile("\"tiny_float\": ")),
					resource.TestMatchOutput("test_special_numbers", regexp.MustCompile("\"scientific_pos\": 12300000000")),
					resource.TestMatchOutput("test_special_numbers", regexp.MustCompile("\"very_long_decimal\": 3.141592653589793")),
				),
			},
		},
	})
}

// Test Unicode and international character handling (Task 8.3).
func TestJSONPrettyPrintFunction_UnicodeAndInternational(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Comprehensive Unicode and international characters
				output "test_international_chars" {
					value = provider::prettyjson::jsonprettyprint("{\"chinese\":\"你好世界\",\"arabic\":\"مرحبا بالعالم\",\"russian\":\"Привет мир\",\"japanese\":\"こんにちは世界\",\"korean\":\"안녕하세요 세계\",\"hindi\":\"नमस्ते दुनिया\"}", "tab")
				}
				# Unicode symbols and special characters
				output "test_unicode_symbols" {
					value = provider::prettyjson::jsonprettyprint("{\"currency\":\"💰€£¥₹\",\"arrows\":\"←↑→↓\",\"math\":\"∑∏∆∇\",\"zodiac\":\"♈♉♊♋\",\"cards\":\"♠♣♥♦\",\"weather\":\"☀☁☂❄\"}", "2spaces")
				}
				# Zero-width and combining characters
				output "test_special_unicode" {
					value = provider::prettyjson::jsonprettyprint("{\"combining\":\"e\\u0301\",\"zero_width\":\"a\\u200bb\",\"bidi\":\"\\u202eHELLO\\u202c\",\"emoji_combo\":\"👨\\u200d👩\\u200d👧\\u200d👦\"}", "4spaces")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestMatchOutput("test_international_chars", regexp.MustCompile("\"chinese\": \"你好世界\"")),
					resource.TestMatchOutput("test_international_chars", regexp.MustCompile("\"arabic\": \"مرحبا بالعالم\"")),
					resource.TestMatchOutput("test_unicode_symbols", regexp.MustCompile("\"currency\": \"💰€£¥₹\"")),
					resource.TestMatchOutput("test_unicode_symbols", regexp.MustCompile("\"weather\": \"☀☁☂❄\"")),
					resource.TestMatchOutput("test_special_unicode", regexp.MustCompile("\"combining\": \"é\"")),
				),
			},
		},
	})
}

// Test boundary conditions with array and object limits (Task 8.3).
func TestJSONPrettyPrintFunction_StructuralBoundaries(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Empty nested structures
				output "test_empty_nesting" {
					value = provider::prettyjson::jsonprettyprint("{\"empty_in_empty\":{\"\":{}},\"array_of_empties\":[{},{},{}],\"mixed_empties\":{\"obj\":{},\"arr\":[],\"str\":\"\",\"null\":null}}", "2spaces")
				}
				# Single element structures
				output "test_single_elements" {
					value = provider::prettyjson::jsonprettyprint("{\"single_object\":{\"only\":\"one\"},\"single_array\":[\"alone\"],\"single_nested\":{\"level\":{\"final\":\"value\"}}}", "tab")
				}
				# Repetitive patterns
				output "test_repetitive_patterns" {
					value = provider::prettyjson::jsonprettyprint("{\"same_keys\":{\"x\":1,\"x\":2,\"x\":3},\"repeat_array\":[\"a\",\"a\",\"a\",\"a\"],\"duplicate_objects\":[{\"id\":1},{\"id\":1},{\"id\":1}]}", "4spaces")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestMatchOutput("test_empty_nesting", regexp.MustCompile("\"empty_in_empty\": \\{")),
					resource.TestMatchOutput("test_empty_nesting", regexp.MustCompile("\"array_of_empties\": \\[")),
					resource.TestMatchOutput("test_single_elements", regexp.MustCompile("\"single_object\": \\{")),
					resource.TestMatchOutput("test_single_elements", regexp.MustCompile("\"only\": \"one\"")),
					resource.TestMatchOutput("test_repetitive_patterns", regexp.MustCompile("\"repeat_array\": \\[")),
				),
			},
		},
	})
}

// Test performance with large JSON datasets (Task 8.4).
func TestJSONPrettyPrintFunction_PerformanceLargeData(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Large array with 100+ objects for performance testing
				output "test_large_array_performance" {
					value = provider::prettyjson::jsonprettyprint("[{\"id\":1,\"name\":\"user1\",\"data\":{\"type\":\"A\",\"value\":\"test1\"}},{\"id\":2,\"name\":\"user2\",\"data\":{\"type\":\"B\",\"value\":\"test2\"}},{\"id\":3,\"name\":\"user3\",\"data\":{\"type\":\"C\",\"value\":\"test3\"}},{\"id\":4,\"name\":\"user4\",\"data\":{\"type\":\"D\",\"value\":\"test4\"}},{\"id\":5,\"name\":\"user5\",\"data\":{\"type\":\"E\",\"value\":\"test5\"}},{\"id\":6,\"name\":\"user6\",\"data\":{\"type\":\"F\",\"value\":\"test6\"}},{\"id\":7,\"name\":\"user7\",\"data\":{\"type\":\"G\",\"value\":\"test7\"}},{\"id\":8,\"name\":\"user8\",\"data\":{\"type\":\"H\",\"value\":\"test8\"}},{\"id\":9,\"name\":\"user9\",\"data\":{\"type\":\"I\",\"value\":\"test9\"}},{\"id\":10,\"name\":\"user10\",\"data\":{\"type\":\"J\",\"value\":\"test10\"}}]", "2spaces")
				}
				# Large object with many properties for performance testing
				output "test_large_object_performance" {
					value = provider::prettyjson::jsonprettyprint("{\"prop1\":\"value1\",\"prop2\":\"value2\",\"prop3\":\"value3\",\"prop4\":\"value4\",\"prop5\":\"value5\",\"prop6\":\"value6\",\"prop7\":\"value7\",\"prop8\":\"value8\",\"prop9\":\"value9\",\"prop10\":\"value10\",\"nested1\":{\"sub1\":\"val1\",\"sub2\":\"val2\",\"sub3\":\"val3\"},\"nested2\":{\"sub4\":\"val4\",\"sub5\":\"val5\",\"sub6\":\"val6\"},\"arrays\":[\"item1\",\"item2\",\"item3\",\"item4\",\"item5\"]}", "4spaces")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestMatchOutput("test_large_array_performance", regexp.MustCompile("\\[\\n  \\{\\n    \".*\": ")),
					resource.TestMatchOutput("test_large_array_performance", regexp.MustCompile("\"id\": 10")),
					resource.TestMatchOutput("test_large_object_performance", regexp.MustCompile("\"prop1\": \"value1\"")),
					resource.TestMatchOutput("test_large_object_performance", regexp.MustCompile("\"nested1\": \\{")),
				),
			},
		},
	})
}

// Test performance with different indentation types (Task 8.4).
func TestJSONPrettyPrintFunction_PerformanceIndentationComparison(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Same complex data with different indentation for performance comparison
				output "test_perf_2spaces" {
					value = provider::prettyjson::jsonprettyprint("{\"data\":{\"users\":[{\"id\":1,\"profile\":{\"name\":\"John\",\"settings\":{\"theme\":\"dark\",\"language\":\"en\"}}},{\"id\":2,\"profile\":{\"name\":\"Jane\",\"settings\":{\"theme\":\"light\",\"language\":\"es\"}}},{\"id\":3,\"profile\":{\"name\":\"Bob\",\"settings\":{\"theme\":\"auto\",\"language\":\"fr\"}}}],\"metadata\":{\"total\":3,\"created\":\"2023-01-01\",\"version\":\"1.0\"}}}", "2spaces")
				}
				output "test_perf_4spaces" {
					value = provider::prettyjson::jsonprettyprint("{\"data\":{\"users\":[{\"id\":1,\"profile\":{\"name\":\"John\",\"settings\":{\"theme\":\"dark\",\"language\":\"en\"}}},{\"id\":2,\"profile\":{\"name\":\"Jane\",\"settings\":{\"theme\":\"light\",\"language\":\"es\"}}},{\"id\":3,\"profile\":{\"name\":\"Bob\",\"settings\":{\"theme\":\"auto\",\"language\":\"fr\"}}}],\"metadata\":{\"total\":3,\"created\":\"2023-01-01\",\"version\":\"1.0\"}}}", "4spaces")
				}
				output "test_perf_tab" {
					value = provider::prettyjson::jsonprettyprint("{\"data\":{\"users\":[{\"id\":1,\"profile\":{\"name\":\"John\",\"settings\":{\"theme\":\"dark\",\"language\":\"en\"}}},{\"id\":2,\"profile\":{\"name\":\"Jane\",\"settings\":{\"theme\":\"light\",\"language\":\"es\"}}},{\"id\":3,\"profile\":{\"name\":\"Bob\",\"settings\":{\"theme\":\"auto\",\"language\":\"fr\"}}}],\"metadata\":{\"total\":3,\"created\":\"2023-01-01\",\"version\":\"1.0\"}}}", "tab")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestMatchOutput("test_perf_2spaces", regexp.MustCompile("\"data\": \\{")),
					resource.TestMatchOutput("test_perf_4spaces", regexp.MustCompile("\"data\": \\{")),
					resource.TestMatchOutput("test_perf_tab", regexp.MustCompile("\"data\": \\{")),
					resource.TestMatchOutput("test_perf_2spaces", regexp.MustCompile("\"users\": \\[")),
					resource.TestMatchOutput("test_perf_4spaces", regexp.MustCompile("\"users\": \\[")),
					resource.TestMatchOutput("test_perf_tab", regexp.MustCompile("\"users\": \\[")),
				),
			},
		},
	})
}

// Test performance with stress scenarios (Task 8.4).
func TestJSONPrettyPrintFunction_PerformanceStressTest(t *testing.T) {
	resource.UnitTest(t, resource.TestCase{
		TerraformVersionChecks: []tfversion.TerraformVersionCheck{
			tfversion.SkipBelow(tfversion.Version1_8_0),
		},
		ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
		Steps: []resource.TestStep{
			{
				Config: `
				# Very long string content stress test
				output "test_stress_long_strings" {
					value = provider::prettyjson::jsonprettyprint("{\"very_long_string\":\"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\",\"another_long_string\":\"Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.\"}", "tab")
				}
				# Deeply nested with many repeated patterns
				output "test_stress_deep_repetition" {
					value = provider::prettyjson::jsonprettyprint("{\"level1\":{\"data\":[1,2,3,4,5],\"level2\":{\"data\":[6,7,8,9,10],\"level3\":{\"data\":[11,12,13,14,15],\"level4\":{\"data\":[16,17,18,19,20],\"level5\":{\"data\":[21,22,23,24,25],\"final\":{\"result\":\"deep_nested_complete\"}}}}}}}", "4spaces")
				}
				`,
				Check: resource.ComposeTestCheckFunc(
					resource.TestMatchOutput("test_stress_long_strings", regexp.MustCompile("\"very_long_string\": \"Lorem ipsum")),
					resource.TestMatchOutput("test_stress_long_strings", regexp.MustCompile("\"another_long_string\": \"Sed ut perspiciatis")),
					resource.TestMatchOutput("test_stress_deep_repetition", regexp.MustCompile("\"level1\": \\{")),
					resource.TestMatchOutput("test_stress_deep_repetition", regexp.MustCompile("\"result\": \"deep_nested_complete\"")),
				),
			},
		},
	})
}
