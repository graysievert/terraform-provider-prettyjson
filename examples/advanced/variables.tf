# Variables for Advanced Complex Data Structure Examples
# These variables demonstrate advanced configuration patterns with complex nested objects,
# lists, and real-world infrastructure and application scenarios.

variable "microservices" {
  description = "Comprehensive microservices configuration with resources, health checks, and environment variables"
  type = map(object({
    image    = string
    replicas = number
    ports    = list(number)
    env_vars = map(string)
    resources = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    health_check = object({
      path     = string
      port     = number
      interval = number
      timeout  = number
    })
  }))
  default = {
    api = {
      image    = "api:v1.2.3"
      replicas = 3
      ports    = [8080, 8443]
      env_vars = {
        LOG_LEVEL = "info"
        DB_HOST   = "postgres.internal"
        CACHE_URL = "redis.internal:6379"
      }
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
      health_check = {
        path     = "/health"
        port     = 8080
        interval = 30
        timeout  = 5
      }
    }
    worker = {
      image    = "worker:v1.2.3"
      replicas = 2
      ports    = [8090]
      env_vars = {
        LOG_LEVEL   = "debug"
        QUEUE_URL   = "amqp://rabbitmq.internal"
        WORKER_TYPE = "background"
      }
      resources = {
        requests = {
          cpu    = "200m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
      }
      health_check = {
        path     = "/status"
        port     = 8090
        interval = 60
        timeout  = 10
      }
    }
  }
}

variable "infrastructure_config" {
  description = "Complex infrastructure configuration with VPC, security groups, and databases"
  type = object({
    vpc = object({
      cidr_block           = string
      enable_dns_hostnames = bool
      enable_dns_support   = bool
      subnets = map(object({
        cidr_block        = string
        availability_zone = string
        public            = bool
      }))
    })
    security_groups = map(object({
      description = string
      ingress_rules = list(object({
        from_port   = number
        to_port     = number
        protocol    = string
        cidr_blocks = list(string)
        description = string
      }))
      egress_rules = list(object({
        from_port   = number
        to_port     = number
        protocol    = string
        cidr_blocks = list(string)
        description = string
      }))
    }))
    databases = map(object({
      engine         = string
      engine_version = string
      instance_class = string
      storage = object({
        allocated     = number
        max_allocated = number
        encrypted     = bool
        type          = string
      })
      backup = object({
        retention_period = number
        window           = string
        final_snapshot   = bool
      })
    }))
  })

  validation {
    condition     = can(cidrhost(var.infrastructure_config.vpc.cidr_block, 0))
    error_message = "VPC CIDR block must be a valid CIDR notation."
  }
}

variable "deployment_environments" {
  description = "List of deployment environments for matrix generation"
  type        = list(string)
  default     = ["dev", "staging", "prod"]

  validation {
    condition = alltrue([
      for env in var.deployment_environments : contains(["dev", "staging", "prod"], env)
    ])
    error_message = "Deployment environments must be one of: dev, staging, prod."
  }
}

variable "monitoring_config" {
  description = "Monitoring and observability configuration"
  type = object({
    prometheus = object({
      enabled         = bool
      scrape_interval = string
      retention_days  = number
    })
    grafana = object({
      enabled       = bool
      admin_user    = string
      theme         = string
      organizations = list(string)
    })
    alerting = object({
      enabled     = bool
      webhook_url = string
      channels = list(object({
        name     = string
        type     = string
        settings = map(string)
      }))
    })
  })
  default = {
    prometheus = {
      enabled         = true
      scrape_interval = "15s"
      retention_days  = 30
    }
    grafana = {
      enabled       = true
      admin_user    = "admin"
      theme         = "dark"
      organizations = ["main", "monitoring"]
    }
    alerting = {
      enabled     = true
      webhook_url = "https://hooks.slack.com/services/example"
      channels = [
        {
          name = "alerts"
          type = "slack"
          settings = {
            channel  = "#alerts"
            username = "terraform-bot"
          }
        }
      ]
    }
  }
}

variable "backup_strategy" {
  description = "Backup and disaster recovery strategy configuration"
  type = object({
    enabled = bool
    retention = object({
      daily   = number
      weekly  = number
      monthly = number
      yearly  = number
    })
    cross_region = object({
      enabled = bool
      regions = list(string)
    })
    encryption = object({
      enabled   = bool
      algorithm = string
      key_rotation = object({
        enabled       = bool
        rotation_days = number
      })
    })
  })
  default = {
    enabled = true
    retention = {
      daily   = 7
      weekly  = 4
      monthly = 12
      yearly  = 7
    }
    cross_region = {
      enabled = true
      regions = ["us-west-2", "us-east-1"]
    }
    encryption = {
      enabled   = true
      algorithm = "AES256"
      key_rotation = {
        enabled       = true
        rotation_days = 90
      }
    }
  }
}

variable "feature_flags" {
  description = "Application feature flags with complex nested structure"
  type = map(object({
    enabled = bool
    rollout = object({
      strategy    = string
      percentage  = number
      user_groups = list(string)
      conditions = list(object({
        field    = string
        operator = string
        value    = string
      }))
    })
    config = map(any)
  }))
  default = {
    new_ui = {
      enabled = true
      rollout = {
        strategy    = "percentage"
        percentage  = 25
        user_groups = ["beta", "internal"]
        conditions = [
          {
            field    = "user.plan"
            operator = "equals"
            value    = "premium"
          }
        ]
      }
      config = {
        theme         = "modern"
        animations    = true
        beta_features = true
      }
    }
    enhanced_search = {
      enabled = false
      rollout = {
        strategy    = "user_groups"
        percentage  = 0
        user_groups = ["internal"]
        conditions  = []
      }
      config = {
        elasticsearch_enabled = true
        fuzzy_search          = true
        filters               = ["date", "category", "author"]
      }
    }
  }
}

variable "output_preferences" {
  description = "Preferences for generated file formats and indentation"
  type = object({
    default_indentation = string
    separate_files      = bool
    include_metadata    = bool
    compress_output     = bool
  })
  default = {
    default_indentation = "2spaces"
    separate_files      = true
    include_metadata    = true
    compress_output     = false
  }

  validation {
    condition     = contains(["2spaces", "4spaces", "tab"], var.output_preferences.default_indentation)
    error_message = "Default indentation must be one of: 2spaces, 4spaces, tab."
  }
}