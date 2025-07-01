variable "environment" {
  description = "Deployment environment (development, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "app_name" {
  description = "Application name prefix"
  type        = string
  default     = "webapp"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "App name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "replica_count" {
  description = "Number of application replicas"
  type        = number
  default     = 2

  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 10
    error_message = "Replica count must be between 1 and 10."
  }
}

variable "enable_debugging" {
  description = "Enable debug mode in configurations"
  type        = bool
  default     = false
}

variable "indentation_format" {
  description = "JSON indentation format for generated files"
  type        = string
  default     = "2spaces"

  validation {
    condition     = contains(["2spaces", "4spaces", "tabs"], var.indentation_format)
    error_message = "Indentation format must be one of: 2spaces, 4spaces, tabs."
  }
}

variable "custom_labels" {
  description = "Custom labels to add to all configurations"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.custom_labels : can(regex("^[a-zA-Z0-9-_.]+$", k))
    ])
    error_message = "Label keys must contain only alphanumeric characters, hyphens, underscores, and periods."
  }
}