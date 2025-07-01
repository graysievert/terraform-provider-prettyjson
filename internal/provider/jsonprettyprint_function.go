// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package provider

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/hashicorp/terraform-plugin-framework/function"
	"github.com/hashicorp/terraform-plugin-log/tflog"
)

var (
	_ function.Function = JSONPrettyPrintFunction{}
)

// Error categories for comprehensive error handling (Task 5).
const (
	// MaxJSONSize defines the maximum allowed JSON input size (10MB).
	MaxJSONSize = 10 * 1024 * 1024 // 10MB
	// LargeJSONWarningSize defines the threshold for large input warnings (1MB).
	LargeJSONWarningSize = 1024 * 1024 // 1MB
)

// Error classification constants for Task 5.
const (
	ErrorTypeValidation = "validation_error"
	ErrorTypeParsing    = "parsing_error"
	ErrorTypeProcessing = "processing_error"
	ErrorTypeSystem     = "system_error"
)

func NewJSONPrettyPrintFunction() function.Function {
	return JSONPrettyPrintFunction{}
}

type JSONPrettyPrintFunction struct{}

func (r JSONPrettyPrintFunction) Metadata(ctx context.Context, req function.MetadataRequest, resp *function.MetadataResponse) {
	// Add structured logging context for function metadata operations
	ctx = tflog.SetField(ctx, "function_name", "jsonprettyprint")
	ctx = tflog.SetField(ctx, "operation", "metadata")

	tflog.Debug(ctx, "Starting function metadata operation")

	resp.Name = "jsonprettyprint"

	tflog.Debug(ctx, "Function metadata operation completed", map[string]any{
		"function_name": resp.Name,
	})
}

func (r JSONPrettyPrintFunction) Definition(ctx context.Context, req function.DefinitionRequest, resp *function.DefinitionResponse) {
	// Add structured logging context for function definition operations
	ctx = tflog.SetField(ctx, "function_name", "jsonprettyprint")
	ctx = tflog.SetField(ctx, "operation", "definition")

	tflog.Debug(ctx, "Starting function definition operation")

	// Define comprehensive function schema with proper validation and logging
	resp.Definition = function.Definition{
		Summary: "Pretty-print JSON with configurable indentation",
		MarkdownDescription: `Formats JSON strings with configurable indentation styles for improved readability.

## Overview

This function takes a JSON string and returns a formatted version with consistent indentation and line breaks. It validates the input JSON syntax and provides detailed error messages for invalid input.

## Supported Indentation Types

- **2spaces** (default): Two-space indentation, commonly used in JavaScript and many style guides
- **4spaces**: Four-space indentation, popular in Python and many enterprise coding standards  
- **tab**: Tab character indentation, preferred by some development teams

## Input Validation

- Validates JSON syntax using Go's built-in JSON parser
- Checks for empty input and provides helpful error messages
- Enforces maximum input size limit (10MB) for performance and memory safety
- Logs performance warnings for large inputs (>1MB)

## Error Handling

Provides comprehensive error messages for:
- Invalid JSON syntax with remediation suggestions
- Invalid indentation type parameters
- Empty input validation
- Size limit enforcement
- JSON formatting failures`,
		Parameters: []function.Parameter{
			function.StringParameter{
				Name:                "json_string",
				MarkdownDescription: "The JSON string to format and pretty-print.\n\n**Requirements:**\n- Must be valid JSON syntax\n- Cannot be empty\n- Maximum size: 10MB\n- Supports all JSON data types (objects, arrays, strings, numbers, booleans, null)\n\n**Examples:**\n- Simple object: `{\"name\":\"value\"}`\n- Complex nested: `{\"app\":{\"name\":\"test\",\"config\":{\"debug\":true}}}`\n- Array: `[{\"id\":1},{\"id\":2}]`\n\n**Validation:**\nThe function performs comprehensive JSON validation and will return detailed error messages for syntax issues such as:\n- Missing quotes around strings\n- Trailing commas\n- Unescaped characters\n- Mismatched brackets or braces",
				AllowNullValue:      false,
				AllowUnknownValues:  false,
			},
		},
		VariadicParameter: function.StringParameter{
			Name:                "indentation_type",
			MarkdownDescription: "Optional parameter to specify the indentation style for formatting.\n\n**Valid Options:**\n- `\"2spaces\"` (default) - Two-space indentation\n- `\"4spaces\"` - Four-space indentation\n- `\"tab\"` - Tab character indentation\n\n**Default Behavior:**\nIf not specified, defaults to `\"2spaces\"` indentation.\n\n**Examples:**\n- `provider::prettyjson::jsonprettyprint(json_string)` - Uses default 2-space indentation\n- `provider::prettyjson::jsonprettyprint(json_string, \"4spaces\")` - Uses 4-space indentation\n- `provider::prettyjson::jsonprettyprint(json_string, \"tab\")` - Uses tab indentation\n\n**Error Handling:**\nInvalid indentation types will result in a clear error message listing valid options.",
			AllowNullValue:      true,
		},
		Return: function.StringReturn{},
	}

	tflog.Debug(ctx, "Function definition operation completed", map[string]any{
		"parameter_count":    len(resp.Definition.Parameters),
		"has_variadic_param": resp.Definition.VariadicParameter != nil,
		"return_type":        "string",
	})
}

func (r JSONPrettyPrintFunction) Run(ctx context.Context, req function.RunRequest, resp *function.RunResponse) {
	// Add structured logging context for function execution
	ctx = tflog.SetField(ctx, "function_name", "jsonprettyprint")
	ctx = tflog.SetField(ctx, "operation", "run")

	// Performance monitoring setup
	startTime := time.Now()
	defer func() {
		duration := time.Since(startTime)
		tflog.Debug(ctx, "Function execution completed", map[string]any{
			"duration_ms": duration.Milliseconds(),
			"duration_ns": duration.Nanoseconds(),
		})
	}()

	tflog.Debug(ctx, "Starting JSON pretty-print function execution")

	var jsonString string
	var indentationTypes []string

	// Extract required json_string parameter
	tflog.Trace(ctx, "Extracting json_string parameter")
	resp.Error = function.ConcatFuncErrors(resp.Error, req.Arguments.Get(ctx, &jsonString, &indentationTypes))
	if resp.Error != nil {
		tflog.Error(ctx, "Failed to extract function parameters", map[string]any{
			"error": resp.Error.Error(),
		})
		return
	}

	// Log input characteristics for performance monitoring
	inputSize := len(jsonString)
	hasVariadicParam := len(indentationTypes) > 0
	tflog.Debug(ctx, "Input parameters extracted", map[string]any{
		"input_size_bytes":   inputSize,
		"input_size_chars":   len([]rune(jsonString)),
		"has_variadic_param": hasVariadicParam,
		"variadic_count":     len(indentationTypes),
	})

	// Task 5.5: Performance monitoring - Log warning for large JSON inputs
	if inputSize > LargeJSONWarningSize {
		tflog.Warn(ctx, "Large JSON input detected", map[string]any{
			"warning_type":   "PERFORMANCE_WARNING",
			"size_bytes":     inputSize,
			"size_mb":        float64(inputSize) / (1024 * 1024),
			"threshold_mb":   LargeJSONWarningSize / (1024 * 1024),
			"recommendation": "Consider reducing JSON size for better performance",
		})
	}

	// Determine indentation type with default value
	var indentationType string
	if hasVariadicParam {
		indentationType = indentationTypes[0]
		tflog.Debug(ctx, "Using provided indentation type", map[string]any{
			"indentation_type": indentationType,
		})
	} else {
		indentationType = "2spaces"
		tflog.Debug(ctx, "Using default indentation type", map[string]any{
			"default_indentation": indentationType,
		})
	}

	tflog.Debug(ctx, "Function parameters processed", map[string]any{
		"indentation_type": indentationType,
		"input_size":       inputSize,
	})

	// Task 4.1: JSON Validation Logic
	tflog.Debug(ctx, "Starting JSON validation", map[string]any{
		"input_size": inputSize,
	})

	// Task 5.1 & 5.3: Enhanced input validation with size limits and error classification
	if inputSize == 0 {
		tflog.Error(ctx, "Empty JSON input provided", map[string]any{
			"error_type": ErrorTypeValidation,
			"error_code": "EMPTY_INPUT",
		})
		resp.Error = function.NewArgumentFuncError(0, "JSON input cannot be empty. Please provide a valid JSON string.")
		return
	}

	// Task 5.3: Enforce maximum input size limit
	if inputSize > MaxJSONSize {
		tflog.Error(ctx, "JSON input exceeds maximum size limit", map[string]any{
			"error_type":    ErrorTypeValidation,
			"error_code":    "SIZE_LIMIT_EXCEEDED",
			"input_size":    inputSize,
			"max_size":      MaxJSONSize,
			"size_limit_mb": MaxJSONSize / (1024 * 1024),
		})
		resp.Error = function.NewArgumentFuncError(0, fmt.Sprintf(
			"JSON input size (%d bytes) exceeds maximum allowed size of %d MB. "+
				"Please reduce the JSON size or split into smaller chunks.",
			inputSize, MaxJSONSize/(1024*1024)))
		return
	}

	// Fast JSON validation using json.Valid()
	validationStart := time.Now()
	var validationDuration time.Duration
	if !json.Valid([]byte(jsonString)) {
		validationDuration = time.Since(validationStart)

		// Task 5.4: Context-aware error messages with remediation suggestions
		tflog.Error(ctx, "JSON validation failed", map[string]any{
			"error_type":         ErrorTypeValidation,
			"error_code":         "INVALID_JSON_SYNTAX",
			"input_preview":      truncateString(jsonString, 100),
			"validation_time_ms": validationDuration.Milliseconds(),
			"input_size":         inputSize,
		})

		// Enhanced error message with context and remediation suggestions
		resp.Error = function.NewArgumentFuncError(0,
			"Invalid JSON syntax detected. Common issues include: "+
				"missing quotes around strings, trailing commas, unescaped characters, "+
				"or mismatched brackets/braces. Please validate your JSON using a JSON "+
				"validator tool and ensure proper formatting.")
		return
	}

	validationDuration = time.Since(validationStart)
	tflog.Debug(ctx, "JSON validation successful", map[string]any{
		"validation_time_ms": validationDuration.Milliseconds(),
	})

	// Task 4.2: JSON Parsing functionality
	tflog.Debug(ctx, "Starting JSON parsing for structure validation")

	var jsonData any
	parseStart := time.Now()
	var parseDuration time.Duration
	if err := json.Unmarshal([]byte(jsonString), &jsonData); err != nil {
		parseDuration = time.Since(parseStart)

		// Task 5.1 & 5.4: Enhanced error classification and context-aware messages
		tflog.Error(ctx, "JSON parsing failed", map[string]any{
			"error_type":    ErrorTypeParsing,
			"error_code":    "JSON_PARSE_ERROR",
			"error":         err.Error(),
			"input_preview": truncateString(jsonString, 100),
			"parse_time_ms": parseDuration.Milliseconds(),
			"input_size":    inputSize,
		})

		// Context-aware error message with specific guidance
		resp.Error = function.NewArgumentFuncError(0, fmt.Sprintf(
			"JSON parsing error: %v. This typically indicates structural issues in "+
				"the JSON such as incorrect nesting, invalid escape sequences, or "+
				"data type mismatches. Please check the JSON structure and syntax.", err))
		return
	}

	parseDuration = time.Since(parseStart)
	tflog.Debug(ctx, "JSON parsing successful", map[string]any{
		"parse_time_ms": parseDuration.Milliseconds(),
		"data_type":     fmt.Sprintf("%T", jsonData),
	})

	// Task 4.3: Pretty-printing with json.MarshalIndent
	tflog.Debug(ctx, "Starting JSON pretty-printing", map[string]any{
		"indentation_type": indentationType,
	})

	// Task 7: Validate indentation type parameter with descriptive error messages
	var indent string
	switch indentationType {
	case "2spaces":
		indent = "  "
	case "4spaces":
		indent = "    "
	case "tab":
		indent = "\t"
	case "":
		// Default to 2 spaces when no indentation type specified
		indent = "  "
		tflog.Debug(ctx, "Using default indentation (no type specified)", map[string]any{
			"default_indent": "2spaces",
		})
	default:
		// Task 7: Explicit validation with descriptive error messages for invalid indentation types
		tflog.Error(ctx, "Invalid indentation type provided", map[string]any{
			"error_type":    ErrorTypeValidation,
			"error_code":    "INVALID_INDENTATION_TYPE",
			"provided_type": indentationType,
			"valid_types":   []string{"2spaces", "4spaces", "tab"},
		})

		resp.Error = function.NewArgumentFuncError(1, fmt.Sprintf(
			"Invalid indentation type '%s'. Valid options are: '2spaces', '4spaces', or 'tab'. "+
				"Please specify one of the supported indentation types for proper JSON formatting.",
			indentationType))
		return
	}

	// Pretty-print with proper indentation
	formatStart := time.Now()
	prettyJSON, err := json.MarshalIndent(jsonData, "", indent)
	if err != nil {
		formatDuration := time.Since(formatStart)

		// Task 5.1 & 5.4: Enhanced error classification for processing errors
		tflog.Error(ctx, "JSON formatting failed", map[string]any{
			"error_type":     ErrorTypeProcessing,
			"error_code":     "JSON_FORMAT_ERROR",
			"error":          err.Error(),
			"indentation":    indentationType,
			"format_time_ms": formatDuration.Milliseconds(),
			"input_size":     inputSize,
		})

		// Context-aware error message for formatting failures
		resp.Error = function.NewFuncError(fmt.Sprintf(
			"JSON formatting failed: %v. This error usually occurs when the parsed "+
				"JSON data contains unsupported types or circular references. "+
				"Please verify the JSON data structure is valid for serialization.", err))
		return
	}

	formatDuration := time.Since(formatStart)
	result := string(prettyJSON)

	tflog.Debug(ctx, "JSON formatting successful", map[string]any{
		"format_time_ms":   formatDuration.Milliseconds(),
		"output_size":      len(result),
		"indentation_used": indentationType,
	})

	// Set result with error handling
	resp.Error = function.ConcatFuncErrors(resp.Error, resp.Result.Set(ctx, result))
	if resp.Error != nil {
		tflog.Error(ctx, "Failed to set function result", map[string]any{
			"error": resp.Error.Error(),
		})
		return
	}

	tflog.Info(ctx, "JSON pretty-print function execution successful", map[string]any{
		"result_size":      len(result),
		"indentation_type": indentationType,
		"input_size":       inputSize,
	})
}

// Helper function to truncate strings for logging.
func truncateString(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}
