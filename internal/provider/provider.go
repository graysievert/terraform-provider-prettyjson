// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package provider

import (
	"context"

	"github.com/hashicorp/terraform-plugin-framework/datasource"
	"github.com/hashicorp/terraform-plugin-framework/function"
	"github.com/hashicorp/terraform-plugin-framework/provider"
	"github.com/hashicorp/terraform-plugin-framework/provider/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource"
)

// Ensure PrettyJSONProvider satisfies various provider interfaces.
var _ provider.Provider = &PrettyJSONProvider{}
var _ provider.ProviderWithFunctions = &PrettyJSONProvider{}

// PrettyJSONProvider defines the provider implementation.
type PrettyJSONProvider struct {
	// version is set to the provider version on release, "dev" when the
	// provider is built and ran locally, and "test" when running acceptance
	// testing.
	version string
}

func (p *PrettyJSONProvider) Metadata(ctx context.Context, req provider.MetadataRequest, resp *provider.MetadataResponse) {
	resp.TypeName = "prettyjson"
	resp.Version = p.version
}

func (p *PrettyJSONProvider) Schema(ctx context.Context, req provider.SchemaRequest, resp *provider.SchemaResponse) {
	resp.Schema = schema.Schema{
		Description: "PrettyJSON provider for formatting JSON with configurable indentation",
		MarkdownDescription: `The **PrettyJSON provider** is a function-only Terraform provider designed for formatting JSON strings with configurable indentation styles.

## Key Features

- **Multiple Indentation Options**: Support for 2-space, 4-space, and tab indentation
- **JSON Validation**: Built-in validation ensures input is syntactically correct JSON
- **Performance Optimized**: Efficient processing with size limits and performance warnings
- **Error Handling**: Comprehensive error messages with troubleshooting guidance
- **Zero Configuration**: No provider configuration required

## Supported Functions

- **jsonprettyprint**: Format JSON strings with configurable indentation (2spaces, 4spaces, or tab)

This provider does not manage any infrastructure resources - it only provides utility functions for JSON formatting.`,
		Attributes: map[string]schema.Attribute{}, // Empty attributes for function-only provider
	}
}

func (p *PrettyJSONProvider) Configure(ctx context.Context, req provider.ConfigureRequest, resp *provider.ConfigureResponse) {
	// No configuration needed for this function-only provider
}

func (p *PrettyJSONProvider) Resources(ctx context.Context) []func() resource.Resource {
	return []func() resource.Resource{}
}

func (p *PrettyJSONProvider) DataSources(ctx context.Context) []func() datasource.DataSource {
	return []func() datasource.DataSource{}
}

func (p *PrettyJSONProvider) Functions(ctx context.Context) []func() function.Function {
	return []func() function.Function{
		NewJSONPrettyPrintFunction,
	}
}

func New(version string) func() provider.Provider {
	return func() provider.Provider {
		return &PrettyJSONProvider{
			version: version,
		}
	}
}
