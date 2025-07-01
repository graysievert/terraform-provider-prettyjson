# Variables for Basic Integration Examples
# These variables demonstrate various configuration patterns and data types
# that can be formatted using the prettyjson provider with local_file resource.

variable "app_name" {
  description = "Name of the application for configuration generation"
  type        = string
  default     = "my-app"

  validation {
    condition     = length(var.app_name) > 0 && can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.app_name))
    error_message = "App name must start with a letter and contain only letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment (affects configuration values)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "database_config" {
  description = "Database configuration parameters"
  type = object({
    host     = string
    port     = number
    database = string
    ssl      = bool
  })
  default = {
    host     = "localhost"
    port     = 5432
    database = "myapp"
    ssl      = true
  }

  validation {
    condition     = var.database_config.port > 0 && var.database_config.port <= 65535
    error_message = "Database port must be between 1 and 65535."
  }
}

variable "enable_features" {
  description = "Feature flags for application configuration"
  type = object({
    logging = bool
    metrics = bool
    tracing = bool
    caching = bool
  })
  default = {
    logging = true
    metrics = true
    tracing = false
    caching = true
  }
}

variable "service_endpoints" {
  description = "List of service endpoints to include in configuration"
  type = list(object({
    name        = string
    port        = number
    health_path = string
  }))
  default = [
    {
      name        = "api"
      port        = 8080
      health_path = "/health"
    },
    {
      name        = "worker"
      port        = 8090
      health_path = "/status"
    }
  ]
}

variable "indentation_preference" {
  description = "Preferred indentation style for generated JSON files"
  type        = string
  default     = "2spaces"

  validation {
    condition     = contains(["2spaces", "4spaces", "tab"], var.indentation_preference)
    error_message = "Indentation preference must be one of: 2spaces, 4spaces, tab."
  }
}

variable "output_directory" {
  description = "Directory path for generated configuration files"
  type        = string
  default     = "generated"

  validation {
    condition     = length(var.output_directory) > 0
    error_message = "Output directory cannot be empty."
  }
}