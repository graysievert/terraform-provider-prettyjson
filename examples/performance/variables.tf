variable "environment" {
  description = "Deployment environment (affects configuration size and optimization)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "enable_large_configs" {
  description = "Enable generation of large configuration files (performance impact)"
  type        = bool
  default     = false
}

variable "max_services_per_chunk" {
  description = "Maximum number of services per configuration chunk (performance tuning)"
  type        = number
  default     = 10

  validation {
    condition     = var.max_services_per_chunk >= 5 && var.max_services_per_chunk <= 50
    error_message = "Services per chunk must be between 5 and 50."
  }
}

variable "indentation_preference" {
  description = "Indentation format preference based on file size and usage"
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["auto", "2spaces", "4spaces", "tabs"], var.indentation_preference)
    error_message = "Indentation preference must be one of: auto, 2spaces, 4spaces, tabs."
  }
}

variable "optimize_for_frequency" {
  description = "Optimize configuration for frequent access (smaller, faster loading files)"
  type        = bool
  default     = true
}

variable "enable_chunking" {
  description = "Enable configuration chunking for better performance with large datasets"
  type        = bool
  default     = true
}

variable "development_service_limit" {
  description = "Maximum number of services to include in development configurations"
  type        = number
  default     = 5

  validation {
    condition     = var.development_service_limit >= 1 && var.development_service_limit <= 20
    error_message = "Development service limit must be between 1 and 20."
  }
}

variable "performance_mode" {
  description = "Performance optimization mode"
  type        = string
  default     = "balanced"

  validation {
    condition     = contains(["minimal", "balanced", "comprehensive"], var.performance_mode)
    error_message = "Performance mode must be one of: minimal, balanced, comprehensive."
  }
}